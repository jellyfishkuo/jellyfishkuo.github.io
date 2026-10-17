"""產生遊戲技術剖析頁（共用外框 + 各頁內容）。

用法：python3 build_detail.py <name> ...
內容放在 content/<name>.py，裡面定義 PAGE = dict(...)。
"""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../..'))  # repo 根目錄
import html
import importlib.util
import sys
from pathlib import Path

ROOT = Path(REPO + '/games')
HERE = Path(__file__).parent

GAMES = [
    ('pentomino', 'pentomino', 'Pentomino 拼圖'),
    ('1A2B', '1a2b', '1A2B 猜數字'),
    ('game-set', 'set', 'SET 牌局'),
    ('infinite-tictactoe', 'infinite-tictactoe', '無限井字棋'),
    ('vertical-gomoku', 'vertical-gomoku', '立式五子棋'),
    ('coc-card', 'coc-card', '卡牌交易站'),
    ('electricity', 'electricity', '電費紀錄'),
]


def case(no, title, symptom, cause, fix, check=None, lesson=None):
    """一個問題案例：症狀 → 原因 → 修法 → 驗證（→ 心得）。參數皆為 HTML。"""
    rows = [('symptom', '症狀', symptom), ('cause', '原因', cause), ('fix', '修法', fix)]
    if check:
        rows.append(('check', '驗證', check))
    if lesson:
        rows.append(('lesson', '心得', lesson))
    body = ''.join(
        f'<div class="case-row"><div class="case-label {cls}">{label}</div><div>{content}</div></div>'
        for cls, label, content in rows)
    return (f'<div class="case"><div class="case-head"><span class="case-no">{no}</span>'
            f'<h3>{title}</h3></div><div class="case-body">{body}</div></div>')


def callout(kind, title, body):
    return f'<div class="callout {kind}"><span class="callout-title">{title}</span>{body}</div>'


def table(headers, rows):
    head = ''.join(f'<th>{h}</th>' for h in headers)
    body = ''.join('<tr>' + ''.join(f'<td>{c}</td>' for c in r) + '</tr>' for r in rows)
    return f'<div class="table-wrap"><table class="kv"><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table></div>'


def build(name):
    spec = importlib.util.spec_from_file_location(name, HERE / 'content' / f'{name}.py')
    mod = importlib.util.module_from_spec(spec)
    mod.case, mod.callout, mod.table = case, callout, table
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    P = mod.PAGE
    icon = next(i for n, i, _ in GAMES if n == name)

    chips = ''.join(f'<span class="meta-chip">{c}</span>' for c in P['chips'])
    tab_buttons = ''.join(
        f'<button class="tab-btn{" active" if i == 0 else ""}" aria-controls="{t[0]}">{t[1]}</button>'
        for i, t in enumerate(P['tabs']))

    panels = []
    for i, (tid, label, sections) in enumerate(P['tabs']):
        toc = ''.join(f'<li><a href="#{sid}">{html.escape(h)}</a></li>' for sid, h, _ in sections)
        secs = ''.join(
            f'<section class="section-block" id="{sid}"><h2>{h}</h2>{body}</section>'
            for sid, h, body in sections)
        panels.append(
            f'<div class="tab-content{" active" if i == 0 else ""}" id="{tid}" role="tabpanel">'
            f'<div class="toc"><div class="toc-title">本頁重點</div><ol>{toc}</ol></div>{secs}</div>')

    facts = ''.join(f'<li><span>{k}</span><span>{v}</span></li>' for k, v in P['facts'])
    others = ''.join(
        f'<li><a href="{n}-detail.html" class="other-link"><img src="../assets/icons/{ic}.svg" alt="" width="20" height="20">{t}</a></li>'
        for n, ic, t in GAMES if n != name)

    mathjax = ('''
    <script>
        MathJax = { tex: { inlineMath: [['$', '$'], ['\\\\(', '\\\\)']], displayMath: [['$$', '$$'], ['\\\\[', '\\\\]']] } };
    </script>
    <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>''' if P.get('mathjax') else '')

    page = f'''<!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/svg+xml" href="../assets/icons/{icon}.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../assets/icons/{icon}-32.png">
    <link rel="apple-touch-icon" href="../assets/icons/{icon}-180.png">
    <title>{P['title']}</title>
    <meta name="description" content="{html.escape(P['description'])}">{mathjax}
    <script src="../assets/theme.js"></script>
    <link rel="stylesheet" href="detail.css">
    <link rel="stylesheet" href="../assets/theme.css">
</head>

<body>
    <div class="bg-glow"></div>
    <div class="bg-glow-2"></div>

    <header>
        <a href="../index.html" class="back-link"><span>←</span> RETURN TO PORTFOLIO</a>
        <h1>{P['h1']}</h1>
        <div class="subtitle">{P['subtitle']}</div>
        <div class="meta-row">{chips}</div>
    </header>

    <div class="tab-wrapper">
        <div class="tabs-container" role="tablist">{tab_buttons}</div>
    </div>

    <main>
        <div class="content">
{"".join(panels)}
        </div>

        <aside class="sidebar">
            <div class="play-card">
                <img src="../assets/icons/{icon}.svg" alt="" width="72" height="72" style="border-radius:18px; margin-bottom:1rem; box-shadow:0 0 30px var(--accent-glow);">
                <h3 style="color: var(--text); font-size: 1.6rem; margin-bottom: 0.5rem; margin-top: 0;">Experience It</h3>
                <p style="font-size: 0.95rem; margin-top: 1rem; color: var(--muted); line-height: 1.6;">{P['play']}</p>
                <a href="{P.get('play_href', name + '.html')}" class="btn">{P.get('play_label', 'Launch Interactive Demo')}</a>
            </div>

            <div class="side-box">
                <h4>Quick Facts</h4>
                <ul class="spec-list">{facts}</ul>
            </div>

            <div class="side-box">
                <h4>其他技術剖析</h4>
                <ul class="spec-list other-list">{others}</ul>
            </div>
        </aside>
    </main>

    <footer
        style="padding: 4rem 10vw; color: var(--muted); font-size: 0.85rem; font-family: 'Space Mono'; border-top: 1px solid var(--border); text-align: center;">
        © 2026 果汁龍 · Engineered with Passion.
    </footer>

    <script src="detail.js"></script>
</body>

</html>
'''
    (ROOT / f'{name}-detail.html').write_text(page)
    print('built', name, len(page))


if __name__ == '__main__':
    for n in sys.argv[1:]:
        build(n)
