"""練習模式：用隨機資料檢查每一題的正確答案，跟 Python 自己算的一致。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）"""
import os, random, sys
from itertools import combinations
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/association-rules.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 150
GET = """([d, m, c]) => { db = d.map(t => new Set(t)); minSup = m; minConfPct = c; trace = buildTrace(); cursor = 0;
    return trace.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_function('() => !blocksBusy', timeout=20000)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        n = random.randint(3, 12)
        db = [set(random.sample(ITEMS, random.randint(1, 6))) for _ in range(n)]
        ms, mc = random.randint(1, max(1, n // 2)), random.choice(range(10, 101, 10))
        sup = lambda s: sum(1 for t in db if set(s) <= t)
        conf = lambda z, y: sup(z) / sup([i for i in z if i not in y])
        for q in pg.evaluate(GET, [[sorted(t) for t in db], ms, mc]):
            if q['ask'].get('only'):
                if q['choices'] != ['會', '不會']: bad += 1
                q = {**q, 'choices': q['ask']['only'], 'answer': [0] if q['answer'] == 0 else [], 'multi': True}
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = bool(len(ch) >= 2 or ask.get('only')) and len(set(ch)) == len(ch) and len(ch) <= 4
            if t == 'cut': ok &= int(ch[a]) == 2 ** ask['k'] - 2
            elif t == 'conf': ok &= abs(float(ch[a][:-1]) / 100 - sup(ask['z']) / sup(ask['x'])) < 6e-4
            elif t == 'lift':
                x, y = ask['x'], ask['y']; d = sup(x + y) * n - sup(x) * sup(y)
                ok &= a == (0 if d > 0 else 1 if d == 0 else 2)
            elif t == 'grow':
                z = ask['z']
                want = {k for k, y in enumerate(ask['sets']) if all(conf(z, s) >= mc / 100 for r in range(1, len(y)) for s in combinations(y, r))}
                ok &= set(a) == want
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', db, ms, mc, q)
    print(f'association-rules 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    b.close()
