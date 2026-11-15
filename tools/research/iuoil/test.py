"""隨機增量資料交叉比對（網頁 JS vs Python 版 vs 暴力法）、論文範例數字、從頭按到尾檢查版面。
需要本機伺服器：cd <repo> && python3 -m http.server 8775（或設環境變數 PORT）"""
import os, sys, random, itertools
from fractions import Fraction as F
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from iuoil import run
from playwright.sync_api import sync_playwright
U = 'http://127.0.0.1:%s/research/iuoil.html' % os.environ.get('PORT', '8775')
SHOT = os.environ.get('SHOT', '')                 # 截圖資料夾（不要放在 repo 裡）
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 300
SHOP = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
LET = list('abcdefgh')


def brute(profit, txs, a, b):
    """列舉所有組合，用分數精確算支持度和平均佔有率"""
    out, n = {}, len(txs)
    items = sorted({i for t in txs for i in t})
    tus = [sum(q * profit[i] for i, q in t.items()) for t in txs]
    for k in range(1, len(items) + 1):
        for s in itertools.combinations(items, k):
            occ = [j for j, t in enumerate(txs) if all(i in t for i in s)]
            if not occ or len(occ) * 100 < n * a:
                continue
            uo = sum(F(sum(txs[j][i] * profit[i] for i in s), tus[j]) for j in occ) / len(occ)
            if uo >= F(b, 100):
                out[frozenset(s)] = (len(occ), uo)
    return out


def rand_cfg(rng):
    items = rng.choice([SHOP, LET])[:rng.randint(3, 6 if rng.random() < 0.7 else 8)]
    batches = [[{i: rng.randint(1, 5) for i in rng.sample(items, rng.randint(1, len(items)))}
                for _ in range(rng.randint(1, 6 if k == 0 else 3))] for k in range(rng.randint(1, 4))]
    return dict(items=items, emoji={}, profit={i: rng.randint(1, 40) for i in items}, batches=batches,
                a=rng.randrange(5, 101, 5), b=rng.randrange(5, 101, 5))


