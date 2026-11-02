// 從 Lichess 公開題庫（CC0，https://database.lichess.org/#puzzles）挑題，寫到 games/chess/data/lichess.js。
// 自己產生的題目（data/tactics.js）不會被動到；網頁會把兩份合在一起。
//
// 用法（從標準輸入讀解壓後的 CSV，邊讀邊挑，不用整個存下來）：
//   curl -L https://database.lichess.org/lichess_db_puzzle.csv.zst | zstd -dc | node tools/chess/import_lichess.mjs
//   node tools/chess/import_lichess.mjs lichess_db_puzzle.csv          # 已經解壓好的檔案也可以
// 選項：--per-theme 60（每個題型挑幾題）  --no-engine（不用 Stockfish 檢查，快但沒有評估分數）
//
// 挑題規則：熱門度 ≥ 85、被做過 ≥ 1000 次、評分誤差 ≤ 80（大家都覺得是好題、難度穩定）；
// 每個題型在 4 個難度區間（<1200、1200–1600、1600–2000、≥2000）平均挑；同一區間裡用題號雜湊排序，
// 所以 Lichess 題庫更新時，挑到的題目大多不會變（使用者的作答紀錄對得上）。
// 每題再用 chess.js 檢查每一步合法，用 Stockfish 確認照答案走完是你這方明顯優勢或將死，不符合的丟掉。
import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';
import { Chess } from '../../games/chess/vendor/chessjs/chess.js';
import { Engine, cpOf, ROOT } from './uci.mjs';
import { explain, materialOf } from './themes.mjs';

const args = process.argv.slice(2);
const opt = k => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : null; };
const PER = +(opt('--per-theme') || 60);
const USE_ENGINE = !args.includes('--no-engine');
const file = args.find(a => !a.startsWith('--') && a !== opt('--per-theme'));

// Lichess 的題型標籤 → 網站的 8 個題型
const MAP = { fork: 'fork', pin: 'pin', skewer: 'skewer', discoveredAttack: 'discovered', deflection: 'deflection', capturingDefender: 'defender', mate: 'mate', defensiveMove: 'defense' };
const BUCKETS = [[0, 1200], [1200, 1600], [1600, 2000], [2000, 9999]];
const perBucket = Math.ceil(PER / BUCKETS.length);
const hash = s => { let h = 0x811c9dc5; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 0x01000193) >>> 0; } return h; };

// 每個（題型, 難度區間）留雜湊值最小的幾題（多留一些，給引擎檢查淘汰）
const KEEP = perBucket * 2;
const pick = {};
for (const t of Object.values(MAP)) pick[t] = BUCKETS.map(() => []);
function offer(arr, row) {
  if (arr.length < KEEP) { arr.push(row); arr.sort((a, b) => a.h - b.h); return; }
  if (row.h < arr[arr.length - 1].h) { arr[arr.length - 1] = row; arr.sort((a, b) => a.h - b.h); }
}

const input = file ? fs.createReadStream(file) : process.stdin;
const rl = readline.createInterface({ input, crlfDelay: Infinity });
let n = 0, ok = 0, header = null;
for await (const line of rl) {
  if (!line) continue;
  const f = line.split(',');
  if (!header) {
    if (f[0] === 'PuzzleId') { header = Object.fromEntries(f.map((k, i) => [k, i])); continue; }
    header = { PuzzleId: 0, FEN: 1, Moves: 2, Rating: 3, RatingDeviation: 4, Popularity: 5, NbPlays: 6, Themes: 7, GameUrl: 8 };
  }
  n++;
  const rating = +f[header.Rating], rd = +f[header.RatingDeviation], pop = +f[header.Popularity], plays = +f[header.NbPlays];
  if (!(pop >= 85 && plays >= 1000 && rd <= 80)) continue;
  const tags = f[header.Themes].split(' ');
  const mine = [...new Set(tags.map(t => MAP[t]).filter(Boolean))];
  if (!mine.length) continue;
  ok++;
  const row = { id: f[header.PuzzleId], fen: f[header.FEN], moves: f[header.Moves], rating, tags, themes: mine, h: hash(f[header.PuzzleId]) };
  const b = BUCKETS.findIndex(([lo, hi]) => rating >= lo && rating < hi);
  for (const t of mine) offer(pick[t][b], row);
  if (n % 500000 === 0) console.error(`  讀了 ${n} 題，符合條件 ${ok} 題`);
}
console.error(`讀完 ${n} 題，符合條件 ${ok} 題`);
if (!n) { console.error('沒有讀到任何題目：檢查輸入是不是解壓後的 CSV'); process.exit(1); }

