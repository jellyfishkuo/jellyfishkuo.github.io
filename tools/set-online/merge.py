import sys; sys.argv=['x']
exec(open('mp.py').read().split('\nif __name__')[0].split('\n# ---- tests')[0])
init = "localStorage.clear()" if False else None
with sync_playwright() as p:
    b=p.chromium.launch(args=['--host-resolver-rules=MAP *.peerjs.com 127.0.0.1'] if False else [])
    h=newpage(b,'房主'); code=host_room(h)
    a=newpage(b,'小明'); join(a,code); c=newpage(b,'阿華'); join(c,code)
    start(h); wait_board([h,a,c])
    s=a.evaluate(SETS,True)[0]; a.evaluate(JSCLICK,s); a.wait_for_timeout(2500)
    print('before:', chips(h))
    a.context.close(); h.wait_for_timeout(1000)
    # immediately rejoin as new tab with same name (old conn may not be detected yet)
    a2=newpage(b,'小明'); a2.fill('#room-input',code); a2.click('#btn-join-room'); a2.wait_for_timeout(6000)
    print('quick rejoin status:', status(a2)); print('host chips:', chips(h)); a3=a2
    print('after merge host:', chips(h)); print('a3 sees:', chips(a3)); print('toast h:', toast(h))
    d=newpage(b,'阿華'); d.fill('#room-input',code); d.click('#btn-join-room'); d.wait_for_timeout(4000)
    print('dup live name:', status(d))
    e=newpage(b,'房主'); e.fill('#room-input',code); e.click('#btn-join-room'); e.wait_for_timeout(4000)
    print('host name:', status(e))
    s=a3.evaluate(SETS,True)[0]; a3.evaluate(JSCLICK,s); a3.wait_for_timeout(2500)
    print('a3 scored:', chips(h)); print('errs', h.errs, a3.errs)
