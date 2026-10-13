import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys, itertools
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
import cantree as C
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片', '關東煮']   # 關東煮不在 ORDER 裡，測「排最後」的規則
U = 'http://127.0.0.1:8797/research/cantree.html'
SHOT = sys.argv[1] if len(sys.argv) > 1 else '.'


def brute(rows, ms):
    items = sorted(set().union(*rows)) if rows else []
    out = {}
    for r in range(1, len(items) + 1):
        for c in itertools.combinations(items, r):
            cnt = sum(1 for t in rows if set(c) <= t)
            if cnt >= ms:
                out[frozenset(c)] = cnt
    return out


def prefix_counts(rows):
    """暴力：每個（照標準順序排好的）前綴，有幾筆交易以它開頭"""
    out = {}
    for t in rows:
        p = sorted(t, key=C.rank)
        for k in range(1, len(p) + 1):
            out[tuple(p[:k])] = out.get(tuple(p[:k]), 0) + 1
    return out


def py_paths(tree):
    out = {}
    def walk(n, path):
        for c in n.children.values():
            out[tuple(path + [c.item])] = c.count
            walk(c, path + [c.item])
    walk(tree.root, [])
    return out


JS = """([db, nInit, ms, at]) => {
    const tr = buildTrace(db, nInit, ms, at);
    const mined = tr.find(s => s.kind === 'mined');
    const end = tr[tr.length - 1];
    const sumOk = end.tree.every(n => n.count >= end.tree.filter(c => c.parent === n.id).reduce((a, c) => a + c.count, 0))
        && end.tree.filter(n => n.parent === 0).reduce((a, n) => a + n.count, 0) === db.filter(t => t.length).length;
    return { res: mined.result.map(r => [r.set, r.count]), minedTree: treePaths(mined), endTree: treePaths(end),
             canNodes: end.canNodes, sumOk, minedAt: mined.minedAt };
}"""

