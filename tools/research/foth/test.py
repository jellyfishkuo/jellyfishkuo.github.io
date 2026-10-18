"""FOTH：網頁 JS、Python 版、暴力法交叉比對，並從頭按到尾檢查每個區塊不會移動。
需要本機伺服器：cd <repo> && python3 -m http.server 8831（或設環境變數 PORT）"""
import os, random, sys, itertools, time
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from foth import foth
from hui_miner import hui_miner
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片', '豆漿']
U = 'http://127.0.0.1:%s/research/foth.html' % os.environ.get('PORT', '8831')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 300


def brute(db, profit, mu):
    out = {}
    for n in range(1, len(ITEMS) + 1):
        for s in itertools.combinations(ITEMS, n):
            u = sum(sum(t[i] * profit[i] for i in s) for t in db if all(i in t for i in s))
            if u >= mu: out[frozenset(s)] = u
    return out


def walk(pg, label):
    """載入後馬上每 30ms 按一次下一步直到最後；量完之後每個 .card 的位置都不能再變"""
    pg.goto(U); pg.wait_for_timeout(3000)
    t0 = time.time()
    pos0 = pg.evaluate("[...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.height)]; })")
    moved, n, hl = 0, 1, set()
    while not pg.is_disabled('#btn-next'):
        pg.click('#btn-next'); pg.wait_for_timeout(30); n += 1
        pos = pg.evaluate("[...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.height)]; })")
        if pos != pos0: moved += 1
        hl.add(pg.evaluate("document.querySelectorAll('#code .ln.hl').length > 0"))
    sw = pg.evaluate('[document.documentElement.scrollWidth, innerWidth]')
    print(f'{label}: 走了 {n} 步，.card 位置變動 {moved} 次，每步都有高亮 {hl == {True}}，scrollWidth {sw}')
    return moved


with sync_playwright() as p:
    b = p.chromium.launch()
    errs = []
    ctx = b.new_context(viewport={'width': 1280, 'height': 900}); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)
    bad = nonempty = 0
    for trial in range(TRIALS):
        items = random.sample(ITEMS, random.randint(1, len(ITEMS)))
        db = [{i: random.randint(1, 5) for i in random.sample(items, random.randint(1, len(items)))} for _ in range(random.randint(1, 10))]
        profit = {i: random.randint(1, 40) for i in ITEMS}
        total = sum(t[i] * profit[i] for t in db for i in t)
        mu = random.randint(1, max(1, total // random.choice([1, 2, 4])))
        py = {frozenset(k): v for k, v in foth(db, profit, mu).items()}
        bf = brute(db, profit, mu)
        hm = {frozenset(k): v for k, v in hui_miner(db, profit, mu).items()}
        got = pg.evaluate("""([d, p, m]) => { const tr = buildTrace(d, p, m), e = tr[tr.length - 1];
            return { res: e.result.map(r => [r.set, r.util]), checks: [e.hui.checks, e.stats.areas], found: e.hui.found,
                     vs: tr.filter(s => s.kind === 'area').map(s => [s.L, s.j, s.order, s.vs]) }; }""", [db, profit, mu])
        js = {frozenset(s): u for s, u in got['res']}
        ok = js == py == bf == hm and len(js) == len(got['res']) and got['checks'][0] == got['checks'][1] and got['found'] == len(bf)
        for L, j, order, vs in got['vs']:          # vs 一定等於 U(L) + RU(L)（RU 只算位元比 j 低、沒被 TWU 刪掉的商品）
            n = len(order); low = {it for k, it in enumerate(order) if n - 1 - k < j}
            want = sum(sum(t[i] * profit[i] for i in L) + sum(t[i] * profit[i] for i in t if i in low) for t in db if all(i in t for i in L))
            ok &= want == vs
        if not ok:
            bad += 1
            if bad < 4: print('MISMATCH', db, profit, mu, js, bf, got['checks'])
        nonempty += bool(bf)
    print(f'隨機 {TRIALS} 組（JS / Python / HUI-Miner / 暴力法，含 vs = U+RU、檢查的組合數一致），不一致 {bad}，有結果的 {nonempty} 組')
    # 論文範例（表 1、表 2，門檻 20）要找到表 4 的 9 個
    paper = pg.evaluate("""() => { const d = DATASETS.paper, tr = buildTrace(d.DB, d.PROFIT, 20);
        return tr[tr.length - 1].result.map(r => r.set.slice().sort().join('') + ':' + r.util).sort(); }""")
    print('論文範例 σ=20：', paper, '與表 4 一致' if paper == sorted(['efg:23', 'fg:21', 'ag:21', 'adg:24', 'ad:20', 'be:22', 'bde:25', 'g:27', 'dg:23']) else '不一致！')
    # 最極端的門檻：量完要多久
    for ds, mu in (('shop', 100), ('paper', 5)):
        ms = pg.evaluate("""async ([ds, mu]) => { useDataset(ds); minUtil = mu; const t = performance.now(); rebuild();
            while (blocksBusy) await new Promise(r => setTimeout(r, 5)); return [Math.round(performance.now() - t), trace.length]; }""", [ds, mu])
        print(f'{ds} 門檻 {mu}：{ms[1]} 步，量完 {ms[0]} ms')
    moved = walk(pg, '1280')
    for w in (375, 320):
        c2 = b.new_context(viewport={'width': w, 'height': 760}); c2.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        p2 = c2.new_page(); p2.on('pageerror', lambda e: errs.append(str(e)))
        moved += walk(p2, str(w))
        p2.click('#ds button[data-ds=paper]'); p2.wait_for_timeout(800)
        print(f'  {w} 論文範例 scrollWidth', p2.evaluate('document.documentElement.scrollWidth'))
        c2.close()
    print('pageerror', errs)
    b.close()
