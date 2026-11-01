// 各模組共用的小工具（棋譜表、建立 DOM、下載、複製…）
import { Chess } from '../vendor/chessjs/chess.js';

// 各方吃掉的子＋子力差
const VAL = { p: 1, n: 3, b: 3, r: 5, q: 9 };
export function capturedBy(g) {
  const start = { p: 8, n: 2, b: 2, r: 2, q: 1 };
  const have = { w: { p: 0, n: 0, b: 0, r: 0, q: 0 }, b: { p: 0, n: 0, b: 0, r: 0, q: 0 } };
  for (const row of g.board()) for (const p of row) if (p && p.type !== 'k') have[p.color][p.type]++;
  const out = { w: { list: [], adv: 0 }, b: { list: [], adv: 0 } };
  let mat = { w: 0, b: 0 };
  for (const c of ['w', 'b']) for (const t of ['q', 'r', 'b', 'n', 'p']) {
    mat[c] += have[c][t] * VAL[t];
    const lost = Math.max(0, start[t] - have[c][t]);
    for (let i = 0; i < lost; i++) out[c === 'w' ? 'b' : 'w'].list.push(t);
  }
  out.w.adv = mat.w - mat.b; out.b.adv = mat.b - mat.w;
  return out;
}

/** 棋譜表：sans = SAN 陣列，cur = 目前看到第幾步（0 = 開局），startNo/startTurn 從 FEN 開始時用 */
export function renderMoves(el, sans, cur, onPick, { startTurn = 'w', startNo = 1, tags = [] } = {}) {
  el.innerHTML = '';
  if (!sans.length) { const e = document.createElement('div'); e.className = 'empty'; e.textContent = '還沒有走任何一步'; el.appendChild(e); return; }
  let no = startNo, i = 0;
  const addNo = () => { const d = document.createElement('div'); d.className = 'no'; d.textContent = no + '.'; el.appendChild(d); };
  if (startTurn === 'b') { addNo(); const d = document.createElement('div'); d.className = 'mv'; d.textContent = '…'; el.appendChild(d); }
  for (; i < sans.length; i++) {
    const white = (startTurn === 'w') === (i % 2 === 0);
    if (white) addNo();
    const b = document.createElement('button');
    b.type = 'button'; b.className = 'mv' + (cur === i + 1 ? ' cur' : '');
    b.dataset.ply = i + 1;
    const s = document.createElement('span'); s.textContent = sans[i]; b.appendChild(s);
    if (tags[i]) { const t = document.createElement('span'); t.className = 'tag ' + tags[i].cls; t.textContent = tags[i].label; t.title = tags[i].title || ''; b.appendChild(t); }
    const ply = i + 1;
    b.onclick = () => onPick(ply);
    el.appendChild(b);
    if (!white) no++;
  }
  const c = el.querySelector('.mv.cur');
  if (c) { const top = c.offsetTop - el.clientHeight / 2; el.scrollTo({ top: Math.max(0, top) }); }
}

export function el(tag, attrs = {}, ...kids) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v === undefined || v === null || v === false) continue;
    if (k === 'class') e.className = v;
    else if (k === 'text') e.textContent = v;
    else if (k.startsWith('on')) e.addEventListener(k.slice(2), v);
    else if (k === 'html') e.innerHTML = v;     // 只用在固定字串，不放使用者輸入
    else e.setAttribute(k, v === true ? '' : v);
  }
  for (const k of kids.flat()) if (k !== null && k !== undefined && k !== false) e.append(k.nodeType ? k : document.createTextNode(String(k)));
  return e;
}
export function download(name, text, type = 'text/plain') {
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([text], { type: type + ';charset=utf-8' }));
  a.download = name; document.body.appendChild(a); a.click();
  setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
}
export async function copy(text) {
  try { await navigator.clipboard.writeText(text); return true; } catch (e) { return false; }
}
export function today() { const d = new Date(); return `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, '0')}.${String(d.getDate()).padStart(2, '0')}`; }
/** 把 chess.js 的局面轉成 uci 走法陣列 */
export const uciList = g => g.history({ verbose: true }).map(m => m.from + m.to + (m.promotion || ''));
/** 從 uci 套到局面上，不合法回傳 null */
export function applyUci(g, u) {
  try { return g.move({ from: u.slice(0, 2), to: u.slice(2, 4), promotion: u[4] }); } catch (e) { return null; }
}
/** 把 uci 主變化轉成 SAN 字串 */
export function pvToSan(fen, pv, max = 10) {
  const g = new Chess(fen); const out = [];
  for (const u of pv.slice(0, max)) {
    const no = g.moveNumber(), t = g.turn();
    const m = applyUci(g, u); if (!m) break;
    out.push((t === 'w' ? no + '. ' : (out.length === 0 ? no + '… ' : '')) + m.san);
  }
  return out.join(' ');
}


/** chess.js 不會擋「不輪到走的一方正被將軍」的局面（Stockfish 遇到會當掉），這裡補檢查。回傳錯誤訊息或 null */
export function fenProblem(fen) {
  let g;
  try { g = new Chess(fen); } catch (e) { return e.message.replace(/^Invalid FEN: /, ''); }
  const other = g.turn() === 'w' ? 'b' : 'w';
  for (const row of g.board()) for (const p of row)
    if (p && p.type === 'k' && p.color === other && g.isAttacked(p.square, g.turn())) return '不輪到走的一方正被將軍，這不是合法的局面';
  return null;
}
