exec(open('rx.py').read())
URL_SHORT="http://127.0.0.1:8766/short.html"
with sync_playwright() as p:
    b=p.chromium.launch()
    h=newpage(b,(390,844)); g=newpage(b,(390,844))
    for pg in (h,g): pg.goto(URL_SHORT); pg.wait_for_timeout(300)
    connect(h,g)
    print("ended:", play_to_end(h,g), "| alerts:", h.inner_text('#custom-alert-text'), '/', g.inner_text('#custom-alert-text'))
    print("deal visible after end:", g.is_visible('#btn-deal'), "| restart label:", g.inner_text('#btn-restart'))
    g.evaluate("document.getElementById('btn-restart').click()"); time.sleep(0.6)
    print("host banner:", banner(h))
    try:
        h.click('#action-banner-no', timeout=2000); print("host could click banner over alert: yes")
    except Exception as e:
        print("host could click banner over alert: NO (covered)"); h.evaluate("document.getElementById('action-banner-no').click()")
    time.sleep(0.6); print("guest toast after decline:", toast(g))
    print("errs", h.errs+g.errs); b.close()
