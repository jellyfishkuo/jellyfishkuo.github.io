<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/top-k-hui.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/top-k-hui-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/top-k-hui-180.png">
    <title>Top-k 高效益樣式探勘</title>
    <meta name="description" content="不用猜門檻，直接要效益最高的前 k 名：一步一步看 TKO 怎麼在 HUI-Miner 的 utility list 上，用最小堆積維護前 k 名、邊挖邊把門檻往上調、剪枝越來越狠，Java 與 Python 程式碼逐行對照，並比較早知道門檻時要做多少事。">
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
        .intro { color: #c6c6d6; max-width: 800px; margin-top: 0.9rem; font-size: 0.95rem; }
        .intro b { color: var(--text); }
        .intro a { color: var(--accent2); }

        /* 手機：一欄，依序 步驟 → 前 k 名 → 交易 → utility list → 搜尋樹 → 程式碼 → 統計
           電腦：左欄 步驟／交易／utility list，右欄 前 k 名／搜尋樹／程式碼／統計 */
        .layout { display: grid; gap: 1rem; margin-top: 1.3rem; align-items: start; }
        .col { display: contents; }
        .layout .card { min-width: 0; }
        .a-step { order: 1; }
        .a-board { order: 2; }
        .a-data { order: 3; }
        .a-lists { order: 4; }
        .a-tree { order: 5; }
        .a-code { order: 6; }
        .a-result { order: 7; }
        @media (min-width: 960px) {
            .layout { grid-template-columns: 1fr 1.05fr; }
            .col { display: grid; gap: 1rem; align-content: start; min-width: 0; }
        }

        .card {
            background: var(--panel);
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 1rem;
        }
        .card-head { display: flex; justify-content: space-between; align-items: center; gap: 0.3rem 0.6rem; flex-wrap: wrap; margin-bottom: 0.7rem; }
        .card-head h2 { margin: 0; }
        .sub { color: var(--muted); font-size: 0.8rem; }

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
        .mu { display: flex; align-items: center; gap: 0.45rem; flex-wrap: wrap; font-size: 0.88rem; margin-top: 0.75rem; }
        .mu .val { font: 700 1rem 'Space Mono', monospace; min-width: 2.2em; text-align: center; }
        .mu input[type=range] { flex: 1 1 140px; min-width: 0; accent-color: var(--accent); }
        .mu .pct { color: var(--muted); font-size: 0.78rem; }
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

        /* ── 交易資料庫 ── */
        .db { width: 100%; table-layout: fixed; border-collapse: separate; border-spacing: 0 3px; }
        /* 欄寬固定：商品欄平分，不會因為「茶葉蛋」「洋芋片」三個字就比較寬 */
        .db th.tid-h { width: 2rem; }
        .db th.tu-h { width: 2.4rem; }
        .db th { font-weight: 400; color: var(--muted); font-size: clamp(0.6rem, 3vw, 0.72rem); white-space: nowrap; padding: 0 1px 4px; text-align: center; line-height: 1.25; vertical-align: bottom; }
        .db th .emo { display: block; font-size: 1.2rem; }
        .db th .pf { display: block; font: 700 0.7rem 'Space Mono', monospace; color: #fcd34d; margin-top: 0.1rem; }
        .db th.sel { color: var(--warn); }
        .db th.off, .db td.twu.out { opacity: 0.4; }
        .db th.off .nm { text-decoration: line-through; }
        .db td { text-align: center; padding: 0; }
        .db td.tid { font: 0.76rem 'Space Mono', monospace; color: var(--muted); text-align: left; width: 2.4em; padding-left: 0.3rem; }
        .db td.tu { font: 700 0.78rem 'Space Mono', monospace; color: var(--accent2); width: 2.8em; }
        .db td.tu.sel, .db th.tu-h.sel { color: var(--warn); }
        .db tr.cur td, .db tr.match td { background: rgba(245, 158, 11, 0.12); }
        .db tr.cur td:first-child, .db tr.match td:first-child { border-radius: 8px 0 0 8px; color: var(--warn); }
        .db tr.cur td:last-child, .db tr.match td:last-child { border-radius: 0 8px 8px 0; }
        .db tr.later { opacity: 0.55; }
        .db tfoot td { font: 700 0.72rem 'Space Mono', monospace; color: var(--accent2); padding-top: 0.35rem; border-top: 1px dashed var(--border); }
        .db tfoot td.tid { color: var(--muted); }
        .db tfoot td.twu.out { color: var(--bad); text-decoration: line-through; opacity: 1; }
        .cell {
            width: 30px;
            min-height: 30px;
            margin: 0 auto;
            border-radius: 8px;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            font: 700 0.85rem/1.1 'Space Mono', monospace;
        }
        .cell.has { background: #2a2a48; }
        .cell.off { opacity: 0.35; text-decoration: line-through; }
        .cell.hit { background: rgba(245, 158, 11, 0.38); }
        .cell small { font-size: 0.62rem; font-weight: 400; color: #fcd34d; }
        .db-note { color: var(--muted); font-size: 0.78rem; margin-top: 0.5rem; }

        /* ── utility list ── */
        .uls { display: flex; flex-wrap: wrap; gap: 0.6rem; align-items: flex-start; min-height: 120px; }
        .uls-empty { color: var(--muted); font-size: 0.85rem; align-self: center; }
        .ul { background: #0a0a14; border: 1px solid var(--border); border-radius: 10px; padding: 0.4rem 0.5rem 0.45rem; min-width: 112px; }
        .ul.res { border-color: var(--accent2); box-shadow: 0 0 0 1px var(--accent2) inset; }
        .ul.focus { border-color: var(--warn); }
        .ul-h { display: flex; align-items: baseline; gap: 0.35rem; font-size: 0.8rem; margin-bottom: 0.2rem; }
        .ul-h .role { font: 700 0.7rem 'Space Mono', monospace; color: var(--accent2); }
        .ul table { border-collapse: collapse; font: 0.74rem 'Space Mono', monospace; width: 100%; }
        .ul th { color: var(--muted); font-weight: 400; text-align: right; padding: 0 0.3rem; font-size: 0.68rem; }
        .ul th:first-child, .ul td:first-child { text-align: left; }
        .ul td { padding: 0.05rem 0.3rem; text-align: right; }
        .ul tr.dim td { opacity: 0.3; }
        .ul tr.new td { background: rgba(34, 197, 94, 0.18); }
        .ul tr.ex td { background: rgba(245, 158, 11, 0.22); color: #fde68a; }
        .ul tr.sum td { border-top: 1px solid var(--border); font-weight: 700; color: var(--accent2); }
        .ul-f { font-size: 0.7rem; color: var(--muted); margin-top: 0.2rem; }
        .ul-f b { font-family: 'Space Mono', monospace; color: var(--text); }
        .ul-f b.ok { color: #86efac; }
        .ul-f b.no { color: #fca5a5; }
        .op { align-self: center; color: var(--muted); font: 700 1rem 'Space Mono', monospace; }

        /* ── 搜尋樹 ── */
        .tree { position: relative; max-height: 540px; overflow: auto; background: #0a0a14; border: 1px solid var(--border); border-radius: 10px; padding: 0.5rem 0.6rem; min-height: 140px; }
        .tree-empty { color: var(--muted); font-size: 0.85rem; padding: 1.5rem 0.5rem; text-align: center; }
        .tr, .tr ul { list-style: none; }
        .tr ul { margin-left: 0.6rem; }
        .tr li { position: relative; }
        .tr ul > li { padding-left: 1rem; }
        .tr ul > li::before { content: ''; position: absolute; left: 0; top: 0; bottom: 0; border-left: 1.5px solid #34345a; }
        .tr ul > li:last-child::before { bottom: auto; height: 1.05rem; }
        .tr ul > li::after { content: ''; position: absolute; left: 0; top: 1.05rem; width: 0.85rem; border-top: 1.5px solid #34345a; }
        .tn {
            display: inline-flex; flex-wrap: wrap; align-items: center; gap: 0.1rem 0.5rem;
            padding: 0.15rem 0.5rem; margin: 0.15rem 0; border: 1px solid var(--border); border-radius: 8px;
            background: var(--panel-2); font-size: 0.82rem; max-width: 100%;
        }
        .tn .v { font: 0.72rem 'Space Mono', monospace; color: var(--muted); }
        .tn .v b { color: var(--text); }
        .tn .tag { font-size: 0.72rem; border-radius: 5px; padding: 0 0.35rem; background: #23233d; color: var(--muted); }
        .tn.root { color: var(--muted); }
        .tn.wait, .tn.built { border-style: dashed; }
        .tn.wait .n { color: var(--muted); }
        .tn.hui { border-color: rgba(34, 197, 94, 0.6); }
        .tn.hui .tag { background: rgba(34, 197, 94, 0.22); color: #86efac; }
        .tn.go .tag { background: rgba(6, 182, 212, 0.15); color: #67e8f9; }
        .tn.cut { border-color: rgba(248, 113, 113, 0.5); }
        .tn.cut .tag { background: rgba(248, 113, 113, 0.18); color: #fca5a5; }
        .tn.cut .n, .tn.empty .n { text-decoration: line-through; color: var(--muted); }
        .tn.empty { opacity: 0.6; border-style: dashed; }
        .tn.cur { box-shadow: 0 0 0 2px var(--warn); }
        .tn.src { box-shadow: 0 0 0 2px rgba(6, 182, 212, 0.7); }
        .legend { display: flex; flex-wrap: wrap; gap: 0.3rem 0.9rem; font-size: 0.75rem; color: var(--muted); margin-top: 0.55rem; }
        .legend i { display: inline-block; width: 11px; height: 11px; border-radius: 3px; border: 2px solid; margin-right: 0.3rem; vertical-align: -1px; }

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
            max-height: 520px;
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
        .stats { display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.5rem; margin-top: 0.9rem; }
        @media (min-width: 600px) { .stats { grid-template-columns: repeat(4, 1fr); } }
        .stat { background: var(--panel-2); border-radius: 10px; padding: 0.55rem 0.6rem; }
        .stat .v { font: 700 1.25rem 'Space Mono', monospace; }
        .stat .k { color: var(--muted); font-size: 0.75rem; line-height: 1.35; }
        .compare { margin-top: 0.9rem; font-size: 0.85rem; color: var(--muted); }
        .compare h3 { font-size: 0.9rem; color: var(--text); margin-bottom: 0.45rem; }
        .compare a { color: var(--accent2); }
        .cmp-row { display: grid; grid-template-columns: 7em 1fr; gap: 0.5rem; margin-top: 0.4rem; align-items: start; }
        .cmp-row .lbl { font-size: 0.78rem; padding-top: 0.15rem; }
        .cmp-row .items { display: flex; flex-wrap: wrap; gap: 0.3rem; }
        .cp { font-size: 0.8rem; color: var(--text); border: 1px solid var(--border); border-radius: 7px; padding: 0.08rem 0.45rem; }
        .cp small { font: 0.7rem 'Space Mono', monospace; color: var(--muted); margin-left: 0.3rem; }
        .cp.both { border-color: rgba(34, 197, 94, 0.5); }
        .cp.hui { border-color: rgba(245, 158, 11, 0.6); }
        .cp.freq { border-style: dashed; }

        .notes { margin-top: 1rem; display: grid; gap: 1rem; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr; } }
        .notes p, .notes li { color: #c6c6d6; font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; margin-top: 0.5rem; }
        .notes b { color: var(--text); }
        .notes a { color: var(--accent2); }

        /* ── 前 k 名排行榜 ── */
        .mu-now { display: flex; align-items: baseline; gap: 0.5rem; flex-wrap: wrap; font-size: 0.85rem; color: var(--muted); }
        .mu-now b { font: 700 1.5rem 'Space Mono', monospace; color: #fca5a5; }
        .mu-now .up { font: 700 0.8rem 'Space Mono', monospace; color: var(--warn); visibility: hidden; }
        .mu-now .up.on { visibility: visible; }
        .chart { position: relative; height: 86px; margin: 0.4rem 0 0.2rem 2.4rem; border-left: 1px solid var(--border); border-bottom: 1px solid var(--border); }
        .chart svg { position: absolute; inset: 0; width: 100%; height: 100%; overflow: visible; }
        .chart .yl { position: absolute; left: -2.5rem; width: 2.2rem; text-align: right; font: 0.66rem 'Space Mono', monospace; color: var(--muted); transform: translateY(-50%); }
        .chart .dot { position: absolute; width: 9px; height: 9px; border-radius: 50%; background: var(--warn); transform: translate(-50%, 50%); box-shadow: 0 0 0 3px rgba(245, 158, 11, 0.25); }
        .chart-x { display: flex; justify-content: space-between; margin-left: 2.4rem; font-size: 0.68rem; color: var(--muted); }
        .board { display: grid; gap: 0.25rem; margin-top: 0.7rem; }
        .rk { display: grid; grid-template-columns: 1.9rem minmax(0, 1fr) 3rem; gap: 0.4rem; align-items: center; font-size: 0.82rem; border-radius: 7px; padding: 0.12rem 0.3rem; }
        .rk .no { font: 700 0.75rem 'Space Mono', monospace; color: var(--accent2); text-align: right; }
        .rk .bar { position: relative; min-width: 0; padding: 0.08rem 0.4rem; border-radius: 6px; overflow: hidden; }
        .rk .bar i { position: absolute; left: 0; top: 0; bottom: 0; background: rgba(124, 58, 237, 0.35); border-radius: 6px; }
        .rk .bar span { position: relative; display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .rk .u { font: 700 0.8rem 'Space Mono', monospace; text-align: right; color: #86efac; }
        .rk.fresh { box-shadow: 0 0 0 2px var(--warn); }
        .rk.kth .u { color: #fca5a5; }
        .rk.slot .bar span { color: var(--muted); }
        .rk.slot .u { color: var(--muted); }
        .rk.gone { opacity: 0.6; }
        .rk.gone .bar span { text-decoration: line-through; }
        .rk.gone .bar i { background: rgba(248, 113, 113, 0.25); }
        .rk.gone .u, .rk.gone .no { color: var(--bad); }
        .kline { display: flex; align-items: center; gap: 0.4rem; font-size: 0.72rem; color: #fca5a5; }
        .kline::before, .kline::after { content: ''; flex: 1; border-top: 1px dashed rgba(248, 113, 113, 0.6); }
        .heap { margin-top: 0.6rem; font-size: 0.78rem; color: var(--muted); display: flex; flex-wrap: wrap; gap: 0.3rem; align-items: center; }
        .heap .hv { font: 0.74rem 'Space Mono', monospace; border: 1px solid var(--border); border-radius: 5px; padding: 0 0.35rem; color: var(--text); }
        .heap .hv.min { border-color: rgba(248, 113, 113, 0.7); color: #fca5a5; }
        .tn.doomed { border-color: rgba(248, 113, 113, 0.4); border-style: dashed; }
        .tn.doomed .tag { background: rgba(248, 113, 113, 0.12); color: #fca5a5; }
        .tn.out .tag { background: #23233d; color: var(--muted); text-decoration: line-through; }
        .tn .late { font-size: 0.66rem; color: var(--warn); margin-left: 0.25rem; }
        .db tfoot tr.single td { color: #86efac; padding-top: 0.15rem; border-top: none; }
        .db tfoot tr.single td.kth { color: var(--warn); text-decoration: underline; }
        .cmp { width: 100%; border-collapse: collapse; font-size: 0.8rem; margin-top: 0.5rem; }
        .cmp th, .cmp td { padding: 0.3rem 0.35rem; border-bottom: 1px solid var(--border); text-align: right; }
        .cmp th { color: var(--muted); font-weight: 400; font-size: 0.72rem; }
        .cmp th:first-child, .cmp td:first-child { text-align: left; }
        .cmp td { font-family: 'Space Mono', monospace; }
        .cmp td:first-child { font-family: inherit; color: var(--text); }
        .cmp tr.me td { color: var(--warn); }
        .cmp-wrap { overflow-x: auto; }
    </style>
</head>

<body>
    <div class="wrap">
        <a class="back" href="../index.html#research">← RETURN TO PORTFOLIO</a>
        <div class="kicker">RESEARCH DEMO · TOP-K HIGH-UTILITY ITEMSET MINING</div>
        <h1>Top-k 高效益樣式探勘<small>不用猜門檻，直接要前 k 名</small></h1>
        <p class="intro">
            在 <a href="high-utility.html">HUI-Miner</a> 那頁，你要先給一個「最小效益門檻」。可是門檻該設多少？設太高什麼都找不到，設太低一次跑出一大堆，
            通常得試好幾次。<b>Top-k 高效益樣式探勘</b>換個問法：<b>直接告訴我效益最高的前 k 名</b>。
            這頁示範 <b>TKO</b> 的做法：一樣用 HUI-Miner 的 utility list，只是門檻從 0（或用單一商品的效益先墊高）開始，
            旁邊放一個<b>最多裝 k 個的最小堆積</b>，裝滿之後，堆積裡最小的那個（第 k 名）就是新門檻。越挖門檻越高，剪枝也跟著越來越狠。
            資料和 HUI-Miner 頁一樣：同一間超商的 8 筆交易，記了每樣買幾個和每樣賺多少。
        </p>

        <div class="layout">
            <div class="col">
                <div class="card a-step">
                    <div class="player">
                        <button class="btn" id="btn-first" title="回到開頭">⏮</button>
                        <button class="btn" id="btn-prev">◀ 上一步</button>
                        <button class="btn primary" id="btn-next">下一步 ▶</button>
                        <button class="btn" id="btn-play">▶ 自動播放</button>
                    </div>
                    <div class="mu">
                        <span>要前幾名 k</span>
                        <button class="btn stepper" id="k-minus" aria-label="減少">−</button>
                        <span class="val" id="k-val">6</span>
                        <button class="btn stepper" id="k-plus" aria-label="增加">+</button>
                        <input type="range" id="k-range" min="1" max="15" step="1" value="6" aria-label="要前幾名 k">
                        <span class="pct" id="k-pct"></span>
                    </div>
                    <div class="explain" id="explain"></div>
                </div>

                <div class="card a-data">
                    <div class="card-head"><h2>交易資料庫</h2><span class="sub" id="db-sub"></span></div>
                    <table class="db" id="db"></table>
                    <p class="db-note">格子裡是購買數量，商品下面是單位利潤；TU 是這筆交易的總效益，TWU 是有買這個商品的交易 TU 加起來，「單品」是這個商品自己的效益。</p>
                </div>

                <div class="card a-lists">
                    <div class="card-head"><h2>Utility list</h2><span class="sub" id="ul-sub"></span></div>
                    <div class="uls" id="uls"></div>
                </div>
            </div>

            <div class="col">
                <div class="card a-board">
                    <div class="card-head"><h2>目前的前 k 名</h2><span class="sub" id="board-sub"></span></div>
                    <div class="mu-now">門檻 minUtil <b id="mu-now">0</b><span class="up" id="mu-up">↑</span></div>
                    <div class="chart" id="chart"></div>
                    <div class="chart-x"><span>開始</span><span>步驟 →</span><span>結束</span></div>
                    <div class="board" id="board"></div>
                    <div class="heap" id="heap"></div>
                </div>

                <div class="card a-tree">
                    <div class="card-head"><h2>搜尋樹（集合列舉樹）</h2><span class="sub">每往下一層多加一個商品</span></div>
                    <div class="tree" id="tree"></div>
                    <div class="legend">
                        <span><i style="border-color:var(--warn)"></i>這一步</span>
                        <span><i style="border-color:var(--good)"></i>在榜上</span>
                        <span><i style="border-color:var(--bad)"></i>被剪掉</span>
                        <span><i style="border-color:var(--bad);border-style:dashed"></i>上界已低於門檻</span>
                        <span><i style="border-color:#3a3a5a;border-style:dashed"></i>還沒檢查</span>
                    </div>
                    <p class="legend" style="margin-top:0.3rem">效益 = Σiutil，上界 = Σiutil + Σrutil。標「↑新門檻」的是門檻升高之後才剪得掉的分支。</p>
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
                    <h2>過程統計</h2>
                    <div class="stats">
                        <div class="stat"><div class="v" id="st-check">0</div><div class="k">檢查過的組合</div></div>
                        <div class="stat"><div class="v" id="st-lists">0</div><div class="k">建立的 utility list</div></div>
                        <div class="stat"><div class="v" id="st-raise">0</div><div class="k">門檻往上調的次數</div></div>
                        <div class="stat"><div class="v" id="st-prune">0</div><div class="k">被上界剪掉的分支</div></div>
                    </div>
                    <div class="compare" id="compare"></div>
                </div>
            </div>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼邊挖邊調門檻不會漏掉？</h2>
                <p>關鍵是：<b>程式裡的門檻，永遠不會超過真正的第 k 名效益</b>。</p>
                <ul>
                    <li><b>預先提升：</b>單一商品本身就是一個組合。第 k 大的單品效益是 X，代表已經有 k 個組合效益 ≥ X，真正的第 k 名一定 ≥ X。所以一開始就把門檻設成 X 是安全的。</li>
                    <li><b>挖的時候提升：</b>堆積裡的 k 個效益都是真的組合算出來的。堆積滿了，最小的那個就是「目前看過的第 k 名」，真正的第 k 名只會更高、不會更低。</li>
                    <li><b>剪枝一樣安全：</b>門檻 ≤ 真正的第 k 名，所以「上界 &lt; 門檻」的分支，裡面每個組合都比第 k 名低，不可能進榜。上界（TWU、Σiutil + Σrutil）跟 <a href="high-utility.html">HUI-Miner</a> 用的完全一樣。</li>
                    <li><b>平手怎麼算：</b>跟第 k 名同分的組合<b>全部列出</b>，所以結果可能比 k 個多（預設 k = 6 時，第 6、7 名都是 250，兩個都列）。這樣結果跟搜尋順序無關，固定是「效益 ≥ 第 k 名效益的所有組合」。
                        也因為這樣，剪枝要用嚴格的「&lt;」，跟門檻同分的還得留著。出現過的組合不到 k 個時，就全部列出。</li>
                </ul>
            </div>
            <div class="card">
                <h2>代價、其他做法，以及實驗室在做的事</h2>
                <ul>
                    <li><b>省掉猜門檻，但多做一點事：</b>門檻是慢慢爬上去的，一開始門檻低，剪得比較少。結果區最下面比較了「早就知道門檻」的 HUI-Miner 要建幾張 list，Top-k 多花了多少。
                        先挖哪裡也有差：越早碰到效益高的組合，門檻越早升上去。</li>
                    <li><b>TKU（兩階段版）：</b>比 TKO 早的 TKU 建在 UP-Tree 上，跟 <a href="two-phase.html">Two-Phase</a> 一樣先用上界找候選、再掃一次資料庫算真正的效益；
                        它用好幾招（例如先用單品、用樹上節點的效益）把門檻墊高。TKO 改用 utility list，一次就算出真正的效益，不用第二階段。</li>
                    <li><b>更多提升門檻的招：</b>TKO 論文還有在搜尋時依上界大小決定先挖哪個分支（先挖最有希望的）等策略；之後的 kHMC、TKEH 等方法用商品兩兩一起出現的效益，一開始就把門檻墊得更高。</li>
                    <li><b>和實驗室研究的關係：</b>資料一直在變的時候，第 k 名也會變。增量／資料串流上的 top-k 高效益樣式，要在新增或刪除交易後，只調整受影響的部分，同時把門檻維持在安全的位置。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           Top-k 高效益樣式探勘（TKO 的做法）一步一步看
           網頁裡用 JavaScript 照著同樣的流程跑一次，把每一步（含每一層遞迴）記下來；
           右邊的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = /*CODE_JSON*/null;

        const ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片'];
        const EMOJI = { '咖啡': '☕', '麵包': '🍞', '牛奶': '🥛', '飯糰': '🍙', '茶葉蛋': '🥚', '洋芋片': '🥔' };
        const PROFIT = { '咖啡': 30, '麵包': 15, '牛奶': 20, '飯糰': 10, '茶葉蛋': 5, '洋芋片': 25 };
        /* 跟 HUI-Miner 頁同樣的 8 筆交易（數量） */
        const DB = [
            { '咖啡': 4, '麵包': 2, '牛奶': 2 },
            { '咖啡': 3, '麵包': 5, '茶葉蛋': 4 },
            { '咖啡': 1, '麵包': 1, '牛奶': 2, '飯糰': 2 },
            { '麵包': 3, '牛奶': 4, '洋芋片': 5 },
            { '咖啡': 3, '牛奶': 2, '茶葉蛋': 2 },
            { '咖啡': 1, '麵包': 2, '牛奶': 1, '茶葉蛋': 1 },
            { '飯糰': 1, '茶葉蛋': 2, '洋芋片': 2 },
            { '咖啡': 1, '麵包': 2, '飯糰': 1 }
        ];
        const K_MIN = 1, K_MAX = 15;

        const $ = id => document.getElementById(id);
        let topK = 6;
        let lang = 'java';
        let trace = [];
        let cursor = 0;
        let timer = null;
        let costs = null;              // 頁尾比較用：早知道門檻的 HUI-Miner、不預先提升的 Top-k

        /* 跟 Java 的 compareTo、Python 的字串比較同一個順序（依字碼） */
        const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
        const esc = x => String(x).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
        const fmt = set => esc('{' + set.join(', ') + '}');
        const arrowPath = items => esc(items.join(' → '));
        const tName = tid => 'T' + (tid + 1);
        const keyOf = items => items.join('|');
        const has = (t, item) => Object.prototype.hasOwnProperty.call(t, item);

        /* ---------- 照著程式跑一次，記下每一步 ----------
           opts.fixed：給一個固定門檻、永遠不調（就是 HUI-Miner），頁尾比較用
           opts.riu = false：不預先提升，門檻從 0 開始 */
        function buildTrace(db, profit, k, opts = {}) {
            const fixed = opts.fixed !== undefined && opts.fixed !== null;
            const cap = fixed ? Infinity : k;
            const steps = [];
            const nodes = [];
            const nodeById = new Map();
            const stats = { scans: 0, lists: 0, checked: 0, pruned: 0, raises: 0 };
            const st = { tu: [], twu: {}, single: {}, order: [], removed: [], twuCalc: false, twuDone: false };
            let mu = 0, mu0 = 0;
            let heap = [];                     // 只放效益，最多 k 個（這裡用排好序的陣列代替最小堆積，heap[0] 最小）
            let board = [];                    // 效益 >= 門檻的組合 {set, util, fresh, seq}
            let seq = 0;

            const addNode = (items, par, extra) => {
                const n = { id: keyOf(items), items, par, ...extra };
                nodes.push(n);
                nodeById.set(n.id, n);
                return n;
            };
            const push = (kind, extra = {}) => {
                steps.push({
                    kind, ...extra, mu, mu0,
                    stats: { ...stats },
                    result: board.map(r => ({ ...r })),
                    heap: heap.slice(),
                    nodes: nodes.map(n => ({ ...n })),
                    tu: st.tu.slice(), twu: { ...st.twu }, single: { ...st.single }, order: st.order.slice(), removed: st.removed.slice(),
                    twuCalc: st.twuCalc, twuDone: st.twuDone
                });
                board.forEach(r => { r.fresh = false; });
            };
            const offer = (items, util) => {
                board.push({ set: items, util, fresh: true, seq: seq++ });
                heap.push(util);
                heap.sort((a, b) => a - b);
                if (heap.length > cap) heap.shift();             // 超過 k 個，把最小的踢掉
                if (heap.length === cap && heap[0] > mu) {       // 堆積滿了：第 k 名的效益就是新門檻
                    const from = mu;
                    mu = heap[0];
                    stats.raises++;
                    const gone = board.filter(r => r.util < mu);
                    board = board.filter(r => r.util >= mu);
                    return { from, to: mu, gone };
                }
                return null;
            };

            push('start');

            // 1. 第 1 次掃描：TU、TWU、單一商品的效益
            stats.scans++;
            st.tu = db.map(t => Object.keys(t).reduce((a, i) => a + t[i] * profit[i], 0));
            push('tu');
            db.forEach((t, r) => Object.keys(t).forEach(i => {
                st.twu[i] = (st.twu[i] || 0) + st.tu[r];
                st.single[i] = (st.single[i] || 0) + t[i] * profit[i];
            }));
            st.twuCalc = true;
            push('twu');

            // 預先提升門檻（RIU）：第 k 大的單品效益
            const singles = Object.values(st.single).sort((a, b) => b - a);
            if (fixed) mu = opts.fixed;
            else if (opts.riu !== false && singles.length >= k) mu = singles[k - 1];
            mu0 = mu;
            push('riu', { singles, applied: !fixed && opts.riu !== false && singles.length >= k });

            const byTwu = (a, b) => st.twu[a] - st.twu[b] || cmp(a, b);
            st.order = Object.keys(st.twu).filter(i => st.twu[i] >= mu).sort(byTwu);
            st.removed = Object.keys(st.twu).filter(i => st.twu[i] < mu).sort(byTwu);
            st.twuDone = true;
            st.order.forEach(i => addNode([i], '', { st: 'wait' }));
            st.removed.forEach(i => addNode([i], '', { st: 'twu', twu: st.twu[i] }));
            push('cut');

            // 2. 第 2 次掃描：建每個商品的 utility list
            stats.scans++;
            const lists = st.order.map(i => ({ items: [i], rows: [], iu: 0, ru: 0 }));
            db.forEach((t, tid) => {
                let rutil = 0;
                const info = [];
                for (let j = st.order.length - 1; j >= 0; j--) {
                    const item = st.order[j];
                    if (!has(t, item)) continue;
                    const u = t[item] * profit[item];
                    lists[j].rows.push([tid, u, rutil]);
                    lists[j].iu += u;
                    lists[j].ru += rutil;
                    info.unshift({ item, q: t[item], u, ru: rutil });
                    rutil += u;
                }
                if (tid === db.length - 1) {
                    stats.lists += lists.length;
                    lists.forEach(l => Object.assign(nodeById.get(keyOf(l.items)), { st: 'built', iu: l.iu, ru: l.ru }));
                }
                push('row', {
                    tid, info, dropped: Object.keys(t).filter(i => st.removed.includes(i)),
                    uls: lists.map(l => ({ ul: { items: l.items, rows: l.rows.slice(), iu: l.iu, ru: l.ru }, newTid: tid }))
                });
            });

            // 3. 深度優先搜尋，邊找邊調門檻
            function construct(p, px, py) {
                const items = [...px.items, py.items[py.items.length - 1]];
                const yRow = new Map(py.rows.map(r => [r[0], r]));
                const pRow = p ? new Map(p.rows.map(r => [r[0], r])) : null;
                const xy = { items, rows: [], iu: 0, ru: 0 };
                px.rows.forEach(([tid, iuX]) => {
                    const ry = yRow.get(tid);
                    if (!ry) return;                                  // 這筆交易沒有 y
                    const iu = iuX + ry[1] - (p ? pRow.get(tid)[1] : 0);
                    xy.rows.push([tid, iu, ry[2]]);
                    xy.iu += iu;
                    xy.ru += ry[2];
                });
                return xy;
            }
            let first = true;
            function search(p, uls) {
                for (let i = 0; i < uls.length; i++) {
                    const x = uls[i];
                    const node = nodeById.get(keyOf(x.items));
                    const before = mu;
                    const offered = x.iu >= mu;
                    const raised = offered ? offer(x.items, x.iu) : null;
                    const prune = x.iu + x.ru < mu;
                    const later = uls.slice(i + 1).map(y => y.items[y.items.length - 1]);
                    stats.checked++;
                    if (prune && later.length) stats.pruned++;
                    Object.assign(node, { st: 'done', offered, prune, leaf: !later.length, cutAt: mu });
                    push('check', { x, p, later, offered, raised, prune, before, first, full: heap.length >= cap, cur: node.id });
                    first = false;
                    if (prune) continue;
                    const ext = [];
                    for (let j = i + 1; j < uls.length; j++) {
                        const y = uls[j];
                        const xy = construct(p, x, y);
                        const empty = !xy.rows.length;
                        addNode(xy.items, node.id, empty ? { st: 'empty' } : { st: 'built', iu: xy.iu, ru: xy.ru });
                        if (!empty) { stats.lists++; ext.push(xy); }
                        push('construct', { p, x, y, xy, empty, cur: keyOf(xy.items), srcs: [node.id, keyOf(y.items)] });
                    }
                    search(x, ext);
                }
            }
            search(null, lists);
            push('end');
            return steps;
        }

        /* ---------- 對照用：直接列舉每個組合 ---------- */
        function allUtils() {
            const out = [];
            for (let m = 1; m < (1 << ITEMS.length); m++) {
                const set = ITEMS.filter((_, i) => m >> i & 1);
                const u = DB.filter(t => set.every(i => has(t, i))).reduce((a, t) => a + set.reduce((b, i) => b + t[i] * PROFIT[i], 0), 0);
                if (u > 0) out.push(u);
            }
            return out;
        }
        const ALL_COUNT = allUtils().length;

        /* ---------- 說明文字 ---------- */
        const qp = (t, items) => items.map(i => `${t[i]}×${PROFIT[i]}`).join(' + ');
        function describe(s) {
            const k = topK;
            switch (s.kind) {
                case 'start':
                    return `HUI-Miner 要你先給門檻，可是設多少才好？太高什麼都找不到，太低一次跑出一大堆。這次換個問法：<b>直接要效益最高的前 ${k} 名</b>。` +
                        `門檻 minUtil 由程式自己決定：從 0 開始，邊挖邊往上調。<b>平手規則</b>：跟第 ${k} 名同分的全部列出，所以結果可能比 ${k} 個多。`;
                case 'tu': {
                    const r = s.tu.indexOf(Math.max(...s.tu));
                    return `第 1 次掃描資料庫：先算每筆交易的總效益 <b>TU</b>（表格最右邊那欄）。例如 ${tName(r)} = ${qp(DB[r], Object.keys(DB[r]))} = ${s.tu[r]}，是最賺的一筆。`;
                }
                case 'twu': {
                    const i = Object.keys(s.single).sort((a, b) => s.single[b] - s.single[a] || cmp(a, b))[0];
                    const ks = DB.map((t, r) => r).filter(r => has(DB[r], i));
                    return `同一次掃描順便算兩樣（表格最下面兩列）：每個商品的 <b>TWU</b>（有買它的交易 TU 加起來，是含它的組合效益的上界），` +
                        `以及每個商品<b>自己的效益</b>。例如 ${esc(i)}：${ks.map(r => `${DB[r][i]}×${PROFIT[i]}`).join(' + ')} = ${s.single[i]}，是單品裡最賺的。`;
                }
                case 'riu': {
                    if (!s.applied) return `單一商品本身就是組合，本來可以拿「第 ${k} 大的單品效益」當起始門檻；可是出現過的商品只有 ${s.singles.length} 個，湊不滿 ${k} 個，` +
                        `這招用不上，<b>門檻從 0 開始</b>，只能等搜尋時把堆積裝滿再往上調。`;
                    return `<b>預先提升門檻</b>：單一商品本身就是組合，它們的效益剛算好，由大到小是 ${s.singles.join('、')}。第 ${k} 大的是 <b>${s.mu}</b>，` +
                        `代表至少已經有 ${k} 個組合效益 ≥ ${s.mu}，真正的第 ${k} 名不可能比它低。所以門檻不用從 0 開始，<b>直接從 0 提升到 ${s.mu}</b>。`;
                }
                case 'cut': {
                    let t = '';
                    if (s.removed.length) t += s.removed.map(i => `${esc(i)} 的 TWU 只有 ${s.twu[i]}`).join('、') + ` < 門檻 ${s.mu}，含它的組合都不可能進榜，<b>整個刪掉</b>。`;
                    else if (s.mu === 0) t += `門檻還是 0，用 TWU 刪不掉任何商品。`;
                    else t += `每個商品的 TWU 都至少 ${s.mu}，這次沒有商品被刪掉。`;
                    t += `${s.removed.length ? '剩下的' : '全部'}照 TWU 由小到大排成 <b>${arrowPath(s.order)}</b>，表格的欄也照這個順序排。`;
                    return t;
                }
                case 'row': {
                    const label = tName(s.tid);
                    const drop = s.dropped.length ? `${esc(s.dropped.join('、'))} 已經被刪掉，不放進 list，也不算進 rutil。` : '';
                    if (!s.info.length) return `第 2 次掃描：${label} 裡沒有留下來的商品，跳過。${drop}`;
                    const f = s.info[0], rest = s.info.slice(1);
                    return `第 2 次掃描（跟 HUI-Miner 一樣）：${label} 照順序排成 ${arrowPath(s.info.map(x => x.item))}，每個商品在自己的 utility list 加一列 (tid, iutil, rutil)：` +
                        `<b>iutil</b> 是它自己在這筆的效益，<b>rutil</b> 是<b>排在它後面</b>的商品效益加起來。例如 ${esc(f.item)}：iutil = ${f.q}×${PROFIT[f.item]} = ${f.u}，` +
                        (rest.length > 1 ? `rutil = ${rest.map(x => x.u).join(' + ')} = ${f.ru}。` : rest.length ? `rutil = ${f.ru}。` : `後面沒有商品，rutil = 0。`) + drop;
                }
                case 'check': {
                    const { x } = s, ub = x.iu + x.ru;
                    let t = `檢查 ${fmt(x.items)}：效益 ${x.iu}`;
                    if (!s.offered) t += ` < 門檻 ${s.before}，進不了榜。`;
                    else {
                        t += ` ≥ 門檻 ${s.before}，<b>放進前 ${k} 名</b>`;
                        if (s.raised) {
                            t += `。堆積裝滿 ${k} 個了，最小的（第 ${k} 名）是 ${s.raised.to}，<b>門檻從 ${s.raised.from} 提升到 ${s.raised.to}</b>`;
                            if (s.raised.gone.length) t += `，${s.raised.gone.map(r => fmt(r.set)).join('、')} 被擠出榜外`;
                            t += '。';
                        } else if (!s.full) t += `（堆積還沒滿，門檻先不動）。`;
                        else t += `（跟第 ${k} 名同分，一起留在榜上，門檻不變）。`;
                    }
                    const later = esc(s.later.join('、'));
                    if (!s.later.length) t += `後面沒有商品可以再加，到此為止。`;
                    else if (s.prune) {
                        t += `上界 ${x.iu} + ${x.ru} = ${ub} < 門檻 ${s.mu}，再加後面的 ${later} 也進不了榜，<b>整個分支剪掉</b>。`;
                        if (ub >= s.mu0) t += `如果門檻還停在一開始的 ${s.mu0}，這裡剪不掉，還得往下合併 ${s.later.length} 次。`;
                    } else t += `上界 ${x.iu} + ${x.ru} = ${ub} ≥ 門檻 ${s.mu}，還有機會，往下展開：跟 ${later} ${s.later.length > 1 ? '各' : ''}合併一次。`;
                    return t;
                }
                case 'construct': {
                    const { x, y, xy, p } = s;
                    const pair = `${fmt(x.items)} 和 ${fmt(y.items)}`;
                    if (s.empty) return `合併 ${pair}：兩張 list 沒有共同的交易（這幾樣從來沒有一起被買過），${fmt(xy.items)} 的 list 是空的，直接丟掉。`;
                    const tids = xy.rows.map(r => tName(r[0])).join('、');
                    const tid = xy.rows[0][0];
                    const a = x.rows.find(r => r[0] === tid)[1], b = y.rows.find(r => r[0] === tid)[1];
                    const ub = xy.iu + xy.ru;
                    const tail = `得到 ${fmt(xy.items)}：效益 ${xy.iu}、上界 ${ub}` + (ub < s.mu ? `，已經低於門檻 ${s.mu}，輪到它時就會被剪。` : '。');
                    if (!p) return `合併 ${pair}：兩邊都有的交易是 ${tids}。每筆的 iutil 直接相加，例如 ${tName(tid)}：${a} + ${b} = ${a + b}；rutil 照抄 ${fmt(y.items)} 的。${tail}`;
                    const c = p.rows.find(r => r[0] === tid)[1];
                    return `合併 ${pair}（共同前綴 P = ${fmt(p.items)}）：兩邊都有的交易是 ${tids}。兩邊的 iutil 都含有 P 的效益，<b>扣掉 P 的一次</b>，` +
                        `例如 ${tName(tid)}：${a} + ${b} − ${c} = ${a + b - c}。${tail}`;
                }
                case 'end': {
                    const n = s.result.length;
                    let t = `完成！門檻從 ${s.mu0} 一路升到 <b>${s.mu}</b>，`;
                    if (ALL_COUNT < k) t = `完成！出現過的組合只有 ${ALL_COUNT} 個，不到 ${k} 個，<b>全部列出</b>。`;
                    else t += n > k ? `榜上有 <b>${n}</b> 個（第 ${k} 名有人同分，一起列出）。` : `榜上正好 <b>${k}</b> 個。`;
                    t += `一共檢查 ${s.stats.checked} 個組合、建了 ${s.stats.lists} 張 utility list、門檻調了 ${s.stats.raises} 次。`;
                    if (ALL_COUNT >= k) t += `如果在 <a href="high-utility.html">HUI-Miner</a> 頁把門檻設成 ${s.mu}，會得到一模一樣的結果；下面比較多花了多少。`;
                    return t;
                }
            }
            return '';
        }

        const CODE_TAGS = s => {
            switch (s.kind) {
                case 'check': return ['check', 'prune'].concat(s.offered ? ['offer'] : [], s.raised ? ['raise'] : [], s.first ? ['search0'] : []);
                case 'construct': return ['call', 'construct'];
                case 'row': return ['scan'];
                case 'twu': return ['tu'];
                case 'cut': return ['twu'];
                default: return [s.kind];        // start / tu / riu / end
            }
        };

        /* ---------- 畫面 ---------- */
        function focusOf(s) {
            if (s.kind === 'check') return { tids: new Set(s.x.rows.map(r => r[0])), items: new Set(s.x.items) };
            if (s.kind === 'construct') return { tids: new Set(s.xy.rows.map(r => r[0])), items: new Set(s.xy.items) };
            return { tids: new Set(), items: new Set() };
        }

        function drawDB(s) {
            const cols = s.twuDone ? [...s.order, ...s.removed, ...ITEMS.filter(i => !(i in s.twu))] : ITEMS;
            const f = focusOf(s);
            const off = i => s.removed.includes(i);
            let h = '<thead><tr><th class="tid-h"></th>' + cols.map(i =>
                `<th class="${off(i) ? 'off' : ''}${f.items.has(i) ? ' sel' : ''}"><span class="emo">${EMOJI[i]}</span><span class="nm">${esc(i)}</span><span class="pf">$${PROFIT[i]}</span></th>`).join('') +
                `<th class="tu-h${s.kind === 'tu' ? ' sel' : ''}">TU</th></tr></thead><tbody>`;
            DB.forEach((t, r) => {
                const cur = s.kind === 'row' && s.tid === r;
                const match = f.tids.has(r);
                const cls = [cur ? 'cur' : '', match ? 'match' : '', s.kind === 'row' && r > s.tid ? 'later' : ''].join(' ');
                h += `<tr class="${cls}"><td class="tid">${tName(r)}</td>` + cols.map(i => {
                    if (!has(t, i)) return '<td><div class="cell"></div></td>';
                    const showU = cur && !off(i);
                    return `<td><div class="cell has${off(i) ? ' off' : ''}${match && f.items.has(i) ? ' hit' : ''}">${t[i]}${showU ? `<small>${t[i] * PROFIT[i]}</small>` : ''}</div></td>`;
                }).join('') + `<td class="tu${s.kind === 'tu' ? ' sel' : ''}">${s.tu.length ? s.tu[r] : ''}</td></tr>`;
            });
            h += '</tbody>';
            if (s.twuCalc) {
                // 預先提升那一步，把「第 k 大的單品」標出來
                let kth = null;
                if (s.kind === 'riu' && s.applied) kth = Object.keys(s.single).sort((a, b) => s.single[b] - s.single[a] || cmp(a, b))[topK - 1];
                h += '<tfoot><tr><td class="tid">TWU</td>' + cols.map(i => `<td class="twu${off(i) ? ' out' : ''}">${i in s.twu ? s.twu[i] : ''}</td>`).join('') + '<td></td></tr>' +
                    '<tr class="single"><td class="tid">單品</td>' + cols.map(i => `<td class="${i === kth ? 'kth' : ''}">${i in s.single ? s.single[i] : ''}</td>`).join('') + '<td></td></tr></tfoot>';
            }
            $('db').innerHTML = h;
            $('db-sub').textContent = s.twuDone ? '欄已照 TWU 由小到大排' : '';
        }

        /* 一張 utility list 的小表格 */
        function ulBox(ul, mu, { role = '', cls = '', newTid = -1, keep = null, ex = -1, verdict = false } = {}) {
            const rows = ul.rows.map(([tid, iu, ru]) => {
                const c = tid === ex ? 'ex' : tid === newTid ? 'new' : keep && !keep.has(tid) ? 'dim' : '';
                return `<tr class="${c}"><td>${tName(tid)}</td><td>${iu}</td><td>${ru}</td></tr>`;
            }).join('');
            const ub = ul.iu + ul.ru;
            const foot = verdict
                ? `效益 <b class="${ul.iu >= mu ? 'ok' : 'no'}">${ul.iu}</b> · 上界 <b class="${ub >= mu ? 'ok' : 'no'}">${ub}</b>`
                : `上界 <b>${ub}</b>`;
            return `<div class="ul ${cls}"><div class="ul-h">${role ? `<span class="role">${role}</span>` : ''}<span>${fmt(ul.items)}</span></div>` +
                `<table><tr><th>tid</th><th>iutil</th><th>rutil</th></tr>${rows || '<tr><td colspan="3" style="color:var(--muted)">（空）</td></tr>'}` +
                `<tr class="sum"><td>Σ</td><td>${ul.iu}</td><td>${ul.ru}</td></tr></table><div class="ul-f">${foot}</div></div>`;
        }

        function drawLists(s) {
            const box = $('uls');
            const sub = $('ul-sub');
            if (s.kind === 'row') {
                sub.textContent = `第 2 次掃描，讀到 ${tName(s.tid)}`;
                box.innerHTML = s.uls.length ? s.uls.map(x => ulBox(x.ul, s.mu, { newTid: x.newTid })).join('') : '<div class="uls-empty">沒有商品留下來，不用建 list。</div>';
            } else if (s.kind === 'check') {
                sub.textContent = `檢查 ${'{' + s.x.items.join(', ') + '}'}（門檻 ${s.mu}）`;
                box.innerHTML = ulBox(s.x, s.mu, { cls: 'focus', verdict: true });
            } else if (s.kind === 'construct') {
                const keep = new Set(s.xy.rows.map(r => r[0]));
                const ex = s.xy.rows.length ? s.xy.rows[0][0] : -1;
                const pre = s.p ? 'P' : '';
                sub.textContent = '合併出 ' + '{' + s.xy.items.join(', ') + '}';
                box.innerHTML = ulBox(s.x, s.mu, { role: pre + 'x', keep, ex }) + '<span class="op">+</span>' + ulBox(s.y, s.mu, { role: pre + 'y', keep, ex }) +
                    (s.p ? '<span class="op">−</span>' + ulBox(s.p, s.mu, { role: 'P', keep, ex }) : '') +
                    '<span class="op">→</span>' + ulBox(s.xy, s.mu, { role: pre + 'xy', cls: 'res', ex });
            } else if (s.kind === 'end') {
                sub.textContent = '';
                box.innerHTML = '<div class="uls-empty">搜尋結束。按「上一步」可以回頭看每一張 list 是怎麼合併出來的。</div>';
            } else {
                sub.textContent = '';
                box.innerHTML = `<div class="uls-empty">${s.kind === 'cut' ? '下一步開始第 2 次掃描，替每個留下來的商品建一張 list。' : '第 1 次掃描算完、決定好門檻和商品順序之後，第 2 次掃描才開始建。'}</div>`;
            }
        }

        function nodeView(n, s, inBoard) {
            const last = n.items[n.items.length - 1];
            let cls = n.st, tag = '', late = '';
            const ub = n.iu + n.ru;
            switch (n.st) {
                case 'wait': tag = '等第 2 次掃描建 list'; break;
                case 'built':
                    if (ub < s.mu) { cls = 'doomed'; tag = `上界 ${ub} < 門檻 ${s.mu}`; }
                    else tag = '待檢查';
                    break;
                case 'empty': tag = '沒有共同交易，丟掉'; break;
                case 'twu': cls = 'cut'; tag = `✂ TWU ${n.twu} < ${s.mu0}`; break;
                case 'done':
                    if (n.offered && inBoard.has(n.id)) { cls = 'hui'; tag = '★ 在榜上'; }
                    else if (n.offered) { cls = 'out'; tag = '進過榜，被擠掉'; }
                    if (n.prune && !n.leaf) {
                        if (!n.offered) cls = 'cut';
                        tag += (tag ? ' · ' : '') + `✂ 上界 ${ub} < ${n.cutAt}`;
                        if (ub >= s.mu0) late = '<span class="late">↑新門檻</span>';
                    } else if (!n.offered) {
                        if (n.leaf) { cls = 'low'; tag = '沒進榜，後面也沒商品'; }
                        else { cls = 'go'; tag = '沒進榜，但上界夠，往下找'; }
                    }
                    break;
            }
            if (n.id === s.cur) cls += ' cur';
            else if (s.srcs && s.srcs.includes(n.id)) cls += ' src';
            const vals = n.iu !== undefined ? `<span class="v">效益 <b>${n.iu}</b> · 上界 ${ub}</span>` : '';
            return `<div class="tn ${cls}" data-id="${esc(n.id)}" title="${esc('{' + n.items.join(', ') + '}')}"><span class="n">${n.items.length > 1 ? '＋' : ''}${EMOJI[last] || ''}${esc(last)}</span>${vals}<span class="tag">${tag}${late}</span></div>`;
        }

        function drawTree(s) {
            const box = $('tree');
            if (!s.twuDone) {
                box.innerHTML = '<div class="tree-empty">決定好門檻和商品的順序之後，這裡會長出搜尋樹。</div>';
                return;
            }
            const inBoard = new Set(s.result.map(r => keyOf(r.set)));
            const kids = {};
            s.nodes.forEach(n => { (kids[n.par] = kids[n.par] || []).push(n); });
            const li = n => `<li>${nodeView(n, s, inBoard)}${kids[n.id] ? `<ul>${kids[n.id].map(li).join('')}</ul>` : ''}</li>`;
            box.innerHTML = `<ul class="tr"><li><div class="tn root">∅ 從空集合開始</div><ul>${(kids[''] || []).map(li).join('')}</ul></li></ul>`;
            // 只捲樹的框，讓這一步的節點留在看得到的地方
            const el = box.querySelector('.tn.cur');
            if (el && !measuringBlocks) {
                const y = el.getBoundingClientRect().top - box.getBoundingClientRect().top + box.scrollTop;
                if (y < box.scrollTop + 10 || y + el.offsetHeight > box.scrollTop + box.clientHeight - 10) {
                    box.scrollTo({ top: Math.max(0, y - box.clientHeight / 2), behavior: 'smooth' });
                }
            }
        }

        /* 排行榜：榜上的組合 + 空位 + 這一步被擠掉的；下面是堆積裡的效益 */
        function drawBoard(s) {
            const k = topK;
            $('mu-now').textContent = s.mu;
            const prev = cursor > 0 ? trace[cursor - 1].mu : s.mu;
            $('mu-up').textContent = `↑ 從 ${prev} 升上來`;
            $('mu-up').classList.toggle('on', s.mu > prev);
            $('board-sub').textContent = `k = ${k}，同分的一起列`;
            drawChart(s);

            const box = $('board');
            box.innerHTML = '';
            const maxU = Math.max(1, ...trace[trace.length - 1].result.map(r => r.util), ...s.result.map(r => r.util));
            const rows = s.result.slice().sort((a, b) => b.util - a.util || a.seq - b.seq);
            const full = s.heap.length >= k;
            const addRow = (no, cls, text, util, w) => {
                const row = document.createElement('div');
                row.className = 'rk ' + cls;
                row.innerHTML = '<span class="no"></span><span class="bar"><i></i><span></span></span><span class="u"></span>';
                row.querySelector('.no').textContent = no;
                row.querySelector('.bar i').style.width = w + '%';
                row.querySelector('.bar span').textContent = text;
                row.querySelector('.u').textContent = util;
                box.appendChild(row);
            };
            rows.forEach((r, i) => {
                const rank = rows.findIndex(o => o.util === r.util) + 1;   // 同分同名次
                const kth = full && r.util === s.mu;
                addRow(rank, (r.fresh ? 'fresh ' : '') + (kth ? 'kth' : ''), '{' + r.set.join(', ') + '}', r.util, r.util / maxU * 100);
                if (i === k - 1 && full && rows.length > k) {
                    const line = document.createElement('div');
                    line.className = 'kline';
                    line.textContent = `第 ${k} 名，下面是同分的`;
                    box.appendChild(line);
                }
            });
            for (let i = rows.length; i < k; i++) addRow(i + 1, 'slot', '（空位）', '', 0);
            if (s.kind === 'check' && s.raised && s.raised.gone.length) {
                s.raised.gone.forEach(r => addRow('✕', 'gone', '{' + r.set.join(', ') + '}', r.util, r.util / maxU * 100));
            }
            if (ALL_COUNT < k && s.kind === 'end') {
                const line = document.createElement('div');
                line.className = 'kline';
                line.textContent = `出現過的組合只有 ${ALL_COUNT} 個`;
                box.appendChild(line);
            }

            const hp = $('heap');
            hp.innerHTML = '';
            const lab = document.createElement('span');
            lab.textContent = `最小堆積（${s.heap.length}/${k}，只存效益）：`;
            hp.appendChild(lab);
            if (!s.heap.length) {
                const e = document.createElement('span');
                e.textContent = '空的';
                hp.appendChild(e);
            }
            s.heap.forEach((u, i) => {
                const v = document.createElement('span');
                v.className = 'hv' + (i === 0 && full ? ' min' : '');
                v.textContent = u;
                hp.appendChild(v);
            });
            if (full) {
                const e = document.createElement('span');
                e.textContent = `← 最小的 ${s.heap[0]} 就是門檻`;
                hp.appendChild(e);
            }
        }

        /* 門檻隨步驟變化的折線（階梯狀），只畫到目前這一步 */
        function drawChart(s) {
            const box = $('chart');
            const n = trace.length;
            const hi = Math.max(1, trace[n - 1].mu);
            const X = i => (n > 1 ? i / (n - 1) * 100 : 0);
            const Y = v => 100 - v / hi * 100;
            let d = `M ${X(0)} ${Y(trace[0].mu)}`;
            for (let i = 1; i <= cursor; i++) d += ` L ${X(i)} ${Y(trace[i - 1].mu)} L ${X(i)} ${Y(trace[i].mu)}`;
            const fin = Y(trace[n - 1].mu);
            box.innerHTML = `<svg viewBox="0 0 100 100" preserveAspectRatio="none">` +
                `<line x1="0" y1="${fin}" x2="100" y2="${fin}" stroke="#4a4a6a" stroke-dasharray="3 3" vector-effect="non-scaling-stroke"/>` +
                `<path d="${d}" fill="none" stroke="#f87171" stroke-width="2" vector-effect="non-scaling-stroke"/></svg>` +
                `<span class="yl" style="top:${fin}%">${trace[n - 1].mu}</span><span class="yl" style="top:100%">0</span>` +
                `<span class="dot" style="left:${X(cursor)}%;bottom:${100 - Y(s.mu)}%"></span>`;
        }

        function drawResult(s) {
            $('st-check').textContent = s.stats.checked;
            $('st-lists').textContent = s.stats.lists;
            $('st-raise').textContent = s.stats.raises;
            $('st-prune').textContent = s.stats.pruned;
            drawCompare(s);
        }

        /* 跟「早就知道門檻」的 HUI-Miner、以及不預先提升的 Top-k 比較 */
        function drawCompare(s) {
            const box = $('compare');
            if (s.kind !== 'end') {
                box.innerHTML = `全部做完之後，這裡會比較：如果<b>事先就知道</b>正確門檻，<a href="high-utility.html">HUI-Miner</a> 要做多少事，Top-k 多花了多少。`;
                return;
            }
            const me = s.stats, hm = costs.fixed, zero = costs.zero;
            const row = (cls, label, mu0, st) => `<tr class="${cls}"><td>${label}</td><td>${mu0}</td><td>${st.checked}</td><td>${st.lists}</td></tr>`;
            const extra = me.lists - hm.lists;
            box.innerHTML = `<h3>多花了多少？</h3><div class="cmp-wrap"><table class="cmp"><tr><th>做法</th><th>起始門檻</th><th>檢查的組合</th><th>建的 list</th></tr>` +
                row('', `HUI-Miner（早知道門檻 = ${s.mu}）`, s.mu, hm) +
                row('me', 'Top-k（這一頁）', s.mu0, me) +
                (s.mu0 > 0 ? row('', 'Top-k，不預先提升', 0, zero) : '') + '</table></div>' +
                `<p style="margin-top:0.5rem">` + (extra > 0
                    ? `跟早知道門檻比，Top-k 多建了 <b>${extra}</b> 張 utility list（多 ${Math.round(extra / Math.max(1, hm.lists) * 100)}%），這就是「不用猜門檻」的代價：門檻是一路爬上去的，前面剪得比較少。`
                    : `這次 Top-k 跟早知道門檻做的事一樣多：門檻很早就升到位了。`) +
                (s.mu0 > 0 && zero.lists > me.lists ? `如果不先用單品效益把門檻墊高，還要再多建 ${zero.lists - me.lists} 張。` : '') + `</p>`;
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
                ? '下載 <a href="code/TopKHUI.java" download>TopKHUI.java</a>　執行 <code>javac TopKHUI.java && java TopKHUI</code>'
                : '下載 <a href="code/top_k_hui.py" download>top_k_hui.py</a>　執行 <code>python3 top_k_hui.py</code>';
        }

        /* ---------- 顯示某一步 ---------- */
        function showStep() {
            const s = trace[cursor];
            $('explain').innerHTML = `<span class="step-no">步驟 ${cursor + 1} / ${trace.length}</span>${describe(s)}`;
            drawDB(s);
            drawLists(s);
            drawBoard(s);
            drawTree(s);
            drawResult(s);
            renderCode(CODE_TAGS(s));
            $('btn-prev').disabled = $('btn-first').disabled = cursor === 0;
            $('btn-next').disabled = cursor === trace.length - 1;
            $('k-val').textContent = topK;
            $('k-range').value = topK;
            $('k-minus').disabled = topK <= K_MIN;
            $('k-plus').disabled = topK >= K_MAX;
            $('k-pct').textContent = `（出現過的組合共 ${ALL_COUNT} 個）`;
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
            trace = buildTrace(DB, PROFIT, topK);
            const fin = trace[trace.length - 1];
            costs = {
                fixed: buildTrace(DB, PROFIT, topK, { fixed: fin.mu }).pop().stats,
                zero: buildTrace(DB, PROFIT, topK, { riu: false }).pop().stats
            };
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
        function setK(v) {
            v = Math.max(K_MIN, Math.min(K_MAX, v));
            if (v === topK) return;
            topK = v;
            rebuild();
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
            if (e.target.tagName === 'INPUT') return;      // 在滑桿上按左右鍵是調 k
            if (e.key === 'ArrowRight') { stopAuto(); step(1); }
            if (e.key === 'ArrowLeft') { stopAuto(); step(-1); }
        });
        $('k-minus').addEventListener('click', () => setK(topK - 1));
        $('k-plus').addEventListener('click', () => setK(topK + 1));
        $('k-range').addEventListener('input', e => setK(Number(e.target.value)));
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
