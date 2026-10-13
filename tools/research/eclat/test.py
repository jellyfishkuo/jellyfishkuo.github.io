import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys
from itertools import combinations
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from eclat import eclat
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:8792/research/eclat.html'
SHOT = sys.argv[1] if len(sys.argv) > 1 else '.'


def brute(db, ms):
    """暴力法：列出所有商品組合，一個一個數"""
    items = sorted(set().union(*db))
    out = {}
    for k in range(1, len(items) + 1):
        for c in combinations(items, k):
            n = sum(1 for t in db if set(c) <= t)
            if n >= ms:
                out[frozenset(c)] = n
    return out


with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route('**/fonts.googleapis.com/**', lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)

    # 1. 隨機資料：網頁 JS、Python 版、暴力法三方比對（樣式與支持度）
    bad = 0; trials = 300
    for trial in range(trials):
        rows = random.randint(3, 12)
        db = [set(random.sample(ITEMS, random.randint(1, 6))) for _ in range(rows)]
        ms = random.randint(1, rows)
        py = {frozenset(k): v for k, v in eclat(db, ms).items()}
        bf = brute(db, ms)
        got = pg.evaluate("([d,m])=>{const tr=buildTrace(d,m);return tr[tr.length-1].result.map(r=>[r.set,r.count])}", [[sorted(t) for t in db], ms])
        js = {frozenset(s): c for s, c in got}
        order_js = [tuple(s) for s, _ in got]
        order_py = list(eclat(db, ms).keys())
        if js != py or py != bf or len(got) != len(js) or order_js != order_py:
            bad += 1
    print(f'random trials {trials}, mismatches: {bad}')

    # 2. 範例資料從頭走到尾
    pg.reload(); pg.wait_for_timeout(400)
    seen = []
    while True:
        st = pg.evaluate("[trace[cursor].kind, trace[cursor].depth, document.getElementById('explain').offsetHeight, document.getElementById('cls').offsetHeight, [...document.querySelectorAll('#code .ln.hl')].map(l=>+l.dataset.n), window.scrollY]")
        seen.append(st)
        if pg.is_disabled('#btn-next'): break
        pg.click('#btn-next')
    kinds = {}
    for s in seen: kinds[s[0]] = kinds.get(s[0], 0) + 1
    print('steps', len(seen), kinds)
    print('explain heights', set(s[2] for s in seen), 'class heights', set(s[3] for s in seen), 'page scrollY', set(s[5] for s in seen))
    print('no-highlight steps', [s[0] for s in seen if not s[4]])
    print('result', pg.inner_text('#levels').replace('\n', ' '))
    print('cmp', pg.inner_text('#cmp').replace('\n', ' | '))
    pg.screenshot(path=f'{SHOT}/ec_end.png', full_page=True)

    def goto(cond):
        pg.evaluate("cursor=0;showStep()")
        while not pg.evaluate(cond): pg.click('#btn-next')
    goto("trace[cursor].kind==='scan'&&trace[cursor].row===2"); pg.screenshot(path=f'{SHOT}/ec_scan.png', full_page=True)
    goto("trace[cursor].kind==='inter'&&trace[cursor].depth===1"); pg.screenshot(path=f'{SHOT}/ec_desktop.png', full_page=True)
    pg.click('#lang button[data-lang=py]'); print('py hl', pg.evaluate("[...document.querySelectorAll('#code .ln.hl')].map(l=>+l.dataset.n)"))
    pg.locator('.pat').first.click(); print('pat hint:', pg.inner_text('#res-hint'), '| matched rows', pg.locator('tr.match').count())
    # 3. 編輯與門檻
    pg.click('#btn-edit'); pg.click('.cell[data-r="6"][data-i="咖啡"]'); pg.click('#sup-minus')
    print('after edit minsup', pg.inner_text('#sup-val'), pg.evaluate("trace.length"), pg.inner_text('#cmp').replace('\n', ' | '))
    print('errs', errs)

    for w in (375, 320):
        mctx = b.new_context(viewport={'width': w, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
        mctx.route('**/fonts.googleapis.com/**', lambda r: r.abort())
        m = mctx.new_page(); merr = []; m.on('pageerror', lambda e: merr.append(str(e)))
        m.goto(U); m.wait_for_timeout(500)
        mx = 0
        n = m.evaluate('trace.length')
        for i in range(n - 1):
            m.click('#btn-next'); mx = max(mx, m.evaluate('document.documentElement.scrollWidth'))
            if i == 13: m.screenshot(path=f'{SHOT}/ec_mobile{w}.png', full_page=True)
        print(w, 'max scrollWidth over all steps', mx, 'errs', merr)
        mctx.close()
    b.close()
