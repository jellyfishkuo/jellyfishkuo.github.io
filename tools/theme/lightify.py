"""幫頁面接上淺色版（果汁龍樂園）。

做三件事：
1. <head> 加 theme.js（決定深淺色、放切換鈕）與 theme.css（淺色的共用樣式）。
2. <style> 裡寫死的顏色（:root 以外）改成 var(--lt-xxxx, 原本的顏色)：
   深色時變數沒定義，照舊用原本的顏色；淺色時用 theme.css 裡算好的顏色。
   JS 裡的顏色不改程式，由 theme.js 在畫面上換成同樣的 var()，這裡只登記。
3. 把用到的顏色記進 colors.json，重寫 assets/theme.css 裡自動產生的那一段。

用法：python3 lightify.py --prefix ../ <檔案...>（.css 檔只換顏色）
      （prefix 是「產出的 HTML」到 repo 根目錄的相對路徑；可以重複執行）
"""
import argparse
import json
import os
import re

from palette import COLOR_RE, key_of, light_of

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
REGISTRY = os.path.join(HERE, 'colors.json')
THEME_CSS = os.path.join(ROOT, 'assets', 'theme.css')
BEGIN, END = '/* ==== 自動產生：tools/theme/lightify.py（不要手改這一段） ==== */', '/* ==== 自動產生結束 ==== */'
VAR_RE = re.compile(r'var\(--lt-[0-9a-f_-]+,\s*(?:#[0-9a-fA-F]+|rgba?\([^)]*\))\)')


def convert_css(css, used, root=False):
    out, pos = [], 0
    # :root { ... } 是頁面自己的變數，淺色值由 theme.css 用同名變數蓋掉，這裡不動
    skip = [] if root else [m.span() for m in re.finditer(r':root\s*\{[^}]*\}', css)]
    # 頁面自己寫的淺色規則已經是淺色的顏色，不要再換
    skip += [m.span() for m in re.finditer(r'\[data-theme="light"\][^{}]*\{[^}]*\}', css)]
    for m in VAR_RE.finditer(css):  # 之前換過的也要登記（重跑時 colors.json 才完整）
        c = COLOR_RE.search(m.group(0)).group(0)
        used.setdefault(key_of(c), c)
    keep = skip + [m.span() for m in VAR_RE.finditer(css)]
    keep.sort()

    def repl(seg):
        def one(m):
            c = m.group(0)
            k = key_of(c)
            used[k] = c
            return f'var({k}, {c})'
        return COLOR_RE.sub(one, seg)

    for a, b in keep:
        if a < pos:
            continue
        out.append(repl(css[pos:a]))
        out.append(css[a:b])
        pos = b
    out.append(repl(css[pos:]))
    return ''.join(out)


def process(path, prefix, used, root=False):
    s = open(path, encoding='utf-8').read()
    orig = s
    if path.endswith('.js'):  # JS 只登記顏色，畫面上由 theme.js 換
        for c in COLOR_RE.findall(s):
            try:
                used.setdefault(key_of(c), c)
            except ValueError:
                pass
        return
    if path.endswith('.css'):
        s = convert_css(s, used, root)
        if s != orig:
            open(path, 'w', encoding='utf-8').write(s)
            print('改了', os.path.relpath(path, ROOT))
        return
    # <style> 以外（JS 畫的 SVG、style="..."）的顏色由 theme.js 在畫面上換，這裡只登記
    for c in COLOR_RE.findall(re.sub(r'<style[^>]*>.*?</style>', '', s, flags=re.S)):
        try:
            used.setdefault(key_of(c), c)
        except ValueError:
            pass
    s = re.sub(r'(<style[^>]*>)(.*?)(</style>)', lambda m: m.group(1) + convert_css(m.group(2), used, root) + m.group(3), s, flags=re.S)
    if 'assets/theme.js' not in s:
        tag = f'<script src="{prefix}assets/theme.js"></script>\n    '
        at = re.search(r'<style|<link rel="stylesheet"|</head>', s)
        s = s[:at.start()] + tag + s[at.start():]
    if 'assets/theme.css' not in s:
        s = s.replace('</head>', f'    <link rel="stylesheet" href="{prefix}assets/theme.css">\n</head>', 1)
    if s != orig:
        open(path, 'w', encoding='utf-8').write(s)
        print('改了', os.path.relpath(path, ROOT))


def write_css(used):
    lines = [BEGIN, ':root[data-theme="light"] {']
    for k in sorted(used):
        lines.append(f'    {k}: {light_of(used[k])};')
    lines += ['}', END]
    block = '\n'.join(lines)
    css = open(THEME_CSS, encoding='utf-8').read()
    if BEGIN in css:
        css = css[:css.index(BEGIN)] + block + css[css.index(END) + len(END):]
    else:
        css = css.rstrip() + '\n\n' + block + '\n'
    open(THEME_CSS, 'w', encoding='utf-8').write(css)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--prefix', default='../')
    ap.add_argument('--root', action='store_true', help=':root 裡的變數也換（遊戲頁各有自己的變數名）')
    ap.add_argument('--css-only', action='store_true', help='只依 colors.json 重寫 theme.css')
    ap.add_argument('files', nargs='*')
    a = ap.parse_args()
    used = json.load(open(REGISTRY)) if os.path.exists(REGISTRY) else {}
    if not a.css_only:
        for f in a.files:
            process(f, a.prefix, used, a.root)
        json.dump(used, open(REGISTRY, 'w'), indent=1, sort_keys=True)
    write_css(used)


if __name__ == '__main__':
    main()
