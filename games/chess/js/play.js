// 對弈：玩家對 Stockfish。選顏色、難度、思考時間；悔棋、重新開始、提示、認輸；FEN／PGN 載入、PGN 匯出；自動存檔。
import { Chess, DEFAULT_POSITION } from '../vendor/chessjs/chess.js';
import { LEVELS, fmtScore, whitePov } from './engine.js';
import { db, prefs, setPref, uid } from './store.js';
import { el, renderMoves, download, copy, today, uciList, applyUci, fenProblem } from './ui.js';

const S = {
  g: null, startFen: DEFAULT_POSITION, my: 'w', view: null, thinking: false, token: 0, id: null, over: null, resigned: false, hint: null,
};
let app, ui = {};

const levelOf = () => LEVELS[S.level] || LEVELS[4];
const engineColor = () => (S.my === 'w' ? 'b' : 'w');

function newGame(fen = DEFAULT_POSITION, pgn = null) {
  S.token++;
  app.engine.stop();
  S.my = S.pick;
  app.board.setFlipped(S.my === 'b');
  S.g = new Chess();
  if (pgn) S.g.loadPgn(pgn);
  else if (fen !== DEFAULT_POSITION) S.g.load(fen);
  S.startFen = pgn ? (S.g.getHeaders().FEN || DEFAULT_POSITION) : fen;
  S.view = null; S.thinking = false; S.id = uid('g'); S.over = null; S.resigned = false; S.hint = null;
  app.engine.newGame();
  sync();
  maybeEngine();
}

function shown() {
  if (S.view === null) return S.g;
  const g = new Chess(S.startFen);
  for (const m of S.g.history({ verbose: true }).slice(0, S.view)) g.move(m.san);
  return g;
}

function outcome(g) {
  if (S.resigned) return { result: S.my === 'w' ? '0-1' : '1-0', text: '你認輸了', cls: 'bad', why: 'resign' };
  if (g.isCheckmate()) {
    const winner = g.turn() === 'w' ? 'b' : 'w';
    return { result: winner === 'w' ? '1-0' : '0-1', text: winner === S.my ? '將死！你贏了 🎉' : '被將死了，電腦獲勝', cls: winner === S.my ? 'good' : 'bad', why: 'checkmate' };
  }
  if (g.isStalemate()) return { result: '1/2-1/2', text: '逼和：輪到走的一方沒有合法步、但沒被將軍，和棋', cls: 'warn', why: 'stalemate' };
  if (g.isInsufficientMaterial()) return { result: '1/2-1/2', text: '和棋：雙方子力都不夠將死對方', cls: 'warn', why: 'material' };
  if (g.isThreefoldRepetition()) return { result: '1/2-1/2', text: '和棋：同一個局面出現三次', cls: 'warn', why: 'repetition' };
  if (g.isDrawByFiftyMoves()) return { result: '1/2-1/2', text: '和棋：50 步內沒有吃子也沒有動兵', cls: 'warn', why: 'fifty' };
  return null;
}

function sync() {
  const g = shown();
  app.setGame(g);
  app.board.setLast(g.history({ verbose: true }).slice(-1)[0] || null);
  app.board.setArrows(S.hint && S.view === null ? [{ from: S.hint.slice(0, 2), to: S.hint.slice(2, 4), color: 'rgba(6,182,212,0.75)' }] : []);
  app.board.render();
  const lv = levelOf();
  app.players({ white: S.my === 'w' ? '你' : `Stockfish（${lv.label}）`, black: S.my === 'b' ? '你' : `Stockfish（${lv.label}）` });
  // 狀態
  const st = ui.status; st.className = 'status'; st.innerHTML = '';
  const o = S.over || outcome(S.g);
  if (o) { st.classList.add(o.cls); st.textContent = o.text + `（${o.result}）`; }
  else if (S.thinking) { st.append(el('span', { class: 'spinner' }), '電腦思考中…'); }
  else if (S.g.turn() === S.my) st.textContent = (S.g.inCheck() ? '被將軍了！' : '') + `輪到你（${S.my === 'w' ? '白' : '黑'}）`;
  else st.textContent = '輪到電腦';
  if (S.view !== null) st.append(el('span', { class: 'small muted', text: `　（正在看第 ${S.view} 步）` }));
  if (app.engine.state === 'loading') st.append(el('span', { class: 'small muted', text: '　引擎載入中…' }));
  if (app.engine.state === 'error') { st.className = 'status bad'; st.textContent = 'Stockfish 載入失敗：' + (app.engine.error && app.engine.error.message || '') + '。請重新整理頁面。'; }
  const h = S.g.history();
  renderMoves(ui.moves, h, S.view === null ? h.length : S.view, ply => { S.view = ply === h.length ? null : ply; sync(); },
    { startTurn: new Chess(S.startFen).turn(), startNo: new Chess(S.startFen).moveNumber() });
  ui.undo.disabled = !h.length || (!!o && !S.resigned && false);
  ui.live.hidden = S.view === null;
  ui.resign.disabled = !!o || !h.length;
  ui.hintBtn.disabled = !!o || S.thinking || S.g.turn() !== S.my;
}

