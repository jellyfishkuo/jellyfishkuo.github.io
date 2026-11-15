"""練習模式：用隨機資料檢查每一題的正確答案，跟 Python 自己算（暴力法）的一致；再打開練習模式隨機作答走到底。
需要本機伺服器：cd <repo> && python3 -m http.server 8775（或設環境變數 PORT）"""
import os, re, sys, math, random, itertools
from fractions import Fraction as F
sys.dont_write_bytecode = True
from playwright.sync_api import sync_playwright
U = 'http://127.0.0.1:%s/research/iuoil.html' % os.environ.get('PORT', '8775')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 150
CAT = ['輸出，也往下展開', '輸出，但不再往下', '不輸出，但往下展開', '不輸出，也不往下']
SHOP = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
LET = list('abcdefgh')


def rand_cfg(rng):   # 跟 test.py 同一份
    items = rng.choice([SHOP, LET])[:rng.randint(3, 6 if rng.random() < 0.7 else 8)]
    batches = [[{i: rng.randint(1, 5) for i in rng.sample(items, rng.randint(1, len(items)))}
                for _ in range(rng.randint(1, 6 if k == 0 else 3))] for k in range(rng.randint(1, 4))]
    return dict(items=items, emoji={}, profit={i: rng.randint(1, 40) for i in items}, batches=batches,
                a=rng.randrange(5, 101, 5), b=rng.randrange(5, 101, 5))


def orders(batches):
    """每一批讀完、重建後的總順序：還沒重建前照字典順序，新商品排最後；重建時照支持度由小到大、一樣多照原本的先後"""
    out, order, seen, rebuilt = {}, [], [], False
    for bt in batches:
        for t in bt:
            new = sorted(i for i in t if i not in order)
            order = order + new if rebuilt else sorted(order + new)
            seen.append(t)
        sup = {i: sum(i in t for t in seen) for i in order}
        order = sorted(order, key=lambda i: (sup[i], order.index(i)))
        rebuilt = True
        out[len(seen)] = order
    return out


def check(c, q):
    profit, a_pct = c['profit'], c['a']
    db = [t for bt in c['batches'] for t in bt]
    ask = q['ask']; a, ch = q['answer'], q['choices']
    n = ask.get('n', 0)
    txs = db[:n]
    tu = lambda t: sum(v * profit[i] for i, v in t.items())
    uo = lambda t, s: sum(t[i] * profit[i] for i in s) / tu(t)
    occ = lambda s: [t for t in txs if all(i in t for i in s)]
    order = orders(c['batches']).get(n, [])
    rank = {i: k for k, i in enumerate(order)}
    near = lambda v: abs(float(ch[a]) - v) <= 0.0051
    low = lambda s: s * 100 < n * a_pct
    t = ask['type']
    if t == 'uo': return near(uo(db[ask['tid']], [ask['item']]))
    if t == 'nidx': return int(ch[a]) == sum(ask['item'] in x for x in db[:ask['tid'] + 1])
    if t == 'low': return {ch[k] for k in a} == {i for i in order if low(len(occ([i])))}
    if t == 'first': return ch[a] == order[0]
    tx = db[ask['tid']] if 'tid' in ask else None
    if t == 'nid':
        after = [j for j in sorted(tx, key=rank.get) if rank[j] > rank[ask['item']]]
        return ch[a] == after[0]
    if t == 'ruo': return near(sum(uo(tx, [j]) for j in tx if rank[j] > rank[ask['item']]))
    if t == 'cuo': return near(uo(tx, ask['items']))
    if t == 'nlists':
        x = ask['items']
        return int(ch[a]) == sum(1 for y in order if rank[y] > rank[x[-1]] and occ(x + [y]))
    if t == 'count':
        cnt = 0
        for k in range(1, len(order) + 1):
            for s in itertools.combinations(order, k):
                ts = occ(s)
                if ts and not low(len(ts)) and sum(F(sum(tt[i] * profit[i] for i in s), tu(tt)) for tt in ts) / len(ts) >= F(c['b'], 100):
                    cnt += 1
        return int(ch[a]) == cnt
    if t == 'check':
        x = ask['items']; beta = c['b'] / 100; cms = -(-n * a_pct // 100)
        ts = occ(x); s = len(ts)
        m = re.search(r'sup (\d+)', q['q'])
        if not m or int(m.group(1)) != s: return False
        later = [y for y in order if rank[y] > rank[x[-1]] and occ(x[:-1] + [y])]
        if low(s): return ch[a] == CAT[3]
        avg = sum(uo(tt, x) for tt in ts) / s
        vals = sorted((uo(tt, x) + sum(uo(tt, [j]) for j in tt if rank[j] > rank[x[-1]]) for tt in ts), reverse=True)
        go = sum(vals) / cms >= beta - 1e-9 and sum(vals[:cms]) / cms >= beta - 1e-9
        return ch[a] == CAT[(0 if avg >= beta - 1e-9 else 2) + (0 if go and later else 1)]
    return False


GET = """c => { setCfg(c); const tr = buildTrace(cfg);
    return tr.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""

with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_function("!document.documentElement.hasAttribute('aria-busy')"); pg.wait_for_timeout(300)
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
    print(f'iuoil 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')

    # 練習模式打開、隨機作答從頭走到尾
    for w, h, ds in ((375, 760, 'shop'), (1280, 900, 'shop'), (375, 760, 'paper')):
        c2 = b.new_context(viewport={'width': w, 'height': h}, is_mobile=w < 600, has_touch=w < 600)
        c2.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        q = c2.new_page(); e2 = []; q.on('pageerror', lambda e: e2.append(str(e)))
        q.goto(U)
        q.wait_for_function("!document.documentElement.hasAttribute('aria-busy')")
        if ds != 'shop':
            q.click(f'#ds button[data-ds={ds}]')
            q.wait_for_function("!document.documentElement.hasAttribute('aria-busy')")
        q.wait_for_timeout(300)
        pos = lambda: q.evaluate("[...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.height)]; })")
        base = pos(); moved = 0; asked = 0; sws = set()
        q.click('#quiz-toggle')
        if pos() != base: moved += 1
        for _ in range(3000):
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
        score = q.inner_text('#quiz-score')
        q.click('#quiz-toggle')
        if pos() != base: moved += 1
        print(f'  {w}px {ds} 練習模式：作答 {asked} 題，{score}，.card 位置變動 {moved}，scrollWidth {sws}，pageerror {e2}')
        c2.close()
    b.close()
