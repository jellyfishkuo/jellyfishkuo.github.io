<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/periodic.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/periodic-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/periodic-180.png">
    <title>週期性頻繁樣式探勘（PFP-tree）</title>
    <meta name="description" content="一步一步看 PFP-tree 怎麼找出「夠常出現、而且出現得夠規律」的商品組合：算每個組合的支持度與最大週期、建樹時把 tid 記在尾節點、挖的時候把 tid 往上交，Java 與 Python 程式碼逐行對照。">
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

        /* 兩欄（手機一欄）：左邊 步驟 → 時間軸 → 資料；右邊 樹 → 程式碼 → 結果 */
        .layout { display: grid; gap: 1rem; margin-top: 1.3rem; }
        .layout > * { min-width: 0; display: grid; gap: 1rem; align-content: start; }
        .layout > * > * { min-width: 0; }
        @media (min-width: 960px) { .layout { grid-template-columns: 1fr 1.05fr; } }

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
        button.btn.on { border-color: var(--warn); color: var(--warn); }

        .player { display: flex; flex-wrap: wrap; gap: 0.4rem; align-items: center; }
        .params { display: flex; flex-wrap: wrap; gap: 0.5rem 1.4rem; margin-top: 0.75rem; }
        .minsup { display: flex; align-items: center; gap: 0.45rem; font-size: 0.88rem; }
        .minsup .val { font: 700 1rem 'Space Mono', monospace; min-width: 1.4em; text-align: center; }
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

        /* ── 時間軸：一格一筆交易，下面的括號是相鄰兩次出現的間隔 ── */
        .tl-list { display: grid; gap: 0.35rem; align-content: start; }
        .tl-row {
            display: grid;
            grid-template-columns: 4.6rem minmax(0, 1fr) 3.6rem;
            grid-template-areas: "lbl tl nums";
            gap: 0.5rem;
            align-items: center;
            padding: 0.25rem 0.35rem;
            border-radius: 8px;
            border: 1px solid transparent;
        }
        @media (max-width: 520px) {
            .tl-row { grid-template-columns: minmax(0, 1fr) auto; grid-template-areas: "lbl nums" "tl tl"; gap: 0.15rem 0.5rem; }
        }
        .tl-row .lbl { grid-area: lbl; font-size: 0.82rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .tl-row .nums { grid-area: nums; font: 0.7rem/1.35 'Space Mono', monospace; color: var(--muted); text-align: right; white-space: nowrap; }
        .tl-row .nums b { color: var(--text); font-size: 0.82rem; }
        .tl-row .nums b.bad { color: var(--bad); }
        .tl-row.focus { border-color: var(--warn); background: var(--lt-f59e0b-7, rgba(245, 158, 11, 0.07)); }
        .tl-row.part { opacity: 0.75; }
        .tl-row.part .lbl { color: var(--muted); }
        .tl-row.drop { opacity: 0.45; }
        .tl-row.drop .lbl { text-decoration: line-through; }
        .tl {
            grid-area: tl;
            display: grid;
            grid-template-columns: repeat(var(--n), minmax(0, 1fr));
            column-gap: 2px;
            row-gap: 3px;
            max-width: calc(var(--n) * 26px);
            width: 100%;
        }
        .tl .c {
            grid-row: 1;
            aspect-ratio: 1;
            border-radius: 4px;
            border: 1px solid var(--lt-24243a, #24243a);
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
            font: 700 min(0.6rem, 2.6vw)/1 'Space Mono', monospace;
            color: transparent;
        }
        .tl .c.on { background: var(--lt-06b6d4-25, rgba(6, 182, 212, 0.25)); border-color: var(--lt-06b6d4-65, rgba(6, 182, 212, 0.65)); color: var(--lt-a5f3fc, #a5f3fc); }
        .tl .c.cur { box-shadow: 0 0 0 2px var(--warn); }
        .tl .g {
            grid-row: 2;
            height: 14px;
            border: 1.5px solid var(--lt-3a3a5a, #3a3a5a);
            border-top: none;
            border-radius: 0 0 5px 5px;
            font: min(0.6rem, 2.6vw)/12px 'Space Mono', monospace;
            color: var(--muted);
            text-align: center;
            overflow: hidden;
        }
        .tl .g.max { border-color: var(--warn); color: var(--warn); font-weight: 700; }
        .tl .g.bad { border-color: var(--bad); color: var(--bad); font-weight: 700; }
        .tl-empty { color: var(--muted); font-size: 0.85rem; padding: 0.3rem 0; }
        .vnote { color: var(--muted); font-size: 0.78rem; margin-top: 0.6rem; }
        .vnote .w { color: var(--warn); }
        .vnote .r { color: var(--bad); }
        .tl-sub { font-size: 0.85rem; color: var(--muted); margin-bottom: 0.4rem; min-height: 1.4em; }
        .tl-sub b { color: var(--text); font-weight: 600; }

        /* ── 樹 ── */
        .crumbs { display: flex; flex-wrap: wrap; gap: 0.3rem; align-items: center; font-size: 0.8rem; color: var(--muted); margin-bottom: 0.5rem; min-height: 1.6rem; }
        .crumb { border: 1px solid var(--border); border-radius: 6px; padding: 0.05rem 0.45rem; }
        .crumb.cur { border-color: var(--accent); color: var(--text); background: var(--lt-7c3aed-15, rgba(124, 58, 237, 0.15)); }
        .tree-wrap { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 0.8rem; align-items: start; }
        @media (max-width: 520px) { .tree-wrap { grid-template-columns: minmax(0, 1fr); } }
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
        svg .tidbox rect { fill: var(--lt-0e2530, #0e2530); stroke: var(--lt-06b6d4-60, rgba(6, 182, 212, 0.6)); stroke-width: 1.2; }
        svg .tidbox text { font: 700 9.5px 'Space Mono', monospace; fill: var(--lt-a5f3fc, #a5f3fc); }
        svg .tidbox.hot rect { fill: var(--lt-33260e, #33260e); stroke: var(--warn); stroke-width: 2; }
        svg .tidbox.hot text { fill: var(--lt-fde68a, #fde68a); }
        svg .root circle { fill: var(--lt-2a2a48, #2a2a48); }
        svg .root text { font: 9px 'Space Mono', monospace; fill: var(--muted); }

        .header-table { border-collapse: collapse; font-size: 0.82rem; min-width: 150px; }
        .header-table caption { text-align: left; color: var(--muted); font-size: 0.75rem; padding-bottom: 0.25rem; }
        .header-table th { font-weight: 400; color: var(--muted); font-size: 0.7rem; text-align: right; padding: 0 0.35rem 0.15rem; }
        .header-table td { padding: 0.18rem 0.35rem; border-bottom: 1px solid var(--border); white-space: nowrap; }
        .header-table tr[data-item] { cursor: pointer; }
        .header-table tr[data-item]:hover td { background: var(--lt-ffffff-3, rgba(255, 255, 255, 0.03)); }
        .header-table tr.sel td { background: var(--lt-06b6d4-14, rgba(6, 182, 212, 0.14)); }
        .header-table tr.out { opacity: 0.45; cursor: default; }
        .header-table tr.out td.nm { text-decoration: line-through; }
        .header-table td.c { font: 700 0.8rem 'Space Mono', monospace; text-align: right; }
        .header-table td.c.bad { color: var(--bad); }
        .legend { display: flex; flex-wrap: wrap; gap: 0.3rem 0.9rem; font-size: 0.75rem; color: var(--muted); margin-top: 0.55rem; }
        .legend i { display: inline-block; width: 10px; height: 10px; border-radius: 50%; border: 2px solid; margin-right: 0.3rem; vertical-align: -1px; }
        .legend i.sq { border-radius: 3px; }

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
        .times { font: 700 0.74rem 'Space Mono', monospace; color: var(--accent2); margin-left: 0.2rem; }
        .rows-empty { color: var(--muted); font-size: 0.85rem; }

        /* ── 編輯資料（矩陣） ── */
        .db { width: 100%; table-layout: fixed; border-collapse: separate; border-spacing: 0 3px; }
        .db th.tid-h { width: 2.1rem; }
        .db th.del-h { width: 30px; }
        .db th { font-weight: 400; color: var(--muted); font-size: clamp(0.6rem, 3vw, 0.75rem); white-space: nowrap; padding: 0 1px 4px; text-align: center; line-height: 1.25; }
        .db th .emo { display: block; font-size: 1.25rem; }
        .db td { text-align: center; padding: 0; }
        .db td.tid { font: 0.78rem 'Space Mono', monospace; color: var(--muted); text-align: left; width: 2.6em; padding-left: 0.3rem; }
        .cell {
            width: 30px;
            height: 30px;
            margin: 0 auto;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 0.95rem;
            cursor: pointer;
            border: 1px dashed var(--lt-3a3a5a, #3a3a5a);
        }
        .cell:hover { border-color: var(--accent2); }
        .cell.has { background: var(--lt-2a2a48, #2a2a48); }
        .cell.has::after { content: ''; width: 11px; height: 11px; border-radius: 50%; background: var(--accent2); }
        .db .del {
            background: none; border: none; color: var(--muted); cursor: pointer; font-size: 0.85rem;
            width: 26px; height: 26px; border-radius: 50%;
        }
        .db .del:hover { color: var(--bad); background: var(--lt-ffffff-5, rgba(255, 255, 255, 0.05)); }
        .db-foot { display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center; margin-top: 0.7rem; }
        .edit-hint { color: var(--muted); font-size: 0.8rem; margin-bottom: 0.4rem; }

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
            max-height: 520px;
            font: 0.78rem/1.7 'Space Mono', ui-monospace, monospace;
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
        .pat {
            font: inherit;
            font-size: 0.82rem;
            color: var(--text);
            background: none;
            border: 1px solid var(--lt-22c55e-50, rgba(34, 197, 94, 0.5));
            border-radius: 7px;
            padding: 0.12rem 0.5rem;
            cursor: pointer;
        }
        .pat:hover { border-color: var(--accent2); }
        .pat .n { font: 700 0.74rem 'Space Mono', monospace; margin-left: 0.35rem; color: var(--lt-86efac, #86efac); }
        .pat .p { font: 700 0.74rem 'Space Mono', monospace; margin-left: 0.3rem; color: var(--warn); }
        .pat.fresh { box-shadow: 0 0 0 2px var(--warn); }
        .pat.sel { border-color: var(--warn); background: var(--lt-f59e0b-10, rgba(245, 158, 11, 0.1)); }
        .empty { color: var(--muted); font-size: 0.85rem; }
        .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.5rem; margin-top: 0.9rem; }
        .stat { background: var(--panel-2); border-radius: 10px; padding: 0.55rem 0.6rem; }
        .stat .v { font: 700 1.25rem 'Space Mono', monospace; }
        .stat .k { color: var(--muted); font-size: 0.75rem; line-height: 1.35; }
        .compare { margin-top: 0.8rem; font-size: 0.85rem; color: var(--muted); }
        .compare b { color: var(--text); }
        .res-hint { color: var(--muted); font-size: 0.78rem; margin-top: 0.5rem; }

        .notes { margin-top: 1rem; display: grid; gap: 1rem; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr; } }
        .notes p, .notes li { color: var(--lt-c6c6d6, #c6c6d6); font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; }
        .notes b { color: var(--text); }
        .notes a { color: var(--accent2); }

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
        <div class="kicker">RESEARCH DEMO · PERIODIC-FREQUENT PATTERN</div>
        <h1>週期性頻繁樣式探勘<small>不只要常出現，還要出現得規律：PFP-tree</small></h1>
        <p class="intro">
            一樣是那 8 筆超商交易，這次把它們當成<b>照時間排好的紀錄</b>：T1 是第 1 天、T8 是第 8 天。
            一般的頻繁樣式只問「出現幾次」，可是有些組合雖然次數夠，卻全擠在某幾天、之後很久都沒出現。
            <b>週期性頻繁樣式</b>多加一個條件：看相鄰兩次出現的間隔（tid 相減，開頭到第一次、最後一次到結尾也算），最長的那段叫做<b>週期</b>，週期不能超過 <b>maxPer</b>。
            做法跟 <a href="fp-growth.html">FP-Growth</a> 很像，只是樹上的節點不記次數，改成在<b>尾節點</b>記 tid 清單，才算得出每個組合是哪幾天出現的。
        </p>

        <div class="layout">
            <div>
                <div class="card">
                    <div class="player">
                        <button class="btn" id="btn-first" title="回到開頭">⏮</button>
                        <button class="btn" id="btn-prev">◀ 上一步</button>
                        <button class="btn primary" id="btn-next">下一步 ▶</button>
                        <button class="btn" id="btn-play">▶ 自動播放</button>
                    </div>
                    <div class="params">
                        <div class="minsup">
                            <span>最小支持度</span>
                            <button class="btn stepper" id="sup-minus" aria-label="減少最小支持度">−</button>
                            <span class="val" id="sup-val">3</span>
                            <button class="btn stepper" id="sup-plus" aria-label="增加最小支持度">+</button>
                        </div>
                        <div class="minsup">
                            <span>最大週期</span>
                            <button class="btn stepper" id="per-minus" aria-label="減少最大週期">−</button>
                            <span class="val" id="per-val">3</span>
                            <button class="btn stepper" id="per-plus" aria-label="增加最大週期">+</button>
                        </div>
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

                <div class="card">
                    <h2>時間軸：出現在哪幾筆、隔了多久</h2>
                    <div class="tl-sub" id="tl-sub"></div>
                    <div class="tl-list" id="timeline"></div>
                    <div class="vnote">一格是一筆交易（T1…T<span id="tl-n">8</span>），亮的格子是有出現；下面的括號是相鄰兩次出現的間隔，最長的那段就是<b>週期</b>：<span class="w">黃色</span>＝沒超過最大週期，<span class="r">紅色</span>＝超過了。</div>
                </div>

                <div class="card" id="db-card">
                    <div class="card-head">
                        <h2 id="data-title">交易資料庫</h2>
                        <button class="btn" id="btn-edit">✎ 編輯資料</button>
                    </div>
                    <div class="rows" id="rows"></div>
                    <div id="editor" hidden>
                        <div class="edit-hint">點格子加上或拿掉商品；由上到下就是時間順序。</div>
                        <table class="db" id="db"></table>
                        <div class="db-foot">
                            <button class="btn" id="btn-add-row">＋ 新增一筆交易</button>
                            <button class="btn" id="btn-reset-db">恢復範例資料</button>
                        </div>
                    </div>
                </div>
            </div>

            <div>
                <div class="card">
                    <div class="card-head"><h2 id="tree-title">PF-tree</h2></div>
                    <div class="crumbs" id="crumbs"></div>
                    <div class="tree-wrap">
                        <div class="tree-box" id="tree"></div>
                        <table class="header-table" id="header"></table>
                    </div>
                    <div class="legend">
                        <span><i style="border-color:var(--warn)"></i>這一步走過或收到 tid 的節點</span>
                        <span><i style="border-color:var(--good)"></i>新長出的節點</span>
                        <span><i style="border-color:var(--accent2)"></i>同商品的節點鏈</span>
                        <span><i class="sq" style="border-color:var(--accent2)"></i>尾節點的 tid 清單</span>
                    </div>
                </div>

                <div class="card">
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

                <div class="card">
                    <h2>目前找到的週期性頻繁樣式</h2>
                    <div class="levels" id="levels"></div>
                    <div class="res-hint">綠色數字是支持度、黃色是週期；點樣式可以在時間軸上看它。</div>
                    <div class="stats">
                        <div class="stat"><div class="v" id="st-scan">0</div><div class="k">掃描資料庫次數</div></div>
                        <div class="stat"><div class="v" id="st-nodes">0</div><div class="k">PF-tree 節點數</div></div>
                        <div class="stat"><div class="v" id="st-drop">0</div><div class="k">次數夠、但週期太長被刪的</div></div>
                    </div>
                    <div class="compare" id="compare"></div>
                </div>
            </div>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼週期也可以拿來剪枝？</h2>
                <p>組合變大，出現的交易只會變少：{咖啡, 麵包} 出現的那幾筆，一定是「咖啡出現的那幾筆」裡的一部分。
                    時間軸上的點變少，原本相鄰的兩個點中間被拿掉一些，間隔只會<b>合併變長</b>、不會變短，所以<b>大組合的週期一定 ≥ 它任何子集合的週期</b>。
                    子集合的週期已經超過 maxPer，大組合也不可能合格。跟支持度一樣有向下封閉性，所以兩個門檻都能在建樹前、建條件樹前直接把商品刪掉。</p>
                <p style="margin-top:0.5rem">為什麼節點只要在<b>尾節點</b>記 tid？每筆交易排好序後，在樹上剛好走一條路徑、停在一個節點，tid 記在那裡就不會重複。
                    挖最下面的商品時，它的節點一定是尾節點；挖完把 tid 清單交給父節點、再拿掉它，上面的商品就變成新的尾節點，往上挖時 tid 一筆都不會漏。</p>
            </div>
            <div class="card">
                <h2>跟 FP-Growth 比起來，以及後來的研究</h2>
                <ul>
                    <li><b>一樣只掃兩次資料庫：</b>第一次算每個商品的 tid、支持度和週期，第二次建樹。之後都在樹上做。</li>
                    <li><b>節點不記次數、改記 tid：</b>支持度只要數字就夠，週期卻要知道「是哪幾天」，所以要多存 tid 清單，記憶體跟交易筆數成正比。</li>
                    <li><b>門檻很嚴格：</b>只要有一段斷太久就整個不算，有一次放假沒進貨都會被刪掉。後來有研究改成看「平均週期」或允許少數幾次超過（部分週期、近似週期）。</li>
                    <li>跟實驗室的研究很接近：時間順序的交易本來就是<b>資料串流</b>的樣子，也有研究把週期加進<b>高效益樣式</b>（例如 PHM，找「又賺錢又規律」的組合），或在新資料進來時<b>增量更新</b>週期。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           PFP-tree（週期性頻繁樣式）一步一步看
           網頁裡用 JavaScript 照著同樣的流程跑一次，把每一步（含每一層遞迴）記下來；
           右邊的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = /*CODE_JSON*/null;

        const ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片'];
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

        const $ = id => document.getElementById(id);
        let db = SAMPLE.map(t => t.slice());
        let minSup = 3;
        let maxPer = 3;
        let editing = false;
        let lang = 'java';
        let trace = [];
        let cursor = 0;
        let linkItem = null;     // 使用者在表上點選、要顯示節點鏈的商品
        let focusKey = null;     // 使用者在結果裡點選、要放到時間軸上的樣式
        let timer = null;

        const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);    // 跟 Java compareTo、Python 字串比較同一個順序
        const fmt = set => '{' + set.join(', ') + '}';
        const arrowPath = items => items.join(' → ');
        const emo = set => set.map(i => EMOJI[i] || i).join('');
        const tidText = tids => tids.map(t => 'T' + t).join('、');
        const byItem = (a, b) => ITEMS.indexOf(a) - ITEMS.indexOf(b) || cmp(a, b);

        /* 週期：相鄰兩次出現的間隔（含開頭到第一次、最後一次到結尾），取最大的 */
        function periodOf(tids, n) {
            let prev = 0, mx = 0;
            [...tids].sort((a, b) => a - b).forEach(t => { mx = Math.max(mx, t - prev); prev = t; });
            return Math.max(mx, n - prev);
        }

        /* ---------- 照著程式跑一次，記下每一步 ---------- */
        function buildTrace(data, minSup, maxPer) {
            const n = data.length;
            const steps = [];
            const result = [];
            const stats = { scans: 0, mainNodes: 0, trees: 0, perDrop: 0 };
            const stack = [];
            let nextId = 1;

            const snapshot = root => {
                const out = [];
                (function walk(nd) {
                    for (const c of nd.children.values()) {
                        out.push({ id: c.id, item: c.item, parent: nd.id, tids: c.tids.slice().sort((a, b) => a - b) });
                        walk(c);
                    }
                })(root);
                return out;
            };

            function push(kind, f, extra = {}) {
                steps.push({
                    kind, n, depth: f ? f.depth : 0, suffix: f ? f.suffix : [],
                    crumbs: stack.map(x => x.suffix),
                    tree: f && f.root ? snapshot(f.root) : [],
                    header: f && f.header ? Object.fromEntries(Object.entries(f.header).map(([k, v]) => [k, v.filter(nd => nd.alive).map(nd => nd.id)])) : {},
                    order: f ? f.order.slice() : [],
                    info: f ? f.info : {},
                    rows: f ? f.rows : [],
                    result: result.map(r => ({ ...r })),
                    stats: { ...stats },
                    ...extra
                });
            }

            function mine(rows, suffix, depth) {
                const f = { depth, suffix, root: null, header: null, order: [], info: {}, rows: rows.map(r => ({ items: r.items, tids: r.tids.slice() })) };
                stack.push(f);

                // 1. 每個商品出現在哪幾筆 → 支持度和週期
                if (depth === 0) stats.scans++;
                const tidsOf = {};
                rows.forEach(r => r.items.forEach(i => { (tidsOf[i] = tidsOf[i] || []).push(...r.tids); }));
                Object.keys(tidsOf).forEach(i => {
                    const tids = tidsOf[i].slice().sort((a, b) => a - b);
                    const sup = tids.length, per = periodOf(tids, n);
                    f.info[i] = { tids, sup, per, supOk: sup >= minSup, perOk: per <= maxPer };
                    if (sup >= minSup && per > maxPer) stats.perDrop++;
                });
                f.order = Object.keys(f.info).filter(i => f.info[i].supOk && f.info[i].perOk)
                    .sort((a, b) => f.info[b].sup - f.info[a].sup || cmp(a, b));
                f.rows.forEach(r => { r.path = f.order.filter(i => r.items.includes(i)); });
                push('count', f);
                if (depth === 0) push('filter', f);
                if (!f.order.length) { stack.pop(); return; }

                // 2. 建 PF-tree：節點不記次數，交易的 tid 記在路徑最後一個節點（尾節點）
                f.root = { id: 0, item: null, tids: [], children: new Map() };
                f.header = Object.fromEntries(f.order.map(i => [i, []]));
                if (depth === 0) stats.scans++; else stats.trees++;
                f.rows.forEach((r, idx) => {
                    let node = f.root;
                    const pathIds = [], newIds = [];
                    r.path.forEach(item => {
                        let child = node.children.get(item);
                        if (!child) {
                            child = { id: nextId++, item, tids: [], children: new Map(), parent: node, alive: true };
                            node.children.set(item, child);
                            f.header[item].push(child);
                            newIds.push(child.id);
                            if (depth === 0) stats.mainNodes++;
                        }
                        pathIds.push(child.id);
                        node = child;
                    });
                    if (r.path.length) node.tids.push(...r.tids);
                    r.done = true;
                    if (depth === 0) push('insert', f, { row: idx, pathIds, newIds, path: r.path, tailId: r.path.length ? node.id : null, rowsDone: idx });
                });
                if (depth > 0) push('build', f);

                // 3. 從最下面（支持度最小）的商品往上挖
                for (let i = f.order.length - 1; i >= 0; i--) {
                    const item = f.order[i];
                    const nodes = f.header[item];
                    const parts = nodes.map(nd => nd.tids.slice().sort((a, b) => a - b));
                    const all = parts.flat().sort((a, b) => a - b);
                    const pattern = [item, ...suffix];
                    const per = periodOf(all, n);
                    result.push({ set: pattern, sup: all.length, per, tids: all, fresh: true });
                    const linkIds = nodes.map(nd => nd.id);
                    push('pattern', f, { item, pattern, linkIds, parts, tids: all, sup: all.length, per });
                    result.forEach(r => { r.fresh = false; });

                    const base = [];
                    const pathIds = [];
                    nodes.forEach(nd => {
                        const path = [];
                        for (let p = nd.parent; p.item !== null; p = p.parent) { path.unshift(p.item); pathIds.push(p.id); }
                        if (path.length) base.push({ items: path, tids: nd.tids.slice().sort((a, b) => a - b) });
                    });
                    push('base', f, { item, pattern, linkIds, pathIds, base, tids: all });
                    if (base.length) mine(base, pattern, depth + 1);

                    // 4. 把 tid 清單交給父節點，再把這個商品的節點拿掉
                    const recvIds = [];
                    nodes.forEach(nd => {
                        if (nd.parent.item !== null) { nd.parent.tids.push(...nd.tids); recvIds.push(nd.parent.id); }
                        nd.parent.children.delete(item);
                        nd.alive = false;
                    });
                    // 最上面的商品（i = 0）節點都直接接在根下面，拿掉之後這一層就挖完了，不另外記一步
                    if (i > 0) push('push', f, { item, pattern, recvIds: [...new Set(recvIds)], recursed: base.length > 0, tids: all });
                }
                stack.pop();
            }

            steps.push({ kind: 'start', n, depth: 0, suffix: [], crumbs: [], tree: [], header: {}, order: [], info: {}, rows: data.map(t => ({ items: t, tids: [] })), result: [], stats: { ...stats } });
            mine(data.map((t, i) => ({ items: t, tids: [i + 1] })), [], 0);
            // 結束畫面回到建好的完整 PF-tree（挖的過程中節點會一個一個拿掉）
            const built = [...steps].reverse().find(s => s.kind === 'insert') || [...steps].reverse().find(s => s.depth === 0);
            steps.push({ ...built, kind: 'end', depth: 0, crumbs: [], pathIds: [], newIds: [], tailId: null, row: -1, result: result.map(r => ({ ...r, fresh: false })), stats: { ...stats } });
            return steps;
        }

        /* 暴力法：列出所有組合，算支持度和週期（拿來比較「只看次數」會多出哪些） */
        function bruteAll(data, minSup, maxPer) {
            const n = data.length;
            const items = ITEMS.filter(i => data.some(t => t.includes(i)));
            const out = [];
            for (let mask = 1; mask < (1 << items.length); mask++) {
                const set = items.filter((_, k) => mask & (1 << k));
                const tids = [];
                data.forEach((t, k) => { if (set.every(x => t.includes(x))) tids.push(k + 1); });
                if (tids.length >= minSup) out.push({ set, tids, sup: tids.length, per: periodOf(tids, n), ok: periodOf(tids, n) <= maxPer });
            }
            return out;
        }

        /* ---------- 說明文字 ---------- */
        const where = s => s.depth === 0 ? '完整的 PF-tree' : `後綴 ${fmt(s.suffix)} 的條件樹`;
        const reasons = (s, list) => list.map(i => {
            const f = s.info[i], w = [];
            if (!f.supOk) w.push(`次數 ${f.sup} < ${minSup}`);
            if (!f.perOk) w.push(`週期 ${f.per} > ${maxPer}`);
            return `${s.depth ? fmt([i, ...s.suffix]) : i}（${w.join('、')}）`;
        }).join('、');
        function describe(s) {
            switch (s.kind) {
                case 'start':
                    return `目標：找出至少出現在 <b>${minSup}</b> 筆交易裡，<b>而且</b>相鄰兩次出現的間隔都不超過 <b>${maxPer}</b> 的商品組合。` +
                        `把每筆交易當成一個時間點（T1 是第 1 天、T${s.n} 是第 ${s.n} 天），「多久出現一次」就算得出來。`;
                case 'count': {
                    const all = Object.keys(s.info);
                    const out = all.filter(i => !s.info[i].supOk || !s.info[i].perOk).sort(byItem);
                    if (s.depth === 0) {
                        const ex = all.filter(i => s.info[i].supOk && !s.info[i].perOk).sort(byItem)[0];
                        let txt = `第 1 次掃描資料庫：記下每個商品出現在哪幾筆（tid 清單），順便算兩個數字：<b>支持度</b>＝出現幾次、<b>週期</b>＝相鄰兩次出現的間隔裡最長的那段（開頭到第一次、最後一次到結尾也算）。`;
                        if (ex) {
                            const t = s.info[ex].tids;
                            let gap = [0, t[0]];
                            [0, ...t, s.n].forEach((x, k, arr) => { if (k && x - arr[k - 1] > gap[1] - gap[0]) gap = [arr[k - 1], x]; });
                            txt += `例如 ${ex} 出現 ${s.info[ex].sup} 次，次數夠，但從${gap[0] ? ` T${gap[0]} ` : '開頭'}到${gap[1] === s.n && !t.includes(s.n) ? '結尾' : ` T${gap[1]} `}間隔是 ${s.info[ex].per}，太久沒出現了。`;
                        }
                        return txt;
                    }
                    if (!s.order.length) {
                        return `在條件模式基底裡，把含有某商品的路徑的 tid 清單合起來，就是它加上 ${fmt(s.suffix)} 出現在哪幾筆。` +
                            `${reasons(s, out)} 都不合格，以 ${fmt(s.suffix)} 結尾的樣式到此為止，回到上一層。`;
                    }
                    return `在條件模式基底裡，把含有某商品的路徑的 tid 清單合起來，就是它加上 ${fmt(s.suffix)} 出現在哪幾筆。` +
                        (out.length ? `${reasons(s, out)} 不合格，刪掉；` : '每個都合格；') + `留下 <b>${arrowPath(s.order)}</b>。`;
                }
                case 'filter': {
                    const out = Object.keys(s.info).filter(i => !s.info[i].supOk || !s.info[i].perOk).sort(byItem);
                    if (!s.order.length) return `每個商品都不合格（${reasons(s, out)}），連一個商品都沒有，當然也不會有更大的組合，直接結束。`;
                    return (out.length ? `兩個門檻都要過：${reasons(s, out)} 刪掉，之後當它不存在。` : '每個商品兩個門檻都過了。') +
                        `剩下的照支持度由多到少排成 <b>${arrowPath(s.order)}</b>（一樣多時照字碼排，只是為了結果固定），每筆交易都照這個順序重排。`;
                }
                case 'insert': {
                    const label = `T${s.row + 1}`;
                    if (!s.path.length) return `第 2 次掃描資料庫：${label} 裡沒有合格的商品，跳過，樹上不會有它的 tid。`;
                    const shared = s.path.length - s.newIds.length;
                    let txt = `第 2 次掃描資料庫：把 ${label} 排成「${arrowPath(s.path)}」插進樹裡。`;
                    if (!s.newIds.length) txt += `整條路徑樹上都有了，一個新節點都不用長。`;
                    else if (!shared) txt += `沒有可以共用的前綴，從根長出新的路徑。`;
                    else txt += `前面的「${arrowPath(s.path.slice(0, shared))}」共用，後面長出「${arrowPath(s.path.slice(shared))}」。`;
                    return txt + `節點不記次數，而是在這筆交易<b>結束的地方</b>（${s.path[s.path.length - 1]}，尾節點）記下 tid ${s.row + 1}。`;
                }
                case 'build':
                    return `把條件模式基底照「${arrowPath(s.order)}」插進一棵新的小樹，每條路徑的 tid 一樣記在尾節點，這就是<b>${where(s)}</b>，共 ${s.tree.length} 個節點。`;
                case 'pattern': {
                    const head = s.depth === 0
                        ? (s.order[s.order.length - 1] === s.item ? `開始挖：從最下面、支持度最小的 <b>${s.item}</b> 開始。` : `往上挖下一個：<b>${s.item}</b>。`)
                        : `在${where(s)}裡挖 <b>${s.item}</b>。`;
                    const src = s.parts.length > 1 ? `它的 ${s.parts.length} 個節點現在都是尾節點，tid 清單合起來是` : `它只有 1 個節點，tid 清單是`;
                    return head + `${src} ${tidText(s.tids)}，所以 ${fmt(s.pattern)} 出現 ${s.sup} 次、週期 ${s.per}，記下來。`;
                }
                case 'base':
                    if (!s.base.length) return `${s.item} 的節點往上直接就是根，沒有前綴路徑，以 ${fmt(s.pattern)} 結尾的不會再有更大的樣式。`;
                    return `找 ${s.item} 的條件模式基底：從每個 ${s.item} 節點往上走到根，路徑帶著那個節點的 tid 清單：` +
                        s.base.map(b => `${arrowPath(b.items)}（${tidText(b.tids)}）`).join('、') + `。接著用它們遞迴，找以 ${fmt(s.pattern)} 結尾的樣式。`;
                case 'push': {
                    const head = s.recursed ? `以 ${fmt(s.pattern)} 結尾的都挖完了，回到${where(s)}。` : '';
                    if (!s.recvIds.length) return head + `${s.item} 的節點都直接接在根下面，拿掉就好。`;
                    return head + `把每個 ${s.item} 節點的 tid 清單<b>交給它的父節點</b>（亮起來的），再把 ${s.item} 節點拿掉。父節點變成新的尾節點，往上挖下一個商品時 tid 一筆都不會漏。`;
                }
                case 'end': {
                    const all = bruteAll(db, minSup, maxPer);
                    const bad = all.filter(x => !x.ok).length;
                    return `完成！找到 <b>${s.result.length}</b> 個週期性頻繁樣式，只掃描資料庫 ${s.stats.scans} 次。` +
                        (bad ? `如果只看次數會有 ${all.length} 個頻繁樣式，其中 <b>${bad}</b> 個次數夠、但中間斷太久（週期 > ${maxPer}），時間軸上列的就是這種組合。`
                            : `這次每個頻繁樣式都夠規律，只看次數也會得到一樣的 ${all.length} 個。`);
                }
            }
            return '';
        }

        const CODE_TAGS = s => ({
            start: ['start'], count: ['count', 'per'], filter: ['count'], insert: ['insert'], build: ['insert'],
            pattern: ['loop', 'pattern', 'per'], base: s.base && s.base.length ? ['base', 'recurse'] : ['base'],
            push: ['push'], end: ['end']
        })[s.kind] || [];

        /* ---------- 時間軸 ---------- */
        function tlRow(label, title, tids, n, opts = {}) {
            const row = document.createElement('div');
            row.className = 'tl-row' + (opts.cls ? ' ' + opts.cls : '');
            const per = periodOf(tids, n);
            const on = new Set(tids);
            let cells = '';
            for (let k = 1; k <= n; k++) cells += `<span class="c${on.has(k) ? ' on' : ''}${opts.cur === k ? ' cur' : ''}" style="grid-column:${k}">${on.has(k) ? k : ''}</span>`;
            let prev = 0;
            if (!opts.part) [...tids, n].forEach(t => {
                const g = t - prev;
                if (g > 0) cells += `<span class="g${g === per ? (per > maxPer ? ' bad' : ' max') : ''}" style="grid-column:${prev + 1} / ${t + 1}">${g}</span>`;
                prev = Math.max(prev, t);
            });
            const supBad = tids.length < minSup, perBad = per > maxPer;
            row.innerHTML = `<span class="lbl"></span><div class="tl" style="--n:${n}">${cells}</div>` + (opts.part ? `<span class="nums">${tids.length} 筆</span>` :
                `<span class="nums"><b class="${supBad ? 'bad' : ''}">${tids.length}</b> 次<br>週期 <b class="${perBad ? 'bad' : ''}">${per}</b></span>`);
            row.querySelector('.lbl').textContent = label;
            row.querySelector('.lbl').title = title;
            return row;
        }

        function drawTimeline(s) {
            const box = $('timeline'), sub = $('tl-sub');
            box.innerHTML = '';
            $('tl-n').textContent = s.n;
            const add = (set, tids, opts) => box.appendChild(tlRow(s.depth === 0 && set.length === 1 && !opts.raw ? `${EMOJI[set[0]] || ''} ${set[0]}` : emo(set), fmt(set), tids, s.n, opts));
            if (focusKey) {
                const r = s.result.find(x => x.set.join('|') === focusKey);
                if (r) {
                    sub.innerHTML = `你點的樣式 <b></b>`;
                    sub.querySelector('b').textContent = fmt(r.set);
                    add(r.set, r.tids, { cls: 'focus' });
                    return;
                }
            }
            switch (s.kind) {
                case 'start':
                    sub.textContent = '掃描之後，每個商品都會在這裡畫一條時間軸。';
                    box.innerHTML = '<div class="tl-empty">還沒開始掃描。</div>';
                    return;
                case 'count': case 'filter': case 'build': case 'insert': {
                    const keys = Object.keys(s.info);
                    const kept = s.kind === 'count' && s.depth === 0 ? [] : s.order;
                    const rest = keys.filter(i => !kept.includes(i)).sort(byItem);
                    const list = s.kind === 'insert' ? s.order : [...kept, ...rest];
                    sub.textContent = s.depth === 0
                        ? (s.kind === 'insert' ? `第 2 次掃描到 T${s.row + 1}（框起來的那一格）。` : '每個商品出現在哪幾筆：')
                        : `加上後綴 ${fmt(s.suffix)} 之後，出現在哪幾筆：`;
                    list.forEach(i => {
                        const f = s.info[i];
                        const dropped = s.kind !== 'count' || s.depth > 0 ? !(f.supOk && f.perOk) : false;
                        add([i, ...s.suffix], f.tids, { cls: dropped ? 'drop' : '', cur: s.kind === 'insert' ? s.row + 1 : null });
                    });
                    return;
                }
                case 'pattern': case 'base': case 'push': {
                    sub.innerHTML = '';
                    sub.append(s.kind === 'pattern' && s.parts.length > 1 ? `每個尾節點的 tid，合起來就是 ` : `樣式 `);
                    const b = document.createElement('b'); b.textContent = fmt(s.pattern); sub.append(b, ' 出現在哪幾筆：');
                    if (s.kind === 'pattern' && s.parts.length > 1 && s.parts.length <= 5)
                        s.parts.forEach((p, k) => add(s.pattern, p, { cls: 'part', part: true }));
                    add(s.pattern, s.tids, { cls: 'focus' });
                    if (s.kind === 'pattern' && s.parts.length > 1 && s.parts.length <= 5)
                        [...box.querySelectorAll('.tl-row.part .lbl')].forEach((l, k) => { l.textContent = `節點 ${k + 1}`; });
                    return;
                }
                case 'end': {
                    const bad = bruteAll(db, minSup, maxPer).filter(x => !x.ok)
                        .sort((a, b) => b.sup - a.sup || b.set.length - a.set.length || b.per - a.per).slice(0, 5);
                    if (bad.length) {
                        sub.textContent = '次數夠、但中間斷太久而不算的組合：';
                        bad.forEach(x => add(x.set, x.tids, {}));
                    } else {
                        const big = s.result.slice().sort((a, b) => b.set.length - a.set.length || b.sup - a.sup).slice(0, 5);
                        sub.textContent = big.length ? '這次沒有被週期刷掉的組合；找到的樣式：' : '沒有找到任何樣式。';
                        big.forEach(x => add(x.set, x.tids, {}));
                    }
                    return;
                }
            }
        }

        /* ---------- 畫樹 ---------- */
        function drawTree(s) {
            const box = $('tree');
            if (!s.tree.length) {
                box.innerHTML = `<div class="tree-empty">${s.kind === 'start' || s.kind === 'count' && s.depth === 0 || s.kind === 'filter' ? '樹還是空的，第 2 次掃描時才開始長。' : s.kind === 'count' && !s.order.length ? '沒有合格的商品，不用建樹。' : '樹是空的。'}</div>`;
                return;
            }
            const kids = { 0: [] };
            s.tree.forEach(nd => { kids[nd.id] = []; });
            s.tree.forEach(nd => kids[nd.parent].push(nd));
            const pos = {};
            let leaf = 0, maxDepth = 0;
            (function place(id, d) {
                maxDepth = Math.max(maxDepth, d);
                const ch = kids[id] || [];
                if (!ch.length) { pos[id] = { x: leaf++, y: d }; return; }
                ch.forEach(c => place(c.id, d + 1));
                pos[id] = { x: (pos[ch[0].id].x + pos[ch[ch.length - 1].id].x) / 2, y: d };
            })(0, 0);
            // tid 清單一行放 3 個，畫在節點正下方
            const chunks = tids => { const out = []; for (let k = 0; k < tids.length; k += 3) out.push(tids.slice(k, k + 3).join(',')); return out; };
            const maxLines = Math.max(0, ...s.tree.map(nd => chunks(nd.tids).length));
            const DX = 54, DY = Math.max(62, 50 + 12 * maxLines), PAD = 30;
            const X = p => PAD + p.x * DX, Y = p => 22 + p.y * DY;
            const W = PAD * 2 + Math.max(0, leaf - 1) * DX, H = 22 + maxDepth * DY + 26 + 12 * maxLines;

            const onIds = new Set([...(s.pathIds || []), ...(s.recvIds || [])]);
            const newIds = new Set(s.newIds || []);
            const linkIds = linkItem && s.header[linkItem] ? s.header[linkItem] : (s.linkIds || []);
            const linked = new Set(linkIds);
            const hot = new Set(s.kind === 'insert' && s.tailId ? [s.tailId] : s.recvIds || []);

            let svg = `<svg viewBox="0 0 ${W} ${H}" width="${W}" role="img" aria-label="PF-tree">`;
            s.tree.forEach(nd => {
                const a = pos[nd.parent], b = pos[nd.id];
                const on = onIds.has(nd.id) && (nd.parent === 0 || onIds.has(nd.parent) || linked.has(nd.parent));
                svg += `<line class="edge${on ? ' on' : ''}" x1="${X(a)}" y1="${Y(a)}" x2="${X(b)}" y2="${Y(b)}"/>`;
            });
            for (let k = 1; k < linkIds.length; k++) {
                const a = pos[linkIds[k - 1]], b = pos[linkIds[k]];
                if (!a || !b) continue;
                const mx = (X(a) + X(b)) / 2, my = Math.max(Y(a), Y(b)) + 26;
                svg += `<path class="link" d="M${X(a)} ${Y(a) + 18} Q${mx} ${my} ${X(b)} ${Y(b) + 18}"/>`;
            }
            svg += `<g class="root"><circle cx="${X(pos[0])}" cy="${Y(pos[0])}" r="11"/><text x="${X(pos[0])}" y="${Y(pos[0]) + 3}" text-anchor="middle">root</text></g>`;
            s.tree.forEach(nd => {
                const p = pos[nd.id];
                const cls = ['node', onIds.has(nd.id) ? 'on' : '', newIds.has(nd.id) ? 'new' : '', linked.has(nd.id) ? 'linked' : ''].join(' ');
                svg += `<g class="${cls}"><title>${nd.item}${nd.tids.length ? '：tid ' + nd.tids.join(', ') : ''}</title>` +
                    `<circle class="body" cx="${X(p)}" cy="${Y(p)}" r="18"/>` +
                    `<text class="emo" x="${X(p)}" y="${Y(p) + 6}" text-anchor="middle">${EMOJI[nd.item] || nd.item[0]}</text></g>`;
            });
            // tid 框最後畫，蓋在線上面
            s.tree.forEach(nd => {
                if (!nd.tids.length) return;
                const p = pos[nd.id], lines = chunks(nd.tids);
                const w = Math.max(...lines.map(l => l.length)) * 6 + 8;
                svg += `<g class="tidbox${hot.has(nd.id) ? ' hot' : ''}"><rect x="${X(p) - w / 2}" y="${Y(p) + 20}" width="${w}" height="${lines.length * 12 + 3}" rx="4"/>` +
                    lines.map((l, k) => `<text x="${X(p)}" y="${Y(p) + 30.5 + k * 12}" text-anchor="middle">${l}</text>`).join('') + '</g>';
            });
            svg += '</svg>';
            box.innerHTML = svg;
        }

        function drawHeader(s) {
            const t = $('header');
            const all = Object.keys(s.info);
            if (!all.length || s.kind === 'count' && s.depth === 0) { t.innerHTML = ''; return; }
            const ok = i => s.info[i].supOk && s.info[i].perOk;
            const list = [...s.order, ...all.filter(i => !ok(i)).sort(byItem)];
            const active = linkItem && s.header[linkItem] ? linkItem : s.item;
            t.innerHTML = `<caption>${s.depth === 0 ? '表頭' : '條件表頭'}</caption><tr><th></th><th></th><th>次數</th><th>週期</th></tr>` + list.map(i => {
                const f = s.info[i];
                const live = ok(i) && s.header[i] && s.header[i].length;
                return `<tr class="${ok(i) ? '' : 'out'}${live && i === active ? ' sel' : ''}"${live ? ` data-item="${i}"` : ''}><td>${EMOJI[i] || ''}</td><td class="nm">${i}</td>` +
                    `<td class="c${f.supOk ? '' : ' bad'}">${f.sup}</td><td class="c${f.perOk ? '' : ' bad'}">${f.per}</td></tr>`;
            }).join('');
        }
        $('header').addEventListener('click', e => {
            const tr = e.target.closest('tr[data-item]');
            if (!tr) return;
            linkItem = linkItem === tr.dataset.item ? null : tr.dataset.item;
            const s = trace[cursor];
            drawTree(s);
            drawHeader(s);
        });

        function drawRows(s) {
            const box = $('rows');
            const isBase = s.depth > 0;
            $('data-title').textContent = editing ? '編輯交易資料庫' : isBase ? `條件模式基底（後綴 ${fmt(s.suffix)}）` : (s.kind === 'start' || s.kind === 'count' ? '交易資料庫（由上到下是時間順序）' : '交易資料庫（照支持度重排後）');
            $('rows').hidden = editing;
            $('editor').hidden = !editing;
            if (editing) { renderDB(); return; }
            if (!s.rows.length) { box.innerHTML = '<div class="rows-empty">沒有資料。</div>'; return; }
            const sorted = !isBase && s.rows[0] && s.rows[0].path && s.kind !== 'start' && s.kind !== 'count';
            box.innerHTML = '';
            s.rows.forEach((r, i) => {
                const div = document.createElement('div');
                div.className = 'row' + (s.kind === 'insert' && s.row === i ? ' cur' : '') + (s.kind === 'insert' && i < s.row ? ' done' : '');
                const label = isBase ? `#${i + 1}` : `T${i + 1}`;
                let items;
                if (sorted) {
                    const out = r.items.filter(x => !r.path.includes(x)).sort(byItem);
                    items = r.path.map(x => `<span class="chip">${EMOJI[x] || ''}${x}</span>`).join('<span class="arrow">→</span>') +
                        out.map(x => ` <span class="chip out">${x}</span>`).join('');
                } else {
                    const list = isBase ? r.items : r.items.slice().sort(byItem);
                    items = list.map(x => `<span class="chip">${EMOJI[x] || ''}${x}</span>`).join(isBase ? '<span class="arrow">→</span>' : '');
                }
                div.innerHTML = `<span class="rid">${label}</span>${items}${isBase ? `<span class="times">${r.tids.map(t => 'T' + t).join(',')}</span>` : ''}`;
                box.appendChild(div);
            });
        }

        function renderDB() {
            let html = '<tr><th class="tid-h"></th>' + ITEMS.map(i => `<th><span class="emo">${EMOJI[i]}</span>${i}</th>`).join('') + '<th class="del-h"></th></tr>';
            db.forEach((t, r) => {
                html += `<tr><td class="tid">T${r + 1}</td>` +
                    ITEMS.map(i => `<td><div class="cell ${t.includes(i) ? 'has' : ''}" data-r="${r}" data-i="${i}"></div></td>`).join('') +
                    `<td><button class="del" data-del="${r}" aria-label="刪除 T${r + 1}">✕</button></td></tr>`;
            });
            $('db').innerHTML = html;
            $('btn-add-row').disabled = db.length >= 12;
        }

        function drawResult(s) {
            const box = $('levels');
            box.innerHTML = '';
            if (!s.result.length) box.innerHTML = '<div class="empty">還沒有，開始挖之後會出現在這裡。</div>';
            const bySize = {};
            s.result.forEach(r => { (bySize[r.set.length] = bySize[r.set.length] || []).push(r); });
            Object.keys(bySize).sort((a, b) => a - b).forEach(k => {
                const row = document.createElement('div');
                row.className = 'level';
                row.innerHTML = `<span class="tag">${k} 個</span><div class="items"></div>`;
                bySize[k].forEach(r => {
                    const p = document.createElement('button');
                    p.type = 'button';
                    const key = r.set.join('|');
                    p.className = 'pat' + (r.fresh ? ' fresh' : '') + (focusKey === key ? ' sel' : '');
                    p.dataset.key = key;
                    p.innerHTML = `<span></span><span class="n">${r.sup}</span><span class="p">${r.per}</span>`;
                    p.firstChild.textContent = fmt(r.set);
                    p.title = `支持度 ${r.sup}、週期 ${r.per}`;
                    row.querySelector('.items').appendChild(p);
                });
                box.appendChild(row);
            });
            $('st-scan').textContent = s.stats.scans;
            $('st-nodes').textContent = s.stats.mainNodes;
            $('st-drop').textContent = s.stats.perDrop;
            const all = bruteAll(db, minSup, maxPer);
            $('compare').innerHTML = `同一份資料只看支持度（像 FP-Growth）會找到 <b>${all.length}</b> 個頻繁樣式，其中 <b>${all.filter(x => x.ok).length}</b> 個週期 ≤ ${maxPer}。`;
        }
        $('levels').addEventListener('click', e => {
            const b = e.target.closest('.pat');
            if (!b) return;
            focusKey = focusKey === b.dataset.key ? null : b.dataset.key;
            const s = trace[cursor];
            drawResult(s);
            drawTimeline(s);
        });

        function drawCrumbs(s) {
            const box = $('crumbs');
            $('tree-title').textContent = s.depth === 0 ? 'PF-tree' : `條件樹：後綴 ${fmt(s.suffix)}`;
            const crumbs = s.crumbs.length ? s.crumbs : [[]];
            box.innerHTML = '遞迴層：' + crumbs.map((c, i) =>
                `<span class="crumb${i === crumbs.length - 1 ? ' cur' : ''}">${c.length ? fmt(c) : '完整的樹'}</span>`).join('<span class="arrow">›</span>');
        }

        /* ---------- 程式碼 ---------- */
        const KW = {
            java: new Set('public static final for if return new boolean int void class import while else null this'.split(' ')),
            py: new Set('def for in if return not and or while import from as True False None class is lambda del'.split(' '))
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
                ? '下載 <a href="code/PeriodicFP.java" download>PeriodicFP.java</a>　執行 <code>javac PeriodicFP.java && java PeriodicFP</code>'
                : '下載 <a href="code/periodic_fp.py" download>periodic_fp.py</a>　執行 <code>python3 periodic_fp.py</code>';
        }

        /* ---------- 顯示某一步 ---------- */
        function showStep() {
            const s = trace[cursor];
            linkItem = null;
            focusKey = null;
            $('explain').innerHTML = `<span class="step-no">步驟 ${cursor + 1} / ${trace.length}</span>${describe(s)}`;
            drawTimeline(s);
            drawCrumbs(s);
            drawTree(s);
            drawHeader(s);
            drawRows(s);
            drawResult(s);
            renderCode(CODE_TAGS(s));
            $('btn-prev').disabled = $('btn-first').disabled = cursor === 0;
            $('btn-next').disabled = cursor === trace.length - 1;
            $('sup-val').textContent = minSup;
            $('per-val').textContent = maxPer;
            $('sup-minus').disabled = minSup <= 1;
            $('sup-plus').disabled = minSup >= db.length;
            $('per-minus').disabled = maxPer <= 1;
            $('per-plus').disabled = maxPer >= db.length;
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

        function rebuild(keepCursor) {
            stopAuto();
            minSup = Math.max(1, Math.min(minSup, db.length));
            maxPer = Math.max(1, Math.min(maxPer, db.length));
            trace = buildTrace(db, minSup, maxPer);
            cursor = keepCursor ? Math.min(cursor, trace.length - 1) : 0;
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
        /* 週期性樣式的題目：週期怎麼算（含頭尾）、哪些商品過得了兩個門檻、tid 記在哪個節點 */
        function quizFor(s, i) {
            const rnd = quizRng(i + 1);
            switch (s.kind) {
                case 'count': {
                    const items = Object.keys(s.info).sort(cmp);
                    if (!items.length) return null;
                    const it = quizPick(items, rnd), x = s.info[it], pat = [it, ...s.suffix];
                    let inner = 0;
                    x.tids.forEach((t, k) => { if (k) inner = Math.max(inner, t - x.tids[k - 1]); });
                    return {
                        q: `${fmt(pat)} 出現在 ${tidText(x.tids)}（共 ${s.n} 筆交易）。它的週期是多少？`,
                        ...quizNums(x.per, 1, s.n, rnd, [inner, x.sup, x.tids[0]]),
                        why: `間隔要算開頭到第一次（${x.tids[0]}）、每兩次之間、最後一次到結尾（${s.n - x.tids[x.tids.length - 1]}），最長的是 ${x.per}；` +
                            (x.per <= maxPer ? `≤ ${maxPer}，週期合格。` : `> ${maxPer}，太久沒出現，不合格。`),
                        ask: { type: 'period', set: pat }
                    };
                }
                case 'filter': {
                    const items = Object.keys(s.info).sort(cmp);
                    if (!items.length) return null;
                    const pick = quizShuffle(items, rnd).slice(0, 4).sort(cmp);
                    const ok = x => s.info[x].supOk && s.info[x].perOk;
                    const mq = {
                        q: `門檻：至少 ${minSup} 次、週期 ≤ ${maxPer}。下面哪些商品會留下來建樹？`,
                        choices: pick, answer: pick.map((x, k) => k).filter(k => ok(pick[k])), multi: true,
                        why: pick.map(x => `${x} ${s.info[x].sup} 次／週期 ${s.info[x].per}`).join('、') + '，兩個都過才留下。',
                        ask: { type: 'filter', sets: pick.map(x => [x]) }
                    };
                    return pick.length === 1 ? quizSingle(mq, `${pick[0]} 會留下來嗎？`) : mq;
                }
                case 'insert': {
                    if (s.path.length < 2) return null;
                    const last = s.path[s.path.length - 1];
                    return {
                        q: `T${s.row + 1} 排好序是 ${arrowPath(s.path)}。插進樹之後，tid「${s.row + 1}」記在哪裡？`,
                        ...quizOptions([{ text: `只記在 ${last} 節點` }, { text: `只記在 ${s.path[0]} 節點` }, { text: '路徑上每個節點都記' }], rnd),
                        why: `只記在路徑最後的尾節點（${last}），不然同一筆會被重複算；往上挖時再把 tid 交給父節點。`,
                        ask: { type: 'tail', row: s.row }
                    };
                }
            }
            return null;
        }

        function step(dir) {
            if (quizGate(dir)) return false;
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
        $('sup-minus').addEventListener('click', () => { if (minSup > 1) { minSup--; rebuild(false); } });
        $('sup-plus').addEventListener('click', () => { if (minSup < db.length) { minSup++; rebuild(false); } });
        $('per-minus').addEventListener('click', () => { if (maxPer > 1) { maxPer--; rebuild(false); } });
        $('per-plus').addEventListener('click', () => { if (maxPer < db.length) { maxPer++; rebuild(false); } });

        $('btn-edit').addEventListener('click', () => {
            editing = !editing;
            $('btn-edit').textContent = editing ? '✓ 編輯完成' : '✎ 編輯資料';
            $('btn-edit').classList.toggle('on', editing);
            stopAuto();
            if (!editing) cursor = 0;
            showStep();
            reserveExplainHeight();
        });
        $('db').addEventListener('click', e => {
            const del = e.target.closest('[data-del]');
            if (del) {
                if (db.length <= 3) return;
                db.splice(Number(del.dataset.del), 1);
                rebuild(false);
                return;
            }
            const cell = e.target.closest('.cell');
            if (!cell) return;
            const t = db[Number(cell.dataset.r)];
            const item = cell.dataset.i;
            if (t.includes(item)) {
                if (t.length <= 1) return;          // 一筆交易至少要買一樣
                t.splice(t.indexOf(item), 1);
            } else {
                t.push(item);
                t.sort(byItem);
            }
            rebuild(false);
        });
        $('btn-add-row').addEventListener('click', () => {
            if (db.length >= 12) return;
            db.push([ITEMS[0]]);
            rebuild(false);
        });
        $('btn-reset-db').addEventListener('click', () => {
            db = SAMPLE.map(t => t.slice());
            minSup = 3;
            maxPer = 3;
            rebuild(false);
        });

        $('lang').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b) return;
            lang = b.dataset.lang;
            [...$('lang').children].forEach(x => x.classList.toggle('active', x === b));
            renderCode(CODE_TAGS(trace[cursor]));
        });
        let resizeTimer = null;
        window.addEventListener('resize', () => { clearTimeout(resizeTimer); resizeTimer = setTimeout(reserveExplainHeight, 150); });

        rebuild(false);
    </script>
</body>

</html>
