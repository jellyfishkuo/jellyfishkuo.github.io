"""rtree.html 驗證：JS ↔ Python ↔ 暴力法隨機交叉比對、不變式檢查、逐步走完（區塊位置不變）、互動、截圖
需要本機伺服器：cd <repo> && python3 -m http.server 8800"""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from rtree import RTree, Point, bound
from playwright.sync_api import sync_playwright

U = 'http://127.0.0.1:8800/research/rtree.html'
SHOT = os.environ.get('SHOT_DIR', '/tmp/rtree-shots')
os.makedirs(SHOT, exist_ok=True)
KINDS = ['超商', '公車站', '咖啡店', '飲料店']
random.seed(20261013)


def rand_points(n, span=128):
    lo = random.randint(0, 128 - span)
    return [[random.randint(lo, lo + span - 1), random.randint(lo, lo + span - 1), random.choice(KINDS)] for _ in range(n)]


def py_ser(node):
    """樹 → 巢狀結構：(id, mbr, 葉子的點編號 或 子節點)"""
    if node.leaf:
        return [node.id, list(node.mbr) if node.mbr else None, [p.no for p in node.entries]]
    return [node.id, list(node.mbr), [py_ser(c) for c in node.entries]]


JS_SER = """
function ser(nodes, id) {
    const n = nodes.find(x => x.id === id);
    if (n.leaf) return [n.id, n.mbr, n.kids.slice()];
    return [n.id, n.mbr, n.kids.map(c => ser(nodes, c))];
}"""


def check_invariants(t, pts, M):
    """回傳違規數：框沒有剛好包住、子節點數不在 [m, M]、葉子不同深度、點數不對"""
    m = M // 2
    bad, leaf_depths, seen = 0, set(), []

    def walk(n, d, is_root):
        nonlocal bad
        nid, mbr, kids = n
        leaf = not kids or not isinstance(kids[0], list)
        if leaf:
            leaf_depths.add(d)
            seen.extend(kids)
            rects = [(pts[j][0], pts[j][1], pts[j][0], pts[j][1]) for j in kids]
        else:
            rects = [tuple(c[1]) for c in kids]
            for c in kids: walk(c, d + 1, False)
        if not kids:
            if not (is_root and mbr is None): bad += 1
            return
        b = rects[0]
        for r in rects[1:]: b = (min(b[0], r[0]), min(b[1], r[1]), max(b[2], r[2]), max(b[3], r[3]))
        if tuple(mbr) != b: bad += 1                      # 框剛好包住子孫（子框又各自包住自己的子孫）
        if len(kids) > M: bad += 1
        if not is_root and len(kids) < m: bad += 1
        if is_root and not leaf and len(kids) < 2: bad += 1
    walk(t, 0, True)
    if len(leaf_depths) > 1: bad += 1
    if sorted(seen) != list(range(len(pts))): bad += 1
    return bad


