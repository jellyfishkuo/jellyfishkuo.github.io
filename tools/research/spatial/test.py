"""spatial.html 驗證：JS ↔ Python ↔ 暴力法隨機交叉比對、逐步走完、互動、截圖"""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import itertools, random, sys
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from quadtree import QuadTree, Point, MAX_DEPTH
from colocation import co_locations
from playwright.sync_api import sync_playwright

U = 'http://127.0.0.1:8784/research/spatial.html'
KINDS = ['超商', '公車站', '咖啡店', '飲料店']
random.seed(20261012)


def rand_points(n, crowd=False):
    out = []
    for _ in range(n):
        if crowd:     # 擠在很小的範圍、刻意製造重疊，逼出最大深度
            x, y = random.randint(40, 42), random.randint(40, 42)
        else:
            x, y = random.randint(0, 127), random.randint(0, 127)
        out.append([x, y, random.choice(KINDS)])
    return out


def py_tree_check(tree, cap, n):
    """回傳違規數：葉子超過容量（且不是最深層的重疊點）、點不在格子裡、點數不對"""
    bad, seen = 0, 0
    stack = [tree.root]
    while stack:
        nd = stack.pop()
        if nd.children:
            stack.extend(nd.children)
            if nd.points: bad += 1
            continue
        seen += len(nd.points)
        for p in nd.points:
            if not (nd.x <= p.x < nd.x + nd.size and nd.y <= p.y < nd.y + nd.size): bad += 1
        if len(nd.points) > cap and not (nd.depth == MAX_DEPTH and len({(p.x, p.y) for p in nd.points}) == 1): bad += 1
    return bad + (seen != n)


