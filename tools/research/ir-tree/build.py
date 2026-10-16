"""從 .tpl 產生：乾淨的原始碼檔（給人下載執行）與帶標記的 JSON（給網頁高亮用）
預設資料只寫在 data.py 一個地方，三份模板都從這裡填，網頁、Java、Python 才不會對不上。
用法：python3 -B build.py <repo>/research/code"""
import json, os, re, sys
sys.dont_write_bytecode = True
MARK = re.compile(r'\s*«([^»]*)»\s*$')
os.chdir(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, '.')
from data import SHOPS, QUERY

(qx, qy), qwords, qk = QUERY
FILL = {
    '/*SHOPS_PY*/': ',\n'.join(f'    ({x}, {y}, {json.dumps(it, ensure_ascii=False)})' for x, y, it in SHOPS) + ',',
    '/*QUERY_PY*/': f'({qx}, {qy}), {{{", ".join(json.dumps(w, ensure_ascii=False) for w in qwords)}}}, {qk}',
    '/*SHOPS_JAVA*/': ',\n'.join(f'        {{{x}, {y}, new String[]{{{", ".join(json.dumps(w, ensure_ascii=False) for w in it)}}}}}' for x, y, it in SHOPS) + ',',
    '/*QUERY_JAVA*/': f'        int qx = {qx}, qy = {qy}, k = {qk};\n        Set<String> words = Set.of({", ".join(json.dumps(w, ensure_ascii=False) for w in qwords)});',
}


def parse(path):
    src = open(path, encoding='utf-8').read()
    for k, v in FILL.items():
        # 填進去的每一行都要留在 hide 區塊裡：把多行內容接在同一個標記行後面
        src = src.replace(k, v)
    clean, shown, region = [], [], []
    for raw in src.split('\n'):
        m = MARK.search(raw)
        text = raw[:m.start()] if m else raw
        tags = set(region)
        hide = 'hide' in region
        if m:
            for t in m.group(1).split(','):
                t = t.strip()
                if t.endswith('{'): region.append(t[:-1]); tags.add(t[:-1]); hide = hide or t[:-1] == 'hide'
                elif t.startswith('}'): tags.add(t[1:])
                elif t == 'hide': hide = True
                else: tags.add(t)
            for t in m.group(1).split(','):
                t = t.strip()
                if t.startswith('}') and t[1:] in region: region.remove(t[1:])
        clean.append(text.rstrip())
        if not hide: shown.append([text.rstrip(), sorted(tags - {'hide'})])
    while shown and not shown[0][0].strip(): shown.pop(0)
    while shown and not shown[-1][0].strip(): shown.pop()
    # 顯示時去掉共同縮排（Java 的方法在 class 裡多縮了一層）
    ind = min(len(l) - len(l.lstrip()) for l, _ in shown if l.strip())
    shown = [[l[ind:] if l.strip() else '', t] for l, t in shown]
    return '\n'.join(clean).rstrip() + '\n', shown


out = {}
for src, dst, key in (('IRTree.java.tpl', 'IRTree.java', 'java'), ('ir_tree.py.tpl', 'ir_tree.py', 'py')):
    clean, shown = parse(src)
    open(os.path.join(sys.argv[1], dst), 'w', encoding='utf-8').write(clean)
    out[key] = shown
open('code.json', 'w', encoding='utf-8').write(json.dumps(out, ensure_ascii=False))
if os.path.exists('ir-tree.html.tpl'):
    page = open('ir-tree.html.tpl', encoding='utf-8').read()
    page = page.replace('/*CODE_JSON*/null', json.dumps(out, ensure_ascii=False))
    page = page.replace('/*DATA_JSON*/null', json.dumps({'shops': SHOPS, 'q': [qx, qy], 'words': qwords, 'k': qk}, ensure_ascii=False))
    open(os.path.join(sys.argv[1], '..', 'ir-tree.html'), 'w', encoding='utf-8').write(page)
    print('page built')
print({k: len(v) for k, v in out.items()})
