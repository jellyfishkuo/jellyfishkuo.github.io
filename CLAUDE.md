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
404.html                找不到頁面時 GitHub Pages 顯示的頁面（果汁龍迷路）；路徑一律 / 開頭；從首頁的連結猜使用者要找哪一頁
index.html              首頁：開場 / 作品 / 研究 / 關於我（含技能）/ 競賽 / 聯絡；深色＝A 版面、淺色＝C「果汁龍樂園」版面
assets/theme.js         深色／淺色切換（<head> 同步載入；localStorage `jfk-theme`，沒選過跟系統）；有 a.back 的頁面自動放切換鈕
assets/theme.css        子頁共用的淺色樣式（後半段由 tools/theme/lightify.py 產生，不要手改）
assets/dragon.svg       沒有底色的果汁龍（首頁開場、導覽列用）
assets/dragon-hold.js   果汁龍手上拿的東西（蘋果汁／牛奶／可樂／檸檬汁／西瓜汁／珍奶，寵物等級解鎖）：`jfkDragonURL(id)` 畫出整隻龍、`jfkPetHold()` 讀寵物的 `hold`；寵物頁、首頁那隻、跑酷都用它。身體是 dragon.svg 的複本，改身體要兩邊一起改
assets/logo.svg|.ico|-32/-180.png   站台圖示（深色底的果汁龍，手拿蘋果汁）
assets/og.png、assets/og/<slug>.jpg   分享預覽圖：首頁用 og.png，其他每頁各一張（tools/og/build_page_og.py 產生）。新增頁面或改標題／說明／圖示後要重跑
assets/pet-mini.js      遊戲頁右下角的小果汁龍（只讀 jfk-pet-v1）：點牠講這頁的話（`PAGE`，key 是檔名）；過關時遊戲呼叫 `if (window.jfkPetCheer) jfkPetCheer('…')`；底下有按鈕就閃到另一邊、兩邊都擋就縮到邊緣（`dodge()`）；「收起來」同一分頁不再出現。新遊戲頁要在 theme.js 後面加 `<script src="../assets/pet-mini.js" defer>`，`PAGE` 補幾句、過關處補 cheer
sw.js、manifest.webmanifest   整站離線快取＋加到手機主畫面（theme.js 會自動註冊 sw.js）。**manifest 只放在 index.html，不要每頁都加**：start_url 是首頁，iPhone 在任何一頁按「加入主畫面」都會變成開首頁。iPhone 用全螢幕（網頁 App）打開時，localStorage 跟 Safari 是分開的，所以電費紀錄這類存重要資料的頁面不要做成全螢幕 App。策略是「先抓網路、成功就存；抓不到才用存的」，所以不會卡舊版。**新增遊戲頁要加進 sw.js 的 `CORE`**；改 CORE 或快取規則就把 `VERSION` 加一。App 圖示 assets/app-192/512(.png、-maskable.png)。西洋棋有自己的 games/chess/sw.js
assets/icons/<name>.svg + -32.png + -180.png   每個作品的圖示（64×64、#12121c 圓角深色底、扁平圖形）
games/                  單檔遊戲／工具（HTML+CSS+JS 同一檔），以及 *-detail.html 技術介紹頁（由 tools/detail 產生）
research/               研究互動 Demo（由 tools/research 產生）與 research/code/ 可執行的 Java / Python
electricity-tracker/    電費紀錄（index.html + script.js + style.css）
stock/                  股票庫存（擁有者自己用，不放首頁、不放 README；noindex）。交易存 localStorage `jfk-stock-portfolio-v1`；收盤價由 .github/workflows/stock-quotes.yml 每個交易日 15:40～22:10 跑幾次 tools/stock/fetch_quotes.py 寫進 **`stock-data` 分支**（latest.json、每檔歷史 hist/<代號>.json、names.json；每次 force-push 成只有一個 commit，main 不放資料免得 repo 每天長大），頁面從 `raw.githubusercontent.com/.../stock-data/` 讀（快取最多 5 分鐘）；更早的歷史用 stock-backfill.yml 補
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
| `games/zip.html` | 一筆畫（像 LinkedIn Zip）：題目無限多，不做每天一題（使用者要求）。**最後要停在最大的數字上**：走到它（`P.K`）就不能再往前（`canStep`），過關也要求最後一格是它；解題器本來就要求終點是它。出題器：backbite 隨機一筆畫路線 → 放數字、加牆 → 解題器確認唯一解 → 拿掉多餘數字；題號 `#大小-難度-種子` 放網址可分享。紀錄存 localStorage `jfk-zip-v1`。電腦：點一下線的尾端進入「跟隨滑鼠」模式（不用按住），移動時把上一點到這一點的線段切成 0.1 格的小段逐格處理（`traceTo`／`enter`，含 `getCoalescedEvents()`），斜切過角落會補上中間那格（優先正前方那格）；往回收：手指走進線頭旁邊（含斜對角）、最近走過的 3 格之一的中間，就收回到那格（`recentBack`；轉彎處往回斜切過轉角也收得回去），更早的線劃過不收、只有點下去才收；放開時手指在這種格子上就照畫面收回；畫面上線的尾端跟著手指連續伸縮（`finger`＋`linePts()`，只影響畫，不影響哪一格算走過），重畫用 `requestDraw()` 每幀最多一次；方向鍵／WASD 也能走 |
| `games/store-manager.html` | 超商店長：5 週，每週隨機的顧客模型（每週一樣「大家都買」的陷阱商品＋幾條隱藏規則），玩家看 80 張收據、用分析工具看支持度／信賴度／提升度，挑最多兩組優惠（每組廣告費 $150）；效果＝只買其中一樣的客人依「真正的提升度」順手多買。評等是跟每週最佳兩組比的比例。紀錄 localStorage `jfk-store-v1`（`best`、`games`、`juice` 給寵物）；`?seed=` 固定題目方便測試 |
| `games/lab-life.html` | 碩一生模擬器：18 週，每週選一件事（讀 paper、跑實驗、準備 meeting、唸書、休息、出去玩），之後 meeting、第 9／17 週考試、隨機事件（第 13～16 週有投稿相關事件）。實驗進度 = 8 + 知識/4，心情 <30 打六折；體力 0 會病倒一週。6 種結局（圖鑑）。紀錄 localStorage `jfk-lab-v1`（`runs`、`endings`、`juice`）。**不要寫喝咖啡**，補體力用蘋果汁 |
| `games/pet.html` | 養一隻果汁龍：果汁＝其他遊戲紀錄算出來的（Zip 每題 1、研究闖關每顆星 2、超商店長 `juice`、碩一生模擬器 `juice`、跑酷 `juice`、數字方格 `juice`、每日簽到 3）減掉已餵的，不用改其他遊戲；新增會給果汁的遊戲時改 `sources()`。餵食長大（蛋→寶寶→小→果汁龍→大，`STAGES`；滿 3 瓶才孵化，判斷一律用 `hatched()`，不要用 `pet.xp` 是不是 0），等級解鎖配件（emoji 疊在 dragon.svg 上）、手上拿的東西（`pet.hold`，清單在 `assets/dragon-hold.js` 的 HOLDS）和背景。飽足每 10 分鐘少 1 格（`DROP`，首頁那隻也寫了一份；`#full-n` 顯示還有多久少 1 格，每 30 秒更新）；掉到 0 不會死，只會「餓扁扁」（`.pet.flat`）。新的蛋從 4/10 開始，蛋的飽足不會掉、可以一直餵到孵化。隱藏彩蛋：4 秒內連點寵物 10 下得 30 瓶（存在 `pet.bonus`，算進 `earned()` 但不列在來源表）；3 秒內連點「飽足」兩個字 5 下切換「無限胃」（`pet.glutton`，吃飽也能餵，開著時標籤顯示「飽足・無限胃」）。兩個都是擁有者要的，不要寫在畫面說明或 README。localStorage `jfk-pet-v1`。首頁也有一隻（index.html 的 `.hpet`，只讀不寫；固定在視窗上，在最下面一條（高 ≤ 140px 或 20%）每秒 22px 慢慢散步、停 2.5～7.5 秒，講話／收起來／餓扁扁／prefers-reduced-motion 時不走；位置用 JS 設 transform，自己有一份 STAGES，改大小規則時兩邊一起改；收起狀態存 `jfk-pet-home`） |
| `games/schulte.html` | 數字方格 1→25（舒爾特方格）：5×5 打亂 1～25，照順序點。按開始倒數 3 秒才翻開、翻開才計時（排行榜公平）；點用 `pointerdown`（快），鍵盤走 click；點錯記失誤不扣時間；切到別的 App 這局作廢。紀錄 localStorage `jfk-schulte-v1`（`runs`、`juice` 每局 1 瓶、`top` 最快 10 筆 `{t,m,d}`）。排行榜只在本機；要做全球排行榜得接外部服務（`finish()` 裡留了位置） |
| `games/runner.html` | 果汁龍跑酷：canvas，世界座標以畫面高 = 100 計，換螢幕手感不變。點一下跳、按住（最多 0.26 秒）重力變小跳更高；地上 🐛／📅／OOM、空中 ✉️（400m 後才有雙 bug 與 OOM）；🍎 無敵 4 秒。碰撞框比圖小一圈。紀錄 localStorage `jfk-runner-v1`（`best`、`runs`、`juice`，每次最多算 10 瓶給寵物） |
| `games/chess/` | Jellyfish Chess（**多檔**，例外於單檔慣例）：`index.html`＋`chess.css`＋`js/`（ES modules：`app.js` 路由與共用 UI、`board.js` 棋盤、`engine.js` Stockfish Worker 包裝、`store.js` IndexedDB＋偏好（DB 版本 2 加了 `meta` store：戰術積分 `puzzleRating`）、`review.js` 失誤分級與整盤評估（分析頁和對弈的「對完自動復盤」共用）、`play/tactics/analysis/openings/endgames/my.js` 六個功能）＋`data/`（`tactics.js` 由 `tools/chess/gen_tactics.mjs` 產生、`lichess.js` 由 `tools/chess/import_lichess.mjs`／Actions「Lichess 戰術題匯入」產生，都不要手改；`openings.js`、`endgames.js` 手寫，改完跑 `node tools/chess/check_data.mjs`）＋`vendor/`（chess.js 1.4、Stockfish 18 lite single WASM，不走 CDN）＋`pieces/`（cburnett SVG）＋`sw.js`（network-first 離線快取）。首頁卡片排在第 3 張（前 6 張之內，使用者要求；跟其他卡一樣大）。路徑一律相對（支援子路徑部署）。IndexedDB `jellyfish-chess`、localStorage `jfk-chess-prefs-v1`。chess.js 不會擋「不輪到走的一方被將軍」的 FEN（Stockfish 會回 `bestmove (none)`），載入 FEN 一律先過 `ui.js` 的 `fenProblem()`。測試：`python3 tools/chess/test_chess.py` |
| `games/dinner-wheel.html` | 晚餐轉盤：選項存 localStorage（`dinner-wheel-v1`），新增預設選項時調 `DEFAULTS_VERSION` 與 `ADDED_IN`，舊使用者會自動補上；轉盤文字由 `fitLabel()` 依扇形寬度與中間按鈕縮字，放不下才加「…」 |
| `electricity-tracker/` | 電費紀錄：localStorage `electricityMeterRecords_v1`；4 位數電表 9999→0000 視為繞圈；跨天用電依時間平均分配；匯入時整理 Excel 改過的日期格式 |
| `research/apriori.html`、`fp-growth.html`、`eclat.html`、`closed-patterns.html`、`association-rules.html`、`prefixspan.html`、`two-phase.html`、`up-growth.html`、`high-utility.html`、`top-k-hui.html`、`incremental.html`、`cantree.html`、`sliding-window.html`、`stream-counting.html`、`count-min.html`、`spatial.html`、`rtree.html`、`dbscan.html`、`efim.html`、`gsp-spade.html`、`gspan.html`、`bloom-filter.html`、`skyline.html`、`periodic.html`、`uspan.html`、`ihup.html`、`hyperloglog.html`、`ir-tree.html`、`foth.html`、`sw-huop.html`、`uncertain-sw.html`、`pretk.html` | 研究 Demo（32 個；最後 4 個是擁有者讀過的論文做的，頁面有「📄 論文」卡放書目與 DOI，不放 PDF；首頁 Research 的主題標籤可以篩選；新增 Demo 時卡片要加 `data-topics`）：大多用同一份 8 筆超商交易（☕🍞🥛🍙🥚🥔），一步一步看＋Java/Python 逐行高亮＋可下載執行。每個 Demo 都有「🎯 練習模式」（猜下一步，規格見 `tools/research/BRIEF.md`；新 Demo 也要寫自己的 `quizFor` 和 `quiz_test.py`） |
| `research/quest.html`、`assets/quest.js` | 研究闖關：每個研究 Demo 的 `<head>` 載入 `assets/quest.js`（寫在各 `.html.tpl`），它只看畫面（`.quiz` 加上 `done` 就是答一題、有 `miss` 是答錯）把答題記到 localStorage `jfk-quest-v1`，不碰各頁的練習模式程式；網址 `?quiz=1` 自動打開練習模式並顯示右下角進度。同一次答滿 5 題且答對 ≥50% 過關，星星看答對率（50/70/90%）。關卡清單在 quest.html 的 `WORLDS`，**新增 Demo 時要加進去，模板也要加 quest.js** |
| `research/papers.html` | 論文書架：上面是擁有者讀過、做成 Demo 的論文（手寫卡片，新增讀過的論文要加一張）；下面是經典論文，資料在頁面 JS 的 `PAPERS` 陣列（一行一篇，新增 Demo 時補上原始論文），連 Google Scholar 搜尋，不放 DOI（會議論文常沒有）。首頁 Research 標題下方第三個入口 |
| `research/overview.html`、`benchmark.html` | 研究地圖（關係圖＋閱讀路線＋比較表，`tools/research/overview/build.py` 自己有一份演算法清單，新增 Demo 時要補）與效能比賽場（Web Worker 實跑，`tools/research/benchmark/algos.js`）；首頁 Research 標題下方兩個入口 |

