// 對弈：玩家對 Stockfish。選顏色、難度、思考時間；悔棋、重新開始、提示、認輸；FEN／PGN 載入、PGN 匯出；自動存檔。
import { Chess, DEFAULT_POSITION } from '../vendor/chessjs/chess.js';
import { LEVELS, fmtScore, whitePov } from './engine.js';
import { db, prefs, setPref, uid } from './store.js';
import { el, renderMoves, download, copy, today, uciList, applyUci, fenProblem, openingLine } from './ui.js';
import { evaluateGame, gameLine, reviewSide, classify } from './review.js';

const S = {
  g: null, startFen: DEFAULT_POSITION, my: 'w', view: null, thinking: false, token: 0, id: null, over: null, resigned: false, hint: null,
  tc: null, clock: null, clockHist: [], tickAt: 0,          // 時間控制：{base, inc}（毫秒）、雙方剩下的時間、每一步之前的時間（悔棋用）
  review: null, reviewTok: 0,                                 // 對完自動復盤的結果
  coach: false, coachEval: null, coachScore: null, checking: false, coachWarn: null, coachSaved: 0,   // 教練模式
};
// 時間控制選項：'分+秒'；空字串＝不限時
export const TIME_CONTROLS = [['', '不限時'], ['3+2', '3 分＋2 秒'], ['5+3', '5 分＋3 秒'], ['10+5', '10 分＋5 秒'], ['15+10', '15 分＋10 秒'], ['30+0', '30 分']];
function parseTc(t) { if (!t) return null; const [m, i] = t.split('+').map(Number); return { base: m * 60000, inc: i * 1000, label: t }; }
function fmtClock(ms) {
  ms = Math.max(0, ms);
  if (ms < 10000) return (ms / 1000).toFixed(1);               // 最後 10 秒顯示到 0.1 秒
  const t = Math.ceil(ms / 1000);
  return `${Math.floor(t / 60)}:${String(t % 60).padStart(2, '0')}`;
}
let app, ui = {};
const MIN_THINK = 1200;   // 電腦每步至少顯示「思考中」這麼久（毫秒）

const levelOf = () => LEVELS[S.level] || LEVELS[4];
const engineColor = () => (S.my === 'w' ? 'b' : 'w');

