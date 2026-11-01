// 開局研究：主線一步一步看（每步附說明）、主要變化、開局目的、典型戰術、常見錯誤、練習模式、收藏。
import { Chess } from '../vendor/chessjs/chess.js';
import { OPENINGS } from '../data/openings.js';
import { db } from './store.js';
import { el, renderMoves } from './ui.js';

const S = { shown: -1, userMoved: false, o: null, line: null, title: '', moves: [], ply: 0, notes: {}, favs: new Set(), drill: false, drillMiss: 0, tok: 0 };
let app, ui = {};

function sansOf(pgn) { const g = new Chess(); g.loadPgn(pgn); return g.history(); }
function posAt(n) { const g = new Chess(); for (const m of S.moves.slice(0, n)) g.move(m); return g; }

function selectOpening(o) {
  S.o = o; S.drill = false;
  app.board.setFlipped(o.side === 'b');
  showLine(o.main, `主線`, o.notes);
  renderList(); renderDetail();
}
function showLine(pgn, title, notes = {}, ply) {
  S.tok++;
  S.line = pgn; S.title = title; S.moves = sansOf(pgn); S.notes = notes;
  S.ply = ply === undefined ? S.moves.length : ply;
  render();
}
function go(n) { S.ply = Math.max(0, Math.min(S.moves.length, n)); render(); }

function render() {
  const g = posAt(S.ply);
  app.setGame(g);
  // 往前走一步時棋子用滑的（自己在棋盤上走的那步不用，已經在那裡了）
  const step = S.ply === S.shown + 1 && !S.userMoved;
  S.shown = S.ply; S.userMoved = false;
  app.board.setLast(g.history({ verbose: true }).slice(-1)[0] || null, { animate: step });
  app.board.setArrows([]);
  app.board.render();
  app.players({ white: '白方', black: '黑方' });
  ui.lineTitle.textContent = `${S.o.name}・${S.title}`;
  renderMoves(ui.moves, S.moves, S.ply, go);
  const note = S.notes[S.ply];
  ui.note.textContent = S.drill ? ui.note.textContent : (note || (S.ply === 0 ? '初始局面。按 ▶ 一步一步看。' : S.ply === S.moves.length ? '這條變化到這裡結束。' : ''));
  ui.note.style.visibility = (S.drill || ui.note.textContent) ? 'visible' : 'hidden';
}

// ── 練習模式：你下這個開局那一方的走法，電腦下另一方 ──
function startDrill() {
  S.drill = true; S.drillMiss = 0;
  S.moves = sansOf(S.o.main); S.notes = S.o.notes; S.title = '練習主線'; S.line = S.o.main;
  S.ply = 0;
  render();
  ui.note.textContent = `練習：你下${S.o.side === 'w' ? '白' : '黑'}方，照主線走。想一想每一步的目的！`;
  ui.note.style.visibility = 'visible';
  autoReply();
}
function autoReply() {
  const myTurnColor = S.o.side;
  const tok = S.tok;
  if (S.ply >= S.moves.length) {
    S.drill = false;
    ui.note.textContent = S.drillMiss ? `走完了！中間錯了 ${S.drillMiss} 次，再練一次看看。` : '完美！整條主線都走對了 🎉';
    return;
  }
  const turn = S.ply % 2 === 0 ? 'w' : 'b';
  if (turn !== myTurnColor) setTimeout(() => { if (tok !== S.tok || !S.drill) return; S.ply++; render(); if (S.notes[S.ply]) ui.note.textContent = S.notes[S.ply]; autoReply(); }, 450);
}
function onMove(m) {
  if (!S.drill) {
    // 一般模式：在棋盤上自由試走就切到「試走」
    const g = posAt(S.ply);
    let mv; try { mv = g.move(m); } catch (e) { return false; }
    S.userMoved = true;
    if (S.moves[S.ply] === mv.san) { go(S.ply + 1); return true; }
    S.moves = S.moves.slice(0, S.ply).concat(mv.san); S.ply++; S.title = '試走'; S.notes = {};
    render(); ui.note.textContent = '你在試走自己的變化。按主線或其他變化可以回去。'; ui.note.style.visibility = 'visible';
    return true;
  }
  const g = posAt(S.ply);
  let mv; try { mv = g.move(m); } catch (e) { return false; }
  if (mv.san !== S.moves[S.ply]) {
    S.drillMiss++;
    ui.note.textContent = `${mv.san} 不是主線的走法。提示：主線下一步動的是${{ p: '兵', n: '馬', b: '象', r: '車', q: '后', k: '王' }[posAt(S.ply).move(S.moves[S.ply]).piece]}。`;
    app.board.render();
    return false;
  }
  S.userMoved = true;
  S.ply++; render();
  ui.note.textContent = '✓ ' + (S.notes[S.ply] || '對了！');
  autoReply();
  return true;
}

function renderList() {
  ui.list.innerHTML = '';
  for (const o of OPENINGS) {
    ui.list.append(el('button', { type: 'button', class: 'item' + (S.o === o ? ' on' : ''), 'data-op': o.id, onclick: () => selectOpening(o) },
      el('div', { class: 'grow' }, el('b', {}, (S.favs.has(o.id) ? '★ ' : '') + o.name), el('span', {}, o.en)),
      el('span', { class: 'eco' }, o.eco)));
  }
}

function lineButton(text, pgn, title, extra) {
  return el('button', { type: 'button', class: 'item', onclick: () => { S.drill = false; showLine(pgn, title); } },
    el('div', { class: 'grow' }, el('b', {}, text), extra ? el('span', {}, extra) : null));
}

