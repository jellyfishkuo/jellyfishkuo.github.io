// 棋局分析：匯入 PGN → Stockfish 逐步評估 → 標出 Blunder／Mistake／Inaccuracy、最佳走法、變化、評估曲線。
import { Chess, DEFAULT_POSITION } from '../vendor/chessjs/chess.js';
import { fmtScore, whitePov, winChance, scoreNum } from './engine.js';
import { db, prefs, setPref, uid } from './store.js';
import { el, renderMoves, download, today, applyUci, pvToSan, fenProblem } from './ui.js';

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
  void k;
  for (const c of CLS) if (drop >= c.min) return { ...c, drop };
  return null;
}

const S = { g: null, startFen: DEFAULT_POSITION, fens: [], moves: [], ply: 0, evals: [], running: false, live: true, liveTok: 0, id: null, headers: {} };
let app, ui = {};

function load(pgnOrFen, { id = null, evals = null } = {}) {
  const g = new Chess();
  const text = (pgnOrFen || '').trim();
  if (!text) throw new Error('沒有內容');
  if (/^[rnbqkpRNBQKP1-8]+(\/[rnbqkpRNBQKP1-8]+){7}\s+[wb]/.test(text)) { const bad = fenProblem(text); if (bad) throw new Error(bad); g.load(text); }
  else g.loadPgn(text);
  S.headers = g.getHeaders();
  S.startFen = S.headers.FEN || (g.history().length ? DEFAULT_POSITION : g.fen());
  const replay = new Chess(S.startFen);
  S.fens = [replay.fen()]; S.moves = [];
  for (const m of g.history({ verbose: true })) {
    const mv = replay.move(m.san);
    S.moves.push({ san: mv.san, uci: mv.from + mv.to + (mv.promotion || ''), color: mv.color, from: mv.from, to: mv.to });
    S.fens.push(replay.fen());
  }
  S.g = g; S.id = id || uid('a'); S.evals = evals || []; S.ply = 0;
  const done = S.evals.filter(Boolean).length === S.fens.length;
  if (ui.prog) { ui.prog.style.width = done ? '100%' : '0'; ui.progTxt.textContent = done ? '已載入存好的分析' : ''; ui.run.textContent = done ? '重新分析' : '整盤分析'; }
  render();
}

function posAt(i) { return new Chess(S.fens[i]); }
function terminalScore(c) {
  if (c.isCheckmate()) return { mate: 0, white: c.turn() === 'w' ? { cp: -100000 } : { cp: 100000 } };
  if (c.isStalemate() || c.isInsufficientMaterial() || c.isDrawByFiftyMoves()) return { white: { cp: 0 } };
  return null;
}

async function runFull() {
  if (S.running) { S.running = false; app.engine.stop(); return; }
  S.running = true; S.liveTok++;
  const depth = +ui.depth.value; setPref('analysisDepth', depth);
  ui.run.textContent = '停止分析';
  for (let i = 0; i < S.fens.length && S.running; i++) {
    if (S.evals[i] && S.evals[i].depth >= depth) continue;
    const c = posAt(i);
    const t = terminalScore(c);
    if (t) { S.evals[i] = { score: t.white, best: null, pv: [], depth: 99 }; }
    else {
      const r = await app.engine.go({ fen: S.fens[i], depth, multipv: 1, skill: 20 });
      if (!S.running && r.stopped) break;
      const l = r.lines[0];
      S.evals[i] = { score: whitePov(l ? l.score : { cp: 0 }, c.turn()), best: r.best, pv: l ? l.pv : [], depth: l ? l.depth : depth };
    }
    ui.prog.style.width = ((i + 1) / S.fens.length * 100).toFixed(1) + '%';
    ui.progTxt.textContent = `分析中… ${i + 1} / ${S.fens.length}`;
    if (i % 3 === 0) renderMeta();
  }
  const complete = S.evals.filter(Boolean).length === S.fens.length;
  S.running = false;
  ui.run.textContent = complete ? '重新分析' : '整盤分析';
  ui.progTxt.textContent = complete ? `分析完成（深度 ${depth}）` : '已停止';
  if (complete) await saveAnalysis(false);
  render();
  startLive();
}

