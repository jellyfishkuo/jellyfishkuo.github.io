"""gSpan Demo 的測試：網頁 JS、Python、Java、暴力法交叉比對，再從頭按到尾檢查版面。
需要本機伺服器：cd <repo> && python3 -m http.server 8807
用法：python3 -B test.py [截圖資料夾]"""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys, itertools, subprocess, tempfile, shutil
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from gspan import gspan
from playwright.sync_api import sync_playwright
U = 'http://127.0.0.1:8807/research/gspan.html'
SHOT = sys.argv[1] if len(sys.argv) > 1 else tempfile.gettempdir()
HL = "[...document.querySelectorAll('#code .ln.hl')].map(l=>+l.dataset.n)"


# ---------- 暴力法：列出每張圖所有連通的邊子集合，用「試遍所有頂點排列」的標準形去重 ----------
def canon(atoms, edges):
    best = None
    for p in itertools.permutations(range(len(atoms))):      # p[k]：新編號 k 是原本的哪個點
        inv = {v: k for k, v in enumerate(p)}
        key = (tuple(atoms[v] for v in p), tuple(sorted((min(inv[u], inv[v]), max(inv[u], inv[v]), b) for u, v, b in edges)))
        if best is None or key < best:
            best = key
    return best


def code_graph(code):
    atoms = {}
    for i, j, a, b, c in code:
        atoms[i], atoms[j] = a, c
    return [atoms[k] for k in range(len(atoms))], [(i, j, b) for i, j, _, b, _ in code]


def subgraphs(atoms, bonds):
    out = set()
    for mask in range(1, 1 << len(bonds)):
        es = [bonds[k] for k in range(len(bonds)) if mask >> k & 1]
        vs = sorted({x for u, v, _ in es for x in (u, v)})
        seen, st = {vs[0]}, [vs[0]]
        while st:
            x = st.pop()
            for u, v, _ in es:
                for a, c in ((u, v), (v, u)):
                    if a == x and c not in seen:
                        seen.add(c); st.append(c)
        if len(seen) == len(vs):
            idx = {v: k for k, v in enumerate(vs)}
            out.add(canon([atoms[v] for v in vs], [(idx[u], idx[v], b) for u, v, b in es]))
    return out


def brute(graphs, ms):
    cnt = {}
    for atoms, bonds in graphs:
        for c in subgraphs(atoms, bonds):
            cnt[c] = cnt.get(c, 0) + 1
    return {c: n for c, n in cnt.items() if n >= ms}


def rand_db(rng):
    gs = []
    for _ in range(rng.randint(1, 6)):
        n = rng.randint(2, 6)
        pool = 'CO' if rng.random() < 0.3 else 'CCCON'
        atoms = [rng.choice(pool) for _ in range(n)]
        es = {(rng.randrange(v), v) for v in range(1, n)}
        for _ in range(rng.randint(0, 3)):
            u, v = rng.sample(range(n), 2)
            es.add((min(u, v), max(u, v)))
        gs.append((atoms, [(u, v, '=' if rng.random() < 0.25 else '-') for u, v in sorted(es)]))
    return gs


def to_canon_map(res):
    out = {}
    for code, sup in res:
        c = canon(*code_graph(code))
        assert c not in out, ('同一個子圖出現兩次', code)
        out[c] = sup
    return out


# ---------- Java：同一批資料丟給下載版的 GSpan.java ----------
HARNESS = r'''
import java.util.*;
public class Harness {
    public static void main(String[] a) {
        Scanner sc = new Scanner(System.in);
        while (sc.hasNextLine()) {
            String line = sc.nextLine().trim();
            if (line.isEmpty()) continue;
            String[] parts = line.split("\\|");
            int ms = Integer.parseInt(parts[0]);
            List<GSpan.Graph> gs = new ArrayList<>();
            for (int k = 1; k < parts.length; k++) {
                String[] f = parts[k].split(" ");
                gs.add(GSpan.graph(f[0], Arrays.copyOfRange(f, 1, f.length)));
            }
            StringBuilder sb = new StringBuilder();
            for (var e : GSpan.gSpan(gs, ms)) {
                StringJoiner sj = new StringJoiner(" ");
                for (GSpan.Edge x : e.getKey()) sj.add(x.toString());
                sb.append(sj).append(" ").append(e.getValue()).append(";");
            }
            System.out.println(sb);
        }
    }
}
'''


