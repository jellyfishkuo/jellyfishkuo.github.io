# 共用規格：研究互動 Demo 頁

你在幫一位資料庫系統實驗室的碩一生（研究資料探勘）做 GitHub Pages 個人網站上的「研究互動 Demo」。
已經做好兩頁，**一定要先完整讀過它們，照同樣的結構、風格、品質做**：

- 網頁：`<repo>/research/apriori.html`、`<repo>/research/fp-growth.html`
- 來源模板（真正的原始檔）：`SCRATCH/apriori/`、`SCRATCH/fp/`（`*.tpl`、`build.py`、`test.py`）
- SCRATCH = 這個 `tools/research` 資料夾（每個 Demo 一個子資料夾）

## 你要交付的東西（只動自己的檔案）

1. `SCRATCH/<你的資料夾>/` 裡的模板與建置腳本：`<Name>.java.tpl`、`<name>.py.tpl`、`<page>.html.tpl`、`build.py`、`test.py`
2. 由 build.py 產生到網站裡的：
   - `<repo>/research/<page>.html`
   - `<repo>/research/code/<Name>.java` 與 `<name>.py`（可直接執行、有 main / `__main__` 範例）
3. 圖示：`<repo>/assets/icons/<page>.svg`、`<page>-32.png`、`<page>-180.png`
   （64×64 viewBox、深色圓角底 `<rect x="1" y="1" width="62" height="62" rx="13" fill="#12121c" stroke="#3a3a52" stroke-width="2"/>`，簡單的扁平圖形；PNG 用 playwright 渲染，方法見其他圖示的作法：把 svg 放進頁面、`omit_background=True` 截圖）

**不要**修改 `index.html`、其他頁面、其他人的檔案；**不要** git add / commit / push；完成後刪掉 `research/code/__pycache__`（跑 Python 時用 `python3 -B` 或 `sys.dont_write_bytecode = True`）。

## 頁面要求（照 apriori / fp-growth）

- 繁體中文（台灣用語），語氣跟現有兩頁一樣：白話、具體、像在教學弟妹。標題區有 `RESEARCH DEMO · ...` kicker、h1 + small 副標、intro 段落（提到並連結相關的前一頁）。
- 返回連結 `../index.html#research`，head 裡的 icon 連結指向你的圖示。
- 「一步一步看」：上一步 / 下一步 / 回到開頭 / 自動播放、鍵盤左右鍵；每一步一段說明（`.explain`），**用最長說明的高度固定說明框**（照抄 reserveExplainHeight），否則下面的東西會跳。
- **區塊不能互相推擠**：每個 `.card` 都要用 `reserveBlockHeights()`（照抄 apriori 的整段：`let measuringBlocks…` 那行到 `document.fonts` 那行，在 reserveExplainHeight 結尾呼叫）固定成所有步驟裡最高的高度；驗證時從頭按到尾，每個 `.card` 的位置都不能變。這段程式會：
  - 分段量（每段約 45ms，用 MessageChannel 接下一段），每段量完畫回目前這一步；量完之前按的上一步／下一步／播放／左右鍵會先排隊，量完才照順序做（所以按鈕 id 要叫 `xx-first`、`xx-prev`、`xx-next`、`xx-play`、`xx-last` 或 `btn-…`）；網路字型載完會自動重量一次。
  - `renderCode()` 第一行要是 `if (measuringBlocks || restoringBlocks) return;`（量的時候和量完畫回來時都不用重畫程式碼）。只在畫面上捲動、不影響高度的動作用 `if (!measuringBlocks)` 包起來。
  - **量完要快**：每一步都會被畫一次再排版一次，一步的成本 × 步數就是量完的時間（目標：預設設定 0.5 秒內、最極端的設定 2 秒內）。常見的省法：結果清單只在後面多幾個時只補新的（不要每一步 `innerHTML = ''` 整排重畫，見 prefixspan / gspan 的 `drawResult`）；內容跟上一步一模一樣就不要重設 `innerHTML`（見 ihup 的 `drawDB`）；量高度時（`measuringBlocks` 為真）可以省略不影響大小的細節，例如固定 viewBox 的 SVG 只畫外框（見 gspan 的 `svgGraph`）、格子數不變的色塊不重畫（見 hyperloglog 的 `renderRegs`）。不確定會不會影響高度的就不要省。
  - 驗證：載入後**馬上**每 30ms 按一次下一步直到最後一步，量完之後每個 `.card` 位置都不能再變；也量一下最極端的參數（門檻調到最低）量完要多久。
