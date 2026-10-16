"""練習模式：用隨機資料檢查每一題的正確答案，跟 Python 暴力法（直接看每家店的商品、算距離排序）的結果一致。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）"""
import os, random, sys
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/ir-tree.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 100
GET = """([S, q, w, k, m]) => { shops = S.map(([x, y, it]) => ({ x, y, items: new Set(it) })); qPoint = { x: q[0], y: q[1] }; qWords = new Set(w); kNum = k; capM = m; rebuild();
    return steps.map((s, i) => irQuiz(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(300)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        n = random.randint(1, 40)
        S = [(random.randint(0, 127), random.randint(0, 127), random.sample(ITEMS, random.randint(1, 4))) for _ in range(n)]
        q = (random.randint(0, 127), random.randint(0, 127))
        W = set(random.sample(ITEMS, random.randint(1, 2)))
        k, m = random.randint(1, 6), random.randint(3, 6)
        good = sorted((j for j in range(n) if W <= set(S[j][2])), key=lambda j: ((S[j][0] - q[0]) ** 2 + (S[j][1] - q[1]) ** 2, j))
        name = lambda j: f'#{j + 1}({S[j][0]},{S[j][1]})'
        for x in pg.evaluate(GET, [S, q, sorted(W), k, m]):
            if x['ask'].get('only'):
                if x['choices'] != ['會', '不會']: bad += 1
                x = {**x, 'choices': x['ask']['only'], 'answer': [0] if x['answer'] == 0 else [], 'multi': True}
            a, ch, ask = x['answer'], x['choices'], x['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = bool((len(ch) >= 2 or ask.get('only')) and len(set(ch)) == len(ch) and len(ch) <= 4)
            if t == 'skip':   # 子節點底下所有店的商品合起來，缺任何一樣就跳過
                skip = [k2 for k2, under in enumerate(ask['entries']) if not W <= set().union(*(set(S[j][2]) for j in under))]
                ok &= (int(ch[a]) == len(skip)) if not x['multi'] else set(a) == set(skip)
            elif t == 'pop': ok &= ch[a] == name(good[ask['rank'] - 1])
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', S, q, W, k, m, x)
    print(f'ir-tree 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    b.close()
