// 戰術題型判斷與中文解析（gen_tactics.mjs 用）。全部照棋盤上的事實判斷，不靠猜。
import { Chess } from '../../games/chess/vendor/chessjs/chess.js';

export const THEME_ORDER = ['fork', 'pin', 'skewer', 'discovered', 'deflection', 'defender', 'mate', 'defense'];
const VAL = { p: 1, n: 3, b: 3, r: 5, q: 9, k: 100 };
const NAME = { p: '兵', n: '馬', b: '象', r: '車', q: '后', k: '王' };
const SIDE = { w: '白', b: '黑' };
const FILES = 'abcdefgh';
const opp = c => (c === 'w' ? 'b' : 'w');

export function materialOf(ch, color) {
  let s = 0;
  for (const row of ch.board()) for (const p of row) if (p && p.type !== 'k') s += (p.color === color ? 1 : -1) * VAL[p.type];
  return s;
}
const sq = (f, r) => (f >= 0 && f < 8 && r >= 0 && r < 8 ? FILES[f] + (r + 1) : null);
const fr = s => [FILES.indexOf(s[0]), +s[1] - 1];
const DIRS = { b: [[1, 1], [1, -1], [-1, 1], [-1, -1]], r: [[1, 0], [-1, 0], [0, 1], [0, -1]] };
DIRS.q = [...DIRS.b, ...DIRS.r];

// 從 from 沿某方向看過去的前兩個棋子
function ray(ch, from, d) {
  const [f, r] = fr(from); const hit = [];
  for (let k = 1; k < 8; k++) {
    const s = sq(f + d[0] * k, r + d[1] * k);
    if (!s) break;
    const p = ch.get(s);
    if (p) { hit.push({ s, ...p }); if (hit.length === 2) break; }
  }
  return hit;
}
// at 上的棋子攻擊到哪些對方棋子
function targetsOf(ch, at) {
  const me = ch.get(at); if (!me) return [];
  const res = [];
  for (const row of ch.board()) for (const p of row) {
    if (!p || p.color === me.color) continue;
    if (ch.attackers(p.square, me.color).includes(at)) res.push(p);
  }
  return res;
}
const defended = (ch, s, color) => ch.attackers(s, color).length > 0;
const pieceDesc = p => `${p.square || p.s} 的${NAME[p.type]}`;

// 把整條解答走一遍，記下每一步前後的局面
function walk(v) {
  const ch = new Chess(v.fen);
  const steps = [];
  for (const u of v.moves) {
    const before = new Chess(ch.fen());
    const m = ch.move({ from: u.slice(0, 2), to: u.slice(2, 4), promotion: u[4] });
    steps.push({ m, before, after: new Chess(ch.fen()) });
  }
  return steps; // steps[0] 是對手的最後一步；奇數 index 是解題方
}

// 每個解題步驟的事實
function facts(step, solver, laterCaps) {
  const { m, before, after } = step;
  const f = { fork: null, pin: null, skewer: null, disc: null };
  const enemy = opp(solver);
  // 雙重攻擊：走到的棋子同時攻擊 ≥2 個「比它值錢或沒人保護」的子（不算兵），王被將軍也算一個
  const tg = targetsOf(after, m.to).filter(p => p.type !== 'p' &&
    (p.type === 'k' || VAL[p.type] > VAL[m.piece] || !defended(after, p.square, enemy)));
  if (tg.length >= 2) f.fork = tg;
  // 牽制／串擊：長程棋子沿線上的前兩個敵方棋子
  const slider = after.get(m.to);
  if (slider && DIRS[slider.type]) for (const d of DIRS[slider.type]) {
    const [a, b] = ray(after, m.to, d);
    if (!a || !b || a.color !== enemy || b.color !== enemy) continue;
    if (VAL[b.type] > VAL[a.type] && a.type !== 'k' && a.type !== 'p') f.pin = f.pin || { a, b };
    if (VAL[a.type] > VAL[b.type] && (a.type === 'k' || a.type === 'q') && b.type !== 'p') f.skewer = f.skewer || { a, b };
  }
  // 閃擊：走開以後，後面我方長程棋子新攻擊到的敵方子（王或 ≥ 象馬）
  for (const row of after.board()) for (const p of row) {
    if (!p || p.color !== solver || p.square === m.to || !DIRS[p.type]) continue;
    const now = targetsOf(after, p.square), was = new Set(targetsOf(before, p.square).map(x => x.square));
    const fresh = now.filter(x => !was.has(x.square) && (x.type === 'k' || VAL[x.type] >= 3));
    if (fresh.length) { f.disc = { by: p, t: fresh }; break; }
  }
  return f;
}

