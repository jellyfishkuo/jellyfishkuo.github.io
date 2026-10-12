exec(open('mp.py').read())
PAGE = sys.argv[1] if len(sys.argv)>1 else 'game-set.html'
with sync_playwright() as p:
    b=p.chromium.launch()
    h=newpage(b,'阿龍',page=PAGE); a=newpage(b,'小明',page=PAGE); c=newpage(b,'小華',page=PAGE)
    # nickname required
    x=newpage(b,'',page=PAGE); x.click('#btn-create-room'); print("empty nick:", status(x)); x.context.close()
    code=host_room(h); print("host lobby:", status(h), "| btn:", h.is_visible('#btn-restart'), "| text:", h.inner_text('.board-waiting'))
    join(a, code); time.sleep(0.6)
    print("after 1 join host chips:", chips(h), "| btn:", h.inner_text('#btn-restart'), "| toast:", toast(h))
    print("guest lobby:", a.inner_text('.board-waiting'), "| chips:", chips(a), "| restart visible:", a.is_visible('#btn-restart'))
    join(c, code); time.sleep(0.6)
    print("3 players chips (小華 view):", chips(c), "| 小明 toast:", toast(a))
    start(h); wait_board([h,a,c]); time.sleep(0.5)
    print("boards equal:", board(h)==board(a)==board(c), "| ranks:", h.inner_text('#stat-opponent'), a.inner_text('#stat-opponent'), "| statuses:", status(a))
    # 小明 claims
    s=a.evaluate(SETS, True)[0]; a.evaluate(JSCLICK, s); time.sleep(0.35)
    print("小明 scored -> 阿龍 sees:", toast(h), "| tags:", h.evaluate("[...document.querySelectorAll('.claim-tag')].map(t=>t.textContent).join(',')"), "| mini cards:", h.locator('#game-toast .mini-card').count())
    print("            小華 sees:", toast(c), "| 小明 sees:", toast(a), a.locator('#game-toast .mini-card').count())
    time.sleep(0.6); print("   still highlighted at 0.95s?", h.locator('.card.taken').count()); time.sleep(0.6)
    print("   chips:", chips(c))
    # 小華 deal while sets exist
    c.click('#btn-deal'); time.sleep(0.5); print("小華 deal -> 小華:", toast(c), "| 阿龍:", toast(h), "| 小明:", toast(a))
    time.sleep(2.6)
    # simultaneous different sets by 3 players
    sets=h.evaluate(SETS, True); disj=[]
    for st in sets:
        if all(not set(st)&set(d) for d in disj): disj.append(st)
    sc0=(h.inner_text('#stat-found'),a.inner_text('#stat-found'),c.inner_text('#stat-found'))
    for pg,st in zip([h,a,c],disj): pg.evaluate(JSCLICK, st)
    time.sleep(3.2)
    print(f"{len(disj)} disjoint sets at once: scores {sc0} -> {(h.inner_text('#stat-found'),a.inner_text('#stat-found'),c.inner_text('#stat-found'))} | boards equal {board(h)==board(a)==board(c)}")
    # restart vote: 小明 proposes, 阿龍 accepts, 小華 declines
    a.click('#btn-restart'); time.sleep(0.5)
    print("vote: 小明:", banner(a), "| 阿龍:", banner(h), "| 小華:", banner(c))
    h.click('#action-banner-yes'); time.sleep(0.4); print("   after 阿龍 accepts, 小華:", banner(c), "| 阿龍:", banner(h))
    c.click('#action-banner-no'); time.sleep(0.5); print("   小華 declines -> 小明:", toast(a), "| 阿龍:", toast(h), "| 小華:", toast(c))
    time.sleep(3)
    # vote all accept
    b0=board(h); c.click('#btn-restart'); time.sleep(0.4); h.click('#action-banner-yes'); a.click('#action-banner-yes'); time.sleep(1)
    print("   all accept -> new game:", board(h)!=b0, "| equal:", board(h)==board(a)==board(c), "| scores:", h.inner_text('#stat-found'), a.inner_text('#stat-found'))
    # 4th joins mid game
    d=newpage(b,'阿美',page=PAGE); join(d, code); time.sleep(0.8)
    print("mid-game join: 阿美 board equal", board(d)==board(h), "| chips:", chips(d), "| 阿龍 toast:", toast(h))
    # 小明 leaves (closes) -> others notified; returns with same id
    pid=a.evaluate("sessionStorage.getItem('set-player-id')"); s=a.evaluate(SETS, True)[0]; a.evaluate(JSCLICK, s); time.sleep(1.2)
    mscore=a.inner_text('#stat-found'); a.reload(); a.wait_for_timeout(500)
    t0=time.time()
    while time.time()-t0<25 and '離線' not in chips(h): time.sleep(0.3)
    print(f"小明 reload: host chips after {time.time()-t0:.1f}s:", chips(h))
    a.click('#action-banner-yes'); a.wait_for_function("/人在線/.test(document.getElementById('connection-status').textContent)", timeout=20000); time.sleep(0.6)
    print("   小明 back: score", mscore, '->', a.inner_text('#stat-found'), "| chips:", chips(c), "| board equal", board(a)==board(h))
    print("errs", [pg.errs for pg in (h,a,c,d)]); b.close()
