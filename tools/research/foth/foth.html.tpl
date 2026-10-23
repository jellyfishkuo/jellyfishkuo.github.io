<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/foth.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/foth-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/foth-180.png">
    <title>FOTH 不用 join 的高效益樣式探勘</title>
    <meta name="description" content="一步一步看 FOTH（Information Sciences 2024）怎麼把商品組合編成二進位、讓每筆交易的 IndexSet 自我傳播出子集合，完全不用 utility list 的 join；mining area 上界剪枝，並跟 HUI-Miner 的 join 次數、tid 比對次數並排比較。Java 與 Python 程式碼逐行對照。">
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
        .intro { color: var(--lt-c6c6d6, #c6c6d6); max-width: 800px; margin-top: 0.9rem; font-size: 0.95rem; }
        .intro b { color: var(--text); }
        .intro a { color: var(--accent2); }

        /* 手機：一欄，依序 步驟 → 交易 → utility list → 搜尋樹 → 程式碼 → 結果
           電腦：左欄 步驟／交易／utility list，右欄 搜尋樹／程式碼／結果 */
        .layout { display: grid; gap: 1rem; margin-top: 1.3rem; align-items: start; }
        .col { display: contents; }
        .layout .card { min-width: 0; }
        .a-step { order: 1; }
        .a-data { order: 2; }
        .a-lists { order: 3; }
        .a-tree { order: 4; }
        .a-code { order: 5; }
        .a-result { order: 6; }
        .a-cmp { order: 7; }
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
        .db th .pf { display: block; font: 700 0.7rem 'Space Mono', monospace; color: var(--lt-fcd34d, #fcd34d); margin-top: 0.1rem; }
        .db th.sel { color: var(--warn); }
        .db th.off, .db td.twu.out { opacity: 0.4; }
        .db th.off .nm { text-decoration: line-through; }
        .db td { text-align: center; padding: 0; }
        .db td.tid { font: 0.76rem 'Space Mono', monospace; color: var(--muted); text-align: left; width: 2.4em; padding-left: 0.3rem; }
        .db td.tu { font: 700 0.78rem 'Space Mono', monospace; color: var(--accent2); width: 2.8em; }
        .db td.tu.sel, .db th.tu-h.sel { color: var(--warn); }
        .db tr.cur td, .db tr.match td { background: var(--lt-f59e0b-12, rgba(245, 158, 11, 0.12)); }
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
        .cell.has { background: var(--lt-2a2a48, #2a2a48); }
        .cell.off { opacity: 0.35; text-decoration: line-through; }
        .cell.hit { background: var(--lt-f59e0b-38, rgba(245, 158, 11, 0.38)); }
        .cell small { font-size: 0.62rem; font-weight: 400; color: var(--lt-fcd34d, #fcd34d); }
        .db-note { color: var(--muted); font-size: 0.78rem; margin-top: 0.5rem; }

        /* ── utility list ── */
        .uls { display: flex; flex-wrap: wrap; gap: 0.6rem; align-items: flex-start; min-height: 120px; }
        .uls-empty { color: var(--muted); font-size: 0.85rem; align-self: center; }
        .ul { background: var(--lt-0a0a14, #0a0a14); border: 1px solid var(--border); border-radius: 10px; padding: 0.4rem 0.5rem 0.45rem; min-width: 112px; }
        .ul.res { border-color: var(--accent2); box-shadow: 0 0 0 1px var(--accent2) inset; }
        .ul.focus { border-color: var(--warn); }
        .ul-h { display: flex; align-items: baseline; gap: 0.35rem; font-size: 0.8rem; margin-bottom: 0.2rem; }
        .ul-h .role { font: 700 0.7rem 'Space Mono', monospace; color: var(--accent2); }
        .ul table { border-collapse: collapse; font: 0.74rem 'Space Mono', monospace; width: 100%; }
        .ul th { color: var(--muted); font-weight: 400; text-align: right; padding: 0 0.3rem; font-size: 0.68rem; }
        .ul th:first-child, .ul td:first-child { text-align: left; }
        .ul td { padding: 0.05rem 0.3rem; text-align: right; }
        .ul tr.dim td { opacity: 0.3; }
        .ul tr.new td { background: var(--lt-22c55e-18, rgba(34, 197, 94, 0.18)); }
        .ul tr.ex td { background: var(--lt-f59e0b-22, rgba(245, 158, 11, 0.22)); color: var(--lt-fde68a, #fde68a); }
        .ul tr.sum td { border-top: 1px solid var(--border); font-weight: 700; color: var(--accent2); }
        .ul-f { font-size: 0.7rem; color: var(--muted); margin-top: 0.2rem; }
        .ul-f b { font-family: 'Space Mono', monospace; color: var(--text); }
        .ul-f b.ok { color: var(--lt-86efac, #86efac); }
        .ul-f b.no { color: var(--lt-fca5a5, #fca5a5); }
        .op { align-self: center; color: var(--muted); font: 700 1rem 'Space Mono', monospace; }

        /* ── 搜尋樹 ── */
        .tree { position: relative; max-height: 540px; overflow: auto; background: var(--lt-0a0a14, #0a0a14); border: 1px solid var(--border); border-radius: 10px; padding: 0.5rem 0.6rem; min-height: 140px; }
        .tree-empty { color: var(--muted); font-size: 0.85rem; padding: 1.5rem 0.5rem; text-align: center; }
        .tr, .tr ul { list-style: none; }
        .tr ul { margin-left: 0.6rem; }
        .tr li { position: relative; }
        .tr ul > li { padding-left: 1rem; }
        .tr ul > li::before { content: ''; position: absolute; left: 0; top: 0; bottom: 0; border-left: 1.5px solid var(--lt-34345a, #34345a); }
        .tr ul > li:last-child::before { bottom: auto; height: 1.05rem; }
        .tr ul > li::after { content: ''; position: absolute; left: 0; top: 1.05rem; width: 0.85rem; border-top: 1.5px solid var(--lt-34345a, #34345a); }
        .tn {
            display: inline-flex; flex-wrap: wrap; align-items: center; gap: 0.1rem 0.5rem;
            padding: 0.15rem 0.5rem; margin: 0.15rem 0; border: 1px solid var(--border); border-radius: 8px;
            background: var(--panel-2); font-size: 0.82rem; max-width: 100%;
        }
        .tn .v { font: 0.72rem 'Space Mono', monospace; color: var(--muted); }
        .tn .v b { color: var(--text); }
        .tn .tag { font-size: 0.72rem; border-radius: 5px; padding: 0 0.35rem; background: var(--lt-23233d, #23233d); color: var(--muted); }
        .tn.root { color: var(--muted); }
        .tn.wait, .tn.built { border-style: dashed; }
        .tn.wait .n { color: var(--muted); }
        .tn.hui { border-color: var(--lt-22c55e-60, rgba(34, 197, 94, 0.6)); }
        .tn.hui .tag { background: var(--lt-22c55e-22, rgba(34, 197, 94, 0.22)); color: var(--lt-86efac, #86efac); }
        .tn.go .tag { background: var(--lt-06b6d4-15, rgba(6, 182, 212, 0.15)); color: var(--lt-67e8f9, #67e8f9); }
        .tn.cut { border-color: var(--lt-f87171-50, rgba(248, 113, 113, 0.5)); }
        .tn.cut .tag { background: var(--lt-f87171-18, rgba(248, 113, 113, 0.18)); color: var(--lt-fca5a5, #fca5a5); }
        .tn.cut .n, .tn.empty .n { text-decoration: line-through; color: var(--muted); }
        .tn.empty { opacity: 0.6; border-style: dashed; }
        .tn.cur { box-shadow: 0 0 0 2px var(--warn); }
        .tn.src { box-shadow: 0 0 0 2px var(--lt-06b6d4-70, rgba(6, 182, 212, 0.7)); }
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
        .pat { font-size: 0.82rem; border: 1px solid var(--lt-22c55e-50, rgba(34, 197, 94, 0.5)); border-radius: 7px; padding: 0.12rem 0.5rem; }
        .pat .n { font: 700 0.74rem 'Space Mono', monospace; margin-left: 0.35rem; color: var(--lt-86efac, #86efac); }
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
        .cp.both { border-color: var(--lt-22c55e-50, rgba(34, 197, 94, 0.5)); }
        .cp.hui { border-color: var(--lt-f59e0b-60, rgba(245, 158, 11, 0.6)); }
        .cp.freq { border-style: dashed; }

        .notes { margin-top: 1rem; display: grid; gap: 1rem; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr; } }
        .notes p, .notes li { color: var(--lt-c6c6d6, #c6c6d6); font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; margin-top: 0.5rem; }
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

        /* ── 二進位編碼：一格一個位元，左邊是最高位 ── */
        .bits { display: inline-flex; gap: 2px; vertical-align: middle; flex: none; }
        .bits i {
            font-style: normal; width: 1.45rem; height: 1.45rem; border-radius: 5px;
            display: inline-flex; align-items: center; justify-content: center;
            background: var(--lt-16162a, #16162a); color: var(--lt-4a4a66, #4a4a66); font: 700 0.72rem 'Space Mono', monospace;
        }
        .bits i.on { background: var(--lt-2a2a48, #2a2a48); color: var(--text); font-size: 0.8rem; }
        .bits i.fx { box-shadow: inset 0 -2px 0 var(--accent2); }
        .bits i.lk { outline: 1px dashed var(--lt-f59e0b-70, rgba(245, 158, 11, 0.7)); outline-offset: -1px; }
        .bits i.drop { background: var(--lt-f87171-28, rgba(248, 113, 113, 0.28)); color: var(--lt-fecaca, #fecaca); }
        .bits-n { font: 0.72rem 'Space Mono', monospace; color: var(--muted); margin-left: 0.35rem; }
        .db tfoot td.bitpos { color: var(--muted); font-weight: 400; }

        /* ── 紅黑樹 R：照編碼由大到小 ── */
        .rlist { display: flex; flex-direction: column; align-items: flex-start; gap: 0.1rem; }
        .rlist .tn { gap: 0.1rem 0.45rem; }
        .rlist .tn.out { opacity: 0.55; border-style: dashed; }
        .ul.wide { flex: 1 1 100%; }
        .ul .bits i { width: 1.25rem; height: 1.25rem; }
        .subs-box { max-height: 250px; overflow: auto; }
        .ul td.flag { color: var(--lt-86efac, #86efac); font-size: 0.68rem; white-space: nowrap; }
        .ul td.flag.add { color: var(--muted); }
        .vs-line { font-size: 0.85rem; color: var(--lt-c6c6d6, #c6c6d6); flex: 1 1 100%; }
        .vs-line b { font-family: 'Space Mono', monospace; }
        .vs-line b.ok { color: var(--lt-86efac, #86efac); }
        .vs-line b.no { color: var(--lt-fca5a5, #fca5a5); }

        /* ── 並排比較 ── */
        .cmp-table { width: 100%; border-collapse: collapse; font-size: 0.84rem; }
        .cmp-table th, .cmp-table td { padding: 0.35rem 0.4rem; border-bottom: 1px solid var(--border); text-align: right; }
        .cmp-table th:first-child, .cmp-table td:first-child { text-align: left; color: var(--lt-c6c6d6, #c6c6d6); }
        .cmp-table th { color: var(--muted); font-weight: 400; font-size: 0.78rem; }
        .cmp-table td { font: 700 0.9rem 'Space Mono', monospace; }
        .cmp-table td:first-child { font: 0.84rem inherit; font-family: inherit; font-weight: 400; }
        .cmp-table td.win { color: var(--lt-86efac, #86efac); }
        .cmp-table td.lose { color: var(--lt-fca5a5, #fca5a5); }
        .paper p { color: var(--lt-c6c6d6, #c6c6d6); font-size: 0.92rem; margin-top: 0.4rem; }
        .paper .cite { font-size: 0.88rem; color: var(--text); border-left: 3px solid var(--accent); padding-left: 0.7rem; }
        .paper .cite a { color: var(--accent2); word-break: break-all; }
    </style>
    <link rel="stylesheet" href="../assets/theme.css">
</head>

<body>
    <div class="wrap">
        <a class="back" href="../index.html#research">← RETURN TO PORTFOLIO</a>
        <div class="kicker">RESEARCH DEMO · PAPER · HIGH-UTILITY ITEMSET MINING</div>
        <h1>FOTH 不用 join 的高效益樣式探勘<small>讓每筆交易自己拆出子集合，取代 utility list 的合併</small></h1>
        <p class="intro">
            <a href="high-utility.html">HUI-Miner</a> 每往下一層，就要把兩張 utility list <b>join</b>：一筆一筆比對 tid，找出兩邊都有的交易，這是 list 類演算法最花時間的地方。
            這篇 2024 年的論文問：<b>能不能完全不 join？</b>FOTH 把每個商品組合編成一個<b>二進位數字</b>，每筆交易先變成一個 <b>IndexSet</b>，
            處理完一個 IndexSet，它的每個 vector 就<b>自己拿掉一個商品</b>、變成子集合，直接接到同編碼的 IndexSet 後面（<b>自我傳播</b>）。
            從編碼最大的開始處理，輪到誰的時候，它的資料剛好收齊；用來剪枝的上界跟 HUI-Miner 是同一個數。資料用跟 HUI-Miner 頁一樣的 8 筆交易，也可以切成論文裡的範例。
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
                        <span>資料</span>
                        <div class="lang" id="ds">
                            <button data-ds="shop" class="active">超商 8 筆</button>
                            <button data-ds="paper">論文範例 6 筆</button>
                        </div>
                    </div>
                    <div class="mu">
                        <span>最小效益門檻</span>
                        <button class="btn stepper" id="mu-minus" aria-label="減少">−</button>
                        <span class="val" id="mu-val">250</span>
                        <button class="btn stepper" id="mu-plus" aria-label="增加">+</button>
                        <input type="range" id="mu-range" min="100" max="500" step="10" value="250" aria-label="最小效益門檻">
                        <span class="pct" id="mu-pct"></span>
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

                <div class="card a-data">
                    <div class="card-head"><h2>交易資料庫</h2><span class="sub" id="db-sub"></span></div>
                    <table class="db" id="db"></table>
                    <p class="db-note">格子裡是購買數量，商品下面是單位利潤；TU 是這筆交易的總效益，TWU 是有買這個商品的交易 TU 加起來。「位元」是這個商品在編碼裡的位置。</p>
                </div>

                <div class="card a-lists">
                    <div class="card-head"><h2>這一步的 IndexSet</h2><span class="sub" id="ul-sub"></span></div>
                    <div class="uls" id="uls"></div>
                    <p class="legend" style="margin-top:0.55rem">格子是編碼（左邊最高位），有商品的位元是 1；底下青線 = 這一區固定的位元，橘色虛框 = 被 fixedPos 鎖住、不能再拿掉。</p>
                </div>
            </div>

            <div class="col">
                <div class="card a-tree">
                    <div class="card-head"><h2>紅黑樹 R 裡的 IndexSet</h2><span class="sub" id="r-sub">照編碼由大到小，上面的先處理</span></div>
                    <div class="tree" id="tree"></div>
                    <div class="legend">
                        <span><i style="border-color:rgba(6,182,212,0.7)"></i>這一區（mining area）</span>
                        <span><i style="border-color:var(--warn)"></i>這一步收到 vector</span>
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
                    <h2>目前找到的高效益樣式</h2>
                    <div class="levels" id="levels"></div>
                    <div class="stats">
                        <div class="stat"><div class="v" id="st-scan">0</div><div class="k">掃描資料庫次數</div></div>
                        <div class="stat"><div class="v" id="st-sets">0</div><div class="k">建立的 IndexSet</div></div>
                        <div class="stat"><div class="v" id="st-vecs">0</div><div class="k">產生的 vector（接上去的次數）</div></div>
                        <div class="stat"><div class="v" id="st-prune">0</div><div class="k">被上界剪掉的 mining area</div></div>
                    </div>
                </div>

                <div class="card a-cmp">
                    <div class="card-head"><h2>跟 HUI-Miner 並排比</h2><span class="sub" id="cmp-sub"></span></div>
                    <div id="cmp"></div>
                </div>
            </div>
        </div>

        <div class="notes" style="grid-template-columns:minmax(0, 1fr)">
            <div class="card paper">
                <h2>📄 論文</h2>
                <p class="cite">Yihe Yan, Xinzheng Niu, Zhiheng Zhang, Philippe Fournier-Viger, Libin Ye, Fan Min.
                    <b>Efficient high utility itemset mining without the join operation.</b>
                    <i>Information Sciences</i>, Vol. 681, Article 121218, 2024.
                    DOI：<a href="https://doi.org/10.1016/j.ins.2024.121218" target="_blank" rel="noopener">10.1016/j.ins.2024.121218</a></p>
                <p><b>它在解決什麼：</b>HUI-Miner 之後的 list 類方法（FHM、HUI-Miner*、ULB-Miner、UBP-Miner…）大多在想辦法把 join 做快一點：二分搜尋、兩邊一起掃、把 tid 編成位元做 AND。這篇換個方向，乾脆不 join。</p>
                <p><b>三個想法：</b>（1）商品照 TWU 排好後，第 i 個商品對應一個位元，一個組合就是一個整數編碼，可以排序、放進紅黑樹查找；
                    （2）<b>IndexSet</b> 把同一個組合在每筆交易裡的效益（vector）收在一起，交易本身就是第一批 IndexSet；
                    （3）<b>自我傳播</b>：IndexSet 被處理完，它的 vector 各自拿掉一個商品變成子 vector，接到對應的 IndexSet 後面；
                    每個 vector 帶一個 <b>fixedPos</b>，記住哪些商品已經不能再拿，同一筆交易的同一個子集合就只會被產生一次。
                    搜尋時用編碼大小切出 <b>mining area</b>，區裡 utilSum 的總和就是 HUI-Miner 用的「效益 + 剩餘效益」上界。</p>
                <p><b>實驗結果：</b>在 8 個常用資料集上跟 UBP-Miner、HUI-Miner*、mHUI-Miner、ULB-Miner 比，稠密資料（Connect、Chess、Mushroom、Accidents…）快很多，
                    因為高效益樣式很長，FOTH 找長樣式需要的步驟少；稀疏資料（Retail、Chainstore）樣式短，反而比較慢。記憶體在大部分資料集上用得比較多，因為傳播會產生很多 vector。</p>
                <p><b>這頁的實作：</b>照論文的資料結構與想法（編碼、IndexSet、fixedPos、由大到小的 mining area、vs 剪枝），寫成每次只拿掉一個商品的版本；
                    在被剪掉的區裡只傳出「拿掉固定位元」的子 vector，區內的子集合不產生。論文的虛擬碼一次往下傳好幾層，細節寫得比較簡略，這頁沒有逐行照抄。
                    結果用隨機資料跟暴力法比對過完全一致，切到「論文範例」、門檻 20 時，找到的 9 個樣式和論文的表 4 一樣。</p>
                <p><b>跟網站上其他 Demo 的關係：</b>它要取代的是 <a href="high-utility.html">HUI-Miner</a> 的 join；上界和搜尋順序也跟 HUI-Miner 一樣。
                    其他高效益方法：<a href="two-phase.html">Two-Phase</a>（產生候選再驗證）、<a href="up-growth.html">UP-Growth</a>（樹）、<a href="efim.html">EFIM</a>（投影資料庫、更緊的上界）、
                    <a href="top-k-hui.html">Top-K</a>（不用設門檻）、<a href="ihup.html">IHUP</a>（增量）。</p>
            </div>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼不 join 也算得對？</h2>
                <ul>
                    <li><b>每個子集合只產生一次：</b>一筆交易的某個子集合 S，看成「把多出來的商品從高位往低位一個一個拿掉」，路徑只有一條。
                        fixedPos 就是在記「上一次拿到哪個位元」，只准拿更低的，所以不會有兩條路都走到 S（論文說的重複傳播）。</li>
                    <li><b>輪到 X 時已經收齊：</b>拿掉商品只會讓編碼變小，而處理順序是編碼由大到小，所以 X 的超集合（編碼都比 X 大）一定先處理、先把 vector 傳給 X。
                        輪到 X 的時候，每筆含 X 的交易剛好留下一個 vector，utilSum 就是 X 的效益。</li>
                    <li><b>vs 是安全的上界：</b>mining area 固定了高位元 L，比它更高的區都已經做完、刪掉。每筆含 L 的交易在區裡剛好一個 vector：L 加上這筆交易所有更低位的商品。
                        加起來就是 U(L) + RU(L)，跟 HUI-Miner 的 Σiutil + Σrutil 一樣，不夠就整區剪掉。</li>
                    <li><b>剪掉的區還是要往外傳：</b>區外的組合（少了 L 裡的某個商品）還需要這些交易的資料，所以只傳「拿掉 L 裡的商品」的子 vector；只拿掉低位元的不傳，那些都在被剪掉的區裡。</li>
                </ul>
            </div>
            <div class="card">
                <h2>優缺點，以及跟實驗室研究的關係</h2>
                <ul>
                    <li><b>省掉的：</b>完全沒有 tid 比對。HUI-Miner 每個新組合都要把兩張 list 對一遍（有前綴時還要再查 P 的那一列）；FOTH 只是「查編碼、接在後面」。</li>
                    <li><b>多出來的：</b>一個 vector 會傳出好幾個子 vector，總數通常比 utility list 的列數多，記憶體用得比較多；樣式短、資料稀疏時，大部分 vector 都白傳了，所以論文在 Retail、Chainstore 上比較慢。</li>
                    <li><b>同一棵搜尋樹：</b>商品照 TWU 排好之後，FOTH 的 mining area 跟 HUI-Miner 的集合列舉樹一一對應，檢查的組合、用的上界都一樣（右上的比較表）；差別只在效益怎麼來。</li>
                    <li><b>可以延伸的方向：</b>每筆交易各自傳播、彼此不用比對，這個性質跟增量資料庫很合：新進來的交易只要自己拆、自己接上去。論文沒有做增量版本，論文最後也提到想再加剪枝來減少 IndexSet 的數量，這些都是可以想的題目。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           FOTH 一步一步看
           網頁裡用 JavaScript 照著同樣的流程跑一次，把每一步（含每一層 Mine 遞迴）記下來；
           右邊的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = /*CODE_JSON*/null;

        const DATASETS = {
            shop: {
                ITEMS: ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片'],
                EMOJI: { '咖啡': '☕', '麵包': '🍞', '牛奶': '🥛', '飯糰': '🍙', '茶葉蛋': '🥚', '洋芋片': '🥔' },
                PROFIT: { '咖啡': 30, '麵包': 15, '牛奶': 20, '飯糰': 10, '茶葉蛋': 5, '洋芋片': 25 },
                /* 跟 HUI-Miner 頁同樣的 8 筆交易與購買數量 */
                DB: [
                    { '咖啡': 4, '麵包': 2, '牛奶': 2 },
                    { '咖啡': 3, '麵包': 5, '茶葉蛋': 4 },
                    { '咖啡': 1, '麵包': 1, '牛奶': 2, '飯糰': 2 },
                    { '麵包': 3, '牛奶': 4, '洋芋片': 5 },
                    { '咖啡': 3, '牛奶': 2, '茶葉蛋': 2 },
                    { '咖啡': 1, '麵包': 2, '牛奶': 1, '茶葉蛋': 1 },
                    { '飯糰': 1, '茶葉蛋': 2, '洋芋片': 2 },
                    { '咖啡': 1, '麵包': 2, '飯糰': 1 }
                ],
                mu: { min: 100, max: 500, step: 10, def: 250 }
            },
            /* 論文第 3 節的範例資料庫（表 1 數量、表 2 單位利潤），門檻 20 時答案是論文表 4 的 9 個樣式 */
            paper: {
                ITEMS: ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
                EMOJI: {},
                PROFIT: { a: 4, b: 2, c: 1, d: 1, e: 2, f: 6, g: 3 },
                DB: [
                    { a: 1, b: 1, d: 1, e: 3 },
                    { d: 3 },
                    { e: 1, f: 2, g: 3 },
                    { b: 3, c: 2, d: 2, e: 4 },
                    { a: 3, d: 3, g: 3 },
                    { b: 1, c: 2, d: 2, g: 3 }
                ],
                mu: { min: 5, max: 60, step: 1, def: 20 }
            }
        };
        let dsKey = 'shop', ITEMS, EMOJI, PROFIT, DB, MU_MIN, MU_MAX, MU_STEP, minUtil;
        function useDataset(k) {
            const d = DATASETS[k];
            dsKey = k;
            ({ ITEMS, EMOJI, PROFIT, DB } = d);
            MU_MIN = d.mu.min; MU_MAX = d.mu.max; MU_STEP = d.mu.step; minUtil = d.mu.def;
        }
        useDataset('shop');

        const $ = id => document.getElementById(id);
        let lang = 'java';
        let trace = [];
        let cursor = 0;
        let timer = null;

        /* 跟 Java 的 compareTo、Python 的字串比較同一個順序（依字碼） */
        const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
        const esc = x => String(x).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
        const fmt = set => esc('{' + set.join(', ') + '}');
        const plain = set => '{' + set.join(', ') + '}';
        const arrowPath = items => esc(items.join(' → '));
        const tName = tid => 'T' + (tid + 1);
        const has = (t, item) => Object.prototype.hasOwnProperty.call(t, item);
        const sym = i => EMOJI[i] || i;
        const bin = (code, n) => n ? code.toString(2).padStart(n, '0') : '';

        /* ---------- HUI-Miner 的成本（拿來並排比）：join 幾次、比對 tid 幾次、建了幾列 ---------- */
        function huiCost(db, profit, minUtil) {
            const tu = db.map(t => Object.keys(t).reduce((a, i) => a + t[i] * profit[i], 0));
            const twu = {};
            db.forEach((t, k) => Object.keys(t).forEach(i => { twu[i] = (twu[i] || 0) + tu[k]; }));
            const order = Object.keys(twu).filter(i => twu[i] >= minUtil).sort((a, b) => twu[a] - twu[b] || cmp(a, b));
            const c = { joins: 0, comps: 0, rows: 0, checks: 0, found: 0 };
            const lists = order.map(i => ({ rows: [], iu: 0, ru: 0 }));
            db.forEach((t, tid) => {
                let ru = 0;
                for (let k = order.length - 1; k >= 0; k--) {
                    if (!has(t, order[k])) continue;
                    const u = t[order[k]] * profit[order[k]];
                    lists[k].rows.push([tid, u, ru]); lists[k].iu += u; lists[k].ru += ru; ru += u;
                }
            });
            lists.forEach(l => { c.rows += l.rows.length; });
            // 兩張 list 都照 tid 排好，兩邊一起往前掃（O(n + m)）；有前綴 P 時再往前掃 P 找同一筆
            function construct(p, px, py) {
                c.joins++;
                const xy = { rows: [], iu: 0, ru: 0 };
                let a = 0, b = 0, k = 0;
                while (a < px.rows.length && b < py.rows.length) {
                    c.comps++;
                    const ta = px.rows[a][0], tb = py.rows[b][0];
                    if (ta < tb) a++;
                    else if (ta > tb) b++;
                    else {
                        let iu = px.rows[a][1] + py.rows[b][1];
                        if (p) { while (p.rows[k][0] !== ta) { c.comps++; k++; } c.comps++; iu -= p.rows[k][1]; }
                        xy.rows.push([ta, iu, py.rows[b][2]]); xy.iu += iu; xy.ru += py.rows[b][2];
                        a++; b++;
                    }
                }
                return xy;
            }
            function search(p, uls) {
                uls.forEach((x, i) => {
                    c.checks++;
                    if (x.iu >= minUtil) c.found++;
                    if (x.iu + x.ru < minUtil) return;
                    const ext = [];
                    for (let j = i + 1; j < uls.length; j++) {
                        const xy = construct(p, x, uls[j]);
                        if (xy.rows.length) { ext.push(xy); c.rows += xy.rows.length; }
                    }
                    search(x, ext);
                });
            }
            search(null, lists);
            return c;
        }

        /* ---------- 照著程式跑一次，記下每一步 ---------- */
        function buildTrace(db, profit, minUtil) {
            const steps = [], result = [];
            const stats = { scans: 0, sets: 0, vecs: 0, areas: 0, pruned: 0, empty: 0 };
            const st = { tu: [], twu: {}, order: [], removed: [], twuCalc: false, twuDone: false, n: 0 };
            const R = new Map();                 // 編碼 -> IndexSet（Java 用 TreeMap = 紅黑樹）
            let touched = new Map();             // 這一步收到 vector 的 IndexSet：'new' 新建 / 'add' 接上
            let n = 0;
            const view = S => ({ code: S.code, util: S.util, vecs: S.vecs.map(v => ({ tid: v.tid, us: v.us, f: v.f, utils: v.utils })) });
            const push = (kind, extra = {}) => {
                steps.push({
                    kind, ...extra, n,
                    stats: { ...stats },
                    result: result.map(r => ({ ...r })),
                    R: [...R.values()].sort((a, b) => b.code - a.code).map(S => ({ code: S.code, util: S.util, nv: S.vecs.length, mark: touched.get(S.code) || '' })),
                    tu: st.tu.slice(), twu: { ...st.twu }, order: st.order.slice(), removed: st.removed.slice(), twuCalc: st.twuCalc, twuDone: st.twuDone
                });
                result.forEach(r => { r.fresh = false; });
                touched = new Map();
            };
            const mkVec = (tid, utils, f) => {
                let us = 0, size = 0;
                utils.forEach(u => { if (u) { us += u; size++; } });
                return { tid, utils, us, size, f };
            };
            const put = (code, v) => {
                let S = R.get(code);
                const isNew = !S;
                if (isNew) { S = { code, util: 0, vecs: [] }; R.set(code, S); stats.sets++; }
                S.vecs.push(v);
                S.util += v.us;
                stats.vecs++;
                if (!touched.has(code)) touched.set(code, isNew ? 'new' : 'add');
                return isNew;
            };

            push('start');

            // 1. 第 1 次掃描：TU 與 TWU
            stats.scans++;
            st.tu = db.map(t => Object.keys(t).reduce((a, i) => a + t[i] * profit[i], 0));
            push('tu');
            db.forEach((t, k) => Object.keys(t).forEach(i => { st.twu[i] = (st.twu[i] || 0) + st.tu[k]; }));
            st.twuCalc = true;
            push('twu');
            const byTwu = (a, b) => st.twu[a] - st.twu[b] || cmp(a, b);
            st.order = Object.keys(st.twu).filter(i => st.twu[i] >= minUtil).sort(byTwu);
            st.removed = Object.keys(st.twu).filter(i => st.twu[i] < minUtil).sort(byTwu);
            st.twuDone = true;
            n = st.order.length;
            push('cut');

            // 2. 第 2 次掃描：每筆交易變成一個 vector，放進同樣編碼的 IndexSet
            stats.scans++;
            db.forEach((t, tid) => {
                const utils = new Array(n).fill(0);
                let code = 0;
                st.order.forEach((it, k) => {
                    if (!has(t, it)) return;
                    utils[n - 1 - k] = t[it] * profit[it];      // 第 k 個商品放在位元 n-1-k
                    code |= 1 << (n - 1 - k);
                });
                const dropped = Object.keys(t).filter(i => st.removed.includes(i));
                if (!code) { push('build', { tid, vec: null, dropped }); return; }
                const v = mkVec(tid, utils, n);
                const others = R.has(code) ? R.get(code).vecs.map(x => x.tid) : [];
                const isNew = put(code, v);
                push('build', { tid, vec: { tid, us: v.us, f: n, utils }, code, isNew, others, total: R.get(code).util, dropped, first: tid === 0 });
            });

            // 3. 挖：mining area 由大到小
            const decode = c => st.order.filter((it, k) => c >> (n - 1 - k) & 1);
            const itemAt = b => st.order[n - 1 - b];
            let first = true, firstProp = true;
            function proc(c, low) {
                const S = R.get(c);
                R.delete(c);
                const is = view(S), items = decode(c);
                const out = S.util >= minUtil;
                if (out) result.push({ set: items, util: S.util, fresh: true });
                const subs = [];
                S.vecs.forEach(v => {
                    for (let y = 0; y < n; y++) {
                        // 只拿掉 low 裡的、而且在 fixedPos 下面的商品：同一筆交易的同一個子集合只會出現一次
                        if (!v.utils[y] || !(low >> y & 1) || y >= v.f || v.size === 1) continue;
                        const u = v.utils.slice();
                        u[y] = 0;
                        const sv = mkVec(v.tid, u, y);
                        const code = c - (1 << y);
                        const isNew = put(code, sv);
                        subs.push({ tid: v.tid, y, item: itemAt(y), code, us: sv.us, isNew, utils: u });
                    }
                });
                return { is, items, out, subs };
            }
            function mine(low) {
                const bit = low & -low, j = 31 - Math.clz32(bit);
                const area = [...R.keys()].filter(c => c >= low && c < low + bit).sort((a, b) => b - a);
                if (!area.length) { stats.empty++; return; }        // 沒有交易含這個組合：什麼都不用做
                const vs = area.reduce((a, c) => a + R.get(c).util, 0);
                const split = vs >= minUtil;
                stats.areas++;
                if (!split) stats.pruned++;
                const L = decode(low);
                const lower = st.order.filter((it, k) => n - 1 - k < j);
                const gaps = st.order.filter((it, k) => n - 1 - k > j && !(low >> (n - 1 - k) & 1));
                const kids = [];
                for (let b = bit >> 1; b; b >>= 1) kids.push(low + b);
                push('area', { low, bit, j, L, lower, gaps, vs, split, kids, area: area.map(c => view(R.get(c))), first, cur: low });
                first = false;
                if (split) {
                    kids.forEach(mine);
                    if (R.has(low)) {
                        const p = proc(low, low);
                        push('proc', { low, j, L, lower, ...p, firstProp: firstProp && p.subs.length > 0, cur: low });
                        if (p.subs.length) firstProp = false;
                    }
                } else {
                    const procs = area.map(c => proc(c, low));
                    push('flush', { low, j, L, lower, vs, procs, cur: low });
                }
            }
            for (let b = n - 1; b >= 0; b--) mine(1 << b);
            push('end', { hui: huiCost(db, profit, minUtil) });
            return steps;
        }

        /* ---------- 說明文字 ---------- */
        const qp = (t, items) => items.map(i => `${t[i]}×${PROFIT[i]}`).join(' + ');
        const B = (code, s) => `<b>${bin(code, s.n)}</b>`;
        function describe(s) {
            switch (s.kind) {
                case 'start':
                    return `FOTH 找的跟 HUI-Miner 一樣：效益（數量 × 利潤加起來）至少 <b>${minUtil}</b> 的所有組合。` +
                        `HUI-Miner 每長出一個新組合，都要把兩張 utility list <b>join</b>：一筆一筆比對 tid，找兩邊都有的交易。` +
                        `FOTH 改成把每個組合編成一個<b>二進位數字</b>，讓每筆交易<b>自己拆出子集合</b>，直接接到同編碼的 IndexSet 後面，整個過程不比對任何 tid。`;
                case 'tu': {
                    const k = s.tu.indexOf(Math.max(...s.tu));
                    return `第 1 次掃描資料庫：先算每筆交易的總效益 <b>TU</b>（表格最右邊那欄）。例如 ${tName(k)} = ${qp(DB[k], Object.keys(DB[k]))} = ${s.tu[k]}，是最賺的一筆。`;
                }
                case 'twu': {
                    const i = Object.keys(s.twu).sort((a, b) => s.twu[a] - s.twu[b] || cmp(a, b))[0];
                    const ks = DB.map((t, k) => k).filter(k => has(DB[k], i));
                    return `同一次掃描順便算每個商品的 <b>TWU</b>：有買它的交易 TU 加起來（表格最下面）。例如 ${esc(i)} 出現在 ${ks.map(tName).join('、')}：` +
                        `${ks.map(k => s.tu[k]).join(' + ')} = ${s.twu[i]}。含這個商品的組合，效益都不會超過它的 TWU。`;
                }
                case 'cut': {
                    let t = s.removed.length
                        ? s.removed.map(i => `${esc(i)} 的 TWU 只有 ${s.twu[i]}`).join('、') + ` < ${minUtil}，<b>整個刪掉</b>（交易裡的它也當作沒買）。`
                        : `每個商品的 TWU 都至少 ${minUtil}，沒有商品被刪掉。`;
                    if (!s.order.length) return t + '沒有商品留下來，不可能有高效益樣式。';
                    const ex = s.order.slice(0, 2), code = ex.reduce((a, it) => a + (1 << (s.n - 1 - s.order.indexOf(it))), 0);
                    t += `剩下的照 TWU 由小到大排成 ${arrowPath(s.order)}，然後<b>編碼</b>：排第 1 的 ${esc(s.order[0])} 放在最高位元（位元 ${s.n - 1}），` +
                        `最後的 ${esc(s.order[s.n - 1])} 在位元 0。一個組合的編碼就是它的位元加起來` +
                        (ex.length > 1 ? `，例如 ${fmt(ex)} = ${B(code, s)} = ${code}。` : '。') +
                        `編碼越大，含的商品越「不賺」，FOTH 就從這邊開始挖。`;
                    return t;
                }
                case 'build': {
                    const T = tName(s.tid), t = DB[s.tid];
                    const drop = s.dropped.length ? `（${esc(s.dropped.join('、'))} 已經被刪掉，不算）` : '';
                    if (!s.vec) return `第 2 次掃描：${T} 裡沒有留下來的商品${drop}，跳過。`;
                    const items = s.order.filter(i => has(t, i));
                    let x = `第 2 次掃描：${T} 留下 ${fmt(items)}${drop}，變成一個 <b>vector</b>：utilSum = ${qp(t, items)} = ${s.vec.us}，編碼 ${B(s.code, s)} = ${s.code}。`;
                    x += s.isNew ? `R 裡還沒有這個編碼，<b>新建</b>一個 IndexSet 放進去。`
                        : `R 裡已經有編碼 ${B(s.code, s)} 的 IndexSet（${s.others.map(tName).join('、')} 買的也剛好是這幾樣），直接<b>接在後面</b>，utilSum 變成 ${s.total}。`;
                    if (s.first) x += `交易本身就是一個組合，所以第一批 IndexSet 就是交易。`;
                    return x;
                }
                case 'area': {
                    const parts = s.area.map(a => a.util);
                    let t = `<b>Mine(${bin(s.low, s.n)})</b>：固定 ${fmt(s.L)}` + (s.gaps.length ? `、不含 ${fmt(s.gaps)}` : '') +
                        (s.lower.length ? `，下面的 ${fmt(s.lower)} 可有可無。` : `，下面沒有位元了。`) +
                        `這一區（mining area）是 R 裡 ${s.area.length} 個 IndexSet，utilSum 加起來 vs = ${parts.length > 1 ? parts.join(' + ') + ' = ' : ''}${s.vs}，` +
                        `剛好是 ${fmt(s.L)} 的<b>效益 + 剩餘效益</b>（HUI-Miner 的 Σiutil + Σrutil）。`;
                    if (s.split) t += `${s.vs} ≥ ${minUtil}，還有機會：` +
                        (s.kids.length ? `再多固定一個位元，依序挖 ${s.kids.map(c => bin(c, s.n)).join('、')}，最後再處理 ${bin(s.low, s.n)} 自己。` : `下面沒有位元可以分，直接處理它。`);
                    else t += `${s.vs} < ${minUtil}：這一區的組合效益全都不可能達標，<b>不再細分（剪掉）</b>。`;
                    return t;
                }
                case 'proc': {
                    const { is } = s, X = fmt(s.items);
                    let t = (s.lower.length ? `回到 ${bin(s.low, s.n)}：小區都做完了，區裡只剩 ${X} 自己。` : `處理 ${X}。`) +
                        `比它大的超集合都已經把 vector 傳給它，所以已經<b>收齊</b>：${is.vecs.length} 個 vector（${is.vecs.map(v => tName(v.tid)).join('、')}），` +
                        `utilSum = ${is.util}` + (s.out ? ` ≥ ${minUtil}，<b>是高效益樣式，輸出</b>。` : ` < ${minUtil}，不輸出。`);
                    if (s.subs.length) {
                        const nn = s.subs.filter(x => x.isNew).length;
                        t += `接著<b>自我傳播</b>：每個 vector 拿掉一個 fixedPos 以下的商品，共傳出 ${s.subs.length} 個子 vector，直接接到對應的 IndexSet 後面` +
                            (nn ? `（新建 ${nn} 個）` : '') + `，不比對任何 tid。`;
                        if (s.firstProp) t += `fixedPos 記的是「上次拿掉哪個位元」，只准再拿更低的，同一筆交易的同一個子集合才不會被傳兩次。`;
                    } else {
                        t += s.items.length === 1 ? `只有一個商品，拿掉就是空集合，不用傳。` : `每個 vector 能拿的商品都被 fixedPos 鎖住了（那些子集合走別條路產生過），不用傳。`;
                    }
                    return t + `最後把它從 R 刪掉。`;
                }
                case 'flush': {
                    const k = s.procs.reduce((a, p) => a + p.subs.length, 0);
                    return `整區剪掉：這 ${s.procs.length} 個 IndexSet 不輸出、也不再細分。但「沒有包含 ${fmt(s.L)} 全部」的組合還沒挖，它們需要這些交易的資料，` +
                        `所以每個 vector <b>只拿掉 ${fmt(s.L)} 裡</b>、fixedPos 以下的商品，共傳出 ${k} 個子 vector 到區外。` +
                        (s.lower.length ? `只拿掉 ${fmt(s.lower)} 的子集合都還在這一區裡，一個都不用產生，<b>這就是剪枝省下的工作</b>。` : '');
                }
                case 'end': {
                    const h = s.hui, n = s.result.length;
                    return (n ? `完成！找到 <b>${n}</b> 個高效益樣式。` : `完成！沒有任何組合的效益達到 ${minUtil}。`) +
                        `FOTH <b>join 0 次、比對 tid 0 次</b>，產生了 ${s.stats.vecs} 個 vector、建了 ${s.stats.sets} 個 IndexSet。` +
                        `同樣的資料 HUI-Miner 要 join ${h.joins} 次、比對 tid ${h.comps} 次，utility list 共 ${h.rows} 列（下面並排比較）。`;
                }
            }
            return '';
        }

        const CODE_TAGS = s => {
            switch (s.kind) {
                case 'tu': case 'twu': return ['tu'];
                case 'cut': return ['twu'];
                case 'build': return ['build', 'merge'];
                case 'area': return ['area'].concat(s.split ? ['split'] : [], s.first ? ['mine0'] : []);
                case 'proc': return ['proc', 'prop', 'merge'].concat(s.out ? ['output'] : []);
                case 'flush': return ['proc', 'prop', 'merge'];
                default: return [s.kind];        // start / end
            }
        };

        /* ---------- 畫面 ---------- */
        /* 編碼的格子：左邊是最高位元。fixFrom：這一位以上被 mining area 固定；lockFrom：fixedPos（這一位以上不能拿掉）；drop：被拿掉的那一位 */
        function bitsHTML(code, s, { fixFrom = -1, lockFrom = 99, drop = -1, util = null } = {}) {
            let h = '<span class="bits">';
            for (let b = s.n - 1; b >= 0; b--) {
                const on = code >> b & 1, it = s.order[s.n - 1 - b];
                const cls = [on ? 'on' : '', fixFrom >= 0 && b >= fixFrom ? 'fx' : '', on && b >= lockFrom ? 'lk' : '', b === drop ? 'drop' : ''].join(' ').trim();
                h += `<i class="${cls}" title="${esc(it)}${util && util[b] ? ' ' + util[b] : ''}">${on ? esc(sym(it)) : b === drop ? '✕' : '0'}</i>`;
            }
            return h + '</span>';
        }

        function focusOf(s) {
            const items = s.kind === 'area' || s.kind === 'flush' ? s.L : s.kind === 'proc' ? s.items : [];
            const tids = new Set();
            if (items.length) DB.forEach((t, k) => { if (items.every(i => has(t, i))) tids.add(k); });
            return { tids, items: new Set(items) };
        }

        let dbKey = '';
        function drawDB(s) {
            const cols = s.twuDone ? [...s.order, ...s.removed, ...ITEMS.filter(i => !(i in s.twu))] : ITEMS;
            const f = focusOf(s);
            const key = [dsKey, s.kind === 'tu' ? 'tu' : '', s.kind === 'build' ? s.tid : '', s.twuCalc, s.twuDone, s.tu.length, cols.join(), [...f.items].join(), [...f.tids].join()].join('/');
            if (key === dbKey) return;                         // 跟上一步一模一樣就不用重畫
            dbKey = key;
            const off = i => s.removed.includes(i);
            let h = '<thead><tr><th class="tid-h"></th>' + cols.map(i =>
                `<th class="${off(i) ? 'off' : ''}${f.items.has(i) ? ' sel' : ''}"><span class="emo">${esc(sym(i))}</span>${EMOJI[i] ? `<span class="nm">${esc(i)}</span>` : ''}<span class="pf">$${PROFIT[i]}</span></th>`).join('') +
                `<th class="tu-h${s.kind === 'tu' ? ' sel' : ''}">TU</th></tr></thead><tbody>`;
            DB.forEach((t, r) => {
                const cur = s.kind === 'build' && s.tid === r;
                const match = f.tids.has(r);
                const cls = [cur ? 'cur' : '', match ? 'match' : '', s.kind === 'build' && r > s.tid ? 'later' : ''].join(' ');
                h += `<tr class="${cls}"><td class="tid">${tName(r)}</td>` + cols.map(i => {
                    if (!has(t, i)) return '<td><div class="cell"></div></td>';
                    const showU = cur && !off(i);
                    return `<td><div class="cell has${off(i) ? ' off' : ''}${match && f.items.has(i) ? ' hit' : ''}">${t[i]}${showU ? `<small>${t[i] * PROFIT[i]}</small>` : ''}</div></td>`;
                }).join('') + `<td class="tu${s.kind === 'tu' ? ' sel' : ''}">${s.tu.length ? s.tu[r] : ''}</td></tr>`;
            });
            h += '</tbody>';
            if (s.twuCalc) {
                h += '<tfoot><tr><td class="tid">TWU</td>' + cols.map(i => `<td class="twu${off(i) ? ' out' : ''}">${i in s.twu ? s.twu[i] : ''}</td>`).join('') + '<td></td></tr>';
                h += '<tr><td class="tid">位元</td>' + cols.map(i => { const k = s.order.indexOf(i); return `<td class="bitpos">${s.twuDone && k >= 0 ? s.n - 1 - k : ''}</td>`; }).join('') + '<td></td></tr></tfoot>';
            }
            $('db').innerHTML = h;
            $('db-sub').textContent = s.twuDone ? '欄已照 TWU 由小到大排（= 位元由高到低）' : '';
        }

        const fixedName = (v, s) => (v.f >= s.n ? '—' : sym(s.order[s.n - 1 - v.f]));
        /* 一個 IndexSet 的小表格：每列一個 vector（哪筆交易、utilSum、fixedPos） */
        function isBox(is, s, { role = '', cls = '', fixFrom = -1, showF = true, foot = '' } = {}) {
            const items = s.order.filter((it, k) => is.code >> (s.n - 1 - k) & 1);
            const rows = is.vecs.map(v => `<tr><td>${tName(v.tid)}</td><td>${v.us}</td>${showF ? `<td>${esc(fixedName(v, s))}</td>` : ''}</tr>`).join('');
            return `<div class="ul ${cls}"><div class="ul-h">${role ? `<span class="role">${role}</span>` : ''}${bitsHTML(is.code, s, { fixFrom })}</div>` +
                `<div class="ul-h"><span>${fmt(items)}</span></div>` +
                `<table><tr><th>vector</th><th>utilSum</th>${showF ? '<th>fixedPos</th>' : ''}</tr>${rows}` +
                `<tr class="sum"><td>Σ</td><td>${is.util}</td>${showF ? '<td></td>' : ''}</tr></table>${foot ? `<div class="ul-f">${foot}</div>` : ''}</div>`;
        }
        function subsBox(subs, s, title) {
            const rows = subs.map(x => `<tr><td>${tName(x.tid)}</td><td>${esc(sym(x.item))}</td><td>${bitsHTML(x.code, s, { drop: x.y })}</td><td>${x.us}</td>` +
                `<td class="flag${x.isNew ? '' : ' add'}">${x.isNew ? '新建' : '接上'}</td></tr>`).join('');
            return `<div class="ul wide"><div class="ul-h"><span class="role">→</span><span>${esc(title)}</span></div>` +
                (subs.length ? `<div class="subs-box"><table><tr><th>來自</th><th>拿掉</th><th>子 vector 編碼</th><th>util</th><th></th></tr>${rows}</table></div>`
                    : '<div class="ul-f">沒有要傳的。</div>') + '</div>';
        }

        function drawLists(s) {
            const box = $('uls'), sub = $('ul-sub');
            if (s.kind === 'build' && s.vec) {
                const t = DB[s.tid], items = s.order.filter(i => has(t, i));
                sub.textContent = `第 2 次掃描，讀到 ${tName(s.tid)}`;
                const vrows = items.map(i => `<tr><td>${esc(sym(i))} ${EMOJI[i] ? esc(i) : ''}</td><td>${t[i]}×${PROFIT[i]}</td><td>${t[i] * PROFIT[i]}</td></tr>`).join('');
                box.innerHTML = `<div class="ul focus"><div class="ul-h"><span class="role">${tName(s.tid)} 的 vector</span></div><div class="ul-h">${bitsHTML(s.code, s)}<span class="bits-n">= ${s.code}</span></div>` +
                    `<table><tr><th>商品</th><th>數量×利潤</th><th>效益</th></tr>${vrows}<tr class="sum"><td>Σ</td><td></td><td>${s.vec.us}</td></tr></table></div>` +
                    `<span class="op">→</span><div class="ul res"><div class="ul-h"><span class="role">${s.isNew ? '新建' : '接上'}</span>${bitsHTML(s.code, s)}</div>` +
                    `<table><tr><th>vector</th><th>utilSum</th></tr>${s.others.concat([s.tid]).map(k => `<tr class="${k === s.tid ? 'new' : ''}"><td>${tName(k)}</td><td>${DB[k] ? s.order.filter(i => has(DB[k], i)).reduce((a, i) => a + DB[k][i] * PROFIT[i], 0) : ''}</td></tr>`).join('')}` +
                    `<tr class="sum"><td>Σ</td><td>${s.total}</td></tr></table></div>`;
            } else if (s.kind === 'area') {
                sub.textContent = `Mine(${bin(s.low, s.n)}) 的 mining area`;
                box.innerHTML = s.area.map(a => isBox(a, s, { fixFrom: s.j })).join('') +
                    `<div class="vs-line">vs = ${s.area.map(a => a.util).join(' + ')} = <b class="${s.split ? 'ok' : 'no'}">${s.vs}</b> ${s.split ? '≥' : '<'} ${minUtil}　→ ${s.split ? '再細分' : '整區剪掉'}</div>`;
            } else if (s.kind === 'proc') {
                sub.textContent = `處理 ${plain(s.items)}，然後傳播`;
                box.innerHTML = isBox(s.is, s, { cls: s.out ? 'res' : 'focus', fixFrom: s.j, foot: `utilSum <b class="${s.out ? 'ok' : 'no'}">${s.is.util}</b>${s.out ? ' ≥ ' : ' < '}${minUtil}` }) +
                    subsBox(s.subs, s, `傳出去的子 vector（${s.subs.length} 個）`);
            } else if (s.kind === 'flush') {
                const all = [].concat(...s.procs.map(p => p.subs));
                sub.textContent = `剪掉的區：只往外傳`;
                box.innerHTML = s.procs.map(p => isBox(p.is, s, { fixFrom: s.j })).join('') + subsBox(all, s, `傳到區外的子 vector（${all.length} 個）`);
            } else {
                sub.textContent = '';
                const msg = s.kind === 'end' ? '全部做完，R 已經空了。按「上一步」可以回頭看每個 IndexSet 是怎麼收齊、怎麼傳出去的。'
                    : s.kind === 'build' ? `${tName(s.tid)} 沒有留下來的商品，不用建 vector。`
                    : s.kind === 'cut' ? '下一步開始第 2 次掃描，每筆交易變成一個 vector。' : '算完 TWU、排好順序、編好碼之後，第 2 次掃描才開始建。';
                box.innerHTML = `<div class="uls-empty">${msg}</div>`;
            }
        }

        function drawTree(s) {
            const box = $('tree');
            if (!s.twuDone || (s.kind === 'cut')) {
                box.innerHTML = '<div class="tree-empty">第 2 次掃描開始後，交易會一筆一筆變成 IndexSet 放進來。</div>';
                $('r-sub').textContent = '照編碼由大到小，上面的先處理';
                return;
            }
            const lo = s.kind === 'area' ? s.low : -1, hi = s.kind === 'area' ? s.low + s.bit : -1;
            const rows = s.R.map(r => {
                const cls = [r.code >= lo && r.code < hi ? 'src' : '', r.mark ? 'cur' : ''].join(' ');
                const tag = r.mark === 'new' ? '新建' : r.mark === 'add' ? '+vector' : '';
                return `<div class="tn ${cls}">${bitsHTML(r.code, s, s.kind === 'area' ? { fixFrom: s.j } : {})}<span class="v">Σ <b>${r.util}</b> · ${r.nv} 個</span>${tag ? `<span class="tag">${tag}</span>` : ''}</div>`;
            }).join('');
            box.innerHTML = rows ? `<div class="rlist">${rows}</div>` : '<div class="tree-empty">R 已經空了。</div>';
            $('r-sub').textContent = `${s.R.length} 個 IndexSet` + (s.cur !== undefined ? `，目前在 Mine(${bin(s.cur, s.n)})` : '');
            if (measuringBlocks) return;
            const el = box.querySelector('.tn.cur, .tn.src');
            if (el) {
                const y = el.getBoundingClientRect().top - box.getBoundingClientRect().top + box.scrollTop;
                if (y < box.scrollTop + 10 || y + el.offsetHeight > box.scrollTop + box.clientHeight - 10) {
                    box.scrollTo({ top: Math.max(0, y - box.clientHeight / 3), behavior: 'smooth' });
                }
            }
        }

        let resKey = '';
        function drawResult(s) {
            const key = s.result.map(r => r.set.join() + (r.fresh ? '*' : '')).join('|') + '/' + s.kind;
            if (key !== resKey) {
                resKey = key;
                const box = $('levels');
                box.innerHTML = '';
                if (!s.result.length) box.innerHTML = `<div class="empty">${s.kind === 'end' ? '沒有找到。把門檻調低一點試試看。' : '還沒有，開始挖之後會出現在這裡。'}</div>`;
                const bySize = {};
                s.result.forEach(r => { (bySize[r.set.length] = bySize[r.set.length] || []).push(r); });
                Object.keys(bySize).sort().forEach(k => {
                    const row = document.createElement('div');
                    row.className = 'level';
                    row.innerHTML = `<span class="tag">${k} 個</span><div class="items"></div>`;
                    bySize[k].forEach(r => {
                        const p = document.createElement('span');
                        p.className = 'pat' + (r.fresh ? ' fresh' : '');
                        p.innerHTML = `<span></span><span class="n">${r.util}</span>`;
                        p.firstChild.textContent = '{' + r.set.join(', ') + '}';
                        row.querySelector('.items').appendChild(p);
                    });
                    box.appendChild(row);
                });
            }
            $('st-scan').textContent = s.stats.scans;
            $('st-sets').textContent = s.stats.sets;
            $('st-vecs').textContent = s.stats.vecs;
            $('st-prune').textContent = s.stats.pruned;
        }

        /* 並排比較：整個門檻跑完的總數（每一步都一樣，只在重新產生 trace 時畫） */
        function drawCompare() {
            const end = trace[trace.length - 1], h = end.hui, f = end.stats;
            const row = (k, a, b, better) => `<tr><td>${k}</td><td class="${better === 'a' ? 'win' : better === 'b' ? 'lose' : ''}">${a}</td><td class="${better === 'b' ? 'win' : better === 'a' ? 'lose' : ''}">${b}</td></tr>`;
            $('cmp-sub').textContent = `門檻 ${minUtil}，整個跑完`;
            $('cmp').innerHTML = `<table class="cmp-table"><tr><th></th><th>HUI-Miner</th><th>FOTH</th></tr>` +
                row('掃描資料庫', 2, f.scans, '') +
                row('檢查的組合（搜尋樹節點）', h.checks, f.areas, '') +
                row('合併兩張 list（join）', h.joins, 0, h.joins ? 'b' : '') +
                row('比對 tid', h.comps, 0, h.comps ? 'b' : '') +
                row('建出來的資料列（list 列 / vector）', h.rows, f.vecs, h.rows === f.vecs ? '' : h.rows < f.vecs ? 'a' : 'b') +
                row('找到的高效益樣式', h.found, end.result.length, '') + '</table>' +
                `<p class="legend" style="margin-top:0.55rem">兩邊檢查的組合一樣多，剪枝用的上界也是同一個數；差別在效益怎麼來：HUI-Miner 每個新組合都要對一次 tid，FOTH 只要查編碼、接在後面。` +
                `代價是 vector 通常比 list 的列多（記憶體），論文的實驗也是這樣。</p>`;
        }
        const KW = {
            java: new Set('public static final for if return new boolean int long void class import while else null this continue'.split(' ')),
            py: new Set('def for in if return not and or while import from as True False None class is lambda continue del'.split(' '))
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
                ? '下載 <a href="code/FOTH.java" download>FOTH.java</a>　執行 <code>javac FOTH.java && java FOTH</code>'
                : '下載 <a href="code/foth.py" download>foth.py</a>　執行 <code>python3 foth.py</code>';
        }


        /* ---------- 顯示某一步 ---------- */
        function showStep() {
            const s = trace[cursor];
            $('explain').innerHTML = `<span class="step-no">步驟 ${cursor + 1} / ${trace.length}</span>${describe(s)}`;
            drawDB(s);
            drawLists(s);
            drawTree(s);
            drawResult(s);
            renderCode(CODE_TAGS(s));
            $('btn-prev').disabled = $('btn-first').disabled = cursor === 0;
            $('btn-next').disabled = cursor === trace.length - 1;
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

        function rebuild() {
            stopAuto();
            trace = buildTrace(DB, PROFIT, minUtil);
            cursor = 0;
            dbKey = resKey = '';
            const r = $('mu-range');
            r.min = MU_MIN; r.max = MU_MAX; r.step = MU_STEP; r.value = minUtil;
            $('mu-val').textContent = minUtil;
            $('mu-minus').disabled = minUtil <= MU_MIN;
            $('mu-plus').disabled = minUtil >= MU_MAX;
            const total = DB.reduce((a, t) => a + Object.keys(t).reduce((b, i) => b + t[i] * PROFIT[i], 0), 0);
            $('mu-pct').textContent = `（全部交易總效益 ${total} 的 ${Math.round(minUtil / total * 100)}%）`;
            drawCompare();
            showStep();
            reserveExplainHeight();
        }


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
            const itemName = (v, n, order) => (v.f >= n ? '沒有' : order[n - 1 - v.f]);
            switch (s.kind) {
                case 'cut': {
                    const items = quizShuffle(Object.keys(s.twu).sort(), rnd);
                    if (!items.length || items.length > 6) return null;
                    const out = items.map((x, k) => k).filter(k => s.twu[items[k]] < minUtil);
                    const mq = {
                        q: `門檻 ${minUtil}：哪些商品的 TWU 不到門檻、要整個刪掉？（都不用刪就直接按確定）`,
                        choices: items, answer: out, multi: true,
                        why: out.length ? `${out.map(k => `${items[k]} 的 TWU ${s.twu[items[k]]}`).join('、')} < ${minUtil}，含它的組合都不可能達標。`
                            : `每個商品的 TWU 都至少 ${minUtil}，這次不用刪。`,
                        ask: { type: 'cut' }
                    };
                    return items.length > 1 ? mq : quizSingle(mq, `門檻 ${minUtil}：${items[0]} 的 TWU 不到門檻、要整個刪掉嗎？`);
                }
                case 'build': {
                    if (!s.vec || s.tid % 2 || s.n < 2) return null;     // 隔一筆問一次
                    const n = s.n, right = bin(s.code, n), items = s.order.filter(it => has(DB[s.tid], it));
                    const flips = [];
                    for (let b = 0; b < n; b++) flips.push(bin(s.code ^ (1 << b), n));
                    const traps = [...new Set([right.split('').reverse().join(''), ...quizShuffle(flips, rnd)])]
                        .filter(x => x !== right && /1/.test(x)).slice(0, 3);
                    return {
                        q: `${tName(s.tid)} 留下 ${plain(items)}，它的 vector 編碼是多少？（左邊是最高位元，看表格最下面的「位元」）`,
                        ...quizOptions([{ text: right }, ...traps.map(text => ({ text }))], rnd),
                        why: `${items.map(it => `${it} 在位元 ${n - 1 - s.order.indexOf(it)}`).join('、')}，這幾位是 1、其他是 0：${right}。`,
                        ask: { type: 'code', tid: s.tid }
                    };
                }
                case 'area': {
                    if (s.area.length < 2) return null;
                    const utils = s.area.map(a => a.util), own = (s.area.find(a => a.code === s.low) || { util: 0 }).util;
                    const traps = [own, Math.max(...utils), s.vs - Math.min(...utils)].filter(x => x > 0 && x !== s.vs);
                    return {
                        q: `Mine(${bin(s.low, s.n)})：固定 ${plain(s.L)}${s.gaps.length ? `、不含 ${plain(s.gaps)}` : ''}。看 R，這一區所有 IndexSet 的 utilSum 加起來 vs 是多少？`,
                        ...quizNums(s.vs, 0, s.vs * 2 + 10, rnd, traps),
                        why: `從最高位到位元 ${s.j} 都跟 ${bin(s.low, s.n)} 一樣的有 ${s.area.length} 個：${utils.join(' + ')} = ${s.vs}，也就是效益 + 剩餘效益。`,
                        ask: { type: 'vs', L: s.L }
                    };
                }
                case 'proc': {
                    const vecs = s.is.vecs, X = s.items, n = s.n;
                    if (!vecs.length || vecs.length > 4 || X.length < 2) return null;
                    const can = vecs.map(v => X.filter(it => n - 1 - s.order.indexOf(it) < v.f).length);
                    const ans = can.reduce((a, b) => a + b, 0), noFix = X.length * vecs.length;
                    if (ans === noFix && rnd() < 0.6) return null;      // fixedPos 沒有擋到的，少問一點
                    return {
                        q: `${plain(X)} 收齊了，${vecs.map(v => `${tName(v.tid)} 的 fixedPos 是${itemName(v, n, s.order) === '沒有' ? '「沒有」' : ' ' + itemName(v, n, s.order)}`).join('、')}。` +
                            `只能拿掉位元比 fixedPos 低的商品，總共會傳出幾個子 vector？`,
                        ...quizNums(ans, 0, noFix + 4, rnd, [noFix, vecs.length, X.length]),
                        why: vecs.map((v, k) => `${tName(v.tid)} 能拿 ${can[k]} 個`).join('、') + `，合起來 ${ans} 個` +
                            (ans < noFix ? `；不看 fixedPos 會是 ${noFix} 個，多的那些子集合別的路已經傳過了。` : '。'),
                        ask: { type: 'subs', items: X }
                    };
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
        function setMinUtil(v) {
            v = Math.max(MU_MIN, Math.min(MU_MAX, v));
            if (v === minUtil) return;
            minUtil = v;
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
            if (e.target.tagName === 'INPUT') return;      // 在滑桿上按左右鍵是調門檻
            if (e.key === 'ArrowRight') { stopAuto(); step(1); }
            if (e.key === 'ArrowLeft') { stopAuto(); step(-1); }
        });
        $('mu-minus').addEventListener('click', () => setMinUtil(minUtil - MU_STEP));
        $('mu-plus').addEventListener('click', () => setMinUtil(minUtil + MU_STEP));
        $('mu-range').addEventListener('input', e => setMinUtil(Number(e.target.value)));
        $('ds').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b || b.dataset.ds === dsKey) return;
            useDataset(b.dataset.ds);
            [...$('ds').children].forEach(x => x.classList.toggle('active', x === b));
            rebuild();
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

        rebuild();
    </script>
</body>

</html>
