"""ir-tree.html 驗證：JS ↔ Python ↔ 暴力法隨機交叉比對（樹、查詢結果、統計、兩種比較做法）、
逐步走完（區塊位置不變、說明框高度固定、沒有水平捲動）、互動、截圖
需要本機伺服器：cd <repo> && python3 -m http.server 8812"""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from ir_tree import IRTree, Shop, filter_then_sort
from playwright.sync_api import sync_playwright

U = 'http://127.0.0.1:8812/research/ir-tree.html'
SHOT = os.environ.get('SHOT_DIR', '/tmp/ir-tree-shots')
os.makedirs(SHOT, exist_ok=True)
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
random.seed(20261016)


def rand_shops(n, span):
    lo = random.randint(0, 128 - span)
    pool = random.sample(ITEMS, random.randint(2, 6))       # 有時候只用少數幾種商品，關鍵字常常湊不齊
    return [[random.randint(lo, lo + span - 1), random.randint(lo, lo + span - 1),
             random.sample(pool, random.randint(1, min(3, len(pool))))] for _ in range(n)]


def py_ser(n):
    kids = [s.no for s in n.entries] if n.leaf else [py_ser(c) for c in n.entries]
    return [n.id, list(n.mbr), sorted(n.words), kids]


JS_SER = """(n) => { const f = n => [n.id, n.mbr, [...n.words].sort(), n.leaf ? n.entries.slice() : n.entries.map(f)]; return n ? f(n) : null; }"""

