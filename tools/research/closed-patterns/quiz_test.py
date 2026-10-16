"""練習模式：用隨機資料檢查每一題的正確答案，跟 Python 暴力法算的一致。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）"""
import os, random, sys
from itertools import combinations
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/closed-patterns.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 150
GET = """([d, m]) => { db = d.map(t => new Set(t)); minSup = m; answer = bruteForce(); trace = buildTrace(); cursor = 0;
    return trace.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""
ACT = ['infreq', 'p1', 'p2', 'p3', 'p4']
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_function('() => !blocksBusy', timeout=20000)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        rows = random.randint(3, 10)
        db = [set(random.sample(ITEMS, random.randint(1, 6))) for _ in range(rows)]
        ms = random.randint(1, rows)
        sup = lambda s: sum(1 for t in db if set(s) <= t)
        items = sorted(set().union(*db))
        freq = [frozenset(c) for k in range(1, len(items) + 1) for c in combinations(items, k) if sup(c) >= ms]
        closed = lambda s: not any(len(g) > len(s) and s <= g and sup(g) == sup(s) for g in freq)
        maximal = lambda s: not any(len(g) > len(s) and s <= g for g in freq)
        for q in pg.evaluate(GET, [[sorted(t) for t in db], ms]):
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = len(ch) >= 2 and len(set(ch)) == len(ch) and len(ch) <= 4
            if t == 'first':
                fi = [i for i in items if sup([i]) >= ms]
                ok &= ch[a] == min(fi, key=lambda i: (sup([i]), i))
            elif t == 'act':
                X, J = set(ask['tX']), set(ask['tj'])
                k = 'infreq' if len(X & J) < ms else 'p1' if X == J else 'p2' if X < J else 'p3' if J < X else 'p4'
                ok &= ch[a] == ask['kinds'][ACT.index(k)]
            elif t == 'closed':
                s = frozenset(ask['set'])
                ok &= (a == 0) == (closed(s) and s not in {frozenset(x) for x in ask['prev']}) and sup(s) >= ms
            elif t == 'max':
                ok &= set(a) == {k for k, s in enumerate(ask['sets']) if maximal(frozenset(s))}
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', db, ms, q)
    print(f'closed-patterns 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    b.close()
