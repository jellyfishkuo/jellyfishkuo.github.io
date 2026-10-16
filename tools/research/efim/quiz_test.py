"""EFIM 練習模式：用隨機資料檢查每一題的正確答案（Python 直接從原始交易算），再到 375 / 1280 開練習模式隨機作答走到尾。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）；截圖路徑可當第二個參數"""
import os, random, sys
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/efim.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 100
SHOT = sys.argv[2] if len(sys.argv) > 2 else None
GET = """([d, p, m]) => { minUtil = m; const tr = buildTrace(d, p, m);
    const out = tr.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); minUtil = 250; return out; }"""


POS = "() => [...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.left), Math.round(r.top + scrollY), Math.round(r.height)]; })"


def walk(b, url, width, shot=None):
    """練習模式打開，從頭隨機作答到尾：每個 .card 位置不變、沒有 pageerror、沒有橫向捲動"""
    ctx = b.new_context(viewport={'width': width, 'height': 900}); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(url); pg.wait_for_timeout(1500)
    base = pg.evaluate(POS); moved = asked = 0
    pg.click('#quiz-toggle'); moved += pg.evaluate(POS) != base
    rnd = random.Random(width)
    for _ in range(600):
        if pg.is_disabled('#btn-next'): break
        pg.click('#btn-next')
        if pg.is_visible('#quiz'):
            asked += 1
            moved += pg.evaluate(POS) != base
            if shot and asked == 3: pg.screenshot(path=shot)
            ch = pg.query_selector_all('#quiz .quiz-choice')
            if rnd.random() < 0.1: pg.click('#quiz .quiz-go'); continue
            for c in rnd.sample(ch, rnd.randint(1, len(ch))) if pg.is_visible('#quiz .quiz-ok') else [rnd.choice(ch)]: c.click()
            if pg.is_visible('#quiz .quiz-ok'): pg.click('#quiz .quiz-ok')
            moved += pg.evaluate(POS) != base
            pg.click('#quiz .quiz-go')
        moved += pg.evaluate(POS) != base
    score = pg.inner_text('#quiz-score')
    pg.click('#quiz-toggle'); moved += pg.evaluate(POS) != base
    sw = pg.evaluate('document.documentElement.scrollWidth')
    print(f'  {width}px：作答 {asked} 題，位置變動 {moved} 次，scrollWidth {sw}（應為 {width}），pageerror {errs[:2]}，{score}')
    ctx.close()


def check(db, profit, mu, q):
    u = lambda t, s: sum(t[i] * profit[i] for i in s)
    tu = [u(t, t) for t in db]
    util = lambda s: sum(u(t, s) for t in db if all(i in t for i in s))
    a, ch, ask = q['answer'], q['choices'], q['ask']
    t = ask['type']
    if t == 'twu': return int(ch[a]) == sum(tu[k] for k, x in enumerate(db) if ask['item'] in x)
    if t == 'cut': return set(a) == {k for k, it in enumerate(ask['sets']) if sum(tu[j] for j, x in enumerate(db) if it in x) < mu}
    if t == 'util': return int(ch[a]) == util(ask['set'])
    pos = {it: k for k, it in enumerate(ask['order'])}
    beta = ask['beta']
    last = pos[beta[-1]] if beta else -1
    if t == 'merge':
        rems = {tuple(i for i in ask['order'] if i in x and pos[i] > last) for x in db if all(i in x for i in beta)}
        return int(ch[a]) == len(rems - {()})
    z = ask['item']
    rows = [x for x in db if all(i in x for i in beta + [z])]
    su = sum(u(x, beta + [z]) + sum(x[i] * profit[i] for i in ask['keep'] if i in x and pos[i] > pos[z]) for x in rows)
    if t == 'su': return int(ch[a]) == su
    if t == 'bins':
        lu = sum(u(x, beta) + sum(x[i] * profit[i] for i in ask['order'] if i in x and pos[i] > last) for x in rows)
        want = '往下挖' if su >= mu else '不挖' if lu >= mu else '從名單刪掉'
        return ch[a].startswith(want) and ask['su'] == (su >= mu) and ask['lu'] == (lu >= mu)
    return False


with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(300)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        db = [{i: random.randint(1, 5) for i in random.sample(ITEMS, random.randint(1, 6))} for _ in range(random.randint(1, 10))]
        if random.random() < 0.4: db += [dict(random.choice(db)) for _ in range(random.randint(1, 4))]
        profit = {i: random.randint(1, 40) for i in ITEMS}
        mu = random.randint(1, max(1, sum(x[i] * profit[i] for x in db for i in x) // 2))
        for q in pg.evaluate(GET, [db, profit, mu]):
            if q['ask'].get('only'):
                if q['choices'] != ['會', '不會']: bad += 1
                q = {**q, 'choices': q['ask']['only'], 'answer': [0] if q['answer'] == 0 else [], 'multi': True}
            kinds[q['ask']['type']] = kinds.get(q['ask']['type'], 0) + 1
            ok = (len(q['choices']) >= 2 or q['ask'].get('only')) and len(set(q['choices'])) == len(q['choices']) and check(db, profit, mu, q)
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', db, profit, mu, q)
    print(f'efim 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    ctx.close()
    for w in (375, 1280): walk(b, U, w, SHOT if w == 375 else None)
    b.close()
