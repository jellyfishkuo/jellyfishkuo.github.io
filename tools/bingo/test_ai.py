"""賓果：跟電腦玩從頭玩到尾（375／320 px、深淺色），檢查版面不動、紀錄、自己排。先開 python3 -m http.server 8770（repo 根目錄）。截圖存在這個資料夾。"""
import time
from playwright.sync_api import sync_playwright
import os
HERE=os.path.dirname(os.path.abspath(__file__)); os.chdir(HERE)
R='../set-online/'
LIB=open(R+'package/dist/peerjs.min.js').read(); MQ=open(R+'mq/package/dist/mqtt.min.js').read()
with sync_playwright() as p:
    b=p.chromium.launch(executable_path='/opt/pw-browsers/chromium')
    for w,theme in ((375,'dark'),(320,'light')):
        ctx=b.new_context(viewport={'width':w,'height':740},device_scale_factor=1,is_mobile=True,has_touch=True)
        ctx.add_init_script(f"try{{localStorage.setItem('jfk-theme','{theme}')}}catch(e){{}}")
        ctx.route("**/peerjs.min.js", lambda r: r.fulfill(body=LIB, content_type="application/javascript"))
        ctx.route("**/mqtt.min.js", lambda r: r.fulfill(body=MQ, content_type="application/javascript"))
        ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        ctx.route("**/cdn.jsdelivr.net/npm/canvas-confetti**", lambda r: r.fulfill(body="", content_type="application/javascript"))
        pg=ctx.new_page(); errs=[]; pg.on('pageerror',lambda e: errs.append(str(e))); pg.on('console', lambda m: m.type=='error' and errs.append(m.text))
        pg.goto('http://127.0.0.1:8770/games/bingo.html'); time.sleep(0.5)
        pg.screenshot(path=f'setup-{w}.png',full_page=True)
        def pos(): return pg.evaluate("[...document.querySelectorAll('#board,.called-list,#mainBtn,#tools')].map(e=>Math.round(e.getBoundingClientRect().top+scrollY))")
        p0=pos()
        pg.click('#mainBtn'); time.sleep(0.3)
        print(w,'after start',pg.inner_text('#statusMain'), pos()==p0)
        for step in range(60):
            ph=pg.evaluate("document.getElementById('over').hidden")
            if not ph: break
            if pg.locator('.cell.can').count():
                pg.locator('.cell.can').first.click()
            time.sleep(0.4)
            if pos()!=p0: print('MOVED', pos(), p0)
        print('over:', pg.inner_text('#overTitle'), '|', pg.inner_text('#overSub'))
        pg.screenshot(path=f'over-{w}.png')
        pg.click('#overClose'); time.sleep(0.2)
        pg.screenshot(path=f'end-{w}.png',full_page=True)
        print('scrollW', pg.evaluate('document.documentElement.scrollWidth'), 'rec', pg.evaluate("localStorage.getItem('jfk-bingo-v1')"))
        pg.click('#mainBtn'); time.sleep(0.2); print('phase back:', pg.inner_text('#statusMain'))
        # manual fill
        pg.click('#btnManual'); 
        for i in range(25): pg.locator('.cell').nth(i).click()
        print('manual:', pg.inner_text('#toolHint'), pg.evaluate("[...document.querySelectorAll('.cell')].map(c=>c.textContent).join(',')"))
        print('errs', errs)
    b.close()
