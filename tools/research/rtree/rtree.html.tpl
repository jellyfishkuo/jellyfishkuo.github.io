<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/rtree.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/rtree-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/rtree-180.png">
    <title>R-tree 與 kNN 查詢</title>
    <meta name="description" content="在街區地圖上一步一步看 R-tree 怎麼一個點一個點插入、用 Quadratic Split 分裂節點、長出巢狀的 MBR 框，再用 best-first search 依 MINDIST 找出離你最近的 k 個點，Java 與 Python 程式碼逐行對照。">
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

        /* ── R-tree 的框 ── */
        .map .box { fill-opacity: 0.045; stroke-width: 1.3; }
        .map .box.path { stroke: var(--warn) !important; stroke-width: 2.6; }
        .map .box.grown { fill: var(--warn) !important; fill-opacity: 0.14; }
        .map .box.split { stroke: var(--warn) !important; stroke-width: 2.6; stroke-dasharray: 6 4; }
        .map .box.g1 { stroke: #fb923c !important; stroke-width: 2.8; fill: #fb923c !important; fill-opacity: 0.1; }
        .map .box.g2 { stroke: #22d3ee !important; stroke-width: 2.8; fill: #22d3ee !important; fill-opacity: 0.1; stroke-dasharray: 6 3; }
        .map .box.opened { fill-opacity: 0.1; }
        .map .box.queued { stroke: var(--accent2) !important; stroke-width: 2; stroke-dasharray: 5 3; }
        .map .box.pruned { fill: #78789a !important; fill-opacity: 0.3; stroke: #78789a !important; stroke-dasharray: 2 3; }
        .map .box.cur { stroke: var(--warn) !important; stroke-width: 3; fill: var(--warn) !important; fill-opacity: 0.12; }
        .map .blbl { paint-order: stroke; stroke: #05050a; stroke-width: 2.5px; stroke-linejoin: round; font-family: 'Space Mono', ui-monospace, monospace; font-weight: 700; }
        .map .blbl.dim { opacity: 0.5; }
        .map .ring.g1 { stroke: #fb923c; }
        .map .ring.g2 { stroke: #22d3ee; }
        .map .mdl { stroke: var(--accent2); stroke-width: 1.4; stroke-dasharray: 3 2; }
        .map .mdl.far { stroke: var(--bad); }
        .map .dk { fill: rgba(34, 197, 94, 0.05); stroke: var(--good); stroke-width: 1.6; stroke-dasharray: 5 4; }
        .map .qpt { fill: #fff; stroke: #05050a; stroke-width: 1.5; }
        .map .qcross { stroke: #fff; stroke-width: 1.6; }

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
        .tnode .ptk { display: inline-flex; gap: 2px; }
        .tnode .ptk svg { width: 11px; height: 11px; display: block; }
        .tnode.path { border-color: var(--warn); box-shadow: 0 0 0 1px var(--warn) inset; }
        .tnode.grown { background: rgba(245, 158, 11, 0.14); }
        .tnode.g1 { border-color: #fb923c; box-shadow: 0 0 0 1px #fb923c inset; }
        .tnode.g2 { border-color: #22d3ee; box-shadow: 0 0 0 1px #22d3ee inset; }
        .tnode.over { border-color: var(--warn); box-shadow: 0 0 0 1px var(--warn) inset; border-style: dashed; }
        .tnote { color: var(--muted); font-size: 0.75rem; margin-top: 0.6rem; }

        /* ── 優先佇列 ── */
        .dkline { font-size: 0.85rem; color: #c6c6d6; margin-bottom: 0.6rem; }
        .dkline b { font: 700 0.9rem 'Space Mono', monospace; color: var(--good); }
        .qlist { display: grid; gap: 0.25rem; }
        .qrow { display: flex; align-items: center; gap: 0.5rem; padding: 0.25rem 0.5rem; border-radius: 8px; border: 1px solid var(--border); background: var(--panel-2); font-size: 0.8rem; }
        .qrow .rk { font: 700 0.72rem 'Space Mono', monospace; color: var(--muted); min-width: 1.6em; }
        .qrow .it { display: inline-flex; align-items: center; gap: 0.3rem; font-weight: 600; min-width: 0; }
        .qrow .it svg { width: 12px; height: 12px; flex: none; }
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
    </style>
</head>

<body>
    <div class="wrap">
        <a class="back" href="../index.html#research">← RETURN TO PORTFOLIO</a>
        <div class="kicker">RESEARCH DEMO · SPATIAL INDEX</div>
        <h1>R-tree 與 kNN 查詢<small>用剛好包住資料的框建索引，再一路找出離你最近的 k 家店</small></h1>
        <p class="intro">
            <a href="spatial.html">上一頁的四元樹</a>是<b>依空間切</b>：不管點在哪，一律從中線切成四塊。R-tree 反過來<b>依資料包框</b>：把靠得近的點放進同一個節點，用「剛好包住它們的最小長方形」（MBR）代表這一群，框跟框可以重疊、也不用蓋滿整張地圖。
            資料庫（例如 PostGIS、SQLite 的 R*Tree 模組）存地圖資料時，最常用的就是這一類索引。
            分頁一看點一個一個插進去時，框怎麼擴大、節點滿了怎麼<b>分裂</b>；分頁二用建好的樹回答「<b>離我最近的 k 家店是哪幾家？</b>」，看優先佇列怎麼讓大部分的框連打開都不用。
        </p>

        <div class="tabs" role="tablist">
            <button role="tab" id="tab-rt" data-tab="rt" class="active" aria-selected="true"><span class="no">01</span>R-tree 建樹</button>
            <button role="tab" id="tab-kn" data-tab="kn" aria-selected="false"><span class="no">02</span>kNN 查詢</button>
        </div>

        <!-- ===================== 分頁一：建樹 ===================== -->
        <section id="panel-rt" role="tabpanel" aria-labelledby="tab-rt">
            <div class="layout">
                <div>
                    <div class="card">
                        <div class="card-head"><h2>一步一步看</h2></div>
                        <div class="player">
                            <button class="btn" id="rt-first" title="回到開頭">⏮</button>
                            <button class="btn" id="rt-prev">◀ 上一步</button>
                            <button class="btn primary" id="rt-next">下一步 ▶</button>
                            <button class="btn" id="rt-play">▶ 自動播放</button>
                            <button class="btn" id="rt-last">⏭ 一次插入全部</button>
                        </div>
                        <div class="params">
                            <div class="param">
                                <span>節點容量 M</span>
                                <button class="btn stepper" id="cap-minus" aria-label="減少">−</button>
                                <span class="val" id="cap-val">4</span>
                                <button class="btn stepper" id="cap-plus" aria-label="增加">+</button>
                                <span class="unit" id="cap-unit">超過就分裂；分裂後至少 m = 2 個</span>
                            </div>
                        </div>
                        <div class="explain" id="rt-explain"></div>
                    </div>

                    <div class="card">
                        <div class="card-head"><h2>街區地圖</h2><span class="unit" id="rt-count" style="color:var(--muted);font-size:0.8rem"></span></div>
                        <div class="map-box"><svg class="map" id="rt-map" viewBox="-7 -7 142 142" role="img" aria-label="地圖與 R-tree 的框"></svg></div>
                        <div class="map-tools" id="rt-tools"></div>
                        <div class="hint" id="rt-hint"></div>
                        <div class="legend">
                            <span><i style="border-color:var(--warn)"></i>這一步走過的框</span>
                            <span><i style="border-color:var(--warn);background:rgba(245,158,11,0.3)"></i>跟著擴大的框</span>
                            <span><i style="border-color:#fb923c"></i>分裂：第 1 組</span>
                            <span><i style="border-color:#22d3ee;border-style:dashed"></i>分裂：第 2 組</span>
                            <span><i style="border-color:#8a8aa3;border-radius:50%"></i>空心：還沒插入</span>
                        </div>
                    </div>
                </div>

                <div>
                    <div class="card">
                        <h2>樹的結構</h2>
                        <div class="stats">
                            <div class="stat"><div class="v" id="st-nodes">0</div><div class="k">節點數</div></div>
                            <div class="stat"><div class="v" id="st-height">0</div><div class="k">樹高（幾層）</div></div>
                            <div class="stat"><div class="v" id="st-ins">0</div><div class="k">已插入的點</div></div>
                        </div>
                        <div class="sub">每一層由左到右是節點裡的順序；葉子裡的小圖示是它放的點</div>
                        <div class="levels" id="rt-tree"></div>
                    </div>

                    <div class="card">
                        <div class="card-head">
                            <h2>程式碼</h2>
                            <div class="lang">
                                <button data-lang="java" class="active">Java</button>
                                <button data-lang="py">Python</button>
                            </div>
                        </div>
                        <pre class="code" id="rt-code"></pre>
                        <div class="downloads" id="rt-downloads"></div>
                    </div>
                </div>
            </div>

            <div class="notes">
                <div class="card">
                    <h2>R-tree 一直維持的三件事</h2>
                    <ul>
                        <li><b>框一定包得住：</b>每個節點的框剛好包住底下所有的點。插入時沿路的框只會擴大，所以從根往下看，「點不在這個框裡」就代表整棵子樹都不用看。</li>
                        <li><b>每個節點不多不少：</b>最多 M 個；分裂時兩組都至少 m 個（這頁取 m = ⌊M/2⌋），所以每一頁磁碟空間至少用掉一半。只有根可以少於 m（但內部的根至少 2 個）。</li>
                        <li><b>所有葉子在同一層：</b>R-tree 跟 B+ tree 一樣只會從<b>根</b>長高——分裂一路傳到根時才長出新的根，所以每次查詢走的路一樣長。</li>
                    </ul>
                    <p style="margin-top:0.5rem"><b>為什麼選「擴大最少」？</b>框越大、跟別的框重疊越多，查詢時就越常兩邊都要看。ChooseLeaf 和分裂都在想辦法讓框小一點。
                        Quadratic Split 先挑「放在一起最浪費」的一對拆開當種子，再讓偏好最明顯的先選邊；它不保證最好（試試看預設資料會出現一個又扁又長的框），R*-tree 等改良版就是在這裡下功夫。</p>
                </div>
                <div class="card">
                    <h2>四元樹 vs. R-tree</h2>
                    <ul>
                        <li><b>怎麼分：</b>四元樹依<b>空間</b>切，切線固定在中點，格子不重疊、蓋滿整張地圖；R-tree 依<b>資料</b>包框，框可以重疊，空曠的地方完全沒有框。</li>
                        <li><b>樹的形狀：</b>四元樹點擠在一起時會切得很深，各處深度不同；R-tree 永遠平衡，每個節點也剛好裝滿一頁，很適合放在磁碟上的資料庫。</li>
                        <li><b>代價：</b>四元樹插入時路是唯一的；R-tree 要選、要分裂，而且框重疊時查詢可能兩條路都得走。資料常常變動、或點很平均時，四元樹或網格反而簡單好用。</li>
                        <li><b>不只放點：</b>R-tree 的框也能包住道路、行政區這種有面積的東西；四元樹放這類資料就麻煩得多。</li>
                    </ul>
                </div>
            </div>
        </section>

        <!-- ===================== 分頁二：kNN ===================== -->
        <section id="panel-kn" role="tabpanel" aria-labelledby="tab-kn" hidden>
            <div class="layout">
                <div>
                    <div class="card">
                        <div class="card-head"><h2>一步一步看</h2></div>
                        <div class="player">
                            <button class="btn" id="kn-first" title="回到開頭">⏮</button>
                            <button class="btn" id="kn-prev">◀ 上一步</button>
                            <button class="btn primary" id="kn-next">下一步 ▶</button>
                            <button class="btn" id="kn-play">▶ 自動播放</button>
                            <button class="btn" id="kn-last">⏭ 直接看結果</button>
                        </div>
                        <div class="params">
                            <div class="param">
                                <span>找最近的 k =</span>
                                <button class="btn stepper" id="k-minus" aria-label="減少">−</button>
                                <span class="val" id="k-val">3</span>
                                <button class="btn stepper" id="k-plus" aria-label="增加">+</button>
                                <span class="unit">個點</span>
                            </div>
                        </div>
                        <div class="explain" id="kn-explain"></div>
                    </div>

                    <div class="card">
                        <div class="card-head"><h2>街區地圖</h2><span class="unit" id="kn-count" style="color:var(--muted);font-size:0.8rem"></span></div>
                        <div class="map-box"><svg class="map" id="kn-map" viewBox="-7 -7 142 142" role="img" aria-label="地圖、查詢點與 R-tree 的框"></svg></div>
                        <div class="hint" id="kn-hint"></div>
                        <div class="legend">
                            <span><i style="border-color:#fff;border-radius:50%;background:#fff"></i>查詢點</span>
                            <span><i style="border-color:var(--warn);background:rgba(245,158,11,0.3)"></i>正在打開的框</span>
                            <span><i style="border-color:var(--accent2);border-style:dashed"></i>在佇列裡的框</span>
                            <span><i style="border-color:#78789a;background:rgba(120,120,154,0.5)"></i>剪掉的框</span>
                            <span><i style="border-color:var(--good);border-radius:50%;border-style:dashed"></i>第 k 近的距離</span>
                            <span><i style="border-color:var(--good);border-radius:50%"></i>找到的點</span>
                        </div>
                    </div>
                </div>

                <div>
                    <div class="card">
                        <h2>優先佇列與答案</h2>
                        <div class="stats">
                            <div class="stat"><div class="v" id="st-open">0</div><div class="k">打開的框</div></div>
                            <div class="stat"><div class="v" id="st-dist">0</div><div class="k">算過距離的點</div></div>
                            <div class="stat"><div class="v" id="st-prune">0</div><div class="k">剪掉的項目</div></div>
                        </div>
                        <div class="sub">佇列（由近到遠，下一個取出最上面那個）</div>
                        <div class="dkline" id="kn-dk"></div>
                        <div class="qlist" id="kn-queue"></div>
                        <div class="sub">已經確定的答案</div>
                        <div class="qlist" id="kn-res"></div>
                    </div>

                    <div class="card">
                        <div class="card-head">
                            <h2>程式碼</h2>
                            <div class="lang">
                                <button data-lang="java" class="active">Java</button>
                                <button data-lang="py">Python</button>
                            </div>
                        </div>
                        <pre class="code" id="kn-code"></pre>
                        <div class="downloads" id="kn-downloads"></div>
                    </div>
                </div>
            </div>

            <div class="notes">
                <div class="card">
                    <h2>為什麼取出來的點一定是答案？</h2>
                    <p>框的 <b>MINDIST</b> 是查詢點到框的最短距離，框裡任何一個點都不可能比它更近。佇列永遠依距離由小到大取：輪到某個點時，佇列裡剩下的框 MINDIST 都比它大（或一樣），框裡的點只會更遠，所以這個點就是「還沒找到的裡面最近的」。這就是 Hjaltason 與 Samet 的 <b>best-first search</b>。</p>
                    <p style="margin-top:0.5rem"><b>剪枝：</b>打開葉子時會算到真正的點，一旦湊滿 k 個，就知道「第 k 近的距離最多是多少」（地圖上的綠色虛線圈）。MINDIST 比這個還大的框，裡面的點連第 k 名都排不上，整個框直接跳過；佇列裡原本排著的太遠的東西也一起丟掉，佇列才不會越長越大。</p>
                    <p style="margin-top:0.5rem"><b>一樣遠怎麼辦？</b>這頁規定距離一樣時，<b>先插入的點排前面</b>，結果跟「全部算距離再排序」的暴力法一模一樣。所以剛好<b>等於</b>第 k 近距離的框不能丟（裡面可能有一樣近、但比較早插入的點）；佇列裡距離一樣時也是框排在點前面，先打開來確認。</p>
                </div>
                <div class="card">
                    <h2>跟四元樹的範圍查詢比，以及延伸</h2>
                    <ul>
                        <li><b>範圍查詢 vs. kNN：</b><a href="spatial.html">四元樹那頁</a>的範圍查詢事先知道框多大；kNN 不知道答案在多遠，所以要邊找邊縮小「第 k 近的距離」。這套 best-first 的做法放到四元樹上也能用，只是把 MINDIST 改成到格子的距離。</li>
                        <li><b>打開的框越少越好：</b>框重疊越少、越方正，MINDIST 越接近真正的距離，就越早剪得掉。這也是為什麼建樹時要盡量讓框「擴大最少」。</li>
                        <li><b>空間關鍵字查詢：</b>真正的需求常常是「離我最近、而且有賣珍奶的 3 家店」。做法之一是在 R-tree 每個節點多記這個框裡有哪些關鍵字（IR-tree），關鍵字對不上的框跟太遠的框一樣整個跳過。</li>
                        <li><b>移動中的查詢：</b>使用者一邊走、答案一邊變（連續 kNN），或資料一直新增刪除，都是空間資料庫研究在處理的問題，跟實驗室做的增量、串流資料是同一種思路：<b>不要每次都從頭算</b>。</li>
                    </ul>
                </div>
            </div>
        </section>
    </div>

    <script>
        /* =========================================================
           R-tree 與 kNN 一步一步看
           網頁裡用 JavaScript 照著同樣的演算法跑一次，把每一步記下來；
           上一步／下一步只是在這些紀錄之間移動。右邊的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = /*CODE_JSON*/null;

        const WORLD = 128;
        const MAX_POINTS = 60;
        const KINDS = ['超商', '公車站', '咖啡店', '飲料店'];
        const KIND_INFO = {
            '超商': { emo: '🏪', color: '#60a5fa', shape: 'circle' },
            '公車站': { emo: '🚏', color: '#f472b6', shape: 'square' },
            '咖啡店': { emo: '☕', color: '#d6a46c', shape: 'triangle' },
            '飲料店': { emo: '🧋', color: '#a78bfa', shape: 'diamond' }
        };
        const DEFAULT_POINTS = [
            [26, 54, '超商'], [38, 36, '超商'], [54, 74, '超商'], [84, 56, '超商'],
            [108, 76, '超商'], [60, 114, '超商'], [12, 96, '超商'], [90, 26, '超商'],
            [20, 60, '公車站'], [44, 30, '公車站'], [48, 68, '公車站'], [78, 62, '公車站'],
            [102, 68, '公車站'], [96, 22, '公車站'], [44, 102, '公車站'], [100, 106, '公車站'],
            [84, 14, '咖啡店'], [110, 36, '咖啡店'], [118, 12, '咖啡店'], [70, 40, '咖啡店'],
            [60, 62, '咖啡店'], [22, 104, '咖啡店'], [72, 110, '咖啡店'],
            [88, 42, '飲料店'], [112, 22, '飲料店'], [74, 30, '飲料店'], [26, 70, '飲料店'],
            [110, 62, '飲料店'], [40, 42, '飲料店'], [16, 18, '飲料店'], [62, 64, '飲料店']
        ];
        const DEFAULT_Q = { x: 70, y: 50 };
        /* 框的顏色：依「離葉子幾層」決定，葉子的框永遠是同一個顏色 */
        const LV_COLORS = ['#2dd4bf', '#818cf8', '#e879f9', '#fbbf24', '#fb7185', '#a3e635'];

        const $ = id => document.getElementById(id);
        let pts = DEFAULT_POINTS.map(([x, y, kind]) => ({ x, y, kind }));
        let capM = 4;
        let kNum = 3;
        let qPoint = { ...DEFAULT_Q };
        let newKind = '超商';
        let activeTab = 'rt';
        let lang = 'java';

        let rtBuild = null;                  // { steps, root, M, m }
        let knSteps = [];
        const cursors = { rt: 0, kn: 0 };
        const timers = { rt: null, kn: null };

        const pn = j => `${pts[j].kind}(${pts[j].x},${pts[j].y})`;
        const rn = id => 'R' + id;
        const dstr = d2 => Math.sqrt(d2).toFixed(1);

        /* =================== 幾何 =================== */
        const union = (a, b) => [Math.min(a[0], b[0]), Math.min(a[1], b[1]), Math.max(a[2], b[2]), Math.max(a[3], b[3])];
        const area = r => (r[2] - r[0]) * (r[3] - r[1]);
        const enlarge = (r, s) => area(union(r, s)) - area(r);
        const sameRect = (a, b) => (!a && !b) || (a && b && a.every((v, i) => v === b[i]));
        function mindist(q, r) {
            const dx = Math.max(r[0] - q.x, 0, q.x - r[2]), dy = Math.max(r[1] - q.y, 0, q.y - r[3]);
            return dx * dx + dy * dy;
        }
        function cmpTuple(a, b) {                       // 跟 Python 的 tuple 比大小一樣
            for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return a[i] < b[i] ? -1 : 1;
            return 0;
        }

        /* =================== R-tree：照著程式跑一次 =================== */
        function rtBuildTrace(points, M) {
            const m = Math.floor(M / 2);
            let nextId = 0;
            const mk = leaf => ({ id: nextId++, leaf, entries: [], mbr: null });
            let root = mk(true);
            const rectOf = e => (typeof e === 'number' ? [points[e].x, points[e].y, points[e].x, points[e].y] : e.mbr);
            const bound = es => es.map(rectOf).reduce(union);
            const ref = e => (typeof e === 'number' ? { p: e } : { n: e.id });
            const steps = [];
            let inserted = 0;
            function snap() {
                const out = [];
                (function walk(n, d) {
                    out.push({ id: n.id, leaf: n.leaf, depth: d, mbr: n.mbr && n.mbr.slice(), kids: n.leaf ? n.entries.slice() : n.entries.map(c => c.id) });
                    if (!n.leaf) n.entries.forEach(c => walk(c, d + 1));
                })(root, 0);
                return out;
            }
            const push = (kind, extra = {}) => steps.push({ kind, nodes: snap(), rootId: root.id, inserted, ...extra });
            push('b-start');

            points.forEach((p, pi) => {
                const r = [p.x, p.y, p.x, p.y];
                const path = [root], levels = [];
                while (!path[path.length - 1].leaf) {            // ChooseLeaf
                    const node = path[path.length - 1];
                    let best = null;
                    const cands = node.entries.map(c => {
                        const key = [enlarge(c.mbr, r), area(c.mbr)];
                        if (!best || cmpTuple(key, best.key) < 0) best = { key, c };
                        return { id: c.id, enl: key[0], area: key[1] };
                    });
                    levels.push({ node: node.id, cands, pick: best.c.id });
                    path.push(best.c);
                }
                const before = new Map(path.map(n => [n.id, n.mbr && n.mbr.slice()]));
                const leaf = path[path.length - 1];
                leaf.entries.push(pi);
                inserted = pi + 1;
                for (let i = path.length - 1; i >= 0; i--) path[i].mbr = bound(path[i].entries);
                const grown = path.filter(n => !sameRect(before.get(n.id), n.mbr)).map(n => n.id);
                push('b-insert', { pi, levels, path: path.map(n => n.id), leaf: leaf.id, grown, overflow: leaf.entries.length > M, fresh: before.get(leaf.id) === null });

                for (let i = path.length - 1; i >= 0; i--) {     // 由下往上：太滿就分裂
                    const n = path[i];
                    if (n.entries.length <= M) break;
                    const E = n.entries.slice();
                    let seeds = null;
                    for (let a = 0; a < E.length; a++) {
                        for (let b = a + 1; b < E.length; b++) {
                            const ra = rectOf(E[a]), rb = rectOf(E[b]);
                            const waste = area(union(ra, rb)) - area(ra) - area(rb);
                            if (!seeds || waste > seeds.waste) seeds = { waste, a, b };
                        }
                    }
                    push('b-seeds', { pi, node: n.id, leafNode: n.leaf, count: E.length, a: ref(E[seeds.a]), b: ref(E[seeds.b]), waste: seeds.waste });

                    const g1 = [E[seeds.a]], g2 = [E[seeds.b]];
                    let b1 = rectOf(E[seeds.a]), b2 = rectOf(E[seeds.b]);
                    const rest = E.filter((_, t) => t !== seeds.a && t !== seeds.b);
                    const order = [];
                    while (rest.length) {
                        if (g1.length + rest.length === m) { rest.forEach(e => order.push({ e: ref(e), g: 1, forced: true })); g1.push(...rest); break; }
                        if (g2.length + rest.length === m) { rest.forEach(e => order.push({ e: ref(e), g: 2, forced: true })); g2.push(...rest); break; }
                        let pick = null;
                        rest.forEach((e, t) => {
                            const d1 = enlarge(b1, rectOf(e)), d2 = enlarge(b2, rectOf(e));
                            if (!pick || Math.abs(d1 - d2) > pick.diff) pick = { diff: Math.abs(d1 - d2), t, d1, d2 };
                        });
                        const e = rest.splice(pick.t, 1)[0];
                        const toFirst = cmpTuple([pick.d1, area(b1), g1.length], [pick.d2, area(b2), g2.length]) <= 0;
                        if (toFirst) { g1.push(e); b1 = union(b1, rectOf(e)); } else { g2.push(e); b2 = union(b2, rectOf(e)); }
                        order.push({ e: ref(e), g: toFirst ? 1 : 2, d1: pick.d1, d2: pick.d2 });
                    }
                    n.entries = g1;
                    const nn = mk(n.leaf);
                    nn.entries = g2;
                    n.mbr = bound(g1); nn.mbr = bound(g2);
                    let newRoot = null;
                    if (i > 0) path[i - 1].entries.push(nn);
                    else { const old = root; root = mk(false); root.entries = [old, nn]; root.mbr = bound(root.entries); newRoot = root.id; }
                    for (let k = i - 1; k >= 0; k--) path[k].mbr = bound(path[k].entries);
                    push('b-split', {
                        pi, node: n.id, newId: nn.id, leafNode: n.leaf, g1: g1.map(ref), g2: g2.map(ref), order, newRoot,
                        parentId: i > 0 ? path[i - 1].id : null, parentFull: i > 0 && path[i - 1].entries.length > M
                    });
                }
            });
            push('b-end');
            return { steps, root, M, m, total: nextId };
        }

        /* =================== kNN：best-first search =================== */
        function knnTrace(root, points, q, k) {
            const steps = [];
            const st = { opened: 0, checked: 0, pruned: 0 };
            const cmpItem = (a, b) => cmpTuple([a.d, a.t, a.id], [b.d, b.t, b.id]);
            let queue = [];
            const results = [], best = [], openedIds = [], prunedIds = [], checkedPts = [];
            const view = it => ({ d: it.d, t: it.t, id: it.id });
            const push = (kind, extra = {}) => steps.push({
                kind, ...extra, st: { ...st }, queue: queue.map(view), results: results.slice(),
                opened: openedIds.slice(), prunedIds: prunedIds.slice(), checkedPts: checkedPts.slice(),
                dk: best.length === k ? best[k - 1] : null
            });
            if (!root.mbr || k <= 0) { push('k-start', { empty: true }); push('k-end', { reason: 'none' }); return steps; }
            queue.push({ d: mindist(q, root.mbr), t: 0, id: root.id, node: root });
            push('k-start', { rootId: root.id });
            while (queue.length && results.length < k) {
                queue.sort(cmpItem);
                const it = queue.shift();
                if (it.t === 1) {                            // 取出來的是點：它就是下一個答案
                    results.push({ j: it.id, d: it.d });
                    push('k-point', { j: it.id, d: it.d, rank: results.length });
                    continue;
                }
                const e = it.node;
                st.opened++;
                openedIds.push(e.id);
                const kids = e.entries.map(c => {
                    if (e.leaf) {
                        st.checked++;
                        checkedPts.push(c);
                        const dd = (points[c].x - q.x) ** 2 + (points[c].y - q.y) ** 2;
                        best.push(dd); best.sort((a, b) => a - b); if (best.length > k) best.pop();
                        return { d: dd, t: 1, id: c };
                    }
                    return { d: mindist(q, c.mbr), t: 0, id: c.id, node: c };
                });
                const dk = best.length === k ? best[k - 1] : Infinity;
                const kidInfo = kids.map(x => {
                    const ok = x.d <= dk;
                    if (ok) queue.push(x);
                    else { st.pruned++; if (x.t === 0) prunedIds.push(x.id); }
                    return { ...view(x), ok };
                });
                const dropped = queue.filter(x => x.d > dk).map(view);
                dropped.forEach(x => { st.pruned++; if (x.t === 0) prunedIds.push(x.id); });
                queue = queue.filter(x => x.d <= dk);
                queue.sort(cmpItem);
                push('k-node', { node: e.id, leaf: e.leaf, from: it.d, kids: kidInfo, dropped });
            }
            push('k-end', { reason: results.length === k ? 'done' : 'empty' });
            return steps;
        }

        /* =================== 說明文字 =================== */
        const refName = r => (r.p !== undefined ? pn(r.p) : rn(r.n));
        const refHtml = r => `<b>${refName(r)}</b>`;
        const itemName = it => (it.t === 1 ? pn(it.id) : '框 ' + rn(it.id));

        function rtDescribe(s) {
            const n = pts.length, M = rtBuild.M, m = rtBuild.m;
            const byId = id => s.nodes.find(x => x.id === id);
            switch (s.kind) {
                case 'b-start':
                    if (!n) return `地圖上還沒有點。點一下地圖就能新增，R-tree 會跟著長出來。`;
                    return `從一棵空的 R-tree 開始：只有一個根，它同時也是葉子。每個節點最多放 <b>M = ${M}</b> 個東西（葉子放點、內部節點放子框），超過就分裂，分裂後兩邊至少各 <b>m = ${m}</b> 個。` +
                        `每個節點用一個<b>剛好包住底下所有點的長方形（MBR）</b>代表。接下來把 ${n} 個點一個一個插進去（空心的點是還沒插入的）。`;
                case 'b-insert': {
                    let t = `插入第 ${s.pi + 1} 個點 <b>${pn(s.pi)}</b>：`;
                    if (!s.levels.length) t += `根還是葉子，直接放進去。`;
                    else {
                        t += s.levels.map(lv => `在 ${rn(lv.node)} 裡比較要擴大多少面積：` +
                            lv.cands.map(c => `${rn(c.id)} +${c.enl}`).join('、') + `，選 <b>${rn(lv.pick)}</b>`).join('；') + '。';
                        const lv0 = s.levels[0];
                        const minE = Math.min(...lv0.cands.map(c => c.enl));
                        if (lv0.cands.filter(c => c.enl === minE).length > 1) t += `（擴大一樣多時，選面積比較小的）`;
                    }
                    if (s.fresh) t += `這是第一個點，葉子的框就是這個點本身。`;
                    else if (s.grown.length) t += `放進去之後，${s.grown.map(rn).join('、')} 的框<b>跟著擴大</b>才包得住它。`;
                    else t += `它本來就在這些框裡面，框都不用變。`;
                    if (s.overflow) t += `葉子 ${rn(s.leaf)} 現在有 ${M + 1} 個點，<span class="no">超過 M = ${M}，要分裂</span>。`;
                    return t;
                }
                case 'b-seeds':
                    return `${rn(s.node)} 有 ${s.count} 個${s.leafNode ? '點' : '子框'}，用 <b>Quadratic Split</b> 分成兩組。第一步 PickSeeds：每兩個配一對，算「放進同一個框會浪費多少面積」（合起來的框面積 − 各自的面積）。` +
                        `最浪費的是 ${refHtml(s.a)} 和 ${refHtml(s.b)}（浪費 ${s.waste}），它們一定要拆開，各自當一組的種子（地圖上橘色、青色）。`;
                case 'b-split': {
                    const free = s.order.filter(o => !o.forced), forced = s.order.filter(o => o.forced);
                    let t = '';
                    if (free.length) t += `PickNext：剩下的每次挑「兩組擴大量差最多」（最有偏好）的先分，放進擴大比較少的那組：` +
                        free.map(o => `${refName(o.e)}→第 ${o.g} 組（+${o.d1} / +${o.d2}）`).join('、') + '。';
                    if (forced.length) t += `剩下的 ${forced.map(o => refName(o.e)).join('、')} 不用比了，全給第 ${forced[0].g} 組，它才湊得到 m = ${m} 個。`;
                    t += `結果 ${rn(s.node)} 留第 1 組（${s.g1.length} 個），新節點 <b>${rn(s.newId)}</b> 拿第 2 組（${s.g2.length} 個）。`;
                    if (s.newRoot !== null) t += `被分裂的是根，所以長出新的根 <b>${rn(s.newRoot)}</b> 把兩個框包起來，<b>樹長高一層</b>，所有葉子還是在同一層。`;
                    else t += `${rn(s.newId)} 交給父節點 ${rn(s.parentId)}` + (s.parentFull ? `，結果 ${rn(s.parentId)} 也超過 M 個，<span class="no">繼續往上分裂</span>。` : '，這次插入就完成了。');
                    return t;
                }
                case 'b-end': {
                    if (!n) return `地圖上沒有點，樹只有一個空的根。`;
                    const h = Math.max(...s.nodes.map(x => x.depth)) + 1;
                    const leaves = s.nodes.filter(x => x.leaf).length;
                    return `${n} 個點都插完了：樹有 ${s.nodes.length} 個節點、${leaves} 個葉子，高度 ${h} 層，<b>所有葉子都在同一層</b>。框和框可以重疊、空曠的地方也沒有框，這是 R-tree 跟四元樹最大的不同。切到分頁二看怎麼用這些框找最近的點。`;
                }
            }
            return '';
        }

        function knDescribe(s) {
            switch (s.kind) {
                case 'k-start':
                    if (s.empty) return `地圖上沒有點，沒有東西可以找。回分頁一新增幾個點吧。`;
                    return `查詢點在 <b>(${qPoint.x},${qPoint.y})</b>（點地圖可以換位置），要找最近的 <b>k = ${kNum}</b> 個點。best-first search 用一個<b>優先佇列</b>，框和點都放進去，依距離由近到遠排；框的距離是 <b>MINDIST</b>：查詢點到框的最短距離，框裡的點不可能比它更近。一開始佇列裡只有根 ${rn(s.rootId)}。`;
                case 'k-node': {
                    let t = `取出佇列最前面的 <b>${rn(s.node)}</b>（MINDIST ${dstr(s.from)}），打開它：`;
                    t += s.leaf ? `它是葉子，算裡面每個點的真正距離：` : `算每個子框的 MINDIST：`;
                    t += s.kids.map(x => `${s.leaf ? pn(x.id) : rn(x.id)} ${dstr(x.d)}`).join('、') + '。';
                    const skipped = s.kids.filter(x => !x.ok);
                    if (s.dk === null) t += `還沒看到 ${kNum} 個點，不知道第 ${kNum} 近有多遠，全部放進佇列。`;
                    else {
                        t += `目前看過的點裡，第 ${kNum} 近的距離是 <b>${dstr(s.dk)}</b>，比它還遠的不可能是答案：`;
                        const gone = skipped.map(x => (x.t === 1 ? pn(x.id) : rn(x.id)) + '（不放進佇列）').concat(s.dropped.map(x => itemName(x) + '（從佇列丟掉）'));
                        t += gone.length ? `<span class="no">${gone.join('、')}</span>。` : `這次沒有可以丟的。`;
                    }
                    return t;
                }
                case 'k-point':
                    return `佇列最前面是點 <b>${pn(s.j)}</b>（距離 ${dstr(s.d)}）。佇列是照距離排的，剩下的框裡任何點都至少有 MINDIST 那麼遠、不會比它近，所以它就是<span class="ok">第 ${s.rank} 近的點 ✓</span>` +
                        (s.rank < kNum ? `，繼續找下一個。` : `，${kNum} 個都找齊了。`);
                case 'k-end': {
                    if (s.reason === 'none') return `沒有點可以找。`;
                    const total = rtBuild.total, n = pts.length;
                    const head = s.reason === 'done' ? `完成！最近的 ${kNum} 個是：` : `佇列空了：地圖上只有 ${n} 個點，全部找出來了：`;
                    return head + s.results.map((r, i) => `${i + 1}. ${pn(r.j)}（${dstr(r.d)}）`).join('、') +
                        `。總共只打開 <b>${s.st.opened}</b> 個框（樹上共 ${total} 個）、算了 <b>${s.st.checked}</b> 個點的距離；暴力法要把 ${n} 個點全部算一次再排序。`;
                }
            }
            return '';
        }

        function rtTags(s) {
            return { 'b-start': ['init'], 'b-insert': ['choose', 'add'], 'b-seeds': ['seeds'], 'b-split': s.newRoot !== null && s.newRoot !== undefined ? ['split', 'root'] : ['split'], 'b-end': [] }[s.kind] || [];
        }
        const KN_TAGS = { 'k-start': ['kstart'], 'k-node': ['expand', 'prune'], 'k-point': ['pop'], 'k-end': ['kend'] };

        /* =================== 畫地圖 =================== */
        function shapeSvg(kind, cx, cy, s, cls = 'pt', attrs = '') {
            const info = KIND_INFO[kind] || { color: '#ccc', shape: 'circle' };
            const pend = /pending/.test(cls);
            const paint = pend ? `stroke="${info.color}"` : `fill="${info.color}"`;
            const f = v => +v.toFixed(2);
            switch (info.shape) {
                case 'square': return `<rect class="${cls}" ${paint} ${attrs} x="${f(cx - s * 0.88)}" y="${f(cy - s * 0.88)}" width="${f(s * 1.76)}" height="${f(s * 1.76)}" rx="${f(s * 0.25)}"/>`;
                case 'triangle': return `<polygon class="${cls}" ${paint} ${attrs} points="${f(cx)},${f(cy - s * 1.15)} ${f(cx + s * 1.05)},${f(cy + s * 0.8)} ${f(cx - s * 1.05)},${f(cy + s * 0.8)}"/>`;
                case 'diamond': return `<polygon class="${cls}" ${paint} ${attrs} points="${f(cx)},${f(cy - s * 1.2)} ${f(cx + s * 1.2)},${f(cy)} ${f(cx)},${f(cy + s * 1.2)} ${f(cx - s * 1.2)},${f(cy)}"/>`;
                default: return `<circle class="${cls}" ${paint} ${attrs} cx="${cx}" cy="${cy}" r="${s}"/>`;
            }
        }
        const PT = 2.1;
        const unitPx = svg => (svg.getBoundingClientRect().width || 500) / 142;
        const ring = (p, cls, r = 3.9) => `<circle class="ring ${cls}" cx="${p.x}" cy="${p.y}" r="${r}"/>`;
        function label(svg, p, text) {
            const fs = 12 / unitPx(svg);
            const right = p.x > 92;
            const ty = p.y < 10 ? p.y + 5.5 + fs * 0.7 : p.y - 5;
            return `<text class="lbl" x="${p.x + (right ? -4.5 : 4.5)}" y="${ty}" font-size="${fs.toFixed(2)}" text-anchor="${right ? 'end' : 'start'}">${text}</text>`;
        }
        function mapBase() {
            let h = '<rect class="bg" x="-7" y="-7" width="142" height="142"/>';
            for (let v = 16; v < WORLD; v += 16) h += `<line class="gridfaint" x1="${v}" y1="0" x2="${v}" y2="128"/><line class="gridfaint" x1="0" y1="${v}" x2="128" y2="${v}"/>`;
            return h + '<rect class="border" x="0" y="0" width="128" height="128"/>';
        }
        /* 框往外多留一點邊，越上層留越多，巢狀的框才看得出來；只有一個點的框也看得到 */
        function boxGeom(n, H) {
            const pad = 1.1 + (H - n.depth) * 1.5;
            return [n.mbr[0] - pad, n.mbr[1] - pad, n.mbr[2] - n.mbr[0] + 2 * pad, n.mbr[3] - n.mbr[1] + 2 * pad];
        }
        function drawBoxes(svg, nodes, clsOf, labelAll) {
            const H = Math.max(...nodes.map(n => n.depth));
            const fs = 10.5 / unitPx(svg);
            let boxes = '', labels = '';
            nodes.forEach(n => {
                if (!n.mbr) return;
                const [x, y, w, hh] = boxGeom(n, H);
                const color = LV_COLORS[(H - n.depth) % LV_COLORS.length];
                const cls = clsOf(n);
                boxes += `<rect class="box ${cls}" x="${x}" y="${y}" width="${w}" height="${hh}" rx="1.4" stroke="${color}" fill="${color}"/>`;
                if (labelAll || cls) labels += `<text class="blbl${cls ? '' : ' dim'}" x="${x + 0.6}" y="${y - 0.7}" font-size="${fs.toFixed(2)}" fill="${color}">${rn(n.id)}</text>`;
            });
            return { boxes, labels };
        }
        const finalNodes = () => rtBuild.steps[rtBuild.steps.length - 1].nodes;

        function drawRtMap() {
            const svg = $('rt-map');
            const s = rtBuild.steps[cursors.rt];
            const cls = new Map();
            const add = (id, c) => cls.set(id, ((cls.get(id) || '') + ' ' + c).trim());
            const ptRing = new Map();
            if (s.kind === 'b-insert') {
                s.path.forEach(id => add(id, 'path'));
                s.grown.forEach(id => add(id, 'grown'));
            } else if (s.kind === 'b-seeds') {
                add(s.node, 'split');
                [[s.a, 'g1'], [s.b, 'g2']].forEach(([r, g]) => (r.p !== undefined ? ptRing.set(r.p, g) : add(r.n, g)));
            } else if (s.kind === 'b-split') {
                add(s.node, 'g1'); add(s.newId, 'g2');
                [[s.g1, 'g1'], [s.g2, 'g2']].forEach(([list, g]) => list.forEach(r => { if (r.p !== undefined) ptRing.set(r.p, g); else add(r.n, g); }));
                if (s.newRoot !== null) add(s.newRoot, 'grown');
            }
            const { boxes, labels } = drawBoxes(svg, s.nodes, n => cls.get(n.id) || '', true);
            let h = mapBase() + boxes, points = '', rings = '', plabels = '';
            pts.forEach((p, i) => {
                const pending = s.kind !== 'b-end' && i >= s.inserted;
                points += shapeSvg(p.kind, p.x, p.y, PT, pending ? 'pt pending' : 'pt');
                if (ptRing.has(i)) rings += ring(p, ptRing.get(i));
                if (i === s.pi && s.kind === 'b-insert') { rings += ring(p, 'cur', 4.4); plabels += label(svg, p, `(${p.x},${p.y})`); }
            });
            svg.innerHTML = h + points + rings + labels + plabels;
        }

        function nearestOnRect(q, r) { return [Math.max(r[0], Math.min(q.x, r[2])), Math.max(r[1], Math.min(q.y, r[3]))]; }

        function drawKnMap() {
            const svg = $('kn-map');
            const s = knSteps[cursors.kn];
            const nodes = finalNodes();
            const opened = new Set(s.opened), pruned = new Set(s.prunedIds);
            const queued = new Set(s.queue.filter(x => x.t === 0).map(x => x.id));
            const { boxes, labels } = drawBoxes(svg, nodes, n => {
                if (s.kind === 'k-node' && n.id === s.node) return 'cur';
                if (pruned.has(n.id)) return 'pruned';
                if (queued.has(n.id)) return 'queued';
                if (opened.has(n.id)) return 'opened';
                return '';
            }, true);
            let h = mapBase();
            if (s.dk !== null && s.dk !== undefined) h += `<circle class="dk" cx="${qPoint.x}" cy="${qPoint.y}" r="${Math.sqrt(s.dk)}"/>`;
            h += boxes;
            // 這一步算了距離的東西：從查詢點畫一條線到框上最近的地方（或點本身）
            let lines = '';
            if (s.kind === 'k-node') {
                const byId = new Map(nodes.map(n => [n.id, n]));
                s.kids.forEach(x => {
                    const [tx, ty] = x.t === 1 ? [pts[x.id].x, pts[x.id].y] : nearestOnRect(qPoint, byId.get(x.id).mbr);
                    lines += `<line class="mdl${x.ok ? '' : ' far'}" x1="${qPoint.x}" y1="${qPoint.y}" x2="${tx}" y2="${ty}"/>`;
                });
            }
            const checked = new Set(s.checkedPts);
            const resRank = new Map(s.results.map((r, i) => [r.j, i + 1]));
            let points = '', rings = '', plabels = '';
            pts.forEach((p, i) => {
                points += shapeSvg(p.kind, p.x, p.y, PT, checked.has(i) || s.kind === 'k-start' ? 'pt' : 'pt faded');
                if (resRank.has(i)) { rings += ring(p, 'hit', 4.2); plabels += label(svg, p, String(resRank.get(i))); }
                else if (s.kind === 'k-point' && i === s.j) rings += ring(p, 'cur', 4.4);
            });
            if (s.kind === 'k-point') { const p = pts[s.j]; rings += ring(p, 'cur', 5.2); }
            const q = qPoint, c = 3.4;
            const qm = `<line class="qcross" x1="${q.x - c * 1.6}" y1="${q.y}" x2="${q.x + c * 1.6}" y2="${q.y}"/><line class="qcross" x1="${q.x}" y1="${q.y - c * 1.6}" x2="${q.x}" y2="${q.y + c * 1.6}"/><circle class="qpt" cx="${q.x}" cy="${q.y}" r="${c * 0.6}"/>`;
            svg.innerHTML = h + lines + points + rings + labels + qm + plabels;
        }

        /* =================== 樹的結構 =================== */
        function iconSvg(kind, s = 2.2) { return `<svg viewBox="-3 -3 6 6" aria-hidden="true">${shapeSvg(kind, 0, 0, s, 'pt')}</svg>`; }
        function renderTree(s) {
            const box = $('rt-tree');
            const H = Math.max(...s.nodes.map(n => n.depth));
            const cls = new Map();
            const add = (id, c) => cls.set(id, ((cls.get(id) || '') + ' ' + c).trim());
            if (s.kind === 'b-insert') { s.path.forEach(id => add(id, 'path')); s.grown.forEach(id => add(id, 'grown')); }
            if (s.kind === 'b-seeds') add(s.node, 'over');
            if (s.kind === 'b-split') { add(s.node, 'g1'); add(s.newId, 'g2'); if (s.newRoot !== null) add(s.newRoot, 'grown'); }
            let html = '';
            for (let d = 0; d <= H; d++) {
                const row = s.nodes.filter(n => n.depth === d);
                const tag = d === 0 ? '第 1 層（根）' : `第 ${d + 1} 層` + (d === H ? '（葉子）' : '');
                html += `<div><div class="lv-tag">${tag}</div><div class="lv-row">` + row.map(n => {
                    const color = LV_COLORS[(H - n.depth) % LV_COLORS.length];
                    const inner = n.leaf
                        ? `<span class="ptk">${n.kids.map(j => iconSvg(pts[j].kind)).join('') || '<span class="kids">空</span>'}</span>`
                        : `<span class="kids">${n.kids.map(rn).join(' ')}</span>`;
                    return `<span class="tnode ${cls.get(n.id) || ''}" style="--lc:${color}"><span class="nm" style="color:${color}">${rn(n.id)}</span>${inner}</span>`;
                }).join('') + `</div></div>`;
            }
            box.innerHTML = html;
            $('st-nodes').textContent = s.nodes.length;
            $('st-height').textContent = H + 1;
            $('st-ins').textContent = s.kind === 'b-end' ? pts.length : s.inserted;
        }

        /* =================== 佇列 =================== */
        function itemHtml(it) {
            if (it.t === 1) return `<span class="it">${iconSvg(pts[it.id].kind)}${pn(it.id)}</span>`;
            const H = Math.max(...finalNodes().map(n => n.depth));
            const node = finalNodes().find(n => n.id === it.id);
            const color = LV_COLORS[(H - node.depth) % LV_COLORS.length];
            return `<span class="it"><span style="color:${color}">■</span>框 ${rn(it.id)}${node.leaf ? '<small style="color:var(--muted);font-weight:400">（葉子）</small>' : ''}</span>`;
        }
        function renderQueue(s) {
            const fresh = new Set((s.kids || []).filter(x => x.ok).map(x => x.t + ':' + x.id));
            $('kn-dk').innerHTML = s.dk === null || s.dk === undefined
                ? `第 ${kNum} 近的距離：還不知道（看過的點不到 ${kNum} 個）`
                : `第 ${kNum} 近的距離最多是 <b>${dstr(s.dk)}</b>，比它遠的都可以丟`;
            let q = s.queue.map((it, i) => {
                const isNew = fresh.has(it.t + ':' + it.id);
                return `<div class="qrow${i === 0 && s.kind !== 'k-end' ? ' first' : ''}"><span class="rk">${i + 1}</span>${itemHtml(it)}${isNew ? '<span class="tagv new">新加入</span>' : ''}<span class="ds"><small>${it.t ? '距離' : 'MINDIST'}</small> ${dstr(it.d)}</span></div>`;
            }).join('');
            const gone = (s.kids || []).filter(x => !x.ok).concat(s.dropped || []);
            q += gone.map(it => `<div class="qrow drop"><span class="rk">✗</span>${itemHtml(it)}<span class="tagv drop">剪掉</span><span class="ds">${dstr(it.d)}</span></div>`).join('');
            $('kn-queue').innerHTML = q || `<div class="empty">${s.kind === 'k-end' || s.empty ? '（空的）' : ''}</div>`;
            $('kn-res').innerHTML = s.results.length
                ? s.results.map((r, i) => `<div class="qrow res"><span class="rk">${i + 1}</span>${itemHtml({ t: 1, id: r.j })}<span class="tagv ok">第 ${i + 1} 近</span><span class="ds">${dstr(r.d)}</span></div>`).join('')
                : `<div class="empty">還沒有。點要從佇列最前面取出來，才算確定。</div>`;
            $('st-open').innerHTML = `${s.st.opened}<small> / ${rtBuild.total}</small>`;
            $('st-dist').innerHTML = `${s.st.checked}<small> / ${pts.length}</small>`;
            $('st-prune').textContent = s.st.pruned;
        }

        /* =================== 地圖工具列與點擊 =================== */
        function renderTools() {
            const box = $('rt-tools');
            const counts = {};
            pts.forEach(p => { counts[p.kind] = (counts[p.kind] || 0) + 1; });
            box.innerHTML = `<div class="kinds"><span class="lab">新增：</span>` + KINDS.map(k =>
                `<button class="kind${k === newKind ? ' sel' : ''}" data-kind="${k}" title="新增的點是${k}">${iconSvg(k)}<span>${k}</span><span class="cnt">${counts[k] || 0}</span></button>`).join('') +
                `</div><button class="btn small" data-act="random">🎲 隨機產生</button><button class="btn small" data-act="clear">清空</button><button class="btn small" data-act="reset">恢復預設</button>`;
            $('rt-count').textContent = `${pts.length} 個點`;
            $('kn-count').textContent = `${pts.length} 個點，查詢點 (${qPoint.x},${qPoint.y})`;
        }
        $('rt-tools').addEventListener('click', e => {
            const kb = e.target.closest('[data-kind]');
            if (kb) { newKind = kb.dataset.kind; renderTools(); return; }
            const act = e.target.closest('[data-act]');
            if (!act) return;
            if (act.dataset.act === 'random') pts = randomPoints();
            if (act.dataset.act === 'clear') pts = [];
            if (act.dataset.act === 'reset') { pts = DEFAULT_POINTS.map(([x, y, kind]) => ({ x, y, kind })); qPoint = { ...DEFAULT_Q }; }
            pointsChanged(act.dataset.act);
        });

        function randomPoints() {
            const rnd = (a, b) => a + Math.floor(Math.random() * (b - a + 1));
            const out = [], seen = new Set();
            const centers = Array.from({ length: rnd(3, 6) }, () => ({ x: rnd(14, 114), y: rnd(14, 114) }));
            const n = rnd(20, 34);
            let guard = 0;
            while (out.length < n && guard++ < 1000) {
                let x, y;
                if (Math.random() < 0.7) { const c = centers[rnd(0, centers.length - 1)]; x = c.x + rnd(-16, 16); y = c.y + rnd(-16, 16); }
                else { x = rnd(3, 124); y = rnd(3, 124); }
                x = Math.max(2, Math.min(125, x)); y = Math.max(2, Math.min(125, y));
                if (seen.has(x + ',' + y)) continue;
                seen.add(x + ',' + y);
                out.push({ x, y, kind: KINDS[rnd(0, 3)] });
            }
            return out;
        }

        function toWorld(svg, e) {
            const pt = svg.createSVGPoint();
            pt.x = e.clientX; pt.y = e.clientY;
            return pt.matrixTransform(svg.getScreenCTM().inverse());
        }
        const clampW = v => Math.max(0, Math.min(WORLD - 1, Math.round(v)));
        function setHint(group, text, warn) {
            const el = $(group + '-hint');
            el.textContent = text;
            el.classList.toggle('warn', !!warn);
        }
        function defaultHint(group) {
            if (group === 'rt') return '點地圖空白處新增一個點（類型選上面），點一下已有的點刪除它；新增後會直接播放它怎麼插進樹裡。';
            return '點地圖任何地方，把查詢點搬過去，查詢會從頭重新跑。要新增或刪除點，請回分頁一。';
        }
        function tapMap(group, svg, e) {
            const w = toWorld(svg, e);
            if (w.x < -2 || w.y < -2 || w.x > WORLD + 1 || w.y > WORLD + 1) return;
            if (group === 'kn') {
                qPoint = { x: clampW(w.x), y: clampW(w.y) };
                queryChanged();
                setHint('kn', `查詢點搬到 (${qPoint.x},${qPoint.y})。按「下一步」看怎麼找。`);
                return;
            }
            const hitR = Math.max(3.2, 13 / unitPx(svg));
            let best = -1, bestD = Infinity;
            pts.forEach((p, i) => { const d = Math.hypot(p.x - w.x, p.y - w.y); if (d < bestD) { bestD = d; best = i; } });
            if (best >= 0 && bestD <= hitR) {
                const p = pts[best];
                pts.splice(best, 1);
                pointsChanged('delete');
                setHint('rt', `刪掉了 ${p.kind}(${p.x},${p.y})，樹照新的點重新建一次。`);
                return;
            }
            if (pts.length >= MAX_POINTS) { setHint('rt', `最多 ${MAX_POINTS} 個點，先刪掉一些吧。`, true); return; }
            const p = { x: clampW(w.x), y: clampW(w.y), kind: newKind };
            pts.push(p);
            pointsChanged('add');
            setHint('rt', `新增了 ${p.kind}(${p.x},${p.y})。`);
        }
        ['rt', 'kn'].forEach(group => {
            const svg = $(group + '-map');
            let start = null;
            svg.addEventListener('pointerdown', e => { if (e.button !== undefined && e.button !== 0) return; start = { x: e.clientX, y: e.clientY }; });
            svg.addEventListener('pointerup', e => {
                if (!start) return;
                const moved = Math.hypot(e.clientX - start.x, e.clientY - start.y);
                start = null;
                if (moved < 8) tapMap(group, svg, e);
            });
            svg.addEventListener('pointercancel', () => { start = null; });
        });

        /* =================== 資料或參數改變：重算 trace =================== */
        function rebuildRt() { rtBuild = rtBuildTrace(pts, capM); }
        function rebuildKn() { knSteps = knnTrace(rtBuild.root, pts, qPoint, kNum); }
        function pointsChanged(how) {
            stopAuto('rt'); stopAuto('kn');
            rebuildRt(); rebuildKn();
            if (how === 'add') cursors.rt = rtBuild.steps.findIndex(s => s.pi === pts.length - 1);   // 直接從新點的插入過程開始看
            else cursors.rt = how === 'delete' ? rtBuild.steps.length - 1 : 0;
            cursors.kn = 0;
            renderTools();
            setHint('rt', defaultHint('rt')); setHint('kn', defaultHint('kn'));
            showActive();
            reserveExplainHeight(activeTab);
        }
        function queryChanged() {
            stopAuto('kn');
            rebuildKn();
            cursors.kn = 0;
            renderTools();
            knShow();
            reserveExplainHeight('kn');
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

        const FILES = { java: ['RTree.java', 'javac RTree.java && java RTree'], py: ['rtree.py', 'python3 rtree.py'] };
        function renderCode(group, tags) {
            if (measuringBlocks || restoringBlocks) return;   // 量區塊高度時不用畫程式碼（程式碼框高度不會變），量完畫回來時它也沒被動過，省時間
            const pre = $(group + '-code');
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
            $(group + '-downloads').innerHTML = `下載 <a href="code/${file}" download>${file}</a>　執行 <code>${cmd}</code>`;
        }

        /* =================== 顯示某一步 =================== */
        function rtShow() {
            const steps = rtBuild.steps, c = cursors.rt, s = steps[c];
            $('rt-explain').innerHTML = `<span class="step-no">步驟 ${c + 1} / ${steps.length}</span>${rtDescribe(s)}`;
            drawRtMap();
            renderTree(s);
            renderCode('rt', rtTags(s));
            $('rt-prev').disabled = $('rt-first').disabled = c === 0;
            $('rt-next').disabled = $('rt-last').disabled = c === steps.length - 1;
            $('cap-val').textContent = capM;
            $('cap-unit').textContent = `超過就分裂；分裂後至少 m = ${Math.floor(capM / 2)} 個`;
            $('cap-minus').disabled = capM <= 3;
            $('cap-plus').disabled = capM >= 6;
        }
        function knShow() {
            const c = cursors.kn, s = knSteps[c];
            $('kn-explain').innerHTML = `<span class="step-no">步驟 ${c + 1} / ${knSteps.length}</span>${knDescribe(s)}`;
            drawKnMap();
            renderQueue(s);
            renderCode('kn', KN_TAGS[s.kind] || []);
            $('kn-prev').disabled = $('kn-first').disabled = c === 0;
            $('kn-next').disabled = $('kn-last').disabled = c === knSteps.length - 1;
            $('k-val').textContent = kNum;
            $('k-minus').disabled = kNum <= 1;
            $('k-plus').disabled = kNum >= 8;
        }
        function showActive() { if (activeTab === 'rt') rtShow(); else knShow(); }

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
            const box = $(group + '-explain');
            if (!box.offsetWidth) return;
            const probe = box.cloneNode(false);
            probe.removeAttribute('id');
            probe.style.cssText = `position:absolute;visibility:hidden;left:-9999px;min-height:0;width:${box.offsetWidth}px`;
            document.body.appendChild(probe);
            let tallest = 0;
            const steps = stepsOf(group), fn = group === 'rt' ? rtDescribe : knDescribe;
            steps.forEach((s, i) => {
                probe.innerHTML = `<span class="step-no">步驟 ${i + 1} / ${steps.length}</span>${fn(s)}`;
                tallest = Math.max(tallest, probe.offsetHeight);
            });
            probe.remove();
            box.style.minHeight = tallest + 'px';
            reserveBlockHeights($('panel-' + group), steps.length, i => { cursors[group] = i; group === 'rt' ? rtShow() : knShow(); }, () => cursors[group]);
        }

        /* =================== 播放控制 =================== */
        function stepsOf(group) { return group === 'rt' ? rtBuild.steps : knSteps; }
        function go(group, dir) {
            const next = cursors[group] + dir;
            if (next < 0 || next >= stepsOf(group).length) return false;
            cursors[group] = next;
            group === 'rt' ? rtShow() : knShow();
            return cursors[group] < stepsOf(group).length - 1;
        }
        function stopAuto(group) {
            clearInterval(timers[group]);
            timers[group] = null;
            $(group + '-play').textContent = '▶ 自動播放';
        }
        ['rt', 'kn'].forEach(group => {
            const show = () => (group === 'rt' ? rtShow() : knShow());
            $(group + '-next').addEventListener('click', () => { stopAuto(group); go(group, 1); });
            $(group + '-prev').addEventListener('click', () => { stopAuto(group); go(group, -1); });
            $(group + '-first').addEventListener('click', () => { stopAuto(group); cursors[group] = 0; show(); });
            $(group + '-last').addEventListener('click', () => { stopAuto(group); cursors[group] = stepsOf(group).length - 1; show(); });
            $(group + '-play').addEventListener('click', () => {
                if (timers[group]) { stopAuto(group); return; }
                if (cursors[group] === stepsOf(group).length - 1) { cursors[group] = 0; show(); }
                $(group + '-play').textContent = '⏸ 暫停';
                timers[group] = setInterval(() => { if (!go(group, 1)) stopAuto(group); }, 1700);
            });
        });
        document.addEventListener('keydown', e => {
            if (e.target.closest && e.target.closest('input, textarea, select')) return;
            if (e.key === 'ArrowRight') { stopAuto(activeTab); go(activeTab, 1); }
            if (e.key === 'ArrowLeft') { stopAuto(activeTab); go(activeTab, -1); }
        });

        function capChanged() {
            stopAuto('rt'); stopAuto('kn');
            rebuildRt(); rebuildKn();
            cursors.rt = rtBuild.steps.length - 1;        // 直接看新容量下的整棵樹
            cursors.kn = 0;
            rtShow();
            reserveExplainHeight('rt');
        }
        $('cap-minus').addEventListener('click', () => { if (capM > 3) { capM--; capChanged(); } });
        $('cap-plus').addEventListener('click', () => { if (capM < 6) { capM++; capChanged(); } });
        $('k-minus').addEventListener('click', () => { if (kNum > 1) { kNum--; queryChanged(); } });
        $('k-plus').addEventListener('click', () => { if (kNum < 8) { kNum++; queryChanged(); } });

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
            $('panel-rt').hidden = tab !== 'rt';
            $('panel-kn').hidden = tab !== 'kn';
            history.replaceState(null, '', tab === 'kn' ? '#knn' : '#build');
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

        rebuildRt();
        rebuildKn();
        renderTools();
        setHint('rt', defaultHint('rt')); setHint('kn', defaultHint('kn'));
        if (location.hash === '#knn') switchTab('kn');
        showActive();
        reserveExplainHeight(activeTab);
    </script>
</body>

</html>
