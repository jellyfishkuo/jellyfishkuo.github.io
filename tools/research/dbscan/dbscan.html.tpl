<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/dbscan.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/dbscan-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/dbscan-180.png">
    <title>DBSCAN 密度分群</title>
    <meta name="description" content="在地圖上一步一步看 DBSCAN 怎麼用「ε 範圍內的鄰居夠不夠多」找出核心點、用佇列把群長出來、標出雜訊，月牙和圓環也分得開，Java 與 Python 程式碼逐行對照。">
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

        .layout { display: grid; gap: 1rem; margin-top: 1.3rem; }
        .layout > * { min-width: 0; display: grid; gap: 1rem; align-content: start; }
        .layout > * > * { min-width: 0; }
        @media (min-width: 960px) { .layout { grid-template-columns: 1fr 1.02fr; } }

        .card {
            background: var(--panel);
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 1rem;
            min-width: 0;
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
        .explain .cl, .notes .cl { font-weight: 700; }

        /* ── 地圖 ── */
        .map-box { background: #0a0a14; border: 1px solid var(--border); border-radius: 10px; overflow: hidden; }
        svg.map { display: block; width: 100%; height: auto; touch-action: manipulation; user-select: none; -webkit-user-select: none; cursor: crosshair; }
        svg.map.still { cursor: default; }
        svg.map * { vector-effect: non-scaling-stroke; }
        .map .bg { fill: #0b0b17; }
        .map .gridfaint { stroke: #15152a; stroke-width: 1; }
        .map .border { fill: none; stroke: #3a3a5a; stroke-width: 1.5; }
        .map .pt.core { stroke: #05050a; stroke-width: 1; }
        .map .pt.edge { fill-opacity: 0.22; stroke-width: 1.8; }
        .map .pt.noise { stroke: #9a9ab5; stroke-width: 1.8; stroke-linecap: round; fill: none; }
        .map .pt.unseen { fill: none; stroke: #5c5c7c; stroke-width: 1.3; }
        .map .pt.dim { opacity: 0.25; }
        .map .eps { fill: rgba(245, 158, 11, 0.07); stroke: var(--warn); stroke-width: 1.5; stroke-dasharray: 5 4; }
        .map .eps.old { fill: none; opacity: 0.5; }
        .map .nline { stroke: var(--warn); stroke-width: 1; opacity: 0.55; }
        .map .tline { stroke-width: 1.4; opacity: 0.42; }
        .map .ring { fill: none; stroke-width: 2.4; }
        .map .ring.cur { stroke: var(--warn); }
        .map .ring.add { stroke: var(--accent2); }
        .map .ring.queue { stroke: var(--accent2); stroke-width: 1.4; stroke-dasharray: 3 2; }
        .map .ring.claim { stroke: var(--good); }
        .map .lbl { fill: var(--text); paint-order: stroke; stroke: #05050a; stroke-width: 3px; stroke-linejoin: round; font-family: 'Space Mono', ui-monospace, monospace; font-weight: 700; }
        .map .idx { fill: #8a8aa3; paint-order: stroke; stroke: #05050a; stroke-width: 2.5px; stroke-linejoin: round; font-family: 'Space Mono', ui-monospace, monospace; }
        .map .center { stroke: #fff; stroke-width: 2.4; stroke-linecap: round; }
        .map .center-bg { stroke: #05050a; stroke-width: 5; stroke-linecap: round; }
        .map .scale { stroke: var(--text); stroke-width: 2; }

        .map-tools { display: flex; flex-wrap: wrap; gap: 0.4rem; align-items: center; margin-top: 0.7rem; }
        .map-tools .lab { color: var(--muted); font-size: 0.8rem; margin-right: 0.15rem; }
        .hint { color: var(--muted); font-size: 0.8rem; margin-top: 0.5rem; min-height: 1.3em; }
        .hint.warn { color: var(--warn); }
        .legend { display: flex; flex-wrap: wrap; gap: 0.3rem 0.9rem; font-size: 0.75rem; color: var(--muted); margin-top: 0.45rem; }
        .legend i { display: inline-block; width: 11px; height: 11px; border-radius: 3px; margin-right: 0.3rem; vertical-align: -1px; border: 2px solid; }

        /* ── 統計 ── */
        .stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 0.5rem; }
        .stat { background: var(--panel-2); border-radius: 10px; padding: 0.55rem 0.6rem; min-width: 0; }
        .stat .v { font: 700 1.25rem 'Space Mono', monospace; }
        .stat .k { color: var(--muted); font-size: 0.75rem; line-height: 1.35; }
        .sub { color: var(--muted); font-size: 0.78rem; margin: 0.8rem 0 0.4rem; }
        .chips { display: flex; flex-wrap: wrap; gap: 0.25rem; }
        .chip {
            font: 700 0.7rem/1.5 'Space Mono', monospace;
            border: 1.5px solid var(--border); border-radius: 6px;
            padding: 0 0.25rem; min-width: 2.5em; text-align: center;
            color: var(--muted); background: var(--panel-2);
        }
        .chip.core { color: #05050a; }
        .chip.edge { color: var(--text); }
        .chip.noise { border-style: dashed; color: #8a8aa3; text-decoration: line-through; }
        .chip.cur { box-shadow: 0 0 0 2px var(--warn); }
        .empty { color: var(--muted); font-size: 0.8rem; }

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
        .notes > * { min-width: 0; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr; } .notes .wide { grid-column: 1 / -1; } }
        .notes p, .notes li { color: #c6c6d6; font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; }
        .notes b { color: var(--text); }
        .notes a { color: var(--accent2); }

        /* ── 跟 k-means 比 ── */
        .cmp { display: grid; grid-template-columns: 1fr 1fr; gap: 0.7rem; margin: 0.4rem 0 0.8rem; }
        .cmp > * { min-width: 0; }
        @media (min-width: 960px) { .cmp { max-width: 640px; } }
        .cmp .cap { font-size: 0.78rem; color: var(--muted); margin-top: 0.3rem; text-align: center; }
    </style>
</head>

<body>
    <div class="wrap">
        <a class="back" href="../index.html#research">← RETURN TO PORTFOLIO</a>
        <div class="kicker">RESEARCH DEMO · DENSITY-BASED CLUSTERING</div>
        <h1>DBSCAN 密度分群<small>鄰居夠多就長成一群：不用先說要分幾群，還會標出雜訊</small></h1>
        <p class="intro">
            <a href="spatial.html">空間資料</a>那頁的共位樣式用「距離 ≤ r 就算鄰近」去找常開在一起的店；DBSCAN 也用同樣的鄰近距離（這裡叫 <b>ε</b>），但問的是另一件事：<b>地圖上的點自己聚成了哪幾團？</b>
            它的想法很直接：一個點周圍半徑 ε 的圈裡如果有夠多鄰居（≥ <b>MinPts</b>），這附近就夠密，從它開始把鄰居一圈一圈拉進來，長成一群。
            所以它<b>不用先指定要分幾群</b>，月牙、圓環這種<b>奇怪形狀也分得開</b>，而周圍太空、又沒被任何群收進去的點，會被標成<b>雜訊</b>。
        </p>

        <div class="layout">
            <div>
                <div class="card">
                    <div class="card-head"><h2>一步一步看</h2></div>
                    <div class="player">
                        <button class="btn" id="btn-first" title="回到開頭">⏮</button>
                        <button class="btn" id="btn-prev">◀ 上一步</button>
                        <button class="btn primary" id="btn-next">下一步 ▶</button>
                        <button class="btn" id="btn-play">▶ 自動播放</button>
                        <button class="btn" id="btn-last">⏭ 直接看結果</button>
                    </div>
                    <div class="params">
                        <label class="param"><span>半徑 ε</span><input type="range" id="eps-range" min="4" max="30" step="1" value="12"><span class="val" id="eps-val">12</span></label>
                        <div class="param">
                            <span>MinPts</span>
                            <button class="btn stepper" id="mp-minus" aria-label="減少">−</button>
                            <span class="val" id="mp-val">3</span>
                            <button class="btn stepper" id="mp-plus" aria-label="增加">+</button>
                            <span class="unit">個（含自己）</span>
                        </div>
                    </div>
                    <div class="explain" id="explain"></div>
                </div>

                <div class="card">
                    <div class="card-head"><h2>地圖</h2><span id="pt-count" style="color:var(--muted);font-size:0.8rem"></span></div>
                    <div class="map-box"><svg class="map" id="map" viewBox="-1 -1 130 130" role="img" aria-label="點的位置、ε 範圍與分群結果"></svg></div>
                    <div class="map-tools" id="tools">
                        <span class="lab">換資料：</span>
                        <button class="btn small" data-act="moons">🌙 兩個月牙</button>
                        <button class="btn small" data-act="rings">◎ 同心圓</button>
                        <button class="btn small" data-act="blobs">● 幾團＋雜訊</button>
                        <button class="btn small" data-act="clear">清空</button>
                        <button class="btn small" data-act="reset">恢復預設</button>
                    </div>
                    <div class="hint" id="hint"></div>
                    <div class="legend">
                        <span><i style="background:#60a5fa;border-color:#60a5fa;border-radius:50%"></i>核心點</span>
                        <span><i style="background:rgba(96,165,250,0.22);border-color:#60a5fa;border-radius:50%"></i>邊界點</span>
                        <span><i style="border-color:#9a9ab5;border-radius:0;border-width:0 0 2px 0;height:6px;transform:rotate(45deg)"></i>雜訊（×）</span>
                        <span><i style="border-color:#5c5c7c;border-radius:50%;border-width:1px"></i>還沒看過</span>
                        <span><i style="border-color:var(--warn);border-radius:50%;border-style:dashed"></i>半徑 ε 的圈</span>
                        <span><i style="border-color:var(--accent2);border-radius:50%;border-style:dashed"></i>在佇列裡排隊</span>
                    </div>
                </div>
            </div>

            <div>
                <div class="card">
                    <h2>目前狀態</h2>
                    <div class="stats">
                        <div class="stat"><div class="v" id="st-clusters">0</div><div class="k">群</div></div>
                        <div class="stat"><div class="v" id="st-core">0</div><div class="k">核心點</div></div>
                        <div class="stat"><div class="v" id="st-edge">0</div><div class="k">邊界點</div></div>
                        <div class="stat"><div class="v" id="st-noise">0</div><div class="k">雜訊</div></div>
                    </div>
                    <div class="sub">佇列（排隊等著被看的點，從左邊拿出來）</div>
                    <div class="chips" id="queue"></div>
                    <div class="sub">每個點目前的狀態（實心＝核心點、空心＝邊界點、劃線＝雜訊、灰色＝還沒看過）</div>
                    <div class="chips" id="plist"></div>
                </div>

                <div class="card">
                    <div class="card-head">
                        <h2>程式碼</h2>
                        <div class="lang">
                            <button data-lang="java" class="active">Java</button>
                            <button data-lang="py">Python</button>
                        </div>
                    </div>
                    <pre class="code" id="code"></pre>
                    <div class="downloads" id="downloads"></div>
                </div>
            </div>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼這樣長出來的就是一群？</h2>
                <p>先講三種點：圈裡（半徑 ε，含自己）至少有 MinPts 個點的叫<b>核心點</b>；自己不夠密、但落在某個核心點圈裡的叫<b>邊界點</b>；兩者都不是的就是<b>雜訊</b>。
                    從核心點出發，只要一路踩著核心點、每一步都不超過 ε，能走到的點都算<b>密度可達</b>，DBSCAN 定義的一群就是「從一個核心點密度可達的所有點」。</p>
                <p style="margin-top:0.5rem">程式裡的佇列就是在做這件事：只有核心點會把它的鄰居排進佇列，邊界點拿出來就停，所以群會沿著夠密的地方一路長，碰到稀疏的地方就停住。
                    兩群中間只要隔著一段沒有核心點的空隙，就不會被連在一起，不管它們是什麼形狀。</p>
                <p style="margin-top:0.5rem"><b>順序會影響什麼？</b>核心點屬於哪一群跟順序無關，順序只影響兩件事：群的編號，以及<b>同時被兩群碰到的邊界點</b>，它歸給先長到它的那一群（這頁照編號順序處理，所以是編號小的群），之後不會再被搶走。
                    雜訊則只是「暫時」的：早一點被看到、當時判定為雜訊的點，之後被某個核心點的圈蓋到，就會被<b>收編</b>成邊界點。</p>
            </div>
            <div class="card">
                <h2>優缺點，以及跟實驗室研究的關係</h2>
                <ul>
                    <li><b>不用先決定群數，形狀不限，還會挑出雜訊。</b>這三點都是 k-means 做不到的（下面有比較）。</li>
                    <li><b>參數要自己挑：</b>ε 和 MinPts 是整張地圖共用的一組值。常見的做法是 MinPts 取維度的兩倍（平面上取 4），再把每個點「第 MinPts 近的鄰居距離」由大到小排成折線圖，在轉彎的地方取 ε。</li>
                    <li><b>密度差很多的群分不好：</b>一團很密、一團很鬆時，ε 小了鬆的那團變雜訊，ε 大了密的那幾團黏在一起。OPTICS、HDBSCAN 就是為了這個問題，改成同時看很多種 ε。</li>
                    <li><b>花時間的是找 ε 鄰居：</b>每個點只做一次範圍查詢，直接掃要 O(n²)；用 <a href="spatial.html">空間資料</a>那頁的四元樹、或 R-tree、網格當索引，只去查附近的格子，就快很多。</li>
                    <li><b>資料會一直進來怎麼辦？</b>原作者後來提出 Incremental DBSCAN，新增或刪除一個點時只重算它附近受影響的部分；資料串流上也有 DenStream 這類方法先把點壓成小小的「微群」再分群，跟 <a href="incremental.html">增量探勘</a>、<a href="sliding-window.html">滑動視窗</a>的想法是同一條路。</li>
                </ul>
            </div>
            <div class="card wide">
                <h2>跟 k-means 比一比</h2>
                <p>k-means 要先說好分 k 群，每個點都分給<b>離它最近的中心</b>，再把中心移到該群的平均位置，重複到不再變。因為只看「離哪個中心近」，兩群的分界永遠是兩個中心連線的<b>垂直平分線</b>，切出來的群都是一塊一塊圓圓胖胖的。
                    下面用目前地圖上的資料直接跑一次（k 取 DBSCAN 找到的群數，至少 2），換成「兩個月牙」或「同心圓」最明顯。</p>
                <div class="cmp">
                    <div>
                        <div class="map-box"><svg class="map still" id="cmp-db" viewBox="-1 -1 130 130" role="img" aria-label="DBSCAN 的分群結果"></svg></div>
                        <div class="cap" id="cap-db"></div>
                    </div>
                    <div>
                        <div class="map-box"><svg class="map still" id="cmp-km" viewBox="-1 -1 130 130" role="img" aria-label="k-means 的分群結果"></svg></div>
                        <div class="cap" id="cap-km"></div>
                    </div>
                </div>
                <ul>
                    <li><b>月牙會被攔腰切斷：</b>一個月牙的兩端離自己的「平均位置」很遠，反而比較靠近另一個月牙的中心，所以會被分過去。DBSCAN 只看鄰居接不接得上，順著彎過去也沒關係。</li>
                    <li><b>同心圓完全沒辦法：</b>兩個圓的平均位置都在正中間，k-means 只能把它切成左右兩半；DBSCAN 沿著圓環一路長，內圈、外圈各自一群。</li>
                    <li><b>沒有雜訊這個選項：</b>k-means 裡每個點都一定要選一群，零星的點會被硬塞進去，還會把中心拉偏。</li>
                    <li>反過來說，資料本來就是幾團大小差不多的圓塊時，k-means 又快又穩；它不用算每個點的 ε 鄰居，資料量很大時比較省。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           DBSCAN 一步一步看
           網頁裡用 JavaScript 照著同樣的演算法跑一次，把每一步記下來；
           上一步／下一步只是在這些紀錄之間移動。右邊的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = /*CODE_JSON*/null;

        const WORLD = 128;          // 地圖 128×128
        const MAX_POINTS = 90;
        const UNSEEN = 0, NOISE = -1;
        // 兩個月牙＋幾個零星的點，編號照 x 由左到右（跟下載的程式裡一樣）
        const DEFAULT_POINTS = [
            [14, 58], [16, 48], [16, 108], [22, 40], [30, 34], [30, 80], [40, 32], [44, 66],
            [46, 76], [50, 34], [52, 84], [58, 40], [60, 90], [64, 48], [66, 58], [70, 92],
            [80, 90], [88, 84], [94, 76], [96, 66], [98, 52], [108, 22]
        ];
        const DEFAULT_EPS = 12, DEFAULT_MINPTS = 3;
        const CL_COLORS = ['#60a5fa', '#f472b6', '#facc15', '#34d399', '#a78bfa', '#fb923c', '#22d3ee', '#e879f9'];

        const $ = id => document.getElementById(id);
        let pts = DEFAULT_POINTS.map(([x, y]) => ({ x, y }));
        let eps = DEFAULT_EPS;
        let minPts = DEFAULT_MINPTS;
        let lang = 'java';
        let steps = [];
        let cursor = 0;
        let timer = null;

        const clColor = c => CL_COLORS[(c - 1) % CL_COLORS.length];
        const cl = c => `<span class="cl" style="color:${clColor(c)}">第 ${c} 群</span>`;
        const pxy = i => `#${i} (${pts[i].x},${pts[i].y})`;
        function idList(arr, max = 6) {
            if (arr.length <= max) return arr.map(i => '#' + i).join('、');
            return arr.slice(0, max).map(i => '#' + i).join('、') + ` 等 ${arr.length} 個`;
        }

        /* =================== DBSCAN：照著程式跑一次 =================== */
        function neighbors(points, p, e) {
            const out = [];
            for (let q = 0; q < points.length; q++) {
                const dx = points[p].x - points[q].x, dy = points[p].y - points[q].y;
                if (dx * dx + dy * dy <= e * e) out.push(q);
            }
            return out;
        }

        function dbscanTrace(points, e, m) {
            const n = points.length;
            const label = new Array(n).fill(UNSEEN);
            const core = new Array(n).fill(null);        // 數過鄰居之後才知道是不是核心點
            const pulledBy = new Array(n).fill(-1);      // 是哪個核心點把它排進佇列的
            const labeledAt = new Array(n).fill(-1);     // 第幾步拿到群編號
            const noiseAt = new Array(n).fill(-1);       // 第幾步被標成雜訊
            const nbCount = new Array(n).fill(0);
            let c = 0, queue = [];
            const out = [];
            const push = (kind, extra = {}) => out.push({
                kind, c, ...extra,
                label: label.slice(), core: core.slice(), queue: queue.slice(), pulledBy: pulledBy.slice()
            });
            push('start');
            for (let p = 0; p < n; p++) {
                if (label[p] !== UNSEEN) { push('skip', { p, when: labeledAt[p] }); continue; }
                const nb = neighbors(points, p, e);
                nbCount[p] = nb.length;
                if (nb.length < m) {
                    label[p] = NOISE; core[p] = false; noiseAt[p] = out.length;
                    push('noise', { p, nb });
                    continue;
                }
                c++;
                label[p] = c; core[p] = true; labeledAt[p] = out.length;
                const queued = new Set([p]);
                queue = [];
                const added = [], wasNoise = [], taken = [];
                for (const q of nb) {
                    if (!queued.has(q) && label[q] <= 0) {
                        queued.add(q); queue.push(q); pulledBy[q] = p; added.push(q);
                        if (label[q] === NOISE) wasNoise.push(q);
                    } else if (label[q] > 0 && q !== p) taken.push(q);
                }
                push('core', { p, nb, added, wasNoise, taken });
                while (queue.length) {
                    const q = queue.shift();
                    if (label[q] === NOISE) {                // 原本的雜訊被收編，成為邊界點
                        label[q] = c; labeledAt[q] = out.length;
                        push('claim', { p: q, from: pulledBy[q], noiseAt: noiseAt[q], k: nbCount[q] });
                        continue;
                    }
                    label[q] = c; labeledAt[q] = out.length;
                    const nq = neighbors(points, q, e);
                    nbCount[q] = nq.length;
                    if (nq.length < m) {                     // 邊界點：不再往外擴
                        core[q] = false;
                        push('grow-border', { p: q, nb: nq, from: pulledBy[q] });
                        continue;
                    }
                    core[q] = true;
                    const add2 = [];
                    for (const r of nq) {
                        if (!queued.has(r) && label[r] <= 0) { queued.add(r); queue.push(r); pulledBy[r] = q; add2.push(r); }
                    }
                    push('grow-core', { p: q, nb: nq, added: add2, from: pulledBy[q] });
                }
                const members = [];
                label.forEach((l, i) => { if (l === c) members.push(i); });
                push('done', { p, members });
            }
            push('end');
            return out;
        }

        /* =================== 說明文字 =================== */
        function describe(s) {
            const n = pts.length;
            switch (s.kind) {
                case 'start':
                    if (!n) return '地圖上還沒有點。點一下地圖就能新增，或按下面的「換資料」產生一組。';
                    return `地圖上有 ${n} 個點，<b>編號就是處理順序</b>（預設和換資料產生的點照 x 由左到右編號，自己點的新點接在最後）。` +
                        `每個點畫一個半徑 <b>ε = ${eps}</b> 的圈，圈裡的點（包含自己）就是它的 ε 鄰居；鄰居至少 <b>MinPts = ${minPts}</b> 個的點叫<b>核心點</b>，代表它周圍夠密。` +
                        `DBSCAN 照編號一個一個看，遇到核心點就開一個新的群，再用佇列把鄰居一圈一圈拉進來。`;
                case 'skip':
                    return `看 <b>#${s.p}</b>：它在第 ${s.when + 1} 步已經被收進 ${cl(s.label[s.p])} 了，<b>跳過</b>。外層迴圈只處理還沒有歸屬的點，一個點拿到群編號之後就不會再變。`;
                case 'noise':
                    return `看 <b>${pxy(s.p)}</b>：圈裡只有 ${s.nb.length} 個點（含自己），比 MinPts = ${minPts} 少，周圍不夠密，<b>先標成雜訊</b>。` +
                        `這只是暫時的：之後如果有核心點的圈蓋到它，它還會被收編進那一群。`;
                case 'core': {
                    let t = `看 <b>${pxy(s.p)}</b>：圈裡有 ${s.nb.length} 個點（含自己）≥ MinPts = ${minPts}，是<b>核心點</b>！開一個新的 ${cl(s.c)}，`;
                    t += s.added.length ? `把還沒歸屬的鄰居 ${idList(s.added)} 排進佇列。` : `不過它的鄰居都已經有歸屬，佇列是空的。`;
                    if (s.wasNoise.length) t += `其中 ${idList(s.wasNoise)} 原本是雜訊，等一下會被收編。`;
                    if (s.taken.length) t += `${idList(s.taken)} 已經屬於別的群，不搶。`;
                    return t;
                }
                case 'grow-core':
                    return `從佇列拿出 <b>#${s.p}</b>（#${s.from} 拉進來的），標成 ${cl(s.c)}。它的圈裡有 ${s.nb.length} 個點 ≥ ${minPts}，也是<b>核心點</b>，群從它這裡繼續往外長：` +
                        (s.added.length ? `新排進佇列 ${idList(s.added)}。` : `不過它的鄰居都已經排過隊或有歸屬，沒有新的點。`) +
                        `佇列還剩 ${s.queue.length} 個。`;
                case 'grow-border':
                    return `從佇列拿出 <b>#${s.p}</b>（#${s.from} 拉進來的），標成 ${cl(s.c)}。它的圈裡只有 ${s.nb.length} 個點 < ${minPts}，不是核心點，是<b>邊界點</b>：它屬於這一群，但周圍不夠密，不能再幫群往外長。佇列還剩 ${s.queue.length} 個。`;
                case 'claim':
                    return `從佇列拿出 <b>#${s.p}</b>：它在第 ${s.noiseAt + 1} 步被標成<b>雜訊</b>（自己的圈裡只有 ${s.k} 個點），但它落在核心點 #${s.from} 的圈裡，所以被 ${cl(s.c)} <b>收編</b>，改成邊界點。` +
                        `它的鄰居之前數過、不夠多，不用再往外擴。佇列還剩 ${s.queue.length} 個。`;
                case 'done': {
                    const cores = s.members.filter(i => s.core[i]).length;
                    return `佇列空了，${cl(s.c)} 長完了：共 <b>${s.members.length}</b> 個點（核心點 ${cores} 個、邊界點 ${s.members.length - cores} 個）。` +
                        (s.p + 1 < n ? `回到外層迴圈，從 #${s.p + 1} 繼續看。` : `外層迴圈也看完了。`);
                }
                case 'end': {
                    if (!n) return '地圖上沒有點，沒有東西可以分群。';
                    const noise = s.label.filter(l => l === NOISE).length;
                    const claimed = steps.filter(x => x.kind === 'claim').length;
                    if (!s.c) return `全部看完：<b>一個核心點都沒有</b>，所以沒有任何群，${n} 個點全是雜訊。試著把 ε 拉大或把 MinPts 調小。`;
                    return `全部看完！分出 <b>${s.c}</b> 群，雜訊 <b>${noise}</b> 個` +
                        (claimed ? `；過程中有 ${claimed} 個點先被標成雜訊、後來才被收編成邊界點` : '') +
                        `。沒有人告訴它要分幾群，群數是由密度自己決定的。`;
                }
            }
            return '';
        }

        const TAGS = {
            start: ['init', 'nbr'], skip: ['skip'], noise: ['visit', 'noise'], core: ['visit', 'core'],
            'grow-core': ['pop', 'grow', 'expand'], 'grow-border': ['pop', 'grow', 'border'], claim: ['pop', 'claim'],
            done: ['done'], end: ['end']
        };

        /* =================== 畫地圖 =================== */
        const unitPx = svg => (svg.getBoundingClientRect().width || 500) / 130;
        const f2 = v => +v.toFixed(2);
        function mapBase() {
            let h = '<rect class="bg" x="0" y="0" width="128" height="128"/>';
            for (let v = 16; v < WORLD; v += 16) h += `<line class="gridfaint" x1="${v}" y1="0" x2="${v}" y2="128"/><line class="gridfaint" x1="0" y1="${v}" x2="128" y2="${v}"/>`;
            return h;
        }
        function ptSvg(p, lab, isCore, extra = '') {
            if (lab === UNSEEN) return `<circle class="pt unseen${extra}" cx="${p.x}" cy="${p.y}" r="1.7"/>`;
            if (lab === NOISE) {
                const d = 1.5;
                return `<path class="pt noise${extra}" d="M${p.x - d},${p.y - d}L${p.x + d},${p.y + d}M${p.x - d},${p.y + d}L${p.x + d},${p.y - d}"/>`;
            }
            const col = clColor(lab);
            if (isCore) return `<circle class="pt core${extra}" fill="${col}" cx="${p.x}" cy="${p.y}" r="2.3"/>`;
            return `<circle class="pt edge${extra}" fill="${col}" stroke="${col}" cx="${p.x}" cy="${p.y}" r="1.8"/>`;
        }
        const ring = (p, cls, r = 3.9) => `<circle class="ring ${cls}" cx="${p.x}" cy="${p.y}" r="${r}"/>`;
        function textAt(svg, p, text, cls, px) {
            const fs = px / unitPx(svg);
            const right = p.x > 100;
            const ty = p.y < 10 ? p.y + 3.5 + fs * 0.7 : p.y - 3.2;
            return `<text class="${cls}" x="${f2(p.x + (right ? -3 : 3))}" y="${f2(ty)}" font-size="${fs.toFixed(2)}" text-anchor="${right ? 'end' : 'start'}">${text}</text>`;
        }

        function drawMap() {
            const svg = $('map');
            const s = steps[cursor];
            let h = mapBase();
            // 擴張的路線：誰把誰拉進群
            pts.forEach((p, i) => {
                const by = s.pulledBy[i];
                if (by >= 0 && s.label[i] > 0 && s.label[by] === s.label[i]) {
                    h += `<line class="tline" stroke="${clColor(s.label[i])}" x1="${pts[by].x}" y1="${pts[by].y}" x2="${p.x}" y2="${p.y}"/>`;
                }
            });
            const cur = s.p !== undefined && s.kind !== 'done' ? s.p : -1;
            if (s.nb) {
                const p = pts[cur];
                h += `<circle class="eps" cx="${p.x}" cy="${p.y}" r="${eps}"/>`;
                s.nb.forEach(q => { if (q !== cur) h += `<line class="nline" x1="${p.x}" y1="${p.y}" x2="${pts[q].x}" y2="${pts[q].y}"/>`; });
            }
            if (s.kind === 'claim') {
                const f = pts[s.from];
                h += `<circle class="eps old" cx="${f.x}" cy="${f.y}" r="${eps}"/>`;
                h += `<line class="nline" x1="${f.x}" y1="${f.y}" x2="${pts[cur].x}" y2="${pts[cur].y}"/>`;
            }
            h += '<rect class="border" x="0" y="0" width="128" height="128"/>';
            const dimOthers = s.kind === 'done';
            let rings = '', labels = '';
            const added = new Set(s.added || []);
            const inQueue = new Set(s.queue);
            pts.forEach((p, i) => {
                const dim = dimOthers && s.label[i] !== s.c ? ' dim' : '';
                h += ptSvg(p, s.label[i], s.core[i], dim);
                if (i === cur) rings += ring(p, s.kind === 'claim' ? 'claim' : 'cur', 4.4);
                else if (added.has(i)) rings += ring(p, 'add');
                else if (inQueue.has(i)) rings += ring(p, 'queue', 3.5);
            });
            // 點少的時候每個點都標編號，點多時只標目前這個
            const showAll = pts.length <= 30;
            pts.forEach((p, i) => {
                if (i === cur) labels += textAt(svg, p, '#' + i, 'lbl', 12);
                else if (showAll) labels += textAt(svg, p, String(i), 'idx', 9);
            });
            // 比例尺：ε 有多長
            const sx = 4, sy = 123;
            h += rings + labels + `<line class="scale" x1="${sx}" y1="${sy}" x2="${sx + eps}" y2="${sy}"/>` +
                `<line class="scale" x1="${sx}" y1="${sy - 1.5}" x2="${sx}" y2="${sy + 1.5}"/><line class="scale" x1="${sx + eps}" y1="${sy - 1.5}" x2="${sx + eps}" y2="${sy + 1.5}"/>` +
                `<text class="lbl" x="${sx + eps + 2}" y="${sy + 1.5}" font-size="${(11 / unitPx(svg)).toFixed(2)}">ε = ${eps}</text>`;
            svg.innerHTML = h;
        }

        /* =================== 跟 k-means 比 =================== */
        function kmeans(points, k) {
            const n = points.length;
            if (n < k) return null;
            const d2 = (a, b) => (a.x - b.x) ** 2 + (a.y - b.y) ** 2;
            // 起始中心：第 0 個點，之後每次挑離現有中心最遠的點（固定的挑法，每次結果都一樣）
            const C = [{ x: points[0].x, y: points[0].y }];
            while (C.length < k) {
                let best = 0, bd = -1;
                points.forEach((p, i) => { const d = Math.min(...C.map(c => d2(p, c))); if (d > bd) { bd = d; best = i; } });
                C.push({ x: points[best].x, y: points[best].y });
            }
            const asg = new Array(n).fill(-1);
            for (let it = 0; it < 100; it++) {
                let changed = false;
                points.forEach((p, i) => {
                    let bj = 0;
                    C.forEach((c, j) => { if (d2(p, c) < d2(p, C[bj])) bj = j; });
                    if (asg[i] !== bj) { asg[i] = bj; changed = true; }
                });
                C.forEach((c, j) => {
                    const mem = points.filter((_, i) => asg[i] === j);
                    if (mem.length) { c.x = mem.reduce((a, p) => a + p.x, 0) / mem.length; c.y = mem.reduce((a, p) => a + p.y, 0) / mem.length; }
                });
                if (!changed) break;
            }
            return { asg, C };
        }
        function drawCompare() {
            const fin = steps[steps.length - 1];
            const nClusters = fin.c;
            let h = mapBase() + '<rect class="border" x="0" y="0" width="128" height="128"/>';
            pts.forEach((p, i) => { h += ptSvg(p, fin.label[i], fin.core[i]); });
            $('cmp-db').innerHTML = h;
            const noise = fin.label.filter(l => l === NOISE).length;
            $('cap-db').textContent = pts.length ? `DBSCAN：${nClusters} 群＋雜訊 ${noise} 個` : 'DBSCAN';
            const k = Math.max(2, nClusters);
            const km = kmeans(pts, k);
            h = mapBase() + '<rect class="border" x="0" y="0" width="128" height="128"/>';
            if (!km) {
                $('cmp-km').innerHTML = h;
                $('cap-km').textContent = `k-means（k = ${k}）：點太少，跑不起來`;
                return;
            }
            // k-means 的每一群挑「跟它重疊最多的 DBSCAN 群」的顏色，比較好對照
            const colorOf = new Array(k).fill(0), used = new Set();
            const pairs = [];
            for (let j = 0; j < k; j++) for (let c = 1; c <= nClusters; c++) {
                pairs.push({ j, c, n: km.asg.filter((a, i) => a === j && fin.label[i] === c).length });
            }
            pairs.sort((a, b) => b.n - a.n || a.j - b.j || a.c - b.c);
            pairs.forEach(x => { if (!colorOf[x.j] && !used.has(x.c) && x.n) { colorOf[x.j] = x.c; used.add(x.c); } });
            let spare = 1;
            for (let j = 0; j < k; j++) if (!colorOf[j]) { while (used.has(spare)) spare++; colorOf[j] = spare; used.add(spare); }
            pts.forEach((p, i) => { h += `<circle class="pt core" fill="${clColor(colorOf[km.asg[i]])}" cx="${p.x}" cy="${p.y}" r="2.1"/>`; });
            km.C.forEach(c => {
                const d = 3.2, seg = `M${f2(c.x - d)},${f2(c.y)}L${f2(c.x + d)},${f2(c.y)}M${f2(c.x)},${f2(c.y - d)}L${f2(c.x)},${f2(c.y + d)}`;
                h += `<path class="center-bg" d="${seg}"/><path class="center" d="${seg}"/>`;
            });
            $('cmp-km').innerHTML = h;
            $('cap-km').textContent = `k-means（k = ${k}，＋是中心）：每個點都得選一群`;
        }

        /* =================== 換資料 =================== */
        const rnd = (a, b) => a + Math.floor(Math.random() * (b - a + 1));
        function gauss() { let u = 0, v = 0; while (!u) u = Math.random(); while (!v) v = Math.random(); return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v); }
        function finish(raw) {
            const seen = new Set(), out = [];
            raw.forEach(([x, y]) => {
                x = Math.max(2, Math.min(125, Math.round(x))); y = Math.max(2, Math.min(125, Math.round(y)));
                if (seen.has(x + ',' + y)) return;
                seen.add(x + ',' + y);
                out.push({ x, y });
            });
            return out.sort((a, b) => a.x - b.x || a.y - b.y).slice(0, MAX_POINTS);   // 編號照 x 由左到右
        }
        const noisePts = k => Array.from({ length: k }, () => [rnd(4, 123), rnd(4, 123)]);
        const GENERATORS = {
            moons: () => {        // 兩個咬在一起的月牙：上面那個開口朝下、下面那個開口朝上
                const raw = [], m = 28;
                for (let i = 0; i < m; i++) {
                    const t = Math.PI * (i + Math.random() * 0.6) / m, r = 30 + (Math.random() - 0.5) * 5;
                    raw.push([49 - r * Math.cos(t), 66 - r * Math.sin(t)]);
                    raw.push([79 + r * Math.cos(t), 51 + r * Math.sin(t)]);
                }
                return { raw: raw.concat(noisePts(5)), e: 8, m: 4, label: '兩個月牙' };
            },
            rings: () => {        // 同心圓：內圈一個小圓、外圈一個大圓環
                const raw = [];
                for (let i = 0; i < 16; i++) { const t = 2 * Math.PI * (i + Math.random() * 0.5) / 16, r = 14 + (Math.random() - 0.5) * 3; raw.push([64 + r * Math.cos(t), 64 + r * Math.sin(t)]); }
                for (let i = 0; i < 52; i++) { const t = 2 * Math.PI * (i + Math.random() * 0.5) / 52, r = 46 + (Math.random() - 0.5) * 3; raw.push([64 + r * Math.cos(t), 64 + r * Math.sin(t)]); }
                return { raw: raw.concat(noisePts(4)), e: 10, m: 3, label: '同心圓' };
            },
            blobs: () => {        // 幾團圓塊，再撒一些零星的點
                const cs = [];
                const want = rnd(3, 4);
                for (let guard = 0; cs.length < want && guard < 500; guard++) {
                    const c = { x: rnd(22, 106), y: rnd(22, 106) };
                    if (cs.every(o => Math.hypot(o.x - c.x, o.y - c.y) > 42)) cs.push(c);
                }
                const raw = [];
                cs.forEach(c => { const k = rnd(13, 17), sd = rnd(5, 7); for (let i = 0; i < k; i++) raw.push([c.x + gauss() * sd, c.y + gauss() * sd]); });
                return { raw: raw.concat(noisePts(8)), e: 9, m: 4, label: '幾團＋雜訊' };
            }
        };

        $('tools').addEventListener('click', e => {
            const b = e.target.closest('[data-act]');
            if (!b) return;
            const act = b.dataset.act;
            if (GENERATORS[act]) {
                const g = GENERATORS[act]();
                pts = finish(g.raw);
                eps = g.e; minPts = g.m;
                dataChanged(true);
                setHint(`換成「${g.label}」：${pts.length} 個點，ε 和 MinPts 也換成適合這組資料的 ${g.e} 和 ${g.m}。`);
                return;
            }
            if (act === 'clear') { pts = []; dataChanged(true); setHint('清空了。點一下地圖新增點。'); }
            if (act === 'reset') { pts = DEFAULT_POINTS.map(([x, y]) => ({ x, y })); eps = DEFAULT_EPS; minPts = DEFAULT_MINPTS; dataChanged(true); setHint(defaultHint()); }
        });

        /* =================== 在地圖上點一下：新增或刪除 =================== */
        function toWorld(svg, e) {
            const pt = svg.createSVGPoint();
            pt.x = e.clientX; pt.y = e.clientY;
            return pt.matrixTransform(svg.getScreenCTM().inverse());
        }
        const clampW = v => Math.max(0, Math.min(WORLD - 1, Math.round(v)));
        function setHint(text, warn) {
            const el = $('hint');
            el.textContent = text;
            el.classList.toggle('warn', !!warn);
        }
        const defaultHint = () => '點地圖空白處新增一個點，點一下已有的點刪除它；改完會直接跳到結果，按 ⏮ 可以從頭看。';

        function tapMap(svg, e) {
            const w = toWorld(svg, e);
            if (w.x < 0 || w.y < 0 || w.x >= WORLD || w.y >= WORLD) return;
            const hitR = Math.max(3, 13 / unitPx(svg));
            let best = -1, bestD = Infinity;
            pts.forEach((p, i) => { const d = Math.hypot(p.x - w.x, p.y - w.y); if (d < bestD) { bestD = d; best = i; } });
            if (best >= 0 && bestD <= hitR) {
                const p = pts[best];
                pts.splice(best, 1);
                dataChanged(false);
                setHint(`刪掉了 #${best} (${p.x},${p.y})，後面的點編號往前補。`);
                return;
            }
            if (pts.length >= MAX_POINTS) { setHint(`最多 ${MAX_POINTS} 個點，先刪掉一些吧。`, true); return; }
            const p = { x: clampW(w.x), y: clampW(w.y) };
            pts.push(p);
            dataChanged(false);
            setHint(`新增了 #${pts.length - 1} (${p.x},${p.y})，它的編號排在最後，所以最後才輪到它。`);
        }
        (function wireMap() {
            const svg = $('map');
            let start = null;
            svg.addEventListener('pointerdown', e => {
                if (e.button !== undefined && e.button !== 0) return;
                start = { x: e.clientX, y: e.clientY };
            });
            const end = e => {
                if (!start) return;
                const moved = Math.hypot(e.clientX - start.x, e.clientY - start.y);
                start = null;
                if (e.type === 'pointercancel') return;
                if (moved < 8) tapMap(svg, e);
            };
            svg.addEventListener('pointerup', end);
            svg.addEventListener('pointercancel', end);
        })();

        /* =================== 資料或參數改變：重算 trace =================== */
        function rebuild() {
            steps = dbscanTrace(pts, eps, minPts);
        }
        // fromStart：換了一整組資料就從頭看；只加減一個點或調參數就直接看結果
        function dataChanged(fromStart) {
            stopAuto();
            rebuild();
            cursor = fromStart ? 0 : steps.length - 1;
            $('eps-range').value = eps;
            showStep();
            drawCompare();
            reserveExplainHeight();
        }

        /* =================== 程式碼 =================== */
        const KW = {
            java: new Set('public static final for if return new boolean int void class import while else null this double continue'.split(' ')),
            py: new Set('def for in if return not and or while import from as True False None class is lambda continue'.split(' '))
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
                    if (lang === 'java' && /^[A-Z]/.test(word) && !/^[A-Z_]+$/.test(word)) return `<span class="ty">${word}</span>`;
                    return word;
                }
                return esc(m);
            });
            return out + (comment ? `<span class="cm">${esc(comment)}</span>` : '');
        }

        const FILES = { java: ['DBSCAN.java', 'javac DBSCAN.java && java DBSCAN'], py: ['dbscan.py', 'python3 dbscan.py'] };
        function renderCode(tags) {
            if (measuringBlocks || restoringBlocks) return;   // 量區塊高度時不用畫程式碼（程式碼框高度不會變），量完畫回來時它也沒被動過，省時間
            const pre = $('code');
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
            $('downloads').innerHTML = `下載 <a href="code/${file}" download>${file}</a>　執行 <code>${cmd}</code>`;
        }

        /* =================== 顯示某一步 =================== */
        function chip(i, s, cur) {
            const lab = s.label[i];
            let cls = 'chip', style = '';
            if (lab === NOISE) cls += ' noise';
            else if (lab > 0 && s.core[i]) { cls += ' core'; style = `background:${clColor(lab)};border-color:${clColor(lab)}`; }
            else if (lab > 0) { cls += ' edge'; style = `border-color:${clColor(lab)};color:${clColor(lab)}`; }
            if (i === cur) cls += ' cur';
            return `<span class="${cls}"${style ? ` style="${style}"` : ''}>#${i}</span>`;
        }
        function showStep() {
            const s = steps[cursor];
            $('explain').innerHTML = `<span class="step-no">步驟 ${cursor + 1} / ${steps.length}</span>${describe(s)}`;
            drawMap();
            const cur = s.p !== undefined && s.kind !== 'done' ? s.p : -1;
            $('st-clusters').textContent = s.c;
            $('st-core').textContent = s.label.filter((l, i) => l > 0 && s.core[i]).length;
            $('st-edge').textContent = s.label.filter((l, i) => l > 0 && !s.core[i]).length;
            $('st-noise').textContent = s.label.filter(l => l === NOISE).length;
            $('queue').innerHTML = s.queue.length ? s.queue.map(i => chip(i, s, -1)).join('') : '<span class="empty">（空的）</span>';
            $('plist').innerHTML = pts.length ? pts.map((_, i) => chip(i, s, cur)).join('') : '<span class="empty">（還沒有點）</span>';
            $('pt-count').textContent = `${pts.length} 個點`;
            renderCode(TAGS[s.kind] || []);
            $('btn-prev').disabled = $('btn-first').disabled = cursor === 0;
            $('btn-next').disabled = $('btn-last').disabled = cursor === steps.length - 1;
            $('eps-val').textContent = eps;
            $('mp-val').textContent = minPts;
            $('mp-minus').disabled = minPts <= 2;
            $('mp-plus').disabled = minPts >= 10;
        }

        /* 一步一步播放時，各區塊的內容會變多變少（佇列變長、說明變多…）。
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
            const box = $('explain');
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
            reserveBlockHeights(document, steps.length, i => { cursor = i; showStep(); }, () => cursor);
        }

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
            $('btn-play').textContent = '▶ 自動播放';
        }
        $('btn-next').addEventListener('click', () => { stopAuto(); go(1); });
        $('btn-prev').addEventListener('click', () => { stopAuto(); go(-1); });
        $('btn-first').addEventListener('click', () => { stopAuto(); cursor = 0; showStep(); });
        $('btn-last').addEventListener('click', () => { stopAuto(); cursor = steps.length - 1; showStep(); });
        $('btn-play').addEventListener('click', () => {
            if (timer) { stopAuto(); return; }
            if (cursor === steps.length - 1) { cursor = 0; showStep(); }
            $('btn-play').textContent = '⏸ 暫停';
            timer = setInterval(() => { if (!go(1)) stopAuto(); }, 1400);
        });
        document.addEventListener('keydown', e => {
            if (e.target.closest && e.target.closest('input, textarea, select')) return;
            if (e.key === 'ArrowRight') { stopAuto(); go(1); }
            if (e.key === 'ArrowLeft') { stopAuto(); go(-1); }
        });

        $('eps-range').addEventListener('input', e => { eps = Number(e.target.value); dataChanged(false); });
        $('mp-minus').addEventListener('click', () => { if (minPts > 2) { minPts--; dataChanged(false); } });
        $('mp-plus').addEventListener('click', () => { if (minPts < 10) { minPts++; dataChanged(false); } });

        document.querySelector('.lang').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b) return;
            lang = b.dataset.lang;
            document.querySelectorAll('.lang button').forEach(x => x.classList.toggle('active', x.dataset.lang === lang));
            showStep();
        });

        let resizeTimer = null;
        window.addEventListener('resize', () => {
            clearTimeout(resizeTimer);
            resizeTimer = setTimeout(() => { showStep(); drawCompare(); reserveExplainHeight(); }, 150);
        });

        rebuild();
        setHint(defaultHint());
        showStep();
        drawCompare();
        reserveExplainHeight();
    </script>
</body>

</html>
