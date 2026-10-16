/* =========================================================
   效能比賽場：在 Web Worker 裡跑的演算法（效能版，不記每一步）
   build.py 會把這個檔整段塞進 benchmark.html；
   頁面也會用同一份原始碼在主執行緒建一份，拿來算資料統計和做測試。
   商品一律編成 0 ~ m-1 的整數，交易是排好序的 Int32Array。
   ========================================================= */
'use strict';

/* ---------- 可重現的亂數：同一個種子，每次產生的資料都一樣 ---------- */
function mulberry32(seed) {
    let a = seed >>> 0;
    return function () {
        a = (a + 0x6D2B79F5) | 0;
        let t = Math.imul(a ^ (a >>> 15), 1 | a);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

/* 超商 8 筆範例（和各 Demo 頁同一份；數量、利潤和 Two-Phase / HUI-Miner 頁相同） */
const SAMPLE_NAMES = ['咖啡', '麵包', '牛奶', '飯糰', '茶葉蛋', '洋芋片'];
const SAMPLE_PROFIT = [30, 15, 20, 10, 5, 25];
const SAMPLE_DB = [
    [[0, 4], [1, 2], [2, 2]],
    [[0, 3], [1, 5], [4, 4]],
    [[0, 1], [1, 1], [2, 2], [3, 2]],
    [[1, 3], [2, 4], [5, 5]],
    [[0, 3], [2, 2], [4, 2]],
    [[0, 1], [1, 2], [2, 1], [4, 1]],
    [[3, 1], [4, 2], [5, 2]],
    [[0, 1], [1, 2], [3, 1]]
];

/* 把「每筆交易 = [[商品, 數量], ...]」整理成演算法要用的格式 */
function packData(rows, profit, names) {
    const m = profit.length;
    const D = { n: rows.length, m, names, profit: Int32Array.from(profit), tx: [], qty: [], len: new Int32Array(rows.length), lo: new Int32Array(rows.length), hi: new Int32Array(rows.length) };
    rows.forEach((row, r) => {
        const s = row.slice().sort((a, b) => a[0] - b[0]);
        D.tx.push(Int32Array.from(s, x => x[0]));
        D.qty.push(Int32Array.from(s, x => x[1]));
        D.len[r] = s.length;
        for (const [i] of s) { if (i < 32) D.lo[r] |= 1 << i; else D.hi[r] |= 1 << (i - 32); }
    });
    return D;
}

/* 產生資料：交易數 n、商品數 m、平均長度、分布（均勻 / Zipf 偏斜）、種子；另外產生數量和利潤（高效益組才用） */
function makeData(spec) {
    if (spec.source === 'sample') return packData(SAMPLE_DB, SAMPLE_PROFIT, SAMPLE_NAMES);
    const rnd = mulberry32(spec.seed);
    const m = spec.items, n = spec.trans;
    const avg = Math.min(spec.avgLen, m);
    const profit = [];
    for (let i = 0; i < m; i++) profit.push(1 + Math.floor(rnd() * spec.pMax));
    // Zipf：第 i 個商品被選到的機率 ∝ 1 / (i+1)，少數商品特別熱門
    const cum = new Float64Array(m);
    let acc = 0;
    for (let i = 0; i < m; i++) { acc += spec.dist === 'zipf' ? 1 / (i + 1) : 1; cum[i] = acc; }
    const pick = () => {
        const x = rnd() * acc;
        let a = 0, b = m - 1;
        while (a < b) { const c = (a + b) >> 1; if (cum[c] > x) b = c; else a = c + 1; }
        return a;
    };
    // 交易長度：1 + Poisson(avg - 1)，平均剛好是 avg
    const poisson = lam => {
        if (lam <= 0) return 0;
        const L = Math.exp(-lam);
        let k = 0, p = 1;
        do { k++; p *= rnd(); } while (p > L);
        return k - 1;
    };
    const rows = [];
    const used = new Uint8Array(m);
    for (let r = 0; r < n; r++) {
        const len = Math.min(m, 1 + poisson(avg - 1));
        const row = [];
        let tries = 0;
        while (row.length < len && tries < 50 * m) {
            tries++;
            const i = pick();
            if (used[i]) continue;
            used[i] = 1;
            row.push([i, 1 + Math.floor(rnd() * spec.qMax)]);
        }
        for (const [i] of row) used[i] = 0;
        rows.push(row);
    }
    const names = [];
    for (let i = 0; i < m; i++) names.push('i' + (i + 1));
    return packData(rows, profit, names);
}

function dataStats(D) {
    let total = 0, util = 0, longest = 0;
    const seen = new Uint8Array(D.m);
    for (let r = 0; r < D.n; r++) {
        total += D.len[r];
        longest = Math.max(longest, D.len[r]);
        for (let k = 0; k < D.len[r]; k++) { seen[D.tx[r][k]] = 1; util += D.qty[r][k] * D.profit[D.tx[r][k]]; }
    }
    const items = seen.reduce((a, b) => a + b, 0);
    return { n: D.n, items, avgLen: total / Math.max(1, D.n), longest, density: total / Math.max(1, D.n) / Math.max(1, items), util };
}

/* ---------- 結果的「指紋」：不用把幾萬個樣式傳回主畫面，也能比對每個演算法的結果是不是一模一樣 ---------- */
function newAcc(collect) { return { n: 0, s: 0, x: 0, list: collect ? [] : null }; }
function emit(acc, items, v) {
    const a = items.length > 1 ? Array.from(items).sort((p, q) => p - q) : items;
    let h = 0x9e3779b1 ^ v, g = Math.imul(v, 31) + 7;
    for (let k = 0; k < a.length; k++) {
        h = Math.imul(h ^ (a[k] + 1), 0x85ebca6b); h ^= h >>> 13;
        g = Math.imul(g + a[k] + 1, 0xc2b2ae35) ^ (g >>> 16);
    }
    h = Math.imul(h ^ (h >>> 16), 0x27d4eb2d) ^ a.length;
    acc.n++;
    acc.s = (acc.s + (h >>> 0)) % 4294967296;
    acc.x ^= g;
    if (acc.list) acc.list.push([Array.from(a), v]);
}

/* 組合裡的商品 → 兩個 32 位元的位元遮罩（最多 64 種商品），判斷「交易包不包含這個組合」只要兩次 AND */
function masks(sets) {
    const lo = new Int32Array(sets.length), hi = new Int32Array(sets.length);
    sets.forEach((c, j) => { for (const i of c) { if (i < 32) lo[j] |= 1 << i; else hi[j] |= 1 << (i - 32); } });
    return [lo, hi];
}

/* Apriori / Two-Phase 共用：前 k-2 個相同的兩兩合併，再剪掉有子集合不在 L 裡的候選 */
function joinPrune(L, k) {
    const keys = new Set(L.map(x => x.join(',')));
    const C = [];
    for (let a = 0; a < L.length; a++) {
        const A = L[a];
        for (let b = a + 1; b < L.length; b++) {
            const B = L[b];
            let same = true;
            for (let x = 0; x < k - 2; x++) if (A[x] !== B[x]) { same = false; break; }
            if (!same) break;                  // L 照字典順序排，前綴相同的一定連在一起
            const c = A.concat(B[k - 2]);
            let ok = true;
            for (let drop = 0; drop < k - 2 && ok; drop++) {   // 拿掉最後兩個之一就是 A、B 本身，不用查
                if (!keys.has(c.filter((_, idx) => idx !== drop).join(','))) ok = false;
            }
            if (ok) C.push(c);
        }
    }
    return C;
}

/* ================= 頻繁樣式組 ================= */
function apriori(D, minSup, acc) {
    const st = { cands: 0, struct: 0, scans: 1 };
    const cnt = new Int32Array(D.m);
    for (const t of D.tx) for (const i of t) cnt[i]++;
    let L = [];
    for (let i = 0; i < D.m; i++) {
        if (cnt[i] > 0) st.cands++;
        if (cnt[i] >= minSup) { L.push([i]); emit(acc, [i], cnt[i]); }
    }
    st.struct = st.cands;
    for (let k = 2; L.length > 1; k++) {
        const C = joinPrune(L, k);                       // ① 合併 ② 剪枝
        if (!C.length) break;
        st.scans++;                                      // ③ 計數：掃一次資料庫
        st.cands += C.length;
        st.struct = Math.max(st.struct, C.length);
        const [clo, chi] = masks(C), cc = new Int32Array(C.length);
        for (let r = 0; r < D.n; r++) {
            if (D.len[r] < k) continue;
            const tl = D.lo[r], th = D.hi[r];
            for (let j = 0; j < C.length; j++) if ((tl & clo[j]) === clo[j] && (th & chi[j]) === chi[j]) cc[j]++;
        }
        L = [];                                          // ④ 篩選
        for (let j = 0; j < C.length; j++) if (cc[j] >= minSup) { L.push(C[j]); emit(acc, C[j], cc[j]); }
    }
    return st;
}

function fpGrowth(D, minSup, acc) {
    const st = { cands: 0, struct: 0, scans: 2 };
    fpMine(D.tx, null, minSup, [], acc, st, D.m);
    return st;
}
function fpMine(paths, ws, minSup, suffix, acc, st, m) {
    const cnt = new Int32Array(m);
    for (let p = 0; p < paths.length; p++) { const w = ws ? ws[p] : 1; for (const i of paths[p]) cnt[i] += w; }
    const order = [];
    for (let i = 0; i < m; i++) { if (cnt[i] > 0) st.cands++; if (cnt[i] >= minSup) order.push(i); }
    order.sort((a, b) => cnt[b] - cnt[a] || a - b);        // 次數多的排前面
    const rank = new Int32Array(m).fill(-1);
    order.forEach((i, r) => { rank[i] = r; });
    const root = { item: -1, count: 0, parent: null, kids: new Map() };
    const header = order.map(() => []);
    const buf = [];
    for (let p = 0; p < paths.length; p++) {              // 建 FP-tree
        const w = ws ? ws[p] : 1;
        buf.length = 0;
        for (const i of paths[p]) if (rank[i] >= 0) buf.push(rank[i]);
        buf.sort((a, b) => a - b);
        let node = root;
        for (const r of buf) {
            let child = node.kids.get(r);
            if (!child) {
                child = { item: order[r], count: 0, parent: node, kids: new Map() };
                node.kids.set(r, child);
                header[r].push(child);
                st.struct++;
            }
            node = child;
            node.count += w;
        }
    }
    for (let r = order.length - 1; r >= 0; r--) {          // 從次數最少的商品開始挖
        const item = order[r];
        const pattern = [item].concat(suffix);
        emit(acc, pattern, cnt[item]);
        const bp = [], bw = [];                            // 條件模式基底
        for (const node of header[r]) {
            const path = [];
            for (let q = node.parent; q.item >= 0; q = q.parent) path.push(q.item);
            if (path.length) { bp.push(path); bw.push(node.count); }
        }
        if (bp.length) fpMine(bp, bw, minSup, pattern, acc, st, m);
    }
}

function eclat(D, minSup, acc) {
    const st = { cands: 0, struct: 0, scans: 1 };
    const lists = Array.from({ length: D.m }, () => []);
    for (let r = 0; r < D.n; r++) for (const i of D.tx[r]) lists[i].push(r);   // 轉成垂直格式：只掃這一次
    const items = [];
    for (let i = 0; i < D.m; i++) {
        if (lists[i].length) { st.cands++; st.struct += lists[i].length; }
        if (lists[i].length >= minSup) items.push(i);
    }
    items.sort((a, b) => lists[a].length - lists[b].length || a - b);   // 支持度小的排前面，交集比較快變小
    eMine([], items, items.map(i => Int32Array.from(lists[i])), minSup, acc, st);
    return st;
}
function eMine(prefix, items, tids, minSup, acc, st) {
    for (let i = 0; i < items.length; i++) {
        const pattern = prefix.concat(items[i]);
        emit(acc, pattern, tids[i].length);
        const ni = [], nt = [];
        for (let j = i + 1; j < items.length; j++) {
            const t = intersect(tids[i], tids[j]);
            st.cands++;
            st.struct += t.length;
            if (t.length >= minSup) { ni.push(items[j]); nt.push(t); }
        }
        if (ni.length) eMine(pattern, ni, nt, minSup, acc, st);
    }
}
function intersect(a, b) {
    const out = new Int32Array(Math.min(a.length, b.length));
    let p = 0, q = 0, k = 0;
    while (p < a.length && q < b.length) {
        if (a[p] === b[q]) { out[k++] = a[p]; p++; q++; }
        else if (a[p] < b[q]) p++;
        else q++;
    }
    return out.subarray(0, k);
}

/* ================= 高效益樣式組 ================= */
function txUtil(D) {
    const tu = new Float64Array(D.n), twu = new Float64Array(D.m), miu = new Float64Array(D.m).fill(Infinity);
    for (let r = 0; r < D.n; r++) {
        let s = 0;
        for (let k = 0; k < D.len[r]; k++) {
            const u = D.qty[r][k] * D.profit[D.tx[r][k]];
            s += u;
            if (u < miu[D.tx[r][k]]) miu[D.tx[r][k]] = u;
        }
        tu[r] = s;
        for (const i of D.tx[r]) twu[i] += s;
    }
    return { tu, twu, miu };
}

/* 掃一次資料庫，算每個候選真正的效益 */
function exactUtil(D, cands) {
    const [clo, chi] = masks(cands), util = new Float64Array(cands.length), uq = new Float64Array(D.m);
    for (let r = 0; r < D.n; r++) {
        const tl = D.lo[r], th = D.hi[r], t = D.tx[r], q = D.qty[r];
        for (let k = 0; k < t.length; k++) uq[t[k]] = q[k] * D.profit[t[k]];
        for (let j = 0; j < cands.length; j++) {
            if ((tl & clo[j]) === clo[j] && (th & chi[j]) === chi[j]) {
                const c = cands[j];
                let s = 0;
                for (let x = 0; x < c.length; x++) s += uq[c[x]];
                util[j] += s;
            }
        }
    }
    return util;
}

function twoPhase(D, minUtil, acc) {
    const st = { cands: 0, struct: 0, scans: 1 };
    const { tu, twu } = txUtil(D);
    const order = [];
    for (let i = 0; i < D.m; i++) { if (twu[i] > 0) st.cands++; if (twu[i] >= minUtil) order.push(i); }
    order.sort((a, b) => twu[a] - twu[b] || a - b);         // TWU 由小到大
    // 在「名次」空間裡做 Apriori 式的合併（名次照 TWU 排），要數的時候再換回商品編號
    let L = order.map((_, r) => [r]);
    const cands = order.map(i => [i]);
    for (let k = 2; L.length > 1; k++) {
        const C = joinPrune(L, k);
        if (!C.length) break;
        st.scans++;
        st.cands += C.length;
        const items = C.map(c => c.map(r => order[r]));
        const [clo, chi] = masks(items), ctw = new Float64Array(C.length);
        for (let r = 0; r < D.n; r++) {
            if (D.len[r] < k) continue;
            const tl = D.lo[r], th = D.hi[r];
            for (let j = 0; j < C.length; j++) if ((tl & clo[j]) === clo[j] && (th & chi[j]) === chi[j]) ctw[j] += tu[r];
        }
        L = [];
        for (let j = 0; j < C.length; j++) if (ctw[j] >= minUtil) { L.push(C[j]); cands.push(items[j]); }
    }
    // 第二階段：再掃一次，算候選真正的效益
    st.scans++;
    st.struct = cands.length;
    const util = exactUtil(D, cands);
    for (let j = 0; j < cands.length; j++) if (util[j] >= minUtil) emit(acc, cands[j], util[j]);
    return st;
}

function huiMiner(D, minUtil, acc) {
    const st = { cands: 0, struct: 0, scans: 2 };
    const { twu } = txUtil(D);
    const order = [];
    for (let i = 0; i < D.m; i++) if (twu[i] >= minUtil) order.push(i);
    order.sort((a, b) => twu[a] - twu[b] || a - b);
    const rank = new Int32Array(D.m).fill(-1);
    order.forEach((i, r) => { rank[i] = r; });
    const raw = order.map(() => ({ tid: [], iu: [], ru: [] }));
    const buf = [];
    for (let r = 0; r < D.n; r++) {                          // 第 2 次掃描：建每個商品的 utility list
        buf.length = 0;
        for (let k = 0; k < D.len[r]; k++) { const x = rank[D.tx[r][k]]; if (x >= 0) buf.push([x, D.qty[r][k] * D.profit[D.tx[r][k]]]); }
        buf.sort((a, b) => b[0] - a[0]);
        let rutil = 0;
        for (const [x, u] of buf) { raw[x].tid.push(r); raw[x].iu.push(u); raw[x].ru.push(rutil); rutil += u; }
    }
    const uls = order.map((item, x) => ulist(item, Int32Array.from(raw[x].tid), Float64Array.from(raw[x].iu), Float64Array.from(raw[x].ru)));
    st.cands = uls.length;
    for (const u of uls) st.struct += u.tid.length;
    hSearch([], null, uls, minUtil, acc, st);
    return st;
}
function ulist(item, tid, iu, ru) {
    let si = 0, sr = 0;
    for (let k = 0; k < tid.length; k++) { si += iu[k]; sr += ru[k]; }
    return { item, tid, iu, ru, sumI: si, sumR: sr };
}
function hSearch(prefix, P, uls, minUtil, acc, st) {
    for (let i = 0; i < uls.length; i++) {
        const X = uls[i];
        const pattern = prefix.concat(X.item);
        if (X.sumI >= minUtil) emit(acc, pattern, X.sumI);
        if (X.sumI + X.sumR < minUtil) continue;             // 再怎麼往下加也不夠，剪掉
        const ext = [];
        for (let j = i + 1; j < uls.length; j++) {
            const xy = construct(P, X, uls[j]);
            st.cands++;
            st.struct += xy.tid.length;
            if (xy.tid.length) ext.push(xy);
        }
        if (ext.length) hSearch(pattern, X, ext, minUtil, acc, st);
    }
}
function construct(P, X, Y) {
    const n = Math.min(X.tid.length, Y.tid.length);
    const tid = new Int32Array(n), iu = new Float64Array(n), ru = new Float64Array(n);
    let a = 0, b = 0, c = 0, k = 0;
    while (a < X.tid.length && b < Y.tid.length) {
        const t = X.tid[a];
        if (t === Y.tid[b]) {
            let u = X.iu[a] + Y.iu[b];
            if (P) { while (P.tid[c] !== t) c++; u -= P.iu[c]; }   // P 的效益兩邊都算了，扣掉一次
            tid[k] = t; iu[k] = u; ru[k] = Y.ru[b]; k++;
            a++; b++;
        } else if (t < Y.tid[b]) a++;
        else b++;
    }
    return ulist(Y.item, tid.subarray(0, k), iu.subarray(0, k), ru.subarray(0, k));
}

function upTree(order, m) {
    return { root: { item: -1, count: 0, nu: 0, parent: null, kids: new Map() }, order, links: new Array(m) };
}
function upAdd(tree, path, nus, count, st) {
    let node = tree.root;
    for (let k = 0; k < path.length; k++) {
        const item = path[k];
        let child = node.kids.get(item);
        if (!child) {
            child = { item, count: 0, nu: 0, parent: node, kids: new Map() };
            node.kids.set(item, child);
            (tree.links[item] || (tree.links[item] = [])).push(child);
            st.nodes++;
        }
        node = child;
        node.count += count;
        node.nu += nus[k];
    }
}
function upGrowth(D, minUtil, acc) {
    const st = { cands: 0, struct: 0, scans: 3, nodes: 0 };
    const { twu, miu } = txUtil(D);
    const order = [];
    for (let i = 0; i < D.m; i++) if (twu[i] >= minUtil) order.push(i);
    order.sort((a, b) => twu[b] - twu[a] || a - b);           // DGU：TWU 由大到小
    const rank = new Int32Array(D.m).fill(-1);
    order.forEach((i, r) => { rank[i] = r; });
    const tree = upTree(order, D.m);
    const buf = [];
    for (let r = 0; r < D.n; r++) {
        buf.length = 0;
        for (let k = 0; k < D.len[r]; k++) if (rank[D.tx[r][k]] >= 0) buf.push([rank[D.tx[r][k]], D.tx[r][k], D.qty[r][k] * D.profit[D.tx[r][k]]]);
        buf.sort((a, b) => a[0] - b[0]);
        let accu = 0;
        const path = [], nus = [];
        for (const [, i, u] of buf) { accu += u; path.push(i); nus.push(accu); }   // DGN
        upAdd(tree, path, nus, 1, st);
    }
    const cands = [];
    upMine(tree, [], minUtil, miu, cands, st, D.m);
    st.struct = cands.length;
    const util = exactUtil(D, cands);                       // 第 3 次掃描：驗證候選
    for (let j = 0; j < cands.length; j++) if (util[j] >= minUtil) emit(acc, cands[j], util[j]);
    return st;
}
function upMine(tree, suffix, minUtil, miu, cands, st, m) {
    for (let idx = tree.order.length - 1; idx >= 0; idx--) {
        const item = tree.order[idx];
        const nodes = tree.links[item] || [];
        let est = 0;
        for (const n of nodes) est += n.nu;
        st.cands++;
        if (est < minUtil) continue;
        const pattern = [item].concat(suffix);
        cands.push(pattern);
        const paths = [], lu = new Float64Array(m);
        for (const n of nodes) {
            const path = [];
            for (let p = n.parent; p.item >= 0; p = p.parent) { path.push(p.item); lu[p.item] += n.nu; }
            path.reverse();
            paths.push(path);
        }
        const local = upTree(tree.order.filter(i => lu[i] >= minUtil), m);   // DLU
        nodes.forEach((n, k) => {
            const path = paths[k], pc = n.count;
            let pu = n.nu, rest = 0;
            const keep = [];
            for (const i of path) { if (lu[i] >= minUtil) { keep.push(i); rest += miu[i] * pc; } else pu -= miu[i] * pc; }
            const nus = [];
            for (const i of keep) { rest -= miu[i] * pc; nus.push(pu - rest); }   // DLN
            upAdd(local, keep, nus, pc, st);
        });
        if (local.order.length) upMine(local, pattern, minUtil, miu, cands, st, m);
    }
}

/* EFIM：在越來越小的投影資料庫上找，一樣的交易合併成一筆；su（sub-tree utility）、lu（local utility）用 utility-bin 一次算好 */
function efim(D, minUtil, acc) {
    const st = { cands: 0, struct: 0, scans: 2 };
    const { twu } = txUtil(D);
    const order = [];
    for (let i = 0; i < D.m; i++) if (twu[i] >= minUtil) order.push(i);
    order.sort((a, b) => twu[a] - twu[b] || a - b);
    const rank = new Int32Array(D.m).fill(-1);
    order.forEach((i, r) => { rank[i] = r; });
    const trans = [];
    for (let r = 0; r < D.n; r++) {                          // 第 2 次掃描：只留 TWU 夠的商品，照名次排
        const row = [];
        for (let k = 0; k < D.len[r]; k++) { const x = rank[D.tx[r][k]]; if (x >= 0) row.push([x, D.qty[r][k] * D.profit[D.tx[r][k]]]); }
        if (!row.length) continue;
        row.sort((a, b) => a[0] - b[0]);
        trans.push({ items: Int32Array.from(row, x => x[0]), utils: Float64Array.from(row, x => x[1]), pu: 0, own: true });
    }
    trans.sort((a, b) => {                                   // 反向字典序：投影後一樣的交易會排在一起
        let i = a.items.length - 1, j = b.items.length - 1;
        for (; i >= 0 && j >= 0; i--, j--) if (a.items[i] !== b.items[j]) return a.items[i] - b.items[j];
        return (i + 1) - (j + 1);
    });
    st.struct = trans.length;
    const all = order.map((_, r) => r);
    const su = new Float64Array(order.length), lu = new Float64Array(order.length), mark = new Uint8Array(order.length);
    efimBins(trans, all, su, lu, mark);
    efimSearch([], trans, all.filter(z => su[z] >= minUtil), all, order, minUtil, acc, st);
    return st;
}
function efimBins(pdb, keep, su, lu, mark) {
    for (const z of keep) { su[z] = 0; lu[z] = 0; mark[z] = 1; }
    for (const tr of pdb) {
        let rest = 0;
        for (let k = 0; k < tr.utils.length; k++) rest += tr.utils[k];
        let after = 0;
        for (let k = tr.items.length - 1; k >= 0; k--) {
            const z = tr.items[k];
            if (mark[z]) { after += tr.utils[k]; su[z] += tr.pu + after; lu[z] += tr.pu + rest; }
        }
    }
    for (const z of keep) mark[z] = 0;
}
function efimSearch(prefix, pdb, primary, secondary, order, minUtil, acc, st) {
    const m = order.length;
    for (const i of primary) {
        let util = 0;
        const proj = [];
        for (const tr of pdb) {
            const its = tr.items;
            let a = 0, b = its.length - 1, k = -1;
            while (a <= b) { const c = (a + b) >> 1; if (its[c] === i) { k = c; break; } if (its[c] < i) a = c + 1; else b = c - 1; }
            if (k < 0) continue;
            util += tr.pu + tr.utils[k];
            if (k + 1 === its.length) continue;
            const items = its.subarray(k + 1), utils = tr.utils.subarray(k + 1), pu = tr.pu + tr.utils[k];
            const last = proj[proj.length - 1];
            let same = !!last && last.items.length === items.length;
            for (let x = 0; same && x < items.length; x++) if (last.items[x] !== items[x]) same = false;
            if (same) {                                      // 交易合併：剩下的商品完全一樣
                if (!last.own) { last.utils = Float64Array.from(last.utils); last.own = true; }
                for (let x = 0; x < utils.length; x++) last.utils[x] += utils[x];
                last.pu += pu;
            } else proj.push({ items, utils, pu, own: false });
        }
        st.cands++;
        st.struct += proj.length;
        const beta = prefix.concat(order[i]);
        if (util >= minUtil) emit(acc, beta, util);
        const keep = secondary.filter(z => z > i);
        if (!keep.length || !proj.length) continue;
        const su = new Float64Array(m), lu = new Float64Array(m);
        efimBins(proj, keep, su, lu, new Uint8Array(m));
        const ns = keep.filter(z => lu[z] >= minUtil);
        const np = ns.filter(z => su[z] >= minUtil);
        if (np.length) efimSearch(beta, proj, np, ns, order, minUtil, acc, st);
    }
}

const ALGOS = {
    freq: { apriori, fpgrowth: fpGrowth, eclat },
    hui: { twophase: twoPhase, huiminer: huiMiner, upgrowth: upGrowth, efim }
};

/* 量一個演算法：跑一次；太快（< 5 ms）就連續多跑幾次取平均，避開計時器的解析度 */
function measure(D, group, algo, thr) {
    const f = ALGOS[group][algo];
    const acc = newAcc(false);
    let t0 = performance.now();
    const st = f(D, thr, acc);
    let ms = performance.now() - t0, iters = 1;
    if (ms < 5) {
        let k = 0;
        t0 = performance.now();
        do { f(D, thr, newAcc(false)); k++; } while (performance.now() - t0 < 30 && k < 5000);
        ms = (performance.now() - t0) / k;
        iters = k;
    }
    return { ms, iters, n: acc.n, fp: acc.n + ':' + acc.s + ':' + acc.x, cands: st.cands, struct: st.struct, scans: st.scans };
}

/* 測試用：直接拿到全部樣式 */
function collect(D, group, algo, thr) {
    const acc = newAcc(true);
    const st = ALGOS[group][algo](D, thr, acc);
    return { list: acc.list, st };
}

if (typeof importScripts === 'function') {
    let DATA = null;
    self.onmessage = e => {
        const msg = e.data;
        try {
            if (msg.cmd === 'data') {
                DATA = makeData(msg.spec);
                self.postMessage({ id: msg.id, ok: true, stats: dataStats(DATA) });
            } else if (msg.cmd === 'run') {
                self.postMessage({ id: msg.id, ok: true, res: measure(DATA, msg.group, msg.algo, msg.thr) });
            }
        } catch (err) {
            self.postMessage({ id: msg.id, ok: false, error: String(err && err.message || err) });
        }
    };
}