async function maybeEngine() {
  if (outcome(S.g) || S.over || S.g.turn() === S.my) { if (outcome(S.g)) finish(); sync(); return; }
  const tok = ++S.token;
  S.thinking = true; sync();
  const lv = levelOf();
  try {
    const r = await app.engine.go({ fen: S.startFen, moves: uciList(S.g), movetime: S.movetime, depth: lv.depth || undefined, skill: lv.skill });
    if (tok !== S.token) return;
    S.thinking = false;
    if (r.best) applyUci(S.g, r.best);
    S.view = null;
    if (outcome(S.g)) finish();
    else save(false);
  } catch (e) {
    if (tok !== S.token) return;
    S.thinking = false;
  }
  sync();
}

async function finish() {
  if (S.over) return;
  S.over = outcome(S.g);
  if (S.over) await save(true);
}

function pgnText() {
  const g = new Chess();
  if (S.startFen !== DEFAULT_POSITION) { g.load(S.startFen); g.setHeader('SetUp', '1'); g.setHeader('FEN', S.startFen); }
  for (const m of S.g.history()) g.move(m);
  const lv = levelOf();
  const o = S.over || outcome(S.g);
  g.setHeader('Event', 'Jellyfish Chess 對弈');
  g.setHeader('Site', 'https://jellyfishkuo.github.io/games/chess/');
  g.setHeader('Date', today());
  g.setHeader('White', S.my === 'w' ? '你' : `Stockfish 等級 ${S.level}`);
  g.setHeader('Black', S.my === 'b' ? '你' : `Stockfish 等級 ${S.level}`);
  g.setHeader('Result', o ? o.result : '*');
  return g.pgn();
}

async function save(final) {
  if (!S.g.history().length) return;
  const o = S.over || outcome(S.g);
  const rec = {
    id: S.id, date: new Date().toISOString(), pgn: pgnText(), mode: 'play', level: S.level, myColor: S.my,
    result: o ? o.result : '*', reason: o ? o.why : null,
    outcome: !o ? 'ongoing' : o.result === '1/2-1/2' ? 'draw' : ((o.result === '1-0') === (S.my === 'w') ? 'win' : 'loss'),
    moves: S.g.history().length,
  };
  try { await db.put('games', rec); if (final) app.toast('棋譜已存到「我的」'); } catch (e) { /* 存不了不影響下棋 */ }
}

function onMove(m) {
  if (S.view !== null || S.thinking || S.over || outcome(S.g)) return false;
  try { S.g.move(m); } catch (e) { return false; }
  S.hint = null;
  sync();
  maybeEngine();
  return true;
}

function undo() {
  S.token++; app.engine.stop(); S.thinking = false; S.hint = null;
  if (S.over && S.resigned) { S.over = null; S.resigned = false; }
  else if (S.over) S.over = null;
  // 退到輪到自己
  S.g.undo();
  if (S.g.turn() !== S.my && S.g.history().length) S.g.undo();
  S.view = null;
  sync();
  if (S.g.turn() !== S.my) maybeEngine();
}

