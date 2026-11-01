// 驗證一個候選題（gen_tactics.mjs 與 hand_tactics.mjs 共用）
import { Chess } from '../../games/chess/vendor/chessjs/chess.js';
import { cpOf } from './uci.mjs';
import { materialOf } from './themes.mjs';

// ── 3. 驗證並延伸解答 ──
export const DEEP = +(process.env.DEEP || 16);
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

export async function verify(e, c) {
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