function renderDetail() {
  const o = S.o, d = ui.detail;
  d.innerHTML = '';
  const fav = el('button', { type: 'button', class: 'btn sm', id: 'op-fav', 'aria-pressed': String(S.favs.has(o.id)), onclick: async () => {
    if (S.favs.has(o.id)) { S.favs.delete(o.id); await db.del('favorites', 'opening:' + o.id).catch(() => {}); }
    else { S.favs.add(o.id); await db.put('favorites', { id: 'opening:' + o.id, kind: 'opening', ref: o.id, date: new Date().toISOString() }).catch(() => {}); }
    renderDetail(); renderList();
  } }, S.favs.has(o.id) ? '★ 已收藏' : '☆ 收藏');
  d.append(el('div', { class: 'card' },
    el('div', { class: 'row spread' }, el('h2', { style: 'margin:0' }, o.name), fav),
    el('p', { class: 'small muted' }, o.en, '　', el('span', { class: 'eco' }, 'ECO ' + o.eco), '　', `通常是${o.side === 'w' ? '白' : '黑'}方的選擇`),
    el('p', { class: 'small mono', style: 'margin-top:6px' }, o.main),
    el('div', { class: 'row', style: 'margin-top:8px' },
      el('button', { type: 'button', class: 'btn', onclick: () => { S.drill = false; showLine(o.main, '主線', o.notes, 0); } }, '▶ 從頭看主線'),
      el('button', { type: 'button', class: 'btn primary', id: 'op-drill', onclick: startDrill }, '練習主線'),
      el('button', { type: 'button', class: 'btn sm', onclick: () => app.go('play', { fen: app.game.fen() }) }, '從目前局面跟電腦下 →')),
  ));
  const purpose = el('ul'); for (const p of o.purpose) purpose.append(el('li', {}, p));
  d.append(el('div', { class: 'card prose' }, el('h2', {}, '開局目的'), purpose));
  const lines = el('div', { class: 'list' });
  lines.append(lineButton('主線', o.main, '主線', o.eco));
  for (const l of o.lines) {
    const b = lineButton(l.name, l.moves, l.name, `ECO ${l.eco}`);
    b.title = l.text;
    lines.append(b, el('p', { class: 'small muted', style: 'margin:-2px 4px 4px' }, l.text));
  }
  d.append(el('div', { class: 'card' }, el('h2', {}, '主要變化'), lines));
  const tac = el('div', { class: 'list' });
  for (const t of o.tactics) tac.append(lineButton(t.title, t.line, t.title), el('p', { class: 'small', style: 'margin:-2px 4px 6px' }, t.text));
  d.append(el('div', { class: 'card' }, el('h2', {}, '典型戰術'), tac));
  const mis = el('div', { class: 'list' });
  for (const t of o.mistakes) mis.append(lineButton('✗ ' + t.title, t.line, t.title), el('p', { class: 'small', style: 'margin:-2px 4px 6px' }, t.text));
  d.append(el('div', { class: 'card' }, el('h2', {}, '常見錯誤'), mis));
}

export default {
  id: 'openings', title: '開局',
  async mount(a, params) {
    app = a;
    ui.lineTitle = el('h2', { id: 'op-line', style: 'margin-bottom:4px' });
    ui.note = el('p', { class: 'small', id: 'op-note', style: 'min-height:4.8em' });
    ui.moves = el('div', { class: 'moves', id: 'op-moves' });
    ui.list = el('div', { class: 'list', id: 'op-list' });
    ui.detail = el('div', { class: 'panel', id: 'op-detail' });
    app.panel.append(
      el('div', { class: 'card' }, ui.lineTitle, ui.note, ui.moves),
      ui.detail,
      el('div', { class: 'card' }, el('h2', {}, '開局列表 ', el('small', {}, `${OPENINGS.length} 個`)), ui.list),
    );
    app.tools.append(
      el('button', { type: 'button', class: 'btn icon', title: '翻轉棋盤', 'aria-label': '翻轉棋盤', onclick: () => app.board.flip() }, '⇅'),
      el('button', { type: 'button', class: 'btn icon', 'aria-label': '第一步', onclick: () => go(0) }, '⏮'),
      el('button', { type: 'button', class: 'btn icon', id: 'op-prev', 'aria-label': '上一步', onclick: () => go(S.ply - 1) }, '◀'),
      el('button', { type: 'button', class: 'btn icon', id: 'op-next', 'aria-label': '下一步', onclick: () => go(S.ply + 1) }, '▶'),
      el('button', { type: 'button', class: 'btn icon', 'aria-label': '最後一步', onclick: () => go(S.moves.length) }, '⏭'),
    );
    this._key = e => {
      if (e.target.closest('input, textarea, select')) return;
      if (e.key === 'ArrowLeft') { go(S.ply - 1); e.preventDefault(); } else if (e.key === 'ArrowRight') { go(S.ply + 1); e.preventDefault(); }
    };
    document.addEventListener('keydown', this._key);
    app.use({ canMove: c => !S.drill || c === S.o.side, onMove });
    const favs = await db.all('favorites').catch(() => []);
    S.favs = new Set(favs.filter(f => f.kind === 'opening').map(f => f.ref));
    const want = OPENINGS.find(o => o.id === params.id) || S.o || OPENINGS[0];
    selectOpening(want);
  },
  unmount() { S.tok++; S.drill = false; document.removeEventListener('keydown', this._key); },
};