// 重新整理頁面後，接回最近一盤還沒下完的棋（存在 IndexedDB 的 games，outcome = 'ongoing'）
async function resumeOrNew() {
  const fresh = S.id;
  let last = null;
  try {
    const all = await db.all('games');
    last = all.filter(g => g.mode === 'play' && g.outcome === 'ongoing').sort((a, b) => b.date.localeCompare(a.date))[0];
  } catch (e) { /* 讀不到就開新局 */ }
  // 只有在剛開的新局還沒被動過時才換上舊棋
  if (!last || S.id !== fresh || S.g.history().length > (S.my === 'b' ? 1 : 0)) return;
  try {
    S.pick = last.myColor;
    document.querySelectorAll('.seg button[data-color]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.color === S.pick)));
    db.del('games', fresh).catch(() => {});   // 剛開的那盤（電腦可能已經先走一步）不留紀錄
    S.g = null;
    S.pickTc = last.tc || '';
    newGame(DEFAULT_POSITION, last.pgn);
    if (S.tc && last.clock) { S.clock = { ...last.clock }; S.tickAt = performance.now(); }   // 離開期間的時間不算
    S.pickTc = prefs().tc || '';
    S.id = last.id;                       // 之後存檔覆蓋同一筆，不會多出一盤
    app.toast('接回上次還沒下完的棋');
  } catch (e) { newGame(); }
}

function newGame(fen = DEFAULT_POSITION, pgn = null) {
  S.token++;
  app.engine.stop();
  // 上一盤沒下完就開新局：標成「未完」，重新整理時不會再被接回來
  if (S.g && S.id && S.g.history().length && !S.over && !outcome(S.g)) {
    const oldId = S.id;
    db.get('games', oldId).then(r => { if (r && r.outcome === 'ongoing') db.put('games', { ...r, outcome: 'unfinished' }); }).catch(() => {});
  }
  S.my = S.pick;
  app.board.setFlipped(S.my === 'b');
  S.g = new Chess();
  if (pgn) S.g.loadPgn(pgn);
  else if (fen !== DEFAULT_POSITION) S.g.load(fen);
  S.startFen = pgn ? (S.g.getHeaders().FEN || DEFAULT_POSITION) : fen;
  S.view = null; S.thinking = false; S.id = uid('g'); S.over = null; S.resigned = false; S.hint = null;
  S.reviewTok++; S.review = null;
  S.coachEval = null; S.coachScore = null; S.checking = false; S.coachWarn = null; S.coachSaved = 0;
  S.tc = parseTc(S.pickTc);
  S.clock = S.tc ? { w: S.tc.base, b: S.tc.base } : null; S.clockHist = []; S.tickAt = performance.now();
  app.engine.newGame();
  sync();
  maybeEngine();
}

// ── 教練模式：顯示評估；你走出 Mistake／Blunder 時先攔下來，可以重走 ──
const coachOn = () => S.coach && !S.clock;          // 有棋鐘時不攔（等你決定的時間不知道該算誰的）
async function evalFen(fen) {
  const r = await app.engine.go({ fen, depth: 12, skill: 20 });
  const turn = new Chess(fen).turn();
  return { fen, score: whitePov(r.lines[0] ? r.lines[0].score : { cp: 0 }, turn), best: r.best, stopped: r.stopped };
}
async function coachEvalPosition() {
  if (!S.coach || S.over || outcome(S.g) || S.g.turn() !== S.my || S.view !== null) return;
  const tok = S.token, fen = S.g.fen();
  if (S.coachEval && S.coachEval.fen === fen) return;
  const e = await evalFen(fen);
  if (tok !== S.token || S.g.fen() !== fen || e.stopped) return;
  S.coachEval = e; S.coachScore = e.score;
  sync();
}
async function coachCheck(beforeFen, mv) {
  const tok = S.token;
  let before = S.coachEval && S.coachEval.fen === beforeFen ? S.coachEval : null;
  if (!before) { before = await evalFen(beforeFen); if (tok !== S.token) return; }
  const after = await evalFen(S.g.fen());
  if (tok !== S.token) return;
  S.coachScore = after.score;
  const c = classify(before.score, after.score, S.my, before.best, mv.from + mv.to + (mv.promotion || ''));
  if (c && (c.key === 'blunder' || c.key === 'mistake')) {
    let best = null;
    try { best = new Chess(beforeFen).move({ from: before.best.slice(0, 2), to: before.best.slice(2, 4), promotion: before.best[4] }).san; } catch (e) { best = null; }
    S.coachWarn = { san: mv.san, best, bestUci: before.best, cls: c, before };
    S.checking = false;
    sync();
    return;
  }
  S.checking = false;
  maybeEngine();
}
function coachRetry() {
  const W = S.coachWarn; if (!W) return;
  S.g.undo(); if (S.clock && S.clockHist.length) S.clock = S.clockHist.pop();
  S.coachWarn = null; S.coachEval = W.before; S.coachScore = W.before.score; S.coachSaved++;
  sync();
}
function coachContinue() { S.coachWarn = null; sync(); maybeEngine(); }
function renderCoach() {
  const box = ui.coach; if (!box) return;
  box.hidden = !S.coach;
  if (!S.coach) return;
  box.innerHTML = '';
  box.className = 'coach' + (S.coachWarn ? ' warn' : '');
  if (S.clock) { box.append(el('p', { class: 'small muted' }, '🧑‍🏫 有棋鐘時教練不會攔你（等你決定的時間不知道該算誰的）；不限時的對局才會提醒。')); return; }
  const W = S.coachWarn;
  if (W) {
    box.append(el('p', { class: 'small' }, el('b', {}, `🧑‍🏫 等一下！${W.san} 是 ${W.cls.name}`), `，勝率大約少了 ${Math.round(W.cls.drop * 100)}%。`, W.best ? `比較好的是 ${W.best}（先不急著看，自己再找找）。` : ''),
      el('div', { class: 'row', style: 'margin-top:6px' },
        el('button', { type: 'button', class: 'btn sm primary', id: 'coach-retry', onclick: coachRetry }, '↶ 重走這步'),
        el('button', { type: 'button', class: 'btn sm', id: 'coach-show', onclick: () => { app.board.setArrows([{ from: W.bestUci.slice(0, 2), to: W.bestUci.slice(2, 4), color: 'rgba(34,197,94,0.8)' }]); } }, '看比較好的走法'),
        el('button', { type: 'button', class: 'btn sm', id: 'coach-go', onclick: coachContinue }, '照樣下')));
  } else if (S.checking) box.append(el('p', { class: 'small muted' }, el('span', { class: 'spinner', style: 'display:inline-block;vertical-align:middle' }), '　教練在看你這一步…'));
  else box.append(el('p', { class: 'small muted' }, `🧑‍🏫 教練模式開著：左邊的評估條是目前局勢；你走出大錯（Mistake／Blunder）時會先提醒你，可以重走。${S.coachSaved ? `這盤已經救回 ${S.coachSaved} 次。` : ''}`));
}

// ── 時鐘 ──
function remaining(c) {
  if (!S.clock) return Infinity;
  const running = !S.over && S.g.turn() === c && S.g.history().length > 0;   // 第一步走之前不計時
  return S.clock[c] - (running ? performance.now() - S.tickAt : 0);
}
/** 某一方走完一步：扣掉這步用的時間、加上每步加秒。elapsed 不給就用實際經過的時間 */
function charge(c, elapsed) {
  if (!S.clock) return;
  S.clockHist.push({ ...S.clock });
  if (S.g.history().length > 1 || c === 'b' || S.startFen !== DEFAULT_POSITION) S.clock[c] -= (elapsed ?? performance.now() - S.tickAt);
  S.clock[c] += S.tc.inc;
  S.tickAt = performance.now();
}
function insufficient(c) {   // c 這一方的子力能不能將死對方（只剩王、或王＋一隻輕子 → 不能）
  const ps = S.g.board().flat().filter(p => p && p.color === c && p.type !== 'k');
  return ps.length === 0 || (ps.length === 1 && (ps[0].type === 'n' || ps[0].type === 'b'));
}
function flag(c) {
  if (S.over) return;
  S.token++; app.engine.stop(); S.thinking = false;
  S.clock[c] = 0;
  const other = c === 'w' ? 'b' : 'w';
  if (insufficient(other)) S.over = { result: '1/2-1/2', text: '時間到，但對方的子力不夠將死 → 和棋', cls: 'warn', why: 'timeout' };
  else S.over = { result: c === 'w' ? '0-1' : '1-0', text: c === S.my ? '時間到，你輸了' : '電腦時間到，你贏了 🎉', cls: c === S.my ? 'bad' : 'good', why: 'timeout' };
  save(true); sync(); startReview();
}
function tick() {
  if (!S.clock || !S.g) return;
  for (const c of ['w', 'b']) {
    const el2 = document.querySelector(`.player .clock[data-c="${c}"]`);
    const r = remaining(c);
    if (el2) { el2.textContent = fmtClock(r); el2.classList.toggle('low', r < 20000); el2.classList.toggle('on', !S.over && S.g.turn() === c && S.g.history().length > 0); }
    if (r <= 0 && !S.over) flag(c);
  }
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
  app.board.setLast(g.history({ verbose: true }).slice(-1)[0] || null, { animate: S.animNext && S.view === null });
  S.animNext = false;
  app.board.setArrows(S.hint && S.view === null ? [{ from: S.hint.slice(0, 2), to: S.hint.slice(2, 4), color: 'rgba(6,182,212,0.75)' }] : []);
  app.board.render();
  app.evalbar(S.coach ? (S.coachScore || undefined) : null);
  renderCoach();
  const lv = levelOf();
  app.players({ white: S.my === 'w' ? '你' : `Stockfish（${lv.label}）`, black: S.my === 'b' ? '你' : `Stockfish（${lv.label}）`, clocks: !!S.clock });
  tick();
  // 狀態
  const st = ui.status; st.className = 'status'; st.innerHTML = '';
  const o = S.over || outcome(S.g);
  if (o) { st.classList.add(o.cls); st.textContent = o.text + `（${o.result}）`; }
  else if (S.thinking) { st.append(el('span', { class: 'spinner' }), '電腦思考中…'); }
  else if (S.checking) { st.append(el('span', { class: 'spinner' }), '教練在看你這一步…'); }
  else if (S.coachWarn) { st.classList.add('warn'); st.textContent = '先等一下：這步不太好，要重走嗎？'; }
  else if (S.g.turn() === S.my) st.textContent = (S.g.inCheck() ? '被將軍了！' : '') + `輪到你（${S.my === 'w' ? '白' : '黑'}）`;
  else st.textContent = '輪到電腦';
  if (S.view !== null) st.append(el('span', { class: 'small muted', text: `　（正在看第 ${S.view} 步）` }));
  if (app.engine.state === 'loading') st.append(el('span', { class: 'small muted', text: '　引擎載入中…' }));
  if (app.engine.state === 'error') { st.className = 'status bad'; st.textContent = 'Stockfish 載入失敗：' + (app.engine.error && app.engine.error.message || '') + '。請重新整理頁面。'; }
  const h = S.g.history();
  openingLine(ui.opening, h, S.startFen, (r, p) => app.go(r, p));
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
    const t0 = performance.now();
    const eng = engineColor();
    const movetime = S.clock ? Math.max(100, Math.min(S.movetime, remaining(eng) / 25 + S.tc.inc * 0.6)) : S.movetime;
    const r = await app.engine.go({ fen: S.startFen, moves: uciList(S.g), movetime, depth: lv.depth || undefined, skill: lv.skill });
    if (tok !== S.token) return;
    const used = performance.now() - t0;                        // 電腦真正想的時間（之後故意等的那一段不算）
    // 低難度的引擎幾毫秒就回答，棋子會「閃」一下就出現；至少等一下，讓人看得到電腦在走
    const wait = MIN_THINK - (performance.now() - t0);
    if (wait > 0) await new Promise(res => setTimeout(res, wait));
    if (tok !== S.token) return;
    S.thinking = false;
    if (r.best) { applyUci(S.g, r.best); S.animNext = true; charge(eng, used); }
    S.view = null;
    if (outcome(S.g)) finish();
    else { save(false); coachEvalPosition(); }
  } catch (e) {
    if (tok !== S.token) return;
    S.thinking = false;
  }
  sync();
}