const engine = USE_ENGINE ? await new Engine().init({ Hash: 64 }) : null;
const chosen = new Map();
const checked = new Map();          // id → 通過檢查的結果（一題可能出現在好幾個題型）
async function check(row) {
  if (checked.has(row.id)) return checked.get(row.id);
  let res = null;
  try {
    const g = new Chess(row.fen);
    const ms = row.moves.split(' ');
    if (ms.length < 2 || ms.length % 2) throw new Error('步數不對');
    g.move({ from: ms[0].slice(0, 2), to: ms[0].slice(2, 4), promotion: ms[0][4] });
    const solver = g.turn(), startMat = materialOf(g, solver), startFen = g.fen();
    for (const u of ms.slice(1)) g.move({ from: u.slice(0, 2), to: u.slice(2, 4), promotion: u[4] });
    const mate = g.isCheckmate();
    let startEval = null;
    if (engine) {
      // 開始局面的評估（給解析用），以及走完後還是不是明顯優勢
      const a = await engine.analyse(startFen, { depth: 14 });
      startEval = a.lines[0] && a.lines[0].score;
      if (!mate) {
        const z = await engine.analyse(g.fen(), { depth: 12 });
        const after = z.lines[0] ? -cpOf(z.lines[0].score) : 0;
        const defensive = row.themes.includes('defense');
        if (!defensive && after < 150) throw new Error('走完不是明顯優勢');
        if (defensive && after < -150) throw new Error('防守後還是輸');
      }
    }
    const v = { fen: row.fen, moves: ms, kind: row.themes.includes('defense') && !row.themes.some(t => t !== 'defense') ? 'defense' : 'attack', mate, gain: materialOf(g, solver) - startMat, startEval, themes: row.themes };
    const level = row.rating < 1200 ? 1 : row.rating < 1800 ? 2 : 3;
    res = { id: 'li' + row.id, fen: row.fen, moves: row.moves, themes: row.themes, level, rating: row.rating, src: 'lichess', ...explain(v) };
  } catch (e) { res = null; }
  checked.set(row.id, res);
  return res;
}
for (const [t, buckets] of Object.entries(pick)) {
  let got = 0;
  for (const arr of buckets) {
    let k = 0;
    for (const row of arr) {
      if (k >= perBucket) break;
      const r = await check(row);
      if (r) { chosen.set(r.id, r); k++; got++; }
    }
  }
  console.error(`  ${t}：${got} 題`);
}
if (engine) engine.quit();

const list = [...chosen.values()].sort((a, b) => a.id.localeCompare(b.id));
const js = `// 由 tools/chess/import_lichess.mjs 從 Lichess 公開題庫（CC0，https://database.lichess.org/#puzzles）挑出來，不要手改。
// 格式跟 data/tactics.js 一樣；id 是 li + Lichess 題號，rating 是 Lichess 上的難度分數。
export const LICHESS = ${JSON.stringify(list).replace(/\},\{/g, '},\n{')};
`;
fs.writeFileSync(path.join(ROOT, 'games/chess/data/lichess.js'), js);
const counts = {};
for (const p of list) for (const t of p.themes) counts[t] = (counts[t] || 0) + 1;
console.error(`寫入 ${list.length} 題`, JSON.stringify(counts));
