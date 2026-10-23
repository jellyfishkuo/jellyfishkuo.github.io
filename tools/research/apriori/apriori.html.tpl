<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/apriori.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/apriori-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/apriori-180.png">
    <title>Apriori 頻繁樣式探勘</title>
    <meta name="description" content="一步一步看 Apriori 怎麼從超商交易紀錄找出常一起買的商品組合：合併、剪枝、計數、篩選，Java 與 Python 程式碼逐行對照。">
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
        .intro { color: var(--lt-c6c6d6, #c6c6d6); max-width: 760px; margin-top: 0.9rem; font-size: 0.95rem; }
        .intro b { color: var(--text); }

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
        /* 欄寬固定：商品欄平分，不會因為「茶葉蛋」「洋芋片」三個字就比較寬 */
        .db th.tid-h { width: 2.1rem; }
        .db th.del-h { width: 30px; }
        .db th { font-weight: 400; color: var(--muted); font-size: clamp(0.6rem, 3vw, 0.75rem); white-space: nowrap; padding: 0 1px 4px; text-align: center; line-height: 1.25; }
        .db th .emo { display: block; font-size: 1.25rem; }
        .db th.sel { color: var(--warn); }
        .db td { text-align: center; padding: 0; }
        .db td.tid { font: 0.78rem 'Space Mono', monospace; color: var(--muted); text-align: left; width: 2.6em; padding-left: 0.3rem; }
        .db tr.match td { background: var(--lt-f59e0b-12, rgba(245, 158, 11, 0.12)); }
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
        .cell.has { background: var(--lt-2a2a48, #2a2a48); }
        .cell.has::after { content: ''; width: 11px; height: 11px; border-radius: 50%; background: var(--accent2); }
        .cell.hit { background: var(--lt-f59e0b-35, rgba(245, 158, 11, 0.35)); }
        .cell.hit::after { background: var(--warn); }
        .editing .cell { cursor: pointer; border: 1px dashed var(--lt-3a3a5a, #3a3a5a); }
        .editing .cell:hover { border-color: var(--accent2); }
        .db .del {
            background: none; border: none; color: var(--muted); cursor: pointer; font-size: 0.85rem;
            width: 26px; height: 26px; border-radius: 50%;
        }
        .db .del:hover { color: var(--bad); background: var(--lt-ffffff-5, rgba(255, 255, 255, 0.05)); }
        .db-foot { display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center; margin-top: 0.7rem; }

        .minsup { display: flex; align-items: center; gap: 0.45rem; flex-wrap: wrap; font-size: 0.9rem; }
        .minsup .val { font: 700 1rem 'Space Mono', monospace; min-width: 1.4em; text-align: center; }
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

        .cands { display: flex; flex-wrap: wrap; gap: 0.4rem; margin-top: 0.8rem; min-height: 2.2rem; }
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
        .cand .n { font: 700 0.78rem 'Space Mono', monospace; padding: 0 0.35rem; border-radius: 5px; background: var(--lt-2a2a48, #2a2a48); }
        .cand.ok { border-color: var(--lt-22c55e-55, rgba(34, 197, 94, 0.55)); }
        .cand.ok .n { background: var(--lt-22c55e-25, rgba(34, 197, 94, 0.25)); color: var(--lt-86efac, #86efac); }
        .cand.out { opacity: 0.6; }
        .cand.out .name { text-decoration: line-through; }
        .cand.out .n { background: var(--lt-f87171-20, rgba(248, 113, 113, 0.2)); color: var(--lt-fca5a5, #fca5a5); }
        .cand .why { color: var(--muted); font-size: 0.75rem; }
        .cands-hint { color: var(--muted); font-size: 0.8rem; margin-top: 0.5rem; min-height: 1.3em; }

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
            color: var(--lt-4a4a66, #4a4a66);
        }
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
        .levels { display: grid; gap: 0.5rem; }
        .level { display: grid; grid-template-columns: 3.2em 1fr; gap: 0.5rem; align-items: start; }
        .level .tag { font: 700 0.8rem 'Space Mono', monospace; color: var(--accent2); padding-top: 0.25rem; }
        .level .items { display: flex; flex-wrap: wrap; gap: 0.35rem; }
        .level .empty { color: var(--muted); font-size: 0.85rem; padding-top: 0.2rem; }
        .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.5rem; margin-top: 0.9rem; }
        .stat { background: var(--panel-2); border-radius: 10px; padding: 0.55rem 0.6rem; }
        .stat .v { font: 700 1.25rem 'Space Mono', monospace; }
        .stat .k { color: var(--muted); font-size: 0.75rem; line-height: 1.35; }

        .notes { margin-top: 1rem; display: grid; gap: 1rem; }
        @media (min-width: 960px) { .notes { grid-template-columns: 1fr 1fr; } }
        .notes p, .notes li { color: var(--lt-c6c6d6, #c6c6d6); font-size: 0.92rem; }
        .notes ul { padding-left: 1.2rem; display: grid; gap: 0.3rem; }
        .notes b { color: var(--text); }

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
        <div class="kicker">RESEARCH DEMO · FREQUENT PATTERN MINING</div>
        <h1>Apriori 頻繁樣式探勘<small>從超商交易紀錄，找出大家常一起買的東西</small></h1>
        <p class="intro">
            每一列是一筆交易（一張發票），點表示這筆有買那樣商品。一個商品組合出現在幾筆交易裡，叫做它的<b>支持度</b>；
            支持度至少達到門檻的組合就是<b>頻繁樣式</b>。Apriori 靠一個觀念大量省下工作：<b>如果一個組合不頻繁，包含它的更大組合也一定不頻繁</b>，
            所以從 1 個商品開始，一層一層往上找，不可能的組合連數都不用數。
        </p>

        <div class="layout">
            <div>
                <div class="card" id="db-card">
                    <div class="card-head">
                        <h2>交易資料庫</h2>
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
                    <div class="quiz-bar">
                        <button class="btn quiz-toggle" id="quiz-toggle" aria-pressed="false" title="按下一步之前先猜猜看">🎯 練習模式<span class="sw" aria-hidden="true"></span></button>
                        <span class="quiz-score" id="quiz-score" style="visibility:hidden">答對 0/0</span>
                    </div>
                    <div class="quiz-host" id="quiz-host">
                        <div class="explain" id="explain"></div>
                        <div class="quiz" id="quiz" role="group" aria-label="練習題" hidden></div>
                    </div>
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
                    <h2>目前找到的頻繁樣式</h2>
                    <div class="levels" id="levels"></div>
                    <div class="stats">
                        <div class="stat"><div class="v" id="st-scan">0</div><div class="k">掃描資料庫次數</div></div>
                        <div class="stat"><div class="v" id="st-count">0</div><div class="k">實際數過的組合</div></div>
                        <div class="stat"><div class="v" id="st-prune">0</div><div class="k">剪枝省掉、不用數的組合</div></div>
                    </div>
                </div>
            </div>
        </div>

        <div class="notes">
            <div class="card">
                <h2>為什麼剪枝是對的？</h2>
                <p>只要買了 {咖啡, 牛奶, 麵包} 的交易，一定也買了 {牛奶, 麵包}。所以大組合出現的次數，<b>不可能超過</b>它任何一個子集合出現的次數。
                    {牛奶, 麵包} 如果不到門檻，{咖啡, 牛奶, 麵包} 也一定不到，不用掃資料庫就能刪掉。這個性質叫做<b>向下封閉性</b>（downward closure）。</p>
                <p style="margin-top:0.5rem">合併時只拿「前 k−2 個商品相同」的兩個樣式來拼，是為了讓每個候選只被產生一次，而且它的兩個「爸爸」一定都是頻繁的。</p>
            </div>
            <div class="card">
                <h2>Apriori 的弱點，以及之後的研究</h2>
                <ul>
                    <li><b>每一層都要掃一次資料庫。</b>資料很大時，掃描是最花時間的部分。<a href="fp-growth.html" style="color:var(--accent2)">FP-Growth</a> 用一棵壓縮過的樹，只掃兩次就能找完（同一份資料可以直接比較）。</li>
                    <li><b>只看「出現次數」。</b>一組很少人買、但很賺錢的商品會被忽略。高效益樣式探勘改看數量 × 利潤，但效益沒有向下封閉性，需要另外設計上界來剪枝。</li>
                    <li><b>資料一直在變。</b>每多幾筆交易就全部重算太浪費，增量探勘研究的是怎麼只更新受影響的部分。</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        /* =========================================================
           Apriori 一步一步看
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
        let selChip = null;      // 目前點選的是哪個候選
        let timer = null;

        /* 跟 Java 的 compareTo、Python 的字串比較同一個順序（依字碼） */
        const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
        const key = set => set.join('|');
        const fmt = set => '{' + set.join(', ') + '}';
        const support = set => db.filter(t => set.every(x => t.has(x))).length;

        /* ---------- 照著程式跑一次，記下每一步 ---------- */
        function buildTrace() {
            const steps = [];
            const stats = { scans: 0, counted: 0, pruned: 0 };
            const found = [];                        // found[k-1] = 第 k 層的頻繁樣式
            const push = (kind, extra = {}) => steps.push({
                kind, ...extra, stats: { ...stats },
                found: found.map(level => level.map(x => ({ ...x })))
            });

            push('start');

            // L1：掃一次資料庫，數每個商品
            stats.scans++;
            const items = [...new Set(db.flatMap(t => [...t]))].sort(cmp);
            stats.counted += items.length;
            const c1 = items.map(i => ({ set: [i], count: support([i]) }));
            c1.forEach(c => { c.ok = c.count >= minSup; });
            let L = c1.filter(c => c.ok).map(c => ({ set: c.set, count: c.count }));
            push('L1', { cands: c1 });

            let k = 2;
            while (L.length) {
                found.push(L);
                push('loop', { k, L });

                // ① 合併
                const C = [];
                for (let i = 0; i < L.length; i++) {
                    for (let j = i + 1; j < L.length; j++) {
                        const a = L[i].set, b = L[j].set;
                        if (key(a.slice(0, k - 2)) === key(b.slice(0, k - 2))) {
                            C.push({ set: [...a, b[k - 2]], from: [a, b] });
                        }
                    }
                }
                push('join', { k, cands: C });

                // ② 剪枝
                const prev = new Set(L.map(x => key(x.set)));
                const pruneView = C.map(c => {
                    let missing = null;
                    for (let i = 0; i < c.set.length && !missing; i++) {
                        const sub = c.set.filter((_, idx) => idx !== i);
                        if (!prev.has(key(sub))) missing = sub;
                    }
                    return { set: c.set, ok: !missing, missing };
                });
                const kept = pruneView.filter(c => c.ok);
                stats.pruned += C.length - kept.length;
                push('prune', { k, cands: pruneView });

                // ③ 計數
                stats.scans++;
                stats.counted += kept.length;
                const counted = kept.map(c => ({ set: c.set, count: support(c.set) }));
                push('count', { k, cands: counted });

                // ④ 篩選
                const filtered = counted.map(c => ({ ...c, ok: c.count >= minSup }));
                L = filtered.filter(c => c.ok).map(c => ({ set: c.set, count: c.count }));
                push('filter', { k, cands: filtered });
                k++;
            }
            push('stop', { k });
            push('end');
            return steps;
        }

        /* ---------- 說明文字 ---------- */
        function describe(s) {
            const n = s.cands ? s.cands.length : 0;
            switch (s.kind) {
                case 'start':
                    return `目標：找出所有至少出現在 <b>${minSup}</b> 筆交易裡的商品組合。先從 1 個商品開始，一層一層往上找。`;
                case 'L1': {
                    const out = s.cands.filter(c => !c.ok);
                    return `第 1 次掃描資料庫：數每個商品出現在幾筆交易裡。` +
                        (out.length ? `${out.map(c => c.set[0]).join('、')} 不到 ${minSup} 筆被淘汰，` : '每個商品都達到門檻，') +
                        `剩下的 ${s.cands.length - out.length} 個就是 L1。`;
                }
                case 'loop':
                    return `L${s.k - 1} 不是空的，進入第 ${s.k} 層：先把 L${s.k - 1} 的 ${s.L.length} 個樣式放進結果，接著要找 ${s.k} 個商品的組合。`;
                case 'join':
                    return s.k === 2
                        ? `① 合併：k = 2 時「前 0 個相同」，所以 L1 裡任兩個商品都能配成一對，共產生 ${n} 個候選。`
                        : `① 合併：把 L${s.k - 1} 裡<b>前 ${s.k - 2} 個商品相同</b>的兩兩配對，拼成 ${s.k} 個商品的候選，共 ${n} 個。` + (n ? '點候選可以看它是哪兩個拼出來的。' : '');
                case 'prune': {
                    const out = s.cands.filter(c => !c.ok).length;
                    if (!n) return `② 剪枝：沒有候選可以檢查。`;
                    return out
                        ? `② 剪枝：檢查每個候選拿掉任一個商品後的子集合，是不是都在 L${s.k - 1} 裡。有 <b>${out}</b> 個候選的子集合不頻繁，不用數就知道它不可能頻繁，直接刪掉。`
                        : `② 剪枝：檢查每個候選的 ${s.k - 1} 個商品子集合，都在 L${s.k - 1} 裡，這一層沒有可以剪掉的。`;
                }
                case 'count':
                    return n
                        ? `③ 計數：第 ${s.stats.scans} 次掃描資料庫，數每個候選出現在幾筆交易裡。點候選可以在左上的表格看到是哪幾筆。`
                        : `③ 計數：沒有候選可以數，但程式還是會呼叫一次計數、掃一次資料庫。實務上可以在這之前判斷候選是不是空的，提早結束。`;
                case 'filter': {
                    const ok = s.cands.filter(c => c.ok).length;
                    return ok
                        ? `④ 篩選：留下次數 ≥ ${minSup} 的 <b>${ok}</b> 個，成為 L${s.k}。` + (ok < n ? `其他 ${n - ok} 個雖然通過剪枝，但實際數完還是不夠。` : '')
                        : `④ 篩選：沒有任何候選達到 ${minSup} 次，L${s.k} 是空的。`;
                }
                case 'stop':
                    return `L${s.k - 1} 是空的，迴圈條件不成立，停止往上找。`;
                case 'end': {
                    const total = s.found.reduce((a, l) => a + l.length, 0);
                    const all = 2 ** ITEMS.length - 1;
                    return `完成！共找到 <b>${total}</b> 個頻繁樣式，掃描資料庫 ${s.stats.scans} 次。${ITEMS.length} 個商品的組合一共有 ${all} 種，Apriori 只實際數了 ${s.stats.counted} 種，另外 ${s.stats.pruned} 種在剪枝時就刪掉了。`;
                }
            }
            return '';
        }

        const CODE_TAG = { start: 'start', L1: 'L1', loop: 'loop', join: 'join', prune: 'prune', count: 'count', filter: 'filter', stop: 'loop', end: 'end' };

        /* ---------- 畫面 ---------- */
        function renderDB() {
            const table = $('db');
            const hit = new Set(selected || []);
            let html = '<tr><th class="tid-h"></th>' + ITEMS.map(i =>
                `<th class="${hit.has(i) ? 'sel' : ''}"><span class="emo">${EMOJI[i]}</span>${i}</th>`).join('') +
                (editing ? '<th class="del-h"></th>' : '') + '</tr>';
            db.forEach((t, r) => {
                const match = selected && selected.every(x => t.has(x));
                html += `<tr class="${match ? 'match' : ''}"><td class="tid">T${r + 1}</td>` +
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

        function candButton(c, s) {
            const b = document.createElement('button');
            b.type = 'button';
            let cls = 'cand';
            let badge = '', why = '';
            if (s.kind === 'L1' || s.kind === 'filter') {
                cls += c.ok ? ' ok' : ' out';
                badge = c.count;
                if (!c.ok) why = `< ${minSup}`;
            } else if (s.kind === 'count') {
                badge = c.count;
            } else if (s.kind === 'prune') {
                cls += c.ok ? '' : ' out';
                if (!c.ok) why = `${fmt(c.missing)} 不頻繁`;
            } else if (s.kind === 'loop' || s.kind === 'found') {
                cls += ' ok';
                badge = c.count;
            }
            if (selChip === key(c.set)) cls += ' sel';
            b.className = cls;
            b.innerHTML = `<span class="name"></span>${badge !== '' ? `<span class="n">${badge}</span>` : ''}${why ? `<span class="why"></span>` : ''}`;
            b.querySelector('.name').textContent = fmt(c.set);
            if (why) b.querySelector('.why').textContent = why;
            b.addEventListener('click', () => {
                const again = selChip === key(c.set);
                selChip = again ? null : key(c.set);
                // 被剪掉的候選，標出的是「不頻繁的那個子集合」出現在哪幾筆
                selected = again ? null : (s.kind === 'prune' && !c.ok ? c.missing : c.set);
                renderDB();
                showCands();
                renderLevels(trace[cursor]);
                showHint(c, s);
            });
            return b;
        }

        function showHint(c, s) {
            const hint = $('cands-hint');
            if (!selected || !c) { hint.textContent = ''; return; }
            const n = support(c.set);
            let text = `${fmt(c.set)} 出現在 ${n} 筆交易裡（左上表格標黃的列）。`;
            if (s.kind === 'join' && c.from) text = `${fmt(c.set)} 是由 ${fmt(c.from[0])} 和 ${fmt(c.from[1])} 拼出來的。` + text;
            if (s.kind === 'prune' && !c.ok) text = `${fmt(c.set)} 的子集合 ${fmt(c.missing)} 只出現在 ${support(c.missing)} 筆（表格標黃的列）、不到 ${minSup}，所以 ${fmt(c.set)} 最多也只會出現 ${support(c.missing)} 次，不用數就能剪掉。`;
            hint.textContent = text;
        }

        function showCands() {
            const s = trace[cursor];
            const box = $('cands');
            box.innerHTML = '';
            const list = s.cands || (s.kind === 'loop' ? s.L : null);
            if (list) list.forEach(c => box.appendChild(candButton(c, s)));
            else if (s.kind === 'end' || s.kind === 'stop') {
                s.found.flat().forEach(c => box.appendChild(candButton(c, { kind: 'found' })));
            }
            if (list && !list.length) box.innerHTML = '<span class="cands-hint">（沒有候選）</span>';
        }

        function renderLevels(s) {
            const box = $('levels');
            box.innerHTML = '';
            if (!s.found.length) {
                box.innerHTML = '<div class="level"><span class="tag">—</span><span class="empty">還沒有，L1 算完之後會出現在這裡。</span></div>';
            }
            s.found.forEach((level, i) => {
                const row = document.createElement('div');
                row.className = 'level';
                row.innerHTML = `<span class="tag">L${i + 1}</span><div class="items"></div>`;
                level.forEach(c => row.querySelector('.items').appendChild(candButton(c, { kind: 'found' })));
                box.appendChild(row);
            });
            $('st-scan').textContent = s.stats.scans;
            $('st-count').textContent = s.stats.counted;
            $('st-prune').textContent = s.stats.pruned;
        }

        /* 簡單的語法上色 */
        const KW = {
            java: new Set('public static final for if return new boolean int void class import while else'.split(' ')),
            py: new Set('def for in if return not and or while import from as True False None'.split(' '))
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
                    if (lang === 'java' && /^[A-Z]/.test(word)) return `<span class="ty">${word}</span>`;
                    return word;
                }
                return esc(m);
            });
            return out + (comment ? `<span class="cm">${esc(comment)}</span>` : '');
        }

        function renderCode(tag) {
            if (measuringBlocks || restoringBlocks) return;   // 量區塊高度時不用畫程式碼（程式碼框高度不會變），量完畫回來時它也沒被動過，省時間
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
                let [top, bottom] = span(hls[0], hls[hls.length - 1]);
                if (bottom - top > pre.clientHeight - 16) {
                    const big = groups.reduce((x, y) => (y.length > x.length ? y : x));
                    [top, bottom] = span(big[0], big[big.length - 1]);
                }
                const target = (top + bottom) / 2 - pre.clientHeight / 2;
                pre.scrollTo({ top: Math.max(0, Math.min(target, top - 8)), behavior: 'smooth' });
            }
            $('downloads').innerHTML = lang === 'java'
                ? '下載 <a href="code/Apriori.java" download>Apriori.java</a>　執行 <code>javac Apriori.java && java Apriori</code>'
                : '下載 <a href="code/apriori.py" download>apriori.py</a>　執行 <code>python3 apriori.py</code>';
        }

        function showStep() {
            const s = trace[cursor];
            selected = null;
            selChip = null;
            renderDB();
            $('explain').innerHTML = `<span class="step-no">步驟 ${cursor + 1} / ${trace.length}</span>${describe(s)}`;
            showCands();
            $('cands-hint').textContent = (s.cands && s.cands.length && ['count', 'join', 'prune', 'L1', 'filter'].includes(s.kind)) ? '點候選看看是哪幾筆交易' : '';
            renderLevels(s);
            renderCode(CODE_TAG[s.kind]);
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

        /* 第 i 步（s = trace[i]）要出的題目：{ q, choices, answer, why, multi?, ask? } 或 null。
           answer 是正確選項的索引（multi 時是索引陣列，可以是空的）；ask 只給 quiz_test.py 對答案用。 */
        function quizFor(s, i) {
            const rnd = quizRng(i + 1);
            const cands = s.cands || [];
            switch (s.kind) {
                case 'L1': {
                    if (!cands.length) return null;
                    const c = quizPick(cands, rnd), item = c.set[0];
                    return {
                        q: `第 1 次掃描：${item} 出現在幾筆交易裡？`,
                        ...quizNums(c.count, 0, db.length, rnd),
                        why: `${item} 那一欄有 ${c.count} 個點，就是 ${c.count} 筆；${c.ok ? `≥ ${minSup}，會留在 L1。` : `不到 ${minSup}，會被淘汰。`}`,
                        ask: { type: 'support', set: c.set }
                    };
                }
                case 'join': {
                    const L = s.found[s.k - 2], m = L.length, all = m * (m - 1) / 2;
                    if (m < 2) return null;
                    return {
                        q: `L${s.k - 1} 有 ${m} 個樣式。合併之後，會產生幾個 ${s.k} 個商品的候選？`,
                        ...quizNums(cands.length, 0, all + 2, rnd, [all]),
                        why: s.k === 2 ? `k = 2 時任兩個商品都能配一對：${m} × ${m - 1} ÷ 2 = ${cands.length} 個。`
                            : all === cands.length ? `這次剛好每一對的前 ${s.k - 2} 個商品都相同，所以有 ${all} 個。`
                            : `只有「前 ${s.k - 2} 個商品相同」的兩個才能合併，不是任兩個都配（那樣會有 ${all} 個），實際是 ${cands.length} 個。`,
                        ask: { type: 'join', k: s.k, L: L.map(c => c.set) }
                    };
                }
                case 'prune': {
                    if (!cands.length) return null;
                    const out = cands.filter(c => !c.ok);
                    const c = out.length && rnd() < 0.6 ? quizPick(out, rnd) : quizPick(cands, rnd);
                    return {
                        q: `剪枝：${fmt(c.set)} 會被直接刪掉、不用數嗎？`,
                        choices: [`會，有子集合不在 L${s.k - 1}`, `不會，要留下來數`],
                        answer: c.ok ? 1 : 0,
                        why: c.ok ? `拿掉任一個商品後的子集合都在 L${s.k - 1} 裡，有機會頻繁，要留下來實際去數。`
                            : `子集合 ${fmt(c.missing)} 不在 L${s.k - 1} 裡（它不頻繁），包含它的 ${fmt(c.set)} 也不可能頻繁。`,
                        ask: { type: 'prune', set: c.set, L: s.found[s.k - 2].map(x => x.set) }
                    };
                }
                case 'count': {
                    if (!cands.length) return null;
                    const c = quizPick(cands, rnd);
                    const rows = db.map((t, r) => r).filter(r => c.set.every(x => db[r].has(x)));
                    return {
                        q: `第 ${s.stats.scans} 次掃描：${fmt(c.set)} 出現在幾筆交易裡？`,
                        ...quizNums(c.count, 0, db.length, rnd),
                        why: rows.length ? `同時買了 ${c.set.join('、')} 的是 ${rows.map(r => 'T' + (r + 1)).join('、')}，共 ${c.count} 筆。` : `沒有任何一筆同時買了這幾樣，是 0 筆。`,
                        ask: { type: 'support', set: c.set }
                    };
                }
                case 'filter': {
                    if (!cands.length) return null;
                    const keep = cands.map((c, k) => k).filter(k => cands[k].ok);
                    const why = keep.length ? `次數 ≥ ${minSup} 的有 ${keep.length} 個：${keep.map(k => `${fmt(cands[k].set)} ${cands[k].count} 次`).join('、')}。`
                        : `每個候選都不到 ${minSup} 次，L${s.k} 是空的。`;
                    if (cands.length > 6) {
                        return {
                            q: `門檻 ${minSup}：這 ${cands.length} 個候選有幾個會留下來成為 L${s.k}？`,
                            ...quizNums(keep.length, 0, cands.length, rnd),
                            why: `次數 ≥ ${minSup} 的有 ${keep.length} 個。`,
                            ask: { type: 'filterCount', sets: cands.map(c => c.set) }
                        };
                    }
                    const mq = {
                        q: `門檻 ${minSup}：哪幾個會留下來成為 L${s.k}？（都不會就直接按確定）`,
                        choices: cands.map(c => fmt(c.set)), answer: keep, multi: true, why,
                        ask: { type: 'filter', sets: cands.map(c => c.set) }
                    };
                    return cands.length > 1 ? mq : quizSingle(mq, `門檻 ${minSup}：${fmt(cands[0].set)} 會留下來成為 L${s.k} 嗎？`);
                }
            }
            return null;
        }

        /* ---------- 操作 ---------- */
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
            timer = setInterval(() => { if (!step(1)) stopAuto(); }, 1800);
        });
        document.addEventListener('keydown', e => {
            if (e.key === 'ArrowRight') { stopAuto(); step(1); }
            if (e.key === 'ArrowLeft') { stopAuto(); step(-1); }
        });

        $('sup-minus').addEventListener('click', () => { minSup--; rebuild(true); });
        $('sup-plus').addEventListener('click', () => { minSup++; rebuild(true); });

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
