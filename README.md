# jellyfishkuo.github.io

果汁龍的個人網站與作品集。純靜態、零建置、零框架 —— 每個頁面都是可以直接用瀏覽器打開的單一 HTML 檔。

🔗 **線上瀏覽：** <https://jellyfishkuo.github.io>

---

## 這個 repo 是什麼

一個 GitHub Pages 網站，包含個人簡介、競賽紀錄，以及六個自己寫的互動專案。每個專案都有兩個入口：

- **直接試玩** —— 可以立刻操作的成品
- **技術介紹** —— 針對工程師讀者寫的深入剖析，包含演算法推導、設計取捨、實測數據，以及誠實記錄的已知限制

## 專案一覽

| 專案 | 類型 | 試玩 | 技術介紹 |
|---|---|---|---|
| Pentomino 8×8 求解器 | 演算法 / 拖曳互動 | [pentomino.html](games/pentomino.html) | [pentomino-detail.html](games/pentomino-detail.html) |
| 無限井字棋 | 賽局論 / AI | [infinite-tictactoe.html](games/infinite-tictactoe.html) | [infinite-tictactoe-detail.html](games/infinite-tictactoe-detail.html) |
| SET 練功房 | 組合數學 / SVG | [game-set.html](games/game-set.html) | [game-set-detail.html](games/game-set-detail.html) |
| 1A2B 猜數字 | 邏輯推理 / 資訊論 | [1A2B.html](games/1A2B.html) | [1A2B-detail.html](games/1A2B-detail.html) |
| 部落衝突卡牌交易站 | 狀態管理 / localStorage | [coc-card.html](games/coc-card.html) | [coc-card-detail.html](games/coc-card-detail.html) |
| 程式解題紀錄 | 筆記 | [Notion](https://www.notion.so/34ac593666d9802ea9a9dc05f3df12d1?source=copy_link) | — |

### 幾個從這些專案裡算出來的結果

- **無限井字棋被完整求解了**：116,074 個可達局面、先手必勝、13 手收官，而且<u>只有下四個「邊」格才贏</u> —— 中央與角落都是和局，和標準井字棋的開局理論完全相反。
- **Pentomino** 經典的中央 2×2 缺口共有 **520 個解**，正好等於文獻上的「65 個本質解 × 8 種對稱」。
- **SET** 隨機 12 張檯面平均藏著 2.78 組解，但有 **3.22%** 的機率完全無解（約每 31 副一次）—— 這解釋了為什麼「提示」按鈕必須兼任自動補牌。
- **1A2B** 解空間 5,040、回饋只有 14 種，資訊論下界是 4 猜；純邏輯推理跑完全部 5,040 個答案的平均成績是 **5.56 猜**。

推導過程與驗證方法都寫在各自的技術介紹頁裡。

## 檔案結構

```
.
├── index.html                 # 首頁（簡介 / 技能 / 專案 / 競賽紀錄 / 聯絡）
├── assets/
│   ├── logo.ico               # 站台 favicon
│   ├── puzzle.ico             # Pentomino 用 favicon
│   └── me.jpg
└── games/
    ├── detail.css             # 所有「技術介紹」頁共用的樣式表
    ├── pentomino.html         # 每日挑戰（拖曳）+ 自由解答（求解器）
    ├── pentomino-detail.html
    ├── infinite-tictactoe.html
    ├── infinite-tictactoe-detail.html
    ├── game-set.html
    ├── game-set-detail.html
    ├── 1A2B.html
    ├── 1A2B-detail.html
    ├── coc-card.html
    └── coc-card-detail.html
```

## 技術與設計原則

**沒有建置流程。** 沒有 npm、沒有打包工具、沒有 CI。改完 HTML 推上 `main`，GitHub Pages 就會部署。

- **遊戲頁是自我完備的單檔**：HTML + 內嵌 CSS + 內嵌 JS 全部在同一個檔案裡。優點是任何一頁都能單獨複製、單獨打開；代價是頁面之間有些重複的程式碼（例如粒子背景）。
- **技術介紹頁共用 [`games/detail.css`](games/detail.css)**：這五頁的樣式高度一致，各自內嵌會變成五份 900 行的複本，所以抽成共用樣式表。
- **外部依賴只有三個 CDN 資源**：Google Fonts（Space Mono / Syne 等）、[canvas-confetti](https://github.com/catdad/canvas-confetti)（過關特效）、[MathJax](https://www.mathjax.org/)（技術介紹頁的數學式）。沒有 CDN 也不會壞掉，只是少了特效與排版精緻度。
- **視覺語言**：深色底 + 紫（`#7c3aed`）青（`#06b6d4`）漸層，`Syne` 做標題、`Space Mono` 做等寬與標籤。
- **資料一律留在本機**：卡牌交易站用 `localStorage`，沒有後端、沒有帳號、沒有追蹤。

## 本機預覽

直接用瀏覽器開 `index.html` 就能看，但建議起一個本機伺服器（`file://` 下沒有 origin，`localStorage` 之類的 API 會受限）：

```bash
# Python 內建就有
python3 -m http.server 8000

# 或 Node
npx serve .
```

然後開 <http://localhost:8000>。

## 想再加一個專案的話

1. 在 `games/` 放 `你的專案.html`（單檔，自我完備）。
2. 想寫技術介紹就加 `games/你的專案-detail.html`，`<head>` 裡連 `detail.css`，沿用 `.tech-card` / `.code-window` / `.callout` / `.table-wrap` 這些現成元件。
3. 在 `index.html` 的 `#projects` 區塊複製一張 `.project-card`，補上「技術介紹」與「直接試玩」兩個連結。
4. 記得檢查：
   - `<html lang="zh-Hant">` 與 `<meta name="viewport">` 都要有，且**不要**鎖 `user-scalable=no`（違反 WCAG 1.4.4）
   - favicon 路徑從 `games/` 出發是 `../assets/...`
   - 在 320 / 390 / 768 / 1280px 四個寬度看一下有沒有水平溢出

## 品質檢查

這個網站沒有測試框架，但改動時我會用 headless Chrome（puppeteer）與 jsdom 做幾件事：

- **全站掃描**：每頁攔截 JS 例外、驗證所有本地連結與資源是否存在、量測各尺寸下的水平溢出。
- **行為測試**：用 jsdom 載入實際頁面模擬點擊與按鍵，驗證遊戲邏輯（例如 SET 的判定重入鎖、1A2B 的 A/B 判定是否自洽）。
- **演算法驗證**：把頁面裡的演算法原封不動抽出來跑窮舉或大量取樣，確認實作與理論一致（例如 SET 的 1,080 組、Pentomino 的 520 個解）。

幾個踩過的坑值得記著：

- macOS 上的 headless Chrome 有 **500px 最小視窗限制**，`--window-size=390` 會變成「用 500px 排版再裁成 390px」，看起來像溢出 bug。要測行動版必須用 CDP 的裝置模擬。
- jsdom 在 `file://`（opaque origin）下**不提供 `localStorage`**，測持久化要用 `https://` 的 URL。
- jsdom 沒有 canvas 實作，`getContext('2d')` 回傳 `null` —— 這反而幫我抓到「純裝飾的背景動畫會讓整個遊戲開不起來」這種真實的健壯性問題。

---

© 2026 果汁龍
