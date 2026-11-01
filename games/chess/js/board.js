// 棋盤元件：點兩下或拖曳走棋、合法落點、最後一步、將軍、箭頭、升變選擇、翻轉。
// 棋規不在這裡判斷，全部交給 chess.js（由外面傳進來的 game）。
const FILES = 'abcdefgh';
const PIECE_NAME = { p: '兵', n: '馬', b: '象', r: '車', q: '后', k: '王' };
const pieceURL = (c, t) => new URL(`../pieces/${c}${t.toUpperCase()}.svg`, import.meta.url).href;

export class Board {
  /**
   * @param {HTMLElement} el 容器
   * @param {object} opt
   *   getGame(): 回傳 chess.js 物件（目前顯示的局面）
   *   canMove(color): 這一方現在可不可以由使用者走
   *   onMove({from,to,promotion}): 使用者走了一步（合法的），回傳 false 代表不接受
   */
  constructor(el, opt) {
    this.el = el; this.opt = opt;
    this.flipped = false; this.sel = null; this.last = null; this.arrows = []; this.marks = {};
    this.el.classList.add('board');
    this.el.setAttribute('role', 'grid');
    this.el.innerHTML = '<div class="sqs"></div><svg class="arrows" viewBox="0 0 800 800" aria-hidden="true"></svg><div class="promo" hidden></div>';
    this.sqEl = this.el.querySelector('.sqs');
    this.svg = this.el.querySelector('.arrows');
    this.promoEl = this.el.querySelector('.promo');
    this.cells = {};
    for (let i = 0; i < 64; i++) {
      const d = document.createElement('div');
      d.className = 'sq';
      this.sqEl.appendChild(d);
    }
    this.layout();
    this.bindPointer();
    this.el.addEventListener('keydown', e => this.onKey(e));
  }

  layout() {
    const divs = this.sqEl.children;
    this.cells = {};
    for (let i = 0; i < 64; i++) {
      const row = Math.floor(i / 8), col = i % 8;
      const f = this.flipped ? 7 - col : col, r = this.flipped ? row : 7 - row;
      const s = FILES[f] + (r + 1);
      const d = divs[i];
      d.dataset.sq = s;
      d.className = 'sq ' + ((f + r) % 2 ? 'light' : 'dark');
      d.setAttribute('role', 'gridcell');
      d.tabIndex = i === 0 ? 0 : -1;
      d.innerHTML = '';
      if (col === 0) d.insertAdjacentHTML('beforeend', `<span class="coord rank">${r + 1}</span>`);
      if (row === 7) d.insertAdjacentHTML('beforeend', `<span class="coord file">${FILES[f]}</span>`);
      this.cells[s] = d;
    }
    this.render();
  }

  setFlipped(v) { this.flipped = !!v; this.layout(); }
  flip() { this.setFlipped(!this.flipped); }
  /** opts.animate：讓這一步的棋子從起點滑到終點（電腦、對手、播放用；自己拖曳的棋不要） */
  setLast(m, opts) {
    this.last = m ? { from: m.from, to: m.to } : null;
    if (m && opts && opts.animate) this.anim = { from: m.from, to: m.to, flags: m.flags || '' };
  }
  playAnim() {
    const a = this.anim; this.anim = null;
    if (!a || (window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches)) return;
    const slide = (from, to) => {
      const img = this.cells[to] && this.cells[to].querySelector('img.pc');
      if (!img || !this.cells[from]) return;
      const f = this.cells[from].getBoundingClientRect(), t = this.cells[to].getBoundingClientRect();
      const dx = f.left - t.left, dy = f.top - t.top;
      if (!dx && !dy) return;
      img.style.zIndex = 15;
      const an = img.animate([{ transform: `translate(${dx}px, ${dy}px)` }, { transform: 'translate(0, 0)' }], { duration: 320, easing: 'cubic-bezier(.25,.8,.35,1)' });
      an.onfinish = an.oncancel = () => { img.style.zIndex = ''; };
    };
    slide(a.from, a.to);
    // 易位時車也一起滑
    const r = a.to[1];
    if (a.flags.includes('k')) slide('h' + r, 'f' + r);
    if (a.flags.includes('q')) slide('a' + r, 'd' + r);
  }
  setArrows(a) { this.arrows = a || []; this.drawArrows(); }
  setMarks(m) { this.marks = m || {}; this.render(); }   // { e4: 'good' | 'bad' | 'hint' }

