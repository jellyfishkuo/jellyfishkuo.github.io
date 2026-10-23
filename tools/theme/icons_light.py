"""產生研究 Demo 圖示的淺色版（首頁淺色「研究實驗室」用）：assets/icons/<name>.svg → assets/icons/<name>-light.svg
研究 Demo（research/ 底下有頁面的）用通用規則換色；作品圖示（PROJECTS）各自寫要換哪些顏色，
因為它們的底色、圖案都是遊戲本身的配色，用通用規則會換壞（例如 SET 的紫色變淡）。

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


# 作品圖示：外框統一換成白底＋墨色粗框，剩下逐一指定 (原字串, 新字串)
PROJECTS = {
    '1a2b': [('fill="#0b0b14"', f'fill="{INK}"'),
             ('rx="6" fill="#22c55e"/>', f'rx="6" fill="#22c55e" stroke="{INK}" stroke-width="2.5"/>'),
             ('rx="6" fill="#f59e0b"/>', f'rx="6" fill="#ffb02e" stroke="{INK}" stroke-width="2.5"/>')],
    'coc-card': [('stroke="#120e1c"', f'stroke="{INK}"'),
                 ('fill="#7c3aed" transform', f'fill="#7c3aed" stroke="{INK}" stroke-width="2.5" transform')],
    'dinner-wheel': [('<circle r="22" fill="#1e1e33"/>', f'<circle r="22" fill="{INK}"/>'),
                     ('<circle r="6" fill="#7c3aed" stroke="#fff"', '<circle r="6" fill="#ffffff" stroke="#ff4d3d"'),
                     ('Z" fill="#fff"/>', f'Z" fill="#ff4d3d" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>')],
    'electricity': [('stroke="#12121c"', f'stroke="{INK}"'),
                    ('fill="#06b6d4"', f'fill="#22d3ee" stroke="{INK}" stroke-width="2"'),
                    ('fill="#facc15"', 'fill="#ffb02e"')],
    'hanoi': [('fill="#4a4a6a"', 'fill="#8a9580"'),
              ('rx="3.5" fill="', f'rx="3.5" stroke="{INK}" stroke-width="1.8" fill="')],
    'infinite-tictactoe': [('stroke="#475569"', 'stroke="#c9d6bb"'),
                           ('stroke="#06b6d4"', 'stroke="#0891b2"'), ('stroke="#ec4899"', 'stroke="#db2777"')],
    'notes': [('fill="#f4f1ff"/>', f'fill="#fff8e6" stroke="{INK}" stroke-width="2"/>')],
    'pentomino': [('stroke="#0f172a"', f'stroke="{INK}"'),
                  ('rx="3" fill="#fbbf24"/>', f'rx="3" fill="#ffb02e" stroke="{INK}" stroke-width="2"/>')],
    'set': [],
    'vertical-gomoku': [('<g fill="#0b1636">', f'<g fill="#fff8e6" stroke="{INK}" stroke-width="1.8">'),
                        ('r="6.5" fill="#facc15"/>', f'r="6.5" fill="#22d3ee" stroke="{INK}" stroke-width="2"/>'),
                        ('r="6.5" fill="#ef4444"/>', f'r="6.5" fill="#f472b6" stroke="{INK}" stroke-width="2"/>')],
    'store-manager': [('fill="#1e1e33"', f'fill="#fff8e6" stroke="{INK}" stroke-width="2"'),
                      ('fill="#ef4444"/>', f'fill="#ff4d3d" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>'),
                      ('rx="1.5" fill="#22d3ee"/>', f'rx="1.5" fill="#22d3ee" stroke="{INK}" stroke-width="1.8"/>'),
                      ('rx="1.5" fill="#facc15"/>', f'rx="1.5" fill="#ffb02e" stroke="{INK}" stroke-width="1.8"/>'),
                      ('fill="#12121c"/>', f'fill="{INK}"/>')],
    'zip': [('stroke="#2a2a40"', 'stroke="#c9d6bb"'), ('stroke="#22d3ee"', 'stroke="#ffb02e"'),
            ('r="5" fill="#ffffff"/>', f'r="5" fill="{INK}"/>'),
            ('r="5" fill="#facc15"/>', f'r="5" fill="#ff4d3d" stroke="{INK}" stroke-width="2"/>')],
}
# 立式五子棋的底板本身就是棋盤：淺色用遊戲淺色版的橘色棋盤
PROJECT_BG = {'vertical-gomoku': '#ffb02e'}


def project_icon(name):
    path = os.path.join(ICONS, name + '.svg')
    src = open(path, encoding='utf-8').read()
    bg = PROJECT_BG.get(name, '#ffffff')
    out = re.sub(r'<rect [^>]*/>', f'<rect x="1.25" y="1.25" width="61.5" height="61.5" rx="13" fill="{bg}" stroke="{INK}" stroke-width="2.5"/>', src, count=1)
    for old, new in PROJECTS[name]:
        assert old in out, (name, old)
        out = out.replace(old, new)
    open(path[:-4] + '-light.svg', 'w', encoding='utf-8').write(out)


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
    for name in PROJECTS:
        project_icon(name)
    print('done')


if __name__ == '__main__':
    main()
