// Stockfish 18（WebAssembly，單執行緒精簡版）跑在 Web Worker 裡，不會卡住畫面。
// 檔案在 ../vendor/stockfish/，路徑用 import.meta.url 算，放在任何子路徑底下都找得到。
// 同一時間只跑一個搜尋：新的搜尋進來會先 stop 舊的，等它回 bestmove 再開始。
const ENGINE_URL = new URL('../vendor/stockfish/stockfish-18-lite-single.js', import.meta.url).href;

// 難度：Stockfish 的 Skill Level（0～20）加上深度上限。數字越大越強。
export const LEVELS = [
  null,
  { skill: 0, depth: 1, label: '1・剛學會走' },
  { skill: 1, depth: 2, label: '2・初學' },
  { skill: 3, depth: 3, label: '3・入門' },
  { skill: 5, depth: 5, label: '4・休閒' },
  { skill: 7, depth: 7, label: '5・社團' },
  { skill: 10, depth: 9, label: '6・進階' },
  { skill: 13, depth: 11, label: '7・強' },
  { skill: 16, depth: 14, label: '8・很強' },
  { skill: 19, depth: 18, label: '9・大師' },
  { skill: 20, depth: 0, label: '10・全力' },
];

export class StockfishEngine extends EventTarget {
  constructor(url = ENGINE_URL) {
    super();
    this.url = url;
    this.worker = null;
    this.state = 'idle';        // idle → loading → ready | error
    this.queue = Promise.resolve();
    this.current = null;
    this.listeners = new Set();
    this._ready = null;
  }
  emit(type, detail) { this.dispatchEvent(new CustomEvent(type, { detail })); }

  ready() {
    if (this._ready) return this._ready;
    this.state = 'loading'; this.emit('status', this.state);
    this._ready = new Promise((resolve, reject) => {
      let w;
      try { w = new Worker(this.url); } catch (e) { this.fail(e); reject(e); return; }
      this.worker = w;
      const timer = setTimeout(() => { const e = new Error('Stockfish 載入逾時'); this.fail(e); reject(e); }, 60000);
      w.onerror = e => { clearTimeout(timer); const err = new Error(e.message || 'Stockfish 載入失敗'); this.fail(err); reject(err); };
      w.onmessage = e => {
        const line = typeof e.data === 'string' ? e.data : '';
        for (const l of [...this.listeners]) l(line);
      };
      this.waitLine(l => l === 'uciok').then(() => {
        this.post('setoption name Hash value 32');
        this.post('isready');
        return this.waitLine(l => l === 'readyok');
      }).then(() => {
        clearTimeout(timer);
        this.state = 'ready'; this.emit('status', this.state); resolve(this);
      });
      this.post('uci');
    });
    return this._ready;
  }
  fail(e) { this.state = 'error'; this.error = e; this.emit('status', this.state); }
  post(cmd) { this.worker.postMessage(cmd); }
  waitLine(pred, onLine) {
    return new Promise(res => {
      const f = line => { if (onLine) onLine(line); if (pred(line)) { this.listeners.delete(f); res(line); } };
      this.listeners.add(f);
    });
  }

  /** 停掉正在跑的搜尋（結果會照常回傳，但會被標記 stopped） */
  stop() { if (this.current) { this.current.stopped = true; this.post('stop'); } }

  /**
   * 搜尋一個局面。
   * @param {object} o fen, moves(uci 陣列), movetime(ms), depth, multipv, skill(0~20), onInfo(lines)
   * @returns {Promise<{best, ponder, lines, stopped}>} lines[i] = {multipv, depth, score:{cp}|{mate}, pv:[uci]}（輪到走的一方的觀點）
   */
  go(o) {
    // 新的搜尋：先叫舊的停下來
    this.stop();
    const run = async () => {
      await this.ready();
      const job = { stopped: false }; this.current = job;
      this.post(`setoption name Skill Level value ${o.skill ?? 20}`);
      this.post(`setoption name MultiPV value ${o.multipv || 1}`);
      this.post(`position fen ${o.fen}${o.moves && o.moves.length ? ' moves ' + o.moves.join(' ') : ''}`);
      const parts = ['go'];
      if (o.depth) parts.push('depth', o.depth);
      if (o.movetime) parts.push('movetime', o.movetime);
      if (!o.depth && !o.movetime) parts.push('infinite');
      const lines = {};
      let lastEmit = 0;
      const done = this.waitLine(l => l.startsWith('bestmove'), l => {
        if (!l.startsWith('info') || l.indexOf(' pv ') < 0 || l.includes('bound')) return;
        const info = parseInfo(l);
        if (!info) return;
        lines[info.multipv] = info;
        const now = performance.now();
        if (o.onInfo && now - lastEmit > 120) { lastEmit = now; o.onInfo(sorted(lines)); }
      });
      this.post(parts.join(' '));
      const line = await done;
      this.current = null;
      const t = line.split(' ');
      const res = { best: t[1] === '(none)' ? null : t[1], ponder: t[3] || null, lines: sorted(lines), stopped: job.stopped };
      if (o.onInfo) o.onInfo(res.lines);
      return res;
    };
    const p = this.queue.then(run, run);
    this.queue = p.catch(() => {});
    return p;
  }
  newGame() { if (this.worker) this.post('ucinewgame'); }
}

function sorted(lines) { return Object.values(lines).sort((a, b) => a.multipv - b.multipv); }
export function parseInfo(l) {
  const t = l.split(' ');
  const g = k => { const i = t.indexOf(k); return i >= 0 ? t[i + 1] : undefined; };
  const si = t.indexOf('score'); if (si < 0) return null;
  const score = t[si + 1] === 'mate' ? { mate: +t[si + 2] } : { cp: +t[si + 2] };
  return { multipv: +(g('multipv') || 1), depth: +g('depth'), nodes: +(g('nodes') || 0), score, pv: t.slice(t.indexOf('pv') + 1) };
}

// ── 分數工具 ──
/** 轉成白方觀點 */
export function whitePov(score, turn) {
  if (!score) return null;
  const k = turn === 'w' ? 1 : -1;
  return score.mate !== undefined ? { mate: score.mate * k } : { cp: score.cp * k };
}
/** 數值化（殺棋換成很大的數），白方觀點 */
export function scoreNum(s) {
  if (!s) return 0;
  if (s.mate !== undefined) return s.mate > 0 ? 10000 - s.mate : (s.mate < 0 ? -10000 - s.mate : 0);
  return s.cp;
}
/** 顯示用：+1.25、-0.40、#3、#-2 */
export function fmtScore(s) {
  if (!s) return '…';
  if (s.mate !== undefined) return s.mate === 0 ? '#' : (s.mate > 0 ? '#' + s.mate : '#-' + (-s.mate));
  if (Math.abs(s.cp) >= 100000) return s.cp > 0 ? '1-0 將死' : '0-1 將死';
  return (s.cp > 0 ? '+' : '') + (s.cp / 100).toFixed(2);
}
/** 勝率（Lichess 用的公式），白方觀點，0~1 */
export function winChance(s) {
  if (!s) return 0.5;
  if (s.mate !== undefined) return s.mate > 0 ? 1 : (s.mate < 0 ? 0 : 0.5);
  const cp = Math.max(-1000, Math.min(1000, s.cp));
  return 1 / (1 + Math.exp(-0.00368208 * cp));
}

let shared = null;
/** 整個 App 共用一個引擎（WASM 只下載、編譯一次） */
export function engine() { return shared || (shared = new StockfishEngine()); }
