import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys
from itertools import combinations
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from sliding_window import SlidingWindow
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:8783/research/sliding-window.html'
HL = "[...document.querySelectorAll('#code .ln.hl')].map(l=>+l.dataset.n)"


def brute(window, ms):
    """直接對當下視窗重算：列舉所有可能的組合，數它在視窗裡出現幾次"""
    cnt = {}
    for k in range(1, 7):
        for s in combinations(sorted(ITEMS), k):
            c = sum(1 for t in window if set(s) <= set(t))
            if c: cnt[s] = c
    f = {s: c for s, c in cnt.items() if c >= ms}
    m = {s: c for s, c in f.items() if not any(set(s) < set(o) for o in f)}
    return cnt, f, m


with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)

    # 1. 隨機串流：每一步 JS 計數表 / 頻繁 / 最大頻繁 vs Python 版 vs 直接重算
    random.seed(7)
    bad = steps = 0
    for trial in range(250):
        n = random.randint(30, 45)
        stream = [random.sample(ITEMS, random.randint(1, 6)) for _ in range(n)]
        W = random.randint(1, 10); ms = random.randint(1, W + 1)
        js = pg.evaluate("([s,w,m])=>simulate(s,w,m)", [stream, W, ms])
        sw = SlidingWindow(W, ms)
        assert len(js) == n
        for i, t in enumerate(stream):
            sw.add(t)
            cnt, f, m = brute(stream[max(0, i + 1 - W):i + 1], ms)
            jc = {tuple(s): c for s, c in js[i]['counts']}
            jf = {tuple(s): c for s, c in js[i]['freq']}
            jm = {tuple(s): c for s, c in js[i]['max']}
            ok = (jc == cnt == sw.count and jf == f == sw.frequent() and jm == m == sw.maximal())
            steps += 1
            if not ok: bad += 1
    print(f'random: 250 streams, {steps} steps, mismatches: {bad}')

    # 2. 範例串流從頭按到尾
    pg.reload(); pg.wait_for_timeout(400)
    seen = []
    while True:
        st = pg.evaluate("[trace[cursor].kind, trace[cursor].arrival, window.scrollY, document.getElementById('explain').offsetHeight, " + HL + "]")
        seen.append(st)
        if pg.is_disabled('#btn-next'): break
        pg.click('#btn-next'); pg.wait_for_timeout(20)
    kinds = {}
    for k, a, y, h, hl in seen:
        kinds.setdefault(k, set()).add((hl[0], hl[-1], len(hl)) if hl else None)
    print('steps', len(seen), 'explain heights', set(s[3] for s in seen), 'scrollY', set(s[2] for s in seen))
    print('no-highlight steps', [s[:2] for s in seen if not s[4]])
    for k, v in kinds.items(): print(' ', k, sorted(v, key=str))
    pg.click('#lang button[data-lang=py]')
    pg.click('#btn-first')
    pyk = {}
    for i in range(10):
        pg.click('#btn-next'); pyk.setdefault(pg.evaluate('trace[cursor].kind'), pg.evaluate(HL))
    print('py hl', pyk)
    pg.click('#lang button[data-lang=java]')

    # 3. 互動：W / minSup / 篩選 / 選樣式 / 自己加一筆
    pg.click('#btn-first')
    for i in range(20): pg.click('#btn-next')
    before = pg.evaluate("[trace[cursor].arrival, trace[cursor].kind]")
    pg.click('#w-plus'); pg.click('#sup-minus')
    print('after W+ / sup-: ', pg.inner_text('#w-val'), pg.inner_text('#sup-val'), before, '->', pg.evaluate("[trace[cursor].arrival, trace[cursor].kind]"))
    pg.click('#filter button[data-f=all]'); print('all rows', pg.locator('.trow').count(), '|', pg.inner_text('#tbl-foot'))
    pg.click('#filter button[data-f=freq]'); print('freq rows', pg.locator('.trow').count())
    pg.locator('.trow').nth(1).click(); print('selected', pg.evaluate('selKey'), pg.inner_text('#chart-cap')[:40])
    pg.select_option('#pick-pattern', '咖啡|麵包'); print('picked', pg.evaluate('selKey'), 'belt hits', pg.locator('.slot.hit').count())
    pg.click('#btn-reset-stream')
    pg.click('.pick >> nth=3'); pg.click('.pick >> nth=4'); pg.click('#btn-append')
    print('appended', pg.evaluate('stream.length'), pg.inner_text('#add-hint')[:30])
    pg.evaluate("cursor=trace.length-1;showStep()")
    print('end step', pg.inner_text('#explain')[:60])
    pg.click('#btn-play'); pg.wait_for_timeout(3300); print('autoplay at', pg.evaluate('cursor'), pg.inner_text('#btn-play')); pg.click('#btn-play')
    pg.keyboard.press('ArrowRight'); pg.keyboard.press('ArrowLeft')

    # 截圖
    pg.click('#btn-reset-stream')
    def goto(cond):
        pg.evaluate("cursor=0;showStep(false)")
        while not pg.evaluate(cond): pg.click('#btn-next')
        pg.wait_for_timeout(700)
    goto("trace[cursor].kind==='add'&&trace[cursor].arrival===11"); pg.screenshot(path='sw_add.png', full_page=True)
    goto("trace[cursor].kind==='expire'&&trace[cursor].arrival===11"); pg.locator('.stream-card').screenshot(path='sw_expire_belt.png')
    pg.locator('#tbl').screenshot(path='sw_expire_tbl.png')
    goto("trace[cursor].kind==='update'&&trace[cursor].arrival===20"); pg.screenshot(path='sw_desktop.png', full_page=True)
    print('errs', errs)

    # 手機
    m = b.new_context(viewport={'width': 375, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
    m.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    mp = m.new_page(); merrs = []; mp.on('pageerror', lambda e: merrs.append(str(e)))
    mp.goto(U); mp.wait_for_timeout(500)
    sws = set(); hs = set()
    while True:
        sws.add(mp.evaluate('document.documentElement.scrollWidth')); hs.add(mp.evaluate("document.getElementById('explain').offsetHeight"))
        if mp.is_disabled('#btn-next'): break
        mp.click('#btn-next')
    for i in range(3): mp.click('#w-plus')
    mp.click('.pick >> nth=0'); mp.click('#btn-append')
    sws.add(mp.evaluate('document.documentElement.scrollWidth'))
    mp.evaluate("cursor=0;showStep(false)")
    while not mp.evaluate("trace[cursor].kind==='update'&&trace[cursor].arrival===13"): mp.click('#btn-next')
    mp.wait_for_timeout(700)
    mp.screenshot(path='sw_mobile.png', full_page=True)
    print('mobile scrollWidth', sws, 'explain heights', hs, 'errs', merrs)
    b.close()
