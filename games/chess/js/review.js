// 分析的共用部分：失誤分級、逐步評估一盤棋。分析頁和「對完自動復盤」都用這裡。
import { Chess } from '../vendor/chessjs/chess.js';
import { whitePov, winChance } from './engine.js';

// 勝率掉多少算哪一級（Lichess 的門檻：勝率差 30%/20%/10%，這裡勝率是 0～1，所以除以 2）
export const CLS = [
  { key: 'blunder', min: 0.15, label: '??', name: 'Blunder 大錯' },
  { key: 'mistake', min: 0.10, label: '?', name: 'Mistake 錯誤' },
  { key: 'inaccuracy', min: 0.05, label: '?!', name: 'Inaccuracy 不精確' },
];
export function classify(before, after, mover, bestUci, playedUci) {
  // before/after：白方觀點的分數。mover：走這步的一方
  if (bestUci && bestUci === playedUci) return { key: 'best', label: '★', name: '最佳走法' };
  const k = mover === 'w' ? 1 : -1;
  const wb = mover === 'w' ? winChance(before) : 1 - winChance(before);
  const wa = mover === 'w' ? winChance(after) : 1 - winChance(after);
  const drop = wb - wa;
  // 走完還是明顯領先（≥ +3 或可以將死）就不算失誤：引擎深度不夠時常把「棄子殺棋」看成丟子
  const afterMine = after.mate !== undefined ? (after.mate * k > 0 ? 99999 : -99999) : after.cp * k;
  if (afterMine >= 300) return null;
  for (const c of CLS) if (drop >= c.min) return { ...c, drop };
  return null;
}
export function terminalScore(c) {
  if (c.isCheckmate()) return { white: c.turn() === 'w' ? { cp: -100000 } : { cp: 100000 } };
  if (c.isStalemate() || c.isInsufficientMaterial() || c.isDrawByFiftyMoves()) return { white: { cp: 0 } };
  return null;
}
/** 一盤棋從頭到尾的局面與棋步（給 evaluateGame 用） */
export function gameLine(g) {
  const h = g.history({ verbose: true });
  const start = h.length ? h[0].before : g.fen();
  const c = new Chess(start);
  const fens = [c.fen()], moves = [];
  for (const m of h) { const mv = c.move(m.san); moves.push({ san: mv.san, uci: mv.from + mv.to + (mv.promotion || ''), color: mv.color }); fens.push(c.fen()); }
  return { start, fens, moves };
}
/**
 * 逐步評估：evals[i] = { score（白方觀點）, best, pv, depth }。alive() 回傳 false 就停下來（回傳 null）。
 * 標成 Mistake／Blunder 的步再用深度 +6 複查一次。
 */
export async function evaluateGame(engine, fens, moves, { depth = 12, evals = [], alive = () => true, onProgress } = {}) {
  for (let i = 0; i < fens.length; i++) {
    if (!alive()) return null;
    if (evals[i] && evals[i].depth >= depth) continue;
    const c = new Chess(fens[i]);
    const t = terminalScore(c);
    if (t) evals[i] = { score: t.white, best: null, pv: [], depth: 99 };
    else {
      const r = await engine.go({ fen: fens[i], depth, multipv: 1, skill: 20 });
      if (!alive()) return null;
      const l = r.lines[0];
      evals[i] = { score: whitePov(l ? l.score : { cp: 0 }, c.turn()), best: r.best, pv: l ? l.pv : [], depth: l ? l.depth : depth };
    }
    if (onProgress) onProgress(i + 1, fens.length, 'eval');
  }
  const deep = depth + 6;
  const suspects = moves.map((m, i) => { const c = classify(evals[i].score, evals[i + 1].score, m.color, evals[i].best, m.uci); return c && (c.key === 'blunder' || c.key === 'mistake') ? i : -1; }).filter(i => i >= 0);
  let k = 0;
  for (const i of suspects) for (const j of [i, i + 1]) {
    if (!alive()) return null;
    if (evals[j].depth >= deep || terminalScore(new Chess(fens[j]))) continue;
    if (onProgress) onProgress(++k, suspects.length * 2, 'recheck');
    const r = await engine.go({ fen: fens[j], depth: deep, multipv: 1, skill: 20 });
    if (!alive()) return null;
    const l = r.lines[0];
    if (l) evals[j] = { score: whitePov(l.score, new Chess(fens[j]).turn()), best: r.best, pv: l.pv, depth: l.depth };
  }
  return evals;
}
/** 某一方每一步的分級與勝率損失 */
export function reviewSide(fens, moves, evals, color) {
  const out = [];
  moves.forEach((m, i) => {
    if (m.color !== color || !evals[i] || !evals[i + 1]) return;
    const c = classify(evals[i].score, evals[i + 1].score, m.color, evals[i].best, m.uci);
    const wb = color === 'w' ? winChance(evals[i].score) : 1 - winChance(evals[i].score);
    const wa = color === 'w' ? winChance(evals[i + 1].score) : 1 - winChance(evals[i + 1].score);
    let best = null;
    if (evals[i].best) { const g = new Chess(fens[i]); try { best = g.move({ from: evals[i].best.slice(0, 2), to: evals[i].best.slice(2, 4), promotion: evals[i].best[4] }).san; } catch (e) { best = null; } }
    out.push({ ply: i + 1, san: m.san, best, cls: c ? c.key : null, name: c ? c.name : null, drop: Math.max(0, wb - wa) });
  });
  return out;
}
