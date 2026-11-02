// 戰術訓練：題目在 ../data/tactics.js（由 tools/chess/gen_tactics.mjs 產生、Stockfish 驗證）。
// 流程：先播對手的最後一步 → 你走 → 對了電腦回應 → … → 解完顯示解析。
// 走錯會退回並給提示；第一次就全對才算「答對」（影響正確率），用過「看答案」算錯，會進錯題本。
import { Chess } from '../vendor/chessjs/chess.js';
import { PUZZLES as OWN } from '../data/tactics.js';
import { LICHESS } from '../data/lichess.js';

// 自己用 Stockfish 產生的題目＋從 Lichess 題庫匯入的題目
const PUZZLES = [...OWN, ...LICHESS];
import { db, uid } from './store.js';
import { el, applyUci } from './ui.js';

export const THEMES = {
  fork: { name: '雙重攻擊', en: 'Fork', desc: '一個子同時攻擊兩個以上的目標（常常帶將軍），對手只能救一個。', tip: '找一個能同時打到兩個目標的位置，特別是馬和后。' },
  pin: { name: '牽制', en: 'Pin', desc: '攻擊一個子，它後面站著更值錢的子（或王），所以它不能、或不敢移開，接著就可以再加壓吃掉它。', tip: '看看對方哪個子跟王或后站在同一條線上。' },
  skewer: { name: '串擊', en: 'Skewer', desc: '跟牽制相反：前面是值錢的子（王或后），被攻擊後只能讓開，後面的子就露出來被吃掉。', tip: '用車、象或后沿著線攻擊對方的王或后，看它後面有什麼。' },
  discovered: { name: '閃擊', en: 'Discovered Attack', desc: '移動一個子，讓開後面我方車、象或后的線路；移動的子自己也能製造威脅，一次出現兩個攻擊。', tip: '你有沒有子擋在自己長程棋子的線上？把它移開，而且移到有威脅的地方。' },
  deflection: { name: '引離', en: 'Deflection', desc: '逼對方某個負責防守的子離開崗位（通常用將軍或棄子），它原本守住的格子或子就失守了。', tip: '對方哪個子身兼重任？逼它離開。' },
  defender: { name: '消除保護者', en: 'Removing the Defender', desc: '先吃掉保護某個目標的子，目標就沒人保護了，下一步再把它吃掉。', tip: '先找出你想吃的目標，再看是誰在保護它。' },
  mate: { name: '殺王', en: 'Checkmate', desc: '找出強迫將死的走法：每一步都要讓對方別無選擇。', tip: '先看將軍的走法，特別是讓對方王沒有空格可逃的那種。' },
  defense: { name: '防守戰術', en: 'Defensive Tactics', desc: '對手剛製造了威脅，大部分走法都會輸掉很多，只有一步能化解。先想想對手想幹嘛。', tip: '對手下一步想做什麼？找出能同時擋住威脅、又不丟子的走法。' },
};
const ORDER = Object.keys(THEMES);
const NAME = { p: '兵', n: '馬', b: '象', r: '車', q: '后', k: '王' };

const S = { filter: 'all', p: null, g: null, step: 1, mistakes: 0, hints: 0, done: false, revealed: false, stats: {}, favs: new Set(), busy: false, tok: 0 };
let app, ui = {};

