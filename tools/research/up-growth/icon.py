import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
from playwright.sync_api import sync_playwright
D=REPO + '/assets/icons/'
svg=open(D+'up-growth.svg').read()
with sync_playwright() as p:
    b=p.chromium.launch()
    for n in (32,180):
        pg=b.new_page(viewport={'width':n,'height':n})
        tag = '<svg width="%d" height="%d" ' % (n, n)
        pg.set_content('<html><body style="margin:0;background:transparent">' + svg.replace('<svg ', tag, 1) + '</body></html>')
        pg.screenshot(path=f'{D}up-growth-{n}.png', omit_background=True, clip={'x':0,'y':0,'width':n,'height':n})
    b.close()
