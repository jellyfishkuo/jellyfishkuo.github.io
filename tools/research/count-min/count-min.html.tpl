<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/count-min.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/count-min-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/count-min-180.png">
    <title>Count-Min Sketch：用雜湊格子數串流</title>
    <meta name="description" content="不記商品名稱，只用 d 列 × w 欄的計數格子數資料串流：一步一步看每筆商品怎麼在每一列各 +1、查詢時為什麼取最小值、撞格子會多算多少，以及保守更新，Java 與 Python 程式碼逐行對照。">
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
        .intro { color: var(--lt-c6c6d6, #c6c6d6); max-width: 800px; margin-top: 0.9rem; font-size: 0.95rem; }
        .intro b { color: var(--text); }
        .intro a { color: var(--accent2); }

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

        /* ── 計數表（d 列 × w 欄） ── */
        .layout { margin-top: 1.3rem; }
        .sk-wrap { overflow-x: auto; }
        .sketch { display: grid; gap: 4px; min-width: 100%; }
        .sk-lab { font: 700 0.72rem 'Space Mono', monospace; color: var(--muted); display: flex; align-items: center; justify-content: center; }
        .sk-lab.col { padding-bottom: 1px; }
        .sk-cell {
            border: 1px solid var(--border);
            border-radius: 8px;
            background: var(--panel-2);
            text-align: center;
            padding: 3px 2px 4px;
            min-width: 0;
            transition: border-color 0.25s, background 0.25s;
        }
        .sk-cell .v { display: block; font: 700 1rem/1.3 'Space Mono', monospace; }
        .sk-cell .v.zero { color: var(--lt-4a4a66, #4a4a66); font-weight: 400; }
        .sk-cell .dv { display: block; font: 0.6rem/1.2 'Space Mono', monospace; color: var(--good); visibility: hidden; }
        .sk-cell .dv.on { visibility: visible; }
        .sk-cell .dv.keep { color: var(--muted); }
        .sk-cell .who { display: block; font-size: 11px; line-height: 1.25; min-height: 14px; word-break: break-all; }
        .sk-cell .who span { border-radius: 4px; padding: 0 1px; }
        .sk-cell .who .me { background: var(--lt-22c55e-30, rgba(34, 197, 94, 0.3)); }
        .sk-cell .who .col { background: var(--lt-f59e0b-35, rgba(245, 158, 11, 0.35)); }
        .sk-cell.hit { border-color: var(--good); box-shadow: 0 0 0 1px var(--good) inset; }
        .sk-cell.ask { border-color: var(--accent2); box-shadow: 0 0 0 1px var(--accent2) inset; }
        .sk-cell.min { border-color: var(--warn); box-shadow: 0 0 0 1px var(--warn) inset; background: var(--lt-f59e0b-12, rgba(245, 158, 11, 0.12)); }
        .sk-note { margin-top: 0.6rem; font-size: 0.8rem; color: var(--muted); }
        .sk-note b { color: var(--text); font: 700 0.8rem 'Space Mono', monospace; }

        /* ── 雜湊表 ── */
        .formula { font: 0.8rem 'Space Mono', monospace; color: var(--lt-c6c6d6, #c6c6d6); background: var(--panel-2); border-radius: 8px; padding: 0.45rem 0.6rem; margin-bottom: 0.6rem; overflow-x: auto; white-space: nowrap; }
        .row.h { font-size: 0.82rem; }
        .row.h .n { text-align: center; }
        .row.h.head span { text-align: center; }
        .row.h.head span:first-child { text-align: left; }
        .row.h .hc { font: 700 0.84rem 'Space Mono', monospace; text-align: center; border-radius: 5px; }
        .row.h .hc.same { background: var(--lt-f59e0b-30, rgba(245, 158, 11, 0.3)); }
        .row.h .ab { display: block; font: 0.58rem 'Space Mono', monospace; color: var(--lt-6a6a8a, #6a6a8a); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .row.h.unseen .it { color: var(--muted); }
        .row.q.unseen .it { color: var(--muted); }
        .row.q.ask { border-color: var(--accent2); box-shadow: 0 0 0 1px var(--accent2) inset; }
        .rbar .over { position: absolute; top: 0; bottom: 0; background: var(--lt-f59e0b-55, rgba(245, 158, 11, 0.55)); border-radius: 0 5px 5px 0; transition: left 0.25s, width 0.25s; }
        .rbar .over.bad { background: var(--lt-f87171-75, rgba(248, 113, 113, 0.75)); }
        .toggle[aria-pressed="true"] { background: var(--accent); border-color: var(--accent); }
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
        <h1>Count-Min Sketch<small>不記商品名稱，只用 d × w 個格子數串流：只會多算，而且多算多少有機率保證</small></h1>
        <p class="intro">
            <a href="stream-counting.html">串流近似計數</a>那頁的 Lossy Counting、Space-Saving 是<b>挑少數商品記住它們的計數</b>，沒被記住的商品就問不到。
            Count-Min Sketch（Cormode 與 Muthukrishnan，2005）換一個想法：<b>完全不記商品名稱，只記雜湊後的格子</b>。
            準備一張 <b>d 列 × w 欄</b>的計數表和 d 個雜湊函數，每來一筆商品，每一列各算出一格、那格 +1；要問某個商品賣了幾次，就把它的 d 格拿出來<b>取最小值</b>。
            好處是任何商品都查得到、記憶體固定 w × d 個整數；代價是不同商品會<b>撞進同一格</b>，所以只會多算、不會少算。
            把 w 調小一點就看得出撞格子；串流沿用那頁的超商商品，含偶爾才有人買的果汁、布丁、泡麵、巧克力。
        </p>

        <div class="layout" id="main">
            <div>
                <div class="card">
                    <div class="card-head"><h2>一步一步看</h2></div>
                    <div class="player">
                        <button class="btn" id="cm-first" title="回到開頭">⏮</button>
                        <button class="btn" id="cm-prev">◀ 上一步</button>
                        <button class="btn primary" id="cm-next">下一步 ▶</button>
                        <button class="btn" id="cm-play">▶ 自動播放</button>
                        <button class="btn" id="cm-last">⏭ 直接看結果</button>
                    </div>
                    <div class="params">
                        <div class="param">
                            <span>欄數 w</span>
                            <button class="btn stepper" id="w-minus" aria-label="w 變小">−</button>
                            <span class="val" id="w-val">5</span>
                            <button class="btn stepper" id="w-plus" aria-label="w 變大">+</button>
                            <span class="unit" id="eps-unit">ε = e/w ≈ 0.544</span>
                        </div>
                        <div class="param">
                            <span>列數 d</span>
                            <button class="btn stepper" id="d-minus" aria-label="d 變小">−</button>
                            <span class="val" id="d-val">3</span>
                            <button class="btn stepper" id="d-plus" aria-label="d 變大">+</button>
                            <span class="unit" id="delta-unit">δ = e⁻ᵈ ≈ 0.050</span>
                        </div>
                        <div class="param">
                            <button class="btn small toggle" id="cu-toggle" aria-pressed="false">保守更新：關</button>
                        </div>
                    </div>
                    <div class="quiz-bar">
                        <button class="btn quiz-toggle" id="quiz-toggle" aria-pressed="false" title="按下一步之前先猜猜看">🎯 練習模式<span class="sw" aria-hidden="true"></span></button>
                        <span class="quiz-score" id="quiz-score" style="visibility:hidden">答對 0/0</span>
                    </div>
                    <div class="quiz-host" id="quiz-host">
                        <div class="explain" id="cm-explain"></div>
                        <div class="quiz" id="quiz" role="group" aria-label="練習題" hidden></div>
                    </div>
                </div>

                <div class="card">
                    <div class="card-head"><h2>商品串流</h2><span class="unit" id="cm-count"></span></div>
                    <div class="belt" id="cm-belt"><div class="belt-inner" id="cm-belt-inner"></div></div>
                    <div class="legend">
                        <span><i style="border-color:var(--good)"></i>正在處理的這一筆</span>
                        <span><i style="border-color:#3a3a5a;border-style:dashed"></i>還沒進來</span>
                        <span><i style="border-color:var(--warn);background:rgba(245,158,11,0.3)"></i>跟這一筆同一種商品</span>
                    </div>
                    <div class="composer" id="cm-tools"></div>
                    <div class="hint" id="cm-hint"></div>
                </div>

                <div class="card">
                    <div class="card-head"><h2>計數表</h2><span class="unit" id="sk-unit">d 列 × w 欄，只記數字</span></div>
                    <div class="sk-wrap"><div class="sketch" id="sketch"></div></div>
                    <div class="legend">
                        <span><i style="border-color:var(--good)"></i>這一筆在每一列算到的格子</span>
                        <span><i style="border-color:var(--accent2)"></i>查詢的格子</span>
                        <span><i style="border-color:var(--warn);background:rgba(245,158,11,0.3)"></i>撞在一起的商品／取到的最小值</span>
                    </div>
                    <div class="sk-note" id="sk-note"></div>
                </div>
            </div>

            <div>
                <div class="card">
                    <div class="card-head"><h2>查詢：估計 vs 真實</h2><span class="unit">每個商品隨時都能查</span></div>
                    <div class="rows" id="q-rows"></div>
                    <div class="legend">
                        <span><i style="border-color:var(--accent2);background:var(--accent2)"></i>真實次數</span>
                        <span><i style="border-color:rgba(245,158,11,0.6);background:rgba(245,158,11,0.55)"></i>多算的部分（撞格子來的）</span>
                        <span><i style="border-color:var(--bad);background:rgba(248,113,113,0.75)"></i>多算超過 εN</span>
                    </div>
                    <div class="stats">
                        <div class="stat"><div class="v" id="st-n">0</div><div class="k">看過幾筆 N</div></div>
                        <div class="stat"><div class="v" id="st-mem">15</div><div class="k">計數表的格子數 w × d</div></div>
                        <div class="stat"><div class="v" id="st-exact">0</div><div class="k">精確計數要記幾個（出現過的種類）</div></div>
                    </div>
                    <div class="bars">
                        <div class="bar"><span>允許多算 εN</span><div class="track"><div class="fill limit" id="bar-lim"></div></div><span class="n" id="bar-lim-n">0</span></div>
                        <div class="bar"><span>實際最多多算</span><div class="track"><div class="fill" id="bar-err"></div></div><span class="n" id="bar-err-n">0</span></div>
                    </div>
                    <div class="guar" id="guar"></div>
                </div>

                <div class="card">
                    <div class="card-head"><h2>雜湊：每個商品落在哪一欄</h2><span class="unit">x = 商品編號</span></div>
                    <div class="formula">h<sub>j</sub>(x) = (a<sub>j</sub>·x + b<sub>j</sub>) mod 101 mod w</div>
                    <div class="rows" id="h-rows"></div>
                    <div class="legend">
                        <span><i style="border-color:var(--warn);background:rgba(245,158,11,0.3)"></i>在這一列跟目前的商品落在同一欄</span>
                    </div>
                </div>

                <div class="card">
                    <div class="card-head">
                        <h2>程式碼</h2>
                        <div class="lang">
                            <button data-lang="java" class="active">Java</button>
                            <button data-lang="py">Python</button>
                        </div>
                    </div>
                    <pre class="code" id="cm-code"></pre>
                    <div class="downloads" id="cm-downloads"></div>
                </div>
            </div>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼只會多算，而且多算不太可能超過 εN？</h2>
                <p>一格裡的數字 = 落在這格的所有商品次數加起來。商品 x 自己的次數一定在裡面，別的商品撞進來只會讓它更大，所以<b>每一格都 ≥ 真實次數，取最小值也還是 ≥ 真實</b>，永遠不會少算。
                    取最小值是因為：d 格裡被別人灌水最少的那格最接近真實。</p>
                <p style="margin-top:0.5rem">多算多少呢？看某一列：其他商品總共 N − f(x) 次，雜湊函數把它們平均撒到 w 欄，平均每欄分到不超過 N/w。所以 x 那格被灌水的<b>期望值 ≤ N/w = εN/e</b>（w = e/ε）。
                    用 Markov 不等式：灌水超過 εN（期望值的 e 倍）的機率 ≤ 1/e。d 列的雜湊函數互相獨立，<b>d 列同時都超過的機率 ≤ (1/e)<sup>d</sup> = δ</b>，只要有一列沒超過，最小值就沒超過。</p>
                <p style="margin-top:0.5rem">所以這是<b>機率保證</b>：每查一個商品，「多算 ≤ εN」成立的機率至少 1 − δ，不是每次都一定。實際上 εN 是對最壞資料的上限，大部分時候差得遠；把 w 調到 2、d 調到 1 試試，偶爾就會看到紅色的超過。
                    <b>保守更新</b>（Estan 與 Varghese 提出）每次只把「最小值那幾格」補到 m + 1：真實次數至少是 m + 1，比它大的格子已經夠了，不用再加。這樣每一格都不會比一般更新大，估計更準，而且一樣不會少算。</p>
            </div>
            <div class="card">
                <h2>跟 Lossy Counting / Space-Saving 比，以及跟實驗室研究的關係</h2>
                <ul>
                    <li><b>記商品 vs 記格子：</b><a href="stream-counting.html">Lossy Counting、Space-Saving</a> 只記少數商品，沒被記住的就只知道「不多」；Count-Min 不記名稱，<b>任何商品（連沒出現過的）都能查</b>，代價是要另外記下想看哪些商品，它自己列不出「最熱門的是誰」。</li>
                    <li><b>誤差方向：</b>Count-Min 和 Space-Saving 一樣只會多算；Lossy Counting 只會少算。Lossy Counting / Space-Saving 的誤差上限一定成立，Count-Min 的是「機率 1 − δ」。</li>
                    <li><b>可以相加、可以扣：</b>兩家分店用同樣的雜湊函數各做一張表，<b>格子對格子相加</b>就是合起來的表，很適合分散式串流。退貨時把那 d 格各 −1 也行（一般更新才可以，保守更新就不行了）。</li>
                    <li><b>記憶體跟商品種類無關：</b>只有 w × d 個整數。商品種類一多，冷門商品的相對誤差會很大（真實 1 次、估計 4 次），所以它最適合問「熱門商品大概幾次」。</li>
                    <li><b>跟實驗室的關係：</b>串流頻繁樣式探勘要數的是「商品組合」，種類多到記不完；把組合也雜湊進 sketch 估計支持度，是很多串流演算法的基本零件。誤差只會多算這點很重要：估計不到門檻的組合，一定真的不頻繁，可以放心剪掉。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           Count-Min Sketch 一步一步看
           網頁裡用 JavaScript 照著同樣的演算法跑一次，把每一步記下來；
           上一步／下一步只是在這些紀錄之間移動。右邊的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = /*CODE_JSON*/null;

        const ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片', '果汁', '布丁', '泡麵', '巧克力'];   // 商品編號 = 位置 + 1
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
        // 雜湊函數的參數：跟 Java / Python 版一模一樣，三邊算出來的格子才會相同
        const P = 101;
        const HA = [90, 67, 79, 56, 33];
        const HB = [10, 78, 20, 99, 71];
        const W_MIN = 2, W_MAX = 10, D_MIN = 1, D_MAX = 5;
        const MAX_LEN = 120, MIN_LEN = 5;
        const TOL = 1e-9;

        const $ = id => document.getElementById(id);
        let stream = DEFAULT_STREAM.slice();
        let hotOrder = ITEMS.slice();     // 隨機串流時誰比較熱門
        let cmW = 5, cmD = 3, useCU = false;
        let lang = 'java';
        let steps = [];
        let cursor = 0;
        let timer = null;

        const esc = x => String(x).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        const it = x => `${EMOJI[x] || ''}${esc(x)}`;
        const num = v => String(+v.toFixed(3));
        const idOf = item => ITEMS.indexOf(item) + 1;
        const hashCol = (j, x, w) => (HA[j] * x + HB[j]) % P % w;
        const epsOf = w => Math.E / w;
        const deltaOf = d => Math.exp(-d);

        /* =================== Count-Min：照著程式跑一次 =================== */
        function cmTrace(items, w, d, cu) {
            const table = Array.from({ length: d }, () => new Array(w).fill(0));
            const truth = new Map();          // 真實次數（只給畫面對照用，演算法本身不知道）
            let n = 0;
            const out = [];
            const estimate = x => Math.min(...table.map((row, j) => row[hashCol(j, x, w)]));
            const push = (kind, extra = {}) => out.push({
                kind, n, w, d, cu, table: table.map(r => r.slice()), truth: [...truth], ...extra
            });
            push('c-start');
            items.forEach((item, i) => {
                n++;
                truth.set(item, (truth.get(item) || 0) + 1);
                const x = idOf(item);
                const cells = table.map((row, j) => ({ j, c: hashCol(j, x, w), before: row[hashCol(j, x, w)] }));
                let m = null;
                if (!cu) {
                    cells.forEach(({ j, c }) => { table[j][c]++; });
                } else {
                    m = estimate(x);
                    cells.forEach(({ j, c }) => { table[j][c] = Math.max(table[j][c], m + 1); });
                }
                cells.forEach(cl => { cl.after = table[cl.j][cl.c]; });
                push('c-add', { i, item, x, m, cells });
            });
            ITEMS.forEach(item => {
                const x = idOf(item);
                const cells = table.map((row, j) => ({ j, c: hashCol(j, x, w), v: row[hashCol(j, x, w)] }));
                push('c-query', { item, x, cells, est: estimate(x), t: truth.get(item) || 0 });
            });
            push('c-end');
            return out;
        }
        // 估計值（給畫面用）
        const estOf = (s, item) => {
            const x = idOf(item);
            return Math.min(...s.table.map((row, j) => row[hashCol(j, x, s.w)]));
        };
        // 同一份串流用另一種更新方式跑，結尾拿來比較
        function errorSummary(table, truth, w) {
            let total = 0, worst = 0;
            ITEMS.forEach(item => {
                const x = idOf(item);
                const e = Math.min(...table.map((row, j) => row[hashCol(j, x, w)])) - (truth.get(item) || 0);
                total += e; worst = Math.max(worst, e);
            });
            return { total, worst };
        }

        /* =================== 說明文字 =================== */
        // 某一列某一欄裡，除了自己之外、已經出現過的商品
        function others(s, j, c, self) {
            const truth = new Map(s.truth);
            return ITEMS.filter(y => y !== self && truth.has(y) && hashCol(j, idOf(y), s.w) === c);
        }
        function describe(s) {
            const N = stream.length;
            const truth = new Map(s.truth);
            const epsN = epsOf(s.w) * s.n;
            switch (s.kind) {
                case 'c-start': {
                    const c0 = hashCol(0, 1, s.w);
                    return `計數表有 <b>d = ${s.d} 列、w = ${s.w} 欄</b>，共 ${s.w * s.d} 格，一開始全是 0。每一列有自己的雜湊函數 h<sub>j</sub>，把商品編號 x 對到那一列的某一欄（右邊的雜湊表）。` +
                        `例如 ☕咖啡編號 1：h1(1) = (90·1 + 10) mod 101 mod ${s.w} = ${c0}，所以第 1 列算到第 ${c0} 欄。表裡<b>不記商品名稱</b>，只有數字。` +
                        `w = ${s.w} 對應 ε = e/w ≈ ${num(epsOf(s.w))}，d = ${s.d} 對應 δ = e<sup>−d</sup> ≈ ${num(deltaOf(s.d))}。` +
                        (s.cu ? `這次開了<b>保守更新</b>：每筆只補最小的那幾格。` : `接下來 ${N} 筆商品一筆一筆進來。`);
                }
                case 'c-add': {
                    const where = s.cells.map(({ j, c }) => `第 ${j + 1} 列第 ${c} 欄`).join('、');
                    const hits = s.cells.map(({ j, c }) => [j, others(s, j, c, s.item)]).filter(([, o]) => o.length);
                    const est = estOf(s, s.item), t = truth.get(s.item);
                    let h = `第 ${s.n} 筆：${it(s.item)}（編號 ${s.x}）。`;
                    if (!s.cu) {
                        h += `算出 ${where}，<b>這 ${s.d} 格各 +1</b>。`;
                    } else {
                        const up = s.cells.filter(cl => cl.after !== cl.before), keep = s.cells.filter(cl => cl.after === cl.before);
                        h += `保守更新：先查目前估計 m = min(${s.cells.map(cl => cl.before).join(', ')}) = ${s.m}，加上這一筆它至少 ${s.m + 1} 次，只把<b>小於 ${s.m + 1} 的格子補到 ${s.m + 1}</b>：` +
                            up.map(cl => `第 ${cl.j + 1} 列 ${cl.before}→${cl.after}`).join('、') + '。' +
                            (keep.length ? `${keep.map(cl => `第 ${cl.j + 1} 列`).join('、')}已經 ≥ ${s.m + 1}，不動。` : '');
                    }
                    h += hits.length
                        ? `撞在一起的：` + hits.map(([j, o]) => `第 ${j + 1} 列有 ${o.map(it).join('、')}`).join('；') + '。'
                        : `這幾格目前只有它自己在用。`;
                    return h + `現在查它會得到 <b>${est}</b>，真實 ${t} 次` + (est === t ? `，剛好準 <span class="ok">✓</span>` : `，多算 ${est - t}`) + '。';
                }
                case 'c-query': {
                    const mins = s.cells.filter(cl => cl.v === s.est).map(cl => `第 ${cl.j + 1} 列`);
                    let h = `查詢 ${it(s.item)}（編號 ${s.x}）：${s.d} 格分別是 ${s.cells.map(cl => cl.v).join('、')}，<b>取最小值 ${s.est}</b>（${mins.join('、')}）。`;
                    if (s.t === 0) h += `它根本沒出現過，${s.est ? `這 ${s.est} 次全是別的商品撞進來的` : '每格都有空出來的，所以是 0'}。`;
                    else h += `真實 ${s.t} 次，` + (s.est === s.t ? `剛好準 <span class="ok">✓</span>` : `多算 ${s.est - s.t} 次`) + '。';
                    const over = s.est - s.t;
                    return h + (over > epsN + TOL ? `多算超過 εN = ${num(epsN)} <span class="no">✗</span>，這就是那 δ 的機率會發生的事。` : over ? `沒超過 εN = ${num(epsN)} <span class="ok">✓</span>` : '');
                }
                case 'c-end': {
                    const me = errorSummary(s.table, truth, s.w);
                    const alt = cmTrace(stream, s.w, s.d, !s.cu);
                    const ae = errorSummary(alt[alt.length - 1].table, truth, s.w);
                    const overs = ITEMS.filter(y => estOf(s, y) - (truth.get(y) || 0) > epsN + TOL);
                    return `${ITEMS.length} 個商品都查完了。<span class="ok">每個都是估計 ≥ 真實 ✓</span>，不管怎麼撞都不會少算。` +
                        `最多多算 ${me.worst} 次、加起來多算 ${me.total} 次；超過 εN = ${num(epsN)} 的` + (overs.length ? ` ${overs.map(it).join('、')}（機率保證不是每次都成立）` : `<b>沒有</b>`) + '。' +
                        `整張表只用 ${s.w * s.d} 個整數。同一份串流如果${s.cu ? '<b>關掉</b>' : '<b>打開</b>'}保守更新，會多算 ${ae.total} 次、最多 ${ae.worst} 次。`;
                }
            }
            return '';
        }

        const TAGS = { 'c-start': ['start', 'hash'], 'c-add': ['arrive', 'inc'], 'c-add-cu': ['arrive', 'cu', 'query'], 'c-query': ['query'], 'c-end': ['query'] };

        /* =================== 串流輸送帶 =================== */
        function renderBelt(s) {
            const inner = $('cm-belt-inner');
            const cur = s.i !== undefined ? s.i : -1;
            const done = s.n;
            const curItem = s.kind === 'c-add' ? s.item : null;
            const cell = j => {
                let cls = 'cell';
                if (j >= done) cls += ' future';
                if (j === s.i) cls += ' cur';
                else if (curItem && j < done && stream[j] === curItem) cls += ' same';
                return `<div class="${cls}" title="第 ${j + 1} 筆：${esc(stream[j])}"><span class="emo">${EMOJI[stream[j]] || '?'}</span><span class="idx">${j + 1}</span></div>`;
            };
            inner.innerHTML = `<div class="bucket plain">${stream.map((_, j) => cell(j)).join('')}</div>`;
            // 只捲輸送帶本身，讓正在處理的那一筆留在中間
            const belt = $('cm-belt');
            const target = cur >= 0 ? inner.querySelectorAll('.cell')[cur] : null;
            $('cm-count').textContent = `共 ${stream.length} 筆`;
            if (measuringBlocks) return;
            if (target && belt.clientWidth) {
                const br = belt.getBoundingClientRect(), tr = target.getBoundingClientRect();
                belt.scrollTo({ left: Math.max(0, belt.scrollLeft + tr.left - br.left - belt.clientWidth / 2 + tr.width / 2), behavior: 'smooth' });
            } else if (belt.clientWidth && s.kind === 'c-start') belt.scrollTo({ left: 0 });
        }

        function renderTools() {
            $('cm-tools').innerHTML =
                `<div class="picks"><span class="lab">加一筆到尾端：</span>` +
                ITEMS.map(x => `<button class="pick${RARE.has(x) ? ' rare' : ''}" data-item="${esc(x)}">${it(x)}</button>`).join('') + `</div>` +
                `<div class="len"><span class="lab">長度</span><button class="btn stepper" data-act="shorter" aria-label="短一點">−</button>` +
                `<span class="val">${stream.length}</span><button class="btn stepper" data-act="longer" aria-label="長一點">+</button></div>` +
                `<button class="btn small" data-act="random">🎲 隨機串流</button><button class="btn small" data-act="reset">恢復範例</button>`;
            const box = $('cm-tools');
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

        /* =================== 計數表 =================== */
        function renderSketch(s) {
            const truth = new Map(s.truth);
            const box = $('sketch');
            box.style.gridTemplateColumns = `2.2em repeat(${s.w}, minmax(40px, 1fr))`;
            const focus = s.kind === 'c-add' || s.kind === 'c-query' ? s.item : null;
            const mine = new Map((s.cells || []).map(cl => [cl.j, cl]));
            let h = `<span class="sk-lab col"></span>`;
            for (let c = 0; c < s.w; c++) h += `<span class="sk-lab col">${c}</span>`;
            s.table.forEach((row, j) => {
                h += `<span class="sk-lab">h${j + 1}</span>`;
                row.forEach((v, c) => {
                    const cl = mine.get(j);
                    const on = cl && cl.c === c;
                    let cls = 'sk-cell';
                    if (on && s.kind === 'c-add') cls += ' hit';
                    if (on && s.kind === 'c-query') cls += v === s.est ? ' min' : ' ask';
                    let dv = '·', dcls = 'dv';
                    if (on && s.kind === 'c-add') {
                        dcls += ' on';
                        if (cl.after === cl.before) { dv = '不動'; dcls += ' keep'; }
                        else dv = cl.after - cl.before === 1 && !s.cu ? '+1' : `${cl.before}→${cl.after}`;
                    } else if (on && v === s.est) { dv = '最小'; dcls += ' on keep'; }
                    // 已經出現過、落在這格的商品
                    const who = ITEMS.filter(y => truth.has(y) && hashCol(j, idOf(y), s.w) === c).map(y => {
                        const k = y === focus ? 'me' : on && s.kind === 'c-add' ? 'col' : '';
                        return `<span class="${k}" title="${esc(y)}">${EMOJI[y]}</span>`;
                    }).join('');
                    h += `<div class="${cls}"><span class="v${v ? '' : ' zero'}">${v}</span><span class="${dcls}">${dv}</span><span class="who">${who}</span></div>`;
                });
            });
            box.innerHTML = h;
            $('sk-unit').textContent = `${s.d} 列 × ${s.w} 欄，只記數字`;
            $('sk-note').innerHTML = s.cu
                ? `保守更新時每一列加起來 <b>≤ N = ${s.n}</b>（只補需要補的格子）。`
                : `一般更新時每一列加起來都剛好是 <b>N = ${s.n}</b>（每筆每列各 +1 一格）。`;
        }

        /* =================== 雜湊表 =================== */
        function renderHash(s) {
            const truth = new Map(s.truth);
            const focus = s.kind === 'c-add' || s.kind === 'c-query' ? s.item : null;
            const fx = focus ? idOf(focus) : 0;
            const cols = `minmax(0, 1fr) 2em repeat(${s.d}, minmax(0, 3.6em))`;
            let h = `<div class="row h head" style="grid-template-columns:${cols}"><span>商品</span><span>x</span>` +
                Array.from({ length: s.d }, (_, j) => `<span>h${j + 1}<span class="ab">${HA[j]}x+${HB[j]}</span></span>`).join('') + `</div>`;
            ITEMS.forEach(y => {
                const x = idOf(y);
                let cls = 'row h';
                if (y === focus) cls += ' cur';
                if (!truth.has(y)) cls += ' unseen';
                h += `<div class="${cls}" style="grid-template-columns:${cols}"><span class="it">${it(y)}</span><span class="n dim">${x}</span>` +
                    Array.from({ length: s.d }, (_, j) => {
                        const c = hashCol(j, x, s.w);
                        const same = focus && y !== focus && c === hashCol(j, fx, s.w);
                        return `<span class="hc${same ? ' same' : ''}">${c}</span>`;
                    }).join('') + `</div>`;
            });
            $('h-rows').innerHTML = h;
        }

        /* =================== 查詢表與誤差保證 =================== */
        function renderQuery(s) {
            const truth = new Map(s.truth);
            const epsN = epsOf(s.w) * s.n;
            const rows = ITEMS.map(y => ({ y, est: estOf(s, y), t: truth.get(y) || 0 }));
            const scale = Math.max(1, ...rows.map(r => r.est));
            const pct = v => (v / scale * 100).toFixed(2) + '%';
            let h = `<div class="row q head"><span>商品</span><span>估計</span><span>真實</span><span>多算</span><span>多算多少</span></div>`;
            rows.forEach(r => {
                const over = r.est - r.t;
                const bad = over > epsN + TOL;
                let cls = 'row q';
                if (r.t === 0) cls += ' unseen';
                if (r.y === s.item && s.kind === 'c-add') cls += ' cur';
                if (r.y === s.item && s.kind === 'c-query') cls += ' ask';
                h += `<div class="${cls}"><span class="it"><span class="sl">#${idOf(r.y)}</span>${it(r.y)}</span>` +
                    `<span class="n est">${r.est}</span><span class="n">${r.t}</span><span class="n${over ? (bad ? ' off' : '') : ' dim'}">${over}</span>` +
                    `<span class="rbar"><span class="solid" style="width:${pct(r.t)}"></span><span class="over${bad ? ' bad' : ''}" style="left:${pct(r.t)};width:${pct(over)}"></span></span></div>`;
            });
            $('q-rows').innerHTML = h;

            const worst = Math.max(0, ...rows.map(r => r.est - r.t));
            const overs = rows.filter(r => r.est - r.t > epsN + TOL).length;
            $('st-n').textContent = s.n;
            $('st-mem').innerHTML = `${s.w * s.d}<small> = ${s.w}×${s.d}</small>`;
            $('st-exact').textContent = truth.size;
            const sc = Math.max(1, epsN, worst);
            $('bar-lim').style.width = (epsN / sc * 100) + '%';
            $('bar-err').style.width = (worst / sc * 100) + '%';
            $('bar-lim-n').textContent = num(epsN);
            $('bar-err-n').textContent = worst;
            $('guar').innerHTML = s.n
                ? `每個商品都是 <b>估計 ≥ 真實</b> <span class="ok">✓</span>（一定成立）。多算超過 εN = ${num(epsN)} 的有 <b>${overs}</b> 個；每個商品超過的機率 ≤ δ ≈ ${num(deltaOf(s.d))}。`
                : '還沒有資料，每格都是 0。';
        }

        /* =================== 程式碼 =================== */
        const KW = {
            java: new Set('public static final for if return new boolean int void class import while else null this double continue'.split(' ')),
            py: new Set('def for in if else return not and or while import from as True False None class is lambda continue del'.split(' '))
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

        const FILES = { java: ['CountMin.java', 'javac CountMin.java && java CountMin'], py: ['count_min.py', 'python3 count_min.py'] };
        function renderCode(tags) {
            if (measuringBlocks || restoringBlocks) return;   // 量區塊高度時不用畫程式碼（程式碼框高度不會變），量完畫回來時它也沒被動過，省時間
            const pre = $('cm-code');
            pre.innerHTML = CODE[lang].map(([text, t], i) =>
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
            const [file, cmd] = FILES[lang];
            $('cm-downloads').innerHTML = `下載 <a href="code/${file}" download>${file}</a>　執行 <code>${cmd}</code>`;
        }

        /* =================== 顯示某一步 =================== */
        function show() {
            const s = steps[cursor];
            $('cm-explain').innerHTML = `<span class="step-no">步驟 ${cursor + 1} / ${steps.length}</span>${describe(s)}`;
            renderBelt(s);
            renderSketch(s);
            renderQuery(s);
            renderHash(s);
            renderCode(TAGS[s.kind === 'c-add' && s.cu ? 'c-add-cu' : s.kind] || []);
            $('cm-prev').disabled = $('cm-first').disabled = cursor === 0;
            $('cm-next').disabled = $('cm-last').disabled = cursor === steps.length - 1;
            $('w-val').textContent = cmW;
            $('d-val').textContent = cmD;
            $('eps-unit').textContent = `ε = e/w ≈ ${num(epsOf(cmW))}`;
            $('delta-unit').textContent = `δ = e⁻ᵈ ≈ ${num(deltaOf(cmD))}`;
            $('w-minus').disabled = cmW <= W_MIN;
            $('w-plus').disabled = cmW >= W_MAX;
            $('d-minus').disabled = cmD <= D_MIN;
            $('d-plus').disabled = cmD >= D_MAX;
            $('cu-toggle').textContent = `保守更新：${useCU ? '開' : '關'}`;
            $('cu-toggle').setAttribute('aria-pressed', useCU);
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

        /* 說明框用最長那段文字的高度固定住，下面的東西才不會跳來跳去 */
        function reserveExplainHeight() {
            quizReserve();   // 練習模式的題目框也要先預留高度，再量各區塊
            const box = $('cm-explain');
            if (!box.offsetWidth) return;
            const probe = box.cloneNode(false);
            probe.removeAttribute('id');
            probe.style.cssText = `position:absolute;visibility:hidden;left:-9999px;min-height:0;width:${box.offsetWidth}px`;
            document.body.appendChild(probe);
            let tallest = 0;
            steps.forEach((s, i) => {
                probe.innerHTML = `<span class="step-no">步驟 ${i + 1} / ${steps.length}</span>${describe(s)}`;
                tallest = Math.max(tallest, probe.offsetHeight);
            });
            probe.remove();
            box.style.minHeight = tallest + 'px';
            reserveBlockHeights($('main'), steps.length, i => { cursor = i; show(); }, () => cursor);
        }

        /* =================== 資料或參數改變：重算 trace =================== */
        function rebuild() { steps = cmTrace(stream, cmW, cmD, useCU); }
        // 參數變了：盡量停在同一筆（同一個 N）；查詢階段就停在查同一個商品
        function cursorLike(old, fromEnd) {
            if (old.kind === 'c-query' || old.kind === 'c-end') return steps.length - fromEnd;
            if (old.n <= 0) return 0;
            const j = steps.findIndex(s => s.kind === 'c-add' && s.n === old.n);
            return j < 0 ? steps.length - 1 : j;
        }
        function paramChanged() {
            stopAuto();
            const old = steps[cursor], fromEnd = steps.length - cursor;
            rebuild();
            cursor = cursorLike(old, fromEnd);
            show();
            reserveExplainHeight();
        }
        function streamChanged(how) {
            stopAuto();
            const oldN = steps[cursor].n;
            rebuild();
            if (how === 'append') cursor = steps.findIndex(s => s.kind === 'c-add' && s.n === stream.length);
            else if (how === 'length') cursor = Math.max(0, steps.findIndex(s => s.kind === 'c-add' && s.n === Math.min(oldN, stream.length)));
            else cursor = 0;
            renderTools();
            show();
            reserveExplainHeight();
        }
        $('cm-tools').addEventListener('click', e => {
            const pick = e.target.closest('[data-item]');
            if (pick) {
                if (stream.length >= MAX_LEN) return;
                stream.push(pick.dataset.item);
                streamChanged('append');
                setHint(`加了一筆 ${pick.dataset.item}，現在共 ${stream.length} 筆，直接跳到它進來的那一步。`);
                return;
            }
            const act = e.target.closest('[data-act]');
            if (!act) return;
            const a = act.dataset.act;
            if (a === 'random') { stream = randomStream(stream.length < 20 ? 30 : stream.length); streamChanged('random'); setHint(`隨機產生 ${stream.length} 筆：這次最熱門的是 ${hotOrder[0]}、${hotOrder[1]}。`); }
            if (a === 'reset') { stream = DEFAULT_STREAM.slice(); hotOrder = ITEMS.slice(); streamChanged('reset'); setHint('恢復成範例串流（30 筆）。'); }
            if (a === 'shorter') { stream = stream.slice(0, Math.max(MIN_LEN, Math.ceil(stream.length / 5) * 5 - 5)); streamChanged('length'); setHint(`剪掉尾巴，剩 ${stream.length} 筆。`); }
            if (a === 'longer') {
                const len = Math.min(MAX_LEN, Math.floor(stream.length / 5) * 5 + 5);
                while (stream.length < len) stream.push(drawItem());
                streamChanged('length');
                setHint(`在尾端隨機多加幾筆，現在 ${stream.length} 筆。`);
            }
        });
        function setHint(text) { $('cm-hint').textContent = text; }

        /* =================== 播放控制 =================== */
        /* =========================================================
           練習模式「猜下一步」（各 Demo 共用，規格見 tools/research/BRIEF.md）
           打開後按「下一步」：如果下一步有題目（quizFor 不是 null），先在說明框的位置疊一層題目，
           答完立刻顯示對錯和一句解釋，按「繼續」才真的前進。題目都從 steps 算出來，資料或門檻改了照樣能出題。
           ========================================================= */
        const QZ = { on: false, q: null, at: -1, picked: new Set(), answered: false, done: new Set(), right: 0, total: 0, steps: null };

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
            if (at >= steps.length || QZ.done.has(at)) return false;
            const q = quizFor(steps[at], at);
            if (!q) return false;
            quizOpen(q, at);
            return true;
        }

        /* 題目框的高度：把這一輪每一題都畫一次，用最高的那題固定（關掉練習模式時也一樣預留，開關才不會推動下面） */
        function quizReserve() {
            if (QZ.steps !== steps) { QZ.steps = steps; QZ.done.clear(); quizClose(); }   // 資料或門檻改了，重新出題
            const host = $('quiz-host');
            if (!host.offsetWidth) return;
            const probe = document.createElement('div');
            probe.className = 'quiz done';
            probe.style.cssText = `position:absolute;visibility:hidden;left:-9999px;top:0;right:auto;bottom:auto;width:${host.offsetWidth}px`;
            document.body.appendChild(probe);
            let tallest = 0;
            steps.forEach((s, i) => {
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
                $('cm-next').click();
            }
        });
        $('quiz-toggle').addEventListener('click', () => {
            QZ.on = !QZ.on;
            if (!QZ.on) quizClose();
            quizScore();
        });
        $('cm-first').addEventListener('click', quizClose);
        $('cm-last').addEventListener('click', quizClose);

        /* 第 i 步（s = steps[i]）要出的題目：{ q, choices, answer, why, multi?, ask? } 或 null（ask 只給 quiz_test.py 對答案用） */
        function quizFor(s, i) {
            const rnd = quizRng(i + 1);
            const truth = new Map(s.truth);
            if (s.kind === 'c-add') {
                if (s.n % 3) return null;                 // 每 3 筆問一次
                const t = truth.get(s.item);
                if (s.cu) {
                    const cl = quizPick(s.cells, rnd);
                    return {
                        q: `保守更新：第 ${s.n} 筆是 ${s.item}，它的 ${s.d} 格現在是 ${s.cells.map(c => c.before).join('、')}。第 ${cl.j + 1} 列那格（${cl.before}）會變成多少？`,
                        ...quizNums(cl.after, 0, s.n, rnd, [cl.before + 1, cl.before, s.m]),
                        why: `先查 m = min(${s.cells.map(c => c.before).join(', ')}) = ${s.m}，加上這筆至少 ${s.m + 1} 次；` +
                            (cl.before < s.m + 1 ? `${cl.before} 比 ${s.m + 1} 小，補到 ${s.m + 1}。` : `${cl.before} 已經 ≥ ${s.m + 1}，不動。`) + `只有一般版才是每格都 +1。`,
                        ask: { type: 'cu', n: s.n, item: s.item, j: cl.j }
                    };
                }
                const after = s.cells.map(c => c.after), est = Math.min(...after);
                return {
                    q: `第 ${s.n} 筆是 ${s.item}，${s.d} 格各 +1 之後，查 ${s.item} 會得到多少？`,
                    ...quizNums(est, 0, s.n, rnd, [t, Math.max(...after), after[0]]),
                    why: `它的 ${s.d} 格 +1 後是 ${after.join('、')}，取最小值 ${est}（不是最大、也不是只看第一列）；真實 ${t} 次，` +
                        (est === t ? '剛好準。' : `多出的 ${est - t} 次是別的商品撞進來的。`),
                    ask: { type: 'est', n: s.n, item: s.item }
                };
            }
            if (s.kind === 'c-query') {
                const v = s.cells.map(c => c.v);
                return {
                    q: `查詢 ${s.item}：照雜湊找到它在每一列的格子，估計值是多少？`,
                    ...quizNums(s.est, 0, s.n, rnd, [s.t, Math.max(...v), v[0]]),
                    why: `${s.d} 格分別是 ${v.join('、')}，取最小值 ${s.est}；真實 ${s.t} 次，` + (s.est === s.t ? '剛好準。' : `多算 ${s.est - s.t} 次，但絕不會少算。`),
                    ask: { type: 'est', n: s.n, item: s.item }
                };
            }
            return null;
        }

        function go(dir) {
            if (quizGate(dir)) return false;
            const next = cursor + dir;
            if (next < 0 || next >= steps.length) return false;
            cursor = next;
            show();
            return cursor < steps.length - 1;
        }
        function stopAuto() {
            clearInterval(timer);
            timer = null;
            $('cm-play').textContent = '▶ 自動播放';
        }
        $('cm-next').addEventListener('click', () => { stopAuto(); go(1); });
        $('cm-prev').addEventListener('click', () => { stopAuto(); go(-1); });
        $('cm-first').addEventListener('click', () => { stopAuto(); cursor = 0; show(); });
        $('cm-last').addEventListener('click', () => { stopAuto(); cursor = steps.length - 1; show(); });
        $('cm-play').addEventListener('click', () => {
            if (timer) { stopAuto(); return; }
            if (cursor === steps.length - 1) { cursor = 0; show(); }
            $('cm-play').textContent = '⏸ 暫停';
            timer = setInterval(() => { if (!go(1)) stopAuto(); }, 1300);
        });
        document.addEventListener('keydown', e => {
            if (e.target.closest && e.target.closest('input, textarea, select')) return;
            if (e.key === 'ArrowRight') { stopAuto(); go(1); }
            if (e.key === 'ArrowLeft') { stopAuto(); go(-1); }
        });

        $('w-minus').addEventListener('click', () => { if (cmW > W_MIN) { cmW--; paramChanged(); } });
        $('w-plus').addEventListener('click', () => { if (cmW < W_MAX) { cmW++; paramChanged(); } });
        $('d-minus').addEventListener('click', () => { if (cmD > D_MIN) { cmD--; paramChanged(); } });
        $('d-plus').addEventListener('click', () => { if (cmD < D_MAX) { cmD++; paramChanged(); } });
        $('cu-toggle').addEventListener('click', () => {
            useCU = !useCU;
            paramChanged();
            setHint(useCU ? '保守更新打開了：每筆只把最小的那幾格補到 m + 1，其他格不動。' : '保守更新關掉了：每筆每一列都 +1。');
        });

        document.querySelectorAll('.lang').forEach(box => box.addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b) return;
            lang = b.dataset.lang;
            document.querySelectorAll('.lang button').forEach(x => x.classList.toggle('active', x.dataset.lang === lang));
            show();
        }));

        let resizeTimer = null;
        window.addEventListener('resize', () => {
            clearTimeout(resizeTimer);
            resizeTimer = setTimeout(() => { show(); reserveExplainHeight(); }, 150);
        });

        rebuild();
        renderTools();
        show();
        reserveExplainHeight();
    </script>
</body>

</html>
