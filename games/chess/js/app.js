// Jellyfish Chess：路由與共用介面。每個功能（對弈、戰術…）是一個模組，負責右側面板與棋盤要顯示什麼。
import { Chess } from '../vendor/chessjs/chess.js';
import { Board } from './board.js';
import { engine as sharedEngine } from './engine.js';
import { prefs } from './store.js';
export { capturedBy, renderMoves, el, download, copy, today, uciList, applyUci, pvToSan } from './ui.js';
import { capturedBy } from './ui.js';
import play from './play.js';
import analysis from './analysis.js';
import tactics from './tactics.js';
import openings from './openings.js';
import endgames from './endgames.js';
import my from './my.js';

const MODULES = { play, tactics, analysis, openings, endgames, my };
const $ = s => document.querySelector(s);

export const app = {
  board: null, panel: $('#panel'), tools: $('#tools'), main: $('#main'), wide: $('#wide'),
  ctl: null, route: null, params: {},
  engine: sharedEngine(),
  game: new Chess(),      // 目前棋盤顯示的局面（由各模組換掉）

  /** 模組設定棋盤要怎麼互動 */
  use(ctl) {
    this.ctl = ctl;
    this.board.sel = null;
    this.board.setArrows([]);
    this.board.setMarks({});
    this.board.render();
  },
  setGame(g) { this.game = g; this.board.sel = null; this.board.render(); },
  go(route, params = {}) {
    this.pending = params;
    if (location.hash.slice(1) === route) this.mount(route);
    else location.hash = route;
  },
  mount(route) {
    if (!MODULES[route]) route = 'play';
    const prev = this.route && MODULES[this.route];
    if (prev && prev.unmount) prev.unmount();
    this.route = route;
    const params = this.pending || {}; this.pending = null;
    for (const a of document.querySelectorAll('.cx-nav a')) {
      if (a.dataset.route === route) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current');
    }
    this.panel.innerHTML = ''; this.tools.innerHTML = ''; this.wide.innerHTML = ''; this.wide.hidden = true;
    this.main.classList.remove('sticky-panel');
    this.main.classList.toggle('no-board', !!MODULES[route].noBoard);
    this.evalbar(null);
    this.players(null);
    this.ctl = null;
    document.title = `${MODULES[route].title} - Jellyfish Chess 西洋棋`;
    MODULES[route].mount(this, params);
  },

  // ── 棋盤上下的玩家列（名稱＋吃掉的子） ──
  players(o) {
    const top = $('#p-top'), bot = $('#p-bottom');
    if (!o) { top.innerHTML = ''; bot.innerHTML = ''; return; }
    const g = this.game;
    const flipped = this.board.flipped;
    const [tc, bc] = flipped ? ['w', 'b'] : ['b', 'w'];
    const caps = capturedBy(g);
    const fill = (el, c) => {
      el.className = 'player' + (g.turn() === c && !g.isGameOver() ? ' turn' : '');
      el.innerHTML = '';
      const dot = document.createElement('span'); dot.className = 'dot ' + c;
      const who = document.createElement('span'); who.className = 'who'; who.textContent = (c === 'w' ? o.white : o.black) || (c === 'w' ? '白方' : '黑方');
      const cp = document.createElement('span'); cp.className = 'caps';
      for (const t of caps[c].list) {
        const im = document.createElement('img'); im.src = new URL(`../pieces/${c === 'w' ? 'b' : 'w'}${t.toUpperCase()}.svg`, import.meta.url).href; im.alt = '';
        cp.appendChild(im);
      }
      if (o.caps === false) { el.append(dot, who); return; }
      if (caps[c].adv > 0) { const b = document.createElement('b'); b.textContent = '+' + caps[c].adv; cp.appendChild(b); }
      el.append(dot, who, cp);
      if (o.clocks) { const k = document.createElement('span'); k.className = 'clock'; k.dataset.c = c; k.textContent = '–'; el.appendChild(k); }   // 時間由對弈頁每 0.2 秒更新
    };
    fill(top, tc); fill(bot, bc);
  },

  // ── 評估條 ──
  evalbar(score, flip) {
    const el = $('#evalbar');
    if (score === null) { el.hidden = true; return; }
    el.hidden = false;
    el.classList.toggle('flip', !!this.board.flipped);
    let pct = 50, txt = '';
    if (score) {
      if (score.mate !== undefined) { pct = score.mate > 0 ? 100 : (score.mate < 0 ? 0 : 50); txt = (score.mate > 0 ? 'M' : '-M') + Math.abs(score.mate); }
      else { const cp = Math.max(-1000, Math.min(1000, score.cp)); pct = 50 + 50 * (2 / (1 + Math.exp(-0.004 * cp)) - 1); txt = Math.abs(score.cp) >= 100000 ? '#' : (score.cp / 100).toFixed(1); }
    }
    el.style.setProperty('--pct', pct + '%');
    el.querySelector('span').textContent = txt;
  },

  toast(msg, ms = 2200) {
    const t = $('#toast'); t.textContent = msg; t.hidden = false;
    clearTimeout(this._tt); this._tt = setTimeout(() => { t.hidden = true; }, ms);
  },

  /** 簡單的對話框：fields = [{name,label,type:'textarea'|'text',value,placeholder}]，回傳值或 null */
  dialog({ title, body, fields = [], ok = '確定', cancel = '取消', extra }) {
    const d = $('#dlg');
    d.innerHTML = '';
    const form = document.createElement('form'); form.method = 'dialog';
    const h = document.createElement('h2'); h.textContent = title; form.appendChild(h);
    if (body) { const p = document.createElement('div'); p.className = 'small muted prose'; if (typeof body === 'string') p.textContent = body; else p.appendChild(body); form.appendChild(p); }
    const inputs = {};
    for (const f of fields) {
      const l = document.createElement('label'); l.className = 'field'; l.style.marginTop = '8px';
      const b = document.createElement('b'); b.textContent = f.label; l.appendChild(b);
      const i = document.createElement(f.type === 'textarea' ? 'textarea' : 'input');
      if (f.type !== 'textarea') i.type = 'text';
      i.name = f.name; i.value = f.value || ''; if (f.placeholder) i.placeholder = f.placeholder;
      if (f.rows) i.rows = f.rows;
      l.appendChild(i); form.appendChild(l); inputs[f.name] = i;
    }
    if (extra) form.appendChild(extra);
    const row = document.createElement('div'); row.className = 'row';
    if (cancel) { const c = document.createElement('button'); c.className = 'btn'; c.value = 'cancel'; c.textContent = cancel; row.appendChild(c); }
    const o = document.createElement('button'); o.className = 'btn primary'; o.value = 'ok'; o.textContent = ok; row.appendChild(o);
    form.appendChild(row); d.appendChild(form);
    return new Promise(res => {
      d.onclose = () => {
        if (d.returnValue !== 'ok') return res(null);
        const out = {}; for (const [k, i] of Object.entries(inputs)) out[k] = i.value; res(out);
      };
      d.returnValue = '';
      d.showModal();
      const first = form.querySelector('textarea, input'); if (first) first.focus();
    });
  },
  confirm(title, body, ok = '確定') { return this.dialog({ title, body, ok }).then(r => r !== null); },
};

// ── 啟動 ──
function start() {
  const p = prefs();
  app.board = new Board($('#board'), {
    getGame: () => app.game,
    canMove: c => (app.ctl && app.ctl.canMove ? app.ctl.canMove(c) : false),
    onMove: m => (app.ctl && app.ctl.onMove ? app.ctl.onMove(m) : false),
  });
  $('#board').classList.toggle('no-coords', !p.coords);
  window.addEventListener('hashchange', () => app.mount(location.hash.slice(1).split('?')[0]));
  app.mount(location.hash.slice(1).split('?')[0] || 'play');
  // 離線：Service Worker 把已經載入過的檔案（含引擎）留一份
  if ('serviceWorker' in navigator && location.protocol === 'https:' || location.hostname === 'localhost' || location.hostname === '127.0.0.1') {
    if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});
  }
  window.jfkChess = app;     // 測試與除錯用
}
start();
