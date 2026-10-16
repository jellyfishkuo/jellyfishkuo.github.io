"""bloom-filter.html 驗證：JS ↔ Python 逐個操作比對整個陣列與查詢結果、暴力法重算、沒有偽陰性、實測誤判率、逐步走完、區塊位置不動、截圖
需要本機伺服器：cd <repo> && python3 -m http.server 8806"""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys, math
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from bloom_filter import BloomFilter, measure, false_positive_rate
from playwright.sync_api import sync_playwright

U = 'http://127.0.0.1:8806/research/bloom-filter.html'
SHOT = sys.argv[1] if len(sys.argv) > 1 else '.'
random.seed(20261016)
L = 'ABCDEFGHJKLMNPQRSTUVWXY'


def rand_key():
    r = random.random()
    if r < 0.6: return random.choice(L) + random.choice(L) + '-%08d' % random.randrange(10 ** 8)
    if r < 0.8: return ''.join(random.choice('飯糰咖啡麵包牛奶茶葉蛋☕🍞🥛') for _ in range(random.randint(1, 4)))   # UTF-8 多位元組
    return ''.join(random.choice('abcXYZ019 -_') for _ in range(random.randint(1, 12)))


def rand_case():
    m, k, cnt = random.randint(2, 64), random.randint(1, 8), random.random() < 0.5
    pool = [rand_key() for _ in range(random.randint(1, 14))]
    ops, present = [], {}
    for _ in range(random.randint(1, 40)):
        r = random.random()
        alive = [x for x, c in present.items() if c > 0]
        if r < 0.45:
            key = random.choice(pool); ops.append(['add', key]); present[key] = present.get(key, 0) + 1
        elif r < 0.85:
            ops.append(['query', random.choice(pool + [rand_key()])])
        elif cnt and alive:      # 計數版只刪加過的
            key = random.choice(alive); ops.append(['del', key]); present[key] -= 1
        elif not cnt:            # 一般版的刪除會被跳過（不能刪）
            ops.append(['del', random.choice(pool)])
    return m, k, cnt, ops


