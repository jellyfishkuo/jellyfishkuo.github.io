# 給 Claude 的專案說明

果汁龍（GitHub：jellyfishkuo）的個人網站，GitHub Pages：<https://jellyfishkuo.github.io>。

## 擁有者與溝通

- 擁有者是資料庫系統實驗室的碩一生，研究方向是資料探勘（頻繁／高效益樣式、增量資料庫、資料串流、空間資料）。喜歡自己做小工具、小遊戲。
- **一律用繁體中文（台灣用語）回覆。** 頁面文字也一樣，白話、具體，像在教學弟妹。
- **改完直接推到 `main`，不要開 PR。** 推之前一定要自己驗證（見下方）。
- 大部分使用者用手機看，手機版面優先。
- 不要寫「喝很多咖啡」之類的敘述（擁有者不喝咖啡）。Java 技能那格的 ☕ 是 Java 標誌，保留。

## 網站結構

```
index.html              首頁：Hero / 01 About / 02 Research / 03 Skills / 04 Projects / 05 Achievements / 06 Contact
assets/logo.svg|.ico|-32/-180.png   站台圖示（深色底的果汁龍，手拿蘋果汁）
assets/icons/<name>.svg + -32.png + -180.png   每個作品的圖示（64×64、#12121c 圓角深色底、扁平圖形）
games/                  單檔遊戲／工具（HTML+CSS+JS 同一檔），以及 *-detail.html 技術介紹頁（由 tools/detail 產生）
research/               研究互動 Demo（由 tools/research 產生）與 research/code/ 可執行的 Java / Python
electricity-tracker/    電費紀錄（index.html + script.js + style.css）
tools/                  產生頁面的原始檔與測試，見 tools/README.md
```

**由原始檔產生的頁面不要直接改 HTML**：`games/*-detail.html` 改 `tools/detail/content/*.py`；`research/*.html` 與 `research/code/*` 改 `tools/research/<page>/*.tpl`。改完重新產生（指令在 `tools/README.md`）。

## 作品一覽與重點

| 頁面 | 重點 / 注意事項 |
|---|---|
| `games/pentomino.html` | 每日挑戰（拖曳）＋ 自由解答（求解器、可一鍵標出今天日期） |
| `games/game-set.html` | SET：單人、電腦對手、**多人連線（最多 6 人）**。房主權威制；WebRTC（PeerJS，自訂 iceServers 時要自己列 TURN）打不通 10 秒後改走 MQTT 備援（EMQX、HiveMQ）。暱稱、等待室、全員同意才重新開始、斷線同房號重回（同暱稱合併紀錄）、配對亮 0.8 秒＋上方縮圖提示、同一局鎖定牌面排法。 |
| `games/1A2B.html`、`infinite-tictactoe.html`、`vertical-gomoku.html`、`coc-card.html` | 各有技術介紹頁 |
| `games/hanoi.html` | 河內塔：自己玩（任意盤面的最佳提示）＋ 看遞迴怎麼解（Python/JS/C++ 逐行高亮、呼叫堆疊） |
| `games/dinner-wheel.html` | 晚餐轉盤：選項存 localStorage（`dinner-wheel-v1`），新增預設選項時調 `DEFAULTS_VERSION` 與 `ADDED_IN`，舊使用者會自動補上；轉盤文字由 `fitLabel()` 依扇形寬度與中間按鈕縮字，放不下才加「…」 |
| `electricity-tracker/` | 電費紀錄：localStorage `electricityMeterRecords_v1`；4 位數電表 9999→0000 視為繞圈；跨天用電依時間平均分配；匯入時整理 Excel 改過的日期格式 |
| `research/apriori.html`、`fp-growth.html`、`eclat.html`、`closed-patterns.html`、`association-rules.html`、`prefixspan.html`、`two-phase.html`、`up-growth.html`、`high-utility.html`、`top-k-hui.html`、`incremental.html`、`cantree.html`、`sliding-window.html`、`stream-counting.html`、`count-min.html`、`spatial.html`、`rtree.html`、`dbscan.html`、`efim.html`、`gsp-spade.html`、`gspan.html`、`bloom-filter.html`、`skyline.html`、`periodic.html`、`uspan.html`、`ihup.html`、`hyperloglog.html`、`ir-tree.html` | 研究 Demo（28 個，首頁 Research 的主題標籤可以篩選；新增 Demo 時卡片要加 `data-topics`）：大多用同一份 8 筆超商交易（☕🍞🥛🍙🥚🥔），一步一步看＋Java/Python 逐行高亮＋可下載執行。apriori、fp-growth、high-utility 有「🎯 練習模式」（猜下一步，規格見 `tools/research/BRIEF.md`） |
| `research/overview.html`、`benchmark.html` | 研究地圖（關係圖＋閱讀路線＋比較表，`tools/research/overview/build.py` 自己有一份演算法清單，新增 Demo 時要補）與效能比賽場（Web Worker 實跑，`tools/research/benchmark/algos.js`）；首頁 Research 標題下方兩個入口 |

