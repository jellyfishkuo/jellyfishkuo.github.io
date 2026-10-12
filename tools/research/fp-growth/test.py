import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from fpgrowth import fp_growth
from apriori import apriori
from playwright.sync_api import sync_playwright
ITEMS=['咖啡','麵包','牛奶','飯糰','茶葉蛋','洋芋片']
U='http://127.0.0.1:8770/research/fp-growth.html'
with sync_playwright() as p:
    b=p.chromium.launch()
    pg=b.new_page(viewport={'width':1280,'height':900}); errs=[]; pg.on('pageerror',lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)
    bad=0
    for trial in range(300):
        rows=random.randint(3,12); db=[set(random.sample(ITEMS, random.randint(1,6))) for _ in range(rows)]
        ms=random.randint(1,rows)
        fp={frozenset(k):v for k,v in fp_growth(db, ms).items()}
        ap=set(frozenset(x) for x in apriori(db, ms))
        got=pg.evaluate("([d,m])=>{const tr=buildTrace(d,m);return tr[tr.length-1].result.map(r=>[r.set,r.count])}", [[sorted(t) for t in db], ms])
        got={frozenset(s):c for s,c in got}
        if got!=fp or set(fp)!=ap or any(sum(1 for t in db if set(k)<=t)!=v for k,v in fp.items()): bad+=1
    print('random mismatches:', bad)
    pg.reload(); pg.wait_for_timeout(400)
    hs=set(); kinds=[]
    PRINT=False
    while True:
        st=pg.evaluate("[trace[cursor].kind, trace[cursor].depth, document.getElementById('explain').offsetHeight, document.getElementById('explain').innerText.split('\\n')[1]]")
        hs.add(st[2]); kinds.append(st)
        if pg.is_disabled('#btn-next'): break
        pg.click('#btn-next')
    print('explain heights', hs)
    # screenshot at a base step depth0 for 牛奶 and at a depth-1 build
    pg.click('#btn-first')
    def goto(cond):
        pg.evaluate("cursor=0;showStep()")
        while not pg.evaluate(cond): pg.click('#btn-next')
    goto("trace[cursor].kind==='insert'&&trace[cursor].row===5"); pg.screenshot(path='fp_insert.png', full_page=True)
    goto("trace[cursor].kind==='base'&&trace[cursor].item==='牛奶'&&trace[cursor].depth===0"); pg.screenshot(path='fp_base.png', full_page=True)
    goto("trace[cursor].kind==='build'&&trace[cursor].suffix.join()==='牛奶'"); pg.locator('.a-tree').screenshot(path='fp_cond.png')
    pg.click('#header tr[data-item="咖啡"]'); pg.locator('.a-tree').screenshot(path='fp_link.png')
    print('errs', errs)
    m=b.new_page(viewport={'width':375,'height':760},is_mobile=True,has_touch=True,device_scale_factor=2); m.goto(U); m.wait_for_timeout(400)
    for i in range(8): m.click('#btn-next')
    m.screenshot(path='fp_mobile.png', full_page=True); print('mobile sw', m.evaluate('document.documentElement.scrollWidth'))
    b.close()