with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)

    # ---------- 1. 隨機：每個操作之後的整個陣列、查詢結果 ↔ Python ↔ 暴力法 ----------
    N_TRIAL = 300
    bad = {'cells': 0, 'brute': 0, 'query': 0, 'probe': 0, 'false_negative': 0, 'measure': 0, 'positions': 0}
    n_ops = n_query = n_del = n_fp = 0
    for trial in range(N_TRIAL):
        m, k, cnt, ops = rand_case()
        js = pg.evaluate("""([ops, m, k, cnt]) => {
            const T = bfTrace(ops.map(([op, key]) => ({ op, key })), m, k, cnt);
            const after = ops.map((_, oi) => { const ss = T.filter(s => s.oi === oi); return ss[ss.length - 1]; });
            const end = T[T.length - 1];
            return { cells: after.map(s => s.cells), kinds: after.map(s => s.kind),
                     verdict: after.map(s => s.kind === 'b-check' ? s.verdict : null),
                     probes: ops.map((_, oi) => T.filter(s => s.oi === oi && s.kind === 'b-check').length),
                     pos: ops.map(([, key]) => positions(key, m, k)),
                     meas: measOf(end) };
        }""", [ops, m, k, cnt])
        bf, multi, ever = BloomFilter(m, k, cnt), {}, set()
        for i, (op, key) in enumerate(ops):
            n_ops += 1
            if bf.positions(key) != js['pos'][i]: bad['positions'] += 1
            if op == 'add':
                bf.add(key); multi[key] = multi.get(key, 0) + 1; ever.add(key)
            elif op == 'query':
                n_query += 1
                got = bf.might_contain(key)
                if got != js['verdict'][i]: bad['query'] += 1
                p = bf.positions(key)
                first0 = next((j for j, c in enumerate(p) if bf.cells[c] == 0), None)
                if js['probes'][i] != (k if first0 is None else first0 + 1): bad['probe'] += 1
                if got and multi.get(key, 0) == 0: n_fp += 1
            elif cnt:
                n_del += 1
                bf.remove(key); multi[key] -= 1
            elif js['kinds'][i] != 'b-nodel': bad['cells'] += 1
            if bf.cells != js['cells'][i]: bad['cells'] += 1
            # 暴力法：從頭重算每一格
            brute = [0] * m
            if cnt:
                for x, c in multi.items():
                    for q in bf.positions(x): brute[q] += c
            else:
                for x in ever:
                    for q in bf.positions(x): brute[q] = 1
            if brute != bf.cells: bad['brute'] += 1
            # 每個操作之後：在集合裡的一定回答「可能在」
            for x, c in multi.items():
                if c > 0 and not bf.might_contain(x): bad['false_negative'] += 1
        present = {x for x, c in multi.items() if c > 0}
        if measure(bf, present) != js['meas']: bad['measure'] += 1
    print(f'[random] {N_TRIAL} 組隨機（m 2~64、k 1~8、一般／計數版各半、含中文與 emoji 字串），共 {n_ops} 個操作逐個比對：', bad)
    print(f'  查詢 {n_query} 次（誤判 {n_fp} 次）、計數版刪除 {n_del} 次')

    # 理論 vs 實測：隨機發票大量測
    rows = []
    for _ in range(60):
        m, k = random.choice(range(8, 65, 4)), random.randint(1, 8)
        n = random.randint(1, m // 2)
        keys = {random.choice(L) + random.choice(L) + '-%08d' % random.randrange(10 ** 8) for _ in range(n)}
        bf = BloomFilter(m, k)
        for x in keys: bf.add(x)
        rows.append((measure(bf, keys) / 1000, false_positive_rate(m, k, len(keys))))
    print('  60 組隨機 (m,k,n)：實測平均 %.3f、理論平均 %.3f、平均差 %.3f' % (sum(a for a, _ in rows) / 60, sum(t for _, t in rows) / 60, sum(abs(a - t) for a, t in rows) / 60))

    # ---------- 2. 從頭走到尾：說明框高度、高亮、區塊位置 ----------
    def walk(p, tag, toggle=False):
        p.reload(); p.wait_for_timeout(500)
        if toggle: p.click('#cnt-toggle')
        p.wait_for_timeout(3000)
        if not p.is_disabled('#bf-first'): p.click('#bf-first')
        kinds, hs, nohl, pos = {}, set(), [], set()
        while True:
            st = p.evaluate("""() => [steps[cursor].kind, $('bf-explain').offsetHeight,
                [...document.querySelectorAll('#bf-code .ln.hl')].length,
                JSON.stringify([...document.querySelectorAll('#main .card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.left), Math.round(r.height)]; })),
                document.documentElement.scrollWidth]""")
            kinds[st[0]] = kinds.get(st[0], 0) + 1; hs.add(st[1]); pos.add(st[3])
            if not st[2]: nohl.append(st[0])
            if p.is_disabled('#bf-next'): break
            p.click('#bf-next')
        print(f'[{tag}] 步驟種類', kinds, '說明框高度', hs, '沒有高亮', nohl or '無', '區塊位置組合數', len(pos), 'scrollWidth', st[4])
    walk(pg, '1280 一般版')
    walk(pg, '1280 計數版', toggle=True)
    pg.locator('.lang button[data-lang=py]').click()
    pg.click('#bf-first')
    while not pg.is_disabled('#bf-next'): pg.click('#bf-next')
    pg.locator('.lang button[data-lang=java]').click()

    # ---------- 3. 互動 ----------
    pg.reload(); pg.wait_for_timeout(500)
    for _ in range(5): pg.keyboard.press('ArrowRight')
    print('鍵盤右鍵 5 次 → 步驟', pg.evaluate('cursor + 1'))
    pg.click('#m-minus'); pg.click('#m-minus')
    print('m 減 2 次：', pg.inner_text('#m-val'), '停在第', pg.evaluate('steps[cursor].oi + 1'), '個操作')
    pg.click('#k-plus'); print('k +1：', pg.inner_text('#k-val'), pg.inner_text('#k-unit'))
    pg.click('#bf-last'); print('結果：', pg.inner_text('#bf-explain').split('\n', 1)[1][:200])
    pg.fill('#key-in', '<b>測試</b>'); pg.click('#do-add')
    print('輸入 <b>測試</b> 加入：', pg.evaluate('[ops.length, steps[cursor].kind, steps[cursor].key]'), '有沒有變成粗體標籤：', pg.evaluate("!!document.querySelector('#bf-belt b, #h-rows b')"))
    pg.fill('#key-in', '<b>測試</b>'); pg.press('#key-in', 'Enter'); print('Enter 查詢：', pg.evaluate('[ops.length, steps[cursor].kind, steps[cursor].verdict]'))
    pg.click('#cnt-toggle')
    pg.fill('#key-in', 'NO-SUCH'); pg.click('#do-del'); print('計數版刪沒加過的：', pg.evaluate('ops.length'), pg.inner_text('#bf-hint'))
    pg.fill('#key-in', '<b>測試</b>'); pg.click('#do-del'); print('計數版刪加過的：', pg.evaluate('[ops.length, steps[cursor].kind]'))
    pg.click('#do-random'); print('隨機：', pg.evaluate('ops.length'), pg.inner_text('#bf-hint'))
    pg.click('#do-reset'); pg.click('#bf-play'); pg.wait_for_timeout(2900)
    print('自動播放 2.9 秒到步驟', pg.evaluate('cursor + 1')); pg.click('#bf-play')
    for _ in range(20): pg.click('#m-plus') if not pg.is_disabled('#m-plus') else None
    for _ in range(10): pg.click('#k-plus') if not pg.is_disabled('#k-plus') else None
    print('m、k 最大：', pg.inner_text('#m-val'), pg.inner_text('#k-val'), 'scrollWidth', pg.evaluate('document.documentElement.scrollWidth'))
    print('pageerror:', errs)

    # ---------- 4. 截圖 ----------
    pg.goto(U); pg.wait_for_timeout(3000)
    while pg.evaluate("!(steps[cursor].kind === 'b-check' && steps[cursor].key === 'MN-14419200' && steps[cursor].last)"): pg.click('#bf-next')
    pg.wait_for_timeout(700); pg.screenshot(path=f'{SHOT}/bf_d.png', full_page=True)
    pg.click('#cnt-toggle'); pg.wait_for_timeout(3000)
    while pg.evaluate("steps[cursor].kind !== 'b-del'"): pg.click('#bf-next')
    pg.wait_for_timeout(700); pg.screenshot(path=f'{SHOT}/bf_d_cnt.png', full_page=True)

    for W in (375, 320):
        m = b.new_context(viewport={'width': W, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
        m.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        mp = m.new_page(); merrs = []; mp.on('pageerror', lambda e: merrs.append(str(e)))
        mp.goto(U)
        walk(mp, f'手機 {W}')
        if W == 375:
            walk(mp, f'手機 {W} 計數版', toggle=True)
            mp.reload(); mp.wait_for_timeout(3000)
            mp.evaluate("cursor = steps.findIndex(s => s.kind === 'b-check' && s.key === 'QW-58160533' && s.last); show()"); mp.wait_for_timeout(700)
            for k, sel in (('step', '#bf-explain'), ('bits', '#bits'), ('hash', '#h-rows'), ('chart', '#chart')):
                mp.evaluate(f"scrollTo(0, document.querySelector('{sel}').getBoundingClientRect().top + scrollY - 120)"); mp.wait_for_timeout(300)
                mp.screenshot(path=f'{SHOT}/bf_m_{k}.png')
            for _ in range(10): mp.click('#m-plus')
            for _ in range(5): mp.click('#k-plus')
            mp.wait_for_timeout(2500)
            mp.evaluate("scrollTo(0, document.querySelector('#bits').getBoundingClientRect().top + scrollY - 120)"); mp.wait_for_timeout(300)
            mp.screenshot(path=f'{SHOT}/bf_m_bits_big.png')
            print('m=64、k=8 scrollWidth', mp.evaluate('document.documentElement.scrollWidth'))
        else:
            mp.screenshot(path=f'{SHOT}/bf_320.png', full_page=True)
        print(f'手機 {W}px pageerror', merrs)
    b.close()