export function classify(v) {
  const steps = walk(v);
  const solver = steps[1].m.color;
  const themes = new Set();
  if (v.kind === 'defense') {
    // 只是把對手剛吃掉的子吃回來，不算防守戰術
    if (steps[1].m.to === steps[0].m.to) return [];
    return ['defense'];
  }
  if (v.mate) themes.add('mate');
  const solverSteps = steps.filter((_, i) => i % 2 === 1);
  const capsAfter = i => steps.slice(i + 1).filter((s, j) => (i + 1 + j) % 2 === 1 && s.m.captured).map(s => s.m.to);
  for (let i = 1; i < steps.length; i += 2) {
    const f = facts(steps[i], solver);
    const later = capsAfter(i);
    // 解答的最後一步：之後的得子已經由引擎確認（最後局面 ≥ +2），只要棋盤上的威脅成立就算
    const lastMove = i === steps.length - 1 && !v.mate;
    const big = t => t.type === 'k' || VAL[t.type] >= 5;
    // 吃掉一個沒人保護的大子（≥ 象馬）只是「白吃」，順便攻擊到別的子不算雙重攻擊
    const m0 = steps[i].m;
    const freeGrab = m0.captured && VAL[m0.captured] >= 3 && steps[i].before.attackers(m0.to, opp(solver)).length === 0;
    if (f.fork && !freeGrab && (v.mate ? f.fork.some(t => t.type === 'k') : (f.fork.some(t => later.includes(t.square)) || (lastMove && f.fork.filter(big).length >= 1 && f.fork.length >= 2)))) themes.add('fork');
    if (f.pin && (later.includes(f.pin.a.s) || (lastMove && VAL[f.pin.b.type] >= 5 && steps[i].after.attackers(f.pin.a.s, solver).length > steps[i].after.attackers(f.pin.a.s, opp(solver)).length))) themes.add('pin');
    if (f.skewer && (later.includes(f.skewer.b.s) || (lastMove && steps[i].after.isCheck() && VAL[f.skewer.b.type] >= 3 && !defended(steps[i].after, f.skewer.b.s, opp(solver))))) themes.add('skewer');
    if (f.disc && steps[i].m.piece !== f.disc.by.type && (later.some(s => f.disc.t.some(t => t.square === s)) || (f.disc.t.some(t => t.type === 'k') && (later.length || v.mate)) || (lastMove && f.disc.t.some(big) && (steps[i].after.isCheck() || steps[i].m.captured))))
      themes.add('discovered');
    // 消除保護者：吃掉的子原本保護某個敵方子 X，之後我方吃到 X
    if (steps[i].m.captured) {
      const before = steps[i].before;
      const D = steps[i].m.to;
      const protectedBy = [];
      for (const row of before.board()) for (const p of row)
        if (p && p.color !== solver && p.square !== D && p.type !== 'k' && before.attackers(p.square, opp(solver)).includes(D)) protectedBy.push(p.square);
      // 吃保護者本身不能就是「白吃一個子」：要是交換（對手吃得回來、或用不比它值錢的子去吃）
      // 而且保護者不是對手剛走過來的子（那只是吃回對手送上門的子）
      const trade = steps[i - 1].m.to !== D && steps[i].after.attackers(D, opp(solver)).length > 0 && VAL[steps[i].m.captured] <= VAL[steps[i].m.piece];
      if (!trade) { /* 不算 */ }
      else if (protectedBy.some(s => later.includes(s) && before.attackers(s, solver).length)) themes.add('defender');
      // 解答最後一步就吃掉保護者：被保護的子（≥ 象馬）現在被我方攻擊、而且攻擊的子比保護的多
      else if (i === steps.length - 1 && !v.mate) {
        const after = steps[i].after;
        if (protectedBy.some(s => { const x = after.get(s); return x && x.color !== solver && VAL[x.type] >= 3
          && after.attackers(s, solver).length > after.attackers(s, opp(solver)).length; })) themes.add('defender');
      }
    }
    // 引離：對手被迫用某個子回應（吃子或擋將），那個子原本守著下一步我方要走到的格子
    if (i + 2 < steps.length) {
      const r = steps[i + 1], nx = steps[i + 2];
      const guarded = r.before.attackers(nx.m.to, opp(solver)).includes(r.m.from);
      const stillGuarded = nx.before.attackers(nx.m.to, opp(solver)).length > 0 && nx.m.captured === undefined;
      if (guarded && r.m.piece !== 'k' && (nx.m.captured || nx.after.isCheckmate() || nx.after.isCheck()) && !stillGuarded && (steps[i].m.captured || steps[i].after.isCheck() || isSac(steps[i])))
        themes.add('deflection');
    }
  }
  // 起始局面就已經被牽制的子，第一步去攻擊它，之後吃掉它
  const s1 = steps[1];
  if (!themes.has('pin')) {
    for (const row of s1.before.board()) for (const p of row) {
      if (!p || p.color !== solver || !DIRS[p.type]) continue;
      for (const d of DIRS[p.type]) {
        const [a, b] = ray(s1.before, p.square, d);
        if (a && b && a.color !== solver && b.color !== solver && a.type !== 'k' && a.type !== 'p' && VAL[b.type] > VAL[a.type] && b.type !== 'p'
          && s1.after.attackers(a.s, solver).includes(s1.m.to) && p.square !== a.s && p.square !== s1.m.from
          && (capsAfter(1).includes(a.s) || (steps.length === 2 && !v.mate && (b.type === 'k' || VAL[b.type] >= 5) && VAL[s1.m.piece] < VAL[a.type]))) themes.add('pin');
      }
    }
  }
  return THEME_ORDER.filter(t => themes.has(t));
}

