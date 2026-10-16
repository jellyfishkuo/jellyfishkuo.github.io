import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
from playwright.sync_api import sync_playwright
I=REPO + '/assets/icons/'
svg=open(I+'hyperloglog.svg').read()
with sync_playwright() as p:
    b=p.chromium.launch()
    for size in (32,180):
        pg=b.new_page(viewport={'width':size,'height':size})
        sized=svg.replace('<svg ', '<svg width="%d" height="%d" ' % (size, size), 1)
        pg.set_content('<html><body style="margin:0;background:transparent">' + sized + '</body></html>')
        pg.locator('svg').screenshot(path=I + 'hyperloglog-%d.png' % size, omit_background=True)
    b.close()
