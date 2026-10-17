<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/overview.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/overview-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/overview-180.png">
    <title>Research 總覽</title>
    <meta name="description" content="把所有研究 Demo 串起來的地圖：演算法之間誰改良自誰、建議的閱讀順序，以及掃描次數、候選、額外結構的比較表。">
    <script src="../assets/theme.js"></script>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=Syne:wght@700;800&display=swap');
        /* 手機瀏覽器會自動把某些段落的字放大，表格裡就會一格大一格小；關掉它 */
        html { -webkit-text-size-adjust: 100%; text-size-adjust: 100%; }

        ::selection { background: var(--lt-7c3aed, #7c3aed); color: var(--lt-ffffff, #fff); -webkit-text-fill-color: var(--lt-ffffff, #fff); }

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
        .intro { color: var(--lt-c6c6d6, #c6c6d6); max-width: 760px; margin-top: 0.9rem; font-size: 0.95rem; }
        .intro b { color: var(--text); }
        a { color: var(--accent2); }

        .sec-label { font: 0.75rem 'Space Mono', monospace; color: var(--muted); letter-spacing: 0.1em; margin: 2rem 0 0.6rem; }

        .card {
            background: var(--panel);
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 1rem;
            min-width: 0;
        }
        .card-head { display: flex; justify-content: space-between; align-items: baseline; gap: 0.5rem; flex-wrap: wrap; margin-bottom: 0.7rem; }
        .card-head h2 { margin: 0; }
        .hint { color: var(--muted); font-size: 0.8rem; }

        /* ── 關係圖：圖本身固定寬度，窄螢幕時只在框內左右捲，不撐寬整頁 ── */
        .graph-scroll {
            overflow-x: auto;
            -webkit-overflow-scrolling: touch;
            border-radius: 10px;
            background: var(--lt-0a0a12, #0a0a12);
            border: 1px solid var(--border);
        }
        .graph { display: block; margin: 0 auto; width: 900px; max-width: none; height: auto; }
        @media (min-width: 1000px) { .graph { width: 100%; max-width: 1060px; } }
        .scroll-hint { display: none; }
        @media (max-width: 940px) { .scroll-hint { display: inline; } }
        .graph .band-t { font: 700 12px 'Space Mono', monospace; letter-spacing: 0.06em; }
        .graph .nt { font: 700 13px -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang TC", "Noto Sans TC", sans-serif; fill: var(--text); text-anchor: middle; }
        .graph .nt2 { font-size: 11.5px; }
        .graph .ny { font: 10px 'Space Mono', monospace; fill: var(--muted); text-anchor: middle; }
        .graph .lg { font-size: 12px; fill: var(--lt-c6c6d6, #c6c6d6); }
        .graph .e { fill: none; stroke: var(--lt-a78bfa, #a78bfa); stroke-width: 1.6; stroke-opacity: 0.75; transition: stroke-opacity 0.15s, stroke-width 0.15s; }
        .graph .e.dash { stroke: var(--lt-22d3ee, #22d3ee); stroke-dasharray: 5 4; }
        .graph .node rect { stroke-width: 1.6; transition: fill 0.15s; }
        .graph a.node { cursor: pointer; }
        .graph a.node:hover rect, .graph a.node:focus rect { fill: var(--lt-24243f, #24243f); }
        .graph a.node:focus { outline: none; }
        .graph a.node:focus-visible rect { stroke: var(--lt-ffffff, #fff); stroke-width: 2.4; }
        .graph .node.soon rect { fill: none; stroke-dasharray: 4 3; stroke-opacity: 0.8; }
        .graph .node.soon .nt { fill: var(--muted); }
        .graph .node.soon .ny { fill: var(--warn); }
        .graph g.node, .graph a.node { transition: opacity 0.15s; }
        /* 指到一個節點：它的祖先和後代亮起來，其他變淡 */
        .graph.focus .node, .graph.focus .e { opacity: 0.18; }
        .graph.focus .node.hl, .graph.focus .e.hl { opacity: 1; }
        .graph.focus .e.hl { stroke-width: 2.4; stroke-opacity: 1; }

        /* ── 依類別的清單（手機的主要看法，電腦上當成索引） ── */
        .groups { display: grid; gap: 0.8rem; margin-top: 1rem; }
        @media (min-width: 640px) { .groups { grid-template-columns: 1fr 1fr; } }
        @media (min-width: 1000px) { .groups { grid-template-columns: 1fr 1fr 1fr; } }
        .grp { background: var(--panel-2); border-radius: 12px; padding: 0.8rem 0.9rem; border-left: 3px solid var(--gc); min-width: 0; }
        .grp h3 { font: 700 0.82rem 'Space Mono', monospace; color: var(--gc); letter-spacing: 0.06em; margin-bottom: 0.4rem; }
        .grp ul { list-style: none; display: grid; gap: 0.55rem; }
        .grp li p { color: var(--lt-c6c6d6, #c6c6d6); font-size: 0.86rem; line-height: 1.5; }
        .nm { font-weight: 700; text-decoration: none; color: var(--text); overflow-wrap: anywhere; }
        a.nm { color: var(--accent2); }
        a.nm:hover { text-decoration: underline; }
        .nm.soon { color: var(--muted); }
        .yr { font: 0.72rem 'Space Mono', monospace; color: var(--muted); margin-left: 0.45rem; }
        .soon-tag { display: inline-block; font-size: 0.68rem; color: var(--warn); border: 1px solid var(--lt-f59e0b-50, rgba(245, 158, 11, 0.5)); border-radius: 999px; padding: 0 0.45rem; margin-left: 0.45rem; vertical-align: 1px; white-space: nowrap; }
        .froms { display: flex; flex-wrap: wrap; gap: 0.3rem; margin-top: 0.25rem; }
        .from { font-size: 0.72rem; color: var(--lt-c4b5fd, #c4b5fd); background: var(--lt-7c3aed-14, rgba(124, 58, 237, 0.14)); border-radius: 6px; padding: 0.05rem 0.4rem; }
        .from.dash { color: var(--lt-67e8f9, #67e8f9); background: var(--lt-06b6d4-12, rgba(6, 182, 212, 0.12)); }

        /* ── 閱讀路線 ── */
        .routes { display: grid; gap: 1rem; }
        @media (min-width: 960px) { .routes { grid-template-columns: repeat(3, 1fr); } }
        .route { border-top: 3px solid var(--rc); }
        .route-sub { color: var(--muted); font-size: 0.85rem; margin: -0.35rem 0 0.7rem; }
        .route ol { list-style: none; counter-reset: st; display: grid; gap: 0.15rem; }
        .route li { counter-increment: st; position: relative; padding: 0 0 0.65rem 2.3rem; }
        .route li::before {
            content: counter(st);
            position: absolute; left: 0; top: 0.05rem;
            width: 1.6rem; height: 1.6rem; border-radius: 50%;
            display: flex; align-items: center; justify-content: center;
            font: 700 0.8rem 'Space Mono', monospace;
            background: var(--panel-2); border: 2px solid var(--rc); color: var(--text);
        }
        /* 站與站之間的連線 */
        .route li:not(:last-child)::after {
            content: ''; position: absolute; left: calc(0.8rem - 1px); top: 1.75rem; bottom: 0.05rem;
            width: 2px; background: var(--rc); opacity: 0.35;
        }
        .route li p { color: var(--lt-c6c6d6, #c6c6d6); font-size: 0.86rem; line-height: 1.5; }
        .route-next { color: var(--muted); font-size: 0.82rem; border-top: 1px dashed var(--border); padding-top: 0.6rem; margin-top: 0.2rem; }
        .route-next .ex { font-weight: 400; }
        .route-next a.ex { color: var(--accent2); }

        /* ── 比較表：在自己的框內左右捲，第一欄固定 ── */
        .tbl-scroll { overflow-x: auto; -webkit-overflow-scrolling: touch; border: 1px solid var(--border); border-radius: 10px; }
        .cmp { border-collapse: separate; border-spacing: 0; width: 100%; min-width: 1040px; font-size: 0.84rem; }
        .cmp th, .cmp td { padding: 0.55rem 0.65rem; text-align: left; vertical-align: top; border-bottom: 1px solid var(--border); line-height: 1.5; }
        .cmp thead th { position: sticky; top: 0; background: var(--panel-2); color: var(--muted); font-weight: 400; font-size: 0.78rem; white-space: nowrap; }
        .cmp tbody th { position: sticky; left: 0; background: var(--panel); min-width: 8.5rem; max-width: 9.5rem; z-index: 1; border-right: 1px solid var(--border); }
        .cmp thead th:first-child { position: sticky; left: 0; z-index: 2; border-right: 1px solid var(--border); }
        .cmp tbody tr:hover td, .cmp tbody tr:hover th { background: var(--lt-14142a, #14142a); }
        .cmp td { color: var(--lt-c6c6d6, #c6c6d6); }
        .cmp td:nth-child(3) { min-width: 15rem; }
        .cmp td:nth-child(4) { min-width: 10rem; }
        .cmp td:nth-child(5) { min-width: 9rem; }
        .cmp td.mono { font-family: 'Space Mono', monospace; font-size: 0.78rem; color: var(--text); }
        .cmp td.c-yes { color: var(--lt-fca5a5, #fca5a5); }
        .cmp td.c-no { color: var(--lt-86efac, #86efac); }
        .cmp td.c-na { color: var(--muted); }
        .cmp .soon-tag { display: block; width: max-content; margin: 0.2rem 0 0; }
        .gtag { display: inline-block; white-space: nowrap; font-size: 0.72rem; color: var(--gc); border: 1px solid var(--gc); border-radius: 999px; padding: 0 0.45rem; }

        .bench { display: flex; gap: 1rem; align-items: center; justify-content: space-between; flex-wrap: wrap; margin-top: 1rem; border-left: 3px solid var(--warn); }
        .bench p { color: var(--lt-c6c6d6, #c6c6d6); font-size: 0.9rem; flex: 1 1 300px; min-width: 0; }
        .btn-link { display: inline-block; text-decoration: none; color: var(--lt-ffffff, #fff); background: var(--accent); border-radius: 8px; padding: 0.45rem 0.9rem; font-size: 0.9rem; white-space: nowrap; }
        .btn-link:hover { filter: brightness(1.15); }
        .btn-link.soon { background: var(--panel-2); color: var(--muted); border: 1px dashed var(--border); }

        .notes { margin-top: 1rem; display: grid; gap: 1rem; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr; } }
        .notes p, .notes li { color: var(--lt-c6c6d6, #c6c6d6); font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; }
        .notes b { color: var(--text); }
    </style>
    <link rel="stylesheet" href="../assets/theme.css">
</head>

<body>
    <div class="wrap">
        <a class="back" href="../index.html#research">← RETURN TO PORTFOLIO</a>
        <div class="kicker">RESEARCH DEMO · OVERVIEW</div>
        <h1>Research 總覽<small>把所有研究 Demo 串起來的地圖：誰改良自誰、從哪裡開始看</small></h1>
        <p class="intro">
            這裡的 Demo 看起來主題很多，其實大部分都從同一個起點長出來：<b>Apriori</b> 的「不頻繁的組合，包含它的更大組合也一定不頻繁」。
            之後的方法有的換資料結構（樹、垂直格式、清單），有的換問題（看順序、看利潤、資料一直進來、資料有位置）。
            下面的圖把 <!--N_ALGO--> 個演算法照「改良自／延伸自」連起來，點方框就能進那個 Demo；不知道從哪開始，就照<b>閱讀路線</b>走；
            想一次比較，最下面有<b>比較表</b>。大部分 Demo 用的都是同一份 8 筆超商交易（☕🍞🥛🍙🥚🥔），換頁時可以直接對照數字。
        </p>

        <div class="sec-label">// 演算法關係圖</div>
        <div class="card" id="graph-card">
            <div class="card-head">
                <h2>誰改良自誰</h2>
                <span class="hint"><span class="scroll-hint">圖可以在框裡左右滑動。</span>滑鼠移到方框上，會亮出它的來源和後續。</span>
            </div>
            <div class="graph-scroll" id="graph-scroll">
<!--GRAPH-->
            </div>
            <div class="groups" id="groups">
<!--LIST-->
            </div>
        </div>

        <div class="sec-label">// 建議閱讀順序</div>
        <div class="routes" id="routes">
<!--ROUTES-->
        </div>

        <div class="sec-label">// 比較表</div>
        <div class="card" id="table-card">
            <div class="card-head">
                <h2>每個演算法一列</h2>
                <span class="hint">表格可以在框裡左右滑動，第一欄固定。</span>
            </div>
            <div class="tbl-scroll">
<!--TABLE-->
            </div>
            <p class="hint" style="margin-top:0.6rem">「範例資料」的次數是各 Demo 頁用預設資料、預設門檻跑到最後的結果；改了資料或門檻，數字會跟著變。
                「單趟」表示資料只會依序讀一次、讀完就丟（串流本來就不能回頭）。</p>
        </div>

        <div class="card bench">
            <p><b>想知道「實際上誰比較快」？</b>效能比賽場把同一份資料交給好幾個演算法跑，比較花的時間和處理的組合數。
                比較表裡「掃描幾次」「會不會產生候選」的差別，資料一變大就會變成看得見的時間差。</p>
<!--BENCH-->
        </div>

        <div class="notes">
            <div class="card">
                <h2>箭頭是什麼意思？</h2>
                <p><b>實線</b>是論文或做法上明確的「改良自／延伸自」：例如 FP-Growth 不再像 Apriori 一層一層猜候選，CHARM 直接建在 Eclat 的垂直格式上，
                    HUI-Miner 拿掉了 Two-Phase、UP-Growth 都需要的「回頭驗證候選」。<b>虛線</b>是借用同一個想法、但不算直接改良：
                    gSpan 跟 PrefixSpan 一樣是深度優先的樣式成長（集合 → 序列 → 圖）；Count-Min 跟 Bloom Filter 一樣用好幾個雜湊把東西撒進格子。</p>
                <p style="margin-top:0.5rem">串流和空間那兩排沒有連到 Apriori，因為它們解決的是不同的問題（記憶體不夠、資料有位置）；
                    但想法常常相通，例如<b>共位樣式</b>的剪枝就是 Apriori 的向下封閉性搬到地圖上，<b>HUI-Miner</b> 的 utility list 則像在 Eclat 的 TID 集合上多記效益。</p>
            </div>
            <div class="card">
                <h2>這些方法在比什麼？</h2>
                <ul>
                    <li><b>少掃資料庫：</b>資料在硬碟上時，掃一次就很花時間。Apriori 每一層掃一次；FP-Growth 2 次、Eclat 1 次，之後都在記憶體裡的結構上做。</li>
                    <li><b>不產生候選：</b>「先猜再數」會白數很多最後不夠的組合。樣式成長（FP-Growth、PrefixSpan、HUI-Miner…）只長出真的出現過的組合。</li>
                    <li><b>上界要緊：</b>效益沒有向下封閉性，只能用上界剪。TWU → UP-Growth 的節點效益 → Σiutil + Σrutil → EFIM 的子樹效益，一路越來越緊。</li>
                    <li><b>資料會變：</b>增量（FUP、CanTree）和串流（滑動視窗、近似計數、sketch）都在想同一件事：<b>新資料進來時，哪些結果一定沒變、哪些要重算</b>，這也是實驗室研究的主軸。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        // 圖上每條箭頭 [來源, 目標]，由 build.py 產生
        const EDGES = /*EDGES_JSON*/null;

        (function setupGraphFocus() {
            const svg = document.querySelector('svg.graph');
            if (!svg) return;
            const up = {}, down = {};
            for (const [s, t] of EDGES) {
                (down[s] = down[s] || []).push(t);
                (up[t] = up[t] || []).push(s);
            }
            function walk(start, next) {
                const seen = new Set([start]), stack = [start];
                while (stack.length) {
                    const x = stack.pop();
                    for (const y of next[x] || []) if (!seen.has(y)) { seen.add(y); stack.push(y); }
                }
                return seen;
            }
            function focusOn(id) {
                const keep = new Set([...walk(id, up), ...walk(id, down)]);
                svg.classList.add('focus');
                svg.querySelectorAll('.node').forEach(n => n.classList.toggle('hl', keep.has(n.dataset.id)));
                const anc = walk(id, up), des = walk(id, down);
                svg.querySelectorAll('.e[data-s]').forEach(e => {
                    const s = e.dataset.s, t = e.dataset.t;
                    // 只亮「祖先鏈」和「後代鏈」上的箭頭
                    e.classList.toggle('hl', (anc.has(s) && anc.has(t)) || (des.has(s) && des.has(t)));
                });
            }
            function clear() {
                svg.classList.remove('focus');
                svg.querySelectorAll('.hl').forEach(n => n.classList.remove('hl'));
            }
            svg.querySelectorAll('.node').forEach(n => {
                n.addEventListener('mouseenter', () => focusOn(n.dataset.id));
                n.addEventListener('mouseleave', clear);
                n.addEventListener('focus', () => focusOn(n.dataset.id));
                n.addEventListener('blur', clear);
            });
        })();
    </script>
</body>

</html>
