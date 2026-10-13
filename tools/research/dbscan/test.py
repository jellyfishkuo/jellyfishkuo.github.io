"""dbscan.html 驗證：JS ↔ Python ↔ 暴力法隨機交叉比對、逐步走完（區塊位置不能動）、互動、截圖
需要本機伺服器：cd <repo> && python3 -m http.server 8801
截圖存到第一個參數指定的資料夾（預設是目前資料夾）"""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import itertools, math, random, sys
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from dbscan import dbscan, NOISE
from playwright.sync_api import sync_playwright

U = 'http://127.0.0.1:8801/research/dbscan.html'
SHOT = sys.argv[1] if len(sys.argv) > 1 else '.'
random.seed(20261013)


def rand_points():
    """各種形狀混著來：均勻亂撒、幾團、月牙、圓環，偶爾有重疊的點"""
    kind = random.choice(['uniform', 'blobs', 'moons', 'rings', 'dup'])
    pts = []
    if kind == 'uniform':
        pts = [(random.randint(0, 127), random.randint(0, 127)) for _ in range(random.randint(0, 60))]
    elif kind == 'blobs':
        for _ in range(random.randint(1, 5)):
            cx, cy, sd = random.randint(15, 113), random.randint(15, 113), random.randint(3, 10)
            pts += [(round(random.gauss(cx, sd)), round(random.gauss(cy, sd))) for _ in range(random.randint(3, 18))]
        pts += [(random.randint(0, 127), random.randint(0, 127)) for _ in range(random.randint(0, 10))]
    elif kind == 'moons':
        for i in range(random.randint(10, 30)):
            t = math.pi * random.random(); r = 30 + random.uniform(-3, 3)
            pts.append((round(49 - r * math.cos(t)), round(66 - r * math.sin(t))))
            pts.append((round(79 + r * math.cos(t)), round(51 + r * math.sin(t))))
    elif kind == 'rings':
        for R, k in ((14, random.randint(5, 16)), (46, random.randint(10, 50))):
            for _ in range(k):
                t = 2 * math.pi * random.random()
                pts.append((round(64 + R * math.cos(t)), round(64 + R * math.sin(t))))
    else:
        base = [(random.randint(30, 50), random.randint(30, 50)) for _ in range(5)]
        pts = [random.choice(base) for _ in range(random.randint(2, 25))]
    pts = [(min(127, max(0, x)), min(127, max(0, y))) for x, y in pts]
    if random.random() < 0.5: random.shuffle(pts)      # 打亂順序，讓「先被看成雜訊、之後被收編」常常出現
    return pts, kind


def brute(pts, eps, m):
    """不跑佇列，直接從定義推出標籤：
    核心點 = ε 鄰居數 ≥ m；核心點用「距離 ≤ ε」連成的連通塊就是一群，
    群的編號照「塊裡最小的核心點編號」排；非核心點歸給它 ε 內核心點所屬群裡編號最小的，沒有就是雜訊"""
    n = len(pts)
    near = lambda a, b: (pts[a][0] - pts[b][0]) ** 2 + (pts[a][1] - pts[b][1]) ** 2 <= eps * eps
    core = [sum(near(i, j) for j in range(n)) >= m for i in range(n)]
    comp = [-1] * n
    for i in range(n):
        if core[i] and comp[i] < 0:
            stack, comp[i] = [i], i
            while stack:
                a = stack.pop()
                for b in range(n):
                    if core[b] and comp[b] < 0 and near(a, b):
                        comp[b] = i; stack.append(b)
    order = {c: k + 1 for k, c in enumerate(sorted({c for c in comp if c >= 0}))}
    label = [0] * n
    for i in range(n):
        if core[i]: label[i] = order[comp[i]]
        else:
            ids = [order[comp[j]] for j in range(n) if core[j] and near(i, j)]
            label[i] = min(ids) if ids else NOISE
    return label, core


