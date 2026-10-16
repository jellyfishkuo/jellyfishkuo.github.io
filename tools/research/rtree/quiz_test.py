"""練習模式：用隨機資料檢查每一題的正確答案，跟 Python 自己算（面積、浪費面積、距離暴力排序）的結果一致。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）"""
import os, random, sys
from playwright.sync_api import sync_playwright
KINDS = ['超商', '公車站', '咖啡店', '飲料店']
U = 'http://127.0.0.1:%s/research/rtree.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 100
GET = """([P, m, q, k]) => { pts = P.map(([x, y, kind]) => ({ x, y, kind })); capM = m; qPoint = { x: q[0], y: q[1] }; kNum = k; rebuildRt(); rebuildKn();
    const pick = q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask });
    return rtBuild.steps.map((s, i) => rtQuiz(s, i)).concat(knSteps.map((s, i) => knQuiz(s, i))).filter(Boolean).map(pick); }"""
area = lambda r: (r[2] - r[0]) * (r[3] - r[1])
union = lambda a, b: [min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3])]
def mind(q, r):
    dx = max(r[0] - q[0], 0, q[0] - r[2]); dy = max(r[1] - q[1], 0, q[1] - r[3])
    return dx * dx + dy * dy
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(300)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        n = random.randint(1, 60)
        P = [(x, y, random.choice(KINDS)) for x, y in {(random.randint(0, 127), random.randint(0, 127)) for _ in range(n)}]
        m, q, k = random.randint(3, 6), (random.randint(0, 127), random.randint(0, 127)), random.randint(1, 8)
        d2 = lambda j: (P[j][0] - q[0]) ** 2 + (P[j][1] - q[1]) ** 2
        near = sorted(range(len(P)), key=lambda j: (d2(j), j))
        for x in pg.evaluate(GET, [P, m, q, k]):
            if x['ask'].get('only'):
                if x['choices'] != ['會', '不會']: bad += 1
                x = {**x, 'choices': x['ask']['only'], 'answer': [0] if x['answer'] == 0 else [], 'multi': True}
            a, ch, ask = x['answer'], x['choices'], x['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = bool((len(ch) >= 2 or ask.get('only')) and len(set(ch)) == len(ch) and len(ch) <= 4)
            if t == 'choose':     # 擴大面積最少、一樣再看面積，再一樣取前面的
                pt = ask['p'] + ask['p']
                best = min(ask['rects'], key=lambda r: (area(union(r[1], pt)) - area(r[1]), area(r[1])))
                ok &= ch[a] == f"R{best[0]}"
            elif t == 'seeds':    # 浪費面積最大的一對（一樣大取最先找到的）
                R, best = ask['rects'], None
                for i in range(len(R)):
                    for j in range(i + 1, len(R)):
                        w = area(union(R[i], R[j])) - area(R[i]) - area(R[j])
                        if best is None or w > best[0]: best = (w, i, j)
                ok &= ch[a] == f"{ask['names'][best[1]]} 和 {ask['names'][best[2]]}"
            elif t == 'prune':    # 算過距離的點裡第 k 近的距離當門檻
                ds = sorted(d2(j) for j in ask['checked'])
                dk = ds[k - 1] if len(ds) >= k else float('inf')
                cut = [i for i, (tt, r) in enumerate(ask['kids']) if mind(q, r) > dk]
                ok &= (int(ch[a]) == len(cut)) if not x['multi'] else set(a) == set(cut)
            elif t == 'pop':
                j = near[ask['rank'] - 1]; ok &= ch[a] == f"{P[j][2]}({P[j][0]},{P[j][1]})"
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', P, m, q, k, x)
    print(f'rtree 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    b.close()
