<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/uncertain-sw.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/uncertain-sw-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/uncertain-sw-180.png">
    <title>不確定資料的滑動視窗探勘 SWUPA</title>
    <meta name="description" content="一步一步看 SWUPA：每樣商品都有存在機率，交易一批一批進入滑動視窗，用 SWUPA-List 移除最舊的批次、用 overExpSup 與 ppCLw 剪枝，挖出期望支持度夠高的樣式，Java 與 Python 程式碼逐行對照。">
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
        h3 { font-size: 0.88rem; color: var(--muted); font-weight: 400; margin: 0.9rem 0 0.4rem; }
        .intro { color: var(--lt-c6c6d6, #c6c6d6); max-width: 780px; margin-top: 0.9rem; font-size: 0.95rem; }
        .intro b { color: var(--text); }
        .intro a { color: var(--accent2); }

        .layout { display: grid; gap: 1rem; margin-top: 1rem; }
        .layout > * { min-width: 0; display: grid; gap: 1rem; align-content: start; }
        .layout > * > * { min-width: 0; }
        @media (min-width: 960px) { .layout { grid-template-columns: 1fr 1.05fr; } }

        .card {
            background: var(--panel);
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 1rem;
            min-width: 0;
        }
        .card-head { display: flex; justify-content: space-between; align-items: center; gap: 0.5rem; flex-wrap: wrap; margin-bottom: 0.7rem; }
        .card-head h2 { margin: 0; }
        .stream-card { margin-top: 1.3rem; }

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
        button.btn.on { border-color: var(--warn); color: var(--warn); }

        .params { display: flex; flex-wrap: wrap; gap: 0.4rem 1.1rem; align-items: center; font-size: 0.88rem; }
        .param { display: flex; align-items: center; gap: 0.4rem; }
        .param .val { font: 700 1rem 'Space Mono', monospace; min-width: 1.2em; text-align: center; }
        .stepper { width: 30px; height: 30px; padding: 0 !important; }
        .seg { display: flex; gap: 0.25rem; flex-wrap: wrap; }
        .seg button {
            background: none;
            border: 1px solid var(--border);
            color: var(--muted);
            border-radius: 6px;
            padding: 0.15rem 0.5rem;
            font: inherit;
            font-size: 0.78rem;
            cursor: pointer;
        }
        .seg button.active { color: var(--text); border-color: var(--accent2); }

        /* ── 輸送帶：一批一批的不確定交易 ── */
        .belt {
            overflow-x: auto;
            background: var(--lt-0a0a14, #0a0a14);
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 30px 10px 12px;
            margin-top: 0.7rem;
        }
        .belt-inner { position: relative; display: flex; gap: 12px; width: max-content; padding: 0 6px; }
        .batch { display: flex; flex-direction: column; gap: 3px; }
        .batch .blabel { font: 700 0.68rem 'Space Mono', monospace; color: var(--muted); text-align: center; line-height: 1.2; }
        .batch.extra .blabel { color: var(--lt-4a4a66, #4a4a66); }
        .bt { display: flex; gap: 5px; }
        .tx {
            flex: none;
            width: 50px;
            border: 1px solid var(--border);
            border-radius: 8px;
            background: var(--panel-2);
            text-align: center;
            padding: 3px 0 4px;
            position: relative;
            transition: opacity 0.3s, border-color 0.3s, background 0.3s;
        }
        .tx .tid { font: 700 0.7rem 'Space Mono', monospace; display: block; line-height: 1.3; margin-bottom: 2px; }
        .tx .slot {
            height: 24px; display: flex; align-items: center; justify-content: center; gap: 1px;
            font-size: 12px; border-radius: 5px; margin: 1px 3px; border: 1px solid transparent;
        }
        .tx .slot .p { font: 700 0.62rem 'Space Mono', monospace; color: var(--lt-cffafe, #cffafe); }
        .tx .slot.on { background: color-mix(in srgb, var(--lt-06b6d4, rgb(6, 182, 212)) calc(8% + var(--p) * 40%), transparent); }
        .tx .slot.off::after { content: ''; width: 3px; height: 3px; border-radius: 50%; background: var(--lt-34344e, #34344e); }
        .tx .slot.hit { border-color: var(--warn); }
        .tx.past { opacity: 0.28; }
        .tx.future { opacity: 0.5; border-style: dashed; background: transparent; }
        .tx.enter { border-color: var(--good); box-shadow: 0 0 0 1px var(--good); }
        .tx.enter .tid { color: var(--good); }
        .tx.leaving { border-color: var(--bad); box-shadow: 0 0 0 1px var(--bad); opacity: 0.85; }
        .tx.leaving .tid { color: var(--bad); }
        .editing .tx .slot { cursor: pointer; border: 1px dashed var(--lt-3a3a5a, #3a3a5a); }
        .editing .tx .slot:hover { border-color: var(--accent2); }
        .frame {
            position: absolute;
            top: -24px;
            bottom: -6px;
            border: 2px solid var(--accent2);
            border-radius: 11px;
            pointer-events: none;
            transition: left 0.35s ease, width 0.35s ease, border-color 0.3s;
        }
        .frame .lbl {
            position: absolute; top: 2px; left: 6px; right: 6px;
            font-size: 0.7rem; color: var(--accent2); text-align: right;
            white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
        }
        .frame.empty { opacity: 0; }
        .legend { display: flex; flex-wrap: wrap; gap: 0.3rem 0.9rem; font-size: 0.75rem; color: var(--muted); margin-top: 0.55rem; }
        .legend i { display: inline-block; width: 11px; height: 11px; border-radius: 3px; border: 2px solid; margin-right: 0.3rem; vertical-align: -1px; }
        .formula { margin-top: 0.7rem; font-size: 0.86rem; color: var(--lt-c6c6d6, #c6c6d6); }
        .formula b { color: var(--warn); font-family: 'Space Mono', monospace; }
        .tools { display: flex; flex-wrap: wrap; gap: 0.4rem; align-items: center; margin-top: 0.7rem; padding-top: 0.7rem; border-top: 1px dashed var(--border); }
        .edit-hint { color: var(--muted); font-size: 0.8rem; }

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
        .explain .up { color: var(--lt-86efac, #86efac); }
        .explain .down { color: var(--lt-fca5a5, #fca5a5); }
        .phases { display: flex; flex-wrap: wrap; gap: 0.3rem; margin-top: 0.7rem; }
        .phase { flex: 1 1 auto; white-space: nowrap; text-align: center; font-size: 0.75rem; color: var(--muted); border: 1px solid var(--border); border-radius: 6px; padding: 0.15rem 0.2rem; }
        .phase.cur { color: var(--text); border-color: var(--accent); background: var(--lt-7c3aed-15, rgba(124, 58, 237, 0.15)); }
        .phase b { font-weight: 600; }

        /* ── SWUPA-List ── */
        .lhead, .lrow { display: grid; grid-template-columns: 4.4rem minmax(0, 1fr) 2.9rem 2.5rem; gap: 0.45rem; align-items: center; }
        .lhead { font-size: 0.72rem; color: var(--muted); padding: 0 0.5rem 0.3rem; }
        .lhead span:nth-child(n+3) { text-align: right; }
        .lists { display: grid; gap: 0.3rem; }
        .lrow { padding: 0.3rem 0.5rem; border-radius: 8px; border: 1px solid var(--lt-1e1e36, #1e1e36); background: var(--lt-0a0a14, #0a0a14); }
        .lrow .it { font-size: 0.84rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .lrow .ents { display: flex; flex-wrap: wrap; gap: 3px; min-width: 0; }
        .ent { font: 0.66rem/1.25 'Space Mono', monospace; border: 1px solid var(--lt-2c2c48, #2c2c48); border-radius: 5px; padding: 0.05rem 0.3rem; color: var(--lt-c6c6d6, #c6c6d6); white-space: nowrap; }
        .ent b { color: var(--lt-a5f3fc, #a5f3fc); font-weight: 700; }
        .ent.new { border-color: var(--good); color: var(--lt-bbf7d0, #bbf7d0); }
        .ent.gone { border-color: var(--lt-f87171-60, rgba(248, 113, 113, 0.6)); color: var(--lt-fca5a5, #fca5a5); text-decoration: line-through; opacity: 0.75; }
        .ent.gone b { color: var(--lt-fca5a5, #fca5a5); }
        .ent.max { box-shadow: inset 0 -2px 0 var(--accent); }
        .lrow .num2 { font: 700 0.8rem 'Space Mono', monospace; text-align: right; }
        .lrow .num2 small { display: block; font: 0.6rem/1.1 'Space Mono', monospace; color: var(--muted); font-weight: 400; }
        .lrow .num2.chg { color: var(--warn); }
        .lrow.ok .num2.es { color: var(--lt-86efac, #86efac); }
        .lrow.drop { opacity: 0.45; }
        .lrow.drop .it { text-decoration: line-through; }
        .lrow.inpat { border-color: var(--accent2); background: var(--lt-06b6d4-7, rgba(6, 182, 212, 0.07)); }
        .lrow.lastit { border-color: var(--warn); background: var(--lt-f59e0b-8, rgba(245, 158, 11, 0.08)); }
        .lrow.fresh { border-color: var(--good); }
        .lrow.removed { border-style: dashed; border-color: var(--lt-f87171-50, rgba(248, 113, 113, 0.5)); }
        .lnote { color: var(--muted); font-size: 0.78rem; margin-top: 0.5rem; }

        /* ── 合併兩個串列 ── */
        .pair-title { font-size: 0.92rem; line-height: 1.5; }
        .pair-title .pt { display: inline-block; border: 1px solid var(--border); border-radius: 7px; padding: 0 0.4rem; margin: 0 0.1rem; background: var(--panel-2); }
        .pair-title .pt.res { border-color: var(--accent); background: var(--lt-7c3aed-14, rgba(124, 58, 237, 0.14)); }
        .calc { margin-top: 0.55rem; font-size: 0.84rem; color: var(--lt-c6c6d6, #c6c6d6); background: var(--panel-2); border-radius: 8px; padding: 0.45rem 0.6rem; }
        .calc b { font-family: 'Space Mono', monospace; color: var(--text); }
        .calc .ok { color: var(--lt-86efac, #86efac); }
        .calc .no { color: var(--lt-fca5a5, #fca5a5); }
        .cmpbox { overflow-x: auto; margin-top: 0.55rem; border: 1px solid var(--border); border-radius: 10px; background: var(--lt-0a0a14, #0a0a14); }
        table.cmp { width: 100%; border-collapse: collapse; font: 0.74rem 'Space Mono', monospace; }
        table.cmp th { font: 0.68rem inherit; font-family: inherit; color: var(--muted); font-weight: 400; padding: 0.35rem 0.3rem; text-align: right; white-space: nowrap; border-bottom: 1px solid var(--border); }
        table.cmp td { padding: 0.28rem 0.3rem; text-align: right; white-space: nowrap; border-bottom: 1px solid var(--lt-1a1a2e, #1a1a2e); }
        table.cmp th:first-child, table.cmp td:first-child { text-align: left; padding-left: 0.5rem; }
        table.cmp tr:last-child td { border-bottom: none; }
        table.cmp tr.match td { background: var(--lt-22c55e-8, rgba(34, 197, 94, 0.08)); }
        table.cmp tr.match td.xy { color: var(--lt-86efac, #86efac); font-weight: 700; }
        table.cmp tr.nomatch td { color: var(--lt-6a6a85, #6a6a85); }
        table.cmp tr.skip td { color: var(--lt-4a4a66, #4a4a66); }
        table.cmp tr.stop td { background: var(--lt-f87171-12, rgba(248, 113, 113, 0.12)); }
        table.cmp td.bad { color: var(--lt-fca5a5, #fca5a5); font-weight: 700; }
        table.cmp td.fine { color: var(--lt-c6c6d6, #c6c6d6); }
        .verdict { margin-top: 0.55rem; font-size: 0.86rem; }
        .verdict.ok { color: var(--lt-86efac, #86efac); }
        .verdict.no { color: var(--lt-fca5a5, #fca5a5); }
        .placeholder { color: var(--muted); font-size: 0.86rem; }
        .order { display: flex; flex-wrap: wrap; gap: 0.3rem; align-items: center; margin-top: 0.55rem; font-size: 0.8rem; }
        .order .o { border: 1px solid var(--border); border-radius: 7px; padding: 0.05rem 0.4rem; }
        .order .o.ok { border-color: var(--lt-22c55e-55, rgba(34, 197, 94, 0.55)); }
        .order .o.no { opacity: 0.5; text-decoration: line-through; }
        .order .o small { font-family: 'Space Mono', monospace; color: var(--muted); margin-left: 0.25rem; }
        .order .arrow { color: var(--muted); }

        /* ── 結果 ── */
        .tag-state { font-size: 0.75rem; color: var(--muted); border: 1px solid var(--border); border-radius: 6px; padding: 0.05rem 0.45rem; }
        .tag-state.fresh { color: var(--accent2); border-color: var(--accent2); }
        .levels { display: grid; gap: 0.45rem; }
        .level { display: grid; grid-template-columns: 2.8em 1fr; gap: 0.5rem; align-items: start; }
        .level .tag { font: 700 0.8rem 'Space Mono', monospace; color: var(--accent2); padding-top: 0.2rem; }
        .level .items { display: flex; flex-wrap: wrap; gap: 0.35rem; min-width: 0; }
        .pat {
            font-size: 0.82rem; border: 1px solid var(--lt-22c55e-50, rgba(34, 197, 94, 0.5)); border-radius: 7px; padding: 0.12rem 0.5rem;
            background: var(--panel-2); color: var(--text); font-family: inherit; cursor: pointer; text-align: left;
        }
        .pat:hover { border-color: var(--accent2); }
        .pat .n { font: 700 0.74rem 'Space Mono', monospace; margin-left: 0.35rem; color: var(--lt-86efac, #86efac); }
        .pat.new { box-shadow: 0 0 0 2px var(--good); }
        .pat.sel { outline: 2px solid var(--warn); outline-offset: 1px; }
        .empty { color: var(--muted); font-size: 0.85rem; }
        .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.5rem; margin-top: 0.9rem; }
        .stat { background: var(--panel-2); border-radius: 10px; padding: 0.55rem 0.6rem; min-width: 0; }
        .stat .v { font: 700 1.2rem 'Space Mono', monospace; }
        .stat .k { color: var(--muted); font-size: 0.75rem; line-height: 1.35; }
        .brute { margin-top: 0.7rem; font-size: 0.85rem; color: var(--muted); }
        .brute b { color: var(--lt-86efac, #86efac); }
        .brute b.bad { color: var(--bad); }

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
        .notes > * { min-width: 0; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr; align-items: start; } }
        .notes p, .notes li { color: var(--lt-c6c6d6, #c6c6d6); font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; }
        .notes b { color: var(--text); }
        .notes a { color: var(--accent2); }
        .paper { margin-top: 1rem; }
        .paper .cite { color: var(--lt-c6c6d6, #c6c6d6); font-size: 0.9rem; border-left: 3px solid var(--accent); padding-left: 0.7rem; }
        .paper .cite i { color: var(--text); }
        .paper .cite a { color: var(--accent2); word-break: break-all; }
        .paper p, .paper li { color: var(--lt-c6c6d6, #c6c6d6); font-size: 0.92rem; }
        .paper ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; margin-top: 0.4rem; }
        .paper b { color: var(--text); }
        .paper a { color: var(--accent2); }
        .paper h3 { color: var(--accent2); font-size: 0.85rem; margin: 0.9rem 0 0.3rem; }

        @media (max-width: 600px) {
            .tx { width: 44px; }
            .tx .slot { height: 22px; font-size: 11px; margin: 1px 2px; }
            .tx .slot .p { font-size: 0.58rem; }
            .lhead, .lrow { grid-template-columns: 3.9rem minmax(0, 1fr) 2.7rem 2.3rem; gap: 0.35rem; }
            .lrow { padding: 0.3rem 0.4rem; }
            .lhead { padding: 0 0.4rem 0.3rem; }
            .lrow .it { font-size: 0.78rem; }
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
        <div class="kicker">RESEARCH DEMO · UNCERTAIN STREAM MINING</div>
        <h1>不確定資料的滑動視窗探勘<small>SWUPA：每樣商品都有「存在機率」，交易一批一批進來，只看最近幾批</small></h1>
        <p class="intro">
            <a href="apriori.html">Apriori</a> 那份 8 筆交易裡，「有買」就是有買。但如果交易是<b>無人商店的攝影機</b>辨識出來的，
            每樣商品只有一個<b>信心值</b>：「這位客人 90% 拿了咖啡、40% 拿了牛奶」。這種資料叫<b>不確定資料</b>，數字叫<b>存在機率</b>。
            一個組合在一筆交易裡的機率是各商品機率相乘，整個視窗加起來就是<b>期望支持度</b>。
            資料又是串流，只想看最近的趨勢，所以跟 <a href="sliding-window.html">滑動視窗</a> 一樣只留最近幾批；
            記資料的方法則像 <a href="eclat.html">Eclat</a> 的垂直格式：每個商品一條「出現在哪幾筆、機率多少」的串列。
            這頁照 2026 年 ESWA 的論文 SWUPA 一步一步做。
        </p>

        <div class="card stream-card">
            <div class="card-head">
                <h2>不確定的交易串流</h2>
                <div class="seg" id="dataset">
                    <button data-ds="shop" class="active">超商 8 筆</button>
                    <button data-ds="paper">論文 Table 3</button>
                </div>
            </div>
            <div class="params">
                <div class="param">
                    <span>一批 b 筆</span>
                    <button class="btn stepper" id="b-minus" aria-label="一批少一筆">−</button>
                    <span class="val" id="b-val">2</span>
                    <button class="btn stepper" id="b-plus" aria-label="一批多一筆">+</button>
                </div>
                <div class="param">
                    <span>視窗 w 批</span>
                    <button class="btn stepper" id="w-minus" aria-label="視窗少一批">−</button>
                    <span class="val" id="w-val">2</span>
                    <button class="btn stepper" id="w-plus" aria-label="視窗多一批">+</button>
                </div>
                <div class="param">
                    <span>門檻 δ</span>
                    <button class="btn stepper" id="d-minus" aria-label="門檻降低">−</button>
                    <span class="val" id="d-val">30%</span>
                    <button class="btn stepper" id="d-plus" aria-label="門檻提高">+</button>
                </div>
            </div>
            <div class="belt" id="belt">
                <div class="belt-inner" id="belt-inner"></div>
            </div>
            <div class="legend">
                <span><i style="border-color:var(--accent2)"></i>視窗（最近 w 批）</span>
                <span><i style="border-color:var(--good)"></i>剛進來的一批</span>
                <span><i style="border-color:var(--bad)"></i>最舊、要離開</span>
                <span><i style="border-color:#3a3a5a;border-style:dashed"></i>還沒進來</span>
                <span><i style="border-color:var(--warn)"></i>目前在看的樣式</span>
            </div>
            <div class="formula" id="formula"></div>
            <div class="tools">
                <button class="btn" id="btn-edit">✏️ 點格子改機率</button>
                <button class="btn" id="btn-reset">恢復範例</button>
                <span class="edit-hint" id="edit-hint" style="visibility:hidden">點一格：沒有 → 1.0 → 0.9 → … → 0.1 → 沒有</span>
            </div>
        </div>

        <div class="layout">
            <div>
                <div class="card">
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
                    <div class="phases" id="phases"></div>
                </div>

                <div class="card">
                    <div class="card-head">
                        <h2>全域 SWUPA-List</h2>
                        <span class="tag-state" id="list-state"></span>
                    </div>
                    <div class="lhead"><span>商品</span><span>entry（TID 機率），由舊到新</span><span>ExpSup</span><span>MaxEP</span></div>
                    <div class="lists" id="lists"></div>
                    <div class="lnote" id="lnote"></div>
                </div>
            </div>

            <div>
                <div class="card">
                    <div class="card-head">
                        <h2>合併兩個串列</h2>
                    </div>
                    <div id="pair"></div>
                </div>

                <div class="card">
                    <div class="card-head">
                        <h2>這個視窗的結果</h2>
                        <span class="tag-state" id="res-state"></span>
                    </div>
                    <div class="levels" id="levels"></div>
                    <div class="stats">
                        <div class="stat"><div class="v" id="st-join">0</div><div class="k">建過的串列（合併）</div></div>
                        <div class="stat"><div class="v" id="st-over">0</div><div class="k">overExpSup 直接剪掉</div></div>
                        <div class="stat"><div class="v" id="st-pp">0</div><div class="k">ppCLw 比到一半停</div></div>
                    </div>
                    <div class="brute" id="brute"></div>
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
            </div>
        </div>

        <div class="card paper">
            <h2>📄 論文</h2>
            <p class="cite">Seungwan Park, Doyoung Kim, Seongbin Park, Unil Yun.
                <i>Uncertainty oriented pattern extracting and analyzing via sliding window control.</i>
                Expert Systems With Applications, Vol. 297, Article 129309, 2026.
                DOI：<a href="https://doi.org/10.1016/j.eswa.2025.129309" target="_blank" rel="noopener">10.1016/j.eswa.2025.129309</a></p>
            <h3>這篇在做什麼（白話）</h3>
            <ul>
                <li><b>問題：</b>資料裡每個商品帶一個 0～1 的存在機率（論文舉的例子是折扣券的折扣比例；這頁換成攝影機的辨識信心），
                    資料又一直進來。以前的不確定樣式方法（例如作者群前一篇的 LIU，或 ILUNA）把<b>所有累積的資料</b>都算進去，看不出「最近」的趨勢。</li>
                <li><b>做法：</b>提出 SWUPA。交易切成固定大小的批次，視窗只裝最近 w 批；每個商品一條 <b>SWUPA-List</b>，記 (TID, 機率)、ExpSup、MaxEP。
                    新批次進來時，最舊那批的 entry 因為 TID 最小，全都在串列最前面，砍掉就好，不用重掃資料。</li>
                <li><b>剪枝：</b>兩個都滿足反單調性的上界：<b>overExpSup</b>（X 的期望支持度 × 新商品的最大機率，合併前就能判斷），
                    和 <b>ppCLw</b>（合併到一半，「已經算到的＋剩下幾筆 × X 的最大機率」還不到門檻就停）。前者便宜但寬鬆，後者要開始建串列但比較緊。</li>
                <li><b>實驗：</b>在 FIMI 的真實資料和 IBM 產生器的合成資料上，跟 LIU、ILUNA、U-WFI（後兩者改成同樣輸出的版本）比，執行時間、記憶體和擴充性都比較好；
                    另外做了概念飄移（concept drift）的案例研究。</li>
            </ul>
            <h3>跟這個網站其他 Demo 的關係</h3>
            <ul>
                <li><a href="sliding-window.html">滑動視窗</a>：一樣「新的進來、舊的離開」，但那頁一筆一筆滑、記每個組合的次數；這篇一批一批滑、只記單一商品的串列，組合要用的時候再合併。</li>
                <li><a href="eclat.html">Eclat</a>：「每個商品記出現在哪幾筆」的垂直格式，合併就是 TID 取交集；這裡多記了機率。</li>
                <li><a href="high-utility.html">HUI-Miner</a>：同樣是 list 結構＋深度優先合併；ppCLw「已算的＋剩下的上限」跟效益串列的剩餘效益剪枝是同一種想法。</li>
                <li><a href="incremental.html">增量探勘</a>：論文比較的 LIU、ILUNA 是增量（landmark）做法，資料只加不減；滑動視窗多了「刪掉最舊的」。</li>
            </ul>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼剪掉的一定不會是答案？</h2>
                <p><b>反單調性：</b>組合在一筆交易的機率是各商品機率相乘，每個機率都 ≤ 1，所以多加一個商品只會一樣或變小，而且出現的交易只會變少。
                    一個組合的期望支持度不到門檻，包含它的更大組合也一定不到，可以整個分支不看。</p>
                <p style="margin-top:0.5rem"><b>overExpSup：</b>X 加上商品 i 之後，每一筆的機率是「X 的機率 × i 的機率」，而 i 的機率不會超過 i 在視窗裡的最大值 MaxEP(i)。
                    所以 ExpSup(X) × MaxEP(i) 一定 ≥ 真正的期望支持度，它不到門檻，真的就更不到。
                    （論文演算法 2 第 3 行寫成 suffix 串列自己的 MaxEP；在第二層以後那個值可能比 i 的機率小、變成低估，這頁照定義 4 用商品 i 自己的 MaxEP。）</p>
                <p style="margin-top:0.5rem"><b>ppCLw：</b>合併是把 X 的 entry 從頭走到尾。走到一半時，還沒走的最多 size(X) − cur_size 筆，每筆的機率都不會超過 MaxEP(X)，
                    所以「目前累計＋剩下筆數 × MaxEP(X)」也是上界。它比 overExpSup 緊，因為已經算到的部分是真的值。</p>
                <p style="margin-top:0.5rem"><b>移除最舊的一批：</b>TID 照到達順序編，串列裡由小到大，最舊那批一定在最前面一段。刪完之後 ExpSup 少了那一段，
                    但 MaxEP 要從剩下的重找（最大值可能剛好被刪掉）。門檻 w × b × δ 每個視窗都一樣，所以上一個視窗不夠的組合，下一個視窗可能變成答案（論文 Lemma 1）。</p>
            </div>
            <div class="card">
                <h2>優缺點，和實驗室在研究什麼</h2>
                <ul>
                    <li><b>比「記所有組合的次數」省很多：</b>只為單一商品存串列，組合是分析時才合併出來，不會像計數表一樣 2<sup>k</sup> 爆掉。</li>
                    <li><b>代價是每個視窗都要重挖一次：</b>串列一直保持最新，但合併、剪枝在每次視窗滿的時候從頭做。視窗很大、要很頻繁地看結果時，這部分是主要成本。</li>
                    <li><b>一批一批滑：</b>比一筆一筆滑省事（批次之間不重疊，刪一段就好），但結果只在每一批結束時更新。</li>
                    <li><b>期望支持度只是平均：</b>它告訴你「平均會出現幾次」，不保證「有 90% 機率至少出現 k 次」。要後者得算機率分布（probabilistic frequent pattern），貴很多。</li>
                    <li><b>延伸：</b>實驗室的方向（增量、串流、高效益）都能跟不確定資料組合，例如不確定的高效益樣式、衰減視窗（damped window，舊資料慢慢變輕而不是直接刪掉）。
                        論文結論也承認：結果樣式很多時，計算量和記憶體在超高速串流或記憶體小的裝置上仍是限制。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           SWUPA 一步一步看
           網頁裡用 JavaScript 照著同樣的方法把整條串流跑一次，把每一步記下來，
           上一步／下一步只是在這些紀錄之間移動；下面的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = /*CODE_JSON*/null;
        const EPS = 1e-9;   // 浮點數誤差：比門檻小不到 1e-9 也算達標（跟 Java / Python 一樣）

        const EMOJI = { '咖啡': '☕', '麵包': '🍞', '牛奶': '🥛', '飯糰': '🍙', '茶葉蛋': '🥚', '洋芋片': '🥔' };
        const DATASETS = {
            /* Apriori 那一頁的同一份 8 筆交易，每樣商品加上攝影機辨識的信心 */
            shop: {
                items: ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片'], b: 2, w: 2, pct: 30,
                rows: [
                    { '咖啡': 0.9, '麵包': 0.4, '牛奶': 0.4 },
                    { '咖啡': 0.5, '麵包': 1.0, '茶葉蛋': 0.8 },
                    { '咖啡': 0.8, '麵包': 0.6, '牛奶': 0.5, '飯糰': 0.3 },
                    { '麵包': 0.3, '牛奶': 0.4, '洋芋片': 0.9 },
                    { '咖啡': 0.8, '牛奶': 1.0, '茶葉蛋': 0.8 },
                    { '咖啡': 0.7, '麵包': 0.3, '牛奶': 0.6, '茶葉蛋': 0.8 },
                    { '飯糰': 1.0, '茶葉蛋': 0.4, '洋芋片': 0.6 },
                    { '咖啡': 0.3, '麵包': 1.0, '飯糰': 0.6 }
                ]
            },
            /* 論文 Table 3 的例子：一批 2 筆、視窗 3 批、δ = 20%（minSup = 1.2） */
            paper: {
                items: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'], b: 2, w: 3, pct: 20,
                rows: [
                    { A: 0.4, B: 0.5, C: 0.6, G: 0.8, H: 0.4 },
                    { A: 0.5, C: 0.9, E: 0.1, F: 0.2 },
                    { B: 0.5, D: 0.7, E: 0.6, G: 0.1, H: 0.3 },
                    { A: 0.5, C: 0.7, E: 0.3, F: 0.6 },
                    { D: 0.3, E: 0.8, H: 0.7 },
                    { A: 0.4, B: 0.9, D: 0.8, E: 0.2 },
                    { A: 0.9, C: 1.0, D: 0.5, E: 0.7, G: 0.1 },
                    { D: 0.1, E: 0.4, G: 0.7 }
                ]
            }
        };

        const $ = id => document.getElementById(id);
        let dsKey = 'shop';
        let ITEMS = DATASETS.shop.items;
        let db = [];
        let bSize = 2, wSize = 2, pct = 30;
        let trace = [];
        let cursor = 0;
        let lang = 'java';
        let timer = null;
        let editing = false;
        let selKey = null;      // 結果裡點選的樣式：輸送帶上標出來

        /* 跟 Java 的 compareTo、Python 的字串比較同一個順序（依字碼） */
        const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
        const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        const canon = items => [...items].sort((a, b) => ITEMS.indexOf(a) - ITEMS.indexOf(b));
        const keyOf = items => [...items].sort(cmp).join('|');
        const fmt = items => '{' + canon(items).join(', ') + '}';
        const emo = items => canon(items).map(i => EMOJI[i] || i).join(dsKey === 'shop' ? '' : '');
        const lab = item => EMOJI[item] ? `${EMOJI[item]} ${item}` : item;
        const num = v => String(Number(v.toFixed(3)));          // 1.2、0.144、1
        const pr = v => v.toFixed(1);                           // 原始機率：0.9、1.0
        const T = tid => `T${tid}`;
        const ge = (v, ms) => v >= ms - EPS;

        function loadDataset(k) {
            dsKey = k;
            const d = DATASETS[k];
            ITEMS = d.items;
            db = d.rows.map(r => ({ ...r }));
            bSize = d.b; wSize = d.w; pct = d.pct;
            selKey = null;
        }

        /* ---------- SWUPA-List ---------- */
        const newList = items => ({ items, tids: [], eps: [], exp: 0, max: 0 });
        function addEntry(L, tid, ep) {
            L.tids.push(tid);
            L.eps.push(ep);
            L.exp += ep;
            L.max = Math.max(L.max, ep);
        }
        function epAt(L, tid) {
            let lo = 0, hi = L.tids.length - 1;
            while (lo < hi) {
                const mid = (lo + hi) >> 1;
                if (L.tids[mid] < tid) lo = mid + 1; else hi = mid;
            }
            return L.eps[lo];
        }
        /* 期望支持度由小到大；一樣大就比商品名稱（跟 Python 的 tuple 排序一樣） */
        const byExp = (p, q) => (p.exp < q.exp ? -1 : p.exp > q.exp ? 1 : cmp(p.items.join('\u0000'), q.items.join('\u0000')));

        function batchesOf(rows, B) {
            const txs = rows.map((t, k) => ({ tid: k + 1, t }));
            const out = [];
            for (let k = 0; k + B <= txs.length; k += B) out.push(txs.slice(k, k + B));
            return out;
        }

        /* 暴力法：列舉視窗裡出現過的商品的所有組合，直接算期望支持度 */
        function bruteForce(rows, tids, ms) {
            const present = ITEMS.filter(i => tids.some(t => rows[t - 1][i] !== undefined));
            const out = new Map();
            for (let mask = 1; mask < (1 << present.length); mask++) {
                const set = present.filter((_, k) => (mask >> k) & 1);
                let e = 0;
                tids.forEach(t => {
                    if (set.every(i => rows[t - 1][i] !== undefined)) e += set.reduce((p, i) => p * rows[t - 1][i], 1);
                });
                if (ge(e, ms)) out.set(keyOf(set), e);
            }
            return { map: out, total: (1 << present.length) - 1 };
        }

        /* ---------- 照著程式把整條串流跑一次，記下每一步 ---------- */
        function buildTrace(rows, B, Wn, P) {
            const steps = [];
            const batches = batchesOf(rows, B);
            const lists = new Map();      // 全域 SWUPA-List：商品 -> 串列
            const win = [];               // 視窗裡是第幾批（0 起算）
            let winNo = 0, snap = [], log = [];
            const takeSnap = () => { snap = [...lists.values()].map(L => ({ items: L.items, tids: L.tids.slice(), eps: L.eps.slice(), exp: L.exp, max: L.max })); };
            const push = (kind, extra) => steps.push({ kind, win: win.slice(), winNo, lists: snap, ...extra });
            push('start', {});
            batches.forEach((batch, h) => {
                // ① 視窗滿了：最舊的一批離開，每個串列從頭砍掉 TID ≤ 那批最後一筆的 entry
                if (win.length === Wn) {
                    const oldH = win.shift();
                    const last = batches[oldH][batches[oldH].length - 1].tid;
                    const gone = [], before = new Map(), dropped = [];
                    [...lists.keys()].forEach(item => {
                        const L = lists.get(item);
                        before.set(item, { exp: L.exp, max: L.max });
                        let k = 0;
                        while (k < L.tids.length && L.tids[k] <= last) { gone.push({ item, tid: L.tids[k], ep: L.eps[k] }); k++; }
                        if (k === L.tids.length) { lists.delete(item); dropped.push(item); return; }
                        const tids = L.tids.slice(k), eps = L.eps.slice(k);
                        L.tids = []; L.eps = []; L.exp = 0; L.max = 0;
                        tids.forEach((t, x) => addEntry(L, t, eps[x]));   // MaxEP 不能用減的，重新算
                    });
                    takeSnap();
                    push('expire', { h: oldH, batchTids: batches[oldH].map(x => x.tid), gone, before, dropped });
                }
                // ② 新的一批進來：每個 (TID, 機率) 接在串列尾端
                win.push(h);
                const added = new Set(), created = [], before = new Map();
                lists.forEach((L, item) => before.set(item, { exp: L.exp, max: L.max }));
                batch.forEach(({ tid, t }) => {
                    Object.keys(t).sort(cmp).forEach(item => {
                        if (!lists.has(item)) { lists.set(item, newList([item])); created.push(item); }
                        addEntry(lists.get(item), tid, t[item]);
                        added.add(item + '|' + tid);
                    });
                });
                takeSnap();
                const full = win.length === Wn;
                push('add', { h, batchTids: batch.map(x => x.tid), added, created, before, full });
                if (!full) return;

                // ③ 視窗滿了：排序、算門檻、兩兩合併
                winNo++;
                const ms = Wn * B * P / 100;
                const order = [...lists.values()].map(L => ({ ...L, tids: L.tids.slice(), eps: L.eps.slice() })).sort(byExp);   // 複製一份：之後的批次還會改串列，這一步的紀錄要停在當下
                const max1 = new Map(order.map(L => [L.items[0], L.max]));
                const valid = order.filter(L => ge(L.exp, ms));
                const found = [];         // 這個視窗找到的樣式（只會往後加）
                valid.forEach(L => found.push({ key: keyOf(L.items), items: L.items, exp: L.exp }));
                const stats = { join: 0, over: 0, pp: 0 };
                log = [];
                const winTids = win.flatMap(x => batches[x].map(y => y.tid));
                push('sort', { ms, order: order.map(L => ({ item: L.items[0], exp: L.exp, max: L.max, ok: ge(L.exp, ms) })), found, nFound: found.length, stats: { ...stats }, winTids });

                const mineLists = (prefix, sl, depth) => {
                    sl.forEach((x, k) => {
                        const nxt = [];
                        sl.slice(k + 1).forEach(y => {
                            const last = y.items[y.items.length - 1];
                            const over = x.exp * max1.get(last);
                            const items = x.items.concat([last]);
                            const base = { ms, X: x, Y: y, prefix, last, maxLast: max1.get(last), over, items, depth, found, winTids };
                            if (!ge(over, ms)) {
                                stats.over++;
                                log.push(['over', items]);
                                push('pair', { ...base, verdict: 'over', rows: [], nFound: found.length, stats: { ...stats } });
                                return;
                            }
                            // 兩邊的 TID 一起往前走；同一筆才算，邊算邊檢查 ppCLw
                            stats.join++;
                            const xy = newList(items);
                            const rowsX = x.tids.map((tid, r) => ({ tid, xe: x.eps[r], ye: null, pe: null, xy: null, cur: null, bound: null, state: 'skip' }));
                            let i = 0, j = 0, stopped = false;
                            const n = x.tids.length;
                            while (i < n && j < y.tids.length) {
                                if (x.tids[i] === y.tids[j]) {
                                    const pe = prefix ? epAt(prefix, x.tids[i]) : 1.0;   // 前綴在兩邊各乘了一次，除掉一次
                                    const ep = x.eps[i] * y.eps[j] / pe;
                                    addEntry(xy, x.tids[i], ep);
                                    Object.assign(rowsX[i], { ye: y.eps[j], pe: prefix ? pe : null, xy: ep, cur: xy.exp, state: 'match' });
                                    i++;
                                    j++;
                                    if (i < n) {
                                        const bound = xy.exp + (n - i) * x.max;
                                        rowsX[i - 1].bound = bound;
                                        if (!ge(bound, ms)) { rowsX[i - 1].stop = true; stopped = true; break; }
                                    }
                                } else if (x.tids[i] < y.tids[j]) { rowsX[i].state = 'nomatch'; i++; }
                                else j++;
                            }
                            if (!stopped) for (; i < n; i++) rowsX[i].state = 'nomatch';
                            if (stopped) {
                                stats.pp++;
                                log.push(['ppclw', items]);
                                push('pair', { ...base, verdict: 'ppclw', rows: rowsX, cur: xy.exp, at: rowsX.findIndex(r => r.stop), nFound: found.length, stats: { ...stats } });
                                return;
                            }
                            const ok = ge(xy.exp, ms);
                            if (ok) {
                                found.push({ key: keyOf(items), items, exp: xy.exp });
                                nxt.push(xy);
                            }
                            log.push([ok ? 'ok' : 'low', items]);
                            push('pair', { ...base, verdict: ok ? 'ok' : 'low', rows: rowsX, exp: xy.exp, xyList: xy, nFound: found.length, newKey: ok ? keyOf(items) : null, stats: { ...stats } });
                        });
                        if (nxt.length > 1) mineLists(x, nxt, depth + 1);
                    });
                };
                mineLists(null, valid, 1);
                const brute = bruteForce(rows, winTids, ms);
                const same = brute.map.size === found.length && found.every(f => brute.map.has(f.key) && Math.abs(brute.map.get(f.key) - f.exp) < 1e-9);
                push('winres', { ms, found, nFound: found.length, stats: { ...stats }, brute: brute.total, same, log: log.slice(), winTids, last: h === batches.length - 1 });
            });
            push('end', { leftover: rows.length - batches.length * B });
            return steps;
        }

        /* 給測試用：每個視窗的結果（商品照字碼排）、合併紀錄 */
        function simulate(rows, B, Wn, P) {
            return buildTrace(rows, B, Wn, P).filter(s => s.kind === 'winres').map(s => ({
                tids: s.winTids, ms: s.ms,
                found: s.found.map(f => [[...f.items].sort(cmp), f.exp]),
                log: s.log, same: s.same
            }));
        }

        /* ---------- 說明文字 ---------- */
        const range = tids => `${T(tids[0])}–${T(tids[tids.length - 1])}`;
        const nameList = (arr, n = 3) => (arr.length > n ? arr.slice(0, n).join('、') + ` 等 ${arr.length} 個` : arr.join('、'));
        function describe(s) {
            switch (s.kind) {
                case 'start':
                    return `每格的數字是<b>存在機率</b>：這筆交易「真的有這樣商品」的把握。一個組合在一筆交易的機率是各商品機率<b>相乘</b>，` +
                        `把視窗裡每一筆加起來就是<b>期望支持度 ExpSup</b>。交易每 ${bSize} 筆一批、視窗裝 ${wSize} 批，` +
                        `門檻 minSup = ${wSize} × ${bSize} × ${pct}% = <b>${num(wSize * bSize * pct / 100)}</b>。按「下一步」讓第一批進來。`;
                case 'add': {
                    const n = s.added.size;
                    let out = `B${s.h + 1}（${range(s.batchTids)}）進入視窗：${n} 個 (TID, 機率) 接在各商品串列的<b>尾端</b>（TID 最大＝最新），` +
                        `ExpSup 加上去，比 MaxEP 大就換掉。`;
                    if (s.created.length) out += `${s.created.map(lab).join('、')} 第一次出現，新建串列。`;
                    out += s.full ? `視窗裝滿 ${wSize} 批了，<b>開始分析</b>。` : `視窗現在 ${s.win.length}/${wSize} 批，還沒滿，先不分析。`;
                    return out;
                }
                case 'expire': {
                    const changed = s.lists.filter(L => s.before.has(L.items[0]) && Math.abs(s.before.get(L.items[0]).max - L.max) > EPS);
                    let out = `視窗滿了，最舊的 B${s.h + 1}（${range(s.batchTids)}）要離開。TID 越小越舊，所以要刪的 entry 都在每個串列的<b>最前面</b>，` +
                        `從頭砍掉就好，共 <b class="down">${s.gone.length}</b> 個。`;
                    if (changed.length) {
                        const c = changed[0], b0 = s.before.get(c.items[0]);
                        out += `${lab(c.items[0])} 的 MaxEP 從 ${pr(b0.max)} 變成 ${pr(c.max)}：最大的那筆被刪了，只能從剩下的重找，不能用減的。`;
                    } else out += `每個串列的 MaxEP 都還在，沒有變。`;
                    if (s.dropped.length) out += `${s.dropped.map(lab).join('、')} 整條串列空了，刪掉。`;
                    return out;
                }
                case 'sort': {
                    const bad = s.order.filter(o => !o.ok).map(o => lab(o.item));
                    return `W${s.winNo}（${range(s.winTids)}）門檻 minSup = ${wSize} × ${bSize} × ${pct}% = <b>${num(s.ms)}</b>。` +
                        `串列照 ExpSup <b>由小到大</b>排好。` +
                        (bad.length ? `${nameList(bad)} 不到門檻，直接淘汰：機率都 ≤ 1，多乘一個只會變小，包含它的組合也不可能夠（反單調）。` : `每個商品都夠門檻。`) +
                        `留下的 ${s.nFound} 個都是答案，接著兩兩合併。`;
                }
                case 'pair': {
                    const head = `${fmt(s.X.items)} + ${lab(s.last)} → <b>${fmt(s.items)}</b>：上界 overExpSup = ${num(s.X.exp)} × MaxEP(${s.last}) ${pr(s.maxLast)} = ${num(s.over)}`;
                    if (s.verdict === 'over') return head + ` <span class="down">&lt; ${num(s.ms)}</span>。就算每一筆的 ${s.last} 都是最大機率也不夠，<b>連串列都不用建</b>，剪掉。`;
                    if (s.verdict === 'ppclw') {
                        const r = s.rows[s.at], left = s.rows.length - s.at - 1;
                        return head + ` ≥ ${num(s.ms)}，開始兩邊 TID 一起往前比。比到 ${T(r.tid)} 時累計 ${num(r.cur)}，X 還剩 ${left} 筆，每筆最多 MaxEP(X) = ${pr(s.X.max)}：` +
                            `${num(r.cur)} + ${left} × ${pr(s.X.max)} = ${num(r.bound)} <span class="down">&lt; ${num(s.ms)}</span>，<b>ppCLw 成立</b>，後面不用比，這條串列丟掉。`;
                    }
                    const m = s.rows.filter(r => r.state === 'match').length;
                    return head + ` ≥ ${num(s.ms)}，兩邊 TID 一起往前比，共同的有 ${m} 筆，每筆機率 = X × Y${s.prefix ? ` ÷ 前綴 ${fmt(s.prefix.items)}` : ''}。` +
                        `ExpSup = <b>${num(s.exp)}</b> ` + (s.verdict === 'ok'
                            ? `<span class="up">≥ ${num(s.ms)}，是答案</span>，之後還能當前綴繼續長。`
                            : `<span class="down">&lt; ${num(s.ms)}</span>，不夠，丟掉。`);
                }
                case 'winres':
                    return `W${s.winNo} 分析完：共 <b>${s.nFound}</b> 個樣式。建了 ${s.stats.join} 條串列，overExpSup 剪掉 ${s.stats.over} 次、ppCLw 中途停 ${s.stats.pp} 次。` +
                        `暴力法把視窗裡 ${s.brute} 個組合全部算一遍，結果${s.same ? '一模一樣 ✓' : '不一樣 ✗'}。` +
                        (s.last ? '' : `下一批進來時，先移掉最舊的一批。`);
                case 'end':
                    return `串流用完了` + (s.leftover ? `（最後 ${s.leftover} 筆湊不滿一批，先等著）` : '') + `。真正的串流不會停，每來一批就重複「移掉最舊的、接上新的、重新合併」。` +
                        `可以換成「論文 Table 3」對照論文的 Example 1–4，或調 δ、改機率看看。`;
            }
            return '';
        }

        const CODE_TAG = { start: 'start', add: 'add', expire: 'expire', sort: 'sort', winres: 'result', end: 'loop' };
        const codeTag = s => (s.kind === 'pair' ? (s.verdict === 'over' ? 'over' : s.verdict === 'ppclw' ? 'ppclw' : 'join') : CODE_TAG[s.kind]);

        /* ---------- 輸送帶 ---------- */
        let beltBatches = [];
        function buildBelt() {
            const inner = $('belt-inner');
            inner.innerHTML = '';
            const nb = Math.floor(db.length / bSize);
            beltBatches = [];
            for (let h = 0; h * bSize < db.length; h++) {
                const g = document.createElement('div');
                g.className = 'batch' + (h >= nb ? ' extra' : '');
                g.innerHTML = '<span class="blabel"></span><div class="bt"></div>';
                g.querySelector('.blabel').textContent = h < nb ? `B${h + 1}` : '不滿一批';
                const box = g.querySelector('.bt');
                for (let k = h * bSize; k < Math.min(db.length, (h + 1) * bSize); k++) {
                    const card = document.createElement('div');
                    card.className = 'tx';
                    card.dataset.k = k;
                    card.innerHTML = `<span class="tid"></span>` + ITEMS.map(it => `<div class="slot" data-i="${esc(it)}"></div>`).join('');
                    card.querySelector('.tid').textContent = T(k + 1);
                    box.appendChild(card);
                }
                inner.appendChild(g);
                beltBatches.push(g);
            }
            const frame = document.createElement('div');
            frame.className = 'frame empty';
            frame.id = 'frame';
            frame.innerHTML = '<span class="lbl"></span>';
            inner.appendChild(frame);
            fillSlots();
        }
        function fillSlots() {
            $('belt-inner').querySelectorAll('.tx').forEach(card => {
                const t = db[Number(card.dataset.k)];
                card.querySelectorAll('.slot').forEach(sl => {
                    const it = sl.dataset.i, p = t[it];
                    sl.className = 'slot ' + (p !== undefined ? 'on' : 'off');
                    sl.title = p !== undefined ? `${it}：${pr(p)}` : `${it}：沒有`;
                    if (p !== undefined) {
                        sl.style.setProperty('--p', p);
                        sl.innerHTML = `<span class="e"></span><span class="p"></span>`;
                        sl.querySelector('.e').textContent = EMOJI[it] || it;
                        sl.querySelector('.p').textContent = p >= 1 ? '1' : pr(p).slice(1);
                    } else sl.innerHTML = '';
                });
            });
        }

        function renderBelt(s, smooth) {
            const inWin = new Set(s.win);
            const lo = s.win.length ? s.win[0] : null;
            const focus = s.kind === 'pair' ? s.items : selKey ? selKey.split('|') : null;
            $('belt-inner').querySelectorAll('.tx').forEach(card => {
                const k = Number(card.dataset.k), h = Math.floor(k / bSize);
                const st = inWin.has(h) ? 'in' : (lo !== null && h < lo) || s.kind === 'end' ? 'past' : 'future';
                let cls = 'tx' + (st === 'past' ? ' past' : st === 'future' ? ' future' : '');
                if (s.kind === 'add' && h === s.h) cls += ' enter';
                if (s.kind === 'expire' && h === s.h) cls = 'tx leaving';
                if (card.className !== cls) card.className = cls;
                const hit = focus && st === 'in' && focus.every(x => db[k][x] !== undefined);
                card.querySelectorAll('.slot').forEach(sl => sl.classList.toggle('hit', !!hit && focus.includes(sl.dataset.i)));
            });
            const frame = $('frame');
            if (!s.win.length || measuringBlocks) { if (!s.win.length) frame.className = 'frame empty'; return; }
            const a = beltBatches[s.win[0]], b = beltBatches[s.win[s.win.length - 1]];
            const left = a.offsetLeft - 6, width = b.offsetLeft + b.offsetWidth + 6 - left;
            frame.style.transition = smooth ? '' : 'none';
            frame.style.left = left + 'px';
            frame.style.width = width + 'px';
            frame.className = 'frame';
            frame.querySelector('.lbl').textContent = s.winNo && s.win.length === wSize ? `W${s.winNo}` : `${s.win.length}/${wSize} 批`;
            if (!smooth) { void frame.offsetWidth; frame.style.transition = ''; }
            // 只捲輸送帶本身：讓視窗右邊（新進來的那端）看得到
            const belt = $('belt');
            const right = $('belt-inner').offsetLeft + b.offsetLeft + b.offsetWidth + 40;
            belt.scrollTo({ left: Math.max(0, right - belt.clientWidth), behavior: smooth ? 'smooth' : 'auto' });
        }

        /* ---------- SWUPA-List ---------- */
        function renderLists(s) {
            const box = $('lists');
            const mining = ['sort', 'pair', 'winres'].includes(s.kind);
            let rowsL = s.lists.slice();
            if (mining) rowsL.sort(byExp); else rowsL.sort((p, q) => ITEMS.indexOf(p.items[0]) - ITEMS.indexOf(q.items[0]));
            const goneBy = new Map();
            if (s.kind === 'expire') s.gone.forEach(g => { if (!goneBy.has(g.item)) goneBy.set(g.item, []); goneBy.get(g.item).push(g); });
            const dropped = s.kind === 'expire' ? s.dropped : [];
            const ms = mining ? s.ms : null;
            const inPat = s.kind === 'pair' ? new Set(s.items) : new Set();
            const html = [];
            const row = (item, L, goneList) => {
                const cls = ['lrow'];
                if (mining) cls.push(ge(L.exp, ms) ? 'ok' : 'drop');
                if (inPat.has(item)) cls.push(item === s.last ? 'lastit' : 'inpat');
                if (s.kind === 'add' && s.created.includes(item)) cls.push('fresh');
                if (!L) cls.push('removed');
                const ents = [];
                (goneList || []).forEach(g => ents.push(`<span class="ent gone">${T(g.tid)} <b>${pr(g.ep)}</b></span>`));
                if (L) L.tids.forEach((t, k) => {
                    const c = ['ent'];
                    if (s.kind === 'add' && s.added.has(item + '|' + t)) c.push('new');
                    if (Math.abs(L.eps[k] - L.max) < EPS) c.push('max');
                    ents.push(`<span class="${c.join(' ')}">${T(t)} <b>${pr(L.eps[k])}</b></span>`);
                });
                const b0 = (s.kind === 'add' || s.kind === 'expire') && s.before.get(item);
                const expChg = b0 && L && Math.abs(b0.exp - L.exp) > EPS, maxChg = b0 && L && Math.abs(b0.max - L.max) > EPS;
                const es = L ? `<span class="num2 es${expChg ? ' chg' : ''}">${num(L.exp)}${expChg ? `<small>原 ${num(b0.exp)}</small>` : ''}</span>` : `<span class="num2">—</span>`;
                const mx = L ? `<span class="num2${maxChg ? ' chg' : ''}">${pr(L.max)}${maxChg ? `<small>原 ${pr(b0.max)}</small>` : ''}</span>` : `<span class="num2">—</span>`;
                html.push(`<div class="${cls.join(' ')}"><span class="it">${esc(lab(item))}</span><div class="ents">${ents.join('')}</div>${es}${mx}</div>`);
            };
            rowsL.forEach(L => row(L.items[0], L, goneBy.get(L.items[0])));
            dropped.forEach(item => row(item, null, goneBy.get(item)));
            const out = html.join('') || '<div class="empty">還沒有任何串列。</div>';
            if (box.innerHTML !== out) box.innerHTML = out;
            const st = $('list-state');
            st.className = 'tag-state' + (s.kind === 'add' || s.kind === 'expire' ? ' fresh' : '');
            st.textContent = s.kind === 'add' ? '接上新的一批' : s.kind === 'expire' ? '砍掉最舊的一批' : mining ? '照 ExpSup 由小到大' : s.kind === 'end' ? '最後的狀態' : '空的';
            $('lnote').textContent = mining ? `門檻 ${num(s.ms)}：灰掉的是不到門檻、不參加合併的商品。底線是 MaxEP 那一筆。`
                : '底線是 MaxEP 那一筆；刪掉的 entry 會劃線，ExpSup / MaxEP 變了的會標出原本的值。';
        }

        /* ---------- 合併兩個串列 ---------- */
        function renderPair(s) {
            const box = $('pair');
            let out = '';
            if (s.kind === 'sort') {
                out = `<div class="placeholder">合併的順序照 ExpSup 由小到大（論文用 support ascending）：小的先當前綴，往後找夥伴。</div><div class="order">` +
                    s.order.map((o, k) => `${k ? '<span class="arrow">→</span>' : ''}<span class="o ${o.ok ? 'ok' : 'no'}">${esc(lab(o.item))}<small>${num(o.exp)}</small></span>`).join('') + `</div>`;
            } else if (s.kind !== 'pair') {
                out = `<div class="placeholder">${s.kind === 'winres' ? `這個視窗的合併都做完了。` : `視窗裝滿 ${wSize} 批之後，這裡會一次一對地顯示：先用 overExpSup 判斷要不要建串列，再把兩邊的 TID 一起往前比，邊比邊檢查 ppCLw。`}</div>`;
            } else {
                const xs = fmt(s.X.items), ys = fmt(s.Y.items);
                out = `<div class="pair-title">X <span class="pt">${esc(xs)}</span> ＋ Y <span class="pt">${esc(ys)}</span> → <span class="pt res">${esc(fmt(s.items))}</span></div>`;
                const ok = ge(s.over, s.ms);
                out += `<div class="calc">① overExpSup = ExpSup(X) <b>${num(s.X.exp)}</b> × MaxEP(${esc(s.last)}) <b>${pr(s.maxLast)}</b> = <b>${num(s.over)}</b> ` +
                    (ok ? `<span class="ok">≥ ${num(s.ms)} → 建串列</span>` : `<span class="no">&lt; ${num(s.ms)} → 剪掉</span>`) + `</div>`;
                if (ok) {
                    const hasP = !!s.prefix;
                    out += `<div class="cmpbox"><table class="cmp"><thead><tr><th>X 的 TID</th><th>X</th><th>Y</th>${hasP ? '<th>÷前綴</th>' : ''}<th>XY</th><th>累計</th><th>ppCLw 上界</th></tr></thead><tbody>` +
                        s.rows.map(r => {
                            const cls = r.state + (r.stop ? ' stop' : '');
                            const cell = v => (v === null ? '' : num(v));
                            const yv = r.state === 'nomatch' ? '—' : r.state === 'skip' ? '' : pr(r.ye);
                            const bd = r.bound === null ? (r.state === 'skip' ? '沒比' : '') : num(r.bound);
                            return `<tr class="${cls}"><td>${T(r.tid)}</td><td>${pr(r.xe)}</td><td>${yv}</td>${hasP ? `<td>${r.pe === null ? '' : pr(r.pe)}</td>` : ''}` +
                                `<td class="xy">${cell(r.xy)}</td><td>${cell(r.cur)}</td><td class="${r.bound === null ? '' : ge(r.bound, s.ms) ? 'fine' : 'bad'}">${bd}</td></tr>`;
                        }).join('') + `</tbody></table></div>`;
                    out += `<div class="placeholder" style="margin-top:0.35rem;font-size:0.76rem">size(X) = ${s.rows.length}；上界 = 累計 + (還沒比的 X entry 數) × MaxEP(X) ${pr(s.X.max)}。Y 有、X 沒有的 TID 直接跳過。</div>`;
                }
                const v = s.verdict;
                out += `<div class="verdict ${v === 'ok' ? 'ok' : 'no'}">` + (v === 'over' ? '✗ 上界就不夠：不建串列、也不用比任何 TID'
                    : v === 'ppclw' ? `✗ ppCLw：比到 ${T(s.rows[s.at].tid)} 就停，後面 ${s.rows.length - s.at - 1} 筆沒比`
                        : v === 'ok' ? `✓ ExpSup ${num(s.exp)} ≥ ${num(s.ms)}，加進結果` : `✗ 算完 ExpSup ${num(s.exp)} &lt; ${num(s.ms)}，不夠`) + `</div>`;
            }
            if (box.innerHTML !== out) box.innerHTML = out;
        }

        /* ---------- 結果 ---------- */
        function renderResults(s) {
            const has = s.found !== undefined;
            const found = has ? s.found.slice(0, s.nFound) : [];
            const st = $('res-state');
            st.className = 'tag-state' + (s.kind === 'winres' ? ' fresh' : '');
            st.textContent = has ? `W${s.winNo}（${range(s.winTids)}）${s.kind === 'winres' ? '完成' : '進行中'}` : s.kind === 'end' ? '串流結束' : s.winNo ? '換下一個視窗' : '視窗還沒滿';
            const box = $('levels');
            const bySize = {};
            found.forEach(f => { (bySize[f.items.length] = bySize[f.items.length] || []).push(f); });
            const sizes = Object.keys(bySize).map(Number).sort((a, b) => a - b);
            let out = sizes.map(n => `<div class="level"><span class="tag">${n} 個</span><div class="items">` +
                bySize[n].map(f => `<button type="button" class="pat${f.key === s.newKey ? ' new' : ''}${f.key === selKey ? ' sel' : ''}" data-k="${esc(f.key)}">` +
                    `${esc(emo(f.items))}<span class="n">${num(f.exp)}</span></button>`).join('') + `</div></div>`).join('');
            if (!out) out = `<div class="empty">${has ? '這個視窗沒有樣式達到門檻。' : s.winNo ? '新的一批接上之後，重新排序、重新合併。' : '視窗裝滿之後才開始分析。'}</div>`;
            if (box.innerHTML !== out) box.innerHTML = out;
            const stt = s.stats || { join: 0, over: 0, pp: 0 };
            $('st-join').textContent = stt.join;
            $('st-over').textContent = stt.over;
            $('st-pp').textContent = stt.pp;
            $('brute').innerHTML = s.kind === 'winres'
                ? `暴力法：視窗裡 ${s.brute} 個組合全部算期望支持度，達標的 ${s.nFound} 個${s.same ? '<b>完全一樣 ✓</b>' : '<b class="bad">不一樣 ✗</b>'}`
                : '點一個樣式，輸送帶上會標出包含它的交易。';
        }
        $('levels').addEventListener('click', e => {
            const b = e.target.closest('.pat');
            if (!b) return;
            selKey = selKey === b.dataset.k ? null : b.dataset.k;
            renderResults(trace[cursor]);
            renderBelt(trace[cursor], false);
        });

        const KW = {
            java: new Set('public static final private for if return new boolean int void class import while else null this double continue'.split(' ')),
            py: new Set('def for in if return not and or while import from as True False None class is lambda yield del elif continue'.split(' '))
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

        function renderCode(tag) {
            if (measuringBlocks || restoringBlocks) return;   // 量區塊高度時不用畫程式碼（程式碼框高度不會變），量完畫回來時它也沒被動過，省時間
            const pre = $('code');
            pre.innerHTML = CODE[lang].map(([text, tags], i) =>
                `<span class="ln${tags.includes(tag) ? ' hl' : ''}" data-n="${i + 1}">${highlight(text) || ' '}</span>`).join('');
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
                    const big = groups.reduce((a, b) => (b.length > a.length ? b : a));
                    [y0, y1] = span(big[0], big[big.length - 1]);
                }
                const target = (y0 + y1) / 2 - pre.clientHeight / 2;
                pre.scrollTo({ top: Math.max(0, Math.min(target, y0 - 8)), behavior: 'smooth' });
            }
            $('downloads').innerHTML = lang === 'java'
                ? '下載 <a href="code/UncertainSW.java" download>UncertainSW.java</a>　執行 <code>javac UncertainSW.java && java UncertainSW</code>'
                : '下載 <a href="code/uncertain_sw.py" download>uncertain_sw.py</a>　執行 <code>python3 uncertain_sw.py</code>';
        }

        /* ---------- 顯示某一步 ---------- */
        function renderPhases(s) {
            const nb = Math.floor(db.length / bSize), nw = Math.max(0, nb - wSize + 1);
            let out = '';
            for (let k = 1; k <= nw; k++) {
                const t0 = (k - 1) * bSize + 1, t1 = (k - 1 + wSize) * bSize;
                out += `<div class="phase${s.winNo === k && s.kind !== 'end' && (s.win.length === wSize) ? ' cur' : ''}"><b>W${k}</b> T${t0}–${t1}</div>`;
            }
            if (!nw) out = '<div class="phase">資料不夠裝滿一個視窗</div>';
            if ($('phases').innerHTML !== out) $('phases').innerHTML = out;
        }

        function renderFormula() {
            $('formula').innerHTML = `視窗 = 最近 ${wSize} 批 × 每批 ${bSize} 筆 = ${wSize * bSize} 筆交易；門檻 minSup = ${wSize} × ${bSize} × ${pct}% = <b>${num(wSize * bSize * pct / 100)}</b>` +
                `（期望支持度 ≥ 它才算數）。` + (dsKey === 'paper' ? '論文的設定：一批 2 筆、視窗 3 批、δ = 20%。' : '');
        }

        function showStep(smooth = true) {
            const s = trace[cursor];
            $('explain').innerHTML = `<span class="step-no">步驟 ${cursor + 1} / ${trace.length}</span>${describe(s)}`;
            renderBelt(s, smooth);
            renderPhases(s);
            renderLists(s);
            renderPair(s);
            renderResults(s);
            renderCode(codeTag(s));
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

        /* 說明框用最長的那段文字的高度固定住，下面的東西才不會跳來跳去 */
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
            reserveBlockHeights(document, trace.length, i => { cursor = i; showStep(false); }, () => cursor);
        }

        function renderParams() {
            $('b-val').textContent = bSize;
            $('w-val').textContent = wSize;
            $('d-val').textContent = pct + '%';
            $('b-minus').disabled = bSize <= 1;
            $('b-plus').disabled = bSize >= 2 || 2 * (wSize + 1) > db.length;
            $('w-minus').disabled = wSize <= 2;
            $('w-plus').disabled = wSize >= 4 || bSize * (wSize + 2) > db.length;
            $('d-minus').disabled = pct <= 5;
            $('d-plus').disabled = pct >= 60;
            [...$('dataset').children].forEach(x => x.classList.toggle('active', x.dataset.ds === dsKey));
        }

        /* 重新產生紀錄；keep = 盡量停在同一個階段 */
        function rebuild(keep) {
            stopAuto();
            const was = keep && trace[cursor] ? { k: trace[cursor].kind, w: trace[cursor].winNo } : null;
            trace = buildTrace(db, bSize, wSize, pct);
            cursor = 0;
            if (was) {
                let i = trace.findIndex(s => s.winNo === was.w && s.kind === was.k);
                if (i < 0) i = trace.findIndex(s => s.winNo === was.w && s.kind === 'sort');
                cursor = Math.max(0, i);
            }
            buildBelt();
            renderParams();
            renderFormula();
            showStep(false);
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

        /* 第 i 步（s = trace[i]）要出的題目：{ q, choices, answer, why, multi?, ask? } 或 null（ask 只給 quiz_test.py 對答案用） */
        const winTidsOf = win => win.flatMap(h => Array.from({ length: bSize }, (_, k) => h * bSize + k + 1));
        const OUTCOMES = ['overExpSup 就剪掉', 'ppCLw 比到一半停', '算完，夠門檻', '算完，不夠門檻'];
        /* 數字選項：正確答案＋陷阱（去重），不夠 4 個再補附近的數字 */
        function numOpts(ans, traps, rnd) {
            const seen = new Set([num(ans)]), opts = [{ text: num(ans) }];
            traps.concat([ans + 0.1, ans - 0.1, ans + 0.2, ans + 0.3]).forEach(v => {
                if (opts.length < 4 && v >= 0 && !seen.has(num(v))) { seen.add(num(v)); opts.push({ text: num(v) }); }
            });
            return quizOptions(opts, rnd);
        }
        function quizFor(s, i) {
            const rnd = quizRng(i + 1);
            switch (s.kind) {
                case 'expire': {
                    // 問一個被砍到的商品：MaxEP 變了就問 MaxEP，沒變就問 ExpSup
                    const hit = s.lists.filter(L => s.gone.some(g => g.item === L.items[0]));
                    if (!hit.length) return null;
                    const chg = hit.filter(L => Math.abs(s.before.get(L.items[0]).max - L.max) > EPS);
                    const L = chg.length ? chg[0] : quizPick(hit, rnd), it = L.items[0], b0 = s.before.get(it);
                    const removed = s.gone.filter(g => g.item === it);
                    if (chg.length) {
                        const r = numOpts(L.max, [b0.max, Math.max(...removed.map(g => g.ep)), L.exp, L.max - 0.1, L.max + 0.1], rnd);
                        return {
                            q: `B${s.h + 1} 離開後，${it} 的串列剩下 ${L.tids.length} 筆。它的 MaxEP 變成多少？`, ...r,
                            why: `原本最大的 ${pr(b0.max)} 在被刪掉的那批裡，只能從剩下的 ${L.eps.map(pr).join('、')} 重找，最大是 ${pr(L.max)}。`,
                            ask: { type: 'maxep', item: it, tids: winTidsOf(s.win) }
                        };
                    }
                    const r = numOpts(L.exp, [b0.exp, removed.reduce((a, g) => a + g.ep, 0), b0.exp - L.max, L.exp + 0.1], rnd);
                    return {
                        q: `B${s.h + 1} 離開，${it} 的串列從頭砍掉 ${removed.length} 筆。它的 ExpSup 變成多少？`, ...r,
                        why: `原本 ${num(b0.exp)}，減掉被刪的 ${removed.map(g => pr(g.ep)).join(' + ')}，剩 ${num(L.exp)}（就是剩下 entry 的加總）。`,
                        ask: { type: 'expsup', item: it, tids: winTidsOf(s.win) }
                    };
                }
                case 'sort': {
                    // 複選：哪些商品的 ExpSup 夠門檻（挑最接近門檻的 4 個來問）
                    const pool = s.order.slice().sort((p, q) => Math.abs(p.exp - s.ms) - Math.abs(q.exp - s.ms) || cmp(p.item, q.item)).slice(0, 4);
                    const opts = quizShuffle(pool, rnd);
                    const mq = {
                        q: `W${s.winNo} 的門檻是 ${num(s.ms)}。下面哪些商品自己的 ExpSup 夠門檻、會留下來合併？`,
                        choices: opts.map(o => o.item), answer: opts.map((o, k) => (o.ok ? k : -1)).filter(k => k >= 0), multi: true,
                        why: opts.map(o => `${o.item} ${num(o.exp)}`).join('、') + `；≥ ${num(s.ms)} 的才留下。`,
                        ask: { type: 'keep', ms: s.ms, winNo: s.winNo, choices: opts.map(o => o.item) }
                    };
                    return opts.length === 1 ? quizSingle(mq, `${opts[0].item} 的 ExpSup 夠門檻 ${num(s.ms)}、會留下來嗎？`) : mq;
                }
                case 'pair': {
                    const k = s.stats.join + s.stats.over + s.stats.pp;   // 這個視窗第幾對
                    const what = `${fmt(s.X.items)} + ${s.last} → ${fmt(s.items)}`;
                    if (k % 2 === 1) {
                        const ans = { over: 0, ppclw: 1, ok: 2, low: 3 }[s.verdict];
                        return {
                            q: `接下來合併 ${what}（門檻 ${num(s.ms)}）。結果會是？`, choices: OUTCOMES.slice(), answer: ans,
                            why: s.verdict === 'over' ? `overExpSup = ${num(s.X.exp)} × ${pr(s.maxLast)} = ${num(s.over)}，合併前就不夠。`
                                : s.verdict === 'ppclw' ? `上界 ${num(s.over)} 過關，但比到 ${T(s.rows[s.at].tid)} 時 ${num(s.rows[s.at].cur)} + 剩下 × ${pr(s.X.max)} = ${num(s.rows[s.at].bound)} 不夠了。`
                                    : `兩個上界都過關，算完 ExpSup = ${num(s.exp)}，${s.verdict === 'ok' ? '夠' : '不夠'}門檻。`,
                            ask: { type: 'outcome', items: s.items, winNo: s.winNo }
                        };
                    }
                    if (s.verdict === 'ok' || s.verdict === 'low') {
                        const naive = s.rows.filter(r => r.state === 'match').reduce((a, r) => a + r.xe * r.ye, 0);
                        const r = numOpts(s.exp, [s.over, s.prefix ? naive : s.X.exp * s.Y.exp, s.X.exp, s.Y.exp], rnd);
                        return {
                            q: `${what}：把 X、Y 共同的 TID 一筆一筆算，ExpSup 會是多少？`, ...r,
                            why: `共同的 ${s.rows.filter(x => x.state === 'match').map(x => T(x.tid)).join('、')}，每筆 X × Y${s.prefix ? ' ÷ 前綴' : ''}，加起來 ${num(s.exp)}；${num(s.over)} 只是上界。`,
                            ask: { type: 'pexp', items: s.items, winNo: s.winNo }
                        };
                    }
                    if (s.verdict === 'over') {
                        const r = numOpts(s.over, [s.X.exp * s.Y.max, s.X.exp, s.X.max * s.maxLast, s.X.exp * s.Y.exp], rnd);
                        return {
                            q: `${what}：上界 overExpSup = ExpSup(X) × MaxEP(${s.last}) 是多少？`, ...r,
                            why: `${num(s.X.exp)} × ${pr(s.maxLast)} = ${num(s.over)}，${ge(s.over, s.ms) ? '≥' : '<'} 門檻 ${num(s.ms)}。`,
                            ask: { type: 'over', items: s.items, winNo: s.winNo }
                        };
                    }
                    return null;
                }
                case 'winres': {
                    const singles = s.found.filter(f => f.items.length === 1).length;
                    const prev = trace.slice(0, i).reverse().find(x => x.kind === 'winres');
                    return {
                        q: `W${s.winNo} 全部合併完，總共有幾個樣式（含單一商品）的 ExpSup ≥ ${num(s.ms)}？`,
                        ...quizNums(s.nFound, 0, s.brute, rnd, [singles, s.nFound + s.stats.pp, prev ? prev.nFound : s.nFound - 1]),
                        why: `單一商品 ${singles} 個＋合併出來的 ${s.nFound - singles} 個 = ${s.nFound} 個；被剪掉的都不可能達標。`,
                        ask: { type: 'count', winNo: s.winNo }
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
            timer = setInterval(() => { if (!step(1)) stopAuto(); }, 1500);
        });
        document.addEventListener('keydown', e => {
            if (e.target.closest && e.target.closest('select, input, textarea')) return;
            if (e.key === 'ArrowRight') { stopAuto(); step(1); }
            if (e.key === 'ArrowLeft') { stopAuto(); step(-1); }
        });

        $('b-minus').addEventListener('click', () => { if (bSize > 1) { bSize--; rebuild(false); } });
        $('b-plus').addEventListener('click', () => { if (bSize < 2 && 2 * (wSize + 1) <= db.length) { bSize++; rebuild(false); } });
        $('w-minus').addEventListener('click', () => { if (wSize > 2) { wSize--; rebuild(false); } });
        $('w-plus').addEventListener('click', () => { if (wSize < 4 && bSize * (wSize + 2) <= db.length) { wSize++; rebuild(false); } });
        $('d-minus').addEventListener('click', () => { if (pct > 5) { pct -= 5; rebuild(true); } });
        $('d-plus').addEventListener('click', () => { if (pct < 60) { pct += 5; rebuild(true); } });
        $('dataset').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b || b.dataset.ds === dsKey) return;
            loadDataset(b.dataset.ds);
            rebuild(false);
        });
        $('btn-reset').addEventListener('click', () => { loadDataset(dsKey); rebuild(false); });
        $('btn-edit').addEventListener('click', () => {
            editing = !editing;
            $('btn-edit').classList.toggle('on', editing);
            $('btn-edit').textContent = editing ? '✓ 改好了' : '✏️ 點格子改機率';
            $('belt').classList.toggle('editing', editing);
            $('edit-hint').style.visibility = editing ? 'visible' : 'hidden';
        });
        /* 編輯：沒有 → 1.0 → 0.9 → … → 0.1 → 沒有 */
        $('belt').addEventListener('click', e => {
            if (!editing) return;
            const sl = e.target.closest('.slot');
            if (!sl) return;
            const t = db[Number(sl.closest('.tx').dataset.k)], it = sl.dataset.i;
            if (t[it] === undefined) t[it] = 1.0;
            else if (t[it] <= 0.1 + EPS) delete t[it];
            else t[it] = Math.round(t[it] * 10 - 1) / 10;
            rebuild(true);
        });

        $('lang').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b) return;
            lang = b.dataset.lang;
            [...$('lang').children].forEach(x => x.classList.toggle('active', x === b));
            renderCode(codeTag(trace[cursor]));
        });

        let resizeTimer = null;
        window.addEventListener('resize', () => {
            clearTimeout(resizeTimer);
            resizeTimer = setTimeout(() => { reserveExplainHeight(); renderBelt(trace[cursor], false); }, 150);
        });

        loadDataset('shop');
        rebuild(false);

    </script>
</body>

</html>
