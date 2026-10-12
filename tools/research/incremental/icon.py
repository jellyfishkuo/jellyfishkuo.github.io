"""用 playwright 把 SVG 圖示渲染成 32 / 180 的 PNG（透明背景）"""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
from playwright.sync_api import sync_playwright
D = REPO + '/assets/icons/'
svg = open(D + 'incremental.svg', encoding='utf-8').read()
with sync_playwright() as p:
    b = p.chromium.launch()
    for size in (32, 180):
        pg = b.new_page(viewport={'width': size, 'height': size})
        pg.set_content(f'<html><body style="margin:0;background:transparent">'
                       f'<div style="width:{size}px;height:{size}px">{svg.replace("<svg ", f"<svg width={size} height={size} ", 1)}</div></body></html>')
        pg.locator('div').screenshot(path=f'{D}incremental-{size}.png', omit_background=True)
    b.close()
