"""練習模式：用隨機串流檢查每一題的正確答案，跟 Python 版（research/code/count_min.py）算的一致。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）"""
import os, random, sys
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from count_min import CountMin, ITEMS
from playwright.sync_api import sync_playwright
U = 'http://127.0.0.1:%s/research/count-min.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 100
GET = """([st, w, d, cu]) => { stream = st; const tr = cmTrace(st, w, d, cu);
    return tr.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_function('() => !blocksBusy', timeout=60000)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        st = [random.choice(ITEMS[:random.randint(2, len(ITEMS))]) for _ in range(random.randint(5, 60))]
        w, d, cu = random.randint(2, 10), random.randint(1, 5), random.random() < 0.5
        def run(n):
            cm = CountMin(w, d, cu)
            for x in st[:n]: cm.add(ITEMS.index(x) + 1)
            return cm
        for q in pg.evaluate(GET, [st, w, d, cu]):
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = len(ch) >= 2 and len(set(ch)) == len(ch)
            x = ITEMS.index(ask['item']) + 1
            if t == 'est': ok &= int(ch[a]) == run(ask['n']).estimate(x)
            elif t == 'cu':
                cm = run(ask['n']); ok &= int(ch[a]) == cm.table[ask['j']][cm.h(ask['j'], x)]
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', st, w, d, cu, q)
    print(f'count-min 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    b.close()
