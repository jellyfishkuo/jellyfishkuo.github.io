"""練習模式：用隨機串流檢查兩個分頁每一題的正確答案，跟 Python 版（lossy_counting.py、space_saving.py）算的一致。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）"""
import os, random, sys
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from lossy_counting import LossyCounting
from space_saving import SpaceSaving, TOL
from playwright.sync_api import sync_playwright
U = 'http://127.0.0.1:%s/research/stream-counting.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 100
GET = """([st, ei, li, k, si]) => { stream = st; epsIdx = ei; lcSIdx = li; ssK = k; ssSIdx = si;
    const out = [];
    [['lc', lossyTrace(st, eps(), lcS())], ['ss', ssTrace(st, k, ssS())]].forEach(([g, tr]) => tr.forEach((s, i) => { const q = quizFor(g, s, i); if (q) out.push(q); }));
    return out.map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_function('() => !blocksBusy', timeout=60000)
    ITEMS, EPS, S = pg.evaluate('[ITEMS, EPS_OPTS, S_OPTS]')
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        st = [random.choice(ITEMS[:random.randint(2, len(ITEMS))]) for _ in range(random.randint(5, 80))]
        ei = random.randrange(len(EPS)); li = random.choice([j for j in range(len(S)) if S[j] > EPS[ei] + TOL] or [len(S) - 1])
        k = random.randint(1, 6); si = random.randrange(len(S))
        def lc(n):
            x = LossyCounting(EPS[ei])
            for it in st[:n]: x.add(it)
            return x
        def ss(n):
            x = SpaceSaving(k)
            for it in st[:n]: x.add(it)
            return x
        for q in pg.evaluate(GET, [st, ei, li, k, si]):
            if q['ask'].get('only'):
                if q['choices'] != ['會', '不會']: bad += 1
                q = {**q, 'choices': q['ask']['only'], 'answer': [0] if q['answer'] == 0 else [], 'multi': True}
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = (len(ch) >= 2 or bool(ask.get('only'))) and len(set(ch)) == len(ch)
            if t == 'delta':   # 新商品的 Δ = 這一桶的編號 − 1（同一筆剛好桶結束時可能馬上被刪，所以直接用桶寬算）
                x = lc(ask['n'] - 1); ok &= int(ch[a]) == -(-ask['n'] // x.w) - 1 and ask['item'] not in x.table
            elif t == 'prune':
                before, after = lc(ask['n'] - 1), lc(ask['n'])
                gone = {x for x in ask['items'] if x not in after.table}
                ok &= {ask['items'][j] for j in a} == gone and all(x in before.table or x == st[ask['n'] - 1] for x in ask['items'])
            elif t == 'lcReport': ok &= int(ch[a]) == len(lc(len(st)).query(S[li]))
            elif t == 'victim':
                before = ss(ask['n'] - 1).slots; c = min(x[1] for x in before)
                v = next(j for j, x in enumerate(before) if x[1] == c)
                ok &= ch[a] == f'第 {v + 1} 格 {before[v][0]}（{c}）'
            elif t == 'ssCount': ok &= int(ch[a]) == ss(ask['n']).slots[ask['slot']][1]
            elif t == 'ssReport': ok &= int(ch[a]) == len(ss(len(st)).query(S[si]))
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', st, ei, li, k, si, q)
    print(f'stream-counting 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    b.close()
