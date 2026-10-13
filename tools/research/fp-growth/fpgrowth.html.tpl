<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/fp-growth.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/fp-growth-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/fp-growth-180.png">
    <title>FP-Growth 頻繁樣式探勘</title>
    <meta name="description" content="一步一步看 FP-Growth 怎麼把交易壓成一棵 FP-tree、再用條件模式基底遞迴挖出所有頻繁樣式，Java 與 Python 程式碼逐行對照，並和 Apriori 比較。">
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=Syne:wght@700;800&display=swap');
        /* 手機瀏覽器會自動把某些段落的字放大，程式碼框裡就會一行大一行小；關掉它 */
        html { -webkit-text-size-adjust: 100%; text-size-adjust: 100%; }

        /* 反白（選取文字）的顏色：background 是底色、color 是字色 */
        ::selection { background: #7c3aed; color: #fff; -webkit-text-fill-color: #fff; }

        :root {
            --bg: #05050a;
            --panel: #0f0f1a;
            --panel-2: #151527;
            --border: #262640;
            --text: #e6e6f0;
            --muted: #8a8aa3;
            --accent: #7c3aed;
            --accent2: #06b6d4;
            --good: #22c55e;
            --bad: #f87171;
            --warn: #f59e0b;
            --line-hl: rgba(124, 58, 237, 0.22);
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }

        body {
            background: var(--bg);
            color: var(--text);
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang TC", "Noto Sans TC", "Microsoft JhengHei", sans-serif;
            line-height: 1.6;
            min-height: 100vh;
        }

        .wrap { max-width: 1180px; margin: 0 auto; padding: 1.5rem 1rem 4rem; }

        .back {
            display: inline-block;
            color: var(--muted);
            font: 0.8rem 'Space Mono', monospace;
            text-decoration: none;
            letter-spacing: 0.05em;
            margin-bottom: 1rem;
        }
        .back:hover { color: var(--accent2); }
        .kicker { font: 0.75rem 'Space Mono', monospace; color: var(--accent2); letter-spacing: 0.12em; }
        h1 { font-family: 'Syne', sans-serif; font-size: clamp(1.7rem, 5vw, 2.6rem); line-height: 1.15; margin-top: 0.2rem; }
        h1 small { display: block; font-size: 0.42em; color: var(--muted); font-weight: 400; margin-top: 0.4rem; font-family: inherit; }
        h2 { font-size: 1.05rem; margin-bottom: 0.6rem; }
        .intro { color: #c6c6d6; max-width: 780px; margin-top: 0.9rem; font-size: 0.95rem; }
        .intro b { color: var(--text); }
        .intro a { color: var(--accent2); }

        /* 手機：一欄，依序 步驟 → 樹 → 資料 → 程式碼 → 結果；電腦：兩欄 */
        .layout {
            display: grid;
            gap: 1rem;
            margin-top: 1.3rem;
            grid-template-areas: "step" "tree" "data" "code" "result";
            align-items: start;
        }
        .layout > * { min-width: 0; }
        @media (min-width: 960px) {
            .layout {
                grid-template-columns: 1fr 1.1fr;
                grid-template-areas: "step tree" "data code" "result code";
            }
        }
        .a-step { grid-area: step; }
        .a-tree { grid-area: tree; }
        .a-data { grid-area: data; }
        .a-code { grid-area: code; }
        .a-result { grid-area: result; }

        .card {
            background: var(--panel);
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 1rem;
        }
        .card-head { display: flex; justify-content: space-between; align-items: center; gap: 0.5rem; flex-wrap: wrap; margin-bottom: 0.7rem; }
        .card-head h2 { margin: 0; }

        button.btn {
            background: var(--panel-2);
            color: var(--text);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 0.4rem 0.75rem;
            font-size: 0.88rem;
            cursor: pointer;
        }
        button.btn:hover:not(:disabled) { border-color: var(--accent2); }
        button.btn:disabled { opacity: 0.4; cursor: default; }
        button.btn.primary { background: var(--accent); border-color: var(--accent); }

        .player { display: flex; flex-wrap: wrap; gap: 0.4rem; align-items: center; }
        .minsup { display: flex; align-items: center; gap: 0.45rem; font-size: 0.88rem; margin-left: auto; }
        .minsup .val { font: 700 1rem 'Space Mono', monospace; min-width: 1.2em; text-align: center; }
        .stepper { width: 30px; height: 30px; padding: 0 !important; }
        .explain {
            background: var(--panel-2);
            border-left: 3px solid var(--accent2);
            border-radius: 8px;
            padding: 0.7rem 0.9rem;
            margin-top: 0.8rem;
            font-size: 0.93rem;
        }
        .explain .step-no { font: 0.74rem 'Space Mono', monospace; color: var(--muted); display: block; }
        .explain b { color: var(--warn); font-weight: 600; }

        /* ── 樹 ── */
        .crumbs { display: flex; flex-wrap: wrap; gap: 0.3rem; align-items: center; font-size: 0.8rem; color: var(--muted); margin-bottom: 0.5rem; min-height: 1.6rem; }
        .crumb { border: 1px solid var(--border); border-radius: 6px; padding: 0.05rem 0.45rem; }
        .crumb.cur { border-color: var(--accent); color: var(--text); background: rgba(124, 58, 237, 0.15); }
        .tree-wrap { display: grid; grid-template-columns: 1fr auto; gap: 0.8rem; align-items: start; }
        @media (max-width: 520px) { .tree-wrap { grid-template-columns: 1fr; } }
        .tree-box { overflow-x: auto; background: #0a0a14; border: 1px solid var(--border); border-radius: 10px; min-height: 140px; display: flex; align-items: flex-start; justify-content: center; padding: 0.4rem; }
        .tree-box svg { display: block; max-width: 100%; height: auto; }
        .tree-empty { color: var(--muted); font-size: 0.85rem; align-self: center; padding: 1rem; text-align: center; }
        svg .edge { stroke: #3a3a5a; stroke-width: 2; }
        svg .edge.on { stroke: var(--warn); stroke-width: 3; }
        svg .link { stroke: var(--accent2); stroke-width: 1.6; stroke-dasharray: 4 3; fill: none; }
        svg .node circle.body { fill: #1e1e36; stroke: #3a3a5a; stroke-width: 2; }
        svg .node.on circle.body { stroke: var(--warn); stroke-width: 3; fill: #2b2318; }
        svg .node.new circle.body { stroke: var(--good); stroke-width: 3; }
        svg .node.linked circle.body { stroke: var(--accent2); stroke-width: 3; }
        svg .node .emo { font-size: 17px; }
        svg .node .badge { fill: #3b3b62; }
        svg .node.on .badge { fill: var(--warn); }
        svg .node.linked .badge { fill: var(--accent2); }
        svg .node .cnt { font: 700 10.5px 'Space Mono', monospace; fill: #fff; }
        svg .root circle { fill: #2a2a48; }
        svg .root text { font: 9px 'Space Mono', monospace; fill: var(--muted); }

        .header-table { border-collapse: collapse; font-size: 0.82rem; min-width: 138px; }
        .header-table caption { text-align: left; color: var(--muted); font-size: 0.75rem; padding-bottom: 0.25rem; }
        .header-table td { padding: 0.18rem 0.35rem; border-bottom: 1px solid var(--border); white-space: nowrap; }
        .header-table tr { cursor: pointer; }
        .header-table tr:hover td { background: rgba(255, 255, 255, 0.03); }
        .header-table tr.sel td { background: rgba(6, 182, 212, 0.14); }
        .header-table tr.out { opacity: 0.45; cursor: default; }
        .header-table tr.out td.nm { text-decoration: line-through; }
        .header-table td.c { font: 700 0.8rem 'Space Mono', monospace; text-align: right; }
        .legend { display: flex; flex-wrap: wrap; gap: 0.3rem 0.9rem; font-size: 0.75rem; color: var(--muted); margin-top: 0.55rem; }
        .legend i { display: inline-block; width: 10px; height: 10px; border-radius: 50%; border: 2px solid; margin-right: 0.3rem; vertical-align: -1px; }

        /* ── 資料列 ── */
        .rows { display: grid; gap: 0.3rem; }
        .row { display: flex; align-items: center; gap: 0.35rem; padding: 0.22rem 0.4rem; border-radius: 8px; flex-wrap: wrap; }
        .row.cur { background: rgba(245, 158, 11, 0.13); }
        .row.done { opacity: 0.55; }
        .row .rid { font: 0.76rem 'Space Mono', monospace; color: var(--muted); width: 2.3em; }
        .row.cur .rid { color: var(--warn); }
        .chip { font-size: 0.82rem; border-radius: 6px; padding: 0.02rem 0.4rem; background: #23233d; }
        .chip.out { background: none; color: var(--muted); text-decoration: line-through; }
        .arrow { color: #4a4a66; font-size: 0.75rem; }
        .times { font: 700 0.78rem 'Space Mono', monospace; color: var(--accent2); margin-left: 0.2rem; }
        .rows-empty { color: var(--muted); font-size: 0.85rem; }

        /* ── 程式碼 ── */
        .lang { display: flex; gap: 0.25rem; }
        .lang button {
            background: none;
            border: 1px solid var(--border);
            color: var(--muted);
            border-radius: 6px;
            padding: 0.2rem 0.6rem;
            font: 0.75rem 'Space Mono', monospace;
            cursor: pointer;
        }
        .lang button.active { color: var(--text); border-color: var(--accent2); }
        pre.code {
            background: #0a0a14;
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 0.5rem 0;
            overflow: auto;
            max-height: 560px;
            font: 0.78rem/1.7 'Space Mono', ui-monospace, monospace;
        }
        @media (max-width: 600px) { pre.code { font-size: 0.7rem; max-height: 400px; } }
        .code .ln { display: block; padding-right: 0.9rem; white-space: pre; width: max-content; min-width: 100%; }
        .code .ln::before { content: attr(data-n); display: inline-block; width: 2.4em; text-align: right; margin-right: 0.9em; color: #4a4a66; }
        .code .ln.hl { background: var(--line-hl); box-shadow: inset 3px 0 0 var(--accent); }
        .kw { color: #c792ea; }
        .fn { color: #82aaff; }
        .num { color: #f78c6c; }
        .cm { color: #637777; }
        .str { color: #c3e88d; }
        .ty { color: #ffcb6b; }
        .downloads { display: flex; flex-wrap: wrap; gap: 0.5rem 1rem; margin-top: 0.7rem; font-size: 0.85rem; color: var(--muted); align-items: center; }
        .downloads a { color: var(--accent2); }
        .downloads code { font: 0.78rem 'Space Mono', monospace; background: var(--panel-2); padding: 0.1rem 0.4rem; border-radius: 4px; color: var(--text); }

        /* ── 結果 ── */
        .levels { display: grid; gap: 0.45rem; }
        .level { display: grid; grid-template-columns: 2.8em 1fr; gap: 0.5rem; align-items: start; }
        .level .tag { font: 700 0.8rem 'Space Mono', monospace; color: var(--accent2); padding-top: 0.2rem; }
        .level .items { display: flex; flex-wrap: wrap; gap: 0.35rem; }
        .pat { font-size: 0.82rem; border: 1px solid rgba(34, 197, 94, 0.5); border-radius: 7px; padding: 0.12rem 0.5rem; }
        .pat .n { font: 700 0.74rem 'Space Mono', monospace; margin-left: 0.35rem; color: #86efac; }
        .pat.fresh { box-shadow: 0 0 0 2px var(--warn); }
        .empty { color: var(--muted); font-size: 0.85rem; }
        .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.5rem; margin-top: 0.9rem; }
        .stat { background: var(--panel-2); border-radius: 10px; padding: 0.55rem 0.6rem; }
        .stat .v { font: 700 1.25rem 'Space Mono', monospace; }
        .stat .k { color: var(--muted); font-size: 0.75rem; line-height: 1.35; }
        .compare { margin-top: 0.8rem; font-size: 0.85rem; color: var(--muted); }
        .compare b { color: var(--text); }

        .notes { margin-top: 1rem; display: grid; gap: 1rem; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr; } }
        .notes p, .notes li { color: #c6c6d6; font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; }
        .notes b { color: var(--text); }
    </style>
</head>

<body>
    <div class="wrap">
        <a class="back" href="../index.html#research">← RETURN TO PORTFOLIO</a>
        <div class="kicker">RESEARCH DEMO · FREQUENT PATTERN MINING</div>
        <h1>FP-Growth 頻繁樣式探勘<small>把交易壓成一棵樹，只掃兩次資料庫</small></h1>
        <p class="intro">
            跟 <a href="apriori.html">Apriori 那一頁</a>用同一份超商資料。Apriori 每一層都要產生候選、再掃一次資料庫去數；
            FP-Growth 換個做法：先把所有交易壓縮成一棵 <b>FP-tree</b>，前綴相同的交易共用同一段路徑。之後只在樹上挖：
            對每個商品找出「通往它的所有路徑」（<b>條件模式基底</b>），用它們建一棵更小的樹，再遞迴挖下去。
        </p>

        <div class="layout">
            <div class="card a-step">
                <div class="player">
                    <button class="btn" id="btn-first" title="回到開頭">⏮</button>
                    <button class="btn" id="btn-prev">◀ 上一步</button>
                    <button class="btn primary" id="btn-next">下一步 ▶</button>
                    <button class="btn" id="btn-play">▶ 自動播放</button>
                    <div class="minsup">
                        <span>最小支持度</span>
                        <button class="btn stepper" id="sup-minus" aria-label="減少">−</button>
                        <span class="val" id="sup-val">3</span>
                        <button class="btn stepper" id="sup-plus" aria-label="增加">+</button>
                    </div>
                </div>
                <div class="explain" id="explain"></div>
            </div>

            <div class="card a-tree">
                <div class="card-head"><h2 id="tree-title">FP-tree</h2></div>
                <div class="crumbs" id="crumbs"></div>
                <div class="tree-wrap">
                    <div class="tree-box" id="tree"></div>
                    <table class="header-table" id="header"></table>
                </div>
                <div class="legend">
                    <span><i style="border-color:var(--warn)"></i>這一步走過的路徑</span>
                    <span><i style="border-color:var(--good)"></i>新長出的節點</span>
                    <span><i style="border-color:var(--accent2)"></i>同商品的節點鏈（點右邊的表也能看）</span>
                </div>
            </div>

            <div class="card a-data">
                <h2 id="data-title">交易資料庫</h2>
                <div class="rows" id="rows"></div>
            </div>

            <div class="card a-code">
                <div class="card-head">
                    <h2>程式碼</h2>
                    <div class="lang" id="lang">
                        <button data-lang="java" class="active">Java</button>
                        <button data-lang="py">Python</button>
                    </div>
                </div>
                <pre class="code" id="code"></pre>
                <div class="downloads" id="downloads"></div>
            </div>

            <div class="card a-result">
                <h2>目前找到的頻繁樣式</h2>
                <div class="levels" id="levels"></div>
                <div class="stats">
                    <div class="stat"><div class="v" id="st-scan">0</div><div class="k">掃描資料庫次數</div></div>
                    <div class="stat"><div class="v" id="st-nodes">0</div><div class="k">FP-tree 節點數</div></div>
                    <div class="stat"><div class="v" id="st-trees">0</div><div class="k">建過的條件 FP-tree</div></div>
                </div>
                <div class="compare" id="compare"></div>
            </div>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼挖一個商品，只要看「通往它的路徑」？</h2>
                <p>樹裡每條從根往下的路徑，都是一群交易排好序之後的共同前綴。想知道「茶葉蛋常跟誰一起出現」，只要找出樹上所有茶葉蛋節點，
                    往上走到根：經過的商品就是跟它同一筆交易的其他商品，節點上的次數就是這樣的交易有幾筆。這些路徑就是<b>條件模式基底</b>，
                    它本身又是一個小小的交易資料庫，可以用同一個方法再建樹、再挖，這就是遞迴的地方。</p>
                <p style="margin-top:0.5rem">從<b>次數最少的商品開始挖</b>，是因為它在樹的最下面，往上的路徑最完整；挖完就不必再管它，越往上的商品要看的東西越少。</p>
            </div>
            <div class="card">
                <h2>跟 Apriori 比起來</h2>
                <ul>
                    <li><b>只掃兩次資料庫：</b>第一次數次數、第二次建樹，之後都在記憶體裡的樹上做。</li>
                    <li><b>不產生候選：</b>沒有「先猜再數」，所以不會白數一堆最後不頻繁的組合。</li>
                    <li><b>代價是記憶體：</b>交易很分散、共同前綴很少時，樹幾乎不會被壓縮，條件樹也會建很多棵。</li>
                    <li>很多後來的演算法（包括高效益樣式探勘的各種樹和清單結構）都延續「把資料壓成結構、在結構上挖」的想法。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           FP-Growth 一步一步看
           網頁裡用 JavaScript 照著同樣的流程跑一次，把每一步（含每一層遞迴）記下來；
           右邊的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = /*CODE_JSON*/null;

        const EMOJI = { '咖啡': '☕', '麵包': '🍞', '牛奶': '🥛', '飯糰': '🍙', '茶葉蛋': '🥚', '洋芋片': '🥔' };
        const DB = [
            ['咖啡', '麵包', '牛奶'],
            ['咖啡', '麵包', '茶葉蛋'],
            ['咖啡', '麵包', '牛奶', '飯糰'],
            ['麵包', '牛奶', '洋芋片'],
            ['咖啡', '牛奶', '茶葉蛋'],
            ['咖啡', '麵包', '牛奶', '茶葉蛋'],
            ['飯糰', '茶葉蛋', '洋芋片'],
            ['咖啡', '麵包', '飯糰']
        ];

        const $ = id => document.getElementById(id);
        let minSup = 3;
        let lang = 'java';
        let trace = [];
        let cursor = 0;
        let linkItem = null;     // 使用者在表上點選、要顯示節點鏈的商品
        let timer = null;

        const fmt = set => '{' + set.join(', ') + '}';
        const arrowPath = items => items.join(' → ');

        /* ---------- 照著程式跑一次，記下每一步 ---------- */
        function buildTrace(db, minSup) {
            const steps = [];
            const result = [];
            const stats = { scans: 0, mainNodes: 0, trees: 0 };
            const stack = [];
            let nextId = 1;

            const snapshot = root => {
                const out = [];
                (function walk(n) {
                    for (const c of n.children.values()) {
                        out.push({ id: c.id, item: c.item, count: c.count, parent: n.id });
                        walk(c);
                    }
                })(root);
                return out;
            };

            function push(kind, f, extra = {}) {
                steps.push({
                    kind, depth: f ? f.depth : 0, suffix: f ? f.suffix : [],
                    crumbs: stack.map(x => x.suffix),
                    tree: f && f.root ? snapshot(f.root) : [],
                    header: f && f.header ? Object.fromEntries(Object.entries(f.header).map(([k, v]) => [k, v.map(n => n.id)])) : {},
                    order: f ? f.order.slice() : [],
                    counts: f ? { ...f.count } : {},
                    rows: f ? f.rows.map(r => ({ ...r })) : [],
                    result: result.map(r => ({ ...r })),
                    stats: { ...stats },
                    ...extra
                });
            }

            function mine(rows, suffix, depth) {
                const f = { depth, suffix, root: null, header: null, order: [], count: {}, rows: rows.map(r => ({ items: r.items, n: r.n })) };
                stack.push(f);

                // 1. 數次數
                if (depth === 0) stats.scans++;
                rows.forEach(r => r.items.forEach(i => { f.count[i] = (f.count[i] || 0) + r.n; }));
                f.order = Object.keys(f.count).filter(i => f.count[i] >= minSup)
                    .sort((a, b) => f.count[b] - f.count[a] || (a < b ? -1 : a > b ? 1 : 0));
                f.rows.forEach(r => { r.path = f.order.filter(i => r.items.includes(i)); });
                push('count', f);
                if (!f.order.length) { stack.pop(); return; }

                // 2. 建樹
                f.root = { id: 0, item: null, count: 0, children: new Map() };
                f.header = Object.fromEntries(f.order.map(i => [i, []]));
                if (depth === 0) stats.scans++; else stats.trees++;
                f.rows.forEach((r, idx) => {
                    let node = f.root;
                    const pathIds = [], newIds = [];
                    r.path.forEach(item => {
                        let child = node.children.get(item);
                        if (!child) {
                            child = { id: nextId++, item, count: 0, children: new Map(), parent: node };
                            node.children.set(item, child);
                            f.header[item].push(child);
                            newIds.push(child.id);
                            if (depth === 0) stats.mainNodes++;
                        }
                        child.count += r.n;
                        pathIds.push(child.id);
                        node = child;
                    });
                    r.done = true;
                    if (depth === 0) push('insert', f, { row: idx, pathIds, newIds, path: r.path });
                });
                if (depth > 0) push('build', f);

                // 3. 從次數最少的商品開始挖
                for (let i = f.order.length - 1; i >= 0; i--) {
                    const item = f.order[i];
                    const pattern = [item, ...suffix];
                    result.push({ set: pattern, count: f.count[item], fresh: true });
                    const linkIds = f.header[item].map(n => n.id);
                    push('pattern', f, { item, pattern, linkIds });
                    result.forEach(r => { r.fresh = false; });

                    const base = [];
                    const pathIds = [];
                    f.header[item].forEach(node => {
                        const path = [];
                        for (let p = node.parent; p.item !== null; p = p.parent) { path.unshift(p.item); pathIds.push(p.id); }
                        if (path.length) base.push({ items: path, n: node.count });
                    });
                    push('base', f, { item, pattern, linkIds, pathIds, base });
                    if (base.length) {
                        mine(base, pattern, depth + 1);
                        push('back', f, { item, pattern });
                    }
                }
                stack.pop();
            }

            steps.push({ kind: 'start', depth: 0, suffix: [], crumbs: [], tree: [], header: {}, order: [], counts: {}, rows: db.map(t => ({ items: t, n: 1 })), result: [], stats: { ...stats } });
            mine(db.map(t => ({ items: t, n: 1 })), [], 0);
            steps.push({ ...steps[steps.length - 1], kind: 'end', depth: 0, crumbs: [], result: result.map(r => ({ ...r, fresh: false })), stats: { ...stats } });
            // 結束畫面回到完整的 FP-tree
            const firstMain = [...steps].reverse().find(s => s.depth === 0 && s.tree.length);
            if (firstMain) Object.assign(steps[steps.length - 1], { tree: firstMain.tree, header: firstMain.header, order: firstMain.order, counts: firstMain.counts, rows: firstMain.rows, suffix: [] });
            return steps;
        }

        /* 同一份資料用 Apriori 要掃幾次資料庫、數幾個組合（拿來比較） */
        function aprioriCost(db, minSup) {
            const sup = s => db.filter(t => s.every(x => t.includes(x))).length;
            const key = s => s.join('|');
            let scans = 1, counted = 0;
            const items = [...new Set(db.flat())].sort();
            counted += items.length;
            let L = items.filter(i => sup([i]) >= minSup).map(i => [i]);
            for (let k = 2; L.length; k++) {
                const prev = new Set(L.map(key));
                const C = [];
                for (let i = 0; i < L.length; i++) for (let j = i + 1; j < L.length; j++) {
                    const a = L[i], b = L[j];
                    if (key(a.slice(0, k - 2)) === key(b.slice(0, k - 2))) C.push([...a, b[k - 2]]);
                }
                const kept = C.filter(c => c.every((_, idx) => prev.has(key(c.filter((__, j) => j !== idx)))));
                scans++;
                counted += kept.length;
                L = kept.filter(c => sup(c) >= minSup);
            }
            return { scans, counted };
        }

        /* ---------- 說明文字 ---------- */
        const where = s => s.depth === 0 ? '完整的 FP-tree' : `後綴 ${fmt(s.suffix)} 的條件 FP-tree`;
        function describe(s) {
            switch (s.kind) {
                case 'start':
                    return `目標跟 Apriori 一樣：找出所有至少出現在 <b>${minSup}</b> 筆交易裡的商品組合。差別是 FP-Growth 不產生候選，而是先建一棵樹，之後都在樹上挖。`;
                case 'count': {
                    const out = Object.keys(s.counts).filter(i => s.counts[i] < minSup);
                    if (s.depth === 0) {
                        return `第 1 次掃描資料庫：數每個商品出現幾次。` +
                            (out.length ? `${out.join('、')} 不到 ${minSup} 次，之後直接忽略；` : '') +
                            `其他商品照次數由多到少排成 <b>${arrowPath(s.order)}</b>，每筆交易都照這個順序重排（次數一樣時照字碼排，只是為了結果固定）。`;
                    }
                    if (!s.order.length) {
                        return `在條件模式基底裡數次數（每條路徑要乘上它的次數）：沒有任何商品達到 ${minSup} 次，以 ${fmt(s.suffix)} 結尾的樣式到此為止，回到上一層。`;
                    }
                    return `在條件模式基底裡數次數（每條路徑要乘上它的次數）：` +
                        (out.length ? `${out.join('、')} 不到 ${minSup} 次被丟掉，` : '') + `留下 <b>${arrowPath(s.order)}</b>。`;
                }
                case 'insert': {
                    const label = `T${s.row + 1}`;
                    if (!s.path.length) return `第 2 次掃描資料庫：${label} 裡沒有頻繁的商品，跳過。`;
                    const shared = s.path.length - s.newIds.length;
                    const head = `第 2 次掃描資料庫：把 ${label} 排成「${arrowPath(s.path)}」插進樹裡。`;
                    if (!s.newIds.length) return head + `整條路徑樹上都已經有了，只要沿路把次數 +1，<b>一個新節點都不用長</b>。`;
                    if (!shared) return head + `樹上沒有可以共用的前綴，從根長出一條新的路徑。`;
                    return head + `前面的「${arrowPath(s.path.slice(0, shared))}」已經有了，沿路次數 +1；後面新長出「${arrowPath(s.path.slice(shared))}」。`;
                }
                case 'build':
                    return `把條件模式基底照「${arrowPath(s.order)}」的順序插進一棵新的小樹，這就是<b>${where(s)}</b>，共 ${s.tree.length} 個節點。`;
                case 'pattern':
                    if (s.depth === 0) {
                        const first = s.order[s.order.length - 1] === s.item;
                        return (first ? `開始挖：從次數最少的 <b>${s.item}</b> 開始。` : `接著挖下一個比較少的 <b>${s.item}</b>。`) +
                            `它本身出現 ${s.counts[s.item]} 次，先記下 ${fmt(s.pattern)}。`;
                    }
                    return `在${where(s)} 裡挖 <b>${s.item}</b>：它出現 ${s.counts[s.item]} 次，代表 ${fmt(s.pattern)} 一起出現了 ${s.counts[s.item]} 次，記下來。`;
                case 'base':
                    if (!s.base.length) return `${s.item} 的節點往上直接就是根，沒有前綴路徑，以 ${fmt(s.pattern)} 結尾的不會再有更大的樣式，換下一個商品。`;
                    return `找 ${s.item} 的條件模式基底：沿著節點鏈（虛線）找到樹上所有 ${s.item}，從每個往上走到根。共 ${s.base.length} 條路徑：` +
                        s.base.map(b => `${arrowPath(b.items)} ×${b.n}`).join('、') + `。接著用它們遞迴，找出以 ${fmt(s.pattern)} 結尾的樣式。`;
                case 'back':
                    return `以 ${fmt(s.pattern)} 結尾的樣式都挖完了，回到${where(s)}，繼續挖下一個商品。`;
                case 'end': {
                    const ap = aprioriCost(DB, minSup);
                    return `完成！找到 <b>${s.result.length}</b> 個頻繁樣式，跟 Apriori 的結果一樣。FP-Growth 只掃描資料庫 ${s.stats.scans} 次（Apriori 是 ${ap.scans} 次），也沒有產生任何候選。`;
                }
            }
            return '';
        }

        const CODE_TAGS = s => ({
            start: ['start'], count: ['count'], insert: ['insert'], build: ['insert'], pattern: ['loop', 'pattern'],
            base: s.base && s.base.length ? ['base', 'recurse'] : ['base'], back: ['recurse'], end: ['end']
        })[s.kind] || [];

        /* ---------- 畫樹 ---------- */
        function drawTree(s) {
            const box = $('tree');
            if (!s.tree.length) {
                box.innerHTML = `<div class="tree-empty">${s.kind === 'start' || (s.kind === 'count' && s.depth === 0) ? '樹還是空的，第 2 次掃描時才開始長。' : s.kind === 'count' && !s.order.length ? '沒有頻繁的商品，不用建樹。' : '樹還是空的。'}</div>`;
                return;
            }
            const kids = { 0: [] };
            s.tree.forEach(n => { kids[n.id] = []; });
            s.tree.forEach(n => kids[n.parent].push(n));
            const pos = {};
            let leaf = 0, maxDepth = 0;
            (function place(id, d) {
                maxDepth = Math.max(maxDepth, d);
                const ch = kids[id] || [];
                if (!ch.length) { pos[id] = { x: leaf++, y: d }; return; }
                ch.forEach(c => place(c.id, d + 1));
                pos[id] = { x: (pos[ch[0].id].x + pos[ch[ch.length - 1].id].x) / 2, y: d };
            })(0, 0);
            const DX = 52, DY = 58, PAD = 28;
            const X = p => PAD + p.x * DX, Y = p => 22 + p.y * DY;
            const W = PAD * 2 + Math.max(0, leaf - 1) * DX, H = 22 + maxDepth * DY + 34;

            const onIds = new Set(s.pathIds || []);
            const newIds = new Set(s.newIds || []);
            const linkTarget = linkItem && s.header[linkItem] ? linkItem : s.item;
            const linkIds = linkItem && s.header[linkItem] ? s.header[linkItem] : (s.linkIds || []);
            const linked = new Set(linkIds);

            let svg = `<svg viewBox="0 0 ${W} ${H}" width="${W}" role="img" aria-label="FP-tree">`;
            s.tree.forEach(n => {
                const a = pos[n.parent], b = pos[n.id];
                const on = onIds.has(n.id) && (n.parent === 0 || onIds.has(n.parent) || linked.has(n.parent));
                svg += `<line class="edge${on ? ' on' : ''}" x1="${X(a)}" y1="${Y(a)}" x2="${X(b)}" y2="${Y(b)}"/>`;
            });
            // 節點鏈：同一個商品的節點依序用虛線串起來
            for (let i = 1; i < linkIds.length; i++) {
                const a = pos[linkIds[i - 1]], b = pos[linkIds[i]];
                if (!a || !b) continue;
                const mx = (X(a) + X(b)) / 2, my = Math.max(Y(a), Y(b)) + 26;
                svg += `<path class="link" d="M${X(a)} ${Y(a) + 18} Q${mx} ${my} ${X(b)} ${Y(b) + 18}"/>`;
            }
            svg += `<g class="root"><circle cx="${X(pos[0])}" cy="${Y(pos[0])}" r="11"/><text x="${X(pos[0])}" y="${Y(pos[0]) + 3}" text-anchor="middle">root</text></g>`;
            s.tree.forEach(n => {
                const p = pos[n.id];
                const cls = ['node', onIds.has(n.id) ? 'on' : '', newIds.has(n.id) ? 'new' : '', linked.has(n.id) ? 'linked' : ''].join(' ');
                svg += `<g class="${cls}"><title>${n.item}：${n.count}</title>` +
                    `<circle class="body" cx="${X(p)}" cy="${Y(p)}" r="18"/>` +
                    `<text class="emo" x="${X(p)}" y="${Y(p) + 6}" text-anchor="middle">${EMOJI[n.item] || n.item[0]}</text>` +
                    `<circle class="badge" cx="${X(p) + 14}" cy="${Y(p) + 13}" r="8.5"/>` +
                    `<text class="cnt" x="${X(p) + 14}" y="${Y(p) + 16.5}" text-anchor="middle">${n.count}</text></g>`;
            });
            svg += '</svg>';
            box.innerHTML = svg;
        }

        function drawHeader(s) {
            const t = $('header');
            const all = Object.keys(s.counts).sort((a, b) => s.counts[b] - s.counts[a] || (a < b ? -1 : 1));
            if (!all.length) { t.innerHTML = ''; return; }
            const active = linkItem && s.header[linkItem] ? linkItem : s.item;
            t.innerHTML = `<caption>${s.depth === 0 ? '表頭（次數）' : '條件表頭（次數）'}</caption>` + all.map(i => {
                const ok = s.counts[i] >= minSup;
                return `<tr class="${ok ? '' : 'out'}${ok && i === active ? ' sel' : ''}" data-item="${ok ? i : ''}"><td>${EMOJI[i] || ''}</td><td class="nm">${i}</td><td class="c">${s.counts[i]}</td></tr>`;
            }).join('');
        }
        $('header').addEventListener('click', e => {
            const tr = e.target.closest('tr[data-item]');
            if (!tr || !tr.dataset.item) return;
            linkItem = linkItem === tr.dataset.item ? null : tr.dataset.item;
            const s = trace[cursor];
            drawTree(s);
            drawHeader(s);
        });

        function drawRows(s) {
            const box = $('rows');
            const isBase = s.depth > 0;
            $('data-title').textContent = isBase ? `條件模式基底（後綴 ${fmt(s.suffix)}）` : (s.kind === 'start' ? '交易資料庫' : '交易資料庫（照次數重排後）');
            if (!s.rows.length) { box.innerHTML = '<div class="rows-empty">沒有資料。</div>'; return; }
            const sorted = s.kind !== 'start' && s.rows[0] && s.rows[0].path;
            box.innerHTML = '';
            s.rows.forEach((r, i) => {
                const div = document.createElement('div');
                div.className = 'row' + (s.kind === 'insert' && s.row === i ? ' cur' : '') + (s.kind === 'insert' && i < s.row ? ' done' : '');
                const label = isBase ? `#${i + 1}` : `T${i + 1}`;
                let items;
                if (sorted) {
                    const out = r.items.filter(x => !r.path.includes(x));
                    items = r.path.map(x => `<span class="chip">${EMOJI[x] || ''}${x}</span>`).join('<span class="arrow">→</span>') +
                        out.map(x => ` <span class="chip out">${x}</span>`).join('');
                } else {
                    items = r.items.map(x => `<span class="chip">${EMOJI[x] || ''}${x}</span>`).join(isBase ? '<span class="arrow">→</span>' : '');
                }
                div.innerHTML = `<span class="rid">${label}</span>${items}${isBase ? `<span class="times">×${r.n}</span>` : ''}`;
                box.appendChild(div);
            });
        }

        function drawResult(s) {
            const box = $('levels');
            box.innerHTML = '';
            if (!s.result.length) { box.innerHTML = '<div class="empty">還沒有，開始挖之後會出現在這裡。</div>'; }
            const bySize = {};
            s.result.forEach(r => { (bySize[r.set.length] = bySize[r.set.length] || []).push(r); });
            Object.keys(bySize).sort().forEach(k => {
                const row = document.createElement('div');
                row.className = 'level';
                row.innerHTML = `<span class="tag">${k} 個</span><div class="items"></div>`;
                bySize[k].forEach(r => {
                    const p = document.createElement('span');
                    p.className = 'pat' + (r.fresh ? ' fresh' : '');
                    p.innerHTML = `<span></span><span class="n">${r.count}</span>`;
                    p.firstChild.textContent = fmt(r.set);
                    row.querySelector('.items').appendChild(p);
                });
                box.appendChild(row);
            });
            $('st-scan').textContent = s.stats.scans;
            $('st-nodes').textContent = s.stats.mainNodes;
            $('st-trees').textContent = s.stats.trees;
            const ap = aprioriCost(DB, minSup);
            $('compare').innerHTML = `同一份資料、同樣的門檻，Apriori 要掃描資料庫 <b>${ap.scans}</b> 次、實際數 <b>${ap.counted}</b> 個組合。`;
        }

        function drawCrumbs(s) {
            const box = $('crumbs');
            $('tree-title').textContent = s.depth === 0 ? 'FP-tree' : `條件 FP-tree：後綴 ${fmt(s.suffix)}`;
            const crumbs = s.crumbs.length ? s.crumbs : [[]];
            box.innerHTML = '遞迴層：' + crumbs.map((c, i) =>
                `<span class="crumb${i === crumbs.length - 1 ? ' cur' : ''}">${c.length ? fmt(c) : '完整的樹'}</span>`).join('<span class="arrow">›</span>');
        }

        /* ---------- 程式碼 ---------- */
        const KW = {
            java: new Set('public static final for if return new boolean int void class import while else null this'.split(' ')),
            py: new Set('def for in if return not and or while import from as True False None class is lambda'.split(' '))
        };
        function highlight(line) {
            const esc = x => x.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
            const at = lang === 'java' ? line.indexOf('//') : line.indexOf('#');
            let body = line, comment = '';
            if (at >= 0) { body = line.slice(0, at); comment = line.slice(at); }
            if (lang === 'py' && /^\s*"""/.test(line)) { body = ''; comment = line; }
            if (lang === 'java' && /^\s*\/\*\*/.test(line)) { body = ''; comment = line; }
            const out = body.replace(/("(?:[^"\\]|\\.)*")|(\b\d+\b)|([A-Za-z_]\w*)(\s*\()?|([^"\w]+)/g, (m, str, num, word, call) => {
                if (str) return `<span class="str">${esc(str)}</span>`;
                if (num) return `<span class="num">${num}</span>`;
                if (word) {
                    if (KW[lang].has(word)) return `<span class="kw">${word}</span>${call ? esc(call) : ''}`;
                    if (call) return `<span class="fn">${word}</span>${esc(call)}`;
                    if (lang === 'java' && /^[A-Z]/.test(word)) return `<span class="ty">${word}</span>`;
                    return word;
                }
                return esc(m);
            });
            return out + (comment ? `<span class="cm">${esc(comment)}</span>` : '');
        }

        function renderCode(tags) {
            if (measuringBlocks) return;   // 量區塊高度時不用畫程式碼（程式碼框高度不會變），省時間
            const pre = $('code');
            pre.innerHTML = CODE[lang].map(([text, t], i) =>
                `<span class="ln${t.some(x => tags.includes(x)) ? ' hl' : ''}" data-n="${i + 1}">${highlight(text) || ' '}</span>`).join('');
            const hls = [...pre.querySelectorAll('.ln.hl')];
            if (hls.length) {
                const groups = [];
                hls.forEach(el => {
                    const g = groups[groups.length - 1];
                    if (g && Number(el.dataset.n) === Number(g[g.length - 1].dataset.n) + 1) g.push(el); else groups.push([el]);
                });
                const span = (a, b) => [a.offsetTop, b.offsetTop + b.offsetHeight];
                let [top, bottom] = span(hls[0], hls[hls.length - 1]);
                if (bottom - top > pre.clientHeight - 16) {
                    const big = groups.reduce((x, y) => (y.length > x.length ? y : x));
                    [top, bottom] = span(big[0], big[big.length - 1]);
                }
                const target = (top + bottom) / 2 - pre.clientHeight / 2;
                pre.scrollTo({ top: Math.max(0, Math.min(target, top - 8)), behavior: 'smooth' });
            }
            $('downloads').innerHTML = lang === 'java'
                ? '下載 <a href="code/FPGrowth.java" download>FPGrowth.java</a>　執行 <code>javac FPGrowth.java && java FPGrowth</code>'
                : '下載 <a href="code/fpgrowth.py" download>fpgrowth.py</a>　執行 <code>python3 fpgrowth.py</code>';
        }

        /* ---------- 顯示某一步 ---------- */
        function showStep() {
            const s = trace[cursor];
            linkItem = null;
            $('explain').innerHTML = `<span class="step-no">步驟 ${cursor + 1} / ${trace.length}</span>${describe(s)}`;
            drawCrumbs(s);
            drawTree(s);
            drawHeader(s);
            drawRows(s);
            drawResult(s);
            renderCode(CODE_TAGS(s));
            $('btn-prev').disabled = $('btn-first').disabled = cursor === 0;
            $('btn-next').disabled = cursor === trace.length - 1;
            $('sup-val').textContent = minSup;
            $('sup-minus').disabled = minSup <= 1;
            $('sup-plus').disabled = minSup >= DB.length;
        }

        /* 一步一步播放時，各區塊的內容會變多變少（樹長大、清單變長…）。
           先把每一步都畫一次，用最高的那一次把每個區塊的高度固定住，
           區塊變長變短才不會把旁邊或下面的東西推來推去。
           步驟多時要量一陣子，所以分段量：每段量完立刻畫回目前這一步，畫面不會閃，也不會卡住。 */
        let measuringBlocks = false, blockJob = 0;
        function reserveBlockHeights(scope, count, showAt, current) {
            const job = ++blockJob;
            const blocks = [...scope.querySelectorAll('.card')].filter(b => !b.closest('[hidden]'));
            if (!blocks.length || count < 2) return;
            const passes = scope.querySelector('.card .card') ? 2 : 1;   // 區塊裡還有區塊時，第二輪把外層補足
            let base = blocks.map(() => ''), tallest = blocks.map(() => 0), i = 0, pass = 0;
            const chunk = () => {
                if (job !== blockJob) return;   // 資料或參數又變了，這一輪作廢
                const cur = current(), shown = blocks.map(b => b.style.minHeight);
                const until = performance.now() + 25;
                measuringBlocks = true;
                blocks.forEach((b, k) => { b.style.minHeight = base[k]; });
                while (pass < passes && performance.now() < until) {
                    showAt(i);
                    blocks.forEach((b, k) => { tallest[k] = Math.max(tallest[k], Math.ceil(b.getBoundingClientRect().height)); });
                    if (++i === count) {
                        i = 0; pass++;
                        base = tallest.map(h => h + 'px');
                        blocks.forEach((b, k) => { b.style.minHeight = base[k]; });
                    }
                }
                measuringBlocks = false;
                blocks.forEach((b, k) => { b.style.minHeight = pass < passes ? shown[k] : base[k]; });
                showAt(cur);
                if (pass < passes) setTimeout(chunk, 0);
            };
            chunk();
        }

        function reserveExplainHeight() {
            const box = $('explain');
            if (!box.offsetWidth) return;
            const probe = box.cloneNode(false);
            probe.removeAttribute('id');
            probe.style.cssText = `position:absolute;visibility:hidden;left:-9999px;min-height:0;width:${box.offsetWidth}px`;
            document.body.appendChild(probe);
            let tallest = 0;
            trace.forEach((s, i) => {
                probe.innerHTML = `<span class="step-no">步驟 ${i + 1} / ${trace.length}</span>${describe(s)}`;
                tallest = Math.max(tallest, probe.offsetHeight);
            });
            probe.remove();
            box.style.minHeight = tallest + 'px';
            reserveBlockHeights(document, trace.length, i => { cursor = i; showStep(); }, () => cursor);
        }

        function rebuild() {
            stopAuto();
            trace = buildTrace(DB, minSup);
            cursor = 0;
            showStep();
            reserveExplainHeight();
        }

        function step(dir) {
            const next = cursor + dir;
            if (next < 0 || next >= trace.length) return false;
            cursor = next;
            showStep();
            return cursor < trace.length - 1;
        }
        function stopAuto() {
            clearInterval(timer);
            timer = null;
            $('btn-play').textContent = '▶ 自動播放';
        }
        $('btn-next').addEventListener('click', () => { stopAuto(); step(1); });
        $('btn-prev').addEventListener('click', () => { stopAuto(); step(-1); });
        $('btn-first').addEventListener('click', () => { stopAuto(); cursor = 0; showStep(); });
        $('btn-play').addEventListener('click', () => {
            if (timer) { stopAuto(); return; }
            if (cursor === trace.length - 1) { cursor = 0; showStep(); }
            $('btn-play').textContent = '⏸ 暫停';
            timer = setInterval(() => { if (!step(1)) stopAuto(); }, 1900);
        });
        document.addEventListener('keydown', e => {
            if (e.key === 'ArrowRight') { stopAuto(); step(1); }
            if (e.key === 'ArrowLeft') { stopAuto(); step(-1); }
        });
        $('sup-minus').addEventListener('click', () => { if (minSup > 1) { minSup--; rebuild(); } });
        $('sup-plus').addEventListener('click', () => { if (minSup < DB.length) { minSup++; rebuild(); } });
        $('lang').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b) return;
            lang = b.dataset.lang;
            [...$('lang').children].forEach(x => x.classList.toggle('active', x === b));
            renderCode(CODE_TAGS(trace[cursor]));
        });
        let resizeTimer = null;
        window.addEventListener('resize', () => { clearTimeout(resizeTimer); resizeTimer = setTimeout(reserveExplainHeight, 150); });

        rebuild();
    </script>
</body>

</html>
