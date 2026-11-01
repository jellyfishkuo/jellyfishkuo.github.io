// 產生戰術題庫 games/chess/data/tactics.js
//
// 原本想用 Lichess 公開題庫（CC0），但這個開發環境連不到 database.lichess.org，
// 所以改成自己用 Stockfish 出題（跟 Lichess 出題器同一套想法）：
//   1. 自我對弈：Stockfish 開低 Skill Level 下棋，約 1/3 的步數改走淺層搜尋的第 2～6 名（像人類會犯的錯）；
//      開局前幾步從前 4 名隨機挑，讓局面多樣。
//   2. 初篩：每個局面用 depth 10、MultiPV 2 看「最好的一步」和「第二好的一步」差多少。
//      對手剛走完、輪到我方時，只有一步能贏很多（差距 ≥ 2.5 兵）→ 候選題。
//      只有一步不會輸（其他都輸 ≥ 3 兵）→ 防守題候選。
//   3. 驗證：depth 16～18 重新算每一步，每一步解答都要是「唯一好棋」才往下延伸，
//      最多 4 步；最後一定停在我方的走法，而且要真的拿到子力（或將死），沒兌現的丟掉。
//   4. 判斷題型：照棋盤上的事實判斷（雙重攻擊、牽制、串擊、閃擊、引離、消除保護者、殺王、防守）。
//   5. 產生中文解析：每一步做了什麼（將軍、吃什麼、同時攻擊誰…），最後淨賺多少。
//
// 用法：node gen_tactics.mjs [對局數=600] [平行引擎數=4]
// 中間結果放在 out/（.gitignore 已排除），可以重跑：已經跑過的對局不會重跑（用 seed 決定）。
import fs from 'node:fs';
import path from 'node:path';
import { Engine, cpOf, ROOT } from './uci.mjs';
import { Chess } from '../../games/chess/vendor/chessjs/chess.js';
import { classify, explain, materialOf, THEME_ORDER } from './themes.mjs';

const GAMES = +(process.argv[2] || 600);
const WORKERS = +(process.argv[3] || 4);
const OUT = path.join(path.dirname(new URL(import.meta.url).pathname), 'out');
fs.mkdirSync(OUT, { recursive: true });

function rng(seed) { let s = seed >>> 0 || 1; return () => { s ^= s << 13; s >>>= 0; s ^= s >> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; }; }
const uciOf = m => m.from + m.to + (m.promotion || '');

// ── 1+2. 自我對弈＋初篩 ──
async function playGame(e, seed) {
  const R = rng(seed * 7919 + 13);
  const ch = new Chess();
  const skill = 1 + Math.floor(R() * 9);        // 1..9
  const cand = [];
  let prevEval = null;                           // 上一個局面「輪到走的一方」的評估
  let prevFen = null, prevMove = null;
  for (let ply = 0; ply < 140 && !ch.isGameOver(); ply++) {
    const fen = ch.fen();
    // 初篩：這個局面（輪到走的一方）
    const a = await e.analyse(fen, { depth: 9, multipv: 2 });
    const l1 = a.lines[0], l2 = a.lines[1];
    if (l1 && ply >= 8 && prevMove) {
      const best = cpOf(l1.score), second = l2 ? cpOf(l2.score) : -99999;
      const before = prevEval === null ? 0 : -prevEval;   // 換成同一方的觀點
      if (l2 && best >= 250 && best - second >= 250 && second < 200 && before < 150)
        cand.push({ kind: 'attack', fen: prevFen, last: prevMove });
      else if (l2 && best > -150 && best < 200 && second <= -300 && before > -150)
        cand.push({ kind: 'defense', fen: prevFen, last: prevMove });
    }
    prevEval = l1 ? cpOf(l1.score) : 0;
    // 下一步：開局前 6 步從前 4 名隨機挑，之後用低 Skill Level
    let mv;
    if (ply < 6) {
      const r = await e.analyse(fen, { depth: 6, multipv: 4 });
      const opts = r.lines.map(l => l.pv[0]);
      mv = opts[Math.floor(R() * opts.length)];
    } else if (R() < 0.35) {
      // 偶爾走一步「看起來合理、其實不好」的棋（深度 5 的第 2～6 名），製造戰術機會
      const r = await e.analyse(fen, { depth: 5, multipv: 6 });
      const opts = r.lines.slice(1).map(l => l.pv[0]);
      mv = opts.length ? opts[Math.floor(R() * opts.length)] : r.best;
    } else {
      e.send(`setoption name Skill Level value ${skill}`);
      const r = await e.analyse(fen, { depth: 7, multipv: 1 });
      e.send('setoption name Skill Level value 20');
      mv = r.best;
    }
    prevFen = fen; prevMove = mv;
    ch.move({ from: mv.slice(0, 2), to: mv.slice(2, 4), promotion: mv[4] });
  }
  return cand;
}

