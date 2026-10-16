"""IHUP 頁的測試：隨機資料＋隨機新增序列，每次挖的結果跟 Python 版、暴力法比對；再從頭按到尾檢查版面。
需要本機伺服器：cd <repo> && python3 -m http.server 8814；截圖資料夾當第一個參數（不要放在 repo 裡）"""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys, itertools
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
import ihup as IH
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片', '關東煮']   # 關東煮不在 ORDER 裡，測「排最後」的規則
U = 'http://127.0.0.1:8814/research/ihup.html'
SHOT = sys.argv[1] if len(sys.argv) > 1 else None
TRIALS = int(os.environ.get("TRIALS", 320))


def tu(t, profit):
    return sum(q * profit[i] for i, q in t.items())


def brute(rows, profit, mu):
    """所有組合：真正效益夠的（高效益樣式）、TWU 夠的（候選）"""
    items = sorted(set().union(*[set(t) for t in rows])) if rows else []
    hui, cand = {}, {}
    for r in range(1, len(items) + 1):
        for c in itertools.combinations(items, r):
            ts = [t for t in rows if all(i in t for i in c)]
            if not ts:
                continue
            u = sum(sum(t[i] * profit[i] for i in c) for t in ts)
            w = sum(tu(t, profit) for t in ts)
            if u >= mu: hui[frozenset(c)] = u
            if w >= mu: cand[frozenset(c)] = w
    return hui, cand


def prefix_stats(rows, profit):
    """暴力：每個（照字典序排好的）前綴，有幾筆交易以它開頭、TU 加起來多少"""
    out = {}
    for t in rows:
        p = sorted(t, key=IH.rank)
        for k in range(1, len(p) + 1):
            c, w = out.get(tuple(p[:k]), (0, 0))
            out[tuple(p[:k])] = (c + 1, w + tu(t, profit))
    return out


JS = """([db, nInit, profit, mu, plan]) => {
    const tr = buildTrace(db, nInit, profit, mu, plan);
    const end = tr[tr.length - 1];
    return { mines: tr.mines, tree: treePaths(end), nodes: end.nodes, kinds: [...new Set(tr.map(s => s.kind))] };
}"""

POS = "JSON.stringify([...document.querySelectorAll('.card')].map(c=>{const r=c.getBoundingClientRect();return [Math.round(r.left),Math.round(r.top+scrollY),Math.round(r.height)]}))"


def walk(pg, label):
    """從第一步按到最後一步：每個 .card 的位置和高度都不能變；高亮行要在程式碼框看得到的範圍"""
    pg.evaluate("window.scrollTo(0, 0)")
    pg.evaluate("document.getElementById('btn-first').click()")
    pos, widths, hs, kinds, nohl, n = set(), set(), set(), set(), 0, 0
    while True:
        st = pg.evaluate(f"""[{POS}, document.documentElement.scrollWidth, document.getElementById('explain').offsetHeight, trace[cursor].kind,
            [...document.querySelectorAll('#code .ln.hl')].length]""")
        pos.add(st[0]); widths.add(st[1]); hs.add(st[2]); kinds.add(st[3]); n += 1
        if st[4] == 0: nohl += 1
        if pg.is_disabled('#btn-next'): break
        pg.click('#btn-next')
    print(f'[{label}] steps {n}, kinds {sorted(kinds)}, distinct card layouts {len(pos)}, explain heights {hs}, scrollWidth {widths}, steps without hl {nohl}')
    return len(pos)