async function finish() {
  if (S.over) return;
  S.over = outcome(S.g);
  if (S.over) { await save(true); startReview(); }
}

// ── 對完自動復盤：在背景用引擎把整盤跑一遍，找出你的轉捩點 ──
async function startReview() {
  const h = S.g.history();
  if (h.length < 4 || !ui.review) return;
  const tok = ++S.reviewTok;
  const alive = () => tok === S.reviewTok;
  const { fens, moves } = gameLine(S.g);
  S.review = { state: 'running', done: 0, total: fens.length };
  renderReview();
  const evals = await evaluateGame(app.engine, fens, moves, { depth: 12, alive, onProgress: (k, n, phase) => { if (!alive()) return; S.review.done = k; S.review.total = n; S.review.phase = phase; renderReview(); } });
  if (!evals || !alive()) return;
  const mine = reviewSide(fens, moves, evals, S.my);
  const count = k => mine.filter(x => x.cls === k).length;
  const worst = mine.filter(x => x.cls && x.cls !== 'best' && x.drop >= 0.05).sort((a, b) => b.drop - a.drop).slice(0, 3);
  // 存成一份分析，點「看這一步」時分析頁直接讀，不用重算
  const aid = 'a' + S.id;
  try {
    await db.put('analyses', { id: aid, date: new Date().toISOString(), title: `你 vs Stockfish 等級 ${S.level}`, pgn: pgnText(), evals: evals.map(e => e && { score: e.score, best: e.best, pv: (e.pv || []).slice(0, 8), depth: e.depth }), result: (S.over || {}).result || '*', vars: [] });
    const rec = await db.get('games', S.id); if (rec) await db.put('games', { ...rec, analysisId: aid });
  } catch (e) { /* 存不了就算了 */ }
  S.review = { state: 'done', aid, blunder: count('blunder'), mistake: count('mistake'), inaccuracy: count('inaccuracy'), best: count('best'), n: mine.length, worst };
  renderReview();
}
function renderReview() {
  const box = ui.review; if (!box) return;
  const R = S.review;
  box.hidden = !R;
  box.innerHTML = '';
  if (!R) return;
  box.append(el('h2', {}, '對完自動復盤 ', el('small', {}, 'Stockfish')));
  if (R.state === 'running') {
    box.append(el('p', { class: 'small muted' }, el('span', { class: 'spinner', style: 'display:inline-block;vertical-align:middle' }), R.phase === 'recheck' ? `　複查失誤 ${R.done}…` : `　引擎正在看這盤棋… ${R.done} / ${R.total}`),
      el('div', { class: 'progress', style: 'margin-top:6px' }, el('div', { style: `width:${(R.done / R.total * 100).toFixed(0)}%` })));
    return;
  }
  const go = ply => app.go('analysis', { analysisId: R.aid, ply, flip: S.my === 'b' });
  box.append(el('div', { class: 'row small', style: 'gap:6px' },
    el('span', { class: 'tag best', style: 'padding:1px 6px;border-radius:4px' }, `★ 最佳 ${R.best}`),
    el('span', { class: 'tag inaccuracy', style: 'padding:1px 6px;border-radius:4px' }, `?! ${R.inaccuracy}`),
    el('span', { class: 'tag mistake', style: 'padding:1px 6px;border-radius:4px' }, `? ${R.mistake}`),
    el('span', { class: 'tag blunder', style: 'padding:1px 6px;border-radius:4px' }, `?? ${R.blunder}`),
    el('span', { class: 'muted' }, `（你走了 ${R.n} 步）`)));
  if (!R.worst.length) box.append(el('p', { class: 'small', style: 'margin-top:8px' }, '這盤你沒有明顯的失誤 👍'));
  else {
    const t = R.worst[0];
    box.append(el('p', { class: 'small', style: 'margin-top:8px' }, el('b', {}, '轉捩點：'), `第 ${Math.ceil(t.ply / 2)} 回合你走 `, el('b', { class: 'mono' }, t.san), t.best ? `，最好是 ` : '', t.best ? el('b', { class: 'mono' }, t.best) : '', `，勝率大約少了 ${Math.round(t.drop * 100)}%。`));
    const list = el('div', { class: 'list', style: 'margin-top:6px' });
    for (const w of R.worst) list.append(el('button', { type: 'button', class: 'item', onclick: () => go(w.ply) },
      el('span', { class: 'tag ' + w.cls, style: 'padding:1px 6px;border-radius:4px;font-size:.75rem' }, w.cls === 'blunder' ? '??' : w.cls === 'mistake' ? '?' : '?!'),
      el('div', { class: 'grow' }, el('b', { class: 'mono' }, `${Math.ceil(w.ply / 2)}${w.ply % 2 ? '.' : '…'} ${w.san}`), el('span', {}, w.best ? `最好是 ${w.best}・勝率 -${Math.round(w.drop * 100)}%` : `勝率 -${Math.round(w.drop * 100)}%`)),
      el('span', { class: 'small muted' }, '看這一步 →')));
    box.append(list);
  }
  box.append(el('div', { class: 'row', style: 'margin-top:8px' }, el('button', { type: 'button', class: 'btn sm', id: 'btn-review-open', onclick: () => go(R.worst[0] ? R.worst[0].ply : 0) }, '打開完整分析 →')));
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
  if (S.tc) g.setHeader('TimeControl', `${S.tc.base / 1000}+${S.tc.inc / 1000}`);
  return g.pgn();
}