首頁 About 的「自己做的小工具與遊戲」數字（目前 9）在新增 Projects 作品時要跟著改。新增作品或研究 Demo 時，`README.md` 的專案表／研究表也要同步。

## 開發慣例與踩過的坑

- 單檔、零建置、零框架；外部只用 CDN（Google Fonts、PeerJS、MQTT.js、canvas-confetti、MathJax）。
- 視覺：深色底、紫 `#7c3aed` / 青 `#06b6d4`，標題 `Syne`、等寬 `Space Mono`。
- **不要用 `top`、`name`、`status`、`parent` 當全域變數或函式名**（`const top` 曾讓整頁掛掉）。
- **內容會變長變短的區塊，不能推動旁邊或下面的其他區塊**（使用者明確要求，所有程式都適用）。一步一步播放的說明框用最長說明的高度固定；Research Demo 的每個 `.card` 由 `reserveBlockHeights()` 把每一步都畫一次、用最高的那次固定（分段量，不卡畫面），新 Demo 也要接上。要切換顯示的提示文字用 `visibility` 切，不要清空內容。驗證：從頭按到尾，每個區塊的位置都不能變。
- 每頁的 CSS 都要有 `html { -webkit-text-size-adjust: 100%; text-size-adjust: 100%; }`，不然手機瀏覽器會自動放大部分文字，程式碼框的字一行大一行小。**這行要放在字型的 `@import` 後面**（`@import` 必須是樣式表的第一條，前面有任何規則就會失效、字型整個跑掉）。
- 程式碼框自動捲動只捲框本身（`pre.scrollTo`），不要 `scrollIntoView` 捲整頁。
- grid 子元素加 `min-width: 0`；寬內容（程式碼、表格）在自己的框內捲動。
- 手機標題用 `nowrap` 時要搭配依螢幕寬度縮放的字級，不然放大字體或窄螢幕會撐破頁面。
- 使用者輸入（暱稱、選項名稱…）一律用 `textContent`，不要塞進 `innerHTML`。
- localStorage 一律包 try/catch，被擋時頁面照樣能用。
- 改 localStorage 的資料格式或預設值時，要處理已經存了舊資料的使用者。

## 驗證（推之前）

- 本機伺服器：`python3 -m http.server 8770`（repo 根目錄），用 Playwright + Chromium 測。外部字型會被擋，測試時 `route("**/fonts.googleapis.com/**", abort)`。
- 至少檢查：沒有 pageerror；手機 375px（必要時 320px、放大字體）`document.documentElement.scrollWidth` 等於視窗寬；截圖自己看過。
- 演算法類：用隨機資料把頁面 JS 跟 Python / 暴力法交叉比對（各 Demo 的 `test.py`）。
- Java：`javac -encoding UTF-8`，執行加 `-Dstdout.encoding=UTF-8`。
- 不要把 `__pycache__`、`*.class`、測試截圖 commit 進去（`.gitignore` 已設）。
