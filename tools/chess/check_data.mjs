// 檢查手寫的開局、殘局資料：每條棋譜都要合法；戰術／錯誤的結論（eval 欄位）用 Stockfish 看最後局面確認；
// 殘局練習的起始局面用 Stockfish 確認目標做得到（要贏的局面要是勝勢，要守和的局面要是均勢）。
// 用法：node check_data.mjs     （有任何錯誤就以非 0 結束）
import { Chess } from '../../games/chess/vendor/chessjs/chess.js';
import { OPENINGS } from '../../games/chess/data/openings.js';
import { ENDGAMES } from '../../games/chess/data/endgames.js';
import { PUZZLES as OWN } from '../../games/chess/data/tactics.js';
import { LICHESS } from '../../games/chess/data/lichess.js';
const PUZZLES = [...OWN, ...LICHESS];
import { Engine, cpOf } from './uci.mjs';

let bad = 0;
const fail = msg => { bad++; console.log('✗', msg); };
function play(line, label) {
  const g = new Chess();
  try { g.loadPgn(line); } catch (e) { fail(`${label}: 不合法 — ${e.message}`); return null; }
  return g;
}

const e = await new Engine().init({ Hash: 64 });
async function whiteEval(fen) {
  const g = new Chess(fen);
  if (g.isCheckmate()) return g.turn() === 'w' ? -100000 : 100000;
  if (g.isDraw()) return 0;
  const a = await e.analyse(fen, { depth: 18 });
  const s = cpOf(a.lines[0].score);
  return g.turn() === 'w' ? s : -s;
}
// chess.js 不會檢查「不輪到走的一方被將軍」這種不合法局面，自己檢查
function legalFen(g) {
  const other = g.turn() === 'w' ? 'b' : 'w';
  for (const row of g.board()) for (const p of row) if (p && p.type === 'k' && p.color === other) return !g.isAttacked(p.square, g.turn());
  return false;
}
// 'w'：白方較好（≥ +0.7）、'b'：黑方較好（≤ -0.7）、'='：沒有決定性優勢（±1.5 以內）
const agrees = (cp, claim) => (claim === 'w' ? cp >= 70 : claim === 'b' ? cp <= -70 : Math.abs(cp) <= 150);
const dir = cp => (cp >= 150 ? 'w' : cp <= -150 ? 'b' : '=');

// ── 開局 ──
const ids = new Set();
for (const o of OPENINGS) {
  if (ids.has(o.id)) fail(`重複的 id ${o.id}`); ids.add(o.id);
  for (const k of ['name', 'en', 'eco', 'main', 'purpose', 'lines', 'tactics', 'mistakes']) if (!o[k]) fail(`${o.id} 缺 ${k}`);
  const g = play(o.main, `${o.id} 主線`);
  if (g) {
    const n = g.history().length;
    for (const k of Object.keys(o.notes || {})) if (+k < 1 || +k > n) fail(`${o.id} notes ${k} 超過主線長度 ${n}`);
    const ev = await whiteEval(g.fen());
    console.log(`  ${o.id} 主線 ${n} 步，最後局面 ${(ev / 100).toFixed(2)}`);
    if (Math.abs(ev) > 120) fail(`${o.id} 主線最後局面不是均勢（${ev}）`);
  }
  for (const l of o.lines) {
    const g2 = play(l.moves, `${o.id} 變化 ${l.name}`);
    if (g2) { const ev = await whiteEval(g2.fen()); console.log(`  ${o.id} ${l.name}: ${(ev / 100).toFixed(2)}`); if (Math.abs(ev) > 150) fail(`${o.id} ${l.name} 不是正常的開局局面（${ev}）`); }
  }
  for (const t of [...o.tactics, ...o.mistakes]) {
    const g3 = play(t.line, `${o.id} ${t.title}`);
    if (!g3) continue;
    const ev = await whiteEval(g3.fen());
    const d = dir(ev);
    console.log(`  ${o.id} 「${t.title}」 ${(ev / 100).toFixed(2)} → ${d}（寫的是 ${t.eval}）`);
    if (!agrees(ev, t.eval)) fail(`${o.id}「${t.title}」評估方向不符：引擎 ${ev}，資料寫 ${t.eval}`);
  }
}

// ── 殘局 ──
for (const c of ENDGAMES) for (const x of c.items) {
  let g;
  try { g = new Chess(x.fen); } catch (err) { fail(`殘局 ${x.id} FEN 不合法：${err.message}`); continue; }
  if (!legalFen(g)) fail(`殘局 ${x.id}：不輪到走的一方正被將軍（不合法局面）`);
  const ev = await whiteEval(x.fen);
  const mine = x.side === 'w' ? ev : -ev;
  console.log(`  殘局 ${x.id}（${x.goal}）：使用者觀點 ${(mine / 100).toFixed(2)}`);
  if ((x.goal === 'mate' || x.goal === 'promote' || x.goal === 'win') && mine < 300) fail(`殘局 ${x.id} 應該是勝勢，引擎 ${mine}`);
  if (x.goal === 'draw' && Math.abs(mine) > 80) fail(`殘局 ${x.id} 應該是和棋，引擎 ${mine}`);
}

// ── 戰術題：每一步都合法、題型有說明 ──
for (const p of PUZZLES) {
  const g = new Chess(p.fen);
  for (const u of p.moves.split(' ')) { try { g.move({ from: u.slice(0, 2), to: u.slice(2, 4), promotion: u[4] }); } catch (err) { fail(`題目 ${p.id} 走法 ${u} 不合法`); break; } }
  if (p.moves.split(' ').length % 2) fail(`題目 ${p.id} 沒有停在解題方`);
}
console.log(`戰術題 ${PUZZLES.length} 題檢查完`);
e.quit();
console.log(bad ? `共 ${bad} 個問題` : '全部通過');
process.exit(bad ? 1 : 0);