async function loadStats() {
  const rows = await db.all('puzzleStats').catch(() => []);
  S.stats = Object.fromEntries(rows.map(r => [r.id, r]));
  const favs = await db.all('favorites').catch(() => []);
  S.favs = new Set(favs.filter(f => f.kind === 'puzzle').map(f => f.ref));
}
const solMoves = p => p.moves.split(' ');
function pool(filter) {
  if (filter === 'fav') return PUZZLES.filter(p => S.favs.has(p.id));
  if (filter === 'wrong') return PUZZLES.filter(p => S.stats[p.id] && S.stats[p.id].lastResult === 'fail');
  if (filter === 'all') return PUZZLES;
  return PUZZLES.filter(p => p.themes.includes(filter));
}
function pickNext() {
  const list = pool(S.filter).filter(p => !S.p || p.id !== S.p.id || pool(S.filter).length === 1);
  if (!list.length) return null;
  const fresh = list.filter(p => !S.stats[p.id]);
  if (S.filter !== 'wrong' && fresh.length) {
    fresh.sort((a, b) => a.level - b.level || a.id.localeCompare(b.id));
    const lv = fresh[0].level;
    const same = fresh.filter(p => p.level === lv);
    return same[Math.floor(Math.random() * same.length)];
  }
  return list[Math.floor(Math.random() * list.length)];
}

function start(p) {
  S.tok++;
  S.p = p; S.step = 1; S.mistakes = 0; S.hints = 0; S.done = false; S.revealed = false; S.busy = true;
  S.g = new Chess(p.fen);
  app.board.setFlipped(p.side === 'b');
  app.setGame(S.g); app.board.setLast(null); app.board.setArrows([]); app.board.setMarks({});
  app.players({ white: p.side === 'w' ? '你' : '對手', black: p.side === 'b' ? '你' : '對手' });
  ui.explain.hidden = true;
  renderHead();
  setStatus('看對手怎麼走…', '');
  const tok = S.tok;
  setTimeout(() => {
    if (tok !== S.tok) return;
    const m = applyUci(S.g, solMoves(p)[0]);
    app.board.setLast(m, { animate: true }); app.board.render(); app.players({ white: p.side === 'w' ? '你' : '對手', black: p.side === 'b' ? '你' : '對手' });
    S.busy = false;
    setStatus(`輪到你（${p.side === 'w' ? '白' : '黑'}）：找出最好的一步`, '');
    renderHead();
  }, 650);
}

function setStatus(text, cls) { ui.status.className = 'status' + (cls ? ' ' + cls : ''); ui.status.textContent = text; }

function renderHead() {
  const p = S.p; if (!p) return;
  ui.title.textContent = `題目 ${p.id.replace(/^(jc|li)/, '#')}`;
  const showTheme = S.done || (S.filter !== 'all' && S.filter !== 'fav' && S.filter !== 'wrong');
  ui.themes.innerHTML = '';
  ui.themes.append(el('span', { class: 'small muted' }, '難度 ', '★'.repeat(p.level) + '☆'.repeat(3 - p.level), '　'));
  if (showTheme) for (const t of p.themes) ui.themes.append(el('span', { class: 'eco', style: 'margin-right:4px' }, THEMES[t].name));
  else ui.themes.append(el('span', { class: 'small muted' }, '題型解完才公布'));
  ui.fav.textContent = S.favs.has(p.id) ? '★ 已收藏' : '☆ 收藏';
  ui.fav.setAttribute('aria-pressed', String(S.favs.has(p.id)));
  const st = S.stats[p.id];
  ui.source.innerHTML = '';
  if (p.src === 'lichess') ui.source.append('來源：', el('a', { href: `https://lichess.org/training/${p.id.slice(2)}`, target: '_blank', rel: 'noopener' }, `Lichess 題庫 #${p.id.slice(2)}`), `（Lichess 難度 ${p.rating}，CC0）`);
  ui.record.textContent = st ? `你做過 ${st.tries} 次，最近一次${st.lastResult === 'ok' ? '答對' : '答錯'}` : '第一次做這題';
}

