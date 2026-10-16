<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/closed-patterns.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/closed-patterns-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/closed-patterns-180.png">
    <title>封閉與最大頻繁樣式 CHARM</title>
    <meta name="description" content="頻繁樣式太多怎麼辦？比較全部頻繁、封閉、最大三種答案，再一步一步看 CHARM 怎麼用 tidset 的四條性質直接找出封閉樣式，Java 與 Python 程式碼逐行對照。">
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
            --gold: #facc15;
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
        .intro { color: #c6c6d6; max-width: 760px; margin-top: 0.9rem; font-size: 0.95rem; }
        .intro b { color: var(--text); }
        .intro a, .explain a, .notes a { color: var(--accent2); }

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

        /* ── 交易資料庫（矩陣） ── */
        .db { width: 100%; table-layout: fixed; border-collapse: separate; border-spacing: 0 3px; }
        /* 欄寬固定：商品欄平分，不會因為「茶葉蛋」「洋芋片」三個字就比較寬 */
        .db th.tid-h { width: 2.1rem; }
        .db th.del-h { width: 30px; }
        .db th { font-weight: 400; color: var(--muted); font-size: clamp(0.6rem, 3vw, 0.75rem); white-space: nowrap; padding: 0 1px 4px; text-align: center; line-height: 1.25; }
        .db th .emo { display: block; font-size: 1.25rem; }
        .db th.sel { color: var(--warn); }
        .db td { text-align: center; padding: 0; }
        .db td.tid { font: 0.78rem 'Space Mono', monospace; color: var(--muted); text-align: left; width: 2.6em; padding-left: 0.3rem; }
        .db tr.match td { background: rgba(245, 158, 11, 0.12); }
        .db tr.match td:first-child { border-radius: 8px 0 0 8px; color: var(--warn); }
        .db tr.match td:last-child { border-radius: 0 8px 8px 0; }
        .cell {
            width: 30px;
            height: 30px;
            margin: 0 auto;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 0.95rem;
        }
        .cell.has { background: #2a2a48; }
        .cell.has::after { content: ''; width: 11px; height: 11px; border-radius: 50%; background: var(--accent2); }
        .cell.hit { background: rgba(245, 158, 11, 0.35); }
        .cell.hit::after { background: var(--warn); }
        .editing .cell { cursor: pointer; border: 1px dashed #3a3a5a; }
        .editing .cell:hover { border-color: var(--accent2); }
        .db .del {
            background: none; border: none; color: var(--muted); cursor: pointer; font-size: 0.85rem;
            width: 26px; height: 26px; border-radius: 50%;
        }
        .db .del:hover { color: var(--bad); background: rgba(255, 255, 255, 0.05); }
        .db-foot { display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center; margin-top: 0.7rem; }

        .minsup { display: flex; align-items: center; gap: 0.45rem; flex-wrap: wrap; font-size: 0.9rem; }
        .minsup .val { font: 700 1rem 'Space Mono', monospace; min-width: 1.4em; text-align: center; }
        .minsup .pct { color: var(--muted); font-size: 0.82rem; }
        .stepper { width: 30px; height: 30px; padding: 0 !important; }

        /* ── 這一步 ── */
        .player { display: flex; flex-wrap: wrap; gap: 0.4rem; align-items: center; }
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

        .stage { margin-top: 0.8rem; display: grid; gap: 0.7rem; }
        .stage > * { min-width: 0; }
        .crumb { font-size: 0.8rem; color: var(--muted); }
        .crumb b { color: var(--accent2); font-weight: 600; }
        .sub-h { font-size: 0.8rem; color: var(--muted); margin-bottom: 0.3rem; }

        /* tidset：一排小格子，第幾格亮代表出現在第幾筆交易 */
        .tcs { display: grid; grid-template-columns: repeat(var(--n), minmax(0, 22px)); gap: 2px; min-width: 0; }
        .tcs i {
            font: 0.6rem/1 'Space Mono', monospace; font-style: normal;
            height: 20px; border-radius: 4px; display: flex; align-items: center; justify-content: center;
            background: #12121f; color: #3a3a55; border: 1px solid #1d1d30;
        }
        .tcs i.on { background: #2a2a48; color: var(--text); border-color: #3a3a5a; }
        .tcs.x i.on { background: rgba(124, 58, 237, 0.35); border-color: var(--accent); }
        .tcs.xj i.on { background: rgba(6, 182, 212, 0.25); border-color: var(--accent2); }
        .tcs.y i.on { background: rgba(245, 158, 11, 0.3); border-color: var(--warn); color: #fde68a; }
        .tcs.y.low i.on { background: rgba(248, 113, 113, 0.2); border-color: var(--bad); color: #fecaca; }

        .vt { display: grid; gap: 4px; }
        .vt-row { display: grid; grid-template-columns: 5.2em minmax(0, 1fr) 1.8em; gap: 0.5rem; align-items: center; }
        .vt-row .lab { font-size: 0.82rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .vt-row .sup { font: 700 0.8rem 'Space Mono', monospace; text-align: right; }
        .vt-row.out { opacity: 0.45; }
        .vt-row.out .lab { text-decoration: line-through; }
        .vt-row .ord { font: 0.7rem 'Space Mono', monospace; color: var(--accent2); margin-right: 0.2rem; }

        .crows { display: grid; gap: 4px; }
        .crow {
            display: grid; grid-template-columns: 1.9em minmax(0, 1fr) auto; gap: 0.45rem; align-items: center;
            background: var(--panel-2); border: 1px solid var(--border); border-radius: 8px; padding: 0.25rem 0.5rem;
            font-size: 0.84rem;
        }
        .crow .role { font: 700 0.68rem 'Space Mono', monospace; color: var(--muted); }
        .crow .set { min-width: 0; overflow-wrap: anywhere; }
        .crow .grow { color: var(--warn); font-size: 0.78rem; }
        .crow .tids { font: 0.72rem 'Space Mono', monospace; color: var(--muted); white-space: nowrap; }
        .crow.x { border-color: var(--accent); background: rgba(124, 58, 237, 0.12); }
        .crow.x .role { color: #c4b5fd; }
        .crow.xj { border-color: var(--accent2); background: rgba(6, 182, 212, 0.08); }
        .crow.xj .role { color: var(--accent2); }
        .crow.done { opacity: 0.55; }
        .crow.gone { opacity: 0.5; border-style: dashed; }
        .crow.gone .set { text-decoration: line-through; }
        .crow.gone .role { color: var(--bad); }

        .cmp { background: #0c0c17; border: 1px solid var(--border); border-radius: 10px; padding: 0.55rem 0.6rem; display: grid; gap: 4px; }
        .cmp-row { display: grid; grid-template-columns: 2.6em minmax(0, 1fr) 1.8em; gap: 0.5rem; align-items: center; }
        .cmp-row .lab { font: 700 0.72rem 'Space Mono', monospace; color: var(--muted); }
        .cmp-row .sup { font: 700 0.8rem 'Space Mono', monospace; text-align: right; }
        .rel { font-size: 0.84rem; margin-top: 0.25rem; display: flex; flex-wrap: wrap; gap: 0.3rem 0.6rem; align-items: center; }
        .badge { font: 700 0.72rem 'Space Mono', monospace; border-radius: 6px; padding: 0.1rem 0.45rem; background: #2a2a48; color: var(--text); white-space: nowrap; }
        .badge.p1, .badge.p2 { background: rgba(124, 58, 237, 0.3); color: #ddd6fe; }
        .badge.p3, .badge.p4 { background: rgba(6, 182, 212, 0.22); color: #a5f3fc; }
        .badge.infreq, .badge.sub { background: rgba(248, 113, 113, 0.2); color: #fecaca; }
        .badge.ok { background: rgba(34, 197, 94, 0.22); color: #bbf7d0; }

        .chips { display: flex; flex-wrap: wrap; gap: 0.35rem; }
        .chip {
            display: inline-flex; align-items: center; gap: 0.35rem;
            border: 1px solid var(--border); background: var(--panel-2); border-radius: 8px;
            padding: 0.2rem 0.55rem; font-size: 0.83rem; color: var(--text); font-family: inherit; text-align: left;
        }
        button.chip { cursor: pointer; }
        button.chip:hover { border-color: var(--accent2); }
        .chip .n { font: 700 0.76rem 'Space Mono', monospace; padding: 0 0.35rem; border-radius: 5px; background: #2a2a48; }
        .chip .star { color: var(--gold); font-size: 0.8rem; }
        .chip.c { border-color: rgba(167, 139, 250, 0.75); }
        .chip.c .n { background: rgba(124, 58, 237, 0.35); color: #ddd6fe; }
        .chip.m { border-color: var(--gold); box-shadow: 0 0 0 1px rgba(250, 204, 21, 0.35) inset; }
        .chip.dim { opacity: 0.38; }
        .chip.cur { border-color: var(--warn); box-shadow: 0 0 0 1px var(--warn) inset; }
        .chip.sel { outline: 2px solid var(--warn); outline-offset: 1px; }
        .chip .why { color: var(--muted); font-size: 0.74rem; }

        /* ── 三種答案比一比 ── */
        .nest { border: 1px solid var(--border); border-radius: 12px; padding: 0.45rem 0.6rem 0.6rem; transition: border-color 0.2s, background 0.2s; }
        .nest > .nl { font-size: 0.8rem; color: var(--muted); display: flex; justify-content: space-between; gap: 0.5rem; margin-bottom: 0.35rem; }
        .nest > .nl b { font: 700 1.05rem 'Space Mono', monospace; color: var(--text); }
        .nest .nest { margin-top: 0.1rem; }
        .nest.act { border-color: var(--accent2); background: rgba(6, 182, 212, 0.06); }
        .nest.n-c.act { border-color: #a78bfa; background: rgba(124, 58, 237, 0.1); }
        .nest.n-m.act { border-color: var(--gold); background: rgba(250, 204, 21, 0.07); }
        .levels { display: grid; gap: 0.5rem; margin-top: 0.9rem; }
        .level { display: grid; grid-template-columns: 2.6em minmax(0, 1fr); gap: 0.5rem; align-items: start; }
        .level .tag { font: 700 0.78rem 'Space Mono', monospace; color: var(--accent2); padding-top: 0.25rem; white-space: nowrap; }
        .level .empty { color: var(--muted); font-size: 0.85rem; padding-top: 0.2rem; }
        .legend { display: flex; flex-wrap: wrap; gap: 0.3rem 0.9rem; font-size: 0.76rem; color: var(--muted); margin-top: 0.7rem; }
        .legend i { display: inline-block; width: 12px; height: 12px; border-radius: 3px; border: 1.5px solid; vertical-align: -2px; margin-right: 0.3rem; }
        .hint { color: var(--muted); font-size: 0.8rem; margin-top: 0.6rem; min-height: 1.3em; }
        .hint b { color: var(--text); font-weight: 600; }

        /* ── 四條性質 ── */
        .props { display: grid; gap: 0.35rem; }
        .prop {
            display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 0.5rem; align-items: center;
            border: 1px solid var(--border); border-radius: 9px; padding: 0.4rem 0.6rem; font-size: 0.84rem; color: #c6c6d6;
        }
        .prop b { color: var(--text); font-weight: 600; }
        .prop .cnt { font: 700 0.8rem 'Space Mono', monospace; color: var(--muted); }
        .prop.now { border-color: var(--warn); background: rgba(245, 158, 11, 0.08); }
        .prop.now .cnt { color: var(--warn); }
        .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.5rem; margin-top: 0.9rem; }
        .stat { background: var(--panel-2); border-radius: 10px; padding: 0.55rem 0.6rem; min-width: 0; }
        .stat .v { font: 700 1.25rem 'Space Mono', monospace; }
        .stat .k { color: var(--muted); font-size: 0.75rem; line-height: 1.35; }

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
            max-height: 470px;
            font: 0.8rem/1.7 'Space Mono', ui-monospace, monospace;
            position: relative;
        }
        @media (max-width: 600px) { pre.code { font-size: 0.72rem; max-height: 380px; } }
        .code .ln { display: block; padding-right: 0.9rem; white-space: pre; width: max-content; min-width: 100%; }
        .code .ln::before {
            content: attr(data-n);
            display: inline-block;
            width: 2.4em;
            text-align: right;
            margin-right: 0.9em;
            color: #4a4a66;
        }
        .code .ln.hl { background: var(--line-hl); box-shadow: inset 3px 0 0 var(--accent); }
        .kw { color: #c792ea; }
        .fn { color: #82aaff; }
        .num { color: #f78c6c; }
        .cm { color: #637777; }
        .str { color: #c3e88d; }
        .ty { color: #ffcb6b; }
        .code-note { color: var(--muted); font-size: 0.8rem; margin-bottom: 0.5rem; min-height: 1.3em; }
        .downloads { display: flex; flex-wrap: wrap; gap: 0.5rem 1rem; margin-top: 0.7rem; font-size: 0.85rem; color: var(--muted); align-items: center; }
        .downloads a { color: var(--accent2); }
        .downloads code { font: 0.78rem 'Space Mono', monospace; background: var(--panel-2); padding: 0.1rem 0.4rem; border-radius: 4px; color: var(--text); }

        .notes { margin-top: 1rem; display: grid; gap: 1rem; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr; } }
        .notes p, .notes li { color: #c6c6d6; font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; }
        .notes b { color: var(--text); }

        /* ── 練習模式（猜下一步）：題目疊在說明框的位置，不推動任何區塊 ── */
        .quiz-bar { display: flex; align-items: center; gap: 0.7rem; margin-top: 0.75rem; }
        .quiz-toggle { display: inline-flex; align-items: center; gap: 0.5rem; }
        .quiz-toggle .sw { position: relative; flex: none; width: 30px; height: 17px; border-radius: 9px; background: #2a2a48; transition: background 0.15s; }
        .quiz-toggle .sw::after { content: ''; position: absolute; top: 2px; left: 2px; width: 13px; height: 13px; border-radius: 50%; background: var(--muted); transition: transform 0.15s, background 0.15s; }
        .quiz-toggle.quiz-on { border-color: var(--accent); }
        .quiz-toggle.quiz-on .sw { background: var(--accent); }
        .quiz-toggle.quiz-on .sw::after { transform: translateX(13px); background: #fff; }
        .quiz-toggle { flex: none; }
        .quiz-score { font: 0.8rem 'Space Mono', monospace; color: var(--accent2); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; min-width: 0; }
        .quiz-host { position: relative; display: grid; margin-top: 0.8rem; }
        .quiz-host > .explain { margin-top: 0; min-width: 0; }
        .quiz {
            position: absolute; inset: 0; z-index: 2; overflow: auto;
            display: flex; flex-direction: column; gap: 0.45rem;
            background: var(--panel-2); border: 1px solid rgba(124, 58, 237, 0.5); border-left: 3px solid var(--accent);
            border-radius: 8px; padding: 0.5rem 0.75rem; font-size: 0.88rem; line-height: 1.5;
        }
        .quiz[hidden] { display: none; }
        .quiz.nudge { animation: quiz-nudge 0.3s; }
        @keyframes quiz-nudge { 25% { transform: translateX(-4px); } 75% { transform: translateX(4px); } }
        .quiz-head { display: flex; align-items: center; justify-content: space-between; gap: 0.3rem 0.5rem; flex-wrap: wrap; }
        .quiz-tag { font: 700 0.74rem 'Space Mono', monospace; color: #c4b5fd; }
        /* 題目和解釋疊在同一格：答完換成解釋，高度取兩者較高的，不會跳 */
        .quiz-body { display: grid; }
        .quiz-body > * { grid-area: 1 / 1; min-width: 0; }
        .quiz-choices { display: flex; flex-wrap: wrap; gap: 0.4rem; }
        .quiz-choices.half { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); }
        .quiz-choices.wide { display: grid; grid-template-columns: minmax(0, 1fr); gap: 0.3rem; }
        .quiz-choices.wide .quiz-choice { min-height: 32px; padding: 0.2rem 0.6rem; font-size: 0.8rem; }
        .quiz-choice {
            min-height: 36px; min-width: 44px; padding: 0.25rem 0.7rem; border-radius: 8px;
            border: 1px solid var(--border); background: #1c1c33; color: var(--text);
            font: inherit; font-size: 0.86rem; line-height: 1.35; text-align: left; cursor: pointer; overflow-wrap: anywhere;
        }
        .quiz-choice:hover:not(:disabled) { border-color: var(--accent2); }
        .quiz-choice:disabled { cursor: default; }
        .quiz-choice.sel { border-color: var(--accent2); background: rgba(6, 182, 212, 0.14); box-shadow: 0 0 0 1px var(--accent2) inset; }
        .quiz-choice.right { border-color: var(--good); background: rgba(34, 197, 94, 0.18); color: #bbf7d0; }
        .quiz-choice.right.missed { border-style: dashed; background: rgba(34, 197, 94, 0.07); }   /* 複選題漏選的 */
        .quiz-choice.wrong { border-color: var(--bad); background: rgba(248, 113, 113, 0.14); color: #fecaca; text-decoration: line-through; }
        .quiz-actions { display: flex; gap: 0.35rem; margin-left: auto; }
        .quiz-actions .btn { padding: 0.2rem 0.65rem; font-size: 0.82rem; }
        .quiz.done .quiz-ok { visibility: hidden; }
        .quiz-why { visibility: hidden; font-size: 0.85rem; color: #c6c6d6; }
        .quiz.done .quiz-why { visibility: visible; }
        .quiz.done .quiz-text { visibility: hidden; }
        .quiz-verdict { color: var(--good); margin-right: 0.3rem; }
        .quiz.miss .quiz-verdict { color: var(--bad); }
    </style>
</head>

<body>
    <div class="wrap">
        <a class="back" href="../index.html#research">← RETURN TO PORTFOLIO</a>
        <div class="kicker">RESEARCH DEMO · CLOSED &amp; MAXIMAL PATTERNS</div>
        <h1>封閉與最大頻繁樣式<small>頻繁樣式太多了，哪些才是真的需要記的？用 CHARM 直接找出來</small></h1>
        <p class="intro">
            <a href="apriori.html">Apriori</a> 會把所有頻繁樣式都列出來，但一個 10 樣商品的頻繁組合，光是它的子集合就有一千多個，而且全都頻繁，答案多到看不完。
            其實很多樣式是重複的資訊：如果買了 {咖啡, 飯糰} 的人<b>每一個</b>也都買了麵包，{咖啡, 飯糰} 和 {咖啡, 飯糰, 麵包} 的次數就一模一樣，只記大的就好。
            <b>封閉樣式</b>只留「沒有更大的組合跟它一樣次數」的，所有次數都還推得回來；<b>最大樣式</b>更狠，只留頻繁的邊界。
            這頁用 <b>CHARM</b> 演算法直接找出封閉樣式，它建在 <a href="eclat.html">Eclat</a> 的垂直格式上：記每個樣式出現在哪幾筆交易，比較兩個樣式時只要做交集。
        </p>

        <div class="layout">
            <div>
                <div class="card" id="db-card">
                    <div class="card-head">
                        <h2>交易資料庫</h2>
                        <div class="minsup">
                            <span>最小支持度</span>
                            <button class="btn stepper" id="sup-minus" aria-label="減少">−</button>
                            <span class="val" id="sup-val">2</span>
                            <button class="btn stepper" id="sup-plus" aria-label="增加">+</button>
                            <span class="pct" id="sup-pct"></span>
                        </div>
                    </div>
                    <table class="db" id="db"></table>
                    <div class="db-foot">
                        <button class="btn" id="btn-edit">✎ 編輯資料</button>
                        <button class="btn hidden-when-view" id="btn-add-row">＋ 新增一筆交易</button>
                        <button class="btn hidden-when-view" id="btn-reset-db">恢復範例資料</button>
                    </div>
                </div>

                <div class="card">
                    <div class="card-head">
                        <h2>一步一步看</h2>
                    </div>
                    <div class="player">
                        <button class="btn" id="btn-first" title="回到開頭">⏮</button>
                        <button class="btn" id="btn-prev">◀ 上一步</button>
                        <button class="btn primary" id="btn-next">下一步 ▶</button>
                        <button class="btn" id="btn-play">▶ 自動播放</button>
                    </div>
                    <div class="quiz-bar">
                        <button class="btn quiz-toggle" id="quiz-toggle" aria-pressed="false" title="按下一步之前先猜猜看">🎯 練習模式<span class="sw" aria-hidden="true"></span></button>
                        <span class="quiz-score" id="quiz-score" style="visibility:hidden">答對 0/0</span>
                    </div>
                    <div class="quiz-host" id="quiz-host">
                        <div class="explain" id="explain"></div>
                        <div class="quiz" id="quiz" role="group" aria-label="練習題" hidden></div>
                    </div>
                    <div class="stage" id="stage"></div>
                </div>

                <div class="card">
                    <h2>三種答案比一比</h2>
                    <div class="nest n-f" id="nest-f">
                        <div class="nl"><span>頻繁樣式：次數 ≥ 門檻</span><b id="cnt-f">0</b></div>
                        <div class="nest n-c" id="nest-c">
                            <div class="nl"><span>封閉：沒有更大的組合跟它一樣次數</span><b id="cnt-c">0</b></div>
                            <div class="nest n-m" id="nest-m">
                                <div class="nl"><span>最大：沒有更大的組合也頻繁</span><b id="cnt-m">0</b></div>
                            </div>
                        </div>
                    </div>
                    <div class="levels" id="levels"></div>
                    <div class="legend" id="legend"></div>
                    <div class="hint" id="hint"></div>
                </div>
            </div>

            <div>
                <div class="card">
                    <div class="card-head">
                        <h2>程式碼</h2>
                        <div class="lang" id="lang">
                            <button data-lang="java" class="active">Java</button>
                            <button data-lang="py">Python</button>
                        </div>
                    </div>
                    <div class="code-note" id="code-note">前三步是在看答案長什麼樣子，還沒開始跑程式。</div>
                    <pre class="code" id="code"></pre>
                    <div class="downloads" id="downloads"></div>
                </div>

                <div class="card">
                    <h2>CHARM 比較兩個樣式時的四條性質</h2>
                    <div class="props" id="props"></div>
                    <div class="stats">
                        <div class="stat"><div class="v" id="st-inter">0</div><div class="k">算過的 tidset 交集</div></div>
                        <div class="stat"><div class="v" id="st-gone">0</div><div class="k">直接刪掉、不用再往下找的樣式</div></div>
                        <div class="stat"><div class="v" id="st-sub">0</div><div class="k">子集合檢查擋下的</div></div>
                    </div>
                </div>
            </div>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼這四條性質是對的？</h2>
                <p>關鍵是：<b>X ∪ Y 出現在哪幾筆，就是 t(X) 和 t(Y) 的交集</b>。把兩個 tidset 一比，就知道它們合起來之後次數會不會變：</p>
                <ul style="margin-top:0.4rem">
                    <li><b>t(X) = t(Xj)：</b>兩個總是一起出現，X ∪ Xj 跟它們次數都一樣，所以 X 和 Xj 單獨都不可能封閉，直接合併。</li>
                    <li><b>t(X) ⊂ t(Xj)：</b>有 X 的交易一定有 Xj，X 加上 Xj 次數不變，所以 X 一定要帶著 Xj；但 Xj 還有自己的出現，要留著。</li>
                    <li><b>t(X) ⊃ t(Xj)：</b>反過來，Xj 一定要帶著 X，Xj 自己不封閉，刪掉；X ∪ Xj 次數變少了，是新的候選。</li>
                    <li><b>互不包含：</b>兩個都還可能封閉，X ∪ Xj 也是新候選。</li>
                </ul>
                <p style="margin-top:0.5rem">這四條只會在同一個類別裡合併，不同分支還是可能找到同一個封閉樣式的子集合，所以最後要做<b>子集合檢查</b>：
                    已經有一個包含它、次數又一樣的封閉樣式，它就不是封閉的。最大樣式則一定是封閉的（如果有更大的組合一樣次數，那個更大的也頻繁），所以從封閉樣式裡挑就好。</p>
            </div>
            <div class="card">
                <h2>什麼時候用哪一種，以及之後的研究</h2>
                <ul>
                    <li><b>要次數、要算關聯規則：</b>用封閉樣式。它是「無損壓縮」，任何頻繁樣式的次數 = 包含它的封閉樣式中最大的那個次數。</li>
                    <li><b>只想知道哪些組合常一起出現：</b>用最大樣式，數量最少，但次數推不回來。</li>
                    <li><b>差別在資料越密越明顯。</b>這份 8 筆的資料很稀疏，三種只差幾個；把門檻調到 1 試試，或在密集的資料（例如每筆都買了很多樣）上，封閉樣式可能比全部頻繁樣式少好幾個數量級。</li>
                    <li><b>跟其他方法的關係：</b>CHARM 建在 Eclat 的垂直格式上；<a href="fp-growth.html">FP-Growth</a> 也有封閉版（CLOSET）；
                        在<a href="sliding-window.html">資料串流</a>或<a href="incremental.html">增量資料庫</a>裡，怎麼在資料變動時只更新受影響的封閉 / 最大樣式，是很常見的研究題目。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           CHARM 一步一步看
           網頁裡另外用 JavaScript 照著同樣的流程跑一次，把每個步驟記下來，
           上一步／下一步只是在這些紀錄之間移動；右邊的 Java / Python 是可以直接下載執行的版本。
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
        const DEFAULT_SUP = 2;

        const $ = id => document.getElementById(id);
        let db = SAMPLE.map(t => new Set(t));
        let minSup = DEFAULT_SUP;
        let editing = false;
        let lang = 'java';
        let trace = [];
        let cursor = 0;
        let answer = null;       // 暴力法算出的三種答案（「三種答案比一比」用）
        let selected = null;     // 要在表格上標出的組合
        let timer = null;

        /* 跟 Java 的 compareTo、Python 的字串比較同一個順序（依字碼） */
        const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
        const key = set => set.join('|');
        const fmt = set => '{' + set.join(', ') + '}';
        const union = (a, b) => [...new Set([...a, ...b])].sort(cmp);
        const inter = (a, b) => a.filter(x => b.includes(x));
        const sameSet = (a, b) => a.length === b.length && a.every(x => b.includes(x));
        const within = (a, b) => a.every(x => b.includes(x));          // a ⊆ b
        const support = set => db.filter(t => set.every(x => t.has(x))).length;
        const tidsTxt = tids => tids.length ? 'T' + tids.join('、T') : '（沒有）';

        /* ---------- 暴力法：列出所有組合，挑出頻繁 / 封閉 / 最大 ---------- */
        function bruteForce() {
            const items = [...ITEMS].sort(cmp).filter(i => db.some(t => t.has(i)));
            const freq = [];
            for (let mask = 1; mask < (1 << items.length); mask++) {
                const set = items.filter((_, b) => mask & (1 << b));
                const sup = support(set);
                if (sup >= minSup) freq.push({ set, sup });
            }
            freq.forEach(f => {
                const bigger = freq.filter(g => g.set.length > f.set.length && within(f.set, g.set));
                const same = bigger.filter(g => g.sup === f.sup);
                f.closed = same.length === 0;
                f.max = bigger.length === 0;
                // 不封閉的話，它的「閉包」= 跟它一樣次數的超集合裡最大的那個
                f.closure = same.reduce((x, y) => (!x || y.set.length > x.set.length ? y : x), null);
                f.maxSuper = bigger.find(g => g.max) || null;
            });
            freq.sort((a, b) => a.set.length - b.set.length || cmp(key(a.set), key(b.set)));
            return {
                freq,
                closed: freq.filter(f => f.closed),
                max: freq.filter(f => f.max)
            };
        }

        /* ---------- 照著程式跑一次 CHARM，記下每一步 ---------- */
        function buildTrace() {
            const steps = [];
            const stats = { inter: 0, gone: 0, sub: 0, use: { infreq: 0, p1: 0, p2: 0, p3: 0, p4: 0, sub: 0 } };
            const closed = [];        // {set, sup}，照找到的順序
            const stack = [];         // 每一層類別：{prefix, rows, i, j, X, tX, newClass}
            const snap = () => stack.map(f => ({
                prefix: f.prefix, i: f.i, j: f.j, X: f.X, tX: f.tX,
                rows: f.rows.map(r => ({ ...r })),
                newClass: f.newClass.map(c => ({ ...c }))
            }));
            const push = (kind, extra = {}) => steps.push({
                kind, ...extra,
                stack: snap(),
                closed: closed.map(c => ({ ...c })),
                stats: { ...stats, use: { ...stats.use } }
            });

            push('all');
            push('closed');
            push('maximal');
            push('start');

            // 垂直格式：每個商品出現在哪幾筆
            const tidset = {};
            db.forEach((t, r) => [...t].forEach(i => { (tidset[i] = tidset[i] || []).push(r + 1); }));
            const vertical = Object.keys(tidset).sort(cmp).map(i => ({ set: [i], tids: tidset[i] }));
            push('vertical', { vertical });

            // 只留頻繁的商品，照支持度由小到大排（一樣就照名稱）
            const P = vertical.filter(v => v.tids.length >= minSup)
                .sort((a, b) => a.tids.length - b.tids.length || cmp(a.set[0], b.set[0]));
            const dropped = vertical.filter(v => v.tids.length < minSup);
            push('order', { order: P, dropped });

            function extend(P, prefix) {
                const f = { prefix, rows: P.map(p => ({ set: p.set, tids: p.tids, gone: null, done: false })), i: -1, j: -1, X: null, tX: null, newClass: [] };
                stack.push(f);
                for (let i = 0; i < f.rows.length; i++) {
                    const r = f.rows[i];
                    if (r.gone) continue;
                    f.i = i; f.j = -1; f.X = r.set; f.tX = r.tids; f.newClass = [];
                    const rest = f.rows.slice(i + 1).filter(q => !q.gone).length;
                    push('pick', { rest });
                    for (let j = i + 1; j < f.rows.length; j++) {
                        const q = f.rows[j];
                        if (q.gone) continue;
                        f.j = j;
                        const Y = inter(f.tX, q.tids);
                        stats.inter++;
                        const before = f.X;
                        let kind;
                        if (Y.length < minSup) kind = 'infreq';
                        else if (sameSet(f.tX, q.tids)) { kind = 'p1'; f.X = union(f.X, q.set); q.gone = 'p1'; stats.gone++; }
                        else if (within(f.tX, q.tids)) { kind = 'p2'; f.X = union(f.X, q.set); }
                        else if (within(q.tids, f.tX)) { kind = 'p3'; f.newClass.push({ set: q.set, tids: Y }); q.gone = 'p3'; stats.gone++; }
                        else { kind = 'p4'; f.newClass.push({ set: q.set, tids: Y }); }
                        stats.use[kind]++;
                        push(kind, { Xj: q.set, tj: q.tids, Y, before });
                    }
                    f.j = -1;
                    if (f.newClass.length) {
                        const next = f.newClass.map(c => ({ set: union(f.X, c.set), tids: c.tids }));
                        push('recurse', { next });
                        extend(next, f.X);
                    }
                    // 子集合檢查：已經有包含 X、次數一樣的封閉樣式 → X 不是封閉的
                    const by = closed.find(c => c.sup === f.tX.length && within(f.X, c.set)) || null;
                    if (by) { stats.sub++; stats.use.sub++; } else closed.push({ set: f.X, sup: f.tX.length });
                    r.done = true;
                    push('check', { by, X: f.X, sup: f.tX.length });
                }
                stack.pop();
            }
            extend(P, []);

            // 最大樣式：封閉樣式裡，沒有其他封閉樣式比它大
            const max = closed.filter(c => !closed.some(d => d.set.length > c.set.length && within(c.set, d.set)));
            push('maxfind', { max });
            push('end', { max });
            return steps;
        }

        /* 給測試用：對任意資料跑一次，回傳 CHARM 的封閉 / 最大樣式，以及暴力法的答案 */
        function simulate(rows, ms) {
            db = rows.map(t => new Set(t));
            minSup = ms;
            const tr = buildTrace();
            const last = tr[tr.length - 1];
            const bf = bruteForce();
            const pairs = list => list.map(c => [c.set, c.sup]);
            return { closed: pairs(last.closed), max: pairs(last.max), brute: { freq: pairs(bf.freq), closed: pairs(bf.closed), max: pairs(bf.max) }, steps: tr.length };
        }

        /* ---------- 說明文字 ---------- */
        const frame = s => s.stack[s.stack.length - 1];
        function where(s) {
            const f = frame(s);
            return f && f.prefix.length ? `（在 ${fmt(f.prefix)} 的類別裡）` : '';
        }
        /* Xj 裡 X 還沒有的商品（同一個類別的樣式共用前綴，只說新加的） */
        const newPart = s => s.Xj.filter(x => !s.before.includes(x)).join('、');
        function describe(s) {
            const A = answer;
            const F = A.freq.length, C = A.closed.length, M = A.max.length;
            const f = frame(s);
            switch (s.kind) {
                case 'all': {
                    if (!F) return `門檻 ${minSup} 時，沒有任何商品組合是頻繁的。把門檻調低一點再看。`;
                    const ex = A.freq.find(x => !x.closed);
                    return `先看答案長什麼樣子。門檻 ${minSup} 時，<b>全部的頻繁樣式</b>有 <b>${F}</b> 個（下面「三種答案比一比」），Apriori 會一個一個列出來。` +
                        (ex ? `但很多是重複的資訊：${fmt(ex.set)} 和 ${fmt(ex.closure.set)} 都是 ${ex.sup} 次，因為買了 ${fmt(ex.set)} 的那 ${ex.sup} 筆，剛好也都買了 ${ex.closure.set.filter(x => !ex.set.includes(x)).join('、')}。`
                            : `這個門檻下剛好沒有重複的，調低門檻差別會比較明顯。`);
                }
                case 'closed':
                    return `<b>封閉樣式</b>：沒有任何更大的組合跟它一樣次數。${F} 個裡留下 <b>${C}</b> 個（紫框）。` +
                        (F > C ? `拿掉的 ${F - C} 個不會遺失資訊：一個樣式的次數 = 包含它的封閉樣式裡，次數最大的那個。點灰色的看看。` : `這個門檻下每個頻繁樣式都是封閉的。`);
                case 'maximal': {
                    const ex = A.freq.find(x => !x.max && x.closed && x.maxSuper && x.maxSuper.sup !== x.sup);
                    return `<b>最大樣式</b>：再加任何一樣商品就不頻繁了，只剩 <b>${M}</b> 個（★），是頻繁和不頻繁的邊界。每個頻繁樣式都是某個最大樣式的子集合，所以「哪些頻繁」推得回來，但<b>次數推不回來</b>` +
                        (ex ? `（例如 ${fmt(ex.set)} 是 ${ex.sup} 次，從 ${fmt(ex.maxSuper.set)} 只看得出它至少 ${ex.maxSuper.sup} 次）` : '') + `。所以：最大 ⊆ 封閉 ⊆ 頻繁。`;
                }
                case 'start':
                    return `CHARM 不先列出全部 ${F} 個再挑，而是一邊找、一邊用四條性質跳過不封閉的。它跟 <a href="eclat.html">Eclat</a> 一樣用<b>垂直格式</b>：記每個樣式出現在哪幾筆（tidset），兩個樣式合起來的 tidset 就是兩者的交集，不用再掃資料庫。`;
                case 'vertical': {
                    const v = s.vertical[0];
                    return `轉成垂直格式：每個商品記下它出現在哪幾筆交易，tidset 有幾格，支持度就是多少。` +
                        (v ? `例如 ${v.set[0]} 出現在 ${tidsTxt(v.tids)}，支持度 ${v.tids.length}。` : '');
                }
                case 'order':
                    if (!s.order.length) return `每個商品都不到 ${minSup} 次，沒有頻繁的商品，CHARM 直接結束。`;
                    return (s.dropped.length ? `拿掉不到 ${minSup} 次的 ${s.dropped.map(d => d.set[0]).join('、')}，` : '') +
                        `剩下 ${s.order.length} 個照支持度<b>由小到大</b>排，這就是第一層的「類別」（前綴是空的）。小的排前面，後面的 tidset 比較大，比較容易出現包含關係，可以早點合併或刪掉。`;
                case 'pick':
                    return `${where(s)}輪到 X = <b>${fmt(f.X)}</b>，出現在 ${tidsTxt(f.tX)}。` +
                        (s.rest ? `接下來跟排在它後面、還沒刪掉的 ${s.rest} 個一一比 tidset。` : `它後面沒有可以比的了，直接做子集合檢查。`);
                case 'infreq':
                    return `X ∪ ${fmt(s.Xj)} 只出現在 ${s.Y.length} 筆，不到 ${minSup}，不頻繁，跳過。`;
                case 'p1':
                    return `<b>性質 1</b>：t(X) 和 t(${fmt(s.Xj)}) 一模一樣，代表它們總是一起出現。把 ${newPart(s)} 併進 X（X = ${fmt(f.X)}），${fmt(s.Xj)} 自己不可能封閉，直接從類別刪掉。`;
                case 'p2':
                    return `<b>性質 2</b>：t(X) ⊂ t(${fmt(s.Xj)})，每次出現 X 都有 ${newPart(s)}，加上去次數不變，所以吸收進 X（X = ${fmt(f.X)}）。但 ${fmt(s.Xj)} 還有別的出現，保留著，輪到它時還要處理。`;
                case 'p3':
                    return `<b>性質 3</b>：t(X) ⊃ t(${fmt(s.Xj)})，每次出現 ${s.Xj.join('、')} 都有 X，所以 ${fmt(s.Xj)} 自己不封閉，刪掉；X ∪ ${fmt(s.Xj)}（${s.Y.length} 次）放進新類別，等一下往下找。`;
                case 'p4':
                    return `<b>性質 4</b>：兩個 tidset 互不包含，交集有 ${s.Y.length} 筆。X ∪ ${fmt(s.Xj)} 放進新類別，${fmt(s.Xj)} 保留。`;
                case 'recurse':
                    return `X = ${fmt(f.X)} 跟後面的都比完了，新類別有 ${s.next.length} 個候選。每個都補上<b>最後的 X</b>，往下一層用同樣的方法處理：${s.next.map(c => fmt(c.set)).join('、')}。`;
                case 'check':
                    return `${where(s)}回到 X = ${fmt(s.X)}（${s.sup} 次）做<b>子集合檢查</b>：` + (s.by
                        ? `已經找到的 ${fmt(s.by.set)} 包含它，而且一樣是 ${s.sup} 次，所以 X 不是封閉的，<b>不加入</b>。`
                        : `已經找到的封閉樣式裡，沒有包含它又一樣是 ${s.sup} 次的，<b>加入封閉樣式</b>（第 ${s.closed.length} 個）。`);
                case 'maxfind':
                    return `封閉樣式找完了，共 ${s.closed.length} 個。最大樣式一定是封閉的，所以只要在封閉樣式裡挑出「沒有其他封閉樣式比它大」的：共 <b>${s.max.length}</b> 個（★）。`;
                case 'end': {
                    const u = s.stats.use;
                    return `完成！頻繁 ${F} 個 → 封閉 <b>${s.closed.length}</b> 個 → 最大 <b>${s.max.length}</b> 個。CHARM 只讀了一次資料庫，之後全靠 ${s.stats.inter} 次 tidset 交集；` +
                        `性質 1、2 合併了 ${u.p1 + u.p2} 次，性質 1、3 直接刪掉 ${s.stats.gone} 個樣式，子集合檢查擋下 ${s.stats.sub} 個。`;
                }
            }
            return '';
        }

        const CODE_TAG = { all: null, closed: null, maximal: null, start: 'start', vertical: 'vertical', order: 'order', pick: 'pick', infreq: 'infreq', p1: 'p1', p2: 'p2', p3: 'p3', p4: 'p4', recurse: 'recurse', check: 'check', maxfind: 'maxfind', end: 'end' };
        const PAIR = ['infreq', 'p1', 'p2', 'p3', 'p4'];
        const PROPS = [
            ['infreq', '不頻繁', '交集不到門檻 → 跳過'],
            ['p1', '性質 1', 't(X) = t(Xj) → Xj 併進 X，刪掉 Xj'],
            ['p2', '性質 2', 't(X) ⊂ t(Xj) → Xj 吸收進 X，保留 Xj'],
            ['p3', '性質 3', 't(X) ⊃ t(Xj) → X∪Xj 進新類別，刪掉 Xj'],
            ['p4', '性質 4', '互不包含 → X∪Xj 進新類別，保留 Xj'],
            ['sub', '子集合檢查', '已有包含 X、次數一樣的 → X 不封閉']
        ];
        const BADGE = { infreq: '不頻繁', p1: '性質 1', p2: '性質 2', p3: '性質 3', p4: '性質 4' };

        /* ---------- 畫面 ---------- */
        function renderDB() {
            const table = $('db');
            const hit = new Set(selected || []);
            let html = '<tr><th class="tid-h"></th>' + ITEMS.map(i =>
                `<th class="${hit.has(i) ? 'sel' : ''}"><span class="emo">${EMOJI[i]}</span>${i}</th>`).join('') +
                (editing ? '<th class="del-h"></th>' : '') + '</tr>';
            db.forEach((t, r) => {
                const match = selected && selected.every(x => t.has(x));
                html += `<tr class="${match ? 'match' : ''}"><td class="tid">T${r + 1}</td>` +
                    ITEMS.map(i => `<td><div class="cell ${t.has(i) ? 'has' : ''} ${match && hit.has(i) ? 'hit' : ''}" data-r="${r}" data-i="${i}"></div></td>`).join('') +
                    (editing ? `<td><button class="del" data-del="${r}" aria-label="刪除 T${r + 1}">✕</button></td>` : '') + '</tr>';
            });
            table.innerHTML = html;
            $('db-card').classList.toggle('editing', editing);
            document.querySelectorAll('.hidden-when-view').forEach(b => { b.style.display = editing ? '' : 'none'; });
            $('btn-edit').textContent = editing ? '✓ 編輯完成' : '✎ 編輯資料';
            $('btn-edit').classList.toggle('on', editing);
            $('btn-add-row').disabled = db.length >= 12;
            $('sup-val').textContent = minSup;
            $('sup-pct').textContent = `筆（${Math.round(minSup / db.length * 1000) / 10}%）`;
            $('sup-minus').disabled = minSup <= 1;
            $('sup-plus').disabled = minSup >= db.length;
        }

        /* 一排 tidset 小格子 */
        function cells(tids, cls = '') {
            const n = db.length;
            let h = `<span class="tcs ${cls}" style="--n:${n}">`;
            for (let t = 1; t <= n; t++) h += `<i class="${tids.includes(t) ? 'on' : ''}">${t}</i>`;
            return h + '</span>';
        }
        function vtRow(v, extra = '', ord = '') {
            const i = v.set[0];
            return `<div class="vt-row ${extra}"><span class="lab">${ord ? `<span class="ord">${ord}</span>` : ''}${EMOJI[i]} ${i}</span>${cells(v.tids)}<span class="sup">${v.tids.length}</span></div>`;
        }

        function classRows(f, s) {
            return '<div class="crows">' + f.rows.map((r, idx) => {
                let cls = '', role = '';
                if (r.gone) { cls = 'gone'; role = r.gone === 'p1' ? '併' : '刪'; }
                else if (idx === f.i) { cls = 'x'; role = 'X'; }
                else if (idx === f.j) { cls = 'xj'; role = 'Xj'; }
                else if (r.done) { cls = 'done'; role = '✓'; }
                const grown = idx === f.i && !sameSet(f.X, r.set) ? `<span class="grow"> → X = ${fmt(f.X)}</span>` : '';
                return `<div class="crow ${cls}"><span class="role">${role}</span><span class="set">${fmt(r.set)}${grown}</span><span class="tids">${r.tids.join(' ')}　${r.tids.length}</span></div>`;
            }).join('') + '</div>';
        }

        function renderStage(s) {
            const box = $('stage');
            const f = frame(s);
            let h = '';
            if (['all', 'closed', 'maximal', 'start'].includes(s.kind)) {
                h = '';
            } else if (s.kind === 'vertical') {
                h = `<div><div class="sub-h">垂直格式：商品 → 出現在哪幾筆（tidset）</div><div class="vt">${s.vertical.map(v => vtRow(v)).join('')}</div></div>`;
            } else if (s.kind === 'order') {
                h = `<div><div class="sub-h">第一層的類別（支持度由小到大）</div><div class="vt">` +
                    s.order.map((v, i) => vtRow(v, '', i + 1)).join('') + s.dropped.map(v => vtRow(v, 'out')).join('') + '</div></div>';
            } else if (f) {
                const path = s.stack.map((g, d) => d === 0 ? '第 1 層（前綴 {}）' : `第 ${d + 1} 層（前綴 <b>${fmt(g.prefix)}</b>）`).join(' › ');
                h += `<div class="crumb">${path}</div>`;
                h += classRows(f, s);
                if (PAIR.includes(s.kind) || s.kind === 'pick') {
                    h += '<div class="cmp">';
                    h += `<div class="cmp-row"><span class="lab">X</span>${cells(f.tX, 'x')}<span class="sup">${f.tX.length}</span></div>`;
                    if (s.Xj) {
                        h += `<div class="cmp-row"><span class="lab">Xj</span>${cells(s.tj, 'xj')}<span class="sup">${s.tj.length}</span></div>`;
                        h += `<div class="cmp-row"><span class="lab">交集</span>${cells(s.Y, 'y' + (s.Y.length < minSup ? ' low' : ''))}<span class="sup">${s.Y.length}</span></div>`;
                        const rel = { infreq: `${s.Y.length} < ${minSup}`, p1: 't(X) = t(Xj)', p2: 't(X) ⊂ t(Xj)', p3: 't(X) ⊃ t(Xj)', p4: '互不包含' }[s.kind];
                        h += `<div class="rel"><span class="badge ${s.kind}">${BADGE[s.kind]}</span><span>${rel}</span></div>`;
                    }
                    h += '</div>';
                }
                if (s.kind === 'check') {
                    h += `<div class="rel">${s.by ? `<span class="badge sub">不封閉</span><span>被 ${fmt(s.by.set)}（${s.by.sup} 次）包含</span>` : `<span class="badge ok">封閉</span><span>${fmt(s.X)} 加入，${s.sup} 次</span>`}</div>`;
                }
                const nc = s.kind === 'recurse' ? s.next : f.newClass;
                if (nc.length || PAIR.includes(s.kind)) {
                    h += `<div><div class="sub-h">${s.kind === 'recurse' ? '補上 X 之後，往下一層的類別' : '新類別（以 X 為前綴，等這一輪比完再往下）'}</div><div class="chips">` +
                        (nc.length ? nc.map(c => `<span class="chip">${s.kind === 'recurse' ? fmt(c.set) : 'X ∪ ' + fmt(c.set)}<span class="n">${c.tids.length}</span></span>`).join('')
                            : '<span class="crumb">（還沒有）</span>') + '</div></div>';
                }
            } else if (s.kind === 'maxfind' || s.kind === 'end') {
                const mk = new Set(s.max.map(c => key(c.set)));
                h = `<div><div class="sub-h">CHARM 找到的封閉樣式（照找到的順序，★ 是最大）</div><div class="chips">` +
                    (s.closed.length ? s.closed.map(c => `<span class="chip c ${mk.has(key(c.set)) ? 'm' : ''}">${mk.has(key(c.set)) ? '<span class="star">★</span>' : ''}${fmt(c.set)}<span class="n">${c.sup}</span></span>`).join('')
                        : '<span class="crumb">（沒有）</span>') + '</div></div>';
            }
            box.innerHTML = h;
        }

        /* ---------- 三種答案比一比 ---------- */
        function chipState(c, s) {
            const k = s.kind;
            const found = new Set(s.closed.map(x => key(x.set)));
            const f = frame(s);
            if (k === 'all') return '';
            if (k === 'closed') return c.closed ? 'c' : 'dim';
            if (k === 'maximal') return c.max ? 'c m' : 'dim';
            if (k === 'maxfind' || k === 'end') return c.closed ? (c.max ? 'c m' : 'c') : 'dim';
            let st = found.has(key(c.set)) ? 'c' : '';
            if (f && f.X && sameSet(f.X, c.set) && !['recurse'].includes(k)) st += ' cur';
            return st;
        }
        function renderLattice(s) {
            const A = answer;
            const k = s.kind;
            $('cnt-f').textContent = A.freq.length;
            $('cnt-c').textContent = A.closed.length;
            $('cnt-m').textContent = A.max.length;
            $('nest-f').classList.toggle('act', k === 'all');
            $('nest-c').classList.toggle('act', k === 'closed');
            $('nest-m').classList.toggle('act', k === 'maximal' || k === 'maxfind' || k === 'end');
            const box = $('levels');
            box.innerHTML = '';
            if (!A.freq.length) box.innerHTML = '<div class="level"><span class="tag">—</span><span class="empty">沒有頻繁樣式，把門檻調低看看。</span></div>';
            const byLen = {};
            A.freq.forEach(c => (byLen[c.set.length] = byLen[c.set.length] || []).push(c));
            Object.keys(byLen).forEach(n => {
                const row = document.createElement('div');
                row.className = 'level';
                row.innerHTML = `<span class="tag">${n} 樣</span><div class="chips"></div>`;
                byLen[n].forEach(c => {
                    const b = document.createElement('button');
                    b.type = 'button';
                    const st = chipState(c, s);
                    b.className = 'chip ' + st + (selected && key(selected) === key(c.set) ? ' sel' : '');
                    b.innerHTML = `${st.split(' ').includes('m') ? '<span class="star">★</span>' : ''}<span class="name"></span><span class="n">${c.sup}</span>`;
                    b.querySelector('.name').textContent = fmt(c.set);
                    b.addEventListener('click', () => pickPattern(c));
                    row.querySelector('.chips').appendChild(b);
                });
                box.appendChild(row);
            });
            const charmPart = !['all', 'closed', 'maximal', 'maxfind', 'end'].includes(k);
            $('legend').innerHTML = charmPart
                ? '<span><i style="border-color:#a78bfa"></i>CHARM 已經找到的封閉樣式</span><span><i style="border-color:var(--warn)"></i>目前的 X</span>'
                : '<span><i style="border-color:#a78bfa"></i>封閉</span><span><span class="star" style="color:var(--gold)">★</span> 最大</span><span><i style="border-color:var(--border);opacity:0.5"></i>這一層被拿掉的</span>';
        }

        function pickPattern(c) {
            const again = selected && key(selected) === key(c.set);
            selected = again ? null : c.set;
            renderDB();
            renderLattice(trace[cursor]);
            const hint = $('hint');
            if (again) { hint.textContent = ''; return; }
            let t = `${fmt(c.set)} 出現在 ${c.sup} 筆（表格標黃的列）。`;
            if (c.closed) {
                t += `它是封閉的：再多加任何一樣，次數都會變少。`;
            } else {
                t += `它不封閉：${fmt(c.closure.set)} 也是 ${c.sup} 次，買了它的人都也買了${c.closure.set.filter(x => !c.set.includes(x)).join('、')}。只記 ${fmt(c.closure.set)} 就能推回它的次數。`;
            }
            if (c.max) t += `它也是最大的：再加任何一樣就不到 ${minSup} 次。`;
            else if (c.maxSuper) t += `它不是最大的（被 ${fmt(c.maxSuper.set)} 包含）。`;
            hint.textContent = t;
        }

        function renderProps(s) {
            const use = s.stats.use;
            const now = s.kind === 'check' && s.by ? 'sub' : s.kind;
            $('props').innerHTML = PROPS.map(([k, label, rule]) =>
                `<div class="prop ${now === k ? 'now' : ''}"><span><b>${label}</b>　${rule}</span><span class="cnt">×${use[k]}</span></div>`).join('');
            $('st-inter').textContent = s.stats.inter;
            $('st-gone').textContent = s.stats.gone;
            $('st-sub').textContent = s.stats.sub;
        }

        /* 簡單的語法上色 */
        const KW = {
            java: new Set('public static final for if return new boolean int void class import while else var record'.split(' ')),
            py: new Set('def for in if elif else return not and or while import from as True False None del lambda any'.split(' '))
        };
        function highlight(line) {
            const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
            const commentAt = lang === 'java' ? line.indexOf('//') : line.indexOf('#');
            let body = line, comment = '';
            if (commentAt >= 0) { body = line.slice(0, commentAt); comment = line.slice(commentAt); }
            if (lang === 'py' && /^\s*"""/.test(line)) { body = ''; comment = line; }
            if (lang === 'java' && /^\s*\/\*\*/.test(line)) { body = ''; comment = line; }
            const out = body.replace(/("(?:[^"\\]|\\.)*")|(\b\d+\b)|([A-Za-z_]\w*)(\s*\()?|([^"\w]+)/g, (m, str, num, word, call, other) => {
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

        function renderCode(tag) {
            if (measuringBlocks || restoringBlocks) return;   // 量區塊高度時不用畫程式碼（程式碼框高度不會變），量完畫回來時它也沒被動過，省時間
            const pre = $('code');
            const lines = CODE[lang];
            pre.innerHTML = lines.map(([text, tags], i) =>
                `<span class="ln${tag && tags.includes(tag) ? ' hl' : ''}" data-n="${i + 1}">${highlight(text) || ' '}</span>`).join('');
            $('code-note').style.visibility = tag ? 'hidden' : '';   // 只切換看不看得到，不改內容，下面的程式碼才不會跳
            // 只捲程式碼框本身，不捲整個頁面
            // 亮起的行可能分成好幾段（主流程＋下面的函式本體）：
            // 全部放得下就一起置中；放不下就優先顯示最長的那一段
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
            } else {
                pre.scrollTo({ top: 0, behavior: 'smooth' });
            }
            $('downloads').innerHTML = lang === 'java'
                ? '下載 <a href="code/Charm.java" download>Charm.java</a>　執行 <code>javac Charm.java && java Charm</code>'
                : '下載 <a href="code/charm.py" download>charm.py</a>　執行 <code>python3 charm.py</code>';
        }

        function showStep() {
            const s = trace[cursor];
            selected = null;
            renderDB();
            $('explain').innerHTML = `<span class="step-no">步驟 ${cursor + 1} / ${trace.length}</span>${describe(s)}`;
            renderStage(s);
            renderLattice(s);
            renderProps(s);
            $('hint').textContent = answer.freq.length ? '點樣式看它出現在哪幾筆、為什麼是（或不是）封閉 / 最大' : '';
            renderCode(CODE_TAG[s.kind]);
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

        function rebuild(keepCursor) {
            stopAuto();
            minSup = Math.max(1, Math.min(minSup, db.length));
            answer = bruteForce();
            trace = buildTrace();
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
        /* CHARM 的題目：第一層排第一的是誰、兩個 tidset 比完套哪一條性質、子集合檢查會不會加入、哪些封閉樣式是最大的 */
        const QUIZ_ACT = {
            infreq: '交集不到門檻，跳過',
            p1: 'Xj 併進 X，並刪掉 Xj',
            p2: 'Xj 併進 X，Xj 保留',
            p3: 'X∪Xj 進新類別，刪掉 Xj',
            p4: 'X∪Xj 進新類別，Xj 保留'
        };
        const QUIZ_TRAP = { infreq: ['p4', 'p3'], p1: ['p2', 'p3'], p2: ['p1', 'p3'], p3: ['p2', 'p4'], p4: ['p3', 'infreq'] };
        function quizFor(s, i) {
            const rnd = quizRng(i + 1);
            const f = frame(s);
            switch (s.kind) {
                case 'order': {
                    if (s.order.length < 2) return null;
                    const first = s.order[0], big = s.order[s.order.length - 1];
                    const abc = [...s.order].sort((a, b) => cmp(a.set[0], b.set[0]))[0];
                    return {
                        q: `頻繁的商品要排成第一層類別（支持度由小到大）。排第一個的是哪個？`,
                        ...quizOptions([first, big, abc, s.order[1]].map(o => ({ text: o.set[0] })), rnd),
                        why: `${first.set[0]} 只有 ${first.tids.length} 次，最少，排最前面；${big.set[0]} 有 ${big.tids.length} 次，排最後。`,
                        ask: { type: 'first' }
                    };
                }
                case 'infreq': case 'p1': case 'p2': case 'p3': case 'p4':
                    return {
                        q: `X = ${fmt(s.before)}，t(X) = ${tidsTxt(f.tX)}；Xj = ${fmt(s.Xj)}，t(Xj) = ${tidsTxt(s.tj)}。比完會怎樣？`,
                        ...quizOptions([s.kind, ...QUIZ_TRAP[s.kind]].map(k => ({ text: QUIZ_ACT[k] })), rnd),
                        why: s.kind === 'infreq' ? `交集只有 ${s.Y.length} 筆，不到 ${minSup}，先看門檻再看包含關係。`
                            : s.kind === 'p1' ? '兩個 tidset 一模一樣：永遠一起出現，Xj 併進 X，Xj 自己也不會封閉。'
                            : s.kind === 'p2' ? 't(X) 被 t(Xj) 包住：有 X 就一定有 Xj，併進 X；但 Xj 還有別的出現，要保留。'
                            : s.kind === 'p3' ? 't(Xj) 被 t(X) 包住：有 Xj 就一定有 X，Xj 自己不封閉，刪掉，X∪Xj 進新類別。'
                            : `兩個 tidset 互不包含，交集 ${s.Y.length} 筆：X∪Xj 進新類別，兩個都還要留著。`,
                        ask: { type: 'act', tX: f.tX, tj: s.tj, kinds: Object.keys(QUIZ_ACT).map(k => QUIZ_ACT[k]) }
                    };
                case 'check':
                    return {
                        q: `回到 X = ${fmt(s.X)}（${s.sup} 次）做子集合檢查。它會加入封閉樣式嗎？`,
                        choices: ['會', '不會'], answer: s.by ? 1 : 0,
                        why: s.by ? `已經找到的 ${fmt(s.by.set)} 包含它，也是 ${s.sup} 次，所以 X 不封閉。`
                            : `已經找到的封閉樣式裡沒有包含它又一樣 ${s.sup} 次的，加入。`,
                        ask: { type: 'closed', set: s.X, prev: trace[i - 1] ? trace[i - 1].closed.map(c => c.set) : [] }
                    };
                case 'maxfind': {
                    if (s.closed.length < 2) return null;
                    const pick = quizShuffle(s.closed, rnd).slice(0, 3);
                    const isMax = c => s.max.some(m => sameSet(m.set, c.set));
                    return {
                        q: '下面這幾個封閉樣式，哪些是最大樣式（沒有更大的封閉樣式包含它）？',
                        choices: pick.map(c => fmt(c.set)), answer: pick.map((c, k) => k).filter(k => isMax(pick[k])), multi: true,
                        why: pick.map(c => `${fmt(c.set)} ${isMax(c) ? '是' : '不是'}`).join('、') + '；只看包含關係，次數不用一樣。',
                        ask: { type: 'max', sets: pick.map(c => c.set) }
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
            timer = setInterval(() => { if (!step(1)) stopAuto(); }, 1800);
        });
        document.addEventListener('keydown', e => {
            if (e.key === 'ArrowRight') { stopAuto(); step(1); }
            if (e.key === 'ArrowLeft') { stopAuto(); step(-1); }
        });

        $('sup-minus').addEventListener('click', () => { minSup--; rebuild(false); });
        $('sup-plus').addEventListener('click', () => { minSup++; rebuild(false); });

        $('btn-edit').addEventListener('click', () => { editing = !editing; renderDB(); });
        $('db').addEventListener('click', e => {
            if (!editing) return;
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
            if (t.has(item)) {
                if (t.size <= 1) return;          // 一筆交易至少要買一樣
                t.delete(item);
            } else {
                t.add(item);
            }
            rebuild(false);
        });
        $('btn-add-row').addEventListener('click', () => {
            if (db.length >= 12) return;
            db.push(new Set([ITEMS[0]]));
            rebuild(false);
        });
        $('btn-reset-db').addEventListener('click', () => {
            db = SAMPLE.map(t => new Set(t));
            minSup = DEFAULT_SUP;
            rebuild(false);
        });

        $('lang').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b) return;
            lang = b.dataset.lang;
            [...$('lang').children].forEach(x => x.classList.toggle('active', x === b));
            renderCode(CODE_TAG[trace[cursor].kind]);
        });

        let resizeTimer = null;
        window.addEventListener('resize', () => {
            clearTimeout(resizeTimer);
            resizeTimer = setTimeout(reserveExplainHeight, 150);
        });

        rebuild(false);
    </script>
</body>

</html>
