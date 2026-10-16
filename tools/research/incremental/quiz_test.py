"""FUP（增量）練習模式：用隨機資料檢查每一題的正確答案（Python 直接從原始交易算），再到 375 / 1280 開練習模式隨機作答走到尾。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）；截圖路徑可當第二個參數"""
import os, random, sys
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/incremental.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 100
SHOT = sys.argv[2] if len(sys.argv) > 2 else None
GET = """([DB, db, p]) => { pct = p; const D = DB.map(t => new Set(t)), d = db.map(t => new Set(t));
    const tr = buildTrace(D, apriori(D).L, d);
    return tr.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""


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


def check(DB, db, pct, q):
    need = lambda n: (n * pct + 99) // 100
    sup = lambda rows, s: sum(1 for t in rows if set(s) <= t)
    a, ch, ask = q['answer'], q['choices'], q['ask']
    t, N = ask['type'], DB + db
    if t == 'drop': return set(a) == {k for k, s in enumerate(ask['sets']) if sup(N, s) < need(len(N))} and all(sup(DB, s) >= need(len(DB)) for s in ask['sets'])
    if t == 'lemma': return set(a) == {k for k, s in enumerate(ask['sets']) if sup(db, s) >= need(len(db))}
    if t == 'count': return int(ch[a]) == sup(N, ask['set'])
    return False


with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(300)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        its = random.sample(ITEMS, random.randint(2, 6))
        DB = [set(random.sample(its, random.randint(1, len(its)))) for _ in range(random.randint(1, 15))]
        db = [set(random.sample(its, random.randint(1, len(its)))) for _ in range(random.randint(1, 8))]
        pct = random.randint(10, 80)
        for q in pg.evaluate(GET, [[sorted(x) for x in DB], [sorted(x) for x in db], pct]):
            if q['ask'].get('only'):
                if q['choices'] != ['會', '不會']: bad += 1
                q = {**q, 'choices': q['ask']['only'], 'answer': [0] if q['answer'] == 0 else [], 'multi': True}
            kinds[q['ask']['type']] = kinds.get(q['ask']['type'], 0) + 1
            ok = (len(q['choices']) >= 2 or q['ask'].get('only')) and len(set(q['choices'])) == len(q['choices']) and check(DB, db, pct, q)
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', DB, db, pct, q)
    print(f'incremental 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    ctx.close()
    for w in (375, 1280): walk(b, U, w, SHOT if w == 375 else None)
    b.close()
