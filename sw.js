/* 整個網站的離線快取（加到手機主畫面後，沒網路也能玩）。
 * 策略：一律「先抓網路、成功就順手存一份；抓不到才拿存的」——有網路時永遠是最新版，不會卡在舊版。
 * 第一次打開時先把首頁和遊戲頁存起來（CORE）；研究 Demo 比較大，看過哪頁才存哪頁。
 * 西洋棋有自己的 games/chess/sw.js（範圍比較小，那個資料夾歸它管）。
 * 新增遊戲時把頁面加進 CORE；改了 CORE 或快取規則就把 VERSION 加一，舊的快取會在新版啟用時清掉。 */
const VERSION = 'jfk-site-v1';
const CORE = [
    './', 'index.html', '404.html', 'manifest.webmanifest',
    'assets/theme.js', 'assets/theme.css', 'assets/dragon.svg', 'assets/dragon-hold.js', 'assets/pet-mini.js', 'assets/quest.js',
    'assets/logo.svg', 'assets/logo-32.png', 'assets/logo-180.png', 'assets/app-192.png',
    'games/zip.html', 'games/schulte.html', 'games/runner.html', 'games/pet.html', 'games/pentomino.html', 'games/game-set.html',
    'games/hanoi.html', 'games/store-manager.html', 'games/lab-life.html', 'games/dinner-wheel.html', 'games/1A2B.html',
    'games/infinite-tictactoe.html', 'games/vertical-gomoku.html', 'games/coc-card.html',
    'electricity-tracker/', 'electricity-tracker/index.html', 'electricity-tracker/script.js', 'electricity-tracker/style.css',
    'research/quest.html'
];

self.addEventListener('install', e => {
    e.waitUntil(caches.open(VERSION).then(c => Promise.all(CORE.map(u => c.add(u).catch(() => { /* 一頁失敗不要整個裝不起來 */ }))))
        .then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
    e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k.startsWith('jfk-site-') && k !== VERSION).map(k => caches.delete(k))))
        .then(() => self.clients.claim()));
});

const OFFLINE = '<!DOCTYPE html><html lang="zh-TW"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1">' +
    '<title>沒有網路</title><style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#05050a;color:#e6e6f0;' +
    'font-family:-apple-system,"PingFang TC","Noto Sans TC",sans-serif;text-align:center;padding:24px}a{color:#06b6d4}</style></head>' +
    '<body><div><p style="font-size:3rem;margin:0">🐲</p><h1 style="font-size:1.3rem">現在沒有網路</h1>' +
    '<p>這一頁還沒存到手機裡。之前看過的頁面和小遊戲離線也能玩。</p><p><a href="./">回首頁</a></p></div></body></html>';

self.addEventListener('fetch', e => {
    const req = e.request;
    if (req.method !== 'GET' || !/^https?:/.test(req.url)) return;
    e.respondWith((async () => {
        try {
            const res = await fetch(req);
            // 正常的回應才存（跨網域的字型、CDN 會是 opaque，也存）；部分內容（206）不存
            if (res && (res.ok || res.type === 'opaque') && res.status !== 206) {
                const copy = res.clone();
                caches.open(VERSION).then(c => c.put(req, copy)).catch(() => {});
            }
            return res;
        } catch (err) {
            const hit = await caches.match(req, { ignoreSearch: req.mode === 'navigate' });
            if (hit) return hit;
            if (req.mode === 'navigate') {
                // 網址結尾是 / 的頁面，試試看存的 index.html
                const url = new URL(req.url);
                if (url.pathname.endsWith('/')) {
                    const idx = await caches.match(url.pathname + 'index.html');
                    if (idx) return idx;
                }
                return new Response(OFFLINE, { headers: { 'Content-Type': 'text/html; charset=utf-8' } });
            }
            throw err;
        }
    })());
});