function tags() {
  return S.moves.map((m, i) => {
    const a = S.evals[i], b = S.evals[i + 1];
    if (!a || !b) return null;
    const c = classify(a.score, b.score, m.color, a.best, m.uci);
    return c ? { cls: c.key, label: c.label, title: c.name } : null;
  });
}

function summary() {
  const t = tags();
  const out = { w: { blunder: 0, mistake: 0, inaccuracy: 0, best: 0, loss: 0, n: 0 }, b: { blunder: 0, mistake: 0, inaccuracy: 0, best: 0, loss: 0, n: 0 } };
  S.moves.forEach((m, i) => {
    const a = S.evals[i], b = S.evals[i + 1];
    if (!a || !b) return;
    const s = out[m.color];
    if (t[i]) s[t[i].cls]++;
    const k = m.color === 'w' ? 1 : -1;
    const clamp = v => Math.max(-1000, Math.min(1000, v));
    s.loss += Math.max(0, clamp(k * scoreNum(a.score)) - clamp(k * scoreNum(b.score)));
    s.n++;
  });
  return out;
}

function chart() {
  const n = S.fens.length;
  const W = 1000, H = 130;
  const svg = ui.chart;
  if (!S.evals.some(Boolean)) { svg.innerHTML = `<text x="500" y="70" text-anchor="middle" font-size="22" fill="currentColor" opacity="0.5">按「整盤分析」後這裡會畫出評估曲線</text>`; return; }
  const x = i => (n <= 1 ? 0 : i / (n - 1) * W);
  const y = s => H - winChance(s) * H;
  let d = `M0 ${H / 2}`;
  const pts = [];
  for (let i = 0; i < n; i++) if (S.evals[i]) pts.push([x(i), y(S.evals[i].score)]);
  d = `M0 ${H} ` + pts.map(p => `L${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' ') + ` L${pts[pts.length - 1][0].toFixed(1)} ${H} Z`;
  const t = tags();
  const dots = t.map((tg, i) => tg && tg.cls !== 'best' && S.evals[i + 1] ? `<circle cx="${x(i + 1)}" cy="${y(S.evals[i + 1].score)}" r="7" class="cls ${tg.cls}" fill="${tg.cls === 'blunder' ? '#dc2626' : tg.cls === 'mistake' ? '#ea580c' : '#ca8a04'}"><title>${S.moves[i].san} ${tg.title}</title></circle>` : '').join('');
  svg.innerHTML = `<path d="${d}" fill="#e8e8e8" opacity="0.9"/><line class="mid" x1="0" x2="${W}" y1="${H / 2}" y2="${H / 2}" stroke-dasharray="6 6"/>`
    + `<line x1="${x(S.ply)}" x2="${x(S.ply)}" y1="0" y2="${H}" stroke="#06b6d4" stroke-width="3"/>` + dots;
}

function renderMeta() { chart(); renderMoveList(); }
function renderMoveList() {
  renderMoves(ui.moves, S.moves.map(m => m.san), S.ply, p => go(p), { startTurn: new Chess(S.startFen).turn(), startNo: new Chess(S.startFen).moveNumber(), tags: tags() });
}

function go(p) {
  S.ply = Math.max(0, Math.min(S.moves.length, p));
  render();
  startLive();
}

function render() {
  const c = posAt(S.ply);
  app.setGame(c);
  const last = S.ply > 0 ? S.moves[S.ply - 1] : null;
  app.board.setLast(last);
  const ev = S.evals[S.ply];
  const arrows = [];
  if (ev && ev.best) arrows.push({ from: ev.best.slice(0, 2), to: ev.best.slice(2, 4), color: 'rgba(34,197,94,0.75)' });
  app.board.setArrows(arrows);
  app.board.render();
  app.players({ white: S.headers.White || '白方', black: S.headers.Black || '黑方' });
  app.evalbar(ev ? ev.score : (S.liveScore && S.liveScore.ply === S.ply ? S.liveScore.s : undefined));
  // 這一步的說明
  const info = ui.info; info.innerHTML = '';
  if (!S.moves.length) info.append(el('p', { class: 'muted small' }, '這是一個局面（沒有棋步）。可以開「即時分析」看引擎怎麼想，或在棋盤上自己走走看。'));
  else if (S.ply === 0) info.append(el('p', { class: 'muted small' }, '開局局面。點棋譜上的任一步，或用 ◀ ▶（鍵盤左右鍵）一步一步看。'));
  else {
    const i = S.ply - 1, m = S.moves[i], a = S.evals[i], b = S.evals[i + 1];
    const no = Math.floor((new Chess(S.startFen).moveNumber() * 2 + (new Chess(S.startFen).turn() === 'b' ? 1 : 0) + i) / 2);
    const head = el('div', { class: 'row' }, el('b', { class: 'mono' }, `${no}${m.color === 'w' ? '.' : '…'} ${m.san}`));
    if (a && b) {
      const c2 = classify(a.score, b.score, m.color, a.best, m.uci);
      if (c2) head.append(el('span', { class: 'tag ' + c2.key, style: 'padding:1px 6px;border-radius:5px;font-size:.78rem;font-weight:700' }, c2.name));
      info.append(head,
        el('p', { class: 'small' }, '實際走法：', el('b', { class: 'mono' }, m.san), `（走完評估 ${fmtScore(b.score)}）`),
        a.best ? el('p', { class: 'small' }, '最佳走法：', el('b', { class: 'mono' }, sanOf(S.fens[i], a.best)), `（評估 ${fmtScore(a.score)}）`) : '',
        a.pv && a.pv.length ? el('p', { class: 'small muted' }, '引擎建議的變化：', el('span', { class: 'mono' }, pvToSan(S.fens[i], a.pv, 8))) : '',
        c2 && c2.drop ? el('p', { class: 'small muted' }, `這步讓${m.color === 'w' ? '白' : '黑'}方的勝率大約少了 ${Math.round(c2.drop * 100)}%。`) : '');
    } else info.append(head, el('p', { class: 'small muted' }, '還沒分析這一步。按「整盤分析」。'));
  }
  renderMeta();
  // 總結
  const sm = ui.sum; sm.innerHTML = '';
  if (S.evals.filter(Boolean).length === S.fens.length && S.moves.length) {
    const s = summary();
    for (const c of ['w', 'b']) {
      const x = s[c];
      sm.append(el('div', { class: 'stat' },
        el('span', {}, c === 'w' ? `白方 ${S.headers.White || ''}` : `黑方 ${S.headers.Black || ''}`),
        el('b', {}, x.n ? Math.round(x.loss / x.n) : 0), el('span', {}, '平均每步損失（centipawn）'),
        el('div', { class: 'small', style: 'margin-top:4px' },
          el('span', { class: 'tag blunder', style: 'padding:0 4px;border-radius:4px' }, `?? ${x.blunder}`), ' ',
          el('span', { class: 'tag mistake', style: 'padding:0 4px;border-radius:4px' }, `? ${x.mistake}`), ' ',
          el('span', { class: 'tag inaccuracy', style: 'padding:0 4px;border-radius:4px' }, `?! ${x.inaccuracy}`))));
    }
  }
}
function sanOf(fen, u) { const c = new Chess(fen); const m = applyUci(c, u); return m ? m.san : u; }

// ── 即時分析（目前局面，MultiPV 3） ──
async function startLive() {
  const tok = ++S.liveTok;
  if (!S.live || S.running) { ui.lines.innerHTML = ''; if (!S.live) ui.lines.append(el('p', { class: 'small muted' }, '即時分析已關閉')); return; }
  const c = app.game;
  if (c.isGameOver()) { ui.lines.innerHTML = ''; ui.lines.append(el('p', { class: 'small muted' }, c.isCheckmate() ? '將死，對局結束' : '和棋局面')); return; }
  const fen = c.fen(), turn = c.turn();
  const ply = S.ply;
  ui.lines.innerHTML = ''; ui.lines.append(el('p', { class: 'small muted' }, el('span', { class: 'spinner', style: 'display:inline-block;vertical-align:middle' }), ' 引擎思考中…'));
  const show = lines => {
    if (tok !== S.liveTok) return;
    ui.lines.innerHTML = '';
    for (const l of lines) {
      const s = whitePov(l.score, turn);
      ui.lines.append(el('button', { type: 'button', class: 'ln', title: '在棋盤上顯示這條變化的第一步', onclick: () => app.board.setArrows([{ from: l.pv[0].slice(0, 2), to: l.pv[0].slice(2, 4), color: 'rgba(6,182,212,0.8)' }]) },
        el('b', {}, fmtScore(s)), el('span', {}, pvToSan(fen, l.pv, 10))));
    }
    if (lines[0]) { ui.depthTxt.textContent = `深度 ${lines[0].depth}`; S.liveScore = { ply, s: whitePov(lines[0].score, turn) }; if (!S.evals[S.ply]) app.evalbar(S.liveScore.s); }
  };
  await app.engine.go({ fen, depth: 20, multipv: 3, skill: 20, onInfo: show });
}

async function saveAnalysis(toast) {
  if (!S.moves.length) return;
  const rec = {
    id: S.id, date: new Date().toISOString(), title: `${S.headers.White || '白方'} vs ${S.headers.Black || '黑方'}`,
    pgn: S.g.pgn(), evals: S.evals.map(e => e && { score: e.score, best: e.best, pv: (e.pv || []).slice(0, 8), depth: e.depth }),
    result: S.headers.Result || '*',
  };
  try { await db.put('analyses', rec); if (toast) app.toast('分析結果已存到「我的」'); } catch (e) { /* ignore */ }
}

// 自己在棋盤上走：從目前局面開一條新的「試走」線（取代後面的棋步）
function onMove(m) {
  const c = posAt(S.ply);
  let mv; try { mv = c.move(m); } catch (e) { return false; }
  const u = mv.from + mv.to + (mv.promotion || '');
  if (S.moves[S.ply] && S.moves[S.ply].uci === u) { go(S.ply + 1); return true; }
  // 改走別的：截斷後面的棋步
  S.moves = S.moves.slice(0, S.ply); S.fens = S.fens.slice(0, S.ply + 1); S.evals = S.evals.slice(0, S.ply + 1);
  S.moves.push({ san: mv.san, uci: u, color: mv.color, from: mv.from, to: mv.to });
  S.fens.push(c.fen());
  const g = new Chess(S.startFen); for (const x of S.moves) g.move(x.san);
  for (const [k, v] of Object.entries(S.headers)) if (k !== 'Result') g.setHeader(k, v);
  S.g = g;
  go(S.ply + 1);
  return true;
}

const SAMPLE = `[Event "Paris Opera"]
[Site "Paris FRA"]
[Date "1858.11.02"]
[White "Paul Morphy"]
[Black "Duke Karl / Count Isouard"]
[Result "1-0"]

1. e4 e5 2. Nf3 d6 3. d4 Bg4 4. dxe5 Bxf3 5. Qxf3 dxe5 6. Bc4 Nf6 7. Qb3 Qe7 8. Nc3 c6 9. Bg5 b5 10. Nxb5 cxb5 11. Bxb5+ Nbd7 12. O-O-O Rd8 13. Rxd7 Rxd7 14. Rd1 Qe6 15. Bxd7+ Nxd7 16. Qb8+ Nxb8 17. Rd8# 1-0`;

export default {
  id: 'analysis', title: '分析',
  mount(a, params) {
    app = a;
    const p = prefs();
    const ta = el('textarea', { id: 'pgn-in', rows: 5, placeholder: '貼上 PGN（或 FEN）…', 'aria-label': 'PGN 或 FEN' });
    const file = el('input', { type: 'file', accept: '.pgn,.txt,text/plain', hidden: true, id: 'pgn-file' });
    file.onchange = async () => { const f = file.files[0]; if (!f) return; ta.value = await f.text(); doLoad(); file.value = ''; };
    const doLoad = () => {
      try { S.running = false; load(ta.value); app.toast(`已載入 ${S.moves.length} 步`); go(0); }
      catch (e) { app.toast('讀不懂這份 PGN／FEN：' + e.message, 4000); }
    };
    ui.depth = el('select', { id: 'an-depth', 'aria-label': '分析深度' });
    for (const d of [10, 12, 14, 16, 18]) ui.depth.append(el('option', { value: d, selected: d === p.analysisDepth }, `深度 ${d}${d <= 12 ? '（快）' : d >= 16 ? '（準，較慢）' : ''}`));
    ui.run = el('button', { type: 'button', class: 'btn primary', id: 'btn-analyse', onclick: runFull }, '整盤分析');
    ui.prog = el('div'); ui.progTxt = el('span', { class: 'small muted', id: 'an-progress' }, '');
    ui.chart = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    ui.chart.setAttribute('class', 'chart'); ui.chart.setAttribute('viewBox', '0 0 1000 130'); ui.chart.setAttribute('preserveAspectRatio', 'none');
    ui.chart.setAttribute('role', 'img'); ui.chart.setAttribute('aria-label', '評估分數圖表：白色面積越大白方越好');
    ui.chart.addEventListener('click', e => { const r = ui.chart.getBoundingClientRect(); go(Math.round((e.clientX - r.left) / r.width * (S.fens.length - 1))); });
    ui.moves = el('div', { class: 'moves tall', id: 'an-moves' });
    ui.info = el('div', { class: 'prose', id: 'an-info' });
    ui.sum = el('div', { class: 'stats', id: 'an-sum', style: 'margin-top:8px' });
    ui.lines = el('div', { class: 'lines', id: 'an-lines' });
    ui.depthTxt = el('span', { class: 'small muted mono' });
    const liveBtn = el('button', { type: 'button', class: 'btn sm', 'aria-pressed': String(S.live), onclick: () => { S.live = !S.live; liveBtn.setAttribute('aria-pressed', String(S.live)); if (!S.live) app.engine.stop(); startLive(); } }, '即時分析');

    app.panel.append(
      el('div', { class: 'card' },
        el('h2', {}, '棋局分析 ', el('small', {}, 'PGN + Stockfish')),
        ta,
        el('div', { class: 'row', style: 'margin-top:8px' },
          el('button', { type: 'button', class: 'btn', id: 'btn-load', onclick: doLoad }, '載入'),
          el('button', { type: 'button', class: 'btn', onclick: () => file.click() }, '開啟 .pgn 檔'),
          el('button', { type: 'button', class: 'btn sm', onclick: () => { ta.value = SAMPLE; doLoad(); } }, '範例：Morphy 歌劇院之局'), file),
        el('div', { class: 'row', style: 'margin-top:10px' }, ui.depth, ui.run),
        el('div', { class: 'progress', style: 'margin-top:8px' }, ui.prog), ui.progTxt),
      el('div', { class: 'card' },
        el('div', { class: 'row spread' }, el('h2', { style: 'margin:0' }, '引擎'), el('div', { class: 'row' }, ui.depthTxt, liveBtn)),
        ui.lines),
      el('div', { class: 'card' }, ui.info),
      el('div', { class: 'card' },
        el('h2', {}, '評估曲線'), ui.chart,
        el('div', { class: 'row small muted', style: 'margin-top:6px;gap:10px' }, el('span', {}, '標記：'), el('span', { class: 'tag blunder', style: 'padding:0 5px;border-radius:4px' }, '?? Blunder'), el('span', { class: 'tag mistake', style: 'padding:0 5px;border-radius:4px' }, '? Mistake'), el('span', { class: 'tag inaccuracy', style: 'padding:0 5px;border-radius:4px' }, '?! Inaccuracy'), el('span', { class: 'tag best', style: 'padding:0 5px;border-radius:4px' }, '★ 最佳')),
        ui.sum,
        el('h3', {}, '棋譜'), ui.moves,
        el('div', { class: 'row', style: 'margin-top:8px' },
          el('button', { type: 'button', class: 'btn sm', onclick: () => saveAnalysis(true) }, '存到「我的」'),
          el('button', { type: 'button', class: 'btn sm', onclick: () => download(`analysis-${today()}.pgn`, annotatedPgn(), 'application/x-chess-pgn') }, '下載含評估的 PGN'),
          el('button', { type: 'button', class: 'btn sm', onclick: () => app.go('play', { fen: app.game.fen() }) }, '從這個局面跟電腦下 →'))),
    );
    ui.prog.style.width = '0';
    app.tools.append(
      el('button', { type: 'button', class: 'btn icon', title: '翻轉棋盤', 'aria-label': '翻轉棋盤', onclick: () => { app.board.flip(); render(); } }, '⇅'),
      el('button', { type: 'button', class: 'btn icon', id: 'an-first', 'aria-label': '第一步', onclick: () => go(0) }, '⏮'),
      el('button', { type: 'button', class: 'btn icon', id: 'an-prev', 'aria-label': '上一步', onclick: () => go(S.ply - 1) }, '◀'),
      el('button', { type: 'button', class: 'btn icon', id: 'an-next', 'aria-label': '下一步', onclick: () => go(S.ply + 1) }, '▶'),
      el('button', { type: 'button', class: 'btn icon', id: 'an-last', 'aria-label': '最後一步', onclick: () => go(S.moves.length) }, '⏭'),
    );
    this._key = e => {
      if (e.target.closest('input, textarea, select, [contenteditable]')) return;
      if (e.key === 'ArrowLeft') { go(S.ply - 1); e.preventDefault(); }
      else if (e.key === 'ArrowRight') { go(S.ply + 1); e.preventDefault(); }
    };
    document.addEventListener('keydown', this._key);
    app.use({ canMove: () => !S.running, onMove });
    (async () => {
      if (params.analysisId) {
        const r = await db.get('analyses', params.analysisId);
        if (r) { ta.value = r.pgn; load(r.pgn, { id: r.id, evals: r.evals }); }
      } else if (params.pgn) { ta.value = params.pgn; try { load(params.pgn); } catch (e) { app.toast('PGN 讀不懂：' + e.message); } }
      else if (!S.g) { ta.value = SAMPLE; load(SAMPLE); }
      else ta.value = S.g.pgn();
      if (S.g && params.ply !== undefined) S.ply = params.ply;
      go(params.ply !== undefined ? params.ply : S.ply);
    })();
  },
  unmount() { S.running = false; S.liveTok++; app.engine.stop(); document.removeEventListener('keydown', this._key); },
};

function annotatedPgn() {
  const g = new Chess(S.startFen);
  for (const [k, v] of Object.entries(S.headers)) g.setHeader(k, v);
  const t = tags();
  S.moves.forEach((m, i) => {
    g.move(m.san);
    const e = S.evals[i + 1];
    if (e) {
      let txt = `[%eval ${e.score.mate !== undefined ? '#' + e.score.mate : (e.score.cp / 100).toFixed(2)}]`;
      if (t[i] && t[i].cls !== 'best') txt += ` ${t[i].title}；最佳是 ${sanOf(S.fens[i], S.evals[i].best)}`;
      g.setComment(txt);
    }
  });
  g.setHeader('Annotator', 'Jellyfish Chess（Stockfish 18）');
  return g.pgn();
}