- CSS 開頭要有 `html { -webkit-text-size-adjust: 100%; text-size-adjust: 100%; }`（手機才不會把程式碼的字放大得忽大忽小），放在字型 `@import` 後面。
- 程式碼框：Java / Python 切換；每一步高亮正在執行的那幾行（用模板裡的 «tag» 標記，build.py 產生 JSON 嵌進頁面）；**只捲程式碼框本身（pre.scrollTo），絕對不要 scrollIntoView 去捲整頁**；下方有下載連結和執行指令。網頁上顯示的程式碼和下載的檔案必須同源（都由 .tpl 產生）。
- 網頁裡用 JavaScript 照同樣的演算法跑一次產生步驟紀錄（trace），上一步/下一步只是在紀錄裡移動。
- 使用者可調的參數（門檻等）改了要重新產生 trace。
- 用超商商品當例子時沿用同一組：咖啡☕ 麵包🍞 牛奶🥛 飯糰🍙 茶葉蛋🥚 洋芋片🥔，以及同一份 8 筆交易（見 apriori.html 的 SAMPLE），除非你的主題需要別的資料。
- 版面：手機一欄、電腦（≥960px）兩欄；grid 子元素要 `min-width: 0`；**375px 寬時整頁不能有水平捲動**（scrollWidth == 375）。
- 使用者輸入或資料顯示用 textContent 或確實跳脫，不要把字串直接塞進 innerHTML。
- 不要用 `top`、`name`、`status`、`parent` 這類瀏覽器全域名稱當全域變數 / 函式名（`top` 曾經讓整頁掛掉）。
- 頁面底部兩張 notes 卡：一張講「為什麼這樣是對的」的關鍵性質，一張講「優缺點 / 跟前面方法比較 / 和實驗室研究的關係」。
- 外部字型會被擋，測試時 `ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())`。

## 驗證（一定要做，回報結果）

- `javac -encoding UTF-8` 編譯並執行 Java，`python3 -B` 執行 Python，兩者輸出一致。
- 用 playwright 對網頁的 JS 實作做**隨機資料交叉驗證**：至少 200 組隨機輸入，跟 Python 版（以及能寫就寫一個暴力法）結果完全一致。
- 從頭按到尾每一步：沒有 pageerror、說明框高度固定、程式碼高亮行合理。
- 手機 375×760 與電腦 1280×900 截圖，自己用 Read 工具看過，修正版面問題。
- 本機伺服器：`cd <repo> && python3 -m http.server <你的埠> >/dev/null 2>&1 &`（每個 shell 呼叫可能會被收掉，必要時在同一個指令裡重開）。

## 練習模式「猜下一步」（照 apriori / fp-growth / high-utility 做）

開關「🎯 練習模式」打開後，按「下一步」（按鈕、→ 鍵、自動播放都一樣）時，如果**下一步**有題目，先在說明框的位置疊一層題目；答完立刻顯示對錯和一句解釋，按「繼續 ▶」才前進（說明框照常顯示）。記分「答對 x/y」。可以「跳過」（不計分）。上一步、⏮、關掉開關都會收起題目；改資料或門檻後重新出題。關掉時行為跟原本完全一樣。

**照抄的部分**（三頁一模一樣，直接複製）：
- CSS：`/* ── 練習模式（猜下一步）…── */` 整段，放在 `</style>` 前面。class：`.quiz-bar` `.quiz-toggle`（`.quiz-on`、`.sw` 開關）`.quiz-score` `.quiz-host` `.quiz`（`.done` 已作答、`.miss` 答錯、`.nudge` 沒作答就按下一步時抖一下）`.quiz-head` `.quiz-tag` `.quiz-actions`（`.quiz-ok` 確定、`.quiz-go` 跳過／繼續）`.quiz-body`（`.quiz-text` 題目、`.quiz-why` 解釋疊在同一格）`.quiz-choices`（`.row` 數字一列、`.half` 短選項兩欄、`.wide` 長選項一行一個）`.quiz-choice`（`.sel` `.right` `.wrong` `.missed`）。
- HTML：把 `<div class="explain" id="explain"></div>` 換成
  ```html
  <div class="quiz-bar">
      <button class="btn quiz-toggle" id="quiz-toggle" aria-pressed="false" title="按下一步之前先猜猜看">🎯 練習模式<span class="sw" aria-hidden="true"></span></button>
      <span class="quiz-score" id="quiz-score" style="visibility:hidden">答對 0/0</span>
  </div>
  <div class="quiz-host" id="quiz-host">
      <div class="explain" id="explain"></div>
      <div class="quiz" id="quiz" role="group" aria-label="練習題" hidden></div>
  </div>
  ```
