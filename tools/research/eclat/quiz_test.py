"""練習模式：用隨機資料檢查每一題的正確答案，跟 Python 自己算的一致。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）"""
import os, random, sys
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/eclat.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 150
GET = """([d, m]) => buildTrace(d.map(t => new Set(t)), m).map((s, i) => quizFor(s, i)).filter(Boolean)
    .map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask }))"""
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_function('() => !blocksBusy', timeout=20000)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        rows = random.randint(3, 12)
        db = [set(random.sample(ITEMS, random.randint(1, 6))) for _ in range(rows)]
        ms = random.randint(1, rows)
        tids = lambda s: [r + 1 for r, t in enumerate(db) if set(s) <= t]
        for q in pg.evaluate(GET, [[sorted(t) for t in db], ms]):
            if q['ask'].get('only'):
                if q['choices'] != ['會', '不會']: bad += 1
                q = {**q, 'choices': q['ask']['only'], 'answer': [0] if q['answer'] == 0 else [], 'multi': True}
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = bool(len(ch) >= 2 or ask.get('only')) and len(set(ch)) == len(ch) and len(ch) <= 4
            if t == 'support': ok &= int(ch[a]) == len(tids(ask['set']))
            elif t == 'tids': ok &= ch[a] == (' '.join('T%d' % x for x in tids(ask['set'])) or '（沒有）')
            elif t == 'filter': ok &= set(a) == {k for k, s in enumerate(ask['sets']) if len(tids(s)) >= ms}
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', db, ms, q)
    print(f'eclat 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    b.close()