def run_java(cases):
    d = tempfile.mkdtemp()
    shutil.copy(REPO + '/research/code/GSpan.java', d)
    open(d + '/Harness.java', 'w').write(HARNESS)
    subprocess.run(['javac', '-encoding', 'UTF-8', '-d', d, d + '/GSpan.java', d + '/Harness.java'], check=True, capture_output=True)
    inp = '\n'.join(str(ms) + '|' + '|'.join(''.join(at) + ''.join(' %d%s%d' % (u, b, v) for u, v, b in bs) for at, bs in gs) for gs, ms in cases) + '\n'
    out = subprocess.run(['java', '-Dstdout.encoding=UTF-8', '-cp', d, 'Harness'], input=inp, capture_output=True, text=True, check=True).stdout
    shutil.rmtree(d)
    lines = out.split('\n')[:-1]
    assert len(lines) == len(cases)
    return lines


def py_line(res):
    return ''.join(' '.join('(%d,%d,%s,%s,%s)' % e for e in code) + ' %d;' % sup for code, sup in res)


CARDS = "[...document.querySelectorAll('.card')].map(c=>{const r=c.getBoundingClientRect();return [Math.round(r.left),Math.round(r.top+scrollY),Math.round(r.width),Math.round(r.height)].join(',')}).join('|')"


def walk(pg, label):
    """從頭按到尾：每一步記下每個 .card 的位置大小、說明框高度、頁面捲動、程式碼高亮"""
    pg.evaluate('cursor=0; showStep()')
    cards, heights, scrolls, sws, kinds = set(), set(), set(), set(), {}
    n = 0
    while True:
        st = pg.evaluate("[trace[cursor].kind, document.getElementById('explain').offsetHeight, scrollY, document.documentElement.scrollWidth, " + CARDS + ", " + HL + "]")
        kinds.setdefault(st[0], set()).add((st[5][0], st[5][-1], len(st[5])) if st[5] else None)
        heights.add(st[1]); scrolls.add(st[2]); sws.add(st[3]); cards.add(st[4]); n += 1
        if pg.is_disabled('#btn-next'):
            break
        pg.click('#btn-next')
    print(f'  {label}: {n} 步，card 位置組合數 {len(cards)}，說明框高度 {heights}，scrollY {scrolls}，scrollWidth {sws}')
    return len(cards), kinds


