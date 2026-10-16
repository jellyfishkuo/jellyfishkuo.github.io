"""skyline.html 驗證：JS ↔ Python ↔ 暴力法隨機交叉比對、Java ↔ Python 輸出、逐步走完（區塊位置不能動）、互動、截圖
需要本機伺服器：cd <repo> && python3 -m http.server 8803
截圖存到 SHOTS（預設 /tmp/skyline-shots，可用環境變數 SHOTS 改）"""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, subprocess, sys, tempfile
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from skyline import Point, bnl, sfs, dominates
from playwright.sync_api import sync_playwright

U = 'http://127.0.0.1:8803/research/skyline.html'
SHOTS = os.environ.get('SHOTS', '/tmp/skyline-shots')
os.makedirs(SHOTS, exist_ok=True)
random.seed(20261016)


def brute(V):
    """O(n²)：沒有被任何點支配的就是 skyline（重複的點互不支配，都留下）"""
    P = [Point(str(i), *v) for i, v in enumerate(V)]
    return sorted(i for i, p in enumerate(P) if not any(dominates(q, p) for q in P))


def rand_case(trial):
    d = 3 if trial % 5 == 4 else 2
    n = random.randint(0, 45)
    kind = trial % 4
    if kind == 0:     # 小格子：很多同值、重複的點
        V = [[random.randint(0, 5) for _ in range(d)] for _ in range(n)]
    elif kind == 1:   # 反相關：skyline 很大，小視窗一定溢出
        V = []
        for _ in range(n):
            t = random.randint(0, 30)
            V.append([t + random.randint(-3, 3), 30 - t + random.randint(-3, 3)] + [random.randint(0, 30) for _ in range(d - 2)])
    elif kind == 2:   # 相關
        V = []
        for _ in range(n):
            t = random.randint(0, 30)
            V.append([t + random.randint(-4, 4) for _ in range(d)])
    else:
        V = [[random.randint(0, 30) for _ in range(d)] for _ in range(n)]
    if V and random.random() < 0.3:   # 故意塞幾個完全重複的點
        for _ in range(random.randint(1, 4)): V.append(list(random.choice(V)))
    w = random.choice([1, 1, 2, 2, 3, 3, 4, 5, 6, 8, 100])
    return V, w