def check_props(pts, eps, m, label):
    """獨立檢查性質：核心點一定有群、同群核心點彼此密度可達、不同群的核心點不相鄰、雜訊不在任何核心點 ε 內、邊界點在自己群某個核心點 ε 內"""
    n = len(pts)
    near = lambda a, b: (pts[a][0] - pts[b][0]) ** 2 + (pts[a][1] - pts[b][1]) ** 2 <= eps * eps
    core = [sum(near(i, j) for j in range(n)) >= m for i in range(n)]
    bad = 0
    for i in range(n):
        if core[i] and label[i] <= 0: bad += 1
        if label[i] == NOISE and any(core[j] and near(i, j) for j in range(n)): bad += 1
        if label[i] > 0 and not core[i] and not any(core[j] and label[j] == label[i] and near(i, j) for j in range(n)): bad += 1
    for c in set(l for l in label if l > 0):
        cs = [i for i in range(n) if core[i] and label[i] == c]
        if not cs: bad += 1; continue
        seen, stack = {cs[0]}, [cs[0]]          # 只踩核心點，看能不能走遍同群所有核心點
        while stack:
            a = stack.pop()
            for b in cs:
                if b not in seen and near(a, b): seen.add(b); stack.append(b)
        if len(seen) != len(cs): bad += 1
    for a, b in itertools.combinations(range(n), 2):
        if core[a] and core[b] and near(a, b) and label[a] != label[b]: bad += 1
    return bad