with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)

    # 1. 隨機圖資料庫：網頁 JS vs Python vs Java vs 暴力法
    rng = random.Random(2024)
    cases = []
    for _ in range(300):
        gs = rand_db(rng)
        cases.append((gs, rng.randint(1, len(gs))))
    java = run_java(cases)
    bad = total = notmin = 0
    for (gs, ms), jl in zip(cases, java):
        py = gspan(gs, ms)
        js = pg.evaluate("([d,m])=>{const tr=buildTrace(d.map(([a,b])=>({atoms:a,bonds:b})),m);"
                         "const nm=tr.filter(s=>s.kind==='notmin');"
                         "const okNm=nm.every(s=>s.found>=0&&s.found<s.result.length&&ckey(s.result[s.found].code)===ckey(s.min)&&s.diff>=0&&dfsCmp(s.min[s.diff],s.code[s.diff])<0);"
                         "return [tr[tr.length-1].result.map(r=>[r.code,r.sup]), nm.length, okNm]}", [gs, ms])
        jsres = [(tuple(tuple(e) for e in c), s) for c, s in js[0]]
        pyres = [(tuple(c), s) for c, s in py]
        br = brute(gs, ms)
        total += len(br); notmin += js[1]
        ok = jsres == pyres and to_canon_map(pyres) == br and jl == py_line(py) and js[2]
        if not ok:
            bad += 1
            if bad < 3: print('MISMATCH', gs, ms)
    print(f'random: {len(cases)} 組資料庫，{total} 個頻繁子圖，{notmin} 次「不是最小」剪枝；JS / Python / Java / 暴力法不一致：{bad}')

    # 2. 三個範例 × 每個門檻：從頭按到尾，每個 .card 的位置都不能變
    pg.reload(); pg.wait_for_timeout(3000)
    allkinds = {}
    moved = 0
    for preset in range(3):
        pg.click(f'#presets button >> nth={preset}')
        for ms in range(1, 6):
            pg.evaluate(f"minSup={ms}; rebuild()")
            pg.wait_for_timeout(3000 if pg.evaluate('trace.length') < 80 else 9000)   # 步驟多時量高度要久一點
            c, kinds = walk(pg, f'preset {preset} minSup {ms}')
            moved += c != 1
            for k, v in kinds.items(): allkinds.setdefault(k, set()).update(v)
    print('desktop：card 位置有變動的情況數', moved)
    for k, v in allkinds.items(): print('   java hl', k, sorted(v, key=str)[:4])

    # 3. 互動：點延伸表、點圖換嵌入、切 Python、隨機
    pg.click('#presets button >> nth=0'); pg.wait_for_timeout(3000)
    pg.evaluate("cursor=trace.findIndex(s=>s.kind==='notmin'); showStep()")
    print('notmin 說明：', pg.inner_text('#explain')[:160].replace('\n', ' '))
    pg.screenshot(path=f'{SHOT}/gs_notmin.png', full_page=True)
    pg.evaluate("cursor=trace.findIndex(s=>s.kind==='cands'); showStep()")
    pg.click('#cand-t tbody tr >> nth=0')
    print('點延伸表：', pg.inner_text('#cand-hint'), '| 亮起來的圖', pg.locator('.gbox.pick').count())
    pg.evaluate("cursor=trace.findIndex(s=>s.kind==='grow'); showStep()")
    before = pg.inner_text('#graphs')
    pg.click('.gbox >> nth=0')
    print('點圖換嵌入：', before.split('\n')[:2], '→', pg.inner_text('#graphs').split('\n')[:2])
    pg.click('#lang button[data-lang=py]')
    pyk = {}
    pg.click('#btn-first')
    while not pg.is_disabled('#btn-next'):
        pg.click('#btn-next')
        pyk.setdefault(pg.evaluate('trace[cursor].kind'), pg.evaluate(HL)[:3])
    print('python hl', pyk)
    pg.click('#lang button[data-lang=java]')
    pg.click('#presets button >> nth=1'); pg.wait_for_timeout(3000)
    pg.evaluate("cursor=trace.findIndex(s=>s.kind==='notmin'); showStep()")
    print('三元環 notmin：', pg.inner_text('#explain')[:200].replace('\n', ' '))
    pg.screenshot(path=f'{SHOT}/gs_ring3.png', full_page=True)
    for _ in range(5):
        pg.click('#presets button >> nth=3'); pg.wait_for_timeout(300)
    print('隨機：', pg.evaluate('graphs.length'), '張圖，', pg.evaluate('trace.length'), '步')
    pg.click('#presets button >> nth=2'); pg.wait_for_timeout(3000)
    pg.evaluate("cursor=trace.findIndex(s=>s.kind==='cands'&&s.table.rows.some(r=>r.e[0]>r.e[1])); showStep()")
    pg.screenshot(path=f'{SHOT}/gs_ring5.png', full_page=True)
    print('desktop errs', errs)

    # 4. 手機
    for w in (375, 320):
        mc = b.new_context(viewport={'width': w, 'height': 760}, is_mobile=True, has_touch=True, device_scale_factor=2)
        mc.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        m = mc.new_page(); merr = []
        m.on('pageerror', lambda e: merr.append(str(e)))
        m.goto(U); m.wait_for_timeout(3000)
        mv = 0
        for preset in range(3):
            m.click(f'#presets button >> nth={preset}'); m.wait_for_timeout(3000)
            c, _ = walk(m, f'mobile {w} preset {preset}')
            mv += c != 1
        m.click('#presets button >> nth=0'); m.wait_for_timeout(3000)
        m.evaluate("cursor=trace.findIndex(s=>s.kind==='notmin'); showStep()")
        m.screenshot(path=f'{SHOT}/gs_mobile_{w}.png', full_page=True)
        print(f'mobile {w}: card 位置有變動的範例數 {mv}，errs {merr}')
        mc.close()
    b.close()