async function onMove(m) {
  if (S.busy || S.done) return false;
  const p = S.p, sol = solMoves(p);
  const want = sol[S.step];
  const before = S.g.fen();
  let mv; try { mv = S.g.move(m); } catch (e) { return false; }
  const u = mv.from + mv.to + (mv.promotion || '');
  const last = S.step === sol.length - 1;
  const ok = u === want || (last && S.g.isCheckmate());
  if (!ok) {
    S.mistakes++;
    app.board.setLast(mv); app.board.setMarks({ [mv.to]: 'bad' }); app.board.render();
    S.busy = true;
    const tok = S.tok;
    setStatus(`✗ ${mv.san} 不是最好的一步，再想想。`, 'bad');
    setTimeout(() => {
      if (tok !== S.tok) return;
      S.g.load(before); app.setGame(S.g);
      const lm = new Chess(p.fen); const prev = sol.slice(0, S.step).map(x => applyUci(lm, x)).pop();
      app.board.setLast(prev); app.board.setMarks({}); app.board.render();
      S.busy = false;
      if (S.mistakes === 1) showHint(1);
    }, 700);
    return true;
  }
  app.board.setMarks({ [mv.to]: 'good' });
  app.board.setLast(mv); app.board.render();
  S.step++;
  if (S.step >= sol.length) { finish(true); return true; }
  // 對手回應
  S.busy = true;
  setStatus(`✓ ${mv.san}！對手回應中…`, 'good');
  const tok = S.tok;
  setTimeout(() => {
    if (tok !== S.tok) return;
    const r = applyUci(S.g, sol[S.step]); S.step++;
    app.board.setLast(r, { animate: true }); app.board.setMarks({}); app.setGame(S.g); app.board.render();
    app.players({ white: p.side === 'w' ? '你' : '對手', black: p.side === 'b' ? '你' : '對手' });
    S.busy = false;
    setStatus(`對手走 ${r.san}。繼續，找下一步！`, '');
  }, 550);
  return true;
}

function showHint(level) {
  const p = S.p; if (!p || S.done) return;
  const sol = solMoves(p), want = sol[S.step];
  S.hints = Math.max(S.hints, level);
  if (level === 1) {
    const t = THEMES[p.themes[0]];
    setStatus(`💡 提示：${S.step === 1 ? p.hint + '。' : ''}${t.tip}`, 'warn');
  } else if (level === 2) {
    const piece = S.g.get(want.slice(0, 2));
    app.board.setMarks({ [want.slice(0, 2)]: 'hint' });
    setStatus(`💡 提示：動 ${want.slice(0, 2)} 的${NAME[piece.type]}`, 'warn');
  }
}

async function reveal() {
  if (S.done || S.busy) return;
  S.revealed = true; S.busy = true;
  const sol = solMoves(S.p);
  const tok = S.tok;
  while (S.step < sol.length) {
    const u = sol[S.step];
    app.board.setArrows([{ from: u.slice(0, 2), to: u.slice(2, 4), color: 'rgba(6,182,212,0.8)' }]);
    await new Promise(r => setTimeout(r, 700));
    if (tok !== S.tok) return;
    const m = applyUci(S.g, u); S.step++;
    app.board.setLast(m, { animate: true }); app.board.setArrows([]); app.setGame(S.g); app.board.render();
  }
  S.busy = false;
  finish(false);
}