def brute_co(pts, r):
    types = list(dict.fromkeys(p[2] for p in pts))
    near = lambda a, b: (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 <= r * r
    out = {}
    for k in range(2, len(types) + 1):
        for S in itertools.combinations(types, k):
            groups = [[i for i, p in enumerate(pts) if p[2] == t] for t in S]
            part = [set() for _ in S]
            for combo in itertools.product(*groups):
                if all(near(pts[a], pts[b]) for a, b in itertools.combinations(combo, 2)):
                    for j, i in enumerate(combo): part[j].add(i)
            out[S] = min(len(part[j]) / len(groups[j]) for j in range(k))
    return out


with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)

    # ---------- 1. 四元樹：JS ↔ Python ↔ 暴力掃描 ----------
    qt_bad = {'js_vs_brute': 0, 'py_vs_brute': 0, 'js_vs_py_order_stats': 0, 'js_capacity': 0, 'py_capacity': 0}
    deep = 0
    N_QT = 300
    for trial in range(N_QT):
        crowd = trial % 10 == 0
        pts = rand_points(random.randint(0, 60), crowd)
        if crowd: pts += rand_points(random.randint(0, 20))
        cap = random.randint(1, 4)
        x1, x2 = sorted(random.sample(range(128), 2)); y1, y2 = sorted(random.sample(range(128), 2))
        q = {'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2}
        js = pg.evaluate("""([P, cap, q]) => {
            const points = P.map(([x, y, kind]) => ({x, y, kind}));
            const t = qtBuildTrace(points, cap);
            const qs = qtQueryTrace(t.root, points, q);
            const last = qs[qs.length - 1];
            const nodes = t.steps[t.steps.length - 1].nodes;
            let bad = 0, seen = 0, depth = 0;
            nodes.forEach(n => {
                depth = Math.max(depth, n.depth);
                if (!n.leaf) { if (n.pts.length) bad++; return; }
                seen += n.pts.length;
                n.pts.forEach(j => { const p = points[j]; if (!(n.x <= p.x && p.x < n.x + n.size && n.y <= p.y && p.y < n.y + n.size)) bad++; });
                const same = new Set(n.pts.map(j => points[j].x + ',' + points[j].y)).size === 1;
                if (n.pts.length > cap && !(n.depth === MAX_DEPTH && same)) bad++;
            });
            if (seen !== points.length) bad++;
            return { found: last.found, visited: last.st.visited, checked: last.st.checked, bad, depth };
        }""", [pts, cap, q])
        brute = [i for i, p in enumerate(pts) if x1 <= p[0] <= x2 and y1 <= p[1] <= y2]
        tree = QuadTree(cap)
        objs = [Point(*p) for p in pts]
        for o in objs: tree.insert(o)
        got = tree.range_query((x1, y1, x2, y2))
        py_idx = [objs.index(o) for o in got]     # 同一個物件 → 原本的編號
        if sorted(js['found']) != brute: qt_bad['js_vs_brute'] += 1
        if sorted(py_idx) != brute: qt_bad['py_vs_brute'] += 1
        if js['found'] != py_idx or js['visited'] != tree.visited or js['checked'] != tree.checked: qt_bad['js_vs_py_order_stats'] += 1
        if js['bad']: qt_bad['js_capacity'] += 1
        if py_tree_check(tree, cap, len(pts)): qt_bad['py_capacity'] += 1
        if js['depth'] == MAX_DEPTH: deep += 1
    print(f'[quadtree] {N_QT} 組隨機：', qt_bad, f'（其中 {deep} 組切到最大深度 {MAX_DEPTH}）')

    # ---------- 2. 共位樣式：JS ↔ Python ↔ 暴力法 ----------
    co_bad = {'js_vs_py': 0, 'py_vs_brute': 0}
    sizes = {}
    N_CO = 300
    for trial in range(N_CO):
        nk = random.randint(1, 4)
        kinds = random.sample(KINDS, nk)
        n = random.randint(0, 34)
        # 一半的資料做成「群聚」，比較容易出現大小 3、4 的樣式
        if trial % 2:
            cs = [(random.randint(10, 118), random.randint(10, 118)) for _ in range(random.randint(2, 5))]
            pts = []
            for _ in range(n):
                cx, cy = random.choice(cs)
                pts.append([min(127, max(0, cx + random.randint(-12, 12))), min(127, max(0, cy + random.randint(-12, 12))), random.choice(kinds)])
        else:
            pts = [[random.randint(0, 127), random.randint(0, 127), random.choice(kinds)] for _ in range(n)]
        r = random.randint(4, 40); pct = random.choice(range(5, 101, 5))
        mp = pct / 100
        js = pg.evaluate("""([P, r, mp]) => {
            const points = P.map(([x, y, kind]) => ({x, y, kind}));
            const st = coTrace(points, r, mp);
            return st[st.length - 1].result.map(x => [x.pat, x.pi]);
        }""", [pts, r, mp])
        js = {tuple(p): v for p, v in js}
        py = co_locations([tuple(p) for p in pts], r, mp)
        br = {k: v for k, v in brute_co(pts, r).items() if v >= mp}
        if js != py: co_bad['js_vs_py'] += 1
        if py != br: co_bad['py_vs_brute'] += 1
        for k in py: sizes[len(k)] = sizes.get(len(k), 0) + 1
    print(f'[colocation] {N_CO} 組隨機：', co_bad, '找到的樣式大小分布', dict(sorted(sizes.items())))

    # ---------- 3. 預設資料從頭走到尾 ----------
    pg.reload(); pg.wait_for_timeout(500)
    expect = pg.evaluate("coSteps[coSteps.length-1].result.map(x => x.pat.join('+') + ' ' + x.pi)")
    print('預設資料的共位樣式（JS）：', expect)

    def walk(group, label):
        if not pg.is_disabled(f'#{group}-first'): pg.click(f'#{group}-first')
        pg.wait_for_timeout(50)
        hs, kinds, nohl, sy = set(), {}, [], set()
        while True:
            st = pg.evaluate(f"""() => {{
                const steps = '{group}' === 'qt' ? qtCurrentSteps() : coSteps;
                const s = steps[cursors[curKey('{group}')]];
                return [s.kind, $('{group}-explain').offsetHeight, [...document.querySelectorAll('#{group}-code .ln.hl')].map(l => +l.dataset.n), window.scrollY];
            }}""")
            hs.add(st[1]); kinds[st[0]] = kinds.get(st[0], 0) + 1; sy.add(st[3])
            if not st[2] and st[0] != 'b-end': nohl.append(st[0])
            if pg.is_disabled(f'#{group}-next'): break
            pg.click(f'#{group}-next')
        print(f'[{label}] 步驟種類', kinds, '說明框高度', hs, '沒有高亮的步驟', nohl or '無', '頁面 scrollY', sy)

    walk('qt', '建樹')
    pg.click('#qt-view button[data-view=query]'); pg.wait_for_timeout(50)
    walk('qt', '查詢')
    # 程式碼高亮行是否在可視範圍（等 smooth scroll 結束）
    pg.click('#qt-first'); pg.click('#qt-next'); pg.click('#qt-next'); pg.click('#qt-next'); pg.wait_for_timeout(700)
    vis = pg.evaluate("""() => { const pre = $('qt-code'); const r = pre.getBoundingClientRect();
        return [...pre.querySelectorAll('.ln.hl')].some(l => { const b = l.getBoundingClientRect(); return b.top >= r.top - 1 && b.bottom <= r.bottom + 1; }); }""")
    print('查詢步驟的高亮行看得到：', vis)
    pg.click('#tab-co'); pg.wait_for_timeout(100)
    walk('co', '共位')

    # ---------- 4. 互動 ----------
    pg.click('#tab-qt'); pg.click('#qt-view button[data-view=build]')
    box = pg.locator('#qt-map').bounding_box()
    w2px = lambda x, y: (box['x'] + (x + 1) / 130 * box['width'], box['y'] + (y + 1) / 130 * box['height'])
    n0 = pg.evaluate('pts.length')
    pg.mouse.click(*w2px(6, 6)); pg.wait_for_timeout(100)
    print('點空白處新增：', n0, '→', pg.evaluate('pts.length'), '，游標停在', pg.evaluate("[qtBuild.steps[cursors.build].kind, qtBuild.steps[cursors.build].pi]"), pg.inner_text('#qt-hint'))
    pg.mouse.click(*w2px(6, 6)); pg.wait_for_timeout(100)
    print('再點同一點刪除：', pg.evaluate('pts.length'), pg.inner_text('#qt-hint'))
    pg.click('#qt-view button[data-view=query]')
    pg.evaluate("$('qt-map').scrollIntoView({block: 'center'})"); pg.wait_for_timeout(100)
    box = pg.locator('#qt-map').bounding_box()
    pg.mouse.move(*w2px(10, 50)); pg.mouse.down(); pg.mouse.move(*w2px(40, 70), steps=6); pg.mouse.move(*w2px(60, 90), steps=6); pg.mouse.up()
    pg.wait_for_timeout(100)
    print('滑鼠拖曳查詢框：', pg.evaluate('queryRect'), '查詢步驟數', pg.evaluate('qtQuery.length'))
    pg.click('#qt-last'); pg.wait_for_timeout(100)
    print('  結果：', pg.inner_text('#qt-explain').split('\n')[1][:80])
    pg.click('#cap-plus'); pg.click('#cap-plus'); pg.click('#cap-minus')
    print('容量改成', pg.inner_text('#cap-val'), '節點數', pg.inner_text('#st-nodes'))
    pg.click('#qt-tools [data-act=random]'); pg.wait_for_timeout(100)
    print('隨機產生：', pg.evaluate('pts.length'), '個點')
    pg.click('#qt-tools [data-act=clear]'); pg.wait_for_timeout(100)
    pg.click('#qt-view button[data-view=build]'); pg.click('#qt-last'); pg.click('#qt-view button[data-view=query]'); pg.click('#qt-last')
    pg.click('#tab-co'); pg.click('#co-last')
    print('清空後：', pg.evaluate('pts.length'), '個點；共位說明', pg.inner_text('#co-explain').split('\n')[1][:40])
    pg.click('#co-tools [data-act=reset]'); pg.wait_for_timeout(100)
    pg.fill('#r-range', '24'); pg.fill('#mp-range', '30'); pg.wait_for_timeout(100)
    print('r=24, minPrev=0.3：', pg.evaluate("coSteps[coSteps.length-1].result.map(x => x.pat.join('+'))"))
    pg.fill('#r-range', '16'); pg.fill('#mp-range', '50')
    pg.click('#co-first')
    for _ in range(3): pg.keyboard.press('ArrowRight')
    print('鍵盤右鍵 3 次：步驟', pg.evaluate('cursors.co + 1'))
    print('pageerror:', errs)

    # ---------- 5. 截圖 ----------
    pg.goto(U); pg.wait_for_timeout(400)
    for _ in range(13): pg.click('#qt-next')
    pg.wait_for_timeout(700); pg.screenshot(path='sp_build_d.png', full_page=True)
    pg.click('#qt-view button[data-view=query]')
    for _ in range(5): pg.click('#qt-next')
    pg.wait_for_timeout(700); pg.screenshot(path='sp_query_d.png', full_page=True)
    pg.click('#tab-co')
    while pg.evaluate("coSteps[cursors.co].kind !== 'c-rows' || coSteps[cursors.co].pat.length !== 3"): pg.click('#co-next')
    pg.wait_for_timeout(700); pg.screenshot(path='sp_co_d.png', full_page=True)

    m = b.new_context(viewport={'width': 375, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
    m.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    mp_ = m.new_page(); merrs = []
    mp_.on('pageerror', lambda e: merrs.append(str(e)))
    mp_.goto(U); mp_.wait_for_timeout(500)
    sw1 = mp_.evaluate('document.documentElement.scrollWidth')
    for _ in range(14): mp_.click('#qt-next')
    mp_.wait_for_timeout(600); mp_.screenshot(path='sp_build_m.png', full_page=True)
    # 手指拖曳查詢框（CDP 觸控事件）
    mp_.click('#qt-view button[data-view=query]')
    mp_.locator('#qt-map').scroll_into_view_if_needed(); mp_.wait_for_timeout(200)
    bb = mp_.locator('#qt-map').bounding_box()
    cdp = m.new_cdp_session(mp_)
    P = lambda x, y: {'x': bb['x'] + (x + 1) / 130 * bb['width'], 'y': bb['y'] + (y + 1) / 130 * bb['height']}
    sy0 = mp_.evaluate('scrollY')
    cdp.send('Input.dispatchTouchEvent', {'type': 'touchStart', 'touchPoints': [P(70, 70)]})
    for t in range(1, 9):
        cdp.send('Input.dispatchTouchEvent', {'type': 'touchMove', 'touchPoints': [P(70 + t * 5, 70 + t * 5)]})
    cdp.send('Input.dispatchTouchEvent', {'type': 'touchEnd', 'touchPoints': []})
    mp_.wait_for_timeout(200)
    print('手機手指拖曳查詢框：', mp_.evaluate('queryRect'), '頁面有沒有被捲動', sy0, '→', mp_.evaluate('scrollY'))
    for _ in range(4): mp_.click('#qt-next')
    mp_.wait_for_timeout(600); mp_.screenshot(path='sp_query_m.png', full_page=True)
    mp_.click('#tab-co')
    for _ in range(6): mp_.click('#co-next')
    mp_.wait_for_timeout(600); mp_.screenshot(path='sp_co_m.png', full_page=True)
    mp_.evaluate('scrollTo(0, 0)'); mp_.wait_for_timeout(200); mp_.screenshot(path='sp_co_m_top.png')
    mp_.evaluate("$('co-table').scrollIntoView()"); mp_.wait_for_timeout(200); mp_.screenshot(path='sp_co_m_table.png')
    mp_.click('#tab-qt'); mp_.evaluate("$('qt-explain').scrollIntoView()"); mp_.wait_for_timeout(300); mp_.screenshot(path='sp_qt_m_mid.png')
    sw2 = mp_.evaluate('document.documentElement.scrollWidth')
    print('手機 scrollWidth：分頁一', sw1, '分頁二', sw2, ' pageerror:', merrs)
    b.close()
