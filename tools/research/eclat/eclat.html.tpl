<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/eclat.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/eclat-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/eclat-180.png">
    <title>Eclat 頻繁樣式探勘</title>
    <meta name="description" content="一步一步看 Eclat 怎麼把超商交易轉成垂直格式（每個商品出現在哪幾筆交易），用 TID 集合取交集、深度優先找出所有頻繁樣式，Java 與 Python 程式碼逐行對照。">
    <style>
        /* 手機瀏覽器會自動把某些段落的字放大，程式碼框裡就會一行大一行小；關掉它 */
        html { -webkit-text-size-adjust: 100%; text-size-adjust: 100%; }
        @import url('https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=Syne:wght@700;800&display=swap');

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
        .intro { color: #c6c6d6; max-width: 760px; margin-top: 0.9rem; font-size: 0.95rem; }
        .intro b { color: var(--text); }
        .intro a, .notes a { color: var(--accent2); }

        .layout { display: grid; gap: 1rem; margin-top: 1.3rem; }
        .layout > * { min-width: 0; display: grid; gap: 1rem; align-content: start; }
        .layout > * > * { min-width: 0; }
        @media (min-width: 960px) { .layout { grid-template-columns: 1fr 1.05fr; } }

        .card {
            background: var(--panel);
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 1rem;
        }
        .card-head { display: flex; justify-content: space-between; align-items: center; gap: 0.5rem; flex-wrap: wrap; margin-bottom: 0.7rem; }
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
        button.btn.on { border-color: var(--warn); color: var(--warn); }

        /* ── 交易資料庫（水平格式） ── */
        .db { width: 100%; table-layout: fixed; border-collapse: separate; border-spacing: 0 3px; }
        .db th.tid-h { width: 2.1rem; }
        .db th.del-h { width: 30px; }
        .db th { font-weight: 400; color: var(--muted); font-size: clamp(0.6rem, 3vw, 0.75rem); white-space: nowrap; padding: 0 1px 4px; text-align: center; line-height: 1.25; }
        .db th .emo { display: block; font-size: 1.25rem; }
        .db th.sel { color: var(--warn); }
        .db td { text-align: center; padding: 0; }
        .db td.tid { font: 0.78rem 'Space Mono', monospace; color: var(--muted); text-align: left; width: 2.6em; padding-left: 0.3rem; }
        .db tr.match td, .db tr.scan td { background: rgba(245, 158, 11, 0.12); }
        .db tr.scan td { background: rgba(6, 182, 212, 0.12); }
        .db tr.match td:first-child, .db tr.scan td:first-child { border-radius: 8px 0 0 8px; color: var(--warn); }
        .db tr.scan td:first-child { color: var(--accent2); }
        .db tr.match td:last-child, .db tr.scan td:last-child { border-radius: 0 8px 8px 0; }
        .cell {
            width: 30px;
            height: 30px;
            margin: 0 auto;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 0.95rem;
        }
        .cell.has { background: #2a2a48; }
        .cell.has::after { content: ''; width: 11px; height: 11px; border-radius: 50%; background: var(--accent2); }
        .cell.hit { background: rgba(245, 158, 11, 0.35); }
        .cell.hit::after { background: var(--warn); }
        .editing .cell { cursor: pointer; border: 1px dashed #3a3a5a; }
        .editing .cell:hover { border-color: var(--accent2); }
        .db .del {
            background: none; border: none; color: var(--muted); cursor: pointer; font-size: 0.85rem;
            width: 26px; height: 26px; border-radius: 50%;
        }
        .db .del:hover { color: var(--bad); background: rgba(255, 255, 255, 0.05); }
        .db-foot { display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center; margin-top: 0.7rem; }

        .minsup { display: flex; align-items: center; gap: 0.45rem; flex-wrap: wrap; font-size: 0.9rem; }
        .minsup .val { font: 700 1rem 'Space Mono', monospace; min-width: 1.4em; text-align: center; }
        .minsup .pct { color: var(--muted); font-size: 0.82rem; }
        .stepper { width: 30px; height: 30px; padding: 0 !important; }

        /* ── 一排小方格：T1…Tn，有出現的格子亮起來、寫上交易編號 ── */
        .tids { display: grid; grid-template-columns: repeat(var(--n), minmax(0, 22px)); gap: 3px; }
        .tids .t {
            aspect-ratio: 1;
            border-radius: 4px;
            border: 1px solid #24243a;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
            font: 700 min(0.6rem, 2.5vw)/1 'Space Mono', monospace;
            color: transparent;
        }
        .tids .t.on { background: rgba(6, 182, 212, 0.25); border-color: rgba(6, 182, 212, 0.65); color: #a5f3fc; }
        .tids .t.both { background: rgba(245, 158, 11, 0.32); border-color: var(--warn); color: #fde68a; }
        .tids .t.new { box-shadow: 0 0 0 2px var(--warn); }
        .tids.ok .t.on { background: rgba(34, 197, 94, 0.28); border-color: rgba(34, 197, 94, 0.75); color: #bbf7d0; }
        .tids.bad .t.on { background: rgba(248, 113, 113, 0.22); border-color: rgba(248, 113, 113, 0.7); color: #fecaca; }

        .mrow {
            display: grid;
            grid-template-columns: 5.2rem minmax(0, 1fr) 2.6rem;
            gap: 0.5rem;
            align-items: center;
            padding: 0.2rem 0.35rem;
            border-radius: 8px;
            border: 1px solid transparent;
        }
        .mrow .lbl { font-size: 0.82rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .mrow .cnt { font: 700 0.8rem 'Space Mono', monospace; text-align: right; }
        .mrow .cnt small { display: block; font: 0.62rem/1.1 inherit; color: var(--bad); font-weight: 400; }
        .mrow.cur { border-color: var(--warn); background: rgba(245, 158, 11, 0.08); }
        .mrow.pair { border-color: var(--accent2); background: rgba(6, 182, 212, 0.08); }
        .mrow.done { opacity: 0.45; }
        .mrow.drop { opacity: 0.4; }
        .mrow.drop .lbl { text-decoration: line-through; }
        .mrow.inpat .lbl { color: var(--warn); }
        .mrow.res { border-color: var(--border); background: var(--panel-2); margin-top: 0.3rem; }
        .mrow.res .cnt.ok { color: #86efac; }
        .mrow.res .cnt.bad { color: #fca5a5; }
        .vnote { color: var(--muted); font-size: 0.78rem; margin-top: 0.5rem; }

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

        .cls { margin-top: 0.8rem; display: grid; gap: 0.25rem; align-content: start; }
        .crumbs { display: flex; flex-wrap: wrap; gap: 0.3rem; align-items: center; font-size: 0.8rem; color: var(--muted); margin-bottom: 0.2rem; }
        .crumb { border: 1px solid var(--border); border-radius: 6px; padding: 0.05rem 0.45rem; }
        .crumb.cur { border-color: var(--accent); color: var(--text); background: rgba(124, 58, 237, 0.15); }
        .cls-title { font-size: 0.88rem; margin: 0.15rem 0 0.2rem; }
        .cls-title b { color: var(--accent2); font-weight: 600; }
        .cls-empty { color: var(--muted); font-size: 0.85rem; padding: 0.3rem 0; }
        .next { display: flex; flex-wrap: wrap; gap: 0.35rem; align-items: center; font-size: 0.8rem; color: var(--muted); margin-top: 0.35rem; }
        .chip { border: 1px solid rgba(34, 197, 94, 0.5); border-radius: 7px; padding: 0.05rem 0.45rem; color: var(--text); }
        .chip .n { font: 700 0.72rem 'Space Mono', monospace; color: #86efac; margin-left: 0.3rem; }
        .hint { color: var(--muted); font-size: 0.8rem; margin-top: 0.3rem; }

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
            max-height: 470px;
            font: 0.8rem/1.7 'Space Mono', ui-monospace, monospace;
            position: relative;
        }
        @media (max-width: 600px) { pre.code { font-size: 0.72rem; max-height: 380px; } }
        .code .ln { display: block; padding-right: 0.9rem; white-space: pre; width: max-content; min-width: 100%; }
        .code .ln::before {
            content: attr(data-n);
            display: inline-block;
            width: 2.4em;
            text-align: right;
            margin-right: 0.9em;
            color: #4a4a66;
        }
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
        .level .items { display: flex; flex-wrap: wrap; gap: 0.35rem; }
        .level .empty { color: var(--muted); font-size: 0.85rem; padding-top: 0.2rem; }
        .pat {
            font-size: 0.82rem; border: 1px solid rgba(34, 197, 94, 0.5); border-radius: 7px; padding: 0.12rem 0.5rem;
            background: var(--panel-2); color: var(--text); font-family: inherit; cursor: pointer; text-align: left;
        }
        .pat:hover { border-color: var(--accent2); }
        .pat .n { font: 700 0.74rem 'Space Mono', monospace; margin-left: 0.35rem; color: #86efac; }
        .pat.fresh { box-shadow: 0 0 0 2px var(--warn); }
        .pat.sel { border-color: var(--warn); background: rgba(245, 158, 11, 0.15); }
        .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.5rem; margin-top: 0.9rem; }
        .stat { background: var(--panel-2); border-radius: 10px; padding: 0.55rem 0.6rem; }
        .stat .v { font: 700 1.25rem 'Space Mono', monospace; }
        .stat .k { color: var(--muted); font-size: 0.75rem; line-height: 1.35; }
        .res-hint { color: var(--muted); font-size: 0.8rem; margin-top: 0.5rem; min-height: 1.3em; }

        .notes { margin-top: 1rem; display: grid; gap: 1rem; }
        .notes > * { min-width: 0; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr; align-items: start; } }
        .notes p, .notes li { color: #c6c6d6; font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; margin-top: 0.7rem; }
        .notes b { color: var(--text); }
        .cmp { width: 100%; border-collapse: collapse; font-size: 0.84rem; table-layout: fixed; }
        .cmp th, .cmp td { border-bottom: 1px solid var(--border); padding: 0.4rem 0.35rem; text-align: left; vertical-align: top; color: #c6c6d6; }
        .cmp th { color: var(--muted); font-weight: 400; font-size: 0.78rem; }
        .cmp th:nth-child(1) { width: 5.6rem; }
        .cmp th:nth-child(2) { width: 4.2rem; }
        .cmp td:first-child { color: var(--text); }
        .cmp td b { font-family: 'Space Mono', monospace; color: var(--warn); }
        .cmp tr.me td { background: rgba(124, 58, 237, 0.1); }
        .cmp-note { color: var(--muted); font-size: 0.78rem; margin-top: 0.4rem; }
    </style>
</head>

<body>
    <div class="wrap">
        <a class="back" href="../index.html#research">← RETURN TO PORTFOLIO</a>
        <div class="kicker">RESEARCH DEMO · FREQUENT PATTERN MINING</div>
        <h1>Eclat 頻繁樣式探勘<small>把資料轉成垂直格式，用交集算出支持度</small></h1>
        <p class="intro">
            跟 <a href="apriori.html">Apriori</a>、<a href="fp-growth.html">FP-Growth</a> 用同一份超商資料，這是找頻繁樣式的第三種做法。
            前兩種都看「一筆交易買了哪些東西」的<b>水平格式</b>；Eclat 把資料轉個方向，變成<b>垂直格式</b>：每個商品記下它出現在哪幾筆交易（交易編號的集合，叫 <b>TID 集合</b>）。
            想知道兩個組合會不會一起出現，把它們的 TID 集合<b>取交集</b>，交集有幾筆就是支持度，不用回去掃資料庫。
            搜尋用<b>深度優先</b>：前綴相同的組合放在同一個<b>等價類</b>，同一類裡兩兩取交集，一路往下長。
        </p>

        <div class="layout">
            <div>
                <div class="card" id="db-card">
                    <div class="card-head">
                        <h2>交易資料庫（水平格式）</h2>
                        <div class="minsup">
                            <span>最小支持度</span>
                            <button class="btn stepper" id="sup-minus" aria-label="減少">−</button>
                            <span class="val" id="sup-val">3</span>
                            <button class="btn stepper" id="sup-plus" aria-label="增加">+</button>
                            <span class="pct" id="sup-pct"></span>
                        </div>
                    </div>
                    <table class="db" id="db"></table>
                    <div class="db-foot">
                        <button class="btn" id="btn-edit">✎ 編輯資料</button>
                        <button class="btn hidden-when-view" id="btn-add-row">＋ 新增一筆交易</button>
                        <button class="btn hidden-when-view" id="btn-reset-db">恢復範例資料</button>
                    </div>
                </div>

                <div class="card">
                    <div class="card-head">
                        <h2>一步一步看</h2>
                    </div>
                    <div class="player">
                        <button class="btn" id="btn-first" title="回到開頭">⏮</button>
                        <button class="btn" id="btn-prev">◀ 上一步</button>
                        <button class="btn primary" id="btn-next">下一步 ▶</button>
                        <button class="btn" id="btn-play">▶ 自動播放</button>
                    </div>
                    <div class="explain" id="explain"></div>
                    <div class="cls" id="cls"></div>
                </div>
            </div>

            <div>
                <div class="card">
                    <div class="card-head">
                        <h2>垂直格式：TID 集合</h2>
                        <span class="sub">商品 → 出現在哪幾筆交易</span>
                    </div>
                    <div id="vert"></div>
                    <div class="vnote">依商品名稱的字碼排序，跟程式裡的 TreeMap、sorted() 同一個順序。格子裡的數字是交易編號。</div>
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

                <div class="card">
                    <h2>目前找到的頻繁樣式</h2>
                    <div class="levels" id="levels"></div>
                    <div class="res-hint" id="res-hint"></div>
                    <div class="stats">
                        <div class="stat"><div class="v" id="st-scan">0</div><div class="k">掃描資料庫次數</div></div>
                        <div class="stat"><div class="v" id="st-inter">0</div><div class="k">取過的交集</div></div>
                        <div class="stat"><div class="v" id="st-cut">0</div><div class="k">交集太小、整條分支不用再往下</div></div>
                    </div>
                </div>
            </div>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼交集的大小就是支持度？</h2>
                <p>{咖啡} 的 TID 集合是「有買咖啡的交易」，{牛奶} 的是「有買牛奶的交易」。兩邊都有的交易，就是咖啡和牛奶都買了的交易，
                    所以 <b>tid({咖啡, 牛奶}) = tid({咖啡}) ∩ tid({牛奶})</b>，交集有幾筆，{咖啡, 牛奶} 的支持度就是多少。
                    更大的組合也一樣：tid({咖啡, 牛奶, 麵包}) = tid({咖啡, 牛奶}) ∩ tid({咖啡, 麵包})，拿同一層兩個已經算好的集合來交就好，不用從單一商品重算。</p>
                <p style="margin-top:0.5rem">交集只會越取越小，所以一個組合不頻繁，往下所有包含它的組合也一定不頻繁（跟 Apriori 一樣的向下封閉性），直接不放進下一層。
                    <b>等價類</b>是把「前綴相同」的組合放在一起，例如 {咖啡, 牛奶}、{咖啡, 茶葉蛋}、{咖啡, 麵包} 都屬於 [咖啡]。只在同一類裡兩兩配對，
                    每個組合剛好被產生一次，不會重複，也不會漏掉。</p>
            </div>
            <div class="card">
                <h2>跟 Apriori、FP-Growth 比起來</h2>
                <table class="cmp" id="cmp"></table>
                <div class="cmp-note">數字是左上這份資料、目前門檻下的結果，改資料或門檻會跟著變。</div>
                <ul>
                    <li><b>只掃一次資料庫：</b>建好垂直表之後，全部在記憶體裡做交集。Apriori 每一層都要掃一次；FP-Growth 掃兩次，但要建樹。</li>
                    <li><b>深度優先：</b>同一時間只需要留著「從根到目前這條路」上的等價類，不像 Apriori 要把一整層的候選都放在記憶體。</li>
                    <li><b>弱點是很密的資料：</b>如果每個商品都出現在大部分交易，TID 集合會很長，交集又慢又佔記憶體。
                        延伸做法 <b>dEclat</b> 改存 <b>diffset</b>：只記「前綴有、但加上這個商品之後就沒有」的交易，支持度 = 前綴的支持度 − diffset 的大小，密的資料可以省很多。</li>
                    <li>實作上 TID 集合常用 bitset（一串 0/1）存，交集就是一次 AND；成員也常依支持度由小到大排，讓交集早點變小。</li>
                    <li>高效益樣式探勘的 <a href="high-utility.html">HUI-Miner</a> 用的效益清單，就是在 TID 集合上多記每筆交易的效益，一樣靠「同前綴的兩個清單合併」往下長。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           Eclat 一步一步看
           網頁裡另外用 JavaScript 照著同樣的流程跑一次，把每個步驟記下來，
           上一步／下一步只是在這些紀錄之間移動；右邊的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = /*CODE_JSON*/null;

        const ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片'];
        const EMOJI = { '咖啡': '☕', '麵包': '🍞', '牛奶': '🥛', '飯糰': '🍙', '茶葉蛋': '🥚', '洋芋片': '🥔' };
        const SAMPLE = [
            ['咖啡', '麵包', '牛奶'],
            ['咖啡', '麵包', '茶葉蛋'],
            ['咖啡', '麵包', '牛奶', '飯糰'],
            ['麵包', '牛奶', '洋芋片'],
            ['咖啡', '牛奶', '茶葉蛋'],
            ['咖啡', '麵包', '牛奶', '茶葉蛋'],
            ['飯糰', '茶葉蛋', '洋芋片'],
            ['咖啡', '麵包', '飯糰']
        ];

        const $ = id => document.getElementById(id);
        let db = SAMPLE.map(t => new Set(t));
        let minSup = 3;
        let editing = false;
        let lang = 'java';
        let trace = [];
        let cursor = 0;
        let selected = null;     // 要在表格上標出的組合（是哪幾筆交易）
        let selChip = null;      // 結果區目前點選的是哪個樣式
        let timer = null;

        /* 跟 Java 的 compareTo、Python 的字串比較同一個順序（依字碼） */
        const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
        const key = set => set.join('|');
        const fmt = set => '{' + set.join(', ') + '}';
        const clsName = prefix => prefix.length ? `[${prefix.join(', ')}]` : '[ ]';
        const tidText = tids => tids.map(t => 'T' + t).join(' ');
        const esc = x => String(x).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

        /* 兩個排好序的交易編號清單取交集（跟程式碼一樣，兩個指標一起往前走） */
        function intersect(a, b) {
            const out = [];
            let p = 0, q = 0;
            while (p < a.length && q < b.length) {
                if (a[p] === b[q]) { out.push(a[p]); p++; q++; }
                else if (a[p] < b[q]) p++;
                else q++;
            }
            return out;
        }

        /* ---------- 照著程式跑一次，記下每一步 ---------- */
        function buildTrace(rows, ms) {
            const tdb = rows.map(t => [...t].sort(cmp));
            const n = tdb.length;
            const steps = [];
            const stats = { scans: 0, inters: 0, cut: 0 };
            const result = [];
            const allItems = [...new Set(tdb.flat())].sort(cmp);
            const vert = Object.fromEntries(allItems.map(i => [i, []]));
            const stack = [];          // 遞迴路上每一層的前綴
            let dropped = [];

            const push = (kind, extra = {}) => steps.push({
                kind, n, ms, allItems, dropped,
                vert: Object.fromEntries(allItems.map(i => [i, vert[i].slice()])),
                crumbs: stack.map(p => p.slice()),
                result: result.map(r => ({ ...r })),
                stats: { ...stats },
                ...extra
            });

            push('start');

            // 掃一次資料庫，建垂直表
            stats.scans = 1;
            tdb.forEach((t, r) => {
                t.forEach(i => vert[i].push(r + 1));
                push('scan', { row: r, items: t });
            });

            // 第一層等價類：前綴是空的，成員是頻繁的單一商品
            const roots = allItems.filter(i => vert[i].length >= ms).map(i => ({ item: i, tids: vert[i].slice() }));
            dropped = allItems.filter(i => vert[i].length < ms);
            stack.push([]);
            push('filter1', { depth: 0, prefix: [], members: roots });

            function mine(prefix, members, depth) {
                if (depth > 0) push('enter', { depth, prefix, members });
                for (let i = 0; i < members.length; i++) {
                    const pattern = [...prefix, members[i].item];
                    result.forEach(r => { r.fresh = false; });
                    result.push({ set: pattern, count: members[i].tids.length, fresh: true });
                    const next = [];
                    const base = { depth, prefix, members, i, pattern };
                    push('pick', { ...base, next: [] });
                    result.forEach(r => { r.fresh = false; });
                    for (let j = i + 1; j < members.length; j++) {
                        const t = intersect(members[i].tids, members[j].tids);
                        stats.inters++;
                        const ok = t.length >= ms;
                        if (ok) next.push({ item: members[j].item, tids: t });
                        else stats.cut++;
                        push('inter', { ...base, j, t, ok, newSet: [...pattern, members[j].item], next: next.map(x => ({ ...x })), last: j === members.length - 1 });
                    }
                    if (next.length) {
                        stack.push(pattern);
                        mine(pattern, next, depth + 1);
                        stack.pop();
                        push('back', { ...base, child: pattern, more: i < members.length - 1 });
                    }
                }
            }
            mine([], roots, 0);
            stack.pop();
            result.forEach(r => { r.fresh = false; });
            push('end');
            return steps;
        }

        /* 同一份資料用 Apriori 要掃幾次資料庫、數幾個組合（拿來比較） */
        function aprioriCost(rows, ms) {
            const sup = s => rows.filter(t => s.every(x => t.includes(x))).length;
            let scans = 1, counted = 0;
            const items = [...new Set(rows.flat())].sort(cmp);
            counted += items.length;
            let L = items.filter(i => sup([i]) >= ms).map(i => [i]);
            for (let k = 2; L.length; k++) {
                const prev = new Set(L.map(key));
                const C = [];
                for (let i = 0; i < L.length; i++) for (let j = i + 1; j < L.length; j++) {
                    const a = L[i], b = L[j];
                    if (key(a.slice(0, k - 2)) === key(b.slice(0, k - 2))) C.push([...a, b[k - 2]]);
                }
                const kept = C.filter(c => c.every((_, idx) => prev.has(key(c.filter((__, j) => j !== idx)))));
                scans++;
                counted += kept.length;
                L = kept.filter(c => sup(c) >= ms);
            }
            return { scans, counted };
        }

        /* FP-Growth 的 FP-tree 有幾個節點（不含根） */
        function fpCost(rows, ms) {
            const count = {};
            rows.forEach(t => t.forEach(i => { count[i] = (count[i] || 0) + 1; }));
            const order = Object.keys(count).filter(i => count[i] >= ms).sort((a, b) => count[b] - count[a] || cmp(a, b));
            const root = new Map();
            let nodes = 0;
            rows.forEach(t => {
                let node = root;
                order.filter(i => t.includes(i)).forEach(i => {
                    if (!node.has(i)) { node.set(i, new Map()); nodes++; }
                    node = node.get(i);
                });
            });
            return { scans: order.length ? 2 : 1, nodes };
        }

        /* ---------- 說明文字 ---------- */
        function describe(s) {
            switch (s.kind) {
                case 'start':
                    return `目標：找出所有至少出現在 <b>${s.ms}</b> 筆交易裡的商品組合。Eclat 先把左上的表「轉個方向」：` +
                        `不再一筆交易列出買了什麼，而是<b>每個商品列出它出現在哪幾筆交易</b>（TID 集合）。之後只要拿這些清單取交集，就知道組合的支持度。`;
                case 'scan':
                    return `掃資料庫（整個過程只掃這一次）：T${s.row + 1} 買了 ${s.items.join('、')}，在這 ${s.items.length} 個商品的清單後面各加上 <b>${s.row + 1}</b>。` +
                        (s.row === s.n - 1 ? '最後一筆加完，之後不會再回頭看資料庫。' : '');
                case 'filter1':
                    if (!s.members.length) return `垂直表完成，清單長度就是支持度。可是沒有任何商品達到 ${s.ms} 筆，第一層就是空的，直接結束。`;
                    return `垂直表完成，每個商品的清單長度就是它的支持度。` +
                        (s.dropped.length ? `${s.dropped.join('、')} 不到 ${s.ms} 筆，先刪掉；` : '每個商品都達到門檻；') +
                        `剩下的 ${s.members.length} 個組成<b>第一層等價類</b>（前綴是空的），接下來從第一個開始深度優先往下挖。`;
                case 'enter':
                    return `進入等價類 <b>${clsName(s.prefix)}</b>（遞迴深度 ${s.depth}）：這一類的 ${s.members.length} 個成員都是 ${fmt(s.prefix)} 再加一樣商品，` +
                        `TID 集合是上一層交集算好帶下來的。在這裡做跟上一層一模一樣的事。`;
                case 'pick': {
                    const later = s.members.length - s.i - 1;
                    return `取出 <b>${fmt(s.pattern)}</b>：它的 TID 集合有 ${s.members[s.i].tids.length} 筆，支持度就是 ${s.members[s.i].tids.length}，不用回去掃資料庫，直接記進結果。` +
                        (later ? `接著拿它跟這一類後面的 ${later} 個成員一一取交集，湊出 ${s.pattern.length + 1} 個商品的組合。`
                            : '它是這一類最後一個成員，後面沒有可以配對的。');
                }
                case 'inter': {
                    const other = [...s.prefix, s.members[s.j].item];
                    let text = `${fmt(s.pattern)} ∩ ${fmt(other)}：兩邊都有的交易是 ${s.t.length ? tidText(s.t) : '（沒有）'}，共 <b>${s.t.length}</b> 筆`;
                    text += s.ok
                        ? ` ≥ ${s.ms}，${fmt(s.newSet)} 頻繁，放進下一層等價類 ${clsName(s.pattern)}。`
                        : ` < ${s.ms}，${fmt(s.newSet)} 不頻繁，丟掉；包含它的更大組合也不用看了。`;
                    if (s.last) text += s.next.length ? `這一類配完了，下一層有 ${s.next.length} 個成員，往下遞迴。` : '這一類配完了，下一層是空的，不用遞迴。';
                    return text;
                }
                case 'back':
                    return `等價類 ${clsName(s.child)} 挖完了，回到上一層 ${clsName(s.prefix)}` +
                        (s.more ? '，繼續處理下一個成員。' : '，這一層也沒有下一個成員了。');
                case 'end': {
                    const total = s.result.length;
                    return `完成！共找到 <b>${total}</b> 個頻繁樣式。整個過程只掃了 ${s.stats.scans} 次資料庫，取了 ${s.stats.inters} 次交集，` +
                        `其中 ${s.stats.cut} 次交集不到門檻，那一整條分支就不用再往下。`;
                }
            }
            return '';
        }

        const CODE_TAG = { start: ['start'], scan: ['scan'], filter1: ['filter1'], enter: ['enter'], pick: ['pick'], inter: ['inter'], back: ['recurse'], end: ['end'] };

        /* ---------- 畫面 ---------- */
        function tidBoxes(tids, n, opts = {}) {
            const set = new Set(tids);
            const both = opts.both ? new Set(opts.both) : null;
            let html = `<div class="tids${opts.cls ? ' ' + opts.cls : ''}" style="--n:${n}">`;
            for (let k = 1; k <= n; k++) {
                let c = 't';
                if (set.has(k)) c += both && both.has(k) ? ' both' : ' on';
                if (opts.fresh === k) c += ' new';
                html += `<span class="${c}">${set.has(k) ? k : ''}</span>`;
            }
            return html + '</div>';
        }

        function renderDB() {
            const table = $('db');
            const s = trace[cursor];
            const hit = new Set(selected || []);
            let html = '<tr><th class="tid-h"></th>' + ITEMS.map(i =>
                `<th class="${hit.has(i) ? 'sel' : ''}"><span class="emo">${EMOJI[i]}</span>${i}</th>`).join('') +
                (editing ? '<th class="del-h"></th>' : '') + '</tr>';
            db.forEach((t, r) => {
                const match = selected && selected.every(x => t.has(x));
                const scan = !selected && s && s.kind === 'scan' && s.row === r;
                html += `<tr class="${match ? 'match' : scan ? 'scan' : ''}"><td class="tid">T${r + 1}</td>` +
                    ITEMS.map(i => `<td><div class="cell ${t.has(i) ? 'has' : ''} ${match && hit.has(i) ? 'hit' : ''}" data-r="${r}" data-i="${i}"></div></td>`).join('') +
                    (editing ? `<td><button class="del" data-del="${r}" aria-label="刪除 T${r + 1}">✕</button></td>` : '') + '</tr>';
            });
            table.innerHTML = html;
            $('db-card').classList.toggle('editing', editing);
            document.querySelectorAll('.hidden-when-view').forEach(b => { b.style.display = editing ? '' : 'none'; });
            $('btn-edit').textContent = editing ? '✓ 編輯完成' : '✎ 編輯資料';
            $('btn-edit').classList.toggle('on', editing);
            $('btn-add-row').disabled = db.length >= 12;
            $('sup-val').textContent = minSup;
            $('sup-pct').textContent = `筆（${Math.round(minSup / db.length * 1000) / 10}%）`;
            $('sup-minus').disabled = minSup <= 1;
            $('sup-plus').disabled = minSup >= db.length;
        }

        /* 垂直表：每個商品一排小方格 */
        function renderVert(s) {
            const inPat = new Set(s.newSet || s.pattern || []);
            const filtered = !['start', 'scan'].includes(s.kind);
            $('vert').innerHTML = s.allItems.map(i => {
                const tids = s.vert[i];
                const drop = filtered && tids.length < s.ms;
                const fresh = s.kind === 'scan' && tids[tids.length - 1] === s.row + 1 ? s.row + 1 : null;
                return `<div class="mrow${drop ? ' drop' : ''}${inPat.has(i) ? ' inpat' : ''}">` +
                    `<span class="lbl">${EMOJI[i] || ''} ${esc(i)}</span>${tidBoxes(tids, s.n, { fresh })}` +
                    `<span class="cnt">${tids.length}${drop ? `<small>&lt; ${s.ms}</small>` : ''}</span></div>`;
            }).join('');
        }

        /* 目前的等價類（也拿來量高度，所以畫到指定的框裡） */
        function renderClass(s, box) {
            if (s.kind === 'start' || s.kind === 'scan') {
                box.innerHTML = `<div class="cls-empty">${s.kind === 'start' ? '下一步開始掃資料庫，右邊（手機在下面）的垂直表會一格一格長出來。'
                    : '垂直表建好之後，深度優先搜尋會從這裡開始：每一層是一個等價類。'}</div>`;
                return;
            }
            if (s.kind === 'end') {
                box.innerHTML = '<div class="cls-empty">所有等價類都挖完了。點「目前找到的頻繁樣式」裡的任一個，可以在左上的表格看到它出現在哪幾筆交易。</div>';
                return;
            }
            const crumbs = s.crumbs.map((c, i) =>
                `<span class="crumb${i === s.crumbs.length - 1 ? ' cur' : ''}">${esc(clsName(c))}</span>`).join('<span>›</span>');
            let html = `<div class="crumbs">遞迴：${crumbs}<span style="margin-left:auto">深度 ${s.depth}</span></div>`;
            html += `<div class="cls-title">等價類 <b>${esc(clsName(s.prefix))}</b>：` +
                (s.prefix.length ? `成員都是 ${esc(fmt(s.prefix))} 再加一樣` : '前綴是空的，成員是頻繁的單一商品') + '</div>';
            if (!s.members.length) html += '<div class="cls-empty">（沒有成員）</div>';
            s.members.forEach((m, idx) => {
                let c = 'mrow';
                if (s.i === idx) c += ' cur';
                else if (s.j === idx) c += ' pair';
                else if (s.i !== undefined && idx < s.i) c += ' done';
                const both = s.kind === 'inter' && (idx === s.i || idx === s.j) ? s.t : null;
                html += `<div class="${c}"><span class="lbl">${s.prefix.length ? '+' : ''}${EMOJI[m.item] || ''} ${esc(m.item)}</span>` +
                    `${tidBoxes(m.tids, s.n, { both })}<span class="cnt">${m.tids.length}</span></div>`;
            });
            if (s.kind === 'inter') {
                html += `<div class="mrow res"><span class="lbl">∩ 交集</span>${tidBoxes(s.t, s.n, { cls: s.ok ? 'ok' : 'bad' })}` +
                    `<span class="cnt ${s.ok ? 'ok' : 'bad'}">${s.t.length}${s.ok ? ' ✓' : ' ✕'}</span></div>`;
            }
            if (s.kind === 'pick' || s.kind === 'inter') {
                const chips = s.next.map(x => `<span class="chip">+${esc(x.item)}<span class="n">${x.tids.length}</span></span>`).join('');
                html += `<div class="next">下一層 ${esc(clsName(s.pattern))}：${chips || '（還沒有）'}</div>`;
                html += `<div class="hint">左上表格標黃的列，就是 ${esc(fmt(s.kind === 'inter' ? s.newSet : s.pattern))} 出現的交易。</div>`;
            }
            box.innerHTML = html;
        }

        function renderLevels(s) {
            const box = $('levels');
            box.innerHTML = '';
            if (!s.result.length) {
                box.innerHTML = '<div class="level"><span class="tag">—</span><span class="empty">還沒有，開始挖之後會出現在這裡。</span></div>';
            }
            const bySize = {};
            s.result.forEach(r => { (bySize[r.set.length] = bySize[r.set.length] || []).push(r); });
            Object.keys(bySize).sort((a, b) => a - b).forEach(k => {
                const row = document.createElement('div');
                row.className = 'level';
                row.innerHTML = `<span class="tag">${k} 個</span><div class="items"></div>`;
                bySize[k].forEach(r => {
                    const b = document.createElement('button');
                    b.type = 'button';
                    b.className = 'pat' + (r.fresh ? ' fresh' : '') + (selChip === key(r.set) ? ' sel' : '');
                    b.innerHTML = `<span></span><span class="n">${r.count}</span>`;
                    b.firstChild.textContent = fmt(r.set);
                    b.addEventListener('click', () => {
                        const again = selChip === key(r.set);
                        selChip = again ? null : key(r.set);
                        selected = again ? autoSelected(trace[cursor]) : r.set;
                        renderDB();
                        renderLevels(trace[cursor]);
                        $('res-hint').textContent = again ? '' :
                            `${fmt(r.set)} 出現在 ${db.filter(t => r.set.every(x => t.has(x))).length} 筆交易裡（左上表格標黃的列）。`;
                    });
                    row.querySelector('.items').appendChild(b);
                });
                box.appendChild(row);
            });
            $('st-scan').textContent = s.stats.scans;
            $('st-inter').textContent = s.stats.inters;
            $('st-cut').textContent = s.stats.cut;
        }

        function renderCompare() {
            const rows = db.map(t => [...t]);
            const ap = aprioriCost(rows, minSup);
            const fp = fpCost(rows, minSup);
            const ec = trace[trace.length - 1].stats;
            $('cmp').innerHTML =
                '<tr><th>方法</th><th>掃資料庫</th><th>主要的工作</th></tr>' +
                `<tr><td>Apriori</td><td><b>${ap.scans}</b> 次</td><td>一層一層產生候選，每層掃一次資料庫去數，共數了 <b>${ap.counted}</b> 個組合</td></tr>` +
                `<tr><td>FP-Growth</td><td><b>${fp.scans}</b> 次</td><td>把交易壓成 <b>${fp.nodes}</b> 個節點的 FP-tree，再遞迴建條件樹</td></tr>` +
                `<tr class="me"><td>Eclat</td><td><b>${ec.scans}</b> 次</td><td>建垂直表，之後取 <b>${ec.inters}</b> 次 TID 集合的交集</td></tr>`;
        }

        /* 簡單的語法上色 */
        const KW = {
            java: new Set('public static final for if return new boolean int void class import while else'.split(' ')),
            py: new Set('def for in if return not and or while import from as True False None'.split(' '))
        };
        function highlight(line) {
            const commentAt = lang === 'java' ? line.indexOf('//') : line.indexOf('#');
            let body = line, comment = '';
            if (commentAt >= 0) { body = line.slice(0, commentAt); comment = line.slice(commentAt); }
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
            if (measuringBlocks) return;   // 量區塊高度時不用畫程式碼（程式碼框高度不會變），省時間
            const pre = $('code');
            pre.innerHTML = CODE[lang].map(([text, t], i) =>
                `<span class="ln${t.some(x => tags.includes(x)) ? ' hl' : ''}" data-n="${i + 1}">${highlight(text) || ' '}</span>`).join('');
            // 只捲程式碼框本身，不捲整個頁面
            // 亮起的行可能分成好幾段（主流程裡的呼叫＋下面的函式本體）：
            // 全部放得下就一起置中；放不下就優先顯示最長的那一段（通常是函式本體）
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
                ? '下載 <a href="code/Eclat.java" download>Eclat.java</a>　執行 <code>javac Eclat.java && java Eclat</code>'
                : '下載 <a href="code/eclat.py" download>eclat.py</a>　執行 <code>python3 eclat.py</code>';
        }

        /* 這一步要在左上表格標出哪個組合 */
        function autoSelected(s) {
            if (s.kind === 'pick') return s.pattern;
            if (s.kind === 'inter') return s.newSet;
            return null;
        }

        function showStep() {
            const s = trace[cursor];
            selChip = null;
            selected = autoSelected(s);
            renderDB();
            $('explain').innerHTML = `<span class="step-no">步驟 ${cursor + 1} / ${trace.length}</span>${describe(s)}`;
            renderClass(s, $('cls'));
            renderVert(s);
            renderLevels(s);
            $('res-hint').textContent = s.result.length ? '點樣式可以在左上的表格看到它出現在哪幾筆交易。' : '';
            renderCode(CODE_TAG[s.kind]);
            $('btn-prev').disabled = $('btn-first').disabled = cursor === 0;
            $('btn-next').disabled = cursor === trace.length - 1;
        }

        /* 說明框和等價類區塊，都用這一輪最高的那一步的高度固定住，下面的東西才不會跳來跳去 */
        function reserveHeight(box, fill) {
            if (!box.offsetWidth) return;
            const probe = box.cloneNode(false);
            probe.removeAttribute('id');
            probe.style.cssText = `position:absolute;visibility:hidden;left:-9999px;min-height:0;width:${box.offsetWidth}px`;
            box.parentNode.appendChild(probe);
            let tallest = 0;
            trace.forEach((s, i) => {
                fill(s, i, probe);
                tallest = Math.max(tallest, probe.offsetHeight);
            });
            probe.remove();
            box.style.minHeight = tallest + 'px';
        }
        /* 一步一步播放時，各區塊的內容會變多變少（樹長大、清單變長…）。
           先把每一步都畫一次，用最高的那一次把每個區塊的高度固定住，
           區塊變長變短才不會把旁邊或下面的東西推來推去。
           步驟多時要量一陣子，所以分段量：每段量完立刻畫回目前這一步，畫面不會閃，也不會卡住。 */
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

        function reserveExplainHeight() {
            reserveHeight($('explain'), (s, i, el) => {
                el.innerHTML = `<span class="step-no">步驟 ${i + 1} / ${trace.length}</span>${describe(s)}`;
            });
            reserveHeight($('cls'), (s, i, el) => renderClass(s, el));
            reserveBlockHeights(document, trace.length, i => { cursor = i; showStep(); }, () => cursor);
        }

        function rebuild(keepCursor) {
            stopAuto();
            minSup = Math.max(1, Math.min(minSup, db.length));
            trace = buildTrace(db.map(t => [...t]), minSup);
            cursor = keepCursor ? Math.min(cursor, trace.length - 1) : 0;
            showStep();
            reserveExplainHeight();
            renderCompare();
        }

        /* ---------- 操作 ---------- */
        function step(dir) {
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
            timer = setInterval(() => { if (!step(1)) stopAuto(); }, 1800);
        });
        document.addEventListener('keydown', e => {
            if (e.key === 'ArrowRight') { stopAuto(); step(1); }
            if (e.key === 'ArrowLeft') { stopAuto(); step(-1); }
        });

        $('sup-minus').addEventListener('click', () => { minSup--; rebuild(false); });
        $('sup-plus').addEventListener('click', () => { minSup++; rebuild(false); });

        $('btn-edit').addEventListener('click', () => { editing = !editing; renderDB(); });
        $('db').addEventListener('click', e => {
            if (!editing) return;
            const del = e.target.closest('[data-del]');
            if (del) {
                if (db.length <= 3) return;
                db.splice(Number(del.dataset.del), 1);
                rebuild(false);
                return;
            }
            const cell = e.target.closest('.cell');
            if (!cell) return;
            const t = db[Number(cell.dataset.r)];
            const item = cell.dataset.i;
            if (t.has(item)) {
                if (t.size <= 1) return;          // 一筆交易至少要買一樣
                t.delete(item);
            } else {
                t.add(item);
            }
            rebuild(false);
        });
        $('btn-add-row').addEventListener('click', () => {
            if (db.length >= 12) return;
            db.push(new Set([ITEMS[0]]));
            rebuild(false);
        });
        $('btn-reset-db').addEventListener('click', () => {
            db = SAMPLE.map(t => new Set(t));
            minSup = 3;
            rebuild(false);
        });

        $('lang').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b) return;
            lang = b.dataset.lang;
            [...$('lang').children].forEach(x => x.classList.toggle('active', x === b));
            renderCode(CODE_TAG[trace[cursor].kind]);
        });

        let resizeTimer = null;
        window.addEventListener('resize', () => {
            clearTimeout(resizeTimer);
            resizeTimer = setTimeout(reserveExplainHeight, 150);
        });

        rebuild(false);
    </script>
</body>

</html>
