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
- **區塊不能互相推擠**：每個 `.card` 都要用 `reserveBlockHeights()`（照抄現有 Demo，在 reserveExplainHeight 結尾呼叫）固定成所有步驟裡最高的高度；驗證時從頭按到尾，每個 `.card` 的位置都不能變。
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

## 回報

最後回覆：做了哪些檔案、步驟流程摘要（列出每種步驟）、驗證結果（數字）、截圖路徑、已知限制。簡潔即可。
