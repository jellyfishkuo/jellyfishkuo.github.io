"""練習模式（GSP、SPADE 兩個分頁）：用隨機資料檢查每一題的正確答案（Python 版 gsp.py 與暴力比對），再檢查版面。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）。用法：quiz_test.py [組數] [截圖路徑]"""
import os, random, sys
from playwright.sync_api import sync_playwright
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from gsp import gsp, join, contiguous_subs, contains
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/gsp-spade.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 100
SHOT = sys.argv[2] if len(sys.argv) > 2 else None
GET = """([d, m]) => { minSup = m; const out = [];
    for (const [g, tr] of [['g', gspTrace(d, m)], ['s', spadeTrace(d, m)]])
        tr.forEach((s, i) => { const q = QUIZ_FOR[g](s, i); if (q) out.push({ g, q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask }); });
    return out; }"""
# 版面：每個分頁都打開練習模式，隨機作答從頭走到尾，每個 .card 位置都不能變
LAYOUT = """(g) => {
    const el = id => document.getElementById(g + '-' + id), Q = quizzes[g].QZ;
    const pos = () => [...document.querySelectorAll('.card')].filter(c => !c.closest('[hidden]') && c.offsetParent).map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.left), Math.round(r.height)]; }).join('|');
    const base = pos(); let moved = 0, asked = 0, guard = 0;
    const chk = () => { if (pos() !== base) moved++; };
    el('quiz-toggle').click(); chk();
    while (guard++ < 5000) {
        if (Q.q && !Q.answered) {
            asked++; chk();
            const cs = [...el('quiz').querySelectorAll('.quiz-choice')];
            if (Q.q.multi) { cs.forEach(c => { if (Math.random() < 0.5) c.click(); }); el('quiz').querySelector('.quiz-ok').click(); }
            else cs[Math.floor(Math.random() * cs.length)].click();
            chk(); el('quiz').querySelector('.quiz-go').click(); chk(); continue;
        }
        if (cursors[g] >= traces[g].length - 1) break;
        el('next').click(); chk();
    }
    el('quiz-toggle').click(); chk();
    return { moved, asked, sw: document.documentElement.scrollWidth, w: innerWidth };
}"""
IDLE = "() => !document.documentElement.hasAttribute('aria-busy')"


def layout(b):
    out = []
    for w in (375, 1280):
        ctx = b.new_context(viewport={'width': w, 'height': 900}); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
        pg.goto(U); pg.wait_for_function(IDLE)
        for g in 'gs':
            if g == 's': pg.click('#tab-s'); pg.wait_for_function(IDLE)
            r = pg.evaluate(LAYOUT, g)
            out.append(f"{w}px {'GSP' if g == 'g' else 'SPADE'}: 題目 {r['asked']}，位置變動 {r['moved']}，scrollWidth {r['sw']}/{r['w']}")
        if w == 375 and SHOT:
            pg.goto(U + '#gsp'); pg.reload(); pg.wait_for_function(IDLE)   # 切過分頁網址會變成 #spade
            pg.evaluate("() => { document.getElementById('g-quiz-toggle').click(); for (let k = 0; k < 40 && !quizzes.g.QZ.q; k++) document.getElementById('g-next').click(); }")
            pg.locator('#g-quiz-host').scroll_into_view_if_needed(); pg.screenshot(path=SHOT)
        out.append(f'{w}px pageerror {errs}')
        ctx.close()
    print('\n'.join(out))


with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(300)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        db = [[random.sample(ITEMS, random.randint(1, 3)) for _ in range(random.randint(1, 5))] for _ in range(random.randint(2, 8))]
        ms = random.randint(2, len(db))
        sdb = [[sorted(set(e)) for e in seq] for seq in db]
        sup = lambda pat: sum(contains(s, pat) for s in sdb)
        freq = gsp(db, ms)
        for q in pg.evaluate(GET, [db, ms]):
            if q['ask'].get('only'):
                if q['choices'] != ['會', '不會']: bad += 1
                q = {**q, 'choices': q['ask']['only'], 'answer': [0] if q['answer'] == 0 else [], 'multi': True}
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = q['g'] + ':' + ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = (len(ch) >= 2 or ask.get('only')) and len(set(ch)) == len(ch) and len(ch) <= 4
            tp = lambda pat: tuple(tuple(e) for e in pat)
            if ask['type'] == 'sup': ok &= int(ch[a]) == sup(ask['pat'])
            elif ask['type'] == 'keep': ok &= set(a) == {k for k, pat in enumerate(ask['pats']) if sup(pat) >= ms}
            elif ask['type'] == 'prune': ok &= (a == 0) == any(sup(s) < ms for s in contiguous_subs(tp(ask['pat'])))
            elif ask['type'] == 'join':
                k = ask['k']
                level = [pt for pt in freq if sum(len(e) for e in pt) == k - 1]
                ok &= int(ch[a]) == len(join(level, k))
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', db, ms, q)
    print(f'gsp-spade 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    layout(b)
    b.close()
