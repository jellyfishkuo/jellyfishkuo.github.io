/* 果汁龍的小禮物＋其他遊戲送的果汁（寵物頁、遊戲頁共用）。
 *
 * 1) 遊戲過關時呼叫（沒載入這支也不會出錯，呼叫前先檢查）：
 *      if (window.jfkReward) jfkReward('hanoi', 3, { key: '同一局只算一次的代號', gift: 'tower' });
 *    - 果汁記在 localStorage jfk-gifts-v1 的 juice[遊戲]，寵物頁 sources() 會加進去（GAMES 是名稱與說明）
 *    - gift：第一次拿到才算，記在 gifts[代號] = 日期
 *    - key：同一個 key 只算一次（重新整理、連線重送畫面都不會重複拿）
 *    - 有載入 pet-mini.js 的頁面，右下角的果汁龍會說「+3 瓶」「拿到小禮物」
 * 2) GIFTS：禮物櫃的清單。got(ctx) 回傳拿到了沒有；有些看遊戲本來就有的紀錄（拿過的人不用重玩），
 *    有些看 jfkReward 記的 gifts。寵物頁可以把拿到的禮物擺 3 個在房間裡（pet.shelf）。
 * 新增遊戲：在 GAMES 加一行、GIFTS 加一個禮物，遊戲過關處呼叫 jfkReward；頁面 <head> 要載入這支。 */
