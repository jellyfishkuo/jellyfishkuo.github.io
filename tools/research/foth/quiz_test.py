"""練習模式：用隨機資料檢查每一題的正確答案（Python 自己算），再打開練習模式隨機作答從頭走到尾。
需要本機伺服器：cd <repo> && python3 -m http.server 8831（或設環境變數 PORT）"""
import os, random, sys
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/foth.html' % os.environ.get('PORT', '8831')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 150
GET = """([d, p, m]) => { minUtil = m; const tr = buildTrace(d, p, m); DB = d; PROFIT = p;
    const out = tr.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask }));
    useDataset('shop'); return out; }"""
POS = "[...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.height)]; })"
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(300)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        db = [{i: random.randint(1, 5) for i in random.sample(ITEMS, random.randint(1, 6))} for _ in range(random.randint(1, 10))]
        profit = {i: random.randint(1, 40) for i in ITEMS}
        total = sum(t[i] * profit[i] for t in db for i in t)
        mu = random.randint(1, max(1, total // 2))
        tu = [sum(t[i] * profit[i] for i in t) for t in db]
        twu = {}
        for k, t in enumerate(db):
            for i in t: twu[i] = twu.get(i, 0) + tu[k]
        order = sorted([i for i in twu if twu[i] >= mu], key=lambda i: (twu[i], i))
        n = len(order); pos = {it: n - 1 - k for k, it in enumerate(order)}
        rev = [{i: q for i, q in t.items() if i in pos} for t in db]          # 刪掉 TWU 不夠的商品之後
        for q in pg.evaluate(GET, [db, profit, mu]):
            if q['ask'].get('only'):
                if q['choices'] != ['會', '不會']: bad += 1
                q = {**q, 'choices': q['ask']['only'], 'answer': [0] if q['answer'] == 0 else [], 'multi': True}
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = (len(ch) >= 2 or ask.get('only')) and len(set(ch)) == len(ch) and (len(ch) <= 4 or t == 'cut')
            if t == 'cut':
                ok &= {ch[k] for k in a} == {i for i in twu if twu[i] < mu}
            elif t == 'code':
                code = sum(1 << pos[i] for i in rev[ask['tid']])
                ok &= ch[a] == format(code, '0%db' % n)
            elif t == 'vs':
                L = ask['L']; j = min(pos[i] for i in L)
                want = sum(sum(tr[i] * profit[i] for i in L) + sum(tr[i] * profit[i] for i in tr if pos[i] < j) for tr in rev if all(i in tr for i in L))
                ok &= int(ch[a]) == want
            elif t == 'subs':
                X = ask['items']; cnt = 0
                for tr in rev:
                    if not all(i in tr for i in X): continue
                    rest = [pos[i] for i in tr if i not in X]
                    f = min(rest) if rest else n                    # fixedPos = 最後拿掉的（最低的）那一位
                    cnt += sum(1 for i in X if pos[i] < f) if len(X) > 1 else 0
                ok &= int(ch[a]) == cnt
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', db, profit, mu, q)
    print(f'foth 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}')
    for w, h in ((375, 760), (1280, 900)):
        c2 = b.new_context(viewport={'width': w, 'height': h}); c2.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        p2 = c2.new_page(); p2.on('pageerror', lambda e: errs.append(str(e)))
        p2.goto(U); p2.wait_for_timeout(3000)
        pos0 = p2.evaluate(POS); moved = asked = 0
        p2.click('#quiz-toggle'); moved += p2.evaluate(POS) != pos0
        while not p2.is_disabled('#btn-next'):
            p2.click('#btn-next'); p2.wait_for_timeout(20)
            if p2.is_visible('#quiz'):
                asked += 1; moved += p2.evaluate(POS) != pos0
                cs = p2.query_selector_all('#quiz .quiz-choice'); random.choice(cs).click()
                if p2.is_visible('#quiz .quiz-ok'): p2.click('#quiz .quiz-ok')
                moved += p2.evaluate(POS) != pos0
                if w == 375 and asked == 2: p2.screenshot(path=os.environ.get('SHOT', '/tmp') + '/quiz_375.png')
                p2.click('#quiz .quiz-go'); p2.wait_for_timeout(20)
            moved += p2.evaluate(POS) != pos0
        score = p2.inner_text('#quiz-score')
        p2.click('#quiz-toggle'); moved += p2.evaluate(POS) != pos0
        print(f'{w}px 練習模式：出題 {asked}，{score}，.card 位置變動 {moved} 次，scrollWidth {p2.evaluate("document.documentElement.scrollWidth")}')
        c2.close()
    print('pageerror', errs)
    b.close()