  render() {
    const g = this.opt.getGame();
    const board = g.board();
    const check = g.inCheck() ? g.turn() : null;
    const legal = this.sel ? g.moves({ square: this.sel, verbose: true }) : [];
    const dest = new Set(legal.map(m => m.to));
    for (let r = 0; r < 8; r++) for (let f = 0; f < 8; f++) {
      const s = FILES[f] + (8 - r);
      const cell = this.cells[s];
      const p = board[r][f];
      let img = cell.querySelector('img.pc');
      if (p) {
        const src = pieceURL(p.color, p.type);
        if (!img) { img = document.createElement('img'); img.className = 'pc'; img.draggable = false; img.alt = ''; cell.appendChild(img); }
        if (img.getAttribute('src') !== src) img.setAttribute('src', src);
        img.dataset.piece = p.color + p.type;
      } else if (img) img.remove();
      cell.classList.toggle('sel', this.sel === s);
      cell.classList.toggle('last', !!this.last && (this.last.from === s || this.last.to === s));
      cell.classList.toggle('dest', dest.has(s));
      cell.classList.toggle('cap', dest.has(s) && !!p);
      cell.classList.toggle('check', !!p && p.type === 'k' && p.color === check);
      cell.classList.remove('mk-good', 'mk-bad', 'mk-hint');
      if (this.marks[s]) cell.classList.add('mk-' + this.marks[s]);
      const label = p ? `${s} ${p.color === 'w' ? '白' : '黑'}${PIECE_NAME[p.type]}` : s;
      cell.setAttribute('aria-label', label);
    }
    this.drawArrows();
    if (this.anim) this.playAnim();
  }

  center(s) {
    const f = FILES.indexOf(s[0]), r = +s[1] - 1;
    const col = this.flipped ? 7 - f : f, row = this.flipped ? r : 7 - r;
    return [col * 100 + 50, row * 100 + 50];
  }
  drawArrows() {
    const out = [];
    for (const a of this.arrows) {
      const [x1, y1] = this.center(a.from), [x2, y2] = this.center(a.to);
      const dx = x2 - x1, dy = y2 - y1, len = Math.hypot(dx, dy) || 1;
      const ux = dx / len, uy = dy / len;
      const ex = x2 - ux * 30, ey = y2 - uy * 30;
      const col = a.color || 'rgba(255,170,0,0.8)';
      const w = a.width || 16;
      out.push(`<line x1="${x1 + ux * 18}" y1="${y1 + uy * 18}" x2="${ex}" y2="${ey}" stroke="${col}" stroke-width="${w}" stroke-linecap="round"/>`);
      out.push(`<polygon points="${x2},${y2} ${ex - uy * w * 1.5},${ey + ux * w * 1.5} ${ex + uy * w * 1.5},${ey - ux * w * 1.5}" fill="${col}"/>`);
    }
    this.svg.innerHTML = out.join('');
  }

  // ── 走棋 ──
  myPiece(s) {
    const g = this.opt.getGame(); const p = g.get(s);
    return p && p.color === g.turn() && this.opt.canMove(p.color);
  }
  async tryMove(from, to) {
    const g = this.opt.getGame();
    const legal = g.moves({ square: from, verbose: true }).filter(m => m.to === to);
    if (!legal.length) return false;
    let promotion;
    if (legal.some(m => m.promotion)) {
      promotion = await this.askPromotion(to, g.turn());
      if (!promotion) { this.render(); return false; }
    }
    this.sel = null;
    const ok = this.opt.onMove({ from, to, promotion });
    this.render();
    return ok !== false;
  }
  askPromotion(to, color) {
    return new Promise(res => {
      const el = this.promoEl;
      el.innerHTML = '<div class="promo-box" role="dialog" aria-label="升變成什麼？"><p>升變成：</p></div>';
      const box = el.firstChild;
      for (const t of ['q', 'r', 'b', 'n']) {
        const b = document.createElement('button');
        b.type = 'button'; b.dataset.promo = t;
        b.title = PIECE_NAME[t]; b.setAttribute('aria-label', PIECE_NAME[t]);
        b.innerHTML = `<img src="${pieceURL(color, t)}" alt="">`;
        b.onclick = e => { e.stopPropagation(); el.hidden = true; res(t); };
        box.appendChild(b);
      }
      const cancel = document.createElement('button');
      cancel.type = 'button'; cancel.className = 'promo-cancel'; cancel.textContent = '取消';
      cancel.onclick = e => { e.stopPropagation(); el.hidden = true; res(null); };
      box.appendChild(cancel);
      el.hidden = false;
      box.querySelector('button').focus();
    });
  }