async function save(final) {
  if (!S.g.history().length) return;
  const o = S.over || outcome(S.g);
  if (S.clock && !S.over) { const c = S.g.turn(); S.clock[c] = remaining(c); S.tickAt = performance.now(); }   // 存的時候把正在跑的時間算進去
  const rec = {
    id: S.id, date: new Date().toISOString(), pgn: pgnText(), mode: 'play', level: S.level, myColor: S.my,
    result: o ? o.result : '*', reason: o ? o.why : null,
    outcome: !o ? 'ongoing' : o.result === '1/2-1/2' ? 'draw' : ((o.result === '1-0') === (S.my === 'w') ? 'win' : 'loss'),
    moves: S.g.history().length,
    tc: S.tc ? S.tc.label : null, clock: S.clock ? { ...S.clock } : null,
  };
  try { await db.put('games', rec); if (final) app.toast('棋譜已存到「我的」'); } catch (e) { /* 存不了不影響下棋 */ }
}

function onMove(m) {
  if (S.view !== null || S.thinking || S.checking || S.coachWarn || S.over || outcome(S.g)) return false;
  const beforeFen = S.g.fen();
  let mv; try { mv = S.g.move(m); } catch (e) { return false; }
  charge(S.my);
  S.hint = null;
  if (coachOn() && !outcome(S.g)) { S.checking = true; sync(); coachCheck(beforeFen, mv); return true; }
  sync();
  maybeEngine();
  return true;
}

