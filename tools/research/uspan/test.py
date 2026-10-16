import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys, itertools
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from uspan import uspan, PROFIT
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:8813/research/uspan.html'
SHOT = sys.argv[1] if len(sys.argv) > 1 else '/tmp'
HL = "[...document.querySelectorAll('#code .ln.hl')].map(l=>+l.dataset.n)"


def subsequences(seq):
    out = set()
    def rec(k, cur):
        if k == len(seq):
            if cur: out.add(tuple(cur))
            return
        rec(k + 1, cur)
        e = sorted(seq[k])
        for r in range(1, len(e) + 1):
            for c in itertools.combinations(e, r):
                rec(k + 1, cur + [c])
    rec(0, [])
    return out


def best_match(pat, seq, profit):
    """列出樣式在這個序列裡的所有對應，取效益最大的（沒有對應回傳 None）"""
    best = None
    def rec(i, k, acc):
        nonlocal best
        if i == len(pat):
            best = acc if best is None else max(best, acc)
            return
        for j in range(k, len(seq)):
            if all(x in seq[j] for x in pat[i]):
                rec(i + 1, j + 1, acc + sum(seq[j][x] * profit[x] for x in pat[i]))
    rec(0, 0, 0)
    return best


def brute(db, profit, mu):
    """暴力法：列舉所有出現過的子序列，每位顧客取最大的對應再加總"""
    cands = set().union(*[subsequences(s) for s in db]) if db else set()
    res = {}
    for c in cands:
        u = sum(best_match(c, s, profit) or 0 for s in db)
        if u >= mu: res[c] = u
    return res


CARDS = """[...document.querySelectorAll('.card')].map(c=>{const r=c.getBoundingClientRect();return [Math.round(r.top+scrollY),Math.round(r.height)].join(',')}).join(';')"""