// ── 3. 驗證並延伸解答 ──
const DEEP = +(process.env.DEEP || 16);
function unique(lines, first) {
  const l1 = lines[0], l2 = lines[1];
  if (!l1) return false;
  const b = cpOf(l1.score);
  if (l1.score.mate !== undefined && l1.score.mate > 0) {
    // 殺棋：其他走法不能也殺（最後一步殺王時另外處理：任何殺王的走法都算對）
    return !l2 || !(l2.score.mate !== undefined && l2.score.mate > 0);
  }
  if (!l2) return b >= 200;
  const s = cpOf(l2.score);
  return first ? (b >= 200 && b - s >= 200 && s < 200) : (b - s >= 200 && s < 300);
}

async function verify(e, c) {
  const ch = new Chess(c.fen);
  try { ch.move({ from: c.last.slice(0, 2), to: c.last.slice(2, 4), promotion: c.last[4] }); } catch { return null; }
  const solver = ch.turn();
  const startMat = materialOf(ch, solver);
  const moves = [c.last];
  const startFen = ch.fen();
  let found = null, startEval = null, finalEval = null, pre = null;
  for (let step = 0; step < 4; step++) {
    const a = pre || await e.analyse(ch.fen(), { depth: DEEP, multipv: 2 });
    pre = null;
    const l1 = a.lines[0], l2 = a.lines[1];
    if (!l1) break;
    if (step === 0) startEval = l1.score;
    if (c.kind === 'defense') {
      if (step > 0) break;
      const b = cpOf(l1.score), s = l2 ? cpOf(l2.score) : -99999;
      if (!(l2 && b > -150 && s <= b - 300)) return null;
    } else if (!unique(a.lines, step === 0)) break;
    const mv = l1.pv[0];
    const m = ch.move({ from: mv.slice(0, 2), to: mv.slice(2, 4), promotion: mv[4] });
    moves.push(mv);
    found = { fen: ch.fen() };
    finalEval = l1.score;
    if (ch.isGameOver()) break;
    if (c.kind === 'defense') break;
    // 對手的最佳回應
    const r = await e.analyse(ch.fen(), { depth: DEEP, multipv: 1 });
    const reply = r.best;
    if (!reply || reply === '(none)') break;
    // 先試著接上對手回應與下一步；下一步不是唯一好棋就把對手這步拿掉
    const save = ch.fen();
    ch.move({ from: reply.slice(0, 2), to: reply.slice(2, 4), promotion: reply[4] });
    const a2 = await e.analyse(ch.fen(), { depth: DEEP, multipv: 2 });
    if (!unique(a2.lines, false) || moves.length >= 8) { ch.load(save); break; }
    // 已經兌現（多 ≥2 兵的子力）而且下一步不是將死相關，就停在這裡比較乾淨
    const gained = materialOf(new Chess(save), solver) - startMat;
    if (gained >= 2 && !(a2.lines[0].score.mate > 0)) { ch.load(save); break; }
    moves.push(reply);
    pre = a2;
  }
  if (moves.length < 2) return null;
  // 必須停在我方的走法
  if (moves.length % 2 === 1) moves.pop();
  const end = new Chess(startFen);
  for (const mv of moves.slice(1)) end.move({ from: mv.slice(0, 2), to: mv.slice(2, 4), promotion: mv[4] });
  const mate = end.isCheckmate();
  const gain = materialOf(end, solver) - startMat;
  if (c.kind === 'attack' && !mate) {
    // 沒兌現的不要：我方最後一步之後，對手最好的回應也救不回（用引擎看最後局面，評估要 ≥ +2）
    const z = await e.analyse(end.fen(), { depth: 14, multipv: 1 });
    const ev = z.lines[0] ? -cpOf(z.lines[0].score) : 0;
    if (gain < 2 && ev < 300) return null;
    if (ev < 200) return null;
    finalEval = z.lines[0] ? { ...z.lines[0].score, pov: 'opp' } : finalEval;
  }
  return { kind: c.kind, fen: c.fen, moves, mate, gain, startEval, finalEval };
}

