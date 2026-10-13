"""count-min.html 驗證：JS ↔ Python 逐筆整張表比對、估計 ≥ 真實、εN 機率保證統計、逐步走完、區塊位置不動、截圖
需要本機伺服器：cd <repo> && python3 -m http.server 8802"""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys, math
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from count_min import CountMin, ITEMS
from playwright.sync_api import sync_playwright

U = 'http://127.0.0.1:8802/research/count-min.html'
SHOT = sys.argv[1] if len(sys.argv) > 1 else '.'
random.seed(20261013)


def rand_stream():
    n = random.randint(1, 120)
    items = random.sample(ITEMS, random.randint(1, 10))
    if random.random() < 0.5:      # 偏斜（少數商品很熱門）
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

    # ---------- 1. 隨機串流：JS 每一筆之後的整張表 ↔ Python ----------
    N_TRIAL = 400
    bad = {'state': 0, 'query': 0, 'underestimate': 0, 'cu_bigger_than_cm': 0}
    arrivals = queries = over = 0
    for trial in range(N_TRIAL):
        st = rand_stream()
        w, d, cu = random.randint(2, 10), random.randint(1, 5), random.random() < 0.5
        js = pg.evaluate("""([st, w, d, cu]) => {
            const T = cmTrace(st, w, d, cu), O = cmTrace(st, w, d, !cu);
            const adds = T.filter(x => x.kind === 'c-add'), oadds = O.filter(x => x.kind === 'c-add');
            return { tables: adds.map(x => x.table), other: oadds.map(x => x.table),
                     q: T.filter(x => x.kind === 'c-query').map(x => [x.item, x.est, x.t]) };
        }""", [st, w, d, cu])
        cm, alt, truth = CountMin(w, d, cu), CountMin(w, d, not cu), {}
        for i, x in enumerate(st):
            cm.add(ITEMS.index(x) + 1); alt.add(ITEMS.index(x) + 1); truth[x] = truth.get(x, 0) + 1; arrivals += 1
            if cm.table != js['tables'][i] or alt.table != js['other'][i]: bad['state'] += 1
            plain, cons = (alt, cm) if cu else (cm, alt)
            if any(cons.table[j][c] > plain.table[j][c] for j in range(d) for c in range(w)): bad['cu_bigger_than_cm'] += 1
            for y in ITEMS:   # 每一筆之後每個商品都不能少算
                if cm.estimate(ITEMS.index(y) + 1) < truth.get(y, 0): bad['underestimate'] += 1
        pq = [[y, cm.estimate(ITEMS.index(y) + 1), truth.get(y, 0)] for y in ITEMS]
        if pq != js['q']: bad['query'] += 1
        for y, est, t in pq:
            queries += 1
            over += est - t > math.e / w * len(st) + 1e-9
    print(f'[random] {N_TRIAL} 組隨機串流（w 2~10、d 1~5、一般／保守更新各半）、共 {arrivals} 筆逐筆比對整張表：', bad)
    print(f'  結尾查詢 {queries} 次，多算超過 εN 的 {over} 次（{over / queries:.2%}）')

    # ---------- 2. 從頭走到尾：說明框高度、高亮、區塊位置 ----------
    def walk(p, tag):
        p.reload(); p.wait_for_timeout(3000)
        if not p.is_disabled('#cm-first'): p.click('#cm-first')
        kinds, hs, nohl, pos = {}, set(), [], set()
        while True:
            st = p.evaluate("""() => [steps[cursor].kind, $('cm-explain').offsetHeight,
                [...document.querySelectorAll('#cm-code .ln.hl')].length,
                JSON.stringify([...document.querySelectorAll('#main .card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.left), Math.round(r.height)]; })),
                document.documentElement.scrollWidth]""")
            kinds[st[0]] = kinds.get(st[0], 0) + 1; hs.add(st[1]); pos.add(st[3])
            if not st[2]: nohl.append(st[0])
            if p.is_disabled('#cm-next'): break
            p.click('#cm-next')
        print(f'[{tag}] 步驟種類', kinds, '說明框高度', hs, '沒有高亮', nohl or '無', '區塊位置組合數', len(pos), 'scrollWidth', st[4])
    walk(pg, '1280 一般')
    pg.click('#cu-toggle'); pg.wait_for_timeout(3000)
    pg.locator('.lang button[data-lang=py]').click()
    print('保守更新後步驟', pg.evaluate('steps.length'), pg.inner_text('#cu-toggle'))
    pg.click('#cm-first'); pg.wait_for_timeout(200)
    kinds = set()
    while not pg.is_disabled('#cm-next'):
        pg.click('#cm-next')
    pg.locator('.lang button[data-lang=java]').click()

    # ---------- 3. 互動 ----------
    pg.reload(); pg.wait_for_timeout(500)
    for _ in range(5): pg.keyboard.press('ArrowRight')
    print('鍵盤右鍵 5 次 → 步驟', pg.evaluate('cursor + 1'))
    pg.click('#w-minus'); pg.click('#w-minus'); pg.click('#w-minus')
    print('w 減 3 次：', pg.inner_text('#w-val'), pg.inner_text('#eps-unit'), '停在 N =', pg.evaluate('steps[cursor].n'))
    for _ in range(6): pg.click('#d-minus') if not pg.is_disabled('#d-minus') else None
    print('d 最小', pg.inner_text('#d-val'), pg.inner_text('#delta-unit'))
    pg.click('#cm-last'); print('結果：', pg.inner_text('#cm-explain').split('\n', 1)[1][:160])
    pg.click('#cm-tools [data-item="布丁"]'); print('加一筆布丁：', pg.evaluate('[stream.length, steps[cursor].kind, steps[cursor].item, steps[cursor].n]'))
    pg.click('#cm-tools [data-act=random]'); print('隨機：', pg.evaluate('stream.length'), pg.inner_text('#cm-hint'))
    pg.click('#cm-tools [data-act=reset]'); pg.click('#cm-play'); pg.wait_for_timeout(2900)
    print('自動播放 2.9 秒到步驟', pg.evaluate('cursor + 1')); pg.click('#cm-play')
    print('pageerror:', errs)

    # ---------- 4. 截圖 ----------
    pg.goto(U); pg.wait_for_timeout(400)
    while pg.evaluate("!(steps[cursor].kind === 'c-add' && steps[cursor].n === 12)"): pg.click('#cm-next')
    pg.wait_for_timeout(700); pg.screenshot(path=f'{SHOT}/cm_d.png', full_page=True)

    for W in (375, 320):
        m = b.new_context(viewport={'width': W, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
        m.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        mp = m.new_page(); merrs = []; mp.on('pageerror', lambda e: merrs.append(str(e)))
        mp.goto(U)
        walk(mp, f'手機 {W}')
        mp.evaluate("cursor = 12; show()"); mp.wait_for_timeout(700)
        if W == 375:
            for k, sel in (('step', '#cm-explain'), ('sketch', '#sketch'), ('query', '#q-rows'), ('hash', '#h-rows')):
                mp.evaluate(f"scrollTo(0, document.querySelector('{sel}').getBoundingClientRect().top + scrollY - 120)"); mp.wait_for_timeout(300)
                mp.screenshot(path=f'{SHOT}/cm_m_{k}.png')
            mp.click('#w-plus'); [mp.click('#w-plus') for _ in range(4)]; mp.click('#d-plus'); mp.click('#d-plus'); mp.wait_for_timeout(2500)
            mp.evaluate("scrollTo(0, document.querySelector('#sketch').getBoundingClientRect().top + scrollY - 120)"); mp.wait_for_timeout(300)
            mp.screenshot(path=f'{SHOT}/cm_m_sketch_w10.png')
            print('w=10、d=5 scrollWidth', mp.evaluate('document.documentElement.scrollWidth'))
        else:
            mp.screenshot(path=f'{SHOT}/cm_320.png', full_page=True)
        print(f'手機 {W}px pageerror', merrs)
    b.close()
