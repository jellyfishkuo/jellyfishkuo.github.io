import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys, itertools
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
import fup as F
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:8782/research/incremental.html'


def brute(rows, pct):
    """暴力法：列舉所有組合直接數"""
    n = len(rows)
    need = (n * pct + 99) // 100
    out = {}
    for r in range(1, 7):
        for c in itertools.combinations(sorted(ITEMS), r):
            cnt = sum(1 for t in rows if set(c) <= t)
            if cnt >= need and cnt > 0:
                out[c] = cnt
    return out


JS = """([DB, db, p]) => {
    pct = p;
    const D = DB.map(t => new Set(t)), d = db.map(t => new Set(t));
    const L = apriori(D).L;
    const tr = buildTrace(D, L, d);
    const end = tr[tr.length - 1];
    return { L: end.newL.map(v => [v.set, v.count]), f: end.reads.f1 + end.reads.f0, r: end.reads.r1 + end.reads.r0,
             reReads: end.reReads, same: end.same, kinds: [...new Set(tr.map(s => s.kind))] };
}"""

with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page()
    errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U)
    pg.wait_for_timeout(500)

    # 1. 隨機資料交叉驗證：JS FUP vs Python FUP vs 直接對 DB∪db 重跑 Apriori vs 暴力法
    random.seed(2026)
    bad = {'js_vs_py': 0, 'py_vs_apriori': 0, 'py_vs_brute': 0, 'reads': 0, 'js_same_flag': 0}
    trials = 400
    for trial in range(trials):
        D = random.randint(1, 15)
        d = random.randint(1, 8)
        pct = random.randint(1, 100)
        k = random.randint(2, 6)
        items = random.sample(ITEMS, k)
        DB = [set(random.sample(items, random.randint(1, k))) for _ in range(D)]
        db = [set(random.sample(items, random.randint(1, k))) for _ in range(d)]
        F.reads = 0
        L = F.apriori(DB, pct)
        F.reads = 0
        py = F.fup(DB, L, db, pct)
        py_reads = F.reads
        F.reads = 0
        ap = F.apriori(DB + db, pct)
        ap_reads = F.reads
        bf = brute(DB + db, pct)
        js = pg.evaluate(JS, [[sorted(t) for t in DB], [sorted(t) for t in db], pct])
        jsL = {tuple(s): c for s, c in js['L']}
        if jsL != py: bad['js_vs_py'] += 1
        if py != ap: bad['py_vs_apriori'] += 1
        if py != bf: bad['py_vs_brute'] += 1
        if js['f'] != py_reads or js['r'] != ap_reads or js['reReads'] != ap_reads: bad['reads'] += 1
        if not js['same']: bad['js_same_flag'] += 1
    print('random trials:', trials, 'mismatches:', bad)
    pg.evaluate("pct = 30; reset()")

    # 2. 三個預設批次 + 從頭按到尾
    for i in range(3):
        pg.evaluate("window.scrollTo(0, 0)")
        pg.evaluate(f"document.querySelector('#presets button:nth-child({i + 1})').click()")
        pg.wait_for_timeout(100)
        seen = []
        while True:
            st = pg.evaluate("""[trace[cursor].kind, trace[cursor].k || '', window.scrollY,
                document.getElementById('explain').offsetHeight,
                [...document.querySelectorAll('#code .ln.hl')].map(l => +l.dataset.n),
                document.getElementById('cands').innerText.replace(/\\n/g, ' '),
                document.getElementById('num-f').textContent + '/' + document.getElementById('num-r').textContent,
                (() => { const pre = document.getElementById('code');
                         const hl = [...pre.querySelectorAll('.ln.hl')];
                         return hl.length === 0 || hl.some(l => l.offsetTop >= pre.scrollTop - 1 && l.offsetTop + l.offsetHeight <= pre.scrollTop + pre.clientHeight + 1); })()]""")
            seen.append(st)
            if pg.is_disabled('#btn-next'): break
            pg.evaluate("document.getElementById('btn-next').click()")
            pg.wait_for_timeout(700 if i == 0 else 20)
        print(f'--- preset {i}:', pg.inner_text(f'#presets button:nth-child({i + 1})'))
        for s in seen:
            print(f'  {s[0]:6}{s[1]!s:2} cost={s[6]:6} hl={s[4][:2]}..{len(s[4])} vis={s[7]} | {s[5][:90]}')
        print('  explain heights', sorted(set(s[3] for s in seen)), 'page scrollY', sorted(set(s[2] for s in seen)))
        print('  end:', pg.inner_text('#explain').split('\n', 1)[1])
        print('  board:', pg.inner_text('#levels').replace('\n', ' '))

    # 3. 截圖：預設 1 的 lemma 步驟、點一個被引理排除的候選
    pg.click('#presets button:nth-child(1)')
    pg.evaluate("cursor = trace.findIndex(s => s.kind === 'lemma' && s.k === 2); showStep()")
    pg.wait_for_timeout(700)
    pg.locator('#cands .cand.out').first.click()
    print('hint:', pg.inner_text('#cands-hint'), '| matched rows', pg.locator('#db tr.match').count())
    pg.screenshot(path='inc_desktop_lemma.png', full_page=True)
    pg.click('#lang button[data-lang=py]')
    print('py hl', pg.evaluate("[...document.querySelectorAll('#code .ln.hl')].map(l=>+l.dataset.n)"))
    pg.click('#lang button[data-lang=java]')

    # 4. 預設 2 的 gen 第 3 層（連帶掉出）截圖
    pg.click('#presets button:nth-child(2)')
    pg.evaluate("cursor = trace.findIndex(s => s.kind === 'level' && s.k === 2); showStep()")
    pg.wait_for_timeout(700)
    pg.screenshot(path='inc_desktop_drop.png', full_page=True)

    # 5. 併入後再加一批：自己組交易
    pg.click('#presets button:nth-child(1)')
    pg.evaluate("cursor = trace.length - 1; showStep()")
    pg.click('#btn-commit')
    print('after commit: DB rows', pg.evaluate('baseDB.length'), 'phase', pg.evaluate('phase'), '|', pg.inner_text('#explain')[:80])
    for combo in (['洋芋片', '飯糰'], ['洋芋片', '茶葉蛋', '飯糰'], ['洋芋片', '麵包']):
        for it in combo: pg.click(f'#picks .pick[data-item="{it}"]')
        pg.click('#btn-add')
    print('pending', pg.evaluate('pending.length'), 'update disabled?', pg.is_disabled('#btn-update'))
    pg.click('#btn-update')
    pg.evaluate("cursor = trace.length - 1; showStep()")
    print('batch2 end:', pg.inner_text('#explain').split('\n', 1)[1])
    pg.screenshot(path='inc_desktop_batch2.png', full_page=True)
    pg.click('#btn-commit')
    print('batches:', pg.inner_text('#batches').replace('\n', ' | '))
    # 門檻調整
    pg.click('#pct-plus'); pg.click('#presets button:nth-child(3)')
    print('pct', pg.inner_text('#pct-val'), pg.inner_text('#pct-note'), '| steps', pg.evaluate('trace.length'))
    pg.evaluate('reset()')
    print('errs', errs)

    # 6. 手機
    m = b.new_context(viewport={'width': 375, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
    m.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    mp = m.new_page()
    merrs = []
    mp.on('pageerror', lambda e: merrs.append(str(e)))
    mp.goto(U)
    mp.wait_for_timeout(500)
    sw = set()
    hs = set()
    while True:
        sw.add(mp.evaluate('document.documentElement.scrollWidth'))
        hs.add(mp.evaluate("document.getElementById('explain').offsetHeight"))
        if mp.is_disabled('#btn-next'): break
        mp.evaluate("document.getElementById('btn-next').click()")
    mp.evaluate("cursor = trace.findIndex(s => s.kind === 'old' && s.k === 2); showStep()")
    mp.wait_for_timeout(700)
    mp.screenshot(path='inc_mobile.png', full_page=True)
    mp.click('#btn-edit-batch')
    sw.add(mp.evaluate('document.documentElement.scrollWidth'))
    mp.locator('#db-card').screenshot(path='inc_mobile_edit.png')
    print('mobile scrollWidth', sw, 'explain heights', hs, 'errs', merrs)
    b.close()
