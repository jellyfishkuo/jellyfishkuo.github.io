"""產生 assets/icons/chess-32.png、chess-180.png（從 chess.svg 用 Chromium 畫出來）。
用法：python3 tools/chess/icon.py"""
import os
from playwright.sync_api import sync_playwright

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SVG = open(os.path.join(ROOT, 'assets/icons/chess.svg'), encoding='utf-8').read()


def launch(p):
    try:
        return p.chromium.launch()
    except Exception:  # 環境裡的 Playwright 版本跟瀏覽器對不上時，用系統的 Chromium
        return p.chromium.launch(executable_path=os.environ.get('CHROMIUM', '/opt/pw-browsers/chromium'))


with sync_playwright() as p:
    b = launch(p)
    for size in (32, 180):
        pg = b.new_page(viewport={'width': size, 'height': size})
        pg.set_content(f'<html><body style="margin:0;background:transparent">{SVG.replace("<svg ", f"<svg width=\"{size}\" height=\"{size}\" ", 1)}</body></html>')
        pg.screenshot(path=os.path.join(ROOT, f'assets/icons/chess-{size}.png'), omit_background=True)
        pg.close()
    b.close()
print('done')
