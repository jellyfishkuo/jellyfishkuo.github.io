<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/prefixspan.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/prefixspan-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/prefixspan-180.png">
    <title>PrefixSpan 序列樣式探勘</title>
    <meta name="description" content="一步一步看 PrefixSpan 怎麼用前綴投影找出「先買什麼、之後再買什麼」的序列樣式：投影資料庫、同一次延伸與下一次延伸、遞迴，Java 與 Python 程式碼逐行對照。">
    <style>
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
        .intro a { color: var(--accent2); }

        /* 手機：一欄，依序 步驟 → 序列資料庫 → 計數表 → 程式碼 → 結果；電腦：兩欄 */
        .layout {
            display: grid;
            gap: 1rem;
            margin-top: 1.3rem;
            grid-template-areas: "step" "seq" "count" "code" "result";
            align-items: start;
        }
        .layout > * { min-width: 0; }
        @media (min-width: 960px) {
            .layout {
                grid-template-columns: 1fr 1fr;
                grid-template-areas: "step code" "seq code" "count result";
            }
        }
        .a-step { grid-area: step; }
        .a-seq { grid-area: seq; }
        .a-count { grid-area: count; }
        .a-code { grid-area: code; }
        .a-result { grid-area: result; }

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
        button.btn.small { padding: 0.25rem 0.55rem; font-size: 0.8rem; }

        .player { display: flex; flex-wrap: wrap; gap: 0.4rem; align-items: center; }
        .minsup { display: flex; align-items: center; gap: 0.45rem; font-size: 0.88rem; margin-left: auto; }
        .minsup .val { font: 700 1rem 'Space Mono', monospace; min-width: 1.2em; text-align: center; }
        .minsup .unit { color: var(--muted); font-size: 0.8rem; }
        .stepper { width: 30px; height: 30px; padding: 0 !important; }
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
        .pt { white-space: nowrap; font-weight: 600; color: var(--text); }

        /* ── 序列資料庫 ── */
        .presets { display: flex; flex-wrap: wrap; gap: 0.35rem; margin-bottom: 0.6rem; }
        .presets .btn.cur { border-color: var(--accent2); color: var(--accent2); }
        .crumbs { display: flex; flex-wrap: wrap; gap: 0.3rem; align-items: center; font-size: 0.8rem; color: var(--muted); margin-bottom: 0.55rem; min-height: 1.6rem; }
        .crumb { border: 1px solid var(--border); border-radius: 6px; padding: 0.05rem 0.45rem; white-space: nowrap; }
        .crumb.cur { border-color: var(--accent); color: var(--text); background: rgba(124, 58, 237, 0.15); }
        .arrow { color: #4a4a66; font-size: 0.75rem; }
        .seqs { display: grid; gap: 0.25rem; }
        .srow { display: grid; grid-template-columns: 2.9em minmax(0, 1fr) auto; column-gap: 0.45rem; align-items: center; padding: 0.3rem 0.4rem; border-radius: 8px; transition: background 0.2s; }
        .srow .who { font-size: 0.8rem; color: var(--muted); white-space: nowrap; }
        .srow.gone .visits, .srow.gone .who { opacity: 0.3; }
        .srow.pick { background: rgba(6, 182, 212, 0.13); }
        .srow.pick .who { color: var(--accent2); }
        .srow .mark { font-size: 0.72rem; color: var(--muted); white-space: nowrap; }
        .srow .mark.drop { color: var(--bad); }
        .srow .post { grid-column: 2 / 4; font: 0.72rem 'Space Mono', monospace; color: var(--muted); margin-top: 0.15rem; overflow-wrap: anywhere; }
        .srow .post b { color: var(--accent2); font-weight: 400; }
        .visits { display: flex; flex-wrap: wrap; gap: 0.25rem; align-items: center; min-width: 0; }
        .visit { display: inline-flex; align-items: center; border: 1px solid var(--border); border-radius: 8px; padding: 0.05rem 0.25rem; background: #16162a; font-size: 1.05rem; line-height: 1.45; }
        .visit.past { opacity: 0.28; }
        .visit.also { border: 1.5px dashed var(--accent2); }
        .it { padding: 0 0.1rem; border-radius: 5px; }
        .it.used { opacity: 0.3; }
        .it.anchor { box-shadow: 0 0 0 2px var(--accent); }
        .it.anchor.new { box-shadow: 0 0 0 2px var(--warn); background: rgba(245, 158, 11, 0.18); }
        .it.under { border-bottom: 2px dashed var(--accent2); border-radius: 0; }
        .us { color: var(--accent2); font: 700 0.8rem 'Space Mono', monospace; margin: 0 0.05rem; }
        .legend { display: flex; flex-wrap: wrap; gap: 0.3rem 0.9rem; font-size: 0.75rem; color: var(--muted); margin-top: 0.6rem; }
        .legend .sw { display: inline-block; width: 13px; height: 13px; border-radius: 4px; margin-right: 0.3rem; vertical-align: -2px; }

        /* 編輯 */
        .db-foot { display: flex; flex-wrap: wrap; gap: 0.4rem; margin-top: 0.6rem; }
        .editing .visit { cursor: pointer; }
        .editing .visit:hover { border-color: var(--accent2); }
        .editing .visit.sel { border: 2px solid var(--accent2); background: rgba(6, 182, 212, 0.12); }
        .editing .visit.empty { min-width: 2em; min-height: 1.6em; justify-content: center; color: var(--muted); font-size: 0.75rem; }
        .addv, .delc { background: none; border: 1px dashed #3a3a5a; color: var(--muted); border-radius: 7px; width: 1.9em; height: 1.75em; cursor: pointer; font-size: 0.85rem; }
        .addv:hover, .delc:hover { border-color: var(--accent2); color: var(--text); }
        .delc { border-style: solid; }
        .palette { margin-top: 0.6rem; padding: 0.55rem; border: 1px solid var(--border); border-radius: 10px; background: var(--panel-2); font-size: 0.82rem; color: var(--muted); }
        .palette .opts { display: flex; flex-wrap: wrap; gap: 0.3rem; margin-top: 0.35rem; }
        .palette .opt { background: #1b1b30; border: 1px solid var(--border); color: var(--text); border-radius: 8px; padding: 0.2rem 0.45rem; font-size: 0.85rem; cursor: pointer; }
        .palette .opt.on { border-color: var(--accent2); background: rgba(6, 182, 212, 0.18); }
        .palette .opt:disabled { opacity: 0.35; cursor: default; }

        /* ── 計數表 ── */
        .prefix-line { font-size: 0.85rem; color: var(--muted); margin-bottom: 0.5rem; }
        .prefix-line .pt { font-size: 0.95rem; }
        table.cnt { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
        table.cnt th { font-weight: 500; color: var(--muted); font-size: 0.76rem; text-align: center; padding: 0.25rem; border-bottom: 1px solid var(--border); line-height: 1.3; }
        table.cnt th:first-child { text-align: left; }
        table.cnt th small { display: block; font-size: 0.68rem; color: #6a6a85; }
        table.cnt td { padding: 0.2rem 0.25rem; border-bottom: 1px solid var(--border); text-align: center; }
        table.cnt td.nm { text-align: left; white-space: nowrap; }
        table.cnt td.c { font: 700 0.85rem 'Space Mono', monospace; }
        td.c span { display: inline-block; min-width: 2.4em; padding: 0.05rem 0.3rem; border-radius: 6px; border: 1px solid transparent; }
        td.c.zero span { color: #44445c; font-weight: 400; }
        td.c.no span { color: var(--muted); font-weight: 400; cursor: pointer; }
        td.c.ok span { color: #86efac; border-color: rgba(34, 197, 94, 0.45); cursor: pointer; }
        td.c.na span { color: #44445c; font-weight: 400; }
        td.c.done span { background: rgba(34, 197, 94, 0.14); }
        td.c.cur span { border-color: var(--warn); box-shadow: 0 0 0 1px var(--warn); color: var(--warn); }
        td.c.picked span { background: rgba(6, 182, 212, 0.22); }
        .cnt-hint { font-size: 0.8rem; color: var(--muted); margin-top: 0.5rem; min-height: 2.6em; }
        .cnt-hint b { color: var(--text); font-weight: 600; }

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
            max-height: 620px;
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
        .pat { font-size: 0.85rem; border: 1px solid rgba(34, 197, 94, 0.5); border-radius: 7px; padding: 0.1rem 0.45rem; white-space: nowrap; }
        .pat .n { font: 700 0.74rem 'Space Mono', monospace; margin-left: 0.35rem; color: #86efac; }
        .pat.fresh { box-shadow: 0 0 0 2px var(--warn); }
        .empty { color: var(--muted); font-size: 0.85rem; }
        .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.5rem; margin-top: 0.9rem; }
        .stat { background: var(--panel-2); border-radius: 10px; padding: 0.55rem 0.6rem; min-width: 0; }
        .stat .v { font: 700 1.25rem 'Space Mono', monospace; }
        .stat .k { color: var(--muted); font-size: 0.75rem; line-height: 1.35; }
        .compare { margin-top: 0.8rem; font-size: 0.85rem; color: var(--muted); }
        .compare b { color: var(--text); }

        .notes { margin-top: 1rem; display: grid; gap: 1rem; }
        .notes > * { min-width: 0; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr; } }
        .notes p, .notes li { color: #c6c6d6; font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; }
        .notes b { color: var(--text); }
        .notes a { color: var(--accent2); }
    </style>
</head>

<body>
    <div class="wrap">
        <a class="back" href="../index.html#research">← RETURN TO PORTFOLIO</a>
        <div class="kicker">RESEARCH DEMO · SEQUENTIAL PATTERN MINING</div>
        <h1>PrefixSpan 序列樣式探勘<small>不只看一起買什麼，還看「先買什麼、之後再買什麼」</small></h1>
        <p class="intro">
            <a href="apriori.html">Apriori</a> 和 <a href="fp-growth.html">FP-Growth</a> 只看「同一張發票裡一起買了什麼」。
            這頁換成看<b>順序</b>：把同一位常客每次來店買的東西照時間排成一個序列，找出很多人都有的「先…之後…」，
            例如 &lt;(☕🍞)(🍙)&gt;：某次一起買了咖啡和麵包，<b>之後</b>又回來買飯糰（中間隔幾次、有沒有買別的都沒關係）。
            PrefixSpan 跟 FP-Growth 一樣是分而治之：先找出頻繁的開頭（<b>前綴</b>），只留下每個人「前綴之後還剩下的部分」（<b>投影資料庫</b>），
            在裡面數一數能再接什麼，接上之後再遞迴。
        </p>

        <div class="layout">
            <div class="card a-step">
                <div class="player">
                    <button class="btn" id="btn-first" title="回到開頭">⏮</button>
                    <button class="btn" id="btn-prev">◀ 上一步</button>
                    <button class="btn primary" id="btn-next">下一步 ▶</button>
                    <button class="btn" id="btn-play">▶ 自動播放</button>
                    <div class="minsup">
                        <span>最小支持度</span>
                        <button class="btn stepper" id="sup-minus" aria-label="減少">−</button>
                        <span class="val" id="sup-val">3</span>
                        <button class="btn stepper" id="sup-plus" aria-label="增加">+</button>
                        <span class="unit">人</span>
                    </div>
                </div>
                <div class="explain" id="explain"></div>
            </div>

            <div class="card a-seq" id="seq-card">
                <div class="card-head"><h2 id="seq-title">序列資料庫</h2></div>
                <div class="presets" id="presets"></div>
                <div class="crumbs" id="crumbs"></div>
                <div class="seqs" id="seqs"></div>
                <div class="palette" id="palette" hidden></div>
                <div class="db-foot">
                    <button class="btn small" id="btn-edit">✎ 編輯資料</button>
                    <button class="btn small" id="btn-add-cust" hidden>＋ 新增顧客</button>
                </div>
                <div class="legend" id="legend">
                    <span><i class="sw" style="background:#2a2a40;opacity:.5"></i>淡掉：前綴已經用掉的部分</span>
                    <span><i class="sw" style="box-shadow:0 0 0 2px var(--accent) inset"></i>前綴最後一個商品配對到這裡（投影點）</span>
                    <span><i class="sw" style="border-bottom:2px dashed var(--accent2);border-radius:0"></i>底線 _：跟它同一次買、排在後面的</span>
                    <span><i class="sw" style="border:1.5px dashed var(--accent2)"></i>後面某次又買齊了前綴的最後一次</span>
                </div>
            </div>

            <div class="card a-count">
                <h2>計數表：前綴後面能接什麼？</h2>
                <div class="prefix-line" id="prefix-line"></div>
                <table class="cnt" id="cnt"></table>
                <div class="cnt-hint" id="cnt-hint"></div>
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
                <h2>目前找到的頻繁序列樣式</h2>
                <div class="levels" id="levels"></div>
                <div class="stats">
                    <div class="stat"><div class="v" id="st-proj">0</div><div class="k">建過的投影資料庫</div></div>
                    <div class="stat"><div class="v" id="st-cells">0</div><div class="k">計數表裡數過的格子</div></div>
                    <div class="stat"><div class="v" id="st-depth">0</div><div class="k">最深的遞迴層</div></div>
                </div>
                <div class="compare" id="compare"></div>
            </div>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼只看「前綴後面剩下的」就夠了？</h2>
                <p>想知道 &lt;(☕)(🍙)&gt; 後面還能接什麼，只要看每個人<b>第一次</b>出現 &lt;(☕)(🍙)&gt; 之後的部分：
                    越早配對完，後面剩的越多，所以任何能接在後面的東西，一定都還在這段「後綴」裡，不會漏掉。
                    每多接一個商品，投影資料庫只會變短、變少人，而且<b>接不上的人以後也不可能再接上</b>（序列版的向下封閉性），所以可以直接丟掉。</p>
                <p style="margin-top:0.5rem">一次可以買好幾樣，所以要分兩種接法：<b>同一次</b>（i-延伸，&lt;(☕)&gt; → &lt;(☕🍞)&gt;）和<b>下一次以後</b>（s-延伸，&lt;(☕)&gt; → &lt;(☕)(🍞)&gt;）。
                    同一次裡的商品照固定順序（程式裡照字碼）排，只往後面接，每個樣式才只會被找到一次。
                    要小心的是：同一次延伸不只看底線 _ 那一格，後面如果某次又<b>買齊了前綴的最後一次</b>，那次裡的商品也算，不然會漏掉。</p>
            </div>
            <div class="card">
                <h2>優缺點、跟前面方法的關係</h2>
                <ul>
                    <li><b>不產生候選：</b>跟 FP-Growth 一樣是「樣式成長」，只去接投影資料庫裡真的出現過的商品；不像序列版的 Apriori（GSP），要先猜一大堆候選序列再整個資料庫掃一遍。</li>
                    <li><b>問題越切越小：</b>每往下一層，資料只剩前綴後面的一段，而且只剩接得上的人。</li>
                    <li><b>代價：</b>每一層都要建投影資料庫。實作上不複製資料，只記「每個人投影到哪裡」（這頁的 (sid, e, p) 就是這樣），稱為偽投影（pseudo-projection）。</li>
                    <li>序列樣式也能跟其他研究方向結合：把「次數」換成「效益」就是高效益序列樣式；資料一直進來就是資料串流上的序列探勘。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           PrefixSpan 一步一步看
           網頁裡用 JavaScript 照著同樣的流程跑一次，把每一步（含每一層遞迴）記下來；
           右邊的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = /*CODE_JSON*/null;

        const ITEMS = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片'];
        const EMOJI = { '咖啡': '☕', '麵包': '🍞', '牛奶': '🥛', '飯糰': '🍙', '茶葉蛋': '🥚', '洋芋片': '🥔' };
        const NAMES = ['阿明', '小美', '阿傑', '小芳', '阿華', '小玉', '阿德', '小婷'];
        const MAX_CUST = 8, MAX_VISITS = 5, MAX_ITEMS = 3;
        const C = '咖啡', B = '麵包', M = '牛奶', R = '飯糰', E = '茶葉蛋', P = '洋芋片';
        const PRESETS = [
            {
                label: '早餐→午餐', sup: 3, db: [
                    [[C, B], [R, E], [P]],
                    [[C], [R, E], [C, B]],
                    [[C, B], [M], [R]],
                    [[B, M], [C, B], [R, P]],
                    [[C, B, E], [R, E]],
                    [[M], [B], [P]]
                ]
            },
            {
                label: '一次買好幾樣', sup: 3, db: [
                    [[C, B, M], [R, E]],
                    [[C, M], [C, B], [R, E]],
                    [[B], [C, B, M], [R]],
                    [[C, B], [M], [C, M, R]],
                    [[P], [C, B, M], [E]]
                ]
            },
            {
                label: '一直回購', sup: 2, db: [
                    [[C], [B], [C], [C]],
                    [[C, P], [C], [R], [C]],
                    [[B], [C], [B], [C]],
                    [[C], [M], [C, B], [B]],
                    [[R], [C], [R], [C, E]]
                ]
            }
        ];

        const $ = id => document.getElementById(id);
        const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);   // 跟 Java compareTo、Python 字串比較一樣：照字碼
        const normSeq = seq => seq.filter(e => e.length).map(e => [...new Set(e)].sort(cmp));
        let db = PRESETS[0].db.map(normSeq);
        let preset = 0;
        let minSup = PRESETS[0].sup;
        let lang = 'java';
        let trace = [];
        let cursor = 0;
        let timer = null;
        let picked = null;        // 計數表上點選的格子 {x, k}
        let editing = false;
        let selVisit = null;      // 編輯時選到的那一次來店 [sid, k]

        const emo = x => EMOJI[x] || x;
        const patText = pat => '<' + pat.map(e => '(' + e.map(emo).join('') + ')').join('') + '>';
        const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        const pt = pat => `<span class="pt">${esc(patText(pat))}</span>`;
        const elText = e => '(' + e.map(emo).join('') + ')';
        const names = sids => sids.map(i => NAMES[i]).join('、');

        /* ---------- 照著程式跑一次，記下每一步 ---------- */
        function buildTrace(dbIn, minSup) {
            const seqs = dbIn.map(normSeq);
            const steps = [];
            const result = [];
            const stats = { projs: 0, cells: 0, depth: 0 };
            const stack = [];
            const push = o => steps.push({ result: result.map(r => ({ ...r })), stats: { ...stats }, ...o });

            function project(proj, last, x, same) {
                const out = [];
                for (const pr of proj) {
                    const seq = seqs[pr.sid];
                    for (let k = same ? pr.e : pr.e + 1; k < seq.length; k++) {
                        const q = seq[k].indexOf(x);
                        if (q < 0) continue;
                        if (same && !(last.every(y => seq[k].includes(y)) && q > seq[k].indexOf(last[last.length - 1]))) continue;
                        out.push({ sid: pr.sid, e: k, p: q });
                        break;
                    }
                }
                return out;
            }

            function mine(prefix, proj, depth) {
                stats.projs++;
                stats.depth = Math.max(stats.depth, depth);
                stack.push(prefix);
                const last = prefix.length ? prefix[prefix.length - 1] : null;
                const cnt = { i: {}, s: {} }, who = { i: {}, s: {} };
                const also = {};          // sid → 後面又買齊 last 的那幾次
                const special = [];       // 只靠「後面又買齊」才算到的同一次延伸
                for (const pr of proj) {
                    const seq = seqs[pr.sid];
                    const iSeen = new Set(), sSeen = new Set();
                    if (last) {
                        seq[pr.e].slice(pr.p + 1).forEach(x => iSeen.add(x));
                        const extra = [];
                        for (let k = pr.e + 1; k < seq.length; k++) {
                            if (!last.every(y => seq[k].includes(y))) continue;
                            (also[pr.sid] = also[pr.sid] || []).push(k);
                            seq[k].forEach(x => {
                                if (x > last[last.length - 1] && !iSeen.has(x)) { iSeen.add(x); extra.push(x); }
                            });
                        }
                        if (extra.length) special.push({ sid: pr.sid, items: extra.sort(cmp) });
                    }
                    for (let k = pr.e + 1; k < seq.length; k++) seq[k].forEach(x => sSeen.add(x));
                    iSeen.forEach(x => { cnt.i[x] = (cnt.i[x] || 0) + 1; (who.i[x] = who.i[x] || []).push(pr.sid); });
                    sSeen.forEach(x => { cnt.s[x] = (cnt.s[x] || 0) + 1; (who.s[x] = who.s[x] || []).push(pr.sid); });
                }
                stats.cells += Object.keys(cnt.i).length + Object.keys(cnt.s).length;
                const exts = [
                    ...Object.keys(cnt.i).sort(cmp).filter(x => cnt.i[x] >= minSup).map(x => ({ x, k: 'i' })),
                    ...Object.keys(cnt.s).sort(cmp).filter(x => cnt.s[x] >= minSup).map(x => ({ x, k: 's' }))
                ];
                const counts = { cnt, who };
                push({ kind: 'count', prefix, proj, depth, counts, also, special, exts, crumbs: stack.slice() });
                const done = [];
                for (const ext of exts) {
                    const pattern = ext.k === 'i' ? [...prefix.slice(0, -1), [...last, ext.x]] : [...prefix, [ext.x]];
                    const sup = cnt[ext.k][ext.x];
                    result.push({ pat: pattern, sup, fresh: true });
                    const np = project(proj, last, ext.x, ext.k === 'i');
                    const dropped = proj.filter(pr => !np.some(q => q.sid === pr.sid)).map(pr => pr.sid);
                    const moved = np.filter(q => { const o = proj.find(pr => pr.sid === q.sid); return ext.k === 'i' && q.e !== o.e; }).map(q => q.sid);
                    push({ kind: 'extend', prefix, pattern, ext, sup, proj: np, depth, counts, dropped, moved, done: done.slice(), crumbs: [...stack, pattern] });
                    result.forEach(r => { r.fresh = false; });
                    done.push(ext);
                    mine(pattern, np, depth + 1);
                }
                stack.pop();
            }

            const all = seqs.map((_, i) => ({ sid: i, e: -1, p: -1 }));
            push({ kind: 'start', prefix: [], proj: all, depth: 0, crumbs: [] });
            mine([], all, 0);
            push({ kind: 'end', prefix: [], proj: all, depth: 0, crumbs: [] });
            steps.forEach((s, i) => { s.seqs = seqs; s.back = i > 0 && s.kind === 'extend' && steps[i - 1].depth > s.depth; });
            return steps;
        }

        /* 暴力法要比對的候選：每位顧客所有可能的子序列（不重複） */
        function bruteCandidates(seqs) {
            const all = new Set();
            seqs.forEach(seq => {
                (function rec(k, cur) {
                    if (k === seq.length) { if (cur) all.add(cur); return; }
                    rec(k + 1, cur);
                    const e = seq[k], n = e.length;
                    for (let mask = 1; mask < (1 << n); mask++)
                        rec(k + 1, cur + '(' + e.filter((_, j) => mask >> j & 1).join(',') + ')');
                })(0, '');
            });
            return all.size;
        }

        /* ---------- 說明文字 ---------- */
        function describe(s) {
            const N = s.seqs.length;
            switch (s.kind) {
                case 'start':
                    return `每一列是一位常客，照時間排好他每次來店買了什麼（一個框是一次，可以買好幾樣）。` +
                        `一個序列樣式的<b>支持度</b>＝有幾位顧客的紀錄裡找得到它（同一個人出現好幾次也只算 1 人）。` +
                        `目標：找出至少 <b>${minSup}</b> 位顧客都有的所有序列樣式。`;
                case 'count': {
                    const ok = s.exts.map(e => pt(e.k === 'i' ? [...s.prefix.slice(0, -1), [...s.prefix[s.prefix.length - 1], e.x]] : [...s.prefix, [e.x]]));
                    if (!s.prefix.length) {
                        return `第一次掃描：數每個商品有幾位顧客買過（不管買幾次都只算一次），看最右邊那一欄。` +
                            (ok.length ? `至少 ${minSup} 人的是 ${ok.join(' ')}，每一個都當成一個<b>前綴</b>，一個一個往下挖。` : `沒有任何商品達到 ${minSup} 人，什麼都找不到。`);
                    }
                    const last = s.prefix[s.prefix.length - 1];
                    let txt = `前綴 ${pt(s.prefix)} 的<b>投影資料庫</b>：只剩 ${s.proj.length} 位顧客，淡掉的是前綴用掉的部分。數兩種接法：` +
                        `<b>同一次</b>（跟 ${esc(elText(last))} 同一次買、排在後面的，就是底線 _ 那格）和<b>下一次以後</b>（投影點之後任何一次）。`;
                    if (s.special.length) {
                        const sp = s.special[0];
                        txt += `注意${NAMES[sp.sid]}：底線那格沒有 ${sp.items.map(emo).join('')}，但後面某次又買齊了 ${esc(elText(last))}（青色虛線框），所以同一次的 ${sp.items.map(emo).join('')} 也算${NAMES[sp.sid]}一份。`;
                    }
                    txt += ok.length ? `夠 ${minSup} 人的：${ok.join(' ')}。` : `沒有任何接法達到 ${minSup} 人，${pt(s.prefix)} 不能再長了，回到上一層。`;
                    return txt;
                }
                case 'extend': {
                    const x = emo(s.ext.x);
                    let txt = s.back ? `回到前綴 ${s.prefix.length ? pt(s.prefix) : '（空的）'}，換下一個。` : '';
                    if (!s.prefix.length) {
                        txt += `前綴 ${pt(s.pattern)}：${s.sup} 位顧客買過 ${x}，記下來。把每個人的投影點放在<b>第一次</b>買 ${x} 的地方（橘框），後面剩下的就是投影資料庫。`;
                    } else if (s.ext.k === 'i') {
                        txt += `<b>同一次延伸</b>：把 ${x} 放進最後一次 → ${pt(s.pattern)}，${s.sup} 人，記下來。投影點移到同一次裡的 ${x}（橘框）` +
                            (s.moved.length ? `；${names(s.moved)}要跳到後面那次買齊的地方` : '') + `。`;
                    } else {
                        txt += `<b>下一次延伸</b>：之後某一次買 ${x} → ${pt(s.pattern)}，${s.sup} 人，記下來。投影點移到投影點之後第一次買 ${x} 的地方（橘框）。`;
                    }
                    if (s.dropped.length) txt += `${names(s.dropped)}接不上，拿掉。`;
                    return txt + `接著用這個更小的投影資料庫遞迴。`;
                }
                case 'end': {
                    return `完成！共找到 <b>${s.result.length}</b> 個頻繁序列樣式。過程中建了 ${s.stats.projs} 個投影資料庫，每往下一層都只剩前綴後面的部分；` +
                        `暴力法要把所有顧客可能的子序列（${bruteCandidates(s.seqs)} 種）一個一個拿去比對。`;
                }
            }
            return '';
        }

        const CODE_TAGS = s => ({
            start: ['start'],
            count: s.prefix && s.prefix.length ? ['scan', 'iscan'] : ['scan'],
            extend: s.ext ? [s.ext.k === 'i' ? 'iext' : 'sext', 'loop', 'project'] : [],
            end: ['end']
        })[s.kind] || [];

        /* ---------- 序列資料庫 ---------- */
        function drawCrumbs(s) {
            const box = $('crumbs');
            const crumbs = s.crumbs.length ? s.crumbs : [[]];
            box.innerHTML = '前綴：' + crumbs.map((c, i) =>
                `<span class="crumb${i === crumbs.length - 1 ? ' cur' : ''}">${c.length ? esc(patText(c)) : '空的'}</span>`).join('<span class="arrow">›</span>');
        }

        function drawSeqs(s) {
            const box = $('seqs');
            box.innerHTML = '';
            const projOf = {};
            s.proj.forEach(pr => { projOf[pr.sid] = pr; });
            const pickSet = new Set(picked && s.counts ? (s.counts.who[picked.k][picked.x] || []) : []);
            const showPost = s.prefix.length > 0 || s.kind === 'extend';
            $('seq-title').textContent = s.kind === 'start' || s.kind === 'end' || (s.kind === 'count' && !s.prefix.length) ? '序列資料庫' :
                `投影資料庫：前綴 ${patText(s.kind === 'extend' ? s.pattern : s.prefix)}`;
            s.seqs.forEach((seq, sid) => {
                const pr = projOf[sid];
                const row = document.createElement('div');
                row.className = 'srow' + (pr ? '' : ' gone') + (pickSet.has(sid) ? ' pick' : '');
                const who = document.createElement('span');
                who.className = 'who';
                who.textContent = NAMES[sid];
                row.appendChild(who);
                const vis = document.createElement('div');
                vis.className = 'visits';
                const also = new Set((s.kind === 'count' && s.also && s.also[sid]) || []);
                let post = '';
                seq.forEach((e, k) => {
                    if (k) { const a = document.createElement('span'); a.className = 'arrow'; a.textContent = '›'; vis.appendChild(a); }
                    const v = document.createElement('span');
                    v.className = 'visit';
                    if (pr && k < pr.e) v.classList.add('past');
                    if (also.has(k)) v.classList.add('also');
                    let under = false;
                    e.forEach((x, j) => {
                        const it = document.createElement('span');
                        it.className = 'it';
                        it.title = x;
                        if (pr && k === pr.e) {
                            if (j < pr.p) it.classList.add('used');
                            else if (j === pr.p) { it.classList.add('anchor'); if (s.kind === 'extend') it.classList.add('new'); }
                            else {
                                if (!under) { const u = document.createElement('span'); u.className = 'us'; u.textContent = '_'; v.appendChild(u); under = true; }
                                it.classList.add('under');
                            }
                        }
                        it.textContent = emo(x);
                        v.appendChild(it);
                    });
                    vis.appendChild(v);
                    if (pr && k === pr.e && pr.p < e.length - 1) post += '(_' + e.slice(pr.p + 1).map(emo).join('') + ')';
                    if (pr && k > pr.e) post += elText(e);
                });
                if (!seq.length) { const n = document.createElement('span'); n.className = 'mark'; n.textContent = '（沒有來店紀錄）'; vis.appendChild(n); }
                row.appendChild(vis);
                const mark = document.createElement('span');
                mark.className = 'mark';
                if (!pr && s.kind === 'extend' && s.dropped.includes(sid)) { mark.classList.add('drop'); mark.textContent = '✕ 接不上'; }
                else if (!pr) mark.textContent = '—';
                row.appendChild(mark);
                if (showPost && pr) {
                    const pd = document.createElement('div');
                    pd.className = 'post';
                    pd.textContent = '後綴 ' + (post || '（後面沒有了）');
                    row.appendChild(pd);
                }
                box.appendChild(row);
            });
        }

        /* 編輯模式：點一次來店選起來，再用下面的按鈕增減商品 */
        function drawEditor() {
            const box = $('seqs');
            box.innerHTML = '';
            $('seq-title').textContent = '編輯序列資料庫';
            db.forEach((seq, sid) => {
                const row = document.createElement('div');
                row.className = 'srow';
                const who = document.createElement('span');
                who.className = 'who';
                who.textContent = NAMES[sid];
                row.appendChild(who);
                const vis = document.createElement('div');
                vis.className = 'visits';
                seq.forEach((e, k) => {
                    if (k) { const a = document.createElement('span'); a.className = 'arrow'; a.textContent = '›'; vis.appendChild(a); }
                    const v = document.createElement('span');
                    v.className = 'visit' + (selVisit && selVisit[0] === sid && selVisit[1] === k ? ' sel' : '') + (e.length ? '' : ' empty');
                    v.dataset.sid = sid;
                    v.dataset.k = k;
                    v.textContent = e.length ? e.map(emo).join('') : '空';
                    vis.appendChild(v);
                });
                if (seq.length < MAX_VISITS) {
                    const add = document.createElement('button');
                    add.className = 'addv';
                    add.dataset.add = sid;
                    add.title = '加一次來店';
                    add.setAttribute('aria-label', `${NAMES[sid]} 加一次來店`);
                    add.textContent = '＋';
                    vis.appendChild(add);
                }
                row.appendChild(vis);
                const del = document.createElement('button');
                del.className = 'delc';
                del.dataset.del = sid;
                del.title = '刪除這位顧客';
                del.setAttribute('aria-label', `刪除${NAMES[sid]}`);
                del.textContent = '✕';
                row.appendChild(del);
                box.appendChild(row);
            });
            const pal = $('palette');
            if (!selVisit || !db[selVisit[0]] || !db[selVisit[0]][selVisit[1]]) {
                pal.innerHTML = '';
                pal.textContent = '點一個框（一次來店）來改裡面的商品；按 ＋ 幫那位顧客多加一次來店。';
                return;
            }
            const e = db[selVisit[0]][selVisit[1]];
            pal.innerHTML = '';
            const tip = document.createElement('div');
            tip.textContent = `${NAMES[selVisit[0]]} 第 ${selVisit[1] + 1} 次來店買了（最多 ${MAX_ITEMS} 樣）：`;
            pal.appendChild(tip);
            const opts = document.createElement('div');
            opts.className = 'opts';
            ITEMS.forEach(x => {
                const b = document.createElement('button');
                const on = e.includes(x);
                b.className = 'opt' + (on ? ' on' : '');
                b.dataset.item = x;
                b.disabled = !on && e.length >= MAX_ITEMS;
                b.textContent = `${emo(x)} ${x}`;
                opts.appendChild(b);
            });
            const rm = document.createElement('button');
            rm.className = 'opt';
            rm.dataset.rmv = '1';
            rm.textContent = '🗑 刪掉這次';
            opts.appendChild(rm);
            pal.appendChild(opts);
        }

        function cleanDb() { db = db.map(seq => normSeq(seq)); }

        function setEditing(on) {
            editing = on;
            selVisit = null;
            if (!on) cleanDb();
            $('seq-card').classList.toggle('editing', on);
            $('palette').hidden = !on;
            $('btn-add-cust').hidden = !on;
            $('btn-edit').textContent = on ? '✓ 編輯完成' : '✎ 編輯資料';
            $('legend').hidden = on;
            rebuild();
        }
        function dataChanged() {
            preset = -1;
            rebuild();
        }

        $('seqs').addEventListener('click', ev => {
            if (!editing) return;
            const v = ev.target.closest('.visit[data-sid]');
            const add = ev.target.closest('[data-add]');
            const del = ev.target.closest('[data-del]');
            if (v) {
                const sid = Number(v.dataset.sid);
                let k = Number(v.dataset.k);
                // 換選別的框時，剛剛那個如果還是空的就拿掉
                if (selVisit && !(selVisit[0] === sid && selVisit[1] === k) && db[selVisit[0]] && db[selVisit[0]][selVisit[1]] && !db[selVisit[0]][selVisit[1]].length) {
                    db[selVisit[0]].splice(selVisit[1], 1);
                    if (selVisit[0] === sid && selVisit[1] < k) k--;
                }
                selVisit = [sid, k];
                drawEditor();
            } else if (add) {
                const sid = Number(add.dataset.add);
                db[sid] = db[sid].filter(e => e.length);
                db[sid].push([]);
                selVisit = [sid, db[sid].length - 1];
                dataChanged();
            } else if (del) {
                db.splice(Number(del.dataset.del), 1);
                selVisit = null;
                dataChanged();
            }
        });
        $('palette').addEventListener('click', ev => {
            const b = ev.target.closest('button');
            if (!b || !selVisit) return;
            const [sid, k] = selVisit;
            if (b.dataset.rmv) {
                db[sid].splice(k, 1);
                selVisit = null;
            } else {
                const e = db[sid][k];
                const x = b.dataset.item;
                db[sid][k] = e.includes(x) ? e.filter(y => y !== x) : [...e, x].sort(cmp);
            }
            dataChanged();
        });
        $('btn-edit').addEventListener('click', () => setEditing(!editing));
        $('btn-add-cust').addEventListener('click', () => {
            if (db.length >= MAX_CUST) return;
            db.push([[ITEMS[0]]]);
            selVisit = [db.length - 1, 0];
            dataChanged();
        });

        function drawPresets() {
            const box = $('presets');
            box.innerHTML = '';
            PRESETS.forEach((p, i) => {
                const b = document.createElement('button');
                b.className = 'btn small' + (i === preset ? ' cur' : '');
                b.textContent = p.label;
                b.addEventListener('click', () => {
                    preset = i;
                    db = p.db.map(normSeq);
                    minSup = p.sup;
                    if (editing) setEditing(false); else rebuild();
                });
                box.appendChild(b);
            });
            const r = document.createElement('button');
            r.className = 'btn small';
            r.textContent = '🎲 隨機';
            r.addEventListener('click', () => {
                preset = -1;
                const n = 5 + Math.floor(Math.random() * 2);
                db = Array.from({ length: n }, () => Array.from({ length: 2 + Math.floor(Math.random() * 3) }, () => {
                    const pool = ITEMS.slice();
                    return Array.from({ length: 1 + Math.floor(Math.random() * 3) }, () => pool.splice(Math.floor(Math.random() * pool.length), 1)[0]);
                })).map(normSeq);
                minSup = Math.min(minSup, db.length);
                if (editing) setEditing(false); else rebuild();
            });
            box.appendChild(r);
        }

        /* ---------- 計數表 ---------- */
        function drawCount(s) {
            const t = $('cnt');
            const hint = $('cnt-hint');
            const line = $('prefix-line');
            if (!s.counts) {
                line.innerHTML = s.kind === 'end' ? '全部挖完了。' : '還沒開始數。按「下一步」。';
                t.innerHTML = '';
                hint.textContent = '';
                return;
            }
            line.innerHTML = `目前的前綴：${s.prefix.length ? pt(s.prefix) : '<span class="pt">空的</span>（還沒選任何商品）'}`;
            const { cnt } = s.counts;
            const last = s.prefix.length ? s.prefix[s.prefix.length - 1] : null;
            const isDone = (x, k) => s.kind === 'extend' && s.done.some(d => d.x === x && d.k === k);
            const isCur = (x, k) => s.kind === 'extend' && s.ext.x === x && s.ext.k === k;
            const cell = (x, k) => {
                if (k === 'i' && !last) return '<td class="c na"><span>—</span></td>';
                if (k === 'i' && x <= last[last.length - 1]) return '<td class="c na"><span>—</span></td>';
                const n = cnt[k][x] || 0;
                const cls = ['c', n === 0 ? 'zero' : n >= minSup ? 'ok' : 'no', isDone(x, k) ? 'done' : '', isCur(x, k) ? 'cur' : '',
                    picked && picked.x === x && picked.k === k ? 'picked' : ''].join(' ');
                return `<td class="${cls}" data-x="${n ? x : ''}" data-k="${k}"><span>${n}</span></td>`;
            };
            t.innerHTML = `<thead><tr><th>商品</th><th>同一次<small>i-延伸 (…x)</small></th><th>下一次以後<small>s-延伸 (…)(x)</small></th></tr></thead><tbody>` +
                ITEMS.slice().sort(cmp).map(x => `<tr><td class="nm">${emo(x)} ${x}</td>${cell(x, 'i')}${cell(x, 's')}</tr>`).join('') + '</tbody>';
            if (picked && s.counts.who[picked.k][picked.x]) {
                const pat = picked.k === 'i' ? [...s.prefix.slice(0, -1), [...last, picked.x]] : [...s.prefix, [picked.x]];
                hint.innerHTML = `${pt(pat)}：${esc(names(s.counts.who[picked.k][picked.x]))}（序列資料庫裡亮起來的列）`;
            } else {
                hint.textContent = `綠框＝至少 ${minSup} 人，可以接；「—」是同一次裡只能往字碼比較大的商品接（避免同一個樣式被找兩次）。點數字看是哪幾位顧客。`;
            }
        }
        $('cnt').addEventListener('click', ev => {
            const td = ev.target.closest('td[data-x]');
            if (!td || !td.dataset.x) return;
            const x = td.dataset.x, k = td.dataset.k;
            picked = picked && picked.x === x && picked.k === k ? null : { x, k };
            const s = trace[cursor];
            drawCount(s);
            drawSeqs(s);
        });

        /* ---------- 結果 ---------- */
        function drawResult(s) {
            const box = $('levels');
            box.innerHTML = '';
            if (!s.result.length) box.innerHTML = '<div class="empty">還沒有，開始挖之後會出現在這裡。</div>';
            const bySize = {};
            s.result.forEach(r => {
                const n = r.pat.reduce((a, e) => a + e.length, 0);
                (bySize[n] = bySize[n] || []).push(r);
            });
            Object.keys(bySize).sort((a, b) => a - b).forEach(k => {
                const row = document.createElement('div');
                row.className = 'level';
                row.innerHTML = `<span class="tag">${k} 個</span><div class="items"></div>`;
                bySize[k].forEach(r => {
                    const p = document.createElement('span');
                    p.className = 'pat' + (r.fresh ? ' fresh' : '');
                    p.innerHTML = `<span></span><span class="n">${r.sup}</span>`;
                    p.firstChild.textContent = patText(r.pat);
                    p.title = r.pat.map(e => e.join('+')).join(' → ');
                    row.querySelector('.items').appendChild(p);
                });
                box.appendChild(row);
            });
            $('st-proj').textContent = s.stats.projs;
            $('st-cells').textContent = s.stats.cells;
            $('st-depth').textContent = s.stats.depth;
            $('compare').innerHTML = `同一份資料如果用暴力法，要把每位顧客所有可能的子序列都列出來（共 <b>${bruteCandidates(s.seqs)}</b> 種不同的候選），每一種都拿去跟 ${s.seqs.length} 位顧客比對。`;
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
            if (measuringBlocks) return;   // 量區塊高度時不用畫程式碼（程式碼框高度不會變），省時間
            const pre = $('code');
            pre.innerHTML = CODE[lang].map(([text, t], i) =>
                `<span class="ln${t.some(x => tags.includes(x)) ? ' hl' : ''}" data-n="${i + 1}">${highlight(text) || ' '}</span>`).join('');
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
                ? '下載 <a href="code/PrefixSpan.java" download>PrefixSpan.java</a>　執行 <code>javac PrefixSpan.java && java PrefixSpan</code>'
                : '下載 <a href="code/prefixspan.py" download>prefixspan.py</a>　執行 <code>python3 prefixspan.py</code>';
        }

        /* ---------- 顯示某一步 ---------- */
        function showStep() {
            const s = trace[cursor];
            picked = null;
            $('explain').innerHTML = `<span class="step-no">步驟 ${cursor + 1} / ${trace.length}</span>${describe(s)}`;
            drawPresets();
            drawCrumbs(s);
            if (editing) drawEditor(); else drawSeqs(s);
            drawCount(s);
            drawResult(s);
            renderCode(CODE_TAGS(s));
            $('btn-prev').disabled = $('btn-first').disabled = cursor === 0 || editing;
            $('btn-next').disabled = cursor === trace.length - 1 || editing;
            $('btn-play').disabled = editing;
            $('sup-val').textContent = minSup;
            $('sup-minus').disabled = minSup <= 1;
            $('sup-plus').disabled = minSup >= Math.max(1, db.length);
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

        function rebuild() {
            stopAuto();
            minSup = Math.max(1, Math.min(minSup, db.length || 1));
            trace = buildTrace(db, minSup);
            cursor = 0;
            showStep();
            reserveExplainHeight();
        }

        function step(dir) {
            if (editing) return false;
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
            timer = setInterval(() => { if (!step(1)) stopAuto(); }, 2200);
        });
        document.addEventListener('keydown', e => {
            if (e.key === 'ArrowRight') { stopAuto(); step(1); }
            if (e.key === 'ArrowLeft') { stopAuto(); step(-1); }
        });
        $('sup-minus').addEventListener('click', () => { if (minSup > 1) { minSup--; rebuild(); } });
        $('sup-plus').addEventListener('click', () => { if (minSup < db.length) { minSup++; rebuild(); } });
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
