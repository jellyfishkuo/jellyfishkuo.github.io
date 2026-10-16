<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/two-phase.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/two-phase-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/two-phase-180.png">
    <title>Two-Phase 高效益樣式探勘</title>
    <meta name="description" content="一步一步看 Two-Phase 怎麼找高效益樣式：第一階段用有向下封閉性的 TWU 當上界，照 Apriori 的方式一層一層產生候選；第二階段再掃一次資料庫算真正的效益。Java 與 Python 程式碼逐行對照，並和 HUI-Miner 比較。">
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

        /* 手機：一欄，依序 步驟 → 交易 → 候選 → 程式碼 → 結果
           電腦：左欄 步驟／交易，右欄 候選／程式碼／結果 */
        .layout { display: grid; gap: 1rem; margin-top: 1.3rem; align-items: start; }
        .col { display: contents; }
        .layout .card { min-width: 0; }
        .a-step { order: 1; }
        .a-data { order: 2; }
        .a-cands { order: 3; }
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
        .phase { display: inline-block; font: 700 0.7rem 'Space Mono', monospace; border-radius: 5px; padding: 0 0.4rem; margin-left: 0.4rem; background: rgba(6, 182, 212, 0.15); color: #67e8f9; }
        .phase.p2 { background: rgba(245, 158, 11, 0.18); color: #fcd34d; }
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

        /* ── 這一層的候選（可以點） ── */
        .cands { display: flex; flex-wrap: wrap; gap: 0.4rem; margin-top: 0.8rem; min-height: 2.2rem; }
        .cand {
            display: inline-flex;
            align-items: center;
            flex-wrap: wrap;
            gap: 0.1rem 0.4rem;
            border: 1px solid var(--border);
            background: var(--panel-2);
            border-radius: 8px;
            padding: 0.25rem 0.6rem;
            font-size: 0.85rem;
            cursor: pointer;
            color: var(--text);
            text-align: left;
            font-family: inherit;
            max-width: 100%;
        }
        .cand:hover { border-color: var(--accent2); }
        .cand.sel { border-color: var(--warn); box-shadow: 0 0 0 1px var(--warn) inset; }
        .cand .n { font: 700 0.78rem 'Space Mono', monospace; padding: 0 0.35rem; border-radius: 5px; background: #2a2a48; }
        .cand.ok { border-color: rgba(34, 197, 94, 0.55); }
        .cand.ok .n { background: rgba(34, 197, 94, 0.25); color: #86efac; }
        .cand.out { opacity: 0.6; }
        .cand.out .nm { text-decoration: line-through; }
        .cand.out .n { background: rgba(248, 113, 113, 0.2); color: #fca5a5; }
        .cand .why { color: var(--muted); font-size: 0.75rem; }
        .cands-note { color: var(--muted); font-size: 0.8rem; }
        .sel-hint { color: var(--muted); font-size: 0.8rem; margin-top: 0.5rem; min-height: 1.3em; }
        .sel-hint b { color: var(--warn); font-weight: 600; }

        /* ── 交易資料庫 ── */
        .db { width: 100%; table-layout: fixed; border-collapse: separate; border-spacing: 0 3px; }
        /* 欄寬固定：商品欄平分，不會因為「茶葉蛋」「洋芋片」三個字就比較寬 */
        .db th.tid-h { width: 2rem; }
        .db th.tu-h { width: 2.4rem; }
        .db th { font-weight: 400; color: var(--muted); font-size: clamp(0.6rem, 3vw, 0.72rem); white-space: nowrap; padding: 0 1px 4px; text-align: center; line-height: 1.25; vertical-align: bottom; }
        .db th .emo { display: block; font-size: 1.2rem; }
        .db th .pf { display: block; font: 700 0.7rem 'Space Mono', monospace; color: #fcd34d; margin-top: 0.1rem; }
        .db th.sel { color: var(--warn); }
        .db th.off, .db td.twu.out { opacity: 0.4; }
        .db th.off .nm { text-decoration: line-through; }
        .db td { text-align: center; padding: 0; }
        .db td.tid { font: 0.76rem 'Space Mono', monospace; color: var(--muted); text-align: left; width: 2.4em; padding-left: 0.3rem; }
        .db td.tu { font: 700 0.78rem 'Space Mono', monospace; color: var(--accent2); width: 2.8em; }
        .db td.tu.sel, .db th.tu-h.sel { color: var(--warn); }
        .db tr.match td { background: rgba(245, 158, 11, 0.12); }
        .db tr.match td:first-child { border-radius: 8px 0 0 8px; color: var(--warn); }
        .db tr.match td:last-child { border-radius: 0 8px 8px 0; }
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
        .cell.has { background: #2a2a48; }
        .cell.off { opacity: 0.35; text-decoration: line-through; }
        .cell.hit { background: rgba(245, 158, 11, 0.38); }
        .cell small { font-size: 0.62rem; font-weight: 400; color: #fcd34d; }
        .db-note { color: var(--muted); font-size: 0.78rem; margin-top: 0.5rem; }

        /* ── 候選清單：TWU（上界）對真正的效益 ── */
        .clist { display: grid; gap: 0.15rem; max-height: 520px; overflow: auto; padding-right: 0.2rem; }
        .clist-empty { color: var(--muted); font-size: 0.85rem; padding: 1.2rem 0.3rem; text-align: center; }
        .clv { font: 700 0.74rem 'Space Mono', monospace; color: var(--accent2); margin-top: 0.45rem; }
        .clv:first-child { margin-top: 0; }
        .crow {
            display: block; width: 100%; text-align: left; font-family: inherit; color: var(--text);
            background: none; border: 1px solid transparent; border-radius: 8px; padding: 0.25rem 0.4rem; cursor: pointer;
        }
        .crow:hover { border-color: var(--border); }
        .crow.sel { border-color: var(--warn); }
        .crow.fresh { background: rgba(6, 182, 212, 0.08); }
        .cr-top { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 0 0.6rem; font-size: 0.82rem; }
        .cr-num { font: 0.72rem 'Space Mono', monospace; color: var(--muted); }
        .cr-num b { color: var(--text); }
        .cr-tag { font-size: 0.7rem; border-radius: 5px; padding: 0 0.35rem; margin-left: 0.35rem; }
        .crow.hui .cr-tag { background: rgba(34, 197, 94, 0.22); color: #86efac; }
        .crow.loose .cr-tag { background: rgba(248, 113, 113, 0.18); color: #fca5a5; }
        .crow.loose .cr-name { color: var(--muted); }
        .bar { position: relative; height: 9px; margin-top: 0.2rem; border-radius: 5px; background: #12121f; }
        .bar .b-twu { position: absolute; left: 0; top: 0; bottom: 0; border-radius: 5px; border: 1.5px dashed rgba(6, 182, 212, 0.65); }
        .bar .b-u { position: absolute; left: 0; top: 0; bottom: 0; border-radius: 5px; background: var(--good); }
        .crow.loose .bar .b-u { background: var(--bad); }
        .bar .b-mu { position: absolute; top: -3px; bottom: -3px; width: 2px; margin-left: -1px; background: var(--warn); }
        .legend { display: flex; flex-wrap: wrap; gap: 0.3rem 0.9rem; font-size: 0.75rem; color: var(--muted); margin-top: 0.55rem; }
        .legend i { display: inline-block; width: 14px; height: 9px; border-radius: 3px; margin-right: 0.3rem; vertical-align: 0; }
        .loose-sum { font-size: 0.82rem; color: #c6c6d6; margin-top: 0.5rem; min-height: 1.3em; }
        .loose-sum b { color: var(--warn); font-weight: 600; }

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
            max-height: 520px;
            font: 0.78rem/1.7 'Space Mono', ui-monospace, monospace;
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

        /* ── 結果 ── */
        .levels { display: grid; gap: 0.45rem; }
        .level { display: grid; grid-template-columns: 2.8em 1fr; gap: 0.5rem; align-items: start; }
        .level .tag { font: 700 0.8rem 'Space Mono', monospace; color: var(--accent2); padding-top: 0.2rem; }
        .level .items { display: flex; flex-wrap: wrap; gap: 0.35rem; min-width: 0; }
        .pat { font-size: 0.82rem; border: 1px solid rgba(34, 197, 94, 0.5); border-radius: 7px; padding: 0.12rem 0.5rem; }
        .pat .n { font: 700 0.74rem 'Space Mono', monospace; margin-left: 0.35rem; color: #86efac; }
        .empty { color: var(--muted); font-size: 0.85rem; }
        .stats { display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.5rem; margin-top: 0.9rem; }
        @media (min-width: 600px) { .stats { grid-template-columns: repeat(4, 1fr); } }
        .stat { background: var(--panel-2); border-radius: 10px; padding: 0.55rem 0.6rem; min-width: 0; }
        .stat .v { font: 700 1.25rem 'Space Mono', monospace; }
        .stat .k { color: var(--muted); font-size: 0.75rem; line-height: 1.35; }
        .compare { margin-top: 0.9rem; font-size: 0.85rem; color: var(--muted); }
        .compare h3 { font-size: 0.9rem; color: var(--text); margin-bottom: 0.45rem; }
        .compare a { color: var(--accent2); }
        .cmp { width: 100%; border-collapse: collapse; margin-top: 0.5rem; font-size: 0.8rem; }
        .cmp th, .cmp td { border-bottom: 1px solid var(--border); padding: 0.3rem 0.35rem; text-align: right; }
        .cmp th:first-child, .cmp td:first-child { text-align: left; }
        .cmp th { color: var(--muted); font-weight: 400; }
        .cmp td { color: var(--text); font-family: 'Space Mono', monospace; }
        .cmp td:first-child { font-family: inherit; color: var(--muted); }

        .notes { margin-top: 1rem; display: grid; gap: 1rem; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr; } }
        .notes p, .notes li { color: #c6c6d6; font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; margin-top: 0.5rem; }
        .notes b { color: var(--text); }
        .notes a { color: var(--accent2); }
    </style>
</head>

<body>
    <div class="wrap">
        <a class="back" href="../index.html#research">← RETURN TO PORTFOLIO</a>
        <div class="kicker">RESEARCH DEMO · TWO-PHASE HIGH-UTILITY MINING</div>
        <h1>Two-Phase 高效益樣式探勘<small>先用上界一層一層挑候選，最後再算一次真的</small></h1>
        <p class="intro">
            跟 <a href="high-utility.html">HUI-Miner</a> 頁同一間超商、同樣 8 筆交易、同樣的購買數量和單位利潤。
            高效益樣式的麻煩是效益<b>沒有向下封閉性</b>：組合變大，效益可能反而變高，所以不能像 <a href="apriori.html">Apriori</a> 那樣看到不夠就剪。
            <b>Two-Phase</b>（Liu 等人，2005）是在 HUI-Miner 之前的經典解法：改用一個<b>有</b>向下封閉性的上界 <b>TWU</b>，
            <b>第一階段</b>完全照 Apriori 一層一層合併、剪枝、掃資料庫，找出 TWU 夠的組合當候選；<b>第二階段</b>再掃一次資料庫，算出候選真正的效益，留下真的夠的。
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
                        <span>最小效益門檻</span>
                        <button class="btn stepper" id="mu-minus" aria-label="減少">−</button>
                        <span class="val" id="mu-val">250</span>
                        <button class="btn stepper" id="mu-plus" aria-label="增加">+</button>
                        <input type="range" id="mu-range" min="100" max="500" step="10" value="250" aria-label="最小效益門檻">
                        <span class="pct" id="mu-pct"></span>
                    </div>
                    <div class="explain" id="explain"></div>
                    <div class="cands" id="cands"></div>
                    <div class="sel-hint" id="hint-step"></div>
                </div>

                <div class="card a-data">
                    <div class="card-head"><h2>交易資料庫</h2><span class="sub" id="db-sub"></span></div>
                    <table class="db" id="db"></table>
                    <p class="db-note">格子裡是購買數量，商品下面是單位利潤；TU 是這筆交易的總效益，TWU 是有買這個商品的交易 TU 加起來。點上面的候選，會標出它出現在哪幾筆，格子裡的小字是那一樣的效益。</p>
                </div>
            </div>

            <div class="col">
                <div class="card a-cands">
                    <div class="card-head"><h2>候選：TWU 對真正的效益</h2><span class="sub" id="cl-sub"></span></div>
                    <div class="clist" id="clist"></div>
                    <div class="legend">
                        <span><i style="border:1.5px dashed rgba(6,182,212,0.65)"></i>TWU（上界）</span>
                        <span><i style="background:var(--good)"></i>真正效益，夠</span>
                        <span><i style="background:var(--bad)"></i>真正效益，不夠</span>
                        <span><i style="background:var(--warn);width:3px"></i>門檻</span>
                    </div>
                    <div class="loose-sum" id="loose-sum"></div>
                    <div class="sel-hint" id="hint-list"></div>
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
                    <h2>目前找到的高效益樣式</h2>
                    <div class="levels" id="levels"></div>
                    <div class="stats">
                        <div class="stat"><div class="v" id="st-scan">0</div><div class="k">掃描資料庫次數</div></div>
                        <div class="stat"><div class="v" id="st-count">0</div><div class="k">算過 TWU 的組合</div></div>
                        <div class="stat"><div class="v" id="st-cand">0</div><div class="k">第一階段的候選（TWU 夠）</div></div>
                        <div class="stat"><div class="v" id="st-waste">–</div><div class="k">TWU 夠、效益卻不夠（白算）</div></div>
                    </div>
                    <div class="compare" id="compare"></div>
                </div>
            </div>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼 TWU 可以照 Apriori 的方式剪？</h2>
                <p>效益本身沒有向下封閉性：預設資料裡 {咖啡, 茶葉蛋} 的效益只有 245，加上麵包變成 {茶葉蛋, 咖啡, 麵包}，效益反而是 250。
                    Two-Phase 的關鍵是換一個量來剪，這個量要同時滿足兩件事：</p>
                <ul>
                    <li><b>它是上界：</b>一個組合在某筆交易裡的效益，不可能超過那筆交易的總效益 TU。把包含它的交易都加起來，效益 ≤ TWU。
                        所以 TWU 不到門檻，效益一定也不到，刪掉不會漏。</li>
                    <li><b>它有向下封閉性：</b>組合變大，包含它的交易只會變少（或一樣），而 TWU 是把這些交易的 TU 加起來，所以 TWU 只會變小或不變。
                        {牛奶, 麵包} 的 TWU 不夠，{咖啡, 牛奶, 麵包} 的 TWU 一定也不夠，跟 Apriori 用出現次數剪枝是同一個道理。</li>
                </ul>
                <p style="margin-top:0.5rem">兩件事合起來：第一階段找到的候選，<b>一定包含所有高效益樣式</b>（可能多、不會少）。多出來的那些，就交給第二階段把真正的效益算出來淘汰掉。</p>
            </div>
            <div class="card">
                <h2>跟 HUI-Miner 比，以及實驗室在做的事</h2>
                <ul>
                    <li><b>上界很鬆：</b>TWU 把整筆交易的錢都算進去，包括組合裡沒有的商品。只要某筆交易很大（例如一次買很多洋芋片），裡面每個小組合的 TWU 都會被灌高，
                        於是第一階段留下一堆「TWU 夠、效益其實不夠」的候選，第二階段要一個一個驗證。</li>
                    <li><b>掃很多次資料庫：</b>第一階段每一層掃一次、第二階段再掃一次。組合越長，掃越多次，跟 Apriori 一樣有這個問題。</li>
                    <li><b><a href="high-utility.html">HUI-Miner</a> 為什麼比較快：</b>它只掃 2 次資料庫，之後把每個組合在每筆交易的效益（iutil）和「後面還剩多少」（rutil）存在 utility list 裡。
                        合併兩張 list 就直接得到新組合<b>真正的效益</b>，不用回頭掃資料庫；剪枝用的 Σiutil + Σrutil 也只算排在後面的商品，比 TWU 緊很多。
                        所以它不需要「候選」這個步驟，論文稱為 one-phase 方法。</li>
                    <li><b>為什麼還要學 Two-Phase：</b>它是第一個把「找上界、照 Apriori 剪」這個想法講清楚的方法，TWU 到現在還是幾乎每個高效益演算法的第一步（HUI-Miner 第一步也是先用 TWU 刪商品）。
                        實驗室學長姐研究的增量／動態高效益探勘，也常常先用 TWU 這類上界過濾，再處理資料增加、修改、刪除時只更新受影響的部分。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           Two-Phase 一步一步看
           網頁裡用 JavaScript 照著同樣的流程跑一次，把每一步記下來；
           右邊的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = /*CODE_JSON*/null;

        const ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片'];
        const EMOJI = { '咖啡': '☕', '麵包': '🍞', '牛奶': '🥛', '飯糰': '🍙', '茶葉蛋': '🥚', '洋芋片': '🥔' };
        const PROFIT = { '咖啡': 30, '麵包': 15, '牛奶': 20, '飯糰': 10, '茶葉蛋': 5, '洋芋片': 25 };
        /* 跟 HUI-Miner 頁同樣的 8 筆交易（Apriori 頁的交易加上購買數量） */
        const DB = [
            { '咖啡': 4, '麵包': 2, '牛奶': 2 },
            { '咖啡': 3, '麵包': 5, '茶葉蛋': 4 },
            { '咖啡': 1, '麵包': 1, '牛奶': 2, '飯糰': 2 },
            { '麵包': 3, '牛奶': 4, '洋芋片': 5 },
            { '咖啡': 3, '牛奶': 2, '茶葉蛋': 2 },
            { '咖啡': 1, '麵包': 2, '牛奶': 1, '茶葉蛋': 1 },
            { '飯糰': 1, '茶葉蛋': 2, '洋芋片': 2 },
            { '咖啡': 1, '麵包': 2, '飯糰': 1 }
        ];
        const MU_MIN = 100, MU_MAX = 500, MU_STEP = 10;

        const $ = id => document.getElementById(id);
        let minUtil = 250;
        let lang = 'java';
        let trace = [];
        let cursor = 0;
        let timer = null;
        let selKey = null;                 // 使用者點選的組合

        /* 跟 Java 的 compareTo、Python 的字串比較同一個順序（依字碼） */
        const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
        const esc = x => String(x).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
        const fmtText = set => '{' + set.join(', ') + '}';
        const fmt = set => esc(fmtText(set));
        const arrowPath = items => esc(items.join(' → '));
        const tName = tid => 'T' + (tid + 1);
        const keyOf = items => items.join('|');
        const has = (t, item) => Object.prototype.hasOwnProperty.call(t, item);
        const contains = (t, set) => set.every(i => has(t, i));

        /* ---------- 照著程式跑一次，記下每一步 ---------- */
        function buildTrace(db, profit, minUtil) {
            const steps = [];
            const stats = { scans: 0, counted: 0, pruned: 0 };
            const st = { tu: [], twu: {}, order: [], removed: [], twuCalc: false, twuDone: false };
            const cands = [];                  // 第一階段留下的候選 {set, twu, level, util?, hui?}
            let result = [];
            let p2 = 0;                        // 0 = 第一階段，1 = 算完真正效益，2 = 篩選完
            const push = (kind, extra = {}) => steps.push({
                kind, ...extra, p2,
                stats: { ...stats, cands: cands.length },
                cands: cands.map(c => ({ ...c })),
                result: result.map(r => ({ ...r })),
                tu: st.tu.slice(), twu: { ...st.twu }, order: st.order.slice(), removed: st.removed.slice(), twuCalc: st.twuCalc, twuDone: st.twuDone
            });
            const twuOf = set => db.reduce((a, t, k) => a + (contains(t, set) ? st.tu[k] : 0), 0);
            const utilOf = set => db.reduce((a, t) => a + (contains(t, set) ? set.reduce((b, i) => b + t[i] * profit[i], 0) : 0), 0);

            push('start');

            // 第一階段 第 1 次掃描：TU 與每個商品的 TWU
            stats.scans++;
            st.tu = db.map(t => Object.keys(t).reduce((a, i) => a + t[i] * profit[i], 0));
            push('tu');
            db.forEach((t, k) => Object.keys(t).forEach(i => { st.twu[i] = (st.twu[i] || 0) + st.tu[k]; }));
            st.twuCalc = true;
            stats.counted += Object.keys(st.twu).length;
            push('twu');
            const byTwu = (a, b) => st.twu[a] - st.twu[b] || cmp(a, b);
            st.order = Object.keys(st.twu).filter(i => st.twu[i] >= minUtil).sort(byTwu);
            st.removed = Object.keys(st.twu).filter(i => st.twu[i] < minUtil).sort(byTwu);
            st.twuDone = true;
            let L = st.order.map(i => [i]);
            L.forEach(set => cands.push({ set, twu: st.twu[set[0]], level: 1, fresh: true }));
            push('L1', { chips: [...st.order, ...st.removed].map(i => ({ set: [i], twu: st.twu[i], ok: st.twu[i] >= minUtil })) });
            cands.forEach(c => { c.fresh = false; });

            let k = 2;
            while (L.length) {
                // ① 合併
                let C = [];
                for (let i = 0; i < L.length; i++) {
                    for (let j = i + 1; j < L.length; j++) {
                        const a = L[i], b = L[j];
                        if (keyOf(a.slice(0, k - 2)) === keyOf(b.slice(0, k - 2))) C.push({ set: [...a, b[k - 2]], from: [a, b] });
                    }
                }
                push('join', { k, nL: L.length, chips: C });
                if (C.length) {
                    // ② 剪枝：有一個 k-1 子集合的 TWU 不夠，就一定不夠
                    const prev = new Set(L.map(keyOf));
                    const view = C.map(c => {
                        let missing = null;
                        for (let i = 0; i < c.set.length && !missing; i++) {
                            const sub = c.set.filter((_, x) => x !== i);
                            if (!prev.has(keyOf(sub))) missing = sub;
                        }
                        return { set: c.set, ok: !missing, missing };
                    });
                    stats.pruned += view.filter(c => !c.ok).length;
                    C = view.filter(c => c.ok).map(c => ({ set: c.set }));
                    push('prune', { k, chips: view, left: C.length });
                }
                if (!C.length) { push('stop', { k, why: 'nocand' }); break; }

                // ③ 再掃一次資料庫，算候選的 TWU
                stats.scans++;
                stats.counted += C.length;
                const counted = C.map(c => ({ set: c.set, twu: twuOf(c.set) }));
                push('count', { k, chips: counted });

                // ④ 篩選
                const judged = counted.map(c => ({ ...c, ok: c.twu >= minUtil }));
                L = judged.filter(c => c.ok).map(c => c.set);
                judged.filter(c => c.ok).forEach(c => cands.push({ set: c.set, twu: c.twu, level: k, fresh: true }));
                push('filter', { k, chips: judged });
                cands.forEach(c => { c.fresh = false; });
                if (!L.length) push('stop', { k, why: 'emptyL' });
                k++;
            }

            // 第二階段：再掃一次，算每個候選真正的效益
            stats.scans++;
            p2 = 1;
            cands.forEach(c => { c.util = utilOf(c.set); });
            push('p2count');
            p2 = 2;
            cands.forEach(c => { c.hui = c.util >= minUtil; });
            result = cands.filter(c => c.hui).map(c => ({ set: c.set, util: c.util }));
            push('p2filter');
            push('end');
            return steps;
        }

        /* ---------- 對照用：HUI-Miner 在同樣條件下建幾張 utility list（跟 HUI-Miner 頁同一套做法） ---------- */
        function huiMinerLists(db, profit, mu) {
            const tu = db.map(t => Object.keys(t).reduce((a, i) => a + t[i] * profit[i], 0));
            const twu = {};
            db.forEach((t, k) => Object.keys(t).forEach(i => { twu[i] = (twu[i] || 0) + tu[k]; }));
            const order = Object.keys(twu).filter(i => twu[i] >= mu).sort((a, b) => twu[a] - twu[b] || cmp(a, b));
            const lists = order.map(() => ({ rows: new Map(), iu: 0, ru: 0 }));
            db.forEach((t, tid) => {
                let r = 0;
                for (let k = order.length - 1; k >= 0; k--) {
                    if (!has(t, order[k])) continue;
                    const u = t[order[k]] * profit[order[k]];
                    lists[k].rows.set(tid, [u, r]); lists[k].iu += u; lists[k].ru += r; r += u;
                }
            });
            let built = lists.length;
            const search = (p, uls) => uls.forEach((x, i) => {
                if (x.iu + x.ru < mu) return;
                const ext = [];
                uls.slice(i + 1).forEach(y => {
                    const xy = { rows: new Map(), iu: 0, ru: 0 };
                    x.rows.forEach(([iuX], tid) => {
                        const ry = y.rows.get(tid);
                        if (!ry) return;
                        const iu = iuX + ry[0] - (p ? p.rows.get(tid)[0] : 0);
                        xy.rows.set(tid, [iu, ry[1]]); xy.iu += iu; xy.ru += ry[1];
                    });
                    if (xy.rows.size) { built++; ext.push(xy); }
                });
                search(x, ext);
            });
            search(null, lists);
            return built;
        }

        /* ---------- 說明文字（用頁面上的 DB） ---------- */
        const qp = (t, items) => items.map(i => `${t[i]}×${PROFIT[i]}`).join(' + ');
        const tidsOf = set => DB.map((t, k) => k).filter(k => contains(DB[k], set));
        const utilIn = (t, set) => set.reduce((a, i) => a + t[i] * PROFIT[i], 0);
        function looseOf(cands) {
            const bad = cands.filter(c => !c.hui);
            if (!bad.length) return null;
            return bad.reduce((x, y) => (y.twu - y.util > x.twu - x.util ? y : x));
        }
        function describe(s) {
            const n = s.chips ? s.chips.length : 0;
            switch (s.kind) {
                case 'start': {
                    const t0 = DB[0], its = Object.keys(t0).slice(0, 2);
                    return `一個組合在某筆交易裡的效益 = 數量 × 利潤加起來，例如 T1 裡的 ${fmt(its)} = ${qp(t0, its)} = ${utilIn(t0, its)}；` +
                        `把它出現過的每筆交易加起來，就是它的效益。目標：找出效益至少 <b>${minUtil}</b> 的所有組合（高效益樣式）。` +
                        `Two-Phase 分兩階段：<b>第一階段</b>用 TWU 照 Apriori 的方式找候選，<b>第二階段</b>再算候選真正的效益。`;
                }
                case 'tu': {
                    const k = s.tu.indexOf(Math.max(...s.tu));
                    return `第一階段，第 1 次掃描資料庫：先算每筆交易的總效益 <b>TU</b>（表格最右邊那欄）。例如 ${tName(k)} = ${qp(DB[k], Object.keys(DB[k]))} = ${s.tu[k]}，是最賺的一筆。`;
                }
                case 'twu': {
                    const i = Object.keys(s.twu).sort((a, b) => s.twu[a] - s.twu[b] || cmp(a, b))[0];
                    const ks = tidsOf([i]);
                    return `同一次掃描順便算每個商品的 <b>TWU</b>：有買它的交易 TU 加起來（表格最下面那列）。例如 ${esc(i)}：${ks.map(k => s.tu[k]).join(' + ')} = ${s.twu[i]}。` +
                        `TWU 有兩個好性質：它<b>不會比真正的效益小</b>（組合在一筆交易裡賺的，不會超過整筆的 TU）；而且組合變大時，包含它的交易只會變少，<b>TWU 只會變小</b>，跟出現次數一樣有向下封閉性。`;
                }
                case 'L1': {
                    let t = s.removed.length
                        ? s.removed.map(i => `${esc(i)} 的 TWU 只有 ${s.twu[i]}`).join('、') + ` < ${minUtil}，含它的組合效益都不可能達標，刪掉。`
                        : `每個商品的 TWU 都至少 ${minUtil}，這次沒有商品被刪掉。`;
                    t += s.order.length
                        ? `留下的 ${s.order.length} 個商品就是<b>第 1 層</b>，照 TWU 由小到大排成 ${arrowPath(s.order)}（跟 HUI-Miner 頁同一個順序），之後的組合都照這個順序寫。它們全部先記進右邊的候選清單。`
                        : `沒有商品留下來，不可能有高效益樣式。`;
                    return t;
                }
                case 'join':
                    if (!n) return `第 ${s.k} 層：第 ${s.k - 1} 層只剩 ${s.nL} 個組合，` + (s.nL < 2 ? '湊不成一對，' : `前 ${s.k - 2} 個商品都不一樣，`) + `合併不出任何候選。`;
                    return s.k === 2
                        ? `第 2 層，① 合併：k = 2 時「前 0 個相同」，第 1 層裡任兩個商品都能配成一對，共 ${n} 個候選。`
                        : `第 ${s.k} 層，① 合併：把第 ${s.k - 1} 層裡<b>前 ${s.k - 2} 個商品相同</b>的兩兩配對，拼成 ${s.k} 個商品的候選，共 ${n} 個。`;
                case 'prune': {
                    const out = s.chips.filter(c => !c.ok);
                    return out.length
                        ? `② 剪枝：候選拿掉任一個商品後的子集合，都要在第 ${s.k - 1} 層裡。有 <b>${out.length}</b> 個候選的子集合 TWU 不夠（例如 ${fmt(out[0].missing)}），因為 TWU 有向下封閉性，它們的 TWU 也一定不夠，不用掃資料庫就刪掉。`
                        : `② 剪枝：每個候選的 ${s.k - 1} 個商品子集合都在第 ${s.k - 1} 層裡，這一層沒有可以剪掉的（這份資料只有 6 樣商品，剪枝很少派上用場；商品多、組合長的時候，這一步能省下很多次計算）。`;
                }
                case 'stop': {
                    const why = s.why === 'nocand' ? `第 ${s.k} 層沒有候選` : `第 ${s.k} 層沒有任何組合的 TWU 達到 ${minUtil}`;
                    return `${why}，<b>第一階段結束</b>。一共留下 <b>${s.stats.cands}</b> 個 TWU 夠的組合（HTWUI），掃了 ${s.stats.scans} 次資料庫。` +
                        `它們只是「有可能」，真正的效益還不知道，下一步進入第二階段。`;
                }
                case 'count': {
                    const c = s.chips[0], ks = tidsOf(c.set);
                    return `③ 第 ${s.stats.scans} 次掃描資料庫：算每個候選的 TWU，也就是包含它的交易 TU 加起來。例如 ${fmt(c.set)} 出現在 ${ks.map(tName).join('、') || '0 筆交易'}` +
                        (ks.length > 1 ? `：${ks.map(k => s.tu[k]).join(' + ')} = ${c.twu}。` : ks.length ? `，TWU 就是那一筆的 TU = ${c.twu}。` : `，TWU = 0。`) + `點候選可以在交易表格看到是哪幾筆。`;
                }
                case 'filter': {
                    const ok = s.chips.filter(c => c.ok).length;
                    return ok
                        ? `④ 篩選：TWU ≥ ${minUtil} 的 <b>${ok}</b> 個成為第 ${s.k} 層，也加進右邊的候選清單。` + (ok < n ? `其他 ${n - ok} 個 TWU 不夠，效益一定也不夠。` : '') +
                          `注意：TWU 夠<b>不代表效益夠</b>，要等第二階段才知道。`
                        : `④ 篩選：沒有任何候選的 TWU 達到 ${minUtil}，第 ${s.k} 層是空的。`;
                }
                case 'p2count': {
                    const lo = looseOf(s.cands.map(c => ({ ...c, hui: c.util >= minUtil })));
                    const c = lo || s.cands[s.cands.length - 1];
                    if (!c) return `第二階段：沒有候選，不用再算。程式還是會掃一次資料庫（第 ${s.stats.scans} 次），只是什麼都不用加。`;
                    const ks = tidsOf(c.set);
                    return `<b>第二階段</b>，第 ${s.stats.scans} 次掃描資料庫：這次對每個候選只加<b>組合裡那幾樣</b>的數量 × 利潤，得到真正的效益（右邊實心的長條）。` +
                        `例如 ${fmt(c.set)}：${ks.map(k => `${tName(k)} ${utilIn(DB[k], c.set)}`).join('、')}，加起來 ${c.util}；它的 TWU 是 ${c.twu}，上界多算了 ${c.twu - c.util}。`;
                }
                case 'p2filter': {
                    const h = s.result.length, w = s.cands.length - h, lo = looseOf(s.cands);
                    return `效益 ≥ ${minUtil} 的 <b>${h}</b> 個是高效益樣式。` +
                        (w ? `另外 <b>${w}</b> 個是 TWU 過了、效益卻不夠的候選（右邊紅色），第一階段為它們掃資料庫、第二階段又驗證一次，等於白算。` +
                            `差最多的是 ${fmt(lo.set)}：TWU ${lo.twu}，真正效益只有 ${lo.util}。`
                            : `這次每個候選的效益都夠，上界剛好沒有多抓。`);
                }
                case 'end': {
                    const n2 = s.result.length;
                    return (n2 ? `完成！找到 <b>${n2}</b> 個高效益樣式，跟 HUI-Miner 找到的完全一樣。` : `完成！沒有任何組合的效益達到 ${minUtil}。`) +
                        `Two-Phase 一共掃描資料庫 ${s.stats.scans} 次、算了 ${s.stats.counted} 個組合的 TWU、留下 ${s.stats.cands} 個候選；結果區最下面有跟 HUI-Miner 的對照。`;
                }
            }
            return '';
        }

        const CODE_TAGS = s => {
            switch (s.kind) {
                case 'twu': return ['tu'];
                case 'join': return ['loop', 'join'];
                case 'stop': return s.why === 'nocand' ? ['prune'] : ['loop'];
                case 'p2count': return ['phase2'];
                case 'p2filter': return ['verify'];
                default: return [s.kind];        // start / tu / L1 / prune / count / filter / end
            }
        };

        /* ---------- 點選某個組合：在交易表標出來，並說明 TWU 和真正效益 ---------- */
        function selectedSet() {
            return selKey ? selKey.split('|') : null;
        }
        function hintHTML(set) {
            if (!set) return '';
            const ks = tidsOf(set);
            if (!ks.length) return `${fmt(set)} 沒有出現在任何一筆交易裡。`;
            const twu = ks.reduce((a, k) => a + trace[cursor].tu[k], 0);
            const u = ks.reduce((a, k) => a + utilIn(DB[k], set), 0);
            return `${fmt(set)} 出現在 ${ks.map(tName).join('、')}（表格標黃的列）。TWU = 這幾筆的 TU 加起來 = ${ks.map(k => trace[cursor].tu[k]).join(' + ')} = <b>${twu}</b>；` +
                `真正的效益只算這幾樣（格子裡的小字）= ${ks.map(k => utilIn(DB[k], set)).join(' + ')} = <b>${u}</b>。`;
        }

        /* ---------- 畫面 ---------- */
        function drawDB(s) {
            const cols = s.twuDone ? [...s.order, ...s.removed, ...ITEMS.filter(i => !(i in s.twu))] : ITEMS;
            const sel = selectedSet();
            const items = new Set(sel || []);
            const off = i => s.removed.includes(i);
            let h = '<thead><tr><th class="tid-h"></th>' + cols.map(i =>
                `<th class="${off(i) ? 'off' : ''}${items.has(i) ? ' sel' : ''}"><span class="emo">${EMOJI[i]}</span><span class="nm">${esc(i)}</span><span class="pf">$${PROFIT[i]}</span></th>`).join('') +
                `<th class="tu-h${s.kind === 'tu' || sel ? ' sel' : ''}">TU</th></tr></thead><tbody>`;
            DB.forEach((t, r) => {
                const match = sel && contains(t, sel);
                h += `<tr class="${match ? 'match' : ''}"><td class="tid">${tName(r)}</td>` + cols.map(i => {
                    if (!has(t, i)) return '<td><div class="cell"></div></td>';
                    const hit = match && items.has(i);
                    return `<td><div class="cell has${off(i) ? ' off' : ''}${hit ? ' hit' : ''}">${t[i]}${hit ? `<small>${t[i] * PROFIT[i]}</small>` : ''}</div></td>`;
                }).join('') + `<td class="tu${s.kind === 'tu' || match ? ' sel' : ''}">${s.tu.length ? s.tu[r] : ''}</td></tr>`;
            });
            h += '</tbody>';
            if (s.twuCalc) h += '<tfoot><tr><td class="tid">TWU</td>' + cols.map(i => `<td class="twu${off(i) ? ' out' : ''}">${i in s.twu ? s.twu[i] : ''}</td>`).join('') + '<td></td></tr></tfoot>';
            $('db').innerHTML = h;
            $('db-sub').textContent = s.twuDone ? '欄已照 TWU 由小到大排' : '';
        }

        /* 這一步正在處理的那一層候選（Apriori 頁同樣的小方塊） */
        function drawChips(s) {
            const box = $('cands');
            box.innerHTML = '';
            if (!s.chips) { box.style.display = 'none'; return; }
            box.style.display = '';
            if (!s.chips.length) { box.innerHTML = '<span class="cands-note">（沒有候選）</span>'; return; }
            s.chips.forEach(c => {
                const b = document.createElement('button');
                b.type = 'button';
                let cls = 'cand', badge = '', why = '';
                if (s.kind === 'L1' || s.kind === 'filter') { cls += c.ok ? ' ok' : ' out'; badge = c.twu; if (!c.ok) why = `< ${minUtil}`; }
                else if (s.kind === 'count') badge = c.twu;
                else if (s.kind === 'prune' && !c.ok) { cls += ' out'; why = `${fmtText(c.missing)} 不夠`; }
                if (selKey === keyOf(c.set)) cls += ' sel';
                b.className = cls;
                b.innerHTML = `<span class="nm"></span>${badge !== '' ? `<span class="n">TWU ${badge}</span>` : ''}${why ? '<span class="why"></span>' : ''}`;
                b.querySelector('.nm').textContent = fmtText(c.set);
                if (why) b.querySelector('.why').textContent = why;
                b.addEventListener('click', () => toggleSel(keyOf(c.set)));
                box.appendChild(b);
            });
        }

        function drawCandList(s) {
            const box = $('clist');
            box.innerHTML = '';
            const sub = $('cl-sub');
            sub.textContent = s.cands.length ? `${s.cands.length} 個 · ${s.p2 ? '第二階段' : '第一階段'}` : '';
            if (!s.cands.length) {
                box.innerHTML = `<div class="clist-empty">${s.twuDone ? '沒有組合的 TWU 達到門檻。' : '算完每個商品的 TWU 之後，TWU 夠的組合會一層一層加進來。'}</div>`;
            }
            const maxTwu = Math.max(1, ...Object.values(s.twu), ...s.cands.map(c => c.twu));
            const pct = v => (Math.min(v, maxTwu) / maxTwu * 100).toFixed(1) + '%';
            let lv = 0;
            s.cands.forEach(c => {
                if (c.level !== lv) {
                    lv = c.level;
                    const h = document.createElement('div');
                    h.className = 'clv';
                    h.textContent = `第 ${lv} 層`;
                    box.appendChild(h);
                }
                const row = document.createElement('button');
                row.type = 'button';
                let cls = 'crow';
                if (s.p2 === 2) cls += c.hui ? ' hui' : ' loose';
                if (c.fresh) cls += ' fresh';
                if (selKey === keyOf(c.set)) cls += ' sel';
                row.className = cls;
                const uTxt = c.util === undefined ? '?' : c.util;
                const tag = s.p2 === 2 ? `<span class="cr-tag">${c.hui ? '✓ 高效益' : '✗ 效益不夠'}</span>` : '';
                row.innerHTML = `<div class="cr-top"><span><span class="cr-name"></span>${tag}</span><span class="cr-num">TWU <b>${c.twu}</b> · 效益 <b>${uTxt}</b></span></div>` +
                    `<div class="bar"><i class="b-twu" style="width:${pct(c.twu)}"></i>${c.util !== undefined ? `<i class="b-u" style="width:${pct(c.util)}"></i>` : ''}<i class="b-mu" style="left:${pct(minUtil)}"></i></div>`;
                row.querySelector('.cr-name').textContent = fmtText(c.set);
                row.addEventListener('click', () => toggleSel(keyOf(c.set)));
                box.appendChild(row);
            });
            const ls = $('loose-sum');
            if (s.p2 === 2 && s.cands.length) {
                const w = s.cands.filter(c => !c.hui).length;
                const sumT = s.cands.reduce((a, c) => a + c.twu, 0), sumU = s.cands.reduce((a, c) => a + c.util, 0);
                ls.innerHTML = `${s.cands.length} 個候選裡有 <b>${w}</b> 個效益不夠。全部加起來，TWU 平均是真正效益的 <b>${(sumT / Math.max(1, sumU)).toFixed(1)}</b> 倍，這就是上界有多鬆。`;
            } else {
                ls.textContent = s.p2 ? '' : '虛線是 TWU，第二階段算出真正的效益後，會畫出實心的長條。點一列可以看它出現在哪幾筆交易。';
            }
            // 新加入的那一層留在看得到的地方（只捲清單本身）
            const fresh = box.querySelector('.crow.fresh');
            if (fresh) box.scrollTo({ top: Math.max(0, fresh.offsetTop - box.offsetTop - 30), behavior: 'smooth' });
            else if (s.kind === 'p2count' || s.kind === 'start') box.scrollTo({ top: 0 });
        }

        function drawHints() {
            const html = hintHTML(selectedSet());
            $('hint-step').innerHTML = html;
            $('hint-list').innerHTML = html;
        }

        function drawResult(s) {
            const box = $('levels');
            box.innerHTML = '';
            if (!s.result.length) box.innerHTML = `<div class="empty">${s.kind === 'end' || s.kind === 'p2filter' ? '沒有找到。把門檻調低一點試試看。' : '第二階段算完真正的效益之後，才知道哪些是高效益樣式。'}</div>`;
            const bySize = {};
            s.result.forEach(r => { (bySize[r.set.length] = bySize[r.set.length] || []).push(r); });
            Object.keys(bySize).sort().forEach(k => {
                const row = document.createElement('div');
                row.className = 'level';
                row.innerHTML = `<span class="tag">${k} 個</span><div class="items"></div>`;
                bySize[k].forEach(r => {
                    const p = document.createElement('span');
                    p.className = 'pat';
                    p.innerHTML = `<span></span><span class="n">${r.util}</span>`;
                    p.firstChild.textContent = fmtText(r.set);
                    row.querySelector('.items').appendChild(p);
                });
                box.appendChild(row);
            });
            $('st-scan').textContent = s.stats.scans;
            $('st-count').textContent = s.stats.counted;
            $('st-cand').textContent = s.stats.cands;
            $('st-waste').textContent = s.p2 === 2 ? s.cands.filter(c => !c.hui).length : '–';
            drawCompare(s);
        }

        /* 跟 HUI-Miner（同樣的資料和門檻）對照 */
        function drawCompare(s) {
            const box = $('compare');
            if (s.kind !== 'end') {
                box.innerHTML = `全部做完之後，這裡會跟 <a href="high-utility.html">HUI-Miner</a>（同樣的資料、同樣的門檻）對照。`;
                return;
            }
            const lists = huiMinerLists(DB, PROFIT, minUtil);
            const w = s.cands.filter(c => !c.hui).length;
            box.innerHTML = `<h3>跟 HUI-Miner 對照（門檻 ${minUtil}）</h3>` +
                `<div>兩個方法找到的高效益樣式完全一樣，差在過程花了多少力氣。</div>` +
                `<table class="cmp"><thead><tr><th></th><th>Two-Phase</th><th>HUI-Miner</th></tr></thead><tbody>` +
                `<tr><td>掃描資料庫</td><td>${s.stats.scans} 次</td><td>2 次</td></tr>` +
                `<tr><td>要處理的組合</td><td>${s.stats.counted} 個算 TWU</td><td>${lists} 張 list</td></tr>` +
                `<tr><td>需要回頭驗證</td><td>${s.stats.cands} 個候選</td><td>不用</td></tr>` +
                `<tr><td>白算的候選</td><td>${w} 個</td><td>—</td></tr></tbody></table>` +
                `<div style="margin-top:0.5rem">HUI-Miner 合併 utility list 時就直接得到真正的效益，所以不需要第二階段；它剪枝用的 Σiutil + Σrutil 只算排在後面的商品，比 TWU 緊。</div>`;
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
                ? '下載 <a href="code/TwoPhase.java" download>TwoPhase.java</a>　執行 <code>javac TwoPhase.java && java TwoPhase</code>'
                : '下載 <a href="code/two_phase.py" download>two_phase.py</a>　執行 <code>python3 two_phase.py</code>';
        }

        /* ---------- 顯示某一步 ---------- */
        function stepHead(s, i) {
            return `<span class="step-no">步驟 ${i + 1} / ${trace.length}<span class="phase${s.p2 ? ' p2' : ''}">${s.p2 ? '第二階段' : '第一階段'}</span></span>`;
        }
        function showStep() {
            const s = trace[cursor];
            $('explain').innerHTML = stepHead(s, cursor) + describe(s);
            drawDB(s);
            drawChips(s);
            drawCandList(s);
            drawHints();
            drawResult(s);
            renderCode(CODE_TAGS(s));
            $('btn-prev').disabled = $('btn-first').disabled = cursor === 0;
            $('btn-next').disabled = cursor === trace.length - 1;
            $('mu-val').textContent = minUtil;
            $('mu-range').value = minUtil;
            $('mu-minus').disabled = minUtil <= MU_MIN;
            $('mu-plus').disabled = minUtil >= MU_MAX;
            const total = DB.reduce((a, t) => a + Object.keys(t).reduce((b, i) => b + t[i] * PROFIT[i], 0), 0);
            $('mu-pct').textContent = `（全部交易總效益 ${total} 的 ${Math.round(minUtil / total * 100)}%）`;
        }
        /* 點選只重畫跟選取有關的部分，不動程式碼框和說明 */
        function toggleSel(key) {
            selKey = selKey === key ? null : key;
            const s = trace[cursor];
            drawDB(s);
            drawChips(s);
            document.querySelectorAll('.crow').forEach(r => r.classList.toggle('sel', r.querySelector('.cr-name').textContent === (selKey ? fmtText(selKey.split('|')) : null)));
            drawHints();
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
            const box = $('explain');
            if (!box.offsetWidth) return;
            const probe = box.cloneNode(false);
            probe.removeAttribute('id');
            probe.style.cssText = `position:absolute;visibility:hidden;left:-9999px;min-height:0;width:${box.offsetWidth}px`;
            document.body.appendChild(probe);
            let tallest = 0;
            trace.forEach((s, i) => {
                probe.innerHTML = stepHead(s, i) + describe(s);
                tallest = Math.max(tallest, probe.offsetHeight);
            });
            probe.remove();
            box.style.minHeight = tallest + 'px';
            reserveBlockHeights(document, trace.length, i => { cursor = i; showStep(); }, () => cursor);
        }

        function rebuild() {
            stopAuto();
            trace = buildTrace(DB, PROFIT, minUtil);
            cursor = 0;
            selKey = null;
            showStep();
            reserveExplainHeight();
        }

        function step(dir) {
            const next = cursor + dir;
            if (next < 0 || next >= trace.length) return false;
            cursor = next;
            selKey = null;
            showStep();
            return cursor < trace.length - 1;
        }
        function stopAuto() {
            clearInterval(timer);
            timer = null;
            $('btn-play').textContent = '▶ 自動播放';
        }
        function setMinUtil(v) {
            v = Math.max(MU_MIN, Math.min(MU_MAX, v));
            if (v === minUtil) return;
            minUtil = v;
            rebuild();
        }
        $('btn-next').addEventListener('click', () => { stopAuto(); step(1); });
        $('btn-prev').addEventListener('click', () => { stopAuto(); step(-1); });
        $('btn-first').addEventListener('click', () => { stopAuto(); cursor = 0; selKey = null; showStep(); });
        $('btn-play').addEventListener('click', () => {
            if (timer) { stopAuto(); return; }
            if (cursor === trace.length - 1) { cursor = 0; showStep(); }
            $('btn-play').textContent = '⏸ 暫停';
            timer = setInterval(() => { if (!step(1)) stopAuto(); }, 1900);
        });
        document.addEventListener('keydown', e => {
            if (e.target.tagName === 'INPUT') return;      // 在滑桿上按左右鍵是調門檻
            if (e.key === 'ArrowRight') { stopAuto(); step(1); }
            if (e.key === 'ArrowLeft') { stopAuto(); step(-1); }
        });
        $('mu-minus').addEventListener('click', () => setMinUtil(minUtil - MU_STEP));
        $('mu-plus').addEventListener('click', () => setMinUtil(minUtil + MU_STEP));
        $('mu-range').addEventListener('input', e => setMinUtil(Number(e.target.value)));
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
