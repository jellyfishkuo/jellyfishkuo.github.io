import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys, json
sys.path.insert(0, REPO + '/research/code')
from apriori import apriori
from playwright.sync_api import sync_playwright
ITEMS=['咖啡','麵包','牛奶','飯糰','茶葉蛋','洋芋片']
U='http://127.0.0.1:8770/research/apriori.html'
with sync_playwright() as p:
    b=p.chromium.launch()
    pg=b.new_page(viewport={'width':1280,'height':900}); errs=[]; pg.on('pageerror',lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)
    # 1. correctness vs python on random data
    bad=0
    for trial in range(200):
        rows=random.randint(3,12); db=[set(random.sample(ITEMS, random.randint(1,6))) for _ in range(rows)]
        ms=random.randint(1,rows)
        exp=sorted(tuple(x) for x in apriori(db, ms))
        got=pg.evaluate("([d,m])=>{db=d.map(t=>new Set(t));minSup=m;const tr=buildTrace();return tr[tr.length-1].found.flat().map(c=>c.set)}", [[sorted(t) for t in db], ms])
        got=sorted(tuple(x) for x in got)
        if exp!=got: bad+=1
    print('random mismatches:', bad)
    pg.reload(); pg.wait_for_timeout(400)
    # 2. walk all steps on sample, record page scroll & explain height & code hl
    seen=[]
    while True:
        st=pg.evaluate("[trace[cursor].kind, window.scrollY, document.getElementById('explain').offsetHeight, [...document.querySelectorAll('#code .ln.hl')].map(l=>+l.dataset.n), document.getElementById('cands').innerText.replace(/\\n/g,' ')]")
        seen.append(st)
        if pg.is_disabled('#btn-next'): break
        pg.click('#btn-next'); pg.wait_for_timeout(30)
    for s in seen: print(s[0], s[2], s[3][:3], '…' if len(s[3])>3 else '', s[4][:110])
    print('explain heights', set(s[2] for s in seen))
    print('stats', pg.inner_text('.stats').replace('\n',' '))
    # 3. click prune candidate hint
    pg.click('#btn-first')
    while pg.evaluate("trace[cursor].kind")!='prune' or pg.evaluate("trace[cursor].k")!=3: pg.click('#btn-next')
    pg.locator('.cand.out').first.click(); print('hint:', pg.inner_text('#cands-hint'), '| matched rows', pg.locator('tr.match').count())
    pg.screenshot(path='ap_desktop.png', full_page=True)
    pg.click('#lang button[data-lang=py]'); print('py hl', pg.evaluate("[...document.querySelectorAll('#code .ln.hl')].map(l=>+l.dataset.n)"))
    # 4. edit + minsup
    pg.click('#btn-edit'); pg.click('.cell[data-r="6"][data-i="咖啡"]'); pg.click('#sup-minus')
    print('after edit minsup', pg.inner_text('#sup-val'), pg.inner_text('#explain')[:40])
    print('errs', errs)
    m=b.new_page(viewport={'width':375,'height':760},is_mobile=True,has_touch=True,device_scale_factor=2)
    m.goto(U); m.wait_for_timeout(500)
    for i in range(9): m.click('#btn-next')
    m.screenshot(path='ap_mobile.png', full_page=True); print('mobile sw', m.evaluate('document.documentElement.scrollWidth'))
    b.close()
