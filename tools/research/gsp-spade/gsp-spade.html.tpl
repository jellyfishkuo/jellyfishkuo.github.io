<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/gsp-spade.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/gsp-spade-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/gsp-spade-180.png">
    <title>GSP 與 SPADE 序列樣式探勘</title>
    <meta name="description" content="序列樣式的另外兩種做法：GSP 像 Apriori 一層一層拼候選、掃資料庫；SPADE 像 Eclat 用 id-list 做 temporal join。一步一步看，Java 與 Python 程式碼逐行對照，並和 PrefixSpan 比較。">
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

        /* ── 分頁（跟空間資料那頁一樣） ── */
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
            white-space: nowrap;
        }
        .tabs button:hover { color: var(--text); }
        .tabs button.active { color: var(--text); background: var(--panel); border-color: var(--border); border-bottom: 1px solid var(--panel); }
        .tabs .no { font: 700 0.78rem 'Space Mono', monospace; color: var(--accent2); margin-right: 0.35rem; }
        @media (max-width: 380px) { .tabs button { padding: 0.5rem 0.6rem; font-size: 0.86rem; } }
        [hidden] { display: none !important; }

        /* 手機：一欄，依序 步驟 → 序列資料庫 → 候選／id-list → 程式碼 → 結果；電腦：兩欄 */
        .layout {
            display: grid;
            gap: 1rem;
            margin-top: 1rem;
            grid-template-areas: "step" "seq" "mid" "code" "result";
            align-items: start;
        }
        .layout > * { min-width: 0; }
        @media (min-width: 960px) {
            .layout {
                grid-template-columns: 1fr 1fr;
                grid-template-areas: "step code" "seq code" "mid result";
            }
        }
        .a-step { grid-area: step; }
        .a-seq { grid-area: seq; }
        .a-mid { grid-area: mid; }
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

        /* ── 序列資料庫（跟 PrefixSpan 那頁一樣） ── */
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
        .srow .mark.ok { color: #86efac; }
        .visits { display: flex; flex-wrap: wrap; gap: 0.25rem; align-items: center; min-width: 0; }
        .visit { display: inline-flex; align-items: center; border: 1px solid var(--border); border-radius: 8px; padding: 0.05rem 0.25rem; background: #16162a; font-size: 1.05rem; line-height: 1.45; }
        .visit.pb { border: 1.5px dashed var(--accent2); }
        .visit.pa { box-shadow: 0 0 0 2px var(--accent); }
        .visit.hit { border: 2px solid var(--warn); background: rgba(245, 158, 11, 0.16); }
        .it { padding: 0 0.1rem; border-radius: 5px; }
        .it.anchor { box-shadow: 0 0 0 2px var(--accent); }
        .it.anchor.new { box-shadow: 0 0 0 2px var(--warn); background: rgba(245, 158, 11, 0.18); }
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

        /* ── 候選（跟 Apriori 那頁一樣） ── */
        .level-line { font-size: 0.85rem; color: var(--muted); margin-bottom: 0.2rem; }
        .level-line .pt { font-size: 0.95rem; }
        .cands { display: flex; flex-wrap: wrap; gap: 0.4rem; margin-top: 0.6rem; min-height: 2.2rem; }
        .cand {
            display: inline-flex;
            align-items: center;
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
        }
        .cand:hover { border-color: var(--accent2); }
        .cand.sel { border-color: var(--warn); box-shadow: 0 0 0 1px var(--warn) inset; }
        .cand .n { font: 700 0.78rem 'Space Mono', monospace; padding: 0 0.35rem; border-radius: 5px; background: #2a2a48; }
        .cand .tg { font: 700 0.68rem 'Space Mono', monospace; color: var(--accent2); }
        .cand.ok { border-color: rgba(34, 197, 94, 0.55); }
        .cand.ok .n { background: rgba(34, 197, 94, 0.25); color: #86efac; }
        .cand.out { opacity: 0.6; }
        .cand.out .name { text-decoration: line-through; }
        .cand.out .n { background: rgba(248, 113, 113, 0.2); color: #fca5a5; }
        .cands-hint { color: var(--muted); font-size: 0.8rem; margin-top: 0.5rem; min-height: 2.6em; }
        .cands-hint b { color: var(--text); font-weight: 600; }

        /* ── id-list 表格（跟 PrefixSpan 的計數表同一套） ── */
        .tbl-wrap { overflow-x: auto; margin-top: 0.6rem; }
        table.cnt { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
        table.cnt th { font-weight: 500; color: var(--muted); font-size: 0.76rem; text-align: center; padding: 0.25rem; border-bottom: 1px solid var(--border); line-height: 1.3; }
        table.cnt th:first-child { text-align: left; }
        table.cnt th small { display: block; font-size: 0.68rem; color: #6a6a85; }
        table.cnt th .pt { font-size: 0.8rem; white-space: normal; }
        table.cnt td { padding: 0.2rem 0.25rem; border-bottom: 1px solid var(--border); text-align: center; }
        table.cnt td.nm { text-align: left; white-space: nowrap; }
        table.cnt td.ids { font: 0.8rem 'Space Mono', monospace; color: #c6c6d6; }
        table.cnt td.ids.none { color: #44445c; }
        table.cnt td.ids.res { color: #fcd34d; }
        table.cnt td.ids .first { color: var(--accent2); text-decoration: underline; text-underline-offset: 3px; }
        table.cnt tr.sum td { border-bottom: none; padding-top: 0.35rem; }
        table.cnt th.pickable, table.cnt td.pickable { cursor: pointer; }
        table.cnt .picked { background: rgba(245, 158, 11, 0.14); }
        td.c { font: 700 0.85rem 'Space Mono', monospace; }
        td.c span { display: inline-block; min-width: 2.4em; padding: 0.05rem 0.3rem; border-radius: 6px; border: 1px solid transparent; }
        td.c.zero span { color: #44445c; font-weight: 400; }
        td.c.no span { color: var(--muted); font-weight: 400; }
        td.c.ok span { color: #86efac; border-color: rgba(34, 197, 94, 0.45); }

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

        /* ── 三種做法比一比 ── */
        .cmp-card { margin-top: 1rem; }
        table.cmp td { text-align: left; vertical-align: top; padding: 0.4rem 0.35rem; }
        table.cmp th { text-align: left; }
        table.cmp td:first-child { font-weight: 600; white-space: nowrap; }
        table.cmp td .big { font: 700 1rem 'Space Mono', monospace; color: var(--text); }
        table.cmp td small { display: block; color: var(--muted); font-size: 0.74rem; line-height: 1.35; }
        table.cmp tr.me td { background: rgba(124, 58, 237, 0.08); }

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
        <h1>GSP 與 SPADE 序列樣式探勘<small>同樣找「先買什麼、之後再買什麼」，一個逐層拼候選，一個靠 id-list 合併</small></h1>
        <p class="intro">
            <a href="prefixspan.html">PrefixSpan</a> 用前綴投影找序列樣式。同一個問題還有兩種經典做法，剛好對應找頻繁項目集的另外兩條路：
            <b>GSP</b> 就像 <a href="apriori.html">Apriori</a>，一層一層拼出候選序列、每一層掃一次資料庫去數（GSP 之於 PrefixSpan，就像 Apriori 之於 FP-Growth）；
            <b>SPADE</b> 就像序列版的 <a href="eclat.html">Eclat</a>，把資料轉成垂直格式，每個樣式帶著一張 id-list，記下它出現在「哪位顧客的第幾次來店」，之後只靠 id-list 合併就能長出新樣式。
            資料和 PrefixSpan 那頁是同一份，找到的樣式也一模一樣；頁尾可以比較三種做法各做了多少事。
        </p>

        <div class="tabs" role="tablist">
            <button role="tab" id="tab-g" data-tab="g" class="active" aria-selected="true"><span class="no">01</span>GSP 逐層</button>
            <button role="tab" id="tab-s" data-tab="s" aria-selected="false"><span class="no">02</span>SPADE 垂直格式</button>
        </div>

        <!-- ===================== 分頁一：GSP ===================== -->
        <section id="panel-g" role="tabpanel" aria-labelledby="tab-g">
            <div class="layout">
                <div class="card a-step">
                    <div class="player">
                        <button class="btn" id="g-first" title="回到開頭">⏮</button>
                        <button class="btn" id="g-prev">◀ 上一步</button>
                        <button class="btn primary" id="g-next">下一步 ▶</button>
                        <button class="btn" id="g-play">▶ 自動播放</button>
                        <div class="minsup">
                            <span>最小支持度</span>
                            <button class="btn stepper" data-sup="-1" aria-label="減少">−</button>
                            <span class="val sup-val">3</span>
                            <button class="btn stepper" data-sup="1" aria-label="增加">+</button>
                            <span class="unit">人</span>
                        </div>
                    </div>
                    <div class="explain" id="g-explain"></div>
                </div>

                <div class="card a-seq seq-card" id="g-seq-card">
                    <div class="card-head"><h2 id="g-seq-title">序列資料庫</h2></div>
                    <div class="presets" id="g-presets"></div>
                    <div class="seqs" id="g-seqs"></div>
                    <div class="palette" id="g-palette" hidden></div>
                    <div class="db-foot">
                        <button class="btn small btn-edit" id="g-edit">✎ 編輯資料</button>
                        <button class="btn small" id="g-add-cust" hidden>＋ 新增顧客</button>
                    </div>
                    <div class="legend" id="g-legend">
                        <span><i class="sw" style="border:2px solid var(--warn);background:rgba(245,158,11,.16)"></i>點候選：它在這位顧客身上依序對到的那幾次</span>
                        <span><i class="sw" style="background:rgba(6,182,212,.25)"></i>亮起來的列：包含這個候選的顧客</span>
                    </div>
                </div>

                <div class="card a-mid">
                    <h2>候選序列</h2>
                    <div class="level-line" id="g-level-line"></div>
                    <div class="cands" id="g-cands"></div>
                    <div class="cands-hint" id="g-hint"></div>
                </div>

                <div class="card a-code">
                    <div class="card-head">
                        <h2>程式碼</h2>
                        <div class="lang">
                            <button data-lang="java" class="active">Java</button>
                            <button data-lang="py">Python</button>
                        </div>
                    </div>
                    <pre class="code" id="g-code"></pre>
                    <div class="downloads" id="g-downloads"></div>
                </div>

                <div class="card a-result">
                    <h2>目前找到的頻繁序列樣式</h2>
                    <div class="levels" id="g-levels"></div>
                    <div class="stats">
                        <div class="stat"><div class="v" id="g-st1">0</div><div class="k">掃描資料庫次數</div></div>
                        <div class="stat"><div class="v" id="g-st2">0</div><div class="k">拼出來的候選</div></div>
                        <div class="stat"><div class="v" id="g-st3">0</div><div class="k">剪枝刪掉、不用數的</div></div>
                    </div>
                </div>
            </div>
        </section>

        <!-- ===================== 分頁二：SPADE ===================== -->
        <section id="panel-s" role="tabpanel" aria-labelledby="tab-s" hidden>
            <div class="layout">
                <div class="card a-step">
                    <div class="player">
                        <button class="btn" id="s-first" title="回到開頭">⏮</button>
                        <button class="btn" id="s-prev">◀ 上一步</button>
                        <button class="btn primary" id="s-next">下一步 ▶</button>
                        <button class="btn" id="s-play">▶ 自動播放</button>
                        <div class="minsup">
                            <span>最小支持度</span>
                            <button class="btn stepper" data-sup="-1" aria-label="減少">−</button>
                            <span class="val sup-val">3</span>
                            <button class="btn stepper" data-sup="1" aria-label="增加">+</button>
                            <span class="unit">人</span>
                        </div>
                    </div>
                    <div class="explain" id="s-explain"></div>
                </div>

                <div class="card a-seq seq-card" id="s-seq-card">
                    <div class="card-head"><h2 id="s-seq-title">序列資料庫</h2></div>
                    <div class="presets" id="s-presets"></div>
                    <div class="seqs" id="s-seqs"></div>
                    <div class="palette" id="s-palette" hidden></div>
                    <div class="db-foot">
                        <button class="btn small btn-edit" id="s-edit">✎ 編輯資料</button>
                        <button class="btn small" id="s-add-cust" hidden>＋ 新增顧客</button>
                    </div>
                    <div class="legend" id="s-legend">
                        <span><i class="sw" style="box-shadow:0 0 0 2px var(--accent) inset"></i>A 的 id-list：A 在這一次結束</span>
                        <span><i class="sw" style="border:1.5px dashed var(--accent2)"></i>B 的 id-list</span>
                        <span><i class="sw" style="border:2px solid var(--warn);background:rgba(245,158,11,.16)"></i>合併後留下的位置</span>
                    </div>
                </div>

                <div class="card a-mid">
                    <h2>id-list 怎麼合併？</h2>
                    <div class="crumbs" id="s-crumbs"></div>
                    <div class="cands" id="s-cands"></div>
                    <div class="tbl-wrap"><table class="cnt" id="s-table"></table></div>
                    <div class="cands-hint" id="s-hint"></div>
                </div>

                <div class="card a-code">
                    <div class="card-head">
                        <h2>程式碼</h2>
                        <div class="lang">
                            <button data-lang="java" class="active">Java</button>
                            <button data-lang="py">Python</button>
                        </div>
                    </div>
                    <pre class="code" id="s-code"></pre>
                    <div class="downloads" id="s-downloads"></div>
                </div>

                <div class="card a-result">
                    <h2>目前找到的頻繁序列樣式</h2>
                    <div class="levels" id="s-levels"></div>
                    <div class="stats">
                        <div class="stat"><div class="v" id="s-st1">0</div><div class="k">掃描資料庫次數</div></div>
                        <div class="stat"><div class="v" id="s-st2">0</div><div class="k">id-list 合併次數</div></div>
                        <div class="stat"><div class="v" id="s-st3">0</div><div class="k">最深的等價類</div></div>
                    </div>
                </div>
            </div>
        </section>

        <div class="card cmp-card">
            <h2>三種做法比一比（目前的資料與門檻）</h2>
            <div class="tbl-wrap"><table class="cnt cmp" id="cmp"></table></div>
            <p class="compare" id="cmp-note"></p>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼這樣不會漏、也不會多？</h2>
                <p><b>GSP：</b>只要一位顧客包含 &lt;(☕🍞)(🍙)&gt;，就一定也包含 &lt;(🍞)(🍙)&gt;、&lt;(☕)(🍙)&gt;、&lt;(☕🍞)&gt;，所以長序列的支持度不可能超過它的子序列（序列版的向下封閉性），子序列不頻繁就能直接剪掉。
                    合併時「a 去掉第一個商品＝b 去掉最後一個商品」，保證每個 k 個商品的頻繁序列都拼得出來（它去頭、去尾的兩個子序列都在上一層），而且每個候選只會被拼一次。
                    剪枝只檢查<b>連續</b>子序列，是原論文為了支援「兩次購買最多隔幾天」這類時間限制的寫法；沒有時間限制時，任何子序列其實都可以拿來剪。</p>
                <p style="margin-top:0.5rem"><b>SPADE：</b>id-list 記下樣式在每位顧客身上<b>所有可能的結束位置</b>。S-step 要「A 之後再出現 B 的最後一個商品」，只要這位顧客最早的那個 A 比它早就成立，所以只看 A 最早的位置（表格裡加底線的那個）。
                    I-step 要同一次一起買，A 和 B 必須在同一位顧客、同一次結束。同一個等價類的成員前綴都一樣，所以兩兩合併就能長出下一層，不用回頭掃資料庫。</p>
            </div>
            <div class="card">
                <h2>優缺點、跟 PrefixSpan 和實驗室研究的關係</h2>
                <ul>
                    <li><b>GSP：</b>最好懂，但跟 Apriori 一樣要產生大量候選（2 個商品就有 n×n＋n(n−1)/2 個），而且每一層都要把整個資料庫重掃一遍，序列越長掃越多次。</li>
                    <li><b>SPADE：</b>只掃一次資料庫，之後都在記憶體裡做 id-list 合併，通常比 GSP 快很多；代價是 id-list 要佔記憶體，資料很大時要分批處理。原論文另外用水平格式先算 2 個商品的序列，共掃 3 次；這頁簡化成直接從垂直格式開始。</li>
                    <li><b>PrefixSpan：</b>不產生候選，只在投影資料庫裡數真的出現過的東西；一般在長序列、低門檻時最快。三種做法找到的結果完全相同，差在「做了多少事」。</li>
                    <li><b>跟研究的關係：</b>id-list 很好更新，新資料進來只要把新的 (sid, eid) 加到對應商品後面，所以增量序列探勘（如 ISM）多半從 SPADE 改起；把次數換成效益就是高效益序列樣式探勘，同樣要處理「效益沒有向下封閉性」的問題。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           GSP 與 SPADE 一步一步看
           網頁裡用 JavaScript 照著同樣的流程跑一次，把每一步記下來；
           程式碼框裡的 Java / Python 是可以直接下載執行的版本。
           ========================================================= */
        const CODE = { g: /*CODE_GSP*/null, s: /*CODE_SPADE*/null };

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
        const GROUPS = ['g', 's'];

        const $ = id => document.getElementById(id);
        const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);   // 跟 Java compareTo、Python 字串比較一樣：照字碼
        const normSeq = seq => seq.filter(e => e.length).map(e => [...new Set(e)].sort(cmp));
        let db = PRESETS[0].db.map(normSeq);
        let preset = 0;
        let minSup = PRESETS[0].sup;
        let lang = 'java';
        let activeTab = 'g';
        const traces = { g: [], s: [] };
        const cursors = { g: 0, s: 0 };
        const timers = { g: null, s: null };
        const picks = { g: null, s: null };   // 點選的候選（GSP：候選的位置；SPADE：合併的位置／垂直格式的商品）
        let editing = false;
        let selVisit = null;      // 編輯時選到的那一次來店 [sid, k]

        const emo = x => EMOJI[x] || x;
        const patText = pat => '<' + pat.map(e => '(' + e.map(emo).join('') + ')').join('') + '>';
        const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        const pt = pat => `<span class="pt">${esc(patText(pat))}</span>`;
        const names = sids => sids.map(i => NAMES[i]).join('、');
        const patKey = pat => JSON.stringify(pat);
        const sizeOf = pat => pat.reduce((a, e) => a + e.length, 0);
        const lastItem = pat => { const e = pat[pat.length - 1]; return e[e.length - 1]; };

        /* 由前往後比對：pat 的每一次都要依序被 seq 的某一次整個包含；回傳對到的是哪幾次（對不上回傳 null） */
        function matchPos(seq, pat) {
            const pos = [];
            for (let k = 0; k < seq.length && pos.length < pat.length; k++)
                if (pat[pos.length].every(x => seq[k].includes(x))) pos.push(k);
            return pos.length === pat.length ? pos : null;
        }

        /* =========================================================
           GSP：照著程式跑一次，記下每一步
           ========================================================= */
        function dropFirst(p) { return [...(p[0].length > 1 ? [p[0].slice(1)] : []), ...p.slice(1)]; }
        function dropLast(p) { const e = p[p.length - 1]; return [...p.slice(0, -1), ...(e.length > 1 ? [e.slice(0, -1)] : [])]; }
        function gspJoin(level, k) {
            const out = [];
            if (k === 2) {
                const items = level.map(r => r.pat[0][0]);
                for (const x of items)
                    for (const y of items) {
                        out.push({ pat: [[x], [y]], a: [[x]], b: [[y]] });
                        if (cmp(x, y) < 0) out.push({ pat: [[x, y]], a: [[x]], b: [[y]] });
                    }
                return out;
            }
            const byHead = {};   // 先把 b 照「去掉最後一個商品」分組，配對時不用兩兩比較（順序跟兩層迴圈一樣）
            level.forEach(rb => { const key = patKey(dropLast(rb.pat)); (byHead[key] = byHead[key] || []).push(rb); });
            for (const ra of level)
                for (const rb of byHead[patKey(dropFirst(ra.pat))] || []) {
                    const a = ra.pat, b = rb.pat;
                    const bl = b[b.length - 1], y = bl[bl.length - 1];
                    const c = bl.length === 1 ? [...a, [y]] : [...a.slice(0, -1), [...a[a.length - 1], y]];
                    out.push({ pat: c, a, b, mid: dropFirst(a) });
                }
            return out;
        }
        function contiguousSubs(c) {
            const out = [];
            c.forEach((e, i) => {
                if (e.length === 1 && i > 0 && i < c.length - 1) return;
                e.forEach(x => {
                    const rest = e.filter(y => y !== x);
                    out.push([...c.slice(0, i), ...(rest.length ? [rest] : []), ...c.slice(i + 1)]);
                });
            });
            return out;
        }

        function gspTrace(dbIn, minSup) {
            const seqs = dbIn.map(normSeq);
            const steps = [], found = [];
            const stats = { scans: 0, gen: 0, pruned: 0, counted: 0 };
            const push = (kind, o = {}) => steps.push({ kind, seqs, found: found.map(r => ({ ...r })), stats: { ...stats }, ...o });
            push('start');
            const cnt = {}, who = {};
            seqs.forEach((seq, sid) => new Set(seq.flat()).forEach(x => { cnt[x] = (cnt[x] || 0) + 1; (who[x] = who[x] || []).push(sid); }));
            stats.scans = 1;
            const c1 = Object.keys(cnt).sort(cmp).map(x => ({ pat: [[x]], sup: cnt[x], who: who[x], status: cnt[x] >= minSup ? 'ok' : 'no' }));
            stats.counted += c1.length;
            let level = c1.filter(c => c.status === 'ok').map(c => ({ pat: c.pat, sup: c.sup }));
            push('L1', { k: 1, cands: c1, L: level });
            let k = 1;
            while (level.length) {
                level.forEach(r => found.push({ ...r, fresh: true }));
                k++;
                const C = gspJoin(level, k);
                stats.gen += C.length;
                push('join', { k, cands: C.map(c => ({ ...c, status: 'wait' })), L: level });
                found.forEach(r => { r.fresh = false; });
                const keys = new Set(level.map(r => patKey(r.pat)));
                const pv = C.map(c => {
                    const miss = contiguousSubs(c.pat).find(s => !keys.has(patKey(s)));
                    return { ...c, status: miss ? 'pruned' : 'wait', missing: miss || null };
                });
                stats.pruned += pv.filter(c => c.status === 'pruned').length;
                push('prune', { k, cands: pv, L: level });
                const alive = pv.filter(c => c.status !== 'pruned').length;
                if (alive) stats.scans++;
                stats.counted += alive;
                const counted = pv.map(c => {
                    if (c.status === 'pruned') return c;
                    const w = [];
                    seqs.forEach((s, sid) => { if (matchPos(s, c.pat)) w.push(sid); });
                    return { ...c, status: 'counted', sup: w.length, who: w };
                });
                push('count', { k, cands: counted, L: level, alive });
                const filtered = counted.map(c => (c.status === 'counted' ? { ...c, status: c.sup >= minSup ? 'ok' : 'no' } : c));
                level = filtered.filter(c => c.status === 'ok').map(c => ({ pat: c.pat, sup: c.sup }));
                push('filter', { k, cands: filtered, L: level });
            }
            push('stop', { k });
            push('end', { k });
            return steps;
        }

        /* =========================================================
           SPADE：照著程式跑一次，記下每一步
           ========================================================= */
        const support = list => new Set(list.map(p => p[0])).size;
        function temporalJoin(a, b) {
            const first = {};
            a.forEach(([sid, eid]) => { if (!(sid in first)) first[sid] = eid; });
            return b.filter(([sid, eid]) => sid in first && first[sid] < eid);
        }
        function equalJoin(a, b) {
            const same = new Set(a.map(p => p.join(',')));
            return b.filter(p => same.has(p.join(',')));
        }

        function spadeTrace(dbIn, minSup) {
            const seqs = dbIn.map(normSeq);
            const steps = [], found = [];
            const stats = { scans: 0, joins: 0, depth: 0 };
            const push = (kind, o = {}) => steps.push({ kind, seqs, found: found.map(r => ({ ...r })), stats: { ...stats }, ...o });
            push('start', { crumbs: [] });
            const vert = {};
            seqs.forEach((seq, sid) => seq.forEach((e, eid) => e.forEach(x => (vert[x] = vert[x] || []).push([sid, eid]))));
            stats.scans = 1;
            const atoms = Object.keys(vert).sort(cmp).filter(x => support(vert[x]) >= minSup).map(x => ({ pat: [[x]], list: vert[x], s: true }));
            atoms.forEach(a => found.push({ pat: a.pat, sup: support(a.list), fresh: true }));
            push('vertical', { vert, atoms: atoms.map(a => a.pat), crumbs: [] });
            found.forEach(r => { r.fresh = false; });
            const path = [];
            let prevDepth = 0;
            (function enumerate(atoms, depth) {
                for (const a of atoms) {
                    const children = [], cands = [];
                    const aLast = a.pat[a.pat.length - 1], ax = aLast[aLast.length - 1];
                    for (const b of atoms) {
                        const y = lastItem(b.pat);
                        if (b.s === a.s && cmp(y, ax) > 0) {
                            const pat = [...a.pat.slice(0, -1), [...aLast, y]];
                            const list = equalJoin(a.list, b.list);
                            cands.push({ step: 'I', b: b.pat, listB: b.list, pat, list, sup: support(list), s: false });
                        }
                        if (b.s) {
                            const pat = [...a.pat, [y]];
                            const list = temporalJoin(a.list, b.list);
                            cands.push({ step: 'S', b: b.pat, listB: b.list, pat, list, sup: support(list), s: true });
                        }
                    }
                    stats.joins += cands.length;
                    stats.depth = Math.max(stats.depth, depth);
                    cands.forEach(c => {
                        c.ok = c.sup >= minSup;
                        if (c.ok) { found.push({ pat: c.pat, sup: c.sup, fresh: true }); children.push({ pat: c.pat, list: c.list, s: c.s }); }
                    });
                    path.push(a.pat);
                    push('class', { a: a.pat, listA: a.list, aS: a.s, siblings: atoms.length, cands, depth, back: depth < prevDepth, crumbs: path.slice() });
                    prevDepth = depth;
                    found.forEach(r => { r.fresh = false; });
                    enumerate(children, depth + 1);
                    path.pop();
                }
            })(atoms, 1);
            push('end', { crumbs: [] });
            return steps;
        }

        /* PrefixSpan（只算它做了多少事，給頁尾比較用；跟 prefixspan.html 同一套流程） */
        function prefixSpanStats(dbIn, minSup) {
            const seqs = dbIn.map(normSeq);
            const st = { projs: 0, cells: 0, found: [] };
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
            (function mine(prefix, proj) {
                st.projs++;
                const last = prefix.length ? prefix[prefix.length - 1] : null;
                const cnt = { i: {}, s: {} };
                for (const pr of proj) {
                    const seq = seqs[pr.sid], iSeen = new Set(), sSeen = new Set();
                    if (last) {
                        seq[pr.e].slice(pr.p + 1).forEach(x => iSeen.add(x));
                        for (let k = pr.e + 1; k < seq.length; k++)
                            if (last.every(y => seq[k].includes(y))) seq[k].forEach(x => { if (x > last[last.length - 1]) iSeen.add(x); });
                    }
                    for (let k = pr.e + 1; k < seq.length; k++) seq[k].forEach(x => sSeen.add(x));
                    iSeen.forEach(x => { cnt.i[x] = (cnt.i[x] || 0) + 1; });
                    sSeen.forEach(x => { cnt.s[x] = (cnt.s[x] || 0) + 1; });
                }
                st.cells += Object.keys(cnt.i).length + Object.keys(cnt.s).length;
                for (const k of ['i', 's'])
                    for (const x of Object.keys(cnt[k]).sort(cmp)) {
                        if (cnt[k][x] < minSup) continue;
                        const pattern = k === 'i' ? [...prefix.slice(0, -1), [...last, x]] : [...prefix, [x]];
                        st.found.push({ pat: pattern, sup: cnt[k][x] });
                        mine(pattern, project(proj, last, x, k === 'i'));
                    }
            })([], seqs.map((_, i) => ({ sid: i, e: -1, p: -1 })));
            return st;
        }

        /* =========================================================
           說明文字
           ========================================================= */
        function gspDescribe(s) {
            const n = s.cands ? s.cands.length : 0;
            const Lk = k => `L<sub>${k}</sub>`;
            switch (s.kind) {
                case 'start':
                    return `每一列是一位常客，照時間排好他每次來店買了什麼（一個框是一次，可以買好幾樣）。支持度＝有幾位顧客的紀錄裡找得到這個序列（同一個人出現好幾次也只算 1 人）。` +
                        `GSP 跟 Apriori 一樣一層一層往上找：第 k 層是「整個序列總共 k 個商品」的樣式，例如 &lt;(☕🍞)(🍙)&gt; 算 3 個。目標：至少 <b>${minSup}</b> 位顧客都有的序列樣式。`;
                case 'L1': {
                    const out = s.cands.filter(c => c.status === 'no');
                    return `第 1 次掃描資料庫：數每個商品有幾位顧客買過（一個人買好幾次也只算 1）。` +
                        (out.length ? `${out.map(c => emo(c.pat[0][0])).join('')} 不到 ${minSup} 人被淘汰，` : '每個商品都達到門檻，') +
                        (s.L.length ? `剩下的 ${s.L.length} 個就是 ${Lk(1)}。` : `${Lk(1)} 是空的，什麼都找不到。`);
                }
                case 'join':
                    if (s.k === 2) {
                        const m = s.L.length;
                        return `① 合併：2 個商品的候選有兩種拼法：&lt;(x)(y)&gt;「買 x 之後再買 y」（x、y 可以一樣，代表回購），和 &lt;(x y)&gt;「同一次一起買」（同一次裡照字碼排，只拼 x 排在 y 前面的那種）。` +
                            `${Lk(1)} 有 ${m} 個商品，所以共 ${m}×${m} ＋ ${m * (m - 1) / 2} ＝ <b>${n}</b> 個候選。`;
                    }
                    return `① 合併：拿 ${Lk(s.k - 1)} 裡兩個樣式 a、b，如果「a 去掉第一個商品」跟「b 去掉最後一個商品」一模一樣，就把 b 的最後一個商品接到 a 後面：` +
                        `它在 b 裡是<b>自己一次</b>，就接成新的一次 (…)(y)；它在 b 裡跟別的<b>同一次</b>買，就放進 a 的最後一次 (…y)。` +
                        (n ? `共拼出 <b>${n}</b> 個候選，點候選看是哪兩個拼的。` : `沒有任何兩個能拼，候選是空的。`);
                case 'prune': {
                    const out = s.cands.filter(c => c.status === 'pruned').length;
                    if (!n) return `② 剪枝：沒有候選可以檢查。`;
                    return `② 剪枝：候選的每個<b>連續子序列</b>（從第一次或最後一次拿掉一個商品，或從買了 2 樣以上的那一次拿掉一個）都要在 ${Lk(s.k - 1)} 裡。` +
                        (out ? `有 <b>${out}</b> 個候選做不到，不用掃資料庫就知道它不可能頻繁，直接刪掉。點被刪的候選看是哪個子序列不頻繁。` : `這一層每個候選都通過，沒有可以剪掉的。`);
                }
                case 'count':
                    return s.alive
                        ? `③ 計數：第 ${s.stats.scans} 次掃描資料庫，把剩下的 ${s.alive} 個候選一個一個拿去比對每位顧客（由前往後找，每一次都要整個包含）。點候選看是哪幾位顧客、對到哪幾次。`
                        : `③ 計數：所有候選都被剪掉了，不用再掃資料庫。`;
                case 'filter': {
                    const ok = s.L.length, no = s.cands.filter(c => c.status === 'no').length;
                    return ok
                        ? `④ 篩選：留下至少 ${minSup} 人的 <b>${ok}</b> 個，成為 ${Lk(s.k)}。` + (no ? `另外 ${no} 個通過了剪枝，但實際數完還是不夠。` : '')
                        : `④ 篩選：沒有任何候選達到 ${minSup} 人，${Lk(s.k)} 是空的。`;
                }
                case 'stop':
                    return `${Lk(s.k)} 是空的，拼不出更長的候選，迴圈停止。`;
                case 'end':
                    return `完成！共找到 <b>${s.found.length}</b> 個頻繁序列樣式，掃描資料庫 ${s.stats.scans} 次；拼出 ${s.stats.gen} 個候選，` +
                        `其中 ${s.stats.pruned} 個在剪枝時就刪掉。結果跟 PrefixSpan 一模一樣，但 PrefixSpan 不用產生候選，可以拉到頁尾比較。`;
            }
            return '';
        }

        function spadeDescribe(s) {
            switch (s.kind) {
                case 'start':
                    return `SPADE 換個方向存資料：不再一位顧客一列，而是<b>每個商品一張 id-list</b>，記下它出現在「第幾位顧客（sid）的第幾次來店（eid）」。` +
                        `跟 Eclat 記交易編號是同一個想法，只是多記了時間。之後全部靠 id-list 合併，不用再回頭掃資料庫。目標：至少 <b>${minSup}</b> 位顧客都有的序列樣式。`;
                case 'vertical':
                    return `只掃這一次資料庫，轉成垂直格式：表格每一欄是一個商品的 id-list，格子裡是那位顧客的第幾次來店。<b>支持度＝有幾位不同的顧客</b>，不是格子裡有幾個數字。` +
                        (s.atoms.length ? `夠 ${minSup} 人的 ${s.atoms.map(p => pt(p)).join(' ')} 是第一個等價類（前綴都是空的），接著輪流拿它們當 A 往下長。點欄位標題看它在哪裡。` : `沒有任何商品達到 ${minSup} 人，什麼都找不到。`);
                case 'class': {
                    let txt = s.back ? '回到上一層。' : '';
                    txt += `輪到 A＝${pt(s.a)}（${support(s.listA)} 人）。`;
                    if (!s.cands.length) return txt + `同一類裡沒有能跟它合併的兄弟：I-step 只能往字碼比較大的商品接，S-step 只能接「之後再買」長出來的兄弟，這一支到此結束。`;
                    txt += `跟同一類的兄弟 B 一一合併 id-list：<b>S-step</b>（後來再買）留下 B 的位置，只要同一位顧客更早出現過 A；` +
                        `<b>I-step</b>（同一次一起買）要同一位顧客、同一次來店都有 A 和 B。共 ${s.cands.length} 次合併，`;
                    const ok = s.cands.filter(c => c.ok);
                    return txt + (ok.length ? `夠 ${minSup} 人的：${ok.map(c => pt(c.pat)).join(' ')}，記下來，它們自成一個等價類，往下挖。` : `沒有一個夠 ${minSup} 人，A 這一支結束。`);
                }
                case 'end':
                    return `完成！共找到 <b>${s.found.length}</b> 個頻繁序列樣式。整個過程只掃了 1 次資料庫，之後做了 ${s.stats.joins} 次 id-list 合併，每次只看兩張小清單。結果跟 GSP、PrefixSpan 完全一樣。`;
            }
            return '';
        }

        const CODE_TAGS = {
            g: s => ({ start: ['start'], L1: ['L1'], join: ['join'], prune: ['prune'], count: ['count'], filter: ['filter'], stop: ['loop'], end: ['end'] })[s.kind] || [],
            s: s => {
                if (s.kind === 'class') {
                    const c = s.cands[spadePickIndex(s)];
                    return c ? ['pair', c.step === 'I' ? 'istep' : 'sstep', ...(c.ok ? ['keep'] : [])] : ['pair'];
                }
                return ({ start: ['start'], vertical: ['vertical'], end: ['end'] })[s.kind] || [];
            }
        };

        /* =========================================================
           序列資料庫
           ========================================================= */
        /* marks(sid, k) 回傳這一次來店要加的 class 與要圈起來的商品 */
        function drawSeqs(g, s, opt) {
            const box = $(g + '-seqs');
            box.innerHTML = '';
            $(g + '-seq-title').textContent = '序列資料庫';
            s.seqs.forEach((seq, sid) => {
                const row = document.createElement('div');
                row.className = 'srow' + (opt.gone && opt.gone(sid) ? ' gone' : '') + (opt.pick && opt.pick(sid) ? ' pick' : '');
                const who = document.createElement('span');
                who.className = 'who';
                who.textContent = NAMES[sid];
                row.appendChild(who);
                const vis = document.createElement('div');
                vis.className = 'visits';
                seq.forEach((e, k) => {
                    if (k) { const a = document.createElement('span'); a.className = 'arrow'; a.textContent = '›'; vis.appendChild(a); }
                    const v = document.createElement('span');
                    const m = opt.marks ? opt.marks(sid, k) : null;
                    v.className = 'visit' + (m && m.cls ? ' ' + m.cls : '');
                    e.forEach(x => {
                        const it = document.createElement('span');
                        it.className = 'it' + (m && m.ring && m.ring[x] ? ' ' + m.ring[x] : '');
                        it.title = x;
                        it.textContent = emo(x);
                        v.appendChild(it);
                    });
                    vis.appendChild(v);
                });
                if (!seq.length) { const n = document.createElement('span'); n.className = 'mark'; n.textContent = '（沒有來店紀錄）'; vis.appendChild(n); }
                row.appendChild(vis);
                const mark = document.createElement('span');
                mark.className = 'mark';
                const t = opt.mark ? opt.mark(sid) : '';
                if (t) { mark.textContent = t; if (t[0] === '✓') mark.classList.add('ok'); }
                row.appendChild(mark);
                box.appendChild(row);
            });
        }

        /* 編輯模式：點一次來店選起來，再用下面的按鈕增減商品 */
        function drawEditor(g) {
            const box = $(g + '-seqs');
            box.innerHTML = '';
            $(g + '-seq-title').textContent = '編輯序列資料庫';
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
            const pal = $(g + '-palette');
            pal.innerHTML = '';
            if (!selVisit || !db[selVisit[0]] || !db[selVisit[0]][selVisit[1]]) {
                pal.textContent = '點一個框（一次來店）來改裡面的商品；按 ＋ 幫那位顧客多加一次來店。';
                return;
            }
            const e = db[selVisit[0]][selVisit[1]];
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

        function setEditing(on) {
            editing = on;
            selVisit = null;
            if (!on) db = db.map(normSeq);
            GROUPS.forEach(g => {
                $(g + '-seq-card').classList.toggle('editing', on);
                $(g + '-palette').hidden = !on;
                $(g + '-add-cust').hidden = !on;
                $(g + '-edit').textContent = on ? '✓ 編輯完成' : '✎ 編輯資料';
                $(g + '-legend').hidden = on;
            });
            rebuild();
        }
        function dataChanged() {
            preset = -1;
            rebuild();
        }

        GROUPS.forEach(g => {
            $(g + '-seqs').addEventListener('click', ev => {
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
                    drawEditor(g);
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
            $(g + '-palette').addEventListener('click', ev => {
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
            $(g + '-edit').addEventListener('click', () => setEditing(!editing));
            $(g + '-add-cust').addEventListener('click', () => {
                if (db.length >= MAX_CUST) return;
                db.push([[ITEMS[0]]]);
                selVisit = [db.length - 1, 0];
                dataChanged();
            });
        });

        function drawPresets(g) {
            const box = $(g + '-presets');
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
                minSup = Math.max(2, Math.min(minSup, db.length));
                if (editing) setEditing(false); else rebuild();
            });
            box.appendChild(r);
        }

        /* =========================================================
           GSP 的畫面
           ========================================================= */
        function gspShow() {
            const s = traces.g[cursors.g];
            const pick = picks.g !== null && s.cands ? s.cands[picks.g] : null;
            if (editing) drawEditor('g');
            else {
                const hasWho = pick && pick.who;
                const pos = hasWho ? s.seqs.map(seq => matchPos(seq, pick.pat)) : [];
                drawSeqs('g', s, {
                    pick: sid => hasWho && pick.who.includes(sid),
                    mark: sid => (hasWho ? (pick.who.includes(sid) ? '✓ 有' : '—') : ''),
                    marks: (sid, k) => (hasWho && pos[sid] && pos[sid].includes(k) ? { cls: 'hit', ring: Object.fromEntries(pick.pat[pos[sid].indexOf(k)].map(x => [x, 'anchor new'])) } : null)
                });
            }
            // 候選
            const line = $('g-level-line'), box = $('g-cands'), hint = $('g-hint');
            box.innerHTML = '';
            const Ck = k => `C<sub>${k}</sub>`;
            if (!s.cands) {
                line.innerHTML = s.kind === 'end' || s.kind === 'stop' ? `全部找完了，第 ${s.k} 層沒有任何頻繁樣式。` : '還沒開始。按「下一步」。';
                hint.textContent = '';
            } else {
                const label = s.kind === 'L1' ? `${Ck(1)}：每個商品自己（${s.cands.length} 個）`
                    : `${Ck(s.k)}：總共 ${s.k} 個商品的候選（${s.cands.length} 個）`;
                line.innerHTML = label;
                if (!s.cands.length) box.innerHTML = '<span class="cands-hint">（沒有候選）</span>';
                s.cands.forEach((c, i) => {
                    const b = document.createElement('button');
                    const showN = c.sup !== undefined && (s.kind !== 'join' && s.kind !== 'prune');
                    b.className = 'cand' + (c.status === 'ok' ? ' ok' : '') + (c.status === 'pruned' || c.status === 'no' ? ' out' : '') + (i === picks.g ? ' sel' : '');
                    b.dataset.i = i;
                    const nm = document.createElement('span');
                    nm.className = 'name';
                    nm.textContent = patText(c.pat);
                    b.appendChild(nm);
                    if (showN || c.status === 'pruned') {
                        const n = document.createElement('span');
                        n.className = 'n';
                        n.textContent = c.status === 'pruned' ? '剪' : c.sup;
                        b.appendChild(n);
                    }
                    box.appendChild(b);
                });
                if (pick) hint.innerHTML = gspPickText(s, pick);
                else hint.textContent = s.cands.length ? (s.kind === 'join' ? '點候選看它是哪兩個樣式拼出來的。'
                    : s.kind === 'prune' ? '劃掉的是被剪掉的候選；點它看是哪個連續子序列不頻繁。'
                        : '點候選看是哪幾位顧客有它（序列資料庫裡會亮起來）。') : '';
            }
            // 結果
            drawFound('g', s.found);
            $('g-st1').textContent = s.stats.scans;
            $('g-st2').textContent = s.stats.gen;
            $('g-st3').textContent = s.stats.pruned;
        }
        function gspPickText(s, c) {
            let t = `${pt(c.pat)}：`;
            if (s.kind === 'L1') return t + `${c.sup} 位顧客買過（${esc(names(c.who))}）。`;
            if (c.status === 'pruned') return t + `連續子序列 ${pt(c.missing)} 不在 L<sub>${s.k - 1}</sub> 裡，不可能頻繁，剪掉。`;
            if (c.who) t += `${c.sup} 位顧客有它${c.sup ? '（' + esc(names(c.who)) + '）' : ''}。`;
            if (s.kind === 'join' || s.kind === 'prune' || !c.who) {
                t += s.k === 2
                    ? `由 L<sub>1</sub> 的 ${pt(c.a)} 和 ${pt(c.b)} 拼出來${c.pat.length === 1 ? '（同一次一起買）' : '（之後再買）'}。`
                    : `由 ${pt(c.a)} ＋ ${pt(c.b)} 拼出來：前者去掉第一個、後者去掉最後一個，都是 ${pt(c.mid)}。`;
                if (s.kind === 'prune') t += '連續子序列都在上一層，留下來等著數。';
            }
            return t;
        }
        $('g-cands').addEventListener('click', ev => {
            const b = ev.target.closest('.cand');
            if (!b) return;
            const i = Number(b.dataset.i);
            picks.g = picks.g === i ? null : i;
            gspShow();
        });

        /* =========================================================
           SPADE 的畫面
           ========================================================= */
        function spadePickIndex(s) {
            if (s.kind !== 'class' || !s.cands.length) return -1;
            if (picks.s !== null && picks.s < s.cands.length) return picks.s;
            const ok = s.cands.findIndex(c => c.ok);
            return ok >= 0 ? ok : 0;
        }
        const eidText = list => list.map(p => p[1] + 1);
        function spadeShow() {
            const s = traces.s[cursors.s];
            const ci = spadePickIndex(s);
            const c = ci >= 0 ? s.cands[ci] : null;
            const has = (list, sid, k) => list.some(p => p[0] === sid && p[1] === k);
            if (editing) drawEditor('s');
            else if (s.kind === 'class' && c) {
                const ax = lastItem(s.a), y = lastItem(c.pat);
                drawSeqs('s', s, {
                    gone: sid => !s.listA.some(p => p[0] === sid),
                    marks: (sid, k) => {
                        const inA = has(s.listA, sid, k), inB = has(c.listB, sid, k), inR = has(c.list, sid, k);
                        if (!inA && !inB && !inR) return null;
                        const ring = {};
                        if (inA) ring[ax] = 'anchor';
                        if (inR) ring[y] = 'anchor new';
                        return { cls: [inA ? 'pa' : '', inB && !inR ? 'pb' : '', inR ? 'hit' : ''].join(' ').trim(), ring };
                    },
                    mark: sid => (c.list.some(p => p[0] === sid) ? '✓ 有' : '')
                });
            } else if (s.kind === 'class') {
                drawSeqs('s', s, {
                    gone: sid => !s.listA.some(p => p[0] === sid),
                    marks: (sid, k) => (has(s.listA, sid, k) ? { cls: 'pa', ring: { [lastItem(s.a)]: 'anchor' } } : null)
                });
            } else if (s.kind === 'vertical' && picks.s !== null && s.vert[picks.s]) {
                const x = picks.s, list = s.vert[x];
                drawSeqs('s', s, {
                    pick: sid => list.some(p => p[0] === sid),
                    marks: (sid, k) => (has(list, sid, k) ? { cls: 'hit', ring: { [x]: 'anchor new' } } : null)
                });
            } else drawSeqs('s', s, {});

            // 等價類路徑
            const crumbs = $('s-crumbs');
            const path = s.crumbs || [];
            crumbs.innerHTML = '等價類：' + ['空的', ...path.map(p => esc(patText(p)))].map((t, i, a) =>
                `<span class="crumb${i === a.length - 1 ? ' cur' : ''}">${i ? 'A＝' : ''}${t}</span>`).join('<span class="arrow">›</span>');

            const box = $('s-cands'), table = $('s-table'), hint = $('s-hint');
            box.innerHTML = '';
            table.innerHTML = '';
            const N = s.seqs.length;
            if (s.kind === 'vertical') {
                const items = ITEMS.slice().sort(cmp);
                const sel = picks.s;
                let h = `<thead><tr><th>顧客</th>${items.map(x => `<th class="pickable${x === sel ? ' picked' : ''}" data-x="${x}" title="${x}">${emo(x)}</th>`).join('')}</tr></thead><tbody>`;
                for (let sid = 0; sid < N; sid++) {
                    h += `<tr><td class="nm">${NAMES[sid]}</td>` + items.map(x => {
                        const e = (s.vert[x] || []).filter(p => p[0] === sid).map(p => p[1] + 1);
                        return `<td class="ids pickable${e.length ? '' : ' none'}${x === sel ? ' picked' : ''}" data-x="${x}">${e.length ? e.join(',') : '·'}</td>`;
                    }).join('') + '</tr>';
                }
                h += `<tr class="sum"><td class="nm">人數</td>` + items.map(x => {
                    const n = support(s.vert[x] || []);
                    return `<td class="c ${n === 0 ? 'zero' : n >= minSup ? 'ok' : 'no'}"><span>${n}</span></td>`;
                }).join('') + '</tr></tbody>';
                table.innerHTML = h;
                hint.innerHTML = sel && s.vert[sel]
                    ? `${pt([[sel]])} 的 id-list：${s.vert[sel].map(p => `(${NAMES[p[0]]}, 第 ${p[1] + 1} 次)`).join(' ')}，共 ${support(s.vert[sel])} 位顧客。`
                    : `格子裡的數字＝第幾次來店；綠框＝至少 ${minSup} 人。點欄位看那個商品出現在哪裡。`;
            } else if (s.kind === 'class') {
                s.cands.forEach((cd, i) => {
                    const b = document.createElement('button');
                    b.className = 'cand' + (cd.ok ? ' ok' : ' out') + (i === ci ? ' sel' : '');
                    b.dataset.i = i;
                    const tg = document.createElement('span');
                    tg.className = 'tg';
                    tg.textContent = cd.step;
                    b.appendChild(tg);
                    const nm = document.createElement('span');
                    nm.className = 'name';
                    nm.textContent = patText(cd.pat);
                    b.appendChild(nm);
                    const n = document.createElement('span');
                    n.className = 'n';
                    n.textContent = cd.sup;
                    b.appendChild(n);
                    box.appendChild(b);
                });
                if (!c) {
                    box.innerHTML = '<span class="cands-hint">（沒有可以合併的兄弟）</span>';
                    let h = `<thead><tr><th>顧客</th><th>A 的 id-list<small>${esc(patText(s.a))}</small></th></tr></thead><tbody>`;
                    for (let sid = 0; sid < N; sid++) {
                        const e = s.listA.filter(p => p[0] === sid).map(p => p[1] + 1);
                        h += `<tr><td class="nm">${NAMES[sid]}</td><td class="ids${e.length ? '' : ' none'}">${e.length ? e.join(',') : '·'}</td></tr>`;
                    }
                    table.innerHTML = h + '</tbody>';
                    hint.textContent = '';
                } else {
                    const cell = (list, sid, cls, firstMark) => {
                        const e = list.filter(p => p[0] === sid).map(p => p[1] + 1);
                        if (!e.length) return `<td class="ids none">·</td>`;
                        return `<td class="ids ${cls}">${e.map((v, j) => (firstMark && j === 0 ? `<span class="first">${v}</span>` : v)).join(',')}</td>`;
                    };
                    const tgName = c.step === 'S' ? 'S-step：後來再買' : 'I-step：同一次';
                    let h = `<thead><tr><th>顧客</th><th>A<small>${esc(patText(s.a))}</small></th><th>B<small>${esc(patText(c.b))}</small></th><th>${tgName}<small>${esc(patText(c.pat))}</small></th></tr></thead><tbody>`;
                    for (let sid = 0; sid < N; sid++)
                        h += `<tr><td class="nm">${NAMES[sid]}</td>${cell(s.listA, sid, '', c.step === 'S')}${cell(c.listB, sid, '', false)}${cell(c.list, sid, 'res', false)}</tr>`;
                    const sc = n => `<td class="c ${n === 0 ? 'zero' : n >= minSup ? 'ok' : 'no'}"><span>${n}</span></td>`;
                    h += `<tr class="sum"><td class="nm">人數</td>${sc(support(s.listA))}${sc(support(c.listB))}${sc(c.sup)}</tr></tbody>`;
                    table.innerHTML = h;
                    hint.innerHTML = (c.step === 'S'
                        ? `S-step：B 的每個位置，只要同一位顧客<b>更早</b>有 A（只要比 A 最早的那次晚，底線那個）就留下。`
                        : `I-step：A 和 B 要在同一位顧客、<b>同一次</b>來店（同一個數字）才留下。`) +
                        `結果 ${pt(c.pat)} 有 ${c.sup} 人，${c.ok ? '夠，記下來。' : `不到 ${minSup} 人，丟掉。`}點上面其他候選看別的合併。`;
                }
            } else {
                table.innerHTML = '';
                hint.textContent = s.kind === 'end' ? '全部挖完了。' : '還沒開始。按「下一步」。';
            }
            drawFound('s', s.found);
            $('s-st1').textContent = s.stats.scans;
            $('s-st2').textContent = s.stats.joins;
            $('s-st3').textContent = s.stats.depth;
        }
        $('s-cands').addEventListener('click', ev => {
            const b = ev.target.closest('.cand');
            if (!b) return;
            picks.s = Number(b.dataset.i);
            spadeShow();
            renderCode('s', CODE_TAGS.s(traces.s[cursors.s]));
        });
        $('s-table').addEventListener('click', ev => {
            const td = ev.target.closest('[data-x]');
            if (!td || traces.s[cursors.s].kind !== 'vertical') return;
            picks.s = picks.s === td.dataset.x ? null : td.dataset.x;
            spadeShow();
        });

        /* ---------- 結果 ---------- */
        function drawFound(g, found) {
            const box = $(g + '-levels');
            box.innerHTML = '';
            if (!found.length) box.innerHTML = '<div class="empty">還沒有，開始挖之後會出現在這裡。</div>';
            const bySize = {};
            found.forEach(r => { (bySize[sizeOf(r.pat)] = bySize[sizeOf(r.pat)] || []).push(r); });
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
        }

        /* ---------- 三種做法比一比 ---------- */
        function drawCompare() {
            const gEnd = traces.g[traces.g.length - 1], sEnd = traces.s[traces.s.length - 1];
            const ps = prefixSpanStats(db, minSup);
            const keyset = list => list.map(r => patKey(r.pat) + ':' + r.sup).sort().join('|');
            const same = keyset(gEnd.found) === keyset(sEnd.found) && keyset(sEnd.found) === keyset(ps.found);
            const row = (cls, nm, a, b, n) => `<tr class="${cls}"><td>${nm}</td><td>${a}</td><td>${b}</td><td><span class="big">${n}</span></td></tr>`;
            $('cmp').innerHTML = `<thead><tr><th>做法</th><th>掃描整個資料庫</th><th>產生／比對了多少東西</th><th>找到</th></tr></thead><tbody>` +
                row(activeTab === 'g' ? 'me' : '', 'GSP', `<span class="big">${gEnd.stats.scans}</span> 次<small>每一層掃一次</small>`,
                    `<span class="big">${gEnd.stats.gen}</span> 個候選<small>剪掉 ${gEnd.stats.pruned} 個，實際數 ${gEnd.stats.counted} 個（含 1 個商品的）</small>`, gEnd.found.length) +
                row(activeTab === 's' ? 'me' : '', 'SPADE', `<span class="big">1</span> 次<small>轉成垂直格式</small>`,
                    `<span class="big">${sEnd.stats.joins}</span> 次 id-list 合併<small>每次只看兩張小清單</small>`, sEnd.found.length) +
                row('', 'PrefixSpan', `<span class="big">1</span> 次<small>之後只看投影資料庫，共建 ${ps.projs - 1} 個</small>`,
                    `<span class="big">${ps.cells}</span> 格計數<small>不產生候選，只數真的出現過的</small>`, ps.found.length) + '</tbody>';
            $('cmp-note').innerHTML = (same ? `三種做法找到的 <b>${ps.found.length}</b> 個樣式（連支持度）完全一樣，差別只在過程做了多少事。` : '（三種做法的結果不一致，這不應該發生。）') +
                `改上面的資料或最小支持度，這張表會跟著重算。`;
        }

        /* =========================================================
           程式碼
           ========================================================= */
        const KW = {
            java: new Set('public static final for if return new boolean int void class import while else null this continue break record'.split(' ')),
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

        function renderCode(g, tags) {
            if (measuringBlocks || restoringBlocks) return;   // 量區塊高度時不用畫程式碼（程式碼框高度不會變），量完畫回來時它也沒被動過，省時間
            const pre = $(g + '-code');
            pre.innerHTML = CODE[g][lang].map(([text, t], i) =>
                `<span class="ln${t.some(x => tags.includes(x)) ? ' hl' : ''}" data-n="${i + 1}">${highlight(text) || ' '}</span>`).join('');
            const hls = [...pre.querySelectorAll('.ln.hl')];
            if (hls.length) {
                const groups = [];
                hls.forEach(el => {
                    const gr = groups[groups.length - 1];
                    if (gr && Number(el.dataset.n) === Number(gr[gr.length - 1].dataset.n) + 1) gr.push(el); else groups.push([el]);
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
            const file = g === 'g' ? ['GSP', 'gsp'] : ['SPADE', 'spade'];
            $(g + '-downloads').innerHTML = lang === 'java'
                ? `下載 <a href="code/${file[0]}.java" download>${file[0]}.java</a>　執行 <code>javac ${file[0]}.java && java ${file[0]}</code>`
                : `下載 <a href="code/${file[1]}.py" download>${file[1]}.py</a>　執行 <code>python3 ${file[1]}.py</code>`;
        }

        /* =========================================================
           顯示某一步
           ========================================================= */
        const DESCRIBE = { g: gspDescribe, s: spadeDescribe };
        function show(g) {
            const tr = traces[g], cur = cursors[g], s = tr[cur];
            $(g + '-explain').innerHTML = `<span class="step-no">步驟 ${cur + 1} / ${tr.length}</span>${DESCRIBE[g](s)}`;
            drawPresets(g);
            if (g === 'g') gspShow(); else spadeShow();
            renderCode(g, CODE_TAGS[g](s));
            $(g + '-prev').disabled = $(g + '-first').disabled = cur === 0 || editing;
            $(g + '-next').disabled = cur === tr.length - 1 || editing;
            $(g + '-play').disabled = editing;
            document.querySelectorAll('.sup-val').forEach(x => { x.textContent = minSup; });
            document.querySelectorAll('[data-sup="-1"]').forEach(b => { b.disabled = minSup <= minAllowed(); });
            document.querySelectorAll('[data-sup="1"]').forEach(b => { b.disabled = minSup >= Math.max(1, db.length); });
        }
        /* 門檻是 1 時樣式會多到一兩百個，候選和步驟都太多，所以最低 2（只有 1 位顧客時才能是 1） */
        const minAllowed = () => (db.length >= 2 ? 2 : 1);
        function goTo(g, i) { cursors[g] = i; picks[g] = null; show(g); }

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
        function reserveExplainHeight(g) {
            const box = $(g + '-explain');
            if (!box.offsetWidth) return;
            const probe = box.cloneNode(false);
            probe.removeAttribute('id');
            probe.style.cssText = `position:absolute;visibility:hidden;left:-9999px;min-height:0;width:${box.offsetWidth}px`;
            document.body.appendChild(probe);
            let tallest = 0;
            traces[g].forEach((s, i) => {
                probe.innerHTML = `<span class="step-no">步驟 ${i + 1} / ${traces[g].length}</span>${DESCRIBE[g](s)}`;
                tallest = Math.max(tallest, probe.offsetHeight);
            });
            probe.remove();
            box.style.minHeight = tallest + 'px';
            reserveBlockHeights($('panel-' + g), traces[g].length, i => { cursors[g] = i; show(g); }, () => cursors[g]);
        }

        function rebuild() {
            GROUPS.forEach(stopAuto);
            minSup = Math.max(minAllowed(), Math.min(minSup, db.length || 1));
            traces.g = gspTrace(db, minSup);
            traces.s = spadeTrace(db, minSup);
            GROUPS.forEach(g => { cursors[g] = 0; picks[g] = null; });
            drawCompare();
            GROUPS.forEach(show);
            reserveExplainHeight(activeTab);
        }

        /* =========================================================
           播放控制
           ========================================================= */
        function step(g, dir) {
            if (editing) return false;
            const next = cursors[g] + dir;
            if (next < 0 || next >= traces[g].length) return false;
            goTo(g, next);
            return cursors[g] < traces[g].length - 1;
        }
        function stopAuto(g) {
            clearInterval(timers[g]);
            timers[g] = null;
            $(g + '-play').textContent = '▶ 自動播放';
        }
        GROUPS.forEach(g => {
            $(g + '-next').addEventListener('click', () => { stopAuto(g); step(g, 1); });
            $(g + '-prev').addEventListener('click', () => { stopAuto(g); step(g, -1); });
            $(g + '-first').addEventListener('click', () => { stopAuto(g); goTo(g, 0); });
            $(g + '-play').addEventListener('click', () => {
                if (timers[g]) { stopAuto(g); return; }
                if (cursors[g] === traces[g].length - 1) goTo(g, 0);
                $(g + '-play').textContent = '⏸ 暫停';
                timers[g] = setInterval(() => { if (!step(g, 1)) stopAuto(g); }, 2200);
            });
        });
        document.addEventListener('keydown', e => {
            if (e.key === 'ArrowRight') { stopAuto(activeTab); step(activeTab, 1); }
            if (e.key === 'ArrowLeft') { stopAuto(activeTab); step(activeTab, -1); }
        });
        document.querySelectorAll('[data-sup]').forEach(b => b.addEventListener('click', () => {
            const v = minSup + Number(b.dataset.sup);
            if (v < minAllowed() || v > db.length) return;
            minSup = v;
            rebuild();
        }));
        document.querySelectorAll('.lang').forEach(box => box.addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b) return;
            lang = b.dataset.lang;
            document.querySelectorAll('.lang button').forEach(x => x.classList.toggle('active', x.dataset.lang === lang));
            GROUPS.forEach(g => renderCode(g, CODE_TAGS[g](traces[g][cursors[g]])));
        }));

        function switchTab(tab) {
            if (tab === activeTab) return;
            stopAuto(activeTab);
            if (editing) setEditing(false);
            activeTab = tab;
            document.querySelectorAll('.tabs button').forEach(b => {
                const on = b.dataset.tab === tab;
                b.classList.toggle('active', on);
                b.setAttribute('aria-selected', on);
            });
            $('panel-g').hidden = tab !== 'g';
            $('panel-s').hidden = tab !== 's';
            history.replaceState(null, '', tab === 's' ? '#spade' : '#gsp');
            drawCompare();
            show(tab);
            reserveExplainHeight(tab);
        }
        document.querySelector('.tabs').addEventListener('click', e => {
            const b = e.target.closest('button[data-tab]');
            if (b) switchTab(b.dataset.tab);
        });

        let resizeTimer = null;
        window.addEventListener('resize', () => { clearTimeout(resizeTimer); resizeTimer = setTimeout(() => reserveExplainHeight(activeTab), 150); });

        rebuild();
        if (location.hash === '#spade') switchTab('s');
    </script>
</body>

</html>
