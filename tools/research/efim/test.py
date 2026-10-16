"""EFIM 頁的測試：網頁 JS、Python 版、暴力法隨機交叉比對；檢查 su、lu 真的是上界；
跟 Two-Phase、UP-Growth、HUI-Miner 頁的花費對照數字一致；從頭按到尾每個區塊位置不動。
需要本機伺服器：cd <repo> && python3 -m http.server 8804"""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys, itertools
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from efim import efim
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
BASE = 'http://127.0.0.1:8804/research/'
U = BASE + 'efim.html'


def util(db, profit, s):
    return sum(sum(t[i] * profit[i] for i in s) for t in db if all(i in t for i in s))


def brute(db, profit, mu):
    out = {}
    for n in range(1, len(ITEMS) + 1):
        for s in itertools.combinations(ITEMS, n):
            u = util(db, profit, s)
            if u >= mu: out[frozenset(s)] = u
    return out


def max_ext(db, profit, base, cands):
    """base 加上 cands 任意子集合的最大效益"""
    best = 0
    for n in range(len(cands) + 1):
        for s in itertools.combinations(cands, n):
            best = max(best, util(db, profit, list(base) + list(s)))
    return best


def check_bounds(db, profit, steps):
    """su(β,z) ≥ β∪{z} 整棵子樹（只加名單上排在 z 後面的商品）的效益；lu(β,z) ≥ 任何含 β 和 z、只加排在 β 後面商品的組合"""
    bad = 0
    order = next(s['order'] for s in steps if s['kind'] == 'end')
    pos = {it: k for k, it in enumerate(order)}
    for s in steps:
        if s['kind'] not in ('bins0', 'bins'): continue
        beta = s.get('beta') or []
        last = pos[beta[-1]] if beta else -1
        for b in s['bins']:
            z = b['item']
            # su 只算名單上（Secondary）還留著的商品：名單外的商品 lu 早就不夠，不可能出現在高效益樣式裡
            after_z = [i for i in s['keepNames'] if pos[i] > pos[z]]
            after_beta = [i for i in order if pos[i] > last and i != z]
            if b["su"] < max_ext(db, profit, beta + [z], after_z): bad += 1
            if s['kind'] == 'bins' and b['lu'] < max_ext(db, profit, beta + [z], after_beta): bad += 1
            if b['su'] > b['lu']: bad += 1
        if s['kind'] == 'bins':
            keys = [tuple(r['items']) for r in s['rows']]
            if len(keys) != len(set(keys)): bad += 1          # 只跟上一筆比，也要合併得乾乾淨淨
    return bad


with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900}); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)
    bad = 0; nonempty = 0; bound_bad = 0; merges = 0; N = 300
    for trial in range(N):
        rows = random.randint(1, 10)
        db = [{i: random.randint(1, 5) for i in random.sample(ITEMS, random.randint(1, 6))} for _ in range(rows)]
        if random.random() < 0.4:      # 多一點一模一樣的交易，才測得到合併
            db += [dict(random.choice(db)) for _ in range(random.randint(1, 4))]
        profit = {i: random.randint(1, 40) for i in ITEMS}
        total = sum(t[i] * profit[i] for t in db for i in t)
        mu = random.randint(1, max(1, total))
        py = {frozenset(k): v for k, v in efim(db, profit, mu).items()}
        bf = brute(db, profit, mu)
        steps = pg.evaluate("([d,p,m])=>{minUtil=m; const tr=buildTrace(d,p,m); minUtil=250; return tr.map(s=>({kind:s.kind,beta:s.beta,bins:s.bins,rows:s.rows,order:s.order,keepNames:s.keepNames,result:s.result,merged:s.stats.merged}))}", [db, profit, mu])
        got = steps[-1]['result']
        js = {frozenset(r['set']): r['util'] for r in got}
        if len(got) != len(js): bad += 1
        if not (js == py == bf): bad += 1; print('MISMATCH', db, profit, mu, js, py, bf); break
        bound_bad += check_bounds(db, profit, steps)
        nonempty += bool(bf); merges += steps[-1]['merged'] > 0
    print(f'random trials {N}, mismatches: {bad}, non-empty results: {nonempty}, trials with merging: {merges}, bound violations: {bound_bad}')

    # 對照表的數字要跟另外三頁自己算出來的一樣
    mine = pg.evaluate("""(()=>{const o={};for(let m=100;m<=500;m+=10){o[m]={tp:twoPhaseCost(DB,PROFIT,m),ug:upGrowthCost(DB,PROFIT,m),hm:huiMinerLists(DB,PROFIT,m)}};return o})()""")
    other = {}
    for page, expr in (('two-phase', "s=>({scans:s.stats.scans,cands:s.stats.cands})"),
                       ('up-growth', "s=>({scans:s.stats.scans,cands:s.stats.cands,trees:s.stats.trees})"),
                       ('high-utility', "s=>s.stats.lists")):
        q = ctx.new_page(); q.goto(BASE + page + '.html'); q.wait_for_timeout(300)
        other[page] = q.evaluate(f"(()=>{{const o={{}};for(let m=100;m<=500;m+=10){{const tr=buildTrace(DB,PROFIT,m);o[m]=({expr})(tr[tr.length-1])}};return o}})()")
        q.close()
    cmp_bad = 0
    for m, c in mine.items():
        if c['tp'] != other['two-phase'][m] or c['ug'] != other['up-growth'][m] or c['hm'] != other['high-utility'][m]:
            cmp_bad += 1; print('COST MISMATCH', m, c, other['two-phase'][m], other['up-growth'][m], other['high-utility'][m])
    print('cost table vs other pages, thresholds checked:', len(mine), 'mismatches:', cmp_bad, '| mu=250:', mine['250'])

    # 從頭按到尾：手機與電腦，每個區塊的位置都不能變
    for w, h in ((375, 760), (1280, 900)):
        pg.set_viewport_size({'width': w, 'height': h})
        pg.reload(); pg.wait_for_timeout(3000)
        seen = []
        while True:
            st = pg.evaluate("""[trace[cursor].kind, window.scrollY, document.getElementById('explain').offsetHeight,
                [...document.querySelectorAll('.card')].map(c=>{const r=c.getBoundingClientRect();return [Math.round(r.top+scrollY),Math.round(r.height)].join(',')}).join(';'),
                document.documentElement.scrollWidth, [...document.querySelectorAll('#code .ln.hl')].length]""")
            seen.append(st)
            if pg.is_disabled('#btn-next'): break
            pg.click('#btn-next'); pg.wait_for_timeout(20)
        print(f'width {w}: steps {len(seen)}, kinds {sorted(set(s[0] for s in seen))}, explain heights {set(s[2] for s in seen)}, '
              f'scrollY {set(s[1] for s in seen)}, card layouts {len(set(s[3] for s in seen))}, scrollWidth {set(s[4] for s in seen)}, '
              f'steps without highlight {[i + 1 for i, s in enumerate(seen) if not s[5]]}')
    print('stats', pg.inner_text('.stats').replace('\n', ' '))
    print('compare', pg.inner_text('#compare').replace('\n', ' | '))
    print('errs', errs)
    b.close()