with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)

    # 1. 隨機資料：網頁 JS vs Python vs 暴力法（一半用頁面的利潤表，一半用隨機利潤）
    random.seed(13)
    bad = total = 0
    N = 400
    for trial in range(N):
        db = [[{x: random.randint(1, 4) for x in random.sample(ITEMS, random.randint(1, 3))} for _ in range(random.randint(0, 4))]
              for _ in range(random.randint(1, 7))]
        pr = PROFIT if trial % 2 == 0 else {x: random.randint(1, 40) for x in ITEMS}
        tot = sum(q * pr[x] for s in db for e in s for x, q in e.items())
        mu = random.randint(1, max(1, tot // 2))
        py = uspan(db, pr, mu)
        br = brute(db, pr, mu)
        got = pg.evaluate("([d,p,m])=>{const tr=buildTrace(d,p,m);return tr[tr.length-1].result.map(r=>[r.pat,r.util])}", [db, pr, mu])
        js = {tuple(tuple(e) for e in pat): u for pat, u in got}
        total += len(br)
        if not (js == py == br and list(js) == list(py) and len(got) == len(js)):
            bad += 1
            if bad < 3: print('MISMATCH', db, pr, mu, set(js.items()) ^ set(br.items()))
    print(f'random: {N} DBs, {total} patterns, mismatches: {bad}')

    # 2. 範例從頭按到尾：每種步驟、高亮、說明框
    for preset in range(2):
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
        res = pg.evaluate("trace[trace.length-1].result.map(r=>[r.pat,r.util])")
        dbn = pg.evaluate("db")
        exp = uspan(dbn, PROFIT, pg.evaluate('minUtil'))
        print(f'preset {preset}: steps', len(seen), 'explain heights', set(s[1] for s in seen), 'scrollY', set(s[2] for s in seen),
              'patterns', len(res), 'same as python', {tuple(tuple(e) for e in a): u for a, u in res} == exp)
        for k, v in kinds.items(): print('   ', k, sorted(v, key=str))
    pg.click('#presets button >> nth=0')
    pg.click('#lang button[data-lang=py]')
    pyk = {}
    for i in range(14):
        pg.click('#btn-next')
        k = pg.evaluate("trace[cursor].kind+(trace[cursor].c?trace[cursor].c.k:'')")
        pyk.setdefault(k, pg.evaluate(HL))
    print('py hl', {k: (v[0], v[-1], len(v)) if v else None for k, v in pyk.items()})
    pg.click('#lang button[data-lang=java]')

    # 3. 截圖、門檻
    def goto(cond):
        pg.evaluate("cursor=0;showStep()")
        while not pg.evaluate(cond): pg.click('#btn-next')
    pg.evaluate("cursor=0;showStep()")
    pg.screenshot(path=f'{SHOT}/us_start.png', full_page=True)
    goto("trace[cursor].kind==='check'&&trace[cursor].per.some(p=>p.ends.length>1)")
    print('multi explain:', pg.inner_text('#explain')[:260])
    pg.click('#presets button >> nth=1')
    goto("trace[cursor].kind==='check'&&trace[cursor].per.some(p=>p.ends.length>1)&&trace[cursor].prefix.length>0")
    print('multi explain (preset 1):', pg.inner_text('#explain')[:300])
    pg.screenshot(path=f'{SHOT}/us_multi.png', full_page=True)
    pg.click('#presets button >> nth=0')
    goto("trace[cursor].kind==='cands'&&trace[cursor].cands.some(c=>!c.ok)")
    pg.screenshot(path=f'{SHOT}/us_swucut.png', full_page=True)
    goto("trace[cursor].kind==='check'&&!trace[cursor].deep&&trace[cursor].spu>0")
    print('spu cut explain:', pg.inner_text('#explain')[:260])
    pg.click('#whos button >> nth=3')
    pg.locator('.a-mat').screenshot(path=f'{SHOT}/us_matrix.png')
    for v in ('100', '300'):
        pg.fill('#mu-range', v); pg.dispatch_event('#mu-range', 'input')
        print('mu', v, 'patterns', pg.evaluate("trace[trace.length-1].result.length"), 'steps', pg.evaluate('trace.length'))
    pg.click('#presets button >> nth=0')

    # 4. 編輯資料
    pg.click('#btn-edit')
    pg.click('.visit[data-sid="0"][data-k="2"]')
    pg.click('#palette .opt[data-item="牛奶"]:not(.q)')
    pg.click('#palette .opt.q[data-item="牛奶"][data-dq="1"]')
    pg.click('#palette .opt.q[data-item="咖啡"][data-dq="1"]')
    pg.click('[data-add="5"]')
    pg.click('#palette .opt[data-item="飯糰"]:not(.q)')
    pg.click('#btn-add-cust')
    pg.screenshot(path=f'{SHOT}/us_edit.png', full_page=True)
    pg.click('[data-del="1"]')
    pg.click('[data-add="0"]')       # 留一個空的來店，完成時要被拿掉
    pg.click('#btn-edit')
    dbnow = pg.evaluate("db")
    print('edited db', dbnow)
    exp = uspan(dbnow, PROFIT, pg.evaluate('minUtil'))
    got = pg.evaluate("trace[trace.length-1].result.map(r=>[r.pat,r.util])")
    print('edited ok', {tuple(tuple(e) for e in a): n for a, n in got} == exp, len(exp))
    pg.click('#presets button >> nth=2')     # 隨機
    print('random preset patterns', pg.evaluate("trace[trace.length-1].result.length"), 'mu', pg.evaluate('minUtil'))
    pg.click('#presets button >> nth=0')
    print('errs', errs)
    ctx.close()     # 關掉前面的分頁，免得它在背景量高度、拖慢下面的測試

    # 5. 從頭按到尾：手機與電腦，每個區塊的位置都不能變
    for w, h in ((375, 760), (1280, 900)):
        c2 = b.new_context(viewport={'width': w, 'height': h}, is_mobile=w < 600, has_touch=w < 600, device_scale_factor=2 if w < 600 else 1)
        c2.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        m = c2.new_page(); merr = []
        m.on('pageerror', lambda e: merr.append(str(e)))
        m.goto(U); m.wait_for_timeout(3000)
        seen = []
        while True:
            seen.append(m.evaluate(f"""[trace[cursor].kind, window.scrollY, document.getElementById('explain').offsetHeight, {CARDS},
                document.documentElement.scrollWidth, document.querySelectorAll('#code .ln.hl').length]"""))
            if m.is_disabled('#btn-next'): break
            m.click('#btn-next'); m.wait_for_timeout(20)
        print(f'width {w}: steps {len(seen)}, kinds {sorted(set(s[0] for s in seen))}, explain heights {set(s[2] for s in seen)}, '
              f'scrollY {set(s[1] for s in seen)}, card layouts {len(set(s[3] for s in seen))}, scrollWidth {set(s[4] for s in seen)}, '
              f'steps without highlight {[i + 1 for i, s in enumerate(seen) if not s[5]]}, errs {merr}')
        # 每一步都把每位顧客點一次（效益矩陣卡），每個區塊的位置也都不能變
        clicks = m.evaluate(f"""(()=>{{const lay=new Set(), n=document.querySelectorAll('#whos button').length; let c=0;
            for(let i=0;i<trace.length;i++){{cursor=i;showStep();
              for(let k=0;k<n;k++){{document.querySelectorAll('#whos button')[k].click();c++;lay.add({CARDS}+'|'+document.documentElement.scrollWidth);}}}}
            return [c, lay.size]}})()""")
        print(f'width {w}: clicked customers {clicks[0]} times, card layouts {clicks[1]}')
        if w >= 600: m.screenshot(path=f'{SHOT}/us_desktop_end.png', full_page=True)
        else:   # 截圖會暫時改視窗大小，所以放在量完位置之後
            m.evaluate("cursor=trace.findIndex(s=>s.kind==='check'&&s.prefix.length===1&&s.c.k==='s');showStep()")
            m.screenshot(path=f'{SHOT}/us_mobile_{w}.png', full_page=True)
        c2.close()
    for w in (320,):
        mc = b.new_context(viewport={'width': w, 'height': 700}, is_mobile=True, has_touch=True, device_scale_factor=2)
        mc.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        m = mc.new_page(); merr = []
        m.on('pageerror', lambda e: merr.append(str(e)))
        m.goto(U); m.wait_for_timeout(1500)
        sws = set()
        while True:
            sws.add(m.evaluate('document.documentElement.scrollWidth'))
            if m.is_disabled('#btn-next'): break
            m.click('#btn-next')
        m.click('#btn-edit'); m.click('.visit[data-sid="0"][data-k="0"]'); sws.add(m.evaluate('document.documentElement.scrollWidth'))
        m.screenshot(path=f'{SHOT}/us_mobile_{w}_edit.png', full_page=True)
        print(f'mobile {w}: scrollWidth', sws, 'errs', merr)
        mc.close()
    b.close()
