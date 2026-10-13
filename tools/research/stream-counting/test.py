"""stream-counting.html 驗證：JS ↔ Python 逐筆狀態比對、誤差保證、逐步走完、互動、截圖
需要本機伺服器：cd <repo> && python3 -m http.server 8795"""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys, math
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from lossy_counting import LossyCounting, TOL
from space_saving import SpaceSaving
from playwright.sync_api import sync_playwright

U = 'http://127.0.0.1:8795/research/stream-counting.html'
SHOT = sys.argv[1] if len(sys.argv) > 1 else '.'
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片', '果汁', '布丁', '泡麵', '巧克力']
EPS = [0.05, 0.1, 0.125, 0.2, 0.25]
S = [0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5]
random.seed(20261013)


def rand_stream():
    n = random.randint(1, 120)
    kind = random.random()
    items = random.sample(ITEMS, random.randint(1, 10))
    if kind < 0.5:      # 偏斜（少數商品很熱門）
        wts = [1 / (r + 1) ** random.uniform(0.5, 2) for r in range(len(items))]
        return random.choices(items, wts, k=n)
    return [random.choice(items) for _ in range(n)]


with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)

    # ---------- 1. 隨機串流：JS 每一筆的狀態 ↔ Python，並檢查誤差保證 ----------
    N_TRIAL = 300
    bad = {'lc_state': 0, 'lc_query': 0, 'lc_guarantee': 0, 'lc_missed': 0,
           'ss_state': 0, 'ss_query': 0, 'ss_guarantee': 0, 'ss_missed': 0}
    arrivals = prunes_with_delete = replaces = fps_lc = fps_ss = 0
    for trial in range(N_TRIAL):
        st = rand_stream()
        e = random.choice(EPS); s = random.choice([x for x in S if x > e + TOL]); k = random.randint(1, 10); s2 = random.choice(S)
        js = pg.evaluate("""([st, e, s, k, s2]) => {
            const L = lossyTrace(st, e, s), P = ssTrace(st, k, s2);
            const lastOf = (steps) => { const m = {}; steps.forEach(x => { if (x.i !== undefined) m[x.i] = x; }); return m; };
            const l = lastOf(L), p = lastOf(P);
            return { lc: st.map((_, i) => l[i].table), ss: st.map((_, i) => p[i].slots),
                     lq: L[L.length - 1].report, sq: P[P.length - 1].report,
                     del: L.filter(x => x.kind === 'l-prune' && x.removed.length).length,
                     rep: P.filter(x => x.kind === 's-replace').length };
        }""", [st, e, s, k, s2])
        lc, ss, truth = LossyCounting(e), SpaceSaving(k), {}
        for i, x in enumerate(st):
            lc.add(x); ss.add(x); truth[x] = truth.get(x, 0) + 1; arrivals += 1
            n = i + 1
            if [[a, f, d] for a, (f, d) in lc.table.items()] != js['lc'][i]: bad['lc_state'] += 1
            if [list(sl) for sl in ss.slots] != js['ss'][i]: bad['ss_state'] += 1
            # Lossy：f ≤ 真實 ≤ f + Δ，且 真實 − f ≤ εN（不在表裡 f = 0）
            for a, t in truth.items():
                f, d = lc.table.get(a, (0, 0))
                if not (f <= t and t - f <= e * n + TOL and (a not in lc.table or t <= f + d)): bad['lc_guarantee'] += 1
            # Space-Saving：次數 − 誤差 ≤ 真實 ≤ 次數、誤差 ≤ N/k；沒在記的真實 < N/k 且 ≤ 最小格
            mon = {a: (c, er) for a, c, er in ss.slots}
            assert sum(c for c, _ in mon.values()) == n
            for a, t in truth.items():
                if a in mon:
                    c, er = mon[a]
                    if not (c - er <= t <= c and er <= n / k + TOL): bad['ss_guarantee'] += 1
                elif not (t < n / k and t <= min(c for c, _ in mon.values())): bad['ss_guarantee'] += 1
        lq = lc.query(s)
        if [[a, f] for a, f in lq.items()] != js['lq']: bad['lc_query'] += 1
        sq = ss.query(s2)
        if [list(x) for x in sq] != js['sq']: bad['ss_query'] += 1
        n = len(st)
        real_lc = {a for a, t in truth.items() if t >= s * n - TOL}
        if not real_lc <= set(lq): bad['lc_missed'] += 1
        real_ss = {a for a, t in truth.items() if t >= s2 * n - TOL}
        if k * s2 >= 1 - TOL and not real_ss <= {x[0] for x in sq}: bad['ss_missed'] += 1
        fps_lc += len(set(lq) - real_lc); fps_ss += len({x[0] for x in sq} - real_ss)
        prunes_with_delete += js['del']; replaces += js['rep']
    print(f'[random] {N_TRIAL} 組隨機串流、共 {arrivals} 筆逐筆比對：', bad)
    print(f'  （過程中有刪除的大掃除 {prunes_with_delete} 次、Space-Saving 搶格子 {replaces} 次；誤報 Lossy {fps_lc} 個、Space-Saving {fps_ss} 個）')

    # ---------- 2. 預設資料從頭走到尾 ----------
    pg.reload(); pg.wait_for_timeout(500)

    def walk(group):
        pg.click(f'#tab-{group}'); pg.wait_for_timeout(50)
        if not pg.is_disabled(f'#{group}-first'): pg.click(f'#{group}-first')
        hs, kinds, nohl, sy, n = set(), {}, [], set(), 0
        while True:
            st = pg.evaluate(f"""() => {{
                const s = stepsOf('{group}')[cursors['{group}']];
                return [s.kind, $('{group}-explain').offsetHeight, [...document.querySelectorAll('#{group}-code .ln.hl')].map(l => +l.dataset.n), window.scrollY];
            }}""")
            n += 1; hs.add(st[1]); kinds[st[0]] = kinds.get(st[0], 0) + 1; sy.add(st[3])
            if not st[2]: nohl.append(st[0])
            if pg.is_disabled(f'#{group}-next'): break
            pg.click(f'#{group}-next')
        print(f'[{group}] {n} 步，步驟種類', kinds, '說明框高度', hs, '沒有高亮', nohl or '無', 'scrollY', sy)
    walk('lc'); walk('ss')
    pg.locator('#panel-ss .lang button[data-lang=py]').click()
    walk('ss'); walk('lc')
    pg.locator('#panel-lc .lang button[data-lang=java]').click()
    print('結果頁說明（lc）：', pg.inner_text('#lc-explain').split('\n', 1)[1][:120])

    # ---------- 3. 互動 ----------
    pg.click('#lc-first')
    for _ in range(5): pg.keyboard.press('ArrowRight')
    print('鍵盤右鍵 5 次 → 步驟', pg.evaluate('cursors.lc + 1'))
    pg.click('#lc-tools [data-item="布丁"]')
    print('加一筆布丁：', pg.evaluate('stream.length'), pg.evaluate('[lcSteps[cursors.lc].kind, lcSteps[cursors.lc].item, lcSteps[cursors.lc].n]'))
    pg.click('#eps-plus'); pg.click('#eps-plus'); pg.click('#eps-plus')
    print('ε 調大 3 次：', pg.inner_text('#eps-val'), pg.inner_text('#w-unit'), 's =', pg.inner_text('#lcs-val'), '停在 N =', pg.evaluate('lcSteps[cursors.lc].n'))
    for _ in range(9): pg.click('#lcs-minus') if not pg.is_disabled('#lcs-minus') else None
    print('s 最小只能到', pg.inner_text('#lcs-val'), '(ε =', pg.inner_text('#eps-val'), ')')
    pg.click('#lc-tools [data-act=longer]'); print('長度 +：', pg.evaluate('stream.length'))
    pg.click('#lc-tools [data-act=shorter]'); pg.click('#lc-tools [data-act=shorter]'); print('長度 − 兩次：', pg.evaluate('stream.length'))
    pg.click('#lc-tools [data-act=random]'); print('隨機：', pg.evaluate('stream.length'), pg.inner_text('#lc-hint'))
    pg.click('#tab-ss'); pg.click('#k-minus'); pg.click('#k-minus'); pg.click('#ss-last')
    print('k =', pg.inner_text('#k-val'), pg.inner_text('#ss-explain').split('\n', 1)[1][:100])
    pg.click('#ss-tools [data-act=reset]'); pg.click('#tab-lc'); pg.click('#lc-play'); pg.wait_for_timeout(2900)
    print('自動播放 2.9 秒到步驟', pg.evaluate('cursors.lc + 1'), pg.inner_text('#lc-play')); pg.click('#lc-play')
    print('pageerror:', errs)

    # ---------- 4. 截圖 ----------
    pg.goto(U); pg.wait_for_timeout(400)
    while pg.evaluate("!(lcSteps[cursors.lc].kind === 'l-prune' && lcSteps[cursors.lc].b === 1)"): pg.click('#lc-next')
    pg.wait_for_timeout(700); pg.screenshot(path=f'{SHOT}/sc_lc_d.png', full_page=True)
    pg.click('#tab-ss')
    while pg.evaluate("ssSteps[cursors.ss].kind !== 's-replace'"): pg.click('#ss-next')
    pg.wait_for_timeout(700); pg.screenshot(path=f'{SHOT}/sc_ss_d.png', full_page=True)

    for W in (375, 320):
        m = b.new_context(viewport={'width': W, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
        m.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        mp = m.new_page(); merrs = []; mp.on('pageerror', lambda e: merrs.append(str(e)))
        mp.goto(U); mp.wait_for_timeout(500)
        sws, hs = set(), set()
        for g in ('lc', 'ss'):
            mp.click(f'#tab-{g}')
            while True:
                sws.add(mp.evaluate('document.documentElement.scrollWidth')); hs.add((g, mp.evaluate(f"$('{g}-explain').offsetHeight")))
                if mp.is_disabled(f'#{g}-next'): break
                mp.click(f'#{g}-next')
        mp.click('#tab-lc'); mp.click('#lc-first')
        while mp.evaluate("!(lcSteps[cursors.lc].kind === 'l-new' && lcSteps[cursors.lc].n === 15)"): mp.click('#lc-next')
        mp.wait_for_timeout(700)
        if W == 375:
            mp.screenshot(path=f'{SHOT}/sc_lc_m.png', full_page=True)
            mp.evaluate("$('lc-rows').scrollIntoView()"); mp.wait_for_timeout(300); mp.screenshot(path=f'{SHOT}/sc_lc_m_rows.png')
            mp.evaluate("scrollTo(0, $('lc-explain').getBoundingClientRect().top + scrollY - 200)"); mp.wait_for_timeout(300); mp.screenshot(path=f'{SHOT}/sc_lc_m_step.png')
            mp.click('#tab-ss'); mp.evaluate("cursors.ss = ssSteps.length - 1; show('ss')"); mp.wait_for_timeout(700)
            mp.evaluate("$('ss-rows').scrollIntoView()"); mp.wait_for_timeout(300); mp.screenshot(path=f'{SHOT}/sc_ss_m_rows.png')
        else:
            mp.screenshot(path=f'{SHOT}/sc_lc_320.png', full_page=True)
        print(f'手機 {W}px scrollWidth', sws, '說明框高度', sorted(hs), 'pageerror', merrs)
    b.close()