with sync_playwright() as p:
    br = p.chromium.launch()
    ctx = br.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)

    # 1. 隨機增量資料：每一次挖的結果 JS == Python == 暴力法（含多批新增）
    rng = random.Random(11)
    bad = rounds = nonempty = multi = 0
    for trial in range(TRIALS):
        c = rand_cfg(rng)
        js = pg.evaluate("c => { setCfg(c); return runAll(c); }", c)
        py = run(c['profit'], c['batches'], c['a'], c['b'])
        multi += len(c['batches']) > 1
        if len(js) != len(py): bad += 1; continue
        n = 0
        for k, (jw, res) in enumerate(zip(js, py)):
            rounds += 1
            n += len(c['batches'][k])
            bf = brute(c['profit'], [t for bt in c['batches'] for t in bt][:n], c['a'], c['b'])
            pyd = {frozenset(x): v for x, v in res.items()}
            jsd = {frozenset(x): (s, u) for x, s, u in jw['pats']}
            ok = jw['n'] == n and jw['ok'] and set(jsd) == set(pyd) == set(bf)
            ok = ok and all(jsd[x][0] == pyd[x][0] == bf[x][0] and abs(jsd[x][1] - pyd[x][1]) < 1e-12
                            and abs(pyd[x][1] - float(bf[x][1])) < 1e-9 for x in bf)
            nonempty += bool(bf)
            if not ok:
                bad += 1
                if bad < 4: print('MISMATCH', c, k, jsd, pyd, bf)
    print(f'random: {TRIALS} 組（{multi} 組有新增批次）、{rounds} 次挖掘（{nonempty} 次有結果），不一致 {bad}')

    # 2. 論文的範例數字（Fig. 5、7、8、9、10，Example 4、5）
    R = pg.evaluate("""() => {
        const r3 = x => Math.round(x * 1000) / 1000;
        loadDataset('paper'); let tr = buildTrace(cfg);
        const orders = tr.filter(s => s.kind === 'result').map(s => s.order.join(''));
        const gl0 = tr.filter(s => s.kind === 'result')[0].gl.map(g => [g.items[0], r3(g.suo), r3(g.sruo)]);
        const b0 = tr.filter(s => s.kind === 'result')[0].gl.find(g => g.items[0] === 'b').rows.map(r => r[2] + r[3]);
        const fin = tr.filter(s => s.kind === 'result')[2];
        const pats = fin.results[2].pats.map(p => p.items.join('') + ' ' + p.sup + ' ' + r3(p.uo));
        const ck = tr.filter(s => s.kind === 'check' && s.b === 2 && ['ef', 'af', 'b', 'f'].includes(s.x.items.join('')))
            .map(s => s.x.items.join('') + ' ' + s.verdict + ' ' + r3(s.verdict === 'lub' ? s.lub : s.ub));
        cfg.a = 25; cfg.b = 25; tr = buildTrace(cfg);
        const e = tr.filter(s => s.kind === 'check' && s.b === 2 && s.x.items.join('') === 'e')[0];
        const ext = tr.filter(s => s.kind === 'extend' && s.b === 2 && s.x.items.join('') === 'e')[0];
        const ea = ext.news.find(n => n.items.join('') === 'ea'), ed = ext.news.find(n => n.items.join('') === 'ed');
        const ext2 = tr.filter(s => s.kind === 'extend' && s.b === 2 && s.x.items.join('') === 'ea')[0];
        const ead = ext2.news.find(n => n.items.join('') === 'ead');
        return { orders, gl0, b0, pats, ck, e: [r3(e.x.suo), r3(e.x.sruo), r3(e.ub)],
                 ea: [r3(ea.suo), r3(ea.sruo), ea.rows[0].slice(1, 5).map(v => typeof v === 'number' ? r3(v) : v)],
                 ed: [r3(ed.suo), r3(ed.sruo), ed.rows[0].slice(1, 5).map(v => typeof v === 'number' ? r3(v) : v)],
                 ead: [r3(ead.suo), r3(ead.rows[0][1])] }; }""")
    for k, v in R.items(): print('  論文', k, v)
    pg.evaluate("() => { loadDataset('shop'); rebuild(); }")

    # 3. 從頭按到尾：.card 位置不能變、說明框高度固定、沒有水平捲動
    def walk(w, h, ds='shop', extreme=False):
        c2 = br.new_context(viewport={'width': w, 'height': h}, is_mobile=w < 600, has_touch=w < 600, color_scheme='dark')
        c2.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        q = c2.new_page(); e2 = []
        q.on('pageerror', lambda e: e2.append(str(e)))
        q.goto(U)
        if ds != 'shop':
            q.wait_for_function("!document.documentElement.hasAttribute('aria-busy')")
            q.click(f'#ds button[data-ds={ds}]')
        q.wait_for_function("!document.documentElement.hasAttribute('aria-busy')")
        if extreme:   # 最極端：α、β 都調到最低，量完要多久
            q.evaluate("window.__t0 = performance.now(); cfg.a = 5; cfg.b = 5; rebuild()")
            q.wait_for_function("!document.documentElement.hasAttribute('aria-busy')")
            print(f'  極端設定（{ds}，α = β = 5%）{q.evaluate("trace.length")} 步，量完 {q.evaluate("performance.now() - window.__t0"):.0f} ms，pageerror {e2}')
            c2.close(); return
        q.evaluate("window.__t0 = performance.now(); rebuild()")
        q.wait_for_function("!document.documentElement.hasAttribute('aria-busy')")
        busy = q.evaluate("performance.now() - window.__t0")
        q.evaluate("rebuild()")   # 重新產生後馬上每 30ms 按一次下一步（量完之前按的會排隊）
        n = q.evaluate('trace.length')
        for i in range(n - 1):
            q.click('#btn-next'); q.wait_for_timeout(30)
        q.wait_for_function("!document.documentElement.hasAttribute('aria-busy')")
        q.wait_for_timeout(500)
        q.evaluate("cursor = 0; showStep()")
        pos = lambda: q.evaluate("[...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.height)]; })")
        base = pos(); moved = 0; sws = set(); ex = set(); hl0 = 0
        while True:
            if pos() != base: moved += 1
            sws.add(q.evaluate('document.documentElement.scrollWidth'))
            ex.add(q.evaluate("document.getElementById('explain').offsetHeight"))
            hl0 += q.evaluate("document.querySelectorAll('#code .ln.hl').length") == 0
            if q.is_disabled('#btn-next'): break
            q.click('#btn-next')
        print(f'  {w}px {ds}：{n} 步，量完 {busy:.0f} ms，.card 位置變動 {moved} 次（{len(base)} 張卡），scrollWidth {sws}，說明框高度 {ex}，沒高亮的步驟 {hl0}，pageerror {e2}')
        if SHOT:
            for kind in ('relink', 'extend'):
                q.evaluate(f"cursor = trace.findIndex(s => s.kind === '{kind}' && s.b === 1); showStep()")
                q.wait_for_timeout(400)
                q.screenshot(path=f'{SHOT}/iuoil_{w}_{ds}_{kind}.png', full_page=True)
        c2.close()

    for w, h in ((375, 760), (1280, 900)): walk(w, h)
    walk(320, 700); walk(375, 760, 'paper')
    walk(1280, 900, 'shop', True); walk(1280, 900, 'paper', True)

    # 4. 互動
    pg.click('#be-plus'); pg.click('#a-minus')
    print('互動後', pg.inner_text('#derived'))
    pg.click('#lang button[data-lang=py]'); pg.click('#btn-next')
    pg.click('#btn-play'); pg.wait_for_timeout(2000); pg.click('#btn-play')
    pg.keyboard.press('ArrowRight'); pg.keyboard.press('ArrowLeft')
    pg.click('#ph2-first'); print('跳到', pg.evaluate('trace[cursor].kind'))
    print('errs', errs)
    br.close()
