<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/benchmark.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/benchmark-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/benchmark-180.png">
    <title>效能比賽場：頻繁與高效益樣式探勘</title>
    <meta name="description" content="在瀏覽器裡產生較大的隨機交易資料，實際跑 Apriori、FP-Growth、Eclat 與 Two-Phase、UP-Growth、HUI-Miner、EFIM，畫出門檻對時間、對候選數的圖，並檢查每個演算法的結果完全一致。">
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=Syne:wght@700;800&display=swap');
        /* 手機瀏覽器會自動把某些段落的字放大，表格裡就會一行大一行小；關掉它 */
        html { -webkit-text-size-adjust: 100%; text-size-adjust: 100%; }

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
            --c-level: #f59e0b;   /* 一層一層：Apriori、Two-Phase */
            --c-tree: #06b6d4;    /* 樹：FP-Growth、UP-Growth */
            --c-vert: #a78bfa;    /* 垂直清單：Eclat、HUI-Miner */
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
        @media (max-width: 420px) { .tabs button { padding: 0.5rem 0.6rem; font-size: 0.86rem; } }

        .layout { display: grid; gap: 1rem; margin-top: 1rem; }
        .layout > * { min-width: 0; display: grid; gap: 1rem; align-content: start; }
        .layout > * > * { min-width: 0; }
        @media (min-width: 960px) { .layout { grid-template-columns: 1fr 1.25fr; } }

        .card {
            background: var(--panel);
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 1rem;
        }
        .card-head { display: flex; justify-content: space-between; align-items: center; gap: 0.5rem; flex-wrap: wrap; margin-bottom: 0.7rem; }
        .card-head h2 { margin: 0; }
        .sub { color: var(--muted); font-size: 0.82rem; }

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

        .seg { display: inline-flex; border: 1px solid var(--border); border-radius: 8px; overflow: hidden; flex-shrink: 0; }
        .seg button { background: none; border: none; color: var(--muted); padding: 0.3rem 0.7rem; font: inherit; font-size: 0.84rem; cursor: pointer; }
        .seg button + button { border-left: 1px solid var(--border); }
        .seg button.active { background: rgba(6, 182, 212, 0.16); color: var(--text); }
        .seg button:disabled { cursor: default; }

        /* ── 資料產生器 ── */
        .form { display: grid; gap: 0.55rem; }
        .row { display: grid; grid-template-columns: 7.2em 1fr 4.6em; align-items: center; gap: 0.5rem; font-size: 0.88rem; }
        .row > span:first-child { color: #c6c6d6; }
        .row input[type=range] { width: 100%; min-width: 0; accent-color: var(--accent); }
        .row .v { font: 700 0.85rem 'Space Mono', monospace; text-align: right; white-space: nowrap; }
        .row.wide { grid-template-columns: 7.2em 1fr; }
        .row.dim { opacity: 0.45; }
        .row .hint { color: var(--muted); font-size: 0.75rem; }
        .seed { display: flex; gap: 0.4rem; align-items: center; min-width: 0; }
        .seed .btn { white-space: nowrap; }
        @media (max-width: 420px) { .row { grid-template-columns: 6.3em 1fr 4.3em; font-size: 0.85rem; } .row.wide { grid-template-columns: 6.3em 1fr; } }
        input.num {
            background: #0a0a14;
            color: var(--text);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 0.3rem 0.5rem;
            font: 16px 'Space Mono', monospace;   /* 16px：iPhone 點進輸入框才不會自動放大 */
            width: 6.5em;
            min-width: 0;
        }
        input.num:focus { outline: none; border-color: var(--accent2); }
        input.num:disabled { opacity: 0.45; }
        .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.5rem; margin-top: 0.9rem; }
        .stat { background: var(--panel-2); border-radius: 10px; padding: 0.55rem 0.6rem; min-width: 0; }
        .stat .v { font: 700 1.05rem 'Space Mono', monospace; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .stat .k { color: var(--muted); font-size: 0.75rem; line-height: 1.35; }

        /* ── 比賽設定 ── */
        .thr { display: flex; flex-wrap: wrap; gap: 0.4rem 0.6rem; align-items: center; font-size: 0.88rem; }
        .thr .unit { color: var(--muted); font-size: 0.8rem; }
        .thr input.num { width: 5.2em; }
        .thr-list { font: 0.75rem 'Space Mono', monospace; color: var(--muted); margin-top: 0.45rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .run-row { display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center; margin-top: 0.8rem; }
        .prog { height: 8px; background: var(--panel-2); border-radius: 99px; overflow: hidden; margin-top: 0.8rem; border: 1px solid var(--border); }
        .prog i { display: block; height: 100%; width: 0; background: linear-gradient(90deg, var(--accent), var(--accent2)); transition: width 0.2s; }
        .prog-text { font-size: 0.82rem; color: var(--muted); margin-top: 0.4rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

        /* ── 圖 ── */
        .chart { display: block; width: 100%; height: 250px; }
        .chart text { font-family: 'Space Mono', ui-monospace, monospace; }
        .legend { display: flex; flex-wrap: wrap; gap: 0.3rem 0.9rem; font-size: 0.82rem; margin-top: 0.4rem; color: #c6c6d6; }
        .legend .sw { display: inline-block; width: 18px; height: 3px; border-radius: 2px; vertical-align: middle; margin-right: 0.35rem; }
        .legend .x { color: var(--muted); }
        .pill { font-size: 0.8rem; padding: 0.15rem 0.6rem; border-radius: 99px; border: 1px solid var(--border); color: var(--muted); white-space: nowrap; }
        .pill.ok { color: #86efac; border-color: rgba(34, 197, 94, 0.55); background: rgba(34, 197, 94, 0.12); }
        .pill.no { color: #fca5a5; border-color: rgba(248, 113, 113, 0.55); background: rgba(248, 113, 113, 0.12); }

        /* ── 表格（寬的話只在自己的框裡捲動） ── */
        .tbl-wrap { overflow-x: auto; }
        .cmp { width: 100%; border-collapse: collapse; font-size: 0.8rem; }
        .cmp th, .cmp td { border-bottom: 1px solid var(--border); padding: 0.3rem 0.45rem; text-align: right; white-space: nowrap; }
        .cmp th:first-child, .cmp td:first-child { text-align: left; }
        .cmp th { color: var(--muted); font-weight: 400; }
        .cmp th.grp { text-align: center; color: #c6c6d6; border-bottom: none; }
        .cmp td { color: var(--text); font-family: 'Space Mono', monospace; }
        .cmp td:first-child { font-family: inherit; color: #c6c6d6; }
        .cmp td.fast { color: #86efac; font-weight: 700; }
        .cmp td.to { color: var(--bad); font-family: inherit; }
        .cmp td.skip, .cmp td.wait { color: #4a4a66; font-family: inherit; }
        .cmp td.yes { color: var(--good); }
        .cmp td.noo { color: var(--bad); }
        .cmp .dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; margin-right: 0.3rem; vertical-align: middle; }
        .cmp .lbl { color: var(--muted); font-family: inherit; font-size: 0.75rem; margin-left: 0.3rem; }
        .tbl-gap { height: 0.9rem; }

        /* ── 觀察 ── */
        .explain {
            background: var(--panel-2);
            border-left: 3px solid var(--accent2);
            border-radius: 8px;
            padding: 0.7rem 0.9rem;
            font-size: 0.93rem;
        }
        .explain b { color: var(--warn); font-weight: 600; }
        .explain ul { padding-left: 1.1rem; display: grid; gap: 0.35rem; }
        .explain .muted { color: var(--muted); }

        .full { margin-top: 1rem; display: grid; gap: 1rem; }
        @media (min-width: 960px) { .full { grid-template-columns: 1.5fr 1fr; } }
        .full > * { min-width: 0; }

        .notes { margin-top: 1rem; display: grid; gap: 1rem; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr 1fr; } }
        .notes p, .notes li { color: #c6c6d6; font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; margin-top: 0.5rem; }
        .notes b { color: var(--text); }
        .notes a { color: var(--accent2); }
    </style>
</head>

<body>
    <div class="wrap">
        <a class="back" href="../index.html#research">← RETURN TO PORTFOLIO</a>
        <div class="kicker">RESEARCH DEMO · BENCHMARK</div>
        <h1>效能比賽場<small>資料變大、門檻變低的時候，誰比較快？</small></h1>
        <p class="intro">
            各 Demo 頁用 8 筆交易一步一步看演算法怎麼跑，但資料那麼小，誰快誰慢根本看不出來。這頁在你的瀏覽器裡<b>產生幾百到一萬筆的隨機交易</b>，
            真的把 <a href="apriori.html">Apriori</a>、<a href="fp-growth.html">FP-Growth</a>、<a href="eclat.html">Eclat</a>，
            以及 <a href="two-phase.html">Two-Phase</a>、<a href="up-growth.html">UP-Growth</a>、<a href="high-utility.html">HUI-Miner</a>、<a href="efim.html">EFIM</a> 各跑好幾次，
            畫出「門檻降低時，時間和要算的組合怎麼變」。每個門檻都會檢查同一組的演算法找到的樣式<b>完全一樣</b>，快不是因為少算。
            時間是瀏覽器裡 JavaScript 量的，會受手機、電腦、其他分頁影響，<b>只能看相對的趨勢</b>，不是論文裡的絕對數字。
        </p>

        <div class="tabs" role="tablist">
            <button role="tab" id="tab-freq" data-group="freq" class="active" aria-selected="true"><span class="no">01</span>頻繁樣式</button>
            <button role="tab" id="tab-hui" data-group="hui" aria-selected="false"><span class="no">02</span>高效益樣式</button>
        </div>

        <div class="layout">
            <div>
                <div class="card">
                    <div class="card-head">
                        <h2>資料產生器</h2>
                        <div class="seg" id="src">
                            <button data-v="random" class="active">隨機產生</button>
                            <button data-v="sample">超商 8 筆範例</button>
                        </div>
                    </div>
                    <div class="form">
                        <label class="row rnd"><span>交易數</span><input type="range" id="in-trans" min="200" max="10000" step="200" value="2000"><span class="v" id="v-trans"></span></label>
                        <label class="row rnd"><span>商品種類</span><input type="range" id="in-items" min="10" max="50" step="1" value="30"><span class="v" id="v-items"></span></label>
                        <label class="row rnd"><span>平均交易長度</span><input type="range" id="in-len" min="2" max="20" step="1" value="8"><span class="v" id="v-len"></span></label>
                        <div class="row wide rnd"><span>商品熱門程度</span>
                            <div class="seg" id="dist">
                                <button data-v="uniform">均勻</button>
                                <button data-v="zipf" class="active">偏斜（Zipf）</button>
                            </div>
                        </div>
                        <div class="row wide rnd"><span>隨機種子</span>
                            <div class="seed"><input class="num" type="number" id="in-seed" min="1" max="999999" value="42" inputmode="numeric" aria-label="隨機種子"><button class="btn" id="btn-dice" title="換一個種子">🎲 換一個</button></div>
                        </div>
                        <label class="row rnd hui-only"><span>每樣買幾個</span><input type="range" id="in-qmax" min="1" max="10" step="1" value="5"><span class="v" id="v-qmax"></span></label>
                        <label class="row rnd hui-only"><span>每個賺多少</span><input type="range" id="in-pmax" min="5" max="100" step="5" value="50"><span class="v" id="v-pmax"></span></label>
                        <div class="row wide"><span></span><span class="hint" id="form-hint"></span></div>
                    </div>
                    <div class="stats">
                        <div class="stat"><div class="v" id="ds-n">0</div><div class="k">筆交易</div></div>
                        <div class="stat"><div class="v" id="ds-items">0</div><div class="k">種商品有出現</div></div>
                        <div class="stat"><div class="v" id="ds-len">0</div><div class="k">每筆平均幾樣</div></div>
                        <div class="stat"><div class="v" id="ds-density">0</div><div class="k">密度（平均長度 ÷ 商品數）</div></div>
                        <div class="stat"><div class="v" id="ds-long">0</div><div class="k">最長的一筆</div></div>
                        <div class="stat"><div class="v" id="ds-util">0</div><div class="k">整個資料庫的總效益</div></div>
                    </div>
                </div>

                <div class="card">
                    <div class="card-head">
                        <h2>比賽設定</h2>
                        <span class="sub" id="group-sub"></span>
                    </div>
                    <div class="thr">
                        <span id="thr-name">最小支持度</span>
                        <span>從</span><input class="num" type="number" id="thr-hi" step="0.1" min="0.01" max="100" inputmode="decimal" aria-label="最高門檻">
                        <span>到</span><input class="num" type="number" id="thr-lo" step="0.1" min="0.01" max="100" inputmode="decimal" aria-label="最低門檻">
                        <span class="unit" id="thr-unit">% 的交易</span>
                    </div>
                    <div class="thr-list" id="thr-list"></div>
                    <div class="thr" style="margin-top:0.7rem">
                        <span>每個門檻跑</span>
                        <div class="seg" id="reps">
                            <button data-v="1">1 次</button>
                            <button data-v="3" class="active">3 次</button>
                            <button data-v="5">5 次</button>
                        </div>
                        <span class="unit">取中位數</span>
                    </div>
                    <div class="run-row">
                        <button class="btn primary" id="btn-run">▶ 開始比賽</button>
                        <button class="btn" id="btn-cancel" disabled>■ 取消</button>
                    </div>
                    <div class="prog"><i id="prog-bar"></i></div>
                    <div class="prog-text" id="prog-text"></div>
                </div>
            </div>

            <div>
                <div class="card">
                    <div class="card-head">
                        <h2>門檻 vs. 執行時間</h2>
                        <div class="seg" id="scale">
                            <button data-v="lin">一般刻度</button>
                            <button data-v="log" class="active">對數刻度</button>
                        </div>
                    </div>
                    <svg class="chart" id="chart-time" role="img" aria-label="門檻對執行時間的折線圖"></svg>
                    <div class="legend" id="legend-time"></div>
                </div>
                <div class="card">
                    <div class="card-head">
                        <h2>門檻 vs. 算過的組合數</h2>
                        <span class="pill" id="check">尚未比對</span>
                    </div>
                    <svg class="chart" id="chart-cand" role="img" aria-label="門檻對算過的組合數的折線圖"></svg>
                    <div class="legend" id="legend-cand"></div>
                </div>
            </div>
        </div>

        <div class="full">
            <div class="card">
                <h2>數值表</h2>
                <div class="tbl-wrap"><table class="cmp" id="tbl-main"></table></div>
                <div class="tbl-gap"></div>
                <div class="tbl-wrap"><table class="cmp" id="tbl-algo"></table></div>
            </div>
            <div class="card">
                <h2>這次實驗的觀察</h2>
                <div class="explain" id="obs"></div>
            </div>
        </div>

        <div class="notes">
            <div class="card">
                <h2>怎麼讀這些圖</h2>
                <ul>
                    <li><b>橫軸是門檻，越往左越低。</b>門檻越低，符合條件的樣式越多，每個演算法都要做更多事，所以線通常往左上升。</li>
                    <li><b>對數刻度</b>每往上一格就是 10 倍。在對數圖上一條接近直線往上爬的線，代表工作量是<b>指數</b>成長；兩條線之間的距離固定，代表一個一直是另一個的固定倍數。數字差很多時用對數刻度才看得到小的那條。</li>
                    <li><b>算過的組合</b>：真的去算支持度（或效益、上界）的商品組合有幾個。Apriori、Two-Phase 是數過的候選；Eclat 是做過的交集；FP-Growth 是每棵條件樹數過的商品；HUI-Miner 是建過的 utility list；UP-Growth 是算過上界的組合；EFIM 是做過投影的組合。這個數字跟電腦快慢無關，比時間穩定。</li>
                    <li><b>顏色</b>照做法分：<span style="color:var(--c-level)">橘＝一層一層產生候選</span>、<span style="color:var(--c-tree)">青＝建樹</span>、<span style="color:var(--c-vert)">紫＝垂直清單</span>、<span style="color:#f472b6">粉紅＝投影資料庫（EFIM）</span>。圖上的 ✕ 是那個門檻逾時（單次超過 10 秒）。</li>
                    <li><b>✓ 結果一致</b>：每個門檻都把每個演算法找到的樣式和支持度（效益）做成指紋互相比對，數量與內容都要一樣。</li>
                </ul>
            </div>
            <div class="card">
                <h2>影響效能的因素</h2>
                <ul>
                    <li><b>門檻</b>：最直接。門檻減半，樣式數可能多好幾倍。</li>
                    <li><b>密度</b>（每筆平均買幾樣 ÷ 商品數）：越密，長的樣式越多。Apriori 每多一層就要多掃一次資料庫、多產生一批候選；Eclat 的交易編號清單也會很長。</li>
                    <li><b>分布</b>：Zipf 偏斜時少數商品特別熱門，它們的組合很快就達到門檻，會冒出比較長的樣式；均勻分布時大家都差不多，門檻一跨過去，所有的兩兩組合可能同時變成頻繁。</li>
                    <li><b>交易數</b>：大致是線性的，但會放大「掃描一次資料庫」的成本。</li>
                    <li><b>實作細節</b>：這頁的 Apriori、Two-Phase 用位元遮罩一次判斷一整個組合在不在交易裡，而且整份資料都在記憶體，所以「多掃一次」很便宜。資料放在硬碟、或候選多到用不了位元遮罩時，掃描次數的代價會大很多。FP-Growth、UP-Growth 的樹用 JavaScript 物件做，配置記憶體和垃圾回收也會算進時間。</li>
                </ul>
            </div>
            <div class="card">
                <h2>在實驗室做實驗時要注意</h2>
                <ul>
                    <li><b>固定隨機種子並記下所有參數</b>（交易數、商品數、平均長度、分布、門檻），別人和未來的自己才能重現同一張圖。</li>
                    <li><b>多跑幾次取中位數</b>，第一次通常比較慢（JIT 還沒最佳化、快取是冷的），也要避開同時在跑的其他程式。這頁每個門檻跑 1、3 或 5 次取中位數；跑得太快（< 5 ms）的會連續多跑幾十次取平均，避開計時器解析度不夠。</li>
                    <li><b>記憶體也要量</b>：門檻很低時 Apriori 的候選、FP-Growth 的條件樹、Eclat 的交易編號清單都可能吃光記憶體。Java 可以用 <code>-Xmx</code> 設上限並記錄最大用量，論文通常會同時畫時間和記憶體兩張圖。</li>
                    <li><b>先檢查結果一樣，再比快慢。</b>少找了樣式的程式當然比較快。</li>
                    <li><b>寫清楚逾時上限</b>和門檻是比例（%）還是次數，並用大家都在用的公開資料集（例如 SPMF 網站上的 chess、mushroom、retail），結果才能和其他論文比較。</li>
                </ul>
            </div>
        </div>
    </div>

    <script id="algos-src" type="text/plain">
/*ALGOS_JS*/
    </script>
    <script>
        /* =========================================================
           效能比賽場
           演算法放在上面那段 algos-src 裡：用 Blob URL 建一個 Web Worker 在背景跑，畫面才不會卡住；
           主畫面也用同一份原始碼產生資料、算統計（和給測試用）。
           每一次量測都是一則訊息；超過 10 秒沒有回來，就把 Worker 整個關掉、換一個新的，標示「逾時」。
           ========================================================= */
        const ALGOS_SRC = document.getElementById('algos-src').textContent;
        const BENCH = new Function(ALGOS_SRC + '\nreturn { makeData, dataStats, collect, measure, packData };')();
        const WORKER_URL = URL.createObjectURL(new Blob([ALGOS_SRC], { type: 'text/javascript' }));
        let benchTimeoutMs = 10000;                    // 單次超過這麼久就算逾時

        const $ = id => document.getElementById(id);
        const GROUPS = {
            freq: {
                label: '頻繁樣式', thrName: '最小支持度', thrUnit: '% 的交易', valueName: '支持度',
                algos: [
                    { id: 'apriori', label: 'Apriori', color: '#f59e0b', shape: 'square', struct: '一層最多的候選' },
                    { id: 'fpgrowth', label: 'FP-Growth', color: '#06b6d4', shape: 'tri', struct: '個 FP-tree 節點（含條件樹）' },
                    { id: 'eclat', label: 'Eclat', color: '#a78bfa', shape: 'circle', struct: '筆交易編號（所有清單加總）' }
                ]
            },
            hui: {
                label: '高效益樣式', thrName: '最小效益', thrUnit: '% 的總效益', valueName: '效益',
                algos: [
                    { id: 'twophase', label: 'Two-Phase', color: '#f59e0b', shape: 'square', struct: '個候選要在第二階段驗證' },
                    { id: 'upgrowth', label: 'UP-Growth', color: '#06b6d4', shape: 'tri', struct: '個候選要在第三次掃描驗證' },
                    { id: 'huiminer', label: 'HUI-Miner', color: '#a78bfa', shape: 'circle', struct: '筆 utility list 紀錄（加總）' },
                    { id: 'efim', label: 'EFIM', color: '#f472b6', shape: 'diamond', struct: '筆投影交易（合併後，加總）' }
                ]
            }
        };
        const DEFAULT_THR = {
            random: { freq: [10, 1], hui: [4, 0.5] },
            sample: { freq: [75, 12.5], hui: [40, 10] }
        };
        const POINTS = 6;

        let group = 'freq';
        let spec = { source: 'random', trans: 2000, items: 30, avgLen: 8, dist: 'zipf', seed: 42, qMax: 5, pMax: 50 };
        let thr = { freq: DEFAULT_THR.random.freq.slice(), hui: DEFAULT_THR.random.hui.slice() };
        let reps = 3;
        let logScale = true;
        let stats = null;                       // 目前這份資料的統計（主畫面自己產生一份來算）
        const results = { freq: null, hui: null };
        let prog = { frac: 0, text: '設定好之後按「開始比賽」。資料比較大或門檻比較低時，要跑幾秒到幾十秒。' };
        let running = null;                     // 正在跑哪一組

        /* ---------- 小工具 ---------- */
        const fmtInt = n => Math.round(n).toLocaleString('en-US');
        const fmtMs = ms => ms >= 100 ? fmtInt(ms) : ms >= 10 ? ms.toFixed(1) : ms >= 1 ? ms.toFixed(2) : ms >= 0.001 ? ms.toFixed(3) : '<0.001';
        const fmtPct = p => String(Math.round(p * 100) / 100);
        const fmtShort = v => {
            const a = Math.abs(v);
            if (a >= 1e6) return (v / 1e6).toFixed(a >= 1e7 ? 0 : 1).replace(/\.0$/, '') + 'M';
            if (a >= 1e3) return (v / 1e3).toFixed(a >= 1e4 ? 0 : 1).replace(/\.0$/, '') + 'k';
            if (a >= 1 || a === 0) return String(Math.round(v * 10) / 10);
            return String(Number(v.toPrecision(2)));
        };
        const median = xs => { const s = xs.slice().sort((a, b) => a - b), k = s.length >> 1; return s.length % 2 ? s[k] : (s[k - 1] + s[k]) / 2; };
        const specKey = s => JSON.stringify(s);

        /* 6 個門檻（由低到高的百分比），以及換算成次數 / 效益的絕對門檻 */
        function thresholds(g, st) {
            let [hi, lo] = thr[g];
            const pcts = [];
            for (let k = 0; k < POINTS; k++) pcts.push(Math.round((lo + (hi - lo) * k / (POINTS - 1)) * 1000) / 1000);
            const base = g === 'freq' ? st.n : st.util;
            return { pcts, abs: pcts.map(p => Math.max(1, Math.ceil(p / 100 * base - 1e-9))) };
        }
        const absLabel = (g, v) => g === 'freq' ? fmtInt(v) + ' 筆' : fmtInt(v);

        /* ---------- 資料 ---------- */
        function refreshData() {
            stats = BENCH.dataStats(BENCH.makeData(spec));
            $('ds-n').textContent = fmtInt(stats.n);
            $('ds-items').textContent = fmtInt(stats.items);
            $('ds-len').textContent = stats.avgLen.toFixed(2);
            $('ds-density').textContent = (stats.density * 100).toFixed(1) + '%';
            $('ds-long').textContent = stats.longest + ' 樣';
            $('ds-util').textContent = stats.util >= 1e6 ? (stats.util / 1e6).toFixed(2) + 'M' : fmtInt(stats.util);
        }

        function dataChanged() {
            results.freq = results.hui = null;
            prog = { frac: 0, text: '資料換了，按「開始比賽」重新量。' };
            refreshData();
            render();
        }

        /* ---------- 畫圖（純 SVG） ---------- */
        function marker(shape, x, y, color) {
            if (shape === 'square') return `<rect x="${x - 5.5}" y="${y - 5.5}" width="11" height="11" fill="${color}"/>`;
            if (shape === 'diamond') return `<path d="M${x} ${y - 5}L${x + 5} ${y}L${x} ${y + 5}L${x - 5} ${y}Z" fill="${color}"/>`;
            if (shape === 'tri') return `<path d="M${x} ${y - 5}L${x + 5} ${y + 4}L${x - 5} ${y + 4}Z" fill="${color}"/>`;
            return `<circle cx="${x}" cy="${y}" r="4.2" fill="${color}"/>`;
        }
        function drawChart(svg, g, R, metric) {
            const W = Math.max(240, Math.round(svg.getBoundingClientRect().width) || 520), H = 250;
            const padL = 50, padR = 14, padT = 14, padB = 38;
            const iw = W - padL - padR, ih = H - padT - padB;
            svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
            const out = [];
            const algos = GROUPS[g].algos;
            const vals = [];
            if (R) algos.forEach(a => R.cells[a.id].forEach(c => { if (c.st === 'ok' && c[metric] > 0) vals.push(c[metric]); }));
            const X = k => padL + (POINTS === 1 ? iw / 2 : iw * k / (POINTS - 1));
            // 橫軸：門檻（由低到高）
            const pcts = R ? R.pcts : thresholds(g, stats).pcts;
            pcts.forEach((p, k) => {
                out.push(`<line x1="${X(k)}" y1="${padT}" x2="${X(k)}" y2="${padT + ih}" stroke="#1c1c30"/>`);
                out.push(`<text x="${X(k)}" y="${H - padB + 16}" text-anchor="middle" font-size="11" fill="#8a8aa3">${fmtPct(p)}%</text>`);
            });
            out.push(`<text x="${padL + iw}" y="${H - 4}" text-anchor="end" font-size="10.5" fill="#6a6a85">${GROUPS[g].thrName}（越往左越低）</text>`);
            let Y = null;
            if (vals.length) {
                let lo = Math.min(...vals), hi = Math.max(...vals);
                const ticks = [];
                if (logScale) {
                    const a = Math.floor(Math.log10(lo)), want = Math.max(a + 1, Math.ceil(Math.log10(hi)));
                    const step = Math.ceil((want - a) / 5);
                    let e = a;
                    for (;;) { ticks.push(10 ** e); if (e >= want) break; e += step; }
                    const b = e;
                    Y = v => padT + ih - ih * (Math.log10(v) - a) / (b - a);
                } else {
                    const raw = hi / 4, mag = 10 ** Math.floor(Math.log10(raw)), f = raw / mag;
                    const step = (f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10) * mag;
                    const top = Math.ceil(hi / step) * step;
                    for (let v = 0; v <= top + step / 2; v += step) ticks.push(v);
                    Y = v => padT + ih - ih * v / top;
                }
                ticks.forEach(v => {
                    const y = Y(v);
                    out.push(`<line x1="${padL}" y1="${y}" x2="${padL + iw}" y2="${y}" stroke="#262640"/>`);
                    out.push(`<text x="${padL - 6}" y="${y + 4}" text-anchor="end" font-size="11" fill="#8a8aa3">${fmtShort(v)}</text>`);
                });
            } else {
                out.push(`<line x1="${padL}" y1="${padT + ih}" x2="${padL + iw}" y2="${padT + ih}" stroke="#262640"/>`);
                out.push(`<text x="${padL + iw / 2}" y="${padT + ih / 2}" text-anchor="middle" font-size="12" fill="#6a6a85">${running === g ? '量測中…' : '還沒有資料，按「開始比賽」'}</text>`);
            }
            out.push(`<text x="${padL}" y="${padT - 3}" font-size="10.5" fill="#6a6a85">${metric === 'ms' ? 'ms' : '個'}</text>`);
            if (R && Y) {
                algos.forEach(a => {
                    const cells = R.cells[a.id];
                    let d = '';
                    cells.forEach((c, k) => {
                        if (c.st === 'ok' && c[metric] > 0) d += (d && cells[k - 1] && cells[k - 1].st === 'ok' ? 'L' : 'M') + X(k).toFixed(1) + ' ' + Y(c[metric]).toFixed(1);
                    });
                    // 數字很接近時線會疊在一起：先畫的比較粗、後畫的比較細，疊住了也看得到三條
                    const wd = [5.5, 3.8, 2.4, 1.3][algos.indexOf(a)];
                    if (d) out.push(`<path d="${d}" fill="none" stroke="${a.color}" stroke-width="${wd}" stroke-opacity="0.9" stroke-linejoin="round"/>`);
                    cells.forEach((c, k) => {
                        if (c.st === 'ok' && c[metric] > 0) out.push(marker(a.shape, X(k), Y(c[metric]), a.color));
                        if (c.st === 'timeout' || c.st === 'error') out.push(`<text x="${X(k)}" y="${padT + 10}" text-anchor="middle" font-size="14" font-weight="700" fill="${a.color}">✕</text>`);
                    });
                });
            }
            svg.innerHTML = out.join('');
        }

        function legendHTML(g) {
            return GROUPS[g].algos.map(a => `<span><span class="sw" style="background:${a.color}"></span>${a.label}</span>`).join('') +
                '<span class="x">✕ 逾時</span>';
        }

        /* ---------- 表格 ---------- */
        function cellText(c, metric) {
            if (c.st === 'ok') return [metric === 'ms' ? fmtMs(c.ms) : fmtInt(c.cands), ''];
            return { timeout: ['逾時', 'to'], error: ['失敗', 'to'], skip: ['略過', 'skip'], run: ['…', 'wait'], wait: ['·', 'wait'] }[c.st];
        }
        function renderTables(g, R) {
            const algos = GROUPS[g].algos;
            const P = R ? R.pcts : thresholds(g, stats).pcts;
            const A = R ? R.abs : thresholds(g, stats).abs;
            let h = `<thead><tr><th></th><th></th><th></th><th class="grp" colspan="${algos.length}">時間（ms，中位數）</th><th class="grp" colspan="${algos.length}">算過的組合</th></tr>` +
                `<tr><th>${GROUPS[g].thrName}</th><th>樣式數</th><th>一致</th>` +
                [0, 1].map(() => algos.map(a => `<th><span class="dot" style="background:${a.color}"></span>${a.label}</th>`).join('')).join('') + '</tr></thead><tbody>';
            for (let k = POINTS - 1; k >= 0; k--) {
                const cells = algos.map(a => R ? R.cells[a.id][k] : { st: 'wait' });
                const okMs = cells.filter(c => c.st === 'ok').map(c => c.ms);
                const best = okMs.length > 1 ? Math.min(...okMs) : -1;
                const first = cells.find(c => c.st === 'ok');
                const chk = R ? R.check[k] : null;
                h += `<tr><td>${fmtPct(P[k])}%（${absLabel(g, A[k])}）</td><td>${first ? fmtInt(first.n) : '·'}</td>` +
                    `<td class="${chk === true ? 'yes' : chk === false ? 'noo' : 'wait'}">${chk === true ? '✓' : chk === false ? '✗' : '·'}</td>` +
                    cells.map(c => { const [t, cls] = cellText(c, 'ms'); return `<td class="${cls}${c.st === 'ok' && c.ms === best ? ' fast' : ''}">${t}</td>`; }).join('') +
                    cells.map(c => { const [t, cls] = cellText(c, 'cands'); return `<td class="${cls}">${t}</td>`; }).join('') + '</tr>';
            }
            $('tbl-main').innerHTML = h + '</tbody>';

            // 每個演算法：跑完的最低門檻那一次的細節
            let h2 = `<thead><tr><th>演算法</th><th>最低跑完的門檻</th><th>掃描資料庫</th><th>結構大小</th></tr></thead><tbody>`;
            algos.forEach(a => {
                let k = -1;
                if (R) for (let j = 0; j < POINTS; j++) if (R.cells[a.id][j].st === 'ok') { k = j; break; }
                const c = k >= 0 ? R.cells[a.id][k] : null;
                h2 += `<tr><td><span class="dot" style="background:${a.color}"></span>${a.label}</td>` +
                    (c ? `<td>${fmtPct(R.pcts[k])}%</td><td>${c.scans} 次</td><td>${fmtInt(c.struct)}<span class="lbl">${a.struct}</span></td>`
                        : `<td class="wait">·</td><td class="wait">·</td><td class="wait">·<span class="lbl">${a.struct}</span></td>`) + '</tr>';
            });
            $('tbl-algo').innerHTML = h2 + '</tbody>';
        }

        /* ---------- 觀察：全部由這次實際跑出來的數字產生 ---------- */
        function rankAt(g, R, k) {
            const list = GROUPS[g].algos.map(a => ({ a, c: R.cells[a.id][k] })).filter(x => x.c.st === 'ok').sort((x, y) => x.c.ms - y.c.ms);
            if (list.length < 2) return null;
            const best = list[0];
            const rest = list.slice(1).map(x => `${x.a.label} 是它的 <b>${(x.c.ms / best.c.ms).toFixed(1)}</b> 倍`).join('，');
            const out = GROUPS[g].algos.filter(a => ['timeout', 'error'].includes(R.cells[a.id][k].st)).map(a => a.label);
            return `門檻 <b>${fmtPct(R.pcts[k])}%</b>（${absLabel(g, R.abs[k])}）時：<b>${best.a.label}</b> 最快（${fmtMs(best.c.ms)} ms），${rest}` +
                (out.length ? `；${out.join('、')} 逾時` : '') + '。';
        }
        function observations(g, R) {
            const algos = GROUPS[g].algos;
            if (!R) {
                return ['<span class="muted">按「開始比賽」之後，這裡會用這次實際量到的數字寫出觀察：</span>',
                    '<span class="muted">・最高和最低門檻時，誰最快、慢幾倍</span>',
                    '<span class="muted">・門檻降低時，要算的組合增加多少</span>',
                    '<span class="muted">・每個演算法掃描資料庫幾次</span>',
                    '<span class="muted">・有沒有演算法逾時、結果是否一致</span>'];
            }
            const lines = [];
            const done = R.check.map((c, k) => c !== null ? k : -1).filter(k => k >= 0);
            if (!done.length) lines.push('<span class="muted">還在量第一個門檻…</span>');
            else {
                const bad = done.filter(k => R.check[k] === false);
                lines.push(bad.length
                    ? `<b>✗ 結果不一致</b>：門檻 ${bad.map(k => fmtPct(R.pcts[k]) + '%').join('、')} 的樣式不一樣，請回報這組參數。`
                    : `✓ 跑完的 ${done.length} 個門檻都比對過：每個演算法找到的樣式和${GROUPS[g].valueName}完全一樣。`);
            }
            const ks = [...done].sort((a, b) => a - b);
            const lo = ks.find(k => rankAt(g, R, k)), hi = [...ks].reverse().find(k => rankAt(g, R, k));
            lines.push(lo !== undefined ? '最低：' + rankAt(g, R, lo) : '<span class="muted">最低門檻的比較：還沒有兩個以上的演算法跑完。</span>');
            lines.push(hi !== undefined && hi !== lo ? '最高：' + rankAt(g, R, hi) : '<span class="muted">最高門檻的比較：只有一個門檻有結果。</span>');
            if (ks.length >= 2) {
                const a = ks[ks.length - 1], b = ks[0];
                const n0 = (algos.map(x => R.cells[x.id][a]).find(c => c.st === 'ok') || {}).n, n1 = (algos.map(x => R.cells[x.id][b]).find(c => c.st === 'ok') || {}).n;
                const first = algos[0], c0 = R.cells[first.id][a], c1 = R.cells[first.id][b];
                let s = `門檻從 ${fmtPct(R.pcts[a])}% 降到 ${fmtPct(R.pcts[b])}%，樣式從 <b>${fmtInt(n0 || 0)}</b> 個變成 <b>${fmtInt(n1 || 0)}</b> 個`;
                if (c0.st === 'ok' && c1.st === 'ok') s += `；${first.label} 算過的組合從 ${fmtInt(c0.cands)} 個變成 <b>${fmtInt(c1.cands)}</b> 個（×${(c1.cands / Math.max(1, c0.cands)).toFixed(1)}）`;
                const cs = algos.map(x => R.cells[x.id][b]).filter(c => c.st === 'ok').map(c => c.cands);
                if (cs.length === algos.length) {
                    const spread = (Math.max(...cs) - Math.min(...cs)) / Math.max(...cs);
                    s += spread < 0.15
                        ? `。最低門檻時 ${algos.length} 個演算法算過的組合數只差 ${(spread * 100).toFixed(0)}%（所以圖上的線幾乎疊在一起），時間的差別主要來自<b>每算一個組合要花多少功夫</b>`
                        : `。最低門檻時算過的組合數最多和最少差 <b>${(1 / (1 - spread)).toFixed(1)}</b> 倍`;
                }
                if (g === 'hui') {
                    const tp = R.cells.twophase[b], up = R.cells.upgrowth[b];
                    if (tp.st === 'ok') s += `。最低門檻時 Two-Phase 第一階段留下 ${fmtInt(tp.struct)} 個候選，真正高效益的只有 ${fmtInt(tp.n)} 個` +
                        (up.st === 'ok' ? `；UP-Growth 收緊上界後要驗證的是 ${fmtInt(up.struct)} 個` : '');
                }
                lines.push(s + '。');
            } else lines.push('<span class="muted">要至少兩個門檻跑完，才看得出組合數怎麼增加。</span>');
            const scanLine = algos.map(a => {
                let k = -1;
                for (let j = 0; j < POINTS; j++) if (R.cells[a.id][j].st === 'ok') { k = j; break; }
                return k >= 0 ? `${a.label} ${R.cells[a.id][k].scans} 次` : null;
            }).filter(Boolean);
            lines.push(scanLine.length ? `掃描資料庫次數（各自跑完的最低門檻）：${scanLine.join('、')}。` : '<span class="muted">掃描次數：還沒有結果。</span>');
            const tos = algos.map(a => {
                const k = R.cells[a.id].findIndex(c => c.st === 'timeout' || c.st === 'error');
                return k >= 0 ? `${a.label} 在 ${fmtPct(R.pcts[k])}% ${R.cells[a.id][k].st === 'timeout' ? '超過 ' + benchTimeoutMs / 1000 + ' 秒' : '執行失敗（可能是記憶體不夠）'}，更低的門檻就略過` : null;
            }).filter(Boolean);
            lines.push(tos.length ? `逾時：${tos.join('；')}。` : (R.cancelled ? '比賽中途取消了，表格裡「·」的是沒跑到的。' : '沒有演算法逾時。'));
            return lines;
        }

        /* ---------- 整頁畫面 ---------- */
        function render(view) {
            const g = view ? view.group : group;
            const R = view ? view.R : results[g];
            const P = view ? view.prog : prog;
            const G = GROUPS[g];
            const src = view && view.source || spec.source;
            document.querySelectorAll('.tabs button').forEach(b => {
                const on = b.dataset.group === g;
                b.classList.toggle('active', on);
                b.setAttribute('aria-selected', on);
            });
            $('group-sub').textContent = G.algos.map(a => a.label).join(' · ');
            $('thr-name').textContent = G.thrName;
            $('thr-unit').textContent = G.thrUnit;
            if (document.activeElement !== $('thr-hi')) $('thr-hi').value = thr[g][0];
            if (document.activeElement !== $('thr-lo')) $('thr-lo').value = thr[g][1];
            const T = thresholds(g, stats);
            $('thr-list').textContent = '門檻：' + [...T.abs].reverse().map(v => absLabel(g, v)).join(' → ');
            document.querySelectorAll('.hui-only').forEach(r => r.classList.toggle('dim', g !== 'hui' || src !== 'random'));
            $('form-hint').textContent = src === 'sample'
                ? '用各 Demo 頁同一份 8 筆交易（數量、利潤也一樣），可以拿表格的樣式數跟那些頁對照。'
                : g === 'hui' ? '數量 1 ～ 上限、利潤 1 ～ 上限，都由同一個種子決定。' : '最後兩列（數量、利潤）只有高效益組會用到。';
            $('prog-bar').style.width = (P.frac * 100).toFixed(1) + '%';
            $('prog-text').textContent = P.text;
            drawChart($('chart-time'), g, R, 'ms');
            drawChart($('chart-cand'), g, R, 'cands');
            $('legend-time').innerHTML = $('legend-cand').innerHTML = legendHTML(g);
            const done = R ? R.check.filter(c => c !== null) : [];
            const pill = $('check');
            pill.className = 'pill' + (done.length ? (done.every(Boolean) ? ' ok' : ' no') : '');
            pill.textContent = done.length ? (done.every(Boolean) ? `✓ 結果一致（${done.length}/${POINTS} 個門檻）` : '✗ 結果不一致') : '尚未比對';
            renderTables(g, R);
            $('obs').innerHTML = '<ul>' + observations(g, R).map(s => `<li>${s}</li>`).join('') + '</ul>';
            const busy = running !== null;
            $('btn-run').disabled = busy;
            $('btn-cancel').disabled = !busy;
            $('btn-run').textContent = `▶ 開始比賽（${G.label}組）`;
            document.querySelectorAll('.form input, .form button, #thr-hi, #thr-lo, #reps button, #src button').forEach(el => {
                el.disabled = busy || (el.closest('.rnd') && spec.source !== 'random');
            });
        }

        /* ---------- Worker：每次量測一則訊息，逾時就換一個新的 ---------- */
        let worker = null, pending = null, msgId = 0, workerData = null;
        function newWorker() {
            if (worker) worker.terminate();
            worker = new Worker(WORKER_URL);
            workerData = null;
            worker.onmessage = e => {
                if (pending && e.data.id === pending.id) { const p = pending; pending = null; clearTimeout(p.timer); p.resolve(e.data); }
            };
            worker.onerror = e => {
                e.preventDefault();
                if (pending) { const p = pending; pending = null; clearTimeout(p.timer); p.resolve({ ok: false, error: e.message || 'worker error' }); }
                newWorker();
            };
        }
        function ask(msg, limit) {
            return new Promise(resolve => {
                const id = ++msgId;
                pending = { id, resolve, timer: null };
                if (limit) pending.timer = setTimeout(() => {
                    if (pending && pending.id === id) { pending = null; newWorker(); resolve({ ok: false, timeout: true }); }
                }, limit);
                worker.postMessage(Object.assign({ id }, msg));
            });
        }
        function cancelRun() {
            if (!running) return;
            cancelled = true;
            if (pending) { const p = pending; pending = null; clearTimeout(p.timer); p.resolve({ ok: false, cancelled: true }); }
            newWorker();
        }

        let cancelled = false;
        async function runBench() {
            if (running) return;
            const g = group, algos = GROUPS[g].algos, key = specKey(spec);
            const T = thresholds(g, stats);
            const R = { pcts: T.pcts, abs: T.abs, cells: {}, check: T.pcts.map(() => null), cancelled: false };
            algos.forEach(a => { R.cells[a.id] = T.pcts.map(() => ({ st: 'wait' })); });
            results[g] = R;
            running = g;
            cancelled = false;
            if (!worker) newWorker();
            const total = POINTS * algos.length * reps;
            let done = 0;
            const t0 = performance.now();
            const dead = {};
            prog = { frac: 0, text: '準備資料…' };
            render();
            outer:
            for (let k = POINTS - 1; k >= 0; k--) {
                for (const a of algos) {
                    const cell = R.cells[a.id][k];
                    if (dead[a.id]) { cell.st = 'skip'; done += reps; continue; }
                    cell.st = 'run';
                    const times = [];
                    for (let r = 0; r < reps; r++) {
                        if (workerData !== key) {
                            const d = await ask({ cmd: 'data', spec });
                            if (cancelled) break outer;
                            if (!d.ok) { cell.st = 'error'; dead[a.id] = true; break; }
                            workerData = key;
                        }
                        prog = { frac: done / total, text: `門檻 ${POINTS - k}/${POINTS}（${fmtPct(R.pcts[k])}%）· ${a.label} 第 ${r + 1}/${reps} 次` };
                        render();
                        const res = await ask({ cmd: 'run', group: g, algo: a.id, thr: R.abs[k] }, benchTimeoutMs);
                        if (cancelled) { cell.st = times.length ? cell.st : 'wait'; break outer; }
                        if (!res.ok) {
                            cell.st = res.timeout ? 'timeout' : 'error';
                            dead[a.id] = true;
                            done += reps - r;
                            break;
                        }
                        times.push(res.res.ms);
                        Object.assign(cell, res.res, { st: 'ok', ms: median(times), runs: times.length });
                        done++;
                    }
                }
                // 這個門檻每個演算法都跑完了：比對結果的指紋
                const fps = algos.map(a => R.cells[a.id][k]).filter(c => c.st === 'ok').map(c => c.fp);
                R.check[k] = fps.length ? fps.every(f => f === fps[0]) : null;
            }
            running = null;
            R.cancelled = cancelled;
            const secs = ((performance.now() - t0) / 1000).toFixed(1);
            prog = cancelled
                ? { frac: done / total, text: `已取消（跑了 ${secs} 秒），保留已經量到的結果。` }
                : { frac: 1, text: `完成：${GROUPS[g].label}組 ${POINTS} 個門檻 × ${algos.length} 個演算法 × ${reps} 次，共花 ${secs} 秒。` };
            render();
        }

        /* ---------- 區塊高度：先用「最長的內容」各畫一次，把每個區塊的高度固定住 ----------
           跑完前後、切換分頁時，表格、觀察、進度文字的長短都不同；用最高的那次固定，
           區塊變長變短才不會把旁邊或下面的東西推來推去。 */
        function fakeResult(g, variant) {
            const algos = GROUPS[g].algos;
            const R = { pcts: [0.123, 12.345, 24.567, 36.789, 48.901, 99.999], abs: [9999999, 9999999, 9999999, 9999999, 9999999, 9999999], cells: {}, check: [], cancelled: variant === 2 };
            algos.forEach((a, i) => {
                R.cells[a.id] = R.pcts.map((_, k) => {
                    if (variant >= 1 && i === 0 && k < 2) return { st: k === 1 ? 'timeout' : 'skip' };
                    if (variant === 2 && i === 2 && k === 0) return { st: 'error' };
                    return { st: 'ok', ms: 12345.6 / (k + 1) / (i + 1), n: 9999999, fp: 'x', cands: 9999999 - k, struct: 99999999, scans: 99 };
                });
            });
            R.check = R.pcts.map((_, k) => variant === 1 && k === 3 ? false : true);
            return R;
        }
        const FAKE_VIEWS = [];
        ['freq', 'hui'].forEach(g => {
            FAKE_VIEWS.push({ group: g, R: null, prog: { frac: 0, text: '資料換了，按「開始比賽」重新量。' } });
            FAKE_VIEWS.push({ group: g, R: null, source: 'sample', prog: { frac: 0, text: '資料換了，按「開始比賽」重新量。' } });
            [0, 1, 2].forEach(v => FAKE_VIEWS.push({ group: g, R: fakeResult(g, v), prog: { frac: 0.5, text: '門檻 6/6（99.99%）· FP-Growth 第 5/5 次 · 已經跑了很久很久很久很久很久很久' } }));
        });

        let measuringBlocks = false, blockJob = 0;
        function reserveBlockHeights(scope, count, showAt, current) {
            const job = ++blockJob;
            const blocks = [...scope.querySelectorAll('.card')].filter(b => !b.closest('[hidden]'));
            if (!blocks.length || count < 2) return;
            const passes = scope.querySelector('.card .card') ? 2 : 1;   // 區塊裡還有區塊時，第二輪把外層補足
            let base = blocks.map(() => ''), tallest = blocks.map(() => 0), i = 0, pass = 0;
            const chunk = () => {
                if (job !== blockJob) return;   // 資料或參數又變了，這一輪作廢
                const cur = current(), shown = blocks.map(b => b.style.minHeight);
                const until = performance.now() + 25;
                measuringBlocks = true;
                blocks.forEach((b, k) => { b.style.minHeight = base[k]; });
                while (pass < passes && performance.now() < until) {
                    showAt(i);
                    blocks.forEach((b, k) => { tallest[k] = Math.max(tallest[k], Math.ceil(b.getBoundingClientRect().height)); });
                    if (++i === count) {
                        i = 0; pass++;
                        base = tallest.map(h => h + 'px');
                        blocks.forEach((b, k) => { b.style.minHeight = base[k]; });
                    }
                }
                measuringBlocks = false;
                blocks.forEach((b, k) => { b.style.minHeight = pass < passes ? shown[k] : base[k]; });
                showAt(cur);
                if (pass < passes) setTimeout(chunk, 0);
            };
            chunk();
        }
        function reserveAll() {
            document.querySelectorAll('.card').forEach(b => { b.style.minHeight = ''; });
            // 最後一個「狀態」是真正的畫面（-1）
            reserveBlockHeights(document, FAKE_VIEWS.length, i => render(i < 0 ? null : FAKE_VIEWS[i]), () => -1);
        }

        /* ---------- 操作 ---------- */
        function segPick(id, v) { [...$(id).children].forEach(b => b.classList.toggle('active', b.dataset.v === String(v))); }
        document.querySelector('.tabs').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b) return;
            group = b.dataset.group;
            render();
        });
        $('src').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b || b.disabled || b.dataset.v === spec.source) return;
            spec = Object.assign({}, spec, { source: b.dataset.v });
            segPick('src', spec.source);
            thr = { freq: DEFAULT_THR[spec.source].freq.slice(), hui: DEFAULT_THR[spec.source].hui.slice() };
            dataChanged();
        });
        $('dist').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b || b.disabled) return;
            spec = Object.assign({}, spec, { dist: b.dataset.v });
            segPick('dist', spec.dist);
            dataChanged();
        });
        const SLIDERS = { 'in-trans': 'trans', 'in-items': 'items', 'in-len': 'avgLen', 'in-qmax': 'qMax', 'in-pmax': 'pMax' };
        function showSliders() {
            $('v-trans').textContent = fmtInt(spec.trans);
            $('v-items').textContent = spec.items;
            $('v-len').textContent = Math.min(spec.avgLen, spec.items);
            $('v-qmax').textContent = '1～' + spec.qMax;
            $('v-pmax').textContent = '$1～' + spec.pMax;
        }
        let sliderTimer = null;
        Object.entries(SLIDERS).forEach(([id, k]) => {
            $(id).addEventListener('input', e => {
                spec = Object.assign({}, spec, { [k]: Number(e.target.value) });
                showSliders();
                clearTimeout(sliderTimer);
                sliderTimer = setTimeout(dataChanged, 120);   // 拖動時不要每一格都重新產生資料
            });
        });
        $('in-seed').addEventListener('change', e => {
            const v = Math.max(1, Math.min(999999, Math.round(Number(e.target.value)) || 1));
            e.target.value = v;
            spec = Object.assign({}, spec, { seed: v });
            dataChanged();
        });
        $('btn-dice').addEventListener('click', () => {
            const v = 1 + Math.floor(Math.random() * 999999);
            $('in-seed').value = v;
            spec = Object.assign({}, spec, { seed: v });
            dataChanged();
        });
        function readThr() {
            let hi = Number($('thr-hi').value), lo = Number($('thr-lo').value);
            if (!(hi > 0)) hi = thr[group][0];
            if (!(lo > 0)) lo = thr[group][1];
            hi = Math.min(100, Math.max(0.01, hi)); lo = Math.min(100, Math.max(0.01, lo));
            if (lo > hi) [lo, hi] = [hi, lo];
            thr[group] = [hi, lo];
            results[group] = null;
            prog = { frac: 0, text: '門檻改了，按「開始比賽」重新量。' };
            render();
        }
        $('thr-hi').addEventListener('change', readThr);
        $('thr-lo').addEventListener('change', readThr);
        $('reps').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b || b.disabled) return;
            reps = Number(b.dataset.v);
            segPick('reps', reps);
        });
        $('scale').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b) return;
            logScale = b.dataset.v === 'log';
            segPick('scale', b.dataset.v);
            render();
        });
        $('btn-run').addEventListener('click', runBench);
        $('btn-cancel').addEventListener('click', cancelRun);

        let resizeTimer = null, lastW = window.innerWidth;
        window.addEventListener('resize', () => {
            clearTimeout(resizeTimer);
            resizeTimer = setTimeout(() => {
                if (window.innerWidth !== lastW) { lastW = window.innerWidth; reserveAll(); } else render();
            }, 150);
        });

        showSliders();
        refreshData();
        render();
        reserveAll();
        if (document.fonts && document.fonts.ready) document.fonts.ready.then(reserveAll);
    </script>
</body>

</html>
