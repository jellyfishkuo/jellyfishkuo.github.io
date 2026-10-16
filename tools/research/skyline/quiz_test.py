"""練習模式：用隨機資料檢查每一題的正確答案，跟 Python 自己照 BNL／SFS 跑一次（加暴力法）的結果一致。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）"""
import os, random, sys
from playwright.sync_api import sync_playwright
U = 'http://127.0.0.1:%s/research/skyline.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 100
GET = """([V, w]) => { pts = V.map((v, i) => ({ label: '店' + i, x: v[0], y: v[1] })); winSize = w; rebuild();
    const out = [];
    [traces.bnl, traces.sfs].forEach(tr => tr.forEach((s, i) => { const q = skylineQuiz(s, i, tr); if (q) out.push({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask }); }));
    return out; }"""
dom = lambda a, b: all(x <= y for x, y in zip(a, b)) and a != b


def run(V, w, sfs):
    """照頁面說的規則跑：回傳 {(輪, 位置): (結果, 踢掉的)}、{輪: 這輪結束可以確定的}"""
    reads, confirm = {}, {}
    data = sorted(range(len(V)), key=lambda i: sum(V[i])) if sfs else list(range(len(V)))
    win, ps = [], 0                    # win：[點, 進視窗時暫存檔有幾筆, 是不是上一輪留下的]
    while data:
        ps += 1
        temp = []
        if sfs: win = []
        for pos, p in enumerate(data):
            if any(dom(V[e[0]], V[p]) for e in win): res, kick = 'drop', []
            else:
                kick = [e[0] for e in win if dom(V[p], V[e[0]])]
                win = [e for e in win if e[0] not in kick]
                if len(win) < w: res = 'insert'; win.append([p, len(temp), False])
                else: res = 'temp'; temp.append(p)
            reads[(ps, pos)] = (res, kick)
            if not sfs: win = [e for e in win if not (e[2] and e[1] <= pos + 1)]
        if not sfs:
            confirm[ps] = {e[0] for e in win if e[1] == 0}
            win = [[e[0], e[1], True] for e in win if e[1] != 0]
        data = temp
    return reads, confirm


OUT = {'被視窗裡的點支配，丟掉': 'drop', '放進視窗': 'insert', '放進視窗，馬上確定是 skyline': 'insert', '視窗滿了，寫到暫存檔': 'temp'}
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_timeout(300)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        n = random.randint(1, 25)
        V = [(random.randint(0, 12) * 10 * (1 + trial % 3), random.randint(0, 12) * 10 * (1 + trial % 3)) for _ in range(n)]
        w = random.choice([1, 2, 3, 4, 6, 8])
        sim = {'bnl': run(V, w, False), 'sfs': run(V, w, True)}
        sky = [i for i in range(n) if not any(dom(V[j], V[i]) for j in range(n))]
        name = lambda i: f'#{i + 1} 店{i}'
        for q in pg.evaluate(GET, [V, w]):
            if q['ask'].get('only'):
                if q['choices'] != ['會', '不會']: bad += 1
                q = {**q, 'choices': q['ask']['only'], 'answer': [0] if q['answer'] == 0 else [], 'multi': True}
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = bool((len(ch) >= 2 or ask.get('only')) and len(set(ch)) == len(ch) and len(ch) <= 4)
            if t == 'outcome': ok &= OUT[ch[a]] == sim[ask['which']][0][(ask['pass'], ask['pos'])][0]
            elif t == 'kick':
                kick = sim['bnl'][0][(ask['pass'], ask['pos'])][1]
                ok &= (int(ch[a]) == len(kick)) if not q['multi'] else {ch[k] for k in a} == {name(i) for i in kick}
            elif t == 'confirm':
                c = sim['bnl'][1][ask['pass']]
                ok &= (int(ch[a]) == len(c)) if not q['multi'] else {ch[k] for k in a} == {name(i) for i in c}
            elif t == 'first':
                f = min(range(n), key=lambda i: (sum(V[i]), i)); ok &= ch[a].startswith(name(f) + '（')
            elif t == 'count': ok &= int(ch[a]) == len(sky)
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', V, w, q)
    print(f'skyline 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    b.close()
