// 離線用：已經載入過的檔案（含 7 MB 的 Stockfish WASM）存一份在瀏覽器。
// 有網路時一律先拿最新的（network-first），斷線才用存下來的，所以更新網站不會卡在舊版。
const CACHE = 'jellyfish-chess-v2';
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(
  caches.keys().then(ks => Promise.all(ks.filter(k => k.startsWith('jellyfish-chess-') && k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())));
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  const scope = new URL(self.registration.scope);
  // 只管這個資料夾裡的檔案與網站共用的 assets（字型等外部資源不管）
  if (url.origin !== scope.origin) return;
  if (!url.pathname.startsWith(scope.pathname) && !url.pathname.includes('/assets/')) return;
  e.respondWith(
    fetch(req, { cache: 'no-cache' }).then(res => {
      if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); }
      return res;
    }).catch(() => caches.match(req, { ignoreSearch: true }).then(r => r || Response.error()))
  );
});
