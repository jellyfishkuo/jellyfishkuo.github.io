"""練習模式：用隨機資料檢查每一題的正確答案，跟 Python 自己算（暴力法）的一致。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）"""
import os, random, re, sys
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/high-utility.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 150
GET = """([d, p, m]) => { minUtil = m; const tr = buildTrace(d, p, m);
    return tr.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""
CAT = ['輸出，也往下展開', '輸出，但不再往下', '不輸出，但往下展開', '不輸出，也不往下']
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(300)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        rows = random.randint(1, 10)
        db = [{i: random.randint(1, 5) for i in random.sample(ITEMS, random.randint(1, 6))} for _ in range(rows)]
        profit = {i: random.randint(1, 40) for i in ITEMS}
        total = sum(t[i] * profit[i] for t in db for i in t)
        mu = random.randint(1, max(1, total // 2))
        tu = [sum(t[i] * profit[i] for i in t) for t in db]
        twu = {}
        for k, t in enumerate(db):
            for i in t: twu[i] = twu.get(i, 0) + tu[k]
        order = sorted([i for i in twu if twu[i] >= mu], key=lambda i: (twu[i], i))
        rank = {i: k for k, i in enumerate(order)}
        has = lambda t, s: all(i in t for i in s)
        util = lambda s: sum(sum(t[i] * profit[i] for i in s) for t in db if has(t, s))
        for q in pg.evaluate(GET, [db, profit, mu]):
            if q['ask'].get('only'):           # 只有一個選項的複選題變成「會／不會」：先確認，再換回複選的樣子比對
                if q['choices'] != ['會', '不會']: bad += 1
                q = {**q, 'choices': q['ask']['only'], 'answer': [0] if q['answer'] == 0 else [], 'multi': True}
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = (len(ch) >= 2 or ask.get('only')) and len(set(ch)) == len(ch)
            if t == 'cut':
                ok &= {ch[k] for k in a} == {i for i in twu if twu[i] < mu}
            elif t == 'rutil':
                tr = db[ask['tid']]
                ok &= int(ch[a]) == sum(tr[j] * profit[j] for j in order if j in tr and rank[j] > rank[ask['item']])
            elif t == 'check':
                x = ask['items']; last = rank[x[-1]]; P = x[:-1]
                rows_x = [tr for tr in db if has(tr, x)]
                iu = sum(sum(tr[i] * profit[i] for i in x) for tr in rows_x)
                ru = sum(sum(tr[j] * profit[j] for j in order if j in tr and rank[j] > last) for tr in rows_x)
                later = [y for y in order if rank[y] > last and any(has(tr, P + [y]) for tr in db)]
                expand = iu + ru >= mu and bool(later)
                ok &= ch[a] == CAT[(0 if iu >= mu else 2) + (0 if expand else 1)]
                m = re.search(r'Σiutil (\d+)、Σrutil (\d+)', q['q'])
                ok &= bool(m) and (int(m.group(1)), int(m.group(2))) == (iu, ru)
            elif t == 'util':
                ok &= int(ch[a]) == util(ask['items'])
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', db, profit, mu, q)
    print(f'high-utility 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    b.close()
