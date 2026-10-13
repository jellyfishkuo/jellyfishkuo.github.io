"""關聯規則 Demo 的測試：網頁 JS、Python 版、暴力法（枚舉所有切法）三方比對，再逐步走完檢查版面
需要本機伺服器：cd <repo> && python3 -m http.server 8791
截圖存到環境變數 SHOTS 指定的資料夾（預設 /tmp）"""
import os
import sys
import random
from itertools import combinations
sys.dont_write_bytecode = True
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
sys.path.insert(0, REPO + '/research/code')
from assoc_rules import gen_rules
from playwright.sync_api import sync_playwright

ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:8791/research/association-rules.html'
SHOTS = os.environ.get('SHOTS', '/tmp')


def brute(db, min_sup, pct):
    """暴力法：所有頻繁樣式 × 所有切法，信賴度用整數比（sup(Z)*100 >= pct*sup(X)）"""
    items = sorted({i for t in db for i in t})
    sup = lambda s: sum(1 for t in db if set(s) <= t)
    out = {}
    for k in range(2, len(items) + 1):
        for z in combinations(items, k):
            sz = sup(z)
            if sz < min_sup:
                continue
            for m in range(1, k):
                for y in combinations(z, m):
                    x = tuple(i for i in z if i not in y)
                    sx, sy = sup(x), sup(y)
                    if sz * 100 >= pct * sx:
                        out[(x, y)] = (sz, sz / sx, sz * len(db) / (sx * sy))
    return out


def same(a, b):
    if a.keys() != b.keys():
        return False
    return all(a[k][0] == b[k][0] and abs(a[k][1] - b[k][1]) < 1e-9 and abs(a[k][2] - b[k][2]) < 1e-9 for k in a)


