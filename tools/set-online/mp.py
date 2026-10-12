import time, sys
from playwright.sync_api import sync_playwright
LIB=open('package/dist/peerjs.min.js').read(); MQ=open('mq/package/dist/mqtt.min.js').read()
SETS = """(want) => { if (document.querySelector('#board .card.correct, #board .card.taken')) return []; const c=[...document.querySelectorAll('#board .card:not(.empty)')].map(e=>e.dataset);
  const ok=(a,b,d)=>new Set([a,b,d]).size!==2; const out=[];
  for(let i=0;i<c.length;i++)for(let j=i+1;j<c.length;j++)for(let k=j+1;k<c.length;k++)
   if(['count','color','shape','shading'].every(x=>ok(c[i][x],c[j][x],c[k][x]))===want) out.push([c[i].uid,c[j].uid,c[k].uid]);
  return out;}"""
JSCLICK="(u)=>u.forEach(x=>document.querySelector(`#board .card[data-uid='${x}']`).click())"
def toast(pg): return pg.inner_text("#game-toast").replace('\n',' ') if 'show' in (pg.get_attribute("#game-toast","class") or '') else '(none)'
def banner(pg): return pg.inner_text("#action-banner-text") if pg.is_visible("#action-banner") else "(no banner)"
def status(pg): return pg.inner_text('#connection-status')
def chips(pg): return pg.evaluate("[...document.querySelectorAll('#player-list .player-chip')].map(c=>c.textContent).join(' | ')")
def board(pg): return pg.evaluate("[...document.querySelectorAll('#board .card')].map(e=>e.dataset.uid||'-').join(',')")
def newpage(b, name, vw=(1200,900), mobile=False, page='game-set.html', init=None):
    ctx=b.new_context(viewport={"width":vw[0],"height":vw[1]}, is_mobile=mobile, has_touch=mobile, device_scale_factor=2 if mobile else 1)
    ctx.route("**/peerjs.min.js", lambda r: r.fulfill(body=LIB, content_type="application/javascript"))
    ctx.route("**/mqtt.min.js", lambda r: r.fulfill(body=MQ, content_type="application/javascript"))
    ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    if init: ctx.add_init_script(init)
    pg=ctx.new_page(); pg.errs=[]; pg.on("pageerror", lambda e: pg.errs.append(str(e))); pg.goto(f"http://127.0.0.1:8766/{page}"); pg.wait_for_timeout(300)
    pg.select_option('#game-mode','online'); pg.fill('#nickname-input', name); pg.name=name
    return pg
def host_room(h):
    h.click('#btn-create-room'); h.wait_for_function("document.getElementById('room-code').textContent !== '----'", timeout=20000)
    return h.inner_text('#room-code')
def join(g, code, t=25):
    g.fill('#room-input', code); g.click('#btn-join-room')
    g.wait_for_function("/人在線/.test(document.getElementById('connection-status').textContent)", timeout=t*1000)
def start(h):
    h.wait_for_function("!document.getElementById('btn-restart').hidden"); h.click('#btn-restart')
def wait_board(pgs):
    for pg in pgs: pg.wait_for_function("document.querySelectorAll('#board .card:not(.empty)').length>=12", timeout=15000)
