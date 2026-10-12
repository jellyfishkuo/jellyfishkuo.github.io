import time
from playwright.sync_api import sync_playwright
LIB=open('package/dist/peerjs.min.js').read(); MQ=open('mq/package/dist/mqtt.min.js').read()
URL="http://127.0.0.1:8766/game-set.html"
def newpage(b, vw=(390,664), mobile=True):
    ctx=b.new_context(viewport={"width":vw[0],"height":vw[1]}, device_scale_factor=2, is_mobile=mobile, has_touch=mobile)
    ctx.route("**/peerjs.min.js", lambda r: r.fulfill(body=LIB, content_type="application/javascript"))
    ctx.route("**/mqtt.min.js", lambda r: r.fulfill(body=MQ, content_type="application/javascript"))
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg=ctx.new_page(); pg.errs=[]; pg.on("pageerror", lambda e: pg.errs.append(str(e))); pg.goto(URL); return pg
def connect(h,g):
    for pg,n in ((h,'房主'),(g,'朋友')): pg.select_option("#game-mode","online"); pg.fill('#nickname-input', n)
    h.click("#btn-create-room"); h.wait_for_function("document.getElementById('room-code').textContent !== '----'")
    g.fill("#room-input", h.inner_text("#room-code")); g.click("#btn-join-room")
    g.wait_for_function("/人在線/.test(document.getElementById('connection-status').textContent)", timeout=25000)
    h.wait_for_function("!document.getElementById('btn-restart').hidden", timeout=10000); h.click('#btn-restart')
    for pg in (h,g): pg.wait_for_function("document.querySelectorAll('#board .card:not(.empty)').length>=12", timeout=15000)
    time.sleep(0.5)
def fit(pg):
    return pg.evaluate("""() => { const cs=[...document.querySelectorAll('#board .card')]; const r=cs.map(c=>c.getBoundingClientRect());
      const btns=[...document.querySelectorAll('.controls button')].filter(b=>b.offsetParent).map(b=>b.getBoundingClientRect());
      return {vh: innerHeight, vw: innerWidth, scrollW: document.documentElement.scrollWidth,
        boardTop: Math.round(Math.min(...r.map(x=>x.top))), boardBottom: Math.round(Math.max(...r.map(x=>x.bottom))),
        cardW: Math.round(r[0].width), cardH: Math.round(r[0].height),
        btnBottom: Math.round(Math.max(...btns.map(x=>x.bottom)))}; }""")
