import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../..'))  # repo 根目錄
import sys
from playwright.sync_api import sync_playwright
S=os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')
name=sys.argv[1]
with sync_playwright() as p:
    b=p.chromium.launch()
    for vw,mob,tag in [((1366,900),False,'d'),((390,844),True,'m')]:
        ctx=b.new_context(viewport={'width':vw[0],'height':vw[1]},is_mobile=mob,device_scale_factor=1 if not mob else 2)
        ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort()); ctx.route("**/cdn.jsdelivr.net/**", lambda r: r.abort())
        pg=ctx.new_page(); errs=[]; pg.on('pageerror',lambda e:errs.append(str(e)))
        pg.goto(f'http://127.0.0.1:8770/games/{name}-detail.html'); pg.wait_for_timeout(600)
        pg.screenshot(path=f'{S}/{name}_{tag}_top.png')
        n=pg.locator('.tab-btn').count()
        pg.evaluate("window.scrollTo(0, 2500)"); pg.wait_for_timeout(200)
        pg.click(f'.tab-btn >> nth={n-2}', force=True); pg.wait_for_timeout(700)
        tabtop=round(pg.evaluate("document.querySelector('.tab-wrapper').getBoundingClientRect().top"))
        links=pg.locator('.tab-content.active .toc a'); k=links.count()
        links.nth(k-1).click(); pg.wait_for_timeout(800)
        tgt=round(pg.evaluate("document.querySelector(location.hash).getBoundingClientRect().top"))
        cross=pg.evaluate("""()=>{const a=[...document.querySelectorAll('.tab-content a[href^="#"]')].find(a=>{const t=document.querySelector(a.getAttribute('href'));return t&&t.closest('.tab-content')!==a.closest('.tab-content')});return a?a.getAttribute('href'):null}""")
        print(f"{tag}: tabs={n} after tab switch tab-bar top={tabtop} | toc->{pg.evaluate('location.hash')} top={tgt} | cross link {cross}", end=' ')
        if cross:
            src=pg.evaluate(f"""document.querySelector('.tab-content a[href="{cross}"]').closest('.tab-content').id""")
            pg.evaluate(f"""[...document.querySelectorAll('.tab-btn')][[...document.querySelectorAll('.tab-content')].findIndex(c=>c.id==='{src}')].click()""")
            pg.wait_for_timeout(200); pg.click(f'.tab-content.active a[href="{cross}"]'); pg.wait_for_timeout(800)
            print("-> active", pg.evaluate("document.querySelector('.tab-content.active').id"), end=' ')
        print("| sw", pg.evaluate('document.documentElement.scrollWidth'), vw[0], "| errs", errs)
        pg.goto(f'http://127.0.0.1:8770/games/{name}-detail.html#'+pg.evaluate("document.querySelectorAll('.tab-content')[%d].querySelector('section').id" % (n-1))); pg.wait_for_timeout(500)
        print("   deep link opens tab:", pg.evaluate("document.querySelector('.tab-content.active').id"))
        if tag=='d': pg.screenshot(path=f'{S}/{name}_{tag}_deep.png')
        ctx.close()
    b.close()
