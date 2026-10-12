exec(open('mp.py').read())
PAGE = sys.argv[1] if len(sys.argv)>1 else 'short.html'
def play_to_end(pgs, limit=80):
    t=0
    for _ in range(limit):
        if all('show' in (pg.get_attribute("#custom-alert","class") or '') for pg in pgs): return True
        pg=pgs[t%len(pgs)]; t+=1
        s=pg.evaluate(SETS, True)
        if s: pg.evaluate(JSCLICK, s[0])
        elif pg.is_visible('#btn-deal') and not pg.evaluate("document.getElementById('btn-deal').disabled"): pg.evaluate("document.getElementById('btn-deal').click()")
        time.sleep(1.0)
    return False
with sync_playwright() as p:
    b=p.chromium.launch()
    h=newpage(b,'阿龍',page=PAGE); a=newpage(b,'小明',page=PAGE); c=newpage(b,'小華',page=PAGE)
    code=host_room(h); join(a,code); join(c,code); start(h); wait_board([h,a,c])
    print("ended:", play_to_end([h,a,c]))
    print("alert 阿龍:", h.inner_text('#custom-alert-text').replace('\n',' / '))
    print("alert 小華:", c.inner_text('#custom-alert-text').replace('\n',' / '))
    print("summary sub:", c.inner_text('.summary-sub'))
    print("buttons after end:", c.inner_text('#btn-restart'), "deal visible", c.is_visible('#btn-deal'))
    # rematch: 小華 proposes, 小明 declines
    c.click('#custom-alert-again'); time.sleep(0.5); print("rematch banner 小明 (alert still open, banner clickable):", banner(a)); a.click('#action-banner-no', timeout=3000); time.sleep(0.5)
    print("   小明 declines -> 小華 (proposer):", toast(c), "| 阿龍:", toast(h))
    time.sleep(3)
    # vote timeout: 阿龍 proposes, nobody answers  (shorten by evaluating? just wait 21s)
    h.click('#custom-alert-btn'); a.click('#custom-alert-btn'); c.click('#custom-alert-btn') if c.is_visible('#custom-alert-btn') else None; h.click('#btn-restart'); time.sleep(21)
    print("   timeout -> 阿龍:", toast(h), "| 小明 banner:", banner(a))
    time.sleep(3)
    # proposer leaves during vote
    a.click('#btn-restart'); time.sleep(0.4); a.context.close(); t0=time.time()
    while time.time()-t0<25 and banner(h)!='(no banner)': time.sleep(0.3)
    print(f"proposer left -> 阿龍 banner cleared after {time.time()-t0:.1f}s, toast:", toast(h))
    # room full: fill up to 6 then 7th
    extra=[]
    for i,n in enumerate(['A1','A2','A3','A4']):
        pg=newpage(b,n,page=PAGE); join(pg,code); extra.append(pg)
    print("players online (host chips):", chips(h))
    x=newpage(b,'七號',page=PAGE); x.fill('#room-input',code); x.click('#btn-join-room'); time.sleep(4)
    print("7th:", status(x))
    print("errs", [pg.errs for pg in [h,c,x]+extra]); b.close()
