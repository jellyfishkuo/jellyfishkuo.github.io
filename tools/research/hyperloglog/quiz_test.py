"""練習模式：用隨機來客檢查每一題的正確答案，跟 Python 版（research/code/hyperloglog.py）算的一致。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）"""
import os, random, sys
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from hyperloglog import HyperLogLog, hash32, alpha
from playwright.sync_api import sync_playwright
U = 'http://127.0.0.1:%s/research/hyperloglog.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 100
GET = """([v, p]) => { visits = v; hp = p; const tr = hllTrace(v, p);
    return tr.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""
MODE = {'small': 'linear counting：m·ln(m/V)', 'raw': '直接用調和平均 E', 'large': '大範圍修正（雜湊快用完）'}
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_function('() => !blocksBusy', timeout=60000)
    B = pg.evaluate('STORE_B')
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        vs = []
        for i in range(random.randint(1, 30)):
            vs.append(random.choice(vs) if vs and random.random() < 0.3 else 'M-%08d' % random.randrange(10 ** 8))
        P = random.randint(4, 10)
        def run(keys):
            h = HyperLogLog(P)
            for k in keys: h.add(k)
            return h
        A = run(vs)
        for q in pg.evaluate(GET, [vs, P]):
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = len(ch) >= 2 and len(set(ch)) == len(ch)
            if t in ('bucket', 'rho'):
                h = hash32(ask['key']); w = (h << P) & 0xFFFFFFFF
                ok &= int(ch[a]) == (h >> (32 - P) if t == 'bucket' else 32 - P + 1 if w == 0 else 32 - w.bit_length() + 1)
            elif t == 'reg': ok &= int(ch[a]) == run(vs[:ask['vi'] + 1]).M[ask['j']]
            elif t == 'zeros': ok &= int(ch[a]) == A.M.count(0)
            elif t == 'mode':
                m = A.m; z = A.M.count(0); e = alpha(m) * m * m / sum(2.0 ** -r for r in A.M)
                ok &= ch[a] == MODE['small' if e <= 2.5 * m and z else 'large' if e > 2 ** 32 / 30 else 'raw']
            elif t == 'merge':
                MB = run(B).M; ok &= int(ch[a]) == sum(1 for x, y in zip(A.M, MB) if y > x)
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', vs, P, q)
    print(f'hyperloglog 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    b.close()
