"""練習模式：用隨機資料檢查每一題的正確答案，跟 Python 版（research/code/quadtree.py、colocation.py）與暴力法的結果一致。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）"""
import itertools, os, random, sys
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from quadtree import QuadTree, Point
from colocation import co_locations, near
from playwright.sync_api import sync_playwright
KINDS = ['超商', '公車站', '咖啡店', '飲料店']
QN = ['左上', '右上', '左下', '右下']
U = 'http://127.0.0.1:%s/research/spatial.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 100
GET = """([P, cap, q, r, mp]) => { pts = P.map(([x, y, kind]) => ({ x, y, kind })); capacity = cap; queryRect = { x1: q[0], y1: q[1], x2: q[2], y2: q[3] }; radius = r; minPct = mp; rebuildQt(); rebuildCo();
    const pick = q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask });
    const out = [];
    [qtBuild.steps, qtQuery].forEach(tr => tr.forEach((s, i) => { const x = qtQuiz(s, i, tr); if (x) out.push(pick(x)); }));
    coSteps.forEach((s, i) => { const x = coQuiz(s, i); if (x) out.push(pick(x)); });
    return out; }"""
def nodes(t):
    out, st = 0, [t.root]
    while st:
        n = st.pop(); out += 1
        if n.children: st += n.children
    return out
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(300)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        n = random.randint(1, 40)
        lo, hi = (0, 127) if trial % 2 else (40, 80)
        P = [(x, y, random.choice(KINDS[:random.randint(2, 4)])) for x, y in {(random.randint(lo, hi), random.randint(lo, hi)) for _ in range(n)}]
        if trial % 7 == 0: P += [P[0]] * 3               # 疊在一起的點：切到第 7 層
        cap = random.randint(1, 4)
        x1, x2 = sorted(random.sample(range(128), 2)); y1, y2 = sorted(random.sample(range(128), 2))
        r, mp = random.randint(6, 40), random.choice([10, 20, 30, 40, 50, 60, 70, 80, 90, 100])
        qt, split = QuadTree(cap), []
        for x, y, k in P:
            before = nodes(qt); qt.insert(Point(x, y, k)); split.append(nodes(qt) > before)
        total = {t: sum(1 for p_ in P if p_[2] == t) for t in KINDS}
        prev_ok = set(co_locations(P, r, mp / 100))
        def rows(pat):
            groups = [[i for i, p_ in enumerate(P) if p_[2] == t] for t in pat]
            return [c for c in itertools.product(*groups) if all(near(P[a], P[b], r) for a, b in itertools.combinations(c, 2))]
        for x in pg.evaluate(GET, [P, cap, [x1, y1, x2, y2], r, mp]):
            if x['ask'].get('only'):
                if x['choices'] != ['會', '不會']: bad += 1
                x = {**x, 'choices': x['ask']['only'], 'answer': [0] if x['answer'] == 0 else [], 'multi': True}
            a, ch, ask = x['answer'], x['choices'], x['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = bool((len(ch) >= 2 or ask.get('only')) and len(set(ch)) == len(ch) and len(ch) <= 4)
            if t == 'split': ok &= (a == 0) == split[ask['pi']]
            elif t == 'quad':
                (nx, ny, s), (px, py) = ask['node'], ask['p']
                ok &= ch[a] == QN[(px >= nx + s // 2) + 2 * (py >= ny + s // 2)]
            elif t == 'go':
                qx1, qy1, qx2, qy2 = ask['q']
                ok &= set(a) == {k for k, (nx, ny, s) in enumerate(ask['kids']) if qx1 < nx + s and nx <= qx2 and qy1 < ny + s and ny <= qy2}
            elif t == 'inside':
                qx1, qy1, qx2, qy2 = ask['q']
                ok &= int(ch[a]) == sum(1 for px, py in ask['pts'] if qx1 <= px <= qx2 and qy1 <= py <= qy2)
            elif t == 'prune':
                cut = [k for k, pat in enumerate(ask['pats']) if any(tuple(pat[:i] + pat[i + 1:]) not in prev_ok for i in range(len(pat)))]
                ok &= (int(ch[a]) == len(cut)) if not x['multi'] else set(a) == set(cut)
            elif t == 'rows': ok &= int(ch[a]) == len(rows(ask['pat']))
            elif t == 'pi':
                R = rows(ask['pat'])
                pi = min(len({row[j] for row in R}) / total[tt] for j, tt in enumerate(ask['pat']))
                ok &= abs(float(ch[a]) - pi) < 1e-3
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', P, cap, (x1, y1, x2, y2), r, mp, x)
    print(f'spatial 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    b.close()
