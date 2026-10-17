/* 深色／淺色切換：放在 <head> 同步載入，畫面出來前就決定好主題，不會先閃一下另一種顏色。
   沒選過就跟著系統設定；選過之後記在 localStorage，每一頁共用。
   頁面上沒有自己的切換鈕時，會自動放一個在「回首頁」連結的同一列。 */
(function () {
    var KEY = 'jfk-theme';
    var root = document.documentElement;
    function saved() {
        try { var t = localStorage.getItem(KEY); return t === 'light' || t === 'dark' ? t : null; }
        catch (e) { return null; }
    }
    var mq = window.matchMedia ? window.matchMedia('(prefers-color-scheme: light)') : null;
    function system() { return mq && mq.matches ? 'light' : 'dark'; }
    function apply(t) {
        root.dataset.theme = t;
        document.dispatchEvent(new CustomEvent('themechange', { detail: t }));
    }
    root.dataset.theme = saved() || system();
    if (mq && mq.addEventListener) mq.addEventListener('change', function () { if (!saved()) apply(system()); });
    window.jfkTheme = {
        get: function () { return root.dataset.theme; },
        set: function (t) {
            try { localStorage.setItem(KEY, t); } catch (e) { /* 被擋就只在這一頁有效 */ }
            apply(t);
        },
        toggle: function () { this.set(this.get() === 'dark' ? 'light' : 'dark'); },
        /* 做一顆切換鈕（太陽、月亮並排），樣式在 theme.css */
        makeSwitch: function () {
            var btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'theme-switch';
            btn.setAttribute('aria-label', '深色模式');
            btn.innerHTML =
                '<span class="thumb" aria-hidden="true"></span>' +
                '<span class="opt" data-set="light" title="淺色"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="4.2"/><path d="M12 2v2.2M12 19.8V22M4.9 4.9l1.6 1.6M17.5 17.5l1.6 1.6M2 12h2.2M19.8 12H22M4.9 19.1l1.6-1.6M17.5 6.5l1.6-1.6"/></svg></span>' +
                '<span class="opt" data-set="dark" title="深色"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round" aria-hidden="true"><path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"/></svg></span>';
            var sync = function () { btn.setAttribute('aria-pressed', root.dataset.theme === 'dark'); };
            // 點太陽就淺色、點月亮就深色；用鍵盤按（沒點在圖示上）就切到另一種
            btn.addEventListener('click', function (e) {
                var opt = e.target.closest && e.target.closest('.opt');
                if (opt) window.jfkTheme.set(opt.getAttribute('data-set')); else window.jfkTheme.toggle();
            });
            document.addEventListener('themechange', sync);
            sync();
            return btn;
        }
    };


    /* 頁面用 JS 畫出來的顏色（SVG 的 fill/stroke、style="..."）也接上淺色：
       換成 var(--lt-xxxx, 原本的顏色)，深色時變數沒定義就照舊。
       --lt-* 的值由 tools/theme/lightify.py 算好放在 theme.css，只有接上 theme.css 的頁面才做。 */
    var COLOR = /var\(--lt-[0-9a-f_-]+,\s*(?:#[0-9a-fA-F]+|rgba?\([^)]*\))\)|#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b|rgba?\(\s*\d[^)]*\)/g;
    function keyOf(c) {
        var r, g, b, a = 1, m;
        if (c[0] === '#') {
            var h = c.slice(1);
            if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
            r = parseInt(h.slice(0, 2), 16); g = parseInt(h.slice(2, 4), 16); b = parseInt(h.slice(4, 6), 16);
        } else {
            m = c.match(/[\d.]+/g);
            if (!m || m.length < 3) return null;
            r = +m[0]; g = +m[1]; b = +m[2]; if (m.length > 3) a = +m[3];
        }
        var k = [r, g, b].map(function (v) { return ('0' + Math.round(v).toString(16)).slice(-2); }).join('');
        if (a < 1) k += '-' + Math.round(a * 100);
        return '--lt-' + k;
    }
    function wrap(text) {
        return text.replace(COLOR, function (c) {
            if (c.indexOf('var(') === 0) return c;
            var k = keyOf(c);
            return k ? 'var(' + k + ', ' + c + ')' : c;
        });
    }
    var ATTRS = ['fill', 'stroke', 'stop-color'];
    function paint(el) {
        for (var i = 0; i < ATTRS.length; i++) {
            var v = el.getAttribute(ATTRS[i]);
            if (v && v.charAt(0) === '#' || v && v.indexOf('rgb') === 0) {
                if (el.style.getPropertyValue(ATTRS[i]) === '') el.style.setProperty(ATTRS[i], wrap(v));
            }
        }
        var st = el.getAttribute('style');
        if (st) { var w = wrap(st); if (w !== st) el.setAttribute('style', w); }
    }
    var SEL = '[style],[fill],[stroke],[stop-color]';
    function paintTree(node) {
        if (node.nodeType !== 1) return;
        if (node.matches(SEL)) paint(node);
        var list = node.querySelectorAll(SEL);
        for (var i = 0; i < list.length; i++) paint(list[i]);
    }
    function startPaint() {
        if (!document.querySelector('link[href$="assets/theme.css"]') || !window.MutationObserver) return;
        paintTree(document.body);
        new MutationObserver(function (muts) {
            for (var i = 0; i < muts.length; i++) {
                var mu = muts[i];
                if (mu.type === 'attributes') {
                    if (mu.attributeName !== 'style') mu.target.style.removeProperty(mu.attributeName);
                    paint(mu.target);
                } else for (var j = 0; j < mu.addedNodes.length; j++) paintTree(mu.addedNodes[j]);
            }
        }).observe(document.body, { subtree: true, childList: true, attributes: true, attributeFilter: ['style', 'fill', 'stroke', 'stop-color'] });
    }

    /* 有「回首頁」連結的頁面：連結換成兩種主題各自的樣子，旁邊放切換鈕 */
    function mount() {
        if (document.querySelector('.theme-switch')) return;
        var back = document.querySelector('a.back, a.back-link');
        if (!back) return;
        var prefix = (back.getAttribute('href') || '').replace(/index\.html.*$/, '');
        var dark = document.createElement('span');
        dark.className = 'only-dark';
        while (back.firstChild) dark.appendChild(back.firstChild);
        var img = document.createElement('img');
        img.className = 'jfk-dragon only-light';
        img.src = prefix + 'assets/dragon.svg';
        img.alt = '';
        var light = document.createElement('span');
        light.className = 'only-light';
        light.textContent = '回果汁龍首頁';
        back.appendChild(dark); back.appendChild(img); back.appendChild(light);
        var bar = document.createElement('div');
        bar.className = 'jfk-topbar';
        back.parentNode.insertBefore(bar, back);
        bar.appendChild(back);
        bar.appendChild(window.jfkTheme.makeSwitch());
    }
    function ready() { mount(); startPaint(); }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', ready);
    else ready();
})();
