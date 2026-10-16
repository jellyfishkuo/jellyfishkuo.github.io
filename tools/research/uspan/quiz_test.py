"""練習模式：用隨機資料檢查每一題的正確答案（暴力列舉每一種對應來算效益、SPU、SWU、ru），再檢查版面。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）。用法：quiz_test.py [組數] [截圖路徑]"""
import os, random, re, sys
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/uspan.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 100
SHOT = sys.argv[2] if len(sys.argv) > 2 else None
GET = """([d, p, m]) => { const tr = buildTrace(d, p, m);
    return tr.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""
CAT = ['是高效益，也往下長', '是高效益，但不往下長', '不是高效益，但往下長', '不是高效益，也不往下長']


def matches(pat, seq, pr):
    out = []
    def rec(i, k, ks, acc):
        if i == len(pat): out.append((ks, acc)); return
        for j in range(k, len(seq)):
            if all(x in seq[j] for x in pat[i]): rec(i + 1, j + 1, ks + [j], acc + sum(seq[j][x] * pr[x] for x in pat[i]))
    rec(0, 0, [], 0)
    return out

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
        db = [[{x: random.randint(1, 4) for x in random.sample(ITEMS, random.randint(1, 3))} for _ in range(random.randint(1, 4))] for _ in range(random.randint(1, 7))]
        pr = {x: random.randint(1, 40) for x in ITEMS}
        su = [sum(e[x] * pr[x] for e in seq for x in e) for seq in db]
        mu = random.randint(1, max(1, sum(su) // 2))
        swu = {}
        for sid, seq in enumerate(db):
            for x in {x for e in seq for x in e}: swu[x] = swu.get(x, 0) + su[sid]
        keep = {x for x in swu if swu[x] >= mu}
        def ru(seq, k, item):
            return sum(e[x] * pr[x] for kk, e in enumerate(seq) for x in e if x in keep and (kk > k or (kk == k and x > item)))
        util = lambda pat: sum(max([u for _, u in matches(pat, seq, pr)], default=0) for seq in db)
        def spu(pat):
            tot = 0
            for seq in db:
                acu = {}
                for ks, u in matches(pat, seq, pr): acu[ks[-1]] = max(acu.get(ks[-1], 0), u)
                tot += max([a + ru(seq, k, pat[-1][-1]) for k, a in acu.items() if ru(seq, k, pat[-1][-1]) > 0], default=0)
            return tot
        swu_pat = lambda pat: sum(su[sid] for sid, seq in enumerate(db) if matches(pat, seq, pr))
        for q in pg.evaluate(GET, [db, pr, mu]):
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = len(ch) >= 2 and len(set(ch)) == len(ch) and len(ch) <= 4
            if t == 'swu': ok &= int(ch[a]) == swu[ask['item']]
            elif t == 'ru': ok &= int(ch[a]) == ru(db[ask['sid']], ask['k'], ask['item'])
            elif t == 'swuPat': ok &= int(ch[a]) == swu_pat(ask['pat'])
            elif t == 'swuCut': ok &= set(a) == {k for k, pat in enumerate(ask['pats']) if swu_pat(pat) < mu}
            elif t == 'util': ok &= int(ch[a]) == util(ask['pat'])
            elif t == 'cat':
                u, s = util(ask['pat']), spu(ask['pat'])
                m = re.search(r'效益 (\d+)、SPU (\d+)', q['q'])
                ok &= bool(m) and (int(m.group(1)), int(m.group(2))) == (u, s) and ch[a] == CAT[(0 if u >= mu else 2) + (0 if s >= mu else 1)]
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', db, pr, mu, q)
    print(f'uspan 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    layout(b, U, SHOT)
    b.close()