  bindPointer() {
    let drag = null;
    const sqAt = (x, y) => {
      const r = this.sqEl.getBoundingClientRect();
      const col = Math.floor((x - r.left) / (r.width / 8)), row = Math.floor((y - r.top) / (r.height / 8));
      if (col < 0 || col > 7 || row < 0 || row > 7) return null;
      const f = this.flipped ? 7 - col : col, rk = this.flipped ? row : 7 - row;
      return FILES[f] + (rk + 1);
    };
    this.sqEl.addEventListener('pointerdown', e => {
      if (e.button !== 0 || !this.promoEl.hidden) return;
      const s = sqAt(e.clientX, e.clientY); if (!s) return;
      if (this.sel && this.sel !== s && !this.myPiece(s)) {
        const from = this.sel; this.tryMove(from, s).then(ok => { if (!ok) { this.sel = null; this.render(); } });
        return;
      }
      if (this.myPiece(s)) {
        const was = this.sel === s;
        this.sel = s; this.render();
        const img = this.cells[s].querySelector('img.pc');
        drag = { from: s, img, x: e.clientX, y: e.clientY, moved: false, was };
        this.sqEl.setPointerCapture(e.pointerId);
        e.preventDefault();
      } else { this.sel = null; this.render(); }
    });
    this.sqEl.addEventListener('pointermove', e => {
      if (!drag) return;
      const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
      if (!drag.moved && Math.hypot(dx, dy) < 6) return;
      drag.moved = true;
      if (drag.img) { drag.img.classList.add('dragging'); drag.img.style.transform = `translate(${dx}px, ${dy}px)`; }
    });
    const end = e => {
      if (!drag) return;
      const d = drag; drag = null;
      if (d.img) { d.img.classList.remove('dragging'); d.img.style.transform = ''; }
      if (!d.moved) { if (d.was) { this.sel = null; this.render(); } return; }
      const s = sqAt(e.clientX, e.clientY);
      if (s && s !== d.from) this.tryMove(d.from, s).then(ok => { if (!ok) { this.sel = null; this.render(); } });
    };
    this.sqEl.addEventListener('pointerup', end);
    this.sqEl.addEventListener('pointercancel', e => { if (drag && drag.img) { drag.img.classList.remove('dragging'); drag.img.style.transform = ''; } drag = null; });
  }

  // 鍵盤：方向鍵移動焦點，Enter／空白鍵選子與落子
  onKey(e) {
    const cell = e.target.closest && e.target.closest('.sq'); if (!cell) return;
    const s = cell.dataset.sq;
    const f = FILES.indexOf(s[0]), r = +s[1] - 1;
    const d = { ArrowUp: [0, 1], ArrowDown: [0, -1], ArrowLeft: [-1, 0], ArrowRight: [1, 0] }[e.key];
    if (d) {
      e.preventDefault();
      const k = this.flipped ? -1 : 1;
      const nf = f + d[0] * k, nr = r + d[1] * k;
      if (nf < 0 || nf > 7 || nr < 0 || nr > 7) return;
      const t = this.cells[FILES[nf] + (nr + 1)];
      cell.tabIndex = -1; t.tabIndex = 0; t.focus();
    } else if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      if (this.sel && this.sel !== s && !this.myPiece(s)) this.tryMove(this.sel, s);
      else if (this.myPiece(s)) { this.sel = this.sel === s ? null : s; this.render(); }
    } else if (e.key === 'Escape') { this.sel = null; this.render(); }
  }
}