首頁 About 的「自己做的小工具與遊戲」數字（目前 16）在新增 Projects 作品時要跟著改。首頁作品區先只顯示剛好排滿的兩排（`#tiles`，依實際欄數算：電腦 5 欄＝10 張、手機 2 欄×3 排＝6 張；其餘按「看全部」展開），想放在前面的作品就排在前 6 個（手機也看得到）。晚餐轉盤排第 4 張（使用者要求）。新增作品或研究 Demo 時，`README.md` 的專案表／研究表也要同步。

首頁全站搜尋（導覽列放大鏡，`/` 或 Ctrl+K 打開）：資料**直接從首頁 DOM 讀**（`#tiles` 作品卡與「技術介紹」連結、`#research .hub`、`#demos .demo` 含主題標籤、關於我／競賽／聯絡段落），新增作品或 Demo 不用另外維護清單；`SYN` 是中英互通（tree↔樹…）。首頁果汁龍講話：跟整個網站連起來，不只講會給果汁的遊戲。台詞分類：`SITE`（每個作品一組，key 是首頁卡片的連結）、`DETAIL`（技術介紹冷知識）、`HUB`（研究入口）、研究 Demo（從 `#demos` 隨機挑＋`DEMO_SAY` 換說法）、`OWNER`（競賽、研究、技能、聯絡）、`timeLines()`（時段、週末、深淺色）、`recordLines()`（讀各遊戲 localStorage，只讀）、`LINES.self`；`CATS` 是各類權重。首頁上沒有那個連結的台詞不會講（作品拿掉就自動消失）；最近 15 句不重複（`sessionStorage` `jfk-pet-recent`）；孵蛋、餓了才偶爾提醒；每個分頁進首頁 12 秒後主動講一次（`jfk-pet-said`，收到角落時不講）。**新增作品時在 `SITE` 補一組台詞**，有技術介紹就在 `DETAIL` 補一句；台詞內容要對照頁面寫，不要寫網站上沒有的功能。

