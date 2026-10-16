"""練習模式：用隨機資料檢查每一題的正確答案（Python 照 up_growth.py 再挖一次，記下每個上界與局部效益），再檢查版面。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）。用法：quiz_test.py [組數] [截圖路徑]"""
import os, random, sys
from playwright.sync_api import sync_playwright
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from up_growth import UPTree
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/up-growth.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 100
SHOT = sys.argv[2] if len(sys.argv) > 2 else None
GET = """([d, p, m]) => { minUtil = m; const tr = buildTrace(d, p, m);
    return tr.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""


def explore(db, profit, mu):
    """照 up_growth.py 挖一次，記下：每筆交易的 DGN 節點效益、每個檢查過的組合的上界、條件模式基底的局部效益"""
    twu, miu = {}, {}
    for t in db:
        tu = sum(q * profit[i] for i, q in t.items())
        for i, q in t.items():
            twu[i] = twu.get(i, 0) + tu
            miu[i] = min(miu.get(i, q * profit[i]), q * profit[i])
    order = sorted((i for i in twu if twu[i] >= mu), key=lambda i: (-twu[i], i))
    tree, dgn = UPTree(order), []
    for t in db:
        path = [i for i in order if i in t]; acc, nus = 0, []
        for i in path: acc += t[i] * profit[i]; nus.append(acc)
        dgn.append(dict(zip(path, nus))); tree.add(path, nus, 1)
    est, lus = {}, {}
    def mine(tree, suffix):
        for item in reversed(tree.order):
            e = sum(n.nu for n in tree.links[item]); pattern = (item,) + suffix; est[pattern] = e
            if e < mu: continue
            paths, lu = [], {}
            for n in tree.links[item]:
                path, p = [], n.parent
                while p.item is not None:
                    path.insert(0, p.item); lu[p.item] = lu.get(p.item, 0) + n.nu; p = p.parent
                paths.append(path)
            lus[pattern] = lu
            local = UPTree([i for i in tree.order if lu.get(i, 0) >= mu])
            for n, path in zip(tree.links[item], paths):
                pu, pc = n.nu, n.count
                keep = [i for i in path if lu[i] >= mu]
                pu -= sum(miu[i] * pc for i in path if lu[i] < mu)
                rest = sum(miu[i] * pc for i in keep); nus = []
                for i in keep: rest -= miu[i] * pc; nus.append(pu - rest)
                local.add(keep, nus, pc)
            if local.order: mine(local, pattern)
    mine(tree, ())
    return twu, dgn, est, lus

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
        mu = random.randint(1, max(1, sum(q * profit[i] for t in db for i, q in t.items()) // 2))
        twu, dgn, est, lus = explore(db, profit, mu)
        util = lambda s: sum(sum(t[i] * profit[i] for i in s) for t in db if all(i in t for i in s))
        for q in pg.evaluate(GET, [db, profit, mu]):
            if q['ask'].get('only'):
                if q['choices'] != ['會', '不會']: bad += 1
                q = {**q, 'choices': q['ask']['only'], 'answer': [0] if q['answer'] == 0 else [], 'multi': True}
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = (len(ch) >= 2 or ask.get('only')) and len(set(ch)) == len(ch) and len(ch) <= 4
            if t == 'twu': ok &= int(ch[a]) == twu[ask['set'][0]]
            elif t == 'cut': ok &= set(a) == {k for k, x in enumerate(ask['opts']) if twu[x] < mu}
            elif t == 'dgn': ok &= int(ch[a]) == dgn[ask['row']][ask['item']]
            elif t == 'est': e = est[tuple(ask['set'])]; ok &= int(ch[a]) == e and e >= util(ask['set'])
            elif t == 'lu': ok &= int(ch[a]) == lus[tuple(ask['set'])][ask['item']]
            elif t == 'dlu': ok &= set(a) == {k for k, x in enumerate(ask['opts']) if lus[tuple(ask['set'])][x] < mu}
            elif t == 'util': ok &= int(ch[a]) == util(ask['set'])
            elif t == 'hui': ok &= set(a) == {k for k, s in enumerate(ask['opts']) if util(s) >= mu}
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', db, profit, mu, q)
    print(f'up-growth 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    layout(b, U, SHOT)
    b.close()
