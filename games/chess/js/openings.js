// 開局研究：主線一步一步看（每步附說明）、主要變化、開局目的、典型戰術、常見錯誤、練習模式、收藏。
import { Chess } from '../vendor/chessjs/chess.js';
import { OPENINGS } from '../data/openings.js';
import { db } from './store.js';
import { el, renderMoves, detectOpening } from './ui.js';

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
// line／side／title 不給就是練這個開局的主線、這個開局通常那一方
function startDrill(line, side, title) {
  S.drill = true; S.drillMiss = 0;
  S.drillSide = side || S.o.side;
  const main = !line || line === S.o.main;
  S.moves = sansOf(line || S.o.main); S.notes = main ? S.o.notes : {}; S.title = title || '練習主線'; S.line = line || S.o.main;
  S.ply = 0;
  app.board.setFlipped(S.drillSide === 'b');
  render();
  ui.note.textContent = `練習：你下${S.drillSide === 'w' ? '白' : '黑'}方，照${main ? '主線' : '這條變化'}走。想一想每一步的目的！`;
  ui.note.style.visibility = 'visible';
  autoReply();
}
function autoReply() {
  const myTurnColor = S.drillSide;
  const tok = S.tok;
  if (S.ply >= S.moves.length) {
    S.drill = false;
    ui.note.textContent = S.drillMiss ? `走完了！中間錯了 ${S.drillMiss} 次，再練一次看看。` : '完美！整條都走對了 🎉';
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

// ── 照你的實戰挑：從「我的」對局找出你最常下的開局，以及你在哪一步離開了書上的走法 ──
async function scanMyGames() {
  const games = (await db.all('games').catch(() => [])).filter(g => g.mode === 'play' && g.pgn);
  const lines = [];
  for (const o of OPENINGS) {
    lines.push({ o, name: null, pgn: o.main, sans: sansOf(o.main) });
    for (const l of o.lines) lines.push({ o, name: l.name, pgn: l.moves, sans: sansOf(l.moves) });
  }
  const freq = new Map(), devs = new Map();
  for (const g of games) {
    let sans;
    try { const c = new Chess(); c.loadPgn(g.pgn); if (c.getHeaders().FEN) continue; sans = c.history(); } catch (e) { continue; }
    const det = detectOpening(sans);
    if (!det) continue;
    freq.set(det.o, (freq.get(det.o) || 0) + 1);
    // 同一個開局的書上走法裡，對得最長的那一條
    let best = null;
    for (const L of lines) {
      if (L.o !== det.o) continue;
      let m = 0; while (m < L.sans.length && m < sans.length && L.sans[m] === sans[m]) m++;
      if (!best || m > best.m) best = { ...L, m };
    }
    if (!best || best.m >= best.sans.length || best.m >= sans.length) continue;   // 照書走完了，或棋局比書短
    const mover = best.m % 2 === 0 ? 'w' : 'b';
    if (mover !== g.myColor) continue;                                             // 是電腦先離開書本，不算你的
    const key = `${best.o.id}|${best.name}|${best.m}|${sans[best.m]}`;
    const d = devs.get(key) || { o: best.o, name: best.name, pgn: best.pgn, ply: best.m, played: sans[best.m], book: best.sans[best.m], side: g.myColor, count: 0, last: '' };
    d.count++; if (g.date > d.last) d.last = g.date;
    devs.set(key, d);
  }
  return { n: games.length, freq: [...freq.entries()].sort((a, b) => b[1] - a[1]), devs: [...devs.values()].sort((a, b) => b.count - a.count || b.last.localeCompare(a.last)) };
}
// ── 我的開局樹：你自己的對局在每一步分別走過哪些著法、各幾盤、勝率多少 ──
const T = { color: 'w', path: [], games: null };
async function loadTreeGames() {
  const all = (await db.all('games').catch(() => [])).filter(g => g.mode === 'play' && g.pgn);
  T.games = [];
  for (const g of all) {
    try { const c = new Chess(); c.loadPgn(g.pgn); if (c.getHeaders().FEN) continue; T.games.push({ sans: c.history(), color: g.myColor, outcome: g.outcome }); } catch (e) { /* 壞掉的棋譜略過 */ }
  }
}
function bookNext(path) {      // 書上（開局資料）在這個位置會走哪些
  const out = new Set();
  for (const o of OPENINGS) for (const pgn of [o.main, ...o.lines.map(l => l.moves)]) {
    const sans = sansOf(pgn);
    if (sans.length > path.length && path.every((m, i) => sans[i] === m)) out.add(sans[path.length]);
  }
  return out;
}
function treeGo(path) {
  T.path = path;
  S.tok++; S.drill = false; S.line = null; S.title = '我的開局樹'; S.notes = {};
  S.moves = path.slice(); S.ply = path.length;
  app.board.setFlipped(T.color === 'b');
  render();
  ui.note.textContent = path.length ? '這是你自己的對局走到這裡的局面。下方「我的開局樹」列出接下來你們走過的著法。' : '開局局面。下方「我的開局樹」列出你第一步走過哪些著法。';
  ui.note.style.visibility = 'visible';
  renderTree();
}
function renderTree() {
  const box = ui.tree; if (!box) return;
  box.innerHTML = '';
  const seg = el('div', { class: 'seg', role: 'group', 'aria-label': '看你執哪一色的對局' });
  for (const [c, t] of [['w', '你執白'], ['b', '你執黑']]) seg.append(el('button', { type: 'button', 'data-tree-color': c, 'aria-pressed': String(T.color === c), onclick: () => { T.color = c; treeGo([]); } }, t));
  box.append(el('div', { class: 'row spread' }, el('h2', { style: 'margin:0' }, '我的開局樹'), seg));
  const mine = (T.games || []).filter(g => g.color === T.color);
  if (!mine.length) { box.append(el('p', { class: 'small muted', style: 'margin-top:8px' }, `還沒有你執${T.color === 'w' ? '白' : '黑'}的對局。去「對弈」下幾盤，這裡會畫出你走過的開局。`)); return; }
  // 麵包屑：一路走來的棋步，點了可以退回那一步
  const crumbs = el('div', { class: 'tree-path', id: 'tree-path' });
  crumbs.append(el('button', { type: 'button', class: 'chip', onclick: () => treeGo([]) }, '開始'));
  T.path.forEach((m, i) => crumbs.append(el('button', { type: 'button', class: 'chip', onclick: () => treeGo(T.path.slice(0, i + 1)) }, `${Math.floor(i / 2) + 1}${i % 2 ? '…' : '.'} ${m}`)));
  box.append(crumbs);
  const det = detectOpening(T.path);
  box.append(el('p', { class: 'small muted', style: 'min-height:1.6em' }, det ? `開局：${det.o.name}${det.name ? '・' + det.name : ''}` : ' '));
  // 這個位置之後走過的著法
  const here = mine.filter(g => T.path.every((m, i) => g.sans[i] === m));
  const kids = new Map();
  for (const g of here) {
    const m = g.sans[T.path.length]; if (!m) continue;
    const k = kids.get(m) || { m, n: 0, w: 0, d: 0, l: 0 };
    k.n++; if (g.outcome === 'win') k.w++; else if (g.outcome === 'draw') k.d++; else if (g.outcome === 'loss') k.l++;
    kids.set(m, k);
  }
  const ply = T.path.length, mover = ply % 2 === 0 ? 'w' : 'b';
  box.append(el('p', { class: 'small', style: 'margin:4px 0 6px' }, `${here.length} 盤走到這裡。接下來${mover === T.color ? '你' : '電腦'}（${mover === 'w' ? '白' : '黑'}）走過：`));
  if (!kids.size) { box.append(el('p', { class: 'small muted' }, '沒有對局再往下走了。')); return; }
  const book = bookNext(T.path);
  const list = el('div', { class: 'list', id: 'tree-list' });
  for (const k of [...kids.values()].sort((a, b) => b.n - a.n)) {
    const done = k.w + k.d + k.l;
    const pct = done ? Math.round((k.w + k.d / 2) / done * 100) : null;
    const bar = el('div', { class: 'wdl-bar', title: `${k.w} 勝 ${k.d} 和 ${k.l} 負` },
      el('span', { class: 'w', style: `flex:${k.w}` }), el('span', { class: 'd', style: `flex:${k.d}` }), el('span', { class: 'l', style: `flex:${k.l}` }));
    list.append(el('button', { type: 'button', class: 'item tree-row', 'data-move': k.m, onclick: () => treeGo(T.path.concat(k.m)) },
      el('b', { class: 'mono', style: 'min-width:5.2em' }, `${Math.floor(ply / 2) + 1}${ply % 2 ? '…' : '.'} ${k.m}`),
      book.has(k.m) ? el('span', { class: 'eco', title: '開局資料裡的走法' }, '書') : el('span', { class: 'eco off' }, '書'),
      el('div', { class: 'grow' }, done ? bar : el('span', { class: 'small muted' }, '還沒下完')),
      el('span', { class: 'small mono', style: 'min-width:6.5em;text-align:right' }, `${k.n} 盤${pct !== null ? `・${pct}%` : ''}`)));
  }
  box.append(list, el('p', { class: 'small muted', style: 'margin-top:6px' }, '勝率＝（勝＋和的一半）÷ 下完的盤數，用你這方算。「書」＝開局資料裡有的走法。'));
}

async function renderMine() {
  const box = ui.mine; box.innerHTML = '';
  const r = await scanMyGames();
  box.append(el('h2', {}, '照你的實戰練 ', el('small', {}, `看過 ${r.n} 盤`)));
  if (!r.freq.length) { box.append(el('p', { class: 'small muted' }, r.n ? '你的對局裡還沒有認得的開局。' : '去「對弈」下幾盤，這裡會列出你最常下的開局，以及你在哪一步離開了書上的走法。')); return; }
  const chips = el('div', { class: 'chips' });
  for (const [o, n] of r.freq.slice(0, 6)) chips.append(el('button', { type: 'button', class: 'chip', onclick: () => selectOpening(o) }, o.name, el('span', { class: 'n' }, `${n} 盤`)));
  box.append(el('p', { class: 'small muted', style: 'margin-bottom:6px' }, '你最常下的開局：'), chips);
  if (!r.devs.length) { box.append(el('p', { class: 'small', style: 'margin-top:8px' }, '你下這些開局時都照著書上的走法 👍')); return; }
  box.append(el('p', { class: 'small muted', style: 'margin:10px 0 6px' }, '你離開書上走法的地方（最常出現的在上面）：'));
  const list = el('div', { class: 'list', id: 'op-mine-list' });
  for (const d of r.devs.slice(0, 5)) {
    const no = Math.floor(d.ply / 2) + 1, dots = d.ply % 2 ? '…' : '.';
    const title = `${d.o.name}${d.name ? '・' + d.name : ''}`;
    list.append(el('div', { class: 'item', style: 'flex-wrap:wrap' },
      el('div', { class: 'grow', style: 'flex-basis:100%' }, el('b', {}, title),
        el('span', {}, `第 ${no} 回合你走了 ${no}${dots} ${d.played}，書上是 ${no}${dots} ${d.book}${d.count > 1 ? `（${d.count} 盤）` : ''}`)),
      el('button', { type: 'button', class: 'btn sm', onclick: () => {
        S.o = d.o; renderList(); renderDetail(); app.board.setFlipped(d.side === 'b'); S.drill = false;
        showLine(d.pgn, title, d.name ? {} : d.o.notes, d.ply);
        const u = posAt(d.ply).move(d.book); app.board.setArrows([{ from: u.from, to: u.to, color: 'rgba(34,197,94,0.8)' }]);
        ui.note.textContent = `你在這裡走了 ${d.played}；書上的走法是綠色箭頭 ${d.book}。` + (d.o.notes && !d.name && d.o.notes[d.ply + 1] ? d.o.notes[d.ply + 1] : '');
        ui.note.style.visibility = 'visible';
      } }, '看書上的走法'),
      el('button', { type: 'button', class: 'btn sm primary', onclick: () => { S.o = d.o; renderList(); renderDetail(); startDrill(d.pgn, d.side, `練習：${title}`); } }, '練習這條')));
  }
  box.append(list);
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
      el('button', { type: 'button', class: 'btn primary', id: 'op-drill', onclick: () => startDrill() }, '練習主線'),
      el('button', { type: 'button', class: 'btn sm', onclick: () => app.go('play', { fen: app.game.fen() }) }, '從目前局面跟電腦下 →')));

  // 棋盤下方：目的、變化、戰術、錯誤，寬一點比較好讀
  const d = app.wide; d.innerHTML = ''; d.hidden = false;
  if (ui.mine) d.append(ui.mine);   // 「照你的實戰練」固定放在最前面
  if (ui.tree) d.append(ui.tree);
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
    ui.mine = el('div', { class: 'card', id: 'op-mine' });
    ui.tree = el('div', { class: 'card', id: 'op-tree' });
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
    app.use({ canMove: c => !S.drill || c === S.drillSide, onMove });
    const favs = await db.all('favorites').catch(() => []);
    S.favs = new Set(favs.filter(f => f.kind === 'opening').map(f => f.ref));
    const want = OPENINGS.find(o => o.id === params.id) || S.o || OPENINGS[0];
    selectOpening(want);
    renderMine();
    loadTreeGames().then(renderTree);
  },
  unmount() { S.tok++; S.drill = false; document.removeEventListener('keydown', this._key); },
};