分享預覽（og／Twitter 標籤）：新頁面要有 `<title>` 和 `<meta name="description">`，再跑 `python3 tools/og/add_og.py <頁面或研究 Demo 樣板>`；技術介紹頁由 `build_detail.py` 自己產生。分享圖是 `assets/og.png`（1200×630，原始檔 `tools/og/og.html`，用 Playwright 截圖）。分享圖上寫了「32 個研究 Demo」「16 個小遊戲與工具」，數字變了要改 og.html 重新截圖。

## 開發慣例與踩過的坑

- 單檔、零建置、零框架；外部只用 CDN（Google Fonts、PeerJS、MQTT.js、canvas-confetti、MathJax）。例外：西洋棋把 chess.js 和 Stockfish WASM 放在 `games/chess/vendor/`（要離線、要在 Worker 裡跑）。
- 視覺有兩套，用 `assets/theme.js` 切換、`<html data-theme="dark|light">` 決定：
  - 深色（A）：深底、紫 `#7c3aed` / 青 `#06b6d4`，標題 `Syne`、等寬 `Space Mono`，細框，小標「// 01 — PROJECTS」。
  - 淺色（C，果汁龍樂園）：淺綠底 `#e9f7d9`、白卡片、粗黑框 `#1d2b12`＋硬陰影、果汁橘 `#ffb02e`、蘋果紅圓點標題，字型 `Noto Sans TC` 900；程式碼框也用淺色。
  - 兩套版面可以不一樣（使用者要求），只屬於一種主題的元素用 `.only-dark` / `.only-light`。首頁自己寫兩套；研究 Demo 與技術介紹頁用 `assets/theme.css`（淺色共用樣式＋自動算出的 `--lt-*` 顏色）＋ `tools/theme/lightify.py`（把 `<style>` 裡寫死的顏色換成 `var(--lt-xxxx, 原色)`），JS 畫出來的 `fill`/`stroke`/`style=` 顏色由 `theme.js` 在畫面上自動換。新頁面或新顏色要重跑 lightify（見 `tools/README.md`；遊戲頁加 `--root`）。頁面自己的淺色規則寫 `[data-theme="light"] ...`，lightify 不會動它。棋子、牌面等遊戲內容的顏色不要被換：容器加 `data-keep-color`，或整頁 `<meta name="jfk-paint" content="off">`；canvas 要聽 `themechange` 重畫。切換鈕位置：頁面放 `.jfk-switch-slot`（`.corner` 是右上角），沒有就跟 `a.back`／`a.back-link` 同一列。電費紀錄用自己的 style.css 變數切換。研究 Demo 與作品圖示另有淺色版 `-light.svg`（`tools/theme/icons_light.py` 產生；作品圖示要在 `PROJECTS` 寫換色），新增時要重跑。淺色下的彩色字保留原本色相（紫還是紫），由 `tools/theme/palette.py` 壓深。
