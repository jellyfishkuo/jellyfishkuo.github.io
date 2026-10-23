/* 果汁龍手上拿的東西可以換（寵物升級的獎勵）。
 * 身體跟 assets/dragon.svg 一樣，只有手上那一杯換掉；改 dragon.svg 的身體時這裡也要一起改。
 * 用法：jfkDragon('cola') 回傳 <svg> 字串；jfkDragonURL('cola') 回傳 data: URL（給 <img>、canvas 用）。
 * 寵物頁、首頁那隻、跑酷都讀 localStorage jfk-pet-v1 的 hold。 */
(function () {
    var STRAW = '<path d="M11 33 L13 29.2" stroke="#f2f2f2" stroke-width="2" stroke-linecap="round"/>';
    // [代號, 衣櫃圖示, 名稱, 幾級解鎖, 畫法]
    var HOLDS = [
        ['juice', '🧃', '蘋果汁', 1,
            STRAW +
            '<rect x="5" y="32" width="11" height="14" rx="2" fill="#ffb02e"/>' +
            '<path d="M5 34 a2 2 0 0 1 2 -2 h7 a2 2 0 0 1 2 2 v1.5 h-11 z" fill="#ff8a1f"/>' +
            '<circle cx="9.4" cy="41" r="2.2" fill="#e8413c"/><circle cx="11.6" cy="41" r="2.2" fill="#e8413c"/>' +
            '<path d="M10.5 38.8 c0 -1.2 0.6 -2 1.6 -2.4" stroke="#6b3b1a" stroke-width="0.8" stroke-linecap="round" fill="none"/>' +
            '<path d="M11 38 c1.2 -1.4 2.6 -1.2 3 -0.8 c-0.8 1 -2 1.3 -3 0.8 z" fill="#4caf2a"/>'],
        ['milk', '🥛', '牛奶', 3,
            '<path d="M5.5 33.5 L8 30 H13 L15.5 33.5 Z" fill="#dfe8f5" stroke="#8aa2c4" stroke-width="0.7" stroke-linejoin="round"/>' +
            '<rect x="5.5" y="33.5" width="10" height="12.5" rx="1.2" fill="#ffffff" stroke="#8aa2c4" stroke-width="0.7"/>' +
            '<rect x="5.5" y="38" width="10" height="3.6" fill="#3b82f6"/>' +
            '<circle cx="10.5" cy="43.6" r="1" fill="#3b82f6"/>'],
        ['cola', '🥤', '可樂', 5,
            '<path d="M11 31.5 L13 27.6" stroke="#f2f2f2" stroke-width="2" stroke-linecap="round"/>' +
            '<rect x="6" y="31.5" width="9" height="14.5" rx="2" fill="#d62828"/>' +
            '<rect x="6.6" y="31" width="7.8" height="1.5" rx="0.7" fill="#d9d9d9"/>' +
            '<rect x="6.6" y="45.2" width="7.8" height="1.3" rx="0.6" fill="#bdbdbd"/>' +
            '<path d="M6 39.6 c3 -2.2 6 1.2 9 -1.4 v1.7 c-3 2.4 -6 -0.8 -9 1.4 z" fill="#ffffff"/>'],
        ['lemon', '🍋', '檸檬汁', 7,
            STRAW +
            '<path d="M5 32 H16 L14.8 46 H6.2 Z" fill="#fff8c4"/>' +
            '<path d="M5.3 35 H15.7 L14.8 46 H6.2 Z" fill="#ffe14d"/>' +
            '<circle cx="14.6" cy="32.2" r="2.6" fill="#fff176" stroke="#f5c400" stroke-width="0.7"/>' +
            '<path d="M14.6 30 V34.4 M12.6 32.2 H16.6" stroke="#f5c400" stroke-width="0.5"/>'],
        ['melon', '🍉', '西瓜汁', 12,
            STRAW +
            '<path d="M5 32 H16 L14.8 46 H6.2 Z" fill="#ffe3e8"/>' +
            '<path d="M5.3 34.5 H15.7 L14.8 46 H6.2 Z" fill="#ff6b81"/>' +
            '<path d="M12 31.4 a3.2 3.2 0 0 0 6 0 z" fill="#ff4d6d" stroke="#2e9e44" stroke-width="0.9"/>' +
            '<circle cx="14.4" cy="32.3" r="0.35" fill="#222"/><circle cx="15.8" cy="32.5" r="0.35" fill="#222"/>'],
        ['boba', '🧋', '珍珠奶茶', 17,
            '<path d="M10.5 33 L12.6 26.8" stroke="#ff7eb6" stroke-width="2.4" stroke-linecap="round"/>' +
            '<path d="M5 31.5 H16 L14.6 46 H6.4 Z" fill="#e2bf8f"/>' +
            '<path d="M4.6 31.6 a5.9 2.4 0 0 1 11.8 0 z" fill="#ffffff" opacity="0.85"/>' +
            '<g fill="#3b2314"><circle cx="7.6" cy="44.4" r="1"/><circle cx="9.8" cy="44.6" r="1"/><circle cx="12" cy="44.4" r="1"/><circle cx="13.6" cy="43" r="1"/><circle cx="8.6" cy="42.6" r="1"/><circle cx="11" cy="42.7" r="1"/></g>']
    ];
    var BODY =
        '<path d="M30.5 11.4 L35.8 8.2 L35.6 14.6 Z M36.8 15 L43.2 15.8 L38.4 21.4 Z M38.3 23.6 L44.6 25.6 L39 30.4 Z M40.8 34.2 L48 32.6 L45.6 38.6 Z M47.6 40.3 L55.2 37.8 L53.2 42.6 Z" fill="#5fa318"/>' +
        '<ellipse cx="27" cy="48.7" rx="2" ry="1.9" fill="#6fae1f"/><ellipse cx="33" cy="48.8" rx="2" ry="1.9" fill="#6fae1f"/>' +
        '<path d="M10.5 19 C10.5 13 16 10 23 10 C31 10 37 13 38 19 C39 24 37 27 39 31 C42 37 48 41 56 43 C59 44 59 47 56 47 L31 48 C24 48 20 45 20 39 C20 35 21 32 23 29.5 C16 29.5 10.5 26 10.5 19 Z" fill="#9bd72f"/>' +
        '<circle cx="18.5" cy="15.8" r="1.6" fill="#111"/>' +
        '<path d="M18.2 23.7 l3 -0.3 l-1.2 3.1 z" fill="#fff"/>' +
        '<path d="M12.4 22.6 c3 1.3 6.6 1.5 10 0.5" stroke="#2c4a12" stroke-width="1.4" stroke-linecap="round" fill="none"/>';
    var HAND =
        '<ellipse cx="17.8" cy="38.6" rx="3" ry="2.3" fill="#7cbb22"/>' +
        '<path d="M15.5 37.4 c-0.8 0.3 -0.8 1.2 0 1.4 M15.5 39.2 c-0.8 0.3 -0.8 1.2 0 1.4" stroke="#5a8f18" stroke-width="0.8" stroke-linecap="round" fill="none"/>';

    function find(id) {
        for (var i = 0; i < HOLDS.length; i++) if (HOLDS[i][0] === id) return HOLDS[i];
        return HOLDS[0];
    }
    window.JFK_HOLDS = HOLDS.map(function (h) { return h.slice(0, 4); });
    window.jfkDragon = function (id) {
        return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="4 10 56 46"><g transform="translate(0 4)">' +
            BODY + find(id)[4] + HAND + '</g></svg>';
    };
    window.jfkDragonURL = function (id) { return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(window.jfkDragon(id)); };
    // 目前寵物手上拿的（讀不到就是蘋果汁）
    window.jfkPetHold = function () {
        try { var p = JSON.parse(localStorage.getItem('jfk-pet-v1') || '{}'); return p && typeof p.hold === 'string' ? find(p.hold)[0] : 'juice'; } catch (e) { return 'juice'; }
    };
})();
