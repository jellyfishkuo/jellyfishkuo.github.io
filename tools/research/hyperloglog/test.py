"""hyperloglog.html 驗證：JS ↔ Python ↔ 位元字串暴力法比對雜湊、暫存器與估計值、合併、誤差統計、逐步走完、區塊位置不動、截圖
需要本機伺服器：cd <repo> && python3 -m http.server 8815"""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys, math
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from hyperloglog import HyperLogLog, hash32, STORE_B
from playwright.sync_api import sync_playwright

U = 'http://127.0.0.1:8815/research/hyperloglog.html'
SHOT = sys.argv[1] if len(sys.argv) > 1 else '.'
random.seed(20261016)


def rand_key():
    r = random.random()
    if r < 0.7: return 'M-%08d' % random.randrange(10 ** 8)
    if r < 0.85: return ''.join(random.choice('會員卡號咖啡麵包☕🍞🥛') for _ in range(random.randint(1, 5)))   # UTF-8 多位元組
    return ''.join(random.choice('abcXYZ019 -_') for _ in range(random.randint(0, 12)))


def rand_stream():
    n = random.choice([random.randint(1, 30), random.randint(30, 600), random.randint(600, 4000)])
    out = []
    for i in range(n):
        out.append(random.choice(out) if out and random.random() < 0.3 else rand_key())
    return out


def brute(keys, p):
    """位元字串暴力法：不用位元運算，直接看 32 個字元"""
    M = [0] * (1 << p)
    for k in keys:
        bits = format(hash32(k), '032b')
        j = int(bits[:p], 2)
        rest = bits[p:]
        rho = rest.index('1') + 1 if '1' in rest else len(rest) + 1
        M[j] = max(M[j], rho)
    return M


