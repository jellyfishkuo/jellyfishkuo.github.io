"""練習模式：用隨機操作檢查每一題的正確答案，跟 Python 版（research/code/bloom_filter.py）算的一致。
需要本機伺服器：cd <repo> && python3 -m http.server 8770（或設環境變數 PORT）"""
import os, random, sys
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))
sys.dont_write_bytecode = True
sys.path.insert(0, REPO + '/research/code')
from bloom_filter import BloomFilter
from playwright.sync_api import sync_playwright
U = 'http://127.0.0.1:%s/research/bloom-filter.html' % os.environ.get('PORT', '8770')
TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 100
GET = """([o, m, k, c]) => { ops = o; const tr = bfTrace(o, m, k, c);
    return tr.map((s, i) => quizFor(s, i)).filter(Boolean).map(q => ({ q: q.q, choices: q.choices, answer: q.answer, multi: !!q.multi, ask: q.ask })); }"""
key = lambda: random.choice('ABGPQTY') + random.choice('PRY') + '-%08d' % random.randrange(10 ** 8)
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(); ctx.route("**/fonts.googleapis.com/**", lambda r: r.abort())
    pg = ctx.new_page(); errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto(U); pg.wait_for_function('() => !blocksBusy', timeout=60000)
    bad, kinds = 0, {}
    for trial in range(TRIALS):
        pool = [key() for _ in range(random.randint(3, 15))]
        ops = [{'op': random.choice(['add', 'add', 'query', 'del']), 'key': random.choice(pool)} for _ in range(random.randint(3, 30))]
        m, k, cnt = random.randrange(8, 65, 4), random.randint(1, 8), random.random() < 0.5
        def run(upto):                     # 做完 ops[0..upto) 的 Bloom Filter 與真正的集合
            bf, have = BloomFilter(m, k, cnt), {}
            for o in ops[:upto]:
                if o['op'] == 'add': bf.add(o['key']); have[o['key']] = have.get(o['key'], 0) + 1
                elif o['op'] == 'del' and cnt and have.get(o['key'], 0) > 0: bf.remove(o['key']); have[o['key']] -= 1
            return bf, {x for x, c in have.items() if c > 0}
        for q in pg.evaluate(GET, [ops, m, k, cnt]):
            a, ch, ask = q['answer'], q['choices'], q['ask']
            t = ask['type']; kinds[t] = kinds.get(t, 0) + 1
            ok = len(ch) >= 2 and len(set(ch)) == len(ch)
            if t == 'ones': ok &= int(ch[a]) == sum(1 for c in run(ask['oi'] + 1)[0].cells if c)
            elif t == 'query':
                bf, have = run(ask['oi'])
                ok &= ch[a] == ('一定不在' if not bf.might_contain(ask['key']) else '可能在（真的登錄過）' if ask['key'] in have else '可能在（其實沒登錄過＝誤判）')
            elif t == 'del': ok &= ch[a] == ('可能在' if run(ask['oi'] + 1)[0].might_contain(ask['key']) else '一定不在') and cnt
            elif t == 'nodel': ok &= ch[a].startswith('什麼都不做') and not cnt
            else: ok = False
            if not ok:
                bad += 1
                if bad < 5: print('MISMATCH', ops, m, k, cnt, q)
    print(f'bloom-filter 隨機 {TRIALS} 組，題目 {sum(kinds.values())} 題 {kinds}，答案不一致 {bad}，pageerror {errs}')
    b.close()
