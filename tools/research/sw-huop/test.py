"""隨機串流交叉比對（網頁 JS vs Python 版 vs 暴力法）、論文範例數字、從頭按到尾檢查版面。
需要本機伺服器：cd <repo> && python3 -m http.server 8832（或設環境變數 PORT）"""
import os, sys, math, random, itertools
from fractions import Fraction as F
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from sw_huop import HUOPS, run
from playwright.sync_api import sync_playwright
U = 'http://127.0.0.1:%s/research/sw-huop.html' % os.environ.get('PORT', '8832')
SHOT = os.environ.get('SHOT', '')                 # 截圖資料夾（不要放在 repo 裡）
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 300
SHOP = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
LET = list('ABCDEFGH')


def brute(profit, txs, B, W, a, b):
    """只看視窗裡的交易，列舉所有組合，用分數精確算支持度和平均佔有率"""
    out = {}
    items = sorted({i for t in txs for i in t})
    tus = [sum(q * profit[i] for i, q in t.items()) for t in txs]
    for n in range(1, len(items) + 1):
        for s in itertools.combinations(items, n):
            occ = [k for k, t in enumerate(txs) if all(i in t for i in s)]
            if not occ or len(occ) * 100 < B * W * a:
                continue
            uo = sum(F(sum(txs[k][i] * profit[i] for i in s), tus[k]) for k in occ) / len(occ)
            if uo >= F(b, 100):
                out[frozenset(s)] = (len(occ), uo)
    return out