- **不要用 `top`、`name`、`status`、`parent` 當全域變數或函式名**（`const top` 曾讓整頁掛掉）。
- **內容會變長變短的區塊，不能推動旁邊或下面的其他區塊**（使用者明確要求，所有程式都適用）。一步一步播放的說明框用最長說明的高度固定；Research Demo 的每個 `.card` 由 `reserveBlockHeights()` 把每一步都畫一次、用最高的那次固定（分段量，不卡畫面），新 Demo 也要接上。要切換顯示的提示文字用 `visibility` 切，不要清空內容。驗證：從頭按到尾，每個區塊的位置都不能變。
- 每頁的 CSS 都要有 `html { -webkit-text-size-adjust: 100%; text-size-adjust: 100%; }`，不然手機瀏覽器會自動放大部分文字，程式碼框的字一行大一行小。**這行要放在字型的 `@import` 後面**（`@import` 必須是樣式表的第一條，前面有任何規則就會失效、字型整個跑掉）。
- 遊戲頁的 CSS 要有 `* { touch-action: manipulation; }`（在 text-size-adjust 那行後面），不然手機連點兩下按鈕會放大畫面；不要用 `user-scalable=no`（兩指縮放要留著）。需要自己處理觸控的 canvas 另外設 `touch-action: none`。
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