async function hint() {
  if (S.g.turn() !== S.my || S.over) return;
  ui.hintBtn.disabled = true;
  const tok = S.token;
  const r = await app.engine.go({ fen: S.g.fen(), movetime: 800, skill: 20 });
  if (tok !== S.token || !r.best) return;
  S.hint = r.best;
  const sc = r.lines[0] && whitePov(r.lines[0].score, S.g.turn());
  app.toast(`提示：箭頭是引擎建議的走法（評估 ${fmtScore(sc)}）`);
  sync();
}

async function loadFen() {
  const r = await app.dialog({ title: '從 FEN 開始', body: '貼上一個 FEN 局面，會從這個局面開始跟電腦下。', fields: [{ name: 'fen', label: 'FEN', value: S.g.fen(), type: 'textarea', rows: 3 }], ok: '開始' });
  if (!r) return;
  const fen = r.fen.trim();
  const bad = fenProblem(fen);
  if (bad) { app.toast('FEN 不能用：' + bad, 3500); return; }
  newGame(fen);
}
async function loadPgn() {
  const r = await app.dialog({ title: '匯入 PGN 接著下', body: '貼上 PGN，會從棋譜的最後一個局面接著跟電腦下。', fields: [{ name: 'pgn', label: 'PGN', type: 'textarea', rows: 8, placeholder: '1. e4 e5 2. Nf3 Nc6 …' }], ok: '匯入' });
  if (!r) return;
  try { new Chess().loadPgn(r.pgn); } catch (e) { app.toast('PGN 讀不懂：' + e.message, 3500); return; }
  newGame(DEFAULT_POSITION, r.pgn);
}
async function exportPgn() {
  const text = pgnText();
  const pre = el('textarea', { rows: 8, readonly: true }); pre.value = text;
  const r = await app.dialog({ title: '匯出 PGN', body: pre, ok: '下載 .pgn', cancel: '關閉', extra: el('div', { class: 'row' }, el('button', { type: 'button', class: 'btn sm', onclick: async () => app.toast(await copy(text) ? '已複製' : '複製失敗，請手動選取') }, '複製')) });
  if (r) download(`jellyfish-chess-${today()}.pgn`, text, 'application/x-chess-pgn');
}