def rand_cfg(rng):
    items = rng.choice([SHOP, LET])[:rng.randint(3, 6 if rng.random() < 0.7 else 8)]
    n = rng.randint(4, 14)
    db = [{i: rng.randint(1, 5) for i in rng.sample(items, rng.randint(1, len(items)))} for _ in range(n)]
    W = rng.randint(2, 4)
    B = rng.randint(1, max(1, min(3, n // W)))
    if n // B < W: W = n // B if n // B >= 2 else 2
    if n // B < W: B = 1
    return dict(items=items, profit={i: rng.randint(1, 40) for i in items}, db=db, B=B, W=W,
                a=rng.randrange(10, 101, 5), b=rng.randrange(5, 101, 5))


with sync_playwright() as p:
    br = p.chromium.launch()
    ctx = br.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)

    # 1. 隨機串流：每個視窗 JS == Python == 暴力法
    rng = random.Random(11)
    bad = wins = nonempty = 0
    for trial in range(TRIALS):
        c = rand_cfg(rng)
        js = pg.evaluate("c => { c.minSup = minSupOf(c); c.cms = Math.ceil(c.minSup); return runAll(c); }", c)
        py = run(c['profit'], c['db'], c['B'], c['W'], c['a'], c['b'])
        if len(js) != len(py): bad += 1; continue
        for jw, (win, res) in zip(js, py):
            wins += 1
            txs = [t for b in win for t in c['db'][b * c['B']:(b + 1) * c['B']]]
            bf = brute(c['profit'], txs, c['B'], c['W'], c['a'], c['b'])
            pyd = {frozenset(k): v for k, v in res.items()}
            jsd = {frozenset(k): (s, u) for k, s, u in jw['pats']}
            ok = jw['win'] == win and jw['ok'] and set(jsd) == set(pyd) == set(bf)
            ok = ok and all(jsd[k][0] == pyd[k][0] == bf[k][0] and abs(jsd[k][1] - pyd[k][1]) < 1e-12
                            and abs(pyd[k][1] - float(bf[k][1])) < 1e-9 for k in bf)
            nonempty += bool(bf)
            if not ok:
                bad += 1
                if bad < 4: print('MISMATCH', c, win, jsd, pyd, bf)
    print(f'random: {TRIALS} 組串流、{wins} 個視窗（{nonempty} 個有結果），不一致 {bad}')

    # 2. 論文的範例數字
    E = pg.evaluate("""() => { loadPreset('paper1'); const tr = buildTrace(cfg);
        const s = tr.filter(x => x.kind === 'check' && x.x.items.join() === 'E')[1];
        return [s.x.sumUo, s.ub1, s.ub2]; }""")
    DE = pg.evaluate("""() => { loadPreset('paper1'); cfg.a = 20; cfg.b = 50; setCfg(cfg);
        return runAll(cfg)[0].pats.find(p => p[0].join() === 'E,D' || p[0].join() === 'D,E')[2]; }""")
    T3 = pg.evaluate("() => { loadPreset('paper3'); return runAll(cfg).map(r => [r.pats.length, r.ok]); }")
    print('論文 Example 4：E 的 sumUo %.2f、UBUO1 %.2f（1.24）、UBUO2 %.3f（0.963）' % tuple(E), '| DE 佔有率 %.3f（0.648）' % DE, '| Table 3 每個視窗', T3, '（18、16）')
    pg.evaluate("() => { loadPreset('shop'); rebuild(); }")

    # 3. 從頭按到尾：.card 位置不能變、說明框高度固定、沒有水平捲動
    def walk(w, h, preset='shop', extreme=False):
        c2 = br.new_context(viewport={'width': w, 'height': h}, is_mobile=w < 600, has_touch=w < 600)
        c2.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        q = c2.new_page(); e2 = []
        q.on('pageerror', lambda e: e2.append(str(e)))
        q.goto(U)
        if preset != 'shop':
            q.select_option('#preset', preset)
        if extreme:   # 最極端：α、β 都調到最低，量完要多久
            q.wait_for_timeout(300)
            q.wait_for_function("!document.documentElement.hasAttribute('aria-busy')")
            ext = "cfg.a = 30; cfg.b = 5;" if preset == 'paper3' else "cfg.a = 10; cfg.b = 5; cfg.B = 1; cfg.W = 4;"
            q.evaluate("window.__t0 = performance.now();" + ext + "rebuild()")
            q.wait_for_function("!document.documentElement.hasAttribute('aria-busy')")
            print(f'  極端設定（{preset}：{ext}）{q.evaluate("trace.length")} 步，量完 {q.evaluate("performance.now() - window.__t0"):.0f} ms')
            c2.close(); return
        q.wait_for_function("!document.documentElement.hasAttribute('aria-busy')")
        q.evaluate("window.__t0 = performance.now(); rebuild()")
        q.wait_for_function("!document.documentElement.hasAttribute('aria-busy')")
        busy = q.evaluate("performance.now() - window.__t0")
        # 重新產生後馬上每 30ms 按一次下一步（量完之前按的會排隊）
        q.evaluate("rebuild()")
        n = q.evaluate('trace.length')
        for i in range(n - 1):
            q.click('#btn-next'); q.wait_for_timeout(30)
        q.wait_for_timeout(3000)
        q.evaluate("cursor = 0; showStep(false)")
        pos = lambda: q.evaluate("[...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.height)]; })")
        base = pos(); moved = 0; sws = set(); ex = set(); hl0 = 0
        while True:
            if pos() != base: moved += 1
            sws.add(q.evaluate('document.documentElement.scrollWidth'))
            ex.add(q.evaluate("document.getElementById('explain').offsetHeight"))
            hl0 += q.evaluate("document.querySelectorAll('#code .ln.hl').length") == 0
            if q.is_disabled('#btn-next'): break
            q.click('#btn-next')
        print(f'  {w}px {preset}：{n} 步，量完 {busy:.0f} ms，.card 位置變動 {moved} 次（{len(base)} 張卡），scrollWidth {sws}，說明框高度 {ex}，沒高亮的步驟 {hl0}，pageerror {e2}')
        if SHOT:
            q.evaluate("cursor = trace.findIndex(s => s.kind === 'check' && s.verdict === 'ub2'); if (cursor < 0) cursor = 40; showStep(false)")
            q.wait_for_timeout(600)
            q.screenshot(path=f'{SHOT}/sw_{w}_{preset}.png', full_page=True)
        c2.close()

    for w, h in ((375, 760), (1280, 900)): walk(w, h)
    walk(320, 700); walk(375, 760, 'paper3')
    walk(1280, 900, 'shop', True); walk(1280, 900, 'paper1', True); walk(1280, 900, 'paper3', True)

    # 4. 互動
    pg.click('#be-plus'); pg.click('#a-minus'); pg.click('#w-minus'); pg.click('#b-plus')
    print('互動後', pg.inner_text('#derived'))
    pg.click('#lang button[data-lang=py]'); pg.click('#btn-next')
    pg.click('#btn-play'); pg.wait_for_timeout(2000); pg.click('#btn-play')
    pg.keyboard.press('ArrowRight'); pg.keyboard.press('ArrowLeft')
    pg.click('#ph1-first'); print('跳到', pg.evaluate('trace[cursor].kind'))
    print('errs', errs)
    br.close()
