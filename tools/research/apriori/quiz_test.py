"""練習模式：用隨機資料檢查每一題的正確答案，跟 Python 自己算的一致。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）"""
import os, random, sys
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from apriori import join, has_infrequent_subset
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/apriori.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 150
GET = """([d, m]) => { db = d.map(t => new Set(t)); minSup = m; const tr = buildTrace();
    return tr.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(300)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        rows = random.randint(3, 12)
        db = [set(random.sample(ITEMS, random.randint(1, 6))) for _ in range(rows)]
        ms = random.randint(1, rows)
        sup = lambda s: sum(1 for t in db if set(s) <= t)
        for q in pg.evaluate(GET, [[sorted(t) for t in db], ms]):
            if q['ask'].get('only'):           # 只有一個選項的複選題變成「會／不會」：先確認，再換回複選的樣子比對
                if q['choices'] != ['會', '不會']: bad += 1
                q = {**q, 'choices': q['ask']['only'], 'answer': [0] if q['answer'] == 0 else [], 'multi': True}
            a, ch, ask = q['answer'], q['choices'], q['ask']
            kinds[ask['type']] = kinds.get(ask['type'], 0) + 1
            ok = (len(ch) >= 2 or ask.get('only')) and len(set(ch)) == len(ch)
            t = ask['type']
            if t == 'support': ok &= int(ch[a]) == sup(ask['set'])
            elif t == 'join': ok &= int(ch[a]) == len(join([tuple(x) for x in ask['L']], ask['k']))
            elif t == 'prune': ok &= (a == 0) == has_infrequent_subset(tuple(ask['set']), [tuple(x) for x in ask['L']])
            elif t == 'filter': ok &= set(a) == {k for k, s in enumerate(ask['sets']) if sup(s) >= ms}
            elif t == 'filterCount': ok &= int(ch[a]) == sum(1 for s in ask['sets'] if sup(s) >= ms)
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', db, ms, q)
    print(f'apriori 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    b.close()