async function finish(solved) {
  S.done = true;
  const p = S.p;
  const clean = solved && S.mistakes === 0 && S.hints === 0 && !S.revealed;
  setStatus(clean ? '✓ 答對了！' : solved ? '✓ 解出來了（有走錯或用了提示，這次記為答錯，會放進錯題本）' : '看完答案了，這題放進錯題本', clean ? 'good' : 'warn');
  // 記錄
  const st = S.stats[p.id] || { id: p.id, tries: 0, solved: 0, fails: 0 };
  st.tries++; if (clean) st.solved++; else st.fails++;
  st.lastResult = clean ? 'ok' : 'fail'; st.lastDate = new Date().toISOString();
  if (st.firstTry === undefined) st.firstTry = clean;
  S.stats[p.id] = st;
  try {
    await db.put('puzzleStats', st);
    await db.put('attempts', { id: uid('t'), puzzleId: p.id, date: st.lastDate, ok: clean, themes: p.themes, mistakes: S.mistakes, hints: S.hints, revealed: S.revealed });
  } catch (e) { /* ignore */ }
  renderHead(); renderFilters(); renderStats();
  // 解析
  const ex = ui.explain; ex.hidden = false; ex.innerHTML = '';
  ex.append(el('h2', {}, '解析'));
  ex.append(el('p', { class: 'small' }, `對手剛走了 `, el('b', { class: 'mono' }, p.last), `，輪到${p.side === 'w' ? '白' : '黑'}方（你）。`));
  const steps = el('div', { class: 'explain' });
  const start = new Chess(p.fen); const turn0 = start.turn(); const no0 = start.moveNumber();
  let ply = 1;
  for (const n of p.notes) {
    const idx = ply; ply++;
    const color = (idx % 2 === 1) === (turn0 === 'w') ? 'b' : 'w';
    const no = no0 + Math.floor((idx + (turn0 === 'b' ? 1 : 0)) / 2);
    steps.append(el('div', { class: 'st ' + n.who }, el('b', {}, `${no}${color === 'w' ? '.' : '…'} ${n.san}`), el('span', {}, (n.who === 'me' ? '' : '對手：') + n.text)));
  }
  ex.append(steps, el('p', { class: 'small', style: 'margin-top:8px' }, p.summary));
  for (const t of p.themes) ex.append(el('p', { class: 'small muted', style: 'margin-top:6px' }, el('b', {}, `${THEMES[t].name}（${THEMES[t].en}）`), '：' + THEMES[t].desc));
  ex.append(el('div', { class: 'row', style: 'margin-top:10px' },
    el('button', { type: 'button', class: 'btn primary', id: 'pz-next', onclick: next }, '下一題 →'),
    el('button', { type: 'button', class: 'btn', onclick: () => start(p) }, '再做一次'),
    el('button', { type: 'button', class: 'btn sm', onclick: () => {
      const g = new Chess(p.fen); applyUci(g, solMoves(p)[0]);
      app.go('analysis', { pgn: g.fen() });
    } }, '用引擎研究這個局面')));
}

function next() {
  const p = pickNext();
  if (!p) {
    setStatus(S.filter === 'wrong' ? '錯題本是空的 🎉 沒有需要重練的題目' : S.filter === 'fav' ? '還沒有收藏的題目' : '這一類沒有題目', 'good');
    S.p = null; S.g = new Chess(); app.setGame(S.g); ui.explain.hidden = true; ui.title.textContent = '戰術訓練'; ui.themes.innerHTML = ''; ui.record.textContent = '';
    return;
  }
  start(p);
}

function renderFilters() {
  ui.filters.innerHTML = '';
  const add = (key, label, n) => ui.filters.append(el('button', { type: 'button', class: 'chip', 'data-filter': key, 'aria-pressed': String(S.filter === key), onclick: () => { S.filter = key; renderFilters(); next(); } }, label, el('span', { class: 'n' }, n)));
  add('all', '全部', PUZZLES.length);
  for (const t of ORDER) add(t, THEMES[t].name, pool(t).length);
  add('fav', '★ 收藏', pool('fav').length);
  add('wrong', '✗ 錯題重練', pool('wrong').length);
}
function renderStats() {
  const st = Object.values(S.stats);
  const tries = st.reduce((a, s) => a + s.tries, 0), ok = st.reduce((a, s) => a + s.solved, 0);
  ui.stats.innerHTML = '';
  ui.stats.append(
    el('div', { class: 'stat' }, el('b', { id: 'pz-acc' }, tries ? Math.round(ok / tries * 100) + '%' : '—'), el('span', {}, '正確率（每次作答）')),
    el('div', { class: 'stat' }, el('b', {}, st.filter(s => s.solved > 0).length + ' / ' + PUZZLES.length), el('span', {}, '解出過的題目')),
    el('div', { class: 'stat' }, el('b', {}, pool('wrong').length), el('span', {}, '錯題本')),
  );
}

