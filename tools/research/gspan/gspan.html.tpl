<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/gspan.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/gspan-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/gspan-180.png">
    <title>gSpan 圖形樣式探勘</title>
    <meta name="description" content="一步一步看 gSpan 怎麼在一堆分子圖裡找出常見的子結構：DFS code、最右路徑延伸、最小 DFS code 檢查去重，Java 與 Python 程式碼逐行對照。">
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

        /* 手機：一欄，依序 步驟 → 圖形資料庫 → 目前的樣式 → 延伸表 → 程式碼 → 結果；電腦：兩欄 */
        .layout {
            display: grid;
            gap: 1rem;
            margin-top: 1.3rem;
            grid-template-areas: "step" "db" "pat" "cand" "code" "result";
            align-items: start;
        }
        .layout > * { min-width: 0; }
        @media (min-width: 960px) {
            .layout {
                grid-template-columns: 1fr 1fr;
                grid-template-areas: "step code" "db code" "pat cand" "result result";
            }
        }
        .a-step { grid-area: step; }
        .a-db { grid-area: db; }
        .a-pat { grid-area: pat; }
        .a-cand { grid-area: cand; }
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
        button.btn.small { padding: 0.25rem 0.55rem; font-size: 0.8rem; }

        .player { display: flex; flex-wrap: wrap; gap: 0.4rem; align-items: center; }
        .minsup { display: flex; align-items: center; gap: 0.45rem; font-size: 0.88rem; margin-left: auto; }
        .minsup .val { font: 700 1rem 'Space Mono', monospace; min-width: 1.2em; text-align: center; }
        .minsup .unit { color: var(--muted); font-size: 0.8rem; }
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
        .pt { white-space: nowrap; font-weight: 600; color: var(--text); }


        /* ── 圖形資料庫 ── */
        .presets { display: flex; flex-wrap: wrap; gap: 0.35rem; margin-bottom: 0.6rem; }
        .presets .btn.cur { border-color: var(--accent2); color: var(--accent2); }
        .graphs { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0.5rem; }
        @media (min-width: 600px) { .graphs { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
        .gbox { background: #0b0b16; border: 1px solid var(--border); border-radius: 10px; padding: 0.3rem 0.4rem 0.2rem; cursor: pointer; transition: border-color 0.2s, background 0.2s, opacity 0.2s; min-width: 0; }
        .gbox.miss { opacity: 0.4; }
        .gbox.pick { border-color: var(--accent2); background: rgba(6, 182, 212, 0.08); }
        .gbox .gt { display: flex; justify-content: space-between; align-items: baseline; gap: 0.3rem; font-size: 0.76rem; color: var(--muted); }
        .gbox .gt b { color: var(--text); font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .gbox .ge { font: 0.66rem 'Space Mono', monospace; white-space: nowrap; visibility: hidden; }
        .gbox .ge.on { visibility: visible; color: var(--accent2); }
        .gbox svg { display: block; width: 100%; height: auto; }
        svg .at { font: 700 11px 'Space Mono', ui-monospace, monospace; text-anchor: middle; dominant-baseline: central; }
        svg .bd { font: 700 9px 'Space Mono', ui-monospace, monospace; text-anchor: middle; dominant-baseline: central; }
        .legend { display: flex; flex-wrap: wrap; gap: 0.3rem 0.9rem; font-size: 0.75rem; color: var(--muted); margin-top: 0.6rem; }
        .legend .sw { display: inline-block; width: 14px; height: 4px; border-radius: 2px; margin-right: 0.3rem; vertical-align: 3px; }
        .legend .dot { display: inline-block; font: 700 0.68rem 'Space Mono', monospace; color: var(--accent2); margin-right: 0.25rem; }

        /* ── 目前的樣式 ── */
        .pat-wrap { display: grid; gap: 0.6rem; }
        .pat-wrap > * { min-width: 0; }
        .pat-svg { width: 100%; max-width: 230px; justify-self: center; }
        .pat-svg svg { display: block; width: 100%; height: auto; }
        @media (min-width: 600px) { .pat-wrap { grid-template-columns: minmax(0, 190px) minmax(0, 1fr); align-items: start; } }
        .tu { font: 0.8rem 'Space Mono', monospace; white-space: nowrap; }
        table.cnt tr.add td { background: rgba(245, 158, 11, 0.13); }
        table.cnt tr.add td:first-child { box-shadow: inset 3px 0 0 var(--warn); }
        table.cnt tr.rmrow td:first-child { box-shadow: inset 3px 0 0 #a78bfa; }
        table.cnt tr.after td { opacity: 0.35; }
        table.cnt td.mono { font: 0.78rem 'Space Mono', monospace; white-space: nowrap; }
        table.cnt td.kind { font-size: 0.74rem; color: var(--muted); white-space: nowrap; }
        table.cnt td.bad { color: var(--bad); }
        table.cnt td.good { color: #86efac; }
        table.cnt th sub { font-size: 0.65rem; }
        .rm-line { font-size: 0.8rem; color: var(--muted); margin-bottom: 0.4rem; min-height: 1.3em; }
        .rm-line b { color: #c4b5fd; font-weight: 600; }

        /* ── 延伸表 ── */
        table.cand tbody tr { cursor: pointer; }
        table.cand tbody tr:hover td { background: rgba(255, 255, 255, 0.03); }
        table.cand tr.cur td { background: rgba(245, 158, 11, 0.13); }
        table.cand tr.cur td:first-child { box-shadow: inset 3px 0 0 var(--warn); }
        table.cand tr.picked td { background: rgba(6, 182, 212, 0.16); }
        table.cand td.res { font-size: 0.76rem; white-space: nowrap; }
        .res.low { color: #55556e; }
        .res.wait { color: var(--muted); }
        .res.ok { color: #86efac; }
        .res.notmin { color: var(--bad); }
        table.cand td.sup { font: 700 0.85rem 'Space Mono', monospace; }
        table.cand td.sup.low { color: #55556e; font-weight: 400; }
        @media (max-width: 380px) {
            table.cand td, table.cand th { padding-left: 0.12rem; padding-right: 0.12rem; }
            table.cand td.mono { font-size: 0.7rem; }
            table.cand td.kind, table.cand td.res { font-size: 0.68rem; }
        }

        /* ── 結果 ── */
        .found { display: flex; flex-wrap: wrap; gap: 0.4rem; min-width: 0; }
        .fp { display: inline-flex; align-items: center; gap: 0.2rem; border: 1px solid rgba(34, 197, 94, 0.45); border-radius: 8px; padding: 0.1rem 0.35rem 0.1rem 0.15rem; background: #0b0b16; }
        .fp svg { width: 68px; height: auto; display: block; }
        .fp .no { font: 0.7rem 'Space Mono', monospace; color: var(--muted); }
        .fp .n { font: 700 0.76rem 'Space Mono', monospace; color: #86efac; }
        .fp.fresh { box-shadow: 0 0 0 2px var(--warn); }
        .fp .lbl { display: grid; line-height: 1.25; }
        /* ── 計數表 ── */
        .prefix-line { font-size: 0.85rem; color: var(--muted); margin-bottom: 0.5rem; }
        .prefix-line .pt { font-size: 0.95rem; }
        table.cnt { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
        table.cnt th { font-weight: 500; color: var(--muted); font-size: 0.76rem; text-align: center; padding: 0.25rem; border-bottom: 1px solid var(--border); line-height: 1.3; }
        table.cnt th:first-child { text-align: left; }
        table.cnt th small { display: block; font-size: 0.68rem; color: #6a6a85; }
        table.cnt td { padding: 0.2rem 0.25rem; border-bottom: 1px solid var(--border); text-align: center; }
        table.cnt td.nm { text-align: left; white-space: nowrap; }
        table.cnt td.c { font: 700 0.85rem 'Space Mono', monospace; }
        td.c span { display: inline-block; min-width: 2.4em; padding: 0.05rem 0.3rem; border-radius: 6px; border: 1px solid transparent; }
        td.c.zero span { color: #44445c; font-weight: 400; }
        td.c.no span { color: var(--muted); font-weight: 400; cursor: pointer; }
        td.c.ok span { color: #86efac; border-color: rgba(34, 197, 94, 0.45); cursor: pointer; }
        td.c.na span { color: #44445c; font-weight: 400; }
        td.c.done span { background: rgba(34, 197, 94, 0.14); }
        td.c.cur span { border-color: var(--warn); box-shadow: 0 0 0 1px var(--warn); color: var(--warn); }
        td.c.picked span { background: rgba(6, 182, 212, 0.22); }
        .cnt-hint { font-size: 0.8rem; color: var(--muted); margin-top: 0.5rem; min-height: 2.6em; }
        .cnt-hint b { color: var(--text); font-weight: 600; }

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
            max-height: 620px;
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
        .level .items { display: flex; flex-wrap: wrap; gap: 0.35rem; min-width: 0; }
        .pat { font-size: 0.85rem; border: 1px solid rgba(34, 197, 94, 0.5); border-radius: 7px; padding: 0.1rem 0.45rem; white-space: nowrap; }
        .pat .n { font: 700 0.74rem 'Space Mono', monospace; margin-left: 0.35rem; color: #86efac; }
        .pat.fresh { box-shadow: 0 0 0 2px var(--warn); }
        .empty { color: var(--muted); font-size: 0.85rem; }
        .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.5rem; margin-top: 0.9rem; }
        .stat { background: var(--panel-2); border-radius: 10px; padding: 0.55rem 0.6rem; min-width: 0; }
        .stat .v { font: 700 1.25rem 'Space Mono', monospace; }
        .stat .k { color: var(--muted); font-size: 0.75rem; line-height: 1.35; }
        .compare { margin-top: 0.8rem; font-size: 0.85rem; color: var(--muted); }
        .compare b { color: var(--text); }

        .notes { margin-top: 1rem; display: grid; gap: 1rem; }
        .notes > * { min-width: 0; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr; } }
        .notes p, .notes li { color: #c6c6d6; font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; }
        .notes b { color: var(--text); }
        .notes a { color: var(--accent2); }
        .level .tag { white-space: nowrap; }
        .level { grid-template-columns: 3.6em 1fr; }
    </style>
</head>

<body>
    <div class="wrap">
        <a class="back" href="../index.html#research">← RETURN TO PORTFOLIO</a>
        <div class="kicker">RESEARCH DEMO · GRAPH PATTERN MINING</div>
        <h1>gSpan 圖形樣式探勘<small>從交易、序列再到圖：找出很多分子裡都有的子結構</small></h1>
        <p class="intro">
            <a href="apriori.html">Apriori</a> 找的是一起買的商品（集合），<a href="prefixspan.html">PrefixSpan</a> 多了先後順序（序列）。
            這頁再往上一層：資料變成<b>圖</b>，例如分子——點是原子（C 碳、O 氧、N 氮），邊是化學鍵（<b>-</b> 單鍵、<b>=</b> 雙鍵）。
            要找的是「很多張圖裡都有的子圖」，例如 C-C=O。難的地方在於<b>同一個子圖有很多種寫法</b>：從哪個點開始、先走哪條邊都可以，
            不小心就會把同一個形狀當成不同樣式數好幾次。gSpan 的做法是把子圖寫成一串邊（<b>DFS code</b>），規定好大小順序，
            只承認最小的那種寫法；樣式成長的想法跟 PrefixSpan 一樣：一次只接一條邊、從<b>最右路徑</b>往外長，再遞迴。
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
                        <span class="val" id="sup-val">2</span>
                        <button class="btn stepper" id="sup-plus" aria-label="增加">+</button>
                        <span class="unit">張圖</span>
                    </div>
                </div>
                <div class="explain" id="explain"></div>
            </div>

            <div class="card a-db">
                <div class="card-head"><h2>圖形資料庫</h2></div>
                <div class="presets" id="presets"></div>
                <div class="graphs" id="graphs"></div>
                <div class="legend">
                    <span><i class="sw" style="background:#06b6d4"></i>目前樣式在這張圖裡的位置（嵌入）</span>
                    <span><i class="sw" style="background:#a78bfa"></i>最右路徑</span>
                    <span><i class="sw" style="background:#f59e0b"></i>剛接上的邊</span>
                    <span><i class="dot">0</i>點在 DFS code 裡的編號；同一處可能有好幾種對法，點圖換下一種</span>
                </div>
            </div>

            <div class="card a-pat">
                <h2 id="pat-title">目前的樣式與 DFS code</h2>
                <div class="pat-wrap">
                    <div class="pat-svg" id="pat-svg"></div>
                    <div>
                        <div class="rm-line" id="rm-line"></div>
                        <table class="cnt" id="code-t"></table>
                    </div>
                </div>
                <div class="cnt-hint" id="pat-hint"></div>
            </div>

            <div class="card a-cand">
                <h2 id="cand-title">延伸表：還能接哪一條邊？</h2>
                <div class="prefix-line" id="cand-line"></div>
                <table class="cnt cand" id="cand-t"></table>
                <div class="cnt-hint" id="cand-hint"></div>
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
                <h2>目前找到的頻繁子圖</h2>
                <div class="levels" id="levels"></div>
                <div class="stats">
                    <div class="stat"><div class="v" id="st-found">0</div><div class="k">頻繁子圖</div></div>
                    <div class="stat"><div class="v" id="st-cands">0</div><div class="k">延伸表裡列過的邊</div></div>
                    <div class="stat"><div class="v" id="st-pruned">0</div><div class="k">不是最小 DFS code、剪掉</div></div>
                </div>
                <div class="compare" id="compare"></div>
            </div>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼只留最小 DFS code 就不會漏、也不會重複？</h2>
                <p>把子圖從某個點開始做深度優先走訪，照「發現的順序」幫點編號，每走一條邊就記一列 (i, j, 原子i, 鍵, 原子j)，整串就是 <b>DFS code</b>。
                    換個起點、換個走法，同一個子圖會寫出不同的 code；gSpan 規定一套大小順序（後退邊先、前進邊從越深的點越先、最後比標籤），
                    每個子圖只承認<b>最小的那一種</b>。所以兩個 code 只要最小的寫法一樣，就是同一個子圖（同構），判斷同構就變成比大小。</p>
                <p style="margin-top:0.5rem">不會漏：最小 DFS code 去掉最後一列，剩下的還是（較小子圖的）最小 DFS code，所以從單一條邊開始、每次只接一條邊，
                    沿著「最小 code」一路長，一定長得到每一個頻繁子圖。不會重複：長出來的 code 不是最小的就剪掉，它和它後面整棵都不用看——
                    更小的那個寫法照順序<b>一定在前面已經找過</b>。支持度也有向下封閉性：子圖出現在 k 張圖，多接一條邊只會更少，所以不夠的邊直接丟掉。</p>
            </div>
            <div class="card">
                <h2>優缺點、跟前面方法的關係</h2>
                <ul>
                    <li><b>不產生候選：</b>跟 FP-Growth、PrefixSpan 一樣是「樣式成長」，只去接嵌入旁邊真的存在的邊；不像圖版的 Apriori（AGM、FSG）要先把兩個子圖合併成候選，再做大量的同構測試。</li>
                    <li><b>只往最右路徑長：</b>從其他點長出去的寫法一定不是最小的，所以乾脆不產生，省掉大部分重複。</li>
                    <li><b>代價：</b>最小 DFS code 檢查本身要把子圖重寫一次，子圖大、對稱多（例如苯環）時很花時間；每個樣式還要記住它在各圖裡的所有嵌入。</li>
                    <li>這頁的圖都很小（每張最多 6 個原子），所以樣式大小沒有另外設上限。延伸：只留封閉子圖的 CloseGraph、圖資料一直進來的增量／串流版本，都是同一套 DFS code 再加剪枝。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           gSpan 一步一步看
           網頁裡用 JavaScript 照著同樣的流程跑一次，把每一步（含每一層遞迴）記下來；
           右邊的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = /*CODE_JSON*/null;

        const ATOM = {
            C: { zh: '碳', fill: '#262638', stroke: '#9a9ab5', text: '#e6e6f0' },
            O: { zh: '氧', fill: '#3a141c', stroke: '#f87171', text: '#fecaca' },
            N: { zh: '氮', fill: '#122046', stroke: '#60a5fa', text: '#bfdbfe' }
        };
        const COL = { emb: '#06b6d4', rm: '#a78bfa', add: '#f59e0b', plain: '#6a6a85', dim: '#2c2c44' };
        /* 正多邊形的座標（環狀分子用） */
        const poly = (n, cx, cy, r) => Array.from({ length: n }, (_, k) => {
            const a = -Math.PI / 2 + 2 * Math.PI * k / n;
            return [Math.round((cx + r * Math.cos(a)) * 10) / 10, Math.round((cy + r * Math.sin(a)) * 10) / 10];
        });
        const ringBonds = kinds => [...kinds].map((b, k) => [k, (k + 1) % kinds.length, b]);
        const PRESETS = [
            {
                label: '鏈狀分子', sup: 2, graphs: [
                    { title: '醋酸', atoms: 'CCOO', bonds: [[0, 1, '-'], [1, 2, '='], [1, 3, '-']], pos: [[22, 66], [56, 44], [56, 12], [90, 66]] },
                    { title: '乙醇', atoms: 'CCO', bonds: [[0, 1, '-'], [1, 2, '-']], pos: [[22, 64], [58, 40], [94, 64]] },
                    { title: '甘胺酸', atoms: 'NCCOO', bonds: [[0, 1, '-'], [1, 2, '-'], [2, 3, '='], [2, 4, '-']], pos: [[10, 40], [38, 66], [68, 42], [68, 12], [104, 64]] },
                    { title: '丙酮', atoms: 'CCOC', bonds: [[0, 1, '-'], [1, 2, '='], [1, 3, '-']], pos: [[22, 66], [60, 44], [60, 12], [98, 66]] },
                    { title: '乙醛', atoms: 'CCO', bonds: [[0, 1, '-'], [1, 2, '=']], pos: [[22, 64], [58, 40], [94, 64]] }
                ]
            },
            {
                label: '三元環', sup: 2, graphs: [
                    { title: '環丙烷', atoms: 'CCC', bonds: ringBonds('---'), pos: poly(3, 60, 50, 34) },
                    { title: '環氧乙烷', atoms: 'OCC', bonds: ringBonds('---'), pos: poly(3, 60, 50, 34) },
                    { title: '氮丙啶', atoms: 'NCC', bonds: ringBonds('---'), pos: poly(3, 60, 50, 34) },
                    { title: '環丙酮', atoms: 'CCCO', bonds: [...ringBonds('---'), [0, 3, '=']], pos: [[60, 42], [34, 80], [86, 80], [60, 10]] },
                    { title: '環丙烯', atoms: 'CCC', bonds: ringBonds('=--'), pos: poly(3, 60, 50, 34) }
                ]
            },
            {
                label: '五元環', sup: 2, graphs: [
                    { title: '環戊烷', atoms: 'CCCCC', bonds: ringBonds('-----'), pos: poly(5, 60, 48, 32) },
                    { title: '環戊酮', atoms: 'CCCCCO', bonds: [...ringBonds('-----'), [0, 5, '=']], pos: [...poly(5, 60, 60, 27), [60, 7]] },
                    { title: '環戊烯', atoms: 'CCCCC', bonds: ringBonds('=----'), pos: poly(5, 60, 48, 32) },
                    { title: '四氫呋喃', atoms: 'OCCCC', bonds: ringBonds('-----'), pos: poly(5, 60, 48, 32) },
                    { title: '吡咯烷', atoms: 'NCCCC', bonds: ringBonds('-----'), pos: poly(5, 60, 48, 32) }
                ]
            }
        ];

        const $ = id => document.getElementById(id);
        const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);   // 跟 Java compareTo、Python 字串比較一樣：照字碼
        const toGraph = g => ({ title: g.title, atoms: [...g.atoms], bonds: g.bonds.map(b => b.slice()), pos: g.pos.map(p => p.slice()) });
        let preset = 0;
        let graphs = PRESETS[0].graphs.map(toGraph);
        let minSup = PRESETS[0].sup;
        let lang = 'java';
        let trace = [];
        let cursor = 0;
        let timer = null;
        let picked = null;        // 延伸表上點選的那一列（index）
        let embPick = {};         // 每張圖目前顯示第幾種嵌入

        const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        const tuple = e => '(' + e.join(', ') + ')';
        const tu = e => `<span class="tu">${esc(tuple(e))}</span>`;
        const ekey = e => e.join(',');
        const ckey = code => code.map(ekey).join(' ');
        const isBack = e => e[0] > e[1];

        /* ---------- gSpan 的幾個小工具（跟 Java / Python 版一樣） ---------- */
        /* 同一個樣式往外長的邊怎麼排：後退邊先（連回越前面的點越小），再來前進邊（從越深的點長越小），最後比標籤 */
        function dfsCmp(x, y) {
            const bx = isBack(x), by = isBack(y);
            if (bx !== by) return bx ? -1 : 1;
            let c = bx ? x[1] - y[1] : y[0] - x[0];
            for (let k = 2; !c && k < 5; k++) c = cmp(x[k], y[k]);
            return c;
        }
        function neighbors(n, bonds) {
            const adj = Array.from({ length: n }, () => []);
            bonds.forEach(([u, v, b]) => { adj[u].push([v, b]); adj[v].push([u, b]); });
            return adj;
        }
        function bondOf(adj, u, v) {
            for (const [w, b] of adj[u]) if (w === v) return b;
            return null;
        }
        const hasEdge = (code, u, v) => code.some(([i, j]) => (i === u && j === v) || (i === v && j === u));
        function rightmostPath(code) {
            const from = {};
            let r = 0;
            code.forEach(([i, j]) => { if (i < j) { from[j] = i; r = Math.max(r, j); } });
            const path = [r];
            while (path[path.length - 1] !== 0) path.push(from[path[path.length - 1]]);
            return path.reverse();
        }
        const support = embs => new Set(embs.map(x => x.gid)).size;

        /* 把 code 畫成一張小圖，從頭重寫一次 DFS code，每一步都挑順序最小的邊 → 最小 DFS code */
        function minCode(code) {
            const atoms = {}, adj = {};
            code.forEach(([i, j, a, b, c]) => {
                atoms[i] = a; atoms[j] = c;
                (adj[i] = adj[i] || []).push([j, b]);
                (adj[j] = adj[j] || []).push([i, b]);
            });
            const vs = Object.keys(adj).map(Number);
            let best = null;
            vs.forEach(u => adj[u].forEach(([v, b]) => { const e = [0, 1, atoms[u], b, atoms[v]]; if (!best || dfsCmp(e, best) < 0) best = e; }));
            const mc = [best];
            let embs = [];
            vs.forEach(u => adj[u].forEach(([v, b]) => { if (ekey([0, 1, atoms[u], b, atoms[v]]) === ekey(best)) embs.push([u, v]); }));
            while (mc.length < code.length) {
                const rm = rightmostPath(mc), r = rm[rm.length - 1];
                const cands = [];
                for (const m of embs) {
                    for (const v of rm.slice(0, -1)) {
                        const b = bondOf(adj, m[r], m[v]);
                        if (b && !hasEdge(mc, r, v)) cands.push([[r, v, atoms[m[r]], b, atoms[m[v]]], m]);
                    }
                    for (let t = rm.length - 1; t >= 0; t--) {
                        const v = rm[t];
                        for (const [w, b] of adj[m[v]]) if (!m.includes(w)) cands.push([[v, m.length, atoms[m[v]], b, atoms[w]], [...m, w]]);
                    }
                }
                let e = cands[0][0];
                cands.forEach(([c]) => { if (dfsCmp(c, e) < 0) e = c; });
                mc.push(e);
                embs = cands.filter(([c]) => ekey(c) === ekey(e)).map(([, m]) => m);
            }
            return mc;
        }

        /* ---------- 照著程式跑一次，記下每一步 ---------- */
        function buildTrace(gIn, minSup) {
            const gs = gIn.map(g => ({ atoms: [...g.atoms], bonds: g.bonds.map(b => b.slice()) }));
            const adj = gs.map(g => neighbors(g.atoms.length, g.bonds));
            const steps = [], result = [];
            const stats = { cands: 0, pruned: 0 };
            const push = o => steps.push({ result: result.map(r => ({ ...r })), stats: { ...stats }, ...o });
            const makeRows = (map, baseCode) => [...map.values()].sort((x, y) => dfsCmp(x.e, y.e)).map(x => {
                const sup = support(x.embs);
                return { e: x.e, code: [...baseCode, x.e], embs: x.embs, sup, gids: [...new Set(x.embs.map(q => q.gid))], res: sup >= minSup ? 'wait' : 'low' };
            });
            const add = (map, e, emb) => { const k = ekey(e); if (!map.has(k)) map.set(k, { e, embs: [] }); map.get(k).embs.push(emb); };

            push({ kind: 'start', depth: 0 });
            // 1. 第一條邊
            const first = new Map();
            gs.forEach((g, gid) => g.atoms.forEach((a, u) => adj[gid][u].forEach(([v, b]) => {
                if (cmp(a, g.atoms[v]) <= 0) add(first, [0, 1, a, b, g.atoms[v]], { gid, m: [u, v] });
            })));
            const t0 = { root: true, rows: makeRows(first, []) };
            stats.cands += t0.rows.length;
            push({ kind: 'first', table: t0, cur: -1, depth: 0 });
            t0.rows.forEach((row, k) => {
                if (row.res === 'low') return;
                row.res = 'ok';                       // 只有一條邊時，兩端照字母排好就是最小的寫法
                mine(row.code, row.embs, t0, k, 1);
            });
            push({ kind: 'end', depth: 0 });
            steps.forEach((s, i) => {
                s.graphs = gs;
                s.minSup = minSup;
                s.back = i > 0 && (s.kind === 'grow' || s.kind === 'notmin') && steps[i - 1].table !== s.table;
            });
            return steps;

            function mine(code, embs, table, k, depth) {
                const sup = support(embs);
                result.push({ code, sup, gid: embs[0].gid, m: embs[0].m, fresh: true });
                const no = result.length;
                push({ kind: 'grow', code, embs, sup, table, cur: k, depth, no });
                result.forEach(r => { r.fresh = false; });
                // 2. 最右延伸
                const rm = rightmostPath(code), r = rm[rm.length - 1];
                const ext = new Map();
                for (const { gid, m } of embs) {
                    const atoms = gs[gid].atoms;
                    for (const v of rm.slice(0, -1)) {
                        const b = bondOf(adj[gid], m[r], m[v]);
                        if (b && !hasEdge(code, r, v)) add(ext, [r, v, atoms[m[r]], b, atoms[m[v]]], { gid, m });
                    }
                    for (let t = rm.length - 1; t >= 0; t--) {
                        const v = rm[t];
                        for (const [w, b] of adj[gid][m[v]]) if (!m.includes(w)) add(ext, [v, m.length, atoms[m[v]], b, atoms[w]], { gid, m: [...m, w] });
                    }
                }
                const tb = { root: false, code, rm, no, rows: makeRows(ext, code) };
                stats.cands += tb.rows.length;
                push({ kind: 'cands', code, embs, rm, table: tb, cur: -1, depth, no });
                // 3. 照順序一個一個試
                tb.rows.forEach((row, j) => {
                    if (row.res === 'low') return;
                    const mc = minCode(row.code);
                    if (ckey(mc) !== ckey(row.code)) {
                        row.res = 'notmin';
                        stats.pruned++;
                        const diff = mc.findIndex((x, t) => ekey(x) !== ekey(row.code[t]));
                        const found = result.findIndex(q => ckey(q.code) === ckey(mc));
                        push({ kind: 'notmin', code: row.code, embs: row.embs, sup: row.sup, min: mc, diff, found, table: tb, cur: j, depth, no });
                    } else {
                        row.res = 'ok';
                        mine(row.code, row.embs, tb, j, depth + 1);
                    }
                });
            }
        }

        /* 暴力法要做的事：每張圖所有連通的子圖（一組邊）都列出來 */
        function bruteCount(gs) {
            let total = 0;
            gs.forEach(g => {
                const m = g.bonds.length;
                for (let mask = 1; mask < (1 << m); mask++) {
                    const es = g.bonds.filter((_, k) => mask >> k & 1);
                    const seen = new Set([es[0][0]]);
                    let grew = true;
                    while (grew) {
                        grew = false;
                        es.forEach(([u, v]) => {
                            if (seen.has(u) !== seen.has(v)) { seen.add(u); seen.add(v); grew = true; }
                        });
                    }
                    if (es.every(([u]) => seen.has(u))) total++;
                }
            });
            return total;
        }
        let bruteCache = null;

        /* ---------- 說明文字 ---------- */
        const kindText = (e, root) => root ? '第一條邊' : isBack(e) ? `後退 ${e[0]}→${e[1]}` : `前進 ${e[0]}→新 ${e[1]}`;
        const patName = no => `<span class="pt">#${no}</span>`;

        function whySmaller(mrow, crow, k) {
            if (k === 0) {
                if (mrow[2] !== crow[2]) return `第一條邊先比 0 號點的原子：${mrow[2]} 排在 ${crow[2]} 前面`;
                if (mrow[3] !== crow[3]) return '第一條邊的兩端一樣，比鍵：單鍵 - 排在雙鍵 = 前面';
                return `第一條邊另一端的原子：${mrow[4]} 排在 ${crow[4]} 前面`;
            }
            const mb = isBack(mrow), cb = isBack(crow);
            if (mb && !cb) return '後退邊（把環接起來）排在前進邊前面';
            if (mb && cb && mrow[1] !== crow[1]) return `都是後退邊，連回比較前面的 ${mrow[1]} 號點比較小`;
            if (!mb && !cb && mrow[0] !== crow[0]) return `都是前進邊，從比較深的 ${mrow[0]} 號點長出去比較小`;
            if (mrow[3] !== crow[3]) return '位置一樣就比鍵：單鍵 - 排在雙鍵 = 前面';
            return `位置一樣就比新的原子：${mrow[4]} 排在 ${crow[4]} 前面`;
        }

        function describe(s) {
            const n = s.graphs.length;
            switch (s.kind) {
                case 'start':
                    return `資料庫有 ${n} 張圖，每張是一個分子的骨架（省略氫）：點是原子，邊是化學鍵。` +
                        `一個子圖的<b>支持度</b>＝有幾張圖裡找得到它（同一張圖裡出現好幾處也只算 1 張）。` +
                        `目標：找出至少 <b>${s.minSup}</b> 張圖都有的所有連通子圖（至少一條邊）。`;
                case 'first': {
                    const ok = s.table.rows.filter(r => r.res !== 'low');
                    return `跟 Apriori 先數單一商品一樣，先數每一種「原子-鍵-原子」的邊出現在幾張圖。` +
                        `一條邊寫成 DFS code 的第一列 (0, 1, 原子, 鍵, 原子)：兩端照字母排，小的當 0 號點。` +
                        (ok.length ? `至少 ${s.minSup} 張的有 ${ok.map(r => tu(r.e)).join(' ')}，照延伸表的順序一個一個當起點往下長。`
                            : `沒有任何一種邊達到 ${s.minSup} 張圖，什麼都找不到。`);
                }
                case 'grow': {
                    let txt = s.back ? `回到 ${s.table.root ? '第一條邊的表' : '樣式 ' + patName(s.table.no)}，換下一個。` : '';
                    if (s.code.length === 1) {
                        txt += `從 ${tu(s.code[0])} 開始：它出現在 ${s.sup} 張圖，記成樣式 ${patName(s.no)}。` +
                            `圖上亮起來的就是它在每張圖裡的位置（<b>嵌入</b>），點旁邊的小數字是它在 DFS code 裡的編號。`;
                    } else {
                        const e = s.code[s.code.length - 1];
                        txt += `在樣式 ${patName(s.table.no)} 後面接上 ${tu(e)}（${isBack(e) ? '後退邊：接成一個環' : '前進邊：多一個 ' + esc(e[4]) + ' 原子'}），` +
                            `出現在 ${s.sup} 張圖。把它從頭重寫一次，最小的寫法就是它自己，代表這是<b>第一次</b>遇到這個子圖，記成樣式 ${patName(s.no)}，再從它往下長。`;
                    }
                    return txt;
                }
                case 'cands': {
                    const ok = s.table.rows.filter(r => r.res !== 'low');
                    const r = s.rm[s.rm.length - 1];
                    let txt = `樣式 ${patName(s.no)} 的<b>最右路徑</b>是 ${s.rm.join(' → ')}（紫色），${r} 號是最後長出來的<b>最右頂點</b>。gSpan 只從這條路徑往外長：` +
                        `<b>後退邊</b>從 ${r} 號連回路徑上的點（多一個環），<b>前進邊</b>從路徑上的點接一個新的原子。`;
                    if (!s.table.rows.length) return txt + `可是每張圖裡都沒有邊可以接了，這個樣式長不下去，回到上一層。`;
                    txt += ok.length ? `能接的 ${s.table.rows.length} 種邊裡，出現在至少 ${s.minSup} 張圖的有 ${ok.length} 種，接下來照表的順序一個一個檢查。`
                        : `能接的邊都不到 ${s.minSup} 張圖，這個樣式長不下去，回到上一層。`;
                    return txt;
                }
                case 'notmin': {
                    const k = s.diff, mrow = s.min[k], crow = s.code[k];
                    return (s.back ? `回到樣式 ${patName(s.no)}，換下一個。` : '') +
                        `接上 ${tu(s.code[s.code.length - 1])} 也出現在 ${s.sup} 張圖，但同一個子圖可以從別的點開始寫。從頭重寫、每一步都挑最小的邊，` +
                        `得到的<b>最小 DFS code</b> 在第 ${k + 1} 列是 ${tu(mrow)}，比這個寫法的 ${tu(crow)} 小（${esc(whySmaller(mrow, crow, k))}）。` +
                        `所以這個子圖早就用最小的寫法找過了（樣式 ${patName(s.found + 1)}），這條<b>剪掉</b>，後面也不用再長。`;
                }
                case 'end':
                    return `完成！共找到 <b>${s.result.length}</b> 個頻繁子圖。延伸表裡一共列了 ${s.stats.cands} 條邊，` +
                        `其中 ${s.stats.pruned} 條夠頻繁、但只是同一個子圖的另一種寫法，被最小 DFS code 檢查剪掉；每個子圖都只記一次。`;
            }
            return '';
        }

        const CODE_TAGS = s => ({
            start: ['start'],
            first: ['first'],
            grow: ['record'].concat(s.code && s.code.length > 1 ? ['recurse'] : ['first']),
            cands: ['ext', 'back', 'fwd'],
            notmin: ['prune', 'min'],
            end: ['end']
        })[s.kind] || [];

        /* ---------- 畫圖 ---------- */
        /* g：{atoms, bonds, pos}；opt.m：樣式第 k 點 → 圖上的點；opt.code：要亮起來的樣式；opt.rm：最右路徑；opt.add：最後接上的邊要用橘色 */
        function svgGraph(g, opt = {}) {
            // 量區塊高度時只要外框：每張圖都是同一個 viewBox、寬度由 CSS 決定，高度跟裡面畫什麼無關
            if (measuringBlocks) return '<svg viewBox="-6 -6 132 102"></svg>';
            const m = opt.m || null, code = opt.code || [], rm = opt.rm || [];
            const at = new Map();
            if (m) m.forEach((v, k) => at.set(v, k));
            const rmEdge = new Set();
            for (let t = 1; t < rm.length; t++) rmEdge.add(rm[t - 1] + '-' + rm[t]);
            const edgeRole = (u, v) => {
                if (!m) return 'plain';
                for (let t = 0; t < code.length; t++) {
                    const [i, j] = code[t];
                    if ((m[i] === u && m[j] === v) || (m[i] === v && m[j] === u)) {
                        if (opt.add && t === code.length - 1) return 'add';
                        if (rmEdge.has(Math.min(i, j) + '-' + Math.max(i, j))) return 'rm';
                        return 'emb';
                    }
                }
                return 'dim';
            };
            let out = `<svg viewBox="-6 -6 132 102" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="${esc(opt.label || '分子圖')}">`;
            g.bonds.forEach(([u, v, b]) => {
                const role = edgeRole(u, v);
                const [x1, y1] = g.pos[u], [x2, y2] = g.pos[v];
                const w = role === 'plain' || role === 'dim' ? 2 : 3;
                const col = COL[role];
                if (b === '=') {
                    const len = Math.hypot(x2 - x1, y2 - y1) || 1, ox = -(y2 - y1) / len * 2.8, oy = (x2 - x1) / len * 2.8;
                    out += `<line x1="${x1 + ox}" y1="${y1 + oy}" x2="${x2 + ox}" y2="${y2 + oy}" stroke="${col}" stroke-width="${w - 0.6}"/>`;
                    out += `<line x1="${x1 - ox}" y1="${y1 - oy}" x2="${x2 - ox}" y2="${y2 - oy}" stroke="${col}" stroke-width="${w - 0.6}"/>`;
                } else {
                    out += `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${col}" stroke-width="${w}"/>`;
                }
            });
            g.atoms.forEach((a, v) => {
                const [x, y] = g.pos[v], st = ATOM[a] || ATOM.C;
                const k = at.has(v) ? at.get(v) : -1;
                const fade = m && k < 0 ? ' opacity="0.35"' : '';
                if (k >= 0) out += `<circle cx="${x}" cy="${y}" r="12.5" fill="none" stroke="${rm.includes(k) ? COL.rm : COL.emb}" stroke-width="${k === rm[rm.length - 1] ? 3 : 2}"/>`;
                out += `<g${fade}><circle cx="${x}" cy="${y}" r="9.5" fill="${st.fill}" stroke="${st.stroke}" stroke-width="1.5"/>` +
                    `<text class="at" x="${x}" y="${y + 0.5}" fill="${st.text}">${esc(a)}</text></g>`;
                if (k >= 0 && opt.badges !== false) {
                    out += `<circle cx="${x + 12}" cy="${y - 11}" r="6.2" fill="#05050a" stroke="${COL.emb}" stroke-width="1"/>` +
                        `<text class="bd" x="${x + 12}" y="${y - 10.5}" fill="#a5f3fc">${k}</text>`;
                }
            });
            return out + '</svg>';
        }

        /* 把樣式本身畫出來：點的位置借用它在某張圖裡的嵌入，再移到中間 */
        function patternGraph(code, g, m) {
            const n = Math.max(...code.map(e => Math.max(e[0], e[1]))) + 1;
            const atoms = [], pos = [];
            code.forEach(([i, j, a, , c]) => { atoms[i] = a; atoms[j] = c; });
            for (let k = 0; k < n; k++) pos.push(g.pos[m[k]].slice());
            const xs = pos.map(p => p[0]), ys = pos.map(p => p[1]);
            const dx = 60 - (Math.min(...xs) + Math.max(...xs)) / 2, dy = 46 - (Math.min(...ys) + Math.max(...ys)) / 2;
            return { atoms, bonds: code.map(([i, j, , b]) => [i, j, b]), pos: pos.map(([x, y]) => [x + dx, y + dy]) };
        }

        /* ---------- 圖形資料庫 ---------- */
        function viewOf(s) {
            // 這一步圖上要亮哪個樣式
            if (picked !== null && s.table && s.table.rows[picked]) {
                const row = s.table.rows[picked];
                return { code: row.code, embs: row.embs, add: true, rm: [] };
            }
            if (s.kind === 'grow') return { code: s.code, embs: s.embs, add: s.code.length > 1, rm: [] };
            if (s.kind === 'cands') return { code: s.code, embs: s.embs, add: false, rm: s.rm };
            if (s.kind === 'notmin') return { code: s.code, embs: s.embs, add: true, rm: [] };
            return null;
        }

        function drawGraphs(s) {
            const box = $('graphs');
            box.innerHTML = '';
            const view = viewOf(s);
            graphs.forEach((g, gid) => {
                const mine = view ? view.embs.filter(x => x.gid === gid) : [];
                const pick = mine.length ? (embPick[gid] || 0) % mine.length : 0;
                const div = document.createElement('div');
                div.className = 'gbox' + (view && !mine.length ? ' miss' : '') + (picked !== null && mine.length ? ' pick' : '');
                div.dataset.gid = gid;
                const head = document.createElement('div');
                head.className = 'gt';
                const t = document.createElement('b');
                t.textContent = `G${gid + 1} ${g.title}`;
                const ge = document.createElement('span');
                ge.className = 'ge' + (mine.length > 1 ? ' on' : '');
                ge.textContent = mine.length > 1 ? `嵌入 ${pick + 1}/${mine.length}` : '嵌入 1/1';
                head.append(t, ge);
                div.appendChild(head);
                const holder = document.createElement('div');
                holder.innerHTML = svgGraph(g, mine.length ? { m: mine[pick].m, code: view.code, rm: view.rm, add: view.add, label: g.title } : { m: view ? [] : null, label: g.title });
                div.appendChild(holder);
                box.appendChild(div);
            });
        }
        $('graphs').addEventListener('click', ev => {
            const div = ev.target.closest('.gbox');
            if (!div) return;
            const gid = Number(div.dataset.gid);
            embPick[gid] = (embPick[gid] || 0) + 1;
            drawGraphs(trace[cursor]);
        });

        function drawPresets() {
            const box = $('presets');
            box.innerHTML = '';
            PRESETS.forEach((p, i) => {
                const b = document.createElement('button');
                b.className = 'btn small' + (i === preset ? ' cur' : '');
                b.textContent = p.label;
                b.addEventListener('click', () => {
                    preset = i;
                    graphs = p.graphs.map(toGraph);
                    minSup = p.sup;
                    rebuild();
                });
                box.appendChild(b);
            });
            const r = document.createElement('button');
            r.className = 'btn small' + (preset === -1 ? ' cur' : '');
            r.textContent = '🎲 隨機';
            r.addEventListener('click', () => {
                preset = -1;
                graphs = randomGraphs();
                minSup = Math.min(Math.max(minSup, 2), graphs.length);
                rebuild();
            });
            box.appendChild(r);
        }

        /* 隨機產生 4～5 張小圖（不一定是真的分子）：先連成一棵樹，再隨機多加 0～2 條邊 */
        function randomGraphs() {
            const rnd = k => Math.floor(Math.random() * k);
            const count = 4 + rnd(2);
            return Array.from({ length: count }, (_, gi) => {
                const n = 3 + rnd(4);
                const atoms = Array.from({ length: n }, () => 'CCCCOON'[rnd(7)]);
                const es = new Set();
                for (let v = 1; v < n; v++) es.add(rnd(v) + ',' + v);
                const extra = rnd(3);
                for (let t = 0; t < extra; t++) {
                    const u = rnd(n), v = rnd(n);
                    if (u !== v) es.add(Math.min(u, v) + ',' + Math.max(u, v));
                }
                const bonds = [...es].map(s => s.split(',').map(Number)).sort((a, b) => a[0] - b[0] || a[1] - b[1]).map(([u, v]) => [u, v, Math.random() < 0.25 ? '=' : '-']);
                return { title: '隨機 ' + (gi + 1), atoms, bonds, pos: poly(n, 60, 46, n <= 3 ? 30 : 36) };
            });
        }

        /* ---------- 目前的樣式 ---------- */
        function drawPattern(s) {
            const holder = $('pat-svg'), t = $('code-t'), line = $('rm-line'), hint = $('pat-hint');
            const code = s.kind === 'grow' || s.kind === 'cands' || s.kind === 'notmin' ? s.code : null;
            if (!code) {
                $('pat-title').textContent = '目前的樣式與 DFS code';
                holder.innerHTML = '';
                t.innerHTML = '';
                line.textContent = '';
                hint.textContent = s.kind === 'end' ? '全部長完了，結果在下面。' : '還沒有樣式。DFS code 的每一列是一條邊 (i, j, 原子i, 鍵, 原子j)：i、j 是點被走到的順序編號。';
                return;
            }
            const e0 = s.embs[0];
            const pg = patternGraph(code, graphs[e0.gid], e0.m);
            const rm = s.kind === 'cands' ? s.rm : [];
            holder.innerHTML = svgGraph(pg, { m: pg.atoms.map((_, k) => k), code, rm, add: s.kind !== 'cands' && code.length > 1, label: '目前的樣式' });
            if (s.kind === 'notmin') {
                $('pat-title').textContent = '同一個子圖，兩種寫法';
                line.innerHTML = '左邊是照這條路長出來的寫法，右邊是從頭重寫的<b>最小 DFS code</b>';
                t.innerHTML = '<thead><tr><th>列</th><th>這個寫法</th><th>最小 DFS code</th></tr></thead><tbody>' +
                    code.map((e, k) => `<tr class="${k === s.diff ? 'add' : k > s.diff ? 'after' : ''}"><td>${k + 1}</td>` +
                        `<td class="mono${k === s.diff ? ' bad' : ''}">${esc(tuple(e))}</td><td class="mono${k === s.diff ? ' good' : ''}">${esc(tuple(s.min[k]))}</td></tr>`).join('') + '</tbody>';
                hint.innerHTML = `第一個不一樣的是第 ${s.diff + 1} 列：${esc(whySmaller(s.min[s.diff], code[s.diff], s.diff))}。後面的列就不用比了。`;
                return;
            }
            $('pat-title').textContent = `目前的樣式 #${s.no} 與 DFS code`;
            const rmSet = new Set();
            for (let k = 1; k < rm.length; k++) rmSet.add(rm[k - 1] + '-' + rm[k]);
            line.innerHTML = s.kind === 'cands' ? `最右路徑：<b>${rm.join(' → ')}</b>，最右頂點是 <b>${rm[rm.length - 1]}</b> 號` : `${code.length} 條邊、${pg.atoms.length} 個點`;
            t.innerHTML = '<thead><tr><th>列</th><th>i</th><th>j</th><th>l<sub>i</sub></th><th>l<sub>(i,j)</sub></th><th>l<sub>j</sub></th><th>種類</th></tr></thead><tbody>' +
                code.map((e, k) => {
                    const cls = s.kind === 'grow' && code.length > 1 && k === code.length - 1 ? 'add' : rmSet.has(e[0] + '-' + e[1]) ? 'rmrow' : '';
                    return `<tr class="${cls}"><td>${k + 1}</td>${e.map(x => `<td class="mono">${esc(x)}</td>`).join('')}<td class="kind">${isBack(e) ? '後退' : '前進'}</td></tr>`;
                }).join('') + '</tbody>';
            hint.innerHTML = s.kind === 'cands'
                ? '紫色＝最右路徑上的邊。前進邊 i &lt; j（走到一個新的點），後退邊 i &gt; j（連回已經走過的點）。'
                : `出現在 ${s.sup} 張圖：${esc([...new Set(s.embs.map(x => x.gid))].map(gid => 'G' + (gid + 1)).join('、'))}`;
        }

        /* ---------- 延伸表 ---------- */
        const RES = { low: '不夠', wait: '待檢查', ok: '✓ 長下去', notmin: '✕ 不是最小' };
        function drawCands(s) {
            const t = $('cand-t'), line = $('cand-line'), hint = $('cand-hint');
            if (!s.table) {
                t.innerHTML = '';
                line.textContent = s.kind === 'end' ? '全部試完了。' : '還沒開始數。按「下一步」。';
                hint.textContent = '';
                return;
            }
            const tb = s.table;
            line.innerHTML = tb.root ? '第一條邊：每一種「原子-鍵-原子」' : `從樣式 <span class="pt">#${tb.no}</span> 的最右路徑 ${tb.rm.join(' → ')} 能接的邊`;
            if (!tb.rows.length) {
                t.innerHTML = '';
                hint.textContent = '沒有任何邊可以接了。';
                return;
            }
            t.innerHTML = '<thead><tr><th>接上的邊</th><th>種類</th><th>幾張圖</th><th>結果</th></tr></thead><tbody>' +
                tb.rows.map((row, k) => {
                    const res = row.res === 'low' ? 'low' : k < s.cur || k === s.cur ? row.res : 'wait';
                    const cls = [k === s.cur ? 'cur' : '', picked === k ? 'picked' : ''].join(' ');
                    const label = res === 'ok' && tb.root ? '✓ 當起點' : RES[res];
                    return `<tr class="${cls}" data-k="${k}"><td class="mono">${esc(tuple(row.e))}</td><td class="kind">${kindText(row.e, tb.root)}</td>` +
                        `<td class="sup${row.sup < s.minSup ? ' low' : ''}">${row.sup}</td><td class="res ${res}">${label}</td></tr>`;
                }).join('') + '</tbody>';
            if (picked !== null && tb.rows[picked]) {
                const row = tb.rows[picked];
                hint.textContent = `${tuple(row.e)}：出現在 ${row.gids.map(g => 'G' + (g + 1)).join('、')}（圖上亮起來的那幾張）。再點一次取消。`;
            } else {
                hint.textContent = `照表的順序（DFS code 的大小順序）往下試：先後退邊、再前進邊。不到 ${s.minSup} 張圖的直接跳過。點一列看它出現在哪幾張圖。`;
            }
        }
        $('cand-t').addEventListener('click', ev => {
            const tr = ev.target.closest('tr[data-k]');
            if (!tr) return;
            const k = Number(tr.dataset.k);
            picked = picked === k ? null : k;
            embPick = {};
            const s = trace[cursor];
            drawCands(s);
            drawGraphs(s);
        });

        /* ---------- 結果 ---------- */
        /* 結果清單：一步一步往後走時，清單只會在後面多幾個，所以只補新的、改「剛找到」的外框，
           不用每一步整排重畫（小圖多時重畫很慢，量區塊高度時也要畫每一步）。往回走或換資料才整排重畫。
           量高度時小圖只畫外框（大小一樣），畫回來時一定整排重畫。 */
        let resultDrawn = null;
        function drawResult(s) {
            const box = $('levels');
            const keys = s.result.map(r => [ckey(r.code), r.sup, r.gid, r.m.join(',')].join('|'));
            const d = resultDrawn;
            const grow = d && d.graphs === s.graphs && d.m === measuringBlocks && d.els.length && d.els.length <= keys.length &&
                box.isConnected && d.keys.every((k, i) => k === keys[i]);
            if (!grow) {
                box.innerHTML = '';
                if (!s.result.length) box.innerHTML = '<div class="empty">還沒有，開始長之後會出現在這裡。</div>';
                resultDrawn = { graphs: s.graphs, m: measuringBlocks, keys: [], els: [], rows: {} };
                if (bruteCache === null) bruteCache = bruteCount(s.graphs);
                $('compare').innerHTML = `同一份資料如果用暴力法，要把每張圖所有連通的子圖都列出來（共 <b>${bruteCache}</b> 個），再兩兩判斷是不是<b>同構</b>（形狀和標籤都一樣）才能合併計數；` +
                    `gSpan 把「是不是同一個子圖」換成「最小 DFS code 一不一樣」，而且只往最右路徑長，大部分重複的寫法根本不會產生。`;
            }
            const st = resultDrawn;
            for (let i = st.els.length; i < s.result.length; i++) {
                const r = s.result[i], k = r.code.length;
                let row = st.rows[k];
                if (!row) {
                    row = document.createElement('div');
                    row.className = 'level';
                    row.dataset.n = k;
                    row.innerHTML = `<span class="tag">${k} 條邊</span><div class="found"></div>`;
                    const after = [...box.children].find(x => Number(x.dataset.n) > k);
                    box.insertBefore(row, after || null);
                    st.rows[k] = row;
                }
                const p = document.createElement('span');
                p.className = 'fp';
                p.title = r.code.map(tuple).join(' ');
                const pg = patternGraph(r.code, graphs[r.gid], r.m);
                p.innerHTML = svgGraph(pg, { label: '樣式 #' + (i + 1) }) + `<span class="lbl"><span class="no">#${i + 1}</span><span class="n">${r.sup} 張</span></span>`;
                row.lastChild.appendChild(p);
                st.els.push(p);
                st.keys.push(keys[i]);
            }
            s.result.forEach((r, i) => st.els[i].classList.toggle('fresh', !!r.fresh));
            drawStats(s);
        }
        function drawStats(s) {
            $('st-found').textContent = s.result.length;
            $('st-cands').textContent = s.stats.cands;
            $('st-pruned').textContent = s.stats.pruned;
        }

        /* ---------- 程式碼 ---------- */
        const KW = {
            java: new Set('public static final for if return new boolean int void class import while else null this continue break record var'.split(' ')),
            py: new Set('def for in if return not and or while import from as True False None class is lambda continue break'.split(' '))
        };
        function highlight(line) {
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
            if (measuringBlocks || restoringBlocks) return;   // 量區塊高度時不用畫程式碼（程式碼框高度不會變），量完畫回來時它也沒被動過，省時間
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
                let [y0, y1] = span(hls[0], hls[hls.length - 1]);
                if (y1 - y0 > pre.clientHeight - 16) {
                    const big = groups.reduce((x, y) => (y.length > x.length ? y : x));
                    [y0, y1] = span(big[0], big[big.length - 1]);
                    if (y1 - y0 > pre.clientHeight - 16) y1 = y0 + pre.clientHeight - 16;
                }
                const target = (y0 + y1) / 2 - pre.clientHeight / 2;
                pre.scrollTo({ top: Math.max(0, Math.min(target, y0 - 8)), behavior: 'smooth' });
            }
            $('downloads').innerHTML = lang === 'java'
                ? '下載 <a href="code/GSpan.java" download>GSpan.java</a>　執行 <code>javac GSpan.java && java GSpan</code>'
                : '下載 <a href="code/gspan.py" download>gspan.py</a>　執行 <code>python3 gspan.py</code>';
        }

        /* ---------- 顯示某一步 ---------- */
        function showStep() {
            const s = trace[cursor];
            picked = null;
            embPick = {};
            $('explain').innerHTML = `<span class="step-no">步驟 ${cursor + 1} / ${trace.length}</span>${describe(s)}`;
            drawPresets();
            drawGraphs(s);
            drawPattern(s);
            drawCands(s);
            drawResult(s);
            renderCode(CODE_TAGS(s));
            $('btn-prev').disabled = $('btn-first').disabled = cursor === 0;
            $('btn-next').disabled = cursor === trace.length - 1;
            $('sup-val').textContent = minSup;
            $('sup-minus').disabled = minSup <= 1;
            $('sup-plus').disabled = minSup >= graphs.length;
        }

        /* 一步一步播放時，各區塊的內容會變多變少（樹長大、清單變長…）。
           先把每一步都畫一次，用最高的那一次把每個區塊的高度固定住，
           區塊變長變短才不會把旁邊或下面的東西推來推去。
           步驟多時要量一陣子，所以分段量：每段量完立刻畫回目前這一步，畫面不會閃，也不會卡住；
           量完之前按的上一步／下一步會先排隊，量完才做，所以一開頁馬上按也不會跳。 */
        let measuringBlocks = false, restoringBlocks = false, blockJob = 0, blocksBusy = false, blockQueue = [], blockPort = null, blockLast = null;
        function reserveBlockHeights(scope, count, showAt, current) {
            const job = ++blockJob;
            blockLast = [scope, count, showAt, current];
            const blocks = [...scope.querySelectorAll('.card')].filter(b => !b.closest('[hidden]'));
            const finish = () => {   // 量完了：把量的時候先按下去的上一步／下一步照順序補做
                blocksBusy = false;
                document.documentElement.removeAttribute('aria-busy');
                const q = blockQueue;
                blockQueue = [];
                q.forEach(f => f());
            };
            if (!blocks.length || count < 2) { finish(); return; }
            blocksBusy = true;
            document.documentElement.setAttribute('aria-busy', 'true');
            const passes = scope.querySelector('.card .card') ? 2 : 1;   // 區塊裡還有區塊時，第二輪把外層補足
            let base = blocks.map(() => ''), tallest = blocks.map(() => 0), i = 0, pass = 0, cost = 0, back = 0;
            const chunk = () => {
                if (job !== blockJob) return;   // 資料或參數又變了，這一輪作廢
                const t0 = performance.now();
                const cur = current(), shown = blocks.map(b => b.style.minHeight);
                try {
                    measuringBlocks = true;
                    blocks.forEach((b, k) => { b.style.minHeight = base[k]; });
                    // 每段約 45ms 內（含最後畫回目前這一步）能量幾步就量幾步：照前面每一步花的時間估，來不及就先停
                    do {
                        const s = performance.now();
                        showAt(i);
                        blocks.forEach((b, k) => { tallest[k] = Math.max(tallest[k], Math.ceil(b.getBoundingClientRect().height)); });
                        const dt = performance.now() - s;
                        cost = cost ? cost * 0.7 + dt * 0.3 : dt;   // 最近幾步的平均
                        if (++i === count) {
                            i = 0; pass++;
                            base = tallest.map(h => h + 'px');
                            blocks.forEach((b, k) => { b.style.minHeight = base[k]; });
                        }
                    } while (pass < passes && performance.now() - t0 + cost + back < 45);
                } finally {
                    measuringBlocks = false;
                }
                blocks.forEach((b, k) => { b.style.minHeight = pass < passes ? shown[k] : base[k]; });
                // 畫回目前這一步；量的時候沒動過的部分（程式碼框）不用重畫
                const s = performance.now();
                restoringBlocks = true;
                try { showAt(cur); } finally { restoringBlocks = false; }
                const dt = performance.now() - s;
                back = back ? back * 0.7 + dt * 0.3 : dt;
                if (pass < passes) blockTick(chunk); else finish();
            };
            chunk();
        }
        // 下一段用 MessageChannel 排：比 setTimeout(0) 快（沒有 4ms 的最短間隔），點擊和按鍵一樣插得進來
        function blockTick(f) {
            if (!blockPort) {
                const ch = new MessageChannel(), fns = [];
                ch.port1.onmessage = () => fns.shift()();
                blockPort = g => { fns.push(g); ch.port2.postMessage(0); };
            }
            blockPort(f);
        }
        // 還在量的時候按上一步／下一步／播放（或左右鍵）：先記下來，量完再照順序做。
        // 不然一開頁馬上按，區塊還沒固定高度就變長，會把下面的東西推下去。
        document.addEventListener('click', e => {
            const b = blocksBusy && e.target.closest && e.target.closest('button');
            if (!b || !/(^|-)(first|prev|next|play|last)$/.test(b.id)) return;
            e.preventDefault();
            e.stopImmediatePropagation();
            blockQueue.push(() => b.click());
        }, true);
        document.addEventListener('keydown', e => {
            if (!blocksBusy || (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight')) return;
            if (e.target.closest && e.target.closest('input, textarea, select')) return;
            e.preventDefault();
            e.stopImmediatePropagation();
            const t = e.target, key = e.key;
            blockQueue.push(() => t.dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true })));
        }, true);
        // 網路字型（Space Mono 等）比較晚到時字寬字高會變，原本量的高度可能不夠：字型載完再量一次
        if (document.fonts) document.fonts.addEventListener('loadingdone', () => { if (blockLast) reserveBlockHeights(...blockLast); });

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
            minSup = Math.max(1, Math.min(minSup, graphs.length || 1));
            trace = buildTrace(graphs, minSup);
            bruteCache = null;
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
            timer = setInterval(() => { if (!step(1)) stopAuto(); }, 2400);
        });
        document.addEventListener('keydown', e => {
            if (e.key === 'ArrowRight') { stopAuto(); step(1); }
            if (e.key === 'ArrowLeft') { stopAuto(); step(-1); }
        });
        $('sup-minus').addEventListener('click', () => { if (minSup > 1) { minSup--; rebuild(); } });
        $('sup-plus').addEventListener('click', () => { if (minSup < graphs.length) { minSup++; rebuild(); } });
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
