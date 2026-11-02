// 棋局分析：匯入 PGN → Stockfish 逐步評估 → 標出 Blunder／Mistake／Inaccuracy、最佳走法、變化、評估曲線。
import { Chess, DEFAULT_POSITION } from '../vendor/chessjs/chess.js';
import { fmtScore, whitePov, winChance, scoreNum } from './engine.js';
import { db, prefs, setPref, uid } from './store.js';
import { el, renderMoves, download, today, applyUci, pvToSan, fenProblem, openingLine } from './ui.js';

import { CLS, classify, terminalScore } from './review.js';
export { CLS, classify };

// vars：試走的支線 [{ start（從主線第幾個局面分出去）, moves:[{san,uci,color,from,to}], fens:[…] }]；vi／vp：目前在第幾條支線的第幾步（vi = -1 是主線）
const S = { vars: [], vi: -1, vp: 0, runTok: 0, shown: -1, userMoved: false, g: null, startFen: DEFAULT_POSITION, fens: [], moves: [], ply: 0, evals: [], running: false, live: true, liveTok: 0, id: null, headers: {} };
let app, ui = {};

function load(pgnOrFen, { id = null, evals = null, vars: savedVars = null } = {}) {
  const g = new Chess();
  const text = (pgnOrFen || '').trim();
  if (!text) throw new Error('沒有內容');
  if (/^[rnbqkpRNBQKP1-8]+(\/[rnbqkpRNBQKP1-8]+){7}\s+[wb]/.test(text)) { const bad = fenProblem(text); if (bad) throw new Error(bad); g.load(text); }
  else g.loadPgn(text);
  // 讀得懂才換：先停掉舊棋局的分析，免得舊的分數寫進新棋局（曲線會亂掉）
  if (S.running) { S.running = false; app.engine.stop(); }
  S.runTok++; S.hover = null;
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
  S.vars = []; S.vi = -1; S.vp = 0;
  for (const v of savedVars || []) {
    try {
      const c = new Chess(S.fens[v.start]); const nv = { start: v.start, moves: [], fens: [c.fen()] };
      for (const san of v.sans) { const mv = c.move(san); nv.moves.push({ san: mv.san, uci: mv.from + mv.to + (mv.promotion || ''), color: mv.color, from: mv.from, to: mv.to }); nv.fens.push(c.fen()); }
      if (nv.moves.length) S.vars.push(nv);
    } catch (e) { /* 存檔壞了就略過這條支線 */ }
  }
  const done = S.evals.filter(Boolean).length === S.fens.length;
  if (done) requestAnimationFrame(() => reserveInfo());
  if (ui.prog) { ui.prog.style.width = done ? '100%' : '0'; ui.progTxt.textContent = done ? '已載入存好的分析' : ''; ui.run.textContent = done ? '重新分析' : '整盤分析'; }
  render();
}

function posAt(i) { return new Chess(S.fens[i]); }
const inVar = () => S.vi >= 0 && S.vars[S.vi];
function curFen() { return inVar() ? S.vars[S.vi].fens[S.vp] : S.fens[S.ply]; }

