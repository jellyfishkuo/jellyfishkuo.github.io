<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/pretk.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/pretk-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/pretk-180.png">
    <title>PreTK 增量資料庫的 Top-K 高效益樣式</title>
    <meta name="description" content="一步一步看 PreTK（Knowledge-Based Systems 2025）怎麼在資料一批一批進來時找效益最高的前 k 名：樹上多存一些 Pre-large 候補，新的一批夠小就不用重挖，只更新樹；要重挖時用 S1、S2（GLIU）、S4 把門檻先拉高。Java 與 Python 程式碼逐行對照。">
    <meta property="og:type" content="website">
    <meta property="og:site_name" content="果汁龍的網站">
    <meta property="og:locale" content="zh_TW">
    <meta property="og:title" content="PreTK 增量資料庫的 Top-K 高效益樣式">
    <meta property="og:description" content="一步一步看 PreTK（Knowledge-Based Systems 2025）怎麼在資料一批一批進來時找效益最高的前 k 名：樹上多存一些 Pre-large 候補，新的一批夠小就不用重挖，只更新樹；要重挖時用 S1、S2（GLIU）、S4 把門檻先拉高。Java 與 Python 程式碼逐行對照。">
    <meta property="og:url" content="https://jellyfishkuo.github.io/research/pretk.html">
    <meta property="og:image" content="https://jellyfishkuo.github.io/assets/og/research-pretk.jpg">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta name="twitter:card" content="summary_large_image">
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

        /* 手機：一欄，依序 步驟 → 門檻 → 樹 → 交易 → 程式碼 → 結果
           電腦：左欄 步驟／門檻／交易，右欄 樹／程式碼／結果 */
        .layout { display: grid; gap: 1rem; margin-top: 1.3rem; align-items: start; }
        .col { display: contents; }
        .layout .card { min-width: 0; }
        .a-step { order: 1; }
        .a-gate { order: 2; }
        .a-tree { order: 3; }
        .a-data { order: 4; }
        .a-code { order: 5; }
        .a-result { order: 6; }
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
        .paper p { color: var(--lt-c6c6d6, #c6c6d6); font-size: 0.92rem; margin-top: 0.4rem; }
        .paper .cite { font-size: 0.88rem; color: var(--text); border-left: 3px solid var(--accent); padding-left: 0.7rem; }
        .paper .cite a { color: var(--accent2); word-break: break-all; }

        /* ── 交易資料庫：一批一批進來 ── */
        .db tr.bh td { font: 700 0.72rem 'Space Mono', monospace; color: var(--accent2); text-align: left; padding: 0.5rem 0.3rem 0.1rem; }
        .db tr.bh td .bn { color: var(--muted); font: 0.72rem inherit; font-family: inherit; font-weight: 400; margin-left: 0.4rem; }
        .db tr.bh.later td { color: var(--muted); opacity: 0.55; }
        .db tr.bh.cur td { color: var(--warn); }
        .db tfoot tr.bt td { color: var(--warn); }
        .db tfoot td.mx { background: var(--lt-f59e0b-22, rgba(245, 158, 11, 0.22)); border-radius: 6px; }
        .db tfoot tr.su td { color: var(--lt-86efac, #86efac); }

        /* ── 門檻與重挖判斷 ── */
        .gate-sub { color: var(--muted); font-size: 0.8rem; }
        .gauge { position: relative; height: 26px; background: var(--lt-0a0a14, #0a0a14); border: 1px solid var(--border); border-radius: 8px; overflow: hidden; margin-top: 0.4rem; }
        .gauge .seg { position: absolute; top: 0; bottom: 0; }
        .gauge .base { left: 0; background: var(--lt-4a4a6a, #4a4a6a); }
        .gauge .grow { background: var(--lt-f59e0b-70, rgba(245, 158, 11, 0.7)); }
        .gauge .grow.over { background: var(--lt-f87171-70, rgba(248, 113, 113, 0.7)); }
        .gauge .mk { position: absolute; top: -1px; bottom: -1px; width: 3px; margin-left: -1px; background: var(--good); }
        .gauge .mk.low { background: var(--accent2); width: 2px; }
        .g-legend { display: flex; flex-wrap: wrap; gap: 0.2rem 0.9rem; font-size: 0.75rem; color: var(--muted); margin-top: 0.4rem; }
        .g-legend i { display: inline-block; width: 11px; height: 11px; border-radius: 3px; margin-right: 0.3rem; vertical-align: -1px; }
        .verdict { margin-top: 0.6rem; font-size: 0.88rem; padding: 0.45rem 0.6rem; border-radius: 8px; background: var(--panel-2); border-left: 3px solid var(--border); }
        .verdict b { font-family: 'Space Mono', monospace; }
        .verdict.ok { border-left-color: var(--good); }
        .verdict.no { border-left-color: var(--bad); }
        .verdict .tag { font-weight: 700; }
        .verdict.ok .tag { color: var(--lt-86efac, #86efac); }
        .verdict.no .tag { color: var(--lt-fca5a5, #fca5a5); }
        .verdict .paper-line { display: block; color: var(--muted); font-size: 0.78rem; margin-top: 0.2rem; }
        .stats.g4 { margin-top: 0.7rem; }
        .stat.win { box-shadow: 0 0 0 2px var(--warn) inset; }
        .stat .k b { color: var(--text); font-weight: 600; }
        .chips { display: flex; flex-wrap: wrap; gap: 0.3rem; margin-top: 0.35rem; }
        .chip { font-size: 0.78rem; border: 1px solid var(--border); border-radius: 7px; padding: 0.06rem 0.45rem; white-space: nowrap; }
        .chip small { font: 700 0.72rem 'Space Mono', monospace; color: var(--muted); margin-left: 0.3rem; }
        .chip.kth { border-color: var(--warn); }
        .chip.kth small { color: var(--warn); }
        .chip.off { opacity: 0.45; text-decoration: line-through; }
        .chip.arrow { border: none; padding: 0; color: var(--muted); }
        .gate-h { font-size: 0.82rem; color: var(--lt-c6c6d6, #c6c6d6); margin-top: 0.75rem; }
        .gate-h b { color: var(--text); }
        .climb { font: 700 0.9rem 'Space Mono', monospace; margin-top: 0.3rem; overflow-wrap: anywhere; }
        .climb span { color: var(--muted); font-weight: 400; }

        /* ── itemset-tree（排行榜） ── */
        .rank { width: 100%; border-collapse: collapse; font-size: 0.84rem; table-layout: fixed; }
        .rank th { color: var(--muted); font-weight: 400; font-size: 0.72rem; text-align: left; padding: 0 0.3rem 0.25rem; }
        .rank td { padding: 0.24rem 0.3rem; border-bottom: 1px solid var(--border); vertical-align: middle; }
        .rank th.no, .rank td.no { width: 1.9rem; }
        .rank th.u, .rank td.u { width: 5.6rem; text-align: right; }
        .rank th.tg, .rank td.tg { width: 4.6rem; text-align: center; }
        .rank td.no { font: 0.72rem 'Space Mono', monospace; color: var(--muted); }
        .rank td.set { overflow-wrap: anywhere; line-height: 1.3; }
        .rank td.set .nm { color: var(--muted); font-size: 0.72rem; margin-left: 0.25rem; }
        .rank td.u { font: 700 0.84rem 'Space Mono', monospace; white-space: nowrap; }
        .rank td.u small { display: block; font-size: 0.68rem; font-weight: 400; color: var(--lt-86efac, #86efac); }
        .rank td.u small.z { color: var(--muted); }
        .rank tr.edge td { border-bottom: 2px dashed var(--warn); }
        .rank tr.hot td { background: var(--lt-f59e0b-12, rgba(245, 158, 11, 0.12)); }
        .badge { display: inline-block; font-size: 0.7rem; border-radius: 5px; padding: 0 0.35rem; line-height: 1.5; }
        .badge.L { background: var(--lt-22c55e-22, rgba(34, 197, 94, 0.22)); color: var(--lt-86efac, #86efac); }
        .badge.P { background: var(--lt-06b6d4-15, rgba(6, 182, 212, 0.15)); color: var(--lt-67e8f9, #67e8f9); }
        .badge.S { background: var(--lt-23233d, #23233d); color: var(--muted); }
        .mv { display: block; font-size: 0.66rem; line-height: 1.2; }
        .mv.up { color: var(--lt-86efac, #86efac); }
        .mv.down { color: var(--lt-fca5a5, #fca5a5); }
        .mv.new { color: var(--warn); }
        .rank tr.small td { color: var(--muted); border-bottom: none; font-size: 0.8rem; }
        .rank tr.small td.u { font-weight: 400; }
        .tree-empty { color: var(--muted); font-size: 0.85rem; padding: 1.5rem 0.5rem; text-align: center; }
        .dropped { font-size: 0.78rem; color: var(--muted); margin-top: 0.5rem; }
        .ans { display: flex; flex-wrap: wrap; gap: 0.35rem; margin-top: 0.2rem; min-height: 1.8rem; }
        .paper .diff { border: 1px dashed var(--lt-f59e0b-60, rgba(245, 158, 11, 0.6)); border-radius: 10px; padding: 0.5rem 0.75rem; margin-top: 0.6rem; }
    </style>
    <link rel="stylesheet" href="../assets/theme.css">
</head>

<body>
    <div class="wrap">
        <a class="back" href="../index.html#research">← RETURN TO PORTFOLIO</a>
        <div class="kicker">RESEARCH DEMO · PAPER · INCREMENTAL TOP-K HIGH-UTILITY MINING</div>
        <h1>PreTK 增量資料庫的 Top-K<small>樹上多存幾名候補，新的一批夠小就不用重挖</small></h1>
        <p class="intro">
            <a href="top-k-hui.html">Top-K</a> 不用設門檻、直接找效益最高的前 k 名，但它假設資料庫是固定的。超商的交易是<b>一批一批進來</b>的：
            每來一批都從頭挖一次，舊資料就一直被重算。這篇 2025 年的論文把 <a href="incremental.html">FUP</a> 系列的 <b>pre-large</b> 想法搬到 top-k：
            挖的時候多找幾名，前 k<sub>lower</sub> 名是答案（<b>Large</b>），後面到第 k<sub>upper</sub> 名當候補（<b>Pre-large</b>），一起存在 itemset-tree 上。
            新的一批進來時，只要它<b>小到樹外的組合不可能擠進前 k<sub>lower</sub> 名</b>，就只把新交易的效益加到樹上，不用重挖；
            真的要重挖時，再用好幾種方法先把門檻拉高、少走冤枉路。跟 <a href="ihup.html">IHUP</a> 一樣是增量的高效益樣式，但 IHUP 要自己給門檻。
            資料用超商的 8 筆交易當原始資料庫，後面再進來 4 小批；也可以切成論文裡的範例。
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
                            <button data-ds="shop" class="active">超商 D＋4 批</button>
                            <button data-ds="paper">論文範例</button>
                        </div>
                    </div>
                    <div class="mu">
                        <span>答案要前 k<sub>lower</sub> =</span>
                        <button class="btn stepper" id="kl-minus" aria-label="減少 k lower">−</button>
                        <span class="val" id="kl-val">3</span>
                        <button class="btn stepper" id="kl-plus" aria-label="增加 k lower">+</button>
                        <span>名</span>
                    </div>
                    <div class="mu">
                        <span>樹上存到第 k<sub>upper</sub> =</span>
                        <button class="btn stepper" id="ku-minus" aria-label="減少 k upper">−</button>
                        <span class="val" id="ku-val">10</span>
                        <button class="btn stepper" id="ku-plus" aria-label="增加 k upper">+</button>
                        <span>名</span>
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

                <div class="card a-gate">
                    <div class="card-head"><h2 id="gate-title">門檻與重挖判斷</h2><span class="sub" id="gate-sub"></span></div>
                    <div id="gate"></div>
                </div>

                <div class="card a-data">
                    <div class="card-head"><h2>交易資料庫</h2><span class="sub" id="db-sub"></span></div>
                    <table class="db" id="db"></table>
                    <p class="db-note">格子裡是購買數量，商品下面是單位利潤；TU 是這筆交易的總效益。淡色的批次還沒進來。
                        最下面：<b>單品效益</b>是這個商品到目前為止的效益、<b>TWU</b> 是有它的交易 TU 加起來、<b>這批 TWU</b> 只算剛進來的這一批（橘底是最大的）。</p>
                </div>
            </div>

            <div class="col">
                <div class="card a-tree">
                    <div class="card-head"><h2>itemset-tree 上的組合</h2><span class="sub" id="tree-sub"></span></div>
                    <div id="tree"></div>
                    <p class="legend" style="margin-top:0.55rem">論文把這些組合存成一棵前綴樹（共用前面的商品），這裡攤平成排行榜比較好看。橘色虛線上面是 Large（答案），下面是 Pre-large（候補）；
                        最下面一列是「不在樹上的組合（Small）」效益最多是多少。</p>
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
                    <h2>目前的答案（前 <span id="res-k">3</span> 名）</h2>
                    <div class="ans" id="ans"></div>
                    <div class="stats">
                        <div class="stat"><div class="v" id="st-batch">0</div><div class="k">已經讀進來的批次</div></div>
                        <div class="stat"><div class="v" id="st-remine">0</div><div class="k">PreTK 重新挖掘次數</div></div>
                        <div class="stat"><div class="v" id="st-check">0</div><div class="k">PreTK 檢查過的組合</div></div>
                        <div class="stat"><div class="v" id="st-ithui">0</div><div class="k">每批都重挖（ITHUI）要檢查的組合</div></div>
                    </div>
                    <p class="legend" style="margin-top:0.55rem">ITHUI 是論文拿來比較的方法：每批都從 Global-Utility-List 重挖前 k<sub>lower</sub> 名。PreTK 每次挖要多找到第 k<sub>upper</sub> 名，挖一次比較貴，但不用每批都挖。</p>
                </div>
            </div>
        </div>

        <div class="notes" style="grid-template-columns:minmax(0, 1fr)">
            <div class="card paper">
                <h2>📄 論文</h2>
                <p class="cite">N.T. Tung, Loan T.T. Nguyen, Trinh D.D. Nguyen, Bao Huynh.
                    <b>Efficient mining top-k high utility itemsets in incremental databases based on threshold raising strategies and pre-large concept.</b>
                    <i>Knowledge-Based Systems</i>, Vol. 315, Article 113273, 2025.
                    DOI：<a href="https://doi.org/10.1016/j.knosys.2025.113273" target="_blank" rel="noopener">10.1016/j.knosys.2025.113273</a></p>
                <p><b>它在解決什麼：</b>增量資料庫上的 top-k 高效益樣式。之前的 ITHUI 每進來一批就整個重挖一次；PreTK 想辦法讓大部分的批次<b>不用重挖</b>，要重挖時也挖得比較快。</p>
                <p><b>四個重點：</b>（1）<b>Global-Utility-List</b>＋<b>Global-TWU-Map</b>（沿用 LIHUP）：讀過的交易都記在每個商品的 list 裡，重挖時從這裡重建 utility list，不回頭掃舊資料；
                    （2）<b>top-k 版的 pre-large</b>：兩個 k，前 k<sub>lower</sub> 名是 Large、到第 k<sub>upper</sub> 名是 Pre-large，都存進 itemset-tree；
                    （3）<b>重挖條件</b>（定理 1）：新的一批裡每個商品的 TWU 都小於 minU<sub>upper</sub> − minU<sub>lower</sub> 時，原本在樹外的組合不可能變成 Large，只要把這批的效益加到樹上；
                    （4）<b>門檻拉高</b>：S1 第 k 大的單一商品、S2 GLIU（照 TWU 排好後連在一起的一段商品）、S3 挖的過程中 PQ 的第 k 名，加上這篇新提的 <b>S4：沿用上次挖掘的門檻</b>——資料只會變多，第 k 名的效益不會變小。</p>
                <p><b>實驗結果：</b>在 Accidents、Connect（稠密）和 Chainstore、Fruithut（稀疏）上跟 ITHUI 比，每次都比較快：不用重挖的批次通常一秒內就更新完；
                    要重挖時因為有 S4，起始門檻比較高，稠密資料上差最多。稀疏資料上大約可以連續更新樹 5 次才需要重挖。論文也量了「多次不重挖之後」門檻的準確度，大約 99%～100%。</p>
                <div class="diff">
                    <p style="margin-top:0"><b>這頁的實作跟論文不一樣的地方：</b>論文每一批都拿「上次挖掘時」的 minU<sub>upper</sub> − minU<sub>lower</sub> 來比。
                        第一批這樣是對的；可是如果<b>連續好幾批都沒重挖</b>，樹外的組合每一批都可能長一點，只看單批會漏掉累積起來的量。
                        用隨機資料跟暴力法比對，照論文原式做，3000 組裡有 21 組在連續兩批以上沒重挖之後，算出來的前 k<sub>lower</sub> 名跟真正的答案不一樣（每一批單獨看都很小，但好幾批加起來，原本在樹外的組合就擠進前面了）。所以這頁把條件改成<b>累積的上界</b>：
                        「樹外上限」＝上次挖掘時的 minU<sub>lower</sub>＋之後每一批的 max TWU，跟目前樹上的第 k<sub>lower</sub> 名比；第一批時兩者完全一樣。
                        這樣改了之後，同樣 3000 組（加上網頁 JS 另外 300 組）都跟暴力法一致（論文自己的實驗也提到多次更新後準確度是 99% 左右，而不是 100%）。</p>
                    <p>其他簡化：GLIU 只用「連續一段商品」的真正效益，沒有再算論文的低估效益 UE；樹用排行榜呈現；不重挖時順便用樹上的第 k<sub>upper</sub> 名更新 minU<sub>lower</sub>（樹上的數字都是真的效益，當 S4 一樣安全）。
                        切到「論文範例」、k<sub>upper</sub> = 10、k<sub>lower</sub> = 5 時，三個階段的 Large、Pre-large 和論文的圖 10～12 一樣；k = 5 時 D 的 GLIU 第 5 大是 28，也跟論文一樣。</p>
                </div>
                <p><b>跟網站上其他 Demo 的關係：</b>挖掘本身就是 <a href="top-k-hui.html">Top-K</a>（utility list＋邊挖邊拉高門檻，utility list 來自 <a href="high-utility.html">HUI-Miner</a>）；
                    「多存一層候補、新資料夠小就不重挖」來自 <a href="incremental.html">FUP</a> 系列的 pre-large 想法；同樣處理增量高效益樣式的還有 <a href="ihup.html">IHUP</a>（要設門檻、用樹存 TWU）。</p>
            </div>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼不重挖也算得對？</h2>
                <ul>
                    <li><b>一個組合在新的一批最多長多少：</b>它在這批的效益，不會超過它在這批的 TWU，也就不會超過它<b>任何一個商品</b>在這批的 TWU。所以「這批的 max TWU」是所有組合的共同上限，一個數就夠了。</li>
                    <li><b>樹外的組合有多大：</b>剛挖完時，沒進樹的組合效益都不超過第 k<sub>upper</sub> 名 minU<sub>lower</sub>；之後每一批最多再加 max TWU。樹上的組合則是每一批都照實加上去，所以它們的效益是精確的。</li>
                    <li><b>擠不進前 k<sub>lower</sub> 名：</b>樹外上限＋這批 max TWU 還是小於樹上第 k<sub>lower</sub> 名，那樹外沒有任何組合追得上；前 k<sub>lower</sub> 名一定都在樹上，排一下就是答案。差距 k<sub>upper</sub> − k<sub>lower</sub> 越大，minU<sub>upper</sub> − minU<sub>lower</sub> 通常越大，能撐越多批。</li>
                    <li><b>S4 為什麼安全：</b>交易只會增加，每個組合的效益只會變大。上次樹上的 k<sub>upper</sub> 個組合現在都至少還有原本的效益，所以真正的第 k<sub>upper</sub> 名不會低於上次的 minU<sub>lower</sub>，拿它當起始門檻不會剪掉答案。</li>
                </ul>
            </div>
            <div class="card">
                <h2>優缺點，以及跟實驗室研究的關係</h2>
                <ul>
                    <li><b>省下的：</b>每批都小、或 k<sub>upper</sub> 設得比較大時，大部分批次只要把新交易對一下樹上的 k<sub>upper</sub> 個組合，完全不用搜尋。重挖時有 S4，起始門檻比只用 S1、S2 高很多。</li>
                    <li><b>多付的：</b>每次挖都要找到第 k<sub>upper</sub> 名，門檻比較低、搜尋比較大；Global-Utility-List 要把所有交易一直留在記憶體裡（論文最後也把「記憶體不夠時怎麼辦」列為未來方向）。新的一批只要有一個很賺的商品，max TWU 就很大，馬上要重挖。</li>
                    <li><b>可以想的題目：</b>max TWU 是很鬆的上界，換成更緊的（例如只看樹外組合真的可能出現的商品）就能少重挖幾次；論文也提到重挖時只看新一批出現的商品、縮小搜尋空間。
                        刪除交易、滑動視窗（見 <a href="sliding-window.html">滑動視窗</a>）時效益會變小，S4 和這個條件都不能直接用，要重新想。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           PreTK 一步一步看
           網頁裡用 JavaScript 照著同樣的流程跑一次，把每一批的每個階段記下來；
           右邊的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = /*CODE_JSON*/null;

        const DATASETS = {
            shop: {
                ITEMS: ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片'],
                EMOJI: { '咖啡': '☕', '麵包': '🍞', '牛奶': '🥛', '飯糰': '🍙', '茶葉蛋': '🥚', '洋芋片': '🥔' },
                PROFIT: { '咖啡': 30, '麵包': 15, '牛奶': 20, '飯糰': 10, '茶葉蛋': 5, '洋芋片': 25 },
                /* 原始資料庫 D 是其他高效益 Demo 用的同一份 8 筆交易，後面再進來 4 小批 */
                BATCHES: [
                    [{ '咖啡': 4, '麵包': 2, '牛奶': 2 },
                     { '咖啡': 3, '麵包': 5, '茶葉蛋': 4 },
                     { '咖啡': 1, '麵包': 1, '牛奶': 2, '飯糰': 2 },
                     { '麵包': 3, '牛奶': 4, '洋芋片': 5 },
                     { '咖啡': 3, '牛奶': 2, '茶葉蛋': 2 },
                     { '咖啡': 1, '麵包': 2, '牛奶': 1, '茶葉蛋': 1 },
                     { '飯糰': 1, '茶葉蛋': 2, '洋芋片': 2 },
                     { '咖啡': 1, '麵包': 2, '飯糰': 1 }],
                    [{ '咖啡': 1, '麵包': 2, '牛奶': 1 }],
                    [{ '麵包': 2, '茶葉蛋': 2 }],
                    [{ '咖啡': 2, '牛奶': 2 }],
                    [{ '飯糰': 1, '茶葉蛋': 1 }]
                ],
                kl: 3, ku: 10
            },
            /* 論文的表 2（數量）、表 3（單位利潤）：D = T1–T4，ID1 = T5–T6，ID2 = T7–T8；k_upper = 10、k_lower = 5 時答案是圖 10～12 */
            paper: {
                ITEMS: ['A', 'B', 'C', 'D', 'E', 'F'],
                EMOJI: {},
                PROFIT: { A: 3, B: 4, C: 1, D: 2, E: 5, F: 4 },
                BATCHES: [
                    [{ A: 5, B: 1, C: 4, D: 1 }, { A: 2, C: 1 }, { C: 1, F: 3 }, { A: 3, B: 2, D: 3, F: 5 }],
                    [{ A: 2, B: 3, F: 4 }, { A: 5, B: 1, C: 4, D: 2, E: 1 }],
                    [{ A: 2, B: 2, C: 2, E: 1, F: 3 }, { A: 2, E: 1, F: 5 }]
                ],
                kl: 5, ku: 10
            }
        };
        const KL_MAX = 8, KU_MAX = 16;
        let dsKey = 'shop', ITEMS, EMOJI, PROFIT, BATCHES, DB, BATCH_OF, kLower, kUpper;
        function useDataset(k) {
            const d = DATASETS[k];
            dsKey = k;
            ({ ITEMS, EMOJI, PROFIT, BATCHES } = d);
            kLower = d.kl; kUpper = d.ku;
            DB = [].concat(...BATCHES);
            BATCH_OF = [].concat(...BATCHES.map((b, i) => b.map(() => i)));
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
        const has = (t, item) => Object.prototype.hasOwnProperty.call(t, item);
        const sym = i => EMOJI[i] || i;
        const tName = tid => 'T' + (tid + 1);
        const bName = b => (b === 0 ? 'D' : 'ID' + b);
        /* 顯示時照商品表的順序排（程式裡同分是照名稱排，跟 Java / Python 一樣） */
        const disp = items => items.slice().sort((a, b) => ITEMS.indexOf(a) - ITEMS.indexOf(b));
        const plain = items => '{' + disp(items).join(', ') + '}';
        const fmt = items => esc(plain(items));
        const kth = (vals, k) => { const v = vals.slice().sort((a, b) => b - a); return v.length >= k ? v[k - 1] : 0; };
        function cmpArr(x, y) {
            for (let i = 0; i < x.length; i++) { const c = cmp(x[i], y[i]); if (c) return c; }
            return 0;
        }
        /* 排名：效益高的在前；同分時短的在前，再照商品名稱（三種語言同一個順序） */
        const rankCmp = (a, b) => b.u - a.u || a.items.length - b.items.length || cmpArr(a.items, b.items);
        const keyOf = items => items.join('\u0001');

        /* ---------- 挖掘：utility list ＋ 邊挖邊拉高門檻（跟 Top-K 頁一樣） ---------- */
        function mineCore(gul, gtwu, n, k, init) {
            const byTwu = (a, b) => gtwu[a] - gtwu[b] || cmp(a, b);
            const all = [...gul.keys()].sort(byTwu);
            const order = all.filter(i => gtwu[i] >= init), removed = all.filter(i => gtwu[i] < init);
            const rua = new Array(n).fill(0);            // Remaining Utility Array
            const lists = [];
            for (let j = order.length - 1; j >= 0; j--) {
                const ul = { items: [order[j]], e: new Map(), iu: 0, ru: 0 };
                gul.get(order[j]).forEach(([tid, u]) => { ul.e.set(tid, [u, rua[tid]]); ul.iu += u; ul.ru += rua[tid]; rua[tid] += u; });
                lists.unshift(ul);
            }
            const st = { mu: init, heap: [], res: new Map(), checked: 0, pruned: 0, raises: [init] };
            const offer = (items, u) => {
                const key = items.slice().sort(cmp);
                st.res.set(keyOf(key), { items: key, u });
                st.heap.push(u);
                st.heap.sort((a, b) => a - b);
                if (st.heap.length > k) st.heap.shift();
                if (st.heap.length === k && st.heap[0] > st.mu) {
                    st.mu = st.heap[0];                      // S3：第 k 名變高了，門檻跟著拉高
                    st.raises.push(st.mu);
                    for (const [kk, r] of st.res) if (r.u < st.mu) st.res.delete(kk);
                }
            };
            const construct = (p, px, py) => {
                const pxy = { items: px.items.concat(py.items[py.items.length - 1]), e: new Map(), iu: 0, ru: 0 };
                for (const [tid, ex] of px.e) {
                    const ey = py.e.get(tid);
                    if (!ey) continue;
                    const iu = ex[0] + ey[0] - (p ? p.e.get(tid)[0] : 0);
                    pxy.e.set(tid, [iu, ey[1]]); pxy.iu += iu; pxy.ru += ey[1];
                }
                return pxy;
            };
            const search = (p, uls) => {
                uls.forEach((x, i) => {
                    st.checked++;
                    if (x.iu >= st.mu) offer(x.items, x.iu);
                    if (x.iu + x.ru < st.mu) { st.pruned++; return; }
                    const ext = [];
                    for (let j = i + 1; j < uls.length; j++) {
                        const xy = construct(p, x, uls[j]);
                        if (xy.e.size) ext.push(xy);
                    }
                    search(x, ext);
                });
            };
            search(null, lists);
            const best = [...st.res.values()].sort(rankCmp).slice(0, k);
            return { best, order, removed, checked: st.checked, pruned: st.pruned, raises: st.raises, final: st.mu };
        }

        /* GLIU：商品照 TWU 排好，交易裡「排序上連在一起」的一段商品，效益加起來（只算兩個商品以上的段） */
        function gliuOf(gul, gtwu, n) {
            const order = [...gul.keys()].sort((a, b) => gtwu[a] - gtwu[b] || cmp(a, b));
            const pos = new Map(order.map((i, k) => [i, k]));
            const rows = Array.from({ length: n }, () => new Map());
            for (const [i, lst] of gul) lst.forEach(([tid, u]) => rows[tid].set(pos.get(i), u));
            const table = new Map();
            rows.forEach(row => {
                const ks = [...row.keys()].sort((a, b) => a - b);
                for (let a = 0; a < ks.length; a++) {
                    let acc = row.get(ks[a]);
                    for (let b = a + 1; b < ks.length; b++) {
                        if (ks[b] !== ks[b - 1] + 1) break;
                        acc += row.get(ks[b]);
                        const key = ks[a] + '-' + ks[b];
                        const g = table.get(key) || { items: order.slice(ks[a], ks[b] + 1), u: 0 };
                        g.u += acc;
                        table.set(key, g);
                    }
                }
            });
            return [...table.values()].sort(rankCmp);
        }
        const singlesOf = gul => [...gul.entries()].map(([i, lst]) => ({ items: [i], u: lst.reduce((a, e) => a + e[1], 0) })).sort(rankCmp);

        /* ---------- 照著程式跑一次，記下每一步 ---------- */
        function buildTrace(batches, profit, kl, ku) {
            const steps = [];
            const gul = new Map(), gtwu = {};
            let n = 0, seen = 0, tree = [], minUpper = 0, minLower = 0, ceiling = 0, last = null, since = 0;
            let twuB = {}, tus = [];
            const stats = { batches: 0, remines: 0, checked: 0, ithui: 0, ithuiMines: 0 };
            const utilOf = items => {      // 只給畫面用：這個組合在目前讀過的交易裡的效益
                let u = 0;
                for (let t = 0; t < n; t++) {
                    const row = tus[t].row;
                    if (items.every(i => has(row, i))) u += items.reduce((a, i) => a + row[i], 0);
                }
                return u;
            };
            const push = (kind, extra = {}) => {
                steps.push({
                    kind, ...extra, seen, kl, ku,
                    tree: extra.tree || tree.map(r => ({ items: r.items, u: r.u })),
                    minUpper, minLower, ceiling, since,
                    gtwu: { ...gtwu }, single: Object.fromEntries(singlesOf(gul).map(r => [r.items[0], r.u])),
                    twuB: { ...twuB }, tus: tus.map(t => t.tu), stats: { ...stats }
                });
            };
            push('start');
            batches.forEach((batch, b) => {
                // 1. 讀這一批
                twuB = {};
                const tids = [];
                batch.forEach(t => {
                    const row = {};
                    Object.keys(t).forEach(i => { row[i] = t[i] * profit[i]; });
                    const tu = Object.values(row).reduce((a, x) => a + x, 0);
                    Object.keys(t).forEach(i => {
                        if (!gul.has(i)) gul.set(i, []);
                        gul.get(i).push([n, row[i]]);
                        gtwu[i] = (gtwu[i] || 0) + tu;
                        twuB[i] = (twuB[i] || 0) + tu;
                    });
                    tus.push({ row, tu });
                    tids.push(n);
                    n++;
                });
                seen = b + 1;
                stats.batches++;
                // 每批都重挖（ITHUI）：找前 kl 名，起始門檻用 S1、S2
                const ith = mineCore(gul, gtwu, n, kl, Math.max(kth(singlesOf(gul).map(r => r.u), kl), kth(gliuOf(gul, gtwu, n).map(r => r.u), kl)));
                stats.ithui += ith.checked;
                stats.ithuiMines++;
                const growItem = Object.keys(twuB).sort((x, y) => twuB[y] - twuB[x] || cmp(x, y))[0];
                const grow = growItem === undefined ? 0 : twuB[growItem];
                push('read', { b, tids, grow, growItem });
                // 2. 重挖條件
                if (tree.length) {
                    const gap = minUpper - ceiling, safe = grow < gap;
                    push('check', { b, grow, growItem, gap, safe, paperGap: last.up - last.low, paperSafe: grow < last.up - last.low, lastLow: last.low });
                    if (safe) {
                        const before = tree.map((r, k) => ({ ...r, rank: k }));
                        const oldUpper = minUpper, oldCeil = ceiling;
                        tree = before.map(r => {
                            let d = 0;
                            batch.forEach(t => { if (r.items.every(i => has(t, i))) d += r.items.reduce((a, i) => a + t[i] * profit[i], 0); });
                            return { items: r.items, u: r.u + d, d, old: r.rank };
                        }).sort(rankCmp);
                        ceiling += grow;
                        minUpper = kth(tree.map(r => r.u), kl);
                        minLower = kth(tree.map(r => r.u), ku);
                        since++;
                        const rows = tree.map((r, k) => ({ items: r.items, u: r.u, d: r.d, old: r.old, rank: k }));
                        tree = tree.map(r => ({ items: r.items, u: r.u }));
                        const up = rows.filter(r => r.rank < kl && r.old >= kl), down = rows.filter(r => r.rank >= kl && r.old < kl);
                        push('update', { b, grow, rows, up, down, oldUpper, oldCeil, tree: rows });
                        return;
                    }
                }
                // 3. 門檻拉高（S1、S2、S4），4. 挖，5. 寫進新的樹
                const singles = singlesOf(gul), gl = gliuOf(gul, gtwu, n);
                const s1 = kth(singles.map(r => r.u), ku), s2 = kth(gl.map(r => r.u), ku), s4 = minLower;
                const init = Math.max(s1, s2, s4);
                push('raise', { b, s1, s2, s4, init, gl: gl.slice(0, ku), nItems: singles.length, first: !last });
                const m = mineCore(gul, gtwu, n, ku, init);
                stats.remines++;
                stats.checked += m.checked;
                push('mine', { b, init, order: m.order, removed: m.removed, checked: m.checked, pruned: m.pruned, raises: m.raises, found: m.best.length });
                const oldKeys = new Set(tree.map(r => keyOf(r.items)));
                const newKeys = new Set(m.best.map(r => keyOf(r.items)));
                const dropped = tree.filter(r => !newKeys.has(keyOf(r.items))).map(r => ({ items: r.items, u: utilOf(r.items) }));
                const hadTree = tree.length > 0;
                tree = m.best.map(r => ({ items: r.items, u: r.u }));
                minUpper = kth(tree.map(r => r.u), kl);
                minLower = kth(tree.map(r => r.u), ku);
                ceiling = minLower;
                since = 0;
                last = { up: minUpper, low: minLower };
                const rows = tree.map((r, k) => ({ ...r, rank: k, fresh: hadTree && !oldKeys.has(keyOf(r.items)) }));
                push('tree', { b, rows, dropped, tree: rows, hadTree });
            });
            push('end', { nb: batches.length });
            return steps;
        }

        /* ---------- 說明文字 ---------- */
        const B = x => `<b>${x}</b>`;
        const tidList = tids => tids.length > 2 ? `${tName(tids[0])}～${tName(tids[tids.length - 1])}` : tids.map(tName).join('、');
        function describe(s) {
            const kl = s.kl, ku = s.ku;
            switch (s.kind) {
                case 'start':
                    return `資料不是一次給齊，而是<b>一批一批</b>進來：先有原始資料庫 D，之後 ${BATCHES.slice(1).map((x, b) => bName(b + 1)).join('、')}。` +
                        `每來一批都要回答「效益最高的前 ${B(kl)} 名是哪些組合」。PreTK 的作法是<b>多記幾名</b>：挖的時候找前 ${B(ku)} 名存在 itemset-tree 上，` +
                        `前 ${kl} 名叫 <b>Large</b>（答案），第 ${kl + 1}～${ku} 名叫 <b>Pre-large</b>（候補），其他的叫 Small。新的一批如果小到樹外的組合不可能擠進前 ${kl} 名，就只更新樹、不用重挖。`;
                case 'read': {
                    const cnt = BATCHES[s.b].length;
                    if (s.b === 0) return `讀進原始資料庫 D（${cnt} 筆，${tidList(s.tids)}）。每筆交易的每個商品都記進 <b>Global-Utility-List</b>（這個商品出現在哪筆交易、效益多少），` +
                        `同時累加每個商品的 <b>TWU</b>（有它的交易 TU 加起來）。之後要重挖都從這裡重建，不用回頭再掃舊交易。還沒有樹，第一次一定要挖。`;
                    return `第 ${s.b} 批 ${bName(s.b)} 進來（${cnt} 筆，${tidList(s.tids)}）。一樣記進 Global-Utility-List、累加全部的 TWU，另外算<b>這一批自己的 TWU</b>（表格最下面橘色那列）：` +
                        `最大的是 ${esc(s.growItem)} 的 ${B(s.grow)}。一個組合在這批多出來的效益，不會超過它任何一個商品在這批的 TWU，所以 ${s.grow} 是「任何組合這批最多長多少」。`;
                }
                case 'check': {
                    const from = s.since ? `上次挖掘時第 ${ku} 名的 ${s.lastLow}，再加上之後 ${s.since} 批的 max TWU` : `上次挖掘時第 ${ku} 名的效益 minU<sub>lower</sub>`;
                    let t = `<b>重挖條件</b>：沒在樹上的組合，效益最多是樹外上限 ${B(s.ceiling)}（${from}）；樹上第 ${kl} 名是 minU<sub>upper</sub> = ${B(s.minUpper)}。` +
                        `差距 ${s.minUpper} − ${s.ceiling} = ${s.gap}，這批 max TWU = ${s.grow}。`;
                    t += s.safe ? `${s.grow} < ${s.gap}：樹外的組合就算這批全部長滿，也追不上第 ${kl} 名，<b>不用重挖</b>，只要更新樹。`
                        : `${s.grow} ≥ ${s.gap}：樹外的組合<b>有可能</b>擠進前 ${kl} 名，可是樹上沒有它們的資料，只好<b>重新挖掘</b>。`;
                    if (s.since && s.paperSafe !== s.safe) t += `如果像論文原式只看這一批（${s.grow} 跟上次挖掘時的 minU<sub>upper</sub> − minU<sub>lower</sub> = ${s.paperGap} 比），會說不用重挖；` +
                        `但前面 ${s.since} 批都沒重挖，樹外的組合可能一直在長，所以要累加起來比。`;
                    return t;
                }
                case 'update': {
                    const ch = s.rows.filter(r => r.d).length;
                    let t = `不重挖：拿這批的交易去對樹上的 ${s.rows.length} 個組合，有整組包含的就把效益加上去（${ch} 個有變）。樹上的數字都是<b>真的效益</b>，重新排名：`;
                    t += s.up.length || s.down.length
                        ? (s.up.length ? `${s.up.map(r => fmt(r.items)).join('、')} <b>升上 Large</b>` : '') + (s.up.length && s.down.length ? '，' : '') +
                          (s.down.length ? `${s.down.map(r => fmt(r.items)).join('、')} <b>掉到 Pre-large</b>` : '') + '。'
                        : `前 ${kl} 名還是同一批組合。`;
                    return t + `前 ${kl} 名就是答案。樹外上限變成 ${s.oldCeil} + ${s.grow} = ${B(s.ceiling)}，第 ${kl} 名 minU<sub>upper</sub> ${s.oldUpper === s.minUpper ? '還是' : `從 ${s.oldUpper} 變成`} ${B(s.minUpper)}。`;
                }
                case 'raise': {
                    const s1 = s.s1 ? `${s.s1}` : `0（只有 ${s.nItems} 個商品，不到 ${ku} 個，用不上）`;
                    const s4 = s.first ? '0（第一次挖，還沒有上次）' : `${s.s4}（樹上第 ${ku} 名；資料只會變多，第 ${ku} 名的效益不會變小）`;
                    return `挖之前先把門檻拉高，門檻越高、剪得越多。<b>S1</b>：第 ${ku} 大的單一商品效益 = ${s1}；<b>S2</b>：GLIU（照 TWU 排好後連在一起的一段商品）第 ${ku} 大的效益 = ${s.s2}；` +
                        `<b>S4</b>：沿用上次的門檻 = ${s4}。這些都是真的組合的效益，第 ${ku} 大一定不超過真正的第 ${ku} 名。取最大的 ${B(s.init)} 當起始門檻。`;
                }
                case 'mine': {
                    const cut = s.removed.length ? `TWU 不到 ${s.init} 的 ${s.removed.map(esc).join('、')} 先不用；` : '';
                    const climb = s.raises.length > 1 ? `門檻一路從 ${s.raises.join(' → ')}` : `門檻一直是 ${s.init}，沒有再往上`;
                    return `從 Global-Utility-List 重建 utility list：${cut}剩下的照 TWU 由小到大排，從最後一個商品往前填剩餘效益（RUA），不用再掃交易。` +
                        `然後像 <a href="top-k-hui.html">Top-K</a> 一樣深度優先搜尋，找到夠格的組合就放進前 ${ku} 名，第 ${ku} 名變高就拉高門檻（<b>S3</b>）：${climb}。` +
                        `共檢查 ${B(s.checked)} 個組合，${s.pruned} 個因為「效益 + 剩餘效益」不到門檻，下面整個剪掉。`;
                }
                case 'tree': {
                    let t = `把前 ${s.rows.length} 名寫進${s.hadTree ? '新的 ' : ' '}itemset-tree：前 ${kl} 名是 Large、其餘是 Pre-large。minU<sub>upper</sub> = 第 ${kl} 名 = ${B(s.minUpper)}，` +
                        `minU<sub>lower</sub> = 第 ${ku} 名 = ${B(s.minLower)}${s.rows.length < ku ? `（組合不到 ${ku} 個，所有組合都在樹上，樹外上限是 0）` : ''}。沒進樹的組合效益都不超過它，所以樹外上限重設成 ${s.ceiling}。`;
                    if (s.hadTree) {
                        const fresh = s.rows.filter(r => r.fresh);
                        t += fresh.length ? `跟舊的樹比，${fresh.map(r => fmt(r.items)).join('、')} 是原本在樹外、這次新進來的${s.dropped.length ? `；${s.dropped.map(r => fmt(r.items)).join('、')} 掉出樹` : ''}。`
                            : `樹上的成員跟原本一樣，只是效益和名次變了。`;
                    }
                    return t;
                }
                case 'end': {
                    const st = s.stats, saved = st.batches - st.remines;
                    return `${st.batches} 批（含 D）都讀完了。PreTK 重新挖了 ${B(st.remines)} 次（第一次一定要挖），${saved ? `其他 ${saved} 批都只更新樹` : '每一批都需要重挖'}；` +
                        `每批都重挖的 ITHUI 要挖 ${st.ithuiMines} 次。檢查的組合：PreTK ${st.checked} 個、ITHUI ${st.ithui} 個。` +
                        (st.checked > st.ithui ? `這組資料 PreTK 反而比較多：每次挖都要找到第 ${ku} 名，門檻比較低。把 k<sub>upper</sub> 調小或換資料看看。` : `省下來的就是那些不用重挖的批次。`);
                }
            }
            return '';
        }

        const CODE_TAGS = s => {
            switch (s.kind) {
                case 'read': return ['read'];
                case 'check': return ['check'].concat(s.safe ? ['update'] : ['remine']);
                case 'update': return ['update'];
                case 'raise': return ['raise'];
                case 'mine': return ['mine', 'offer'];
                case 'tree': return ['tree'];
                default: return [s.kind];        // start / end
            }
        };

        /* ---------- 畫面 ---------- */
        /* 內容跟上一步一模一樣就不要重設 innerHTML（量高度時快很多） */
        const setHtml = (el, h) => { if (el._h !== h) { el.innerHTML = h; el._h = h; } };

        function setLabel(items) {
            const d = disp(items);
            return Object.keys(EMOJI).length
                ? `<span>${esc(d.map(sym).join(''))}</span><span class="nm">${esc(d.join(' '))}</span>`
                : `<span>${esc('{' + d.join(', ') + '}')}</span>`;
        }

        function drawDB(s) {
            const batchStep = ['read', 'check'].includes(s.kind) ? s.b : -1;
            const curB = ['read', 'check', 'update', 'raise', 'mine', 'tree'].includes(s.kind) ? s.b : -1;
            let h = '<thead><tr><th class="tid-h"></th>' + ITEMS.map(i =>
                `<th><span class="emo">${esc(sym(i))}</span>${EMOJI[i] ? `<span class="nm">${esc(i)}</span>` : ''}<span class="pf">$${PROFIT[i]}</span></th>`).join('') +
                '<th class="tu-h">TU</th></tr></thead><tbody>';
            DB.forEach((t, r) => {
                const b = BATCH_OF[r], later = b >= s.seen, cur = b === curB;
                if (r === 0 || BATCH_OF[r - 1] !== b)
                    h += `<tr class="bh${later ? ' later' : ''}${cur ? ' cur' : ''}"><td colspan="${ITEMS.length + 2}">${bName(b)}<span class="bn">${b === 0 ? '原始資料庫' : '新的一批'} · ${BATCHES[b].length} 筆${later ? ' · 還沒進來' : ''}</span></td></tr>`;
                h += `<tr class="${later ? 'later' : ''}${cur ? ' cur' : ''}"><td class="tid">${tName(r)}</td>` + ITEMS.map(i =>
                    has(t, i) ? `<td><div class="cell has">${t[i]}</div></td>` : '<td><div class="cell"></div></td>').join('') +
                    `<td class="tu">${later ? '' : s.tus[r]}</td></tr>`;
            });
            h += '</tbody><tfoot>';
            const row = (cls, label, f) => `<tr class="${cls}"><td class="tid">${label}</td>` + ITEMS.map(f).join('') + '<td></td></tr>';
            h += row('su', '單品', i => `<td>${s.single[i] !== undefined ? s.single[i] : ''}</td>`);
            h += row('', 'TWU', i => `<td>${s.gtwu[i] !== undefined ? s.gtwu[i] : ''}</td>`);
            h += row('bt', '這批', i => `<td class="${batchStep > 0 && s.twuB[i] === s.grow && i === s.growItem ? 'mx' : ''}">${batchStep > 0 && s.twuB[i] !== undefined ? s.twuB[i] : ''}</td>`);
            h += '</tfoot>';
            setHtml($('db'), h);
            $('db-sub').textContent = s.seen ? `讀到 ${bName(s.seen - 1)}，共 ${s.tus.length} 筆` : '';
        }

        /* 門檻與重挖判斷：看這一步是哪個階段，畫不一樣的內容 */
        function drawGate(s) {
            const box = $('gate'), sub = $('gate-sub'), kl = s.kl, ku = s.ku;
            const stat = (v, k, win) => `<div class="stat${win ? ' win' : ''}"><div class="v">${v}</div><div class="k">${k}</div></div>`;
            if (s.kind === 'raise') {
                sub.textContent = '重挖前：起始門檻';
                const w = Math.max(s.s1, s.s2, s.s4);
                const chips = s.gl.map((g, k) => `<span class="chip${k === ku - 1 ? ' kth' : ''}">${esc(plain(g.items))}<small>${g.u}</small></span>`).join('');
                setHtml(box, `<div class="stats">${stat(s.s1, `<b>S1</b> 第 ${ku} 大的單品效益`, s.s1 === w && w > 0)}${stat(s.s2, `<b>S2</b> GLIU 第 ${ku} 大`, s.s2 === w && w > 0 && s.s1 !== w)}` +
                    `${stat(s.s4, `<b>S4</b> 上次的第 ${ku} 名`, s.s4 === w && w > 0 && s.s1 !== w && s.s2 !== w)}${stat(s.init, '起始門檻（取最大）', false)}</div>` +
                    `<div class="gate-h"><b>GLIU</b>：照 TWU 排好後「連在一起的一段商品」，同一段在所有交易的效益加起來（前 ${s.gl.length} 個${s.gl.length >= ku ? `，橘框是第 ${ku} 大` : `，不到 ${ku} 個`}）。` +
                    `讀交易時順便就能累加，不用另外搜尋；這些都是真的組合，所以拿來拉門檻是安全的。</div><div class="chips">${chips || '<span class="chip off">沒有</span>'}</div>`);
                return;
            }
            if (s.kind === 'mine') {
                sub.textContent = '重新挖掘';
                const ord = s.order.map(i => `<span class="chip">${esc(sym(i))}${EMOJI[i] ? ' ' + esc(i) : ''}</span>`).join('<span class="chip arrow">→</span>');
                const off = s.removed.map(i => `<span class="chip off">${esc(sym(i))}${EMOJI[i] ? ' ' + esc(i) : ''}</span>`).join('');
                setHtml(box, `<div class="gate-h">用到的商品（照 TWU 由小到大）${s.removed.length ? '，劃掉的是 TWU 不到起始門檻的' : ''}：</div><div class="chips">${ord}${off}</div>` +
                    `<div class="gate-h">門檻怎麼被拉高（S3：前 ${ku} 名的第 ${ku} 名變高就跟著拉）：</div>` +
                    `<div class="climb">${s.raises.map((v, k) => k ? `<span> → </span>${v}` : v).join('')}</div>` +
                    `<div class="stats g4">${stat(s.checked, '檢查的組合', false)}${stat(s.pruned, '剪掉的分支', false)}${stat(s.found, `進樹的組合（最多 ${ku}）`, false)}${stat(s.raises[s.raises.length - 1], '挖完的門檻', false)}</div>`);
                return;
            }
            if (!s.seen || (s.kind === 'read' && s.b === 0)) {
                sub.textContent = '';
                setHtml(box, `<div class="tree-empty">${s.kind === 'start' ? '讀進原始資料庫 D 之後，第一次一定要挖。' : '還沒有樹，第一次一定要挖：下一步先把門檻拉高。'}</div>`);
                return;
            }
            // 其他步驟：樹外上限＋這批 max TWU，跟第 kl 名比
            const showGrow = s.kind === 'read' || s.kind === 'check';
            const grow = showGrow ? s.grow : 0, top = s.ceiling + grow;
            const scale = Math.max(s.minUpper, top, 1) * 1.08;
            const pc = v => (v / scale * 100).toFixed(2) + '%';
            const over = top >= s.minUpper;
            sub.textContent = s.kind === 'check' ? `${bName(s.b)} 要不要重挖？` : s.kind === 'read' ? `${bName(s.b)} 剛進來` : s.kind === 'update' ? `${bName(s.b)} 只更新樹` : s.kind === 'tree' ? '剛挖完' : '';
            let h = `<div class="gauge"><div class="seg base" style="width:${pc(s.ceiling)}"></div>` +
                (showGrow ? `<div class="seg grow${over ? ' over' : ''}" style="left:${pc(s.ceiling)};width:${pc(grow)}"></div>` : '') +
                `<div class="mk" style="left:${pc(s.minUpper)}"></div></div>` +
                `<div class="g-legend"><span><i style="background:var(--lt-4a4a6a, #4a4a6a)"></i>樹外上限 ${s.ceiling}</span>` +
                (showGrow ? `<span><i style="background:var(--lt-f59e0b-70, rgba(245, 158, 11, 0.7))"></i>這批最多再長 ${s.grow}</span>` : '') +
                `<span><i style="background:var(--good)"></i>第 ${kl} 名 ${s.minUpper}</span></div>`;
            h += `<div class="stats g4">${stat(s.minUpper, `minU<sub>upper</sub>：樹上第 ${kl} 名`, false)}${stat(s.minLower, `minU<sub>lower</sub>：樹上第 ${ku} 名`, false)}` +
                `${stat(s.ceiling, '樹外上限（Small 最多）', false)}${stat(s.minUpper - s.ceiling, '差距（這批 max TWU 要小於它）', s.kind === 'check')}</div>`;
            if (s.kind === 'check') {
                h += `<div class="verdict ${s.safe ? 'ok' : 'no'}">這批 max TWU <b>${s.grow}</b>（${esc(s.growItem)}）${s.safe ? '<' : '≥'} 差距 <b>${s.gap}</b> → <span class="tag">${s.safe ? '不用重挖，只更新樹' : '重新挖掘'}</span>` +
                    (s.since ? `<span class="paper-line">論文原式只看這一批：${s.grow} 跟上次挖掘時的 minU<sub>upper</sub> − minU<sub>lower</sub> = ${s.paperGap} 比 → ${s.paperSafe ? '不用重挖' : '重挖'}</span>` : '<span class="paper-line">剛挖完的第一批：跟論文的公式（10）一模一樣</span>') + '</div>';
            } else {
                h += `<div class="verdict">${s.kind === 'read' ? '下一步：拿這批的 max TWU 跟差距比。' : s.kind === 'update' ? `樹外上限加上了這批的 max TWU ${s.grow}；樹上的組合照實加。` : s.kind === 'tree' ? '剛挖完：樹外上限就是第 ' + ku + ' 名的效益。' : `全部讀完。`}<span class="paper-line">&nbsp;</span></div>`;
            }
            setHtml(box, h);
        }

        function drawTree(s) {
            const box = $('tree'), kl = s.kl;
            if (!s.tree.length) {
                setHtml(box, '<div class="tree-empty">還沒有樹。第一次挖完會把前 k<sub>upper</sub> 名寫進來。</div>');
                $('tree-sub').textContent = '';
                return;
            }
            const rows = s.kind === 'update' || s.kind === 'tree' ? s.rows : s.tree.map((r, k) => ({ ...r, rank: k }));
            let h = '<table class="rank"><tr><th class="no">#</th><th>組合</th><th class="u">效益</th><th class="tg">類別</th></tr>';
            rows.forEach((r, k) => {
                const L = k < kl;
                let mv = '';
                if (s.kind === 'update' && r.old !== k) {
                    const wasL = r.old < kl;
                    mv = wasL !== L ? `<span class="mv ${L ? 'up' : 'down'}">${L ? '↑ 升級' : '↓ 降級'}</span>` : `<span class="mv ${r.old > k ? 'up' : 'down'}">${r.old > k ? '↑' : '↓'}${Math.abs(r.old - k)}</span>`;
                }
                if (s.kind === 'tree' && r.fresh) mv = '<span class="mv new">新進樹</span>';
                const d = s.kind === 'update' ? `<small class="${r.d ? '' : 'z'}">+${r.d}</small>` : '';
                const hot = (s.kind === 'update' && r.d) || (s.kind === 'tree' && r.fresh);
                h += `<tr class="${k === kl - 1 && rows.length > kl ? 'edge' : ''}${hot ? ' hot' : ''}"><td class="no">${k + 1}</td><td class="set">${setLabel(r.items)}</td>` +
                    `<td class="u">${r.u}${d}</td><td class="tg"><span class="badge ${L ? 'L' : 'P'}">${L ? 'Large' : 'Pre-large'}</span>${mv}</td></tr>`;
            });
            h += `<tr class="small"><td class="no">…</td><td class="set">不在樹上的組合</td><td class="u">≤ ${s.ceiling}</td><td class="tg"><span class="badge S">Small</span></td></tr></table>`;
            if (s.kind === 'tree' && s.dropped.length) h += `<div class="dropped">掉出樹：${s.dropped.map(r => `${esc(plain(r.items))} ${r.u}`).join('、')}</div>`;
            setHtml(box, h);
            $('tree-sub').textContent = `${rows.length} 個組合` + (s.kind === 'update' ? '，加上這批的效益後重新排名' : s.kind === 'tree' ? '，剛重建' : '');
        }

        function drawResult(s) {
            $('res-k').textContent = s.kl;
            const ans = s.tree.slice(0, s.kl);
            setHtml($('ans'), ans.length ? ans.map(r => `<span class="pat"><span>${esc(plain(r.items))}</span><span class="n">${r.u}</span></span>`).join('')
                : `<span class="empty">${s.kind === 'start' ? '還沒有，讀進 D、挖完之後會出現在這裡。' : '第一次挖完才有。'}</span>`);
            $('st-batch').textContent = s.stats.batches;
            $('st-remine').textContent = s.stats.remines;
            $('st-check').textContent = s.stats.checked;
            $('st-ithui').textContent = s.stats.ithui;
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
                ? '下載 <a href="code/PreTK.java" download>PreTK.java</a>　執行 <code>javac PreTK.java && java PreTK</code>'
                : '下載 <a href="code/pretk.py" download>pretk.py</a>　執行 <code>python3 pretk.py</code>';
        }

        /* ---------- 顯示某一步 ---------- */
        function showStep() {
            const s = trace[cursor];
            $('explain').innerHTML = `<span class="step-no">步驟 ${cursor + 1} / ${trace.length}</span>${describe(s)}`;
            drawDB(s);
            drawGate(s);
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
            trace = buildTrace(BATCHES, PROFIT, kLower, kUpper);
            cursor = 0;
            $('kl-val').textContent = kLower;
            $('ku-val').textContent = kUpper;
            $('kl-minus').disabled = kLower <= 1;
            $('kl-plus').disabled = kLower >= KL_MAX;
            $('ku-minus').disabled = kUpper <= kLower + 1;
            $('ku-plus').disabled = kUpper >= KU_MAX;
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
            const rnd = quizRng(i + 1), kl = s.kl, ku = s.ku, nm = bName(s.b);
            switch (s.kind) {
                case 'check': {
                    if (!s.since) {
                        const right = s.safe ? '不用重挖，只更新樹' : '要重新挖掘';
                        return {
                            q: `${nm}：樹外上限 ${s.ceiling}、樹上第 ${kl} 名 ${s.minUpper}、這批 max TWU ${s.grow}。這批要重新挖掘嗎？`,
                            ...quizOptions([{ text: right }, { text: s.safe ? '要重新挖掘' : '不用重挖，只更新樹' }], rnd),
                            why: `${s.ceiling} + ${s.grow} = ${s.ceiling + s.grow} ${s.safe ? '<' : '≥'} ${s.minUpper}：樹外的組合${s.safe ? '追不上第 ' + kl + ' 名，不用重挖' : '有可能擠進前 ' + kl + ' 名，要重挖'}。`,
                            ask: { type: 'remine', b: s.b }
                        };
                    }
                    return {
                        q: `${nm}：前面已經 ${s.since} 批沒重挖。樹上第 ${kl} 名 ${s.minUpper}、第 ${ku} 名 ${s.minLower}、樹外上限 ${s.ceiling}。這批 max TWU 要小於多少才不用重挖？`,
                        ...quizNums(s.gap, -999, 99999, rnd, [s.minUpper - s.minLower, s.paperGap, s.minUpper]),
                        why: `要跟累積的樹外上限比：${s.minUpper} − ${s.ceiling} = ${s.gap}。只用 minU_upper − minU_lower 會忽略前面幾批樹外組合可能長的量。`,
                        ask: { type: 'gap', b: s.b }
                    };
                }
                case 'update': {
                    const rows = s.rows;
                    const tie = rows.length > kl && rows[kl - 1].u === rows[kl].u;
                    if (s.b % 2 === 1 && rows.length > kl && !tie) {
                        const cands = rows.slice(Math.max(0, kl - 2), kl + 1);
                        const opts = quizShuffle(cands, rnd);
                        const mq = {
                            q: `${nm} 的效益加到樹上之後，下面哪些組合會是 Large（前 ${kl} 名）？`,
                            choices: opts.map(r => plain(r.items)), answer: opts.map((r, k) => (r.rank < kl ? k : -1)).filter(k => k >= 0), multi: true,
                            why: cands.map(r => `${plain(r.items)} ${r.u - r.d}+${r.d}=${r.u}`).join('、') + `，第 ${kl} 名是 ${rows[kl - 1].u}。`,
                            ask: { type: 'large', b: s.b, sets: opts.map(r => r.items) }
                        };
                        return mq;
                    }
                    return {
                        q: `${nm} 不用重挖。更新完之後，樹外上限（不在樹上的組合最多多少）會變成多少？`,
                        ...quizNums(s.ceiling, 0, 99999, rnd, [s.oldCeil, s.grow, s.minLower]),
                        why: `樹外的組合沒有實際去算，只知道這批最多長 max TWU：${s.oldCeil} + ${s.grow} = ${s.ceiling}。`,
                        ask: { type: 'ceil', b: s.b }
                    };
                }
                case 'raise': {
                    if (s.first) return null;
                    return {
                        q: `${nm} 要重挖。S4 沿用上次的門檻：起始門檻至少可以設成多少？（看「門檻與重挖判斷」）`,
                        ...quizNums(s.s4, 0, 99999, rnd, [s.minUpper, s.ceiling]),
                        why: `樹上第 ${ku} 名 minU_lower = ${s.s4}：資料只會變多，這 ${ku} 個組合的效益都還至少這麼多，真正的第 ${ku} 名不會更低。`,
                        ask: { type: 's4', b: s.b }
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
            timer = setInterval(() => { if (!step(1)) stopAuto(); }, 2200);
        });
        document.addEventListener('keydown', e => {
            if (e.target.tagName === 'INPUT') return;
            if (e.key === 'ArrowRight') { stopAuto(); step(1); }
            if (e.key === 'ArrowLeft') { stopAuto(); step(-1); }
        });
        function setK(kl, ku) {
            kl = Math.max(1, Math.min(KL_MAX, kl));
            ku = Math.max(kl + 1, Math.min(KU_MAX, ku));
            if (kl === kLower && ku === kUpper) return;
            kLower = kl; kUpper = ku;
            rebuild();
        }
        $('kl-minus').addEventListener('click', () => setK(kLower - 1, kUpper));
        $('kl-plus').addEventListener('click', () => setK(kLower + 1, kUpper));
        $('ku-minus').addEventListener('click', () => setK(kLower, kUpper - 1));
        $('ku-plus').addEventListener('click', () => setK(kLower, kUpper + 1));
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