// ── 平行跑 ──
async function pool(items, fn) {
  const engines = await Promise.all(Array.from({ length: WORKERS }, () => new Engine().init({ Hash: 32 })));
  let i = 0; const res = [];
  await Promise.all(engines.map(async e => {
    while (i < items.length) { const k = i++; res[k] = await fn(e, items[k], k); }
    e.quit();
  }));
  return res;
}

const candFile = path.join(OUT, 'candidates.json');
let cands = fs.existsSync(candFile) ? JSON.parse(fs.readFileSync(candFile)) : {};
const todo = [];
for (let g = 1; g <= GAMES; g++) if (!cands[g]) todo.push(g);
console.log(`self-play: ${todo.length} games to play`);
let done = 0;
await pool(todo, async (e, g) => {
  await e.newGame();
  cands[g] = await playGame(e, g);
  if (++done % 10 === 0) { fs.writeFileSync(candFile, JSON.stringify(cands)); console.log(`  games ${done}/${todo.length}`); }
});
fs.writeFileSync(candFile, JSON.stringify(cands));

// 去重（同一局面只留一次）
const seen = new Set(); const list = [];
for (const g of Object.keys(cands).sort((a, b) => a - b)) for (const c of cands[g]) {
  const k = c.fen.split(' ').slice(0, 4).join(' ') + c.last;
  if (!seen.has(k)) { seen.add(k); list.push(c); }
}
console.log(`candidates: ${list.length} (attack ${list.filter(c => c.kind === 'attack').length}, defense ${list.filter(c => c.kind === 'defense').length})`);

const verFile = path.join(OUT, 'verified.json');
let ver = fs.existsSync(verFile) ? JSON.parse(fs.readFileSync(verFile)) : {};
// 防守題候選很多，驗證前 200 個就夠
const defense = list.filter(c => c.kind === 'defense').slice(0, 200);
const vtodo = [...list.filter(c => c.kind === 'attack'), ...defense].filter(c => !(c.fen + c.last in ver));
console.log(`verify: ${vtodo.length} to check`);
done = 0;
await pool(vtodo, async (e, c) => {
  try { ver[c.fen + c.last] = await verify(e, c); } catch (err) { console.log('verify error', err.message); ver[c.fen + c.last] = null; }
  if (++done % 20 === 0) { fs.writeFileSync(verFile, JSON.stringify(ver)); console.log(`  verified ${done}/${vtodo.length}`); }
});
fs.writeFileSync(verFile, JSON.stringify(ver));

// ── 4+5. 題型＋解析，寫出題庫 ──
const puzzles = [];
for (const v of Object.values(ver)) {
  if (!v) continue;
  const themes = classify(v);
  if (!themes.length) continue;
  puzzles.push({ ...v, themes });
}
// 每個題型最多 45 題，挑解答步數多一點、評估差距大的，難度平均分布
const byTheme = {};
for (const t of THEME_ORDER) byTheme[t] = [];
for (const p of puzzles) for (const t of p.themes) byTheme[t].push(p);
const chosen = new Map();
for (const t of THEME_ORDER) {
  const arr = byTheme[t].filter(p => !chosen.has(p.fen + p.moves[0]));
  arr.sort((a, b) => b.moves.length - a.moves.length || a.fen.localeCompare(b.fen));
  const already = [...chosen.values()].filter(p => p.themes.includes(t)).length;
  for (const p of arr.slice(0, Math.max(0, 45 - already))) chosen.set(p.fen + p.moves[0], p);
}
const outList = [...chosen.values()].map((p, i) => {
  const solverMoves = p.moves.length / 2;
  const level = p.mate ? Math.min(3, solverMoves) : Math.min(3, solverMoves + (p.kind === 'defense' ? 1 : 0));
  return {
    id: 'jc' + String(i + 1).padStart(4, '0'),
    fen: p.fen, moves: p.moves.join(' '), themes: p.themes, level,
    ...explain(p),
  };
});
const js = `// 由 tools/chess/gen_tactics.mjs 產生，不要手改。每一題都經 Stockfish 18（depth 16 以上）驗證：
// fen 是對手走之前的局面；moves 第一步是對手的走法，之後輪流是「你」與對手，你的每一步都是唯一好棋。
// 最後一步若是將死，任何能將死的走法都算對。
export const PUZZLES = ${JSON.stringify(outList, null, 0).replace(/\},\{/g, '},\n{')};
`;
fs.writeFileSync(path.join(ROOT, 'games/chess/data/tactics.js'), js);
const counts = {};
for (const p of outList) for (const t of p.themes) counts[t] = (counts[t] || 0) + 1;
console.log('written', outList.length, 'puzzles', counts);