with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page()
    errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U)
    pg.wait_for_timeout(800)

    # 1. 隨機（初始＋新增）資料：JS / Python / 暴力法的頻繁樣式與支持度；樹的每條路徑次數
    random.seed(2007)
    bad = dict(js_py=0, py_brute=0, js_tree=0, py_tree=0, sums=0, nodes=0)
    trials = 300
    for _ in range(trials):
        k = random.randint(2, 7)
        items = random.sample(ITEMS, k)
        nInit = random.randint(1, 10)
        nNew = random.randint(0, 8)
        db = [set(random.sample(items, random.randint(1, k))) for _ in range(nInit + nNew)]
        at = random.randint(1, len(db))
        ms = random.randint(1, max(1, at))
        part = db[:at]
        t = C.CanTree()
        for r in part: t.add(r)
        py = {frozenset(k2): v for k2, v in t.mine(ms).items()}
        bf = brute(part, ms)
        js = pg.evaluate(JS, [[sorted(r) for r in db], nInit, ms, at])
        jsr = {frozenset(s): c for s, c in js['res']}
        if jsr != py or len(js['res']) != len(jsr): bad['js_py'] += 1
        if py != bf: bad['py_brute'] += 1
        if {tuple(a): c for a, c in js['minedTree']} != prefix_counts(part) or {tuple(a): c for a, c in js['endTree']} != prefix_counts(db): bad['js_tree'] += 1
        if py_paths(t) != prefix_counts(part): bad['py_tree'] += 1
        if not js['sumOk']: bad['sums'] += 1
        t2 = C.CanTree()
        for r in db: t2.add(r)
        if t2.nodes != js['canNodes'] or t2.nodes != len(prefix_counts(db)): bad['nodes'] += 1
    print('random trials:', trials, 'mismatches:', bad)

    # 2. 從頭按到尾：說明框高度、每個 .card 的位置都不能變、高亮行有在框裡
    def walk(page, label):
        page.evaluate("window.scrollTo(0, 0)")
        page.evaluate("document.getElementById('btn-first').click()")
        rects, hs, kinds, vis, sws = set(), set(), [], True, set()
        while True:
            st = page.evaluate("""[JSON.stringify([...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.left), Math.round(r.height)]; })),
                document.getElementById('explain').offsetHeight, trace[cursor].kind, document.documentElement.scrollWidth,
                [...document.querySelectorAll('#code .ln.hl')].length]""")
            rects.add(st[0]); hs.add(st[1]); kinds.append(st[2]); sws.add(st[3])
            if st[4] == 0: vis = False
            if page.is_disabled('#btn-next'): break
            page.click('#btn-next')
        print(f'[{label}] steps {len(kinds)}, kinds {sorted(set(kinds))}, distinct card layouts {len(rects)}, explain heights {hs}, scrollWidth {sws}, every step has hl {vis}')

    walk(pg, '1280 預設批次')
    pg.click('#presets button:nth-child(3)'); pg.wait_for_timeout(3000)
    walk(pg, '1280 洋芋片爆紅')
    pg.click('#presets button:nth-child(1)'); pg.wait_for_timeout(3000)

    # 3. 互動：在第 10 筆挖、門檻、自己組交易、刪除、語言切換
    pg.evaluate("cursor = trace.findIndex(s => s.kind === 'insert' && s.row === 9); showStep()")
    pg.click('#btn-mine-here'); pg.wait_for_timeout(300)
    print('mine here ->', pg.inner_text('#at-val'), pg.evaluate('trace[cursor].kind'), '| kinds after mined:',
          pg.evaluate("trace.slice(trace.findIndex(s => s.kind === 'mined')).map(s => s.kind).join(',')"))
    pg.evaluate("cursor = trace.length - 1; showStep()")
    print('end explain:', pg.inner_text('#explain').split('\n', 1)[1])
    print('result note:', pg.inner_text('#result-note'))
    pg.click('#sup-minus'); print('minsup', pg.inner_text('#sup-val'), pg.evaluate('trace[cursor].kind'))
    for combo in (['洋芋片', '關東煮'][:1], ['茶葉蛋', '麵包']):
        for it in combo: pg.click(f'#picks .pick[data-item="{it}"]')
        pg.click('#btn-add')
    print('batch', pg.evaluate('batch.length'), 'cursor kind', pg.evaluate('trace[cursor].kind'), pg.evaluate('trace[cursor].row'))
    pg.click('#rows .del >> nth=0'); print('after del', pg.evaluate('batch.length'))
    pg.click('#lang button[data-lang=py]'); print('py hl', pg.evaluate("[...document.querySelectorAll('#code .ln.hl')].map(l=>+l.dataset.n)"))
    pg.click('#lang button[data-lang=java]')
    pg.evaluate("reset()"); pg.wait_for_timeout(3000)
    pg.evaluate("cursor = trace.findIndex(s => s.kind === 'insert' && s.fpChanged); showStep()"); pg.wait_for_timeout(600)
    pg.screenshot(path=f'{SHOT}/ct_desktop_insert.png', full_page=True)
    pg.evaluate("cursor = trace.findIndex(s => s.kind === 'base' && s.depth === 0 && s.item === '茶葉蛋'); showStep()"); pg.wait_for_timeout(600)
    pg.locator('.a-tree').screenshot(path=f'{SHOT}/ct_base.png')
    pg.evaluate("cursor = trace.findIndex(s => s.kind === 'build'); showStep()"); pg.wait_for_timeout(600)
    pg.screenshot(path=f'{SHOT}/ct_desktop_cond.png', full_page=True)
    print('errs', errs)

    # 4. 手機 375 / 320
    for w in (375, 320):
        m = b.new_context(viewport={'width': w, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
        m.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        mp = m.new_page()
        merrs = []
        mp.on('pageerror', lambda e: merrs.append(str(e)))
        mp.goto(U)
        mp.wait_for_timeout(3000)
        walk(mp, f'{w}px')
        mp.evaluate("cursor = trace.findIndex(s => s.kind === 'insert' && s.fpChanged); showStep()"); mp.wait_for_timeout(600)
        mp.screenshot(path=f'{SHOT}/ct_mobile{w}.png', full_page=True)
        print(w, 'errs', merrs)
    b.close()