export default {
  id: 'tactics', title: '戰術',
  async mount(a, params) {
    app = a;
    ui.filters = el('div', { class: 'chips', id: 'pz-filters' });
    ui.stats = el('div', { class: 'stats', id: 'pz-stats' });
    ui.title = el('h2', { id: 'pz-title' }, '戰術訓練');
    ui.themes = el('div', { class: 'row', id: 'pz-themes', style: 'margin-bottom:8px' });
    ui.status = el('div', { class: 'status', id: 'pz-status' }, '載入中…');
    ui.record = el('p', { class: 'small muted', style: 'margin-top:6px' });
    ui.source = el('p', { class: 'small muted', id: 'pz-source' });
    ui.fav = el('button', { type: 'button', class: 'btn sm', id: 'pz-fav', onclick: async () => {
      if (!S.p) return;
      const id = 'puzzle:' + S.p.id;
      if (S.favs.has(S.p.id)) { S.favs.delete(S.p.id); await db.del('favorites', id).catch(() => {}); }
      else { S.favs.add(S.p.id); await db.put('favorites', { id, kind: 'puzzle', ref: S.p.id, date: new Date().toISOString() }).catch(() => {}); }
      renderHead(); renderFilters();
    } }, '☆ 收藏');
    ui.explain = el('div', { class: 'card', id: 'pz-explain', hidden: true });
    // 題目卡放最上面（手機上不用往下捲就看得到狀態）
    app.panel.append(
      el('div', { class: 'card' },
        el('div', { class: 'row spread' }, ui.title, ui.fav), ui.themes, ui.status, ui.record, ui.source,
        el('div', { class: 'row', style: 'margin-top:10px' },
          el('button', { type: 'button', class: 'btn', id: 'pz-hint', onclick: () => showHint(Math.min(2, S.hints + 1)) }, '💡 提示'),
          el('button', { type: 'button', class: 'btn', id: 'pz-reveal', onclick: reveal }, '看答案'),
          el('button', { type: 'button', class: 'btn', id: 'pz-skip', onclick: next }, '換一題'))),
      ui.explain,
      el('div', { class: 'card' },
        el('h2', {}, '題型 ', el('small', {}, `${PUZZLES.length} 題・Stockfish 驗證`)),
        ui.filters, el('div', { style: 'margin-top:10px' }, ui.stats)),
      el('details', { class: 'card more' }, el('summary', {}, '這些題目從哪裡來？'),
        el('p', { class: 'small muted' }, '用 Stockfish 18 自我對弈，從實際出現的局面裡找「只有一步能贏（或只有一步不會輸）」的時刻，再用深度 18 逐步驗證：你的每一步都必須是唯一好棋，而且最後真的拿到子力或將死。題型是照棋盤上的事實判斷的（例如走完後同一個子攻擊兩個目標＝雙重攻擊）。最後一步如果是將死，任何能將死的走法都算對。'),
        LICHESS.length ? el('p', { class: 'small muted', style: 'margin-top:6px' }, `另外 ${LICHESS.length} 題來自 `, el('a', { href: 'https://database.lichess.org/#puzzles', target: '_blank', rel: 'noopener' }, 'Lichess 公開題庫'), '（CC0）：真人對局裡出現的戰術，挑熱門、被做過上千次的題目，再用 Stockfish 確認答案。題目卡上會標出 Lichess 題號和難度分數。') : null),
    );
    app.tools.append(el('button', { type: 'button', class: 'btn icon', title: '翻轉棋盤', 'aria-label': '翻轉棋盤', onclick: () => app.board.flip() }, '⇅ 翻轉'));
    app.use({ canMove: c => !!S.p && !S.busy && !S.done && c === S.p.side, onMove });
    await loadStats();
    if (params.filter) S.filter = params.filter;
    renderFilters(); renderStats();
    const want = params.puzzle && PUZZLES.find(p => p.id === params.puzzle);
    if (want) start(want);
    else if (S.p && !S.done) start(S.p);
    else next();
  },
  unmount() { S.tok++; },
};
export { PUZZLES };
