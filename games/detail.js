/* 技術剖析頁共用：分頁切換
 *
 * 舊版每頁各自有一份 switchTab()，切換時一律 scrollTo({ top: 0 })，
 * 讀到一半換分頁就整頁跳回頂端；目錄裡指向「其他分頁」段落的連結也點不動
 * （目標元素在 display:none 的分頁裡）。這裡統一處理：
 *   1. 切換分頁時，只在分頁列已經捲出畫面時才把它帶回視窗頂端，否則不動。
 *   2. 點目錄或任何 #錨點：自動切到該段落所在的分頁，再捲到段落。
 *   3. 網址帶 #段落 直接開啟對應分頁，方便分享某一段。
 */
(function () {
    'use strict';

    const buttons = Array.from(document.querySelectorAll('.tab-btn'));
    const panels = Array.from(document.querySelectorAll('.tab-content'));
    const tabBar = document.querySelector('.tab-wrapper');
    if (!buttons.length || buttons.length !== panels.length) return;

    function activate(index) {
        buttons.forEach((btn, i) => {
            const on = i === index;
            btn.classList.toggle('active', on);
            btn.setAttribute('aria-selected', on ? 'true' : 'false');
            btn.tabIndex = on ? 0 : -1;
        });
        panels.forEach((panel, i) => panel.classList.toggle('active', i === index));
    }

    function bringTabBarIntoView() {
        if (!tabBar) return;
        const top = tabBar.getBoundingClientRect().top;
        // 分頁列還看得到就不捲；捲過頭了才回到分頁列的位置（不是頁首）
        if (top < 0) window.scrollTo({ top: window.scrollY + top - 8, behavior: 'smooth' });
    }

    function goToHash(hash, smooth) {
        if (!hash || hash.length < 2) return false;
        let target;
        try { target = document.querySelector(hash); } catch (_) { return false; }
        if (!target) return false;
        const panel = target.closest('.tab-content');
        const index = panels.indexOf(panel);
        if (index >= 0 && !panel.classList.contains('active')) activate(index);
        target.scrollIntoView({ behavior: smooth ? 'smooth' : 'auto', block: 'start' });
        return true;
    }

    buttons.forEach((btn, i) => {
        btn.setAttribute('role', 'tab');
        btn.removeAttribute('onclick');
        btn.addEventListener('click', () => {
            activate(i);
            bringTabBarIntoView();
            if (panels[i].id) history.replaceState(null, '', '#' + panels[i].id);
        });
        btn.addEventListener('keydown', e => {
            if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
            e.preventDefault();
            const next = (i + (e.key === 'ArrowRight' ? 1 : -1) + buttons.length) % buttons.length;
            buttons[next].click();
            buttons[next].focus();
        });
    });

    document.addEventListener('click', e => {
        const link = e.target.closest('a[href^="#"]');
        if (!link) return;
        if (goToHash(link.getAttribute('href'), true)) {
            e.preventDefault();
            history.replaceState(null, '', link.getAttribute('href'));
        }
    });

    // 舊版頁面裡寫死的 onclick="switchTab(n)" 仍可運作
    window.switchTab = index => { activate(index); bringTabBarIntoView(); };

    const initial = panels.findIndex(p => p.classList.contains('active'));
    activate(initial >= 0 ? initial : 0);
    if (location.hash) requestAnimationFrame(() => goToHash(location.hash, false));
    // 同一頁裡只改 # 後面（貼上分享的段落連結、瀏覽器上一頁）也要切到對應分頁
    window.addEventListener('hashchange', () => goToHash(location.hash, false));
})();
