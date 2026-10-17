# tools：產生頁面與測試用的原始檔

網站本身沒有建置流程，大部分頁面是手寫的單一 HTML。但有兩類頁面是**由這裡的原始檔產生的**，要改它們請改這裡，再重新產生，不要直接改產出的 HTML：

| 產出 | 原始檔 | 怎麼重新產生 |
|---|---|---|
| `games/*-detail.html`（技術介紹頁） | `detail/content/<name>.py` + `detail/build_detail.py`（共用外框） | `cd tools/detail && python3 -B build_detail.py <name> ...` |
| `research/<page>.html` 與 `research/code/*.java`、`*.py` | `research/<page>/` 裡的 `*.tpl` + `build.py` | `cd tools/research/<page> && python3 -B build.py ../../../research/code` |

需要 Python 3；測試另外需要 `pip install playwright`（瀏覽器用系統裝好的 Chromium 即可）。所有腳本都用相對路徑找 repo 根目錄，從哪裡 clone 都能跑。

## detail/：技術介紹頁

- `build_detail.py`：共用外框（標題、分頁、側欄「其他技術剖析」、Quick Facts）。`GAMES` 清單決定側欄的交叉連結，新增一頁要加進去，然後**重新產生所有頁面**，側欄才會同步。
- `content/<name>.py`：每頁內容，定義 `PAGE = dict(...)`。可用的輔助函式：`case(no, title, symptom, cause, fix, check=None, lesson=None)`、`callout(kind, title, body)`、`table(headers, rows)`。案例編號 `#n` 要連續，新增案例後記得重新編號、檢查內文交叉引用（例如「見問題 #23」）。
- `PAGE` 可選的 `play_href` / `play_label`：試玩按鈕不在 `games/` 裡時用（例如電費紀錄）。
- `check_detail.py <name>`：開本機伺服器（埠 8770，服務 repo 根目錄）後跑，檢查分頁切換、目錄跳轉、深層連結、手機寬度與 JS 錯誤。
- 寫作原則：寫「遇到什麼問題、怎麼修」，不要寫成貼程式碼；繁體中文、白話。

## research/：研究互動 Demo

每個子資料夾一個 Demo：

- `<Name>.java.tpl`、`<name>.py.tpl`：程式碼模板。每行行尾可以加 `«tag»` 標記，表示這行屬於哪個步驟（例如 `«join»`、`«prune»`）；`«tag{»` … `«}tag»` 標一整段；`«hide»` / `«hide{»…«}hide»` 是只放在下載檔、不顯示在網頁上的部分（import、main）。
- `build.py`：把模板拆成兩份——乾淨的原始碼寫到 `research/code/`（可直接下載執行），以及帶標記的 JSON 嵌進 `<page>.html.tpl` 的 `/*CODE_JSON*/null`，產生 `research/<page>.html`。所以**網頁上高亮的程式碼和下載的檔案永遠同源**。
- `<page>.html.tpl`：頁面本體。JS 裡照同樣的演算法跑一次、把每一步記成 trace，上一步／下一步只是在 trace 裡移動。
- `test.py`：用隨機資料把網頁 JS、Python 版（有的還有暴力法）交叉比對，並逐步走完檢查錯誤與版面。需要本機伺服器在 8770 埠：`cd <repo> && python3 -m http.server 8770`。
- `icon.py`（部分有）：產生 `assets/icons/<page>-32.png`、`-180.png`。
- `BRIEF.md`：做新 Demo 時的共用規格與檢查清單（版面、互動、驗證方式、踩過的坑）。

驗證 Java：`javac -encoding UTF-8 -d /tmp/out research/code/X.java && java -Dstdout.encoding=UTF-8 -cp /tmp/out X`（終端機不是 UTF-8 時中文會變問號）。

## theme/：淺色版（果汁龍樂園）

- `lightify.py`：幫頁面接上淺色。`<head>` 加 `theme.js`／`theme.css`，`<style>` 裡寫死的顏色改成 `var(--lt-xxxx, 原色)`（深色時變數沒定義，照舊），用到的顏色記在 `colors.json`，並重寫 `assets/theme.css` 最後自動產生的那段。可以重複執行。
- `palette.py`：深色→淺色的換色規則（語法高亮、紫青主色有指定，其餘依亮度／飽和度換）。調規則後跑 `python3 lightify.py --css-only`。
- 技術介紹頁的顏色在 `games/detail.css`（`python3 lightify.py ../../games/detail.css`）。
- 研究 Demo 改的是樣板：`cd tools/theme && python3 lightify.py --prefix ../ ../research/*/*.tpl ../../research/*.html`，再重新產生各頁。
- JS 產生的顏色不用改程式：`theme.js` 會把畫面上 `fill`/`stroke`/`style=` 的顏色換成同樣的 `var()`；顏色要先被 lightify 登記過（掃整個檔案）才有淺色值。

- `icons_light.py`：產生圖示的淺色版 `assets/icons/<name>-light.svg`（首頁淺色版用，白底墨框）。研究 Demo 用通用規則換色；作品圖示寫在 `PROJECTS`，逐一指定要換的顏色。新增 Demo／作品或改圖示後重跑。
- `palette.py`：淺色換色規則。彩色字保留色相，只把亮度壓到白底看得清楚（大約 Tailwind 700 色階，見 `text_tone`）；改完跑 `python3 lightify.py --css-only` 重新產生 `theme.css` 的自動區塊。

## set-online/：SET 多人連線的本機測試環境

SET 線上對戰平常用公開的 PeerJS 配對服務和 MQTT 伺服器，測試時改成本機的：

1. `cd tools/set-online && npm install`（裝 `peer`、`aedes`、`ws`）
2. `bash mk.sh`：從 `games/game-set.html` 產生測試版到 `site/`（連線改指向本機；`short.html` 只有 18 張牌方便測結束；`blocked.html` 擋掉直連、強迫走 MQTT 備援）
3. `bash up.sh`：啟動 PeerServer（9000）、MQTT over WebSocket（9001）、測試站（8766）與 repo（8770）
4. 跑測試，例如 `python3 t_mp1.py`、`python3 t_resume.py`（多人、斷線重連、再來一局等情境；`mp.py` / `rx.py` / `harness.py` 是共用的輔助函式）

這些測試腳本是一路修 bug 時寫的，有的還假設舊的 UI；跑失敗時先看是不是腳本跟不上頁面。
