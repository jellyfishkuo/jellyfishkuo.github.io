// 資料都留在這台裝置的瀏覽器裡：長期資料放 IndexedDB，偏好設定放 localStorage。
// IndexedDB 被擋（無痕模式、Safari 某些設定）時改用記憶體，頁面照樣能用，只是關掉就不見。
const DB_NAME = 'jellyfish-chess';
const DB_VERSION = 1;
export const STORES = {
  games: 'id',          // 對局：{id, date, pgn, result, white, black, mode, level, myColor, outcome}
  analyses: 'id',       // 分析結果：{id, date, title, pgn, evals:[], tags}
  puzzleStats: 'id',    // 每題戰術：{id, tries, solved, fails, lastResult, lastDate, firstTry}
  attempts: 'id',       // 每次答題紀錄：{id, puzzleId, date, ok, themes}
  favorites: 'id',      // 收藏：{id:'puzzle:xxx' | 'opening:xxx', kind, ref, date}
  notes: 'id',          // 筆記：{id, date, updated, title, body, fen}
};
const PREF_KEY = 'jfk-chess-prefs-v1';

let dbp = null;
let memory = null;     // 退而求其次：記憶體
function openDB() {
  if (dbp) return dbp;
  dbp = new Promise(resolve => {
    let req;
    try { req = indexedDB.open(DB_NAME, DB_VERSION); } catch (e) { resolve(null); return; }
    req.onupgradeneeded = () => {
      const db = req.result;
      for (const [name, key] of Object.entries(STORES))
        if (!db.objectStoreNames.contains(name)) db.createObjectStore(name, { keyPath: key });
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => resolve(null);
    req.onblocked = () => resolve(null);
  }).then(db => {
    if (!db) memory = Object.fromEntries(Object.keys(STORES).map(k => [k, new Map()]));
    return db;
  });
  return dbp;
}
export async function persistent() { return !!(await openDB()); }

function reqP(r) { return new Promise((res, rej) => { r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error); }); }
async function tx(store, mode, fn) {
  const db = await openDB();
  if (!db) return fn(null, memory[store]);
  const t = db.transaction(store, mode);
  const os = t.objectStore(store);
  const done = new Promise((res, rej) => { t.oncomplete = res; t.onerror = () => rej(t.error); t.onabort = () => rej(t.error); });
  const out = await fn(os, null);
  await done;
  return out;
}

export const db = {
  async put(store, obj) {
    return tx(store, 'readwrite', (os, mem) => (mem ? (mem.set(obj.id, structuredClone(obj)), obj.id) : reqP(os.put(obj))));
  },
  async get(store, id) {
    return tx(store, 'readonly', (os, mem) => (mem ? structuredClone(mem.get(id)) : reqP(os.get(id))));
  },
  async all(store) {
    return tx(store, 'readonly', (os, mem) => (mem ? [...mem.values()].map(v => structuredClone(v)) : reqP(os.getAll())));
  },
  async del(store, id) {
    return tx(store, 'readwrite', (os, mem) => (mem ? mem.delete(id) : reqP(os.delete(id))));
  },
  async clear(store) {
    return tx(store, 'readwrite', (os, mem) => (mem ? mem.clear() : reqP(os.clear())));
  },
};
export const uid = (p = '') => p + Date.now().toString(36) + Math.random().toString(36).slice(2, 7);

// ── 偏好設定（localStorage，包 try/catch） ──
const DEFAULT_PREFS = { level: 4, movetime: 1000, color: 'w', coords: true, sound: false, legal: true, analysisDepth: 14 };
export function prefs() {
  try { return { ...DEFAULT_PREFS, ...(JSON.parse(localStorage.getItem(PREF_KEY)) || {}) }; }
  catch (e) { return { ...DEFAULT_PREFS }; }
}
export function setPref(k, v) {
  const p = prefs(); p[k] = v;
  try { localStorage.setItem(PREF_KEY, JSON.stringify(p)); } catch (e) { /* 被擋就只在這次有效 */ }
  return p;
}

// ── 備份／還原 ──
export async function backup() {
  const data = { app: 'jellyfish-chess', format: 1, exportedAt: new Date().toISOString(), prefs: prefs(), stores: {} };
  for (const s of Object.keys(STORES)) data.stores[s] = await db.all(s);
  return data;
}
/** 驗證備份檔；回傳錯誤訊息或 null */
export function checkBackup(data) {
  if (!data || typeof data !== 'object') return '不是 JSON 物件';
  if (data.app !== 'jellyfish-chess') return '這不是 Jellyfish Chess 的備份檔';
  if (typeof data.format !== 'number' || data.format > 1) return '備份檔版本比這個網頁新，請先重新整理頁面';
  if (!data.stores || typeof data.stores !== 'object') return '備份檔裡沒有資料';
  for (const [s, rows] of Object.entries(data.stores)) {
    if (!(s in STORES)) continue;
    if (!Array.isArray(rows)) return `「${s}」的格式不對`;
    if (rows.some(r => !r || typeof r !== 'object' || typeof r.id !== 'string')) return `「${s}」裡有資料缺少 id`;
  }
  return null;
}
/** mode: 'replace'（清空再還原）或 'merge'（同 id 覆蓋，其餘保留） */
export async function restore(data, mode = 'replace') {
  const err = checkBackup(data);
  if (err) throw new Error(err);
  const counts = {};
  for (const s of Object.keys(STORES)) {
    const rows = data.stores[s] || [];
    if (mode === 'replace') await db.clear(s);
    for (const r of rows) await db.put(s, r);
    counts[s] = rows.length;
  }
  if (data.prefs && typeof data.prefs === 'object') {
    try { localStorage.setItem(PREF_KEY, JSON.stringify({ ...DEFAULT_PREFS, ...data.prefs })); } catch (e) { /* ignore */ }
  }
  return counts;
}