function isSac(step) {
  const { m, after } = step;
  return after.attackers(m.to, opp(m.color)).length > 0 && !defended(after, m.to, m.color) || VAL[m.piece] > (m.captured ? VAL[m.captured] : 0) + 1 && after.attackers(m.to, opp(m.color)).length > 0;
}

const fmtScore = s => {
  if (!s) return '';
  if (s.mate !== undefined) return `${Math.abs(s.mate)} 步殺`;
  return (s.cp >= 0 ? '+' : '') + (s.cp / 100).toFixed(1);
};

// 中文解析：hint（提示）＋ steps（每一步說明）＋ summary（結論）
export function explain(v) {
  const steps = walk(v);
  const solver = steps[1].m.color;
  const notes = [];
  const sanList = steps.map(s => s.m.san);
  const hintBits = [];
  for (let i = 1; i < steps.length; i++) {
    const { m, after } = steps[i];
    const mine = i % 2 === 1;
    const bits = [];
    if (m.captured) bits.push(`吃掉${NAME[m.captured]}`);
    if (m.promotion) bits.push(`升變成${NAME[m.promotion]}`);
    if (after.isCheckmate()) bits.push('將死！');
    else if (after.isCheck()) bits.push('將軍');
    if (mine) {
      const f = facts(steps[i], solver);
      if (f.fork) bits.push(`同時攻擊 ${f.fork.map(pieceDesc).join('、')}`);
      if (f.disc && m.piece !== f.disc.by.type) bits.push(`讓開線路，${f.disc.by.square} 的${NAME[f.disc.by.type]}直接攻擊 ${f.disc.t.map(pieceDesc).join('、')}`);
      if (f.pin && (v.themes || []).includes('pin')) bits.push(`沿線牽制 ${pieceDesc(f.pin.a)}，它後面是${NAME[f.pin.b.type]}`);
      if (f.skewer && (v.themes || []).includes('skewer')) bits.push(`串擊：${NAME[f.skewer.a.type]}被攻擊得讓開，後面 ${pieceDesc(f.skewer.b)} 就露出來`);
      notes.push({ san: m.san, who: 'me', text: bits.join('，') || (v.kind === 'defense' ? '唯一不會輸的走法' : '唯一能保持優勢的走法') });
    } else {
      notes.push({ san: m.san, who: 'opp', text: bits.length ? bits.join('，') : '最頑強的回應' });
    }
  }
  const first = steps[1].m;
  hintBits.push(`動你的${NAME[first.piece]}`);
  if (steps[1].after.isCheck()) hintBits.push('而且是將軍');
  else if (first.captured) hintBits.push('而且是吃子');
  let summary;
  if (v.kind === 'defense') summary = `對手有很強的威脅，這是唯一不會輸掉的走法（其他走法至少輸 3 兵）。走完後引擎評估 ${fmtScore(v.startEval)}（以你這方來看）。`;
  else if (v.mate) summary = `${v.moves.length / 2} 步將死。`;
  else {
    // 「淨賺」只有在子力差跟引擎評估差不多時才說（不然代表之後還會被吃回一部分，或優勢是別的原因）
    const ev = v.startEval && v.startEval.cp !== undefined ? v.startEval.cp / 100 : null;
    const net = v.gain > 0 && ev !== null && Math.abs(v.gain - ev) <= 1.5;
    const what = net ? `子力淨賺 ${v.gain} 兵的價值，` : v.gain > 0 && ev !== null && v.gain > ev ? '先吃到子（對手之後還能拿回一部分），' : '';
    summary = `照這條解答走完，${what}引擎評估 ${fmtScore(v.startEval)}（以你這方來看），已經是明顯優勢。`;
  }
  return { side: solver, last: sanList[0], hint: hintBits.join('，'), notes, summary };
}
