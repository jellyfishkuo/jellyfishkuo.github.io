import time, sys
from harness import *
SETS = """(want) => { if (document.querySelector('#board .card.correct, #board .card.taken')) return []; const c=[...document.querySelectorAll('#board .card:not(.empty)')].map(e=>e.dataset);
  const ok=(a,b,d)=>new Set([a,b,d]).size!==2; const out=[];
  for(let i=0;i<c.length;i++)for(let j=i+1;j<c.length;j++)for(let k=j+1;k<c.length;k++)
   if(['count','color','shape','shading'].every(x=>ok(c[i][x],c[j][x],c[k][x]))===want) out.push([c[i].uid,c[j].uid,c[k].uid]);
  return out;}"""
toast = lambda pg: pg.inner_text("#game-toast") if 'show' in (pg.get_attribute("#game-toast","class") or '') else '(none)'
banner = lambda pg: pg.inner_text("#action-banner-text") if pg.is_visible("#action-banner") else "(no banner)"
JSCLICK="(u)=>u.forEach(x=>document.querySelector(`#board .card[data-uid='${x}']`).click())"
alert_on = lambda pg: 'show' in (pg.get_attribute("#custom-alert","class") or '')
def play_to_end(h,g,limit=60):
    pages=[h,g]; t=0
    for _ in range(limit):
        if alert_on(g) and alert_on(h): return True
        pg=pages[t%2]; t+=1
        s=pg.evaluate(SETS, True)
        if s: pg.evaluate(JSCLICK, s[0])
        elif pg.is_visible('#btn-deal') and not pg.evaluate("document.getElementById('btn-deal').disabled"): pg.evaluate("document.getElementById('btn-deal').click()")
        time.sleep(0.8)
    return False
