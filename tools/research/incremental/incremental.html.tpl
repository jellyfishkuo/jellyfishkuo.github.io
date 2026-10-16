<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/incremental.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/incremental-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/incremental-180.png">
    <title>增量探勘 FUP</title>
    <meta name="description" content="資料庫一直新增交易時，FUP 怎麼只讀新的那幾筆就更新頻繁樣式：舊樣式只加新次數、新候選先用引理篩掉，必要時才回頭掃舊資料庫。和全部重算比較讀了幾筆交易，Java 與 Python 程式碼逐行對照。">
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
        .intro { color: #c6c6d6; max-width: 780px; margin-top: 0.9rem; font-size: 0.95rem; }
        .intro b { color: var(--text); }
        .intro a { color: var(--accent2); }

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
        button.btn.small { padding: 0.25rem 0.55rem; font-size: 0.8rem; }

        /* ── 資料庫（矩陣） ── */
        .minsup { display: flex; align-items: center; gap: 0.45rem; flex-wrap: wrap; font-size: 0.9rem; }
        .minsup .val { font: 700 1rem 'Space Mono', monospace; min-width: 2.6em; text-align: center; }
        .minsup .pct { color: var(--muted); font-size: 0.8rem; }
        .stepper { width: 30px; height: 30px; padding: 0 !important; }

        .db-scroll { max-height: 620px; overflow-y: auto; overscroll-behavior: contain; margin: 0 -0.2rem; padding: 0 0.2rem; }
        .db { width: 100%; table-layout: fixed; border-collapse: separate; border-spacing: 0 3px; }
        /* 欄寬固定：商品欄平分，不會因為「茶葉蛋」「洋芋片」三個字就比較寬 */
        .db th.tid-h { width: 2.3rem; }
        .db th.del-h { width: 30px; }
        .db th { font-weight: 400; color: var(--muted); font-size: clamp(0.6rem, 3vw, 0.75rem); white-space: nowrap; padding: 0 1px 4px; text-align: center; line-height: 1.25; position: sticky; top: 0; background: var(--panel); z-index: 1; }
        .db th .emo { display: block; font-size: 1.25rem; }
        .db th.sel { color: var(--warn); }
        .db td { text-align: center; padding: 0; }
        .db td.tid { font: 0.78rem 'Space Mono', monospace; color: var(--muted); text-align: left; width: 2.8em; padding-left: 0.3rem; }
        .db tr.pend td.tid { color: var(--newc); }
        .db tr.match td { background: rgba(245, 158, 11, 0.12); }
        .db tr.match td:first-child { border-radius: 8px 0 0 8px; color: var(--warn); }
        .db tr.match td:last-child { border-radius: 0 8px 8px 0; }
        .db tr.sep td { font-size: 0.76rem; color: var(--newc); text-align: left; padding: 0.35rem 0.3rem 0.1rem; border-top: 1px dashed rgba(192, 132, 252, 0.45); }
        .db tr.sep.none td { color: var(--muted); border-top-color: var(--border); }
        .cell {
            width: 30px;
            height: 30px;
            margin: 0 auto;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .cell.has { background: #2a2a48; }
        .cell.has::after { content: ''; width: 11px; height: 11px; border-radius: 50%; background: var(--accent2); }
        .cell.has.nw { background: rgba(192, 132, 252, 0.18); }
        .cell.has.nw::after { background: var(--newc); }
        .cell.hit { background: rgba(245, 158, 11, 0.35) !important; }
        .cell.hit::after { background: var(--warn) !important; }
        .db .del {
            background: none; border: none; color: var(--muted); cursor: pointer; font-size: 0.85rem;
            width: 26px; height: 26px; border-radius: 50%;
        }
        .db .del:hover { color: var(--bad); background: rgba(255, 255, 255, 0.05); }

        /* ── 組新交易 ── */
        .compose { margin-top: 0.8rem; display: grid; gap: 0.6rem; }
        .compose .lbl { font-size: 0.8rem; color: var(--muted); }
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
        .pick.on { color: var(--text); border-color: var(--newc); background: rgba(192, 132, 252, 0.16); }
        .presets { display: flex; flex-wrap: wrap; gap: 0.35rem; }
        .presets .btn.cur { border-color: var(--newc); color: var(--newc); }
        .row-actions { display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center; }
        .row-actions .grow { flex: 1; }
        .note { font-size: 0.76rem; color: var(--muted); }
        .locked { font-size: 0.85rem; color: #c6c6d6; }
        .locked b { color: var(--newc); }

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

        .cost { margin-top: 0.8rem; background: #0a0a14; border: 1px solid var(--border); border-radius: 10px; padding: 0.6rem 0.7rem; }
        .cost-head { display: flex; justify-content: space-between; flex-wrap: wrap; gap: 0.2rem 0.8rem; font-size: 0.8rem; color: var(--muted); margin-bottom: 0.45rem; }
        .cost-head .lg { display: flex; gap: 0.7rem; }
        .sw { display: inline-block; width: 10px; height: 10px; border-radius: 3px; margin-right: 0.3rem; vertical-align: -1px; }
        .sw.d1 { background: var(--newc); }
        .sw.d0 { background: var(--accent2); }
        .bar-row { display: grid; grid-template-columns: 4.6em 1fr 2.6em; gap: 0.5rem; align-items: center; margin-top: 0.3rem; font-size: 0.82rem; }
        .bar-row .who { color: #c6c6d6; white-space: nowrap; }
        .bar { height: 14px; background: #191930; border-radius: 4px; display: flex; overflow: hidden; }
        .seg { height: 100%; transition: width 0.35s; }
        .seg.d1 { background: var(--newc); }
        .seg.d0 { background: var(--accent2); }
        .bar-row .num { font: 700 0.9rem 'Space Mono', monospace; text-align: right; }
        .cost-note { font-size: 0.78rem; color: var(--muted); margin-top: 0.45rem; min-height: 2.5em; line-height: 1.55; }
        .cost-note b { color: var(--good); font-weight: 600; }

        .cands { display: flex; flex-wrap: wrap; gap: 0.4rem; margin-top: 0.8rem; min-height: 2.2rem; }
        .cand {
            display: inline-flex;
            align-items: center;
            gap: 0.35rem;
            border: 1px solid var(--border);
            background: var(--panel-2);
            border-radius: 8px;
            padding: 0.25rem 0.55rem;
            font-size: 0.84rem;
            cursor: pointer;
            color: var(--text);
            text-align: left;
            font-family: inherit;
            max-width: 100%;
            flex-wrap: wrap;
        }
        .cand:hover { border-color: var(--accent2); }
        .cand.sel { border-color: var(--warn); box-shadow: 0 0 0 1px var(--warn) inset; }
        .cand .tg { font-size: 0.7rem; padding: 0 0.3rem; border-radius: 4px; }
        .cand .tg.t-old { background: rgba(6, 182, 212, 0.18); color: #67e8f9; }
        .cand .tg.t-new { background: rgba(192, 132, 252, 0.2); color: #e9d5ff; }
        .cand .n { font: 700 0.76rem 'Space Mono', monospace; padding: 0 0.35rem; border-radius: 5px; background: #2a2a48; }
        .cand.new { border-style: dashed; border-color: rgba(192, 132, 252, 0.55); }
        .cand.ok { border-color: rgba(34, 197, 94, 0.55); border-style: solid; }
        .cand.ok .n { background: rgba(34, 197, 94, 0.25); color: #86efac; }
        .cand.out { opacity: 0.62; border-style: solid; }
        .cand.out .name { text-decoration: line-through; }
        .cand.out .n { background: rgba(248, 113, 113, 0.2); color: #fca5a5; }
        .cand .why { color: var(--muted); font-size: 0.74rem; }
        .cands-hint { color: var(--muted); font-size: 0.8rem; margin-top: 0.5rem; min-height: 1.3em; }

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
            max-height: 500px;
            font: 0.78rem/1.7 'Space Mono', ui-monospace, monospace;
            position: relative;
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
        .downloads code { font: 0.78rem 'Space Mono', monospace; background: var(--panel-2); padding: 0.1rem 0.4rem; border-radius: 4px; color: var(--text); overflow-wrap: anywhere; }

        /* ── L 的變化 ── */
        .levels { display: grid; gap: 0.5rem; }
        .level { display: grid; grid-template-columns: 2.4em 1fr; gap: 0.5rem; align-items: start; }
        .level .tag { font: 700 0.8rem 'Space Mono', monospace; color: var(--accent2); padding-top: 0.2rem; }
        .level .items { display: flex; flex-wrap: wrap; gap: 0.35rem; min-width: 0; }
        .pat { font-size: 0.82rem; border: 1px solid var(--border); border-radius: 7px; padding: 0.12rem 0.5rem; }
        .pat .n { font: 700 0.74rem 'Space Mono', monospace; margin-left: 0.35rem; }
        .pat.pending { border-style: dashed; color: var(--muted); }
        .pat.kept { border-color: rgba(34, 197, 94, 0.5); }
        .pat.kept .n { color: #86efac; }
        .pat.added { border-color: var(--warn); box-shadow: 0 0 0 1px var(--warn) inset; }
        .pat.added .n { color: var(--warn); }
        .pat.dropped, .pat.gone { border-color: rgba(248, 113, 113, 0.45); opacity: 0.7; }
        .pat.dropped .nm, .pat.gone .nm { text-decoration: line-through; }
        .pat.dropped .n, .pat.gone .n { color: #fca5a5; }
        .empty { color: var(--muted); font-size: 0.85rem; }
        .legend { display: flex; flex-wrap: wrap; gap: 0.3rem 0.9rem; font-size: 0.75rem; color: var(--muted); margin-top: 0.7rem; }
        .legend i { display: inline-block; width: 12px; height: 10px; border-radius: 3px; border: 1.5px solid; margin-right: 0.3rem; vertical-align: -1px; }
        .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.5rem; margin-top: 0.9rem; }
        .stat { background: var(--panel-2); border-radius: 10px; padding: 0.55rem 0.6rem; }
        .stat .v { font: 700 1.25rem 'Space Mono', monospace; }
        .stat .k { color: var(--muted); font-size: 0.75rem; line-height: 1.35; }
        .batches { margin-top: 0.8rem; font-size: 0.82rem; color: var(--muted); display: grid; gap: 0.15rem; }
        .batches b { color: var(--text); }

        .notes { margin-top: 1rem; display: grid; gap: 1rem; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr; } }
        .notes p, .notes li { color: #c6c6d6; font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; }
        .notes b { color: var(--text); }
        .notes a { color: var(--accent2); }
        .formula { font: 0.8rem/1.7 'Space Mono', monospace; background: #0a0a14; border: 1px solid var(--border); border-radius: 8px; padding: 0.5rem 0.7rem; margin: 0.5rem 0; color: var(--text); overflow-x: auto; white-space: nowrap; }
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
        <div class="kicker">RESEARCH DEMO · INCREMENTAL MINING</div>
        <h1>增量探勘：FUP<small>資料一直進來，頻繁樣式怎麼更新才不用全部重算</small></h1>
        <p class="intro">
            接續 <a href="apriori.html">Apriori</a> 那一頁：舊的資料庫 <b>DB</b> 已經挖好頻繁樣式 L（連次數都記著），今天又進來一批新交易 <b>db</b>。
            最直覺的做法是把 DB∪db 整個丟給 Apriori 重跑，但每一層都要把舊交易全部再讀一次。
            <b>FUP</b>（Fast UPdate，Cheung 等人 1996）只讀新的那幾筆就能更新舊樣式，新冒出來的候選也先用一個<b>引理</b>篩過，
            只有少數「真的有機會」的才回頭讀 DB。門檻用<b>百分比</b>，因為筆數一直在變。
        </p>

        <div class="layout">
            <div>
                <div class="card" id="db-card">
                    <div class="card-head">
                        <h2>資料庫 DB ＋ 新增的 db</h2>
                        <div class="minsup">
                            <span>門檻</span>
                            <button class="btn stepper" id="pct-minus" aria-label="降低門檻">−</button>
                            <span class="val" id="pct-val">30%</span>
                            <button class="btn stepper" id="pct-plus" aria-label="提高門檻">+</button>
                            <span class="pct" id="pct-note"></span>
                        </div>
                    </div>
                    <div class="db-scroll" id="db-scroll"><table class="db" id="db"></table></div>

                    <div class="compose" id="compose">
                        <div>
                            <div class="lbl">組一筆新交易（點商品勾選），再按「＋ 加入」</div>
                            <div class="picks" id="picks"></div>
                        </div>
                        <div>
                            <div class="lbl">或直接用一組預設批次<span class="note">（效果以範例資料、門檻 30% 為準）</span></div>
                            <div class="presets" id="presets"></div>
                        </div>
                        <div class="row-actions" id="edit-actions">
                            <button class="btn" id="btn-clear">清空待新增</button>
                            <button class="btn" id="btn-reset">↺ 恢復範例資料</button>
                            <span class="grow"></span>
                            <button class="btn primary" id="btn-update">更新 ▶</button>
                        </div>
                        <div class="row-actions" id="run-actions">
                            <span class="locked" id="locked-text"></span>
                            <span class="grow"></span>
                            <button class="btn small" id="btn-reset2">↺ 恢復範例</button>
                            <button class="btn small" id="btn-edit-batch">✎ 修改這一批</button>
                            <button class="btn small primary" id="btn-commit">✓ 併入 DB，加下一批</button>
                        </div>
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
                    <div class="cost">
                        <div class="cost-head">
                            <span>到這一步為止，讀了幾筆交易</span>
                            <span class="lg"><span><i class="sw d1"></i>新的 db</span><span><i class="sw d0"></i>舊的 DB</span></span>
                        </div>
                        <div class="bar-row"><span class="who">FUP</span><div class="bar"><span class="seg d1" id="bar-f1"></span><span class="seg d0" id="bar-f0"></span></div><span class="num" id="num-f">0</span></div>
                        <div class="bar-row"><span class="who">全部重算</span><div class="bar"><span class="seg d1" id="bar-r1"></span><span class="seg d0" id="bar-r0"></span></div><span class="num" id="num-r">0</span></div>
                        <div class="cost-note" id="cost-note"></div>
                    </div>
                    <div class="cands" id="cands"></div>
                    <div class="cands-hint" id="cands-hint"></div>
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
                    <pre class="code" id="code"></pre>
                    <div class="downloads" id="downloads"></div>
                </div>

                <div class="card">
                    <h2>L 的變化</h2>
                    <div class="levels" id="levels"></div>
                    <div class="legend">
                        <span><i style="border-color:rgba(34,197,94,.6)"></i>保留（舊次數→新次數）</span>
                        <span><i style="border-color:var(--warn)"></i>新加入</span>
                        <span><i style="border-color:rgba(248,113,113,.6)"></i>掉出</span>
                        <span><i style="border-color:var(--muted);border-style:dashed"></i>這層還沒處理</span>
                    </div>
                    <div class="stats">
                        <div class="stat"><div class="v" id="st-db">0</div><div class="k">掃 db 的次數</div></div>
                        <div class="stat"><div class="v" id="st-DB">0</div><div class="k">回頭掃 DB 的次數</div></div>
                        <div class="stat"><div class="v" id="st-cut">0</div><div class="k">被引理擋下、不用回頭數的新候選</div></div>
                    </div>
                    <div class="batches" id="batches"></div>
                </div>
            </div>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼可以只讀 db？</h2>
                <p>次數是可以<b>直接相加</b>的：一個樣式在 DB∪db 的次數 = 在 DB 的次數 ＋ 在 db 的次數。舊樣式在 DB 的次數 L 裡本來就記著，所以只要數 db 那一份。</p>
                <p style="margin-top:0.5rem">麻煩的是原本不在 L 的樣式，它在 DB 的次數沒有記下來。這時候靠 FUP 的<b>引理</b>：設門檻比例是 s，</p>
                <div class="formula">不在 L：count<sub>DB</sub>(X) &lt; s·|DB|<br>如果也 count<sub>db</sub>(X) &lt; s·|db|<br>⇒ count<sub>DB∪db</sub>(X) &lt; s·(|DB|+|db|)</div>
                <p>兩邊都不到，加起來一定不到。所以新候選只要在 db 裡不到門檻就能直接排除，<b>一筆舊交易都不用讀</b>；只有在 db 裡夠多的，才需要回頭掃 DB 把次數補齊。</p>
                <p style="margin-top:0.5rem">候選本身還是照 Apriori 用「剛更新好的 L(k−1)」產生，向下封閉性在 DB∪db 一樣成立，所以 FUP 的結果跟全部重算<b>完全相同</b>，不是近似。舊樣式如果有子集合掉出去，它根本不會被產生，等於連帶掉出、連 db 都不用數。</p>
            </div>
            <div class="card">
                <h2>省了多少？跟增量探勘研究的關係</h2>
                <ul>
                    <li><b>成本怎麼算：</b>全部重算每一層都讀 |DB|+|db| 筆；FUP 每一層只讀 |db| 筆，只有「有新候選通過引理」的那幾層才多讀 |DB|。新資料跟舊資料長得差不多時，大部分層都不用碰 DB，db 越小省越多。</li>
                    <li><b>最壞情況：</b>新的一批跟以前很不一樣（例如換季、新商品），很多新候選通過引理，就幾乎每層都要回頭掃 DB，省得不多；不過那時要數的候選也只有通過引理的那幾個。</li>
                    <li><b>FUP 只處理新增。</b>交易被刪掉或修改時要用 FUP2 這類方法；Hong 等人提出的 <b>pre-large</b>（預先大項目集）多記一層「差一點頻繁」的樣式，讓新資料不多時連回頭掃 DB 都能省掉。</li>
                    <li><b>實驗室常見的方向：</b>把同樣的想法搬到 <a href="fp-growth.html">FP-tree</a> 這類樹狀結構（例如 CanTree 用固定順序，插入新交易不用重排）、搬到高效益樣式探勘，或是處理資料流的滑動視窗，核心問題都一樣：<b>新資料進來時，哪些結果一定沒變、哪些需要回頭查</b>。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           增量探勘（FUP）一步一步看
           網頁裡用 JavaScript 照著同樣的流程跑一次，把每一步記下來，
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
        const PRESETS = [
            { label: '✨ 冒出新樣式', rows: [['咖啡', '茶葉蛋'], ['咖啡', '麵包', '牛奶'], ['咖啡', '牛奶', '茶葉蛋'], ['牛奶', '飯糰', '茶葉蛋']] },
            { label: '📉 舊樣式掉出去', rows: [['咖啡', '麵包'], ['咖啡', '麵包', '茶葉蛋'], ['牛奶', '飯糰'], ['麵包', '飯糰'], ['咖啡', '茶葉蛋'], ['麵包', '牛奶']] },
            { label: '😐 什麼都沒變', rows: [['咖啡', '茶葉蛋'], ['麵包', '牛奶'], ['咖啡', '麵包', '牛奶'], ['咖啡', '麵包', '飯糰']] }
        ];
        const MAX_BATCH = 8;      // 一批最多幾筆
        const MAX_DB = 60;        // 資料庫最多幾筆（畫面放得下）

        const $ = id => document.getElementById(id);
        let baseDB = [];          // 目前的 DB（每筆是一個 Set）
        let oldL = new Map();     // DB 的頻繁樣式：key → { set, count }
        let pending = [];         // 這一批要新增的 db
        let pct = 30;
        let phase = 'run';        // 'edit'：正在組這一批；'run'：已經按了更新，在看步驟
        let draft = new Set();    // 正在組的那一筆
        let presetUsed = -1;
        let batchLog = [];        // 已經併入的批次
        let lang = 'java';
        let trace = [];
        let cursor = 0;
        let selected = null;      // 要在表格上標出的組合
        let selChip = null;
        let timer = null;

        /* 跟 Java 的 compareTo、Python 的字串比較同一個順序（依字碼） */
        const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
        const cmpSet = (a, b) => {
            for (let i = 0; i < Math.min(a.length, b.length); i++) { const c = cmp(a[i], b[i]); if (c) return c; }
            return a.length - b.length;
        };
        const key = set => set.join('|');
        const fmt = set => '{' + set.join(', ') + '}';
        const list = sets => sets.map(fmt).join('、');
        /* n 筆交易、門檻 pct% 時，至少要出現幾次（跟程式一樣用整數無條件進位） */
        const need = n => Math.floor((n * pct + 99) / 100);
        const support = (rows, set) => rows.filter(t => set.every(x => t.has(x))).length;

        function countRows(rows, C) {
            const cnt = new Map(C.map(c => [key(c), 0]));
            rows.forEach(t => C.forEach(c => { if (c.every(x => t.has(x))) cnt.set(key(c), cnt.get(key(c)) + 1); }));
            return cnt;
        }
        const subsets = c => c.map((_, i) => c.filter((__, j) => j !== i));

        /* 合併前 k-2 個相同的兩個樣式，再剪掉有不頻繁子集合的（跟 Apriori 一樣） */
        function aprioriGen(L, k) {
            L = L.slice().sort(cmpSet);
            const frequent = new Set(L.map(key));
            const C = [];
            for (let i = 0; i < L.length; i++) {
                for (let j = i + 1; j < L.length; j++) {
                    const a = L[i], b = L[j];
                    if (key(a.slice(0, k - 2)) !== key(b.slice(0, k - 2))) continue;
                    const c = [...a, b[k - 2]];
                    if (subsets(c).every(s => frequent.has(key(s)))) C.push(c);
                }
            }
            return C;
        }
        const singleItems = rows => [...new Set(rows.flatMap(t => [...t]))].sort(cmp).map(i => [i]);

        /* 一般的 Apriori：算一開始的 L，也用來對答案、算「全部重算」要讀幾筆 */
        function apriori(rows) {
            const L = new Map();
            let reads = 0;
            let C = singleItems(rows);
            for (let k = 2; C.length; k++) {
                const cnt = countRows(rows, C);
                reads += rows.length;
                const Lk = C.filter(c => cnt.get(key(c)) >= need(rows.length));
                Lk.forEach(c => L.set(key(c), { set: c, count: cnt.get(key(c)) }));
                C = aprioriGen(Lk, k);
            }
            return { L, reads };
        }

        /* ---------- 照著 FUP 跑一次，記下每一步 ---------- */
        function buildTrace(DBrows, L, db) {
            const D = DBrows.length, d = db.length, N = D + d;
            const needN = need(N), needd = need(d), needD = need(D);
            const steps = [];
            const reads = { f1: 0, f0: 0, r1: 0, r0: 0 };   // f＝FUP、r＝全部重算；1＝讀 db、0＝讀 DB
            const stats = { dbScans: 0, DBScans: 0, cut: 0 };
            const newL = new Map();
            const board = new Map();                          // 右下「L 的變化」：每個樣式目前的狀態
            [...L.values()].forEach(v => board.set(key(v.set), { set: v.set, old: v.count, now: null, st: 'pending' }));
            const push = (kind, extra = {}) => steps.push({
                kind, D, d, N, needN, needd, needD, ...extra,
                reads: { ...reads }, stats: { ...stats },
                board: [...board.values()].map(x => ({ ...x }))
            });
            const missing = set => subsets(set).find(s => !newL.has(key(s)));
            const both = set => ({ a: support(DBrows, set), b: support(db, set) });

            push('start', { Lsize: L.size });

            let C = singleItems([...DBrows, ...db]);
            let k = 1;
            while (C.length) {
                const inC = new Set(C.map(key));
                const old = C.filter(c => L.has(key(c)));
                const fresh = C.filter(c => !L.has(key(c)));
                // 舊的 L(k) 卻沒被產生出來：它有子集合已經掉出，不用數就知道它也掉出
                const gone = [...L.values()].filter(v => v.set.length === k && !inC.has(key(v.set)))
                    .sort((x, y) => cmpSet(x.set, y.set)).map(v => ({ set: v.set, old: v.count, miss: missing(v.set) }));
                gone.forEach(g => board.set(key(g.set), { set: g.set, old: g.old, now: null, st: 'gone', miss: g.miss }));
                push('gen', {
                    k, nOld: old.length, nFresh: fresh.length, gone,
                    cands: [
                        ...old.map(c => ({ set: c, cls: 'old', tag: ['t-old', '舊'], badge: `DB ${L.get(key(c)).count}`,
                            hint: `${fmt(c)} 原本就在 L 裡，它在 DB 的 ${L.get(key(c)).count} 次已經記著，不用再數 DB。` })),
                        ...fresh.map(c => ({ set: c, cls: 'new', tag: ['t-new', '新'],
                            hint: `${fmt(c)} 原本不在 L 裡（在 DB 不到 ${needD} 次），L 沒有記它的次數，所以是「新候選」。` })),
                        ...gone.map(g => ({ set: g.set, cls: 'out', tag: ['t-old', '舊'], why: `${fmt(g.miss)} 掉出了`, mark: g.miss,
                            hint: `${fmt(g.set)} 的子集合 ${fmt(g.miss)} 已經掉出（表格標黃的是含 ${fmt(g.miss)} 的列），所以 ${fmt(g.set)} 也不可能頻繁，連數都不用數。` }))
                    ]
                });

                // 掃 db 一次：舊樣式和新候選一起數
                const inDb = countRows(db, C);
                reads.f1 += d; reads.r1 += d; reads.r0 += D;
                stats.dbScans++;
                const Lk = new Map();
                const oldView = old.map(c => {
                    const a = L.get(key(c)).count, b = inDb.get(key(c)), t = a + b, ok = t >= needN;
                    if (ok) Lk.set(key(c), { set: c, count: t });
                    board.set(key(c), { set: c, old: a, now: t, st: ok ? 'kept' : 'dropped' });
                    return { set: c, a, b, t, ok };
                });
                push('old', {
                    k, nFresh: fresh.length, dropped: oldView.filter(x => !x.ok).map(x => x.set),
                    cands: oldView.map(x => ({ set: x.set, a: x.a, b: x.b, t: x.t, cls: x.ok ? 'ok' : 'out', badge: `${x.a}+${x.b}=${x.t}`, why: x.ok ? '' : `< ${needN}`,
                        hint: `${fmt(x.set)}：DB 的 ${x.a} 次（L 裡本來就有）＋ db 裡數到 ${x.b} 次 ＝ ${x.t} 次，${x.ok ? `≥ ${needN}，留著。` : `不到 ${needN}，掉出去了。`}` }))
                });

                // 引理：在 db 裡也不頻繁的新候選，直接排除
                const lemmaView = fresh.map(c => ({ set: c, b: inDb.get(key(c)), ok: inDb.get(key(c)) >= needd }));
                const pass = lemmaView.filter(x => x.ok).map(x => x.set);
                stats.cut += fresh.length - pass.length;
                push('lemma', {
                    k, nPass: pass.length, nCut: fresh.length - pass.length,
                    cands: lemmaView.map(x => ({ set: x.set, b: x.b, cls: x.ok ? 'ok' : 'out', badge: `db ${x.b}`,
                        why: x.ok ? '要回頭掃 DB' : `< ${needd}`,
                        hint: x.ok
                            ? `${fmt(x.set)} 在 db 裡有 ${x.b} 次 ≥ ${needd}，有機會變頻繁，要回頭掃 DB 才知道它在 DB 裡有幾次。`
                            : `${fmt(x.set)} 在 db 裡只有 ${x.b} 次，不到 ${needd}；它在 DB 本來就不到 ${needD} 次（其實是 ${both(x.set).a} 次，但 FUP 根本不用去數），兩邊加起來一定不到 ${needN}，直接排除。` }))
                });

                // 通過引理的新候選，才回頭掃 DB
                let scanView = [];
                if (pass.length) {
                    const inDB = countRows(DBrows, pass);
                    reads.f0 += D;
                    stats.DBScans++;
                    scanView = pass.map(c => {
                        const a = inDB.get(key(c)), b = inDb.get(key(c)), t = a + b, ok = t >= needN;
                        if (ok) {
                            Lk.set(key(c), { set: c, count: t });
                            board.set(key(c), { set: c, old: null, now: t, st: 'added' });
                        }
                        return { set: c, a, b, t, ok };
                    });
                }
                push('scan', {
                    k, skip: !pass.length,
                    added: scanView.filter(x => x.ok).map(x => x.set), failed: scanView.filter(x => !x.ok).map(x => x.set),
                    cands: scanView.map(x => ({ set: x.set, a: x.a, b: x.b, t: x.t, cls: x.ok ? 'ok' : 'out', badge: `${x.a}+${x.b}=${x.t}`, why: x.ok ? '新加入' : `< ${needN}`,
                        hint: `${fmt(x.set)}：回頭掃 DB 數到 ${x.a} 次 ＋ db 的 ${x.b} 次 ＝ ${x.t} 次，${x.ok ? `≥ ${needN}，新加入 L！` : `還是不到 ${needN}。`}` }))
                });

                // 這一層的結果
                const LkList = [...Lk.values()].sort((x, y) => cmpSet(x.set, y.set));
                LkList.forEach(v => newL.set(key(v.set), v));
                push('level', {
                    k, size: LkList.length,
                    nKept: oldView.filter(x => x.ok).length, nAdded: scanView.filter(x => x.ok).length,
                    nDropped: oldView.filter(x => !x.ok).length + gone.length,
                    cands: [
                        ...LkList.map(v => {
                            const was = L.get(key(v.set));
                            return { set: v.set, cls: 'ok', tag: was ? null : ['t-new', '新'], badge: was && was.count !== v.count ? `${was.count}→${v.count}` : `${v.count}`,
                                hint: was ? `${fmt(v.set)} 本來就頻繁，次數 ${was.count} → ${v.count}。` : `${fmt(v.set)} 是這次新加入的，${v.count} 次。` };
                        }),
                        ...oldView.filter(x => !x.ok).map(x => ({ set: x.set, cls: 'out', badge: `${x.a}→${x.t}`, why: `< ${needN}`,
                            hint: `${fmt(x.set)} 原本 ${x.a} 次，加上 db 變成 ${x.t} 次，但筆數變多、門檻變成 ${needN} 次，所以掉出。` })),
                        ...gone.map(g => ({ set: g.set, cls: 'out', why: '連帶掉出', mark: g.miss,
                            hint: `${fmt(g.set)} 的子集合 ${fmt(g.miss)} 已經掉出，它跟著掉出，連數都不用數。` }))
                    ]
                });

                k++;
                C = aprioriGen(LkList.map(v => v.set), k);
            }

            // 沒有候選了：舊 L 裡還沒處理到的大樣式，全部連帶掉出
            const rest = [...L.values()].filter(v => v.set.length >= k).sort((x, y) => x.set.length - y.set.length || cmpSet(x.set, y.set))
                .map(v => ({ set: v.set, old: v.count, miss: missing(v.set) }));
            rest.forEach(g => board.set(key(g.set), { set: g.set, old: g.old, now: null, st: 'gone', miss: g.miss }));
            push('stop', {
                k, gone: rest,
                cands: rest.map(g => ({ set: g.set, cls: 'out', tag: ['t-old', '舊'], why: `${fmt(g.miss)} 掉出了`, mark: g.miss,
                    hint: `${fmt(g.set)} 的子集合 ${fmt(g.miss)} 已經不頻繁，所以它也跟著掉出。` }))
            });

            // 對答案：直接對 DB∪db 重跑 Apriori
            const again = apriori([...DBrows, ...db]);
            const same = again.L.size === newL.size && [...newL].every(([kk, v]) => again.L.has(kk) && again.L.get(kk).count === v.count);
            const added = [...newL.values()].filter(v => !L.has(key(v.set))).map(v => v.set).sort(cmpSet);
            const dropped = [...L.values()].filter(v => !newL.has(key(v.set))).map(v => v.set).sort((a, b) => a.length - b.length || cmpSet(a, b));
            const changed = [...newL.values()].filter(v => L.has(key(v.set)) && L.get(key(v.set)).count !== v.count).length;
            push('end', {
                size: newL.size, added, dropped, changed, same, reReads: again.reads,
                newL: [...newL.values()].map(v => ({ set: v.set, count: v.count }))
            });
            const scale = Math.max(1, reads.r1 + reads.r0, reads.f1 + reads.f0);
            steps.forEach(s => { s.scale = scale; });
            return steps;
        }

        /* ---------- 說明文字 ---------- */
        function describe(s) {
            const n = s.cands ? s.cands.length : 0;
            switch (s.kind) {
                case 'idle':
                    return `先在上面組好這一批要新增的交易 db（點商品勾選後按「＋ 加入」，或直接選一組預設批次），再按「<b>更新 ▶</b>」。` +
                        `目前 DB 有 ${baseDB.length} 筆，門檻 ${pct}%，L 裡有 ${oldL.size} 個頻繁樣式。`;
                case 'start':
                    return `DB 原本有 <b>${s.D}</b> 筆，L 已經算好（${s.Lsize} 個頻繁樣式，連次數都有）。現在新增 <b>${s.d}</b> 筆 db，合起來 ${s.N} 筆。` +
                        `門檻 ${pct}%：在 DB∪db 至少要 <b>${s.needN}</b> 次；在 db 裡則是 ${s.needd} 次（引理會用到）。目標是盡量只讀新的 ${s.d} 筆，非不得已才回頭讀舊的 ${s.D} 筆。`;
                case 'gen':
                    return (s.k === 1
                        ? `第 1 層：候選是每個商品，共 ${n} 個。`
                        : `第 ${s.k} 層：跟 Apriori 一樣，用剛更新好的 L${s.k - 1} 合併＋剪枝，產生 ${n - s.gone.length} 個候選。`) +
                        `其中 ${s.nOld} 個本來就在 L 裡（標「舊」，DB 的次數已知），${s.nFresh} 個是<b>新候選</b>（DB 的次數沒記下來）。` +
                        (s.gone.length ? `舊的 ${list(s.gone.map(g => g.set))} 沒被產生出來：它的子集合已經掉出，<b>不用數就知道它也掉出</b>。` : '');
                case 'old': {
                    const head = `掃 db 一次（讀 ${s.d} 筆），舊樣式和新候選一起數。`;
                    if (!n) return head + `這一層沒有舊樣式；db 還是要掃，因為新候選要先知道自己在 db 裡有幾次。全部重算的話，這一層要讀 ${s.N} 筆。`;
                    return head + `舊樣式的新次數 ＝ DB 的舊次數（L 裡就有）＋ db 裡數到的。` +
                        (s.dropped.length ? `<b>${list(s.dropped)}</b> 加完還是不到 ${s.needN} 次，掉出去了。` : `全部都還 ≥ ${s.needN} 次，留著。`) +
                        `全部重算的話，這一層要讀 ${s.N} 筆。`;
                }
                case 'lemma':
                    if (!n) return `這一層沒有新候選，引理不用出場。`;
                    return `<b>引理</b>：原本在 DB 不頻繁的樣式，如果在 db 裡也不到 ${s.needd} 次（${pct}% × ${s.d} 筆），合起來一定不到門檻。` +
                        (s.nCut ? `所以 ${s.nCut} 個新候選直接排除，DB 一筆都不用讀；` : `這一層沒有被排除的；`) +
                        (s.nPass ? `剩下 ${s.nPass} 個要回頭掃 DB 補次數。` : `<b>沒有任何新候選需要回頭掃 DB</b>。`);
                case 'scan':
                    if (s.skip) return `這一層<b>完全不用碰 DB</b>：沒有新候選通過引理。全部重算的話這裡還要把 ${s.D} 筆舊交易再讀一次，這就是 FUP 省下來的地方。`;
                    return `回頭掃 DB 一次（讀 ${s.D} 筆），只數通過引理的 ${n} 個新候選。` +
                        (s.added.length ? `<b>${list(s.added)}</b> 合起來 ≥ ${s.needN} 次，新加入 L！` : '') +
                        (s.failed.length ? `${list(s.failed)} 補完還是不到 ${s.needN} 次。` : '');
                case 'level': {
                    const parts = [];
                    if (s.nKept) parts.push(`保留 ${s.nKept} 個`);
                    if (s.nAdded) parts.push(`新加入 ${s.nAdded} 個`);
                    if (s.nDropped) parts.push(`掉出 ${s.nDropped} 個`);
                    return `第 ${s.k} 層更新完成，新的 L${s.k} 有 <b>${s.size}</b> 個` + (parts.length ? `（${parts.join('、')}）` : '') + `。` +
                        (s.size ? `接著用它產生第 ${s.k + 1} 層的候選。` : `L${s.k} 是空的，不會再有更大的樣式。`);
                }
                case 'stop':
                    return `用 L${s.k - 1} 產生不出任何 ${s.k} 個商品的候選，迴圈結束。` +
                        (s.gone.length ? `舊 L 裡更大的 ${list(s.gone.map(g => g.set))} 也因為子集合掉出，跟著掉出。` : '');
                case 'end': {
                    const f = s.reads.f1 + s.reads.f0, r = s.reads.r1 + s.reads.r0;
                    const save = r ? Math.round((r - f) / r * 100) : 0;
                    return `更新完成！新的 L 有 <b>${s.size}</b> 個：新加入 ${s.added.length}、掉出 ${s.dropped.length}、次數改變 ${s.changed}` +
                        (!s.added.length && !s.dropped.length ? `（L 裡的樣式完全沒變，只有次數更新）` : '') +
                        (s.same ? `，跟直接對 ${s.N} 筆重跑 Apriori 的結果一模一樣。` : `。（⚠ 跟重算的結果不一樣，這不應該發生）`) +
                        `FUP 讀了 <b>${f}</b> 筆交易，全部重算要 <b>${r}</b> 筆，省下 ${save}%。可以按「✓ 併入 DB」再加下一批。`;
                }
            }
            return '';
        }

        const CODE_TAGS = s => ({
            start: ['start'], gen: s.k === 1 ? ['c1', 'split'] : ['gen', 'split'], old: ['old'], lemma: ['lemma'],
            scan: ['scan'], level: ['level'], stop: ['stop'], end: ['end']
        })[s.kind] || [];

        /* ---------- 畫面：資料庫 ---------- */
        function renderDB() {
            const table = $('db');
            const hit = new Set(selected || []);
            const editing = phase === 'edit';
            const row = (t, label, cls, extra) => {
                const match = selected && selected.every(x => t.has(x));
                return `<tr class="${cls}${match ? ' match' : ''}"><td class="tid">${label}</td>` +
                    ITEMS.map(i => `<td><div class="cell${t.has(i) ? ' has' : ''}${cls === 'pend' ? ' nw' : ''}${match && hit.has(i) ? ' hit' : ''}"></div></td>`).join('') +
                    (editing ? `<td>${extra || ''}</td>` : '') + '</tr>';
            };
            let html = '<tr><th class="tid-h"></th>' + ITEMS.map(i =>
                `<th class="${hit.has(i) ? 'sel' : ''}"><span class="emo">${EMOJI[i]}</span>${i}</th>`).join('') + (editing ? '<th class="del-h"></th>' : '') + '</tr>';
            baseDB.forEach((t, r) => { html += row(t, `T${r + 1}`, ''); });
            const cols = ITEMS.length + (editing ? 2 : 1);
            if (pending.length) {
                html += `<tr class="sep"><td colspan="${cols}">＋ ${phase === 'run' ? '這一批新增的' : '待新增的'} db（${pending.length} 筆）</td></tr>`;
                pending.forEach((t, r) => {
                    html += row(t, `+${r + 1}`, 'pend', `<button class="del" data-del="${r}" aria-label="刪除第 ${r + 1} 筆待新增">✕</button>`);
                });
            } else {
                html += `<tr class="sep none"><td colspan="${cols}">（還沒有待新增的交易）</td></tr>`;
            }
            table.innerHTML = html;
            $('pct-val').textContent = pct + '%';
            $('pct-note').textContent = `DB ${baseDB.length} 筆 → 至少 ${need(baseDB.length)} 次`;
            $('pct-minus').disabled = pct <= 10;
            $('pct-plus').disabled = pct >= 80;
        }

        function renderCompose() {
            const editing = phase === 'edit';
            $('picks').parentElement.style.display = editing ? '' : 'none';
            $('edit-actions').style.display = editing ? '' : 'none';
            $('run-actions').style.display = editing ? 'none' : '';
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
            add.disabled = !draft.size || pending.length >= MAX_BATCH || baseDB.length + pending.length >= MAX_DB;
            box.appendChild(add);
            [...$('presets').children].forEach((b, i) => b.classList.toggle('cur', i === presetUsed));
            $('btn-update').disabled = !pending.length;
            $('btn-clear').disabled = !pending.length;
            $('locked-text').innerHTML = `這一批 db 有 <b>${pending.length}</b> 筆，已鎖定。`;
            $('btn-commit').disabled = baseDB.length + pending.length > MAX_DB;
        }

        /* ---------- 畫面：這一步 ---------- */
        function candButton(c) {
            const b = document.createElement('button');
            b.type = 'button';
            b.className = 'cand' + (c.cls ? ' ' + c.cls : '') + (selChip === key(c.set) ? ' sel' : '');
            b.innerHTML = `<span class="name"></span>` + (c.tag ? `<span class="tg ${c.tag[0]}">${c.tag[1]}</span>` : '') +
                (c.badge ? `<span class="n"></span>` : '') + (c.why ? `<span class="why"></span>` : '');
            b.querySelector('.name').textContent = fmt(c.set);
            if (c.badge) b.querySelector('.n').textContent = c.badge;
            if (c.why) b.querySelector('.why').textContent = c.why;
            b.addEventListener('click', () => {
                const again = selChip === key(c.set);
                selChip = again ? null : key(c.set);
                selected = again ? null : (c.mark || c.set);
                renderDB();
                showCands();
                $('cands-hint').textContent = again ? '' : c.hint;
            });
            return b;
        }

        function showCands() {
            const s = trace[cursor];
            const box = $('cands');
            box.innerHTML = '';
            if (s.cands) s.cands.forEach(c => box.appendChild(candButton(c)));
            if (s.cands && !s.cands.length) box.innerHTML = '<span class="cands-hint">（這一步沒有樣式）</span>';
        }

        function renderCost(s) {
            const r = s.reads || { f1: 0, f0: 0, r1: 0, r0: 0 };
            const scale = s.scale || 1;
            const w = v => (v / scale * 100) + '%';
            $('bar-f1').style.width = w(r.f1);
            $('bar-f0').style.width = w(r.f0);
            $('bar-r1').style.width = w(r.r1);
            $('bar-r0').style.width = w(r.r0);
            const f = r.f1 + r.f0, re = r.r1 + r.r0;
            $('num-f').textContent = f;
            $('num-r').textContent = re;
            const note = $('cost-note');
            if (s.kind === 'idle') { note.textContent = '按「更新」之後，這裡會一層一層累計兩種做法各讀了幾筆交易。'; return; }
            note.innerHTML = `FUP：db ${r.f1} ＋ DB ${r.f0} ＝ ${f} 筆；全部重算：每層都讀 ${s.N} 筆，共 ${re} 筆。` +
                (re ? ` <b>目前省下 ${re - f} 筆（${Math.round((re - f) / re * 100)}%）</b>` : '');
        }

        /* ---------- 畫面：L 的變化 ---------- */
        function renderBoard(s) {
            const box = $('levels');
            box.innerHTML = '';
            const board = s.board || [...oldL.values()].map(v => ({ set: v.set, old: v.count, now: null, st: 'pending' }));
            if (!board.length) { box.innerHTML = '<div class="empty">L 是空的：門檻太高，DB 裡沒有任何頻繁樣式。</div>'; }
            const byK = {};
            board.forEach(x => { (byK[x.set.length] = byK[x.set.length] || []).push(x); });
            Object.keys(byK).map(Number).sort((a, b) => a - b).forEach(k => {
                const row = document.createElement('div');
                row.className = 'level';
                row.innerHTML = `<span class="tag">L${k}</span><div class="items"></div>`;
                byK[k].sort((x, y) => cmpSet(x.set, y.set)).forEach(x => {
                    const p = document.createElement('span');
                    p.className = 'pat ' + x.st;
                    p.innerHTML = '<span class="nm"></span><span class="n"></span>';
                    p.firstChild.textContent = fmt(x.set);
                    p.lastChild.textContent = {
                        pending: `${x.old}`, kept: x.old === x.now ? `${x.now}` : `${x.old}→${x.now}`, added: `新 ${x.now}`,
                        dropped: `${x.old}→${x.now}，不到 ${s.needN}`, gone: '連帶'
                    }[x.st];
                    p.title = {
                        pending: `還沒處理，DB 裡的舊次數 ${x.old}`, kept: '保留', added: '新加入',
                        dropped: `掉出：只有 ${x.now} 次`, gone: `連帶掉出：子集合 ${x.miss ? fmt(x.miss) : ''} 已經掉出`
                    }[x.st];
                    row.querySelector('.items').appendChild(p);
                });
                box.appendChild(row);
            });
            const st = s.stats || { dbScans: 0, DBScans: 0, cut: 0 };
            $('st-db').textContent = st.dbScans;
            $('st-DB').textContent = st.DBScans;
            $('st-cut').textContent = st.cut;
            const log = $('batches');
            log.innerHTML = '';
            batchLog.forEach((x, i) => {
                const div = document.createElement('div');
                div.innerHTML = `第 ${i + 1} 批（+${x.d} 筆，門檻 ${x.pct}%）：FUP 讀 <b>${x.f}</b> 筆，全部重算要 <b>${x.r}</b> 筆`;
                log.appendChild(div);
            });
            if (batchLog.length > 1) {
                const f = batchLog.reduce((a, x) => a + x.f, 0), r = batchLog.reduce((a, x) => a + x.r, 0);
                const div = document.createElement('div');
                div.innerHTML = `累計：FUP <b>${f}</b> 筆、全部重算 <b>${r}</b> 筆`;
                log.appendChild(div);
            }
        }

        /* ---------- 程式碼 ---------- */
        const KW = {
            java: new Set('public static final for if return new boolean int void class import while else null this continue'.split(' ')),
            py: new Set('def for in if return not and or while import from as True False None global lambda continue'.split(' '))
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
                ? '下載 <a href="code/FUP.java" download>FUP.java</a>　執行 <code>javac FUP.java && java FUP</code>'
                : '下載 <a href="code/fup.py" download>fup.py</a>　執行 <code>python3 fup.py</code>';
        }

        /* ---------- 顯示某一步 ---------- */
        function stepLabel(i) {
            return phase === 'edit' ? '還沒開始' : `步驟 ${i + 1} / ${trace.length}`;
        }
        function showStep() {
            const s = trace[cursor];
            selected = null;
            selChip = null;
            renderDB();
            renderCompose();
            $('explain').innerHTML = `<span class="step-no">${stepLabel(cursor)}</span>${describe(s)}`;
            showCands();
            $('cands-hint').textContent = s.cands && s.cands.length ? '點樣式看它出現在哪幾筆交易、為什麼這樣處理' : '';
            renderCost(s);
            renderBoard(s);
            renderCode(CODE_TAGS(s));
            $('btn-prev').disabled = $('btn-first').disabled = cursor === 0;
            $('btn-next').disabled = cursor === trace.length - 1;
            $('btn-play').disabled = trace.length < 2;
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
                probe.innerHTML = `<span class="step-no">${stepLabel(i)}</span>${describe(s)}`;
                tallest = Math.max(tallest, probe.offsetHeight);
            });
            probe.remove();
            box.style.minHeight = tallest + 'px';
            reserveBlockHeights(document, trace.length, i => { cursor = i; showStep(); }, () => cursor);
        }

        function rebuild(keepCursor) {
            stopAuto();
            if (phase === 'run' && pending.length) {
                trace = buildTrace(baseDB, oldL, pending);
            } else {
                phase = 'edit';
                trace = [{ kind: 'idle' }];
            }
            cursor = keepCursor ? Math.min(cursor, trace.length - 1) : 0;
            showStep();
            reserveExplainHeight();
            const sc = $('db-scroll');
            if (pending.length) sc.scrollTop = sc.scrollHeight;   // 只捲表格框，讓這一批新交易看得到
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
            /* 複選：從 cands 挑最多 4 個（對的最多先放 2 個），只剩 1 個時改成會／不會 */
            const multi = (q, cs, isRight, why, ask, single) => {
                if (!cs.length) return null;
                const right = quizShuffle(cs.filter(isRight), rnd), wrong = quizShuffle(cs.filter(c => !isRight(c)), rnd);
                const pick = quizShuffle([...right.slice(0, 2), ...wrong, ...right.slice(2)].slice(0, 4), rnd);
                const mq = { q, multi: true, choices: pick.map(c => fmt(c.set)), answer: pick.map((c, k) => (isRight(c) ? k : -1)).filter(k => k >= 0), why: why(pick), ask: { ...ask, sets: pick.map(c => c.set) } };
                return pick.length === 1 ? quizSingle(mq, `${fmt(pick[0].set)} ${single}嗎？`) : mq;
            };
            switch (s.kind) {
                case 'old':
                    return multi(`DB∪db 共 ${s.N} 筆，至少要 ${s.needN} 次。數完 db 後，哪些舊樣式會掉出去？`, s.cands, c => c.t < s.needN,
                        pick => pick.map(c => `${fmt(c.set)} ${c.a}+${c.b}=${c.t}`).join('、') + `；舊次數加上 db 的次數，不到 ${s.needN} 就掉出。`,
                        { type: 'drop' }, '會掉出去');
                case 'lemma':
                    return multi(`新候選在 db 裡至少要 ${s.needd} 次（${pct}% × ${s.d} 筆）才值得回頭掃 DB。哪些要回頭掃 DB？`, s.cands, c => c.b >= s.needd,
                        pick => pick.map(c => `${fmt(c.set)} db ${c.b} 次`).join('、') + `；在 DB 和 db 都不頻繁，合起來一定不頻繁，直接排除。`,
                        { type: 'lemma' }, '要回頭掃 DB');
                case 'scan': {
                    if (s.skip || !s.cands.length) return null;
                    const c = quizPick(s.cands, rnd);
                    return {
                        q: `回頭掃 DB 之後，${fmt(c.set)} 在 DB∪db 一共出現幾次？`,
                        ...quizNums(c.t, 0, s.N, rnd, [c.b, c.a, s.needN]),
                        why: `DB 裡 ${c.a} 次 + db 裡 ${c.b} 次 = ${c.t} 次，` + (c.t >= s.needN ? `≥ ${s.needN}，新加入 L。` : `不到 ${s.needN}，進不了 L。`),
                        ask: { type: 'count', set: c.set }
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

        // 門檻改了：舊的 L 要用新門檻重新算一次（相當於用 Apriori 重新挖 DB），再重跑 FUP
        function setPct(v) {
            pct = Math.max(10, Math.min(80, v));
            oldL = apriori(baseDB).L;
            rebuild(true);
        }
        $('pct-minus').addEventListener('click', () => setPct(pct - 5));
        $('pct-plus').addEventListener('click', () => setPct(pct + 5));

        $('picks').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b || phase !== 'edit') return;
            if (b.id === 'btn-add') {
                if (!draft.size || pending.length >= MAX_BATCH) return;
                pending.push(new Set(draft));
                draft = new Set();
                presetUsed = -1;
                rebuild(false);
                return;
            }
            const item = b.dataset.item;
            if (draft.has(item)) draft.delete(item); else draft.add(item);
            renderCompose();
        });
        $('db').addEventListener('click', e => {
            const del = e.target.closest('[data-del]');
            if (!del || phase !== 'edit') return;
            pending.splice(Number(del.dataset.del), 1);
            presetUsed = -1;
            rebuild(false);
        });
        PRESETS.forEach((p, i) => {
            const b = document.createElement('button');
            b.type = 'button';
            b.className = 'btn small';
            b.textContent = p.label;
            b.addEventListener('click', () => {
                pending = p.rows.map(r => new Set(r));
                presetUsed = i;
                phase = 'run';
                rebuild(false);
            });
            $('presets').appendChild(b);
        });
        $('btn-clear').addEventListener('click', () => { pending = []; presetUsed = -1; rebuild(false); });
        $('btn-update').addEventListener('click', () => {
            if (!pending.length) return;
            phase = 'run';
            rebuild(false);
        });
        $('btn-edit-batch').addEventListener('click', () => { phase = 'edit'; rebuild(false); });
        $('btn-commit').addEventListener('click', () => {
            const end = trace[trace.length - 1];
            if (phase !== 'run' || end.kind !== 'end') return;
            batchLog.push({ d: pending.length, pct, f: end.reads.f1 + end.reads.f0, r: end.reads.r1 + end.reads.r0 });
            baseDB = baseDB.concat(pending);
            oldL = new Map(end.newL.map(v => [key(v.set), { set: v.set, count: v.count }]));
            pending = [];
            presetUsed = -1;
            phase = 'edit';
            rebuild(false);
        });
        $('btn-reset').addEventListener('click', () => { reset(); });
        $('btn-reset2').addEventListener('click', () => { reset(); });

        function reset() {
            baseDB = SAMPLE.map(t => new Set(t));
            pct = 30;
            oldL = apriori(baseDB).L;
            pending = PRESETS[0].rows.map(r => new Set(r));
            presetUsed = 0;
            batchLog = [];
            draft = new Set();
            phase = 'run';
            rebuild(false);
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
