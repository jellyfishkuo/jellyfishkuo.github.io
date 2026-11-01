// 殘局練習：直接在指定局面跟 Stockfish（全力）下，看自己能不能達成目標。
// 目標：mate（將死）、promote（安全升變）、win（贏下來）、draw（守和）。
import { Chess } from '../vendor/chessjs/chess.js';
import { ENDGAMES } from '../data/endgames.js';
import { whitePov, fmtScore } from './engine.js';
import { db, uid } from './store.js';
import { el, renderMoves, applyUci, uciList } from './ui.js';

const GOAL = { mate: '將死對方', promote: '把兵安全升變', win: '贏下來', draw: '守成和棋' };
const S = { item: null, g: null, tok: 0, thinking: false, result: null, myMoves: 0, lastScore: null };
let app, ui = {};
const all = () => ENDGAMES.flatMap(c => c.items.map(x => ({ ...x, cat: c })));

function select(item) {
  S.tok++; app.engine.stop();
  S.item = item; S.g = new Chess(item.fen); S.result = null; S.myMoves = 0; S.thinking = false; S.lastScore = null;
  app.board.setFlipped(item.side === 'b');
  app.setGame(S.g); app.board.setLast(null); app.board.setArrows([]);
  renderList(); renderItem(); sync();
  if (S.g.turn() !== item.side) engineMove();
}

function sync() {
  app.setGame(S.g);
  const me = S.item.side;
  app.players({ white: me === 'w' ? '你' : 'Stockfish', black: me === 'b' ? '你' : 'Stockfish', caps: false });
  const st = ui.status; st.className = 'status'; st.innerHTML = '';
  if (S.result) { st.classList.add(S.result.ok ? 'good' : 'bad'); st.textContent = S.result.text; }
  else if (S.thinking) st.append(el('span', { class: 'spinner' }), 'Stockfish 思考中…');
  else st.textContent = `目標：${GOAL[S.item.goal]}。輪到你（${me === 'w' ? '白' : '黑'}）` + (S.item.limit ? `，還有 ${Math.max(0, S.item.limit - S.myMoves)} 步` : '');
  renderMoves(ui.moves, S.g.history(), S.g.history().length, () => {}, { startTurn: new Chess(S.item.fen).turn(), startNo: new Chess(S.item.fen).moveNumber() });
  ui.undo.disabled = !S.g.history().length || S.thinking;
}

function judge(engineScoreMine) {
  // engineScoreMine：使用者觀點的分數（引擎剛算完）
  const it = S.item, g = S.g, me = it.side;
  if (g.isCheckmate()) {
    const iWon = g.turn() !== me;
    return iWon ? { ok: true, text: '將死！' + (it.goal === 'draw' ? '你不只守和還贏了 🎉' : '目標達成 🎉') } : { ok: false, text: '被將死了。按「重來」再試一次。' };
  }
  if (g.isDraw()) {
    const why = g.isStalemate() ? '逼和（對方無子可動、但沒被將軍）' : g.isInsufficientMaterial() ? '子力不足' : g.isThreefoldRepetition() ? '三次重複局面' : '50 步規則';
    return it.goal === 'draw' ? { ok: true, text: `和棋（${why}）——守和成功 🎉` } : { ok: false, text: `和棋了（${why}）。${it.goal === 'mate' ? '小心別把對方逼和！' : ''}再試一次。` };
  }
  if (it.goal === 'promote') {
    const q = g.history({ verbose: true }).some(m => m.color === me && m.promotion);
    if (q && engineScoreMine !== null && engineScoreMine >= 500) return { ok: true, text: '成功升變，而且保住了勝勢 🎉' };
  }
  if (engineScoreMine !== null) {
    if (it.goal === 'draw' && engineScoreMine <= -400) return { ok: false, text: `引擎評估 ${fmtScore({ cp: -engineScoreMine })}（對手觀點）：這個局面已經守不住了。按「悔棋」找找看哪一步出錯。` };
    if (it.goal !== 'draw' && engineScoreMine < 150) return { ok: false, text: '優勢不見了（引擎認為已經贏不了）。按「悔棋」再試。' };
  }
  if (it.goal === 'draw' && it.limit && S.myMoves >= it.limit) return { ok: true, text: `撐過 ${it.limit} 步、局面仍然是和棋——守和成功 🎉` };
  if (it.goal !== 'draw' && it.limit && S.myMoves >= it.limit) return { ok: false, text: `超過 ${it.limit} 步還沒完成目標。試試更有效率的走法。` };
  return null;
}

