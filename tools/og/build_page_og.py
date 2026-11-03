"""產生每一頁自己的分享圖 assets/og/<slug>.jpg，並把頁面的 og:image 指過去。

用法（在 repo 根目錄，先開 python3 -m http.server 8770）：
    python3 tools/og/build_page_og.py              # 所有有 og:image 的頁面
    python3 tools/og/build_page_og.py games/zip.html research/apriori.html

內容直接拿頁面的 og:title、og:description 和 <link rel="icon" type="image/svg+xml">（作品／Demo 的圖示），
版面在 tools/og/page.html。底色看類別：小遊戲橘、研究綠、小工具藍、技術剖析紫（KIND 決定）。
首頁維持 assets/og.png（tools/og/og.html）；股票頁不放。
og:image 的網址規則在 add_og.py 的 image_url()；研究 Demo 樣板、技術介紹頁產生器也用同一個規則，重新產生時不會跑掉。
"""
import html
import json
import pathlib
import re
import sys
import urllib.request

from playwright.sync_api import sync_playwright

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from add_og import ROOT, SITE, image_slug, image_url  # noqa: E402

BASE = 'http://localhost:8770/'
TOOLS = {'electricity-tracker', 'games-coc-card', 'games-dinner-wheel'}
SKIP = {'index.html', 'stock/index.html', '404.html'}


def kind(slug: str) -> str:
    if slug.endswith('-detail'):
        return '技術剖析'
    if slug.startswith('research-'):
        return '研究' if slug in ('research-papers', 'research-quest', 'research-overview', 'research-benchmark') else '研究 Demo'
    return '小工具' if slug in TOOLS else '小遊戲'


def meta(src: str, prop: str) -> str:
    m = re.search(r'<meta property="%s" content="([^"]*)">' % re.escape(prop), src)
    return html.unescape(m.group(1)) if m else ''


def pages(args):
    if args:
        return [ROOT / a for a in args]
    out = []
    for p in sorted(ROOT.glob('**/*.html')):
        rel = p.relative_to(ROOT).as_posix()
        if rel.startswith(('tools/', '.git/')) or rel in SKIP:
            continue
        if 'og:image' in p.read_text(encoding='utf-8'):
            out.append(p)
    return out


# 字型從 Google Fonts 來：瀏覽器的請求改由 Python 代抓（走系統的 proxy 與憑證），不用關掉 TLS 檢查
def font_route(route):
    req = urllib.request.Request(route.request.url, headers={'User-Agent': route.request.headers.get('user-agent', 'Mozilla/5.0')})
    with urllib.request.urlopen(req, timeout=30) as r:
        route.fulfill(status=r.status, headers={'content-type': r.headers.get('content-type', ''), 'access-control-allow-origin': '*'}, body=r.read())


def point_tag(path: pathlib.Path, url: str):
    """把這一頁的 og:image 換成自己的圖（研究 Demo 也改樣板）。"""
    targets = [path]
    rel = path.relative_to(ROOT).as_posix()
    m = re.fullmatch(r'research/([^/]+)\.html', rel)
    if m:
        targets += sorted((ROOT / 'tools/research' / m.group(1)).glob('*.html.tpl'))   # 檔名不一定跟頁面一樣（fp-growth/fpgrowth.html.tpl）
    for t in targets:
        s = t.read_text(encoding='utf-8')
        out = re.sub(r'(<meta property="og:image" content=")[^"]*(">)', lambda mm: mm.group(1) + url + mm.group(2), s)
        if out != s:
            t.write_text(out, encoding='utf-8')


def main(args):
    outdir = ROOT / 'assets/og'
    outdir.mkdir(exist_ok=True)
    todo = pages(args)
    with sync_playwright() as p:
        b = p.chromium.launch(executable_path='/opt/pw-browsers/chromium')
        pg = b.new_page(viewport={'width': 1200, 'height': 630})
        pg.route(re.compile(r'https://fonts\.(googleapis|gstatic)\.com/.*'), font_route)
        pg.goto(BASE + 'tools/og/page.html')
        pg.evaluate('document.fonts.ready')
        for path in todo:
            src = path.read_text(encoding='utf-8')
            url = meta(src, 'og:url')
            if not url.startswith(SITE):
                print('略過（沒有 og:url）', path, file=sys.stderr)
                continue
            slug = image_slug(url)
            title = meta(src, 'og:title')
            title = re.sub(r'^技術剖析\s*\|\s*', '', title)          # 技術介紹頁的標題前綴，圖上已經有類別了
            title = re.sub(r'｜果汁龍的研究$', '', title)
            icon = re.search(r'<link rel="icon" type="image/svg\+xml" href="([^"]+)"', src)
            icon_url = BASE + (path.parent / icon.group(1)).resolve().relative_to(ROOT).as_posix() if icon else BASE + 'assets/logo.svg'
            data = {'kind': kind(slug), 'title': title, 'desc': meta(src, 'og:description'), 'icon': icon_url}
            pg.evaluate('d => render(d)', data)
            pg.evaluate('document.fonts.ready')
            pg.screenshot(path=str(outdir / f'{slug}.jpg'), type='jpeg', quality=88)
            point_tag(path, image_url(url))
            print(f'{slug}.jpg  {json.dumps(data, ensure_ascii=False)[:90]}')
        b.close()


if __name__ == '__main__':
    main(sys.argv[1:])
