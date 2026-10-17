<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/prefixspan.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/prefixspan-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/prefixspan-180.png">
    <title>PrefixSpan 序列樣式探勘</title>
    <meta name="description" content="一步一步看 PrefixSpan 怎麼用前綴投影找出「先買什麼、之後再買什麼」的序列樣式：投影資料庫、同一次延伸與下一次延伸、遞迴，Java 與 Python 程式碼逐行對照。">
    <script src="../assets/theme.js"></script>
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

        /* 手機：一欄，依序 步驟 → 序列資料庫 → 計數表 → 程式碼 → 結果；電腦：兩欄 */
        .layout {
            display: grid;
            gap: 1rem;
            margin-top: 1.3rem;
            grid-template-areas: "step" "seq" "count" "code" "result";
            align-items: start;
        }
        .layout > * { min-width: 0; }
        @media (min-width: 960px) {
            .layout {
                grid-template-columns: 1fr 1fr;
                grid-template-areas: "step code" "seq code" "count result";
            }
        }
        .a-step { grid-area: step; }
        .a-seq { grid-area: seq; }
        .a-count { grid-area: count; }
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

        /* ── 序列資料庫 ── */
        .presets { display: flex; flex-wrap: wrap; gap: 0.35rem; margin-bottom: 0.6rem; }
        .presets .btn.cur { border-color: var(--accent2); color: var(--accent2); }
        .crumbs { display: flex; flex-wrap: wrap; gap: 0.3rem; align-items: center; font-size: 0.8rem; color: var(--muted); margin-bottom: 0.55rem; min-height: 1.6rem; }
        .crumb { border: 1px solid var(--border); border-radius: 6px; padding: 0.05rem 0.45rem; white-space: nowrap; }
        .crumb.cur { border-color: var(--accent); color: var(--text); background: var(--lt-7c3aed-15, rgba(124, 58, 237, 0.15)); }
        .arrow { color: var(--lt-4a4a66, #4a4a66); font-size: 0.75rem; }
        .seqs { display: grid; gap: 0.25rem; }
        .srow { display: grid; grid-template-columns: 2.9em minmax(0, 1fr) auto; column-gap: 0.45rem; align-items: center; padding: 0.3rem 0.4rem; border-radius: 8px; transition: background 0.2s; }
        .srow .who { font-size: 0.8rem; color: var(--muted); white-space: nowrap; }
        .srow.gone .visits, .srow.gone .who { opacity: 0.3; }
        .srow.pick { background: var(--lt-06b6d4-13, rgba(6, 182, 212, 0.13)); }
        .srow.pick .who { color: var(--accent2); }
        .srow .mark { font-size: 0.72rem; color: var(--muted); white-space: nowrap; }
        .srow .mark.drop { color: var(--bad); }
        .srow .post { grid-column: 2 / 4; font: 0.72rem 'Space Mono', monospace; color: var(--muted); margin-top: 0.15rem; overflow-wrap: anywhere; }
        .srow .post b { color: var(--accent2); font-weight: 400; }
        .visits { display: flex; flex-wrap: wrap; gap: 0.25rem; align-items: center; min-width: 0; }
        .visit { display: inline-flex; align-items: center; border: 1px solid var(--border); border-radius: 8px; padding: 0.05rem 0.25rem; background: var(--lt-16162a, #16162a); font-size: 1.05rem; line-height: 1.45; }
        .visit.past { opacity: 0.28; }
        .visit.also { border: 1.5px dashed var(--accent2); }
        .it { padding: 0 0.1rem; border-radius: 5px; }
        .it.used { opacity: 0.3; }
        .it.anchor { box-shadow: 0 0 0 2px var(--accent); }
        .it.anchor.new { box-shadow: 0 0 0 2px var(--warn); background: var(--lt-f59e0b-18, rgba(245, 158, 11, 0.18)); }
        .it.under { border-bottom: 2px dashed var(--accent2); border-radius: 0; }
        .us { color: var(--accent2); font: 700 0.8rem 'Space Mono', monospace; margin: 0 0.05rem; }
        .legend { display: flex; flex-wrap: wrap; gap: 0.3rem 0.9rem; font-size: 0.75rem; color: var(--muted); margin-top: 0.6rem; }
        .legend .sw { display: inline-block; width: 13px; height: 13px; border-radius: 4px; margin-right: 0.3rem; vertical-align: -2px; }

        /* 編輯 */
        .db-foot { display: flex; flex-wrap: wrap; gap: 0.4rem; margin-top: 0.6rem; }
        .editing .visit { cursor: pointer; }
        .editing .visit:hover { border-color: var(--accent2); }
        .editing .visit.sel { border: 2px solid var(--accent2); background: var(--lt-06b6d4-12, rgba(6, 182, 212, 0.12)); }
        .editing .visit.empty { min-width: 2em; min-height: 1.6em; justify-content: center; color: var(--muted); font-size: 0.75rem; }
        .addv, .delc { background: none; border: 1px dashed var(--lt-3a3a5a, #3a3a5a); color: var(--muted); border-radius: 7px; width: 1.9em; height: 1.75em; cursor: pointer; font-size: 0.85rem; }
        .addv:hover, .delc:hover { border-color: var(--accent2); color: var(--text); }
        .delc { border-style: solid; }
        .palette { margin-top: 0.6rem; padding: 0.55rem; border: 1px solid var(--border); border-radius: 10px; background: var(--panel-2); font-size: 0.82rem; color: var(--muted); }
        .palette .opts { display: flex; flex-wrap: wrap; gap: 0.3rem; margin-top: 0.35rem; }
        .palette .opt { background: var(--lt-1b1b30, #1b1b30); border: 1px solid var(--border); color: var(--text); border-radius: 8px; padding: 0.2rem 0.45rem; font-size: 0.85rem; cursor: pointer; }
        .palette .opt.on { border-color: var(--accent2); background: var(--lt-06b6d4-18, rgba(6, 182, 212, 0.18)); }
        .palette .opt:disabled { opacity: 0.35; cursor: default; }

        /* ── 計數表 ── */
        .prefix-line { font-size: 0.85rem; color: var(--muted); margin-bottom: 0.5rem; }
        .prefix-line .pt { font-size: 0.95rem; }
        table.cnt { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
        table.cnt th { font-weight: 500; color: var(--muted); font-size: 0.76rem; text-align: center; padding: 0.25rem; border-bottom: 1px solid var(--border); line-height: 1.3; }
        table.cnt th:first-child { text-align: left; }
        table.cnt th small { display: block; font-size: 0.68rem; color: var(--lt-6a6a85, #6a6a85); }
        table.cnt td { padding: 0.2rem 0.25rem; border-bottom: 1px solid var(--border); text-align: center; }
        table.cnt td.nm { text-align: left; white-space: nowrap; }
        table.cnt td.c { font: 700 0.85rem 'Space Mono', monospace; }
        td.c span { display: inline-block; min-width: 2.4em; padding: 0.05rem 0.3rem; border-radius: 6px; border: 1px solid transparent; }
        td.c.zero span { color: var(--lt-44445c, #44445c); font-weight: 400; }
        td.c.no span { color: var(--muted); font-weight: 400; cursor: pointer; }
        td.c.ok span { color: var(--lt-86efac, #86efac); border-color: var(--lt-22c55e-45, rgba(34, 197, 94, 0.45)); cursor: pointer; }
        td.c.na span { color: var(--lt-44445c, #44445c); font-weight: 400; }
        td.c.done span { background: var(--lt-22c55e-14, rgba(34, 197, 94, 0.14)); }
        td.c.cur span { border-color: var(--warn); box-shadow: 0 0 0 1px var(--warn); color: var(--warn); }
        td.c.picked span { background: var(--lt-06b6d4-22, rgba(6, 182, 212, 0.22)); }
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
            background: var(--lt-0a0a14, #0a0a14);
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 0.5rem 0;
            overflow: auto;
            max-height: 620px;
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
        .level .items { display: flex; flex-wrap: wrap; gap: 0.35rem; min-width: 0; }
        .pat { font-size: 0.85rem; border: 1px solid var(--lt-22c55e-50, rgba(34, 197, 94, 0.5)); border-radius: 7px; padding: 0.1rem 0.45rem; white-space: nowrap; }
        .pat .n { font: 700 0.74rem 'Space Mono', monospace; margin-left: 0.35rem; color: var(--lt-86efac, #86efac); }
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
        <div class="kicker">RESEARCH DEMO · SEQUENTIAL PATTERN MINING</div>
        <h1>PrefixSpan 序列樣式探勘<small>不只看一起買什麼，還看「先買什麼、之後再買什麼」</small></h1>
        <p class="intro">
            <a href="apriori.html">Apriori</a> 和 <a href="fp-growth.html">FP-Growth</a> 只看「同一張發票裡一起買了什麼」。
            這頁換成看<b>順序</b>：把同一位常客每次來店買的東西照時間排成一個序列，找出很多人都有的「先…之後…」，
            例如 &lt;(☕🍞)(🍙)&gt;：某次一起買了咖啡和麵包，<b>之後</b>又回來買飯糰（中間隔幾次、有沒有買別的都沒關係）。
            PrefixSpan 跟 FP-Growth 一樣是分而治之：先找出頻繁的開頭（<b>前綴</b>），只留下每個人「前綴之後還剩下的部分」（<b>投影資料庫</b>），
            在裡面數一數能再接什麼，接上之後再遞迴。
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
                        <span class="unit">人</span>
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

            <div class="card a-seq" id="seq-card">
                <div class="card-head"><h2 id="seq-title">序列資料庫</h2></div>
                <div class="presets" id="presets"></div>
                <div class="crumbs" id="crumbs"></div>
                <div class="seqs" id="seqs"></div>
                <div class="palette" id="palette" hidden></div>
                <div class="db-foot">
                    <button class="btn small" id="btn-edit">✎ 編輯資料</button>
                    <button class="btn small" id="btn-add-cust" hidden>＋ 新增顧客</button>
                </div>
                <div class="legend" id="legend">
                    <span><i class="sw" style="background:#2a2a40;opacity:.5"></i>淡掉：前綴已經用掉的部分</span>
                    <span><i class="sw" style="box-shadow:0 0 0 2px var(--accent) inset"></i>前綴最後一個商品配對到這裡（投影點）</span>
                    <span><i class="sw" style="border-bottom:2px dashed var(--accent2);border-radius:0"></i>底線 _：跟它同一次買、排在後面的</span>
                    <span><i class="sw" style="border:1.5px dashed var(--accent2)"></i>後面某次又買齊了前綴的最後一次</span>
                </div>
            </div>

            <div class="card a-count">
                <h2>計數表：前綴後面能接什麼？</h2>
                <div class="prefix-line" id="prefix-line"></div>
                <table class="cnt" id="cnt"></table>
                <div class="cnt-hint" id="cnt-hint"></div>
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
                <h2>目前找到的頻繁序列樣式</h2>
                <div class="levels" id="levels"></div>
                <div class="stats">
                    <div class="stat"><div class="v" id="st-proj">0</div><div class="k">建過的投影資料庫</div></div>
                    <div class="stat"><div class="v" id="st-cells">0</div><div class="k">計數表裡數過的格子</div></div>
                    <div class="stat"><div class="v" id="st-depth">0</div><div class="k">最深的遞迴層</div></div>
                </div>
                <div class="compare" id="compare"></div>
            </div>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼只看「前綴後面剩下的」就夠了？</h2>
                <p>想知道 &lt;(☕)(🍙)&gt; 後面還能接什麼，只要看每個人<b>第一次</b>出現 &lt;(☕)(🍙)&gt; 之後的部分：
                    越早配對完，後面剩的越多，所以任何能接在後面的東西，一定都還在這段「後綴」裡，不會漏掉。
                    每多接一個商品，投影資料庫只會變短、變少人，而且<b>接不上的人以後也不可能再接上</b>（序列版的向下封閉性），所以可以直接丟掉。</p>
                <p style="margin-top:0.5rem">一次可以買好幾樣，所以要分兩種接法：<b>同一次</b>（i-延伸，&lt;(☕)&gt; → &lt;(☕🍞)&gt;）和<b>下一次以後</b>（s-延伸，&lt;(☕)&gt; → &lt;(☕)(🍞)&gt;）。
                    同一次裡的商品照固定順序（程式裡照字碼）排，只往後面接，每個樣式才只會被找到一次。
                    要小心的是：同一次延伸不只看底線 _ 那一格，後面如果某次又<b>買齊了前綴的最後一次</b>，那次裡的商品也算，不然會漏掉。</p>
            </div>
            <div class="card">
                <h2>優缺點、跟前面方法的關係</h2>
                <ul>
                    <li><b>不產生候選：</b>跟 FP-Growth 一樣是「樣式成長」，只去接投影資料庫裡真的出現過的商品；不像序列版的 Apriori（GSP），要先猜一大堆候選序列再整個資料庫掃一遍。</li>
                    <li><b>問題越切越小：</b>每往下一層，資料只剩前綴後面的一段，而且只剩接得上的人。</li>
                    <li><b>代價：</b>每一層都要建投影資料庫。實作上不複製資料，只記「每個人投影到哪裡」（這頁的 (sid, e, p) 就是這樣），稱為偽投影（pseudo-projection）。</li>
                    <li>序列樣式也能跟其他研究方向結合：把「次數」換成「效益」就是高效益序列樣式；資料一直進來就是資料串流上的序列探勘。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           PrefixSpan 一步一步看
           網頁裡用 JavaScript 照著同樣的流程跑一次，把每一步（含每一層遞迴）記下來；
           右邊的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = /*CODE_JSON*/null;

        const ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片'];
        const EMOJI = { '咖啡': '☕', '麵包': '🍞', '牛奶': '🥛', '飯糰': '🍙', '茶葉蛋': '🥚', '洋芋片': '🥔' };
        const NAMES = ['阿明', '小美', '阿傑', '小芳', '阿華', '小玉', '阿德', '小婷'];
        const MAX_CUST = 8, MAX_VISITS = 5, MAX_ITEMS = 3;
        const C = '咖啡', B = '麵包', M = '牛奶', R = '飯糰', E = '茶葉蛋', P = '洋芋片';
        const PRESETS = [
            {
                label: '早餐→午餐', sup: 3, db: [
                    [[C, B], [R, E], [P]],
                    [[C], [R, E], [C, B]],
                    [[C, B], [M], [R]],
                    [[B, M], [C, B], [R, P]],
                    [[C, B, E], [R, E]],
                    [[M], [B], [P]]
                ]
            },
            {
                label: '一次買好幾樣', sup: 3, db: [
                    [[C, B, M], [R, E]],
                    [[C, M], [C, B], [R, E]],
                    [[B], [C, B, M], [R]],
                    [[C, B], [M], [C, M, R]],
                    [[P], [C, B, M], [E]]
                ]
            },
            {
                label: '一直回購', sup: 2, db: [
                    [[C], [B], [C], [C]],
                    [[C, P], [C], [R], [C]],
                    [[B], [C], [B], [C]],
                    [[C], [M], [C, B], [B]],
                    [[R], [C], [R], [C, E]]
                ]
            }
        ];

        const $ = id => document.getElementById(id);
        const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);   // 跟 Java compareTo、Python 字串比較一樣：照字碼
        const normSeq = seq => seq.filter(e => e.length).map(e => [...new Set(e)].sort(cmp));
        let db = PRESETS[0].db.map(normSeq);
        let preset = 0;
        let minSup = PRESETS[0].sup;
        let lang = 'java';
        let trace = [];
        let cursor = 0;
        let timer = null;
        let picked = null;        // 計數表上點選的格子 {x, k}
        let editing = false;
        let selVisit = null;      // 編輯時選到的那一次來店 [sid, k]

        const emo = x => EMOJI[x] || x;
        const patText = pat => '<' + pat.map(e => '(' + e.map(emo).join('') + ')').join('') + '>';
        const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        const pt = pat => `<span class="pt">${esc(patText(pat))}</span>`;
        const elText = e => '(' + e.map(emo).join('') + ')';
        const names = sids => sids.map(i => NAMES[i]).join('、');

        /* ---------- 照著程式跑一次，記下每一步 ---------- */
        function buildTrace(dbIn, minSup) {
            const seqs = dbIn.map(normSeq);
            const steps = [];
            const result = [];
            const stats = { projs: 0, cells: 0, depth: 0 };
            const stack = [];
            const push = o => steps.push({ result: result.map(r => ({ ...r })), stats: { ...stats }, ...o });

            function project(proj, last, x, same) {
                const out = [];
                for (const pr of proj) {
                    const seq = seqs[pr.sid];
                    for (let k = same ? pr.e : pr.e + 1; k < seq.length; k++) {
                        const q = seq[k].indexOf(x);
                        if (q < 0) continue;
                        if (same && !(last.every(y => seq[k].includes(y)) && q > seq[k].indexOf(last[last.length - 1]))) continue;
                        out.push({ sid: pr.sid, e: k, p: q });
                        break;
                    }
                }
                return out;
            }

            function mine(prefix, proj, depth) {
                stats.projs++;
                stats.depth = Math.max(stats.depth, depth);
                stack.push(prefix);
                const last = prefix.length ? prefix[prefix.length - 1] : null;
                const cnt = { i: {}, s: {} }, who = { i: {}, s: {} };
                const also = {};          // sid → 後面又買齊 last 的那幾次
                const special = [];       // 只靠「後面又買齊」才算到的同一次延伸
                for (const pr of proj) {
                    const seq = seqs[pr.sid];
                    const iSeen = new Set(), sSeen = new Set();
                    if (last) {
                        seq[pr.e].slice(pr.p + 1).forEach(x => iSeen.add(x));
                        const extra = [];
                        for (let k = pr.e + 1; k < seq.length; k++) {
                            if (!last.every(y => seq[k].includes(y))) continue;
                            (also[pr.sid] = also[pr.sid] || []).push(k);
                            seq[k].forEach(x => {
                                if (x > last[last.length - 1] && !iSeen.has(x)) { iSeen.add(x); extra.push(x); }
                            });
                        }
                        if (extra.length) special.push({ sid: pr.sid, items: extra.sort(cmp) });
                    }
                    for (let k = pr.e + 1; k < seq.length; k++) seq[k].forEach(x => sSeen.add(x));
                    iSeen.forEach(x => { cnt.i[x] = (cnt.i[x] || 0) + 1; (who.i[x] = who.i[x] || []).push(pr.sid); });
                    sSeen.forEach(x => { cnt.s[x] = (cnt.s[x] || 0) + 1; (who.s[x] = who.s[x] || []).push(pr.sid); });
                }
                stats.cells += Object.keys(cnt.i).length + Object.keys(cnt.s).length;
                const exts = [
                    ...Object.keys(cnt.i).sort(cmp).filter(x => cnt.i[x] >= minSup).map(x => ({ x, k: 'i' })),
                    ...Object.keys(cnt.s).sort(cmp).filter(x => cnt.s[x] >= minSup).map(x => ({ x, k: 's' }))
                ];
                const counts = { cnt, who };
                push({ kind: 'count', prefix, proj, depth, counts, also, special, exts, crumbs: stack.slice() });
                const done = [];
                for (const ext of exts) {
                    const pattern = ext.k === 'i' ? [...prefix.slice(0, -1), [...last, ext.x]] : [...prefix, [ext.x]];
                    const sup = cnt[ext.k][ext.x];
                    result.push({ pat: pattern, sup, fresh: true });
                    const np = project(proj, last, ext.x, ext.k === 'i');
                    const dropped = proj.filter(pr => !np.some(q => q.sid === pr.sid)).map(pr => pr.sid);
                    const moved = np.filter(q => { const o = proj.find(pr => pr.sid === q.sid); return ext.k === 'i' && q.e !== o.e; }).map(q => q.sid);
                    push({ kind: 'extend', prefix, pattern, ext, sup, proj: np, depth, counts, dropped, moved, done: done.slice(), crumbs: [...stack, pattern] });
                    result.forEach(r => { r.fresh = false; });
                    done.push(ext);
                    mine(pattern, np, depth + 1);
                }
                stack.pop();
            }

            const all = seqs.map((_, i) => ({ sid: i, e: -1, p: -1 }));
            push({ kind: 'start', prefix: [], proj: all, depth: 0, crumbs: [] });
            mine([], all, 0);
            push({ kind: 'end', prefix: [], proj: all, depth: 0, crumbs: [] });
            steps.forEach((s, i) => { s.seqs = seqs; s.back = i > 0 && s.kind === 'extend' && steps[i - 1].depth > s.depth; });
            return steps;
        }

        /* 暴力法要比對的候選：每位顧客所有可能的子序列（不重複） */
        const bruteMemo = new WeakMap();   // 同一份資料只算一次（每一步的說明和比較都會用到）
        function bruteCandidates(seqs) {
            if (!bruteMemo.has(seqs)) bruteMemo.set(seqs, bruteCandidatesOf(seqs));
            return bruteMemo.get(seqs);
        }
        function bruteCandidatesOf(seqs) {
            const all = new Set();
            seqs.forEach(seq => {
                (function rec(k, cur) {
                    if (k === seq.length) { if (cur) all.add(cur); return; }
                    rec(k + 1, cur);
                    const e = seq[k], n = e.length;
                    for (let mask = 1; mask < (1 << n); mask++)
                        rec(k + 1, cur + '(' + e.filter((_, j) => mask >> j & 1).join(',') + ')');
                })(0, '');
            });
            return all.size;
        }

        /* ---------- 說明文字 ---------- */
        function describe(s) {
            const N = s.seqs.length;
            switch (s.kind) {
                case 'start':
                    return `每一列是一位常客，照時間排好他每次來店買了什麼（一個框是一次，可以買好幾樣）。` +
                        `一個序列樣式的<b>支持度</b>＝有幾位顧客的紀錄裡找得到它（同一個人出現好幾次也只算 1 人）。` +
                        `目標：找出至少 <b>${minSup}</b> 位顧客都有的所有序列樣式。`;
                case 'count': {
                    const ok = s.exts.map(e => pt(e.k === 'i' ? [...s.prefix.slice(0, -1), [...s.prefix[s.prefix.length - 1], e.x]] : [...s.prefix, [e.x]]));
                    if (!s.prefix.length) {
                        return `第一次掃描：數每個商品有幾位顧客買過（不管買幾次都只算一次），看最右邊那一欄。` +
                            (ok.length ? `至少 ${minSup} 人的是 ${ok.join(' ')}，每一個都當成一個<b>前綴</b>，一個一個往下挖。` : `沒有任何商品達到 ${minSup} 人，什麼都找不到。`);
                    }
                    const last = s.prefix[s.prefix.length - 1];
                    let txt = `前綴 ${pt(s.prefix)} 的<b>投影資料庫</b>：只剩 ${s.proj.length} 位顧客，淡掉的是前綴用掉的部分。數兩種接法：` +
                        `<b>同一次</b>（跟 ${esc(elText(last))} 同一次買、排在後面的，就是底線 _ 那格）和<b>下一次以後</b>（投影點之後任何一次）。`;
                    if (s.special.length) {
                        const sp = s.special[0];
                        txt += `注意${NAMES[sp.sid]}：底線那格沒有 ${sp.items.map(emo).join('')}，但後面某次又買齊了 ${esc(elText(last))}（青色虛線框），所以同一次的 ${sp.items.map(emo).join('')} 也算${NAMES[sp.sid]}一份。`;
                    }
                    txt += ok.length ? `夠 ${minSup} 人的：${ok.join(' ')}。` : `沒有任何接法達到 ${minSup} 人，${pt(s.prefix)} 不能再長了，回到上一層。`;
                    return txt;
                }
                case 'extend': {
                    const x = emo(s.ext.x);
                    let txt = s.back ? `回到前綴 ${s.prefix.length ? pt(s.prefix) : '（空的）'}，換下一個。` : '';
                    if (!s.prefix.length) {
                        txt += `前綴 ${pt(s.pattern)}：${s.sup} 位顧客買過 ${x}，記下來。把每個人的投影點放在<b>第一次</b>買 ${x} 的地方（橘框），後面剩下的就是投影資料庫。`;
                    } else if (s.ext.k === 'i') {
                        txt += `<b>同一次延伸</b>：把 ${x} 放進最後一次 → ${pt(s.pattern)}，${s.sup} 人，記下來。投影點移到同一次裡的 ${x}（橘框）` +
                            (s.moved.length ? `；${names(s.moved)}要跳到後面那次買齊的地方` : '') + `。`;
                    } else {
                        txt += `<b>下一次延伸</b>：之後某一次買 ${x} → ${pt(s.pattern)}，${s.sup} 人，記下來。投影點移到投影點之後第一次買 ${x} 的地方（橘框）。`;
                    }
                    if (s.dropped.length) txt += `${names(s.dropped)}接不上，拿掉。`;
                    return txt + `接著用這個更小的投影資料庫遞迴。`;
                }
                case 'end': {
                    return `完成！共找到 <b>${s.result.length}</b> 個頻繁序列樣式。過程中建了 ${s.stats.projs} 個投影資料庫，每往下一層都只剩前綴後面的部分；` +
                        `暴力法要把所有顧客可能的子序列（${bruteCandidates(s.seqs)} 種）一個一個拿去比對。`;
                }
            }
            return '';
        }

        const CODE_TAGS = s => ({
            start: ['start'],
            count: s.prefix && s.prefix.length ? ['scan', 'iscan'] : ['scan'],
            extend: s.ext ? [s.ext.k === 'i' ? 'iext' : 'sext', 'loop', 'project'] : [],
            end: ['end']
        })[s.kind] || [];

        /* ---------- 序列資料庫 ---------- */
        function drawCrumbs(s) {
            const box = $('crumbs');
            const crumbs = s.crumbs.length ? s.crumbs : [[]];
            box.innerHTML = '前綴：' + crumbs.map((c, i) =>
                `<span class="crumb${i === crumbs.length - 1 ? ' cur' : ''}">${c.length ? esc(patText(c)) : '空的'}</span>`).join('<span class="arrow">›</span>');
        }

        function drawSeqs(s) {
            const box = $('seqs');
            box.innerHTML = '';
            const projOf = {};
            s.proj.forEach(pr => { projOf[pr.sid] = pr; });
            const pickSet = new Set(picked && s.counts ? (s.counts.who[picked.k][picked.x] || []) : []);
            const showPost = s.prefix.length > 0 || s.kind === 'extend';
            $('seq-title').textContent = s.kind === 'start' || s.kind === 'end' || (s.kind === 'count' && !s.prefix.length) ? '序列資料庫' :
                `投影資料庫：前綴 ${patText(s.kind === 'extend' ? s.pattern : s.prefix)}`;
            s.seqs.forEach((seq, sid) => {
                const pr = projOf[sid];
                const row = document.createElement('div');
                row.className = 'srow' + (pr ? '' : ' gone') + (pickSet.has(sid) ? ' pick' : '');
                const who = document.createElement('span');
                who.className = 'who';
                who.textContent = NAMES[sid];
                row.appendChild(who);
                const vis = document.createElement('div');
                vis.className = 'visits';
                const also = new Set((s.kind === 'count' && s.also && s.also[sid]) || []);
                let post = '';
                seq.forEach((e, k) => {
                    if (k) { const a = document.createElement('span'); a.className = 'arrow'; a.textContent = '›'; vis.appendChild(a); }
                    const v = document.createElement('span');
                    v.className = 'visit';
                    if (pr && k < pr.e) v.classList.add('past');
                    if (also.has(k)) v.classList.add('also');
                    let under = false;
                    e.forEach((x, j) => {
                        const it = document.createElement('span');
                        it.className = 'it';
                        it.title = x;
                        if (pr && k === pr.e) {
                            if (j < pr.p) it.classList.add('used');
                            else if (j === pr.p) { it.classList.add('anchor'); if (s.kind === 'extend') it.classList.add('new'); }
                            else {
                                if (!under) { const u = document.createElement('span'); u.className = 'us'; u.textContent = '_'; v.appendChild(u); under = true; }
                                it.classList.add('under');
                            }
                        }
                        it.textContent = emo(x);
                        v.appendChild(it);
                    });
                    vis.appendChild(v);
                    if (pr && k === pr.e && pr.p < e.length - 1) post += '(_' + e.slice(pr.p + 1).map(emo).join('') + ')';
                    if (pr && k > pr.e) post += elText(e);
                });
                if (!seq.length) { const n = document.createElement('span'); n.className = 'mark'; n.textContent = '（沒有來店紀錄）'; vis.appendChild(n); }
                row.appendChild(vis);
                const mark = document.createElement('span');
                mark.className = 'mark';
                if (!pr && s.kind === 'extend' && s.dropped.includes(sid)) { mark.classList.add('drop'); mark.textContent = '✕ 接不上'; }
                else if (!pr) mark.textContent = '—';
                row.appendChild(mark);
                if (showPost && pr) {
                    const pd = document.createElement('div');
                    pd.className = 'post';
                    pd.textContent = '後綴 ' + (post || '（後面沒有了）');
                    row.appendChild(pd);
                }
                box.appendChild(row);
            });
        }

        /* 編輯模式：點一次來店選起來，再用下面的按鈕增減商品 */
        function drawEditor() {
            const box = $('seqs');
            box.innerHTML = '';
            $('seq-title').textContent = '編輯序列資料庫';
            db.forEach((seq, sid) => {
                const row = document.createElement('div');
                row.className = 'srow';
                const who = document.createElement('span');
                who.className = 'who';
                who.textContent = NAMES[sid];
                row.appendChild(who);
                const vis = document.createElement('div');
                vis.className = 'visits';
                seq.forEach((e, k) => {
                    if (k) { const a = document.createElement('span'); a.className = 'arrow'; a.textContent = '›'; vis.appendChild(a); }
                    const v = document.createElement('span');
                    v.className = 'visit' + (selVisit && selVisit[0] === sid && selVisit[1] === k ? ' sel' : '') + (e.length ? '' : ' empty');
                    v.dataset.sid = sid;
                    v.dataset.k = k;
                    v.textContent = e.length ? e.map(emo).join('') : '空';
                    vis.appendChild(v);
                });
                if (seq.length < MAX_VISITS) {
                    const add = document.createElement('button');
                    add.className = 'addv';
                    add.dataset.add = sid;
                    add.title = '加一次來店';
                    add.setAttribute('aria-label', `${NAMES[sid]} 加一次來店`);
                    add.textContent = '＋';
                    vis.appendChild(add);
                }
                row.appendChild(vis);
                const del = document.createElement('button');
                del.className = 'delc';
                del.dataset.del = sid;
                del.title = '刪除這位顧客';
                del.setAttribute('aria-label', `刪除${NAMES[sid]}`);
                del.textContent = '✕';
                row.appendChild(del);
                box.appendChild(row);
            });
            const pal = $('palette');
            if (!selVisit || !db[selVisit[0]] || !db[selVisit[0]][selVisit[1]]) {
                pal.innerHTML = '';
                pal.textContent = '點一個框（一次來店）來改裡面的商品；按 ＋ 幫那位顧客多加一次來店。';
                return;
            }
            const e = db[selVisit[0]][selVisit[1]];
            pal.innerHTML = '';
            const tip = document.createElement('div');
            tip.textContent = `${NAMES[selVisit[0]]} 第 ${selVisit[1] + 1} 次來店買了（最多 ${MAX_ITEMS} 樣）：`;
            pal.appendChild(tip);
            const opts = document.createElement('div');
            opts.className = 'opts';
            ITEMS.forEach(x => {
                const b = document.createElement('button');
                const on = e.includes(x);
                b.className = 'opt' + (on ? ' on' : '');
                b.dataset.item = x;
                b.disabled = !on && e.length >= MAX_ITEMS;
                b.textContent = `${emo(x)} ${x}`;
                opts.appendChild(b);
            });
            const rm = document.createElement('button');
            rm.className = 'opt';
            rm.dataset.rmv = '1';
            rm.textContent = '🗑 刪掉這次';
            opts.appendChild(rm);
            pal.appendChild(opts);
        }

        function cleanDb() { db = db.map(seq => normSeq(seq)); }

        function setEditing(on) {
            editing = on;
            selVisit = null;
            if (!on) cleanDb();
            $('seq-card').classList.toggle('editing', on);
            $('palette').hidden = !on;
            $('btn-add-cust').hidden = !on;
            $('btn-edit').textContent = on ? '✓ 編輯完成' : '✎ 編輯資料';
            $('legend').hidden = on;
            rebuild();
        }
        function dataChanged() {
            preset = -1;
            rebuild();
        }

        $('seqs').addEventListener('click', ev => {
            if (!editing) return;
            const v = ev.target.closest('.visit[data-sid]');
            const add = ev.target.closest('[data-add]');
            const del = ev.target.closest('[data-del]');
            if (v) {
                const sid = Number(v.dataset.sid);
                let k = Number(v.dataset.k);
                // 換選別的框時，剛剛那個如果還是空的就拿掉
                if (selVisit && !(selVisit[0] === sid && selVisit[1] === k) && db[selVisit[0]] && db[selVisit[0]][selVisit[1]] && !db[selVisit[0]][selVisit[1]].length) {
                    db[selVisit[0]].splice(selVisit[1], 1);
                    if (selVisit[0] === sid && selVisit[1] < k) k--;
                }
                selVisit = [sid, k];
                drawEditor();
            } else if (add) {
                const sid = Number(add.dataset.add);
                db[sid] = db[sid].filter(e => e.length);
                db[sid].push([]);
                selVisit = [sid, db[sid].length - 1];
                dataChanged();
            } else if (del) {
                db.splice(Number(del.dataset.del), 1);
                selVisit = null;
                dataChanged();
            }
        });
        $('palette').addEventListener('click', ev => {
            const b = ev.target.closest('button');
            if (!b || !selVisit) return;
            const [sid, k] = selVisit;
            if (b.dataset.rmv) {
                db[sid].splice(k, 1);
                selVisit = null;
            } else {
                const e = db[sid][k];
                const x = b.dataset.item;
                db[sid][k] = e.includes(x) ? e.filter(y => y !== x) : [...e, x].sort(cmp);
            }
            dataChanged();
        });
        $('btn-edit').addEventListener('click', () => setEditing(!editing));
        $('btn-add-cust').addEventListener('click', () => {
            if (db.length >= MAX_CUST) return;
            db.push([[ITEMS[0]]]);
            selVisit = [db.length - 1, 0];
            dataChanged();
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
                    db = p.db.map(normSeq);
                    minSup = p.sup;
                    if (editing) setEditing(false); else rebuild();
                });
                box.appendChild(b);
            });
            const r = document.createElement('button');
            r.className = 'btn small';
            r.textContent = '🎲 隨機';
            r.addEventListener('click', () => {
                preset = -1;
                const n = 5 + Math.floor(Math.random() * 2);
                db = Array.from({ length: n }, () => Array.from({ length: 2 + Math.floor(Math.random() * 3) }, () => {
                    const pool = ITEMS.slice();
                    return Array.from({ length: 1 + Math.floor(Math.random() * 3) }, () => pool.splice(Math.floor(Math.random() * pool.length), 1)[0]);
                })).map(normSeq);
                minSup = Math.min(minSup, db.length);
                if (editing) setEditing(false); else rebuild();
            });
            box.appendChild(r);
        }

        /* ---------- 計數表 ---------- */
        function drawCount(s) {
            const t = $('cnt');
            const hint = $('cnt-hint');
            const line = $('prefix-line');
            if (!s.counts) {
                line.innerHTML = s.kind === 'end' ? '全部挖完了。' : '還沒開始數。按「下一步」。';
                t.innerHTML = '';
                hint.textContent = '';
                return;
            }
            line.innerHTML = `目前的前綴：${s.prefix.length ? pt(s.prefix) : '<span class="pt">空的</span>（還沒選任何商品）'}`;
            const { cnt } = s.counts;
            const last = s.prefix.length ? s.prefix[s.prefix.length - 1] : null;
            const isDone = (x, k) => s.kind === 'extend' && s.done.some(d => d.x === x && d.k === k);
            const isCur = (x, k) => s.kind === 'extend' && s.ext.x === x && s.ext.k === k;
            const cell = (x, k) => {
                if (k === 'i' && !last) return '<td class="c na"><span>—</span></td>';
                if (k === 'i' && x <= last[last.length - 1]) return '<td class="c na"><span>—</span></td>';
                const n = cnt[k][x] || 0;
                const cls = ['c', n === 0 ? 'zero' : n >= minSup ? 'ok' : 'no', isDone(x, k) ? 'done' : '', isCur(x, k) ? 'cur' : '',
                    picked && picked.x === x && picked.k === k ? 'picked' : ''].join(' ');
                return `<td class="${cls}" data-x="${n ? x : ''}" data-k="${k}"><span>${n}</span></td>`;
            };
            t.innerHTML = `<thead><tr><th>商品</th><th>同一次<small>i-延伸 (…x)</small></th><th>下一次以後<small>s-延伸 (…)(x)</small></th></tr></thead><tbody>` +
                ITEMS.slice().sort(cmp).map(x => `<tr><td class="nm">${emo(x)} ${x}</td>${cell(x, 'i')}${cell(x, 's')}</tr>`).join('') + '</tbody>';
            if (picked && s.counts.who[picked.k][picked.x]) {
                const pat = picked.k === 'i' ? [...s.prefix.slice(0, -1), [...last, picked.x]] : [...s.prefix, [picked.x]];
                hint.innerHTML = `${pt(pat)}：${esc(names(s.counts.who[picked.k][picked.x]))}（序列資料庫裡亮起來的列）`;
            } else {
                hint.textContent = `綠框＝至少 ${minSup} 人，可以接；「—」是同一次裡只能往字碼比較大的商品接（避免同一個樣式被找兩次）。點數字看是哪幾位顧客。`;
            }
        }
        $('cnt').addEventListener('click', ev => {
            const td = ev.target.closest('td[data-x]');
            if (!td || !td.dataset.x) return;
            const x = td.dataset.x, k = td.dataset.k;
            picked = picked && picked.x === x && picked.k === k ? null : { x, k };
            const s = trace[cursor];
            drawCount(s);
            drawSeqs(s);
        });

        /* ---------- 結果 ---------- */
        /* 結果清單：一步一步往後走時，清單只會在後面多幾個，所以只補新的、改「剛找到」的外框，
           不用每一步整排重畫（樣式多時重畫很慢，量區塊高度時也要畫每一步）。往回走或換資料才整排重畫。 */
        let resultDrawn = null;
        function drawResult(s) {
            const box = $('levels');
            const keys = s.result.map(r => patText(r.pat) + '|' + r.sup);
            const d = resultDrawn;
            const grow = d && d.seqs === s.seqs && d.els.length && d.els.length <= keys.length && box.isConnected &&
                d.keys.every((k, i) => k === keys[i]);
            if (!grow) {
                box.innerHTML = '';
                if (!s.result.length) box.innerHTML = '<div class="empty">還沒有，開始挖之後會出現在這裡。</div>';
                resultDrawn = { seqs: s.seqs, keys: [], els: [], rows: {} };
                $('compare').innerHTML = `同一份資料如果用暴力法，要把每位顧客所有可能的子序列都列出來（共 <b>${bruteCandidates(s.seqs)}</b> 種不同的候選），每一種都拿去跟 ${s.seqs.length} 位顧客比對。`;
            }
            const st = resultDrawn;
            for (let i = st.els.length; i < s.result.length; i++) {
                const r = s.result[i];
                const n = r.pat.reduce((a, e) => a + e.length, 0);
                let row = st.rows[n];
                if (!row) {
                    row = document.createElement('div');
                    row.className = 'level';
                    row.dataset.n = n;
                    row.innerHTML = `<span class="tag">${n} 個</span><div class="items"></div>`;
                    const after = [...box.children].find(x => Number(x.dataset.n) > n);
                    box.insertBefore(row, after || null);
                    st.rows[n] = row;
                }
                const p = document.createElement('span');
                p.className = 'pat';
                p.innerHTML = `<span></span><span class="n">${r.sup}</span>`;
                p.firstChild.textContent = patText(r.pat);
                p.title = r.pat.map(e => e.join('+')).join(' → ');
                row.lastChild.appendChild(p);
                st.els.push(p);
                st.keys.push(keys[i]);
            }
            s.result.forEach((r, i) => st.els[i].classList.toggle('fresh', !!r.fresh));
            $('st-proj').textContent = s.stats.projs;
            $('st-cells').textContent = s.stats.cells;
            $('st-depth').textContent = s.stats.depth;
        }

        /* ---------- 程式碼 ---------- */
        const KW = {
            java: new Set('public static final for if return new boolean int void class import while else null this continue break'.split(' ')),
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
                }
                const target = (y0 + y1) / 2 - pre.clientHeight / 2;
                pre.scrollTo({ top: Math.max(0, Math.min(target, y0 - 8)), behavior: 'smooth' });
            }
            $('downloads').innerHTML = lang === 'java'
                ? '下載 <a href="code/PrefixSpan.java" download>PrefixSpan.java</a>　執行 <code>javac PrefixSpan.java && java PrefixSpan</code>'
                : '下載 <a href="code/prefixspan.py" download>prefixspan.py</a>　執行 <code>python3 prefixspan.py</code>';
        }

        /* ---------- 顯示某一步 ---------- */
        function showStep() {
            const s = trace[cursor];
            picked = null;
            $('explain').innerHTML = `<span class="step-no">步驟 ${cursor + 1} / ${trace.length}</span>${describe(s)}`;
            drawPresets();
            drawCrumbs(s);
            if (editing) drawEditor(); else drawSeqs(s);
            drawCount(s);
            drawResult(s);
            renderCode(CODE_TAGS(s));
            $('btn-prev').disabled = $('btn-first').disabled = cursor === 0 || editing;
            $('btn-next').disabled = cursor === trace.length - 1 || editing;
            $('btn-play').disabled = editing;
            $('sup-val').textContent = minSup;
            $('sup-minus').disabled = minSup <= 1;
            $('sup-plus').disabled = minSup >= Math.max(1, db.length);
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
            minSup = Math.max(1, Math.min(minSup, db.length || 1));
            trace = buildTrace(db, minSup);
            cursor = 0;
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
            const N = s.seqs.length;
            const extPat = (prefix, k, x) => k === 'i' ? [...prefix.slice(0, -1), [...prefix[prefix.length - 1], x]] : [...prefix, [x]];
            if (s.kind === 'count') {
                const { cnt } = s.counts;
                const cands = [...Object.keys(cnt.i).map(x => ({ x, k: 'i' })), ...Object.keys(cnt.s).map(x => ({ x, k: 's' }))];
                if (!cands.length) return null;
                if (!s.prefix.length) {
                    // 第一次掃描：支持度是「幾位顧客」，不是「買了幾次」
                    const c = quizPick(cands, rnd), x = c.x, n = cnt.s[x];
                    const times = s.seqs.reduce((a, seq) => a + seq.filter(e => e.includes(x)).length, 0);
                    return {
                        q: `第一次掃描：${emo(x)} 的支持度（有幾位顧客買過）是多少？`,
                        ...quizNums(n, 0, Math.max(N, times), rnd, [times]),
                        why: `有 ${n} 位顧客買過 ${emo(x)}，一共買了 ${times} 次；同一個人買好幾次也只算 1 人，所以是 ${n}。`,
                        ask: { type: 'support', pat: [[x]] }
                    };
                }
                const last = s.prefix[s.prefix.length - 1];
                if (cands.length >= 2 && rnd() < 0.4) {
                    // 哪幾種接法夠門檻（最多 4 個選項）
                    const pick = quizShuffle(cands, rnd).slice(0, 4).sort((a, b) => a.k === b.k ? cmp(a.x, b.x) : a.k === 'i' ? -1 : 1);
                    const keep = pick.map((c, k) => k).filter(k => cnt[pick[k].k][pick[k].x] >= minSup);
                    return {
                        q: `前綴 ${patText(s.prefix)} 的投影資料庫裡，哪幾種接法至少有 ${minSup} 人？（都不夠就直接按確定）`,
                        choices: pick.map(c => (c.k === 'i' ? '同一次 ' : '下一次 ') + emo(c.x)),
                        answer: keep, multi: true,
                        why: pick.map(c => `${c.k === 'i' ? '同一次' : '下一次'}${emo(c.x)} ${cnt[c.k][c.x]} 人`).join('、') + `；門檻 ${minSup}。`,
                        ask: { type: 'exts', prefix: s.prefix, opts: pick.map(c => extPat(s.prefix, c.k, c.x)) }
                    };
                }
                const c = quizPick(cands, rnd), x = c.x, n = cnt[c.k][x], pat = extPat(s.prefix, c.k, x);
                if (c.k === 'i') {
                    // 陷阱：只看底線那一格，忘了「後面某次又買齊前綴最後一次」也算同一次
                    const under = s.proj.filter(pr => s.seqs[pr.sid][pr.e].slice(pr.p + 1).includes(x)).length;
                    const later = cnt.s[x] || 0;
                    return {
                        q: `前綴 ${patText(s.prefix)}：跟 ${elText(last)} 同一次買 ${emo(x)}（接成 ${patText(pat)}）的有幾位顧客？`,
                        ...quizNums(n, 0, N, rnd, [under, later]),
                        why: under === n ? `投影點那一次（底線那格）還有 ${emo(x)} 的有 ${n} 位。`
                            : `底線那格有 ${emo(x)} 的只有 ${under} 位，但後面又買齊 ${elText(last)} 而且同一次也買了 ${emo(x)} 的也算，共 ${n} 位。`,
                        ask: { type: 'support', pat }
                    };
                }
                // 陷阱：把同一個人買好幾次都算進去；或忘了只能看投影點後面
                const times = s.proj.reduce((a, pr) => a + s.seqs[pr.sid].slice(pr.e + 1).filter(e => e.includes(x)).length, 0);
                const anywhere = s.proj.filter(pr => s.seqs[pr.sid].some(e => e.includes(x))).length;
                return {
                    q: `前綴 ${patText(s.prefix)}：投影點之後「下一次以後」買 ${emo(x)}（接成 ${patText(pat)}）的有幾位顧客？`,
                    ...quizNums(n, 0, Math.max(N, times), rnd, [times, anywhere]),
                    why: `只看投影點後面的部分，有 ${n} 位顧客之後還買過 ${emo(x)}` + (times !== n ? `（買了 ${times} 次，但一人只算一次）` : '') + `。`,
                    ask: { type: 'support', pat }
                };
            }
            if (s.kind === 'extend' && s.prefix.length && s.dropped.length && rnd() < 0.6) {
                // 延伸之後誰接不上、要從投影資料庫拿掉
                if (s.dropped.length > 3) return null;
                const keepSome = quizShuffle(s.proj.map(q => q.sid), rnd).slice(0, Math.max(1, 4 - s.dropped.length));
                const opts = [...s.dropped, ...keepSome].sort((a, b) => a - b);
                const mq = {
                    q: `延伸成 ${patText(s.pattern)} 之後，哪幾位顧客接不上、會從投影資料庫拿掉？`,
                    choices: opts.map(sid => NAMES[sid]),
                    answer: opts.map((sid, k) => k).filter(k => s.dropped.includes(opts[k])), multi: true,
                    why: `${names(s.dropped)}在投影點之後找不到能接成 ${patText(s.pattern)} 的地方；剩下 ${s.proj.length} 位（就是支持度 ${s.sup}）。`,
                    ask: { type: 'dropped', prefix: s.prefix, pat: s.pattern, sids: opts }
                };
                return mq;
            }
            return null;
        }

        function step(dir) {
            if (editing) return false;
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
            timer = setInterval(() => { if (!step(1)) stopAuto(); }, 2200);
        });
        document.addEventListener('keydown', e => {
            if (e.key === 'ArrowRight') { stopAuto(); step(1); }
            if (e.key === 'ArrowLeft') { stopAuto(); step(-1); }
        });
        $('sup-minus').addEventListener('click', () => { if (minSup > 1) { minSup--; rebuild(); } });
        $('sup-plus').addEventListener('click', () => { if (minSup < db.length) { minSup++; rebuild(); } });
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