async function engineMove() {
  const tok = ++S.tok;
  S.thinking = true; sync();
  const r = await app.engine.go({ fen: S.item.fen, moves: uciList(S.g), movetime: 600, skill: 20 });
  if (tok !== S.tok) return;
  S.thinking = false;
  let mine = null;
  if (r.lines[0]) { const w = whitePov(r.lines[0].score, S.g.turn()); mine = (S.item.side === 'w' ? 1 : -1) * (w.mate !== undefined ? (w.mate > 0 ? 100000 : -100000) : w.cp); }
  if (r.best) { const m = applyUci(S.g, r.best); app.board.setLast(m, { animate: true }); }
  S.result = judge(mine);
  if (S.result) record();
  sync(); app.board.render();
}

async function record() {
  try { await db.put('attempts', { id: uid('e'), kind: 'endgame', ref: S.item.id, date: new Date().toISOString(), ok: S.result.ok, moves: S.myMoves }); } catch (e) { /* ignore */ }
  renderList();
}

function onMove(m) {
  if (S.thinking || S.result || S.g.turn() !== S.item.side) return false;
  try { S.g.move(m); } catch (e) { return false; }
  S.myMoves++;
  app.board.setLast(S.g.history({ verbose: true }).slice(-1)[0]);
  S.result = judge(null);
  if (S.result) { record(); sync(); return true; }
  sync();
  engineMove();
  return true;
}

function undo() {
  S.tok++; app.engine.stop(); S.thinking = false; S.result = null;
  S.g.undo();
  if (S.g.turn() !== S.item.side && S.g.history().length) S.g.undo();
  S.myMoves = Math.max(0, S.myMoves - 1);
  app.board.setLast(S.g.history({ verbose: true }).slice(-1)[0] || null);
  sync(); app.board.render();
  if (S.g.turn() !== S.item.side) engineMove();
}

function renderList() {
  ui.list.innerHTML = '';
  for (const c of ENDGAMES) {
    ui.list.append(el('h3', {}, c.name));
    const box = el('div', { class: 'list' });
    for (const x of c.items) {
      box.append(el('button', { type: 'button', class: 'item' + (S.item && S.item.id === x.id ? ' on' : ''), 'data-eg': x.id, onclick: () => select({ ...x, cat: c }) },
        el('div', { class: 'grow' }, el('b', {}, x.title), el('span', {}, `你執${x.side === 'w' ? '白' : '黑'}・目標：${GOAL[x.goal]}`))));
    }
    ui.list.append(box);
  }
}
function renderItem() {
  const it = S.item, c = it.cat;
  ui.info.innerHTML = '';
  ui.info.append(el('h2', {}, it.title, ' ', el('small', {}, c.en)),
    el('p', { class: 'small' }, it.text));
  if (c.idea) ui.info.append(el('p', { class: 'small muted', style: 'margin-top:6px' }, c.idea));
  if (it.steps && it.steps.length) {
    const ol = el('ol', { class: 'small', style: 'margin-top:6px' });
    for (const s of it.steps) ol.append(el('li', {}, s));
    ui.info.append(el('details', { class: 'more', style: 'margin-top:6px' }, el('summary', {}, '技巧（卡住再打開）'), ol));
  }
}

export default {
  id: 'endgames', title: '殘局',
  mount(a, params) {
    app = a;
    ui.status = el('div', { class: 'status', id: 'eg-status' });
    ui.moves = el('div', { class: 'moves', id: 'eg-moves' });
    ui.info = el('div', { class: 'prose' });
    ui.list = el('div', { id: 'eg-list' });
    ui.undo = el('button', { type: 'button', class: 'btn', id: 'eg-undo', onclick: undo }, '↶ 悔棋');
    app.panel.append(
      el('div', { class: 'card' }, ui.info),
      el('div', { class: 'card' }, ui.status,
        el('div', { class: 'row', style: 'margin:10px 0' }, ui.undo,
          el('button', { type: 'button', class: 'btn', id: 'eg-reset', onclick: () => select(S.item) }, '↺ 重來'),
          el('button', { type: 'button', class: 'btn sm', onclick: () => app.go('analysis', { pgn: S.g.fen() }) }, '用引擎看這個局面')),
        ui.moves),
      el('div', { class: 'card' }, el('h2', {}, '殘局練習 ', el('small', {}, '對手是 Stockfish 全力')), ui.list),
    );
    app.tools.append(el('button', { type: 'button', class: 'btn icon', title: '翻轉棋盤', 'aria-label': '翻轉棋盤', onclick: () => app.board.flip() }, '⇅ 翻轉'));
    app.use({ canMove: c => !!S.item && c === S.item.side && !S.thinking && !S.result, onMove });
    const want = params.id && all().find(x => x.id === params.id);
    if (want) select(want);
    else if (S.item) { select(S.item); }
    else select(all()[0]);
  },
  unmount() { S.tok++; app.engine.stop(); },
};
