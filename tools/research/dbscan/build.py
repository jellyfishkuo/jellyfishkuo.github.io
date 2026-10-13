"""從 .tpl 產生：乾淨的原始碼檔（給人下載執行）與帶標記的 JSON（給網頁高亮用）
用法：python3 build.py <repo>/research/code"""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # repo 根目錄
import json, os, re, sys
MARK = re.compile(r'\s*«([^»]*)»\s*$')


def parse(path):
    clean, shown, region = [], [], []
    for raw in open(path, encoding='utf-8').read().split('\n'):
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
for src, dst, key in (('DBSCAN.java.tpl', 'DBSCAN.java', 'java'), ('dbscan.py.tpl', 'dbscan.py', 'py')):
    clean, shown = parse(src)
    open(os.path.join(sys.argv[1], dst), 'w', encoding='utf-8').write(clean)
    out[key] = shown
open('code.json', 'w', encoding='utf-8').write(json.dumps(out, ensure_ascii=False))
if os.path.exists('dbscan.html.tpl'):
    page = open('dbscan.html.tpl', encoding='utf-8').read()
    page = page.replace('/*CODE_JSON*/null', json.dumps(out, ensure_ascii=False))
    open(os.path.join(sys.argv[1], '..', 'dbscan.html'), 'w', encoding='utf-8').write(page)
    print('page built')
print({k: len(v) for k, v in out.items()})
