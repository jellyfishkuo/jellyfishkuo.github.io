import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys, itertools
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from prefixspan import prefix_span
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:8794/research/prefixspan.html'
SHOT = sys.argv[1] if len(sys.argv) > 1 else '/tmp'
HL = "[...document.querySelectorAll('#code .ln.hl')].map(l=>+l.dataset.n)"


def contains(seq, pat):
    """貪心比對：pat 的每一個 itemset 依序被 seq 的某一次來店整個包含"""
    i = 0
    for e in seq:
        if i < len(pat) and set(pat[i]) <= set(e):
            i += 1
    return i == len(pat)


def subsequences(seq):
    out = set()
    def rec(k, cur):
        if k == len(seq):
            if cur: out.add(tuple(cur))
            return
        rec(k + 1, cur)
        e = sorted(set(seq[k]))
        for r in range(1, len(e) + 1):
            for c in itertools.combinations(e, r):
                rec(k + 1, cur + [c])
    rec(0, [])
    return out


def brute(db, ms):
    """暴力法：列舉所有出現過的子序列當候選，逐一檢查每位顧客是否包含"""
    cands = set().union(*[subsequences(s) for s in db]) if db else set()
    res = {}
    for c in cands:
        n = sum(contains(s, c) for s in db)
        if n >= ms: res[c] = n
    return res


with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)

    # 1. 隨機序列資料庫：網頁 JS vs Python vs 暴力法
    random.seed(11)
    bad = total = 0
    for trial in range(300):
        db = [[random.sample(ITEMS, random.randint(1, 3)) for _ in range(random.randint(0, 5))] for _ in range(random.randint(1, 8))]
        ms = random.randint(1, len(db))
        py = {k: v for k, v in prefix_span(db, ms).items()}
        br = brute(db, ms)
        got = pg.evaluate("([d,m])=>{const tr=buildTrace(d,m);return tr[tr.length-1].result.map(r=>[r.pat,r.sup])}", [db, ms])
        js = {tuple(tuple(e) for e in pat): n for pat, n in got}
        order_ok = list(js) == list(py)          # 找到的順序也要跟 Python 一樣（同樣的遞迴順序）
        total += len(br)
        if not (js == py == br and order_ok and len(got) == len(js)):
            bad += 1
            if bad < 3: print('MISMATCH', db, ms, set(js) ^ set(br))
    print(f'random: 300 DBs, {total} patterns, mismatches: {bad}')

    # 2. 範例從頭按到尾（每個範例、幾個門檻）
    pg.reload(); pg.wait_for_timeout(400)
    for preset in range(3):
        pg.click(f'#presets button >> nth={preset}')
        seen = []
        while True:
            st = pg.evaluate("[trace[cursor].kind, document.getElementById('explain').offsetHeight, window.scrollY, " + HL + "]")
            seen.append(st)
            if pg.is_disabled('#btn-next'): break
            pg.click('#btn-next')
        kinds = {}
        for k, h, y, hl in seen:
            kinds.setdefault(k, set()).add((hl[0], hl[-1], len(hl)) if hl else None)
        print(f'preset {preset}: steps', len(seen), 'explain heights', set(s[1] for s in seen), 'scrollY', set(s[2] for s in seen))
        for k, v in kinds.items(): print('   ', k, sorted(v, key=str))
    pg.click('#lang button[data-lang=py]')
    pg.click('#presets button >> nth=0')
    pyk = {}
    for i in range(12):
        pg.click('#btn-next')
        k = pg.evaluate("trace[cursor].kind+(trace[cursor].ext?trace[cursor].ext.k:'')")
        pyk.setdefault(k, pg.evaluate(HL))
    print('py hl', pyk)
    pg.click('#lang button[data-lang=java]')

    # 3. 門檻、計數表點選、特殊情況截圖
    pg.click('#btn-first')
    def goto(cond):
        pg.evaluate("cursor=0;showStep()")
        while not pg.evaluate(cond): pg.click('#btn-next')
    goto("trace[cursor].kind==='count'&&trace[cursor].special.length>0")
    print('special explain:', pg.inner_text('#explain')[:200])
    pg.click('#cnt td[data-k=i][data-x="麵包"]')
    print('picked rows', pg.evaluate("[...document.querySelectorAll('.srow.pick .who')].map(x=>x.textContent)"), pg.inner_text('#cnt-hint'))
    pg.screenshot(path=f'{SHOT}/ps_special.png', full_page=True)
    goto("trace[cursor].kind==='extend'&&trace[cursor].moved.length>0")
    pg.screenshot(path=f'{SHOT}/ps_moved.png', full_page=True)
    goto("trace[cursor].kind==='count'&&trace[cursor].prefix.length===2")
    pg.locator('.a-seq').screenshot(path=f'{SHOT}/ps_seq.png')
    pg.click('#sup-minus'); print('minSup 2 patterns', pg.evaluate("trace[trace.length-1].result.length"))
    pg.click('#sup-plus'); pg.click('#sup-plus'); print('minSup 4 patterns', pg.evaluate("trace[trace.length-1].result.length"))

    # 4. 編輯資料
    pg.click('#btn-edit')
    pg.click('.visit[data-sid="0"][data-k="2"]')
    pg.click('#palette .opt[data-item="牛奶"]')
    pg.click('[data-add="5"]')
    pg.click('#palette .opt[data-item="飯糰"]')
    pg.click('#btn-add-cust')
    pg.screenshot(path=f'{SHOT}/ps_edit.png', full_page=True)
    pg.click('[data-del="1"]')
    pg.click('[data-add="0"]')       # 留一個空的來店，完成時要被拿掉
    pg.click('#btn-edit')
    dbnow = pg.evaluate("db")
    print('edited db', dbnow)
    exp = prefix_span(dbnow, pg.evaluate('minSup'))
    got = pg.evaluate("trace[trace.length-1].result.map(r=>[r.pat,r.sup])")
    print('edited ok', {tuple(tuple(e) for e in a): n for a, n in got} == dict(exp))
    pg.click('#presets button >> nth=3')     # 隨機
    print('random preset patterns', pg.evaluate("trace[trace.length-1].result.length"))
    pg.click('#presets button >> nth=0')
    print('errs', errs)

    # 5. 手機
    for w in (375, 320):
        mc = b.new_context(viewport={'width': w, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
        mc.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        m = mc.new_page(); merr = []
        m.on('pageerror', lambda e: merr.append(str(e)))
        m.goto(U); m.wait_for_timeout(400)
        sws, hs = set(), set()
        while True:
            sws.add(m.evaluate('document.documentElement.scrollWidth')); hs.add(m.evaluate("document.getElementById('explain').offsetHeight"))
            if m.is_disabled('#btn-next'): break
            m.click('#btn-next')
            if m.evaluate("trace[cursor].kind==='count'&&trace[cursor].special.length>0") and w == 375:
                m.screenshot(path=f'{SHOT}/ps_mobile_{w}.png', full_page=True)
        m.click('#btn-edit'); m.click('.visit[data-sid="0"][data-k="0"]'); sws.add(m.evaluate('document.documentElement.scrollWidth'))
        if w == 320: m.screenshot(path=f'{SHOT}/ps_mobile_{w}_edit.png', full_page=True)
        print(f'mobile {w}: scrollWidth', sws, 'explain heights', hs, 'errs', merr)
        mc.close()
    b.close()
