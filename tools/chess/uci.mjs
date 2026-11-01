// 在 Node 裡跑網站用的同一份 Stockfish（games/chess/vendor/stockfish），給出題、驗證腳本用。
import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const ROOT = path.resolve(HERE, '../..');
const ENGINE = path.join(ROOT, 'games/chess/vendor/stockfish/stockfish-18-lite-single.js');

export class Engine {
  constructor() {
    this.p = spawn(process.execPath, [ENGINE], { stdio: ['pipe', 'pipe', 'inherit'] });
    this.buf = ''; this.waiters = [];
    this.p.stdout.on('data', d => {
      this.buf += d.toString();
      let i;
      while ((i = this.buf.indexOf('\n')) >= 0) {
        const line = this.buf.slice(0, i).trim(); this.buf = this.buf.slice(i + 1);
        for (const w of [...this.waiters]) w(line);
      }
    });
  }
  send(cmd) { this.p.stdin.write(cmd + '\n'); }
  waitFor(pred, onLine) {
    return new Promise(res => {
      const w = line => { if (onLine) onLine(line); if (pred(line)) { this.waiters = this.waiters.filter(x => x !== w); res(line); } };
      this.waiters.push(w);
    });
  }
  async init(opts = {}) {
    this.send('uci'); await this.waitFor(l => l === 'uciok');
    for (const [k, v] of Object.entries(opts)) this.send(`setoption name ${k} value ${v}`);
    this.send('isready'); await this.waitFor(l => l === 'readyok');
    return this;
  }
  async newGame() { this.send('ucinewgame'); this.send('isready'); await this.waitFor(l => l === 'readyok'); }
  // 回傳 { best, lines: [{multipv, depth, score:{cp|mate}, pv:[]}] }，分數是「輪到走的一方」的觀點
  async analyse(fen, { depth = 14, movetime, multipv = 1, moves = '' } = {}) {
    this.send(`setoption name MultiPV value ${multipv}`);
    this.send(`position fen ${fen}${moves ? ' moves ' + moves : ''}`);
    const lines = {};
    this.send(movetime ? `go movetime ${movetime}` : `go depth ${depth}`);
    const done = await this.waitFor(l => l.startsWith('bestmove'), l => {
      if (!l.startsWith('info') || !l.includes(' pv ') || l.includes('upperbound') || l.includes('lowerbound')) return;
      const t = l.split(' ');
      const g = k => t[t.indexOf(k) + 1];
      const mp = +(t.includes('multipv') ? g('multipv') : 1);
      const si = t.indexOf('score');
      const score = t[si + 1] === 'mate' ? { mate: +t[si + 2] } : { cp: +t[si + 2] };
      lines[mp] = { multipv: mp, depth: +g('depth'), score, pv: t.slice(t.indexOf('pv') + 1) };
    });
    return { best: done.split(' ')[1], lines: Object.values(lines).sort((a, b) => a.multipv - b.multipv) };
  }
  quit() { this.send('quit'); setTimeout(() => this.p.kill(), 200); }
}

// 分數換成「輪到走的一方」的 centipawn（將死換成很大的數，越快越大）
export function cpOf(score) {
  if (score.mate !== undefined) return score.mate > 0 ? 100000 - score.mate * 100 : -100000 - score.mate * 100;
  return score.cp;
}
