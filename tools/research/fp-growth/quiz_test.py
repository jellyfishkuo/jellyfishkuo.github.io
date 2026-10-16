"""練習模式：用隨機資料檢查每一題的正確答案，跟 Python 自己算的一致。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）"""
import os, random, sys
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/fp-growth.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 150
GET = """([d, m]) => { minSup = m; const tr = buildTrace(d, m);
    return tr.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""
def parse_base(text):
    if text.startswith('（'): return {}
    out = {}
    for part in text.split('、'):
        path, n = part.rsplit(' ×', 1)
        out[tuple(path.split('→'))] = out.get(tuple(path.split('→')), 0) + int(n)
    return out
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(300)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        rows = random.randint(3, 10)
        db = [sorted(random.sample(ITEMS, random.randint(1, 6))) for _ in range(rows)]
        ms = random.randint(1, rows)
        for q in pg.evaluate(GET, [db, ms]):
            if q['ask'].get('only'):           # 只有一個選項的複選題變成「會／不會」：先確認，再換回複選的樣子比對
                if q['choices'] != ['會', '不會']: bad += 1
                q = {**q, 'choices': q['ask']['only'], 'answer': [0] if q['answer'] == 0 else [], 'multi': True}
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = (len(ch) >= 2 or ask.get('only')) and len(set(ch)) == len(ch)
            if t == 'freq':
                cnt = {}
                for items, n in ask['rows']:
                    for i in items: cnt[i] = cnt.get(i, 0) + n
                ok &= {ch[k] for k in a} == {i for i in cnt if cnt[i] >= ms} and set(ch) == set(cnt)
            elif t in ('newNodes', 'nodeCount'):
                paths = [tuple(x) for x in ask['paths']]; last = paths[-1]
                if t == 'newNodes':
                    seen = {pp[:j] for pp in paths[:-1] for j in range(1, len(pp) + 1)}
                    ok &= int(ch[a]) == sum(1 for j in range(1, len(last) + 1) if last[:j] not in seen)
                else:
                    ok &= int(ch[a]) == sum(1 for pp in paths if pp[:len(last)] == last)
            elif t == 'base':
                # 暴力：每筆有這個商品的（排序後）路徑，取它前面的那段，次數照權重加總
                exp = {}
                for path, n in ask['rows']:
                    if ask['item'] in path:
                        pre = tuple(path[:path.index(ask['item'])])
                        if pre: exp[pre] = exp.get(pre, 0) + n
                ok &= parse_base(ch[a]) == exp and sum(1 for c in ch if parse_base(c) == exp) == 1
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', db, ms, q)
    print(f'fp-growth 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    b.close()
