"""GSP / SPADE 頁面測試：隨機資料交叉比對（網頁 JS、Python、PrefixSpan、暴力法）＋逐步走完檢查版面
需要本機伺服器：cd <repo> && python3 -m http.server 8805
用法：python3 -B test.py [截圖資料夾]"""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys, itertools
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from gsp import gsp
from spade import spade
from prefixspan import prefix_span
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:8805/research/gsp-spade.html'
SHOT = sys.argv[1] if len(sys.argv) > 1 else '/tmp'


def contains(seq, pat):
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


def as_dict(got):
    return {tuple(tuple(e) for e in pat): n for pat, n in got}


CARD_POS = "[...document.querySelectorAll('#panel-' + activeTab + ' .card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.left), Math.round(r.top + scrollY), Math.round(r.width), Math.round(r.height)].join(','); }).join(' ')"
HL = "g => [...document.querySelectorAll('#' + g + '-code .ln.hl')].map(l => +l.dataset.n)"

with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)

    # 1. 隨機序列資料庫：網頁 JS（GSP、SPADE）vs Python（GSP、SPADE、PrefixSpan）vs 暴力法
    random.seed(7)
    bad = total = 0
    N = int(os.environ.get("N", 300))
    for trial in range(N):
        db = [[random.sample(ITEMS, random.randint(1, 3)) for _ in range(random.randint(0, 5))] for _ in range(random.randint(1, 8))]
        ms = random.randint(min(2, len(db)), len(db))   # 頁面上門檻最低 2（只有 1 位顧客時才是 1）
        br = brute(db, ms)
        pg_, ps_ = gsp(db, ms), spade(db, ms)
        pps = dict(prefix_span(db, ms))
        jg, js = pg.evaluate("([d,m])=>{const g=gspTrace(d,m), s=spadeTrace(d,m);return [g[g.length-1].found.map(r=>[r.pat,r.sup]), s[s.length-1].found.map(r=>[r.pat,r.sup])]}", [db, ms])
        jgd, jsd = as_dict(jg), as_dict(js)
        total += len(br)
        ok = (jgd == jsd == pg_ == ps_ == pps == br and len(jg) == len(jgd) and len(js) == len(jsd)
              and list(jgd) == list(pg_) and list(jsd) == list(ps_))      # 找到的順序也要跟 Python 版一樣
        if not ok:
            bad += 1
            if bad < 3: print('MISMATCH', db, ms)
    print(f'random: {N} DBs, {total} patterns, mismatches: {bad}')

    # 2. 從頭按到尾：每一步 explain 高度、各 .card 位置、程式碼高亮
    def walk(page, g, record=True):
        page.evaluate(f"goTo('{g}', 0)")
        seen = []
        while True:
            seen.append(page.evaluate(f"[traces.{g}[cursors.{g}].kind, document.getElementById('{g}-explain').offsetHeight, scrollY, ({HL})('{g}'), {CARD_POS}]"))
            if page.is_disabled(f'#{g}-next'): break
            page.click(f'#{g}-next')
        return seen

    for g, tab in (('g', '#tab-g'), ('s', '#tab-s')):
        pg.click(tab); pg.wait_for_timeout(300)
        for preset in range(3):
            pg.click(f'#{g}-presets button >> nth={preset}'); pg.wait_for_timeout(3000)
            seen = walk(pg, g)
            kinds = {}
            for k, h, y, hl, pos in seen:
                kinds.setdefault(k, set()).add((hl[0], hl[-1], len(hl)) if hl else None)
            print(f'{g} preset {preset}: steps', len(seen), 'explain heights', set(s[1] for s in seen), 'scrollY', set(s[2] for s in seen),
                  'card layouts', len(set(s[4] for s in seen)))
            if preset == 0:
                for k, v in kinds.items(): print('   ', k, sorted(v, key=str))
    pg.click('#tab-g')

    # 3. 點候選、截圖
    pg.click('#g-presets button >> nth=0'); pg.wait_for_timeout(1500)
    def goto(page, g, cond):
        page.evaluate(f"goTo('{g}', 0)")
        while not page.evaluate(cond): page.click(f'#{g}-next')
    goto(pg, 'g', "traces.g[cursors.g].kind==='count'&&traces.g[cursors.g].k===2")
    pg.click('#g-cands .cand >> nth=3')
    print('gsp pick:', pg.inner_text('#g-hint'), pg.evaluate("[...document.querySelectorAll('#g-seqs .srow.pick .who')].map(x=>x.textContent)"))
    pg.screenshot(path=f'{SHOT}/gs_count.png', full_page=True)
    goto(pg, 'g', "traces.g[cursors.g].kind==='prune'&&traces.g[cursors.g].cands.some(c=>c.status==='pruned')")
    pg.click('#g-cands .cand.out >> nth=0')
    print('gsp pruned:', pg.inner_text('#g-hint'))
    goto(pg, 'g', "traces.g[cursors.g].kind==='join'&&traces.g[cursors.g].k===3")
    pg.click('#g-cands .cand >> nth=0'); print('gsp join:', pg.inner_text('#g-hint'))
    pg.click('#tab-s'); pg.wait_for_timeout(500)
    goto(pg, 's', "traces.s[cursors.s].kind==='vertical'")
    pg.click('#s-table th[data-x="飯糰"]'); print('spade vertical pick:', pg.inner_text('#s-hint'))
    goto(pg, 's', "traces.s[cursors.s].kind==='class'&&traces.s[cursors.s].cands.some(c=>c.step==='I'&&c.ok)")
    i = pg.evaluate("traces.s[cursors.s].cands.findIndex(c=>c.step==='I'&&c.ok)")
    pg.click(f'#s-cands .cand >> nth={i}')
    print('spade I pick:', pg.inner_text('#s-hint')[:80], 'code hl', pg.evaluate('(' + HL + ")('s')")[:3])
    pg.screenshot(path=f'{SHOT}/gs_spade_istep.png', full_page=True)
    print('compare:', pg.inner_text('#cmp-note'))
    pg.click('#s-presets button >> nth=0')
    pg.click('[data-sup="-1"] >> nth=1'); print('minSup', pg.evaluate('minSup'), 'patterns', pg.evaluate("traces.s[traces.s.length-1].found.length"), 'down disabled', pg.is_disabled('[data-sup="-1"] >> nth=1'))
    pg.click('#panel-s .lang button[data-lang=py]'); pg.click('#s-next'); pg.click('#s-next')
    print('py hl', pg.evaluate('(' + HL + ")('s')")[:4])
    pg.click('#panel-s .lang button[data-lang=java]')

    # 4. 編輯資料
    pg.click('#s-edit')
    pg.click('#s-seqs .visit[data-sid="0"][data-k="2"]')
    pg.click('#s-palette .opt[data-item="牛奶"]')
    pg.click('#s-seqs [data-add="5"]')
    pg.click('#s-palette .opt[data-item="飯糰"]')
    pg.click('#s-add-cust')
    pg.screenshot(path=f'{SHOT}/gs_edit.png', full_page=True)
    pg.click('#s-seqs [data-del="1"]')
    pg.click('#s-seqs [data-add="0"]')
    pg.click('#s-edit')
    dbnow, ms = pg.evaluate("[db, minSup]")
    exp = gsp(dbnow, ms)
    print('edited ok', as_dict(pg.evaluate("traces.g[traces.g.length-1].found.map(r=>[r.pat,r.sup])")) == exp == as_dict(pg.evaluate("traces.s[traces.s.length-1].found.map(r=>[r.pat,r.sup])")))
    pg.click('#s-presets button >> nth=3')
    print('random preset patterns', pg.evaluate("traces.s[traces.s.length-1].found.length"))
    print('errs', errs)

    # 5. 手機：375（從頭按到尾記 card 位置）、320
    for w in (375, 320):
        mc = b.new_context(viewport={'width': w, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
        mc.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        m = mc.new_page(); merr = []
        m.on('pageerror', lambda e: merr.append(str(e)))
        m.goto(U); m.wait_for_timeout(3000)
        for g in ('g', 's'):
            if g == 's': m.click('#tab-s'); m.wait_for_timeout(3000)
            seen = walk(m, g)
            sws = m.evaluate('document.documentElement.scrollWidth')
            print(f'mobile {w} {g}: steps {len(seen)} scrollWidth {sws} explain heights', set(s[1] for s in seen), 'card layouts', len(set(s[4] for s in seen)))
            m.evaluate(f"goTo('{g}', Math.min(5, traces.{g}.length-1))")
            m.screenshot(path=f'{SHOT}/gs_m{w}_{g}.png', full_page=True)
        m.click('#s-edit'); m.click('#s-seqs .visit[data-sid="0"][data-k="0"]')
        print(f'mobile {w} edit scrollWidth', m.evaluate('document.documentElement.scrollWidth'), 'errs', merr)
        mc.close()
    b.close()
