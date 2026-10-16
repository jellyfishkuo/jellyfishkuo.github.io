"""練習模式：用隨機串流檢查每一題的正確答案，跟 Python 暴力法（直接數視窗裡的交易）一致。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）"""
import os, random, sys
from itertools import combinations
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/sliding-window.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 100
GET = """([txs, W, ms]) => { stream = txs.map(items => ({ items, when: '', mine: false })); winSize = W; minSup = ms;
    const tr = buildTrace(txs, W, ms);
    return tr.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""
subs = lambda t: [frozenset(c) for r in range(1, len(t) + 1) for c in combinations(t, r)]
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_function('() => !blocksBusy', timeout=60000)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        txs = [random.sample(ITEMS, random.randint(1, 5)) for _ in range(random.randint(2, 16))]
        W = random.randint(3, 8); ms = random.randint(1, W)
        win = lambda a: [set(t) for t in txs[max(0, a - W):a]]          # 第 a 筆進來（含離開）之後的視窗
        sup = lambda S, a: sum(1 for t in win(a) if S <= t)
        for q in pg.evaluate(GET, [txs, W, ms]):
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = len(ch) >= 2 and len(set(ch)) == len(ch)
            A = ask['arrival']
            if t == 'count':   # 加進來時舊的還沒離開：視窗是最近 W+1 筆
                ok &= int(ch[a]) == sum(1 for x in txs[max(0, A - W - 1):A] if set(ask['set']) <= set(x))
            elif t == 'ops': ok &= int(ch[a]) == 2 ** len(ask['set']) - 1
            elif t == 'expire': ok &= int(ch[a]) == sum(1 for S in subs(txs[ask['idx']]) if sup(S, A) == 0)
            elif t == 'freq': ok &= int(ch[a]) == len({S for x in win(A) for S in subs(x) if sup(S, A) >= ms})
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', txs, W, ms, q)
    print(f'sliding-window 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    b.close()