(function () {
    var KEY = 'jfk-gifts-v1';
    function read(k) {
        try { var v = JSON.parse(localStorage.getItem(k) || '{}'); return v && typeof v === 'object' && !Array.isArray(v) ? v : {}; }
        catch (e) { return {}; }
    }
    function data() {
        var d = read(KEY);
        if (!d.juice || typeof d.juice !== 'object') d.juice = {};
        if (!d.plays || typeof d.plays !== 'object') d.plays = {};
        if (!d.gifts || typeof d.gifts !== 'object') d.gifts = {};
        if (!Array.isArray(d.keys)) d.keys = [];
        return d;
    }

    // 送果汁的遊戲（href 從網站根目錄算）
    var GAMES = {
        pentomino: { name: 'Pentomino 每日挑戰', href: 'games/pentomino.html', how: '每天完成一次 2 瓶', unit: '天' },
        'game-set': { name: 'SET 練功房', href: 'games/game-set.html', how: '玩完一局 2 瓶，贏電腦或朋友 3 瓶', unit: '局' },
        '1A2B': { name: '1A2B 猜數字', href: 'games/1A2B.html', how: '猜中 1 瓶，6 次內猜中 2 瓶', unit: '局' },
        'infinite-tictactoe': { name: '無限井字棋', href: 'games/infinite-tictactoe.html', how: '贏電腦 1～3 瓶（看強度）', unit: '局' },
        'vertical-gomoku': { name: '立式五子棋', href: 'games/vertical-gomoku.html', how: '贏電腦 1～3 瓶（看強度）', unit: '局' },
        hanoi: { name: '河內塔', href: 'games/hanoi.html', how: '搬完 1 瓶；沒看提示又最少步數，再多（盤子數 − 3）瓶', unit: '次' },
        chess: { name: 'Jellyfish Chess', href: 'games/chess/', how: '贏電腦 3 瓶、和棋 2、下完 1；戰術題一次答對 1 瓶', unit: '次' }
    };

    // [代號, 圖示, 名稱, 哪個遊戲（href）, 怎麼拿, 拿到了沒]
    function rec(ctx, k) { return ctx.read(k); }
    function has(id) { return function (ctx) { return !!ctx.gifts[id]; }; }
    var GIFTS = [
        ['puzzle', '🧩', '拼圖抱枕', 'games/pentomino.html', '完成一次 Pentomino 每日挑戰', has('puzzle')],
        ['setcard', '🃏', 'SET 幸運牌', 'games/game-set.html', 'SET 贏電腦或朋友一局', has('setcard')],
        ['lock', '🔐', '密碼鎖', 'games/1A2B.html', '1A2B 用 5 次以內猜中', has('lock')],
        ['ring', '⭕', '圈圈抱枕', 'games/infinite-tictactoe.html', '無限井字棋贏「困難」的電腦', has('ring')],
        ['stone', '🔴', '紅色棋子', 'games/vertical-gomoku.html', '立式五子棋贏「困難」的電腦', has('stone')],
        ['tower', '🗼', '河內小塔', 'games/hanoi.html', '河內塔 7 片以上、不看提示、用最少步數搬完', has('tower')],
        ['knight', '♟️', '小兵', 'games/chess/', '西洋棋贏 Stockfish 一盤', has('knight')],
        ['ball', '🎱', '賓果球', 'games/bingo.html', '賓果連線贏一局', function (c) { return (rec(c, 'jfk-bingo-v1').wins || 0) > 0; }],
        ['pencil', '✏️', '一筆畫鉛筆', 'games/zip.html', '一筆畫 Zip 解 20 題', function (c) { return (rec(c, 'jfk-zip-v1').solved || 0) >= 20; }],
        ['watch', '⏱️', '碼錶', 'games/schulte.html', '數字方格 25 秒內點完', function (c) { var t = rec(c, 'jfk-schulte-v1').top; return Array.isArray(t) && t.some(function (x) { return x && x.t < 25; }); }],
        ['shoe', '👟', '跑鞋', 'games/runner.html', '果汁龍跑酷跑到 1000 m', function (c) { return (rec(c, 'jfk-runner-v1').best || 0) >= 1000; }],
        ['cart', '🛒', '購物車', 'games/store-manager.html', '超商店長拿到 S 評等', has('cart')],
        ['diploma', '📜', '畢業證書', 'games/lab-life.html', '碩一生模擬器看過 3 種結局', function (c) { var e = rec(c, 'jfk-lab-v1').endings; return !!e && Object.keys(e).length >= 3; }],
        ['star', '🌟', '金星星', 'research/quest.html', '研究闖關拿到 10 顆星', function (c) { var q = rec(c, 'jfk-quest-v1'), s = 0; if (q.pages) for (var k in q.pages) s += (q.pages[k] && q.pages[k].stars) || 0; return s >= 10; }],
        ['bento', '🍱', '便當', 'games/dinner-wheel.html', '晚餐轉盤按一次「就決定是你了！」', has('bento')],
        ['stamp', '📅', '簽到章', 'games/pet.html', '每日簽到 7 天', function (c) { return Array.isArray(c.pet.days) && c.pet.days.length >= 7; }]
    ];
    function giftName(id) { for (var i = 0; i < GIFTS.length; i++) if (GIFTS[i][0] === id) return GIFTS[i][1] + ' ' + GIFTS[i][2]; return ''; }

    window.JFK_GIFTS = GIFTS;
    window.JFK_REWARD_GAMES = GAMES;
    window.jfkGiftData = data;
    // 拿到了哪些禮物（代號陣列，照 GIFTS 的順序）
    window.jfkGiftsOwned = function (pet) {
        var ctx = { gifts: data().gifts, read: read, pet: pet || read('jfk-pet-v1') };
        return GIFTS.filter(function (g) { try { return g[5](ctx); } catch (e) { return false; } }).map(function (g) { return g[0]; });
    };
    window.jfkReward = function (game, juice, opt) {
        opt = opt || {};
        var d = data();
        if (opt.key) {
            if (d.keys.indexOf(opt.key) >= 0) return false;
            d.keys.push(opt.key);
            d.keys = d.keys.slice(-300);
        }
        juice = Math.max(0, Math.floor(juice) || 0);
        d.juice[game] = (d.juice[game] || 0) + juice;
        if (juice) d.plays[game] = (d.plays[game] || 0) + 1;
        var gift = opt.gift && !d.gifts[opt.gift] ? opt.gift : '';
        if (gift) { var t = new Date(); d.gifts[gift] = t.getFullYear() + '-' + (t.getMonth() + 1) + '-' + t.getDate(); }
        if (!juice && !gift) return false;
        try { localStorage.setItem(KEY, JSON.stringify(d)); } catch (e) { return false; }
        var note = (juice ? '🧃 +' + juice + ' 瓶' : '') + (gift ? (juice ? '・' : '') + '🎁 新禮物：' + giftName(gift) : '');
        if (window.jfkPetGain) window.jfkPetGain(note);
        return true;
    };
})();
