<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/stream-counting.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/stream-counting-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/stream-counting-180.png">
    <title>串流近似計數：Lossy Counting 與 Space-Saving</title>
    <meta name="description" content="記憶體有限、資料又停不下來時，怎麼數每個商品賣了幾次？一步一步看 Lossy Counting 怎麼分桶清理、Space-Saving 怎麼只用 k 個計數器，以及它們的誤差保證，Java 與 Python 程式碼逐行對照。">
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

        /* ── 分頁 ── */
        .tabs { display: flex; gap: 0.4rem; margin-top: 1.3rem; border-bottom: 1px solid var(--border); }
        .tabs button {
            background: none;
            border: 1px solid transparent;
            border-bottom: none;
            color: var(--muted);
            font: inherit;
            font-size: 0.92rem;
            padding: 0.5rem 0.9rem;
            border-radius: 10px 10px 0 0;
            cursor: pointer;
            margin-bottom: -1px;
        }
        .tabs button:hover { color: var(--text); }
        .tabs button.active { color: var(--text); background: var(--panel); border-color: var(--border); border-bottom: 1px solid var(--panel); }
        .tabs .no { font: 700 0.78rem 'Space Mono', monospace; color: var(--accent2); margin-right: 0.35rem; }
        @media (max-width: 420px) { .tabs button { padding: 0.5rem 0.6rem; font-size: 0.86rem; } }
        [hidden] { display: none !important; }

        .layout { display: grid; gap: 1rem; margin-top: 1rem; }
        .layout > * { min-width: 0; display: grid; gap: 1rem; align-content: start; }
        .layout > * > * { min-width: 0; }
        @media (min-width: 960px) { .layout { grid-template-columns: 1fr 1.02fr; } }

        .card {
            background: var(--panel);
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 1rem;
        }
        .card-head { display: flex; justify-content: space-between; align-items: center; gap: 0.5rem; flex-wrap: wrap; margin-bottom: 0.7rem; }
        .card-head h2 { margin: 0; }
        .card-head .unit { color: var(--muted); font-size: 0.8rem; }

        button.btn {
            background: var(--panel-2);
            color: var(--text);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 0.4rem 0.75rem;
            font-size: 0.88rem;
            cursor: pointer;
            font-family: inherit;
        }
        button.btn:hover:not(:disabled) { border-color: var(--accent2); }
        button.btn:disabled { opacity: 0.4; cursor: default; }
        button.btn.primary { background: var(--accent); border-color: var(--accent); }
        button.btn.small { padding: 0.25rem 0.6rem; font-size: 0.8rem; }

        .player { display: flex; flex-wrap: wrap; gap: 0.4rem; align-items: center; }
        .stepper { width: 30px; height: 30px; padding: 0 !important; }
        .params { display: flex; flex-wrap: wrap; gap: 0.5rem 1.2rem; align-items: center; margin-top: 0.75rem; font-size: 0.88rem; }
        .param { display: flex; align-items: center; gap: 0.4rem; }
        .param .val { font: 700 1rem 'Space Mono', monospace; min-width: 2.6em; text-align: center; }
        .param .unit { color: var(--muted); font-size: 0.8rem; }
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
        .explain .ok { color: var(--lt-86efac, #86efac); font-weight: 600; }
        .explain .no { color: var(--lt-fca5a5, #fca5a5); font-weight: 600; }

        /* ── 串流輸送帶 ── */
        .belt {
            overflow-x: auto;
            background: var(--lt-0a0a14, #0a0a14);
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 10px 8px;
        }
        .belt-inner { display: flex; gap: 6px; width: max-content; align-items: flex-end; }
        .bucket { display: flex; gap: 3px; position: relative; padding: 18px 4px 4px; border: 1px dashed var(--lt-2c2c48, #2c2c48); border-radius: 9px; }
        .bucket.plain { border-color: transparent; padding-top: 4px; }
        .bucket .blab { position: absolute; top: 1px; left: 6px; font: 0.62rem 'Space Mono', monospace; color: var(--muted); white-space: nowrap; }
        .bucket.cur { border-color: var(--accent2); }
        .bucket.cur .blab { color: var(--accent2); }
        .bucket.ended { border: 1px solid var(--warn); box-shadow: 0 0 0 1px var(--warn); }
        .bucket.ended .blab { color: var(--warn); }
        .cell {
            flex: none;
            width: 32px;
            border: 1px solid var(--border);
            border-radius: 7px;
            background: var(--panel-2);
            text-align: center;
            padding: 2px 0 1px;
            transition: opacity 0.3s, border-color 0.3s;
        }
        .cell .emo { display: block; font-size: 17px; line-height: 1.35; }
        .cell .idx { display: block; font: 0.56rem 'Space Mono', monospace; color: var(--muted); line-height: 1.2; }
        .cell.future { opacity: 0.4; border-style: dashed; background: transparent; }
        .cell.cur { border-color: var(--good); box-shadow: 0 0 0 1px var(--good); }
        .cell.cur .idx { color: var(--good); }
        .cell.same { background: var(--lt-f59e0b-22, rgba(245, 158, 11, 0.22)); }
        .legend { display: flex; flex-wrap: wrap; gap: 0.3rem 0.9rem; font-size: 0.75rem; color: var(--muted); margin-top: 0.5rem; }
        .legend i { display: inline-block; width: 11px; height: 11px; border-radius: 3px; margin-right: 0.3rem; vertical-align: -1px; border: 2px solid; }
        .composer { display: flex; flex-wrap: wrap; gap: 0.4rem; align-items: center; margin-top: 0.8rem; padding-top: 0.8rem; border-top: 1px dashed var(--border); font-size: 0.85rem; }
        .composer .lab { color: var(--muted); font-size: 0.8rem; }
        .picks { display: flex; flex-wrap: wrap; gap: 0.3rem; flex-basis: 100%; align-items: center; }
        .pick {
            background: var(--panel-2);
            border: 1px solid var(--border);
            color: var(--text);
            border-radius: 999px;
            padding: 0.12rem 0.55rem 0.12rem 0.4rem;
            font: inherit;
            font-size: 0.8rem;
            cursor: pointer;
        }
        .pick:hover { border-color: var(--accent2); }
        .pick.rare { color: var(--muted); border-style: dashed; }
        .len { display: flex; align-items: center; gap: 0.35rem; }
        .len .val { font: 700 0.95rem 'Space Mono', monospace; min-width: 2em; text-align: center; }
        .hint { color: var(--muted); font-size: 0.8rem; margin-top: 0.5rem; min-height: 1.3em; }
        .hint.warn { color: var(--warn); }

        /* ── 計數器表 ── */
        .rows { display: grid; gap: 0.3rem; }
        .row {
            display: grid;
            grid-template-columns: minmax(0, 1fr) 2.3em 2.3em 2.3em minmax(56px, 1.1fr);
            gap: 0.4rem;
            align-items: center;
            padding: 0.3rem 0.55rem;
            border: 1px solid var(--border);
            border-radius: 8px;
            background: var(--panel-2);
            font-size: 0.84rem;
        }
        .row.head { background: none; border-color: transparent; color: var(--muted); font-size: 0.72rem; padding-top: 0; padding-bottom: 0; }
        .row.head span { text-align: right; }
        .row.head span:first-child, .row.head span:last-child { text-align: left; }
        .row .it { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .row .it .sl { font: 700 0.7rem 'Space Mono', monospace; color: var(--muted); margin-right: 0.3rem; }
        .row .n { font: 700 0.84rem 'Space Mono', monospace; text-align: right; }
        .row .n.est { color: var(--accent2); }
        .row .n.dim { color: var(--muted); font-weight: 400; }
        .row .n.off { color: var(--bad); }
        .row.cur { border-color: var(--warn); box-shadow: 0 0 0 1px var(--warn) inset; }
        .row.new { border-color: var(--good); box-shadow: 0 0 0 1px var(--good) inset; }
        .row.gone { opacity: 0.6; border-style: dashed; border-color: var(--lt-f87171-60, rgba(248, 113, 113, 0.6)); }
        .row.gone .it { text-decoration: line-through; }
        .row.rep { box-shadow: inset 3px 0 0 var(--accent); background: var(--lt-7c3aed-12, rgba(124, 58, 237, 0.12)); }
        .row.rep.fp { box-shadow: inset 3px 0 0 var(--warn); background: var(--lt-f59e0b-10, rgba(245, 158, 11, 0.1)); }
        .rbar { position: relative; height: 10px; background: var(--lt-1b1b30, #1b1b30); border-radius: 5px; }
        .rbar .solid { position: absolute; left: 0; top: 0; bottom: 0; background: var(--accent2); border-radius: 5px; transition: width 0.25s; }
        .rbar .range { position: absolute; top: 0; bottom: 0; background: var(--lt-06b6d4-30, rgba(6, 182, 212, 0.3)); border-radius: 0 5px 5px 0; transition: left 0.25s, width 0.25s; }
        .rbar .truth { position: absolute; top: -3px; bottom: -3px; width: 2px; margin-left: -1px; background: var(--lt-ffffff, #fff); border-radius: 1px; transition: left 0.25s; }
        .rbar .truth.out { background: var(--bad); }
        .empty { color: var(--muted); font-size: 0.85rem; padding: 0.3rem 0.2rem; }
        .forgot { margin-top: 0.7rem; font-size: 0.8rem; color: var(--muted); display: flex; flex-wrap: wrap; gap: 0.3rem 0.45rem; align-items: center; min-height: 1.6em; }
        .forgot .chip { border: 1px dashed var(--lt-3a3a5a, #3a3a5a); border-radius: 999px; padding: 0 0.5rem; color: var(--lt-b4b4c8, #b4b4c8); white-space: nowrap; }
        .forgot .chip b { font: 700 0.74rem 'Space Mono', monospace; color: var(--text); }

        .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.5rem; margin-top: 0.9rem; }
        .stat { background: var(--panel-2); border-radius: 10px; padding: 0.55rem 0.6rem; min-width: 0; }
        .stat .v { font: 700 1.2rem 'Space Mono', monospace; }
        .stat .v small { font-size: 0.72rem; color: var(--muted); font-weight: 400; }
        .stat .k { color: var(--muted); font-size: 0.75rem; line-height: 1.35; }
        .bars { display: grid; gap: 0.35rem; margin-top: 0.8rem; }
        .bar { display: grid; grid-template-columns: 8.4em 1fr 3em; gap: 0.5rem; align-items: center; font-size: 0.78rem; color: var(--muted); }
        .bar .track { height: 10px; background: var(--lt-1b1b30, #1b1b30); border-radius: 6px; overflow: hidden; }
        .bar .fill { height: 100%; background: var(--warn); border-radius: 6px; transition: width 0.25s; }
        .bar .fill.limit { background: var(--lt-4a4a6a, #4a4a6a); }
        .bar .fill.mem { background: var(--accent2); }
        .bar .n { font: 700 0.8rem 'Space Mono', monospace; color: var(--text); text-align: right; }
        .guar { margin-top: 0.6rem; font-size: 0.82rem; color: var(--muted); }
        .guar b { color: var(--text); }
        .guar .ok { color: var(--lt-86efac, #86efac); font-weight: 600; }

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
            position: relative;
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

        .notes { margin-top: 1rem; display: grid; gap: 1rem; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr; } }
        .notes p, .notes li { color: var(--lt-c6c6d6, #c6c6d6); font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; }
        .notes b { color: var(--text); }
        .notes a { color: var(--accent2); }

        @media (max-width: 600px) {
            .row { grid-template-columns: minmax(0, 1fr) 2.1em 2.1em 2.1em minmax(44px, 0.8fr); gap: 0.3rem; padding: 0.3rem 0.45rem; font-size: 0.8rem; }
            .bar { grid-template-columns: 7.4em 1fr 2.8em; }
            .stat .v { font-size: 1.05rem; }
        }
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
        <div class="kicker">RESEARCH DEMO · DATA STREAM MINING</div>
        <h1>串流近似計數<small>Lossy Counting 與 Space-Saving：記憶體不夠記全部，數出來的次數還是有保證</small></h1>
        <p class="intro">
            收銀機一直刷，商品一筆一筆進來，想知道「哪些商品賣得特別多」。最直接的做法是每種商品一個計數器，但真實的店有上萬種商品、資料又停不下來，<b>記憶體不可能每種都記</b>。
            <a href="sliding-window.html">滑動視窗</a>那頁是只看最近 W 筆、每個組合都<b>精確</b>計數；這頁反過來：<b>從頭到現在的全部資料都算</b>，但記憶體有限，只能<b>近似</b>，而且誤差有數學保證。
            分頁一的 <b>Lossy Counting</b> 定期把次數太少的商品忘掉，次數只會少算、最多少 εN；分頁二的 <b>Space-Saving</b> 只有 k 個計數器，滿了就把最小的那個讓出來，次數只會多算、最多多 N/k。
            例子沿用超商的六樣商品，再加上偶爾才有人買的果汁、布丁、泡麵、巧克力，讓記憶體不夠用。
        </p>

        <div class="tabs" role="tablist">
            <button role="tab" id="tab-lc" data-tab="lc" class="active" aria-selected="true"><span class="no">01</span>Lossy Counting</button>
            <button role="tab" id="tab-ss" data-tab="ss" aria-selected="false"><span class="no">02</span>Space-Saving</button>
        </div>

        <!-- ===================== 分頁一：Lossy Counting ===================== -->
        <section id="panel-lc" role="tabpanel" aria-labelledby="tab-lc">
            <div class="layout">
                <div>
                    <div class="card">
                        <div class="card-head"><h2>一步一步看</h2></div>
                        <div class="player">
                            <button class="btn" id="lc-first" title="回到開頭">⏮</button>
                            <button class="btn" id="lc-prev">◀ 上一步</button>
                            <button class="btn primary" id="lc-next">下一步 ▶</button>
                            <button class="btn" id="lc-play">▶ 自動播放</button>
                            <button class="btn" id="lc-last">⏭ 直接看結果</button>
                        </div>
                        <div class="params">
                            <div class="param">
                                <span>誤差 ε</span>
                                <button class="btn stepper" id="eps-minus" aria-label="ε 變小">−</button>
                                <span class="val" id="eps-val">0.1</span>
                                <button class="btn stepper" id="eps-plus" aria-label="ε 變大">+</button>
                                <span class="unit" id="w-unit">桶寬 w = 10</span>
                            </div>
                            <div class="param">
                                <span>支持度 s</span>
                                <button class="btn stepper" id="lcs-minus" aria-label="s 變小">−</button>
                                <span class="val" id="lcs-val">0.2</span>
                                <button class="btn stepper" id="lcs-plus" aria-label="s 變大">+</button>
                            </div>
                        </div>
                        <div class="quiz-bar">
                            <button class="btn quiz-toggle" id="lc-quiz-toggle" aria-pressed="false" title="按下一步之前先猜猜看">🎯 練習模式<span class="sw" aria-hidden="true"></span></button>
                            <span class="quiz-score" id="lc-quiz-score" style="visibility:hidden">答對 0/0</span>
                        </div>
                        <div class="quiz-host" id="lc-quiz-host">
                            <div class="explain" id="lc-explain"></div>
                            <div class="quiz" id="lc-quiz" role="group" aria-label="練習題" hidden></div>
                        </div>
                    </div>

                    <div class="card">
                        <div class="card-head"><h2>商品串流</h2><span class="unit" id="lc-count"></span></div>
                        <div class="belt" id="lc-belt"><div class="belt-inner" id="lc-belt-inner"></div></div>
                        <div class="legend">
                            <span><i style="border-color:var(--good)"></i>正在處理的這一筆</span>
                            <span><i style="border-color:#3a3a5a;border-style:dashed"></i>還沒進來</span>
                            <span><i style="border-color:var(--warn);background:rgba(245,158,11,0.3)"></i>跟這一筆同一種商品</span>
                            <span><i style="border-color:#2c2c48;border-style:dashed"></i>一桶（w 筆）</span>
                        </div>
                        <div class="composer" id="lc-tools"></div>
                        <div class="hint" id="lc-hint"></div>
                    </div>
                </div>

                <div>
                    <div class="card">
                        <div class="card-head"><h2>記憶體裡的表</h2><span class="unit">一列 = 一個商品的 (f, Δ)</span></div>
                        <div class="rows" id="lc-rows"></div>
                        <div class="forgot" id="lc-forgot"></div>
                        <div class="legend">
                            <span><i style="border-color:var(--accent2);background:var(--accent2)"></i>f：至少有這麼多次</span>
                            <span><i style="border-color:rgba(6,182,212,0.4);background:rgba(6,182,212,0.3)"></i>f ~ f+Δ：真實次數可能的範圍</span>
                            <span><i style="border-color:#fff;width:3px;padding:0;border-width:0 0 0 3px;border-radius:0"></i>真實次數</span>
                        </div>
                        <div class="stats">
                            <div class="stat"><div class="v" id="lc-st-n">0</div><div class="k">看過幾筆 N</div></div>
                            <div class="stat"><div class="v" id="lc-st-mem">0</div><div class="k">表裡記著幾個商品</div></div>
                            <div class="stat"><div class="v" id="lc-st-exact">0</div><div class="k">精確計數要記幾個（出現過的種類）</div></div>
                        </div>
                        <div class="bars">
                            <div class="bar"><span>允許低估 εN</span><div class="track"><div class="fill limit" id="lc-bar-lim"></div></div><span class="n" id="lc-bar-lim-n">0</span></div>
                            <div class="bar"><span>實際最多少算</span><div class="track"><div class="fill" id="lc-bar-err"></div></div><span class="n" id="lc-bar-err-n">0</span></div>
                        </div>
                        <div class="guar" id="lc-guar"></div>
                    </div>

                    <div class="card">
                        <div class="card-head">
                            <h2>程式碼</h2>
                            <div class="lang">
                                <button data-lang="java" class="active">Java</button>
                                <button data-lang="py">Python</button>
                            </div>
                        </div>
                        <pre class="code" id="lc-code"></pre>
                        <div class="downloads" id="lc-downloads"></div>
                    </div>
                </div>
            </div>

            <div class="notes">
                <div class="card">
                    <h2>為什麼少算不會超過 εN？</h2>
                    <p>把串流每 w = ⌈1/ε⌉ 筆切成一桶。看到第 N 筆時是第 b = ⌈N/w⌉ 桶，前面已經結束的 b − 1 桶共 (b − 1)·w 筆，不超過 N，所以 <b>b − 1 ≤ N/w ≤ εN</b>。整個保證就靠這件事：
                        一個商品在第 j 桶結束被刪掉時 f + Δ ≤ j，也就是「到那時為止它最多出現 j 次」，漏掉的量不會超過 j ≤ b − 1。</p>
                    <p style="margin-top:0.5rem">它之後在第 b 桶又出現時，演算法不知道之前漏了多少，就保守地記 <b>Δ = b − 1</b>（之前最晚在第 b − 1 桶結束時被刪，那時最多 b − 1 次）。
                        所以表裡的每一列都滿足 <b>f ≤ 真實次數 ≤ f + Δ</b>，而 Δ ≤ b − 1 ≤ εN；不在表裡的商品，真實次數也不超過 εN。</p>
                    <p style="margin-top:0.5rem">查詢時把門檻放寬成 f ≥ (s − ε)N：真實次數 ≥ sN 的商品，f 至少有 sN − εN，<b>一定會被回報，不會漏</b>；代價是可能多報幾個真實次數在 (s − ε)N 到 sN 之間的商品。
                        記憶體方面，論文證明表的大小最多約 (1/ε)·log(εN)，跟商品有幾萬種無關。</p>
                </div>
                <div class="card">
                    <h2>跟滑動視窗比，以及跟實驗室研究的關係</h2>
                    <ul>
                        <li><b>看的範圍不同：</b><a href="sliding-window.html">滑動視窗</a>只看最近 W 筆，舊資料會「離開」，但視窗裡的次數是精確的；Lossy Counting 看從頭到現在的全部（叫做 landmark 模型），沒有資料離開，換成次數不精確。</li>
                        <li><b>ε 是在拿記憶體換準確度：</b>ε 越小，桶越寬、清得越少，越準但記得越多。試著把 ε 調大，看表變小、誤報變多。</li>
                        <li><b>只會少算、不會多算：</b>f 是「確定看到的次數」，所以 f 本身已經 ≥ sN 的商品一定是真的頻繁；放寬門檻才會出現誤報。</li>
                        <li><b>從單一商品到商品組合：</b>原始論文（Manku 與 Motwani，2002）也把同一招用在頻繁樣式上：一批一批讀交易，組合的計數一樣帶著 Δ、一樣分桶清理。
                            實驗室做的串流頻繁樣式、高效益樣式探勘，核心也是同一個問題：<b>記不下全部時，要丟掉哪些、丟了之後誤差怎麼保證</b>。</li>
                    </ul>
                </div>
            </div>
        </section>

        <!-- ===================== 分頁二：Space-Saving ===================== -->
        <section id="panel-ss" role="tabpanel" aria-labelledby="tab-ss" hidden>
            <div class="layout">
                <div>
                    <div class="card">
                        <div class="card-head"><h2>一步一步看</h2></div>
                        <div class="player">
                            <button class="btn" id="ss-first" title="回到開頭">⏮</button>
                            <button class="btn" id="ss-prev">◀ 上一步</button>
                            <button class="btn primary" id="ss-next">下一步 ▶</button>
                            <button class="btn" id="ss-play">▶ 自動播放</button>
                            <button class="btn" id="ss-last">⏭ 直接看結果</button>
                        </div>
                        <div class="params">
                            <div class="param">
                                <span>計數器 k</span>
                                <button class="btn stepper" id="k-minus" aria-label="k 變小">−</button>
                                <span class="val" id="k-val">5</span>
                                <button class="btn stepper" id="k-plus" aria-label="k 變大">+</button>
                                <span class="unit">格</span>
                            </div>
                            <div class="param">
                                <span>支持度 s</span>
                                <button class="btn stepper" id="sss-minus" aria-label="s 變小">−</button>
                                <span class="val" id="sss-val">0.2</span>
                                <button class="btn stepper" id="sss-plus" aria-label="s 變大">+</button>
                            </div>
                        </div>
                        <div class="quiz-bar">
                            <button class="btn quiz-toggle" id="ss-quiz-toggle" aria-pressed="false" title="按下一步之前先猜猜看">🎯 練習模式<span class="sw" aria-hidden="true"></span></button>
                            <span class="quiz-score" id="ss-quiz-score" style="visibility:hidden">答對 0/0</span>
                        </div>
                        <div class="quiz-host" id="ss-quiz-host">
                            <div class="explain" id="ss-explain"></div>
                            <div class="quiz" id="ss-quiz" role="group" aria-label="練習題" hidden></div>
                        </div>
                    </div>

                    <div class="card">
                        <div class="card-head"><h2>商品串流</h2><span class="unit" id="ss-count"></span></div>
                        <div class="belt" id="ss-belt"><div class="belt-inner" id="ss-belt-inner"></div></div>
                        <div class="legend">
                            <span><i style="border-color:var(--good)"></i>正在處理的這一筆</span>
                            <span><i style="border-color:#3a3a5a;border-style:dashed"></i>還沒進來</span>
                            <span><i style="border-color:var(--warn);background:rgba(245,158,11,0.3)"></i>跟這一筆同一種商品</span>
                        </div>
                        <div class="composer" id="ss-tools"></div>
                        <div class="hint" id="ss-hint"></div>
                    </div>
                </div>

                <div>
                    <div class="card">
                        <div class="card-head"><h2>k 格計數器</h2><span class="unit">一格 = (商品, 次數, 誤差)</span></div>
                        <div class="rows" id="ss-rows"></div>
                        <div class="forgot" id="ss-forgot"></div>
                        <div class="legend">
                            <span><i style="border-color:var(--accent2);background:var(--accent2)"></i>次數 − 誤差：至少有這麼多次</span>
                            <span><i style="border-color:rgba(6,182,212,0.4);background:rgba(6,182,212,0.3)"></i>到估計次數為止：可能的範圍</span>
                            <span><i style="border-color:#fff;width:3px;padding:0;border-width:0 0 0 3px;border-radius:0"></i>真實次數</span>
                        </div>
                        <div class="stats">
                            <div class="stat"><div class="v" id="ss-st-n">0</div><div class="k">看過幾筆 N</div></div>
                            <div class="stat"><div class="v" id="ss-st-mem">0</div><div class="k">用掉幾格計數器</div></div>
                            <div class="stat"><div class="v" id="ss-st-exact">0</div><div class="k">精確計數要記幾個（出現過的種類）</div></div>
                        </div>
                        <div class="bars">
                            <div class="bar"><span>允許高估 N/k</span><div class="track"><div class="fill limit" id="ss-bar-lim"></div></div><span class="n" id="ss-bar-lim-n">0</span></div>
                            <div class="bar"><span>實際最多多算</span><div class="track"><div class="fill" id="ss-bar-err"></div></div><span class="n" id="ss-bar-err-n">0</span></div>
                        </div>
                        <div class="guar" id="ss-guar"></div>
                    </div>

                    <div class="card">
                        <div class="card-head">
                            <h2>程式碼</h2>
                            <div class="lang">
                                <button data-lang="java" class="active">Java</button>
                                <button data-lang="py">Python</button>
                            </div>
                        </div>
                        <pre class="code" id="ss-code"></pre>
                        <div class="downloads" id="ss-downloads"></div>
                    </div>
                </div>
            </div>

            <div class="notes">
                <div class="card">
                    <h2>為什麼多算不會超過 N/k？</h2>
                    <p>每來一筆，剛好有一格的次數 +1（不管是原本就在記、放進空格、還是搶別人的格子），所以 <b>k 格的次數加起來永遠等於 N</b>。
                        k 個數加起來是 N，最小的那個一定 <b>≤ N/k</b>。</p>
                    <p style="margin-top:0.5rem">新商品搶走最小那格時，次數從 c + 1 開始，其中最多 c 次其實是被踢掉的商品的，所以記<b>誤差 = c</b>，而 c 是當時的最小值、≤ N/k。
                        之後這格只會因為自己出現才 +1，所以一直滿足 <b>次數 − 誤差 ≤ 真實次數 ≤ 次數</b>。</p>
                    <p style="margin-top:0.5rem">反過來，沒在記的商品，真實次數不會超過它被踢掉時的次數，那時它是最小的；而接手那格的次數已經比它多 1、之後只會變大。
                        算一下就知道<b>沒在記的商品，真實次數一定小於 N/k</b>。所以只要 k ≥ 1/s，真實次數 ≥ sN 的商品一定還在格子裡，查詢「次數 ≥ sN」不會漏；「次數 − 誤差 ≥ sN」的更是保證真的頻繁。</p>
                </div>
                <div class="card">
                    <h2>兩種方法怎麼選</h2>
                    <ul>
                        <li><b>記憶體：</b>Space-Saving 固定 k 格，事先就知道要多少；Lossy Counting 的表會隨資料長大縮小，只有上界。</li>
                        <li><b>誤差方向：</b>Lossy Counting 只會少算（f ≤ 真實），Space-Saving 只會多算（次數 ≥ 真實）。兩個都附帶「最多差多少」，所以都能回答「哪些商品一定夠頻繁、哪些可能是誤報」。</li>
                        <li><b>熱門商品排行（top-k）：</b>Space-Saving 的格子本身就是一份「目前最熱門的 k 個」，特別適合即時排行榜；資料越偏（少數商品賣超多），它越準。</li>
                        <li><b>速度：</b>這頁的程式每次都把 k 格掃一遍找最小，好讀但慢；原論文用一種叫 Stream-Summary 的結構（同次數的放同一串、串依次數排好），每筆都是 O(1)。</li>
                        <li><b>還有別的路：</b>Count-Min Sketch 用幾個雜湊表只記數字、不記商品名稱，也是只會多算。這些「用很小的摘要回答近似問題」的技巧，就是串流探勘研究的基本工具。</li>
                    </ul>
                </div>
            </div>
        </section>
    </div>

    <script>
        /* =========================================================
           串流近似計數一步一步看
           網頁裡用 JavaScript 照著同樣的演算法跑一次，把每一步記下來；
           上一步／下一步只是在這些紀錄之間移動。右邊的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = { lc: /*CODE_LC*/null, ss: /*CODE_SS*/null };

        const ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片', '果汁', '布丁', '泡麵', '巧克力'];
        const RARE = new Set(['果汁', '布丁', '泡麵', '巧克力']);
        const EMOJI = { '咖啡': '☕', '麵包': '🍞', '牛奶': '🥛', '飯糰': '🍙', '茶葉蛋': '🥚', '洋芋片': '🥔', '果汁': '🧃', '布丁': '🍮', '泡麵': '🍜', '巧克力': '🍫' };
        const DEFAULT_STREAM = [
            '咖啡', '麵包', '咖啡', '布丁', '飯糰',
            '咖啡', '牛奶', '飯糰', '果汁', '咖啡',
            '茶葉蛋', '飯糰', '咖啡', '泡麵', '麵包',
            '咖啡', '飯糰', '巧克力', '茶葉蛋', '咖啡',
            '牛奶', '飯糰', '洋芋片', '咖啡', '茶葉蛋',
            '飯糰', '布丁', '咖啡', '洋芋片', '茶葉蛋'
        ];
        const EPS_OPTS = [0.05, 0.1, 0.125, 0.2, 0.25];
        const S_OPTS = [0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5];
        const TOL = 1e-9;                 // 跟程式一樣：比大小時容忍浮點數誤差
        const MAX_LEN = 120, MIN_LEN = 5;

        const $ = id => document.getElementById(id);
        let stream = DEFAULT_STREAM.slice();
        let hotOrder = ITEMS.slice();     // 隨機串流時誰比較熱門
        let epsIdx = 1, lcSIdx = 2;       // ε = 0.1、s = 0.2
        let ssK = 5, ssSIdx = 2;          // k = 5、s = 0.2
        let activeTab = 'lc';
        let lang = 'java';
        let lcSteps = [], ssSteps = [];
        const cursors = { lc: 0, ss: 0 };
        const timers = { lc: null, ss: null };

        const esc = x => String(x).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        const it = x => `${EMOJI[x] || ''}${esc(x)}`;
        const num = v => String(+v.toFixed(3));
        const eps = () => EPS_OPTS[epsIdx];
        const lcS = () => S_OPTS[lcSIdx];
        const ssS = () => S_OPTS[ssSIdx];

        /* =================== Lossy Counting：照著程式跑一次 =================== */
        function lossyTrace(items, e, s) {
            const w = Math.ceil(1 / e);
            const table = new Map();          // 商品 -> [f, Δ]（Map 跟 Python dict 一樣照加入順序）
            const truth = new Map();          // 真實次數（只給畫面對照用，演算法本身不知道）
            let n = 0, maxMem = 0;
            const steps = [];
            const push = (kind, extra = {}) => steps.push({
                kind, n, w, maxMem, table: [...table].map(([x, [f, d]]) => [x, f, d]), truth: [...truth], ...extra
            });
            push('l-start');
            items.forEach((item, i) => {
                n++;
                const b = Math.ceil(n / w);
                const before = truth.get(item) || 0;
                truth.set(item, before + 1);
                if (table.has(item)) {
                    const prevF = table.get(item)[0];
                    table.get(item)[0]++;
                    maxMem = Math.max(maxMem, table.size);
                    push('l-inc', { i, item, b, prevF });
                } else {
                    table.set(item, [1, b - 1]);
                    maxMem = Math.max(maxMem, table.size);
                    push('l-new', { i, item, b, seenBefore: before });
                }
                if (n % w === 0) {                    // 一桶結束：清掉 f + Δ ≤ b 的
                    const removed = [];
                    for (const [x, [f, d]] of [...table]) {
                        if (f + d <= b) { removed.push([x, f, d]); table.delete(x); }
                    }
                    push('l-prune', { i, b, removed });
                }
            });
            const limit = (s - e) * n;
            const report = [...table].filter(([, [f]]) => f >= limit - TOL).map(([x, [f]]) => [x, f]);
            push('l-end', { report, limit, sN: s * n });
            return steps;
        }

        /* =================== Space-Saving：照著程式跑一次 =================== */
        function ssTrace(items, k, s) {
            const slots = [];                 // 每一格 [商品, 次數, 誤差]
            const truth = new Map();
            let n = 0;
            const steps = [];
            const push = (kind, extra = {}) => steps.push({
                kind, n, k, slots: slots.map(x => x.slice()), truth: [...truth], ...extra
            });
            push('s-start');
            items.forEach((item, i) => {
                n++;
                truth.set(item, (truth.get(item) || 0) + 1);
                const at = slots.findIndex(x => x[0] === item);
                if (at >= 0) {
                    const prevC = slots[at][1];
                    slots[at][1]++;
                    push('s-inc', { i, item, slot: at, prevC });
                    return;
                }
                if (slots.length < k) {
                    slots.push([item, 1, 0]);
                    push('s-new', { i, item, slot: slots.length - 1 });
                    return;
                }
                let m = 0;                            // 次數最小的那格；一樣小取最前面
                for (let j = 1; j < slots.length; j++) if (slots[j][1] < slots[m][1]) m = j;
                const victim = slots[m].slice();
                const ties = slots.filter(x => x[1] === victim[1]).length;
                const c = victim[1];
                slots[m] = [item, c + 1, c];
                push('s-replace', { i, item, slot: m, victim, ties });
            });
            const report = slots.filter(x => x[1] >= s * n - TOL).map(x => x.slice());
            push('s-end', { report, sN: s * n });
            return steps;
        }

        /* =================== 說明文字 =================== */
        function lcDescribe(s) {
            const N = stream.length;
            const truth = new Map(s.truth);
            switch (s.kind) {
                case 'l-start':
                    return `ε = ${eps()} 的意思是「每個商品的次數最多少算 εN」。先算<b>桶寬 w = ⌈1/ε⌉ = ${s.w}</b>：每 ${s.w} 筆算一桶，每桶結束時大掃除一次，把次數太少的商品忘掉。` +
                        `表一開始是空的，接下來 ${N} 筆商品一筆一筆進來，每一列記 <b>f</b>（看到幾次）和 <b>Δ</b>（之前最多漏算幾次）。`;
                case 'l-inc':
                    return `第 ${s.n} 筆（第 ${s.b} 桶）：${it(s.item)} 已經在表裡，f 從 ${s.prevF} 變成 <b>${s.prevF + 1}</b>，Δ 不變。`;
                case 'l-new': {
                    const head = `第 ${s.n} 筆（第 ${s.b} 桶）：${it(s.item)} 不在表裡，新增一列 f = 1、<b>Δ = b − 1 = ${s.b - 1}</b>。`;
                    if (s.b === 1) return head + `現在還在第 1 桶，還沒大掃除過，它不可能被刪過，所以 Δ = 0。`;
                    if (s.seenBefore) return head + `其實它之前出現過 ${s.seenBefore} 次，只是被大掃除忘掉了。Δ = ${s.b - 1} 是在說「之前最多漏算 ${s.b - 1} 次」，真的漏了 ${s.seenBefore} 次，<span class="ok">沒有超過 ✓</span>`;
                    return head + `它其實是第一次出現，但演算法分不出來，只能保守地記「之前最多漏算 ${s.b - 1} 次」。`;
                }
                case 'l-prune': {
                    const head = `第 ${s.b} 桶結束（N = ${s.n}）：大掃除，<b>f + Δ ≤ ${s.b}</b> 的商品真實次數最多 ${s.b} 次，先忘掉。`;
                    if (!s.removed.length) return head + `這次每一列都 f + Δ > ${s.b}，<b>沒有要刪的</b>。表裡還有 ${s.table.length} 個商品。`;
                    return head + `刪掉 ` + s.removed.map(([x, f, d]) => `${it(x)}（${f}+${d}=${f + d}，真實 ${truth.get(x)} 次）`).join('、') +
                        `，表裡剩 <b>${s.table.length}</b> 個商品。`;
                }
                case 'l-end': {
                    const sN = s.sN;
                    const real = [...truth].filter(([, t]) => t >= sN - TOL).map(([x]) => x);
                    const fp = s.report.filter(([x]) => truth.get(x) < sN - TOL).map(([x]) => x);
                    let t = `串流結束，N = ${s.n}。真的頻繁 = 真實次數 ≥ sN = ${num(sN)}。Lossy Counting 回報 <b>f ≥ (s − ε)N = ${num(s.limit)}</b> 的商品：` +
                        (s.report.length ? s.report.map(([x, f]) => `${it(x)} ${f}`).join('、') : '沒有') + '。';
                    t += fp.length ? `其中 ${fp.map(it).join('、')} 其實不到 ${num(sN)} 次，是門檻放寬 εN 帶來的<span class="no">誤報</span>；` : '';
                    t += real.length ? `真的頻繁的 ${real.map(it).join('、')} <span class="ok">一個都沒漏 ✓</span>` : `這次沒有真的頻繁的商品`;
                    return t + `。整個過程表裡最多同時記 ${s.maxMem} 個商品，精確計數要記 ${truth.size} 個。`;
                }
            }
            return '';
        }

        function ssDescribe(s) {
            const N = stream.length;
            const truth = new Map(s.truth);
            switch (s.kind) {
                case 's-start':
                    return `只有 <b>k = ${s.k} 格</b>計數器，每格記「商品、次數、誤差」。還有空格時新商品直接放進去；格子滿了以後，新商品要<b>搶走次數最小的那格</b>。接下來 ${N} 筆商品一筆一筆進來。`;
                case 's-inc':
                    return `第 ${s.n} 筆：${it(s.item)} 已經在第 ${s.slot + 1} 格，次數 ${s.prevC} → <b>${s.prevC + 1}</b>，誤差不變。`;
                case 's-new':
                    return `第 ${s.n} 筆：${it(s.item)} 沒在記，還有空格，放進第 ${s.slot + 1} 格：次數 1、誤差 0。從它第一次出現就開始記，所以完全準。`;
                case 's-replace': {
                    const [vx, c] = s.victim;
                    const t = truth.get(s.item);
                    return `第 ${s.n} 筆：${it(s.item)} 沒在記，${s.k} 格都滿了。次數最小的是第 ${s.slot + 1} 格的 ${it(vx)}（${c} 次${s.ties > 1 ? `，有 ${s.ties} 格一樣小，取最前面` : ''}），<b>把它踢掉</b>。` +
                        `${it(s.item)} 接手這格：次數 = ${c} + 1 = <b>${c + 1}</b>、誤差 = <b>${c}</b>（這 ${c + 1} 次裡最多 ${c} 次其實是別人的）。它真實出現 ${t} 次，多算了 ${c + 1 - t} 次。`;
                }
                case 's-end': {
                    const sN = s.sN;
                    const real = [...truth].filter(([, t]) => t >= sN - TOL).map(([x]) => x);
                    const sure = s.report.filter(([, c, e]) => c - e >= sN - TOL).map(([x]) => x);
                    const fp = s.report.filter(([x]) => truth.get(x) < sN - TOL).map(([x]) => x);
                    let t = `串流結束，N = ${s.n}。真的頻繁 = 真實次數 ≥ sN = ${num(sN)}。Space-Saving 回報 <b>次數 ≥ sN</b> 的格子：` +
                        (s.report.length ? s.report.map(([x, c, e]) => `${it(x)} ${c}`).join('、') : '沒有') + '。';
                    if (sure.length) t += `其中 ${sure.map(it).join('、')} 的「次數 − 誤差」也 ≥ ${num(sN)}，<span class="ok">保證真的頻繁</span>。`;
                    if (fp.length) t += `${fp.map(it).join('、')} 是被繼承的次數灌高的<span class="no">誤報</span>。`;
                    if (real.length) t += 1 / s.k <= ssS() + TOL ? `k ≥ 1/s，真的頻繁的<span class="ok">一個都沒漏 ✓</span>` : `k < 1/s 時不保證不漏，這次真的頻繁的有 ${real.map(it).join('、')}`;
                    return t + `。只用了 ${s.slots.length} 格，精確計數要記 ${truth.size} 個。`;
                }
            }
            return '';
        }

        const LC_TAGS = { 'l-start': ['start'], 'l-inc': ['arrive', 'inc'], 'l-new': ['arrive', 'new'], 'l-prune': ['pcall', 'prune'], 'l-end': ['query'] };
        const SS_TAGS = { 's-start': ['start'], 's-inc': ['arrive', 'inc'], 's-new': ['arrive', 'new'], 's-replace': ['arrive', 'replace'], 's-end': ['query'] };

        /* =================== 串流輸送帶 =================== */
        function renderBelt(group, s) {
            const inner = $(group + '-belt-inner');
            const cur = s.i !== undefined ? s.i : (s.kind.endsWith('end') ? stream.length - 1 : -1);
            const done = s.kind.endsWith('end') ? stream.length : s.n;
            const curItem = s.item;
            const cell = j => {
                let cls = 'cell';
                if (j >= done) cls += ' future';
                if (j === s.i && s.item) cls += ' cur';
                else if (curItem && j < done && stream[j] === curItem) cls += ' same';
                return `<div class="${cls}" title="第 ${j + 1} 筆：${esc(stream[j])}"><span class="emo">${EMOJI[stream[j]] || '?'}</span><span class="idx">${j + 1}</span></div>`;
            };
            let h = '';
            if (group === 'lc') {
                const w = s.w;
                for (let b = 0; b * w < stream.length; b++) {
                    let cls = 'bucket';
                    if (s.kind === 'l-prune' && b + 1 === s.b) cls += ' ended';
                    else if (s.b !== undefined && b + 1 === s.b) cls += ' cur';
                    let cells = '';
                    for (let j = b * w; j < Math.min(stream.length, (b + 1) * w); j++) cells += cell(j);
                    h += `<div class="${cls}"><span class="blab">第 ${b + 1} 桶</span>${cells}</div>`;
                }
            } else {
                h = `<div class="bucket plain">${stream.map((_, j) => cell(j)).join('')}</div>`;
            }
            inner.innerHTML = h;
            // 只捲輸送帶本身，讓正在處理的那一筆留在中間
            const belt = $(group + '-belt');
            const target = cur >= 0 ? inner.querySelectorAll('.cell')[cur] : null;
            if (target && belt.clientWidth) {
                const br = belt.getBoundingClientRect(), tr = target.getBoundingClientRect();
                belt.scrollTo({ left: Math.max(0, belt.scrollLeft + tr.left - br.left - belt.clientWidth / 2 + tr.width / 2), behavior: 'smooth' });
            } else if (belt.clientWidth) belt.scrollTo({ left: 0 });
            $(group + '-count').textContent = `共 ${stream.length} 筆`;
        }

        function renderTools(group) {
            $(group + '-tools').innerHTML =
                `<div class="picks"><span class="lab">加一筆到尾端：</span>` +
                ITEMS.map(x => `<button class="pick${RARE.has(x) ? ' rare' : ''}" data-item="${esc(x)}">${it(x)}</button>`).join('') + `</div>` +
                `<div class="len"><span class="lab">長度</span><button class="btn stepper" data-act="shorter" aria-label="短一點">−</button>` +
                `<span class="val">${stream.length}</span><button class="btn stepper" data-act="longer" aria-label="長一點">+</button></div>` +
                `<button class="btn small" data-act="random">🎲 隨機串流</button><button class="btn small" data-act="reset">恢復範例</button>`;
            const box = $(group + '-tools');
            box.querySelector('[data-act=shorter]').disabled = stream.length <= MIN_LEN;
            box.querySelector('[data-act=longer]').disabled = stream.length >= MAX_LEN;
            box.querySelectorAll('.pick').forEach(b => { b.disabled = stream.length >= MAX_LEN; });
        }

        /* 隨機串流：少數商品很熱門、大部分很冷門（大約是 Zipf 分布） */
        function drawItem() {
            const wts = hotOrder.map((_, r) => 1 / Math.pow(r + 1, 1.15));
            let x = Math.random() * wts.reduce((a, b) => a + b, 0);
            for (let r = 0; r < wts.length; r++) { x -= wts[r]; if (x <= 0) return hotOrder[r]; }
            return hotOrder[hotOrder.length - 1];
        }
        function randomStream(len) {
            hotOrder = ITEMS.slice().sort(() => Math.random() - 0.5);
            return Array.from({ length: len }, drawItem);
        }

        /* =================== 計數器表 =================== */
        function renderRows(group, s) {
            const truth = new Map(s.truth);
            const lc = group === 'lc';
            let rows;
            if (lc) rows = s.table.map(([x, f, d]) => ({ x, est: f, extra: d, lo: f, hi: f + d }));
            else rows = s.slots.map(([x, c, e], j) => ({ x, est: c, extra: e, lo: c - e, hi: c, slot: j }));
            const gone = lc && s.kind === 'l-prune' ? s.removed.map(([x, f, d]) => ({ x, est: f, extra: d, lo: f, hi: f + d, gone: true })) : [];
            const all = rows.concat(gone);
            const scale = Math.max(1, ...all.map(r => r.hi), ...all.map(r => truth.get(r.x) || 0));
            const ending = s.kind.endsWith('end');
            const repSet = ending ? new Set(s.report.map(r => r[0])) : null;
            const head = `<div class="row head"><span>${lc ? '商品' : '格・商品'}</span><span>${lc ? 'f' : '次數'}</span><span>${lc ? 'Δ' : '誤差'}</span><span>真實</span><span>範圍</span></div>`;
            const line = r => {
                const t = truth.get(r.x) || 0;
                let cls = 'row';
                if (r.gone) cls += ' gone';
                else if (s.item === r.x) cls += (s.kind === 'l-new' || s.kind === 's-new' || s.kind === 's-replace') ? ' new' : ' cur';
                if (repSet && repSet.has(r.x)) cls += ' rep' + (t < s.sN - TOL ? ' fp' : '');
                const pct = v => (v / scale * 100).toFixed(2) + '%';
                const bad = t < r.lo || t > r.hi;
                return `<div class="${cls}"><span class="it">${r.slot !== undefined ? `<span class="sl">#${r.slot + 1}</span>` : ''}${it(r.x)}</span>` +
                    `<span class="n est">${r.est}</span><span class="n${r.extra ? '' : ' dim'}">${r.extra}</span><span class="n${t !== r.est ? ' off' : ''}">${t}</span>` +
                    `<span class="rbar"><span class="solid" style="width:${pct(r.lo)}"></span><span class="range" style="left:${pct(r.lo)};width:${pct(r.hi - r.lo)}"></span>` +
                    `<span class="truth${bad ? ' out' : ''}" style="left:${pct(t)}"></span></span></div>`;
            };
            let h = head + (all.length ? all.map(line).join('') : `<div class="empty">${lc ? '表是空的。' : `${s.k} 格都還空著。`}</div>`);
            if (!lc && s.slots.length < s.k && s.slots.length) h += `<div class="empty">還有 ${s.k - s.slots.length} 格空著。</div>`;
            $(group + '-rows').innerHTML = h;
            // 出現過、但沒在記的商品
            const kept = new Set(all.map(r => r.x));
            const forgot = [...truth].filter(([x]) => !kept.has(x));
            $(group + '-forgot').innerHTML = forgot.length
                ? `<span>${lc ? '被忘掉的' : '沒在記的'}：</span>` + forgot.map(([x, t]) => `<span class="chip">${it(x)} 真實 <b>${t}</b></span>`).join('')
                : `<span>${s.n ? '出現過的商品全都在記。' : ''}</span>`;
        }

        /* =================== 統計與誤差保證 =================== */
        function renderStats(group, s) {
            const truth = new Map(s.truth);
            const N = s.n;
            $(group + '-st-n').textContent = N;
            $(group + '-st-exact').textContent = truth.size;
            let limit, worst, guar;
            if (group === 'lc') {
                const f = new Map(s.table.map(([x, ff]) => [x, ff]));
                worst = 0;
                truth.forEach((t, x) => { worst = Math.max(worst, t - (f.get(x) || 0)); });
                limit = eps() * N;
                $('lc-st-mem').innerHTML = `${s.table.length}<small> / 最多 ${s.maxMem}</small>`;
                guar = N ? `每個商品：<b>f ≤ 真實 ≤ f + Δ</b>，沒在表裡的當作 f = 0。目前最多少算 ${worst} 次 ≤ εN = ${num(limit)} <span class="ok">✓</span>` : '還沒有資料。';
            } else {
                worst = 0;
                s.slots.forEach(([x, c]) => { worst = Math.max(worst, c - (truth.get(x) || 0)); });
                limit = s.k ? N / s.k : 0;
                $('ss-st-mem').innerHTML = `${s.slots.length}<small> / ${s.k}</small>`;
                const minC = s.slots.length === s.k ? Math.min(...s.slots.map(x => x[1])) : 0;
                guar = N ? `每一格：<b>次數 − 誤差 ≤ 真實 ≤ 次數</b>。目前最多多算 ${worst} 次 ≤ N/k = ${num(limit)} <span class="ok">✓</span>` +
                    (s.slots.length === s.k ? `；沒在記的商品真實次數都 ≤ 最小那格的 ${minC}。` : '。') : '還沒有資料。';
            }
            const scale = Math.max(1, limit, worst);
            $(group + '-bar-lim').style.width = (limit / scale * 100) + '%';
            $(group + '-bar-err').style.width = (worst / scale * 100) + '%';
            $(group + '-bar-lim-n').textContent = num(limit);
            $(group + '-bar-err-n').textContent = worst;
            $(group + '-guar').innerHTML = guar;
        }

        /* =================== 程式碼 =================== */
        const KW = {
            java: new Set('public static final for if return new boolean int void class import while else null this double continue'.split(' ')),
            py: new Set('def for in if return not and or while import from as True False None class is lambda continue del'.split(' '))
        };
        function highlight(line) {
            const at = lang === 'java' ? line.indexOf('//') : line.indexOf('#');
            let body = line, comment = '';
            if (at >= 0) { body = line.slice(0, at); comment = line.slice(at); }
            if (lang === 'py' && /^\s*"""/.test(line)) { body = ''; comment = line; }
            if (lang === 'java' && /^\s*\/\*\*/.test(line)) { body = ''; comment = line; }
            const out = body.replace(/("(?:[^"\\]|\\.)*")|(\b\d+(?:\.\d+)?(?:e-?\d+)?\b)|([A-Za-z_]\w*)(\s*\()?|([^"\w]+)/g, (m, str, numb, word, call) => {
                if (str) return `<span class="str">${esc(str)}</span>`;
                if (numb) return `<span class="num">${numb}</span>`;
                if (word) {
                    if (KW[lang].has(word)) return `<span class="kw">${word}</span>${call ? esc(call) : ''}`;
                    if (call) return `<span class="fn">${word}</span>${esc(call)}`;
                    if (lang === 'java' && /^[A-Z]/.test(word) && !/^[A-Z_]+$/.test(word)) return `<span class="ty">${word}</span>`;
                    return word;
                }
                return esc(m);
            });
            return out + (comment ? `<span class="cm">${esc(comment)}</span>` : '');
        }

        const FILES = {
            lc: { java: ['LossyCounting.java', 'javac LossyCounting.java && java LossyCounting'], py: ['lossy_counting.py', 'python3 lossy_counting.py'] },
            ss: { java: ['SpaceSaving.java', 'javac SpaceSaving.java && java SpaceSaving'], py: ['space_saving.py', 'python3 space_saving.py'] }
        };
        function renderCode(group, tags) {
            if (measuringBlocks || restoringBlocks) return;   // 量區塊高度時不用畫程式碼（程式碼框高度不會變），量完畫回來時它也沒被動過，省時間
            const pre = $(group + '-code');
            pre.innerHTML = CODE[group][lang].map(([text, t], i) =>
                `<span class="ln${t.some(x => tags.includes(x)) ? ' hl' : ''}" data-n="${i + 1}">${highlight(text) || ' '}</span>`).join('');
            // 只捲程式碼框本身，不捲整個頁面
            const hls = [...pre.querySelectorAll('.ln.hl')];
            if (hls.length && pre.clientHeight) {
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
            const [file, cmd] = FILES[group][lang];
            $(group + '-downloads').innerHTML = `下載 <a href="code/${file}" download>${file}</a>　執行 <code>${cmd}</code>`;
        }

        /* =================== 顯示某一步 =================== */
        const stepsOf = group => (group === 'lc' ? lcSteps : ssSteps);
        const describe = (group, s) => (group === 'lc' ? lcDescribe(s) : ssDescribe(s));
        function show(group) {
            const steps = stepsOf(group);
            const c = cursors[group];
            const s = steps[c];
            $(group + '-explain').innerHTML = `<span class="step-no">步驟 ${c + 1} / ${steps.length}</span>${describe(group, s)}`;
            renderBelt(group, s);
            renderRows(group, s);
            renderStats(group, s);
            renderCode(group, (group === 'lc' ? LC_TAGS : SS_TAGS)[s.kind] || []);
            $(group + '-prev').disabled = $(group + '-first').disabled = c === 0;
            $(group + '-next').disabled = $(group + '-last').disabled = c === steps.length - 1;
            if (group === 'lc') {
                $('eps-val').textContent = eps();
                $('w-unit').textContent = `桶寬 w = ${Math.ceil(1 / eps())}`;
                $('lcs-val').textContent = lcS();
                $('eps-minus').disabled = epsIdx === 0;
                $('eps-plus').disabled = epsIdx === EPS_OPTS.length - 1;
                $('lcs-minus').disabled = lcSIdx === 0 || S_OPTS[lcSIdx - 1] <= eps() + TOL;
                $('lcs-plus').disabled = lcSIdx === S_OPTS.length - 1;
            } else {
                $('k-val').textContent = ssK;
                $('sss-val').textContent = ssS();
                $('k-minus').disabled = ssK <= 1;
                $('k-plus').disabled = ssK >= ITEMS.length;
                $('sss-minus').disabled = ssSIdx === 0;
                $('sss-plus').disabled = ssSIdx === S_OPTS.length - 1;
            }
        }
        function showActive() { show(activeTab); }

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

        /* 說明框用最長那段文字的高度固定住，下面的東西才不會跳來跳去 */
        function reserveExplainHeight(group) {
            quizReserve(group);   // 練習模式的題目框也要先預留高度，再量各區塊
            const box = $(group + '-explain');
            if (!box.offsetWidth) return;
            const probe = box.cloneNode(false);
            probe.removeAttribute('id');
            probe.style.cssText = `position:absolute;visibility:hidden;left:-9999px;min-height:0;width:${box.offsetWidth}px`;
            document.body.appendChild(probe);
            let tallest = 0;
            const steps = stepsOf(group);
            steps.forEach((s, i) => {
                probe.innerHTML = `<span class="step-no">步驟 ${i + 1} / ${steps.length}</span>${describe(group, s)}`;
                tallest = Math.max(tallest, probe.offsetHeight);
            });
            probe.remove();
            box.style.minHeight = tallest + 'px';
            reserveBlockHeights($('panel-' + group), stepsOf(group).length, i => { cursors[group] = i; show(group); }, () => cursors[group]);
        }

        /* =================== 資料或參數改變：重算 trace =================== */
        function rebuild() {
            lcSteps = lossyTrace(stream, eps(), lcS());
            ssSteps = ssTrace(stream, ssK, ssS());
        }
        // 參數變了：盡量停在同一筆（同一個 N），結果頁就留在結果頁
        function cursorAtN(steps, n, atEnd) {
            if (atEnd) return steps.length - 1;
            if (n <= 0) return 0;
            const j = steps.findIndex(s => s.n === n && s.i !== undefined);
            return j < 0 ? steps.length - 1 : j;
        }
        function paramChanged(group) {
            stopAuto(group);
            const old = stepsOf(group)[cursors[group]];
            const atEnd = cursors[group] === stepsOf(group).length - 1;
            rebuild();
            cursors[group] = cursorAtN(stepsOf(group), old.n, atEnd);
            show(group);
            reserveExplainHeight(group);
        }
        function streamChanged(how, from) {
            stopAuto('lc'); stopAuto('ss');
            const oldN = { lc: stepsOf('lc')[cursors.lc].n, ss: stepsOf('ss')[cursors.ss].n };
            rebuild();
            ['lc', 'ss'].forEach(g => {
                if (how === 'append' && g === from) cursors[g] = cursorAtN(stepsOf(g), stream.length, false);
                else if (how === 'length') cursors[g] = cursorAtN(stepsOf(g), Math.min(oldN[g], stream.length), false);
                else cursors[g] = 0;
            });
            renderTools('lc'); renderTools('ss');
            showActive();
            reserveExplainHeight(activeTab);
        }
        ['lc', 'ss'].forEach(group => {
            $(group + '-tools').addEventListener('click', e => {
                const pick = e.target.closest('[data-item]');
                if (pick) {
                    if (stream.length >= MAX_LEN) return;
                    stream.push(pick.dataset.item);
                    streamChanged('append', group);
                    setHint(group, `加了一筆 ${pick.dataset.item}，現在共 ${stream.length} 筆，直接跳到它進來的那一步。`);
                    return;
                }
                const act = e.target.closest('[data-act]');
                if (!act) return;
                const a = act.dataset.act;
                if (a === 'random') { stream = randomStream(stream.length < 20 ? 30 : stream.length); streamChanged('random'); setHint(group, `隨機產生 ${stream.length} 筆：這次最熱門的是 ${hotOrder[0]}、${hotOrder[1]}。`); }
                if (a === 'reset') { stream = DEFAULT_STREAM.slice(); hotOrder = ITEMS.slice(); streamChanged('reset'); setHint(group, '恢復成範例串流（30 筆）。'); }
                if (a === 'shorter') { stream = stream.slice(0, Math.max(MIN_LEN, Math.ceil(stream.length / 5) * 5 - 5)); streamChanged('length'); setHint(group, `剪掉尾巴，剩 ${stream.length} 筆。`); }
                if (a === 'longer') {
                    const len = Math.min(MAX_LEN, Math.floor(stream.length / 5) * 5 + 5);
                    while (stream.length < len) stream.push(drawItem());
                    streamChanged('length');
                    setHint(group, `在尾端隨機多加幾筆，現在 ${stream.length} 筆。`);
                }
            });
        });
        function setHint(group, text, warn) {
            ['lc', 'ss'].forEach(g => {
                const el = $(g + '-hint');
                el.textContent = g === group ? text : '';
                el.classList.toggle('warn', !!warn);
            });
        }

        /* =================== 播放控制 =================== */
        /* =========================================================
           練習模式「猜下一步」（各 Demo 共用，規格見 tools/research/BRIEF.md）
           打開後按「下一步」：如果下一步有題目（quizFor 不是 null），先在說明框的位置疊一層題目，
           答完立刻顯示對錯和一句解釋，按「繼續」才真的前進。題目都從 trace 算出來，資料或門檻改了照樣能出題。
           ========================================================= */
        // 兩個分頁各自一份：開關、記分、出過的題目都分開
        const QZS = Object.fromEntries(['lc', 'ss'].map(g => [g, { on: false, q: null, at: -1, picked: new Set(), answered: false, done: new Set(), right: 0, total: 0, trace: null }]));

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
        function quizOpen(g, q, at) {
            const QZ = QZS[g];
            Object.assign(QZ, { q, at, picked: new Set(), answered: false });
            const box = $(g + '-quiz');
            box.classList.remove('done', 'miss', 'nudge');
            quizRender(box, q);
            box.hidden = false;
        }
        function quizClose(g) {
            const QZ = QZS[g];
            QZ.q = null;
            QZ.at = -1;
            $(g + '-quiz').hidden = true;
        }
        function quizAnswer(g) {
            const QZ = QZS[g];
            const q = QZ.q, want = new Set(q.multi ? q.answer : [q.answer]);
            const ok = want.size === QZ.picked.size && [...want].every(k => QZ.picked.has(k));
            QZ.answered = true;
            QZ.done.add(QZ.at);
            QZ.total++;
            if (ok) QZ.right++;
            const box = $(g + '-quiz');
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
            quizScore(g);
        }
        function quizScore(g) {
            const QZ = QZS[g];
            $(g + '-quiz-score').textContent = `答對 ${QZ.right}/${QZ.total}`;
            $(g + '-quiz-score').style.visibility = QZ.on ? 'visible' : 'hidden';
            $(g + '-quiz-toggle').classList.toggle('quiz-on', QZ.on);
            $(g + '-quiz-toggle').setAttribute('aria-pressed', String(QZ.on));
        }

        /* 接在 step(dir) 最前面：回傳 true 表示「先別前進，題目還沒答」 */
        function quizGate(g, dir) {
            const QZ = QZS[g], trace = stepsOf(g), cursor = cursors[g];
            if (dir < 0 || !QZ.on) { quizClose(g); return false; }
            if (QZ.q) {
                if (QZ.answered || QZ.at !== cursor + 1) { quizClose(g); return false; }
                const box = $(g + '-quiz');
                box.classList.remove('nudge');
                void box.offsetWidth;          // 重新觸發動畫
                box.classList.add('nudge');
                return true;
            }
            const at = cursor + 1;
            if (at >= trace.length || QZ.done.has(at)) return false;
            const q = quizFor(g, trace[at], at);
            if (!q) return false;
            quizOpen(g, q, at);
            return true;
        }

        /* 題目框的高度：把這一輪每一題都畫一次，用最高的那題固定（關掉練習模式時也一樣預留，開關才不會推動下面） */
        function quizReserve(g) {
            const QZ = QZS[g], trace = stepsOf(g);
            if (QZ.trace !== trace) { QZ.trace = trace; QZ.done.clear(); quizClose(g); }   // 資料或門檻改了，重新出題
            const host = $(g + '-quiz-host');
            if (!host.offsetWidth) return;
            const probe = document.createElement('div');
            probe.className = 'quiz done';
            probe.style.cssText = `position:absolute;visibility:hidden;left:-9999px;top:0;right:auto;bottom:auto;width:${host.offsetWidth}px`;
            document.body.appendChild(probe);
            let tallest = 0;
            trace.forEach((s, i) => {
                const q = quizFor(g, s, i);
                if (!q) return;
                quizRender(probe, q);
                tallest = Math.max(tallest, probe.offsetHeight);
            });
            probe.remove();
            host.style.minHeight = tallest ? tallest + 'px' : '';
        }

        ['lc', 'ss'].forEach(g => {
            const QZ = QZS[g];
            $(g + '-quiz').addEventListener('click', e => {
                const q = QZ.q;
                if (!q) return;
                const c = e.target.closest('.quiz-choice');
                if (c && !QZ.answered) {
                    const k = Number(c.dataset.k);
                    if (!q.multi) { QZ.picked = new Set([k]); quizAnswer(g); return; }
                    if (QZ.picked.has(k)) QZ.picked.delete(k); else QZ.picked.add(k);
                    c.classList.toggle('sel', QZ.picked.has(k));
                    return;
                }
                if (e.target.closest('.quiz-ok') && !QZ.answered) { quizAnswer(g); return; }
                if (e.target.closest('.quiz-go')) {
                    if (!QZ.answered) QZ.done.add(QZ.at);   // 跳過：不計分，也不再問
                    quizClose(g);
                    $(g + '-next').click();
                }
            });
            $(g + '-quiz-toggle').addEventListener('click', () => {
                QZ.on = !QZ.on;
                if (!QZ.on) quizClose(g);
                quizScore(g);
            });
            $(g + '-first').addEventListener('click', () => quizClose(g));
            $(g + '-last').addEventListener('click', () => quizClose(g));
        });

        /* 第 i 步（s = stepsOf(g)[i]）要出的題目：{ q, choices, answer, why, multi?, ask? } 或 null（ask 只給 quiz_test.py 對答案用） */
        function quizFor(g, s, i) {
            const rnd = quizRng(i + 1);
            const truth = new Map(s.truth);
            switch (s.kind) {
                case 'l-new': {
                    if (s.b === 1) return null;            // 第 1 桶的新商品 Δ 一定是 0，不問
                    return {
                        q: `第 ${s.n} 筆（第 ${s.b} 桶）：${s.item} 不在表裡，新增一列 f = 1。它的 Δ 是多少？`,
                        ...quizNums(s.b - 1, 0, s.b + 2, rnd, [0, s.b, s.seenBefore]),
                        why: `Δ = b − 1 = ${s.b - 1}：它可能在前 ${s.b - 1} 桶出現過、被大掃除忘掉，最多漏算 ${s.b - 1} 次` +
                            (s.seenBefore ? `（真的漏了 ${s.seenBefore} 次，沒超過）。` : `（其實它是第一次出現，但演算法分不出來）。`),
                        ask: { type: 'delta', n: s.n, item: s.item }
                    };
                }
                case 'l-prune': {
                    const all = [...s.removed.map(r => [...r, true]), ...s.table.map(r => [...r, false])];
                    const pick = quizShuffle(all, rnd).slice(0, 4);
                    if (!pick.length) return null;
                    const mq = {
                        q: `第 ${s.b} 桶結束（N = ${s.n}），大掃除：哪些商品會被刪掉？`,
                        choices: pick.map(([x, f, d]) => `${x} f=${f} Δ=${d}`),
                        answer: pick.map((r, k) => r[3] ? k : -1).filter(k => k >= 0), multi: true,
                        why: `規則是 f + Δ ≤ b = ${s.b} 就刪：` + pick.map(([x, f, d, gone]) => `${x} ${f}+${d}=${f + d}${gone ? '，刪' : '，留'}`).join('；') + '。',
                        ask: { type: 'prune', n: s.n, items: pick.map(r => r[0]) }
                    };
                    return pick.length === 1 ? quizSingle(mq, `第 ${s.b} 桶結束，${mq.choices[0]} 會被刪掉嗎？`) : mq;
                }
                case 'l-end': {
                    const sNc = s.table.filter(([, f]) => f >= s.sN - TOL).length;
                    return {
                        q: `串流結束，N = ${s.n}、s = ${lcS()}、ε = ${eps()}。表裡會回報幾個商品（f ≥ (s − ε)N = ${num(s.limit)}）？`,
                        ...quizNums(s.report.length, 0, Math.max(3, s.table.length), rnd, [sNc, s.table.length]),
                        why: `門檻放寬成 (s − ε)N = ${num(s.limit)}（不是 sN = ${num(s.sN)}），f 夠大的有 ${s.report.length} 個；放寬是為了真的頻繁的一個都不漏。`,
                        ask: { type: 'lcReport', eps: eps(), s: lcS() }
                    };
                }
                case 's-replace': {
                    const [vx, c] = s.victim;
                    const before = s.slots.map((x, k) => k === s.slot ? s.victim : x);
                    if (s.n % 2 && s.k > 1) {          // 輪流問「搶哪一格」和「接手後幾次」
                        const others = quizShuffle(before.map((x, k) => [x, k]).filter(([, k]) => k !== s.slot), rnd).slice(0, 3);
                        return {
                            q: `第 ${s.n} 筆 ${s.item} 沒在記，${s.k} 格都滿了。它會搶走哪一格？（一樣小取最前面）`,
                            ...quizOptions([[s.victim, s.slot], ...others].map(([x, k]) => ({ text: `第 ${k + 1} 格 ${x[0]}（${x[1]}）` })), rnd),
                            why: `搶次數最小的那格：第 ${s.slot + 1} 格 ${vx} 只有 ${c} 次${s.ties > 1 ? `（有 ${s.ties} 格一樣小，取最前面）` : ''}。`,
                            ask: { type: 'victim', n: s.n }
                        };
                    }
                    const t = truth.get(s.item);
                    return {
                        q: `第 ${s.n} 筆 ${s.item} 搶走了 ${vx} 那格（${vx} 原本 ${c} 次）。${s.item} 接手後的次數是多少？`,
                        ...quizNums(c + 1, 1, s.n, rnd, [1, c, t]),
                        why: `繼承原本的 ${c} 次再 +1 = ${c + 1}，誤差記 ${c}；它真實出現 ${t} 次，所以只會多算、不會少算。`,
                        ask: { type: 'ssCount', n: s.n, slot: s.slot }
                    };
                }
                case 's-end': {
                    const sure = s.report.filter(([, c, e]) => c - e >= s.sN - TOL).length;
                    return {
                        q: `串流結束，N = ${s.n}、s = ${ssS()}。會回報幾格（次數 ≥ sN = ${num(s.sN)}）？`,
                        ...quizNums(s.report.length, 0, Math.max(3, s.slots.length), rnd, [sure, s.slots.length]),
                        why: `次數 ≥ ${num(s.sN)} 的有 ${s.report.length} 格；其中「次數 − 誤差」也夠的 ${sure} 個是保證真的頻繁。`,
                        ask: { type: 'ssReport', s: ssS() }
                    };
                }
            }
            return null;
        }

        function go(group, dir) {
            if (quizGate(group, dir)) return false;
            const next = cursors[group] + dir;
            if (next < 0 || next >= stepsOf(group).length) return false;
            cursors[group] = next;
            show(group);
            return cursors[group] < stepsOf(group).length - 1;
        }
        function stopAuto(group) {
            clearInterval(timers[group]);
            timers[group] = null;
            $(group + '-play').textContent = '▶ 自動播放';
        }
        ['lc', 'ss'].forEach(group => {
            $(group + '-next').addEventListener('click', () => { stopAuto(group); go(group, 1); });
            $(group + '-prev').addEventListener('click', () => { stopAuto(group); go(group, -1); });
            $(group + '-first').addEventListener('click', () => { stopAuto(group); cursors[group] = 0; show(group); });
            $(group + '-last').addEventListener('click', () => { stopAuto(group); cursors[group] = stepsOf(group).length - 1; show(group); });
            $(group + '-play').addEventListener('click', () => {
                if (timers[group]) { stopAuto(group); return; }
                if (cursors[group] === stepsOf(group).length - 1) { cursors[group] = 0; show(group); }
                $(group + '-play').textContent = '⏸ 暫停';
                timers[group] = setInterval(() => { if (!go(group, 1)) stopAuto(group); }, 1300);
            });
        });
        document.addEventListener('keydown', e => {
            if (e.target.closest && e.target.closest('input, textarea, select')) return;
            if (e.key === 'ArrowRight') { stopAuto(activeTab); go(activeTab, 1); }
            if (e.key === 'ArrowLeft') { stopAuto(activeTab); go(activeTab, -1); }
        });

        $('eps-minus').addEventListener('click', () => { if (epsIdx > 0) { epsIdx--; paramChanged('lc'); } });
        $('eps-plus').addEventListener('click', () => {
            if (epsIdx >= EPS_OPTS.length - 1) return;
            epsIdx++;
            while (lcSIdx < S_OPTS.length - 1 && S_OPTS[lcSIdx] <= eps() + TOL) lcSIdx++;   // s 一定要比 ε 大
            paramChanged('lc');
        });
        $('lcs-minus').addEventListener('click', () => { if (lcSIdx > 0 && S_OPTS[lcSIdx - 1] > eps() + TOL) { lcSIdx--; paramChanged('lc'); } });
        $('lcs-plus').addEventListener('click', () => { if (lcSIdx < S_OPTS.length - 1) { lcSIdx++; paramChanged('lc'); } });
        $('k-minus').addEventListener('click', () => { if (ssK > 1) { ssK--; paramChanged('ss'); } });
        $('k-plus').addEventListener('click', () => { if (ssK < ITEMS.length) { ssK++; paramChanged('ss'); } });
        $('sss-minus').addEventListener('click', () => { if (ssSIdx > 0) { ssSIdx--; paramChanged('ss'); } });
        $('sss-plus').addEventListener('click', () => { if (ssSIdx < S_OPTS.length - 1) { ssSIdx++; paramChanged('ss'); } });

        document.querySelectorAll('.lang').forEach(box => box.addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b) return;
            lang = b.dataset.lang;
            document.querySelectorAll('.lang button').forEach(x => x.classList.toggle('active', x.dataset.lang === lang));
            showActive();
        }));

        function switchTab(tab) {
            if (tab === activeTab) return;
            stopAuto(activeTab);
            activeTab = tab;
            document.querySelectorAll('.tabs button').forEach(b => {
                const on = b.dataset.tab === tab;
                b.classList.toggle('active', on);
                b.setAttribute('aria-selected', on);
            });
            $('panel-lc').hidden = tab !== 'lc';
            $('panel-ss').hidden = tab !== 'ss';
            history.replaceState(null, '', tab === 'ss' ? '#space-saving' : '#lossy-counting');
            showActive();
            reserveExplainHeight(tab);
        }
        document.querySelector('.tabs').addEventListener('click', e => {
            const b = e.target.closest('button[data-tab]');
            if (b) switchTab(b.dataset.tab);
        });

        let resizeTimer = null;
        window.addEventListener('resize', () => {
            clearTimeout(resizeTimer);
            resizeTimer = setTimeout(() => { showActive(); reserveExplainHeight(activeTab); }, 150);
        });

        rebuild();
        renderTools('lc'); renderTools('ss');
        if (location.hash === '#space-saving') switchTab('ss');
        showActive();
        reserveExplainHeight(activeTab);
    </script>
</body>

</html>
