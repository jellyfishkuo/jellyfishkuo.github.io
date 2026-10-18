"""練習模式：用隨機資料檢查每一題的正確答案，跟 Python 版（uncertain_sw.py）和暴力法一致；
再打開練習模式隨機作答從頭走到尾，檢查 .card 位置不變。
需要本機伺服器：cd <repo> && python3 -m http.server 8833（或設環境變數 PORT）"""
import os, random, sys
from itertools import combinations
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from uncertain_sw import SWUPA
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/uncertain-sw.html' % os.environ.get('PORT', '8833')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 120
GET = """([r, b, w, p]) => { db = r; bSize = b; wSize = w; pct = p; const tr = buildTrace(r, b, w, p); trace = tr;
    return tr.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""
CARDS = "[...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.left), Math.round(r.height)]; })"
close = lambda c, v: abs(float(c) - v) <= 0.0005 + 1e-9   # 頁面顯示到小數 3 位
n3 = lambda v: str(float(f'{v:.3f}')).rstrip('0').rstrip('.') if v else '0'


def exp_sup(rows, tids, s):
    e = 0.0
    for t in tids:
        if all(i in rows[t - 1] for i in s):
            p = 1.0
            for i in s: p *= rows[t - 1][i]
            e += p
    return e


def windows(rows, b, w, pct):
    """Python 版跑一次：每個視窗的 TID、合併紀錄、結果"""
    sw = SWUPA(b, w, pct)
    txs = [(k + 1, t) for k, t in enumerate(rows)]
    out = []
    for k in range(0, len(txs) - b + 1, b):
        sw.log = []
        r = sw.add_batch(txs[k:k + b])
        if r is not None:
            out.append(([tid for bt in sw.window for tid, _ in bt], {tuple(it): kd for kd, it in sw.log}, r, sw.min_sup))
    return out


with sync_playwright() as p:
    br = p.chromium.launch()
    ctx = br.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_function('() => !blocksBusy', timeout=30000)
    bad, kinds = 0, {}
    random.seed(5)
    for trial in range(TRIALS):
        n = random.randint(6, 10)
        rows = [{i: random.randint(1, 10) / 10 for i in random.sample(ITEMS, random.randint(1, 6))} for _ in range(n)]
        b = random.randint(1, 2); w = random.randint(2, 4)
        if b * (w + 1) > n: b = 1
        pct = random.choice(range(5, 65, 5))
        W = windows(rows, b, w, pct)
        for q in pg.evaluate(GET, [rows, b, w, pct]):
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = len(ch) >= 2 and len(set(ch)) == len(ch)
            if t == 'maxep': ok &= close(ch[a], max(rows[x - 1][ask['item']] for x in ask['tids'] if ask['item'] in rows[x - 1]))
            elif t == 'expsup': ok &= close(ch[a], exp_sup(rows, ask['tids'], [ask['item']]))
            else:
                tids, log, res, ms = W[ask['winNo'] - 1]
                if t == 'keep':
                    want = [k for k, it in enumerate(ask.get('only', ask['choices'])) if exp_sup(rows, tids, [it]) >= ms - 1e-9]
                    ok &= (a == (0 if want else 1)) if 'only' in ask else sorted(a) == want
                elif t == 'outcome':
                    ok &= ['over', 'ppclw', 'ok', 'low'][a] == log[tuple(ask['items'])]
                elif t == 'pexp': ok &= close(ch[a], exp_sup(rows, tids, ask['items']))
                elif t == 'over':
                    X, last = ask['items'][:-1], ask['items'][-1]
                    ok &= close(ch[a], exp_sup(rows, tids, X) * max(rows[x - 1][last] for x in tids if last in rows[x - 1]))
                elif t == 'count':
                    pres = sorted({i for x in tids for i in rows[x - 1]})
                    cnt = sum(1 for r in range(1, len(pres) + 1) for s in combinations(pres, r) if exp_sup(rows, tids, s) >= ms - 1e-9)
                    ok &= int(ch[a]) == cnt == len(res)
                else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', rows, b, w, pct, q)
    print(f'uncertain-sw 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')

    # 練習模式打開、隨機作答走到尾
    for Wd, H in ((375, 760), (1280, 900)):
        c = br.new_context(viewport={'width': Wd, 'height': H}, is_mobile=Wd < 600, has_touch=Wd < 600)
        c.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        m = c.new_page(); me = []; m.on('pageerror', lambda e: me.append(str(e)))
        m.goto(U); m.wait_for_function('() => !blocksBusy')
        base = m.evaluate(CARDS)
        m.click('#quiz-toggle'); moved = m.evaluate(CARDS) != base; asked = 0; sws = set()
        for _ in range(400):
            if not m.is_hidden('#quiz'):
                asked += 1
                moved += m.evaluate(CARDS) != base
                chs = m.locator('#quiz .quiz-choice')
                chs.nth(random.randrange(chs.count())).click()
                if m.is_visible('#quiz .quiz-ok'): m.click('#quiz .quiz-ok')
                moved += m.evaluate(CARDS) != base
                m.click('#quiz .quiz-go')
            elif m.is_disabled('#btn-next'): break
            else: m.click('#btn-next')
            moved += m.evaluate(CARDS) != base
            sws.add(m.evaluate('document.documentElement.scrollWidth'))
        score = m.inner_text('#quiz-score')
        m.click('#quiz-toggle'); moved += m.evaluate(CARDS) != base
        print(f'{Wd}px 練習模式：{asked} 題，{score}，.card 位置變動 {moved}，scrollWidth {sws}，pageerror {me}')
        c.close()
    br.close()
