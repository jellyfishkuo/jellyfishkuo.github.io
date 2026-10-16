"""練習模式：用隨機資料檢查每一題的正確答案（Python 自己算 TU／TWU／效益），再檢查版面。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）。用法：quiz_test.py [組數] [截圖路徑]"""
import os, random, sys
from itertools import combinations
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/two-phase.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 100
SHOT = sys.argv[2] if len(sys.argv) > 2 else None
GET = """([d, p, m]) => { minUtil = m; const tr = buildTrace(d, p, m); trace = tr;
    return tr.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""

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
        db = [{i: random.randint(1, 5) for i in random.sample(ITEMS, random.randint(1, 6))} for _ in range(random.randint(1, 10))]
        profit = {i: random.randint(1, 40) for i in ITEMS}
        tu = [sum(t[i] * profit[i] for i in t) for t in db]
        mu = random.randint(1, max(1, sum(tu) // 2))
        has = lambda t, s: all(i in t for i in s)
        twu = lambda s: sum(tu[k] for k, t in enumerate(db) if has(t, s))
        util = lambda s: sum(sum(t[i] * profit[i] for i in s) for t in db if has(t, s))
        for q in pg.evaluate(GET, [db, profit, mu]):
            if q['ask'].get('only'):
                if q['choices'] != ['會', '不會']: bad += 1
                q = {**q, 'choices': q['ask']['only'], 'answer': [0] if q['answer'] == 0 else [], 'multi': True}
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = (len(ch) >= 2 or ask.get('only')) and len(set(ch)) == len(ch) and len(ch) <= 4
            if t == 'tu': ok &= int(ch[a]) == tu[ask['tid']]
            elif t == 'twu': ok &= int(ch[a]) == twu(ask['set'])
            elif t == 'util': ok &= int(ch[a]) == util(ask['set'])
            elif t == 'cut': ok &= set(a) == {k for k, s in enumerate(ask['sets']) if twu(s) < mu}
            elif t == 'keepTwu': ok &= set(a) == {k for k, s in enumerate(ask['sets']) if twu(s) >= mu}
            elif t == 'hui': ok &= set(a) == {k for k, s in enumerate(ask['sets']) if util(s) >= mu} and all(twu(s) >= mu for s in ask['sets'])
            elif t == 'prune': ok &= (a == 0) == any(twu(sub) < mu for sub in combinations(ask['set'], len(ask['set']) - 1))
            elif t == 'join':
                L, k = ask['L'], ask['k']
                allL = {frozenset(c) for c in combinations({i for t in db for i in t}, k - 1) if twu(c) >= mu}
                ok &= {frozenset(x) for x in L} == allL
                ok &= int(ch[a]) == sum(1 for x in range(len(L)) for y in range(x + 1, len(L)) if L[x][:k - 2] == L[y][:k - 2])
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', db, profit, mu, q)
    print(f'two-phase 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    layout(b, U, SHOT)
    b.close()
