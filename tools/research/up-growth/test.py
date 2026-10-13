import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys, itertools
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
import up_growth as UP
from playwright.sync_api import sync_playwright
ITEMS=['咖啡','麵包','牛奶','飯糰','茶葉蛋','洋芋片']
U='http://127.0.0.1:8798/research/up-growth.html'
SHOT = sys.argv[1] if len(sys.argv) > 1 else None   # 截圖資料夾（不要放在 repo 裡）
TRIALS = 400

def brute(db, profit, mu):
    out={}
    for n in range(1,len(ITEMS)+1):
        for s in itertools.combinations(ITEMS,n):
            u=sum(sum(t[i]*profit[i] for i in s) for t in db if all(i in t for i in s))
            if u>=mu: out[frozenset(s)]=u
    return out

def py_cands(db, profit, mu):
    """照 up_growth() 的前半段建 UP-Tree、呼叫 mine()，拿到候選和它們的上界"""
    twu, miu = {}, {}
    for t in db:
        tu=sum(q*profit[i] for i,q in t.items())
        for i,q in t.items():
            twu[i]=twu.get(i,0)+tu; miu[i]=min(miu.get(i,q*profit[i]),q*profit[i])
    order=sorted((i for i in twu if twu[i]>=mu), key=lambda i:(-twu[i],i))
    tree=UP.UPTree(order)
    for t in db:
        path=[i for i in order if i in t]; acc=0; nus=[]
        for i in path: acc+=t[i]*profit[i]; nus.append(acc)
        tree.add(path,nus,1)
    c={}; UP.mine(tree,(),mu,miu,c)
    return c

POS = "[...document.querySelectorAll('.card')].map(c=>{const r=c.getBoundingClientRect();return [Math.round(r.left),Math.round(r.top+scrollY),Math.round(r.height)]})"

def walk(pg, label):
    """從第一步按到最後一步：每個 .card 的位置和高度都不能變"""
    if not pg.is_disabled('#btn-first'): pg.click('#btn-first')
    pos=set(); widths=set(); hs=set(); n=0
    while True:
        pos.add(str(pg.evaluate(POS))); widths.add(pg.evaluate("document.documentElement.scrollWidth"))
        hs.add(pg.evaluate("document.getElementById('explain').offsetHeight")); n+=1
        if pg.is_disabled('#btn-next'): break
        pg.click('#btn-next')
    # 點選候選也不能推動區塊
    pg.click('.crow >> nth=0'); pos.add(str(pg.evaluate(POS)))
    pg.click('.crow >> nth=-1'); pos.add(str(pg.evaluate(POS)))
    pg.click('.crow >> nth=-1')
    print(label, 'steps', n, 'distinct card layouts', len(pos), 'scrollWidth', widths, 'explain heights', hs)
    return len(pos)

