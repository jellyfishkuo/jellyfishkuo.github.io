"""產生研究 Demo 圖示的淺色版（首頁淺色「研究實驗室」用）：assets/icons/<name>.svg → assets/icons/<name>-light.svg
只處理 research/ 底下有頁面的圖示。

深色底換成白底＋墨色粗框；深色的線、格子換成淺灰綠；原本在深底上當「白字」的顏色換成墨色；
鮮豔的顏色（黃、青、紫、紅…）保留，白底上一樣好看。可以重複執行。
用法：python3 icons_light.py
"""
import colorsys
import glob
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
ICONS = os.path.join(ROOT, 'assets', 'icons')
INK = '#1d2b12'


def norm(h):
    h = h.lower()[1:]
    if len(h) == 3:
        h = ''.join(c * 2 for c in h)
    return h


def light(hexcolor):
    h = norm(hexcolor)
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hh, l, s = colorsys.rgb_to_hls(r, g, b)
    if l < 0.2:                      # 很深的底色、格子 → 淺綠白
        return '#f3f8ec'
    if s < 0.3 or (l < 0.4 and s < 0.6):
        if l > 0.85:                 # 深底上的白字／白線 → 墨色
            return INK
        if l < 0.45:                 # 深灰的線、被剪掉的灰點 → 淺灰綠
            return '#c9d6bb'
        return '#8a9580'             # 中間的灰 → 灰綠
    return hexcolor                  # 鮮豔的顏色保留


def main():
    names = sorted(os.path.basename(p)[:-5] for p in glob.glob(os.path.join(ROOT, 'research', '*.html')))
    for name in names:
        path = os.path.join(ICONS, name + '.svg')
        if not os.path.exists(path):
            continue
        src = open(path, encoding='utf-8').read()
        out = path[:-4] + '-light.svg'
        # 外框先換好，避免下面的通用換色把白底又換成墨色
        head = re.sub(r'(<rect x="1" y="1" width="62" height="62" rx="13") fill="#[0-9a-fA-F]+" stroke="#[0-9a-fA-F]+" stroke-width="2"',
                      r'\1 fill="__BG__" stroke="__INK__" stroke-width="2.5"', src, count=1)
        body = re.sub(r'#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b(?![0-9a-fA-F])', lambda m: light(m.group(0)), head)
        body = body.replace('__BG__', '#ffffff').replace('__INK__', INK)
        open(out, 'w', encoding='utf-8').write(body)
    print('done')


if __name__ == '__main__':
    main()