with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)

    # ---------- 1. 隨機交叉比對 ----------
    N = 400
    bad = {'js_vs_py': 0, 'py_vs_brute': 0, 'js_core_vs_brute': 0, 'props': 0, 'trace_steps': 0}
    stats = {'claims': 0, 'clusters': 0, 'noise_sets': 0, 'kinds': {}}
    for trial in range(N):
        pts, kind = rand_points()
        eps, m = random.randint(4, 30), random.randint(2, 10)
        js = pg.evaluate("""([P, e, m]) => {
            const points = P.map(([x, y]) => ({x, y}));
            const st = dbscanTrace(points, e, m);
            const fin = st[st.length - 1];
            // 每個點剛好被外層迴圈看一次（noise / core / skip），或在佇列裡被拿出來一次
            const visits = st.filter(s => ['noise', 'core', 'skip'].includes(s.kind)).length;
            return { label: fin.label, core: fin.core, claims: st.filter(s => s.kind === 'claim').length, visits };
        }""", [pts, eps, m])
        py = dbscan(pts, eps, m)
        br, core = brute(pts, eps, m)
        if js['label'] != py: bad['js_vs_py'] += 1
        if py != br: bad['py_vs_brute'] += 1
        if js['core'] != core: bad['js_core_vs_brute'] += 1
        if check_props(pts, eps, m, py): bad['props'] += 1
        if js['visits'] != len(pts): bad['trace_steps'] += 1
        stats['claims'] += js['claims'] > 0
        stats['clusters'] += max(py, default=0) >= 2
        stats['noise_sets'] += NOISE in py
        stats['kinds'][kind] = stats['kinds'].get(kind, 0) + 1
    print(f'[交叉比對] {N} 組隨機：', bad)
    print(f'  其中有收編雜訊 {stats["claims"]} 組、2 群以上 {stats["clusters"]} 組、有雜訊 {stats["noise_sets"]} 組，形狀', stats['kinds'])

    # ---------- 2. 換資料按鈕產生的形狀，用建議的參數分得對不對 ----------
    for act, want in (('moons', 2), ('rings', 2)):
        ok = 0
        for _ in range(30):
            ok += pg.evaluate(f"""() => {{ const g = GENERATORS.{act}(); const P = finish(g.raw);
                const st = dbscanTrace(P, g.e, g.m); return st[st.length - 1].c === {want}; }}""")
        print(f'[產生器] {act}：30 次裡分成 {want} 群的有 {ok} 次')
    ok = 0
    for _ in range(30):
        ok += pg.evaluate("""() => { const g = GENERATORS.blobs(); const P = finish(g.raw);
            const st = dbscanTrace(P, g.e, g.m); return st[st.length - 1].c >= 3; }""")
    print(f'[產生器] blobs：30 次裡分成 ≥3 群的有 {ok} 次')

    # ---------- 3. 從第一步按到最後一步：說明框高度、每個 .card 的位置都不能變 ----------
    def walk(page, label):
        page.goto(U); page.wait_for_timeout(3000)       # 等高度量完
        kinds, hs, sy, nohl, moved = {}, set(), set(), [], 0
        ref = None
        while True:
            st = page.evaluate("""() => [steps[cursor].kind, $('explain').offsetHeight, window.scrollY,
                [...document.querySelectorAll('#code .ln.hl')].length,
                [...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.height)]; })]""")
            kinds[st[0]] = kinds.get(st[0], 0) + 1; hs.add(st[1]); sy.add(st[2])
            if not st[3]: nohl.append(st[0])
            if ref is None: ref = st[4]
            elif st[4] != ref: moved += 1
            if page.is_disabled('#btn-next'): break
            page.click('#btn-next')
        print(f'[{label}] 步驟種類', kinds, '說明框高度', hs, '頁面 scrollY', sy, '沒有高亮', nohl or '無',
              f'，{len(ref)} 個 .card 位置有變的步驟數：{moved}')
        return moved

    walk(pg, '電腦 1280')

    # ---------- 4. 互動 ----------
    pg.goto(U); pg.wait_for_timeout(500)
    box = pg.locator('#map').bounding_box()
    w2px = lambda x, y: (box['x'] + (x + 1) / 130 * box['width'], box['y'] + (y + 1) / 130 * box['height'])
    pg.evaluate("$('map').scrollIntoView({block: 'center'})"); pg.wait_for_timeout(100)
    box = pg.locator('#map').bounding_box()
    n0 = pg.evaluate('pts.length')
    pg.mouse.click(*w2px(110, 110)); pg.wait_for_timeout(100)
    print('點空白處新增：', n0, '→', pg.evaluate('pts.length'), '，游標在', pg.evaluate('steps[cursor].kind'), '|', pg.inner_text('#hint'))
    pg.mouse.click(*w2px(110, 110)); pg.wait_for_timeout(100)
    print('再點同一點刪除：', pg.evaluate('pts.length'), '|', pg.inner_text('#hint'))
    pg.fill('#eps-range', '20'); pg.wait_for_timeout(100)
    print('ε=20：', pg.evaluate('[eps, steps[steps.length-1].c]'), '群')
    pg.click('#mp-plus'); pg.click('#mp-plus'); pg.click('#mp-minus')
    print('MinPts：', pg.inner_text('#mp-val'))
    for act in ('moons', 'rings', 'blobs'):
        pg.click(f'#tools [data-act={act}]'); pg.wait_for_timeout(100)
        print(f'換資料 {act}：', pg.evaluate('[pts.length, eps, minPts, steps[steps.length-1].c]'), '| k-means', pg.inner_text('#cap-km'))
    pg.click('#tools [data-act=clear]'); pg.click('#btn-last')
    print('清空：', pg.evaluate('pts.length'), pg.inner_text('#explain').split('\n')[1][:30])
    pg.click('#tools [data-act=reset]'); pg.wait_for_timeout(100)
    pg.click('.lang button[data-lang=py]')
    for _ in range(3): pg.keyboard.press('ArrowRight')
    print('鍵盤右鍵 3 次：步驟', pg.evaluate('cursor + 1'), 'Python 高亮行', pg.evaluate("[...document.querySelectorAll('#code .ln.hl')].map(l => +l.dataset.n)"))
    pg.click('#btn-play'); pg.wait_for_timeout(3200); pg.click('#btn-play')
    print('自動播放 3.2 秒後：步驟', pg.evaluate('cursor + 1'))
    print('pageerror:', errs)

    # ---------- 5. 截圖 ----------
    pg.goto(U); pg.wait_for_timeout(1500)
    while pg.evaluate("steps[cursor].kind !== 'claim'"): pg.click('#btn-next')
    pg.wait_for_timeout(700); pg.screenshot(path=f'{SHOT}/db_claim_d.png', full_page=True)
    pg.click('#tools [data-act=moons]'); pg.click('#btn-last'); pg.wait_for_timeout(700)
    pg.screenshot(path=f'{SHOT}/db_moons_d.png', full_page=True)

    for w in (375, 320):
        m = b.new_context(viewport={'width': w, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
        m.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        mp = m.new_page(); merrs = []
        mp.on('pageerror', lambda e: merrs.append(str(e)))
        walk(mp, f'手機 {w}')
        sw = [mp.evaluate('document.documentElement.scrollWidth')]
        mp.click('#btn-first')
        while mp.evaluate("steps[cursor].kind !== 'core'"): mp.click('#btn-next')
        mp.wait_for_timeout(600); mp.screenshot(path=f'{SHOT}/db_core_m{w}.png', full_page=True)
        mp.click('#tools [data-act=rings]'); mp.click('#btn-last'); mp.wait_for_timeout(600)
        sw.append(mp.evaluate('document.documentElement.scrollWidth'))
        mp.evaluate("$('explain').scrollIntoView()"); mp.wait_for_timeout(200); mp.screenshot(path=f'{SHOT}/db_rings_m{w}.png')
        print(f'手機 {w} scrollWidth', sw, ' pageerror:', merrs)
        m.close()
    b.close()
