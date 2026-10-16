"""效能比賽場的測試：
1. 用隨機小資料把頁面裡六個演算法的 JS 跟 research/code/ 的 Python 版、暴力法交叉比對
2. 較大的隨機資料：同一組三個演算法的結果指紋要一樣
3. 實際按「開始比賽」：結果一致、超商範例的樣式數跟 Python 一樣、逾時與取消、區塊位置不能動、手機不能水平捲動
需要本機伺服器：cd <repo> && python3 -m http.server 8808
用法：python3 -B test.py [截圖資料夾]
"""
import os, sys, random, itertools, json
sys.dont_write_bytecode = True
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))
sys.path.insert(0, REPO + '/research/code')
from apriori import apriori
from fpgrowth import fp_growth
from eclat import eclat
from two_phase import two_phase
from hui_miner import hui_miner
from up_growth import up_growth
from efim import efim
from playwright.sync_api import sync_playwright

U = 'http://127.0.0.1:8808/research/benchmark.html'
SHOT = sys.argv[1] if len(sys.argv) > 1 else None
NAMES = list('abcdefgh')
random.seed(20261016)

def brute(db, profit, items):
    sup, util = {}, {}
    for n in range(1, len(items) + 1):
        for s in itertools.combinations(items, n):
            ts = [t for t in db if all(i in t for i in s)]
            if ts:
                sup[frozenset(s)] = len(ts)
                util[frozenset(s)] = sum(sum(t[i] * profit[i] for i in s) for t in ts)
    return sup, util

JS_RUN = """cases => cases.map(c => {
    const D = BENCH.packData(c.rows, c.profit, null);
    const out = {};
    for (const [g, algos] of [['freq', ['apriori', 'fpgrowth', 'eclat']], ['hui', ['twophase', 'huiminer', 'upgrowth', 'efim']]])
        for (const a of algos) out[a] = BENCH.collect(D, g, a, g === 'freq' ? c.minsup : c.minutil).list;
    return out;
})"""

