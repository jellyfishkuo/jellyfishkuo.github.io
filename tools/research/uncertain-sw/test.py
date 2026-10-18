"""SWUPA 頁面測試：隨機資料把網頁 JS、Python 版、暴力法交叉比對，再從頭按到尾檢查版面。
需要本機伺服器：cd <repo> && python3 -m http.server 8833（或設環境變數 PORT）"""
import os, random, sys, time
from itertools import combinations
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from uncertain_sw import SWUPA
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/uncertain-sw.html' % os.environ.get('PORT', '8833')
SHOT = sys.argv[1] if len(sys.argv) > 1 else None   # 截圖資料夾（不要放在 repo 裡）
CARDS = "[...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.left), Math.round(r.height)]; })"


def python_windows(rows, b, w, pct):
    sw = SWUPA(b, w, pct)
    txs = [(k + 1, t) for k, t in enumerate(rows)]
    out = []
    for k in range(0, len(txs) - b + 1, b):
        sw.log = []
        r = sw.add_batch(txs[k:k + b])
        if r is not None:
            tids = [tid for bt in sw.window for tid, _ in bt]
            out.append((tids, {tuple(sorted(s)): v for s, v in r.items()}, [[kd, list(it)] for kd, it in sw.log]))
    return out


def brute(rows, tids, ms):
    present = sorted({i for t in tids for i in rows[t - 1]})
    res = {}
    for r in range(1, len(present) + 1):
        for s in combinations(present, r):
            e = 0.0
            for t in tids:
                if all(i in rows[t - 1] for i in s):
                    p = 1.0
                    for i in s: p *= rows[t - 1][i]
                    e += p
            if e >= ms - 1e-9: res[s] = e
    return res


def same(a, b):
    return a.keys() == b.keys() and all(abs(a[k] - b[k]) < 1e-9 for k in a)


with sync_playwright() as p:
    br = p.chromium.launch()
    ctx = br.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_function('() => !blocksBusy', timeout=30000)

    # 1. 隨機資料：每個視窗 JS vs Python vs 暴力法，合併紀錄（剪枝在哪裡發生）也要一樣
    random.seed(11)
    trials = wins = bad = 0
    while trials < 250:
        n = random.randint(5, 12)
        rows = [{i: random.randint(1, 10) / 10 for i in random.sample(ITEMS, random.randint(1, 6))} for _ in range(n)]
        b = random.randint(1, 3); w = random.randint(2, 4)
        if b * w > n: continue
        trials += 1
        pct = random.choice(range(5, 65, 5))
        js = pg.evaluate("([r,b,w,p]) => simulate(r,b,w,p)", [rows, b, w, pct])
        py = python_windows(rows, b, w, pct)
        ok = len(js) == len(py)
        for jw, (tids, pres, plog) in zip(js, py):
            wins += 1
            jres = {tuple(s): v for s, v in jw['found']}
            br_ = brute(rows, tids, w * b * pct / 100)
            ok &= jw['tids'] == tids and same(jres, pres) and same(pres, br_) and jw['log'] == plog and jw['same']
        if not ok:
            bad += 1
            if bad < 4: print('MISMATCH', rows, b, w, pct)
    print(f'random: {trials} 組、{wins} 個視窗，JS / Python / 暴力法不一致 {bad}')

    # 2. 論文 Table 3 的數字（Example 1–4）
    pg.click('#dataset button[data-ds=paper]'); pg.wait_for_function('() => !blocksBusy')
    chk = pg.evaluate("""() => {
        const w1 = trace.find(s => s.kind === 'sort' && s.winNo === 1), w2 = trace.find(s => s.kind === 'sort' && s.winNo === 2);
        const A = w1.order.find(o => o.item === 'A');
        const ab = trace.find(s => s.kind === 'pair' && s.winNo === 1 && s.items.join('') === 'AB');
        const ae = trace.find(s => s.kind === 'pair' && s.winNo === 2 && s.items.join('') === 'AE');
        const a2 = trace.find(s => s.kind === 'expire').lists.find(L => L.items[0] === 'A');
        return { ms: w1.ms, A: [A.exp, A.max], AB: ab.over, AE: [ae.verdict, ae.rows.map(r => r.bound)], A2: a2.tids };
    }""")
    print('paper:', chk)
    stale = pg.evaluate("trace.filter(s => s.kind === 'pair' && Math.abs(s.X.exp * s.maxLast - s.over) > 1e-12).length")
    print('pair 步驟裡 X 的數字跟當下不一致：', stale)
    pg.click('#dataset button[data-ds=shop]'); pg.wait_for_function('() => !blocksBusy')

    # 3. 最極端的設定（一批 1 筆、視窗 4 批、δ 5%）量高度要多久
    pg.evaluate("bSize = 1; wSize = 4; pct = 5"); t0 = time.time()
    pg.evaluate("rebuild(false)"); pg.wait_for_function('() => !blocksBusy')
    print('extreme steps', pg.evaluate('trace.length'), 'measure %.2fs' % (time.time() - t0))
    print('errs', errs)

    # 4. 從頭按到尾：375 / 1280，載入後馬上每 30ms 按一次下一步；量完之後每個 .card 位置都不能變
    for W, H in ((375, 760), (1280, 900), (320, 640)):
        c = br.new_context(viewport={'width': W, 'height': H}, is_mobile=W < 600, has_touch=W < 600)
        c.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        m = c.new_page(); me = []; m.on('pageerror', lambda e: me.append(str(e)))
        m.goto(U)
        t0 = time.time()
        while not m.is_disabled('#btn-next'):
            m.click('#btn-next', force=True); m.wait_for_timeout(30)
            if time.time() - t0 > 30: break
        m.wait_for_function('() => !blocksBusy')
        m.evaluate("document.getElementById('btn-first').click()"); m.wait_for_timeout(50)
        base = m.evaluate(CARDS); moved = 0; steps = 0; sws = set(); hs = set(); hl0 = 0
        while True:
            steps += 1
            moved += m.evaluate(CARDS) != base
            sws.add(m.evaluate('document.documentElement.scrollWidth'))
            hs.add(m.evaluate("document.getElementById('explain').offsetHeight"))
            hl0 += m.evaluate("document.querySelectorAll('#code .ln.hl').length") == 0
            if m.is_disabled('#btn-next'): break
            m.click('#btn-next')
        m.click('#lang button[data-lang=py]'); hl0 += m.evaluate("document.querySelectorAll('#code .ln.hl').length") == 0
        print(f'{W}px: {steps} 步、.card 位置變動 {moved} 次、scrollWidth {sws}、說明框高度 {hs}、沒高亮 {hl0}、pageerror {me}')
        if SHOT and W != 320:
            m.evaluate("cursor = trace.findIndex(s => s.kind === 'pair' && s.verdict === 'ppclw' && s.winNo === 2); showStep(false)"); m.wait_for_timeout(400)
            m.screenshot(path=f'{SHOT}/usw_{W}.png', full_page=True)
        c.close()
    br.close()
