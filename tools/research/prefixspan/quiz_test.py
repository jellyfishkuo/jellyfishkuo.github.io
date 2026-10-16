"""練習模式：用隨機資料檢查每一題的正確答案（暴力比對子序列），再檢查版面。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）。用法：quiz_test.py [組數] [截圖路徑]"""
import os, random, sys
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/prefixspan.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 100
SHOT = sys.argv[2] if len(sys.argv) > 2 else None
GET = """([d, m]) => { minSup = m; const tr = buildTrace(d, m);
    return tr.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""


def contains(seq, pat):
    i = 0
    for e in seq:
        if i < len(pat) and set(pat[i]) <= set(e): i += 1
    return i == len(pat)


# ---- 版面：375 / 1280 打開練習模式，隨機作答從頭走到尾，每個 .card 位置都不能變 ----
LAYOUT = """() => {
    const pos = () => [...document.querySelectorAll('.card')].filter(c => !c.closest('[hidden]') && c.offsetParent).map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.left), Math.round(r.height)]; }).join('|');
    const base = pos(); let moved = 0, asked = 0, guard = 0;
    const chk = () => { if (pos() !== base) moved++; };
    $('quiz-toggle').click(); chk();
    while (guard++ < 5000) {
        if (QZ.q && !QZ.answered) {
            asked++; chk();
            const cs = [...document.querySelectorAll('#quiz .quiz-choice')];
            if (QZ.q.multi) { cs.forEach(c => { if (Math.random() < 0.5) c.click(); }); document.querySelector('#quiz .quiz-ok').click(); }
            else cs[Math.floor(Math.random() * cs.length)].click();
            chk(); document.querySelector('#quiz .quiz-go').click(); chk(); continue;
        }
        if (cursor >= trace.length - 1) break;
        $('btn-next').click(); chk();
    }
    $('quiz-toggle').click(); chk();
    return { moved, asked, score: $('quiz-score').textContent, sw: document.documentElement.scrollWidth, w: innerWidth };
}"""
IDLE = "() => !document.documentElement.hasAttribute('aria-busy')"


def layout(b, url, shot, prep=None):
    out = []
    for w in (375, 1280):
        ctx = b.new_context(viewport={'width': w, 'height': 900}); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
        pg.goto(url); pg.wait_for_function(IDLE)
        for tab in (prep or [None]):
            if tab: pg.evaluate(tab); pg.wait_for_function(IDLE)
            r = pg.evaluate(LAYOUT)
            out.append(f"{w}px{' ' + tab if tab else ''}: 題目 {r['asked']}，位置變動 {r['moved']}，scrollWidth {r['sw']}/{r['w']}")
        if w == 375 and shot:
            pg.reload(); pg.wait_for_function(IDLE)
            pg.evaluate("() => { $('quiz-toggle').click(); for (let k = 0; k < 40 && !QZ.q; k++) $('btn-next').click(); }")
            pg.locator('#quiz-host').scroll_into_view_if_needed(); pg.screenshot(path=shot)
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
        ms = random.randint(max(1, len(db) // 3), len(db))
        sup = lambda pat: sum(contains(s, pat) for s in db)
        for q in pg.evaluate(GET, [db, ms]):
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = len(ch) >= 2 and len(set(ch)) == len(ch) and len(ch) <= 4
            if t == 'support': ok &= int(ch[a]) == sup(ask['pat'])
            elif t == 'exts': ok &= set(a) == {k for k, pat in enumerate(ask['opts']) if sup(pat) >= ms}
            elif t == 'dropped':
                ok &= all(contains(db[s], ask['prefix']) for s in ask['sids'])
                ok &= set(a) == {k for k, s in enumerate(ask['sids']) if not contains(db[s], ask['pat'])} and len(a) > 0
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', db, ms, q)
    print(f'prefixspan 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    layout(b, U, SHOT)
    b.close()