with sync_playwright() as p:
    b=p.chromium.launch()
    ctx=b.new_context(viewport={'width':1280,'height':900}); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg=ctx.new_page(); errs=[]; pg.on('pageerror',lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(500)
    bad=0; nonempty=0; tighter=0; fewer=0
    for trial in range(TRIALS):
        rows=random.randint(1,10)
        db=[{i:random.randint(1,5) for i in random.sample(ITEMS, random.randint(1,6))} for _ in range(rows)]
        profit={i:random.randint(1,40) for i in ITEMS}
        total=sum(t[i]*profit[i] for t in db for i in t)
        mu=random.randint(1,max(1,total))
        py={frozenset(k):v for k,v in UP.up_growth(db,profit,mu).items()}
        pc={k:v for k,v in py_cands(db,profit,mu).items()}
        bf=brute(db,profit,mu)
        got=pg.evaluate("([d,p,m])=>{const tr=buildTrace(d,p,m);const e=tr[tr.length-1];return [e.result.map(r=>[r.set,r.util]), e.cands.map(c=>[c.set,c.est,c.twu,c.util]), twoPhaseCost(d,p,m).cands]}", [db,profit,mu])
        js={frozenset(s):u for s,u in got[0]}
        jc={tuple(s):e for s,e,_,_ in got[1]}
        if jc!=pc: bad+=1; print('CANDS DIFFER', db, profit, mu, jc, pc)
        for s,e,tw,u in got[1]:
            ts=[t for t in db if all(i in t for i in s)]
            if tw!=sum(sum(t[i]*profit[i] for i in t) for t in ts) or u!=sum(sum(t[i]*profit[i] for i in s) for t in ts): bad+=1
            if not (u<=e<=tw) or e<mu: bad+=1; print('BOUND', s, e, tw, u)
            tighter+= e<tw
        if not set(bf)<=set(frozenset(s) for s in jc): bad+=1; print('CANDS MISS', db, profit, mu)
        if not (js==py==bf): bad+=1; print('MISMATCH',db,profit,mu,js,py,bf); break
        # Two-Phase 的候選就是 TWU 夠的組合，UP-Growth 的候選一定是它的子集合
        twp=sum(1 for n in range(1,7) for s in itertools.combinations(ITEMS,n)
                if any(all(i in t for i in s) for t in db) and sum(sum(t[i]*profit[i] for i in t) for t in db if all(i in t for i in s))>=mu)
        if got[2]!=twp or len(jc)>twp: bad+=1; print('TWO-PHASE COUNT', got[2], twp, len(jc))
        nonempty+= bool(bf); fewer+= len(jc)<twp
    print(f'random trials {TRIALS}, mismatches: {bad}, non-empty results: {nonempty}, trials with fewer candidates than Two-Phase: {fewer}, candidates with bound < TWU: {tighter}')
    for mu in range(100, 510, 10):
        pg.evaluate("m=>{const tr=buildTrace(DB,PROFIT,m);return tr.length}", mu)
    pg.reload(); pg.wait_for_timeout(3000)
    seen=[]
    while True:
        st=pg.evaluate("""[trace[cursor].kind, window.scrollY, document.getElementById('explain').offsetHeight,
            [...document.querySelectorAll('#code .ln.hl')].map(l=>+l.dataset.n), document.getElementById('explain').innerText.split('\\n').slice(1).join(' ')]""")
        seen.append(st)
        if pg.is_disabled('#btn-next'): break
        pg.click('#btn-next'); pg.wait_for_timeout(20)
    for i,s in enumerate(seen): print(i+1, s[0], s[3][:2], len(s[3]), s[4][:170])
    print('steps', len(seen), 'explain heights', set(s[2] for s in seen), 'scrollY', set(s[1] for s in seen))
    print('stats', pg.inner_text('.stats').replace('\n',' '))
    print('compare', pg.inner_text('#compare').replace('\n',' | '))
    print('loose', pg.inner_text('#loose-sum'))
    layouts = {'desk': walk(pg, 'desktop 1280')}
    # 每個門檻都從頭走到尾，不能有錯誤
    for mu in (100, 180, 330, 420, 500):
        pg.evaluate("m=>setMinUtil(m)", mu)
        while not pg.is_disabled('#btn-next'): pg.click('#btn-next')
    pg.evaluate("m=>setMinUtil(m)", 250); pg.wait_for_timeout(3000)
    if SHOT:
        while pg.evaluate("trace[cursor].kind")!='build': pg.click('#btn-next')
        pg.screenshot(path=SHOT+'/desk-build.png', full_page=True)
        while not pg.is_disabled('#btn-next'): pg.click('#btn-next')
        pg.click('.crow >> nth=0')
        pg.screenshot(path=SHOT+'/desk-end.png', full_page=True)
    for w in (375, 320):
        m=b.new_context(viewport={'width':w,'height':760}, device_scale_factor=2); m.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        mp=m.new_page(); mp.on('pageerror',lambda e: errs.append(str(e)))
        mp.goto(U); mp.wait_for_timeout(3000)
        layouts[w]=walk(mp, f'mobile {w}')
        if SHOT:
            if not mp.is_disabled('#btn-first'): mp.click('#btn-first')
            for _ in range(8): mp.click('#btn-next')
            mp.screenshot(path=SHOT+f'/m{w}-insert.png', full_page=True)
            while mp.evaluate("trace[cursor].kind")!='cpb': mp.click('#btn-next')
            mp.screenshot(path=SHOT+f'/m{w}-cpb.png', full_page=True)
            while not mp.is_disabled('#btn-next'): mp.click('#btn-next')
            mp.screenshot(path=SHOT+f'/m{w}-end.png', full_page=True)
    print('card layouts per walk (must all be 1):', layouts)
    print('errs', errs)
    b.close()
