/* 果汁龍跑到遊戲頁：右下角一隻小果汁龍，只讀 localStorage jfk-pet-v1，不改任何資料。
 * - 點牠會講跟這一頁有關的話（PAGE），肚子餓、還是蛋的時候會講別的
 * - 遊戲過關、破紀錄時呼叫 jfkPetCheer('文字')，牠會跳一下說出來（沒載入這支也不會出錯：呼叫前先檢查 window.jfkPetCheer）
 * - 「收起來」之後同一個分頁不再出現（sessionStorage jfk-pet-mini-off）
 * - 頁面最下面補一點空白，捲到底時牠不會擋住最後的按鈕；底下有按鈕時自動閃到另一邊，兩邊都擋就縮到邊緣（點不到、也不擋）
 * 用法：<script src="../assets/pet-mini.js" defer></script>（路徑依頁面調整；會自己載入 dragon-hold.js）
 * 配件的位置、大小跟首頁那隻（index.html .hpet-me）一樣，改的時候三邊（pet.html、首頁、這裡）一起改。 */
(function () {
    if (window.jfkPetCheer) return;
    var script = document.currentScript;
    var root = new URL('../', script && script.src ? script.src : location.href);   // 這支在 assets/ 底下，上一層就是網站根目錄
    var off = false;
    try { off = sessionStorage.getItem('jfk-pet-mini-off') === '1'; } catch (e) { /* 預設顯示 */ }
    var api = null, queued = null;
    window.jfkPetCheer = function (text) { if (off) return; if (api) api.cheer(text); else queued = text; };
    if (off) return;

    function read(k) { try { var v = JSON.parse(localStorage.getItem(k) || '{}'); return v && typeof v === 'object' ? v : {}; } catch (e) { return {}; } }
    function pick(a) { return a[Math.floor(Math.random() * a.length)]; }

    // 這一頁是哪個遊戲
    var path = location.pathname;
    var key = /\/chess\//.test(path) ? 'chess' : /electricity-tracker/.test(path) ? 'electricity' : path.split('/').pop().replace(/\.html$/, '');
    var PAGE = {
        zip: ['最後要停在最大的數字上喔', '走錯了就往回拖，線會收回來', '卡住可以按提示，我不會說出去'],
        runner: ['跳！跳！前面有 bug！', '按住螢幕可以跳比較高', '撿到 🍎 可以無敵 4 秒'],
        schulte: ['眼睛盯著中間那格，用餘光找下一個數字', '點錯不扣時間，但會記下來喔', '我從 1 數到 25 都要好久……'],
        pentomino: ['今天的日期拼得出來嗎？', '拼不出來可以偷看求解器'],
        'game-set': ['三張牌的每個特徵，都要全部一樣或全部不同', '找朋友連線一起搶 SET 吧'],
        hanoi: ['大的盤子不能壓在小的上面喔', '卡住了可以看遞迴一步一步怎麼解'],
        'store-manager': ['大家都會買的東西，不一定值得做優惠', '看提升度！比 1 大才是真的會一起買'],
        'lab-life': ['記得休息，體力見底會病倒一週', '心情太低的話，實驗進度會打折喔'],
        '1A2B': ['A 是數字和位置都對，B 是數字對、位置不對', '4 個數字都不會重複喔'],
        'infinite-tictactoe': ['下第 4 顆的時候，最舊的那顆會消失', '這個遊戲先手必勝，但電腦也很強'],
        'vertical-gomoku': ['棋子會往下掉，先看清楚會落在哪', '小心！對手快要連成四顆了'],
        'dinner-wheel': ['我投蘋果汁一票', '轉到不想吃的，可以排除再轉一次'],
        'coc-card': ['有多出來的卡，可以拿去跟別的帳號換'],
        chess: ['加油！我幫你看著棋盤', '下完可以丟進分析，看看哪一步走壞了'],
        electricity: ['今天抄電表了嗎？', '電表從 9999 跳回 0000 也算得出來喔']
    };
    var LINES = {
        egg: ['（蛋晃了一下）', '（裡面好像有東西在動）', '玩遊戲拿蘋果汁，就可以把我孵出來喔'],
        flat: ['餓扁扁了……', '（扁扁地躺著）蘋果汁……'],
        hungry: ['肚子好餓……', '咕嚕咕嚕……'],
        self: ['加油加油！', '我在旁邊看你玩', '玩累了記得休息一下', '好好玩喔，我也想玩']
    };

    var pet = read('jfk-pet-v1');
    var xp0 = typeof pet.xp === 'number' ? pet.xp : 0;
    var xp = xp0 >= 3 ? xp0 : 0;                    // 喝滿 3 瓶才孵出來
    var full = !xp ? 10 : Math.max(0, Math.min(10, (pet.full || 0) - Math.floor((Date.now() - (pet.fedAt || 0)) / (10 * 60e3))));
    var nm = typeof pet.name === 'string' && pet.name.trim() ? pet.name.trim().slice(0, 12) : '果汁龍';

    var css = '' +
        '.jfk-mini{position:fixed;right:max(10px,env(safe-area-inset-right));bottom:max(8px,env(safe-area-inset-bottom));z-index:60;pointer-events:none;transition:transform .35s}' +
        '.jfk-mini.left{right:auto;left:max(10px,env(safe-area-inset-left))}' +
        '.jfk-mini.left .jfk-mini-say{right:auto;left:0}' +
        '.jfk-mini.tuck{transform:translateY(78%)}' +
        '.jfk-mini.tuck>*{pointer-events:none}' +
        '.jfk-mini.tuck .jfk-mini-me{opacity:.55}' +
        '.jfk-mini.tuck.cheer{transform:none}' +
        '.jfk-mini.tuck.cheer .jfk-mini-me{opacity:1}' +
        '.jfk-mini>*{pointer-events:auto}' +
        '.jfk-mini-me{position:relative;display:block;width:var(--w,46px);aspect-ratio:56/46;padding:0;border:0;background:none;cursor:pointer;' +
        'filter:drop-shadow(0 3px 8px rgba(0,0,0,.4));-webkit-tap-highlight-color:transparent;container-type:inline-size}' +
        '.jfk-mini-me.egg{aspect-ratio:60/74}' +
        '.jfk-mini-me img,.jfk-mini-me svg{width:100%;height:100%;display:block}' +
        '.jfk-mini-me .body{position:absolute;inset:0;transform-origin:50% 100%}' +
        '.jfk-mini-me.flat .body{transform:scale(1.18,.62)}' +
        '.jfk-mini-me .acc{position:absolute;line-height:1;transform:translate(-50%,-50%);pointer-events:none}' +
        '.jfk-mini-me .acc.hat{left:37%;top:2%;font-size:29cqw}' +
        '.jfk-mini-me .acc.face{left:25.9%;top:21.3%;font-size:21cqw;transform:translate(-74%,-52%)}' +
        '.jfk-mini-me .acc.neck{left:46%;top:54%;font-size:22.6cqw}' +
        '.jfk-mini-me .acc.side{left:57%;top:10%;font-size:19.4cqw}' +
        '.jfk-mini-me.bump{animation:jfkMiniBump .45s}' +
        '@keyframes jfkMiniBump{30%{transform:translateY(-10px) scale(1.06,.95)}60%{transform:translateY(0) scale(.96,1.04)}}' +
        '@media (prefers-reduced-motion:reduce){.jfk-mini-me.bump{animation:none}}' +
        '.jfk-mini-say{position:absolute;right:0;bottom:calc(100% + 6px);width:max-content;max-width:min(240px,calc(100vw - 24px));' +
        'padding:8px 11px;border-radius:13px;background:#0f0f1a;border:1px solid rgba(124,58,237,.4);color:#e6e6f0;' +
        'font:500 .84rem/1.5 -apple-system,"PingFang TC","Noto Sans TC",sans-serif;box-shadow:0 8px 22px rgba(0,0,0,.45);' +
        'visibility:hidden;opacity:0;transform:translateY(6px);transition:opacity .2s,transform .2s,visibility .2s}' +
        '.jfk-mini-say.show{visibility:visible;opacity:1;transform:none}' +
        '.jfk-mini-say b{display:block;font-size:.72rem;color:#06b6d4}' +
        '.jfk-mini-say .row{display:flex;align-items:center;justify-content:space-between;gap:10px;margin-top:4px}' +
        '.jfk-mini-say a{color:#06b6d4;font-size:.78rem;text-decoration:none;white-space:nowrap}' +
        '.jfk-mini-say button{border:0;background:none;color:#8a8aa3;font:inherit;font-size:.74rem;cursor:pointer;padding:2px 0;white-space:nowrap}' +
        '[data-theme="light"] .jfk-mini-me{filter:drop-shadow(2px 2px 0 #1d2b12)}' +
        '[data-theme="light"] .jfk-mini-say{background:#fff;color:#1d2b12;border:2.5px solid #1d2b12;box-shadow:3px 3px 0 #1d2b12}' +
        '[data-theme="light"] .jfk-mini-say b,[data-theme="light"] .jfk-mini-say a{color:#3f8f12;font-weight:700}' +
        '[data-theme="light"] .jfk-mini-say button{color:#4f5d44}';

    function build() {
        var st = document.createElement('style');
        st.textContent = css;
        document.head.appendChild(st);

        var box = document.createElement('div');
        box.className = 'jfk-mini';
        var say = document.createElement('div');
        say.className = 'jfk-mini-say';
        say.setAttribute('role', 'status');
        say.setAttribute('aria-live', 'polite');
        var who = document.createElement('b');
        who.textContent = xp ? nm : '一顆蛋';
        var line = document.createElement('span');
        var row = document.createElement('div');
        row.className = 'row';
        var hide = document.createElement('button');
        hide.type = 'button';
        hide.textContent = '收起來';
        var go = document.createElement('a');
        go.href = new URL('games/pet.html', root).href;
        go.textContent = xp ? '去看牠 →' : '去孵蛋 →';
        row.append(hide, go);
        say.append(who, line, row);

        var me = document.createElement('button');
        me.type = 'button';
        me.className = 'jfk-mini-me';
        me.setAttribute('aria-label', xp ? nm + '（點一下牠會講話）' : '一顆蛋');
        if (!xp) {
            me.classList.add('egg');
            me.style.setProperty('--w', '26px');
            me.innerHTML = '<svg viewBox="0 0 60 74" aria-hidden="true"><ellipse cx="30" cy="40" rx="26" ry="32" fill="#fff8e6" stroke="#1d2b12" stroke-width="2.5"/>' +
                '<circle cx="20" cy="30" r="5" fill="#9bd72f"/><circle cx="38" cy="22" r="3.5" fill="#9bd72f"/><circle cx="40" cy="48" r="6" fill="#9bd72f"/><circle cx="22" cy="54" r="3" fill="#9bd72f"/></svg>';
        } else {
            var body = document.createElement('span');
            body.className = 'body';
            var img = document.createElement('img');
            img.alt = '';
            img.src = window.jfkDragonURL ? window.jfkDragonURL(window.jfkPetHold ? window.jfkPetHold() : '') : new URL('assets/dragon.svg', root).href;
            body.appendChild(img);
            ['hat', 'face', 'neck', 'side'].forEach(function (slot) {
                if (typeof pet[slot] !== 'string' || !pet[slot]) return;
                var a = document.createElement('span');
                a.className = 'acc ' + slot;
                a.textContent = pet[slot];
                body.appendChild(a);
            });
            me.appendChild(body);
            if (!full) me.classList.add('flat');
        }
        box.append(say, me);
        document.body.appendChild(box);

        // 頁面最下面補一點空白，捲到底時最後的按鈕不會被牠擋住
        var pb = parseFloat(getComputedStyle(document.body).paddingBottom) || 0;
        if (pb < 72) document.body.style.paddingBottom = '72px';

        var hideT = 0, last = '', shownAt = 0;
        function show(text) {
            shownAt = Date.now();
            line.textContent = text;
            me.classList.remove('bump'); void me.offsetWidth; me.classList.add('bump');
            say.classList.add('show');
            clearTimeout(hideT);
            hideT = setTimeout(function () { say.classList.remove('show'); box.classList.remove('cheer'); }, text.length > 18 ? 6500 : 4500);
        }
        function nextLine() {
            if (!xp) return pick(LINES.egg);
            if (!full && Math.random() < 0.5) return pick(LINES.flat);
            if (full <= 2 && Math.random() < 0.4) return pick(LINES.hungry);
            var pool = (PAGE[key] || []).concat(PAGE[key] && Math.random() < 0.7 ? [] : LINES.self);
            if (!pool.length) pool = LINES.self;
            var t, n = 0;
            do { t = pick(pool); } while (t === last && pool.length > 1 && ++n < 6);
            return (last = t);
        }
        me.addEventListener('click', function (e) { e.stopPropagation(); show(nextLine()); });
        say.addEventListener('click', function (e) { e.stopPropagation(); });
        // 點別的地方就收起對話框；剛跳出來的那一下不算（過關那一下點擊會一路傳上來，不然一出現就被關掉）
        document.addEventListener('click', function () { if (Date.now() - shownAt > 400) { say.classList.remove('show'); box.classList.remove('cheer'); } });
        hide.addEventListener('click', function () {
            box.remove();
            document.body.style.paddingBottom = '';
            off = true;
            try { sessionStorage.setItem('jfk-pet-mini-off', '1'); } catch (e) { /* 不記也沒關係 */ }
        });
        // ── 閃開按鈕：看牠站的位置底下有沒有能點的東西，有就換邊，兩邊都有就縮到邊緣 ──
        var CLICKABLE = 'a,button,input,select,textarea,label,summary,canvas,[role="button"],[role="gridcell"],[onclick],[tabindex]:not([tabindex="-1"])';
        function blocked(left) {
            var r = me.getBoundingClientRect(), w = r.width, h = r.height, vw = document.documentElement.clientWidth, vh = window.innerHeight;
            var x0 = left ? 10 : vw - 10 - w, y0 = vh - 8 - h;
            for (var i = 0; i < 5; i++) for (var j = 0; j < 5; j++) {          // 身上 5×5 個點都看一次
                var els = document.elementsFromPoint(x0 + w * (0.04 + 0.23 * i), y0 + h * (0.04 + 0.23 * j));
                for (var k = 0; k < els.length; k++) {
                    if (box.contains(els[k])) continue;
                    if (els[k].closest(CLICKABLE)) return true;
                    break;                                  // 最上面那個不是能點的東西，就不算擋到
                }
            }
            return false;
        }
        var dodgeQ = 0;
        function dodge() {
            dodgeQ = 0;
            if (!box.isConnected) return;
            var wasLeft = box.classList.contains('left');
            var mine = blocked(wasLeft);
            if (!mine) { box.classList.remove('tuck'); return; }
            if (!blocked(!wasLeft)) { box.classList.toggle('left', !wasLeft); box.classList.remove('tuck'); return; }
            box.classList.add('tuck');
            if (!box.classList.contains('cheer')) say.classList.remove('show');
        }
        function queueDodge() { if (!dodgeQ) dodgeQ = requestAnimationFrame(dodge); }
        window.addEventListener('scroll', queueDodge, { passive: true });
        window.addEventListener('resize', queueDodge);
        setInterval(queueDodge, 900);                   // 遊戲畫面會自己變（跳出視窗、換題），定時再看一次
        queueDodge();
        // 過關時：縮在邊緣也探出頭來講（這幾秒牠跟對話框都不攔點擊，後面的按鈕照樣按得到）
        api = { cheer: function (text) { if (off || !box.isConnected) return; if (box.classList.contains('tuck')) box.classList.add('cheer'); show(xp ? text : '（蛋開心地晃來晃去）' + text); } };
        if (queued) { api.cheer(queued); queued = null; }
    }

    function start() {
        if (window.jfkDragonURL) return build();
        var s = document.createElement('script');
        s.src = new URL('assets/dragon-hold.js', root).href;
        s.onload = s.onerror = build;
        document.head.appendChild(s);
    }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
    else start();
})();
