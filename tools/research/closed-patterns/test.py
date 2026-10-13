"""closed-patterns.html 的測試：隨機資料交叉比對（網頁 JS / Python 版 / 暴力法），再從頭按到尾檢查版面
需要本機伺服器：cd <repo> && python3 -m http.server 8793
截圖存到 argv[1]（預設目前資料夾）"""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys
from itertools import combinations
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from charm import charm, maximal
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:8793/research/closed-patterns.html'
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
HL = "[...document.querySelectorAll('#code .ln.hl')].map(l=>+l.dataset.n)"


def brute(db, ms):
    """列舉所有組合：頻繁 = 次數 ≥ ms；封閉 = 沒有同次數的超集合；最大 = 沒有頻繁的超集合"""
    f = {}
    for k in range(1, 7):
        for s in combinations(sorted(ITEMS), k):
            c = sum(1 for t in db if set(s) <= set(t))
            if c >= ms: f[s] = c
    c = {s: n for s, n in f.items() if not any(set(s) < set(o) and f[o] == n for o in f)}
    m = {s: n for s, n in f.items() if not any(set(s) < set(o) for o in f)}
    return f, c, m


with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)

    # 1. 隨機資料：JS 的 CHARM（照找到的順序）== Python 版；兩者的集合 == 暴力法；頁面上的暴力法也 == Python 暴力法
    random.seed(11)
    bad = 0; trials = 400; closed_total = 0; dense = 0
    for trial in range(trials):
        rows = random.randint(1, 12)
        # 一半稀疏、一半密集（每筆買很多樣），密集時封閉和全部頻繁差很多
        lo = 1 if trial % 2 else 3
        db = [random.sample(ITEMS, random.randint(lo, 6)) for _ in range(rows)]
        ms = random.randint(1, rows)
        js = pg.evaluate("([d,m])=>simulate(d,m)", [db, ms])
        py_c = charm([set(t) for t in db], ms)
        py_m = maximal(py_c)
        f, c, m = brute(db, ms)
        jc = [(tuple(s), n) for s, n in js['closed']]
        jm = [(tuple(s), n) for s, n in js['max']]
        ok = (jc == py_c and jm == py_m and dict(jc) == c and len(jc) == len(c) and dict(jm) == m
              and {tuple(s): n for s, n in js['brute']['freq']} == f
              and {tuple(s): n for s, n in js['brute']['closed']} == c
              and {tuple(s): n for s, n in js['brute']['max']} == m)
        closed_total += len(c); dense += len(f) > len(c)
        if not ok:
            bad += 1
            if bad <= 3: print('MISMATCH', db, ms, jc, py_c, c)
    print(f'random: {trials} databases, {closed_total} closed patterns total, {dense} cases where closed < frequent, mismatches: {bad}')

    # 2. 範例資料從頭按到尾：說明框高度、頁面有沒有被捲、每種步驟亮哪幾行
    pg.reload(); pg.wait_for_timeout(400)
    seen = []
    while True:
        seen.append(pg.evaluate("[trace[cursor].kind, window.scrollY, document.getElementById('explain').offsetHeight, " + HL + "]"))
        if pg.is_disabled('#btn-next'): break
        pg.click('#btn-next'); pg.wait_for_timeout(20)
    kinds = {}
    for k, y, h, hl in seen:
        kinds.setdefault(k, set()).add((hl[0], hl[-1], len(hl)) if hl else None)
    print('steps', len(seen), 'explain heights', set(s[2] for s in seen), 'scrollY', set(s[1] for s in seen))
    for k, v in kinds.items(): print(' ', k, sorted(v, key=str))
    print('end text:', pg.inner_text('#explain')[:160].replace('\n', ' '))
    pg.click('#lang button[data-lang=py]')
    pyk = {}
    pg.click('#btn-first')
    while True:
        pyk.setdefault(pg.evaluate('trace[cursor].kind'), pg.evaluate(HL))
        if pg.is_disabled('#btn-next'): break
        pg.click('#btn-next')
    print('py hl', {k: (v[0], v[-1], len(v)) if v else None for k, v in pyk.items()})
    pg.click('#lang button[data-lang=java]')

    # 3. 互動：點樣式、改門檻、編輯資料、自動播放、鍵盤
    pg.click('#btn-first'); pg.click('#btn-next')
    pg.locator('#levels .chip.dim').first.click()
    print('hint:', pg.inner_text('#hint'), '| matched rows', pg.locator('tr.match').count())
    pg.screenshot(path=f'{OUT}/cp_closed.png', full_page=True)
    pg.click('#btn-next'); pg.screenshot(path=f'{OUT}/cp_maximal.png', full_page=True)

    def goto(cond):
        pg.evaluate("cursor=0;showStep()")
        while not pg.evaluate(cond): pg.click('#btn-next')
        pg.wait_for_timeout(600)
    for k in ('p1', 'p2', 'p3', 'p4'):
        goto(f"trace[cursor].kind==='{k}'")
        pg.screenshot(path=f'{OUT}/cp_{k}.png', full_page=True)
    goto("trace[cursor].kind==='vertical'"); pg.screenshot(path=f'{OUT}/cp_vertical.png', full_page=True)
    goto("trace[cursor].kind==='end'"); pg.screenshot(path=f'{OUT}/cp_end.png', full_page=True)
    for ms in (1, 3, 4):
        while int(pg.inner_text('#sup-val')) != ms: pg.click('#sup-minus' if int(pg.inner_text('#sup-val')) > ms else '#sup-plus')
        print(f'minSup {ms}:', pg.evaluate("[trace.length, answer.freq.length, answer.closed.length, answer.max.length, [...new Set(trace.map(s=>s.kind))].join(' ')]"),
              'subsumed', pg.evaluate("trace[trace.length-1].stats.sub"))
    pg.click('#btn-edit'); pg.click('.cell[data-r="6"][data-i="咖啡"]'); pg.click('#btn-add-row')
    print('after edit', pg.evaluate('db.length'), pg.inner_text('#explain')[:40])
    pg.click('#btn-reset-db'); pg.click('#btn-edit')
    pg.click('#btn-play'); pg.wait_for_timeout(2000); print('autoplay at', pg.evaluate('cursor'), pg.inner_text('#btn-play')); pg.click('#btn-play')
    pg.keyboard.press('ArrowRight'); pg.keyboard.press('ArrowLeft')
    print('errs', errs)

    # 4. 手機 375 / 320：每一步都不能水平捲動、說明框高度固定
    for w in (375, 320):
        m = b.new_context(viewport={'width': w, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
        m.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        mp = m.new_page(); merrs = []; mp.on('pageerror', lambda e: merrs.append(str(e)))
        mp.goto(U); mp.wait_for_timeout(500)
        sws = set(); hs = set()
        for ms in (2, 1):
            while int(mp.inner_text('#sup-val')) != ms: mp.click('#sup-minus')
            while True:
                sws.add(mp.evaluate('document.documentElement.scrollWidth')); hs.add(mp.evaluate("document.getElementById('explain').offsetHeight"))
                if mp.is_disabled('#btn-next'): break
                mp.click('#btn-next')
        mp.click('#btn-edit'); [mp.click('#btn-add-row') for _ in range(4)]
        sws.add(mp.evaluate('document.documentElement.scrollWidth'))
        mp.click('#btn-reset-db'); mp.click('#btn-edit')
        mp.evaluate("cursor=0;showStep()")
        while not mp.evaluate("trace[cursor].kind==='p2'"): mp.click('#btn-next')
        mp.wait_for_timeout(600)
        mp.screenshot(path=f'{OUT}/cp_mobile_{w}.png', full_page=True)
        print(f'mobile {w}: scrollWidth', sws, 'explain heights', hs, 'errs', merrs)
        m.close()
    b.close()
