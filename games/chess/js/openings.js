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
    ui.list.append(el('button', { type: 'button', 'data-op': o.id, 'aria-pressed': String(S.o === o), onclick: () => selectOpening(o) },
      el('b', {}, (S.favs.has(o.id) ? '★ ' : '') + o.name), el('span', {}, `${o.en}・${o.eco}`)));
  }
}

// 在下方說明裡點一條棋譜：換到棋盤上；棋盤不在畫面裡就捲回去（手機上說明在棋盤下面很遠）
function showFromBelow(pgn, title, btn) {
  S.drill = false;
  showLine(pgn, title, {}, 0);
  document.querySelectorAll('#wide .line-btn.on').forEach(b => b.classList.remove('on'));
  if (btn) btn.classList.add('on');
  const r = document.querySelector('.stage').getBoundingClientRect();
  if (r.top < 0 || r.top > innerHeight * 0.5) window.scrollTo({ top: Math.max(0, scrollY + r.top - 70), behavior: 'smooth' });
}
function lineButton(head, pgn, title, sub, text) {
  const b = el('button', { type: 'button', class: 'line-btn', title: '在棋盤上看這條棋譜' }, el('b', {}, head),
    el('span', { class: 'mono' }, sub || pgn), text ? el('p', {}, text) : null);
  b.onclick = () => showFromBelow(pgn, title, b);
  return b;
}

function renderDetail() {
  const o = S.o;
  // 右側：這個開局的名稱、收藏、主線按鈕
  const h = ui.head; h.innerHTML = '';
  const fav = el('button', { type: 'button', class: 'btn sm', id: 'op-fav', 'aria-pressed': String(S.favs.has(o.id)), onclick: async () => {
    if (S.favs.has(o.id)) { S.favs.delete(o.id); await db.del('favorites', 'opening:' + o.id).catch(() => {}); }
    else { S.favs.add(o.id); await db.put('favorites', { id: 'opening:' + o.id, kind: 'opening', ref: o.id, date: new Date().toISOString() }).catch(() => {}); }
    renderDetail(); renderList();
  } }, S.favs.has(o.id) ? '★ 已收藏' : '☆ 收藏');
  h.append(
    el('div', { class: 'row spread' }, el('h2', { style: 'margin:0' }, o.name), fav),
    el('p', { class: 'small muted' }, o.en, '　', el('span', { class: 'eco' }, 'ECO ' + o.eco), '　', `通常是${o.side === 'w' ? '白' : '黑'}方的選擇`),
    el('div', { class: 'row', style: 'margin-top:8px' },
      el('button', { type: 'button', class: 'btn', onclick: () => { S.drill = false; showLine(o.main, '主線', o.notes, 0); } }, '▶ 從頭看主線'),
      el('button', { type: 'button', class: 'btn primary', id: 'op-drill', onclick: startDrill }, '練習主線'),
      el('button', { type: 'button', class: 'btn sm', onclick: () => app.go('play', { fen: app.game.fen() }) }, '從目前局面跟電腦下 →')));

  // 棋盤下方：目的、變化、戰術、錯誤，寬一點比較好讀
  const d = app.wide; d.innerHTML = ''; d.hidden = false;
  d.id = 'wide';
  const purpose = el('ul'); for (const p of o.purpose) purpose.append(el('li', {}, p));
  d.append(el('div', { class: 'card prose', id: 'op-purpose' }, el('h2', {}, '開局目的'), purpose,
    el('p', { class: 'small muted', style: 'margin-top:8px' }, '主線：', el('span', { class: 'mono' }, o.main))));
  const lines = el('div', { class: 'list' });
  lines.append(lineButton('主線', o.main, '主線', `ECO ${o.eco}`));
  for (const l of o.lines) lines.append(lineButton(l.name, l.moves, l.name, `ECO ${l.eco}`, l.text));
  d.append(el('div', { class: 'card' }, el('h2', {}, '主要變化'), lines));
  const tac = el('div', { class: 'list' });
  for (const t of o.tactics) tac.append(lineButton(t.title, t.line, t.title, null, t.text));
  d.append(el('div', { class: 'card' }, el('h2', {}, '典型戰術'), tac));
  const mis = el('div', { class: 'list' });
  for (const t of o.mistakes) mis.append(lineButton('✗ ' + t.title, t.line, t.title, null, t.text));
  d.append(el('div', { class: 'card' }, el('h2', {}, '常見錯誤'), mis));
  // 舊的測試／其他模組用 #op-detail 找說明：指到同一塊
  ui.detail = d;
}

export default {
  id: 'openings', title: '開局',
  async mount(a, params) {
    app = a;
    ui.lineTitle = el('h2', { id: 'op-line', style: 'margin-bottom:4px' });
    ui.note = el('p', { class: 'small', id: 'op-note', style: 'min-height:4.8em' });
    ui.moves = el('div', { class: 'moves', id: 'op-moves' });
    ui.list = el('div', { class: 'op-grid', id: 'op-list' });
    ui.head = el('div', { id: 'op-head' });
    app.main.classList.add('sticky-panel');
    app.panel.append(
      el('div', { class: 'card' }, el('h2', {}, '選一個開局 ', el('small', {}, `${OPENINGS.length} 個`)), ui.list),
      el('div', { class: 'card' }, ui.head, el('hr', { style: 'border:0;border-top:1px solid var(--c-line);margin:12px 0' }), ui.lineTitle, ui.note, ui.moves),
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