with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)

    # ---------- 1. 隨機串流：雜湊、暫存器、估計值 ----------
    N_TRIAL = 320
    bad = {'hash': 0, 'M': 0, 'brute': 0, 'est': 0, 'trace': 0, 'merge': 0}
    n_exact = n_ulp = 0
    n_keys = 0; modes = {}
    for t in range(N_TRIAL):
        p = random.randint(4, 10)
        keys = rand_stream()
        other = rand_stream()
        js = pg.evaluate("""([keys, other, p]) => {
            const r = hllRun(keys, p);
            const T = hllTrace(keys.slice(0, 30), p);
            const u = hllRun(keys.concat(other), p), o = hllRun(other, p);
            return { r, hs: keys.map(hashRaw), traceM: T[T.length - 1].M, mergeEq: JSON.stringify(u.M) === JSON.stringify(r.M.map((x, j) => Math.max(x, o.M[j]))) };
        }""", [keys, other, p])
        n_keys += len(keys)
        if js['hs'] != [hash32(k) for k in keys]: bad['hash'] += 1
        h = HyperLogLog(p)
        for k in keys: h.add(k)
        if h.M != js['r']['M']: bad['M'] += 1
        if brute(keys, p) != h.M: bad['brute'] += 1
        e = h.estimate()
        # 調和平均那條路兩邊算出來完全一樣；linear counting 的 ln() 是各自的數學函式庫算的，最後一位可能差 1 ulp
        if e == js['r']['est']: n_exact += 1
        elif abs(e - js['r']['est']) <= 2 * math.ulp(e) and js['r']['mode'] == 'small': n_ulp += 1
        else: bad['est'] += 1
        modes[js['r']['mode']] = modes.get(js['r']['mode'], 0) + 1
        h30 = HyperLogLog(p)
        for k in keys[:30]: h30.add(k)
        if h30.M != js['traceM']: bad['trace'] += 1
        # 合併 = 一起丟進去
        h2, hu = HyperLogLog(p), HyperLogLog(p)
        for k in other: h2.add(k)
        for k in keys + other: hu.add(k)
        h.merge(h2)
        if h.M != hu.M or not js['mergeEq']: bad['merge'] += 1
    print(f'[random] {N_TRIAL} 組隨機串流（p 4~10、長度 1~4000、三成回頭客、含中文與 emoji），共 {n_keys} 個卡號：', bad, '估計方式', modes)
    print(f'  估計值：{n_exact} 組完全相同、{n_ulp} 組只差最後一位（ln 的 1 ulp）、其他 0 組')

    # 頁面上的預設範例 ↔ Python（合併那一步）
    ex = pg.evaluate("(() => { const s = steps[steps.length - 1]; return { A: s.M, B: s.MB, U: s.MU, eA: s.e.est, eB: s.eB.est, eU: s.eU.est }; })()")
    from hyperloglog import STORE_A
    a, bb = HyperLogLog(4), HyperLogLog(4)
    for k in STORE_A: a.add(k)
    for k in STORE_B: bb.add(k)
    close = lambda x, y: abs(x - y) <= 2 * math.ulp(y)
    ok = ex['A'] == a.M and ex['B'] == bb.M and close(ex['eA'], a.estimate()) and close(ex['eB'], bb.estimate())
    a.merge(bb)
    print('預設範例 A、B、合併的暫存器與估計 ↔ Python：', ok and ex['U'] == a.M and close(ex['eU'], a.estimate()), f"(A≈{ex['eA']:.4f} B≈{ex['eB']:.4f} 合併≈{ex['eU']:.4f})")

    # ---------- 2. 誤差統計 ----------
    pg.wait_for_function('pStats !== null', timeout=20000)
    ps = pg.evaluate('pStats')
    print('[誤差] 網頁實測（每種 p 30 組 × 10,000 位不同會員）：')
    for r in ps:
        print(f"  p={r['p']:2d} 理論 {r['theory']*100:5.2f}%  實測均方根 {r['rms']*100:5.2f}%  平均偏差 {r['mean']*100:+5.2f}%")
    print('[誤差] Python 版（每種 p 20 組 × 5,000 位不同會員）：', end=' ')
    for p in (6, 8, 10):
        sq = 0
        for t in range(20):
            keys = {'M-%08d' % random.randrange(10 ** 8) for _ in range(5000)}
            h = HyperLogLog(p)
            for k in keys: h.add(k)
            sq += (h.estimate() / len(keys) - 1) ** 2
        print(f'p={p} 實測 {math.sqrt(sq / 20)*100:.2f}%／理論 {104 / math.sqrt(1 << p):.2f}%', end='；')
    print()

    # ---------- 3. 從頭走到尾：說明框高度、高亮、區塊位置 ----------
    def walk(p, tag, pclicks=0):
        p.reload(); p.wait_for_timeout(500)
        for _ in range(pclicks): p.click('#p-plus')
        p.wait_for_timeout(3000)
        if not p.is_disabled('#hl-first'): p.click('#hl-first')
        kinds, hs, nohl, pos, seen_pos = {}, set(), [], set(), set()
        while True:
            st = p.evaluate("""() => [steps[cursor].kind, $('hl-explain').offsetHeight,
                [...document.querySelectorAll('#hl-code .ln.hl')].length,
                JSON.stringify([...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.left), Math.round(r.height)]; })),
                document.documentElement.scrollWidth]""")
            kinds[st[0]] = kinds.get(st[0], 0) + 1; hs.add(st[1]); pos.add(st[3])
            if not st[2]: nohl.append(st[0])
            if len(pos) > 1 and st[3] not in seen_pos: print('  位置變了：第', sum(kinds.values()), '步', st[0])
            seen_pos.add(st[3])
            if p.is_disabled('#hl-next'): break
            p.click('#hl-next')
        print(f'[{tag}] 步驟種類', kinds, '說明框高度', hs, '沒有高亮', nohl or '無', '所有 .card 位置組合數', len(pos), 'scrollWidth', st[4])
    walk(pg, '1280 p=4')
    walk(pg, '1280 p=10', pclicks=6)
    pg.locator('.lang button[data-lang=py]').click()
    pg.click('#hl-first')
    while not pg.is_disabled('#hl-next'): pg.click('#hl-next')
    pg.locator('.lang button[data-lang=java]').click()

    # ---------- 4. 互動 ----------
    pg.reload(); pg.wait_for_timeout(500)
    for _ in range(5): pg.keyboard.press('ArrowRight')
    print('鍵盤右鍵 5 次 → 步驟', pg.evaluate('cursor + 1'))
    pg.click('#p-plus'); print('p +1：', pg.inner_text('#p-val'), pg.inner_text('#p-unit'), '停在', pg.evaluate('[steps[cursor].kind, steps[cursor].vi]'))
    pg.fill('#key-in', '<b>測試</b>'); pg.click('#do-add')
    print('輸入 <b>測試</b> 來店：', pg.evaluate('[visits.length, steps[cursor].kind, steps[cursor].key]'), '有沒有變成粗體標籤：', pg.evaluate("!!document.querySelector('#hl-belt b, #h-rows b')"))
    pg.fill('#key-in', '<b>測試</b>'); pg.press('#key-in', 'Enter'); print('Enter 再來一次：', pg.evaluate('[visits.length, steps[cursor].again]'), pg.inner_text('#hl-hint'))
    pg.click('#do-again'); print('第 1 位再來：', pg.evaluate('visits.length'))
    pg.click('#do-random'); print('隨機：', pg.evaluate('visits.length'), pg.inner_text('#hl-hint'))
    pg.click('#do-reset'); pg.click('#hl-play'); pg.wait_for_timeout(2900)
    print('自動播放 2.9 秒到步驟', pg.evaluate('cursor + 1')); pg.click('#hl-play')
    exp_h = pg.evaluate("document.querySelector('.exp').offsetHeight")
    for n in ('100000', '1000', '10000'):
        pg.click(f'.exp-btns button[data-n="{n}"]'); pg.wait_for_timeout(300)
        r = pg.evaluate('[exp.n, exp.result.truth, Math.round(exp.result.est), exp.result.same, document.querySelector(".exp").offsetHeight]')
        print(f'灌入 {n}：', r[:4], '實驗卡高度不變' if r[4] == exp_h else f'高度變了 {exp_h}→{r[4]}')
    for _ in range(6): pg.click('#p-plus') if not pg.is_disabled('#p-plus') else None
    print('p 最大：', pg.inner_text('#p-val'), '實驗重算 p =', pg.evaluate('exp.result.p'), 'scrollWidth', pg.evaluate('document.documentElement.scrollWidth'))
    print('pageerror:', errs)

    # ---------- 5. 截圖 ----------
    pg.goto(U); pg.wait_for_timeout(3000)
    while pg.evaluate("!(steps[cursor].kind === 'h-update' && steps[cursor].vi === 1)"): pg.click('#hl-next')
    pg.wait_for_timeout(700); pg.screenshot(path=f'{SHOT}/hll_d.png', full_page=True)
    pg.click('#hl-last'); pg.wait_for_timeout(700); pg.screenshot(path=f'{SHOT}/hll_d_merge.png', full_page=True)

    for W in (375, 320):
        m = b.new_context(viewport={'width': W, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
        m.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        mp = m.new_page(); merrs = []; mp.on('pageerror', lambda e: merrs.append(str(e)))
        mp.goto(U)
        walk(mp, f'手機 {W}')
        if W == 375:
            walk(mp, f'手機 {W} p=7', pclicks=3)
            mp.reload(); mp.wait_for_timeout(3000)
            mp.evaluate("cursor = steps.findIndex(s => s.kind === 'h-update' && s.vi === 6); show()"); mp.wait_for_timeout(700)
            for k, sel in (('step', '#hl-explain'), ('regs', '#regs'), ('hash', '#bitrow'), ('est', '#est-formula'), ('exp', '.exp')):
                mp.evaluate(f"scrollTo(0, document.querySelector('{sel}').getBoundingClientRect().top + scrollY - 120)"); mp.wait_for_timeout(300)
                mp.screenshot(path=f'{SHOT}/hll_m_{k}.png')
            mp.evaluate("cursor = steps.length - 1; show()"); mp.wait_for_timeout(300)
            mp.evaluate("scrollTo(0, document.querySelector('#merge-box').getBoundingClientRect().top + scrollY - 120)"); mp.wait_for_timeout(300)
            mp.screenshot(path=f'{SHOT}/hll_m_merge.png')
            for _ in range(6): mp.click('#p-plus')
            mp.wait_for_timeout(2500)
            mp.evaluate("scrollTo(0, document.querySelector('#regs').getBoundingClientRect().top + scrollY - 120)"); mp.wait_for_timeout(300)
            mp.screenshot(path=f'{SHOT}/hll_m_regs_p10.png')
            print('p=10 scrollWidth', mp.evaluate('document.documentElement.scrollWidth'))
        else:
            mp.screenshot(path=f'{SHOT}/hll_320.png', full_page=True)
        print(f'手機 {W}px pageerror', merrs)
    b.close()
