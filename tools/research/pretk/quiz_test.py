"""練習模式：用隨機資料檢查每一題的正確答案（Python 版自己算），再打開練習模式隨機作答從頭走到尾。
需要本機伺服器：cd <repo> && python3 -m http.server 8774（或設環境變數 PORT）"""
import os, random, sys
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from pretk import PreTK
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/pretk.html' % os.environ.get('PORT', '8774')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 150
GET = """([bs, p, kl, ku]) => { DATASETS.rand = { ITEMS: DATASETS.shop.ITEMS, EMOJI: DATASETS.shop.EMOJI, PROFIT: p, BATCHES: bs, kl, ku };
    useDataset('rand'); const tr = buildTrace(bs, p, kl, ku);
    const out = tr.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask }));
    useDataset('shop'); return out; }"""
POS = "[...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.height)]; })"
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(300)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        items = random.sample(ITEMS, random.randint(2, 6))
        profit = {i: random.randint(1, 30) for i in ITEMS}
        batches = [[{i: random.randint(1, 5) for i in random.sample(items, random.randint(1, len(items)))} for _ in range(random.randint(2, 7))]]
        for _ in range(random.randint(1, 5)):
            batches.append([{i: random.randint(1, 3) for i in random.sample(items, random.randint(1, min(2, len(items))))} for _ in range(random.randint(1, 2))])
        kl = random.randint(1, 5); ku = kl + random.randint(1, 10)
        # Python 版逐批跑，記下每批之前／之後的狀態
        m, info = PreTK(profit, kl, ku), {}
        for k, bt in enumerate(batches):
            before = (m.min_upper, m.min_lower, m.ceiling)
            r = m.add_batch(bt)
            info[k] = dict(before=before, remine=r, ceil=m.ceiling, large={tuple(sorted(s)) for s, _ in m.answer()})
        for q in pg.evaluate(GET, [batches, profit, kl, ku]):
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            st = info[ask['b']]; up, low, ceil = st['before']
            ok = len(ch) >= 2 and len(set(ch)) == len(ch) and len(ch) <= 4
            if t == 'remine': ok &= (ch[a] == '要重新挖掘') == st['remine']
            elif t == 'gap': ok &= int(ch[a]) == up - ceil
            elif t == 'ceil': ok &= int(ch[a]) == st['ceil'] and not st['remine']
            elif t == 's4': ok &= int(ch[a]) == low and st['remine']
            elif t == 'large': ok &= {tuple(sorted(ask['sets'][k])) for k in a} == {tuple(sorted(s)) for s in ask['sets']} & st['large']
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', batches, profit, kl, ku, q)
    print(f'pretk 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}')
    for w, h in ((375, 760), (1280, 900)):
        c2 = b.new_context(viewport={'width': w, 'height': h}); c2.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        p2 = c2.new_page(); p2.on('pageerror', lambda e: errs.append(str(e)))
        for ds in ('shop', 'paper'):
            p2.goto(U); p2.wait_for_timeout(3000)
            if ds == 'paper': p2.click('#ds button[data-ds=paper]'); p2.wait_for_timeout(2000)
            pos0 = p2.evaluate(POS); moved = asked = 0
            p2.click('#quiz-toggle'); moved += p2.evaluate(POS) != pos0
            while not p2.is_disabled('#btn-next'):
                p2.click('#btn-next'); p2.wait_for_timeout(20)
                if p2.is_visible('#quiz'):
                    asked += 1; moved += p2.evaluate(POS) != pos0
                    cs = p2.query_selector_all('#quiz .quiz-choice'); random.choice(cs).click()
                    if p2.is_visible('#quiz .quiz-ok'): p2.click('#quiz .quiz-ok')
                    moved += p2.evaluate(POS) != pos0
                    if w == 375 and asked == 2 and ds == 'shop': p2.screenshot(path=os.environ.get('SHOT', '/tmp') + '/quiz_375.png')
                    p2.click('#quiz .quiz-go'); p2.wait_for_timeout(20)
                moved += p2.evaluate(POS) != pos0
            score = p2.inner_text('#quiz-score')
            p2.click('#quiz-toggle'); moved += p2.evaluate(POS) != pos0
            print(f'{w}px {ds} 練習模式：出題 {asked}，{score}，.card 位置變動 {moved} 次，scrollWidth {p2.evaluate("document.documentElement.scrollWidth")}')
        c2.close()
    print('pageerror', errs)
    b.close()
