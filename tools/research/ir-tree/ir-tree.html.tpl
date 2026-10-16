<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/ir-tree.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/ir-tree-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/ir-tree-180.png">
    <title>IR-tree 空間關鍵字查詢</title>
    <meta name="description" content="在街區地圖上點一個位置、勾選要買的商品，一步一步看 IR-tree 怎麼查每個節點的倒排表，把湊不齊關鍵字的框整個跳過，再依距離找出最近的 k 家店；跟「先找最近再檢查」、「先查倒排表再排序」比較打開的節點與檢查的店家數，Java 與 Python 程式碼逐行對照。">
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
        .intro { color: #c6c6d6; max-width: 800px; margin-top: 0.9rem; font-size: 0.95rem; }
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
        .param { display: flex; align-items: center; gap: 0.45rem; }
        .param .val { font: 700 1rem 'Space Mono', monospace; min-width: 1.4em; text-align: center; }
        .param input[type=range] { width: 120px; accent-color: var(--accent2); }
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
        .explain .ok { color: #86efac; font-weight: 600; }
        .explain .no { color: #fca5a5; font-weight: 600; }


        /* ── 地圖 ── */
        .map-box { background: #0a0a14; border: 1px solid var(--border); border-radius: 10px; overflow: hidden; }
        svg.map { display: block; width: 100%; height: auto; touch-action: manipulation; user-select: none; -webkit-user-select: none; cursor: crosshair; }
        svg.map * { vector-effect: non-scaling-stroke; }
        .map .bg { fill: #0b0b17; }
        .map .gridfaint { stroke: #15152a; stroke-width: 1; }
        .map .border { fill: none; stroke: #3a3a5a; stroke-width: 1.5; }
        .map .pt { stroke: #05050a; stroke-width: 1; }
        .map .pt.pending { fill: none; stroke-width: 1.6; opacity: 0.6; }
        .map .pt.dim { opacity: 0.22; }
        .map .pt.faded { opacity: 0.4; }
        .map .ring { fill: none; stroke-width: 2.4; }
        .map .ring.cur { stroke: var(--warn); }
        .map .ring.hit { stroke: var(--good); }
        .map .ring.miss { stroke: var(--bad); }
        .map .ring.moved { stroke: var(--accent2); }
        .map .ring.old { opacity: 0.45; stroke-width: 1.6; }
        .map .lbl { fill: var(--text); paint-order: stroke; stroke: #05050a; stroke-width: 3px; stroke-linejoin: round; font-family: 'Space Mono', ui-monospace, monospace; font-weight: 700; }

        .map-tools { display: flex; flex-wrap: wrap; gap: 0.4rem; align-items: center; margin-top: 0.7rem; }
        .kinds { display: flex; flex-wrap: wrap; gap: 0.3rem; align-items: center; flex-basis: 100%; }
        .kinds .lab { color: var(--muted); font-size: 0.8rem; margin-right: 0.15rem; }
        .kind {
            display: inline-flex; align-items: center; gap: 0.3rem;
            background: var(--panel-2); border: 1px solid var(--border); border-radius: 999px;
            color: var(--text); font: inherit; font-size: 0.8rem; padding: 0.15rem 0.6rem 0.15rem 0.4rem; cursor: pointer;
        }
        .kind svg { width: 14px; height: 14px; display: block; }
        .kind.sel { border-color: var(--warn); box-shadow: 0 0 0 1px var(--warn) inset; }
        .kind .cnt { font: 700 0.72rem 'Space Mono', monospace; color: var(--muted); }
        .hint { color: var(--muted); font-size: 0.8rem; margin-top: 0.5rem; min-height: 1.3em; }
        .hint.warn { color: var(--warn); }
        .legend { display: flex; flex-wrap: wrap; gap: 0.3rem 0.9rem; font-size: 0.75rem; color: var(--muted); margin-top: 0.45rem; }
        .legend i { display: inline-block; width: 11px; height: 11px; border-radius: 3px; margin-right: 0.3rem; vertical-align: -1px; border: 2px solid; }

        /* ── 統計 ── */
        .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.5rem; }
        .stat { background: var(--panel-2); border-radius: 10px; padding: 0.55rem 0.6rem; }
        .stat .v { font: 700 1.25rem 'Space Mono', monospace; }
        .stat .v small { font-size: 0.75rem; color: var(--muted); font-weight: 400; }
        .stat .k { color: var(--muted); font-size: 0.75rem; line-height: 1.35; }
        .sub { color: var(--muted); font-size: 0.78rem; margin: 0.8rem 0 0.4rem; }
        .bars { display: grid; gap: 0.35rem; margin-top: 0.8rem; }
        .bar { display: grid; grid-template-columns: 7.2em 1fr 2.4em; gap: 0.5rem; align-items: center; font-size: 0.8rem; color: var(--muted); }
        .bar .track { height: 10px; background: #1b1b30; border-radius: 6px; overflow: hidden; }
        .bar .fill { height: 100%; background: var(--accent2); border-radius: 6px; transition: width 0.25s; }
        .bar .fill.all { background: #4a4a6a; }
        .bar .n { font: 700 0.8rem 'Space Mono', monospace; color: var(--text); text-align: right; }


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
            max-height: 560px;
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
        .downloads code { font: 0.78rem 'Space Mono', monospace; background: var(--panel-2); padding: 0.1rem 0.4rem; border-radius: 4px; color: var(--text); }

        .notes { margin-top: 1rem; display: grid; gap: 1rem; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr; } }
        .notes p, .notes li { color: #c6c6d6; font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; }
        .notes b { color: var(--text); }
        .notes a { color: var(--accent2); }

        /* ── IR-tree 的框 ── */
        .map .box { fill-opacity: 0.045; stroke-width: 1.3; }
        .map .box.opened { fill-opacity: 0.1; }
        .map .box.queued { stroke: var(--accent2) !important; stroke-width: 2; stroke-dasharray: 5 3; }
        .map .box.skip { fill: #78789a !important; fill-opacity: 0.3; stroke: #78789a !important; stroke-dasharray: 2 3; }
        .map .box.cur { stroke: var(--warn) !important; stroke-width: 3; fill: var(--warn) !important; fill-opacity: 0.12; }
        .map .blbl { paint-order: stroke; stroke: #05050a; stroke-width: 2.5px; stroke-linejoin: round; font-family: 'Space Mono', ui-monospace, monospace; font-weight: 700; }
        .map .blbl.dim { opacity: 0.5; }
        .map .pt.match { fill: #22d3ee; }
        .map .pt.other { fill: #55556e; }
        .map .emo { paint-order: stroke; stroke: #05050a; stroke-width: 2px; }
        .map .mdl { stroke: var(--accent2); stroke-width: 1.4; stroke-dasharray: 3 2; }
        .map .qpt { fill: #fff; stroke: #05050a; stroke-width: 1.5; }
        .map .qcross { stroke: #fff; stroke-width: 1.6; }

        /* ── 關鍵字選擇 ── */
        .kws { display: flex; flex-wrap: wrap; gap: 0.3rem; align-items: center; }
        .kws .lab { color: var(--muted); font-size: 0.88rem; margin-right: 0.2rem; }
        .kind .em { font-size: 0.95rem; line-height: 1; }

        /* ── 樹的結構 ── */
        .levels { display: grid; gap: 0.6rem; }
        .lv-tag { font: 700 0.75rem 'Space Mono', monospace; color: var(--muted); margin-bottom: 0.3rem; }
        .lv-row { display: flex; flex-wrap: wrap; gap: 0.35rem; }
        .tnode {
            display: inline-flex; align-items: center; gap: 0.35rem; flex-wrap: wrap;
            border: 1px solid var(--border); border-left: 3px solid var(--lc, var(--border));
            background: var(--panel-2); border-radius: 7px; padding: 0.2rem 0.45rem; font-size: 0.78rem;
        }
        .tnode .nm { font: 700 0.78rem 'Space Mono', monospace; }
        .tnode .kids { color: var(--muted); font: 0.72rem 'Space Mono', monospace; }
        .tnode .wd { letter-spacing: 1px; }
        .tnode .wd i { font-style: normal; }
        .tnode .wd i.off { opacity: 0.28; filter: grayscale(1); }
        .tnode .shop { font: 0.7rem 'Space Mono', monospace; color: var(--muted); white-space: nowrap; }
        .tnode .shop.match { color: #67e8f9; }
        .tnode.cur { border-color: var(--warn); box-shadow: 0 0 0 1px var(--warn) inset; background: rgba(245, 158, 11, 0.12); }
        .tnode.queued { border-color: var(--accent2); border-style: dashed; }
        .tnode.opened { background: rgba(6, 182, 212, 0.08); }
        .tnode.skip { opacity: 0.5; text-decoration: line-through; text-decoration-color: rgba(248, 113, 113, 0.8); }
        .tnote { color: var(--muted); font-size: 0.75rem; margin-top: 0.6rem; }

        /* ── 倒排表 ── */
        .invhead { font-size: 0.85rem; color: #c6c6d6; margin-bottom: 0.5rem; }
        .invhead b { font-family: 'Space Mono', monospace; color: var(--warn); }
        .inv { display: grid; gap: 0.25rem; }
        .irow { display: flex; align-items: center; gap: 0.5rem; padding: 0.25rem 0.5rem; border-radius: 8px; border: 1px solid var(--border); background: var(--panel-2); font-size: 0.8rem; flex-wrap: wrap; }
        .irow .w { min-width: 4.6em; white-space: nowrap; }
        .irow.dim { opacity: 0.45; }
        .irow.q { border-color: var(--warn); box-shadow: 0 0 0 1px var(--warn) inset; }
        .irow.miss { border-color: var(--bad); box-shadow: 0 0 0 1px var(--bad) inset; }
        .irow.ans { border-color: rgba(34, 197, 94, 0.6); background: rgba(34, 197, 94, 0.08); }
        .ents { display: flex; flex-wrap: wrap; gap: 0.25rem; }
        .ent { font: 700 0.72rem 'Space Mono', monospace; border-radius: 6px; padding: 0 0.35rem; background: #1b1b30; color: var(--muted); }
        .ent.hit { background: rgba(34, 197, 94, 0.22); color: #86efac; }
        .ent.out { background: rgba(248, 113, 113, 0.16); color: #fca5a5; }
        .ent.none { background: none; color: #fca5a5; font-weight: 400; font-family: inherit; }

        /* ── 優先佇列 ── */
        .qlist { display: grid; gap: 0.25rem; }
        .qrow { display: flex; align-items: center; gap: 0.5rem; padding: 0.25rem 0.5rem; border-radius: 8px; border: 1px solid var(--border); background: var(--panel-2); font-size: 0.8rem; }
        .qrow .rk { font: 700 0.72rem 'Space Mono', monospace; color: var(--muted); min-width: 1.6em; }
        .qrow .it { display: inline-flex; align-items: center; gap: 0.3rem; font-weight: 600; min-width: 0; flex-wrap: wrap; }
        .qrow .ds { margin-left: auto; font: 700 0.78rem 'Space Mono', monospace; white-space: nowrap; }
        .qrow .ds small { color: var(--muted); font-weight: 400; }
        .qrow.first { border-color: var(--warn); box-shadow: 0 0 0 1px var(--warn) inset; }
        .qrow.drop { opacity: 0.6; text-decoration: line-through; text-decoration-color: rgba(248, 113, 113, 0.7); }
        .qrow.res { border-color: rgba(34, 197, 94, 0.55); }
        .tagv { font-size: 0.7rem; border-radius: 6px; padding: 0 0.35rem; white-space: nowrap; }
        .tagv.new { background: rgba(6, 182, 212, 0.18); color: var(--accent2); }
        .tagv.drop { background: rgba(248, 113, 113, 0.18); color: #fca5a5; }
        .tagv.ok { background: rgba(34, 197, 94, 0.22); color: #86efac; }
        .empty { color: var(--muted); font-size: 0.85rem; }

        /* ── 三種做法比一比 ── */
        .cmp-sub { color: var(--muted); font-size: 0.78rem; margin-top: 0.8rem; }
        .cmp-sub:first-of-type { margin-top: 0.2rem; }
        .bars { display: grid; gap: 0.35rem; margin-top: 0.4rem; }
        .bar { display: grid; grid-template-columns: 7.4em 1fr 3.6em; gap: 0.5rem; align-items: center; font-size: 0.8rem; color: var(--muted); }
        .bar .track { height: 10px; background: #1b1b30; border-radius: 6px; overflow: hidden; }
        .bar .fill { height: 100%; background: var(--accent2); border-radius: 6px; transition: width 0.25s; }
        .bar .fill.a { background: var(--accent); }
        .bar .fill.b { background: #4a4a6a; }
        .bar .n { font: 700 0.8rem 'Space Mono', monospace; color: var(--text); text-align: right; white-space: nowrap; }
        .cmp-note { color: var(--muted); font-size: 0.8rem; margin-top: 0.7rem; }
        .cmp-note b { color: var(--text); }
    </style>
</head>

<body>
    <div class="wrap">
        <a class="back" href="../index.html#research">← RETURN TO PORTFOLIO</a>
        <div class="kicker">RESEARCH DEMO · SPATIAL KEYWORD QUERY</div>
        <h1>IR-tree 空間關鍵字查詢<small>R-tree 的每個節點掛一份倒排表，關鍵字湊不齊的框整個跳過</small></h1>
        <p class="intro">
            <a href="rtree.html">上一頁的 R-tree</a> 只管「近不近」。可是真正的需求常常是「<b>離我最近、而且咖啡和牛奶都有賣</b>的 3 家店」：只看距離，最近的那幾家可能都缺貨；只看商品，又得把所有有賣的店都算一次距離。
            IR-tree（Cong 等人 2009 年提出，De Felipe 等人 2008 年也有類似的想法）把兩件事綁在一起：R-tree 的<b>每個節點多記一份倒排表</b>，寫著「哪個子節點底下有賣哪些商品」。
            查詢時打開一個節點，先查倒排表，<b>商品湊不齊的子節點連距離都不用算，整個跳過</b>；湊得齊的才依最短距離排進優先佇列。點地圖換位置、勾選要買的東西，看看可以少打開多少框。
        </p>

        <section id="panel" class="layout">
            <div>
                <div class="card">
                    <div class="card-head"><h2>一步一步看</h2></div>
                    <div class="player">
                        <button class="btn" id="ir-first" title="回到開頭">⏮</button>
                        <button class="btn" id="ir-prev">◀ 上一步</button>
                        <button class="btn primary" id="ir-next">下一步 ▶</button>
                        <button class="btn" id="ir-play">▶ 自動播放</button>
                        <button class="btn" id="ir-last">⏭ 直接看結果</button>
                    </div>
                    <div class="params">
                        <div class="kws" id="kw-box"></div>
                        <div class="param">
                            <span>找最近的 k =</span>
                            <button class="btn stepper" id="k-minus" aria-label="減少">−</button>
                            <span class="val" id="k-val">3</span>
                            <button class="btn stepper" id="k-plus" aria-label="增加">+</button>
                            <span class="unit">家</span>
                        </div>
                        <div class="param">
                            <span>節點容量 M =</span>
                            <button class="btn stepper" id="m-minus" aria-label="減少">−</button>
                            <span class="val" id="m-val">4</span>
                            <button class="btn stepper" id="m-plus" aria-label="增加">+</button>
                        </div>
                    </div>
                    <div class="explain" id="ir-explain"></div>
                </div>

                <div class="card">
                    <div class="card-head"><h2>街區地圖</h2><span class="unit" id="ir-count" style="color:var(--muted);font-size:0.8rem"></span></div>
                    <div class="map-box"><svg class="map" id="ir-map" viewBox="-7 -7 142 142" role="img" aria-label="地圖、店家、查詢點與 IR-tree 的框"></svg></div>
                    <div class="map-tools" id="ir-tools">
                        <button class="btn small" data-act="random">🎲 隨機產生店家</button>
                        <button class="btn small" data-act="reset">恢復預設</button>
                    </div>
                    <div class="hint" id="ir-hint"></div>
                    <div class="legend">
                        <span><i style="border-color:#fff;border-radius:50%;background:#fff"></i>查詢點</span>
                        <span><i style="border-color:#22d3ee;border-radius:50%;background:#22d3ee"></i>商品都有的店</span>
                        <span><i style="border-color:#55556e;border-radius:50%;background:#55556e"></i>缺商品的店</span>
                        <span><i style="border-color:var(--warn);background:rgba(245,158,11,0.3)"></i>正在打開的框</span>
                        <span><i style="border-color:var(--accent2);border-style:dashed"></i>在佇列裡的框</span>
                        <span><i style="border-color:#78789a;background:rgba(120,120,154,0.5)"></i>關鍵字不符、跳過</span>
                        <span><i style="border-color:var(--good);border-radius:50%"></i>找到的店</span>
                    </div>
                </div>

                <div class="card">
                    <h2>這一步查的倒排表</h2>
                    <div class="invhead" id="inv-head"></div>
                    <div class="inv" id="inv-rows"></div>
                </div>

                <div class="card">
                    <h2>三種做法比一比</h2>
                    <div class="cmp-sub">打開的節點（樹上共 <span id="cmp-nodes">0</span> 個）</div>
                    <div class="bars" id="cmp-open"></div>
                    <div class="cmp-sub">算了距離的店家（地圖上共 <span id="cmp-shops">0</span> 家）</div>
                    <div class="bars" id="cmp-dist"></div>
                    <div class="cmp-note" id="cmp-note"></div>
                </div>
            </div>

            <div>
                <div class="card">
                    <h2>IR-tree 的結構</h2>
                    <div class="sub">每個節點後面的圖示就是它的倒排表裡有的商品（整棵子樹賣的東西）；你要的商品亮著，其他的變灰</div>
                    <div class="levels" id="ir-tree"></div>
                </div>

                <div class="card">
                    <h2>優先佇列與答案</h2>
                    <div class="stats">
                        <div class="stat"><div class="v" id="st-open">0</div><div class="k">打開的節點</div></div>
                        <div class="stat"><div class="v" id="st-dist">0</div><div class="k">算了距離的店</div></div>
                        <div class="stat"><div class="v" id="st-skip">0</div><div class="k">缺商品跳過</div></div>
                    </div>
                    <div class="sub">佇列（由近到遠，下一個取出最上面那個）</div>
                    <div class="qlist" id="ir-queue"></div>
                    <div class="sub">已經確定的答案</div>
                    <div class="qlist" id="ir-res"></div>
                </div>

                <div class="card">
                    <div class="card-head">
                        <h2>程式碼</h2>
                        <div class="lang">
                            <button data-lang="java" class="active">Java</button>
                            <button data-lang="py">Python</button>
                        </div>
                    </div>
                    <pre class="code" id="ir-code"></pre>
                    <div class="downloads" id="ir-downloads"></div>
                </div>
            </div>
        </section>

        <div class="notes">
            <div class="card">
                <h2>為什麼跳過的框裡一定沒有答案？</h2>
                <p>節點的倒排表是由下往上合併的：葉子記它的店家賣什麼，上一層把子節點的倒排表合起來。所以<b>某個商品不在節點的倒排表裡，就代表整棵子樹沒有一家店賣它</b>。答案要「每個商品都有」，只要缺一個，那棵子樹裡就不可能有答案，跳過不會漏掉任何一家。</p>
                <p style="margin-top:0.5rem"><b>為什麼取出來的店一定是答案？</b>跟 R-tree 的 best-first search 一樣：框的 MINDIST 是查詢點到框的最短距離，框裡的店不可能比它更近。佇列依距離由近到遠取，輪到某家店時，剩下的框裡的店都不會比它近；而佇列裡只放「商品都有」的店，所以它就是下一個答案。</p>
                <p style="margin-top:0.5rem"><b>一樣遠怎麼辦？</b>距離一樣時編號小的店排前面；佇列裡距離一樣時框排在店前面，先打開來確認。結果跟「所有店先過濾商品、再依距離排序」的暴力法一模一樣。</p>
            </div>
            <div class="card">
                <h2>優缺點，以及跟實驗室研究的關係</h2>
                <ul>
                    <li><b>兩種剪法一起用：</b>只看距離（做法一）會一直打開附近、但商品不對的框；只看商品（做法二）要把每家有賣的店都算距離。IR-tree 兩個條件同時用來剪，商品很常見或很少見時都不會太差。</li>
                    <li><b>代價：</b>每個節點多一份倒排表，比 R-tree 占空間；新增店家時沿路的倒排表也要更新。上層節點底下店很多，倒排表容易「什麼都有」，剪不太掉——預設資料讓附近的店賣的東西比較像，才剪得明顯，可以按「隨機產生」看看效果變多少。</li>
                    <li><b>延伸：</b>原始論文的 IR-tree 還會依文字相關度（例如 TF-IDF）和距離一起排分數，找「又近又相關」的店；這頁只做「商品全部都要有」的布林版本。也有把建樹時就把賣類似東西的店放在一起的做法（如 DIR-tree），讓倒排表更好剪。</li>
                    <li><b>跟研究的關係：</b>倒排表就是在記「哪些項目出現在哪裡」，跟 <a href="eclat.html">Eclat 的 tid-list</a> 是同一個東西，取交集也一樣；「整棵子樹都不可能，直接跳過」則跟頻繁樣式探勘裡用上界剪枝是同一種想法。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           IR-tree 空間關鍵字查詢一步一步看
           網頁裡用 JavaScript 照著同樣的演算法跑一次，把每一步記下來；
           上一步／下一步只是在這些紀錄之間移動。右邊的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = /*CODE_JSON*/null;
        const DATA = /*DATA_JSON*/null;

        const WORLD = 128;
        const ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片'];
        const EMOJI = { '咖啡': '☕', '麵包': '🍞', '牛奶': '🥛', '飯糰': '🍙', '茶葉蛋': '🥚', '洋芋片': '🥔' };
        const LV_COLORS = ['#2dd4bf', '#818cf8', '#e879f9', '#fbbf24', '#fb7185', '#a3e635'];
        const defaultShops = () => DATA.shops.map(([x, y, items]) => ({ x, y, items: new Set(items) }));

        const $ = id => document.getElementById(id);
        let shops = defaultShops();
        let capM = 4;
        let kNum = DATA.k;
        let qPoint = { x: DATA.q[0], y: DATA.q[1] };
        let qWords = new Set(DATA.words);
        let lang = 'java';

        let tree = null;                     // { root, nodes(依編號), total }
        let steps = [];
        let compare = null;
        let cursor = 0;
        let timer = null;

        const emo = ws => ITEMS.filter(w => ws.has(w)).map(w => EMOJI[w]).join('');
        const qList = () => ITEMS.filter(w => qWords.has(w));
        const qEmo = () => qList().map(w => EMOJI[w]).join('');
        const pn = j => `#${j + 1}(${shops[j].x},${shops[j].y})`;
        const rn = id => 'R' + id;
        const dstr = d2 => Math.sqrt(d2).toFixed(1);
        const hasAll = (have, need) => [...need].every(w => have.has(w));

        /* =================== 幾何 =================== */
        const shopRect = j => [shops[j].x, shops[j].y, shops[j].x, shops[j].y];
        function mindist(q, r) {
            const dx = Math.max(r[0] - q.x, 0, q.x - r[2]), dy = Math.max(r[1] - q.y, 0, q.y - r[3]);
            return dx * dx + dy * dy;
        }
        const dist2 = (q, j) => (shops[j].x - q.x) ** 2 + (shops[j].y - q.y) ** 2;
        function cmpTuple(a, b) {                       // 跟 Python 的 tuple 比大小一樣
            for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return a[i] < b[i] ? -1 : 1;
            return 0;
        }

        /* =================== 建樹：STR 批次建樹＋每個節點的倒排表 =================== */
        function buildTree(list, M) {
            let nextId = 0;
            const nodes = [];
            const rectOf = (e, leaf) => (leaf ? [list[e].x, list[e].y, list[e].x, list[e].y] : e.mbr);
            const wordsOf = (e, leaf) => (leaf ? list[e].items : e.words);
            function mk(leaf, entries) {
                const rs = entries.map(e => rectOf(e, leaf));
                const mbr = rs.reduce((a, b) => [Math.min(a[0], b[0]), Math.min(a[1], b[1]), Math.max(a[2], b[2]), Math.max(a[3], b[3])]);
                const inv = new Map();
                entries.forEach((e, i) => [...wordsOf(e, leaf)].sort().forEach(w => { if (!inv.has(w)) inv.set(w, []); inv.get(w).push(i); }));
                const n = { id: nextId++, leaf, entries, mbr, inv, words: new Set(inv.keys()) };
                nodes.push(n);
                return n;
            }
            function pack(items, leaf) {
                const key = e => { const r = rectOf(e, leaf); return [r[0] + r[2], r[1] + r[3], leaf ? e : e.id]; };
                const pages = Math.ceil(items.length / M);
                const per = Math.ceil(Math.sqrt(pages)) * M;
                items.sort((a, b) => cmpTuple(key(a), key(b)));
                const out = [];
                for (let i = 0; i < items.length; i += per) {
                    const yk = e => { const k = key(e); return [k[1], k[0], k[2]]; };
                    const slab = items.slice(i, i + per).sort((a, b) => cmpTuple(yk(a), yk(b)));
                    for (let j = 0; j < slab.length; j += M) out.push(mk(leaf, slab.slice(j, j + M)));
                }
                return out;
            }
            let level = list.length ? pack(list.map((_, j) => j), true) : [];
            while (level.length > 1) level = pack(level, false);
            const root = level.length ? level[0] : null;
            const depth = new Map();
            (function walk(n, d) { if (!n) return; depth.set(n.id, d); if (!n.leaf) n.entries.forEach(c => walk(c, d + 1)); })(root, 0);
            return { root, nodes, total: nextId, depth, H: root ? Math.max(...depth.values()) : 0 };
        }

        /* =================== 查詢：照著程式跑一次，記下每一步 =================== */
        function irTrace(t, q, words, k) {
            const out = [];
            const st = { opened: 0, checked: 0, skipped: 0 };
            const cmpItem = (a, b) => cmpTuple([a.d, a.t, a.id], [b.d, b.t, b.id]);
            let queue = [];
            const results = [], openedIds = [], skipNodes = [], skipShops = [], checkedShops = [];
            const view = it => ({ d: it.d, t: it.t, id: it.id });
            const push = (kind, extra = {}) => out.push({
                kind, ...extra, st: { ...st }, queue: queue.map(view), results: results.slice(),
                opened: openedIds.slice(), skipNodes: skipNodes.slice(), skipShops: skipShops.slice(), checked: checkedShops.slice()
            });
            const root = t.root;
            push('build', { inv: root ? root.id : null });
            if (!root || k <= 0) { push('end', { reason: 'none', inv: null }); return out; }
            const missing = [...words].filter(w => !root.words.has(w));
            if (missing.length) {
                push('start', { fail: missing, inv: root.id });
                push('end', { reason: 'nokw', inv: root.id });
                return out;
            }
            queue.push({ d: mindist(q, root.mbr), t: 0, id: root.id, node: root });
            push('start', { inv: root.id });
            let lastInv = root.id;
            while (queue.length && results.length < k) {
                queue.sort(cmpItem);
                const it = queue.shift();
                if (it.t === 1) {                            // 取出來的是店家：它就是下一個答案
                    results.push({ j: it.id, d: it.d });
                    push('point', { j: it.id, d: it.d, rank: results.length, inv: lastInv });
                    continue;
                }
                const e = it.node;
                st.opened++;
                openedIds.push(e.id);
                let ok = e.entries.map((_, i) => i);
                const rows = ITEMS.filter(w => words.has(w)).map(w => {
                    const list = e.inv.get(w);
                    ok = ok.filter(i => list.includes(i));
                    return { w, list: list.slice() };
                });
                const okSet = new Set(ok);
                const ref = c => (e.leaf ? c : c.id);
                const skipped = e.entries.filter((_, i) => !okSet.has(i)).map(ref);
                st.skipped += skipped.length;
                skipped.forEach(r => (e.leaf ? skipShops : skipNodes).push(r));
                const pushed = ok.map(i => {
                    const c = e.entries[i];
                    let x;
                    if (e.leaf) { st.checked++; checkedShops.push(c); x = { d: dist2(q, c), t: 1, id: c }; }
                    else x = { d: mindist(q, c.mbr), t: 0, id: c.id, node: c };
                    queue.push(x);
                    return view(x);
                });
                queue.sort(cmpItem);
                lastInv = e.id;
                push('node', { node: e.id, leaf: e.leaf, from: it.d, entries: e.entries.map(ref), skipped, pushed, inv: e.id });
            }
            push('end', { reason: results.length === k ? 'done' : 'empty', inv: lastInv });
            return out;
        }

        /* 做法一：當成普通 R-tree，由近到遠一家一家拿出來，再看關鍵字對不對 */
        function nearestThenFilter(t, q, words, k) {
            let opened = 0, checked = 0, rejected = 0;
            const res = [];
            const queue = t.root ? [{ d: mindist(q, t.root.mbr), t: 0, id: t.root.id, node: t.root }] : [];
            const cmpItem = (a, b) => cmpTuple([a.d, a.t, a.id], [b.d, b.t, b.id]);
            while (queue.length && res.length < k) {
                queue.sort(cmpItem);
                const it = queue.shift();
                if (it.t === 1) { if (hasAll(shops[it.id].items, words)) res.push({ j: it.id, d: it.d }); else rejected++; continue; }
                opened++;
                it.node.entries.forEach(c => {
                    if (it.node.leaf) { checked++; queue.push({ d: dist2(q, c), t: 1, id: c }); }
                    else queue.push({ d: mindist(q, c.mbr), t: 0, id: c.id, node: c });
                });
            }
            return { res, opened, checked, rejected };
        }
        /* 做法二：先用整份倒排表找出關鍵字都有的店，再全部算距離、排序 */
        function filterThenSort(q, words, k) {
            const cand = shops.map((_, j) => j).filter(j => hasAll(shops[j].items, words));
            const res = cand.map(j => ({ j, d: dist2(q, j) })).sort((a, b) => cmpTuple([a.d, a.j], [b.d, b.j])).slice(0, k);
            return { res, cand: cand.length };
        }

        /* =================== 說明文字 =================== */
        const itemName = it => (it.t === 1 ? pn(it.id) : '框 ' + rn(it.id));
        const wq = () => qList().map(w => `${EMOJI[w]}${w}`).join('、');

        function describe(s) {
            const n = shops.length, H = tree.H;
            switch (s.kind) {
                case 'build': {
                    if (!n) return `地圖上沒有店家。按「隨機產生店家」或「恢復預設」吧。`;
                    const leaves = tree.nodes.filter(x => x.leaf).length;
                    return `先把 ${n} 家店建成 R-tree（這頁用 <b>STR 批次建樹</b>：依 x 排序切成幾條直的，每條再依 y 排序、每 M = ${capM} 家裝成一個葉子，上一層也照樣包），共 ${tree.total} 個節點、${leaves} 個葉子、${H + 1} 層。` +
                        `IR-tree 多做一件事：<b>每個節點記一份倒排表</b>，寫「哪個商品出現在哪些子節點底下」。葉子的倒排表從店家來，上一層把子節點的合起來，所以根的倒排表就是全地圖賣的東西。`;
                }
                case 'start':
                    if (s.fail) return `查詢點 <b>(${qPoint.x},${qPoint.y})</b>，要找同時有 ${wq()} 的店。先看根 ${rn(tree.root.id)} 的倒排表：<span class="no">根本沒有 ${s.fail.map(w => EMOJI[w] + w).join('、')}</span>，代表整張地圖沒有一家店賣，一個框都不用打開就知道沒有答案。`;
                    return `查詢點在 <b>(${qPoint.x},${qPoint.y})</b>（點地圖可以換位置），要找<b>同時有 ${wq()}</b> 的店裡最近的 <b>k = ${kNum}</b> 家。` +
                        `根 ${rn(tree.root.id)} 的倒排表裡這些商品都有，所以把根放進<b>優先佇列</b>。佇列跟 R-tree 的 kNN 一樣依距離排：框用 <b>MINDIST</b>（查詢點到框的最短距離），店家用真正的距離。`;
                case 'node': {
                    const nm = x => (s.leaf ? pn(x) : rn(x));
                    let t = `取出佇列最前面的 <b>${rn(s.node)}</b>（MINDIST ${dstr(s.from)}），打開它，先查它的倒排表：`;
                    t += qList().map(w => {
                        const node = tree.nodes[s.node];
                        const list = node.inv.get(w).map(i => (s.leaf ? '#' + (node.entries[i] + 1) : rn(node.entries[i].id)));
                        return `${EMOJI[w]} 在 ${list.join('、')}`;
                    }).join('；') + '。';
                    if (s.skipped.length) t += `<span class="no">${s.skipped.map(nm).join('、')} 缺商品，整個跳過</span>${s.leaf ? '（連距離都不用算）' : '（底下的店一家都不用看）'}；`;
                    else t += `${s.leaf ? '每家店' : '每個子框'}都有你要的商品；`;
                    if (s.pushed.length) t += `${s.leaf ? '商品都有的店算真正的距離' : '留下來的子框算 MINDIST'}，放進佇列：` + s.pushed.map(x => `${s.leaf ? pn(x.id) : rn(x.id)} ${dstr(x.d)}`).join('、') + '。';
                    return t;
                }
                case 'point':
                    return `佇列最前面是店家 <b>${pn(s.j)}</b>（${emo(shops[s.j].items)}，距離 ${dstr(s.d)}）。佇列是照距離排的，剩下的框裡任何一家都至少有 MINDIST 那麼遠，不會比它近；佇列裡也只放商品都有的店，所以它就是<span class="ok">第 ${s.rank} 近、商品都有的店 ✓</span>` +
                        (s.rank < kNum ? `，繼續找下一家。` : `，${kNum} 家都找齊了。`);
                case 'end': {
                    if (s.reason === 'none') return `地圖上沒有店家，沒有東西可以找。`;
                    if (s.reason === 'nokw') return `沒有答案：整張地圖沒有一家店同時賣 ${wq()}。打開 0 個節點就知道了，換幾個商品試試看。`;
                    const a = compare.nf, b = compare.fs;
                    const head = s.reason === 'done' ? `完成！最近的 ${kNum} 家是：` : !s.results.length ? `佇列空了：根的倒排表雖然每樣都有，但是分散在不同的店，<span class="no">沒有一家店同時有 ${wq()}</span>` : `佇列空了：同時有 ${wq()} 的店只有 ${s.results.length} 家，全部找出來了：`;
                    return head + s.results.map((r, i) => `${i + 1}. ${pn(r.j)}（${dstr(r.d)}）`).join('、') +
                        `。IR-tree 打開 <b>${s.st.opened}</b> 個節點、算了 <b>${s.st.checked}</b> 家的距離；只看距離的做法一要打開 ${a.opened} 個、算 ${a.checked} 家（其中 ${a.rejected} 家拿出來才發現缺貨）；只看商品的做法二要算 ${b.cand} 家。`;
                }
            }
            return '';
        }
        const TAGS = { build: ['build', 'inv'], start: ['qstart'], node: ['open', 'kw', 'push'], point: ['pop'], end: ['end'] };

        /* =================== 畫地圖 =================== */
        const PT = 2.1;
        const unitPx = svg => (svg.getBoundingClientRect().width || 500) / 142;
        const ring = (p, cls, r = 3.9) => `<circle class="ring ${cls}" cx="${p.x}" cy="${p.y}" r="${r}"/>`;
        function label(svg, p, text, cls = 'lbl') {
            const fs = 12 / unitPx(svg);
            const right = p.x > 92;
            const ty = p.y < 10 ? p.y + 5.5 + fs * 0.7 : p.y - 5;
            return `<text class="${cls}" x="${p.x + (right ? -4.5 : 4.5)}" y="${ty}" font-size="${fs.toFixed(2)}" text-anchor="${right ? 'end' : 'start'}">${text}</text>`;
        }
        function mapBase() {
            let h = '<rect class="bg" x="-7" y="-7" width="142" height="142"/>';
            for (let v = 16; v < WORLD; v += 16) h += `<line class="gridfaint" x1="${v}" y1="0" x2="${v}" y2="128"/><line class="gridfaint" x1="0" y1="${v}" x2="128" y2="${v}"/>`;
            return h + '<rect class="border" x="0" y="0" width="128" height="128"/>';
        }
        /* 框往外多留一點邊，越上層留越多，巢狀的框才看得出來；只有一個點的框也看得到 */
        function boxGeom(n) {
            const pad = 1.1 + (tree.H - tree.depth.get(n.id)) * 1.5;
            return [n.mbr[0] - pad, n.mbr[1] - pad, n.mbr[2] - n.mbr[0] + 2 * pad, n.mbr[3] - n.mbr[1] + 2 * pad];
        }
        const lvColor = n => LV_COLORS[(tree.H - tree.depth.get(n.id)) % LV_COLORS.length];
        function nodeState(s, id) {
            if (s.kind === 'node' && id === s.node) return 'cur';
            if (s.skipNodes.includes(id)) return 'skip';
            if (s.queue.some(x => x.t === 0 && x.id === id)) return 'queued';
            if (s.opened.includes(id)) return 'opened';
            return '';
        }
        function nearestOnRect(q, r) { return [Math.max(r[0], Math.min(q.x, r[2])), Math.max(r[1], Math.min(q.y, r[3]))]; }

        function drawMap(s) {
            const svg = $('ir-map');
            let h = mapBase(), boxes = '', labels = '';
            const fs = 10.5 / unitPx(svg);
            // 被跳過的框底下的框也一起變灰（整棵子樹都沒看）
            const skipAll = new Set();
            const mark = n => { skipAll.add(n.id); if (!n.leaf) n.entries.forEach(mark); };
            s.skipNodes.forEach(id => mark(tree.nodes[id]));
            tree.nodes.forEach(n => {
                const [x, y, w, hh] = boxGeom(n);
                const color = lvColor(n);
                const st = nodeState(s, n.id) || (skipAll.has(n.id) ? 'skip' : '');
                boxes += `<rect class="box ${st}" x="${x}" y="${y}" width="${w}" height="${hh}" rx="1.4" stroke="${color}" fill="${color}"/>`;
                labels += `<text class="blbl${st ? '' : ' dim'}" x="${x + 0.6}" y="${y - 0.7}" font-size="${fs.toFixed(2)}" fill="${color}">${rn(n.id)}</text>`;
            });
            h += boxes;
            let lines = '';
            if (s.kind === 'node') {
                s.pushed.forEach(x => {
                    const [tx, ty] = x.t === 1 ? [shops[x.id].x, shops[x.id].y] : nearestOnRect(qPoint, tree.nodes[x.id].mbr);
                    lines += `<line class="mdl" x1="${qPoint.x}" y1="${qPoint.y}" x2="${tx}" y2="${ty}"/>`;
                });
            }
            const resRank = new Map(s.results.map((r, i) => [r.j, i + 1]));
            const curLeaf = s.kind === 'node' && s.leaf ? new Set(s.entries) : null;
            let points = '', rings = '', plabels = '';
            shops.forEach((p, i) => {
                const match = hasAll(p.items, qWords);
                points += `<circle class="pt ${match ? 'match' : 'other'}" cx="${p.x}" cy="${p.y}" r="${PT}"><title>#${i + 1} ${emo(p.items)}</title></circle>`;
                if (resRank.has(i)) { rings += ring(p, 'hit', 4.2); plabels += label(svg, p, String(resRank.get(i))); }
                else if (curLeaf && curLeaf.has(i)) {
                    rings += ring(p, s.skipped.includes(i) ? 'miss' : 'cur', 4.2);
                    plabels += label(svg, p, emo(p.items), 'emo');
                }
            });
            if (s.kind === 'point') rings += ring(shops[s.j], 'cur', 5.4);
            const q = qPoint, c = 3.4;
            const qm = `<line class="qcross" x1="${q.x - c * 1.6}" y1="${q.y}" x2="${q.x + c * 1.6}" y2="${q.y}"/><line class="qcross" x1="${q.x}" y1="${q.y - c * 1.6}" x2="${q.x}" y2="${q.y + c * 1.6}"/><circle class="qpt" cx="${q.x}" cy="${q.y}" r="${c * 0.6}"/>`;
            svg.innerHTML = h + lines + points + rings + labels + qm + plabels;
        }

        /* =================== 樹的結構 =================== */
        const wordsHtml = ws => `<span class="wd">${ITEMS.filter(w => ws.has(w)).map(w => `<i class="${qWords.has(w) ? '' : 'off'}">${EMOJI[w]}</i>`).join('')}</span>`;
        function renderTree(s) {
            const box = $('ir-tree');
            if (!tree.root) { box.innerHTML = '<div class="empty">（沒有店家，樹是空的）</div>'; return; }
            const skipAll = new Set();
            const mark = n => { skipAll.add(n.id); if (!n.leaf) n.entries.forEach(mark); };
            s.skipNodes.forEach(id => mark(tree.nodes[id]));
            let html = '';
            for (let d = 0; d <= tree.H; d++) {
                const row = [];
                (function walk(n) { if (tree.depth.get(n.id) === d) row.push(n); else if (!n.leaf) n.entries.forEach(walk); })(tree.root);
                const tag = d === 0 ? '第 1 層（根）' : `第 ${d + 1} 層` + (d === tree.H ? '（葉子）' : '');
                html += `<div><div class="lv-tag">${tag}</div><div class="lv-row">` + row.map(n => {
                    const color = lvColor(n);
                    const st = nodeState(s, n.id) || (skipAll.has(n.id) ? 'skip' : '');
                    const inner = n.leaf
                        ? n.entries.map(j => `<span class="shop${hasAll(shops[j].items, qWords) ? ' match' : ''}">#${j + 1}${emo(shops[j].items)}</span>`).join('')
                        : `<span class="kids">→ ${n.entries.map(c => rn(c.id)).join(' ')}</span>`;
                    return `<span class="tnode ${st}" style="--lc:${color}"><span class="nm" style="color:${color}">${rn(n.id)}</span>${wordsHtml(n.words)}${inner}</span>`;
                }).join('') + `</div></div>`;
            }
            box.innerHTML = html;
        }

        /* =================== 倒排表 =================== */
        function renderInv(s) {
            const head = $('inv-head'), rows = $('inv-rows');
            if (s.inv === null || s.inv === undefined) { head.textContent = '還沒有節點。'; rows.innerHTML = ''; return; }
            const node = tree.nodes[s.inv];
            const nm = i => (node.leaf ? '#' + (node.entries[i] + 1) : rn(node.entries[i].id));
            const isCur = s.kind === 'node' && s.node === node.id;
            head.innerHTML = `<b>${rn(node.id)}</b> 的倒排表（${node.leaf ? '葉子：串列裡是店家' : '內部節點：串列裡是子節點'}）` +
                (s.kind === 'build' ? '' : isCur ? '：你要的商品取交集' : '：上一個打開的節點');
            let ok = node.entries.map((_, i) => i);
            qList().forEach(w => { const l = node.inv.get(w) || []; ok = ok.filter(i => l.includes(i)); });
            const okSet = new Set(ok);
            const showCut = s.kind !== 'build';
            let html = ITEMS.map(w => {
                const l = node.inv.get(w);
                const want = qWords.has(w);
                const cls = !showCut ? '' : want ? (l ? 'q' : 'miss') : 'dim';
                const ents = l ? l.map(i => `<span class="ent${showCut && want ? (okSet.has(i) ? ' hit' : ' out') : ''}">${nm(i)}</span>`).join('') : '<span class="ent none">（沒有）</span>';
                return `<div class="irow ${cls}"><span class="w">${EMOJI[w]} ${w}</span><span class="ents">${ents}</span></div>`;
            }).join('');
            if (showCut) {
                const all = node.entries.map((_, i) => i);
                html += `<div class="irow ans"><span class="w">交集 ${qEmo()}</span><span class="ents">${ok.length ? ok.map(i => `<span class="ent hit">${nm(i)}</span>`).join('') : '<span class="ent none">（沒有，整個節點都不用看）</span>'}${all.filter(i => !okSet.has(i)).map(i => `<span class="ent out">${nm(i)} 跳過</span>`).join('')}</span></div>`;
            }
            rows.innerHTML = html;
        }

        /* =================== 佇列 =================== */
        function itemHtml(it) {
            if (it.t === 1) return `<span class="it">#${it.id + 1}(${shops[it.id].x},${shops[it.id].y}) ${emo(shops[it.id].items)}</span>`;
            const node = tree.nodes[it.id];
            return `<span class="it"><span style="color:${lvColor(node)}">■</span>框 ${rn(it.id)}${node.leaf ? '<small style="color:var(--muted);font-weight:400">（葉子）</small>' : ''}</span>`;
        }
        function renderQueue(s) {
            const fresh = new Set((s.pushed || []).map(x => x.t + ':' + x.id));
            let q = s.queue.map((it, i) => {
                const isNew = fresh.has(it.t + ':' + it.id);
                return `<div class="qrow${i === 0 && s.kind !== 'end' ? ' first' : ''}"><span class="rk">${i + 1}</span>${itemHtml(it)}${isNew ? '<span class="tagv new">新加入</span>' : ''}<span class="ds"><small>${it.t ? '距離' : 'MINDIST'}</small> ${dstr(it.d)}</span></div>`;
            }).join('');
            if (s.kind === 'node') q += s.skipped.map(r => `<div class="qrow drop"><span class="rk">✗</span>${itemHtml({ t: s.leaf ? 1 : 0, id: r })}<span class="tagv drop">缺商品，不放進佇列</span></div>`).join('');
            $('ir-queue').innerHTML = q || `<div class="empty">（空的）</div>`;
            $('ir-res').innerHTML = s.results.length
                ? s.results.map((r, i) => `<div class="qrow res"><span class="rk">${i + 1}</span>${itemHtml({ t: 1, id: r.j })}<span class="tagv ok">第 ${i + 1} 近</span><span class="ds">${dstr(r.d)}</span></div>`).join('')
                : `<div class="empty">還沒有。店家要從佇列最前面取出來，才算確定。</div>`;
            $('st-open').innerHTML = `${s.st.opened}<small> / ${tree.total}</small>`;
            $('st-dist').innerHTML = `${s.st.checked}<small> / ${shops.length}</small>`;
            $('st-skip').textContent = s.st.skipped;
        }

        /* =================== 三種做法比一比（整個查詢的結果，不隨步驟變） =================== */
        function renderCompare() {
            const last = steps[steps.length - 1];
            const ir = last.st, a = compare.nf, b = compare.fs;
            const N = Math.max(1, tree.total), S = Math.max(1, shops.length);
            const bar = (lab, v, max, cls, txt) => `<div class="bar"><span>${lab}</span><div class="track"><div class="fill ${cls}" style="width:${(v / max * 100).toFixed(1)}%"></div></div><span class="n">${txt ?? v}</span></div>`;
            $('cmp-nodes').textContent = tree.total;
            $('cmp-shops').textContent = shops.length;
            $('cmp-open').innerHTML = bar('IR-tree', ir.opened, N, '') + bar('先找最近', a.opened, N, 'a') + bar('先查倒排表', 0, N, 'b', '不用樹');
            $('cmp-dist').innerHTML = bar('IR-tree', ir.checked, S, '') + bar('先找最近', a.checked, S, 'a') + bar('先查倒排表', b.cand, S, 'b');
            const same = JSON.stringify(a.res.map(r => r.j)) === JSON.stringify(last.results.map(r => r.j)) && JSON.stringify(b.res.map(r => r.j)) === JSON.stringify(last.results.map(r => r.j));
            $('cmp-note').innerHTML = `<b>先找最近</b>：當成普通 R-tree 由近到遠拿店家，拿出來才檢查商品，缺貨就丟掉再拿下一家（這次丟了 ${a.rejected} 家）。` +
                `<b>先查倒排表</b>：用全部店家的倒排表取交集，找出商品都有的 ${b.cand} 家，再一家一家算距離、排序。` +
                `三種做法的答案${same ? '<span style="color:#86efac">完全一樣</span>' : '不一樣（不該發生）'}，差別只在要做多少事。`;
        }

        /* =================== 程式碼 =================== */
        const KW = {
            java: new Set('public static final for if return new boolean int long void class import while else null this record instanceof continue break'.split(' ')),
            py: new Set('def for in if return not and or while import from as True False None class is lambda continue break else'.split(' '))
        };
        function highlight(line) {
            const esc = x => x.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
            const at = lang === 'java' ? line.indexOf('//') : line.indexOf('#');
            let body = line, comment = '';
            if (at >= 0) { body = line.slice(0, at); comment = line.slice(at); }
            if (lang === 'py' && /^\s*"""/.test(line)) { body = ''; comment = line; }
            if (lang === 'java' && /^\s*\/\*\*/.test(line)) { body = ''; comment = line; }
            const out = body.replace(/("(?:[^"\\]|\\.)*")|(\b\d+\b)|([A-Za-z_]\w*)(\s*\()?|([^"\w]+)/g, (m, str, numb, word, call) => {
                if (str) return `<span class="str">${esc(str)}</span>`;
                if (numb) return `<span class="num">${numb}</span>`;
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

        const FILES = { java: ['IRTree.java', 'javac IRTree.java && java IRTree'], py: ['ir_tree.py', 'python3 ir_tree.py'] };
        function renderCode(tags) {
            if (measuringBlocks || restoringBlocks) return;   // 量區塊高度時不用畫程式碼（程式碼框高度不會變），量完畫回來時它也沒被動過，省時間
            const pre = $('ir-code');
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
            $('ir-downloads').innerHTML = `下載 <a href="code/${file}" download>${file}</a>　執行 <code>${cmd}</code>`;
        }

        /* =================== 顯示某一步 =================== */
        function showStep() {
            const s = steps[cursor];
            $('ir-explain').innerHTML = `<span class="step-no">步驟 ${cursor + 1} / ${steps.length}</span>${describe(s)}`;
            drawMap(s);
            renderTree(s);
            renderInv(s);
            renderQueue(s);
            renderCode(TAGS[s.kind] || []);
            $('ir-prev').disabled = $('ir-first').disabled = cursor === 0;
            $('ir-next').disabled = $('ir-last').disabled = cursor === steps.length - 1;
            $('k-val').textContent = kNum;
            $('k-minus').disabled = kNum <= 1;
            $('k-plus').disabled = kNum >= 6;
            $('m-val').textContent = capM;
            $('m-minus').disabled = capM <= 3;
            $('m-plus').disabled = capM >= 6;
        }

        /* 一步一步播放時，各區塊的內容會變多變少（清單變長…）。
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
            const box = $('ir-explain');
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
            reserveBlockHeights($('panel'), steps.length, i => { cursor = i; showStep(); }, () => cursor);
        }

        /* =================== 資料或參數改變：重算 trace =================== */
        function rebuild(keepTree) {
            if (!keepTree) tree = buildTree(shops, capM);
            steps = irTrace(tree, qPoint, qWords, kNum);
            compare = { nf: nearestThenFilter(tree, qPoint, qWords, kNum), fs: filterThenSort(qPoint, qWords, kNum) };
        }
        function changed(keepTree, at = 0) {
            stopAuto();
            rebuild(keepTree);
            cursor = at === 'last' ? steps.length - 1 : at;
            renderKw();
            renderCompare();
            $('ir-count').textContent = `${shops.length} 家店，查詢點 (${qPoint.x},${qPoint.y})`;
            showStep();
            reserveExplainHeight();
        }

        /* =================== 關鍵字、地圖點擊 =================== */
        function renderKw() {
            $('kw-box').innerHTML = `<span class="lab">要買：</span>` + ITEMS.map(w =>
                `<button class="kind${qWords.has(w) ? ' sel' : ''}" data-w="${w}" aria-pressed="${qWords.has(w)}"><span class="em">${EMOJI[w]}</span><span>${w}</span><span class="cnt">${shops.filter(p => p.items.has(w)).length}</span></button>`).join('');
        }
        $('kw-box').addEventListener('click', e => {
            const b = e.target.closest('[data-w]');
            if (!b) return;
            const w = b.dataset.w;
            if (qWords.has(w)) {
                if (qWords.size === 1) { setHint('至少要選一樣商品。', true); return; }
                qWords.delete(w);
            } else qWords.add(w);
            changed(true);
            setHint(`現在要找同時有 ${wq()} 的店。按「下一步」看怎麼找。`);
        });

        function setHint(text, warn) {
            const el = $('ir-hint');
            el.textContent = text;
            el.classList.toggle('warn', !!warn);
        }
        const DEFAULT_HINT = '點地圖任何地方，把查詢點搬過去；上面勾選要買的商品（每一樣都要有）。地圖上青色的店是商品都有的，灰色的缺東西。';

        function randomShops() {
            const rnd = (a, b) => a + Math.floor(Math.random() * (b - a + 1));
            const pick = (arr, n) => { const a = arr.slice(); const out = []; while (out.length < n && a.length) out.push(a.splice(rnd(0, a.length - 1), 1)[0]); return out; };
            const out = [], seen = new Set();
            // 幾個商圈：每個商圈主要賣某幾樣東西（像早餐店區、便利商店區），附近的店才會比較像
            const centers = Array.from({ length: rnd(4, 7) }, () => ({ x: rnd(14, 114), y: rnd(14, 114), theme: pick(ITEMS, rnd(2, 3)) }));
            const n = rnd(24, 40);
            let guard = 0;
            while (out.length < n && guard++ < 2000) {
                const c = centers[rnd(0, centers.length - 1)];
                let x = c.x + rnd(-18, 18), y = c.y + rnd(-18, 18);
                x = Math.max(2, Math.min(125, x)); y = Math.max(2, Math.min(125, y));
                if (seen.has(x + ',' + y)) continue;
                seen.add(x + ',' + y);
                const items = new Set(pick(c.theme, rnd(1, c.theme.length)));
                if (Math.random() < 0.2) items.add(ITEMS[rnd(0, ITEMS.length - 1)]);
                out.push({ x, y, items });
            }
            return out;
        }
        $('ir-tools').addEventListener('click', e => {
            const act = e.target.closest('[data-act]');
            if (!act) return;
            if (act.dataset.act === 'random') { shops = randomShops(); setHint(`隨機產生了 ${shops.length} 家店，樹重新建好了。`); }
            if (act.dataset.act === 'reset') {
                shops = defaultShops(); qPoint = { x: DATA.q[0], y: DATA.q[1] }; qWords = new Set(DATA.words); kNum = DATA.k; capM = 4;
                setHint(DEFAULT_HINT);
            }
            changed(false);
        });

        function toWorld(svg, e) {
            const pt = svg.createSVGPoint();
            pt.x = e.clientX; pt.y = e.clientY;
            return pt.matrixTransform(svg.getScreenCTM().inverse());
        }
        const clampW = v => Math.max(0, Math.min(WORLD - 1, Math.round(v)));
        (() => {
            const svg = $('ir-map');
            let start = null;
            svg.addEventListener('pointerdown', e => { if (e.button !== undefined && e.button !== 0) return; start = { x: e.clientX, y: e.clientY }; });
            svg.addEventListener('pointerup', e => {
                if (!start) return;
                const moved = Math.hypot(e.clientX - start.x, e.clientY - start.y);
                start = null;
                if (moved >= 8) return;
                const w = toWorld(svg, e);
                if (w.x < -2 || w.y < -2 || w.x > WORLD + 1 || w.y > WORLD + 1) return;
                qPoint = { x: clampW(w.x), y: clampW(w.y) };
                changed(true);
                setHint(`查詢點搬到 (${qPoint.x},${qPoint.y})。按「下一步」看怎麼找。`);
            });
            svg.addEventListener('pointercancel', () => { start = null; });
        })();

        /* =================== 播放控制 =================== */
        function go(dir) {
            const next = cursor + dir;
            if (next < 0 || next >= steps.length) return false;
            cursor = next;
            showStep();
            return cursor < steps.length - 1;
        }
        function stopAuto() {
            clearInterval(timer);
            timer = null;
            $('ir-play').textContent = '▶ 自動播放';
        }
        $('ir-next').addEventListener('click', () => { stopAuto(); go(1); });
        $('ir-prev').addEventListener('click', () => { stopAuto(); go(-1); });
        $('ir-first').addEventListener('click', () => { stopAuto(); cursor = 0; showStep(); });
        $('ir-last').addEventListener('click', () => { stopAuto(); cursor = steps.length - 1; showStep(); });
        $('ir-play').addEventListener('click', () => {
            if (timer) { stopAuto(); return; }
            if (cursor === steps.length - 1) { cursor = 0; showStep(); }
            $('ir-play').textContent = '⏸ 暫停';
            timer = setInterval(() => { if (!go(1)) stopAuto(); }, 1800);
        });
        document.addEventListener('keydown', e => {
            if (e.target.closest && e.target.closest('input, textarea, select')) return;
            if (e.key === 'ArrowRight') { stopAuto(); go(1); }
            if (e.key === 'ArrowLeft') { stopAuto(); go(-1); }
        });

        $('k-minus').addEventListener('click', () => { if (kNum > 1) { kNum--; changed(true); } });
        $('k-plus').addEventListener('click', () => { if (kNum < 6) { kNum++; changed(true); } });
        $('m-minus').addEventListener('click', () => { if (capM > 3) { capM--; changed(false); } });
        $('m-plus').addEventListener('click', () => { if (capM < 6) { capM++; changed(false); } });

        document.querySelectorAll('.lang').forEach(box => box.addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b) return;
            lang = b.dataset.lang;
            document.querySelectorAll('.lang button').forEach(x => x.classList.toggle('active', x.dataset.lang === lang));
            showStep();
        }));

        let resizeTimer = null;
        window.addEventListener('resize', () => {
            clearTimeout(resizeTimer);
            resizeTimer = setTimeout(() => { showStep(); reserveExplainHeight(); }, 150);
        });

        setHint(DEFAULT_HINT);
        changed(false);
    </script>
</body>

</html>
