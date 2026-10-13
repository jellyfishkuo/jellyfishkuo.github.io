<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/association-rules.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/association-rules-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/association-rules-180.png">
    <title>關聯規則：信賴度與提升度</title>
    <meta name="description" content="一步一步看怎麼從頻繁樣式切出「買了 X 的人也會買 Y」的關聯規則：算信賴度、提升度，後件逐層變大並剪枝，Java 與 Python 程式碼逐行對照。">
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
        .intro { color: #c6c6d6; max-width: 780px; margin-top: 0.9rem; font-size: 0.95rem; }
        .intro b { color: var(--text); }
        .intro a, .explain a, .notes a { color: var(--accent2); }

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

        /* ── 交易資料庫（矩陣） ── */
        .db { width: 100%; table-layout: fixed; border-collapse: separate; border-spacing: 0 3px; }
        .db th.tid-h { width: 2.1rem; }
        .db th.del-h { width: 30px; }
        .db th { font-weight: 400; color: var(--muted); font-size: clamp(0.6rem, 3vw, 0.75rem); white-space: nowrap; padding: 0 1px 4px; text-align: center; line-height: 1.25; }
        .db th .emo { display: block; font-size: 1.25rem; }
        .db th.sel { color: var(--warn); }
        .db td { text-align: center; padding: 0; }
        .db td.tid { font: 0.78rem 'Space Mono', monospace; color: var(--muted); text-align: left; width: 2.6em; padding-left: 0.3rem; }
        .db tr.match td { background: rgba(245, 158, 11, 0.12); }
        .db tr.match td:first-child { border-radius: 8px 0 0 8px; color: var(--warn); }
        .db tr.match td:last-child { border-radius: 0 8px 8px 0; }
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

        .params { display: grid; gap: 0.4rem; margin-bottom: 0.7rem; }
        .minsup { display: flex; align-items: center; gap: 0.45rem; flex-wrap: wrap; font-size: 0.9rem; }
        .minsup .lbl { min-width: 5.5em; }
        .minsup .val { font: 700 1rem 'Space Mono', monospace; min-width: 2.6em; text-align: center; }
        .minsup .pct { color: var(--muted); font-size: 0.82rem; }
        .stepper { width: 30px; height: 30px; padding: 0 !important; }

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

        .cands { display: grid; gap: 0.45rem; margin-top: 0.8rem; min-height: 2.2rem; }
        .cands .row { display: flex; flex-wrap: wrap; gap: 0.4rem; }
        .cands .lvl { display: grid; grid-template-columns: 3.4em 1fr; gap: 0.5rem; align-items: start; }
        .cands .lvl .tag { font: 700 0.74rem 'Space Mono', monospace; color: var(--accent2); padding-top: 0.3rem; line-height: 1.3; }
        .cand {
            display: inline-flex;
            align-items: center;
            flex-wrap: wrap;
            gap: 0.4rem;
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
        .cand.bad { border-color: rgba(248, 113, 113, 0.5); }
        .cand.bad .n { background: rgba(248, 113, 113, 0.2); color: #fca5a5; }
        .cand.out { opacity: 0.6; }
        .cand.out .name { text-decoration: line-through; }
        .cand.wait { border-style: dashed; color: var(--muted); }
        .cand.dim { opacity: 0.5; }
        .cand.cur { border-color: var(--warn); box-shadow: 0 0 0 2px rgba(245, 158, 11, 0.35); }
        .cand .why { color: var(--muted); font-size: 0.75rem; }
        .cands-hint { color: var(--muted); font-size: 0.8rem; margin-top: 0.5rem; min-height: 1.3em; }

        /* ── 程式碼 ── */
        .lang { display: flex; gap: 0.25rem; flex-wrap: wrap; }
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
        .downloads code { font: 0.78rem 'Space Mono', monospace; background: var(--panel-2); padding: 0.1rem 0.4rem; border-radius: 4px; color: var(--text); overflow-wrap: anywhere; }

        /* ── 規則表 ── */
        .sortbar { display: flex; align-items: center; gap: 0.4rem; flex-wrap: wrap; font-size: 0.8rem; color: var(--muted); }
        .rules-box { max-height: 420px; overflow: auto; border: 1px solid var(--border); border-radius: 10px; }
        .rules { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
        .rules th { position: sticky; top: 0; background: var(--panel-2); color: var(--muted); font-weight: 400; font-size: 0.75rem; padding: 0.4rem 0.5rem; text-align: right; white-space: nowrap; }
        .rules th:first-child { text-align: left; }
        .rules td { padding: 0.35rem 0.5rem; border-top: 1px solid var(--border); text-align: right; font: 0.8rem 'Space Mono', monospace; white-space: nowrap; }
        .rules td.rule { text-align: left; font-family: inherit; font-size: 0.85rem; line-height: 1.4; white-space: normal; }
        .rules td.rule .arrow { color: var(--accent2); padding: 0 0.15rem; }
        .rules tr { cursor: pointer; }
        .rules tbody tr:hover td { background: rgba(255, 255, 255, 0.03); }
        .rules tr.new td { background: rgba(34, 197, 94, 0.1); }
        .rules tr.sel td { background: rgba(245, 158, 11, 0.14); }
        .rules .up { color: #86efac; }
        .rules .same { color: var(--muted); }
        .rules .down { color: #fca5a5; }
        .rules-empty { color: var(--muted); font-size: 0.85rem; padding: 0.7rem; }
        .legend { color: var(--muted); font-size: 0.78rem; margin-top: 0.5rem; }
        .legend .up { color: #86efac; }
        .legend .down { color: #fca5a5; }

        .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.5rem; margin-top: 0.9rem; }
        .stat { background: var(--panel-2); border-radius: 10px; padding: 0.55rem 0.6rem; }
        .stat .v { font: 700 1.25rem 'Space Mono', monospace; }
        .stat .k { color: var(--muted); font-size: 0.75rem; line-height: 1.35; }

        .notes { margin-top: 1rem; display: grid; gap: 1rem; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr; } }
        .notes > * { min-width: 0; }
        .notes p, .notes li { color: #c6c6d6; font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; }
        .notes b { color: var(--text); }
        .formula { font: 0.8rem/1.7 'Space Mono', monospace; background: #0a0a14; border: 1px solid var(--border); border-radius: 8px; padding: 0.5rem 0.7rem; margin: 0.5rem 0; color: var(--text); overflow-x: auto; white-space: nowrap; }
    </style>
</head>

<body>
    <div class="wrap">
        <a class="back" href="../index.html#research">← RETURN TO PORTFOLIO</a>
        <div class="kicker">RESEARCH DEMO · ASSOCIATION RULES</div>
        <h1>關聯規則：信賴度與提升度<small>買了咖啡的人，也比較會買麵包嗎？</small></h1>
        <p class="intro">
            接續 <a href="apriori.html">Apriori</a> 那一頁：頻繁樣式只告訴我們「哪些東西常一起出現」，但店長真正想知道的是
            「<b>買了 X 的人，有多少比例也會買 Y</b>」，這就是關聯規則 <b>X → Y</b>（X 叫前件、Y 叫後件）。
            <b>信賴度</b> = sup(X∪Y) ÷ sup(X)，就是買 X 的人裡面也買 Y 的比例；<b>提升度</b> = 信賴度 ÷ (sup(Y) ÷ 總筆數)，
            是跟「所有人」買 Y 的比例比起來高了幾倍。一個 k 個商品的頻繁樣式有 2<sup>k</sup> − 2 種切法，
            靠一個性質可以少算很多：<b>同一個樣式切出來的規則，後件越大，信賴度只會越低</b>。
        </p>

        <div class="layout">
            <div>
                <div class="card" id="db-card">
                    <div class="card-head">
                        <h2>交易資料庫</h2>
                    </div>
                    <div class="params">
                        <div class="minsup">
                            <span class="lbl">最小支持度</span>
                            <button class="btn stepper" id="sup-minus" aria-label="減少最小支持度">−</button>
                            <span class="val" id="sup-val">3</span>
                            <button class="btn stepper" id="sup-plus" aria-label="增加最小支持度">+</button>
                            <span class="pct" id="sup-pct"></span>
                        </div>
                        <div class="minsup">
                            <span class="lbl">最小信賴度</span>
                            <button class="btn stepper" id="conf-minus" aria-label="減少最小信賴度">−</button>
                            <span class="val" id="conf-val">70%</span>
                            <button class="btn stepper" id="conf-plus" aria-label="增加最小信賴度">+</button>
                            <span class="pct">每次 5%</span>
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
                    <div class="cands" id="cands"></div>
                    <div class="cands-hint" id="cands-hint"></div>
                </div>
            </div>

            <div>
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
                    <div class="card-head">
                        <h2 id="rules-title">目前找到的規則</h2>
                        <div class="sortbar">
                            <span>排序</span>
                            <div class="lang" id="sort">
                                <button data-sort="found" class="active">找到順序</button>
                                <button data-sort="conf">信賴度</button>
                                <button data-sort="lift">提升度</button>
                            </div>
                        </div>
                    </div>
                    <div class="rules-box" id="rules-box"></div>
                    <div class="legend">提升度 <span class="up">&gt; 1 正相關</span>、= 1 沒關係、<span class="down">&lt; 1 負相關</span>。點一列可以在左上表格看是哪幾筆交易。</div>
                    <div class="stats">
                        <div class="stat"><div class="v" id="st-test">0</div><div class="k">實際算過信賴度的切法</div></div>
                        <div class="stat"><div class="v" id="st-skip">0</div><div class="k">剪枝省掉、不用算的切法</div></div>
                        <div class="stat"><div class="v" id="st-brute">0</div><div class="k">暴力法要算的切法</div></div>
                    </div>
                </div>
            </div>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼後件變大，信賴度只會變低？</h2>
                <p>同一個頻繁樣式 Z 切出來的規則，分子都是 sup(Z)，只有分母 sup(X) 不一樣：</p>
                <div class="formula">conf(X → Y) = sup(Z) ÷ sup(X)，X = Z − Y</div>
                <p>把一個商品從前件搬到後件，前件就變小了。條件越少，符合的交易只會越多，所以 sup(X) 只會變大、信賴度只會變小。
                    例如 {咖啡, 麵包} → {牛奶} 是 3/5 = 60%，把麵包搬過去變成 {咖啡} → {麵包, 牛奶}，就剩 3/6 = 50%。</p>
                <p style="margin-top:0.5rem">所以<b>只要 X → Y 不夠，任何後件包含 Y 的規則也一定不夠</b>，跟 Apriori 的向下封閉性是同一個道理，
                    連產生大一號後件的方法（合併＋剪枝）都可以直接沿用。注意這只在<b>同一個 Z 裡</b>成立：前件變大、後件不變的規則，信賴度可能變高也可能變低，不能拿來剪。</p>
            </div>
            <div class="card">
                <h2>信賴度高，不代表真的有關係</h2>
                <ul>
                    <li><b>要看提升度。</b>範例裡 {茶葉蛋} → {咖啡} 信賴度 75%，看起來很強；但 8 個客人裡本來就有 6 個買咖啡（75%），提升度剛好 1.00，茶葉蛋對買咖啡一點幫助都沒有。
                        把最小信賴度調到 60% 還會看到 {咖啡, 麵包} → {牛奶} 的提升度是 0.96，比一般人還低。</li>
                    <li><b>提升度是對稱的</b>：lift(X → Y) = lift(Y → X) = sup(X∪Y)·N ÷ (sup(X)·sup(Y))；信賴度則不是，{咖啡} → {牛奶} 67%，{牛奶} → {咖啡} 80%。</li>
                    <li><b>規則很容易爆量。</b>門檻一調低，一個 6 個商品的樣式就能切出 62 條規則，大多是重複或理所當然的。研究上會再用其他興趣度量（conviction、leverage 等）或只留最精簡的規則。</li>
                    <li><b>和實驗室研究的關係：</b>資料一直進來時，規則也要跟著<a href="incremental.html">增量更新</a>或在<a href="sliding-window.html">滑動視窗</a>裡維護；
                        改看利潤時則變成<a href="high-utility.html">高效益樣式</a>延伸出的高效益關聯規則。規則產生這一步都差不多，難的是前面怎麼有效率地拿到頻繁樣式和它們的次數。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           關聯規則一步一步看
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
        let minConfPct = 70;     // 最小信賴度（百分比）
        let editing = false;
        let lang = 'java';
        let sortBy = 'found';
        let trace = [];
        let cursor = 0;
        let selected = null;     // 要在表格上標出的 { x: 前件, z: 整個樣式 }
        let selChip = null;      // 目前點選的是哪個切法 / 規則
        let timer = null;

        /* 跟 Java 的 compareTo、Python 的字串比較同一個順序（依字碼） */
        const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
        const key = set => set.join('|');
        const fmt = set => '{' + set.join(', ') + '}';
        const support = set => db.filter(t => set.every(x => t.has(x))).length;
        const pct = v => Math.round(v * 1000) / 10 + '%';
        /* 從 arr 挑 m 個（保持原本順序） */
        function combos(arr, m) {
            const out = [];
            const pick = (start, cur) => {
                if (cur.length === m) { out.push(cur.slice()); return; }
                for (let i = start; i < arr.length; i++) { cur.push(arr[i]); pick(i + 1, cur); cur.pop(); }
            };
            pick(0, []);
            return out;
        }
        /* 提升度跟 1 比：用整數比，避免小數誤差。sup(Z)·N 跟 sup(X)·sup(Y) */
        const liftSign = r => Math.sign(r.supZ * r.n - r.supX * r.supY);

        /* 合併＋剪枝（跟程式碼裡的 grow 一樣） */
        function grow(H, k) {
            const ok = new Set(H.map(key));
            const C = [];
            for (let i = 0; i < H.length; i++) {
                for (let j = i + 1; j < H.length; j++) {
                    const a = H[i], b = H[j];
                    if (key(a.slice(0, k - 2)) !== key(b.slice(0, k - 2))) continue;
                    const c = [...a, b[k - 2]];
                    if (combos(c, k - 1).every(sub => ok.has(key(sub)))) C.push(c);
                }
            }
            return C;
        }

        /* ---------- 照著程式跑一次，記下每一步 ---------- */
        function buildTrace() {
            const steps = [];
            const N = db.length;
            const minConf = minConfPct / 100;
            const stats = { tested: 0, skipped: 0, brute: 0 };
            const rules = [];
            let zv = null;   // 目前這個 Z 的所有切法：zv[m-1] = 後件有 m 個的那一排
            const push = (kind, extra = {}) => steps.push({
                kind, ...extra, stats: { ...stats }, nRules: rules.length,
                zv: zv ? zv.map(row => row.map(c => ({ ...c }))) : null
            });

            push('start');

            // 先用 Apriori 找頻繁樣式和次數
            const sup = new Map();
            const freq = [];
            let C = [...new Set(db.flatMap(t => [...t]))].sort(cmp).map(i => [i]);
            while (C.length) {
                const L = [];
                for (const c of C) {
                    const n = support(c);
                    if (n >= minSup) { L.push(c); sup.set(key(c), n); freq.push({ set: c, count: n }); }
                }
                C = grow(L, C[0].length + 1);
            }
            const big = freq.filter(f => f.set.length >= 2);
            stats.brute = big.reduce((a, f) => a + 2 ** f.set.length - 2, 0);
            push('mine', { freq, big: big.length });

            // 後件 y 為什麼被剪：找出它裡面「已經測過、不夠」的最小後件
            const failedPart = (y) => {
                for (let m = 1; m < y.length; m++) {
                    for (const sub of combos(y, m)) {
                        const c = zv[m - 1].find(cc => key(cc.y) === key(sub));
                        if (c && c.state === 'fail') return sub;
                    }
                }
                return null;
            };

            for (const f of freq) {
                const z = f.set;
                if (z.length < 2) continue;
                const supZ = f.count;
                zv = [];
                for (let m = 1; m < z.length; m++) {
                    zv.push(combos(z, m).map(y => ({ y, x: z.filter(i => !y.includes(i)), state: 'wait' })));
                }
                const cellOf = y => zv[y.length - 1].find(c => key(c.y) === key(y));
                const before = { rules: rules.length, tested: stats.tested, skipped: stats.skipped };
                push('pick', { z, supZ });

                let H = z.map(i => [i]);
                push('h1', { z, H });
                let m = 1;
                let lastM = 1;
                while (H.length && m < z.length) {
                    lastM = m;
                    const passed = [];
                    for (const y of H) {
                        const x = z.filter(i => !y.includes(i));
                        const supX = sup.get(key(x)), supY = sup.get(key(y));
                        const conf = supZ / supX;
                        stats.tested++;
                        const cell = cellOf(y);
                        cell.conf = conf;
                        const info = { z, x, y, supZ, supX, supY, conf, n: N, m, cur: key(y) };
                        if (conf >= minConf) {
                            const lift = conf / (supY / N);
                            rules.push({ x, y, supZ, supX, supY, conf, lift, n: N, order: rules.length });
                            passed.push(y);
                            cell.state = 'pass';
                            push('pass', { ...info, lift });
                        } else {
                            cell.state = 'fail';
                            push('fail', info);
                        }
                    }
                    if (m + 1 < z.length) {
                        const cands = grow(passed, m + 1);
                        const gen = new Set(cands.map(key));
                        const skipped = [];
                        zv[m].forEach(c => {
                            if (!gen.has(key(c.y))) { c.state = 'skip'; c.why = failedPart(c.y); skipped.push(c.y); }
                        });
                        stats.skipped += skipped.length;
                        push('grow', { z, m: m + 1, passed, cands, skipped });
                        H = cands;
                    } else {
                        H = [];   // 後件再大一個，前件就空了（程式裡 while 的條件會擋下來）
                    }
                    m++;
                }
                // 還沒輪到就結束的（更大的後件），也都是剪掉的
                let rest = 0;
                zv.forEach(row => row.forEach(c => {
                    if (c.state === 'wait') { c.state = 'skip'; c.why = failedPart(c.y); rest++; }
                }));
                stats.skipped += rest;
                push('zdone', {
                    z, supZ, made: rules.length - before.rules, tested: stats.tested - before.tested,
                    skipped: stats.skipped - before.skipped, full: lastM === z.length - 1 && !rest
                });
            }
            zv = null;
            push('end', { big: big.length });
            steps.rules = rules;
            return steps;
        }

        /* ---------- 說明文字 ---------- */
        const ruleText = (x, y) => `${fmt(x)} → ${fmt(y)}`;
        function liftMeaning(s) {
            const l = s.lift.toFixed(2);
            const sign = liftSign(s);
            const X = s.x.join('、'), Y = s.y.join('、');
            if (sign > 0) return `買 ${X} 的人買 ${Y} 的機率是一般人的 ${l} 倍，<b>正相關</b>。`;
            if (sign === 0) return `跟一般人一模一樣，買不買 ${X} 對買 ${Y} <b>沒有影響</b>，信賴度高只是因為 ${Y} 本來就很多人買。`;
            return `比一般人還低，買了 ${X} 反而比較不會買 ${Y}，<b>負相關</b>。`;
        }
        function describe(s) {
            switch (s.kind) {
                case 'start':
                    return `目標：找出像「買咖啡的人，也常買麵包」這種規則。規則要從頻繁樣式切出來，所以先找出現至少 <b>${minSup}</b> 次的頻繁樣式，再把每個樣式切成「前件 → 後件」，只留下信賴度 ≥ <b>${minConfPct}%</b> 的。`;
                case 'mine':
                    return `先用 <a href="apriori.html">Apriori</a> 找出所有頻繁樣式和它們的次數（過程見上一頁），共 ${s.freq.length} 個。` +
                        (s.big
                            ? `只有 1 個商品的切不出規則，真正要處理的是下面亮綠框的 <b>${s.big}</b> 個。`
                            : `但沒有任何 2 個商品以上的頻繁樣式，切不出規則。可以把最小支持度調低試試。`);
                case 'pick':
                    return `處理樣式 Z = ${fmt(s.z)}（出現 ${s.supZ} 次）。把它切成「前件 X → 後件 Y」，X、Y 都不能是空的，共 2<sup>${s.z.length}</sup> − 2 = ${2 ** s.z.length - 2} 種切法，下面每一格是一種。` +
                        `不管怎麼切，X∪Y 都是 Z，所以<b>分子都是 sup(Z) = ${s.supZ}</b>，差別只在分母 sup(X)。`;
                case 'h1':
                    return `後件先從 1 個商品開始試：${s.H.map(fmt).join('、')}，前件就是 Z 拿掉後件剩下的。`;
                case 'pass':
                    return `${ruleText(s.x, s.y)}：信賴度 = sup(Z) ÷ sup(X) = ${s.supZ}/${s.supX} = <b>${pct(s.conf)}</b> ≥ ${minConfPct}%，過關！` +
                        `提升度 = 信賴度 ÷ 所有人買 ${s.y.join('、')} 的比例（${s.supY}/${s.n} = ${pct(s.supY / s.n)}）= <b>${s.lift.toFixed(2)}</b>：${liftMeaning(s)}`;
                case 'fail':
                    return `${ruleText(s.x, s.y)}：信賴度 = ${s.supZ}/${s.supX} = <b>${pct(s.conf)}</b> &lt; ${minConfPct}%，不夠。` +
                        (s.m + 1 < s.z.length
                            ? `所以之後<b>後件包含 ${fmt(s.y)} 的都不用試</b>：後件變大 = 前件變小，前件出現次數只會變多，信賴度只會更低。`
                            : `（後件已經是最大的，沒有更大的要剪。）`);
                case 'grow':
                    if (!s.cands.length) return `後件要變成 ${s.m} 個，但過關的後件拼不出任何組合，Z 剩下的切法<b>全部不用試</b>。`;
                    return `後件變成 ${s.m} 個：只拿過關的後件 ${s.passed.map(fmt).join('、')} 來拼（跟 Apriori 一樣的合併＋剪枝），要試的是 ${s.cands.map(fmt).join('、')}。` +
                        (s.skipped.length ? `另外 <b>${s.skipped.length}</b> 種後件含有已經不夠的部分，直接剪掉。` : `上一輪全部過關，這一輪沒有可以剪的。`);
                case 'zdone':
                    return `${fmt(s.z)} 處理完：算了 ${s.tested} 種切法、剪掉 ${s.skipped} 種，產生 <b>${s.made}</b> 條規則。` +
                        (s.full ? `後件已經 ${s.z.length - 1} 個，再大前件就空了，換下一個樣式。` : `沒有後件可以再變大，換下一個樣式。`);
                case 'end': {
                    const R = trace.rules ? trace.rules.length : s.nRules;
                    if (!s.big) return `完成，沒有可以切的樣式，所以 0 條規則。`;
                    return `完成！共 <b>${R}</b> 條規則。暴力法要把 ${s.big} 個樣式的 ${s.stats.brute} 種切法都算一次信賴度，這裡只算了 ${s.stats.tested} 種，剪掉 ${s.stats.skipped} 種。右邊的規則表可以依信賴度或提升度排序。`;
                }
            }
            return '';
        }

        const CODE_TAG = { start: 'start', mine: 'mine', pick: 'pick', h1: 'h1', pass: 'pass', fail: 'fail', grow: 'grow', zdone: 'loop', end: 'end' };

        /* ---------- 畫面 ---------- */
        function renderDB() {
            const table = $('db');
            const zset = new Set(selected ? selected.z : []);
            let html = '<tr><th class="tid-h"></th>' + ITEMS.map(i =>
                `<th class="${zset.has(i) ? 'sel' : ''}"><span class="emo">${EMOJI[i]}</span>${i}</th>`).join('') +
                (editing ? '<th class="del-h"></th>' : '') + '</tr>';
            db.forEach((t, r) => {
                const match = selected && selected.x.every(x => t.has(x));
                const full = selected && selected.z.every(x => t.has(x));
                html += `<tr class="${match ? 'match' : ''}"><td class="tid">T${r + 1}</td>` +
                    ITEMS.map(i => `<td><div class="cell ${t.has(i) ? 'has' : ''} ${match && full && zset.has(i) ? 'hit' : ''}" data-r="${r}" data-i="${i}"></div></td>`).join('') +
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
            $('conf-val').textContent = minConfPct + '%';
            $('conf-minus').disabled = minConfPct <= 5;
            $('conf-plus').disabled = minConfPct >= 100;
        }

        /* 點了某個切法 / 規則：表格標出前件出現的列，以及整個 Z 都有的格子 */
        function choose(id, x, z, hintFn) {
            const again = selChip === id;
            selChip = again ? null : id;
            selected = again ? null : { x, z };
            renderDB();
            showCands();
            renderRules(trace[cursor]);
            $('cands-hint').textContent = again ? '' : hintFn();
        }
        function splitHint(x, y, z, prefix = '') {
            const sx = support(x), sz = support(z);
            return prefix + `前件 ${fmt(x)} 出現在 ${sx} 筆（左上表格標黃的列），其中 ${sz} 筆連後件 ${fmt(y)} 也有（橘色點）→ 信賴度 ${sz}/${sx} = ${pct(sz / sx)}。`;
        }

        function chip(label, cls, badge, why, id, onClick) {
            const b = document.createElement('button');
            b.type = 'button';
            b.className = 'cand ' + cls + (selChip === id ? ' sel' : '');
            b.innerHTML = `<span class="name"></span>${badge !== '' ? '<span class="n"></span>' : ''}${why ? '<span class="why"></span>' : ''}`;
            b.querySelector('.name').textContent = label;
            if (badge !== '') b.querySelector('.n').textContent = badge;
            if (why) b.querySelector('.why').textContent = why;
            b.addEventListener('click', onClick);
            return b;
        }

        function showCands() {
            const s = trace[cursor];
            const box = $('cands');
            box.innerHTML = '';
            if (s.kind === 'mine') {
                const row = document.createElement('div');
                row.className = 'row';
                s.freq.forEach(f => {
                    const id = 'f:' + key(f.set);
                    row.appendChild(chip(fmt(f.set), f.set.length >= 2 ? 'ok' : 'dim', f.count, '', id,
                        () => choose(id, f.set, f.set, () => `${fmt(f.set)} 出現在 ${f.count} 筆交易裡（左上表格標黃的列）。`)));
                });
                box.appendChild(row);
                return;
            }
            if (!s.zv) return;
            const z = s.z;
            s.zv.forEach((rowData, idx) => {
                const lvl = document.createElement('div');
                lvl.className = 'lvl';
                lvl.innerHTML = `<span class="tag">後件<br>${idx + 1} 個</span><div class="row"></div>`;
                const row = lvl.querySelector('.row');
                rowData.forEach(c => {
                    const id = 's:' + key(c.y);
                    let cls = '', badge = '', why = '', prefix = '';
                    if (c.state === 'pass') { cls = 'ok'; badge = pct(c.conf); }
                    else if (c.state === 'fail') { cls = 'bad'; badge = pct(c.conf); }
                    else if (c.state === 'skip') { cls = 'out'; why = c.why ? `含 ${fmt(c.why)}` : '剪掉'; prefix = '這種切法被剪掉，程式沒有算；真的算的話：'; }
                    else { cls = 'wait'; prefix = '還沒輪到；'; }
                    if (s.cur === key(c.y)) cls += ' cur';
                    row.appendChild(chip(ruleText(c.x, c.y), cls, badge, why, id,
                        () => choose(id, c.x, z, () => splitHint(c.x, c.y, z, prefix))));
                });
                box.appendChild(lvl);
            });
        }

        function renderRules(s) {
            const all = (trace.rules || []).slice(0, s.nRules);
            const list = all.slice();
            if (sortBy === 'conf') list.sort((a, b) => b.conf - a.conf || a.order - b.order);
            if (sortBy === 'lift') list.sort((a, b) => b.lift - a.lift || a.order - b.order);
            $('rules-title').textContent = `目前找到的規則（${all.length} 條）`;
            const box = $('rules-box');
            if (!list.length) {
                box.innerHTML = '<div class="rules-empty">還沒有。每一條過關的切法會出現在這裡。</div>';
            } else {
                const table = document.createElement('table');
                table.className = 'rules';
                table.innerHTML = '<thead><tr><th>規則</th><th>支持度</th><th>信賴度</th><th>提升度</th></tr></thead><tbody></tbody>';
                const tb = table.querySelector('tbody');
                list.forEach(r => {
                    const tr = document.createElement('tr');
                    const id = 'r:' + key(r.x) + '>' + key(r.y);
                    const isNew = s.kind === 'pass' && r.order === s.nRules - 1;
                    tr.className = (isNew ? 'new' : '') + (selChip === id ? ' sel' : '');
                    const sign = liftSign(r);
                    tr.innerHTML = `<td class="rule"><span class="a"></span><span class="arrow">→</span><span class="b"></span></td>` +
                        `<td>${r.supZ}</td><td>${pct(r.conf)}</td><td class="${sign > 0 ? 'up' : sign < 0 ? 'down' : 'same'}">${r.lift.toFixed(2)}</td>`;
                    tr.querySelector('.a').textContent = r.x.join('、');
                    tr.querySelector('.b').textContent = r.y.join('、');
                    const z = [...r.x, ...r.y];
                    tr.addEventListener('click', () => choose(id, r.x, z, () => splitHint(r.x, r.y, z)));
                    tb.appendChild(tr);
                });
                box.innerHTML = '';
                box.appendChild(table);
            }
            $('st-test').textContent = s.stats.tested;
            $('st-skip').textContent = s.stats.skipped;
            $('st-brute').textContent = s.stats.brute;
        }

        /* 簡單的語法上色 */
        const KW = {
            java: new Set('public static final for if return new boolean int double void class import while else continue'.split(' ')),
            py: new Set('def for in if return not and or while import from as True False None continue all sum'.split(' '))
        };
        function highlight(line) {
            const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
            const commentAt = lang === 'java' ? line.indexOf('//') : line.indexOf('#');
            let body = line, comment = '';
            if (commentAt >= 0) { body = line.slice(0, commentAt); comment = line.slice(commentAt); }
            if (lang === 'py' && /^\s*"""/.test(line)) { body = ''; comment = line; }
            if (lang === 'java' && /^\s*\/\*\*/.test(line)) { body = ''; comment = line; }
            const out = body.replace(/("(?:[^"\\]|\\.)*")|(\b\d+\b)|([A-Za-z_]\w*)(\s*\()?|([^"\w]+)/g, (m, str, num, word, call, other) => {
                if (str) return `<span class="str">${esc(str)}</span>`;
                if (num) return `<span class="num">${num}</span>`;
                if (word) {
                    if (KW[lang].has(word)) return `<span class="kw">${word}</span>${call ? esc(call) : ''}`;
                    if (call) return `<span class="fn">${word}</span>${esc(call)}`;
                    if (lang === 'java' && /^[A-Z]\w*[a-z]/.test(word)) return `<span class="ty">${word}</span>`;
                    return word;
                }
                return esc(m);
            });
            return out + (comment ? `<span class="cm">${esc(comment)}</span>` : '');
        }

        function renderCode(tag) {
            if (measuringBlocks) return;   // 量區塊高度時不用畫程式碼（程式碼框高度不會變），省時間
            const pre = $('code');
            const lines = CODE[lang];
            pre.innerHTML = lines.map(([text, tags], i) =>
                `<span class="ln${tags.includes(tag) ? ' hl' : ''}" data-n="${i + 1}">${highlight(text) || ' '}</span>`).join('');
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
                let [from, to] = span(hls[0], hls[hls.length - 1]);
                if (to - from > pre.clientHeight - 16) {
                    const bigGroup = groups.reduce((x, y) => (y.length > x.length ? y : x));
                    [from, to] = span(bigGroup[0], bigGroup[bigGroup.length - 1]);
                }
                const target = (from + to) / 2 - pre.clientHeight / 2;
                pre.scrollTo({ top: Math.max(0, Math.min(target, from - 8)), behavior: 'smooth' });
            }
            $('downloads').innerHTML = lang === 'java'
                ? '下載 <a href="code/AssocRules.java" download>AssocRules.java</a>　執行 <code>javac AssocRules.java && java AssocRules</code>'
                : '下載 <a href="code/assoc_rules.py" download>assoc_rules.py</a>　執行 <code>python3 assoc_rules.py</code>';
        }

        function showStep() {
            const s = trace[cursor];
            selected = null;
            selChip = null;
            renderDB();
            $('explain').innerHTML = `<span class="step-no">步驟 ${cursor + 1} / ${trace.length}</span>${describe(s)}`;
            showCands();
            $('cands-hint').textContent = s.kind === 'mine' && s.freq.length ? '點樣式看看是哪幾筆交易'
                : s.zv ? '點任一個切法，看前件和整個樣式各出現在哪幾筆' : '';
            renderRules(s);
            renderCode(CODE_TAG[s.kind]);
            $('btn-prev').disabled = $('btn-first').disabled = cursor === 0;
            $('btn-next').disabled = cursor === trace.length - 1;
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
                probe.innerHTML = `<span class="step-no">步驟 ${i + 1} / ${trace.length}</span>${describe(s)}`;
                tallest = Math.max(tallest, probe.offsetHeight);
            });
            probe.remove();
            box.style.minHeight = tallest + 'px';
            reserveBlockHeights(document, trace.length, i => { cursor = i; showStep(); }, () => cursor);
        }

        function rebuild(keepCursor) {
            stopAuto();
            minSup = Math.max(1, Math.min(minSup, db.length));
            trace = buildTrace();
            cursor = keepCursor ? Math.min(cursor, trace.length - 1) : 0;
            showStep();
            reserveExplainHeight();
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

        // 門檻一改，步驟數會變，回到開頭重新看
        $('sup-minus').addEventListener('click', () => { minSup--; rebuild(false); });
        $('sup-plus').addEventListener('click', () => { minSup++; rebuild(false); });
        $('conf-minus').addEventListener('click', () => { minConfPct = Math.max(5, minConfPct - 5); rebuild(false); });
        $('conf-plus').addEventListener('click', () => { minConfPct = Math.min(100, minConfPct + 5); rebuild(false); });

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
            minConfPct = 70;
            rebuild(false);
        });

        $('lang').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b) return;
            lang = b.dataset.lang;
            [...$('lang').children].forEach(x => x.classList.toggle('active', x === b));
            renderCode(CODE_TAG[trace[cursor].kind]);
        });
        $('sort').addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b) return;
            sortBy = b.dataset.sort;
            [...$('sort').children].forEach(x => x.classList.toggle('active', x === b));
            renderRules(trace[cursor]);
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