function undo() {
  S.token++; app.engine.stop(); S.thinking = false; S.hint = null;
  if (S.over && S.resigned) { S.over = null; S.resigned = false; }
  else if (S.over) S.over = null;
  // 退到輪到自己
  S.reviewTok++; S.review = null;
  S.g.undo(); if (S.clock && S.clockHist.length) S.clock = S.clockHist.pop();
  if (S.g.turn() !== S.my && S.g.history().length) { S.g.undo(); if (S.clock && S.clockHist.length) S.clock = S.clockHist.pop(); }
  S.tickAt = performance.now();
  S.view = null; S.checking = false; S.coachWarn = null; S.coachEval = null;
  sync();
  if (S.g.turn() !== S.my) maybeEngine(); else coachEvalPosition();
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
    S.pickTc = p.tc || '';
    const tcSel = el('select', { id: 'time-control', 'aria-label': '時間控制' });
    for (const [v, t] of TIME_CONTROLS) tcSel.append(el('option', { value: v, selected: v === S.pickTc }, t));
    tcSel.onchange = () => { S.pickTc = tcSel.value; setPref('tc', S.pickTc); app.toast('時間控制按「開新局」後生效'); };

    panel.append(el('div', { class: 'card' },
      el('h2', {}, '與電腦對弈 ', el('small', {}, 'Stockfish 18')),
      el('div', { class: 'row', style: 'margin-bottom:10px' }, colorSeg),
      el('label', { class: 'field' }, el('span', {}, '難度：', lvlTxt), lvl),
      el('label', { class: 'field', style: 'margin-top:8px' }, '每步最多思考', tm),
      el('label', { class: 'field', style: 'margin-top:8px' }, '時間控制（棋鐘）', tcSel),
      el('div', { class: 'row', style: 'margin-top:12px' },
        el('button', { type: 'button', class: 'btn primary', id: 'btn-new', onclick: () => newGame() }, '開新局'),
        el('button', { type: 'button', class: 'btn', onclick: loadFen }, '從 FEN 開始'),
        el('button', { type: 'button', class: 'btn', onclick: loadPgn }, '匯入 PGN')),
      el('p', { class: 'small muted', style: 'margin-top:8px' }, '難度是 Stockfish 的 Skill Level 加上搜尋深度上限；等級 10 是全力。有時間控制時，電腦也會照剩下的時間調整思考時間。換顏色、時間控制後按「開新局」生效。'),
    ));
    ui.status = el('div', { class: 'status', id: 'play-status' });
    ui.moves = el('div', { class: 'moves', id: 'play-moves' });
    ui.opening = el('p', { class: 'small muted', id: 'play-opening', style: 'margin:6px 0 0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis' });
    ui.undo = el('button', { type: 'button', class: 'btn', id: 'btn-undo', onclick: undo }, '↶ 悔棋');
    ui.hintBtn = el('button', { type: 'button', class: 'btn', id: 'btn-hint', onclick: hint }, '💡 提示');
    ui.resign = el('button', { type: 'button', class: 'btn danger', id: 'btn-resign', onclick: async () => {
      if (!(await app.confirm('確定要認輸嗎？', '這盤會記成輸棋。'))) return;
      S.token++; app.engine.stop(); S.thinking = false; S.resigned = true; S.over = outcome(S.g); await save(true); sync(); startReview();
    } }, '🏳 認輸');
    S.coach = !!p.coach;
    ui.coachBtn = el('button', { type: 'button', class: 'btn', id: 'btn-coach', 'aria-pressed': String(S.coach), title: '顯示評估；走出大錯時先提醒你', onclick: () => {
      S.coach = !S.coach; setPref('coach', S.coach); ui.coachBtn.setAttribute('aria-pressed', String(S.coach));
      if (!S.coach) { S.coachWarn = null; if (S.checking) { S.checking = false; maybeEngine(); } }
      sync(); coachEvalPosition();
    } }, '🧑‍🏫 教練');
    ui.coach = el('div', { class: 'coach', id: 'play-coach', hidden: true });
    ui.live = el('button', { type: 'button', class: 'btn sm', onclick: () => { S.view = null; sync(); } }, '回到目前局面');
    panel.prepend(el('div', { class: 'card' },
      ui.status, ui.opening,
      ui.coach,
      el('div', { class: 'row', style: 'margin:10px 0' }, ui.undo, ui.hintBtn, ui.coachBtn, ui.resign),
      el('div', { class: 'row spread', style: 'margin-bottom:6px' }, el('b', { class: 'small' }, '棋譜'), ui.live),
      ui.moves,
      el('div', { class: 'row', style: 'margin-top:10px' },
        el('button', { type: 'button', class: 'btn sm', id: 'btn-export', onclick: exportPgn }, '匯出 PGN'),
        el('button', { type: 'button', class: 'btn sm', id: 'btn-save', onclick: async () => { await save(false); app.toast('已存到「我的」'); } }, '儲存棋譜'),
        el('button', { type: 'button', class: 'btn sm', onclick: () => app.go('analysis', { pgn: pgnText(), flip: S.my === 'b' }) }, '用引擎分析這盤 →')),
    ));
    ui.review = el('div', { class: 'card', id: 'play-review', hidden: true });
    panel.children[0].after(ui.review);
    app.tools.append(
      el('button', { type: 'button', class: 'btn icon', id: 'btn-flip', title: '翻轉棋盤', 'aria-label': '翻轉棋盤', onclick: () => { app.board.flip(); sync(); } }, '⇅ 翻轉'),
      el('button', { type: 'button', class: 'btn icon', title: '上一步', 'aria-label': '上一步', onclick: () => { const n = S.g.history().length; const v = S.view === null ? n : S.view; if (v > 0) { S.view = v - 1; sync(); } } }, '◀'),
      el('button', { type: 'button', class: 'btn icon', title: '下一步', 'aria-label': '下一步', onclick: () => { const n = S.g.history().length; if (S.view !== null) { S.view = S.view + 1 >= n ? null : S.view + 1; sync(); } } }, '▶'),
    );
    app.use({ canMove: c => c === S.my && S.view === null && !S.thinking && !S.checking && !S.coachWarn && !S.over && !outcome(S.g), onMove });
    this._st = () => sync();
    this._tick = setInterval(tick, 200);
    app._play = S;   // 測試用：可以直接改剩下的時間
    app.engine.addEventListener('status', this._st);
    if (params.fen) { S.pick = new Chess(params.fen).turn(); newGame(params.fen); }
    else if (S.g && !params.fresh) {
      app.board.setFlipped(S.my === 'b'); sync(); maybeEngine();
      if (S.over && (!S.review || S.review.state === 'running')) startReview();   // 復盤跑到一半離開了：回來重跑
      else renderReview();
    }
    else { newGame(); resumeOrNew(); }
    app.engine.ready().catch(() => sync());
  },
  unmount() {
    S.token++; S.reviewTok++; app.engine.stop(); S.thinking = false;
    clearInterval(this._tick);
    app.engine.removeEventListener('status', this._st);
  },
};
