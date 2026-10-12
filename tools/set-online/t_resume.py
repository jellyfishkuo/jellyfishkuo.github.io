import sys
exec(open('rx.py').read())
PAGE = sys.argv[1] if len(sys.argv)>1 else 'game-set.html'
def state(pg):
    return pg.evaluate("[...document.querySelectorAll('#board .card')].map(e=>e.dataset.uid||'-').join(',')"), pg.inner_text('#stat-found'), pg.inner_text('#stat-opponent'), pg.inner_text('#stat-time')
def status(pg): return pg.inner_text('#connection-status')
def wait_connected(pg, t=25):
    pg.wait_for_function("document.getElementById('connection-status').classList.contains('connected') && !!document.querySelector('#board .card:not(.empty)') && !/同步中|正在同步/.test(document.getElementById('connection-status').textContent)", timeout=t*1000)
def score_some(h,g,n=2):
    for i in range(n):
        pg=[h,g][i%2]; s=pg.evaluate(SETS, True)
        if s: pg.evaluate(JSCLICK, s[0]); time.sleep(1.0)
with sync_playwright() as p:
    b=p.chromium.launch()
    h=newpage(b,(1200,900),False); g=newpage(b,(1200,900),False)
    for pg in (h,g): pg.goto(f"http://127.0.0.1:8766/{PAGE}"); pg.wait_for_timeout(300)
    connect(h,g); wait_connected(g); score_some(h,g)
    hs=state(h); print("before:", "host", hs[1:], "| guest", state(g)[1:])
    # ---- T1 guest reload -> rejoin same game
    g.reload(); g.wait_for_timeout(600)
    print("T1 guest after reload banner:", banner(g))
    t0=time.time()
    while time.time()-t0<20 and '離線' not in status(h): time.sleep(0.3)
    print("   host status:", status(h)); time.sleep(2); t_paused=h.inner_text('#stat-time'); time.sleep(2); print("   host clock paused:", t_paused, '->', h.inner_text('#stat-time'))
    g.click('#action-banner-yes'); wait_connected(g)
    time.sleep(1.2)
    print("   resumed: board same", state(g)[0]==state(h)[0]==hs[0], "| host", state(h)[1:], "| guest", state(g)[1:], "| host toast:", toast(h))
    # ---- T2 host reload -> restore room, guest rejoins
    score_some(h,g,1); hs=state(h)
    code=h.evaluate("document.getElementById('room-code').textContent")
    h.reload(); h.wait_for_timeout(600)
    print("T2 host after reload banner:", banner(h))
    t0=time.time()
    while time.time()-t0<25 and not g.is_visible('#action-banner'): time.sleep(0.3)
    print("   guest banner:", banner(g))
    h.click('#action-banner-yes')
    h.wait_for_function("document.getElementById('connection-status').textContent.includes('牌局已恢復')", timeout=20000)
    print("   host status:", status(h), "| code same:", h.evaluate("document.getElementById('room-code').textContent")==code, "| board kept:", state(h)[0]==hs[0])
    g.click('#action-banner-yes'); wait_connected(g); time.sleep(1.2)
    print("   resumed: board same", state(g)[0]==state(h)[0]==hs[0], "| host", state(h)[1:], "| guest", state(g)[1:])
    # play on after resume
    score_some(h,g,2); print("   after more play host", state(h)[1:], "guest", state(g)[1:], "boards equal", state(h)[0]==state(g)[0])
    # ---- T3 a different person joins after guest leaves -> new game
    g.context.close()
    t0=time.time()
    while time.time()-t0<25 and '離線' not in status(h): time.sleep(0.3)
    n=newpage(b,(1200,900),False); n.goto(f"http://127.0.0.1:8766/{PAGE}"); n.select_option('#game-mode','online'); n.fill('#nickname-input','路人'); n.fill('#room-input', code); n.click('#btn-join-room'); time.sleep(6); print("n status", status(n), n.input_value("#nickname-input")); wait_connected(n); time.sleep(1)
    print("T3 new person: host", state(h)[1:], "| newcomer", state(n)[1:], "| boards equal", state(h)[0]==state(n)[0])
    print("errs", h.errs+n.errs); b.close()
