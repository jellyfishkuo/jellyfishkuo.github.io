/* 研究闖關：研究 Demo 的「🎯 練習模式」每答一題就記到 localStorage（jfk-quest-v1），
   research/quest.html 讀出來畫關卡地圖。
   不動各頁練習模式的程式，只看畫面：.quiz 框加上 done 就是答了一題，同時有 miss 就是答錯
   （規格見 tools/research/BRIEF.md，每頁的題目框都是同一套 class）。
   同一次打開頁面答滿 CLEAR 題、答對一半以上就過關，星星看這一次的答對率；網址有 ?quiz=1 時自動打開練習模式、右下角顯示進度。 */
(function () {
    var KEY = 'jfk-quest-v1';
    var CLEAR = 5;
    var page = (location.pathname.split('/').pop() || '').replace(/\.html$/, '');
    var ses = { a: 0, r: 0 };
    var fromQuest = /[?&]quiz=1\b/.test(location.search);
    var pill = null;

    function load() {
        try { var s = JSON.parse(localStorage.getItem(KEY) || '{}'); return s && typeof s === 'object' ? s : {}; }
        catch (e) { return {}; }
    }
    function save(s) {
        try { localStorage.setItem(KEY, JSON.stringify(s)); } catch (e) { /* 被擋就不記，頁面照樣能練習 */ }
    }
    function starsOf(a, r) {
        if (a < CLEAR) return 0;
        var p = r / a;
        return p >= 0.9 ? 3 : p >= 0.7 ? 2 : p >= 0.5 ? 1 : 0;
    }
    function record(ok) {
        ses.a++;
        if (ok) ses.r++;
        var s = load();
        if (!s.pages || typeof s.pages !== 'object') s.pages = {};
        var p = s.pages[page] || { a: 0, r: 0, stars: 0 };
        p.a = (p.a || 0) + 1;
        if (ok) p.r = (p.r || 0) + 1;
        p.at = Date.now();
        p.stars = Math.max(p.stars || 0, starsOf(ses.a, ses.r));
        s.pages[page] = p;
        save(s);
        showPill();
    }

    function watch(box) {
        var was = box.classList.contains('done');
        new MutationObserver(function () {
            var now = box.classList.contains('done');
            if (now && !was) record(!box.classList.contains('miss'));
            was = now;
        }).observe(box, { attributes: true, attributeFilter: ['class'] });
    }

    // 從闖關地圖來的：右下角的小進度條（fixed，不推動頁面上的任何區塊）
    function showPill() {
        if (!fromQuest) return;
        if (!pill) {
            var css = document.createElement('style');
            css.textContent =
                '.jfk-quest{position:fixed;right:12px;bottom:12px;z-index:950;display:flex;align-items:center;gap:8px;max-width:calc(100% - 24px);' +
                'padding:7px 8px 7px 13px;border-radius:999px;font:700 13px/1.3 -apple-system,"PingFang TC","Noto Sans TC",sans-serif;' +
                'background:#151527;color:#e6e6f0;border:1px solid #7c3aed;box-shadow:0 6px 20px rgba(0,0,0,.45)}' +
                '.jfk-quest span{min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
                '.jfk-quest a{flex:none;color:#fff;text-decoration:none;padding:4px 10px;border-radius:999px;background:linear-gradient(135deg,#7c3aed,#06b6d4)}' +
                '[data-theme="light"] .jfk-quest{background:#fff;color:#1d2b12;border:2.5px solid #1d2b12;box-shadow:3px 3px 0 #1d2b12}' +
                '[data-theme="light"] .jfk-quest a{background:#ffb02e;color:#1d2b12;border:2px solid #1d2b12}';
            document.head.appendChild(css);
            pill = document.createElement('div');
            pill.className = 'jfk-quest';
            pill.setAttribute('aria-live', 'polite');
            pill.appendChild(document.createElement('span'));
            var a = document.createElement('a');
            a.href = 'quest.html#' + page;
            a.textContent = '地圖';
            pill.appendChild(a);
            document.body.appendChild(pill);
        }
        var st = starsOf(ses.a, ses.r);
        var text;
        if (!ses.a) text = '🎯 闖關：按「下一步」開始答題，答滿 ' + CLEAR + ' 題過關';
        else if (ses.a < CLEAR) text = '🎯 答對 ' + ses.r + '/' + ses.a + '，再答 ' + (CLEAR - ses.a) + ' 題過關';
        else if (!st) text = '💪 答對 ' + ses.r + '/' + ses.a + '，要一半以上才過關，繼續答';
        else text = '🏆 過關 ' + '★★★'.slice(0, st) + '☆☆☆'.slice(st) + '（答對 ' + ses.r + '/' + ses.a + '）';
        pill.firstChild.textContent = text;
    }

    function start() {
        var boxes = document.querySelectorAll('.quiz');
        for (var i = 0; i < boxes.length; i++) watch(boxes[i]);
        if (fromQuest && boxes.length) {
            var tg = document.querySelectorAll('.quiz-toggle');
            for (var k = 0; k < tg.length; k++) if (tg[k].getAttribute('aria-pressed') !== 'true') tg[k].click();
            showPill();
        }
    }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
    else start();
})();
