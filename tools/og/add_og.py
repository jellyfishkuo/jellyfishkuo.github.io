"""幫頁面加上分享預覽用的 Open Graph／Twitter 標籤。

用法（在 repo 根目錄）：
    python3 tools/og/add_og.py games/zip.html research/apriori.html ...
    python3 tools/og/add_og.py --all        # 所有手寫頁＋研究 Demo 樣板，之後要重新產生研究 Demo

標題、說明直接拿頁面的 <title> 和 <meta name="description">，所以頁面一定要先有 description。
網址：一般 .html 用自己的路徑；研究 Demo 樣板 tools/research/<x>/<x>.html.tpl → research/<x>.html。
可以重複執行：先拿掉舊的 og:/twitter: 標籤再加新的。
技術介紹頁（games/*-detail.html）的標籤寫在 tools/detail/build_detail.py，不用這支。
"""
import html
import pathlib
import re
import sys

SITE = 'https://jellyfishkuo.github.io/'
IMAGE = SITE + 'assets/og.png'   # 首頁用的；其他頁各自有 assets/og/<slug>.jpg（build_page_og.py 產生）
ROOT = pathlib.Path(__file__).resolve().parents[2]

# 不加的頁面：404（不會被分享）、股票（自己用、noindex）、首頁（標籤手寫）、技術介紹頁（產生器負責）
SKIP = {'404.html', 'index.html', 'stock/index.html'}


def page_url(path: pathlib.Path) -> str:
    rel = path.resolve().relative_to(ROOT).as_posix()
    m = re.fullmatch(r'tools/research/([^/]+)/[^/]+\.html\.tpl', rel)   # 用資料夾名（fp-growth/fpgrowth.html.tpl → fp-growth.html）
    if m:
        rel = f'research/{m.group(1)}.html'
    if rel.endswith('/index.html'):
        rel = rel[: -len('index.html')]
    return SITE + rel


def image_slug(url: str) -> str:
    """頁面網址 → 分享圖檔名：games/zip.html → games-zip、electricity-tracker/ → electricity-tracker"""
    rel = url[len(SITE):]
    rel = re.sub(r'(/index)?\.html$', '', rel).strip('/')
    return rel.replace('/', '-') or 'index'


def image_url(url: str) -> str:
    return SITE + 'assets/og/' + image_slug(url) + '.jpg'


def tags(title: str, desc: str, url: str, indent: str) -> str:
    a = lambda s: html.escape(s, quote=True)
    rows = [
        '<meta property="og:type" content="website">',
        '<meta property="og:site_name" content="果汁龍的網站">',
        '<meta property="og:locale" content="zh_TW">',
        f'<meta property="og:title" content="{a(title)}">',
        f'<meta property="og:description" content="{a(desc)}">',
        f'<meta property="og:url" content="{a(url)}">',
        f'<meta property="og:image" content="{image_url(url)}">',
        '<meta property="og:image:width" content="1200">',
        '<meta property="og:image:height" content="630">',
        '<meta name="twitter:card" content="summary_large_image">',
    ]
    return ''.join('\n' + indent + r for r in rows)


def apply(path: pathlib.Path) -> bool:
    src = path.read_text(encoding='utf-8')
    out = re.sub(r'\n[ \t]*<meta (?:property="og:|name="twitter:)[^>]*>', '', src)
    t = re.search(r'<title>(.*?)</title>', out, re.S)
    d = re.search(r'^([ \t]*)<meta name="description" content="([^"]*)">', out, re.M)
    if not t or not d:
        print(f'略過 {path}：沒有 <title> 或 description', file=sys.stderr)
        return False
    title = html.unescape(t.group(1).strip())
    desc = html.unescape(d.group(2))
    out = out[: d.end()] + tags(title, desc, page_url(path), d.group(1)) + out[d.end():]
    if out != src:
        path.write_text(out, encoding='utf-8')
        print('更新', path.resolve().relative_to(ROOT))
    return True


def all_targets():
    for p in sorted(ROOT.glob('**/*.html')):
        rel = p.relative_to(ROOT).as_posix()
        if rel.startswith(('tools/', 'research/', '.git/')) or rel in SKIP or rel.endswith('-detail.html'):
            continue
        yield p
    yield from sorted(ROOT.glob('tools/research/*/*.html.tpl'))
    # research/ 底下手寫、沒有樣板的頁面
    for name in ('papers', 'quest'):
        yield ROOT / 'research' / f'{name}.html'


if __name__ == '__main__':
    args = sys.argv[1:]
    files = list(all_targets()) if args == ['--all'] else [pathlib.Path(a) for a in args]
    ok = all([apply(f) for f in files])
    sys.exit(0 if ok else 1)
