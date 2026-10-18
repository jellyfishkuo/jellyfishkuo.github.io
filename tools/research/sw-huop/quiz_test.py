"""練習模式：用隨機資料檢查每一題的正確答案，跟 Python 自己算（暴力法）的一致；再打開練習模式隨機作答走到底。
需要本機伺服器：cd <repo> && python3 -m http.server 8832（或設環境變數 PORT）"""
import os, re, sys, math, random
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))
sys.dont_write_bytecode = True

import itertools
from fractions import Fraction as F
from playwright.sync_api import sync_playwright
U = 'http://127.0.0.1:%s/research/sw-huop.html' % os.environ.get('PORT', '8832')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 150
CAT = ['輸出，也往下展開', '輸出，但不再往下', '不輸出，但往下展開', '不輸出，也不往下']
# 隨機資料與暴力法：跟 test.py 同一份
SHOP = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
LET = list('ABCDEFGH')


def brute(profit, txs, B, W, a, b):
    """只看視窗裡的交易，列舉所有組合，用分數精確算支持度和平均佔有率"""
    out = {}
    items = sorted({i for t in txs for i in t})
    tus = [sum(q * profit[i] for i, q in t.items()) for t in txs]
    for n in range(1, len(items) + 1):
        for s in itertools.combinations(items, n):
            occ = [k for k, t in enumerate(txs) if all(i in t for i in s)]
            if not occ or len(occ) * 100 < B * W * a:
                continue
            uo = sum(F(sum(txs[k][i] * profit[i] for i in s), tus[k]) for k in occ) / len(occ)
            if uo >= F(b, 100):
                out[frozenset(s)] = (len(occ), uo)
    return out


def rand_cfg(rng):
    items = rng.choice([SHOP, LET])[:rng.randint(3, 6 if rng.random() < 0.7 else 8)]
    n = rng.randint(4, 14)
    db = [{i: rng.randint(1, 5) for i in rng.sample(items, rng.randint(1, len(items)))} for _ in range(n)]
    W = rng.randint(2, 4)
    B = rng.randint(1, max(1, min(3, n // W)))
    if n // B < W: W = n // B if n // B >= 2 else 2
    if n // B < W: B = 1
    return dict(items=items, profit={i: rng.randint(1, 40) for i in items}, db=db, B=B, W=W,
                a=rng.randrange(10, 101, 5), b=rng.randrange(5, 101, 5))


GET = """c => { setCfg(c); const tr = buildTrace(cfg);
    return tr.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""


def check(c, q):
    B, profit, db = c['B'], c['profit'], c['db']
    ask = q['ask']; a, ch = q['answer'], q['choices']
    win = ask.get('win')
    txs = [db[k] for b in (win or []) for k in range(b * B, (b + 1) * B)]
    tu = lambda t: sum(v * profit[i] for i, v in t.items())
    uo = lambda t, s: sum(t[i] * profit[i] for i in s) / tu(t)
    occ = lambda s: [t for t in txs if all(i in t for i in s)]
    sup = {i: len(occ([i])) for i in {i for t in txs for i in t}}
    order = sorted(sup, key=lambda i: (sup[i], i))
    rank = {i: k for k, i in enumerate(order)}
    min_sup = c['B'] * c['W'] * c['a'] / 100
    near = lambda v: abs(float(ch[a]) - v) <= 0.0051
    t = ask['type']
    if t == 'uo': return near(uo(db[ask['tid']], [ask['item']]))
    if t == 'remain': return int(ch[a]) == sup.get(ask['item'], 0)
    if t == 'low': return {ch[k] for k in a} == {i for i in sup if sup[i] < min_sup}
    if t == 'first': return ch[a] == order[0]
    if t == 'ruo':
        tx = db[ask['tid']]
        return near(sum(uo(tx, [j]) for j in tx if rank[j] > rank[ask['item']]))
    if t == 'cuo': return near(uo(db[ask['tid']], ask['items']))
    if t == 'count': return int(ch[a]) == len(brute(profit, txs, B, c['W'], c['a'], c['b']))
    if t == 'check':
        x = ask['items']; P = x[:-1]; s = len(occ(x)); beta = c['b'] / 100; cms = math.ceil(min_sup)
        later = [y for y in order if rank[y] > rank[x[-1]] and occ(P + [y])]
        m = re.search(r'sup (\d+)', q['q'])
        if not m or int(m.group(1)) != s: return False
        if s < min_sup: return ch[a] == CAT[3]
        ts = occ(x)
        avg = sum(uo(tt, x) for tt in ts) / s
        vals = sorted((uo(tt, x) + sum(uo(tt, [j]) for j in tt if rank[j] > rank[x[-1]]) for tt in ts), reverse=True)
        go = sum(vals) / cms >= beta - 1e-9 and sum(vals[:cms]) / cms >= beta - 1e-9
        return ch[a] == CAT[(0 if avg >= beta - 1e-9 else 2) + (0 if go and later else 1)]
    return False


with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(300)
    rng = random.Random(5)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        c = rand_cfg(rng)
        for q in pg.evaluate(GET, c):
            if q['ask'].get('only'):           # 只有一個選項的複選題變成「會／不會」：先確認，再換回複選的樣子比對
                if q['choices'] != ['會', '不會']: bad += 1
                q = {**q, 'choices': q['ask']['only'], 'answer': [0] if q['answer'] == 0 else [], 'multi': True}
            kinds[q['ask']['type']] = kinds.get(q['ask']['type'], 0) + 1
            ok = (len(q['choices']) >= 2 or q['ask'].get('only')) and len(set(q['choices'])) == len(q['choices']) and len(q['choices']) <= 4 + 2 * q['multi']
            if not (ok and check(c, q)):
                bad += 1
                if bad < 5: print('MISMATCH', c, q)
    print(f'sw-huop 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')

    # 練習模式打開、隨機作答從頭走到尾
    for w, h in ((375, 760), (1280, 900)):
        c2 = b.new_context(viewport={'width': w, 'height': h}, is_mobile=w < 600, has_touch=w < 600)
        c2.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        q = c2.new_page(); e2 = []; q.on('pageerror', lambda e: e2.append(str(e)))
        q.goto(U); q.wait_for_timeout(3000)
        pos = lambda: q.evaluate("[...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.height)]; })")
        base = pos(); moved = 0; asked = 0; sws = set()
        q.click('#quiz-toggle')
        if pos() != base: moved += 1
        for _ in range(2000):
            if not q.is_hidden('#quiz'):
                asked += 1
                if pos() != base: moved += 1
                chs = q.locator('#quiz .quiz-choice')
                chs.nth(random.randrange(chs.count())).click()
                if q.is_visible('#quiz .quiz-ok'): q.click('#quiz .quiz-ok')
                if pos() != base: moved += 1
                q.click('#quiz .quiz-go')
            elif q.is_disabled('#btn-next'): break
            else: q.click('#btn-next')
            if pos() != base: moved += 1
            sws.add(q.evaluate('document.documentElement.scrollWidth'))
        print(f'  {w}px 練習模式：作答 {asked} 題，{q.inner_text("#quiz-score")}，.card 位置變動 {moved}，scrollWidth {sws}，pageerror {e2}')
        c2.close()
    b.close()