- JS：`練習模式「猜下一步」（各 Demo 共用…）` 那段整段（`QZ`、`quizRng`、`quizPick`、`quizShuffle`、`quizNums`、`quizOptions`、`quizSingle`、`quizRender`、`quizOpen/Close/Answer/Score`、`quizGate`、`quizReserve` 和事件），放在 `function step(dir)` 前面。需要頁面上有 `$`、`trace`、`cursor`、`#btn-next`、`#btn-first`。
- 接兩行：`step(dir)` 的第一行 `if (quizGate(dir)) return false;`；`reserveExplainHeight()` 的第一行 `quizReserve();`（先替題目框預留高度，再讓 `reserveBlockHeights()` 量各區塊）。

**每頁自己寫的只有 `quizFor(s, i)`**：第 i 步（`s = trace[i]`）要出的題目，沒有就回傳 `null`。
```js
{ q: '題目', choices: ['選項', ...], answer: 2,          // 單選：正確選項的索引
  multi: true, answer: [0, 3],                            // 複選：索引陣列，可以是空的（「都不會就直接按確定」）
  why: '一句解釋（答完才顯示）', ask: { type: '...', ... } }  // ask 只給 quiz_test.py 對答案
```
- **答案一定從 `s`（頁面自己算出來的 trace）取**，不能寫死；題目也只能用 trace 和目前的資料／門檻組出來，使用者改資料後照樣能出題。
- q / choices / why 都是**純文字**（`quizRender` 用 textContent 放），不要放 HTML；頁面的 `fmt()` 如果有跳脫（例如 high-utility），要另外用沒跳脫的版本。
- 亂數一律用 `const rnd = quizRng(i + 1)`，同一步每次出的題目才會一樣（預留高度時量的和真的顯示的一致）。
- 工具：`quizNums(ans, lo, hi, rnd, traps)` 數字題（正確答案＋容易搞混的數字＋附近的數，湊 4 個）；`quizOptions([{ text: 正確 }, { text: 陷阱 }...], rnd)` 文字題（去重、打亂）；複選只剩一個選項時用 `quizSingle(mq, '…會留下來嗎？')` 改成會／不會。
- 出題原則：只在有重點的步驟出（剪枝會不會剪、支持度／效益是多少、哪些留下、插入後節點次數、條件模式基底、上界夠不夠…），太多重複的步驟可以隔幾步問一次；陷阱選項用**常見的錯誤想法**算出來（忘了扣 P、把自己算進前綴、用上面節點的次數、把上界當效益…）；why 一句話講為什麼，引用實際數字。
- 題目框要短：選項最多 4 個、長選項（像路徑清單）最多 3 個；手機 375px 時題目框高度最好不要比最長的說明多太多（關掉練習模式也會預留這個高度）。
- 驗證：寫 `quiz_test.py`（照 apriori 的），至少 100 組隨機資料，每一題用 Python 自己算（或暴力法）對答案，並檢查選項不重複、至少 2 個；再用 playwright 在 375 / 1280 把練習模式打開、隨機作答從頭走到尾：每個 `.card` 位置不變（包括開關練習模式、題目打開、作答後）、沒有 pageerror、`scrollWidth` 等於視窗寬。

**研究闖關**：模板 `<head>` 在 theme.js 後面加 `<script src="../assets/quest.js" defer></script>`，再把新 Demo 加進 `research/quest.html` 的 `WORLDS`。quest.js 靠 `.quiz`／`.done`／`.miss`／`.quiz-toggle` 這幾個 class 判斷答題，不要改名。

## 回報

最後回覆：做了哪些檔案、步驟流程摘要（列出每種步驟）、驗證結果（數字）、截圖路徑、已知限制。簡潔即可。