with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)
    pg.evaluate('() => { window.ser = ' + JS_SER.strip().replace('function ser', 'function') + '; }')

    # ---------- 1. 建樹：JS ↔ Python 每一次插入後的樹完全一樣，而且不變式成立 ----------
    N_TREE = 250
    tb = {'js_vs_py_step': 0, 'js_invariant': 0, 'py_invariant': 0}
    inserts, splits, root_splits, heights = 0, 0, 0, set()
    for trial in range(N_TREE):
        M = random.randint(3, 6)
        span = random.choice([128, 128, 20, 6])          # 小範圍：很多重複的點與共線
        pts = rand_points(random.randint(0, 60), span)
        js = pg.evaluate("""([P, M]) => {
            const points = P.map(([x, y, kind]) => ({x, y, kind}));
            const t = rtBuildTrace(points, M);
            const after = [];
            t.steps.forEach((s, i) => { const nx = t.steps[i + 1]; if (s.pi !== undefined && (!nx || nx.pi !== s.pi)) after.push(ser(s.nodes, s.rootId)); });
            return { after, splits: t.steps.filter(s => s.kind === 'b-split').length, roots: t.steps.filter(s => s.kind === 'b-split' && s.newRoot !== null).length };
        }""", [pts, M])
        tree = RTree(M)
        ok = len(js['after']) == len(pts)
        for i, (x, y, k) in enumerate(pts):
            tree.insert(Point(x, y, k))
            s = py_ser(tree.root)
            if not ok or js['after'][i] != s: ok = False
            if check_invariants(s, pts[:i + 1], M): tb['py_invariant'] += 1
            if i < len(js['after']) and check_invariants(js['after'][i], pts[:i + 1], M): tb['js_invariant'] += 1
            inserts += 1
        if not ok: tb['js_vs_py_step'] += 1
        splits += js['splits']; root_splits += js['roots']
        h = 0; n = tree.root
        while not n.leaf: n = n.entries[0]; h += 1
        heights.add(h + 1)
    print(f'[建樹] {N_TREE} 組隨機（共 {inserts} 次插入、{splits} 次分裂、其中 {root_splits} 次根分裂，樹高 {sorted(heights)}）：', tb)

    # ---------- 2. kNN：JS ↔ Python ↔ 暴力法 ----------
    N_KNN = 400
    kb = {'js_vs_brute': 0, 'py_vs_brute': 0, 'js_vs_py_stats': 0}
    ties = 0
    for trial in range(N_KNN):
        M = random.randint(3, 6)
        span = random.choice([128, 128, 16, 5])
        pts = rand_points(random.randint(0, 60), span)
        k = random.randint(1, 8)
        q = (random.randint(0, 127), random.randint(0, 127)) if span == 128 or trial % 3 == 0 else (pts[0][0] if pts else 5, pts[0][1] if pts else 5)
        js = pg.evaluate("""([P, M, q, k]) => {
            const points = P.map(([x, y, kind]) => ({x, y, kind}));
            const t = rtBuildTrace(points, M);
            const st = knnTrace(t.root, points, {x: q[0], y: q[1]}, k);
            const last = st[st.length - 1];
            return { res: last.results.map(r => [r.j, r.d]), st: last.st };
        }""", [pts, M, list(q), k])
        tree = RTree(M)
        objs = [Point(*p) for p in pts]
        for o in objs: tree.insert(o)
        py = [[p.no, d] for p, d in tree.knn(q, k)]
        brute = sorted(([(p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2, i] for i, p in enumerate(pts)))[:k]
        brute = [[i, d] for d, i in brute]
        if len(pts) > k and brute and ((pts[0][0] - q[0]) ** 2 + 0 >= 0):
            ds = sorted((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 for p in pts)
            if ds[k - 1] == ds[k]: ties += 1             # 第 k 名跟第 k+1 名一樣遠：平手規則有被考到
        if js['res'] != brute: kb['js_vs_brute'] += 1
        if py != brute: kb['py_vs_brute'] += 1
        if js['res'] != py or (js['st']['opened'], js['st']['checked'], js['st']['pruned']) != (tree.opened, tree.checked, tree.pruned): kb['js_vs_py_stats'] += 1
    print(f'[kNN] {N_KNN} 組隨機（其中 {ties} 組第 k 名與第 k+1 名同距離）：', kb)

    # ---------- 3. 預設資料從頭走到尾：說明框高度、區塊位置、捲動 ----------
    def walk(page, group, label):
        if not page.is_disabled(f'#{group}-first'): page.click(f'#{group}-first')
        page.wait_for_timeout(100)
        hs, kinds, nohl, sy, pos = set(), {}, [], set(), set()
        while True:
            st = page.evaluate(f"""() => {{
                const s = stepsOf('{group}')[cursors['{group}']];
                const cards = [...$('panel-{group}').querySelectorAll('.card')].map(c => {{ const r = c.getBoundingClientRect(); return [Math.round(r.left), Math.round(r.top + scrollY), Math.round(r.height)].join(','); }}).join(' ');
                return [s.kind, $('{group}-explain').offsetHeight, [...document.querySelectorAll('#{group}-code .ln.hl')].map(l => +l.dataset.n), window.scrollY, cards];
            }}""")
            hs.add(st[1]); kinds[st[0]] = kinds.get(st[0], 0) + 1; sy.add(st[3]); pos.add(st[4])
            if not st[2] and st[0] != 'b-end': nohl.append(st[0])
            if page.is_disabled(f'#{group}-next'): break
            page.click(f'#{group}-next')
        n = sum(kinds.values())
        print(f'  [{label}] {n} 步', kinds, '說明框高度', hs, '沒有高亮', nohl or '無', 'scrollY', sy, '區塊位置組合數', len(pos))
        return len(pos) == 1 and len(hs) == 1

    allok = True
    for w, h, mob in ((1280, 900, False), (375, 760, True), (320, 700, True)):
        c2 = b.new_context(viewport={'width': w, 'height': h}, is_mobile=mob, has_touch=mob, device_scale_factor=2 if mob else 1)
        c2.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        p2 = c2.new_page(); e2 = []
        p2.on('pageerror', lambda e: e2.append(str(e)))
        p2.goto(U); p2.wait_for_timeout(3000)
        print(f'寬 {w}：')
        allok &= walk(p2, 'rt', '建樹')
        sw1 = p2.evaluate('document.documentElement.scrollWidth')
        p2.click('#tab-kn'); p2.wait_for_timeout(3000)
        allok &= walk(p2, 'kn', 'kNN')
        sw2 = p2.evaluate('document.documentElement.scrollWidth')
        print(f'  scrollWidth 分頁一 {sw1} 分頁二 {sw2}（視窗 {w}）pageerror', e2)
        allok &= sw1 == w and sw2 == w and not e2
        c2.close()
    print('區塊位置與說明框高度全程不變、沒有水平捲動：', allok)

    # ---------- 4. 互動 ----------
    pg.goto(U); pg.wait_for_timeout(800)
    pg.evaluate("$('rt-map').scrollIntoView({block: 'center'})"); pg.wait_for_timeout(100)
    box = pg.locator('#rt-map').bounding_box()
    w2px = lambda bb, x, y: (bb['x'] + (x + 7) / 142 * bb['width'], bb['y'] + (y + 7) / 142 * bb['height'])
    n0 = pg.evaluate('pts.length')
    pg.mouse.click(*w2px(box, 4, 124)); pg.wait_for_timeout(100)
    print('點空白處新增：', n0, '→', pg.evaluate('pts.length'), '游標停在', pg.evaluate("[rtBuild.steps[cursors.rt].kind, rtBuild.steps[cursors.rt].pi]"), pg.inner_text('#rt-hint'))
    pg.mouse.click(*w2px(box, 4, 124)); pg.wait_for_timeout(100)
    print('再點同一點刪除：', pg.evaluate('pts.length'), pg.inner_text('#rt-hint'))
    while not pg.is_disabled('#cap-minus'): pg.click('#cap-minus')
    print('M 最小', pg.inner_text('#cap-val'), '節點數', pg.inner_text('#st-nodes'), '樹高', pg.inner_text('#st-height'))
    while not pg.is_disabled('#cap-plus'): pg.click('#cap-plus')
    print('M 最大', pg.inner_text('#cap-val'), '節點數', pg.inner_text('#st-nodes'), '樹高', pg.inner_text('#st-height'))
    pg.click('#cap-minus'); pg.click('#cap-minus')
    print('M 回到', pg.inner_text('#cap-val'))
    pg.click('#rt-first')
    for _ in range(3): pg.keyboard.press('ArrowRight')
    print('鍵盤右鍵 3 次：步驟', pg.evaluate('cursors.rt + 1'))
    pg.click('#tab-kn'); pg.wait_for_timeout(200)
    pg.evaluate("$('kn-map').scrollIntoView({block: 'center'})"); pg.wait_for_timeout(100)
    box = pg.locator('#kn-map').bounding_box()
    pg.mouse.click(*w2px(box, 30, 90)); pg.wait_for_timeout(100)
    print('點地圖換查詢點：', pg.evaluate('qPoint'), pg.inner_text('#kn-hint'))
    pg.click('#k-plus'); pg.click('#k-plus'); pg.click('#kn-last')
    print('k=5 結果：', pg.inner_text('#kn-explain').split('\n')[1][:120])
    pg.click('#tab-rt'); pg.click('#rt-tools [data-act=random]', force=True); pg.wait_for_timeout(100)
    print('隨機產生：', pg.evaluate('pts.length'), '個點')
    pg.click('#rt-tools [data-act=clear]'); pg.click('#rt-last'); pg.click('#tab-kn'); pg.click('#kn-last')
    print('清空後 kNN 說明：', pg.inner_text('#kn-explain').split('\n')[1][:40])
    pg.click('#tab-rt'); pg.click('#rt-tools [data-act=reset]')
    print('pageerror:', errs)

    # ---------- 5. 截圖 ----------
    pg.goto(U); pg.wait_for_timeout(1500)
    idx = pg.evaluate("rtBuild.steps.findIndex((s, i) => s.kind === 'b-split' && i > 30)")
    for _ in range(idx): pg.click('#rt-next')
    pg.wait_for_timeout(700); pg.screenshot(path=f'{SHOT}/rt_build_d.png', full_page=True)
    pg.click('#tab-kn'); pg.wait_for_timeout(1500)
    for _ in range(7): pg.click('#kn-next')
    pg.wait_for_timeout(700); pg.screenshot(path=f'{SHOT}/rt_knn_d.png', full_page=True)
    m = b.new_context(viewport={'width': 375, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
    m.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    mp = m.new_page()
    mp.goto(U); mp.wait_for_timeout(1500)
    for _ in range(8): mp.click('#rt-next')
    mp.wait_for_timeout(600)
    mp.evaluate("$('rt-explain').scrollIntoView()"); mp.wait_for_timeout(300); mp.screenshot(path=f'{SHOT}/rt_build_m.png')
    mp.evaluate("$('rt-tree').scrollIntoView()"); mp.wait_for_timeout(300); mp.screenshot(path=f'{SHOT}/rt_tree_m.png')
    mp.click('#tab-kn'); mp.wait_for_timeout(1500)
    for _ in range(7): mp.click('#kn-next')
    mp.wait_for_timeout(600)
    mp.evaluate("$('kn-explain').scrollIntoView()"); mp.wait_for_timeout(300); mp.screenshot(path=f'{SHOT}/rt_knn_m.png')
    mp.evaluate("$('kn-queue').scrollIntoView()"); mp.wait_for_timeout(300); mp.screenshot(path=f'{SHOT}/rt_queue_m.png')
    b.close()
