<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/cantree.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/cantree-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/cantree-180.png">
    <title>CanTree 增量 FP-tree</title>
    <meta name="description" content="一步一步看 CanTree 怎麼用固定的標準順序插入交易：新交易進來直接插、沿路次數 +1、不用重排重建，要挖的時候再用 FP-Growth 的條件模式基底挖；和 FP-tree 比較順序與節點數，Java 與 Python 程式碼逐行對照。">
    <script src="../assets/theme.js"></script>
    <script src="../assets/quest.js" defer></script><!-- 練習模式答題記到研究闖關 -->
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=Syne:wght@700;800&display=swap');
        /* 手機瀏覽器會自動把某些段落的字放大，程式碼框裡就會一行大一行小；關掉它 */
        html { -webkit-text-size-adjust: 100%; text-size-adjust: 100%; }

        /* 反白（選取文字）的顏色：background 是底色、color 是字色 */
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
            --newc: #c084fc;
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
        .intro { color: var(--lt-c6c6d6, #c6c6d6); max-width: 780px; margin-top: 0.9rem; font-size: 0.95rem; }
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
        .crumb.cur { border-color: var(--accent); color: var(--text); background: var(--lt-7c3aed-15, rgba(124, 58, 237, 0.15)); }
        .tree-wrap { display: grid; grid-template-columns: 1fr auto; gap: 0.8rem; align-items: start; }
        @media (max-width: 520px) { .tree-wrap { grid-template-columns: 1fr; } }
        .tree-box { overflow-x: auto; background: var(--lt-0a0a14, #0a0a14); border: 1px solid var(--border); border-radius: 10px; min-height: 140px; display: flex; align-items: flex-start; justify-content: center; padding: 0.4rem; }
        .tree-box svg { display: block; max-width: 100%; height: auto; }
        .tree-empty { color: var(--muted); font-size: 0.85rem; align-self: center; padding: 1rem; text-align: center; }
        svg .edge { stroke: var(--lt-3a3a5a, #3a3a5a); stroke-width: 2; }
        svg .edge.on { stroke: var(--warn); stroke-width: 3; }
        svg .link { stroke: var(--accent2); stroke-width: 1.6; stroke-dasharray: 4 3; fill: none; }
        svg .node circle.body { fill: var(--lt-1e1e36, #1e1e36); stroke: var(--lt-3a3a5a, #3a3a5a); stroke-width: 2; }
        svg .node.on circle.body { stroke: var(--warn); stroke-width: 3; fill: var(--lt-2b2318, #2b2318); }
        svg .node.new circle.body { stroke: var(--good); stroke-width: 3; }
        svg .node.linked circle.body { stroke: var(--accent2); stroke-width: 3; }
        svg .node .emo { font-size: 17px; }
        svg .node .badge { fill: var(--lt-3b3b62, #3b3b62); }
        svg .node.on .badge { fill: var(--warn); }
        svg .node.linked .badge { fill: var(--accent2); }
        svg .node .cnt { font: 700 10.5px 'Space Mono', monospace; fill: var(--lt-ffffff, #fff); }
        svg .root circle { fill: var(--lt-2a2a48, #2a2a48); }
        svg .root text { font: 9px 'Space Mono', monospace; fill: var(--muted); }

        .header-table { border-collapse: collapse; font-size: 0.82rem; min-width: 138px; }
        .header-table caption { text-align: left; color: var(--muted); font-size: 0.75rem; padding-bottom: 0.25rem; }
        .header-table td { padding: 0.18rem 0.35rem; border-bottom: 1px solid var(--border); white-space: nowrap; }
        .header-table tr { cursor: pointer; }
        .header-table tr:hover td { background: var(--lt-ffffff-3, rgba(255, 255, 255, 0.03)); }
        .header-table tr.sel td { background: var(--lt-06b6d4-14, rgba(6, 182, 212, 0.14)); }
        .header-table tr.out { opacity: 0.45; cursor: default; }
        .header-table tr.out td.nm { text-decoration: line-through; }
        .header-table td.c { font: 700 0.8rem 'Space Mono', monospace; text-align: right; }
        .legend { display: flex; flex-wrap: wrap; gap: 0.3rem 0.9rem; font-size: 0.75rem; color: var(--muted); margin-top: 0.55rem; }
        .legend i { display: inline-block; width: 10px; height: 10px; border-radius: 50%; border: 2px solid; margin-right: 0.3rem; vertical-align: -1px; }

        /* ── 資料列 ── */
        .rows { display: grid; gap: 0.3rem; }
        .row { display: flex; align-items: center; gap: 0.35rem; padding: 0.22rem 0.4rem; border-radius: 8px; flex-wrap: wrap; }
        .row.cur { background: var(--lt-f59e0b-13, rgba(245, 158, 11, 0.13)); }
        .row.done { opacity: 0.55; }
        .row .rid { font: 0.76rem 'Space Mono', monospace; color: var(--muted); width: 2.3em; }
        .row.cur .rid { color: var(--warn); }
        .chip { font-size: 0.82rem; border-radius: 6px; padding: 0.02rem 0.4rem; background: var(--lt-23233d, #23233d); }
        .chip.out { background: none; color: var(--muted); text-decoration: line-through; }
        .arrow { color: var(--lt-4a4a66, #4a4a66); font-size: 0.75rem; }
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
            background: var(--lt-0a0a14, #0a0a14);
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 0.5rem 0;
            overflow: auto;
            max-height: 560px;
            font: 0.78rem/1.7 'Space Mono', ui-monospace, monospace;
            position: relative;   /* 高亮行的 offsetTop 要以程式碼框為準，自動捲動才捲得到 */
        }
        @media (max-width: 600px) { pre.code { font-size: 0.7rem; max-height: 400px; } }
        .code .ln { display: block; padding-right: 0.9rem; white-space: pre; width: max-content; min-width: 100%; }
        .code .ln::before { content: attr(data-n); display: inline-block; width: 2.4em; text-align: right; margin-right: 0.9em; color: var(--lt-4a4a66, #4a4a66); }
        .code .ln.hl { background: var(--line-hl); box-shadow: inset 3px 0 0 var(--accent); }
        .kw { color: var(--lt-c792ea, #c792ea); }
        .fn { color: var(--lt-82aaff, #82aaff); }
        .num { color: var(--lt-f78c6c, #f78c6c); }
        .cm { color: var(--lt-637777, #637777); }
        .str { color: var(--lt-c3e88d, #c3e88d); }
        .ty { color: var(--lt-ffcb6b, #ffcb6b); }
        .downloads { display: flex; flex-wrap: wrap; gap: 0.5rem 1rem; margin-top: 0.7rem; font-size: 0.85rem; color: var(--muted); align-items: center; }
        .downloads a { color: var(--accent2); }
        .downloads code { font: 0.78rem 'Space Mono', monospace; background: var(--panel-2); padding: 0.1rem 0.4rem; border-radius: 4px; color: var(--text); }

        /* ── 結果 ── */
        .levels { display: grid; gap: 0.45rem; }
        .level { display: grid; grid-template-columns: 2.8em 1fr; gap: 0.5rem; align-items: start; }
        .level .tag { font: 700 0.8rem 'Space Mono', monospace; color: var(--accent2); padding-top: 0.2rem; }
        .level .items { display: flex; flex-wrap: wrap; gap: 0.35rem; }
        .pat { font-size: 0.82rem; border: 1px solid var(--lt-22c55e-50, rgba(34, 197, 94, 0.5)); border-radius: 7px; padding: 0.12rem 0.5rem; }
        .pat .n { font: 700 0.74rem 'Space Mono', monospace; margin-left: 0.35rem; color: var(--lt-86efac, #86efac); }
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
        .notes p, .notes li { color: var(--lt-c6c6d6, #c6c6d6); font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; }
        .notes b { color: var(--text); }
        /* ── CanTree 專用：控制列、順序比較、組新交易 ── */
        .controls { display: flex; flex-wrap: wrap; gap: 0.5rem 1.2rem; align-items: center; margin-top: 0.7rem; font-size: 0.88rem; }
        .controls .minsup { margin-left: 0; }
        .controls .val { font: 700 1rem 'Space Mono', monospace; min-width: 1.6em; text-align: center; }
        button.btn.small { padding: 0.25rem 0.55rem; font-size: 0.8rem; }
        .orders { background: var(--lt-0a0a14, #0a0a14); border: 1px solid var(--border); border-radius: 10px; padding: 0.5rem 0.65rem; margin-bottom: 0.6rem; font-size: 0.8rem; display: grid; gap: 0.2rem; }
        .ord { display: grid; grid-template-columns: 7.2em 1fr; gap: 0.5rem; align-items: baseline; }
        .ord .k { color: var(--muted); }
        .ord .v { min-width: 0; overflow-wrap: anywhere; }
        .ord .v .diff { color: var(--warn); font-weight: 600; }
        .ord-warn { font-size: 0.78rem; color: var(--muted); padding-top: 0.15rem; }
        .ord-warn.bad { color: var(--warn); }
        .ord-warn.ok { color: var(--lt-86efac, #86efac); }
        .row.todo { opacity: 0.35; }
        .row.nw .rid { color: var(--newc); }
        .row.nw .chip { background: var(--lt-c084fc-16, rgba(192, 132, 252, 0.16)); }
        .row .del { background: none; border: none; color: var(--muted); cursor: pointer; font-size: 0.8rem; width: 24px; height: 24px; border-radius: 50%; margin-left: auto; }
        .row .del:hover { color: var(--bad); background: var(--lt-ffffff-5, rgba(255, 255, 255, 0.05)); }
        .row-sep { font-size: 0.76rem; color: var(--newc); padding: 0.3rem 0.4rem 0.05rem; border-top: 1px dashed var(--lt-c084fc-45, rgba(192, 132, 252, 0.45)); margin-top: 0.2rem; }
        .compose { margin-top: 0.8rem; display: grid; gap: 0.55rem; border-top: 1px solid var(--border); padding-top: 0.7rem; }
        .compose .lbl { font-size: 0.8rem; color: var(--muted); margin-bottom: 0.25rem; }
        .picks { display: flex; flex-wrap: wrap; gap: 0.35rem; align-items: center; }
        .pick {
            background: var(--panel-2);
            border: 1px solid var(--border);
            color: var(--muted);
            border-radius: 8px;
            padding: 0.25rem 0.5rem;
            font-size: 0.84rem;
            cursor: pointer;
            font-family: inherit;
        }
        .pick:hover { border-color: var(--newc); }
        .pick.on { color: var(--text); border-color: var(--newc); background: var(--lt-c084fc-16, rgba(192, 132, 252, 0.16)); }
        .presets { display: flex; flex-wrap: wrap; gap: 0.35rem; }
        .presets .btn.cur { border-color: var(--newc); color: var(--newc); }
        .row-actions { display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center; }
        .result-note { font-size: 0.78rem; color: var(--muted); margin-bottom: 0.5rem; }
        /* ── 練習模式（猜下一步）：題目疊在說明框的位置，不推動任何區塊 ── */
        .quiz-bar { display: flex; align-items: center; gap: 0.7rem; margin-top: 0.75rem; }
        .quiz-toggle { display: inline-flex; align-items: center; gap: 0.5rem; }
        .quiz-toggle .sw { position: relative; flex: none; width: 30px; height: 17px; border-radius: 9px; background: var(--lt-2a2a48, #2a2a48); transition: background 0.15s; }
        .quiz-toggle .sw::after { content: ''; position: absolute; top: 2px; left: 2px; width: 13px; height: 13px; border-radius: 50%; background: var(--muted); transition: transform 0.15s, background 0.15s; }
        .quiz-toggle.quiz-on { border-color: var(--accent); }
        .quiz-toggle.quiz-on .sw { background: var(--accent); }
        .quiz-toggle.quiz-on .sw::after { transform: translateX(13px); background: var(--lt-ffffff, #fff); }
        .quiz-toggle { flex: none; }
        .quiz-score { font: 0.8rem 'Space Mono', monospace; color: var(--accent2); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; min-width: 0; }
        .quiz-host { position: relative; display: grid; margin-top: 0.8rem; }
        .quiz-host > .explain { margin-top: 0; min-width: 0; }
        .quiz {
            position: absolute; inset: 0; z-index: 2; overflow: auto;
            display: flex; flex-direction: column; gap: 0.45rem;
            background: var(--panel-2); border: 1px solid var(--lt-7c3aed-50, rgba(124, 58, 237, 0.5)); border-left: 3px solid var(--accent);
            border-radius: 8px; padding: 0.5rem 0.75rem; font-size: 0.88rem; line-height: 1.5;
        }
        .quiz[hidden] { display: none; }
        .quiz.nudge { animation: quiz-nudge 0.3s; }
        @keyframes quiz-nudge { 25% { transform: translateX(-4px); } 75% { transform: translateX(4px); } }
        .quiz-head { display: flex; align-items: center; justify-content: space-between; gap: 0.3rem 0.5rem; flex-wrap: wrap; }
        .quiz-tag { font: 700 0.74rem 'Space Mono', monospace; color: var(--lt-c4b5fd, #c4b5fd); }
        /* 題目和解釋疊在同一格：答完換成解釋，高度取兩者較高的，不會跳 */
        .quiz-body { display: grid; }
        .quiz-body > * { grid-area: 1 / 1; min-width: 0; }
        .quiz-choices { display: flex; flex-wrap: wrap; gap: 0.4rem; }
        .quiz-choices.half { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); }
        .quiz-choices.wide { display: grid; grid-template-columns: minmax(0, 1fr); gap: 0.3rem; }
        .quiz-choices.wide .quiz-choice { min-height: 32px; padding: 0.2rem 0.6rem; font-size: 0.8rem; }
        .quiz-choice {
            min-height: 36px; min-width: 44px; padding: 0.25rem 0.7rem; border-radius: 8px;
            border: 1px solid var(--border); background: var(--lt-1c1c33, #1c1c33); color: var(--text);
            font: inherit; font-size: 0.86rem; line-height: 1.35; text-align: left; cursor: pointer; overflow-wrap: anywhere;
        }
        .quiz-choice:hover:not(:disabled) { border-color: var(--accent2); }
        .quiz-choice:disabled { cursor: default; }
        .quiz-choice.sel { border-color: var(--accent2); background: var(--lt-06b6d4-14, rgba(6, 182, 212, 0.14)); box-shadow: 0 0 0 1px var(--accent2) inset; }
        .quiz-choice.right { border-color: var(--good); background: var(--lt-22c55e-18, rgba(34, 197, 94, 0.18)); color: var(--lt-bbf7d0, #bbf7d0); }
        .quiz-choice.right.missed { border-style: dashed; background: var(--lt-22c55e-7, rgba(34, 197, 94, 0.07)); }   /* 複選題漏選的 */
        .quiz-choice.wrong { border-color: var(--bad); background: var(--lt-f87171-14, rgba(248, 113, 113, 0.14)); color: var(--lt-fecaca, #fecaca); text-decoration: line-through; }
        .quiz-actions { display: flex; gap: 0.35rem; margin-left: auto; }
        .quiz-actions .btn { padding: 0.2rem 0.65rem; font-size: 0.82rem; }
        .quiz.done .quiz-ok { visibility: hidden; }
        .quiz-why { visibility: hidden; font-size: 0.85rem; color: var(--lt-c6c6d6, #c6c6d6); }
        .quiz.done .quiz-why { visibility: visible; }
        .quiz.done .quiz-text { visibility: hidden; }
        .quiz-verdict { color: var(--good); margin-right: 0.3rem; }
        .quiz.miss .quiz-verdict { color: var(--bad); }
    </style>
    <link rel="stylesheet" href="../assets/theme.css">
</head>

<body>
    <div class="wrap">
        <a class="back" href="../index.html#research">← RETURN TO PORTFOLIO</a>
        <div class="kicker">RESEARCH DEMO · INCREMENTAL MINING</div>
        <h1>CanTree 增量 FP-tree<small>商品順序事先定好，新交易來了直接插，不用重排</small></h1>
        <p class="intro">
            <a href="fp-growth.html">FP-Growth</a> 的 FP-tree 是照「次數多到少」排商品的，可是資料一直進來，次數就會變；
            順序一變，整棵樹就得重建。<a href="incremental.html">FUP 那一頁</a>處理的是 Apriori 的增量更新，這頁換成樹：
            <b>CanTree</b>（Canonical-order Tree，Leung 等人 2007）改用一個<b>事先定好、永遠不變的標準順序</b>（這裡用貨架順序 ☕→🍞→🥛→🍙→🥚→🥔），
            所以新交易進來只要照順序直接插、沿路次數 +1。建樹時不看門檻、所有商品都存；<b>要挖的時候</b>才用門檻，跟 FP-Growth 一樣找條件模式基底。
        </p>

        <div class="layout">
            <div class="card a-step">
                <div class="player">
                    <button class="btn" id="btn-first" title="回到開頭">⏮</button>
                    <button class="btn" id="btn-prev">◀ 上一步</button>
                    <button class="btn primary" id="btn-next">下一步 ▶</button>
                    <button class="btn" id="btn-play">▶ 自動播放</button>
                </div>
                <div class="controls">
                    <div class="minsup">
                        <span>最小支持度</span>
                        <button class="btn stepper" id="sup-minus" aria-label="降低門檻">−</button>
                        <span class="val" id="sup-val">3</span>
                        <button class="btn stepper" id="sup-plus" aria-label="提高門檻">+</button>
                    </div>
                    <div class="minsup">
                        <span>插完</span>
                        <button class="btn stepper" id="at-minus" aria-label="提早挖">−</button>
                        <span class="val" id="at-val">12</span>
                        <button class="btn stepper" id="at-plus" aria-label="晚一點挖">+</button>
                        <span>筆後挖</span>
                    </div>
                    <button class="btn small" id="btn-mine-here">⛏ 在這一步挖</button>
                </div>
                <div class="quiz-bar">
                    <button class="btn quiz-toggle" id="quiz-toggle" aria-pressed="false" title="按下一步之前先猜猜看">🎯 練習模式<span class="sw" aria-hidden="true"></span></button>
                    <span class="quiz-score" id="quiz-score" style="visibility:hidden">答對 0/0</span>
                </div>
                <div class="quiz-host" id="quiz-host">
                    <div class="explain" id="explain"></div>
                    <div class="quiz" id="quiz" role="group" aria-label="練習題" hidden></div>
                </div>
            </div>

            <div class="card a-tree">
                <div class="card-head"><h2 id="tree-title">CanTree</h2></div>
                <div class="crumbs" id="crumbs"></div>
                <div class="orders">
                    <div class="ord"><span class="k">CanTree 順序</span><span class="v" id="ord-can"></span></div>
                    <div class="ord"><span class="k">FP-tree 照次數</span><span class="v" id="ord-fp"></span></div>
                    <div class="ord-warn" id="ord-warn">&nbsp;</div>
                </div>
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
                <div class="compose">
                    <div>
                        <div class="lbl">組一筆新交易（點商品勾選），再按「＋ 加入」；最多 8 筆</div>
                        <div class="picks" id="picks"></div>
                    </div>
                    <div>
                        <div class="lbl">或直接換一組新交易</div>
                        <div class="presets" id="presets"></div>
                    </div>
                    <div class="row-actions">
                        <button class="btn small" id="btn-clear">清空新交易</button>
                        <button class="btn small" id="btn-reset">↺ 恢復範例</button>
                    </div>
                </div>
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
                <h2>挖出來的頻繁樣式</h2>
                <div class="result-note" id="result-note"></div>
                <div class="levels" id="levels"></div>
                <div class="stats">
                    <div class="stat"><div class="v" id="st-can">0</div><div class="k">CanTree 節點數</div></div>
                    <div class="stat"><div class="v" id="st-fp">0</div><div class="k">FP-tree 節點數（照目前次數排）</div></div>
                    <div class="stat"><div class="v" id="st-rebuild">0</div><div class="k">FP-tree 得整棵重建的次數</div></div>
                </div>
                <div class="compare" id="compare"></div>
            </div>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼順序固定，挖出來還是對的？</h2>
                <p>FP-Growth 正確的關鍵不是「照次數排」，而是<b>每筆交易都照同一個順序排</b>：這樣樹上從根往下的每條路徑都是一群交易的共同前綴，
                    某個商品節點往上走到根，經過的就是跟它同一筆交易、而且排在它前面的商品。換成任何一個固定的順序，這件事一樣成立，
                    所以條件模式基底、遞迴的方法都可以照搬，結果跟對整個資料庫重跑 FP-Growth 完全一樣。</p>
                <p style="margin-top:0.5rem">照次數排只是為了讓樹<b>比較小</b>（常見的商品放上面，共用的前綴比較多）。CanTree 放棄這一點，換到的是：
                    次數怎麼變都不影響順序，新交易永遠只要沿一條路徑插進去，<b>舊的節點一個都不用動</b>。另外它建樹時不看門檻、所有商品都存，所以門檻改了也不用重建。</p>
            </div>
            <div class="card">
                <h2>跟 FP-tree、FUP 比起來</h2>
                <ul>
                    <li><b>插入很便宜：</b>每筆新交易只走一條路徑；FP-tree 只要次數順序一變（或有商品從不頻繁變頻繁），就得重新掃資料庫、整棵重建。</li>
                    <li><b>代價是樹比較大：</b>順序不是照次數排，共用的前綴比較少，又存了所有商品（包括不頻繁的），節點數通常比 FP-tree 多，挖的時候也要多走一些節點。</li>
                    <li><b>跟 <a href="incremental.html">FUP</a> 比：</b>FUP 存的是「結果」（頻繁樣式和次數），新資料來時有時還得回頭掃舊資料庫；CanTree 存的是「整份資料的壓縮」，從來不用回頭掃，但每次要結果都要重新挖一次。</li>
                    <li>後來很多增量、資料串流的樹（例如滑動視窗用的樹、高效益樣式的增量樹）都借用「固定順序、只改路徑上的次數」這個想法，刪除交易時也一樣只要沿路徑把次數 −1。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           CanTree 一步一步看
           網頁裡用 JavaScript 照著同樣的流程跑一次（插入、在某個時間點挖、繼續插入），
           把每一步記下來；右邊的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = /*CODE_JSON*/null;

        const ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片'];
        const ORDER = ITEMS;      // 標準順序：跟程式裡的 ORDER 一樣（貨架順序），永遠不變
        const EMOJI = { '咖啡': '☕', '麵包': '🍞', '牛奶': '🥛', '飯糰': '🍙', '茶葉蛋': '🥚', '洋芋片': '🥔' };
        const SAMPLE = [
            ['咖啡', '麵包', '牛奶'],
            ['咖啡', '麵包', '茶葉蛋'],
            ['咖啡', '麵包', '牛奶', '飯糰'],
            ['麵包', '牛奶', '洋芋片'],
            ['咖啡', '牛奶', '茶葉蛋'],
            ['咖啡', '麵包', '牛奶', '茶葉蛋'],
            ['飯糰', '茶葉蛋', '洋芋片'],
            ['咖啡', '麵包', '飯糰']
        ];
        const PRESETS = [
            { label: '🔀 次數順序會變', rows: [['飯糰', '洋芋片'], ['茶葉蛋', '洋芋片', '飯糰'], ['牛奶', '飯糰'], ['洋芋片', '飯糰', '咖啡']] },
            { label: '😐 順序都沒變', rows: [['咖啡', '麵包'], ['咖啡', '牛奶'], ['麵包', '牛奶', '茶葉蛋']] },
            { label: '🥔 洋芋片爆紅', rows: [['洋芋片', '咖啡'], ['洋芋片', '麵包'], ['洋芋片', '牛奶'], ['洋芋片', '茶葉蛋'], ['洋芋片', '飯糰'], ['洋芋片']] }
        ];
        const MAX_BATCH = 8;

        const $ = id => document.getElementById(id);
        let batch = [];           // 新增的交易（接在 8 筆初始交易後面）
        let presetUsed = 0;
        let draft = new Set();
        let minSup = 3;
        let mineAt = null;        // 插完第幾筆後挖；null＝全部插完才挖
        let lang = 'java';
        let trace = [];
        let cursor = 0;
        let linkItem = null;
        let timer = null;

        /* 跟 Java 的 compareTo、Python 的字串比較同一個順序（依字碼） */
        const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
        const rank = i => (ORDER.includes(i) ? ORDER.indexOf(i) : ORDER.length);
        const canon = (a, b) => rank(a) - rank(b) || cmp(a, b);
        const sortCanon = items => items.slice().sort(canon);
        const fmt = set => '{' + set.join(', ') + '}';
        const arrowPath = items => items.join(' → ');
        const esc = x => String(x).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        const allRows = () => SAMPLE.concat(batch);
        const mineCount = () => (mineAt === null ? allRows().length : Math.min(mineAt, allRows().length));

        /* FP-tree 會用的順序：所有商品照次數由多到少（一樣多照字碼） */
        function freqOrder(rows) {
            const count = {};
            rows.forEach(t => t.forEach(i => { count[i] = (count[i] || 0) + 1; }));
            return { count, order: Object.keys(count).sort((a, b) => count[b] - count[a] || cmp(a, b)) };
        }
        /* 照某個順序把交易插成前綴樹，會有幾個節點（不同的前綴有幾種） */
        function prefixNodes(rows, order) {
            const seen = new Set();
            rows.forEach(t => {
                const p = order.filter(i => t.includes(i));
                for (let k = 1; k <= p.length; k++) seen.add(p.slice(0, k).join('|'));
            });
            return seen.size;
        }

        /* ---------- 照著程式跑一次，記下每一步 ---------- */
        function buildTrace(db, nInit, minSup, mineAt) {
            const steps = [];
            const result = [];
            const stats = { trees: 0, rebuilds: 0 };
            const stack = [];
            let nextId = 1, ins = 0, fpBuilt = null, minedAt = 0;
            const can = { id: 0, item: null, count: 0, children: new Map() };
            const canHeader = {};
            let canNodes = 0;

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
            // 第 0 層：CanTree 本身（表頭照標準順序）
            const f0 = () => {
                const count = {};
                Object.keys(canHeader).forEach(i => { count[i] = canHeader[i].reduce((a, n) => a + n.count, 0); });
                return { depth: 0, suffix: [], root: can, header: canHeader, order: sortCanon(Object.keys(canHeader)), count, rows: null };
            };

            function push(kind, f, extra = {}) {
                const sofar = db.slice(0, ins);
                const fo = freqOrder(sofar);
                steps.push({
                    kind, depth: f.depth, suffix: f.suffix,
                    crumbs: stack.map(x => x.suffix),
                    tree: f.root ? snapshot(f.root) : [],
                    header: f.header ? Object.fromEntries(Object.entries(f.header).map(([k, v]) => [k, v.map(n => n.id)])) : {},
                    order: f.order.slice(),
                    counts: { ...f.count },
                    rows: f.rows ? f.rows.map(r => ({ ...r })) : null,
                    ins, minedAt, canNodes,
                    fpOrder: fo.order, fpBuilt: fpBuilt ? fpBuilt.slice() : null,
                    fpNodes: prefixNodes(sofar, fo.order),
                    fpNodesMin: prefixNodes(sofar, fo.order.filter(i => fo.count[i] >= minSup)),
                    result: result.map(r => ({ ...r })),
                    stats: { ...stats },
                    ...extra
                });
            }

            /* 條件模式基底之後：跟 FP-Growth 一模一樣 */
            function fpMine(rows, suffix, depth) {
                const f = { depth, suffix, root: null, header: null, order: [], count: {}, rows: rows.map(r => ({ items: r.items, n: r.n })) };
                stack.push(f);
                rows.forEach(r => r.items.forEach(i => { f.count[i] = (f.count[i] || 0) + r.n; }));
                f.order = Object.keys(f.count).filter(i => f.count[i] >= minSup)
                    .sort((a, b) => f.count[b] - f.count[a] || cmp(a, b));
                f.rows.forEach(r => { r.path = f.order.filter(i => r.items.includes(i)); });
                push('count', f);
                if (!f.order.length) { stack.pop(); return; }

                f.root = { id: 0, item: null, count: 0, children: new Map() };
                f.header = Object.fromEntries(f.order.map(i => [i, []]));
                stats.trees++;
                f.rows.forEach(r => {
                    let node = f.root;
                    r.path.forEach(item => {
                        let child = node.children.get(item);
                        if (!child) {
                            child = { id: nextId++, item, count: 0, children: new Map(), parent: node };
                            node.children.set(item, child);
                            f.header[item].push(child);
                        }
                        child.count += r.n;
                        node = child;
                    });
                });
                push('build', f);

                for (let i = f.order.length - 1; i >= 0; i--) {
                    const item = f.order[i];
                    const pattern = [item, ...suffix];
                    result.push({ set: pattern, count: f.count[item], fresh: true });
                    const linkIds = f.header[item].map(n => n.id);
                    push('pattern', f, { item, pattern, linkIds });
                    result.forEach(r => { r.fresh = false; });
                    const base = [], pathIds = [];
                    f.header[item].forEach(node => {
                        const path = [];
                        for (let p = node.parent; p.item !== null; p = p.parent) { path.unshift(p.item); pathIds.push(p.id); }
                        if (path.length) base.push({ items: path, n: node.count });
                    });
                    push('base', f, { item, pattern, linkIds, pathIds, base });
                    if (base.length) {
                        fpMine(base, pattern, depth + 1);
                        push('back', f, { item, pattern });
                    }
                }
                stack.pop();
            }

            /* 在 CanTree 上挖：表頭照標準順序，從最後面的商品開始 */
            function mineCan() {
                const f = f0();
                stack.push(f);
                push('mine', f, { mining: true });
                for (const item of f.order.slice().reverse()) {
                    const sup = f.count[item];
                    const linkIds = f.header[item].map(n => n.id);
                    if (sup < minSup) { push('skip', f, { mining: true, item, linkIds, sup }); continue; }
                    const pattern = [item];
                    result.push({ set: pattern, count: sup, fresh: true });
                    push('pattern', f, { mining: true, item, pattern, linkIds });
                    result.forEach(r => { r.fresh = false; });
                    const base = [], pathIds = [];
                    f.header[item].forEach(node => {
                        const path = [];
                        for (let p = node.parent; p.item !== null; p = p.parent) { path.unshift(p.item); pathIds.push(p.id); }
                        if (path.length) base.push({ items: path, n: node.count });
                    });
                    push('base', f, { mining: true, item, pattern, linkIds, pathIds, base });
                    if (base.length) {
                        fpMine(base, pattern, 1);
                        push('back', f, { mining: true, item, pattern });
                    }
                }
                stack.pop();
                minedAt = ins;
                push('mined', f0(), { mining: true });
            }

            push('start', f0());
            db.forEach((t, r) => {
                const path = sortCanon(t);
                let node = can;
                const pathIds = [], newIds = [];
                path.forEach(item => {
                    let child = node.children.get(item);
                    if (!child) {
                        child = { id: nextId++, item, count: 0, children: new Map(), parent: node };
                        node.children.set(item, child);
                        (canHeader[item] = canHeader[item] || []).push(child);
                        newIds.push(child.id);
                        canNodes++;
                    }
                    child.count++;
                    pathIds.push(child.id);
                    node = child;
                });
                ins++;
                let fpChanged = false, oldOrder = null;
                if (r >= nInit && fpBuilt) {
                    const o = freqOrder(db.slice(0, ins)).order;
                    if (o.join('|') !== fpBuilt.join('|')) { fpChanged = true; oldOrder = fpBuilt; fpBuilt = o; stats.rebuilds++; }
                }
                push('insert', f0(), { row: r, isNew: r >= nInit, path, pathIds, newIds, fpChanged, oldOrder });
                if (r === nInit - 1) {
                    fpBuilt = freqOrder(db.slice(0, ins)).order;
                    push('ready', f0());
                }
                if (ins === mineAt) mineCan();
            });
            push('end', f0());
            return steps;
        }

        /* 直接對 CanTree 的快照檢查：每個節點的次數 = 以這條路徑開頭的交易筆數（測試用） */
        function treePaths(s) {
            const byId = {};
            s.tree.forEach(n => { byId[n.id] = n; });
            return s.tree.map(n => {
                const p = [];
                for (let x = n; x; x = byId[x.parent]) p.unshift(x.item);
                return [p, n.count];
            });
        }

        /* ---------- 說明文字 ---------- */
        const label = (r, nInit) => (r < nInit ? `T${r + 1}` : `+${r - nInit + 1}`);
        const where = s => s.depth === 0 ? 'CanTree' : `後綴 ${fmt(s.suffix)} 的條件 FP-tree`;
        function describe(s) {
            const nInit = SAMPLE.length, N = allRows().length;
            switch (s.kind) {
                case 'start':
                    return `CanTree 跟 FP-tree 一樣是前綴樹，差別只在<b>商品的排法</b>：FP-tree 要先掃一次資料庫數次數、照次數排；` +
                        `CanTree 直接用事先定好的標準順序「${arrowPath(ORDER)}」，所以<b>不用先數、也不用門檻</b>，交易來一筆插一筆。` +
                        `先插入 ${nInit} 筆初始交易，再插入 ${N - nInit} 筆新交易，插完第 ${mineCount()} 筆時挖。`;
                case 'insert': {
                    const lb = label(s.row, nInit);
                    const shared = s.path.length - s.newIds.length;
                    const head = s.isNew
                        ? `新交易 ${lb} 進來：一樣照標準順序排成「${arrowPath(s.path)}」直接插。`
                        : `插入 ${lb}：照標準順序排成「${arrowPath(s.path)}」。`;
                    let body;
                    if (!s.newIds.length) body = `整條路徑樹上都有了，只要沿路次數 +1，<b>一個新節點都不用長</b>。`;
                    else if (!shared) body = `樹上沒有可以共用的前綴，從根長出一條新的路徑。`;
                    else body = `前面的「${arrowPath(s.path.slice(0, shared))}」已經有了，沿路次數 +1；後面新長出「${arrowPath(s.path.slice(shared))}」。`;
                    if (!s.isNew) return head + body;
                    body += `樹上其他節點<b>完全不動、不用重排</b>。`;
                    if (s.fpChanged) body += `可是 FP-tree 照次數排的順序<b>已經跟建樹時不同</b>了，它得重新掃資料庫、整棵重建。`;
                    else body += `這筆沒有改變次數的排名，FP-tree 這次也能直接插。`;
                    return head + body;
                }
                case 'ready':
                    return `初始的 ${nInit} 筆插完了，CanTree 有 <b>${s.canNodes}</b> 個節點，而且我們一次都沒有數過次數。` +
                        `同樣 ${nInit} 筆如果建 FP-tree：先掃一次數次數，照「${arrowPath(s.fpOrder)}」排，再掃一次建樹，會是 ${s.fpNodes} 個節點。` +
                        `接下來新交易一筆一筆進來，看兩棵樹各要做什麼。`;
                case 'mine': {
                    const out = s.order.filter(i => s.counts[i] < minSup);
                    return `現在要挖（樹裡有 ${s.ins} 筆交易，最小支持度 <b>${minSup}</b>）。門檻到這時候才用到：` +
                        `每個商品的次數就是它節點鏈上的次數加起來，看右邊的表頭就有，<b>不用再掃資料庫</b>。` +
                        (out.length ? `${out.join('、')} 不到 ${minSup} 次，挖的時候跳過，但節點還留在樹上（門檻改了還用得到）。` : '') +
                        `跟 FP-Growth 一樣從表頭最後面的 ${s.order[s.order.length - 1]} 開始往前挖。`;
                }
                case 'skip':
                    return `${s.item} 節點鏈上加起來只有 ${s.sup} 次，不到 ${minSup}，以它結尾的樣式都不可能頻繁，跳過。它的節點不用刪，留在樹上。`;
                case 'count': {
                    const out = Object.keys(s.counts).filter(i => s.counts[i] < minSup);
                    if (!s.order.length) return `在條件模式基底裡數次數（每條路徑要乘上它的次數）：沒有任何商品達到 ${minSup} 次，以 ${fmt(s.suffix)} 結尾的樣式到此為止，回到上一層。`;
                    return `在條件模式基底裡數次數（每條路徑要乘上它的次數）：` +
                        (out.length ? `${out.join('、')} 不到 ${minSup} 次被丟掉，` : '') + `留下 <b>${arrowPath(s.order)}</b>。` +
                        `從這裡開始跟 FP-Growth 完全一樣：條件樹照<b>條件裡的次數</b>排（反正它用完就丟，不用顧慮之後的新資料）。`;
                }
                case 'build':
                    return `把條件模式基底照「${arrowPath(s.order)}」的順序插進一棵新的小樹，這就是<b>${where(s)}</b>，共 ${s.tree.length} 個節點。`;
                case 'pattern':
                    if (s.depth === 0) {
                        return `挖 <b>${s.item}</b>：節點鏈（虛線）上的次數加起來 ${s.counts[s.item]} 次 ≥ ${minSup}，先記下 ${fmt(s.pattern)}。`;
                    }
                    return `在${where(s)} 裡挖 <b>${s.item}</b>：它出現 ${s.counts[s.item]} 次，代表 ${fmt(s.pattern)} 一起出現了 ${s.counts[s.item]} 次，記下來。`;
                case 'base':
                    if (!s.base.length) return `${s.item} 的節點往上直接就是根，沒有前綴路徑，以 ${fmt(s.pattern)} 結尾的不會再有更大的樣式，換下一個商品。`;
                    return `找 ${s.item} 的條件模式基底：沿著節點鏈找到樹上所有 ${s.item}，從每個往上走到根。共 ${s.base.length} 條路徑：` +
                        s.base.map(b => `${arrowPath(b.items)} ×${b.n}`).join('、') + `。` +
                        (s.depth === 0 ? `路徑上可能有不頻繁的商品，下一層數次數時會被丟掉。` : '') + `接著用它們遞迴，找出以 ${fmt(s.pattern)} 結尾的樣式。`;
                case 'back':
                    return `以 ${fmt(s.pattern)} 結尾的樣式都挖完了，回到${where(s)}，繼續挖下一個商品。`;
                case 'mined':
                    return `挖完了！在 ${s.ins} 筆交易上找到 <b>${s.result.length}</b> 個頻繁樣式，跟直接對這 ${s.ins} 筆跑 FP-Growth 的結果一樣。` +
                        `挖的過程只是讀樹，<b>CanTree 本身一點都沒改</b>，` +
                        (s.ins < N ? `接下來剩下的 ${N - s.ins} 筆照樣直接插。` : `之後再有新交易，照樣直接插。`);
                case 'end': {
                    const extra = s.minedAt && s.minedAt < N ? `下面的結果是插完第 ${s.minedAt} 筆時挖的；想看最新的結果，把挖的時間點調到「插完 ${N} 筆後挖」就好，樹不用重建。` : '';
                    return `完成！CanTree 最後有 <b>${s.canNodes}</b> 個節點；同樣 ${N} 筆照目前次數排的 FP-tree 是 ${s.fpNodes} 個。` +
                        `新交易進來時，CanTree 重排 0 次；FP-tree 的順序變了 <b>${s.stats.rebuilds}</b> 次，每次都得整棵重建。` + extra;
                }
            }
            return '';
        }

        const CODE_TAGS = s => {
            if (s.depth > 0) {
                return ({
                    count: ['count'], build: ['cinsert'], pattern: ['cloop', 'cpattern'],
                    base: s.base && s.base.length ? ['cbase', 'crecurse'] : ['cbase'], back: ['crecurse']
                })[s.kind] || [];
            }
            return ({
                start: ['order'], insert: ['insert'], ready: ['order'], mine: ['mine'], skip: ['sup', 'skip'], pattern: ['sup', 'pattern'],
                base: s.base && s.base.length ? ['base', 'recurse'] : ['base'], back: ['recurse'], mined: ['end'], end: ['insert']
            })[s.kind] || [];
        };

        /* ---------- 畫樹 ---------- */
        function drawTree(s) {
            const box = $('tree');
            if (!s.tree.length) {
                box.innerHTML = `<div class="tree-empty">${s.kind === 'start' ? '樹還是空的，下一步開始一筆一筆插。' : s.kind === 'count' && !s.order.length ? '沒有頻繁的商品，不用建樹。' : '樹還是空的。'}</div>`;
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
            const linkIds = linkItem && s.header[linkItem] ? s.header[linkItem] : (s.linkIds || []);
            const linked = new Set(linkIds);

            let svg = `<svg viewBox="0 0 ${W} ${H}" width="${W}" role="img" aria-label="${s.depth === 0 ? 'CanTree' : '條件 FP-tree'}">`;
            s.tree.forEach(n => {
                const a = pos[n.parent], b = pos[n.id];
                const on = onIds.has(n.id) && (n.parent === 0 || onIds.has(n.parent) || linked.has(n.parent));
                svg += `<line class="edge${on ? ' on' : ''}" x1="${X(a)}" y1="${Y(a)}" x2="${X(b)}" y2="${Y(b)}"/>`;
            });
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
                svg += `<g class="${cls}"><title>${esc(n.item)}：${n.count}</title>` +
                    `<circle class="body" cx="${X(p)}" cy="${Y(p)}" r="18"/>` +
                    `<text class="emo" x="${X(p)}" y="${Y(p) + 6}" text-anchor="middle">${EMOJI[n.item] || esc(n.item[0])}</text>` +
                    `<circle class="badge" cx="${X(p) + 14}" cy="${Y(p) + 13}" r="8.5"/>` +
                    `<text class="cnt" x="${X(p) + 14}" y="${Y(p) + 16.5}" text-anchor="middle">${n.count}</text></g>`;
            });
            svg += '</svg>';
            box.innerHTML = svg;
        }

        function drawHeader(s) {
            const t = $('header');
            const all = s.depth === 0 ? sortCanon(Object.keys(s.counts))
                : Object.keys(s.counts).sort((a, b) => s.counts[b] - s.counts[a] || cmp(a, b));
            if (!all.length) { t.innerHTML = ''; return; }
            const active = linkItem && s.header[linkItem] ? linkItem : s.item;
            const mining = s.depth > 0 || s.mining;
            t.innerHTML = `<caption>${s.depth === 0 ? '表頭（標準順序）' : '條件表頭（次數）'}</caption>` + all.map(i => {
                const ok = !mining || s.counts[i] >= minSup;
                const clickable = !!s.header[i];
                return `<tr class="${ok ? '' : 'out'}${clickable && i === active ? ' sel' : ''}" data-item="${clickable ? esc(i) : ''}"><td>${EMOJI[i] || ''}</td><td class="nm">${esc(i)}</td><td class="c">${s.counts[i]}</td></tr>`;
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

        /* CanTree 的順序 vs FP-tree 此刻的順序 */
        function drawOrders(s) {
            const emo = arr => arr.map(i => `${EMOJI[i] || ''}${esc(i)}`).join(' → ');
            $('ord-can').innerHTML = emo(ORDER) + '（固定）';
            const fp = s.fpOrder || [];
            const ref = s.kind === 'insert' && s.fpChanged ? s.oldOrder : null;
            $('ord-fp').innerHTML = fp.length
                ? fp.map((i, k) => `<span class="${ref && ref[k] !== i ? 'diff' : ''}">${EMOJI[i] || ''}${esc(i)}</span>`).join(' → ')
                : '<span style="color:var(--muted)">（還沒有交易）</span>';
            const w = $('ord-warn');
            w.className = 'ord-warn';
            let text = '', show = true;
            if (s.kind === 'insert' && s.isNew) {
                if (s.fpChanged) { w.classList.add('bad'); text = `⚠ FP-tree 這時候的順序已經不同（建樹時是 ${s.oldOrder.join('→')}），要整棵重建；CanTree 照插。`; }
                else { w.classList.add('ok'); text = '✓ 次數排名沒變，兩棵樹都只要沿路徑插。'; }
            } else if (s.kind === 'insert' || s.kind === 'ready' || s.kind === 'start') {
                text = '初始資料：CanTree 不必先數次數；FP-tree 要先掃一次才知道順序。';
            } else if (s.depth > 0) {
                text = `條件 FP-tree 照條件裡的次數排：${s.order.join('→') || '（沒有）'}`;
            } else {
                text = `新交易進來後，FP-tree 共要整棵重建 ${s.stats.rebuilds} 次；CanTree 0 次。`;
            }
            // 用 visibility 切換，不清空內容，框的高度才不會變
            w.textContent = text || ' ';
            w.style.visibility = show ? 'visible' : 'hidden';
        }

        function drawRows(s) {
            const box = $('rows');
            box.innerHTML = '';
            if (s.depth > 0) {
                $('data-title').textContent = `條件模式基底（後綴 ${fmt(s.suffix)}）`;
                s.rows.forEach((r, i) => {
                    const div = document.createElement('div');
                    div.className = 'row';
                    const items = r.path
                        ? r.path.map(x => `<span class="chip">${EMOJI[x] || ''}${esc(x)}</span>`).join('<span class="arrow">→</span>') +
                          r.items.filter(x => !r.path.includes(x)).map(x => ` <span class="chip out">${esc(x)}</span>`).join('')
                        : r.items.map(x => `<span class="chip">${EMOJI[x] || ''}${esc(x)}</span>`).join('<span class="arrow">→</span>');
                    div.innerHTML = `<span class="rid">#${i + 1}</span>${items}<span class="times">×${r.n}</span>`;
                    box.appendChild(div);
                });
                return;
            }
            $('data-title').textContent = '交易資料庫（照標準順序排）';
            const rows = allRows(), nInit = SAMPLE.length;
            rows.forEach((t, i) => {
                if (i === nInit) {
                    const sep = document.createElement('div');
                    sep.className = 'row-sep';
                    sep.textContent = `＋ 新交易（${rows.length - nInit} 筆）`;
                    box.appendChild(sep);
                }
                const div = document.createElement('div');
                const cur = s.kind === 'insert' && s.row === i;
                div.className = 'row' + (i >= nInit ? ' nw' : '') + (cur ? ' cur' : '') + (i >= s.ins ? ' todo' : '');
                div.innerHTML = `<span class="rid">${label(i, nInit)}</span>` +
                    sortCanon(t).map(x => `<span class="chip">${EMOJI[x] || ''}${esc(x)}</span>`).join('<span class="arrow">→</span>') +
                    (i >= nInit ? `<button class="del" data-del="${i - nInit}" aria-label="刪除新交易 +${i - nInit + 1}">✕</button>` : '');
                box.appendChild(div);
            });
            if (rows.length === nInit) {
                const sep = document.createElement('div');
                sep.className = 'row-sep';
                sep.textContent = '（還沒有新交易，在下面組幾筆）';
                box.appendChild(sep);
            }
        }

        function drawResult(s) {
            const box = $('levels');
            box.innerHTML = '';
            const N = allRows().length;
            $('result-note').textContent = !s.minedAt && !s.mining ? ''
                : s.mining && !s.minedAt ? `正在 ${s.ins} 筆交易上挖，最小支持度 ${minSup}`
                : `插完第 ${s.minedAt} 筆時挖的結果（最小支持度 ${minSup}）` + (s.ins > s.minedAt ? `；之後又插了 ${s.ins - s.minedAt} 筆，還沒重挖` : '');
            if (!s.result.length) {
                box.innerHTML = `<div class="empty">${s.minedAt ? '沒有任何樣式達到門檻。' : `還沒挖。CanTree 平常只管插入，要結果的時候（插完第 ${mineCount()} 筆）才挖。`}</div>`;
            }
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
            $('st-can').textContent = s.canNodes;
            $('st-fp').textContent = s.fpNodes;
            $('st-rebuild').textContent = s.stats.rebuilds;
            $('compare').innerHTML = `目前 ${s.ins} 筆交易：一般的 FP-tree 還會丟掉不到 ${minSup} 次的商品，只剩 <b>${s.fpNodesMin}</b> 個節點；` +
                `CanTree 全部商品都存（<b>${s.canNodes}</b> 個），換來的是門檻改了、次數變了都不用重建。`;
        }

        function drawCrumbs(s) {
            const box = $('crumbs');
            $('tree-title').textContent = s.depth === 0 ? 'CanTree' : `條件 FP-tree：後綴 ${fmt(s.suffix)}`;
            const crumbs = s.crumbs.length ? s.crumbs : [[]];
            box.innerHTML = (s.mining || s.depth > 0 ? '遞迴層：' : '插入中：') + crumbs.map((c, i) =>
                `<span class="crumb${i === crumbs.length - 1 ? ' cur' : ''}">${c.length ? esc(fmt(c)) : 'CanTree'}</span>`).join('<span class="arrow">›</span>');
        }

        /* ---------- 程式碼 ---------- */
        const KW = {
            java: new Set('public static final for if return new boolean int void class import while else null this continue'.split(' ')),
            py: new Set('def for in if return not and or while import from as True False None class is lambda continue'.split(' '))
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
                    if (lang === 'java' && /^[A-Z][a-z]/.test(word)) return `<span class="ty">${word}</span>`;
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
            // 只捲程式碼框本身，不捲整個頁面
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
                }
                const target = (y0 + y1) / 2 - pre.clientHeight / 2;
                pre.scrollTo({ top: Math.max(0, Math.min(target, y0 - 8)), behavior: 'smooth' });
            }
            $('downloads').innerHTML = lang === 'java'
                ? '下載 <a href="code/CanTree.java" download>CanTree.java</a>　執行 <code>javac CanTree.java && java CanTree</code>'
                : '下載 <a href="code/cantree.py" download>cantree.py</a>　執行 <code>python3 cantree.py</code>';
        }

        /* ---------- 組新交易 ---------- */
        function renderCompose() {
            const box = $('picks');
            box.innerHTML = '';
            ITEMS.forEach(i => {
                const b = document.createElement('button');
                b.type = 'button';
                b.className = 'pick' + (draft.has(i) ? ' on' : '');
                b.dataset.item = i;
                b.textContent = `${EMOJI[i]} ${i}`;
                b.setAttribute('aria-pressed', draft.has(i));
                box.appendChild(b);
            });
            const add = document.createElement('button');
            add.type = 'button';
            add.className = 'btn small';
            add.id = 'btn-add';
            add.textContent = '＋ 加入';
            add.disabled = !draft.size || batch.length >= MAX_BATCH;
            box.appendChild(add);
            [...$('presets').children].forEach((b, i) => b.classList.toggle('cur', i === presetUsed));
            $('btn-clear').disabled = !batch.length;
        }

        /* ---------- 顯示某一步 ---------- */
        function showStep() {
            const s = trace[cursor];
            linkItem = null;
            $('explain').innerHTML = `<span class="step-no">步驟 ${cursor + 1} / ${trace.length}</span>${describe(s)}`;
            drawCrumbs(s);
            drawOrders(s);
            drawTree(s);
            drawHeader(s);
            drawRows(s);
            drawResult(s);
            renderCode(CODE_TAGS(s));
            $('btn-prev').disabled = $('btn-first').disabled = cursor === 0;
            $('btn-next').disabled = cursor === trace.length - 1;
            $('sup-val').textContent = minSup;
            $('sup-minus').disabled = minSup <= 1;
            $('sup-plus').disabled = minSup >= mineCount();
            $('at-val').textContent = mineCount();
            $('at-minus').disabled = mineCount() <= 1;
            $('at-plus').disabled = mineCount() >= allRows().length;
            const here = (s.kind === 'insert' || s.kind === 'ready') && s.depth === 0 ? s.ins : 0;
            $('btn-mine-here').disabled = !here || here === mineCount();
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

        /* 說明框用這一輪最長的那段文字的高度固定住，下面的東西才不會跳來跳去 */
        function reserveExplainHeight() {
            quizReserve();   // 練習模式的題目框也要先預留高度，再量各區塊
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

        function rebuild(cursorTo) {
            stopAuto();
            minSup = Math.max(1, Math.min(minSup, mineCount()));
            trace = buildTrace(allRows(), SAMPLE.length, minSup, mineCount());
            cursor = typeof cursorTo === 'function' ? Math.max(0, cursorTo()) : Math.min(cursorTo || 0, trace.length - 1);
            renderCompose();
            showStep();
            reserveExplainHeight();
        }

        /* ---------- 操作 ---------- */
        /* =========================================================
           練習模式「猜下一步」（各 Demo 共用，規格見 tools/research/BRIEF.md）
           打開後按「下一步」：如果下一步有題目（quizFor 不是 null），先在說明框的位置疊一層題目，
           答完立刻顯示對錯和一句解釋，按「繼續」才真的前進。題目都從 trace 算出來，資料或門檻改了照樣能出題。
           ========================================================= */
        const QZ = { on: false, q: null, at: -1, picked: new Set(), answered: false, done: new Set(), right: 0, total: 0, trace: null };

        /* 固定種子的亂數：同一步每次出的題目都一樣，預留高度時量到的才會跟真的顯示的一致 */
        function quizRng(seed) {
            let a = (seed * 2654435761) >>> 0 || 1;
            return () => { a ^= a << 13; a >>>= 0; a ^= a >>> 17; a ^= a << 5; a >>>= 0; return a / 4294967296; };
        }
        const quizPick = (arr, rnd) => arr[Math.floor(rnd() * arr.length)];
        function quizShuffle(arr, rnd) {
            const a = arr.slice();
            for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; }
            return a;
        }
        /* 數字題：正確答案＋容易搞混的數字（traps）＋附近的數字，湊滿 4 個、由小到大排 */
        function quizNums(ans, lo, hi, rnd, traps = []) {
            const set = new Set([ans]);
            traps.forEach(v => { if (set.size < 4 && v >= lo && v <= hi) set.add(v); });
            for (let d = 1; set.size < 4 && d <= hi - lo; d++) {
                quizShuffle([ans + d, ans - d], rnd).forEach(v => { if (set.size < 4 && v >= lo && v <= hi) set.add(v); });
            }
            const nums = [...set].sort((a, b) => a - b);
            return { choices: nums.map(String), answer: nums.indexOf(ans) };
        }
        /* 文字選項：opts[0] 是正確的，其他是陷阱；去掉重複、打亂後回傳 choices 和正確的索引 */
        function quizOptions(opts, rnd) {
            const seen = new Set();
            const list = quizShuffle(opts.filter(o => !seen.has(o.text) && seen.add(o.text)).map((o, k) => ({ ...o, ok: k === 0 })), rnd);
            return { choices: list.map(o => o.text), answer: list.findIndex(o => o.ok) };
        }

        /* 複選題只剩一個選項時，改成「會／不會」二選一（q 是問句，例如「{咖啡, 牛奶} 會留下來嗎？」） */
        function quizSingle(multiQ, q) {
            return { ...multiQ, q, choices: ['會', '不會'], answer: multiQ.answer.length ? 0 : 1, multi: false, ask: { ...multiQ.ask, only: multiQ.choices } };
        }

        /* 把一題畫進 box（q、choices、why 都是純文字，一律用 textContent） */
        function quizRender(box, q) {
            box.innerHTML = '<div class="quiz-head"><span class="quiz-tag"></span><div class="quiz-actions">' +
                '<button type="button" class="btn quiz-ok">確定</button><button type="button" class="btn quiz-go">跳過</button></div></div>' +
                '<div class="quiz-body"><div class="quiz-text"></div><div class="quiz-why" aria-live="polite"><b class="quiz-verdict">✗ 不對喔</b><span></span></div></div>' +
                '<div class="quiz-choices"></div>';
            box.querySelector('.quiz-tag').textContent = q.multi ? '🎯 猜猜看（可複選）' : '🎯 猜猜看';
            box.querySelector('.quiz-text').textContent = q.q;
            const list = box.querySelector('.quiz-choices');
            const longest = Math.max(...q.choices.map(c => c.length));
            list.classList.add(longest > 12 ? 'wide' : longest > 4 ? 'half' : 'row');   // 長選項一行一個、短的兩欄、數字排一列
            q.choices.forEach((c, k) => {
                const b = document.createElement('button');
                b.type = 'button';
                b.className = 'quiz-choice';
                b.dataset.k = k;
                b.textContent = c;
                list.appendChild(b);
            });
            box.querySelector('.quiz-why span').textContent = q.why;
            box.querySelector('.quiz-ok').style.display = q.multi ? '' : 'none';
        }
        function quizOpen(q, at) {
            Object.assign(QZ, { q, at, picked: new Set(), answered: false });
            const box = $('quiz');
            box.classList.remove('done', 'miss', 'nudge');
            quizRender(box, q);
            box.hidden = false;
        }
        function quizClose() {
            QZ.q = null;
            QZ.at = -1;
            $('quiz').hidden = true;
        }
        function quizAnswer() {
            const q = QZ.q, want = new Set(q.multi ? q.answer : [q.answer]);
            const ok = want.size === QZ.picked.size && [...want].every(k => QZ.picked.has(k));
            QZ.answered = true;
            QZ.done.add(QZ.at);
            QZ.total++;
            if (ok) QZ.right++;
            const box = $('quiz');
            box.querySelectorAll('.quiz-choice').forEach(b => {
                const k = Number(b.dataset.k);
                b.classList.toggle('right', want.has(k));
                b.classList.toggle('wrong', QZ.picked.has(k) && !want.has(k));
                b.classList.toggle('missed', !!q.multi && want.has(k) && !QZ.picked.has(k));
                b.disabled = true;
            });
            box.querySelector('.quiz-verdict').textContent = ok ? '✓ 答對了！' : '✗ 不對喔';
            box.classList.add('done');
            box.classList.toggle('miss', !ok);
            box.querySelector('.quiz-go').textContent = '繼續 ▶';
            quizScore();
        }
        function quizScore() {
            $('quiz-score').textContent = `答對 ${QZ.right}/${QZ.total}`;
            $('quiz-score').style.visibility = QZ.on ? 'visible' : 'hidden';
            $('quiz-toggle').classList.toggle('quiz-on', QZ.on);
            $('quiz-toggle').setAttribute('aria-pressed', String(QZ.on));
        }

        /* 接在 step(dir) 最前面：回傳 true 表示「先別前進，題目還沒答」 */
        function quizGate(dir) {
            if (dir < 0 || !QZ.on) { quizClose(); return false; }
            if (QZ.q) {
                if (QZ.answered || QZ.at !== cursor + 1) { quizClose(); return false; }
                const box = $('quiz');
                box.classList.remove('nudge');
                void box.offsetWidth;          // 重新觸發動畫
                box.classList.add('nudge');
                return true;
            }
            const at = cursor + 1;
            if (at >= trace.length || QZ.done.has(at)) return false;
            const q = quizFor(trace[at], at);
            if (!q) return false;
            quizOpen(q, at);
            return true;
        }

        /* 題目框的高度：把這一輪每一題都畫一次，用最高的那題固定（關掉練習模式時也一樣預留，開關才不會推動下面） */
        function quizReserve() {
            if (QZ.trace !== trace) { QZ.trace = trace; QZ.done.clear(); quizClose(); }   // 資料或門檻改了，重新出題
            const host = $('quiz-host');
            if (!host.offsetWidth) return;
            const probe = document.createElement('div');
            probe.className = 'quiz done';
            probe.style.cssText = `position:absolute;visibility:hidden;left:-9999px;top:0;right:auto;bottom:auto;width:${host.offsetWidth}px`;
            document.body.appendChild(probe);
            let tallest = 0;
            trace.forEach((s, i) => {
                const q = quizFor(s, i);
                if (!q) return;
                quizRender(probe, q);
                tallest = Math.max(tallest, probe.offsetHeight);
            });
            probe.remove();
            host.style.minHeight = tallest ? tallest + 'px' : '';
        }

        $('quiz').addEventListener('click', e => {
            const q = QZ.q;
            if (!q) return;
            const c = e.target.closest('.quiz-choice');
            if (c && !QZ.answered) {
                const k = Number(c.dataset.k);
                if (!q.multi) { QZ.picked = new Set([k]); quizAnswer(); return; }
                if (QZ.picked.has(k)) QZ.picked.delete(k); else QZ.picked.add(k);
                c.classList.toggle('sel', QZ.picked.has(k));
                return;
            }
            if (e.target.closest('.quiz-ok') && !QZ.answered) { quizAnswer(); return; }
            if (e.target.closest('.quiz-go')) {
                if (!QZ.answered) QZ.done.add(QZ.at);   // 跳過：不計分，也不再問
                quizClose();
                $('btn-next').click();
            }
        });
        $('quiz-toggle').addEventListener('click', () => {
            QZ.on = !QZ.on;
            if (!QZ.on) quizClose();
            quizScore();
        });
        $('btn-first').addEventListener('click', quizClose);

        /* 第 i 步（s = trace[i]）要出的題目：{ q, choices, answer, why, multi?, ask? } 或 null。
           answer 是正確選項的索引（multi 時是索引陣列，可以是空的）；ask 只給 quiz_test.py 對答案用。 */
        function quizFor(s, i) {
            const rnd = quizRng(i + 1);
            switch (s.kind) {
                case 'insert': {
                    const n = s.newIds.length, len = s.path.length;
                    if (s.isNew && s.fpBuilt && (s.fpChanged || i % 2)) {
                        const prev = s.fpChanged ? s.oldOrder : s.fpBuilt;
                        return {
                            q: `第 ${s.row + 1} 筆「${arrowPath(s.path)}」插進 CanTree。同一筆如果是 FP-tree，要整棵重建嗎？`,
                            choices: ['要：照次數排的順序變了', '不用：順序沒變，直接插'], answer: s.fpChanged ? 0 : 1,
                            why: s.fpChanged ? `次數排名從「${arrowPath(prev)}」變成「${arrowPath(s.fpBuilt)}」，FP-tree 得重建；CanTree 用固定順序，不用。`
                                : `次數排名還是「${arrowPath(prev)}」，FP-tree 這次也能直接插。`,
                            ask: { type: 'rebuild', row: s.row }
                        };
                    }
                    return {
                        q: `第 ${s.row + 1} 筆照標準順序排成「${arrowPath(s.path)}」。插進 CanTree 要長出幾個新節點？`,
                        ...quizNums(n, 0, len, rnd, [len, 0]),
                        why: n === len ? `樹上沒有可以共用的前綴，${len} 個都是新節點。` : `前面 ${len - n} 個樹上已經有了，只要次數 +1；新長出 ${n} 個。`,
                        ask: { type: 'newNodes', row: s.row }
                    };
                }
                case 'pattern':
                case 'skip': {
                    if (s.depth !== 0) return null;
                    const sup = s.kind === 'skip' ? s.sup : s.counts[s.item];
                    const link = s.tree.filter(n => s.linkIds.includes(n.id));
                    const big = Math.max(...link.map(n => n.count));
                    return {
                        q: `挖 ${s.item}：把它節點鏈上的次數加起來，是幾次？`,
                        ...quizNums(sup, 0, s.ins, rnd, [link.length, big]),
                        why: `鏈上 ${link.length} 個節點：${link.map(n => n.count).join(' + ')} = ${sup}，` + (sup >= minSup ? `≥ ${minSup}，記下 {${s.item}}。` : `不到 ${minSup}，跳過（節點留在樹上）。`),
                        ask: { type: 'sup', set: [s.item], ins: s.ins }
                    };
                }
                case 'count': {
                    const its = Object.keys(s.counts).sort(cmp);
                    if (!its.length) return null;
                    const ok = x => s.counts[x] >= minSup;
                    const right = quizShuffle(its.filter(ok), rnd), wrong = quizShuffle(its.filter(x => !ok(x)), rnd);
                    const pick = quizShuffle([...right.slice(0, 2), ...wrong, ...right.slice(2)].slice(0, 4), rnd);
                    const mq = {
                        q: `條件模式基底數完次數（每條路徑乘上它的次數），哪些商品會留下來？（至少 ${minSup} 次）`, multi: true,
                        choices: pick, answer: pick.map((x, k) => (ok(x) ? k : -1)).filter(k => k >= 0),
                        why: pick.map(x => `${x} ${s.counts[x]} 次`).join('、') + `；記得每條路徑要乘上它的次數。`,
                        ask: { type: 'cond', suffix: s.suffix, ins: s.ins, sets: pick }
                    };
                    return pick.length === 1 ? quizSingle(mq, `後綴 ${fmt(s.suffix)} 的條件模式基底裡，${pick[0]} 會留下來嗎？`) : mq;
                }
            }
            return null;
        }

        function step(dir) {
            if (quizGate(dir)) return false;   // 練習模式：下一步有題目時先答題
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
        const firstMine = () => trace.findIndex(s => s.kind === 'mine');
        // 門檻只影響「挖」：改了之後跳到開始挖的那一步
        $('sup-minus').addEventListener('click', () => { if (minSup > 1) { minSup--; rebuild(firstMine); } });
        $('sup-plus').addEventListener('click', () => { if (minSup < mineCount()) { minSup++; rebuild(firstMine); } });
        $('at-minus').addEventListener('click', () => { mineAt = Math.max(1, mineCount() - 1); rebuild(firstMine); });
        $('at-plus').addEventListener('click', () => {
            mineAt = Math.min(allRows().length, mineCount() + 1);
            if (mineAt === allRows().length) mineAt = null;
            rebuild(firstMine);
        });
        $('btn-mine-here').addEventListener('click', () => {
            const s = trace[cursor];
            mineAt = s.ins === allRows().length ? null : s.ins;
            rebuild(firstMine);
        });

        $('picks').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b) return;
            if (b.id === 'btn-add') {
                if (!draft.size || batch.length >= MAX_BATCH) return;
                batch.push(sortCanon([...draft]));
                draft = new Set();
                presetUsed = -1;
                if (mineAt === null || mineAt > allRows().length) mineAt = null;
                rebuild(() => trace.length - 1 - [...trace].reverse().findIndex(s => s.kind === 'insert'));
                return;
            }
            const item = b.dataset.item;
            if (draft.has(item)) draft.delete(item); else draft.add(item);
            renderCompose();
        });
        $('rows').addEventListener('click', e => {
            const del = e.target.closest('[data-del]');
            if (!del) return;
            batch.splice(Number(del.dataset.del), 1);
            presetUsed = -1;
            if (mineAt !== null && mineAt >= allRows().length) mineAt = null;
            rebuild(0);
        });
        PRESETS.forEach((p, i) => {
            const b = document.createElement('button');
            b.type = 'button';
            b.className = 'btn small';
            b.textContent = p.label;
            b.addEventListener('click', () => {
                batch = p.rows.map(r => r.slice());
                presetUsed = i;
                mineAt = null;
                rebuild(() => trace.findIndex(s => s.kind === 'ready'));
            });
            $('presets').appendChild(b);
        });
        $('btn-clear').addEventListener('click', () => { batch = []; presetUsed = -1; mineAt = null; rebuild(0); });
        $('btn-reset').addEventListener('click', () => { reset(); });

        function reset() {
            batch = PRESETS[0].rows.map(r => r.slice());
            presetUsed = 0;
            draft = new Set();
            minSup = 3;
            mineAt = null;
            rebuild(0);
        }

        $('lang').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b) return;
            lang = b.dataset.lang;
            [...$('lang').children].forEach(x => x.classList.toggle('active', x === b));
            renderCode(CODE_TAGS(trace[cursor]));
        });
        let resizeTimer = null;
        window.addEventListener('resize', () => { clearTimeout(resizeTimer); resizeTimer = setTimeout(reserveExplainHeight, 150); });

        reset();
    </script>
</body>

</html>
