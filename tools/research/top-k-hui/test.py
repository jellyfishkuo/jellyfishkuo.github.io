import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys, itertools
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from top_k_hui import top_k_hui
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:8799/research/top-k-hui.html'
SHOTS = sys.argv[1] if len(sys.argv) > 1 else '.'      # 截圖放哪（不要放在 repo 裡）


def brute(db, profit, k):
    """列出每個出現過的組合，照效益排序；跟第 k 名同分的全部算進來"""
    util = {}
    for n in range(1, len(ITEMS) + 1):
        for s in itertools.combinations(ITEMS, n):
            u = sum(sum(t[i] * profit[i] for i in s) for t in db if all(i in t for i in s))
            if u > 0:
                util[frozenset(s)] = u
    if len(util) < k:
        return util
    kth = sorted(util.values(), reverse=True)[k - 1]
    return {s: u for s, u in util.items() if u >= kth}


def first(pg):
    if not pg.is_disabled('#btn-first'): pg.click('#btn-first')


def walk(pg, label):
    """從第一步按到最後一步，記下每個 .card 的位置和高度，以及說明框高度"""
    pg.wait_for_timeout(3000)                       # 等區塊高度量完
    pos0 = None; moved = 0; heights = set(); steps = 0; kinds = []
    first(pg)
    while True:
        st = pg.evaluate("""[[...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.left), Math.round(r.height)]; }),
            document.getElementById('explain').offsetHeight, trace[cursor].kind, document.documentElement.scrollWidth]""")
        if pos0 is None: pos0 = st[0]
        if st[0] != pos0: moved += 1
        heights.add(st[1]); kinds.append(st[2]); steps += 1
        if st[3] != pg.viewport_size['width']: print(label, 'scrollWidth', st[3], 'at step', steps)
        if pg.is_disabled('#btn-next'): break
        pg.click('#btn-next'); pg.wait_for_timeout(15)
    print(label, 'steps', steps, 'cards', len(pos0), 'steps with moved cards', moved, 'explain heights', heights)
    return kinds


with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900}); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)
    bad = 0; ties = 0; short = 0
    for trial in range(400):
        rows = random.randint(1, 10)
        db = [{i: random.randint(1, 5) for i in random.sample(ITEMS, random.randint(1, 6))} for _ in range(rows)]
        profit = {i: random.randint(1, 30) for i in ITEMS}
        k = random.randint(1, 15)
        py = {frozenset(s): u for s, u in top_k_hui(db, profit, k).items()}
        bf = brute(db, profit, k)
        got = pg.evaluate("""([d,p,k]) => { const tr = buildTrace(d, p, k), e = tr[tr.length - 1];
            const hm = buildTrace(d, p, k, { fixed: e.mu }).pop(), z = buildTrace(d, p, k, { riu: false }).pop();
            return [e.result.map(r => [r.set, r.util]), hm.result.map(r => [r.set, r.util]), z.result.map(r => [r.set, r.util])]; }""", [db, profit, k])
        js, hm, z = ({frozenset(s): u for s, u in g} for g in got)
        if not (js == py == bf == hm == z) or len(got[0]) != len(js):
            bad += 1; print('MISMATCH', db, profit, k, js, py, bf, hm, z); break
        ties += len(bf) > k
        short += len(bf) < k
    print('random trials 400, mismatches:', bad, '| results with ties (> k):', ties, '| fewer than k itemsets:', short)

    pg.reload()
    kinds = walk(pg, 'desktop 1280')
    from collections import Counter
    print('step kinds', dict(Counter(kinds)))
    print('board', pg.inner_text('#board').replace('\n', ' '))
    print('compare', pg.inner_text('#compare').replace('\n', ' | '))
    pg.screenshot(path=SHOTS + '/desktop.png', full_page=True)
    pg.click('#lang button[data-lang=py]')
    print('py hl at end', pg.evaluate("[...document.querySelectorAll('#code .ln.hl')].map(l=>+l.dataset.n)"))
    # 找一個門檻上升的步驟截圖
    first(pg)
    while not pg.evaluate("trace[cursor].kind === 'check' && !!trace[cursor].raised && trace[cursor].raised.gone.length > 0"):
        pg.click('#btn-next')
    print('raise step:', pg.inner_text('#explain').replace('\n', ' '))
    print('java hl', pg.evaluate("[...document.querySelectorAll('#code .ln.hl')].map(l=>+l.dataset.n)"))
    pg.screenshot(path=SHOTS + '/desktop-raise.png', full_page=True)
    print('scrollY after walking (page must not scroll by itself):', pg.evaluate('scrollY'))
    for k in (1, 3, 15):
        pg.evaluate(f"setK({k})"); pg.wait_for_timeout(50)
        first(pg)
        while not pg.is_disabled('#btn-next'): pg.click('#btn-next')
        print('k =', k, '|', pg.inner_text('#explain').replace('\n', ' ')[:160])
    print('errs', errs)

    for w in (375, 320):
        m = b.new_context(viewport={'width': w, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
        m.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        mp = m.new_page(); merr = []; mp.on('pageerror', lambda e: merr.append(str(e)))
        mp.goto(U)
        walk(mp, f'mobile {w}')
        first(mp)
        for i in range(20): mp.click('#btn-next')
        mp.screenshot(path=f'{SHOTS}/mobile-{w}.png', full_page=True)
        print(f'mobile {w} scrollWidth', mp.evaluate('document.documentElement.scrollWidth'), 'errs', merr)
        m.close()
    b.close()
