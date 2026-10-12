import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys, itertools
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from hui_miner import hui_miner
from playwright.sync_api import sync_playwright
ITEMS=['咖啡','麵包','牛奶','飯糰','茶葉蛋','洋芋片']
U='http://127.0.0.1:8781/research/high-utility.html'
def brute(db, profit, mu):
    out={}
    for n in range(1,len(ITEMS)+1):
        for s in itertools.combinations(ITEMS,n):
            u=sum(sum(t[i]*profit[i] for i in s) for t in db if all(i in t for i in s))
            if u>=mu: out[frozenset(s)]=u
    return out
with sync_playwright() as p:
    b=p.chromium.launch()
    ctx=b.new_context(viewport={'width':1280,'height':900}); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg=ctx.new_page(); errs=[]; pg.on('pageerror',lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)
    bad=0; nonempty=0
    for trial in range(400):
        rows=random.randint(1,10)
        db=[{i:random.randint(1,5) for i in random.sample(ITEMS, random.randint(1,6))} for _ in range(rows)]
        profit={i:random.randint(1,40) for i in ITEMS}
        total=sum(t[i]*profit[i] for t in db for i in t)
        mu=random.randint(1,max(1,total))
        py={frozenset(k):v for k,v in hui_miner(db,profit,mu).items()}
        bf=brute(db,profit,mu)
        got=pg.evaluate("([d,p,m])=>{const tr=buildTrace(d,p,m);return tr[tr.length-1].result.map(r=>[r.set,r.util])}", [db,profit,mu])
        js={frozenset(s):u for s,u in got}
        if len(got)!=len(js): bad+=1
        if not (js==py==bf): bad+=1; print('MISMATCH',db,profit,mu,js,py,bf); break
        nonempty+= bool(bf)
    print('random trials 400, mismatches:', bad, 'non-empty results:', nonempty)
    pg.reload(); pg.wait_for_timeout(400)
    seen=[]
    while True:
        st=pg.evaluate("""[trace[cursor].kind, window.scrollY, document.getElementById('explain').offsetHeight,
            [...document.querySelectorAll('#code .ln.hl')].map(l=>+l.dataset.n), document.getElementById('explain').innerText.split('\\n').slice(1).join(' ')]""")
        seen.append(st)
        if pg.is_disabled('#btn-next'): break
        pg.click('#btn-next'); pg.wait_for_timeout(20)
    for i,s in enumerate(seen): print(i+1, s[0], s[3][:2], len(s[3]), s[4][:150])
    print('steps', len(seen), 'explain heights', set(s[2] for s in seen), 'scrollY', set(s[1] for s in seen))
    print('stats', pg.inner_text('.stats').replace('\n',' '))
    print('compare', pg.inner_text('#compare').replace('\n',' | '))
    print('errs', errs)
    b.close()
