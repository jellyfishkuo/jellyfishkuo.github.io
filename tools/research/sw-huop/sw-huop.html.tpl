<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/sw-huop.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/sw-huop-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/sw-huop-180.png">
    <title>滑動視窗高效益佔有率樣式（HUOPS）</title>
    <meta name="description" content="一步一步看 HUOPS（Information Sciences 2025）怎麼在資料串流上用滑動視窗找高效益佔有率樣式：交易一批一批進來、最舊的一批整批移出，HUOPS-List 怎麼更新、重整、用 UBUO1／UBUO2 兩個上界剪枝，每個視窗都和暴力法對照。">
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

        /* 手機：一欄，依序 串流 → 步驟 → HUOPS-List → 搜尋樹 → 程式碼 → 結果
           電腦：串流在上面整排；下面左欄 步驟／HUOPS-List，右欄 搜尋樹／程式碼／結果 */
        .layout { display: grid; gap: 1rem; margin-top: 1rem; align-items: start; }
        .col { display: contents; }
        .layout .card { min-width: 0; }
        .a-step { order: 1; }
        .a-lists { order: 2; }
        .a-tree { order: 3; }
        .a-code { order: 4; }
        .a-result { order: 5; }
        @media (min-width: 960px) {
            .layout { grid-template-columns: 1fr 1.05fr; }
            .col { display: grid; gap: 1rem; align-content: start; min-width: 0; }
        }

        .card {
            background: var(--panel);
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 1rem;
            min-width: 0;
        }
        .card-head { display: flex; justify-content: space-between; align-items: center; gap: 0.3rem 0.6rem; flex-wrap: wrap; margin-bottom: 0.7rem; }
        .card-head h2 { margin: 0; }
        .sub { color: var(--muted); font-size: 0.8rem; }
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

        /* ── 參數 ── */
        .params { display: flex; flex-wrap: wrap; gap: 0.4rem 1.1rem; align-items: center; font-size: 0.88rem; }
        .param { display: flex; align-items: center; gap: 0.4rem; }
        .param .val { font: 700 1rem 'Space Mono', monospace; min-width: 2.6em; text-align: center; }
        .stepper { width: 30px; height: 30px; padding: 0 !important; }
        .preset { background: var(--panel-2); color: var(--text); border: 1px solid var(--border); border-radius: 8px; padding: 0.3rem 0.4rem; font: inherit; font-size: 0.85rem; max-width: 100%; }
        .derived { color: var(--muted); font-size: 0.8rem; margin-top: 0.5rem; }
        .derived b { color: var(--text); font-family: 'Space Mono', monospace; }

        /* ── 輸送帶（交易一批一批進來） ── */
        .belt {
            overflow-x: auto;
            background: var(--lt-0a0a14, #0a0a14);
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 30px 10px 12px;
            margin-top: 0.8rem;
        }
        .belt-inner { position: relative; display: flex; gap: 12px; width: max-content; padding: 0 6px; }
        .bt { display: flex; flex-direction: column; gap: 3px; transition: opacity 0.3s; }
        .bt-l { font: 700 0.68rem 'Space Mono', monospace; color: var(--muted); text-align: center; line-height: 1.2; }
        .bt-row { display: flex; gap: 4px; }
        .bt.past { opacity: 0.28; }
        .bt.future .tx, .bt.rest .tx { opacity: 0.5; border-style: dashed; background: transparent; }
        .bt.leaving .tx { border-color: var(--bad); box-shadow: 0 0 0 1px var(--bad); }
        .bt.leaving .bt-l { color: var(--bad); }
        .bt.entering .bt-l { color: var(--good); }
        .tx {
            flex: none;
            width: 46px;
            border: 1px solid var(--border);
            border-radius: 8px;
            background: var(--panel-2);
            text-align: center;
            padding: 3px 0 4px;
            transition: opacity 0.3s, border-color 0.3s, background 0.3s;
        }
        .tx .tid { font: 700 0.7rem 'Space Mono', monospace; display: block; line-height: 1.3; }
        .tx .slot { height: 21px; display: flex; align-items: center; justify-content: center; gap: 1px; font-size: 13px; border-radius: 5px; margin: 0 3px; line-height: 1; }
        .tx .slot small { font: 700 0.62rem 'Space Mono', monospace; color: var(--lt-fcd34d, #fcd34d); }
        .tx .slot .lt { font: 700 0.72rem 'Space Mono', monospace; color: var(--text); }
        .tx .slot.off::after { content: ''; width: 3px; height: 3px; border-radius: 50%; background: var(--lt-34344e, #34344e); }
        .tx .slot.hit { background: var(--lt-f59e0b-30, rgba(245, 158, 11, 0.3)); }
        .tx .tu { display: block; font: 0.58rem 'Space Mono', monospace; color: var(--accent2); margin-top: 2px; line-height: 1.2; }
        .tx.enter { border-color: var(--good); box-shadow: 0 0 0 1px var(--good); }
        .tx.enter .tid { color: var(--good); }
        .tx.match { border-color: var(--warn); }
        .frame {
            position: absolute;
            top: -24px;
            bottom: -6px;
            border: 2px solid var(--accent2);
            border-radius: 11px;
            pointer-events: none;
            transition: left 0.35s ease, width 0.35s ease, border-color 0.3s;
        }
        .frame .lbl { position: absolute; top: 2px; left: 6px; right: 6px; font-size: 0.7rem; color: var(--accent2); text-align: right; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .frame.full { border-color: var(--accent); }
        .frame.full .lbl { color: var(--lt-c4b5fd, #c4b5fd); }
        .frame.empty { opacity: 0; }
        .profits { display: flex; flex-wrap: wrap; gap: 0.25rem 0.8rem; font-size: 0.8rem; color: var(--muted); margin-top: 0.6rem; }
        .profits b { font: 700 0.78rem 'Space Mono', monospace; color: var(--lt-fcd34d, #fcd34d); }
        .legend { display: flex; flex-wrap: wrap; gap: 0.3rem 0.9rem; font-size: 0.75rem; color: var(--muted); margin-top: 0.55rem; }
        .legend i { display: inline-block; width: 11px; height: 11px; border-radius: 3px; border: 2px solid; margin-right: 0.3rem; vertical-align: -1px; }

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
        .explain .ok { color: var(--lt-86efac, #86efac); }
        .explain .no { color: var(--lt-fca5a5, #fca5a5); }
        .phases { display: flex; flex-wrap: wrap; gap: 0.3rem; margin-top: 0.7rem; }
        .phase { flex: 1 1 auto; white-space: nowrap; text-align: center; font: inherit; font-size: 0.75rem; color: var(--muted); background: none; border: 1px solid var(--border); border-radius: 6px; padding: 0.15rem 0.35rem; cursor: pointer; }
        .phase:hover { border-color: var(--accent2); }
        .phase.mine { border-style: dashed; }
        .phase.cur { color: var(--text); border-color: var(--accent); background: var(--lt-7c3aed-15, rgba(124, 58, 237, 0.15)); border-style: solid; }

        /* ── HUOPS-List ── */
        .uls { display: flex; flex-wrap: wrap; gap: 0.6rem; align-items: flex-start; min-height: 120px; max-height: 620px; overflow: auto; }
        .uls-empty { color: var(--muted); font-size: 0.85rem; align-self: center; }
        .ul { background: var(--lt-0a0a14, #0a0a14); border: 1px solid var(--border); border-radius: 10px; padding: 0.4rem 0.5rem 0.45rem; min-width: 128px; }
        .ul.res { border-color: var(--accent2); box-shadow: 0 0 0 1px var(--accent2) inset; }
        .ul.focus { border-color: var(--warn); }
        .ul.low { opacity: 0.55; }
        .ul.gone { border-style: dashed; border-color: var(--lt-f87171-60, rgba(248, 113, 113, 0.6)); }
        .ul-h { display: flex; align-items: baseline; gap: 0.35rem; font-size: 0.8rem; margin-bottom: 0.2rem; }
        .ul-h .role { font: 700 0.7rem 'Space Mono', monospace; color: var(--accent2); }
        .ul-h .sp { margin-left: auto; font: 0.68rem 'Space Mono', monospace; color: var(--muted); white-space: nowrap; }
        .ul table { border-collapse: collapse; font: 0.74rem 'Space Mono', monospace; width: 100%; }
        .ul th { color: var(--muted); font-weight: 400; text-align: right; padding: 0 0.3rem; font-size: 0.68rem; }
        .ul th:nth-child(-n+2), .ul td:nth-child(-n+2) { text-align: left; }
        .ul td { padding: 0.05rem 0.3rem; text-align: right; }
        .ul td.b { color: var(--muted); font-size: 0.66rem; }
        .ul tr.bsep td { border-top: 1px dashed var(--lt-2c2c48, #2c2c48); }
        .ul tr.dim td { opacity: 0.3; }
        .ul tr.new td { background: var(--lt-22c55e-18, rgba(34, 197, 94, 0.18)); }
        .ul tr.del td { background: var(--lt-f87171-14, rgba(248, 113, 113, 0.14)); color: var(--lt-fca5a5, #fca5a5); text-decoration: line-through; }
        .ul tr.ex td { background: var(--lt-f59e0b-22, rgba(245, 158, 11, 0.22)); color: var(--lt-fde68a, #fde68a); }
        .ul tr.tp td:nth-child(n+3) { color: var(--lt-c4b5fd, #c4b5fd); font-weight: 700; }
        .ul tr.sum td { border-top: 1px solid var(--border); font-weight: 700; color: var(--accent2); }
        .ul-f { font-size: 0.7rem; color: var(--muted); margin-top: 0.2rem; max-width: 15rem; }
        .ul-f b { font-family: 'Space Mono', monospace; color: var(--text); }
        .ul-f b.ok { color: var(--lt-86efac, #86efac); }
        .ul-f b.no { color: var(--lt-fca5a5, #fca5a5); }
        .op { align-self: center; color: var(--muted); font: 700 1rem 'Space Mono', monospace; }
        .temp { display: flex; flex-wrap: wrap; align-items: center; gap: 0.3rem; margin-top: 0.6rem; font-size: 0.78rem; color: var(--muted); min-height: 1.6rem; }
        .temp .tc { font: 0.72rem 'Space Mono', monospace; color: var(--text); border: 1px solid var(--border); border-radius: 6px; padding: 0 0.35rem; }
        .temp .tc.up { border-color: var(--good); color: var(--lt-86efac, #86efac); }
        .temp .tc.rd { border-color: var(--warn); color: var(--lt-fde68a, #fde68a); }

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
        .wins { display: grid; gap: 0.7rem; }
        .win { border: 1px solid var(--border); border-radius: 10px; padding: 0.5rem 0.6rem; background: var(--lt-0a0a14, #0a0a14); }
        .win.now { border-color: var(--accent); }
        .win-h { display: flex; flex-wrap: wrap; align-items: baseline; gap: 0.2rem 0.6rem; font-size: 0.85rem; margin-bottom: 0.35rem; }
        .win-h .wn { font: 700 0.85rem 'Space Mono', monospace; color: var(--accent2); }
        .win-h .rg { color: var(--muted); font-size: 0.78rem; }
        .win-h .bf { margin-left: auto; font-size: 0.74rem; border-radius: 6px; padding: 0 0.4rem; background: var(--lt-23233d, #23233d); color: var(--muted); }
        .win-h .bf.ok { background: var(--lt-22c55e-18, rgba(34, 197, 94, 0.18)); color: var(--lt-86efac, #86efac); }
        .win-h .bf.no { background: var(--lt-f87171-18, rgba(248, 113, 113, 0.18)); color: var(--lt-fca5a5, #fca5a5); }
        .win .items { display: flex; flex-wrap: wrap; gap: 0.35rem; }
        .pat { font-size: 0.82rem; border: 1px solid var(--lt-22c55e-50, rgba(34, 197, 94, 0.5)); border-radius: 7px; padding: 0.12rem 0.5rem; }
        .pat .n { font: 700 0.72rem 'Space Mono', monospace; margin-left: 0.35rem; color: var(--lt-86efac, #86efac); }
        .pat.fresh { box-shadow: 0 0 0 2px var(--warn); }
        .pat.newp { border-color: var(--accent2); }
        .pat.gone { border-style: dashed; border-color: var(--lt-f87171-60, rgba(248, 113, 113, 0.6)); color: var(--muted); }
        .pat.gone .nm { text-decoration: line-through; }
        .pat.gone .n { color: var(--lt-fca5a5, #fca5a5); }
        .empty { color: var(--muted); font-size: 0.85rem; }
        .stats { display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.5rem; margin-top: 0.9rem; }
        @media (min-width: 600px) { .stats { grid-template-columns: repeat(4, 1fr); } }
        .stat { background: var(--panel-2); border-radius: 10px; padding: 0.55rem 0.6rem; min-width: 0; }
        .stat .v { font: 700 1.2rem 'Space Mono', monospace; }
        .stat .k { color: var(--muted); font-size: 0.75rem; line-height: 1.35; }

        .notes { margin-top: 1rem; display: grid; gap: 1rem; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr; } .notes .wide { grid-column: 1 / -1; } }
        .notes p, .notes li { color: var(--lt-c6c6d6, #c6c6d6); font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; margin-top: 0.5rem; }
        .notes b { color: var(--text); }
        .notes a { color: var(--accent2); overflow-wrap: anywhere; }
        .cite { background: var(--panel-2); border-radius: 10px; padding: 0.6rem 0.8rem; font-size: 0.88rem; color: var(--lt-c6c6d6, #c6c6d6); margin-bottom: 0.6rem; }
        .cite i { color: var(--text); }

        @media (max-width: 600px) {
            .tx { width: 42px; }
            .tx .slot { font-size: 12px; height: 20px; }
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
        <div class="kicker">RESEARCH DEMO · HIGH UTILITY OCCUPANCY · DATA STREAM</div>
        <h1>滑動視窗高效益佔有率樣式<small>HUOPS：交易一批一批進來，只看最近幾批，找「佔整筆消費比例高」的組合</small></h1>
        <p class="intro">
            <a href="high-utility.html">HUI-Miner</a> 看的是一個組合「總共賺多少」；<b>效益佔有率（utility occupancy）</b>改問：
            這個組合在它出現的那幾筆交易裡，<b>佔了整筆消費的幾成</b>？例如一筆 210 元的交易裡咖啡賣了 120 元，咖啡在這筆的佔有率就是 120 / 210 = 0.57；
            把它出現過的每筆交易的佔有率<b>取平均</b>，就是它的佔有率。<b>高效益佔有率樣式</b>要同時滿足兩個門檻：出現的筆數（支持度）≥ minSup，平均佔有率 ≥ β。
            這頁照 2025 年 Information Sciences 的論文，把它搬到<a href="sliding-window.html">滑動視窗</a>上：交易一批一批進來，只看最近 W 批，
            看它的 <b>HUOPS-List</b> 怎麼整批加入、整批移出，要結果時怎麼重新排序、算剩餘佔有率 ruo，再用兩個上界剪枝。
        </p>

        <div class="card stream-card">
            <div class="card-head">
                <h2>交易串流</h2>
                <select class="preset" id="preset" aria-label="選資料">
                    <option value="shop">超商 8 筆（跟其他頁同一份）</option>
                    <option value="paper1">論文 Table 1（A～F，8 筆）</option>
                    <option value="paper3">論文 Table 3（A～J，18 筆）</option>
                </select>
            </div>
            <div class="params">
                <div class="param">
                    <span>每批筆數</span>
                    <button class="btn stepper" id="b-minus" aria-label="每批少一筆">−</button>
                    <span class="val" id="b-val">2</span>
                    <button class="btn stepper" id="b-plus" aria-label="每批多一筆">+</button>
                </div>
                <div class="param">
                    <span>視窗放幾批</span>
                    <button class="btn stepper" id="w-minus" aria-label="視窗少一批">−</button>
                    <span class="val" id="w-val">3</span>
                    <button class="btn stepper" id="w-plus" aria-label="視窗多一批">+</button>
                </div>
                <div class="param">
                    <span>α 最小支持度</span>
                    <button class="btn stepper" id="a-minus" aria-label="α 減少">−</button>
                    <span class="val" id="a-val">35%</span>
                    <button class="btn stepper" id="a-plus" aria-label="α 增加">+</button>
                </div>
                <div class="param">
                    <span>β 最小佔有率</span>
                    <button class="btn stepper" id="be-minus" aria-label="β 減少">−</button>
                    <span class="val" id="be-val">65%</span>
                    <button class="btn stepper" id="be-plus" aria-label="β 增加">+</button>
                </div>
            </div>
            <div class="derived" id="derived"></div>
            <div class="belt" id="belt">
                <div class="belt-inner" id="belt-inner"></div>
            </div>
            <div class="profits" id="profits"></div>
            <div class="legend">
                <span><i style="border-color:var(--accent2)"></i>視窗（最近幾批）</span>
                <span><i style="border-color:var(--good)"></i>剛進來</span>
                <span><i style="border-color:var(--bad)"></i>最舊的一批，整批移出</span>
                <span><i style="border-color:#3a3a5a;border-style:dashed"></i>還沒進來</span>
                <span><i style="border-color:var(--warn);background:rgba(245,158,11,0.3)"></i>含這一步的樣式</span>
            </div>
        </div>

        <div class="layout">
            <div class="col">
                <div class="card a-step">
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

                <div class="card a-lists">
                    <div class="card-head"><h2>HUOPS-List</h2><span class="sub" id="ul-sub"></span></div>
                    <div class="uls" id="uls"></div>
                    <div class="temp" id="temp"></div>
                    <p class="legend" style="margin-top:0.3rem">每個節點照批次分組記 (tid, uo, ruo)；uo、ruo 顯示到小數第 2 位，Σ 是用沒四捨五入的值加的。</p>
                </div>
            </div>

            <div class="col">
                <div class="card a-tree">
                    <div class="card-head"><h2>搜尋樹（這個視窗）</h2><span class="sub">每往下一層多加一個商品</span></div>
                    <div class="tree" id="tree"></div>
                    <div class="legend">
                        <span><i style="border-color:var(--warn)"></i>這一步</span>
                        <span><i style="border-color:var(--good)"></i>高效益佔有率，輸出</span>
                        <span><i style="border-color:var(--bad)"></i>被剪掉（後面寫原因）</span>
                        <span><i style="border-color:#3a3a5a;border-style:dashed"></i>還沒檢查</span>
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
                    <h2>每個視窗的結果</h2>
                    <div class="wins" id="wins"></div>
                    <div class="stats">
                        <div class="stat"><div class="v" id="st-del">0</div><div class="k">整批移出的 entry</div></div>
                        <div class="stat"><div class="v" id="st-nodes">0</div><div class="k">合併出的條件節點</div></div>
                        <div class="stat"><div class="v" id="st-sup">0</div><div class="k">支持度不夠、跳過的樣式</div></div>
                        <div class="stat"><div class="v" id="st-ub">0 / 0</div><div class="k">被 UBUO1 / UBUO2 剪掉的分支</div></div>
                    </div>
                </div>
            </div>
        </div>

        <div class="notes">
            <div class="card wide">
                <h2>📄 論文</h2>
                <div class="cite">
                    Seungwan Park, Taewoong Ryu, Doyoon Kim, Doyoung Kim, Hanju Kim, Myungha Cho, Unil Yun.
                    <i>Sliding window-based high utility occupancy pattern mining for data streams.</i>
                    Information Sciences, Vol. 716, 2025, Article 122243.
                    DOI：<a href="https://doi.org/10.1016/j.ins.2025.122243" target="_blank" rel="noopener">10.1016/j.ins.2025.122243</a>
                </div>
                <p>論文提出的方法叫 <b>HUOPS</b>（High Utility Occupancy Pattern mining with Sliding window）。白話整理它做了什麼：</p>
                <ul>
                    <li><b>問題：</b>之前在串流上找高效益佔有率樣式的方法（HUOMI）會把<b>從頭到現在所有的交易</b>都算進來，資料越堆越多、越跑越慢，也分不出「最近」的趨勢。
                        HUOPS 改用滑動視窗：交易分成固定筆數的<b>批次</b>，只看最近 W 批，新的一批進來、最舊的一批就丟掉。</li>
                    <li><b>資料結構 HUOPS-List：</b>每個商品一個節點，記 sumUo、sumRuo，底下的 (tid, uo, ruo) <b>照批次分組</b>，所以移出舊批次時整組拿掉、sumUo 減掉就好。
                        只掃一次串流，ruo 先記 0。</li>
                    <li><b>要結果時才重整：</b>視窗內容變了，支持度的順序也會變，所以挖之前先照支持度由小到大重新排，再用 tempArray 從最後一個商品往前算每筆的 ruo。</li>
                    <li><b>兩個上界：</b>UBUO1 = (Σuo + Σruo) / ⌈minSup⌉，直接用節點上的兩個總和算，便宜但比較鬆；
                        UBUO2 只拿 uo + ruo 最大的 ⌈minSup⌉ 筆取平均，要排序、比較貴但比較緊。兩個都 ≥ β 才往下合併（合併方式跟 utility list 一樣，扣掉共同前綴）。</li>
                    <li><b>實驗：</b>在 Accidents、Pumsb、Kosarak、BMS-POS 等真實資料和人造資料上，跟 HUOMI 等方法比執行時間、記憶體、擴充性，並用統計檢定確認找到的樣式不多不少。</li>
                </ul>
                <p style="margin-top:0.5rem">上面可以切換成<b>論文的範例資料</b>對照數字：Table 1（每批 2 筆、視窗 3 批）在 α = 35%、β = 20% 時，E 在第二個視窗的 UBUO1 = 1.24、UBUO2 = 0.96（論文 Example 4）；
                    把 α 調成 20%、β 調成 50%，第一個視窗的 {D, E} 佔有率是 0.648（論文的 DE 例子）；Table 3（每批 6 筆、視窗 2 批、α = β = 40%）兩個視窗分別找到 18 和 16 個，跟論文 Table 5 一樣。
                    （論文例子裡有些小數是先四捨五入再相加的，所以第二位小數偶爾差 0.01。）</p>
                <p style="margin-top:0.5rem">跟網站其他頁的關係：串流、視窗一進一出的想法來自<a href="sliding-window.html">滑動視窗頻繁樣式</a>；
                    節點合併、扣掉共同前綴、剩餘值 ruo 都跟 <a href="high-utility.html">HUI-Miner 的 utility list</a>（iutil、rutil）同一套，只是效益換成佔有率；
                    「資料一直變，只更新受影響的部分」則跟<a href="incremental.html">增量探勘</a>、<a href="ihup.html">IHUP</a> 是同一類問題。</p>
            </div>
            <div class="card">
                <h2>為什麼可以這樣剪？</h2>
                <p><b>佔有率沒有向下封閉性：</b>預設資料第一個視窗裡，{咖啡} 的平均佔有率只有 0.48，但 {咖啡, 牛奶, 麵包} 有 0.92——組合變大，每筆交易裡佔的比例跟著變大。
                    所以不能看「佔有率不夠」就剪，要找一個保證不會比較小的上界。<b>支持度</b>倒是有向下封閉性：加商品只會讓出現的筆數變少，所以 sup &lt; minSup 可以直接跳過整個分支。</p>
                <ul>
                    <li><b>分子變大：</b>把 X 再加上排在後面的商品，在每筆交易裡多出來的佔有率最多就是 ruo，所以每筆 uo(X 的延伸) ≤ uo + ruo；而延伸出現的交易只會是 X 的交易裡的一部分。</li>
                    <li><b>分母變小：</b>延伸要能輸出，支持度至少 ⌈minSup⌉，平均是「總和 ÷ 筆數」，用最小可能的筆數 ⌈minSup⌉ 當分母，只會更大。這就是 UBUO1。</li>
                    <li><b>UBUO2 更緊：</b>延伸只會用到其中幾筆，平均最大的情況是挑 uo + ruo 最大的那幾筆，而筆數越多、平均只會越小，所以取最大的 ⌈minSup⌉ 筆平均就夠了。它一定 ≤ UBUO1。</li>
                </ul>
                <p style="margin-top:0.5rem">照支持度<b>由小到大</b>排，支持度小的商品排前面，它們的分支最早被檢查，也最容易因為支持度不夠整個跳過；排在後面的 ruo 是「後面還有誰」，順序變了 ruo 就要重算，這就是每次挖之前要重整的原因。</p>
            </div>
            <div class="card">
                <h2>優缺點，以及跟實驗室研究的關係</h2>
                <ul>
                    <li><b>只顧最近：</b>舊批次整組丟掉，資料量固定是 W × B 筆，不會越跑越慢；結果反映最近的購買習慣（換成論文 Table 3 看看，兩個視窗的結果幾乎整批換掉）。</li>
                    <li><b>每次要結果都從頭挖：</b>批次的加入移出很便宜，但排序、算 ruo、深度優先搜尋都是整個視窗重做，結果本身沒有增量更新。</li>
                    <li><b>上界常常很鬆：</b>uo + ruo 每筆最多是 1，β 不高的時候兩個上界幾乎都會過，真正剪得多的是支持度。把 β 調高（例如 70% 以上）才看得到 UBUO1、UBUO2 出手。</li>
                    <li><b>兩個門檻不好設：</b>論文結論也提到 α、β 要看資料特性調，未來想讓門檻更好設、剪枝更有效。</li>
                    <li><b>跟實驗室的方向：</b>串流、增量資料庫上的高效益類樣式探勘，核心都是「資料變了，哪些結構要更新、上界怎麼維持正確又夠緊」，這篇是把佔有率這個指標也搬進滑動視窗的例子。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           HUOPS（滑動視窗高效益佔有率樣式）一步一步看
           網頁裡用 JavaScript 照著同樣的流程把整條串流跑一次，把每一步（含每一層遞迴）記下來；
           右邊的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = /*CODE_JSON*/null;
        const EPS = 1e-9;   // 小數比大小時的容許誤差（跟 Java / Python 版一樣）

        const EMOJI = { '咖啡': '☕', '麵包': '🍞', '牛奶': '🥛', '飯糰': '🍙', '茶葉蛋': '🥚', '洋芋片': '🥔' };
        const parseTx = s => Object.fromEntries(s.split(',').map(kv => { const [i, q] = kv.split(':'); return [i.trim(), Number(q)]; }));
        const PRESETS = {
            /* 跟 HUI-Miner 頁同樣的 8 筆交易和利潤 */
            shop: {
                items: ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片'],
                profit: { '咖啡': 30, '麵包': 15, '牛奶': 20, '飯糰': 10, '茶葉蛋': 5, '洋芋片': 25 },
                db: [
                    { '咖啡': 4, '麵包': 2, '牛奶': 2 },
                    { '咖啡': 3, '麵包': 5, '茶葉蛋': 4 },
                    { '咖啡': 1, '麵包': 1, '牛奶': 2, '飯糰': 2 },
                    { '麵包': 3, '牛奶': 4, '洋芋片': 5 },
                    { '咖啡': 3, '牛奶': 2, '茶葉蛋': 2 },
                    { '咖啡': 1, '麵包': 2, '牛奶': 1, '茶葉蛋': 1 },
                    { '飯糰': 1, '茶葉蛋': 2, '洋芋片': 2 },
                    { '咖啡': 1, '麵包': 2, '飯糰': 1 }
                ],
                B: 2, W: 3, a: 35, b: 65
            },
            /* 論文 Table 1、Table 2（範例串流與單位利潤） */
            paper1: {
                items: ['A', 'B', 'C', 'D', 'E', 'F'],
                profit: { A: 3, B: 1, C: 2, D: 3, E: 5, F: 4 },
                db: ['B:1,C:4,D:2,F:2', 'A:3,D:2,E:4', 'A:2,C:2,D:3,E:1', 'A:4,C:2,D:1,F:3', 'A:3,D:2,F:3', 'B:1,D:2,E:3,F:3',
                    'A:2,C:2,D:3,E:4,F:3', 'A:3,D:1,E:4,F:3'].map(parseTx),
                B: 2, W: 3, a: 35, b: 20
            },
            /* 論文 Table 3、Table 4（看視窗怎麼反映最近趨勢的例子） */
            paper3: {
                items: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'],
                profit: { A: 3, B: 1, C: 2, D: 3, E: 5, F: 4, G: 6, H: 3, I: 2, J: 2 },
                db: ['A:4,B:2,D:1,E:3,G:2,I:1', 'A:3,D:2,E:3,G:2', 'A:2,G:4,I:1,J:1', 'A:3,B:2,D:1,E:2,I:5,J:3', 'A:2,E:3,G:2,I:6',
                    'B:4,D:1,E:3,G:2,J:5', 'B:2,D:2,E:1,G:1,I:2,J:2', 'B:3,D:1,G:1,J:3', 'B:3,D:2,E:1,I:2,J:2',
                    'A:3,B:6,C:4,D:4,E:1,F:2,G:1,H:3,I:4,J:3', 'B:2,C:3,D:2,I:3,J:3', 'B:5,D:1,F:3,H:3,I:2,J:2', 'B:2,C:2,D:1,F:2,H:2,J:3',
                    'C:2,D:2,F:2,H:2,I:2', 'B:3,C:2,D:2,F:1,H:3,I:3,J:2', 'C:1,F:2,H:3,J:4', 'C:2,D:2,F:1,H:1,I:2', 'C:9,F:5,H:8'].map(parseTx),
                B: 6, W: 2, a: 40, b: 40
            }
        };

        const $ = id => document.getElementById(id);
        let presetKey = 'shop';
        let cfg = null;            // { items, profit, db, B, W, a, b }
        let lang = 'java';
        let trace = [];
        let cursor = 0;
        let timer = null;

        /* 跟 Java 的 compareTo、Python 的字串比較同一個順序（依字碼） */
        const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
        const esc = x => String(x).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
        const plain = set => '{' + set.join(', ') + '}';
        const fmt = set => esc(plain(set));
        const keyOf = items => items.join('|');
        const tName = tid => 'T' + (tid + 1);
        const bName = bid => 'B' + (bid + 1);
        const f2 = x => x.toFixed(2);
        const f3 = x => x.toFixed(3);
        const has = (t, item) => Object.prototype.hasOwnProperty.call(t, item);
        const lastOf = items => items[items.length - 1];
        const minSupOf = c => c.B * c.W * c.a / 100;
        const msTxt = () => { const m = minSupOf(cfg); return Number.isInteger(m) ? String(m) : String(Math.round(m * 100) / 100); };
        const tuOf = (t, profit) => Object.keys(t).reduce((s, i) => s + t[i] * profit[i], 0);
        const rangeTxt = bids => bids.length ? `${bName(bids[0])}–${bName(bids[bids.length - 1])}` : '';
        const txRange = (bids, B) => bids.length ? `${tName(bids[0] * B)}–${tName(bids[bids.length - 1] * B + B - 1)}` : '';

        /* ---------- 節點（跟 Java / Python 的 Node 一樣：照批次分組） ---------- */
        const newNode = items => ({ items, batches: new Map(), sumUo: 0, sumRuo: 0, ruoOk: false, low: false });
        const entriesOf = n => { const out = []; n.batches.forEach(es => es.forEach(e => out.push(e))); return out; };
        const supOf = n => { let c = 0; n.batches.forEach(es => { c += es.length; }); return c; };
        const rowsOf = n => { const out = []; n.batches.forEach((es, bid) => es.forEach(e => out.push([bid, e.tid, e.uo, e.ruo]))); return out; };
        const snapNode = n => ({ items: n.items, rows: rowsOf(n), sumUo: n.sumUo, sumRuo: n.sumRuo, ok: n.ruoOk, low: n.low });

        /* ---------- 照著程式把整條串流跑一次，記下每一步 ---------- */
        function buildTrace(c) {
            const { profit, db, B, W } = c;
            const minSup = minSupOf(c), beta = c.b / 100, cms = Math.ceil(minSup);
            const nb = Math.floor(db.length / B);
            const steps = [];
            const gl = new Map();               // 全域 HUOPS-List：商品 -> 節點
            const win = [];                     // 視窗裡的批次編號，最舊的在前面
            const stats = { del: 0, nodes: 0, cutSup: 0, cutUb1: 0, cutUb2: 0 };
            const results = [];                 // 每個視窗：{ win, pats, done, ok, fresh, gone }
            let tree = [], treeById = new Map();
            let order = null;                   // 最近一次重整的順序；視窗一變就作廢
            let glSnap = [];
            let phase = -1;
            const tus = db.map(t => tuOf(t, profit));

            const takeSnap = () => { glSnap = (order || [...gl.keys()]).filter(i => gl.has(i)).map(i => snapNode(gl.get(i))); };
            const addTree = (items, parentId, extra) => {
                const n = { id: keyOf(items), items, parent: parentId, ...extra };
                tree.push(n);
                treeById.set(n.id, n);
                return n;
            };
            const push = (kind, extra = {}) => {
                steps.push({
                    kind, phase, gl: glSnap, order, win: win.slice(), stats: { ...stats },
                    results: results.map(r => ({ ...r, pats: r.pats.slice() })),
                    tree: tree.map(n => ({ ...n })), ...extra
                });
                results.forEach(r => r.pats.forEach(p => { p.fresh = false; }));
            };

            push('start');
            for (let b = 0; b < nb; b++) {
                phase++;
                // ① 視窗滿了：最舊的一批整批移出
                if (win.length === W) {
                    const old = win.shift();
                    const before = [...gl.keys()].map(i => snapNode(gl.get(i)));
                    const info = [];
                    [...gl.keys()].forEach(item => {
                        const n = gl.get(item);
                        const es = n.batches.get(old) || [];
                        const u0 = n.sumUo;
                        n.batches.delete(old);
                        es.forEach(e => { n.sumUo -= e.uo; });
                        stats.del += es.length;
                        const gone = !n.batches.size;
                        if (gone) gl.delete(item);
                        if (es.length) info.push({ item, n: es.length, u0, u1: n.sumUo, gone, left: gone ? 0 : supOf(n) });
                    });
                    order = null;
                    gl.forEach(n => { n.ruoOk = false; n.low = false; });
                    takeSnap();
                    push('remove', { bid: old, before, info });
                }
                // ② 新的一批進來：每筆交易的每個商品，在自己的節點、這一批底下加一筆 entry
                win.push(b);
                gl.forEach(n => { n.ruoOk = false; n.low = false; });
                for (let tid = b * B; tid < (b + 1) * B; tid++) {
                    const t = db[tid], tu = tus[tid];
                    const ent = [];
                    Object.keys(t).forEach(item => {
                        if (!gl.has(item)) gl.set(item, newNode([item]));
                        const n = gl.get(item);
                        const e = { tid, uo: t[item] * profit[item] / tu, ruo: 0 };
                        if (!n.batches.has(b)) n.batches.set(b, []);
                        n.batches.get(b).push(e);
                        n.sumUo += e.uo;
                        ent.push({ item, q: t[item], u: t[item] * profit[item], uo: e.uo });
                    });
                    takeSnap();
                    push('tx', { tid, bid: b, tu, ent });
                }
                if (win.length < W) continue;

                // ③ 視窗滿了：重整（照支持度由小到大排、從後面往前算 ruo），再挖
                phase++;
                const sup = {};
                gl.forEach((n, i) => { sup[i] = supOf(n); });
                order = [...gl.keys()].sort((x, y) => sup[x] - sup[y] || cmp(x, y));
                const low = order.filter(i => sup[i] < minSup);
                low.forEach(i => { gl.get(i).low = true; });
                takeSnap();
                push('sort', { sup, low, cms, minSup });
                const temp = new Map();          // tempArray：tid -> 排在後面的商品 uo 加總
                for (let k = order.length - 1; k >= 0; k--) {
                    const n = gl.get(order[k]);
                    n.sumRuo = 0;
                    if (sup[order[k]] < minSup) { entriesOf(n).forEach(e => { e.ruo = 0; }); continue; }
                    const tempBefore = new Map(temp);
                    const rows = [];
                    entriesOf(n).forEach(e => {
                        e.ruo = temp.get(e.tid) || 0;
                        temp.set(e.tid, e.ruo + e.uo);
                        n.sumRuo += e.ruo;
                        rows.push({ tid: e.tid, ruo: e.ruo, uo: e.uo });
                    });
                    n.ruoOk = true;
                    takeSnap();
                    push('ruo', { item: order[k], rows, tempBefore, tempAfter: new Map(temp), lastOne: k === order.length - 1 });
                }

                tree = [];
                treeById = new Map();
                order.forEach(i => addTree([i], '', { status: 'wait' }));
                const R = { win: win.slice(), pats: [], done: false, ok: null, gone: [] };
                results.push(R);

                const search = (prefix, cl) => {
                    for (let k = 0; k < cl.length; k++) {
                        const x = cl[k];
                        const node = treeById.get(keyOf(x.items));
                        const s = supOf(x);
                        const later = cl.slice(k + 1).map(y => lastOf(y.items));
                        const ck = { sup: s, later, out: false, avg: null, ub1: null, ub2: null, tops: [], verdict: '' };
                        if (s < minSup) { ck.verdict = 'sup'; stats.cutSup++; }
                        else {
                            ck.avg = x.sumUo / s;
                            if (ck.avg >= beta - EPS) { ck.out = true; R.pats.push({ items: x.items, sup: s, uo: ck.avg, fresh: true }); }
                            ck.ub1 = (x.sumUo + x.sumRuo) / cms;
                            if (ck.ub1 < beta - EPS) { ck.verdict = 'ub1'; if (later.length) stats.cutUb1++; }
                            else {
                                const vec = rowsOf(x).map(r => ({ tid: r[1], v: r[2] + r[3] })).sort((p, q) => q.v - p.v);
                                ck.ub2 = vec.slice(0, cms).reduce((a, r) => a + r.v, 0) / cms;
                                ck.tops = vec.slice(0, cms).map(r => r.tid);
                                if (ck.ub2 < beta - EPS) { ck.verdict = 'ub2'; if (later.length) stats.cutUb2++; }
                                else ck.verdict = 'go';
                            }
                        }
                        Object.assign(node, { status: 'done', sup: s, avg: ck.avg, ub1: ck.ub1, ub2: ck.ub2, verdict: ck.verdict, out: ck.out, leaf: !later.length });
                        push('check', { x: snapNode(x), p: prefix ? snapNode(prefix) : null, ...ck, cur: node.id });
                        if (ck.verdict !== 'go') continue;
                        const ncl = [];
                        for (let j = k + 1; j < cl.length; j++) {
                            const y = cl[j];
                            const xy = combine(prefix, x, y);
                            const empty = !xy.batches.size;
                            addTree(xy.items, node.id, empty ? { status: 'empty' } : { status: 'built', sup: supOf(xy) });
                            if (!empty) { stats.nodes++; ncl.push(xy); }
                            push('combine', { p: prefix ? snapNode(prefix) : null, x: snapNode(x), y: snapNode(y), xy: snapNode(xy), empty, cur: keyOf(xy.items), srcs: [node.id, keyOf(y.items)] });
                        }
                        if (ncl.length) search(x, ncl);
                    }
                };
                search(null, order.map(i => gl.get(i)));

                // 跟暴力法對照：只看視窗裡的交易，列舉所有組合重算
                const bf = brute(c, win);
                const mineKeys = new Set(R.pats.map(p => keyOf([...p.items].sort(cmp))));
                R.ok = bf.length === R.pats.length && bf.every(p => mineKeys.has(keyOf(p.items)) &&
                    R.pats.some(q => keyOf([...q.items].sort(cmp)) === keyOf(p.items) && q.sup === p.sup && Math.abs(q.uo - p.uo) < 1e-9));
                R.bfCount = bf.length;
                R.freqCount = bf.freq;
                const prev = results.length > 1 ? results[results.length - 2] : null;
                const prevKeys = prev ? new Set(prev.pats.map(p => keyOf([...p.items].sort(cmp)))) : null;
                R.newKeys = prev ? R.pats.filter(p => !prevKeys.has(keyOf([...p.items].sort(cmp)))).map(p => keyOf([...p.items].sort(cmp))) : [];
                R.gone = prev ? prev.pats.filter(p => !mineKeys.has(keyOf([...p.items].sort(cmp)))).map(p => p.items) : [];
                R.done = true;
                push('result', { idx: results.length - 1 });
            }
            push('end', { nb });
            return steps;
        }

        /* 合併 Px 和 Py 的節點，得到 Pxy 的（只留兩邊都有的交易） */
        function combine(p, x, y) {
            const xy = newNode([...x.items, lastOf(y.items)]);
            xy.ruoOk = true;
            const ys = new Map(entriesOf(y).map(e => [e.tid, e]));
            const ps = p ? new Map(entriesOf(p).map(e => [e.tid, e])) : null;
            x.batches.forEach((es, bid) => es.forEach(ex => {
                const ey = ys.get(ex.tid);
                if (!ey) return;                                 // 這筆交易沒有 y
                const e = { tid: ex.tid, uo: ex.uo + ey.uo - (p ? ps.get(ex.tid).uo : 0), ruo: Math.min(ex.ruo, ey.ruo) };
                if (!xy.batches.has(bid)) xy.batches.set(bid, []);
                xy.batches.get(bid).push(e);
                xy.sumUo += e.uo;
                xy.sumRuo += e.ruo;
            }));
            return xy;
        }

        /* 暴力法：只看視窗裡的交易，列舉所有組合，直接算支持度和平均佔有率 */
        function brute(c, bids) {
            const txs = [];
            bids.forEach(b => { for (let k = b * c.B; k < (b + 1) * c.B; k++) txs.push(c.db[k]); });
            const items = [...new Set(txs.flatMap(t => Object.keys(t)))].sort(cmp);
            const minSup = minSupOf(c), beta = c.b / 100;
            const out = [];
            let freq = 0;
            for (let m = 1; m < (1 << items.length); m++) {
                const set = items.filter((_, i) => m >> i & 1);
                const occ = txs.filter(t => set.every(i => has(t, i)));
                if (!occ.length || occ.length < minSup) continue;
                freq++;
                const uo = occ.reduce((a, t) => a + set.reduce((s, i) => s + t[i] * c.profit[i], 0) / tuOf(t, c.profit), 0) / occ.length;
                if (uo >= beta - EPS) out.push({ items: set, sup: occ.length, uo });
            }
            out.freq = freq;
            return out;
        }

        /* 給測試用：每個視窗挖到的 [樣式, 支持度, 佔有率] */
        function runAll(c) {
            const tr = buildTrace(c);
            return tr.filter(s => s.kind === 'result').map(s => {
                const r = s.results[s.idx];
                return { win: r.win, ok: r.ok, pats: r.pats.map(p => [p.items, p.sup, p.uo]) };
            });
        }

        /* ---------- 說明文字 ---------- */
        const nmOf = i => (EMOJI[i] ? EMOJI[i] : '') + i;
        const uoCalc = (t, i) => `${t[i]}×${cfg.profit[i]}`;
        const winTxt = bids => `${bids.length} 批（${rangeTxt(bids)}，${bids.length * cfg.B} 筆）`;
        const later3 = list => esc(list.length > 4 ? list.slice(0, 4).join('、') + ` 等 ${list.length} 個` : list.join('、'));
        function describe(s) {
            const beta = cfg.b / 100;
            switch (s.kind) {
                case 'start': {
                    const t0 = cfg.db[0], i0 = Object.keys(t0)[0], tu0 = tuOf(t0, cfg.profit);
                    return `交易一筆一筆進來，每 <b>${cfg.B}</b> 筆收成一<b>批</b>，視窗只放最近 <b>${cfg.W}</b> 批（${cfg.W * cfg.B} 筆）；新的一批進來時，最舊的一批整批移出。` +
                        `一個組合在某筆交易的<b>佔有率 uo</b> = 它的效益 ÷ 那筆的總效益 TU，例如 T1 裡 ${esc(i0)} 是 ${uoCalc(t0, i0)} = ${t0[i0] * cfg.profit[i0]}，TU = ${tu0}，uo = ${f2(t0[i0] * cfg.profit[i0] / tu0)}。` +
                        `目標：每個視窗裡，找出出現至少 minSup = ${cfg.W * cfg.B} × ${cfg.a}% = <b>${msTxt()}</b> 筆、而且平均佔有率 ≥ β = <b>${f2(beta)}</b> 的組合。`;
                }
                case 'tx': {
                    const t = cfg.db[s.tid];
                    const e = s.ent[0];
                    return `${tName(s.tid)} 進來（第 ${s.bid + 1} 批 ${bName(s.bid)}）：TU = ${Object.keys(t).map(i => uoCalc(t, i)).join(' + ')} = ${s.tu}。` +
                        `每個商品在自己的節點、${bName(s.bid)} 那一組底下加一筆 (tid, uo, ruo)：uo = 自己的效益 ÷ TU，例如 ${esc(e.item)} ${e.u} / ${s.tu} = <b>${f2(e.uo)}</b>，sumUo 跟著加上去；` +
                        `ruo 先記 0（要等排好順序才知道誰在後面）。` +
                        (s.win.length < cfg.W ? `視窗現在 ${s.win.length} / ${cfg.W} 批，還沒滿。` : s.tid === (s.bid + 1) * cfg.B - 1 ? `這一批收完，視窗滿了，可以挖了。` : '');
                }
                case 'remove': {
                    const gone = s.info.filter(x => x.gone).map(x => x.item);
                    const ex = s.info.find(x => !x.gone) || s.info[0];
                    return `視窗已經放滿 ${cfg.W} 批，${bName(s.bid + cfg.W)} 要進來之前，最舊的 <b>${bName(s.bid)}</b>（${txRange([s.bid], cfg.B)}）整批移出。` +
                        `entry 本來就照批次分組，每個節點把 ${bName(s.bid)} 那一組整組拿掉、sumUo 減掉它們的 uo 就好，不用一筆一筆找` +
                        (ex ? `，例如 ${esc(ex.item)}：${f2(ex.u0)} → ${f2(ex.u1)}` : '') + '。' +
                        (gone.length ? `${esc(gone.join('、'))} 在視窗裡已經沒有了，節點整個拿掉。` : '') +
                        `視窗內容變了，支持度的順序可能跟著變，ruo 全部作廢，等要挖的時候重算。`;
                }
                case 'sort': {
                    const ord = s.order.map(i => `${esc(i)}(${s.sup[i]})`).join(' → ');
                    return `視窗 ${winTxt(s.win)}滿了，開始挖。先<b>重整</b>：照支持度由小到大排（一樣多比名稱），括號是出現幾筆：${ord}。` +
                        (s.low.length ? `minSup = ${msTxt()}，${esc(s.low.join('、'))} 不到，含它的組合出現次數只會更少，<b>ruo 不用算</b>，挖的時候第一關就跳過。`
                            : `每個商品都至少 ${msTxt()} 筆，全部要算 ruo。`) +
                        `支持度小的排前面，它們的分支最早檢查、也最容易早早結束。`;
                }
                case 'ruo': {
                    const r = s.rows.find(x => x.ruo > 0) || s.rows[0];
                    if (s.lastOne) return `從排最後的往前算 ruo（排在後面的商品 uo 加總），用 <b>tempArray</b> 記每筆交易「目前加到哪裡」。` +
                        `${esc(s.item)} 排在最後，後面沒有商品，ruo 全部是 0；接著把它每筆的 uo 放進 tempArray（下面那排）。`;
                    return `輪到 ${esc(s.item)}：每筆 entry 的 ruo 就是 tempArray 裡那筆目前的值，例如 ${tName(r.tid)} 的 ruo = <b>${f2(r.ruo)}</b>` +
                        `（排在 ${esc(s.item)} 後面、也在這筆交易裡的商品 uo 加起來）；抄完再把自己的 uo 加進 tempArray（${f2(r.ruo)} + ${f2(r.uo)} = ${f2(r.ruo + r.uo)}），給排在前面的商品用。` +
                        `Σruo = ${f2(s.gl.find(n => n.items[0] === s.item).sumRuo)}。`;
                }
                case 'check': {
                    const x = s.x;
                    let t = `檢查 ${fmt(x.items)}：sup = ${s.sup}`;
                    if (s.verdict === 'sup') return t + ` < minSup ${msTxt()}，出現的筆數不夠；再加商品只會出現得更少，<b>自己不算、整個分支也跳過</b>。`;
                    t += ` ≥ ${msTxt()}；平均佔有率 = Σuo / sup = ${f2(x.sumUo)} / ${s.sup} = ${f3(s.avg)}` +
                        (s.out ? ` ≥ ${f2(beta)}，<b class="ok">輸出</b>。` : ` < ${f2(beta)}，本身不夠。`);
                    t += `UBUO1 = (Σuo + Σruo) / ⌈minSup⌉ = (${f2(x.sumUo)} + ${f2(x.sumRuo)}) / ${cfg.cms} = ${f2(s.ub1)}`;
                    if (s.verdict === 'ub1') return t + ` < ${f2(beta)}：就算把後面的商品全加進來，佔有率也到不了，<b>${s.later.length ? '整個分支剪掉' : '後面也沒商品了'}</b>。`;
                    t += ` ≥ ${f2(beta)}，再算比較緊的 UBUO2：uo + ruo 最大的 ${cfg.cms} 筆（${s.tops.map(tName).join('、')}）平均 = ${f2(s.ub2)}`;
                    if (s.verdict === 'ub2') return t + ` < ${f2(beta)}，<b>${s.later.length ? 'UBUO2 把這個分支剪掉' : '後面也沒商品了'}</b>。`;
                    return t + (s.later.length ? ` ≥ ${f2(beta)}，兩個上界都過，往下展開：跟後面的 ${later3(s.later)} ${s.later.length > 1 ? '各' : ''}合併一次。`
                        : ` ≥ ${f2(beta)}，可是後面沒有商品可以再加，到此為止。`) +
                        (!s.out && s.later.length ? `<b>不能看它本身不夠就丟掉</b>：佔有率沒有向下封閉性，組合變大，佔的比例可能更高。` : '');
                }
                case 'combine': {
                    const { x, y, xy, p } = s;
                    const pair = `${fmt(x.items)} 和 ${fmt(y.items)}`;
                    if (s.empty) return `合併 ${pair}：兩個節點沒有共同的交易（這幾樣從來沒有一起被買過），${fmt(xy.items)} 是空的，直接丟掉。`;
                    const tids = xy.rows.map(r => tName(r[1])).join('、');
                    const tid = xy.rows[0][1];
                    const a = x.rows.find(r => r[1] === tid), b = y.rows.find(r => r[1] === tid);
                    const tail = `得到 ${fmt(xy.items)}：sup ${xy.rows.length}、Σuo ${f2(xy.sumUo)}、Σruo ${f2(xy.sumRuo)}。`;
                    const ruoTxt = `ruo 取兩邊較小的（${f2(Math.min(a[3], b[3]))}，就是 ${esc(lastOf(y.items))} 的，因為它排在後面）。`;
                    if (!p) return `合併 ${pair}：只留兩邊都有的交易 ${tids}，照原本的批次分組。新 entry 的 uo 直接相加，例如 ${tName(tid)}：${f2(a[2])} + ${f2(b[2])} = <b>${f2(a[2] + b[2])}</b>；${ruoTxt}${tail}`;
                    const c = p.rows.find(r => r[1] === tid);
                    return `合併 ${pair}（共同前綴 P = ${fmt(p.items)}）：只留兩邊都有的交易 ${tids}。兩邊的 uo 都已經含有 P 的佔有率，相加會算兩次，` +
                        `所以要<b>扣掉 P 的一次</b>，例如 ${tName(tid)}：${f2(a[2])} + ${f2(b[2])} − ${f2(c[2])} = <b>${f2(a[2] + b[2] - c[2])}</b>；${ruoTxt}${tail}`;
                }
                case 'result': {
                    const r = s.results[s.idx];
                    let t = `第 ${s.idx + 1} 個視窗（${rangeTxt(r.win)}）挖完：找到 <b>${r.pats.length}</b> 個高效益佔有率樣式。` +
                        `用暴力法對照（只看視窗裡的 ${r.win.length * cfg.B} 筆，把所有組合的支持度和平均佔有率直接算一遍）：` +
                        (r.ok ? `<b class="ok">一模一樣 ✓</b>。` : `<b class="no">不一致 ✗</b>。`) +
                        (r.freqCount > r.pats.length ? `只看支持度的話會有 ${r.freqCount} 個，佔有率把 ${r.freqCount - r.pats.length} 個刷掉了。` : '');
                    if (s.idx > 0) t += r.newKeys.length || r.gone.length ? `跟上一個視窗比：新出現 ${r.newKeys.length} 個、消失 ${r.gone.length} 個。` : `跟上一個視窗的結果一樣。`;
                    return t;
                }
                case 'end': {
                    const st = s.stats;
                    if (!s.results.length) return `交易不夠湊滿一個視窗（要 ${cfg.W} 批 × ${cfg.B} 筆），沒有挖。把每批筆數或視窗批數調小一點試試看。`;
                    return `串流用完了（真正的串流不會停）。一共挖了 ${s.results.length} 個視窗，每個都跟暴力法${s.results.every(r => r.ok) ? '<b class="ok">一致</b>' : '<b class="no">有不一致</b>'}。` +
                        `整批移出 ${st.del} 筆 entry、合併出 ${st.nodes} 個條件節點；支持度不夠跳過 ${st.cutSup} 次，UBUO1 剪掉 ${st.cutUb1} 個分支、UBUO2 再多剪 ${st.cutUb2} 個。` +
                        (st.cutUb1 + st.cutUb2 === 0 ? `這組門檻下上界沒有出手，把 β 調高看看。` : '');
                }
            }
            return '';
        }

        const CODE_TAGS = s => {
            switch (s.kind) {
                case 'tx': return ['insert'];
                case 'check': return ['check'].concat(s.out ? ['output'] : [], s.verdict === 'sup' ? [] : ['ub1'],
                    s.verdict === 'ub2' || s.verdict === 'go' ? ['ub2'] : [], s.verdict === 'go' ? ['expand'] : []);
                case 'end': return ['loop'];
                default: return [s.kind];        // start / remove / sort / ruo / combine / result
            }
        };

        /* ---------- 輸送帶 ---------- */
        function buildBelt() {
            const inner = $('belt-inner');
            inner.innerHTML = '';
            const nb = Math.floor(cfg.db.length / cfg.B);
            const groups = [];
            for (let b = 0; b < nb; b++) groups.push({ label: bName(b), tids: Array.from({ length: cfg.B }, (_, k) => b * cfg.B + k), bid: b });
            if (nb * cfg.B < cfg.db.length) groups.push({ label: '湊不滿一批', tids: Array.from({ length: cfg.db.length - nb * cfg.B }, (_, k) => nb * cfg.B + k), bid: -1 });
            groups.forEach(g => {
                const box = document.createElement('div');
                box.className = 'bt' + (g.bid < 0 ? ' rest' : '');
                box.dataset.b = g.bid;
                box.innerHTML = '<span class="bt-l"></span><div class="bt-row"></div>';
                box.firstChild.textContent = g.label;
                g.tids.forEach(tid => {
                    const t = cfg.db[tid];
                    const card = document.createElement('div');
                    card.className = 'tx';
                    card.dataset.tid = tid;
                    card.innerHTML = '<span class="tid"></span>' + cfg.items.map(() => '<div class="slot"></div>').join('') + '<span class="tu"></span>';
                    card.querySelector('.tid').textContent = tName(tid);
                    card.querySelectorAll('.slot').forEach((sl, k) => {
                        const it = cfg.items[k];
                        sl.dataset.i = it;
                        if (!has(t, it)) { sl.className = 'slot off'; return; }
                        sl.title = `${it} × ${t[it]}`;
                        sl.innerHTML = EMOJI[it] ? '<span></span><small></small>' : '<span class="lt"></span><small></small>';
                        sl.firstChild.textContent = EMOJI[it] || it;
                        sl.lastChild.textContent = t[it];
                    });
                    card.querySelector('.tu').textContent = 'TU ' + tuOf(t, cfg.profit);
                    box.lastChild.appendChild(card);
                });
                inner.appendChild(box);
            });
            const frame = document.createElement('div');
            frame.className = 'frame empty';
            frame.id = 'frame';
            frame.innerHTML = '<span class="lbl"></span>';
            inner.appendChild(frame);
            $('profits').innerHTML = '<span>單位利潤：</span>' + cfg.items.map(i => `<span>${esc(nmOf(i))} <b>$${cfg.profit[i]}</b></span>`).join('');
        }

        function focusItems(s) {
            if (s.kind === 'check') return s.x.items;
            if (s.kind === 'combine') return s.xy.items;
            if (s.kind === 'ruo') return [s.item];
            return null;
        }
        function renderBelt(s, smooth) {
            const inWin = new Set(s.win);
            const lo = s.win.length ? s.win[0] : Infinity;
            const fi = focusItems(s);
            const enterTid = s.kind === 'tx' ? s.tid : -1;
            const curBid = s.kind === 'tx' ? s.bid : -1;
            const seen = s.kind === 'end' ? Infinity : s.kind === 'start' ? -1 : Math.max(...s.win, s.kind === 'remove' ? s.bid : -1);
            [...$('belt-inner').querySelectorAll('.bt')].forEach(box => {
                const b = Number(box.dataset.b);
                const leaving = s.kind === 'remove' && b === s.bid;
                let cls = 'bt' + (b < 0 ? ' rest' : '');
                if (b >= 0) {
                    if (leaving) cls += ' leaving';
                    else if (inWin.has(b)) cls += b === curBid ? ' entering' : '';
                    else if (b < lo || (s.kind === 'end' && !inWin.has(b))) cls += ' past';
                    else if (b > seen) cls += ' future';
                }
                if (box.className !== cls) box.className = cls;
                box.querySelectorAll('.tx').forEach(card => {
                    const tid = Number(card.dataset.tid);
                    const t = cfg.db[tid];
                    const hidden = b === curBid && tid > enterTid;
                    const match = fi && inWin.has(b) && fi.every(i => has(t, i));
                    const c2 = 'tx' + (tid === enterTid ? ' enter' : '') + (match ? ' match' : '');
                    if (card.className !== c2) card.className = c2;
                    card.style.opacity = hidden ? '0.35' : '';
                    card.style.borderStyle = hidden ? 'dashed' : '';
                    card.querySelectorAll('.slot').forEach(sl => sl.classList.toggle('hit', !!match && fi.includes(sl.dataset.i)));
                });
            });
            const frame = $('frame');
            if (!s.win.length) { frame.className = 'frame empty'; if (!measuringBlocks) $('belt').scrollTo({ left: 0 }); return; }
            const boxes = [...$('belt-inner').querySelectorAll('.bt')];
            const a = boxes[s.win[0]], z = boxes[s.win[s.win.length - 1]];
            const left = a.offsetLeft - 5, width = z.offsetLeft + z.offsetWidth + 5 - left;
            frame.style.transition = smooth ? '' : 'none';
            frame.style.left = left + 'px';
            frame.style.width = width + 'px';
            const full = s.win.length === cfg.W;
            frame.className = 'frame' + (full ? ' full' : '');
            frame.querySelector('.lbl').textContent = `視窗 ${s.win.length}/${cfg.W} 批`;
            if (!smooth) { void frame.offsetWidth; frame.style.transition = ''; }
            if (measuringBlocks) return;
            // 只捲輸送帶本身：讓視窗右邊（新進來的那端）看得到
            const belt = $('belt');
            const right = $('belt-inner').offsetLeft + z.offsetLeft + z.offsetWidth + 40;
            belt.scrollTo({ left: Math.max(0, right - belt.clientWidth), behavior: smooth ? 'smooth' : 'auto' });
        }

        /* ---------- HUOPS-List ---------- */
        function ulBox(n, { role = '', cls = '', newTid = -1, delBid = -1, keep = null, ex = -1, tops = null, foot = '' } = {}) {
            let lastB = null;
            const rows = n.rows.map(([bid, tid, uo, ruo], k) => {
                const c = [tid === ex ? 'ex' : tid === newTid ? 'new' : bid === delBid ? 'del' : keep && !keep.has(tid) ? 'dim' : '',
                    tops && tops.includes(tid) ? 'tp' : '', k && bid !== lastB ? 'bsep' : ''].join(' ');
                const bl = bid !== lastB ? bName(bid) : '';
                lastB = bid;
                return `<tr class="${c}"><td class="b">${bl}</td><td>${tName(tid)}</td><td>${f2(uo)}</td><td>${n.ok ? f2(ruo) : '–'}</td></tr>`;
            }).join('');
            return `<div class="ul ${cls}${n.low ? ' low' : ''}"><div class="ul-h">${role ? `<span class="role">${role}</span>` : ''}<span>${esc((n.items.length === 1 ? nmOf(n.items[0]) : plain(n.items)))}</span><span class="sp">sup ${n.rows.length}</span></div>` +
                `<table><tr><th>批</th><th>tid</th><th>uo</th><th>ruo</th></tr>${rows || '<tr><td colspan="4" style="color:var(--muted)">（空）</td></tr>'}` +
                `<tr class="sum"><td>Σ</td><td></td><td>${f2(n.sumUo)}</td><td>${n.ok ? f2(n.sumRuo) : '–'}</td></tr></table>` +
                (foot || n.low ? `<div class="ul-f">${foot || '支持度不夠，ruo 不用算'}</div>` : '') + '</div>';
        }

        function drawLists(s) {
            const box = $('uls'), sub = $('ul-sub'), temp = $('temp');
            const beta = cfg.b / 100;
            let h = '', tp = '';
            if (s.kind === 'check') {
                const x = s.x;
                sub.textContent = `檢查 ${plain(x.items)}`;
                let foot = `sup <b class="${s.sup >= cfg.minSup ? 'ok' : 'no'}">${s.sup}</b>（minSup ${msTxt()}）`;
                if (s.avg !== null) foot += ` · 平均 uo <b class="${s.out ? 'ok' : 'no'}">${f3(s.avg)}</b>`;
                if (s.ub1 !== null) foot += ` · UBUO1 <b class="${s.ub1 >= beta - EPS ? 'ok' : 'no'}">${f2(s.ub1)}</b>`;
                if (s.ub2 !== null) foot += ` · UBUO2 <b class="${s.ub2 >= beta - EPS ? 'ok' : 'no'}">${f2(s.ub2)}</b>`;
                h = ulBox(x, { cls: 'focus', tops: s.tops.length ? s.tops : null, foot });
                if (s.ub2 !== null) tp = `<span>紫色粗體是 uo + ruo 最大的 ${cfg.cms} 筆（算 UBUO2 用）</span>`;
            } else if (s.kind === 'combine') {
                const keep = new Set(s.xy.rows.map(r => r[1]));
                const ex = s.xy.rows.length ? s.xy.rows[0][1] : -1;
                const pre = s.p ? 'P' : '';
                sub.textContent = '合併出 ' + plain(s.xy.items);
                h = ulBox(s.x, { role: pre + 'x', keep, ex }) + '<span class="op">+</span>' + ulBox(s.y, { role: pre + 'y', keep, ex }) +
                    (s.p ? '<span class="op">−</span>' + ulBox(s.p, { role: 'P', keep, ex }) : '') +
                    '<span class="op">→</span>' + ulBox(s.xy, { role: pre + 'xy', cls: 'res', ex });
            } else if (s.kind === 'remove') {
                sub.textContent = `${bName(s.bid)} 整批移出`;
                const goneSet = new Set(s.info.filter(x => x.gone).map(x => x.item));
                h = s.before.map(n => {
                    const inf = s.info.find(x => x.item === n.items[0]);
                    return ulBox(n, { delBid: s.bid, cls: goneSet.has(n.items[0]) ? 'gone' : '',
                        foot: inf ? (inf.gone ? '視窗裡沒有了，整個節點拿掉' : `sumUo ${f2(inf.u0)} → <b>${f2(inf.u1)}</b>`) : '' });
                }).join('');
            } else if (s.kind === 'start' || (s.kind === 'end' && !s.gl.length)) {
                sub.textContent = '';
                h = `<div class="uls-empty">${s.kind === 'start' ? '還沒有交易進來，list 是空的。' : '沒有資料。'}</div>`;
            } else {
                sub.textContent = s.kind === 'tx' ? `${tName(s.tid)} 加進 ${bName(s.bid)} 那一組`
                    : s.kind === 'sort' ? '照支持度由小到大重排' : s.kind === 'ruo' ? `從後面往前算 ruo：${s.item}` : '全域 list（目前的視窗）';
                h = s.gl.map(n => ulBox(n, { newTid: s.kind === 'tx' ? s.tid : -1, cls: s.kind === 'ruo' && n.items[0] === s.item ? 'focus' : '' })).join('');
            }
            if (s.kind === 'ruo') {
                const upd = new Set(s.rows.map(r => r.tid));
                tp = '<span>tempArray：</span>' + [...s.tempAfter.keys()].sort((a, b) => a - b).map(tid =>
                    `<span class="tc${upd.has(tid) ? ' up' : ''}">${tName(tid)} ${f2(s.tempAfter.get(tid))}</span>`).join('');
            }
            if (drawLists.last !== h) { box.innerHTML = h; drawLists.last = h; }   // 跟上一步一樣就不重畫
            if (drawLists.lastTp !== tp) { temp.innerHTML = tp; drawLists.lastTp = tp; }
        }

        /* ---------- 搜尋樹 ---------- */
        function nodeView(n, s) {
            const last = lastOf(n.items);
            const beta = cfg.b / 100;
            let cls = n.status, tag = '';
            switch (n.status) {
                case 'wait': tag = '待檢查'; break;
                case 'built': tag = `sup ${n.sup}，待檢查`; break;
                case 'empty': tag = '沒有共同交易，丟掉'; break;
                case 'done': {
                    const cut = n.verdict === 'sup' ? `✂ sup ${n.sup} < ${msTxt()}`
                        : n.verdict === 'ub1' && !n.leaf ? `✂ UBUO1 ${f2(n.ub1)} < ${f2(beta)}`
                        : n.verdict === 'ub2' && !n.leaf ? `✂ UBUO2 ${f2(n.ub2)} < ${f2(beta)}` : '';
                    if (n.out) { cls = 'hui'; tag = '✓ 輸出' + (cut ? '，' + cut : ''); }
                    else if (cut) { cls = 'cut'; tag = cut; }
                    else if (n.leaf) { cls = 'low'; tag = '不夠，後面也沒商品'; }
                    else { cls = 'go'; tag = '不夠，但上界夠，往下找'; }
                    break;
                }
            }
            if (n.id === s.cur) cls += ' cur';
            else if (s.srcs && s.srcs.includes(n.id)) cls += ' src';
            const vals = n.status === 'done' && n.avg !== null ? `<span class="v">sup <b>${n.sup}</b> · uo <b>${f2(n.avg)}</b></span>` : '';
            return `<div class="tn ${cls}" title="${fmt(n.items)}"><span class="n">${n.items.length > 1 ? '＋' : ''}${esc(nmOf(last))}</span>${vals}<span class="tag">${tag}</span></div>`;
        }
        function drawTree(s) {
            const box = $('tree');
            const mining = ['check', 'combine', 'result'].includes(s.kind) || (s.kind === 'end' && s.tree.length);
            if (!mining) {
                const h = `<div class="tree-empty">${s.kind === 'sort' || s.kind === 'ruo' ? '重整完（排好順序、算好 ruo）就從這裡開始深度優先搜尋。' : '視窗滿了、要結果的時候，這裡會長出這個視窗的搜尋樹。'}</div>`;
                if (drawTree.last !== h) { box.innerHTML = h; drawTree.last = h; }
                return;
            }
            const kids = {};
            s.tree.forEach(n => { (kids[n.parent] = kids[n.parent] || []).push(n); });
            const li = n => `<li>${nodeView(n, s)}${kids[n.id] ? `<ul>${kids[n.id].map(li).join('')}</ul>` : ''}</li>`;
            const h = `<ul class="tr"><li><div class="tn root">∅ 第 ${s.results.length} 個視窗（${rangeTxt(s.results[s.results.length - 1].win)}）</div><ul>${(kids[''] || []).map(li).join('')}</ul></li></ul>`;
            if (drawTree.last !== h) { box.innerHTML = h; drawTree.last = h; }
            if (measuringBlocks) return;
            // 只捲樹的框，讓這一步的節點留在看得到的地方
            const el = box.querySelector('.tn.cur');
            if (el) {
                const y = el.getBoundingClientRect().top - box.getBoundingClientRect().top + box.scrollTop;
                if (y < box.scrollTop + 10 || y + el.offsetHeight > box.scrollTop + box.clientHeight - 10) {
                    box.scrollTo({ top: Math.max(0, y - box.clientHeight / 2), behavior: 'smooth' });
                }
            }
        }

        /* ---------- 每個視窗的結果 ---------- */
        function patChip(items, sup, uo, cls) {
            const p = document.createElement('span');
            p.className = 'pat ' + cls;
            p.innerHTML = '<span class="nm"></span><span class="n"></span>';
            p.firstChild.textContent = plain(items);
            p.lastChild.textContent = uo === null ? '掉出' : `${sup} · ${f3(uo)}`;
            return p;
        }
        function winBox(r, k, now) {
            const w = document.createElement('div');
            w.className = 'win' + (now ? ' now' : '');
            w.innerHTML = '<div class="win-h"><span class="wn"></span><span class="rg"></span><span class="bf"></span></div><div class="items"></div>';
            w.querySelector('.wn').textContent = `W${k + 1}`;
            w.querySelector('.rg').textContent = `${rangeTxt(r.win)}（${txRange(r.win, cfg.B)}）`;
            const bf = w.querySelector('.bf');
            bf.textContent = r.done ? (r.ok ? '✓ 跟暴力法一致' : '✗ 跟暴力法不同') : '挖掘中…';
            bf.className = 'bf' + (r.done ? (r.ok ? ' ok' : ' no') : '');
            const items = w.querySelector('.items');
            const nk = new Set(r.done ? r.newKeys : []);
            r.pats.forEach(p => items.appendChild(patChip(p.items, p.sup, p.uo, (p.fresh ? 'fresh ' : '') + (nk.has(keyOf([...p.items].sort(cmp))) ? 'newp' : ''))));
            if (r.done) r.gone.forEach(g => items.appendChild(patChip(g, 0, null, 'gone')));
            if (!items.children.length) items.innerHTML = `<span class="empty">${r.done ? '（沒有）' : '還沒找到'}</span>`;
            return w;
        }
        function drawResult(s) {
            const box = $('wins');
            // 只重畫內容有變的視窗（大部分步驟只有最後一個視窗在變，或完全沒變）
            const sigs = s.results.map((r, k) => `${r.done}:${r.pats.length}:${r.pats.map(p => p.fresh ? 1 : 0).join('')}:${k === s.results.length - 1 && s.kind !== 'end'}`);
            const emptySig = s.results.length ? '' : 'empty:' + (s.kind === 'end');
            if (drawResult.box !== box.firstChild || drawResult.emptySig !== emptySig) { box.innerHTML = ''; drawResult.sigs = []; }
            drawResult.emptySig = emptySig;
            if (!s.results.length && !box.firstChild) {
                box.innerHTML = `<div class="empty">${s.kind === 'end' ? '交易不夠湊滿一個視窗。' : '視窗還沒滿。第一次滿了之後，每個視窗挖到的結果會一個一個列在這裡（小字是「支持度 · 平均佔有率」）。'}</div>`;
            }
            const old = drawResult.sigs || [];
            const kids = [...box.querySelectorAll(':scope > .win')];
            kids.slice(sigs.length).forEach(el => el.remove());
            sigs.forEach((g, k) => {
                if (old[k] === g && kids[k]) return;
                const el = winBox(s.results[k], k, k === s.results.length - 1 && s.kind !== 'end');
                if (kids[k]) box.replaceChild(el, kids[k]); else box.appendChild(el);
            });
            drawResult.sigs = sigs;
            drawResult.box = box.firstChild;
            $('st-del').textContent = s.stats.del;
            $('st-nodes').textContent = s.stats.nodes;
            $('st-sup').textContent = s.stats.cutSup;
            $('st-ub').textContent = `${s.stats.cutUb1} / ${s.stats.cutUb2}`;
        }

        /* ---------- 進度（每一批、每次挖） ---------- */
        let phaseList = [];
        function buildPhases() {
            phaseList = [];
            trace.forEach((s, i) => {
                if (s.phase < 0 || phaseList[s.phase]) return;
                phaseList[s.phase] = { at: i, label: s.kind === 'sort' ? `挖 W${s.results.length + 1}` : `${bName(s.kind === 'remove' ? s.bid + cfg.W : s.bid)} 進來`, mine: s.kind === 'sort' };
            });
            const box = $('phases');
            box.innerHTML = '';
            phaseList.forEach((p, k) => {
                const b = document.createElement('button');
                b.type = 'button';
                b.className = 'phase' + (p.mine ? ' mine' : '');
                b.id = `ph${k}-first`;            // id 結尾是 first：量高度時按下去會先排隊
                b.textContent = p.label;
                b.addEventListener('click', () => { stopAuto(); quizClose(); cursor = p.at; showStep(); });
                box.appendChild(b);
            });
        }
        function renderPhases(s) {
            [...$('phases').children].forEach((b, k) => b.classList.toggle('cur', k === s.phase));
        }

        /* ---------- 程式碼 ---------- */
        const KW = {
            java: new Set('public static final for if return new boolean int long double void class import while else null this continue'.split(' ')),
            py: new Set('def for in if return not and or while import from as True False None class is lambda continue del self'.split(' '))
        };
        function highlight(line) {
            const at = lang === 'java' ? line.indexOf('//') : line.indexOf('#');
            let body = line, comment = '';
            if (at >= 0) { body = line.slice(0, at); comment = line.slice(at); }
            if (lang === 'py' && /^\s*"""/.test(line)) { body = ''; comment = line; }
            if (lang === 'java' && /^\s*\/\*\*/.test(line)) { body = ''; comment = line; }
            const out = body.replace(/("(?:[^"\\]|\\.)*")|(\b\d+(?:\.\d+)?(?:e-?\d+)?\b)|([A-Za-z_]\w*)(\s*\()?|([^"\w]+)/g, (m, str, num, word, call) => {
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
                ? '下載 <a href="code/SWHUOP.java" download>SWHUOP.java</a>　執行 <code>javac SWHUOP.java && java SWHUOP</code>'
                : '下載 <a href="code/sw_huop.py" download>sw_huop.py</a>　執行 <code>python3 sw_huop.py</code>';
        }

        /* ---------- 顯示某一步 ---------- */
        function showStep(smooth = true) {
            const s = trace[cursor];
            $('explain').innerHTML = `<span class="step-no">步驟 ${cursor + 1} / ${trace.length}</span>${describe(s)}`;
            renderBelt(s, smooth && !measuringBlocks);
            renderPhases(s);
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
            reserveBlockHeights(document, trace.length, i => { cursor = i; showStep(false); }, () => cursor);
        }

        /* ---------- 參數 ---------- */
        const nbOf = (B, n) => Math.floor(n / B);
        function renderParams() {
            const n = cfg.db.length;
            $('b-val').textContent = cfg.B;
            $('w-val').textContent = cfg.W;
            $('a-val').textContent = cfg.a + '%';
            $('be-val').textContent = cfg.b + '%';
            const fixed = presetKey === 'paper3';   // 10 個商品：批次和視窗照論文固定，不然步驟會多到上千步
            $('b-minus').disabled = fixed || cfg.B <= 1;
            $('b-plus').disabled = fixed || cfg.B >= 6 || nbOf(cfg.B + 1, n) < cfg.W;
            $('w-minus').disabled = fixed || cfg.W <= 2;
            $('w-plus').disabled = fixed || cfg.W >= 4 || nbOf(cfg.B, n) < cfg.W + 1;
            $('a-minus').disabled = cfg.a <= (fixed ? 30 : 10);
            $('a-plus').disabled = cfg.a >= 100;
            $('be-minus').disabled = cfg.b <= 5;
            $('be-plus').disabled = cfg.b >= 100;
            const m = cfg.W * cfg.B;
            $('derived').innerHTML = `視窗 = ${cfg.W} 批 × ${cfg.B} 筆 = <b>${m}</b> 筆　·　minSup = ${m} × ${cfg.a}% = <b>${msTxt()}</b>（⌈minSup⌉ = <b>${cfg.cms}</b>）　·　β = <b>${f2(cfg.b / 100)}</b>　·　共 ${nbOf(cfg.B, n)} 批、挖 ${Math.max(0, nbOf(cfg.B, n) - cfg.W + 1)} 次`;
        }
        function setCfg(c) {
            cfg = c;
            cfg.minSup = minSupOf(cfg);
            cfg.cms = Math.ceil(cfg.minSup);
        }
        function loadPreset(k) {
            presetKey = k;
            const p = PRESETS[k];
            setCfg({ items: p.items, profit: p.profit, db: p.db, B: p.B, W: p.W, a: p.a, b: p.b });
        }

        function rebuild() {
            stopAuto();
            setCfg(cfg);
            trace = buildTrace(cfg);
            cursor = 0;
            drawResult.box = drawLists.last = drawTree.last = null;
            buildBelt();
            buildPhases();
            renderParams();
            showStep(false);
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

        /* 小數題：正確答案＋容易搞混的數字，湊滿 4 個、由小到大排（顯示到小數第 2 位） */
        function quizDec(ans, traps, rnd) {
            const seen = new Set([f2(ans)]);
            const vals = [ans];
            traps.forEach(v => { if (vals.length < 4 && isFinite(v) && v >= 0 && !seen.has(f2(v))) { seen.add(f2(v)); vals.push(v); } });
            for (let d = 1; vals.length < 4 && d < 40; d++) {
                quizShuffle([ans + 0.05 * d, ans - 0.05 * d], rnd).forEach(v => { if (vals.length < 4 && v >= 0 && !seen.has(f2(v))) { seen.add(f2(v)); vals.push(v); } });
            }
            vals.sort((p, q) => p - q);
            return { choices: vals.map(f2), answer: vals.indexOf(ans) };
        }

        const CAT = ['輸出，也往下展開', '輸出，但不再往下', '不輸出，但往下展開', '不輸出，也不往下'];
        /* 第 i 步（s = trace[i]）要出的題目：{ q, choices, answer, why, multi?, ask? } 或 null（ask 只給 quiz_test.py 對答案用） */
        function quizFor(s, i) {
            const rnd = quizRng(i + 1);
            const beta = cfg.b / 100;
            switch (s.kind) {
                case 'tx': {
                    if (s.tid % 2) return null;                       // 隔一筆問一次
                    const e = quizPick(s.ent, rnd);
                    const t = cfg.db[s.tid];
                    const qs = Object.values(t).reduce((a, v) => a + v, 0), ps = Object.keys(t).reduce((a, k) => a + cfg.profit[k], 0);
                    return {
                        q: `${tName(s.tid)} 進來，TU = ${s.tu}。${e.item}（買 ${e.q} 個、利潤 ${cfg.profit[e.item]}）在這筆的 uo 是多少？`,
                        ...quizDec(e.uo, [e.q / qs, cfg.profit[e.item] / ps, 1 - e.uo], rnd),
                        why: `uo = 自己的效益 ÷ 整筆 TU = ${e.q}×${cfg.profit[e.item]} / ${s.tu} = ${e.u} / ${s.tu} = ${f2(e.uo)}（看的是錢，不是個數）。`,
                        ask: { type: 'uo', tid: s.tid, item: e.item }
                    };
                }
                case 'remove': {
                    const inf = quizPick(s.info, rnd);
                    if (!inf) return null;
                    const before = inf.left + inf.n;
                    return {
                        q: `${bName(s.bid)} 整批移出後，${inf.item} 的節點還剩幾筆 entry（也就是視窗裡的支持度）？`,
                        ...quizNums(inf.left, 0, Math.max(before, 3), rnd, [before, inf.n]),
                        why: inf.gone ? `${inf.item} 只出現在 ${bName(s.bid)}，那一組拿掉就沒了，節點整個刪掉（0 筆）。`
                            : `原本 ${before} 筆，${bName(s.bid)} 那一組有 ${inf.n} 筆，整組拿掉剩 ${inf.left} 筆。`,
                        ask: { type: 'remain', win: s.win, item: inf.item }
                    };
                }
                case 'sort': {
                    const items = Object.keys(s.sup);
                    if (items.length <= 6) {
                        const ch = quizShuffle(items.slice().sort(cmp), rnd);
                        const ans = ch.map((x, k) => k).filter(k => s.sup[ch[k]] < cfg.minSup);
                        const mq = {
                            q: `視窗滿了，minSup = ${msTxt()}。哪些商品支持度不到、ruo 不用算？（都夠就直接按確定）`,
                            choices: ch, answer: ans, multi: true,
                            why: ans.length ? `${ans.map(k => `${ch[k]} 只出現 ${s.sup[ch[k]]} 筆`).join('、')}，< ${msTxt()}，含它的組合不可能過關。`
                                : `每個商品都至少出現 ${msTxt()} 筆，全部都要算。`,
                            ask: { type: 'low', win: s.win }
                        };
                        return ch.length > 1 ? mq : quizSingle(mq, `視窗滿了，minSup = ${msTxt()}。${ch[0]} 支持度不到、ruo 不用算嗎？`);
                    }
                    const o = s.order;
                    return {
                        q: `照支持度由小到大排（一樣多比名稱），排第一個的是哪個？`,
                        ...quizOptions([{ text: o[0] }, { text: o[o.length - 1] }, { text: o[1] }, { text: items.slice().sort(cmp)[0] }], rnd),
                        why: `${o[0]} 只出現 ${s.sup[o[0]]} 筆，是最少的；最多的 ${o[o.length - 1]}（${s.sup[o[o.length - 1]]} 筆）排在最後。`,
                        ask: { type: 'first', win: s.win }
                    };
                }
                case 'ruo': {
                    if (s.lastOne || i % 2) return null;
                    const r = quizPick(s.rows, rnd);
                    return {
                        q: `輪到 ${s.item}：它在 ${tName(r.tid)} 這筆的 ruo 是多少？（看上一步的 tempArray）`,
                        ...quizDec(r.ruo, [r.ruo + r.uo, r.uo, Math.max(0, 1 - r.uo)], rnd),
                        why: `ruo 就是 tempArray 裡 ${tName(r.tid)} 目前的值 ${f2(r.ruo)}（排在 ${s.item} 後面的商品 uo 加總），不含自己；抄完才把自己的 ${f2(r.uo)} 加進去。`,
                        ask: { type: 'ruo', win: s.win, item: s.item, tid: r.tid }
                    };
                }
                case 'check': {
                    const more = s.verdict === 'go' && s.later.length > 0;
                    const nums = s.verdict === 'sup' ? `sup ${s.sup}（minSup ${msTxt()}）`
                        : `sup ${s.sup}（minSup ${msTxt()}）、平均 uo ${f3(s.avg)}、UBUO1 ${f2(s.ub1)}` + (s.ub2 !== null ? `、UBUO2 ${f2(s.ub2)}` : '（UBUO2 還沒算）');
                    return {
                        q: `${plain(s.x.items)}：${nums}，β = ${f2(beta)}，` + (s.later.length ? `後面還有 ${s.later.join('、')}。` : '後面沒有商品了。') + '接下來？',
                        choices: CAT,
                        answer: (s.out ? 0 : 2) + (more ? 0 : 1),
                        why: s.verdict === 'sup' ? `sup ${s.sup} < ${msTxt()}，自己不算，加商品只會更少，整個跳過。`
                            : (s.out ? `平均 ${f3(s.avg)} ≥ ${f2(beta)}，輸出；` : `平均 ${f3(s.avg)} < ${f2(beta)}，不輸出；`) +
                            (!s.later.length ? '後面沒有商品，到此為止。'
                                : s.verdict === 'ub1' ? `UBUO1 ${f2(s.ub1)} < ${f2(beta)}，整個分支剪掉。`
                                : s.verdict === 'ub2' ? `UBUO1 過了，但 UBUO2 ${f2(s.ub2)} < ${f2(beta)}，剪掉。`
                                : `兩個上界都 ≥ ${f2(beta)}，往下展開。`),
                        ask: { type: 'check', win: s.win, items: s.x.items }
                    };
                }
                case 'combine': {
                    if (s.empty || (!s.p && rnd() < 0.5)) return null;   // 有共同前綴 P 的一定問（要扣 P），其他問一半
                    const r = quizPick(s.xy.rows, rnd), tid = r[1];
                    const a = s.x.rows.find(z => z[1] === tid)[2], b = s.y.rows.find(z => z[1] === tid)[2];
                    return {
                        q: `合併 ${plain(s.x.items)} 和 ${plain(s.y.items)}${s.p ? `（共同前綴 P = ${plain(s.p.items)}）` : ''}：新節點在 ${tName(tid)} 的 uo 是多少？`,
                        ...quizDec(r[2], [a + b, a, b], rnd),
                        why: s.p ? `${f2(a)} + ${f2(b)} − P 的 ${f2(a + b - r[2])} = ${f2(r[2])}：P 的佔有率兩邊都算了，要扣掉一次。`
                            : `沒有共同前綴，兩邊直接相加：${f2(a)} + ${f2(b)} = ${f2(r[2])}。`,
                        ask: { type: 'cuo', win: s.win, items: s.xy.items, tid }
                    };
                }
                case 'result': {
                    const r = s.results[s.idx];
                    const prev = s.idx ? s.results[s.idx - 1].pats.length : -1;
                    return {
                        q: `第 ${s.idx + 1} 個視窗（${rangeTxt(r.win)}）挖完，一共有幾個高效益佔有率樣式？`,
                        ...quizNums(r.pats.length, 0, Math.max(r.freqCount, r.pats.length + 3), rnd, [r.freqCount, prev]),
                        why: `綠框的 ${r.pats.length} 個；只看支持度會有 ${r.freqCount} 個，佔有率不夠的被刷掉。`,
                        ask: { type: 'count', win: r.win }
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
            timer = setInterval(() => { if (!step(1)) stopAuto(); }, 1700);
        });
        document.addEventListener('keydown', e => {
            if (e.target.closest && e.target.closest('select, input, textarea')) return;
            if (e.key === 'ArrowRight') { stopAuto(); step(1); }
            if (e.key === 'ArrowLeft') { stopAuto(); step(-1); }
        });
        const bump = (k, d) => () => { cfg[k] += d; rebuild(); };
        $('b-minus').addEventListener('click', bump('B', -1));
        $('b-plus').addEventListener('click', bump('B', 1));
        $('w-minus').addEventListener('click', bump('W', -1));
        $('w-plus').addEventListener('click', bump('W', 1));
        $('a-minus').addEventListener('click', bump('a', -5));
        $('a-plus').addEventListener('click', bump('a', 5));
        $('be-minus').addEventListener('click', bump('b', -5));
        $('be-plus').addEventListener('click', bump('b', 5));
        $('preset').addEventListener('change', e => { loadPreset(e.target.value); rebuild(); });
        $('lang').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b) return;
            lang = b.dataset.lang;
            [...$('lang').children].forEach(x => x.classList.toggle('active', x === b));
            renderCode(CODE_TAGS(trace[cursor]));
        });
        let resizeTimer = null;
        window.addEventListener('resize', () => { clearTimeout(resizeTimer); resizeTimer = setTimeout(() => { reserveExplainHeight(); renderBelt(trace[cursor], false); }, 150); });

        loadPreset('shop');
        rebuild();
    </script>
</body>

</html>