errs = []
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900}); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)

    # ---- 1. 隨機小資料：JS × Python × 暴力法 ----
    cases, meta = [], []
    for trial in range(300):
        m = random.randint(1, 8); items = NAMES[:m]
        db = []
        for _ in range(random.randint(1, 20)):
            t = {i: random.randint(1, 6) for i in items if random.random() < random.choice((0.3, 0.5, 0.8))}
            if not t: t = {random.choice(items): 1}
            db.append(t)
        profit = {i: random.randint(1, 40) for i in items}
        total = sum(t[i] * profit[i] for t in db for i in t)
        minsup = random.randint(1, len(db)); minutil = random.randint(1, max(1, total))
        cases.append({'rows': [[[NAMES.index(i), q] for i, q in t.items()] for t in db], 'profit': [profit[i] for i in items], 'minsup': minsup, 'minutil': minutil})
        meta.append((db, profit, items, minsup, minutil))
    got = pg.evaluate(JS_RUN, cases)
    bad = 0; nonempty = [0, 0]
    for (db, profit, items, ms, mu), js in zip(meta, got):
        sup, util = brute(db, profit, items)
        bf_f = {k: v for k, v in sup.items() if v >= ms}
        bf_h = {k: v for k, v in util.items() if v >= mu}
        sets = [set(t) for t in db]
        py = {
            'apriori': {frozenset(c): sup[frozenset(c)] for c in apriori(sets, ms)},
            'fpgrowth': {frozenset(k): v for k, v in fp_growth(sets, ms).items()},
            'eclat': {frozenset(k): v for k, v in eclat(sets, ms).items()},
            'twophase': {frozenset(k): v for k, v in two_phase(db, profit, mu).items()},
            'huiminer': {frozenset(k): v for k, v in hui_miner(db, profit, mu).items()},
            'upgrowth': {frozenset(k): v for k, v in up_growth(db, profit, mu).items()},
            'efim': {frozenset(k): v for k, v in efim(db, profit, mu).items()},
        }
        for a, lst in js.items():
            jm = {frozenset(NAMES[i] for i in s): v for s, v in lst}
            want = bf_f if a in ('apriori', 'fpgrowth', 'eclat') else bf_h
            if len(jm) != len(lst) or jm != want or py[a] != want:
                bad += 1
                if bad < 4: print('MISMATCH', a, db, profit, ms, mu, jm, py[a], want)
        nonempty[0] += bool(bf_f); nonempty[1] += bool(bf_h)
    print(f'1. 隨機小資料 {len(cases)} 組 × 7 個演算法（JS / Python / 暴力法）不一致：{bad}；有結果的組數 頻繁 {nonempty[0]}、高效益 {nonempty[1]}')

    # ---- 2. 較大的隨機資料：指紋一致 ----
    fpbad = pg.evaluate("""() => {
        let bad = 0, runs = 0, pats = 0;
        for (const dist of ['uniform', 'zipf']) for (const seed of [1, 7, 42, 2026]) for (const [n, m, len] of [[300, 12, 4], [800, 20, 7], [1500, 30, 9]]) {
            const D = BENCH.makeData({ source: 'random', trans: n, items: m, avgLen: len, dist, seed, qMax: 5, pMax: 50 });
            const st = BENCH.dataStats(D);
            for (const pct of [8, 4, 2]) {
                const f = ['apriori', 'fpgrowth', 'eclat'].map(a => BENCH.measure(D, 'freq', a, Math.ceil(pct / 100 * n)).fp);
                const h = ['twophase', 'huiminer', 'upgrowth', 'efim'].map(a => BENCH.measure(D, 'hui', a, Math.ceil(pct / 400 * st.util)).fp);
                runs += 2; pats += Number(f[0].split(':')[0]) + Number(h[0].split(':')[0]);
                if (new Set(f).size !== 1) bad++;
                if (new Set(h).size !== 1) bad++;
            }
        }
        return [runs, bad, pats];
    }""")
    print(f'2. 較大的隨機資料 {fpbad[0]} 組（每組 3～4 個演算法），指紋不一致 {fpbad[1]}，總樣式數 {fpbad[2]}')

    # ---- 3. 超商 8 筆範例：頁面跑出來的樣式數 = Python ----
    pg.click('#src button[data-v=sample]')
    sample_db = [{'咖啡': 4, '麵包': 2, '牛奶': 2}, {'咖啡': 3, '麵包': 5, '茶葉蛋': 4}, {'咖啡': 1, '麵包': 1, '牛奶': 2, '飯糰': 2},
                 {'麵包': 3, '牛奶': 4, '洋芋片': 5}, {'咖啡': 3, '牛奶': 2, '茶葉蛋': 2}, {'咖啡': 1, '麵包': 2, '牛奶': 1, '茶葉蛋': 1},
                 {'飯糰': 1, '茶葉蛋': 2, '洋芋片': 2}, {'咖啡': 1, '麵包': 2, '飯糰': 1}]
    sprofit = {'咖啡': 30, '麵包': 15, '牛奶': 20, '飯糰': 10, '茶葉蛋': 5, '洋芋片': 25}
    sbad = 0
    for g in ('freq', 'hui'):
        pg.click(f'#tab-{g}'); pg.click('#btn-run'); pg.wait_for_function('!running', timeout=60000)
        R = pg.evaluate(f"results.{g}")
        for k, a in enumerate(R['abs']):
            n = len(fp_growth([set(t) for t in sample_db], a)) if g == 'freq' else len(two_phase(sample_db, sprofit, a))
            ns = {c['n'] for c in (R['cells'][x][k] for x in R['cells'])}
            if ns != {n} or R['check'][k] is not True: sbad += 1
        print(f'3. 超商範例 {g}：門檻 {R["abs"]} 樣式數 {[R["cells"]["apriori" if g=="freq" else "twophase"][k]["n"] for k in range(6)]}')
    print('   超商範例與 Python 不一致：', sbad)
    pg.click('#src button[data-v=random]')

    # ---- 4. 逾時：把上限調成 400 ms，用大資料 ----
    pg.fill('#in-seed', '7'); pg.dispatch_event('#in-seed', 'change')
    pg.evaluate("""() => { const s = document.getElementById('in-trans'); s.value = 10000; s.dispatchEvent(new Event('input')); }""")
    pg.wait_for_timeout(400)
    pg.click('#tab-hui')
    pg.evaluate("benchTimeoutMs = 400")
    pg.click('#btn-run'); pg.wait_for_function('!running', timeout=120000)
    R = pg.evaluate("results.hui")
    sts = {a: [c['st'] for c in R['cells'][a]] for a in R['cells']}
    has_to = any('timeout' in v for v in sts.values()); has_skip = any('skip' in v for v in sts.values())
    print('4. 逾時測試：', sts, '有逾時', has_to, '有略過', has_skip, '一致', R['check'])
    print('   觀察：', pg.inner_text('#obs').split('\n')[-1])
    pg.evaluate("benchTimeoutMs = 10000")

    # ---- 5. 取消，然後再跑一次 ----
    pg.click('#tab-freq')
    pg.click('#btn-run'); pg.wait_for_timeout(250); pg.click('#btn-cancel'); pg.wait_for_function('!running', timeout=10000)
    print('5. 取消：', pg.inner_text('#prog-text'))
    pg.click('#btn-run'); pg.wait_for_function('!running', timeout=120000)
    print('   再跑一次：', pg.inner_text('#prog-text'), pg.inner_text('#check'))

    # ---- 6. 版面：各種狀態下每個 .card 的位置都不能變；手機不能水平捲動 ----
    POS = "scrollTo(0, 0), [...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.left), Math.round(r.height), Math.round(r.width)]; })"
    for w, h in ((1280, 900), (375, 760), (320, 640)):
        c2 = b.new_context(viewport={'width': w, 'height': h}, device_scale_factor=1 if w > 900 else 2); c2.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        mp = c2.new_page(); mp.on('pageerror', lambda e: errs.append(str(e)))
        mp.goto(U); mp.wait_for_timeout(3000)
        states = [('載入', mp.evaluate(POS))]
        sws = {mp.evaluate('document.documentElement.scrollWidth')}
        def snap(label):
            states.append((label, mp.evaluate(POS))); sws.add(mp.evaluate('document.documentElement.scrollWidth'))
        mp.click('#btn-run'); mp.wait_for_timeout(300); snap('頻繁 跑到一半')
        mp.wait_for_function('!running', timeout=120000); snap('頻繁 跑完')
        mp.click('#scale button[data-v=lin]'); snap('一般刻度')
        mp.click('#tab-hui'); snap('切到高效益')
        mp.click('#btn-run'); mp.wait_for_timeout(400); snap('高效益 跑到一半')
        mp.click('#btn-cancel'); mp.wait_for_function('!running'); snap('取消')
        mp.click('#btn-run'); mp.wait_for_function('!running', timeout=120000); snap('高效益 跑完')
        mp.click('#src button[data-v=sample]'); snap('超商範例')
        mp.click('#btn-run'); mp.wait_for_function('!running', timeout=60000); snap('範例 跑完')
        mp.click('#tab-freq'); mp.click('#btn-run'); mp.wait_for_function('!running', timeout=60000); snap('範例 頻繁 跑完')
        moved = [lab for lab, s in states if s != states[0][1]]
        print(f'6. {w}px：{len(states)} 個狀態 × {len(states[0][1])} 個區塊，位置有變的狀態：{moved or "無"}；scrollWidth {sws}')
        if moved:
            for lab, s in states:
                if s != states[0][1]: print('   ', lab, [(i, a, b2) for i, (a, b2) in enumerate(zip(states[0][1], s)) if a != b2][:4])
        c2.close()
    # 截圖另外跑（整頁截圖會暫時改變視窗大小，不能混在位置檢查裡）
    if SHOT:
        for w, h in ((1280, 900), (375, 760)):
            c2 = b.new_context(viewport={'width': w, 'height': h}, device_scale_factor=1); c2.route("**/fonts.googleapis.com/**", lambda r: r.abort())
            mp = c2.new_page(); mp.on('pageerror', lambda e: errs.append(str(e)))
            mp.goto(U); mp.wait_for_timeout(1500)
            mp.screenshot(path=f'{SHOT}/w{w}-load.png', full_page=True)
            mp.click('#btn-run'); mp.wait_for_function('!running', timeout=120000)
            mp.screenshot(path=f'{SHOT}/w{w}-freq.png', full_page=True)
            mp.click('#tab-hui'); mp.click('#btn-run'); mp.wait_for_function('!running', timeout=120000)
            mp.screenshot(path=f'{SHOT}/w{w}-hui.png', full_page=True)
            c2.close()
    print('pageerror：', errs)
    b.close()
