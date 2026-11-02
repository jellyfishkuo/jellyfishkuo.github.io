// 手工擺的經典戰術局面（牽制、串擊、消除保護者在自我對弈裡很少出現）。
// 每一題都跟自我對弈的題目走同一套驗證（verify.mjs：每一步唯一好棋、最後真的得子），
// 題型由人標（want），再加上 themes.mjs 自動判斷出的其他題型。結果寫到 out/hand.json，gen_tactics.mjs 會一起併進題庫。
// 用法：node hand_tactics.mjs
import fs from 'node:fs';
import path from 'node:path';
import { Engine } from './uci.mjs';
import { verify } from './verify.mjs';
import { classify } from './themes.mjs';
import { Chess } from '../../games/chess/vendor/chessjs/chess.js';

// fen：對手走之前的局面；last：對手這一步（通常是一個看起來自然、其實不好的走法）；want：預期題型
export const HAND = [
  // 牽制：黑后走到 d7，Bb5 把后釘在王前面（c 兵已經不在，擋不住）
  { want: 'pin', fen: 'r1b1k2r/pp3ppp/3qpn2/8/8/2N5/PPP2PPP/R2QRBK1 b kq - 0 12', last: 'd6d7' },
  // 串擊：王走到長對角線，後面是 a8 的后
  { want: 'skewer', fen: 'q7/8/8/2k5/8/8/5PPP/3B2K1 b - - 0 1', last: 'c5d5' },
  // 串擊：黑王走進第 5 排，車將軍，王讓開後吃掉後面的后
  { want: 'skewer', fen: '8/5ppp/8/7q/2k5/8/5PPP/RB4K1 b - - 0 1', last: 'c4d5' },
  // 消除保護者：f6 的馬是 h7 唯一的保護者，Bxf6 之後黑方不能吃回（吃回就 Qxh7#）
  { want: 'defender', fen: 'r1bq1rk1/ppp2ppp/4pn2/6B1/8/2PQ4/PP3PPP/RB3RK1 b - - 0 12', last: 'c8d7' },
];

// 同一個想法換個方向：左右鏡射（a↔h 線）、黑白對調（上下翻轉＋換色）。鏡射後不能易位，所以拿掉易位權。
const sqMirror = s => 'abcdefgh'['abcdefgh'.indexOf(s[0]) ^ 7] + s[1];
const sqFlip = s => s[0] + (9 - +s[1]);
function mirror(c) {
  const [b, t, , ep, h, f] = c.fen.split(' ');
  const rows = b.split('/').map(r => r.replace(/\d/g, d => '1'.repeat(+d)).split('').reverse().join('').replace(/1+/g, m => m.length));
  return { ...c, fen: [rows.join('/'), t, '-', ep === '-' ? '-' : sqMirror(ep), h, f].join(' '), last: sqMirror(c.last.slice(0, 2)) + sqMirror(c.last.slice(2, 4)) + c.last.slice(4) };
}
function flip(c) {
  const [b, t, , ep, h, f] = c.fen.split(' ');
  const rows = b.split('/').reverse().map(r => r.replace(/[a-zA-Z]/g, x => (x === x.toUpperCase() ? x.toLowerCase() : x.toUpperCase())));
  return { ...c, fen: [rows.join('/'), t === 'w' ? 'b' : 'w', '-', ep === '-' ? '-' : sqFlip(ep), h, f].join(' '), last: sqFlip(c.last.slice(0, 2)) + sqFlip(c.last.slice(2, 4)) + c.last.slice(4) };
}

if (process.argv[1] && process.argv[1].endsWith('hand_tactics.mjs')) {
  const e = await new Engine().init({ Hash: 64 });
  const out = [];
  for (const c of HAND.flatMap(c => [c, mirror(c), flip(c), flip(mirror(c))])) {
    try { const g = new Chess(c.fen); g.move({ from: c.last.slice(0, 2), to: c.last.slice(2, 4) }); } catch (err) { console.log('✗ 不合法', c.fen, c.last); continue; }
    const v = await verify(e, { kind: 'attack', fen: c.fen, last: c.last });
    if (!v) { console.log('✗ 沒通過驗證', c.want, c.fen); continue; }
    const t = classify(v);
    const g = new Chess(c.fen); const sans = v.moves.map(u => g.move({ from: u.slice(0, 2), to: u.slice(2, 4), promotion: u[4] }).san);
    const themes = [...new Set([c.want, ...t])];
    console.log('✓', c.want, '自動判斷：', t.join(',') || '—', '|', sans.join(' '), 'gain', v.gain);
    out.push({ ...v, themes });
  }
  fs.writeFileSync(path.join(path.dirname(new URL(import.meta.url).pathname), 'out', 'hand.json'), JSON.stringify(out));
  e.quit();
}
