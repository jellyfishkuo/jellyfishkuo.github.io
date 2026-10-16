"""Research 總覽頁的檢查：連結都有效、每個現有 Demo 都連得到、手機不能水平捲動、沒有 JS 錯誤、hover 不會推動版面。

先在 repo 根目錄開伺服器：python3 -m http.server 8809
再執行：python3 -B test.py [截圖資料夾]
"""
import os, sys, glob
from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '../../..'))
BASE = 'http://localhost:8809/research/overview.html'
SHOTS = sys.argv[1] if len(sys.argv) > 1 else None
fails = []

def check(cond, msg):
    print(('  ok  ' if cond else '  FAIL ') + msg)
    if not cond:
        fails.append(msg)

with sync_playwright() as p:
    b = p.chromium.launch()
    for w, h in ((375, 760), (320, 640), (1280, 900)):
        ctx = b.new_context(viewport={'width': w, 'height': h})
        ctx.route('**/fonts.googleapis.com/**', lambda r: r.abort())
        pg = ctx.new_page()
        errs = []
        pg.on('pageerror', lambda e: errs.append(str(e)))
        pg.goto(BASE)
        pg.wait_for_timeout(600)
        print(f'— {w}px')
        check(not errs, f'沒有 pageerror {errs}')
        sw = pg.evaluate('document.documentElement.scrollWidth')
        check(sw == w, f'沒有水平捲動（scrollWidth {sw}）')
        # 框內的圖與表格可以比框寬，但只在自己的框內捲
        g = pg.evaluate("(() => { const s = document.getElementById('graph-scroll'); return [s.clientWidth, s.scrollWidth]; })()")
        check(g[0] <= w, f'關係圖的框沒有超出畫面（框 {g[0]}，內容 {g[1]}）')

        # hover 每個節點：版面不能動
        before = pg.evaluate("[...document.querySelectorAll('.card, .routes > *')].map(e => Math.round(e.getBoundingClientRect().top + scrollY))")
        if w >= 1000:
            n_nodes = pg.locator('svg.graph .node').count()
            for i in range(n_nodes):
                pg.locator('svg.graph .node').nth(i).hover()
            pg.mouse.move(1, 1)
            after = pg.evaluate("[...document.querySelectorAll('.card, .routes > *')].map(e => Math.round(e.getBoundingClientRect().top + scrollY))")
            check(before == after, f'hover {n_nodes} 個節點後，{len(before)} 個區塊位置都沒變')
            check(not pg.evaluate("document.querySelector('svg.graph').classList.contains('focus')"), '移開後不再淡化')

        if SHOTS:
            os.makedirs(SHOTS, exist_ok=True)
            pg.screenshot(path=f'{SHOTS}/overview-{w}.png', full_page=True)
            if w >= 1000:
                pg.locator('svg.graph a.node[data-id="huiminer"]').hover()
                pg.locator('#graph-card').screenshot(path=f'{SHOTS}/overview-hover.png')
        if w == 375:
            # 連結：每個 href 指到的檔案都存在
            hrefs = pg.evaluate("[...document.querySelectorAll('a[href]')].map(a => a.getAttribute('href'))")
            bad = []
            for hr in set(hrefs):
                if hr.startswith('http'):
                    continue
                path = os.path.normpath(os.path.join(REPO, 'research', hr.split('#')[0]))
                if not os.path.exists(path):
                    bad.append(hr)
            check(not bad, f'{len(set(hrefs))} 個不同的連結都指到存在的檔案 {bad}')
            # 每個現有的 Demo 頁都至少有一個連結（圖、清單、表格）
            pages = {os.path.basename(f) for f in glob.glob(os.path.join(REPO, 'research', '*.html'))} - {'overview.html'}
            missing = sorted(pages - set(hrefs))
            check(not missing, f'{len(pages)} 個現有 Demo 頁都連得到 {missing}')
            n_soon = pg.locator('svg.graph .node.soon').count()
            print(f'      圖上即將推出的節點：{n_soon}')
            # 用 HTTP 實際開一次每個連結
            for hr in sorted(set(hrefs)):
                if hr.startswith('http') or hr.startswith('../index'):
                    continue
                r = pg.request.get('http://localhost:8809/research/' + hr)
                if r.status != 200:
                    bad.append(hr)
            check(not bad, '每個連結都回 200')
        ctx.close()
    b.close()

print('全部通過' if not fails else f'{len(fails)} 項失敗')
sys.exit(1 if fails else 0)
