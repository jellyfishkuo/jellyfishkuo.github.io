"""週期性頻繁樣式（PFP-tree）Demo 的測試：
1. 隨機資料：網頁 JS、Python 版、暴力法（枚舉所有組合算支持度與週期）三方比對
2. 從頭按到尾：沒有 pageerror、說明框高度固定、每個 .card 的位置都不變、每一步都有高亮行
3. 互動：門檻、編輯資料、點結果看時間軸、切換語言
4. 手機 375 / 320 不能水平捲動
需要本機伺服器：cd <repo> && python3 -m http.server 8811
用法：python3 -B test.py [截圖資料夾]
"""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys, itertools
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from periodic_fp import pfp_growth
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:8811/research/periodic.html'
SHOT = sys.argv[1] if len(sys.argv) > 1 else '.'


def brute(db, ms, mp):
    n = len(db)
    items = sorted(set().union(*db))
    out = {}
    for r in range(1, len(items) + 1):
        for c in itertools.combinations(items, r):
            tids = [k + 1 for k, t in enumerate(db) if set(c) <= t]
            if not tids:
                continue
            gaps = [b - a for a, b in zip([0] + tids, tids + [n])]
            if len(tids) >= ms and max(gaps) <= mp:
                out[frozenset(c)] = (len(tids), max(gaps))
    return out


with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page()
    errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U)
    pg.wait_for_timeout(800)

    # 1. 隨機資料交叉比對
    random.seed(2009)
    trials, bad = 400, dict(js_py=0, py_brute=0, js_tids=0)
    nonempty = 0
    for _ in range(trials):
        rows = random.randint(3, 12)
        k = random.randint(2, 6)
        items = random.sample(ITEMS, k)
        db = [set(random.sample(items, random.randint(1, k))) for _ in range(rows)]
        ms = random.randint(1, rows)
        mp = random.randint(1, rows)
        py = {frozenset(s): v for s, v in pfp_growth(db, ms, mp).items()}
        bf = brute(db, ms, mp)
        got = pg.evaluate("([d,m,q])=>{const tr=buildTrace(d,m,q);return tr[tr.length-1].result.map(r=>[r.set,r.sup,r.per,r.tids])}", [[sorted(t) for t in db], ms, mp])
        js = {frozenset(s): (c, q) for s, c, q, _ in got}
        if js != py or len(got) != len(js): bad['js_py'] += 1
        if py != bf: bad['py_brute'] += 1
        if any(t != [i + 1 for i, row in enumerate(db) if set(s) <= row] for s, _, _, t in got): bad['js_tids'] += 1
        if bf: nonempty += 1
    print(f'random trials: {trials} (non-empty results {nonempty}), mismatches: {bad}')

    # 2. 從頭按到尾
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
        return kinds

    pg.wait_for_timeout(3000)
    kinds = walk(pg, '1280 範例')
    from collections import Counter
    print('kind counts', dict(Counter(kinds)))
    print('end explain:', pg.inner_text('#explain').split('\n', 1)[1])
    print('compare:', pg.inner_text('#compare'))
    for ms, mp in ((2, 2), (1, 8), (4, 4)):
        pg.evaluate(f"minSup={ms}; maxPer={mp}; rebuild(false)"); pg.wait_for_timeout(3000)
        walk(pg, f'1280 minSup={ms} maxPer={mp}')
    pg.evaluate("db = SAMPLE.map(t => t.slice()); minSup = 3; maxPer = 3; rebuild(false)"); pg.wait_for_timeout(3000)

    # 3. 互動
    pg.evaluate("cursor = trace.length - 1; showStep()")
    pg.click('.pat >> nth=4'); print('focus ->', pg.inner_text('#tl-sub'), '| rows', pg.locator('#timeline .tl-row').count())
    pg.screenshot(path=f'{SHOT}/pf_desktop_end.png', full_page=True)
    pg.click('#per-minus'); print('maxPer', pg.inner_text('#per-val'), 'result count', pg.evaluate('trace[trace.length-1].result.length'))
    pg.click('#per-plus')
    pg.click('#lang button[data-lang=py]'); pg.evaluate("cursor = trace.findIndex(s => s.kind === 'push'); showStep()")
    print('py push hl', pg.evaluate("[...document.querySelectorAll('#code .ln.hl')].map(l=>+l.dataset.n)"))
    pg.click('#lang button[data-lang=java]')
    pg.click('#btn-edit'); pg.click('.cell[data-r="6"][data-i="咖啡"]'); pg.click('#btn-add-row')
    print('after edit: rows', pg.evaluate('db.length'), 'explain', pg.inner_text('#explain')[:30].replace('\n', ' '))
    pg.screenshot(path=f'{SHOT}/pf_desktop_edit.png', full_page=True)
    pg.click('#btn-reset-db'); pg.click('#btn-edit'); pg.wait_for_timeout(3000)
    for cond, name in (("trace[cursor].kind==='count'&&trace[cursor].depth===0", 'count'),
                       ("trace[cursor].kind==='insert'&&trace[cursor].row===5", 'insert'),
                       ("trace[cursor].kind==='pattern'&&trace[cursor].item==='茶葉蛋'&&trace[cursor].depth===0", 'pattern'),
                       ("trace[cursor].kind==='push'&&trace[cursor].item==='牛奶'&&trace[cursor].depth===0", 'push'),
                       ("trace[cursor].kind==='build'", 'build')):
        pg.evaluate(f"cursor = trace.findIndex(()=>false); for (cursor=0; cursor<trace.length && !({cond}); cursor++); showStep()")
        pg.wait_for_timeout(500)
        pg.screenshot(path=f'{SHOT}/pf_desktop_{name}.png', full_page=True)
    print('errs', errs)

    # 4. 手機
    for w in (375, 320):
        m = b.new_context(viewport={'width': w, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
        m.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        mp_ = m.new_page()
        merrs = []
        mp_.on('pageerror', lambda e: merrs.append(str(e)))
        mp_.goto(U)
        mp_.wait_for_timeout(3000)
        walk(mp_, f'{w}px')
        mp_.evaluate("for (cursor=0; !(trace[cursor].kind==='pattern'&&trace[cursor].item==='牛奶'&&trace[cursor].depth===0); cursor++); showStep()")
        mp_.wait_for_timeout(600)
        mp_.screenshot(path=f'{SHOT}/pf_mobile{w}.png', full_page=True)
        mp_.click('#btn-edit'); mp_.wait_for_timeout(2500)
        print(w, 'edit-mode scrollWidth', mp_.evaluate('document.documentElement.scrollWidth'))
        print(w, 'errs', merrs)
    b.close()
