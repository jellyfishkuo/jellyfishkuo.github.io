/* 深色／淺色切換：放在 <head> 同步載入，畫面出來前就決定好主題，不會先閃一下另一種顏色。
   沒選過就跟著系統設定；選過之後記在 localStorage，每一頁共用。 */
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
        toggle: function () { this.set(this.get() === 'dark' ? 'light' : 'dark'); }
    };
})();