with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)
    pg.evaluate('() => { window.ser = ' + JS_SER + '; }')

    N = 400
    bad = {'tree': 0, 'js_vs_brute': 0, 'py_vs_brute': 0, 'stats': 0, 'nf_js': 0, 'nf_py': 0, 'fs_js': 0, 'fs_py': 0, 'trace': 0}
    empty_ans, short_ans, nokw, ties, heights = 0, 0, 0, 0, set()
    for trial in range(N):
        M = random.randint(3, 6)
        span = random.choice([128, 128, 24, 6])
        S = rand_shops(random.randint(0, 60), span)
        k = random.randint(1, 8)
        have = sorted({w for _, _, it in S for w in it}) or ITEMS
        # 大部分從地圖上有的商品挑（才有答案可以比），少數故意挑全部商品（考「根就湊不齊」）
        words = random.sample(have if random.random() < 0.85 else ITEMS, min(len(have), random.choice([1, 1, 2, 2, 3])))
        q = (random.randint(0, 127), random.randint(0, 127)) if span == 128 or trial % 3 == 0 else ((S[0][0], S[0][1]) if S else (5, 5))
        js = pg.evaluate("""([S, M, q, words, k]) => {
            shops = S.map(([x, y, it]) => ({ x, y, items: new Set(it) }));
            const t = buildTree(shops, M), Q = { x: q[0], y: q[1] }, W = new Set(words);
            const tr = irTrace(t, Q, W, k), last = tr[tr.length - 1];
            const nf = nearestThenFilter(t, Q, W, k), fs = filterThenSort(Q, W, k);
            // trace 自己的一致性：每一步的統計只會變大、答案依距離排好
            let ok = true;
            for (let i = 1; i < tr.length; i++) for (const key of ['opened', 'checked', 'skipped']) if (tr[i].st[key] < tr[i - 1].st[key]) ok = false;
            return { tree: ser(t.root), res: last.results.map(r => [r.j, r.d]), st: last.st, total: t.total, H: t.H,
                     nf: [nf.res.map(r => r.j), nf.opened, nf.checked], fs: [fs.res.map(r => r.j), fs.cand], ok, nokw: tr.some(s => s.fail) };
        }""", [S, M, list(q), words, k])
        objs = [Shop(x, y, it) for x, y, it in S]
        tree = IRTree(objs, M)
        if (py_ser(tree.root) if tree.root else None) != js['tree']: bad['tree'] += 1
        W = set(words)
        py = [[s.no, d] for s, d in tree.search(q, W, k)]
        st = (tree.opened, tree.checked, tree.skipped)
        cand = sorted(((x - q[0]) ** 2 + (y - q[1]) ** 2, i) for i, (x, y, it) in enumerate(S) if W <= set(it))
        brute = [[i, d] for d, i in cand[:k]]
        if len(cand) > k and cand[k - 1][0] == cand[k][0]: ties += 1
        if not brute: empty_ans += 1
        elif len(brute) < k: short_ans += 1
        nokw += js['nokw']
        heights.add(js['H'] + 1 if tree.root else 0)
        if js['res'] != brute: bad['js_vs_brute'] += 1
        if py != brute: bad['py_vs_brute'] += 1
        if (js['st']['opened'], js['st']['checked'], js['st']['skipped']) != st: bad['stats'] += 1
        nf = tree.nearest_then_filter(q, W, k)
        if js['nf'][0] != [i for i, _ in brute]: bad['nf_js'] += 1
        if [s.no for s, _ in nf] != [i for i, _ in brute] or js['nf'][1:] != [tree.opened, tree.checked]: bad['nf_py'] += 1
        fr, fc = filter_then_sort(objs, q, W, k)
        if js['fs'][0] != [i for i, _ in brute]: bad['fs_js'] += 1
        if [s.no for s, _ in fr] != [i for i, _ in brute] or js['fs'][1] != fc: bad['fs_py'] += 1
        if not js['ok']: bad['trace'] += 1
    print(f'[隨機交叉比對] {N} 組（答案是空的 {empty_ans} 組、不滿 k 家 {short_ans} 組、根就湊不齊關鍵字 {nokw} 組、第 k 名同距離 {ties} 組、樹高 {sorted(heights)}）：', bad)
    print('  全部一致：', not any(bad.values()), 'pageerror', errs)

    # ---------- 從頭走到尾：說明框高度、區塊位置、捲動、高亮 ----------
    def walk(page, label):
        if not page.is_disabled('#ir-first'): page.click('#ir-first')
        page.wait_for_timeout(100)
        hs, kinds, nohl, sy, pos = set(), {}, [], set(), set()
        while True:
            st = page.evaluate("""() => {
                const s = steps[cursor];
                const cards = [...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.left), Math.round(r.top + scrollY), Math.round(r.height)].join(','); }).join(' ');
                return [s.kind, $('ir-explain').offsetHeight, document.querySelectorAll('#ir-code .ln.hl').length, window.scrollY, cards];
            }""")
            hs.add(st[1]); kinds[st[0]] = kinds.get(st[0], 0) + 1; sy.add(st[3]); pos.add(st[4])
            if not st[2]: nohl.append(st[0])
            if page.is_disabled('#ir-next'): break
            page.click('#ir-next')
        print(f'  [{label}] {sum(kinds.values())} 步', kinds, '說明框高度', hs, '沒有高亮', nohl or '無', 'scrollY', sy, '區塊位置組合數', len(pos))
        return len(pos) == 1 and len(hs) == 1

    allok = True
    for w, h, mob in ((1280, 900, False), (375, 760, True), (320, 700, True)):
        c2 = b.new_context(viewport={'width': w, 'height': h}, is_mobile=mob, has_touch=mob, device_scale_factor=2 if mob else 1)
        c2.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        p2 = c2.new_page(); e2 = []
        p2.on('pageerror', lambda e: e2.append(str(e)))
        p2.goto(U); p2.wait_for_timeout(3000)
        print(f'寬 {w}：')
        allok &= walk(p2, '預設查詢')
        p2.click('#kw-box [data-w="飯糰"]'); p2.click('#kw-box [data-w="牛奶"]'); p2.wait_for_timeout(3000)
        allok &= walk(p2, '改成 ☕🍙')
        sw = p2.evaluate('document.documentElement.scrollWidth')
        print(f'  scrollWidth {sw}（視窗 {w}）pageerror', e2)
        allok &= sw == w and not e2
        c2.close()
    print('區塊位置與說明框高度全程不變、沒有水平捲動：', allok)

    # ---------- 互動 ----------
    pg.goto(U); pg.wait_for_timeout(800)
    pg.evaluate("$('ir-map').scrollIntoView({block: 'center'})"); pg.wait_for_timeout(100)
    box = pg.locator('#ir-map').bounding_box()
    w2px = lambda bb, x, y: (bb['x'] + (x + 7) / 142 * bb['width'], bb['y'] + (y + 7) / 142 * bb['height'])
    pg.mouse.click(*w2px(box, 20, 100)); pg.wait_for_timeout(100)
    print('點地圖換查詢點：', pg.evaluate('qPoint'), pg.inner_text('#ir-hint'))
    pg.click('#ir-last'); print('結果：', pg.inner_text('#ir-explain').split('\n')[1][:90])
    for w in ['牛奶']: pg.click(f'#kw-box [data-w="{w}"]')
    pg.click('#kw-box [data-w="咖啡"]'); print('取消最後一個關鍵字：', sorted(pg.evaluate('[...qWords]')), pg.inner_text('#ir-hint'))
    pg.click('#kw-box [data-w="洋芋片"]'); pg.click('#kw-box [data-w="茶葉蛋"]'); pg.click('#ir-last')
    print('☕🥚🥔：', pg.inner_text('#ir-explain').split('\n')[1][:90])
    pg.click('#k-plus'); pg.click('#m-plus'); print('k、M：', pg.inner_text('#k-val'), pg.inner_text('#m-val'), '節點數', pg.evaluate('tree.total'))
    if not pg.is_disabled('#ir-first'): pg.click('#ir-first')
    for _ in range(3): pg.keyboard.press('ArrowRight')
    print('鍵盤右鍵 3 次：步驟', pg.evaluate('cursor + 1'))
    pg.click('#ir-tools [data-act=random]'); pg.wait_for_timeout(100); print('隨機產生：', pg.evaluate('shops.length'), '家')
    pg.click('#ir-last'); print('隨機資料結果：', pg.inner_text('#ir-explain').split('\n')[1][:80])
    pg.click('#ir-tools [data-act=reset]')
    pg.click('[data-lang=py]'); pg.click('#ir-next'); print('Python 程式碼高亮行數：', pg.evaluate("document.querySelectorAll('#ir-code .ln.hl').length"))
    print('pageerror:', errs)

    # ---------- 截圖 ----------
    pg.goto(U); pg.wait_for_timeout(1500)
    for _ in range(3): pg.click('#ir-next')
    pg.wait_for_timeout(700); pg.screenshot(path=f'{SHOT}/ir_d.png', full_page=True)
    m = b.new_context(viewport={'width': 375, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
    m.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    mp = m.new_page()
    mp.goto(U); mp.wait_for_timeout(2500)
    for _ in range(4): mp.click('#ir-next')
    mp.wait_for_timeout(600)
    for el, nm in (('ir-explain', 'explain'), ('ir-map', 'map'), ('inv-rows', 'inv'), ('ir-tree', 'tree'), ('ir-queue', 'queue')):
        mp.evaluate(f"$('{el}').scrollIntoView()"); mp.wait_for_timeout(300); mp.screenshot(path=f'{SHOT}/ir_{nm}_m.png')
    b.close()