with sync_playwright() as p:
    br = p.chromium.launch()
    ctx = br.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route('**/fonts.googleapis.com/**', lambda r: r.abort())
    pg = ctx.new_page()
    errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U)
    pg.wait_for_timeout(400)

    # 1. 隨機資料：JS / Python / 暴力法，規則集合、支持度、信賴度、提升度、順序（JS 與 Python）都要一樣
    bad = 0
    trials = 300
    nrules = 0
    for trial in range(trials):
        rows = random.randint(3, 12)
        db = [set(random.sample(ITEMS, random.randint(1, 6))) for _ in range(rows)]
        ms = random.randint(1, rows)
        pct = random.choice(range(5, 101, 5))
        py = gen_rules(db, ms, pct / 100)
        pyd = {(x, y): (s, c, l) for x, y, s, c, l in py}
        bf = brute(db, ms, pct)
        js = pg.evaluate("""([d, m, c]) => { db = d.map(t => new Set(t)); minSup = m; minConfPct = c;
            const tr = buildTrace(); return tr.rules.map(r => [r.x, r.y, r.supZ, r.conf, r.lift]); }""",
                         [[sorted(t) for t in db], ms, pct])
        jsd = {(tuple(x), tuple(y)): (s, c, l) for x, y, s, c, l in js}
        order_ok = [(tuple(x), tuple(y)) for x, y, *_ in js] == [(x, y) for x, y, *_ in py]
        nrules += len(bf)
        if not (same(pyd, bf) and same(jsd, bf) and order_ok and len(js) == len(py)):
            bad += 1
            if bad <= 3:
                print('MISMATCH', db, ms, pct, len(py), len(js), len(bf))
    print(f'random: {trials} 組, 共 {nrules} 條規則, 不一致 {bad} 組')

    # 統計：算過 + 剪掉 = 暴力法切法數
    stat_bad = 0
    for trial in range(100):
        rows = random.randint(3, 12)
        db = [sorted(random.sample(ITEMS, random.randint(1, 6))) for _ in range(rows)]
        r = pg.evaluate("""([d, m, c]) => { db = d.map(t => new Set(t)); minSup = m; minConfPct = c;
            const s = buildTrace().at(-1).stats; return s.tested + s.skipped === s.brute; }""",
                        [db, random.randint(1, rows), random.choice(range(5, 101, 5))])
        stat_bad += not r
    print('stats tested+skipped==brute 失敗', stat_bad)

    pg.reload()
    pg.wait_for_timeout(400)
    # 2. 範例資料從頭走到尾
    seen = []
    while True:
        st = pg.evaluate("""[trace[cursor].kind, window.scrollY, document.getElementById('explain').offsetHeight,
            [...document.querySelectorAll('#code .ln.hl')].map(l => +l.dataset.n),
            document.getElementById('explain').innerText.replace(/\\n/g, ' ')]""")
        seen.append(st)
        if pg.is_disabled('#btn-next'):
            break
        pg.click('#btn-next')
        pg.wait_for_timeout(20)
    for s in seen:
        print(f'{s[0]:6} h={s[2]} hl={s[3][:4]}{"…" if len(s[3]) > 4 else ""} {s[4][:90]}')
    print('steps', len(seen), 'explain heights', set(s[2] for s in seen), 'scrollY', set(s[1] for s in seen))
    print('no-hl steps', [s[0] for s in seen if not s[3]])
    print('stats', pg.inner_text('.stats').replace('\n', ' '))

    # 3. 排序、點規則
    pg.click('#sort button[data-sort=lift]')
    lifts = pg.eval_on_selector_all('.rules tbody tr td:last-child', 'els => els.map(e => +e.textContent)')
    print('lift sorted desc', lifts == sorted(lifts, reverse=True), lifts)
    pg.click('#sort button[data-sort=conf]')
    confs = pg.eval_on_selector_all('.rules tbody tr td:nth-child(3)', 'els => els.map(e => parseFloat(e.textContent))')
    print('conf sorted desc', confs == sorted(confs, reverse=True), confs)
    pg.locator('.rules tbody tr').first.click()
    print('row hint:', pg.inner_text('#cands-hint'), '| match rows', pg.locator('tr.match').count(), 'hit cells', pg.locator('.cell.hit').count())

    # 4. 走到第一個 grow 有剪掉的步驟，截圖
    pg.click('#btn-first')
    while not pg.evaluate("trace[cursor].kind === 'grow' && trace[cursor].skipped.length > 0"):
        pg.click('#btn-next')
    pg.locator('.cand.out').first.click()
    print('skip hint:', pg.inner_text('#cands-hint'))
    pg.screenshot(path=f'{SHOTS}/ar_desktop.png', full_page=True)
    pg.click('#lang button[data-lang=py]')
    print('py hl', pg.evaluate("[...document.querySelectorAll('#code .ln.hl')].map(l => +l.dataset.n)"))

    # 5. 調門檻、編輯
    pg.click('#conf-minus'); pg.click('#conf-minus')
    print('minconf 60 →', pg.evaluate('trace.rules.length'), 'rules; lift<1:', pg.evaluate("trace.rules.filter(r => liftSign(r) < 0).map(r => r.x + '→' + r.y)"))
    pg.click('#btn-edit'); pg.click('.cell[data-r="6"][data-i="咖啡"]'); pg.click('#sup-minus')
    print('after edit', pg.inner_text('#sup-val'), pg.evaluate('trace.length'), 'steps')
    print('errs', errs)

    # 6. 手機
    for w in (375, 320):
        mctx = br.new_context(viewport={'width': w, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
        mctx.route('**/fonts.googleapis.com/**', lambda r: r.abort())
        m = mctx.new_page()
        m.on('pageerror', lambda e: errs.append(str(e)))
        m.goto(U)
        m.wait_for_timeout(400)
        widths, heights = set(), set()
        while True:
            widths.add(m.evaluate('document.documentElement.scrollWidth'))
            heights.add(m.evaluate("document.getElementById('explain').offsetHeight"))
            if m.evaluate("trace[cursor].kind === 'grow' && trace[cursor].skipped.length > 0"):
                m.screenshot(path=f'{SHOTS}/ar_mobile{w}.png', full_page=True)
            if m.is_disabled('#btn-next'):
                break
            m.click('#btn-next')
        print(f'mobile {w}: scrollWidth {widths} explain heights {heights}')
        mctx.close()
    print('errs', errs)
    br.close()