with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page()
    errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U)
    pg.wait_for_timeout(800)

    # 1. 隨機資料＋隨機新增序列＋隨機挖的時間點：每次挖都要跟 Python、暴力法一致
    random.seed(2009)
    bad = dict(js_py=0, js_brute=0, cands=0, tree=0, nodes=0)
    mines_checked = nonempty = 0
    for _ in range(TRIALS):
        k = random.randint(2, 7)
        items = random.sample(ITEMS, k)
        profit = {i: random.randint(1, 40) for i in ITEMS}
        nInit = random.randint(1, 10)
        nNew = random.randint(0, 8)
        db = [{i: random.randint(1, 5) for i in random.sample(items, random.randint(1, k))} for _ in range(nInit + nNew)]
        plan = sorted(random.sample(range(1, len(db) + 1), random.randint(1, min(4, len(db)))))
        total = sum(tu(t, profit) for t in db)
        mu = random.randint(1, max(1, total // 2))
        js = pg.evaluate(JS, [db, nInit, profit, mu, plan])
        tree = IH.IHUPTree(profit)
        ji = 0
        for at, t in enumerate(db, 1):
            tree.add(t)
            if at in plan:
                m = js['mines'][ji]; ji += 1
                assert m['at'] == at
                py = {frozenset(c): u for c, u in tree.mine(mu).items()}
                hui, cand = brute(db[:at], profit, mu)
                jr = {frozenset(s): u for s, u in m['result']}
                jc = {frozenset(s): w for s, w in m['cands']}
                if jr != py: bad['js_py'] += 1
                if jr != hui: bad['js_brute'] += 1; print('MISMATCH', db[:at], profit, mu, jr, hui)
                if jc != cand or len(jc) != len(m['cands']): bad['cands'] += 1
                mines_checked += 1; nonempty += bool(hui)
        if ji != len(js['mines']): bad['js_py'] += 1
        ps = prefix_stats(db, profit)
        if {tuple(pth): (c, w) for pth, c, w in js['tree']} != ps: bad['tree'] += 1
        if js['nodes'] != len(ps) or tree.nodes != len(ps): bad['nodes'] += 1
    print(f'random trials {TRIALS}, mines checked {mines_checked} (non-empty {nonempty}), mismatches {bad}')

    # 2. 預設資料從頭按到尾
    pg.reload(); pg.wait_for_timeout(5000)
    layouts = {'1280': walk(pg, '1280 預設')}
    print('end explain:', pg.inner_text('#explain').split('\n', 1)[1])
    print('compare:', pg.inner_text('#compare').replace('\n', ' | '))

    # 3. 互動：門檻、加交易、在這筆後挖、取消、刪掉、預設組、語言
    pg.click('#mu-plus'); print('mu', pg.inner_text('#mu-val'), pg.evaluate('trace[cursor].kind'))
    for it in ('茶葉蛋', '茶葉蛋', '洋芋片'): pg.click(f'#picks .pick[data-item="{it}"]')
    pg.click('#btn-add')
    print('added ->', pg.evaluate('JSON.stringify(batch[batch.length-1])'), pg.evaluate('trace[cursor].kind'), pg.evaluate('trace[cursor].row'))
    pg.click('#btn-mine-here'); pg.wait_for_timeout(200)
    print('mine here ->', pg.inner_text('#mine-list'), pg.evaluate('trace[cursor].kind'), pg.evaluate('trace[cursor].ins'))
    pg.evaluate("cursor = trace.findIndex(s => s.kind === 'insert' && s.row === 9); showStep()")
    pg.click('#btn-mine-here'); print('mine at 10 ->', pg.inner_text('#mine-list'))
    pg.evaluate("cursor = trace.findIndex(s => s.kind === 'insert' && s.row === 9); showStep()")
    pg.click('#btn-mine-here'); print('cancel ->', pg.inner_text('#mine-list'), pg.evaluate('trace[cursor].kind'))
    pg.click('#btn-undo'); print('after undo', pg.evaluate('batch.length'))
    pg.click('#lang button[data-lang=py]'); print('py hl', pg.evaluate("[...document.querySelectorAll('#code .ln.hl')].map(l=>+l.dataset.n)"))
    pg.click('#lang button[data-lang=java]')
    for i in (2, 3):
        pg.click(f'#presets button:nth-child({i})'); pg.wait_for_timeout(5000)
        layouts[f'preset{i}'] = walk(pg, f'1280 預設組 {i}')
    for mu in (50, 120, 400, 800):
        pg.evaluate("m => setMinUtil(m)", mu)
        while not pg.is_disabled('#btn-next'): pg.click('#btn-next')
    pg.evaluate("reset()"); pg.wait_for_timeout(5000)
    if SHOT:
        pg.evaluate("cursor = trace.findIndex(s => s.kind === 'insert' && s.twuChanged); showStep()"); pg.wait_for_timeout(700)
        pg.screenshot(path=f'{SHOT}/desk_insert.png', full_page=True)
        pg.evaluate("cursor = trace.findIndex(s => s.kind === 'count' && s.depth === 1 && s.order.length); showStep()"); pg.wait_for_timeout(700)
        pg.screenshot(path=f'{SHOT}/desk_cond.png', full_page=True)
        pg.evaluate("cursor = trace.length - 1 - [...trace].reverse().findIndex(s => s.kind === 'mined'); showStep()"); pg.wait_for_timeout(700)
        pg.screenshot(path=f'{SHOT}/desk_mined.png', full_page=True)

    # 4. 手機 375 / 320
    for w in (375, 320):
        m = b.new_context(viewport={'width': w, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
        m.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        mp = m.new_page()
        mp.on('pageerror', lambda e: errs.append(str(e)))
        mp.goto(U)
        mp.wait_for_timeout(5000)
        layouts[w] = walk(mp, f'{w}px')
        if SHOT:
            for name, q in (('insert', "s.kind === 'insert' && s.twuChanged"), ('pattern', "s.kind === 'pattern' && s.depth === 1"), ('mined', "s.kind === 'mined'")):
                mp.evaluate(f"cursor = trace.findIndex(s => {q}); showStep()"); mp.wait_for_timeout(700)
                for k, sel in enumerate(('.a-step', '.a-tree', '.a-work', '.a-data', '.a-result')):
                    if name != 'insert' and k > 2 and sel != '.a-result': continue
                    mp.locator(sel).screenshot(path=f'{SHOT}/m{w}_{name}_{k}.png')
        m.close()
    print('card layouts per walk (must all be 1):', layouts)
    print('errs', errs)
    b.close()
