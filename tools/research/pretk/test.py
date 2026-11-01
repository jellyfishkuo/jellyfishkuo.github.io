"""PreTK：網頁 JS、Python 版、暴力法交叉比對（每一批之後的前 k_lower 名），
並測論文原式（只看單批）在連續不重挖時會不會出錯；最後從頭按到尾檢查每個區塊不會移動。
需要本機伺服器：cd <repo> && python3 -m http.server 8774（或設環境變數 PORT）"""
import os, random, sys, itertools, time
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from pretk import PreTK
from playwright.sync_api import sync_playwright
ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片']
U = 'http://127.0.0.1:%s/research/pretk.html' % os.environ.get('PORT', '8774')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 300
POS = "[...document.querySelectorAll('.card')].map(c => { const r = c.getBoundingClientRect(); return [Math.round(r.top + scrollY), Math.round(r.height)]; })"


def brute(db, profit, k):
    """暴力法：列出所有組合的效益，取前 k 大"""
    items = sorted({i for t in db for i in t}); us = []
    for n in range(1, len(items) + 1):
        for s in itertools.combinations(items, n):
            u = sum(sum(t[i] * profit[i] for i in s) for t in db if all(i in t for i in s))
            if u: us.append(u)
    return sorted(us, reverse=True)[:k]


class PaperRule(PreTK):
    """論文原式：每批都拿上次挖掘時的 minU_upper − minU_lower 比，不累加"""
    def mine(self):
        super().mine(); self.last = (self.min_upper, self.min_lower)

    def add_batch(self, batch):
        if self.tree:
            self.ceiling = self.last[1]; self.min_upper = self.last[0]   # 當作每批都是剛挖完
        return super().add_batch(batch)


def rand_case():
    items = random.sample(ITEMS, random.randint(2, 6))
    profit = {i: random.randint(1, 30) for i in ITEMS}
    batches = [[{i: random.randint(1, 5) for i in random.sample(items, random.randint(1, len(items)))} for _ in range(random.randint(1, 6))]]
    for _ in range(random.randint(1, 5)):
        batches.append([{i: random.randint(1, 3) for i in random.sample(items, random.randint(1, min(2, len(items))))} for _ in range(random.randint(1, 2))])
    kl = random.randint(1, 5)
    return batches, profit, kl, kl + random.randint(1, 10)


def walk(pg, label):
    pg.goto(U); pg.wait_for_timeout(3000)
    pos0 = pg.evaluate(POS); moved, n, hl = 0, 1, set()
    while not pg.is_disabled('#btn-next'):
        pg.click('#btn-next'); pg.wait_for_timeout(30); n += 1
        moved += pg.evaluate(POS) != pos0
        hl.add(pg.evaluate("document.querySelectorAll('#code .ln.hl').length > 0"))
    sw = pg.evaluate('[document.documentElement.scrollWidth, innerWidth]')
    print(f'{label}: 走了 {n} 步，.card 位置變動 {moved} 次，每步都有高亮 {hl == {True}}，scrollWidth {sw}')
    return moved


# 論文原式 vs 累積上界（只用 Python，跟暴力法比）
random.seed(7)
fail = {'paper': 0, 'ours': 0}
for _ in range(3000):
    batches, profit, kl, ku = rand_case()
    for name, cls in (('paper', PaperRule), ('ours', PreTK)):
        m, db = cls(profit, kl, ku), []
        for b in batches:
            db += b; m.add_batch(b)
            if [u for _, u in m.answer()] != brute(db, profit, kl):
                fail[name] += 1; break
print(f'Python 3000 組：論文原式答錯 {fail["paper"]} 組，累積上界答錯 {fail["ours"]} 組')

with sync_playwright() as p:
    b = p.chromium.launch(); errs = []
    ctx = b.new_context(viewport={'width': 1280, 'height': 900}); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)
    bad = remines = batches_n = 0
    for trial in range(TRIALS):
        batches, profit, kl, ku = rand_case()
        js = pg.evaluate("""([bs, p, kl, ku]) => { const tr = buildTrace(bs, p, kl, ku);
            return bs.map((x, b) => { const s = tr.filter(t => t.b === b).pop();
                return { ans: s.tree.slice(0, kl).map(r => [r.items, r.u]), remine: tr.some(t => t.b === b && t.kind === 'mine') }; }); }""", [batches, profit, kl, ku])
        m, db, ok = PreTK(profit, kl, ku), [], True
        for k, bt in enumerate(batches):
            db += bt; r = m.add_batch(bt)
            py = [[list(s), u] for s, u in m.answer()]
            ok &= js[k]['ans'] == py and js[k]['remine'] == r and [u for _, u in py] == brute(db, profit, kl)
            remines += r; batches_n += 1
        if not ok:
            bad += 1
            if bad < 4: print('MISMATCH', batches, profit, kl, ku, js)
    print(f'隨機 {TRIALS} 組（JS / Python / 暴力法，每批之後的前 k_lower 名與是否重挖），不一致 {bad}；{batches_n} 批裡重挖 {remines} 批')
    # 論文範例（k_upper = 10、k_lower = 5）：三個階段跟圖 10～12 一樣
    paper = pg.evaluate("""() => { const d = DATASETS.paper, tr = buildTrace(d.BATCHES, d.PROFIT, 5, 10);
        return [0, 1, 2].map(b => tr.filter(t => t.b === b).pop().tree.map(r => r.items.join('') + r.u)); }""")
    want = [['ABD44', 'ABDF43', 'ABF37', 'AB36', 'ADF35', 'BDF34', 'F32', 'AD32', 'A30', 'AF29'],
            ['AB73', 'ABF71', 'ABD67', 'BF56', 'ABCD52', 'A51', 'AD51', 'AF51', 'F48', 'ABC46'],
            ['ABF97', 'AF95', 'AB87', 'F80', 'BF76', 'ABD67', 'A63', 'ABC62', 'AEF54', 'AC53']]
    print('論文範例：', '與圖 10～12 一致' if paper == want else ('不一致！', paper))
    g = pg.evaluate("() => { const d = DATASETS.paper; return buildTrace([d.BATCHES[0]], d.PROFIT, 4, 5).find(s => s.kind === 'raise').s2; }")
    print('論文範例 D、k = 5 的 GLIU 第 5 大：', g, '（論文 28）')
    for ds, kl, ku in (('shop', 3, 10), ('shop', 1, 16), ('shop', 8, 16), ('paper', 5, 10)):
        ms = pg.evaluate("""async ([ds, kl, ku]) => { useDataset(ds); kLower = kl; kUpper = ku; const t = performance.now(); rebuild();
            while (blocksBusy) await new Promise(r => setTimeout(r, 5)); return [Math.round(performance.now() - t), trace.length]; }""", [ds, kl, ku])
        print(f'{ds} k={kl}/{ku}：{ms[1]} 步，量完 {ms[0]} ms')
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
