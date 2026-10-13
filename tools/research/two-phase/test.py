import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import random, sys, itertools
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from two_phase import two_phase
from playwright.sync_api import sync_playwright
ITEMS=['咖啡','麵包','牛奶','飯糰','茶葉蛋','洋芋片']
U='http://127.0.0.1:8796/research/two-phase.html'
SHOT = sys.argv[1] if len(sys.argv) > 1 else None   # 截圖資料夾（不要放在 repo 裡）
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
    bad=0; nonempty=0; loose=0
    for trial in range(400):
        rows=random.randint(1,10)
        db=[{i:random.randint(1,5) for i in random.sample(ITEMS, random.randint(1,6))} for _ in range(rows)]
        profit={i:random.randint(1,40) for i in ITEMS}
        total=sum(t[i]*profit[i] for t in db for i in t)
        mu=random.randint(1,max(1,total))
        py={frozenset(k):v for k,v in two_phase(db,profit,mu).items()}
        bf=brute(db,profit,mu)
        got=pg.evaluate("([d,p,m])=>{const tr=buildTrace(d,p,m);const e=tr[tr.length-1];return [e.result.map(r=>[r.set,r.util]), e.cands.map(c=>[c.set,c.twu,c.util])]}", [db,profit,mu])
        js={frozenset(s):u for s,u in got[0]}
        cands={frozenset(s) for s,_,_ in got[1]}
        # 候選的 TWU、效益都要對；候選一定包含所有高效益樣式
        for s,tw,u in got[1]:
            ts=[t for t in db if all(i in t for i in s)]
            if tw!=sum(sum(t[i]*profit[i] for i in t) for t in ts) or u!=sum(sum(t[i]*profit[i] for i in s) for t in ts) or tw<mu: bad+=1
        if len(got[0])!=len(js) or len(cands)!=len(got[1]): bad+=1
        if not set(bf)<=cands: bad+=1; print('CANDS MISS', db, profit, mu)
        if not (js==py==bf): bad+=1; print('MISMATCH',db,profit,mu,js,py,bf); break
        nonempty+= bool(bf); loose+= len(cands)>len(bf)
    print('random trials 400, mismatches:', bad, 'non-empty results:', nonempty, 'trials with loose candidates:', loose)
    for mu in range(100, 510, 10):
        pg.evaluate("m=>{const tr=buildTrace(DB,PROFIT,m);return tr.length}", mu)
    pg.reload(); pg.wait_for_timeout(400)
    seen=[]
    while True:
        st=pg.evaluate("""[trace[cursor].kind, window.scrollY, document.getElementById('explain').offsetHeight,
            [...document.querySelectorAll('#code .ln.hl')].map(l=>+l.dataset.n), document.getElementById('explain').innerText.split('\\n').slice(1).join(' ')]""")
        seen.append(st)
        if pg.is_disabled('#btn-next'): break
        pg.click('#btn-next'); pg.wait_for_timeout(20)
    for i,s in enumerate(seen): print(i+1, s[0], s[3][:2], len(s[3]), s[4][:160])
    print('steps', len(seen), 'explain heights', set(s[2] for s in seen), 'scrollY', set(s[1] for s in seen))
    print('stats', pg.inner_text('.stats').replace('\n',' '))
    print('compare', pg.inner_text('#compare').replace('\n',' | '))
    print('loose', pg.inner_text('#loose-sum'))
    # 每個門檻都從頭走到尾，不能有錯誤
    for mu in (100, 180, 330, 420, 500):
        pg.evaluate("m=>setMinUtil(m)", mu)
        while not pg.is_disabled('#btn-next'): pg.click('#btn-next')
    if SHOT:
        pg.evaluate("m=>setMinUtil(m)", 250)
        for _ in range(9): pg.click('#btn-next')
        pg.click('.cand >> nth=0')
        pg.screenshot(path=SHOT+'/desk-mid.png', full_page=True)
        while not pg.is_disabled('#btn-next'): pg.click('#btn-next')
        pg.screenshot(path=SHOT+'/desk-end.png', full_page=True)
    for w in (375, 320):
        m=b.new_context(viewport={'width':w,'height':760}, device_scale_factor=2); m.route("**/fonts.googleapis.com/**", lambda r: r.abort())
        mp=m.new_page(); mp.on('pageerror',lambda e: errs.append(str(e)))
        mp.goto(U); mp.wait_for_timeout(400)
        widths=set(); hs=set()
        while True:
            widths.add(mp.evaluate("document.documentElement.scrollWidth")); hs.add(mp.evaluate("document.getElementById('explain').offsetHeight"))
            if mp.is_disabled('#btn-next'): break
            mp.click('#btn-next')
            if SHOT and mp.evaluate("trace[cursor].kind")=='prune' and not os.path.exists(SHOT+f'/m{w}-prune.png'):
                mp.click('.cand.out >> nth=0') if mp.locator('.cand.out').count() else None
                mp.screenshot(path=SHOT+f'/m{w}-prune.png', full_page=True)
        print('mobile', w, 'scrollWidth', widths, 'explain heights', hs)
        if SHOT: mp.screenshot(path=SHOT+f'/m{w}-end.png', full_page=True)
    print('errs', errs)
    b.close()