with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)

    # ---------- 1. 隨機交叉比對 ----------
    N = 600
    cases = [rand_case(t) for t in range(N)]
    js_all = pg.evaluate("""cases => cases.map(([V, w]) => {
        const a = bnlTrace(V, w), b = sfsTrace(V, w);
        const A = a[a.length - 1], B = b[b.length - 1];
        return [[A.sky, A.comps, A.passes], [B.sky, B.comps, B.passes]];
    })""", cases)
    bad = {'bnl_js_vs_py': 0, 'sfs_js_vs_py': 0, 'bnl_vs_brute': 0, 'sfs_vs_brute': 0, 'js_vs_brute': 0}
    overflow = multi = dup_in_sky = d3 = 0
    for (V, w), (jb, js) in zip(cases, js_all):
        P = [Point(str(i), *v) for i, v in enumerate(V)]
        idx = {id(p): i for i, p in enumerate(P)}
        pb, cb, sb = bnl(P, w)
        pf, cf, sf = sfs(P, w)
        pyb = [[idx[id(p)] for p in pb], cb, sb]
        pyf = [[idx[id(p)] for p in pf], cf, sf]
        br = brute(V)
        if jb != pyb: bad['bnl_js_vs_py'] += 1
        if js != pyf: bad['sfs_js_vs_py'] += 1
        if sorted(pyb[0]) != br: bad['bnl_vs_brute'] += 1
        if sorted(pyf[0]) != br: bad['sfs_vs_brute'] += 1
        if sorted(jb[0]) != br or sorted(js[0]) != br: bad['js_vs_brute'] += 1
        if len(br) > w: overflow += 1
        if sb > 1: multi += 1
        if len({tuple(V[i]) for i in br}) < len(br): dup_in_sky += 1
        if V and len(V[0]) == 3: d3 += 1
    print(f'[隨機] {N} 組：', bad, f'；skyline 比視窗大（溢出）{overflow} 組、BNL 讀超過一輪 {multi} 組、skyline 含重複點 {dup_in_sky} 組、三維 {d3} 組')

    # ---------- 2. Java ↔ Python ----------
    out = tempfile.mkdtemp()
    subprocess.run(['javac', '-encoding', 'UTF-8', '-d', out, REPO + '/research/code/Skyline.java'], check=True)
    jv = subprocess.run(['java', '-Dstdout.encoding=UTF-8', '-cp', out, 'Skyline'], capture_output=True, text=True, encoding='utf-8').stdout
    py = subprocess.run([sys.executable, '-B', REPO + '/research/code/skyline.py'], capture_output=True, text=True, encoding='utf-8').stdout
    print('[Java/Python] 輸出一致：', jv == py)
    print(py.rstrip())
    js_default = pg.evaluate("[bnlDone().comps, bnlDone().passes, sfsDone().comps, sfsDone().passes, bnlDone().sky.map(i => pts[i].label).join(' ')]")
    print('  網頁預設資料：', js_default)

    # ---------- 3. 從頭走到尾：說明框高度、每個區塊的位置都不能變 ----------
    def walk(page, label):
        page.wait_for_timeout(3000)       # 等區塊高度量完
        res = {}
        for tab in ('bnl', 'sfs'):
            page.click(f'#tab-{tab}'); page.wait_for_timeout(50)
            if not page.is_disabled('#first'): page.click('#first')
            heights, poses, kinds, nohl, sy = set(), set(), {}, [], set()
            while True:
                st = page.evaluate("""() => {
                    const s = traces[algo][cursors[algo]];
                    const cards = [...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.left), Math.round(r.height)].join(','); }).join('|');
                    return [s.kind, $('explain').offsetHeight, cards, document.querySelectorAll('#code .ln.hl').length, scrollY];
                }""")
                heights.add(st[1]); poses.add(st[2]); sy.add(st[4])
                kinds[st[0]] = kinds.get(st[0], 0) + 1
                if not st[3]: nohl.append(st[0])
                if page.is_disabled('#next'): break
                page.click('#next')
            res[tab] = poses
            print(f'[{label} {tab}] 步驟種類', kinds, '說明框高度', heights, '區塊位置組合數', len(poses), '沒有高亮', nohl or '無', 'scrollY', sy)
        print(f'[{label}] 兩個分頁的區塊位置一樣：', res['bnl'] == res['sfs'] and len(res['bnl']) == 1)

    pg.reload(); walk(pg, '電腦 1280')
    pg.click('#tab-bnl'); pg.click('#first')
    for _ in range(3): pg.click('#next')
    pg.wait_for_timeout(700)
    vis = pg.evaluate("""() => { const pre = $('code'); const r = pre.getBoundingClientRect();
        return [...pre.querySelectorAll('.ln.hl')].some(l => { const b = l.getBoundingClientRect(); return b.top >= r.top - 1 && b.bottom <= r.bottom + 1; }); }""")
    print('高亮行在程式碼框可視範圍內：', vis)

    # ---------- 4. 互動 ----------
    pg.goto(U); pg.wait_for_timeout(400)
    pg.evaluate("$('plot').scrollIntoView({block: 'center'})"); pg.wait_for_timeout(100)
    box = pg.locator('#plot').bounding_box()
    d2px = lambda x, y: (box['x'] + (40 + x * 290 / 300) / 340 * box['width'], box['y'] + (310 - y * 290 / 300) / 344 * box['height'])
    n0 = pg.evaluate('pts.length')
    pg.mouse.click(*d2px(40, 40)); pg.wait_for_timeout(100)
    print('點空白處新增：', n0, '→', pg.evaluate('pts.length'), pg.evaluate('pts[pts.length-1]'), '游標', pg.evaluate("[traces.bnl[cursors.bnl].kind, traces.bnl[cursors.bnl].p]"), pg.inner_text('#hint'))
    pg.evaluate("$('plot').scrollIntoView({block: 'center'})"); pg.wait_for_timeout(100)
    box = pg.locator('#plot').bounding_box()      # 新增後區塊高度會重新量，圖可能移動
    pg.mouse.click(*d2px(40, 40)); pg.wait_for_timeout(100)
    print('再點同一點刪除：', pg.evaluate('pts.length'), pg.inner_text('#hint'))
    for act in ('ind', 'cor', 'anti'):
        sizes = []
        for _ in range(5):
            pg.click(f'#tools [data-act={act}]'); pg.wait_for_timeout(30)
            sizes.append(pg.evaluate('bnlDone().sky.length'))
        print(f'隨機 {act}：skyline 大小', sizes, pg.inner_text('#hint'))
    pg.click('#tools [data-act=reset]')
    pg.click('#w-plus'); pg.click('#w-plus')
    print('視窗 5 格：', pg.evaluate("[winSize, bnlDone().passes, bnlDone().comps, sfsDone().passes, sfsDone().comps]"))
    for _ in range(4): pg.click('#w-minus')
    print('視窗最小：', pg.evaluate('winSize'), '按鈕停用', pg.is_disabled('#w-minus'))
    pg.click('#tools [data-act=clear]'); pg.click('#last')
    print('清空後：', pg.evaluate('pts.length'), pg.inner_text('#explain').split('\n')[1][:30])
    pg.click('#tools [data-act=reset]')
    for _ in range(3): pg.keyboard.press('ArrowRight')
    print('鍵盤右鍵 3 次：步驟', pg.evaluate('cursors[algo] + 1'))
    pg.click('.lang button[data-lang=py]')
    print('Python 程式碼高亮行數', pg.evaluate("document.querySelectorAll('#code .ln.hl').length"))
    print('pageerror:', errs)

    # ---------- 5. 截圖 ----------
    pg.goto(U); pg.wait_for_timeout(1500)
    pg.evaluate("cursors.bnl = traces.bnl.findIndex(s => s.kind === 'read' && s.kicked.length); show()")
    pg.wait_for_timeout(700); pg.screenshot(path=f'{SHOTS}/bnl_kick_d.png', full_page=True)
    pg.evaluate("cursors.bnl = traces.bnl.findIndex(s => s.kind === 'passend'); show()")
    pg.wait_for_timeout(700); pg.screenshot(path=f'{SHOTS}/bnl_passend_d.png', full_page=True)
    pg.click('#tab-sfs'); pg.evaluate("cursors.sfs = 8; show()")
    pg.wait_for_timeout(700); pg.screenshot(path=f'{SHOTS}/sfs_read_d.png', full_page=True)
    pg.click('#last'); pg.wait_for_timeout(700); pg.screenshot(path=f'{SHOTS}/sfs_end_d.png', full_page=True)

    for width in (375, 320):
        m = b.new_context(viewport={'width': width, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
        m.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        mp = m.new_page(); merrs = []
        mp.on('pageerror', lambda e: merrs.append(str(e)))
        mp.goto(U)
        sw = [mp.evaluate('document.documentElement.scrollWidth')]
        if width == 375: walk(mp, '手機 375')
        else: mp.wait_for_timeout(1500)
        mp.click('#tab-bnl')
        mp.evaluate("cursors.bnl = traces.bnl.findIndex(s => s.kind === 'read' && s.confirmed.length); show()")
        mp.wait_for_timeout(600)
        sw.append(mp.evaluate('document.documentElement.scrollWidth'))
        mp.screenshot(path=f'{SHOTS}/bnl_m{width}.png', full_page=True)
        mp.evaluate('scrollTo(0, 0)'); mp.wait_for_timeout(200); mp.screenshot(path=f'{SHOTS}/top_m{width}.png')
        mp.evaluate("scrollTo(0, $('plot').getBoundingClientRect().top + scrollY - 60)"); mp.wait_for_timeout(200); mp.screenshot(path=f'{SHOTS}/plot_m{width}.png')
        mp.evaluate("scrollTo(0, $('slots').getBoundingClientRect().top + scrollY - 80)"); mp.wait_for_timeout(200); mp.screenshot(path=f'{SHOTS}/box_m{width}.png')
        mp.click('#tab-sfs'); mp.evaluate('cursors.sfs = traces.sfs.length - 1; show()'); mp.wait_for_timeout(500)
        sw.append(mp.evaluate('document.documentElement.scrollWidth'))
        mp.evaluate("scrollTo(0, $('plot').getBoundingClientRect().top + scrollY - 60)"); mp.wait_for_timeout(200); mp.screenshot(path=f'{SHOTS}/sfs_end_m{width}.png')
        # 手指點一下圖新增
        bb = mp.locator('#plot').bounding_box()
        n0 = mp.evaluate('pts.length')
        mp.tap('#plot', position={'x': bb['width'] * 0.5, 'y': bb['height'] * 0.5}); mp.wait_for_timeout(200)
        print(f'[手機 {width}] scrollWidth', sw, '手指點圖新增', n0, '→', mp.evaluate('pts.length'), 'pageerror', merrs)
        m.close()
    b.close()
