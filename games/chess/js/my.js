// 我的：對局紀錄、勝負統計、戰術正確率（分題型）、收藏、開局收藏、筆記、分析結果、JSON 備份與還原。
import { Chess } from '../vendor/chessjs/chess.js';
import { db, uid, backup, restore, checkBackup, persistent, STORES } from './store.js';
import { el, download, today } from './ui.js';
import { PUZZLES, THEMES } from './tactics.js';
import { OPENINGS } from '../data/openings.js';

let app, root;
const fmtDate = s => { const d = new Date(s); return isNaN(d) ? '' : `${d.getFullYear()}/${d.getMonth() + 1}/${d.getDate()} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };
const OUT = { win: '勝', loss: '負', draw: '和', ongoing: '…', unfinished: '…' };
const OUT_LONG = { win: '你贏了', loss: '你輸了', draw: '和棋', ongoing: '還沒下完', unfinished: '沒下完' };
const OUT_CLS = { win: 'win', loss: 'loss', draw: 'draw', ongoing: 'ongoing', unfinished: 'ongoing' };
const REASON = { checkmate: '將死', resign: '認輸', stalemate: '逼和', material: '子力不足', repetition: '三次重複', fifty: '50 步規則' };

async function render() {
  const [games, analyses, stats, attempts, favs, notes] = await Promise.all(['games', 'analyses', 'puzzleStats', 'attempts', 'favorites', 'notes'].map(s => db.all(s).catch(() => [])));
  root.innerHTML = '';
  const saved = await persistent();
  if (!saved) root.append(el('div', { class: 'status warn' }, '這個瀏覽器不讓網頁長期存資料（可能是無痕模式），紀錄只會保留到關閉分頁。可以用下面的「下載備份」自己存一份。'));

  // ── 總覽 ──
  const played = games.filter(g => g.outcome !== 'ongoing' && g.outcome !== 'unfinished');
  const w = played.filter(g => g.outcome === 'win').length, l = played.filter(g => g.outcome === 'loss').length, d = played.filter(g => g.outcome === 'draw').length;
  const pz = attempts.filter(a => a.puzzleId);
  const ok = pz.filter(a => a.ok).length;
  root.append(el('div', { class: 'card' },
    el('h2', {}, '我的西洋棋 ', el('small', {}, 'My Chess・資料只存在這台裝置')),
    el('div', { class: 'stats', id: 'my-overview' },
      el('div', { class: 'stat' }, el('b', { class: 'wdl' }, el('span', { class: 'w' }, `${w} 勝`), ' ', el('span', { class: 'd' }, `${d} 和`), ' ', el('span', { class: 'l' }, `${l} 負`)), el('span', {}, '對電腦的戰績')),
      el('div', { class: 'stat' }, el('b', {}, pz.length ? Math.round(ok / pz.length * 100) + '%' : '—'), el('span', {}, `戰術正確率（${pz.length} 次作答）`)),
      el('div', { class: 'stat' }, el('b', {}, stats.filter(s => s.solved > 0).length), el('span', {}, `解出的戰術題（共 ${PUZZLES.length}）`)),
      el('div', { class: 'stat' }, el('b', {}, attempts.filter(a => a.kind === 'endgame' && a.ok).length), el('span', {}, '殘局練習成功次數')),
    )));

  // ── 對局 ──
  const gl = el('div', { class: 'list', id: 'my-games' });
  if (!games.length) gl.append(el('p', { class: 'small muted' }, '還沒有對局。去「對弈」跟電腦下一盤吧！'));
  for (const g of games.sort((a, b) => b.date.localeCompare(a.date)).slice(0, 50)) {
    const oc = OUT_CLS[g.outcome] || 'ongoing';
    gl.append(el('div', { class: 'item game ' + oc },
      el('span', { class: 'res ' + oc, 'aria-label': OUT_LONG[g.outcome] || '未完' }, OUT[g.outcome] || '?'),
      el('div', { class: 'grow' },
        el('b', {}, `${OUT_LONG[g.outcome] || '未完'}${g.reason && REASON[g.reason] ? '・' + REASON[g.reason] : ''}`),
        el('span', {}, `你執${g.myColor === 'w' ? '白' : '黑'}・電腦等級 ${g.level}・${Math.ceil((g.moves || 0) / 2)} 回合・${g.result}・${fmtDate(g.date)}`)),
      el('button', { type: 'button', class: 'btn sm', onclick: () => app.go('analysis', { pgn: g.pgn, flip: g.myColor === 'b' }) }, '分析'),
      el('button', { type: 'button', class: 'btn sm', onclick: () => download(`game-${g.date.slice(0, 10)}.pgn`, g.pgn, 'application/x-chess-pgn') }, 'PGN'),
      el('button', { type: 'button', class: 'btn sm danger', 'aria-label': '刪除這盤', onclick: async () => { if (await app.confirm('刪除這盤棋？', '刪除後無法復原（除非你有備份）。', '刪除')) { await db.del('games', g.id); render(); } } }, '✕')));
  }
  root.append(el('div', { class: 'card' }, el('h2', {}, '對局紀錄 ', el('small', {}, `${games.length} 盤`)), gl));

  // ── 戰術：分題型正確率 ──
  const byTheme = el('div', { class: 'list', id: 'my-themes' });
  for (const [t, info] of Object.entries(THEMES)) {
    const xs = pz.filter(a => (a.themes || []).includes(t));
    const r = xs.length ? xs.filter(a => a.ok).length / xs.length : 0;
    byTheme.append(el('div', { class: 'bar-row' }, el('span', {}, info.name), el('div', { class: 'progress' }, el('div', { style: `width:${Math.round(r * 100)}%` })), el('span', { class: 'mono small' }, xs.length ? `${Math.round(r * 100)}%` : '—')));
  }
  const wrong = stats.filter(s => s.lastResult === 'fail').length;
  const favP = favs.filter(f => f.kind === 'puzzle');
  root.append(el('div', { class: 'card' }, el('h2', {}, '戰術紀錄'), byTheme,
    el('div', { class: 'row', style: 'margin-top:10px' },
      el('button', { type: 'button', class: 'btn', onclick: () => app.go('tactics', { filter: 'wrong' }) }, `✗ 錯題重練（${wrong}）`),
      el('button', { type: 'button', class: 'btn', onclick: () => app.go('tactics', { filter: 'fav' }) }, `★ 收藏的題目（${favP.length}）`))));

  // ── 開局收藏 ──
  const favO = favs.filter(f => f.kind === 'opening');
  const ol = el('div', { class: 'chips' });
  if (!favO.length) ol.append(el('p', { class: 'small muted' }, '在「開局」按 ☆ 收藏，這裡就會出現。'));
  for (const f of favO) { const o = OPENINGS.find(x => x.id === f.ref); if (o) ol.append(el('button', { type: 'button', class: 'chip', onclick: () => app.go('openings', { id: o.id }) }, o.name)); }
  root.append(el('div', { class: 'card' }, el('h2', {}, '收藏的開局'), ol));

  // ── 分析結果 ──
  const al = el('div', { class: 'list' });
  if (!analyses.length) al.append(el('p', { class: 'small muted' }, '在「分析」完成整盤分析後會自動存在這裡。'));
  for (const a of analyses.sort((x, y) => y.date.localeCompare(x.date)).slice(0, 30)) {
    al.append(el('div', { class: 'item' },
      el('div', { class: 'grow' }, el('b', {}, a.title), el('span', {}, `${fmtDate(a.date)}・${a.result}`)),
      el('button', { type: 'button', class: 'btn sm', onclick: () => app.go('analysis', { analysisId: a.id }) }, '打開'),
      el('button', { type: 'button', class: 'btn sm danger', 'aria-label': '刪除這份分析', onclick: async () => { await db.del('analyses', a.id); render(); } }, '✕')));
  }
  root.append(el('div', { class: 'card' }, el('h2', {}, '分析結果 ', el('small', {}, `${analyses.length} 份`)), al));

  // ── 筆記 ──
  const nl = el('div', { class: 'list', id: 'my-notes' });
  for (const n of notes.sort((a, b) => (b.updated || b.date).localeCompare(a.updated || a.date))) {
    const body = el('p', { class: 'small', style: 'white-space:pre-wrap;margin-top:4px' }); body.textContent = n.body;
    nl.append(el('div', { class: 'item', style: 'flex-direction:column;align-items:stretch' },
      el('div', { class: 'row spread' }, el('b', {}, n.title || '（沒有標題）'), el('span', { class: 'small muted' }, fmtDate(n.updated || n.date))),
      body,
      n.fen ? el('p', { class: 'small mono muted' }, n.fen) : null,
      el('div', { class: 'row' },
        el('button', { type: 'button', class: 'btn sm', onclick: () => editNote(n) }, '編輯'),
        n.fen ? el('button', { type: 'button', class: 'btn sm', onclick: () => app.go('analysis', { pgn: n.fen }) }, '看局面') : null,
        el('button', { type: 'button', class: 'btn sm danger', onclick: async () => { if (await app.confirm('刪除這則筆記？', n.title || '', '刪除')) { await db.del('notes', n.id); render(); } } }, '刪除'))));
  }
  if (!notes.length) nl.append(el('p', { class: 'small muted' }, '記下學到的東西：開局想法、常犯的錯、想研究的局面（可以附上 FEN）。'));
  root.append(el('div', { class: 'card' },
    el('div', { class: 'row spread' }, el('h2', { style: 'margin:0' }, '筆記'), el('button', { type: 'button', class: 'btn sm primary', id: 'my-add-note', onclick: () => editNote(null) }, '＋ 新筆記')),
    el('div', { style: 'margin-top:8px' }, nl)));

  // ── 備份 ──
  const file = el('input', { type: 'file', accept: '.json,application/json', hidden: true, id: 'my-restore-file' });
  file.onchange = async () => {
    const f = file.files[0]; file.value = ''; if (!f) return;
    let data;
    try { data = JSON.parse(await f.text()); } catch (e) { app.toast('這不是 JSON 檔', 3000); return; }
    const err = checkBackup(data);
    if (err) { app.toast('不能還原：' + err, 4000); return; }
    const n = Object.fromEntries(Object.keys(STORES).map(s => [s, (data.stores[s] || []).length]));
    const ok = await app.confirm('用這份備份取代目前的資料？', `備份時間 ${fmtDate(data.exportedAt)}：對局 ${n.games}、分析 ${n.analyses}、戰術紀錄 ${n.puzzleStats}、作答 ${n.attempts}、收藏 ${n.favorites}、筆記 ${n.notes}。目前的資料會被清掉。`, '還原');
    if (!ok) return;
    try { await restore(data, 'replace'); app.toast('還原完成'); render(); } catch (e) { app.toast('還原失敗：' + e.message, 4000); }
  };
  root.append(el('div', { class: 'card' },
    el('h2', {}, '備份與還原'),
    el('p', { class: 'small muted' }, '所有紀錄都存在這個瀏覽器的 IndexedDB，換手機、清除瀏覽資料前先下載備份。備份是一個 JSON 檔，包含對局、分析、戰術紀錄、收藏、筆記和偏好設定。'),
    el('div', { class: 'row', style: 'margin-top:8px' },
      el('button', { type: 'button', class: 'btn primary', id: 'my-backup', onclick: async () => { const b = await backup(); download(`jellyfish-chess-backup-${today().replace(/\./g, '')}.json`, JSON.stringify(b, null, 1), 'application/json'); } }, '下載備份（JSON）'),
      el('button', { type: 'button', class: 'btn', id: 'my-restore', onclick: () => file.click() }, '從備份還原'), file,
      el('button', { type: 'button', class: 'btn danger', onclick: async () => {
        if (!(await app.confirm('清除所有 Jellyfish Chess 的資料？', '對局、分析、戰術紀錄、收藏、筆記都會刪除，無法復原。建議先下載備份。', '全部清除'))) return;
        for (const s of Object.keys(STORES)) await db.clear(s);
        app.toast('已清除'); render();
      } }, '清除全部資料'))));
}

async function editNote(n) {
  const r = await app.dialog({
    title: n ? '編輯筆記' : '新筆記',
    fields: [
      { name: 'title', label: '標題', value: n ? n.title : '' },
      { name: 'body', label: '內容', type: 'textarea', rows: 6, value: n ? n.body : '' },
      { name: 'fen', label: '局面 FEN（可留空）', value: n ? (n.fen || '') : '' },
    ],
    ok: '儲存',
  });
  if (!r) return;
  const fen = r.fen.trim();
  if (fen) { try { new Chess(fen); } catch (e) { app.toast('FEN 格式不對，沒有存', 3000); return; } }
  const now = new Date().toISOString();
  await db.put('notes', { id: n ? n.id : uid('n'), date: n ? n.date : now, updated: now, title: r.title.trim(), body: r.body, fen });
  render();
}

export default {
  id: 'my', title: '我的', noBoard: true,
  mount(a) { app = a; root = app.panel; render(); },
};
