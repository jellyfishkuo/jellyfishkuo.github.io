"""練習模式：用隨機圖資料庫檢查每一題的正確答案，跟 Python 版（research/code/gspan.py）算的一致。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）"""
import os, random, sys
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from gspan import min_code, rightmost_path
from playwright.sync_api import sync_playwright
U = 'http://127.0.0.1:%s/research/gspan.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 150
GET = """([d, m]) => { trace = buildTrace(d.map(([a, b]) => ({ atoms: a, bonds: b })), m); cursor = 0;
    return trace.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""


def rand_db(rng):
    gs = []
    for _ in range(rng.randint(1, 6)):
        n = rng.randint(2, 6)
        pool = 'CO' if rng.random() < 0.3 else 'CCCON'
        atoms = [rng.choice(pool) for _ in range(n)]
        es = {(rng.randrange(v), v) for v in range(1, n)}
        for _ in range(rng.randint(0, 3)):
            u, v = rng.sample(range(n), 2)
            es.add((min(u, v), max(u, v)))
        gs.append((atoms, [(u, v, '=' if rng.random() < 0.25 else '-') for u, v in sorted(es)]))
    return gs


with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_function('() => !blocksBusy', timeout=20000)
    rng = random.Random()
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        gs = rand_db(rng); ms = rng.randint(1, len(gs))
        for q in pg.evaluate(GET, [gs, ms]):
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = len(ch) >= 2 and len(set(ch)) == len(ch) and len(ch) <= 4
            if t == 'first':
                _, _, x, bd, y = ask['e']
                ok &= int(ch[a]) == sum(1 for at, bs in gs if any((at[u], b_, at[v]) in ((x, bd, y), (y, bd, x)) for u, v, b_ in bs))
            elif t == 'rm':
                ok &= ch[a] == ' → '.join(map(str, rightmost_path([tuple(e) for e in ask['code']])))
            elif t == 'min':
                code = [tuple(e) for e in ask['code']]
                ok &= ch[a].startswith('是') == (min_code(code) == code)
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', gs, ms, q)
    print(f'gspan 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    b.close()