// 按鈕：分析中就停止，否則開始
function runFull() {
  if (S.running) { S.running = false; S.runTok++; app.engine.stop(); return; }
  return startFull();
}
// 載入棋局後自動開始（使用者不用再按）；已經分析完的不重跑
function autoAnalyse() {
  if (!S.fens.length || S.evals.filter(Boolean).length === S.fens.length) return;   // 只有一個局面也會算它的評估
  if (S.running) { S.running = false; S.runTok++; app.engine.stop(); }
  startFull();
}
async function startFull() {
  const tok = ++S.runTok;
  const alive = () => S.running && tok === S.runTok;   // 換了一盤棋或按了停止，舊的分析就不要再寫回來
  S.running = true; S.liveTok++;
  const depth = +ui.depth.value; setPref('analysisDepth', depth);
  ui.progTxt.textContent = `分析中… 0 / ${S.fens.length}`;
  ui.run.textContent = '停止分析';
  for (let i = 0; i < S.fens.length && alive(); i++) {
    if (S.evals[i] && S.evals[i].depth >= depth) continue;
    const c = posAt(i);
    const t = terminalScore(c);
    if (t) { S.evals[i] = { score: t.white, best: null, pv: [], depth: 99 }; }
    else {
      const r = await app.engine.go({ fen: S.fens[i], depth, multipv: 1, skill: 20 });
      if (!alive()) return;
      const l = r.lines[0];
      S.evals[i] = { score: whitePov(l ? l.score : { cp: 0 }, c.turn()), best: r.best, pv: l ? l.pv : [], depth: l ? l.depth : depth };
    }
    ui.prog.style.width = ((i + 1) / S.fens.length * 100).toFixed(1) + '%';
    ui.progTxt.textContent = `分析中… ${i + 1} / ${S.fens.length}`;
    if (i % 3 === 0) renderMeta();
  }
  // 被標成 Mistake／Blunder 的步，用更深的深度再確認一次（淺層常看不到棄子殺棋之類的手段）
  if (alive() && S.evals.filter(Boolean).length === S.fens.length) {
    const deep = depth + 6;
    const suspects = tags().map((t, i) => (t && (t.cls === 'blunder' || t.cls === 'mistake') ? i : -1)).filter(i => i >= 0);
    let k = 0;
    for (const i of suspects) {
      for (const j of [i, i + 1]) {
        if (!alive()) return;
        if (S.evals[j].depth >= deep || terminalScore(posAt(j))) continue;
        ui.progTxt.textContent = `複查失誤 ${++k}…（深度 ${deep}）`;
        const r = await app.engine.go({ fen: S.fens[j], depth: deep, multipv: 1, skill: 20 });
        if (!alive()) return;
        const l = r.lines[0];
        if (l) S.evals[j] = { score: whitePov(l.score, posAt(j).turn()), best: r.best, pv: l.pv, depth: l.depth };
      }
    }
  }
  if (tok !== S.runTok) return;
  const complete = S.evals.filter(Boolean).length === S.fens.length;
  S.running = false;
  ui.run.textContent = complete ? '重新分析' : '繼續分析';
  ui.progTxt.textContent = complete ? `分析完成（深度 ${depth}）` : '已停止';
  if (complete) await saveAnalysis(false);
  render();
  reserveInfo();
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

// 評估曲線：縱軸是「白方領先幾個兵」（±5 兵以上畫在邊上），上半白色＝白方好、下半深色＝黑方好。
// 用實際像素畫（不拉伸），文字才不會變形；視窗大小改變時重畫。
const CLAMP = 5;
function pawns(s) {
  if (!s) return 0;
  if (s.mate !== undefined) return s.mate > 0 ? CLAMP : s.mate < 0 ? -CLAMP : 0;
  return Math.max(-CLAMP, Math.min(CLAMP, s.cp / 100));
}
export function evalWords(s) {
  if (!s) return '';
  if (s.mate !== undefined) return s.mate === 0 ? '' : (s.mate > 0 ? '白方' : '黑方') + `可以強迫將死（${Math.abs(s.mate)} 步殺）`;
  if (Math.abs(s.cp) >= 100000) return s.cp > 0 ? '白方將死' : '黑方將死';
  const a = Math.abs(s.cp), side = s.cp > 0 ? '白方' : '黑方';
  if (a < 50) return '差不多均勢';
  if (a < 150) return side + '稍好';
  if (a < 300) return side + '比較好';
  return side + '明顯優勢';
}
function chart() {
  const svg = ui.chart, n = S.fens.length;
  const W = Math.max(260, Math.round(svg.clientWidth || 340)), H = 150;
  const L = 30, R = 8, T = 8, B = 20;                 // 留給刻度文字的邊
  const pw = W - L - R, ph = H - T - B, mid = T + ph / 2;
  svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
  if (!S.evals.some(Boolean)) {
    svg.innerHTML = `<text x="${W / 2}" y="${H / 2}" text-anchor="middle" font-size="13" fill="currentColor" opacity="0.6">${S.running ? '分析中…' : '還沒有分析結果'}</text>`;
    ui.chartTip.textContent = '';
    return;
  }
  const x = i => L + (n <= 1 ? 0 : i / (n - 1) * pw);
  const y = v => mid - v / CLAMP * (ph / 2);
  const pts = [];
  for (let i = 0; i < n; i++) if (S.evals[i]) pts.push([x(i), y(pawns(S.evals[i].score)), i]);
  const line = pts.map((p, k) => `${k ? 'L' : 'M'}${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' ');
  const area = `M${pts[0][0].toFixed(1)} ${mid} ` + pts.map(p => `L${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' ') + ` L${pts[pts.length - 1][0].toFixed(1)} ${mid} Z`;
  const out = [];
  out.push(`<defs><clipPath id="cTop"><rect x="${L}" y="${T}" width="${pw}" height="${ph / 2}"/></clipPath><clipPath id="cBot"><rect x="${L}" y="${mid}" width="${pw}" height="${ph / 2}"/></clipPath></defs>`);
  out.push(`<rect x="${L}" y="${T}" width="${pw}" height="${ph}" fill="#8a8f99" opacity="0.12"/>`);
  out.push(`<path d="${area}" fill="#f4f1ea" clip-path="url(#cTop)"/><path d="${area}" fill="#2b2f36" clip-path="url(#cBot)"/>`);
  // 刻度：+5、+2、0、-2、-5
  for (const v of [CLAMP, 2, 0, -2, -CLAMP]) {
    out.push(`<line x1="${L}" x2="${L + pw}" y1="${y(v)}" y2="${y(v)}" stroke="currentColor" opacity="${v === 0 ? 0.55 : 0.15}" ${v === 0 ? '' : 'stroke-dasharray="3 4"'}/>`);
    out.push(`<text x="${L - 4}" y="${y(v) + 4}" text-anchor="end" font-size="10" fill="currentColor" opacity="0.7" font-family="Space Mono, monospace">${v > 0 ? '+' + v : v}</text>`);
  }
  out.push(`<text x="${L + 6}" y="${T + 13}" font-size="11" fill="currentColor" opacity="0.75">▲ 白方好</text>`);
  out.push(`<text x="${L + 6}" y="${T + ph - 5}" font-size="11" fill="currentColor" opacity="0.75">▼ 黑方好</text>`);
  // 橫軸：第幾回合
  const start = new Chess(S.startFen), no0 = start.moveNumber(), off = start.turn() === 'b' ? 1 : 0;
  const total = Math.ceil((n - 1 + off) / 2);
  const step = total <= 20 ? 5 : total <= 50 ? 10 : 20;
  for (let mv = Math.ceil(no0 / step) * step; mv < no0 + total; mv += step) {
    const ply = (mv - no0) * 2 + 1 - off;
    if (ply < 0 || ply >= n) continue;
    out.push(`<text x="${x(ply)}" y="${H - 5}" text-anchor="middle" font-size="10" fill="currentColor" opacity="0.6" font-family="Space Mono, monospace">${mv}</text>`);
  }
  out.push(`<path d="${line}" fill="none" stroke="#d9a441" stroke-width="2" stroke-linejoin="round"/>`);
  const t = tags();
  t.forEach((tg, i) => {
    if (!tg || tg.cls === 'best' || !S.evals[i + 1]) return;
    const c = tg.cls === 'blunder' ? '#dc2626' : tg.cls === 'mistake' ? '#ea580c' : '#ca8a04';
    out.push(`<circle cx="${x(i + 1)}" cy="${y(pawns(S.evals[i + 1].score))}" r="${tg.cls === 'blunder' ? 5.5 : 4.5}" fill="${c}" stroke="#fff" stroke-width="1.2"><title>${S.moves[i].san} ${tg.title}</title></circle>`);
  });
  // 目前這一步（或滑鼠指著的那一步）
  const cur = S.hover !== null && S.hover !== undefined ? S.hover : S.ply;
  out.push(`<line x1="${x(cur)}" x2="${x(cur)}" y1="${T}" y2="${T + ph}" stroke="#06b6d4" stroke-width="2"/>`);
  if (S.evals[cur]) out.push(`<circle cx="${x(cur)}" cy="${y(pawns(S.evals[cur].score))}" r="5" fill="#06b6d4" stroke="#fff" stroke-width="1.5"/>`);
  svg.innerHTML = out.join('');
  // 說明文字：第幾步、誰走了什麼、評估是多少、意思是什麼
  const ev = S.evals[cur];
  if (cur === 0) ui.chartTip.textContent = ev ? `開局局面：${fmtScore(ev.score)}，${evalWords(ev.score)}` : '';
  else {
    const m = S.moves[cur - 1];
    const no = no0 + Math.floor((cur - 1 + off) / 2);
    ui.chartTip.textContent = `${no}${m.color === 'w' ? '.' : '…'} ${m.san} 之後：` + (ev ? `${fmtScore(ev.score)}（${evalWords(ev.score)}）` : '還沒分析') + (t[cur - 1] && t[cur - 1].cls !== 'best' ? `　${t[cur - 1].title}` : '');
  }
}
function chartPly(e) {
  const r = ui.chart.getBoundingClientRect();
  const L = 30, R = 8, pw = r.width - L - R;
  return Math.max(0, Math.min(S.fens.length - 1, Math.round((e.clientX - r.left - L) / pw * (S.fens.length - 1))));
}

function renderMeta() { chart(); renderMoveList(); }
function renderMoveList() {
  renderMoves(ui.moves, S.moves.map(m => m.san), inVar() ? -1 : S.ply, p => go(p), { startTurn: new Chess(S.startFen).turn(), startNo: new Chess(S.startFen).moveNumber(), tags: tags() });
  // 每條支線插在它分出去的那一步所在的那一列後面（整列寬）
  S.vars.forEach((V, v) => {
    const box = el('div', { class: 'var', 'data-var': v });
    const start = new Chess(V.fens[0]);
    V.moves.forEach((m, i) => {
      const no = start.moveNumber() + Math.floor((i + (start.turn() === 'b' ? 1 : 0)) / 2);
      const label = (m.color === 'w' ? `${no}. ` : (i === 0 ? `${no}… ` : '')) + m.san;
      box.append(el('button', { type: 'button', class: 'vmv' + (S.vi === v && S.vp === i + 1 ? ' cur' : ''), 'data-vp': i + 1, onclick: () => goVar(v, i + 1) }, label));
    });
    box.append(el('button', { type: 'button', class: 'vdel', title: '刪除這條支線', 'aria-label': '刪除這條支線', onclick: () => deleteVar(v) }, '✕'));
    // 找到「分出去那一步」所在那一列的最後一格，插在它後面
    const cells = [...ui.moves.querySelectorAll('.mv[data-ply]')];
    let after = cells.find(b => +b.dataset.ply === V.start + 1) || cells.find(b => +b.dataset.ply === V.start) || null;
    if (after) {
      const ply = +after.dataset.ply;
      const nxt = cells.find(b => +b.dataset.ply === ply + 1);
      if (S.moves[ply - 1] && S.moves[ply - 1].color === 'w' && nxt) after = nxt;
      let n = after.nextSibling; while (n && n.classList && n.classList.contains('var')) { after = n; n = n.nextSibling; }
      after.after(box);
    } else ui.moves.append(box);
  });
  const c = ui.moves.querySelector('.vmv.cur');
  if (c) ui.moves.scrollTo({ top: Math.max(0, c.offsetTop - ui.moves.clientHeight / 2) });
}

function go(p) {
  S.vi = -1;
  S.ply = Math.max(0, Math.min(S.moves.length, p));
  render();
  startLive();
}
function goVar(v, i) {
  const V = S.vars[v]; if (!V) return go(S.ply);
  if (i <= 0) return go(V.start);                 // 支線退到起點 = 回到主線分出去的地方
  S.vi = v; S.vp = Math.min(V.moves.length, i); S.ply = V.start;
  render();
  startLive();
}
function step(d) { if (inVar()) goVar(S.vi, S.vp + d); else go(S.ply + d); }

// 某一步的說明（畫面上用，也拿來量最高的高度）
function buildInfo(info, ply) {
  info.innerHTML = '';
  if (!S.moves.length) info.append(el('p', { class: 'muted small' }, '這是一個局面（沒有棋步）。右邊「引擎」會列出最好的幾種走法，也可以在棋盤上自己走走看。'));
  else if (ply === 0) info.append(el('p', { class: 'muted small' }, '開局局面。點棋譜上的任一步，或用 ◀ ▶（鍵盤左右鍵）一步一步看。'));
  else {
    const i = ply - 1, m = S.moves[i], a = S.evals[i], b = S.evals[i + 1];
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
    } else info.append(head, el('p', { class: 'small muted' }, '還沒分析到這一步，分析中…'));
  }
}
// 支線上的說明：沒有整盤分析的分數，看右邊「引擎」的即時分析
function buildVarInfo(info) {
  const V = S.vars[S.vi];
  info.innerHTML = '';
  const start = new Chess(V.fens[0]);
  const parts = V.moves.slice(0, S.vp).map((m, i) => {
    const no = start.moveNumber() + Math.floor((i + (start.turn() === 'b' ? 1 : 0)) / 2);
    return (m.color === 'w' ? `${no}. ` : (i === 0 ? `${no}… ` : '')) + m.san;
  }).join(' ');
  const mainMove = S.moves[V.start];
  info.append(el('div', { class: 'row' }, el('b', {}, '試走的支線'), el('span', { class: 'tag var-tag' }, `第 ${S.vi + 1} 條`)),
    el('p', { class: 'small mono' }, parts),
    el('p', { class: 'small muted' }, mainMove ? `原本棋譜在這裡走的是 ${mainMove.san}。` : '原本棋譜到這裡就結束了。', '右邊「引擎」顯示這個局面的評估和最好的走法；按 ◀ 退回去，退到底就回到原本的棋譜。'));
}
// 每一步的說明長短不同：全部量一次，用最高的那個固定高度，換步時下面的卡片才不會跳
function reserveInfo() {
  const box = ui.info;
  if (!box.isConnected || !box.clientWidth) return;
  const probe = document.createElement('div');
  probe.className = box.className;
  // 放在同一張卡片裡量，字型大小等樣式才會一樣
  probe.style.cssText = `position:absolute;visibility:hidden;pointer-events:none;left:0;top:0;width:${box.clientWidth}px`;
  box.parentNode.appendChild(probe);
  let max = 0;
  for (let k = 0; k <= S.moves.length; k++) { buildInfo(probe, k); max = Math.max(max, probe.getBoundingClientRect().height); }
  probe.remove();
  box.style.minHeight = Math.ceil(max) + "px";
}

function render() {
  const V = inVar();
  const c = new Chess(curFen());
  app.setGame(c);
  const last = V ? (S.vp > 0 ? V.moves[S.vp - 1] : (S.ply > 0 ? S.moves[S.ply - 1] : null)) : (S.ply > 0 ? S.moves[S.ply - 1] : null);
  const key = V ? `v${S.vi}:${S.vp}` : `m${S.ply}`;
  const prevKey = S.shownKey; S.shownKey = key;
  // 往前一步才用滑的（主線或同一條支線），自己在棋盤上走的那步不用
  const stepAnim = !S.userMoved && (V ? prevKey === `v${S.vi}:${S.vp - 1}` || (S.vp === 1 && prevKey === `m${V.start}`) : prevKey === `m${S.ply - 1}`);
  S.userMoved = false;
  app.board.setLast(last, { animate: stepAnim });
  const ev = V ? null : S.evals[S.ply];
  const arrows = [];
  if (ev && ev.best) arrows.push({ from: ev.best.slice(0, 2), to: ev.best.slice(2, 4), color: 'rgba(34,197,94,0.75)' });
  app.board.setArrows(arrows);
  app.board.render();
  app.players({ white: S.headers.White || '白方', black: S.headers.Black || '黑方' });
  app.evalbar(ev ? ev.score : (S.liveScore && S.liveScore.key === key ? S.liveScore.s : undefined));
  if (V) buildVarInfo(ui.info); else buildInfo(ui.info, S.ply);
  openingLine(ui.opening, S.moves.map(m => m.san), S.startFen, (r, p) => app.go(r, p));
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
  const key = inVar() ? `v${S.vi}:${S.vp}` : `m${S.ply}`;
  ui.lines.innerHTML = ''; ui.lines.append(el('p', { class: 'small muted' }, el('span', { class: 'spinner', style: 'display:inline-block;vertical-align:middle' }), ' 引擎思考中…'));
  const show = lines => {
    if (tok !== S.liveTok) return;
    ui.lines.innerHTML = '';
    for (const l of lines) {
      const s = whitePov(l.score, turn);
      ui.lines.append(el('button', { type: 'button', class: 'ln', title: '在棋盤上顯示這條變化的第一步', onclick: () => app.board.setArrows([{ from: l.pv[0].slice(0, 2), to: l.pv[0].slice(2, 4), color: 'rgba(6,182,212,0.8)' }]) },
        el('b', {}, fmtScore(s)), el('span', {}, pvToSan(fen, l.pv, 10))));
    }
    if (lines[0]) { ui.depthTxt.textContent = `深度 ${lines[0].depth}`; S.liveScore = { key, s: whitePov(lines[0].score, turn) }; if (inVar() || !S.evals[S.ply]) app.evalbar(S.liveScore.s); }
  };
  await app.engine.go({ fen, depth: 20, multipv: 3, skill: 20, onInfo: show });
}

async function saveAnalysis(toast) {
  if (!S.moves.length) return;
  const rec = {
    id: S.id, date: new Date().toISOString(), title: `${S.headers.White || '白方'} vs ${S.headers.Black || '黑方'}`,
    pgn: S.g.pgn(), evals: S.evals.map(e => e && { score: e.score, best: e.best, pv: (e.pv || []).slice(0, 8), depth: e.depth }),
    result: S.headers.Result || '*',
    vars: S.vars.map(v => ({ start: v.start, sans: v.moves.map(m => m.san) })),
  };
  try { await db.put('analyses', rec); if (toast) app.toast('分析結果已存到「我的」'); } catch (e) { /* ignore */ }
}

// 自己在棋盤上走：跟棋譜一樣就往下走；不一樣就開一條支線（原本的棋譜和分析都保留）
function onMove(m) {
  const c = new Chess(curFen());
  let mv; try { mv = c.move(m); } catch (e) { return false; }
  const u = mv.from + mv.to + (mv.promotion || '');
  const rec = { san: mv.san, uci: u, color: mv.color, from: mv.from, to: mv.to };
  S.userMoved = true;
  const V = inVar();
  if (!V) {
    if (S.moves[S.ply] && S.moves[S.ply].uci === u) { go(S.ply + 1); return true; }
    const same = S.vars.findIndex(v => v.start === S.ply && v.moves[0].uci === u);
    if (same >= 0) { goVar(same, 1); return true; }
    S.vars.push({ start: S.ply, moves: [rec], fens: [S.fens[S.ply], c.fen()] });
    goVar(S.vars.length - 1, 1);
    return true;
  }
  if (V.moves[S.vp] && V.moves[S.vp].uci === u) { goVar(S.vi, S.vp + 1); return true; }
  // 在支線中間改走別的：後面的支線棋步換掉
  V.moves = V.moves.slice(0, S.vp).concat(rec); V.fens = V.fens.slice(0, S.vp + 1).concat(c.fen());
  goVar(S.vi, S.vp + 1);
  return true;
}
function deleteVar(v) {
  const V = S.vars[v]; if (!V) return;
  S.vars.splice(v, 1);
  if (S.vi === v) go(V.start); else { if (S.vi > v) S.vi--; render(); }
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
      try { load(ta.value); app.toast(`已載入 ${S.moves.length} 步，開始分析`); go(0); autoAnalyse(); }
      catch (e) { app.toast('讀不懂這份 PGN／FEN：' + e.message, 4000); }
    };
    ui.depth = el('select', { id: 'an-depth', 'aria-label': '分析深度', style: 'width:auto' });
    for (const d of [10, 12, 14, 16, 18]) ui.depth.append(el('option', { value: d, selected: d === p.analysisDepth }, `深度 ${d}${d <= 12 ? '（快）' : d >= 16 ? '（準，較慢）' : ''}`));
    // 換深度：用新的深度重新分析（已經夠深的步會跳過）
    ui.depth.onchange = () => { setPref('analysisDepth', +ui.depth.value); if (S.moves.length) { if (S.running) { S.running = false; S.runTok++; app.engine.stop(); } startFull(); } };
    ui.run = el('button', { type: 'button', class: 'btn', id: 'btn-analyse', onclick: runFull }, '整盤分析');
    ui.prog = el('div'); ui.progTxt = el('span', { class: 'small muted', id: 'an-progress' }, '');
    ui.chart = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    ui.chart.setAttribute('class', 'chart');
    ui.chart.setAttribute('role', 'img'); ui.chart.setAttribute('aria-label', '評估曲線：線在中線上方是白方好，下方是黑方好，離中線越遠優勢越大');
    ui.chartTip = el('p', { class: 'small mono', id: 'an-chart-tip', style: 'min-height:1.6em;margin-top:4px' });
    S.hover = null;
    // 不用 click：滑鼠移動時曲線會重畫，按下和放開之間元素換掉，click 就不會觸發
    let down = null;
    ui.chart.addEventListener('pointerdown', e => { down = { x: e.clientX, y: e.clientY }; });
    ui.chart.addEventListener('pointerup', e => {
      if (down && Math.hypot(e.clientX - down.x, e.clientY - down.y) < 10 && S.evals.some(Boolean)) { S.hover = null; go(chartPly(e)); }
      down = null;
    });
    ui.chart.addEventListener('pointermove', e => { if (e.pointerType !== 'mouse' || !S.evals.some(Boolean)) return; const p = chartPly(e); if (p !== S.hover) { S.hover = p; chart(); } });
    ui.chart.addEventListener('pointerleave', () => { if (S.hover !== null) { S.hover = null; chart(); } });
    this._ro = new ResizeObserver(() => { chart(); reserveInfo(); });
    this._ro.observe(ui.chart);
    ui.moves = el('div', { class: 'moves tall', id: 'an-moves' });
    ui.opening = el('p', { class: 'small muted', id: 'an-opening', style: 'margin:4px 0 0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis' });
    ui.info = el('div', { class: 'prose', id: 'an-info', style: 'min-height:9.5em' });   // 分析完後 reserveInfo() 改成實際量到的最高高度
    ui.sum = el('div', { class: 'stats', id: 'an-sum', style: 'margin-top:8px' });
    ui.lines = el('div', { class: 'lines', id: 'an-lines', style: 'min-height:6.6em' });
    ui.depthTxt = el('span', { class: 'small muted mono' });
    const liveBtn = el('button', { type: 'button', class: 'btn sm', 'aria-pressed': String(S.live), onclick: () => { S.live = !S.live; liveBtn.setAttribute('aria-pressed', String(S.live)); if (!S.live) app.engine.stop(); startLive(); } }, '即時分析');

    app.panel.append(
      // 最上面：這一步的說明＋分析進度（手機上不用捲過輸入框就看得到）
      el('div', { class: 'card' },
        el('div', { class: 'row spread', style: 'margin-bottom:8px' }, el('h2', { style: 'margin:0' }, '棋局分析 ', el('small', {}, 'Stockfish')), el('div', { class: 'row' }, ui.depth, ui.run)),
        el('div', { class: 'progress' }, ui.prog), ui.progTxt, ui.opening,
        el('div', { style: 'margin-top:8px' }, ui.info)),
      el('div', { class: 'card' },
        el('div', { class: 'row spread' }, el('h2', { style: 'margin:0' }, '引擎'), el('div', { class: 'row' }, ui.depthTxt, liveBtn)),
        ui.lines),
      el('div', { class: 'card' },
        el('h2', {}, '評估曲線'),
        el('p', { class: 'small muted', style: 'margin-bottom:6px' }, '線在中線上面＝白方好，下面＝黑方好；數字是領先幾個兵（+2 大約是多兩個兵）。點曲線可以跳到那一步，圓點是失誤。'),
        ui.chart, ui.chartTip,
        el('div', { class: 'row small muted', style: 'margin-top:6px;gap:10px' }, el('span', {}, '標記：'), el('span', { class: 'tag blunder', style: 'padding:0 5px;border-radius:4px' }, '?? Blunder'), el('span', { class: 'tag mistake', style: 'padding:0 5px;border-radius:4px' }, '? Mistake'), el('span', { class: 'tag inaccuracy', style: 'padding:0 5px;border-radius:4px' }, '?! Inaccuracy'), el('span', { class: 'tag best', style: 'padding:0 5px;border-radius:4px' }, '★ 最佳')),
        ui.sum,
        el('h3', {}, '棋譜'), ui.moves,
        el('div', { class: 'row', style: 'margin-top:8px' },
          el('button', { type: 'button', class: 'btn sm', onclick: () => saveAnalysis(true) }, '存到「我的」'),
          el('button', { type: 'button', class: 'btn sm', onclick: () => download(`analysis-${today()}.pgn`, annotatedPgn(), 'application/x-chess-pgn') }, '下載含評估的 PGN'),
          el('button', { type: 'button', class: 'btn sm', onclick: () => app.go('play', { fen: app.game.fen() }) }, '從這個局面跟電腦下 →'))),
      el('div', { class: 'card' },
        el('h2', {}, '載入其他棋局 ', el('small', {}, 'PGN／FEN')),
        ta,
        el('div', { class: 'row', style: 'margin-top:8px' },
          el('button', { type: 'button', class: 'btn', id: 'btn-load', onclick: doLoad }, '載入'),
          el('button', { type: 'button', class: 'btn', onclick: () => file.click() }, '開啟 .pgn 檔'),
          el('button', { type: 'button', class: 'btn sm', onclick: () => { ta.value = SAMPLE; doLoad(); } }, '範例：Morphy 歌劇院之局'), file),
        ),
    );

    ui.prog.style.width = '0';
    app.tools.append(
      el('button', { type: 'button', class: 'btn icon', title: '翻轉棋盤', 'aria-label': '翻轉棋盤', onclick: () => { app.board.flip(); S.flip = app.board.flipped; render(); } }, '⇅'),
      el('button', { type: 'button', class: 'btn icon', id: 'an-first', 'aria-label': '第一步', onclick: () => go(0) }, '⏮'),
      el('button', { type: 'button', class: 'btn icon', id: 'an-prev', 'aria-label': '上一步', onclick: () => step(-1) }, '◀'),
      el('button', { type: 'button', class: 'btn icon', id: 'an-next', 'aria-label': '下一步', onclick: () => step(1) }, '▶'),
      el('button', { type: 'button', class: 'btn icon', id: 'an-last', 'aria-label': '最後一步', onclick: () => go(S.moves.length) }, '⏭'),
    );
    this._key = e => {
      if (e.target.closest('input, textarea, select, [contenteditable]')) return;
      if (e.key === 'ArrowLeft') { step(-1); e.preventDefault(); }
      else if (e.key === 'ArrowRight') { step(1); e.preventDefault(); }
    };
    document.addEventListener('keydown', this._key);
    app.use({ canMove: () => true, onMove });   // 試走只會開支線，不影響正在跑的整盤分析
    // 棋盤方向：從別頁帶棋局進來時照你那一方；其他情況白方在下（不沿用上一頁翻過的方向）
    if (params.pgn || params.analysisId || !S.g) S.flip = !!params.flip;
    app.board.setFlipped(!!S.flip);   // 分析頁自己記方向，不沿用上一頁（例如執黑的戰術題）翻過的
    (async () => {
      if (params.analysisId) {
        const r = await db.get('analyses', params.analysisId);
        if (r) { ta.value = r.pgn; load(r.pgn, { id: r.id, evals: r.evals, vars: r.vars }); }
      } else if (params.pgn) { ta.value = params.pgn; try { load(params.pgn); } catch (e) { app.toast('PGN 讀不懂：' + e.message); } }
      else if (!S.g) { ta.value = SAMPLE; load(SAMPLE); }
      else ta.value = S.g.pgn();
      if (S.g && params.ply !== undefined) S.ply = params.ply;
      go(params.ply !== undefined ? params.ply : S.ply);
      autoAnalyse();
    })();
  },
  unmount() { S.running = false; S.runTok++; S.liveTok++; app.engine.stop(); document.removeEventListener('keydown', this._key); if (this._ro) this._ro.disconnect(); },
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
