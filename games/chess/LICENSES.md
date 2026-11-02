# Jellyfish Chess 使用的第三方元件

Jellyfish Chess（`games/chess/`）是純靜態網頁，以下元件直接放在 repo 裡（不靠 CDN，離線也能用）。

| 元件 | 版本 | 用途 | 授權 | 檔案 |
|---|---|---|---|---|
| [chess.js](https://github.com/jhlywa/chess.js) | 1.4.0 | 棋規（合法走法、易位、吃過路兵、升變、將死／和棋判定、FEN、PGN） | BSD-2-Clause | `vendor/chessjs/chess.js`、`vendor/chessjs/LICENSE` |
| [Stockfish.js](https://github.com/nmrugg/stockfish.js) | 18（npm `stockfish@18.0.8`，lite single-threaded） | 棋力引擎，WebAssembly，在 Web Worker 執行 | GPL-3.0 | `vendor/stockfish/stockfish-18-lite-single.js`、`.wasm`、`vendor/stockfish/COPYING.txt` |
| 棋子圖（cburnett） | — | 棋盤上的棋子 SVG | GPL-2.0-or-later（Colin M.L. Burnett，取自 [lichess-org/lila](https://github.com/lichess-org/lila/tree/master/public/piece/cburnett)） | `pieces/*.svg` |

## GPL 說明

Stockfish 以 GPLv3 發佈。這裡放的是 Stockfish.js 官方 npm 套件裡**未經修改**的編譯檔，原始碼在
<https://github.com/nmrugg/stockfish.js>（Stockfish 本體：<https://github.com/official-stockfish/Stockfish>）。
引擎以獨立的 Web Worker 載入，透過 UCI 文字協定溝通。

## 資料

- 戰術題：`data/tactics.js` 由 `tools/chess/gen_tactics.mjs` 用 Stockfish 自我對弈產生並驗證，是這個專案自己產生的資料。
- `data/lichess.js`：從 [Lichess 公開題庫](https://database.lichess.org/#puzzles) 挑出的題目，Lichess 以 CC0 釋出；題目卡上標有 Lichess 題號與連結。
- 開局、殘局內容：手寫，棋譜由 `tools/chess/check_data.mjs` 用 chess.js 與 Stockfish 檢查。
- 分析範例「歌劇院之局」（Morphy, 1858）是公共領域的歷史棋局。
