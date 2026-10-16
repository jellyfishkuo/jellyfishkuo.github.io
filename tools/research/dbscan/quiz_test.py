"""練習模式：用隨機資料檢查每一題的正確答案，跟 Python 版 DBSCAN（research/code/dbscan.py）與暴力數鄰居的結果一致。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）"""
import os, random, sys
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from dbscan import dbscan, neighbors
from playwright.sync_api import sync_playwright
U = 'http://127.0.0.1:%s/research/dbscan.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 100
GET = """([P, e, m]) => { pts = P.map(([x, y]) => ({ x, y })); eps = e; minPts = m; rebuild();
    return steps.map((s, i) => dbscanQuiz(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(300)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        n = random.randint(1, 45)
        P = list({(random.randint(2, 125), random.randint(2, 125)) for _ in range(n)}) if trial % 2 else \
            list({(random.randint(40, 80), random.randint(40, 80)) for _ in range(n)})
        e, m = random.randint(4, 30), random.randint(2, 10)
        lab = dbscan(P, e, m)
        nb = lambda i: len(neighbors(P, i, e))
        for q in pg.evaluate(GET, [P, e, m]):
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = len(ch) >= 2 and len(set(ch)) == len(ch) and len(ch) <= 4
            if t == 'nb': ok &= int(ch[a]) == nb(ask['p'])
            elif t == 'visit': ok &= ch[a] == ('核心點，開一個新的群' if nb(ask['p']) >= m else '先標成雜訊')
            elif t == 'pop': ok &= ch[a].startswith('核心點' if nb(ask['p']) >= m else '邊界點') and lab[ask['p']] > 0
            elif t == 'claim': ok &= ch[a] == '被收編成這群的邊界點' and nb(ask['p']) < m and lab[ask['p']] > 0
            elif t == 'size': ok &= int(ch[a]) == lab.count(ask['c'])
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', P, e, m, q)
    print(f'dbscan 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    b.close()