export default {
  id: 'play', title: '對弈',
  mount(a, params) {
    app = a;
    const p = prefs();
    S.level = p.level; S.movetime = p.movetime; S.pick = p.color;
    if (!S.g) S.my = p.color;
    const panel = app.panel;
    // 設定卡
    const colorSeg = el('div', { class: 'seg', role: 'group', 'aria-label': '你執哪一色' });
    for (const [c, t] of [['w', '白棋（先走）'], ['b', '黑棋']]) {
      colorSeg.append(el('button', { type: 'button', 'data-color': c, 'aria-pressed': String(S.pick === c), onclick: () => {
        S.pick = c; setPref('color', c);
        colorSeg.querySelectorAll('button').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.color === c)));
      } }, t));
    }
    const lvl = el('input', { type: 'range', min: 1, max: 10, step: 1, value: S.level, id: 'lvl', 'aria-label': '電腦難度' });
    const lvlTxt = el('b', { text: LEVELS[S.level].label });
    lvl.oninput = () => { S.level = +lvl.value; lvlTxt.textContent = LEVELS[S.level].label; setPref('level', S.level); sync(); };
    const tm = el('select', { id: 'movetime', 'aria-label': '電腦思考時間' });
    for (const [v, t] of [[200, '0.2 秒'], [500, '0.5 秒'], [1000, '1 秒'], [2000, '2 秒'], [3000, '3 秒'], [5000, '5 秒']])
      tm.append(el('option', { value: v, selected: v === S.movetime }, t));
    tm.onchange = () => { S.movetime = +tm.value; setPref('movetime', S.movetime); };

    panel.append(el('div', { class: 'card' },
      el('h2', {}, '與電腦對弈 ', el('small', {}, 'Stockfish 18')),
      el('div', { class: 'row', style: 'margin-bottom:10px' }, colorSeg),
      el('label', { class: 'field' }, el('span', {}, '難度：', lvlTxt), lvl),
      el('label', { class: 'field', style: 'margin-top:8px' }, '每步最多思考', tm),
      el('div', { class: 'row', style: 'margin-top:12px' },
        el('button', { type: 'button', class: 'btn primary', id: 'btn-new', onclick: () => newGame() }, '開新局'),
        el('button', { type: 'button', class: 'btn', onclick: loadFen }, '從 FEN 開始'),
        el('button', { type: 'button', class: 'btn', onclick: loadPgn }, '匯入 PGN')),
      el('p', { class: 'small muted', style: 'margin-top:8px' }, '難度是 Stockfish 的 Skill Level 加上搜尋深度上限；等級 10 是全力。換顏色後按「開新局」生效。'),
    ));
    ui.status = el('div', { class: 'status', id: 'play-status' });
    ui.moves = el('div', { class: 'moves', id: 'play-moves' });
    ui.undo = el('button', { type: 'button', class: 'btn', id: 'btn-undo', onclick: undo }, '↶ 悔棋');
    ui.hintBtn = el('button', { type: 'button', class: 'btn', id: 'btn-hint', onclick: hint }, '💡 提示');
    ui.resign = el('button', { type: 'button', class: 'btn danger', id: 'btn-resign', onclick: async () => {
      if (!(await app.confirm('確定要認輸嗎？', '這盤會記成輸棋。'))) return;
      S.token++; app.engine.stop(); S.thinking = false; S.resigned = true; S.over = outcome(S.g); await save(true); sync();
    } }, '🏳 認輸');
    ui.live = el('button', { type: 'button', class: 'btn sm', onclick: () => { S.view = null; sync(); } }, '回到目前局面');
    panel.prepend(el('div', { class: 'card' },
      ui.status,
      el('div', { class: 'row', style: 'margin:10px 0' }, ui.undo, ui.hintBtn, ui.resign),
      el('div', { class: 'row spread', style: 'margin-bottom:6px' }, el('b', { class: 'small' }, '棋譜'), ui.live),
      ui.moves,
      el('div', { class: 'row', style: 'margin-top:10px' },
        el('button', { type: 'button', class: 'btn sm', id: 'btn-export', onclick: exportPgn }, '匯出 PGN'),
        el('button', { type: 'button', class: 'btn sm', id: 'btn-save', onclick: async () => { await save(false); app.toast('已存到「我的」'); } }, '儲存棋譜'),
        el('button', { type: 'button', class: 'btn sm', onclick: () => app.go('analysis', { pgn: pgnText() }) }, '用引擎分析這盤 →')),
    ));
    app.tools.append(
      el('button', { type: 'button', class: 'btn icon', id: 'btn-flip', title: '翻轉棋盤', 'aria-label': '翻轉棋盤', onclick: () => { app.board.flip(); sync(); } }, '⇅ 翻轉'),
      el('button', { type: 'button', class: 'btn icon', title: '上一步', 'aria-label': '上一步', onclick: () => { const n = S.g.history().length; const v = S.view === null ? n : S.view; if (v > 0) { S.view = v - 1; sync(); } } }, '◀'),
      el('button', { type: 'button', class: 'btn icon', title: '下一步', 'aria-label': '下一步', onclick: () => { const n = S.g.history().length; if (S.view !== null) { S.view = S.view + 1 >= n ? null : S.view + 1; sync(); } } }, '▶'),
    );
    app.use({ canMove: c => c === S.my && S.view === null && !S.thinking && !S.over && !outcome(S.g), onMove });
    this._st = () => sync();
    app.engine.addEventListener('status', this._st);
    if (params.fen) { S.pick = new Chess(params.fen).turn(); newGame(params.fen); }
    else if (S.g && !params.fresh) { app.board.setFlipped(S.my === 'b'); sync(); maybeEngine(); }
    else newGame();
    app.engine.ready().catch(() => sync());
  },
  unmount() {
    S.token++; app.engine.stop(); S.thinking = false;
    app.engine.removeEventListener('status', this._st);
  },
};
