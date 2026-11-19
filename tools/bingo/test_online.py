"""賓果：3 人連線（直連＋一人只走 MQTT 備援）、中途重新整理接回格子、超時代喊、離開。
先照 tools/README.md 的 set-online 段落 npm install、npm pack，再 bash ../set-online/up.sh。"""
import time, json
from playwright.sync_api import sync_playwright
import os
HERE=os.path.dirname(os.path.abspath(__file__)); os.chdir(HERE)
R='../set-online/'
LIB=open(R+'package/dist/peerjs.min.js').read(); MQ=open(R+'mq/package/dist/mqtt.min.js').read()
SRC=open('../../games/bingo.html', encoding='utf-8').read()
T=SRC.replace("host: '0.peerjs.com',\n                port: 443,","host: '127.0.0.1',\n                port: 9000,").replace("secure: true,","secure: false,",1)
T=T.replace("'wss://broker.emqx.io:8084/mqtt',","'ws://127.0.0.1:9001/mqtt',").replace("'wss://broker.hivemq.com:8884/mqtt'","'ws://127.0.0.1:9999/mqtt'")
assert T.count('127.0.0.1')==3
URL='http://127.0.0.1:8770/games/bingo.html'
def page(b, name, nopeer=False):
    ctx=b.new_context(viewport={'width':375,'height':740},is_mobile=True,has_touch=True)
    ctx.route("**/games/bingo.html", lambda r: r.fulfill(body=T, content_type="text/html; charset=utf-8"))
    ctx.route("**/peerjs.min.js", lambda r: r.fulfill(body="" if nopeer else LIB, content_type="application/javascript"))
    ctx.route("**/mqtt.min.js", lambda r: r.fulfill(body=MQ, content_type="application/javascript"))
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    ctx.route("**/canvas-confetti**", lambda r: r.fulfill(body="", content_type="application/javascript"))
    pg=ctx.new_page(); pg.errs=[]; pg.on('pageerror',lambda e: pg.errs.append(str(e)))
    pg.goto(URL); pg.click('#seg button[data-mode=online]'); pg.fill('#nick',name); pg.name=name
    return pg
def st(pg): return pg.inner_text('#statusMain')
with sync_playwright() as p:
    b=p.chromium.launch(executable_path='/opt/pw-browsers/chromium', args=['--disable-features=LocalNetworkAccessChecks,BlockInsecurePrivateNetworkRequests,PrivateNetworkAccessChecks'])
    h=page(b,'房主'); g1=page(b,'小明'); g2=page(b,'阿華',nopeer=True)
    h.click('#btnCreate'); h.wait_for_function("document.getElementById('roomCode').textContent!=='----'")
    code=h.inner_text('#roomCode'); print('room',code)
    for g in (g1,g2):
        g.fill('#roomInput',code); g.click('#btnJoin')
    h.wait_for_function("/3 人在線/.test(document.getElementById('conn').textContent)",timeout=30000)
    print('g1:',g1.inner_text('#conn'),'| g2:',g2.inner_text('#conn'))
    g1.click('#mainBtn'); time.sleep(0.5)
    print('host status:',st(h), '| btn', h.inner_text('#mainBtn'))
    h.click('#mainBtn'); time.sleep(0.4)
    print('banner:', h.is_visible('#banner'), h.inner_text('#bannerText') if h.is_visible('#banner') else '')
    if h.is_visible('#banner'): h.click('#bannerYes')
    time.sleep(0.8)
    for pg in (h,g1,g2): print(pg.name, st(pg))
    boards={pg.name: pg.evaluate("[...document.querySelectorAll('.cell')].map(c=>c.textContent).join(',')") for pg in (h,g1,g2)}
    reloaded=False
    for step in range(80):
        if all(not pg.evaluate("document.getElementById('over').hidden") for pg in (h,g1,g2)): break
        for pg in (h,g1,g2):
            if pg.locator('.cell.can').count():
                pg.locator('.cell.can').first.click(); break
        time.sleep(0.5)
        called=int(h.inner_text('#calledN').split('/')[0])
        if called==4 and not reloaded:
            reloaded=True
            g1.reload(); g1.wait_for_selector('#banner:not([hidden])',timeout=5000)
            print('g1 banner:', g1.inner_text('#bannerText')); g1.click('#bannerYes')
            g1.wait_for_function("/已連上/.test(document.getElementById('conn').textContent)",timeout=30000)
            time.sleep(0.8)
            nb=g1.evaluate("[...document.querySelectorAll('.cell')].map(c=>c.textContent).join(',')")
            print('g1 board kept after reload:', nb==boards['小明'], '| called on g1', g1.inner_text('#calledN'))
    for pg in (h,g1,g2): print(pg.name,'over:',pg.inner_text('#overTitle'),'| lines', pg.inner_text('#lineText'), '| rec', pg.evaluate("localStorage.getItem('jfk-bingo-v1')"))
    lists=[pg.evaluate("[...document.querySelectorAll('#calledList b')].map(x=>x.textContent).join(',')") for pg in (h,g1,g2)]
    print('same called:', len(set(lists))==1, lists[0])
    g2.screenshot(path='mp-over-g2.png')
    g1.click('#overClose'); g1.screenshot(path='mp-g1.png', full_page=True)
    h.click('#overAgain'); time.sleep(0.6)
    for pg in (h,g1,g2): print(pg.name,'after again:',st(pg))
    # timeout auto-call: start game, nobody plays except waiting > 20s
    g1.click('#mainBtn'); g2.click('#mainBtn'); time.sleep(0.5); h.click('#mainBtn'); time.sleep(0.5)
    print('turn:', st(h)); time.sleep(21.5)
    print('after 21s called:', h.inner_text('#calledN'), '|', h.inner_text('#statusSub'))
    # guest leaves
    g2.click('#btnLeave'); time.sleep(1.5); print('host conn after leave:', h.inner_text('#conn'))
    for pg in (h,g1,g2): print(pg.name,'errs',pg.errs)
    b.close()
