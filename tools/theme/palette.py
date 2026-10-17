"""深色頁面上寫死的顏色 → 淺色（果汁龍樂園）要換成什麼顏色。

大部分顏色用規則換算（暗底變淺底、淺字變深字、紫色系換成果汁橘、青色系換成葉子綠），
規則算出來不好看的再寫進 EXPLICIT 直接指定。
"""
import colorsys
import re

# 直接指定（深色值 → 淺色值）
EXPLICIT = {
    # 程式碼語法顏色（淺色程式碼框用）
    '#c792ea': '#8b2fc9', '#82aaff': '#1f5fbf', '#f78c6c': '#c2410c',
    '#637777': '#6b7760', '#c3e88d': '#2b7a0b', '#ffcb6b': '#9a5b00',
    # 程式碼框、圖表底
    '#0a0a14': '#fbfdf6', '#0b0b17': '#fbfdf6', '#05050a': '#f6fbef',
    # 常見的淡灰字（說明文字）
    '#c6c6d6': '#3d4a33', '#e6e6f0': '#1d2b12', '#fff': '#1d2b12', '#ffffff': '#1d2b12',
    # 主色
    '#7c3aed': '#e08a00', '#06b6d4': '#3f8f12',
}

INK = (29, 43, 18)          # #1d2b12


def parse(c):
    c = c.strip().lower()
    if c.startswith('#'):
        h = c[1:]
        if len(h) == 3:
            h = ''.join(x * 2 for x in h)
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)), 1.0
    nums = [x.strip() for x in c[c.index('(') + 1:c.rindex(')')].split(',')]
    a = float(nums[3]) if len(nums) > 3 else 1.0
    return tuple(int(float(x)) for x in nums[:3]), a


def hexof(rgb):
    return '#' + ''.join(f'{max(0, min(255, round(v))):02x}' for v in rgb)


def remap_hue(h, s):
    """紫 → 果汁橘、青 → 葉子綠；其他（紅綠黃藍）保持原本的意思"""
    deg = h * 360
    if s > 0.25:
        if 240 <= deg <= 300:
            return 33 / 360
        if 175 <= deg <= 200:
            return 95 / 360
    return h


def light_rgb(rgb):
    r, g, b = (v / 255 for v in rgb)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if s < 0.25 or (l < 0.25 and s < 0.5):        # 灰階（帶一點紫），或很暗、不太飽和的底
        if l < 0.22:                               # 暗底 → 很淡的綠白
            nl, ns, nh = 1 - l * 0.55, 0.35, 95 / 360
        elif l < 0.5:                              # 邊框、次要線條 → 中間的灰綠
            nl, ns, nh = min(0.8, 1.08 - l * 1.25), 0.12, 95 / 360
        else:                                      # 淺字 → 深字
            nl, ns, nh = max(0.12, 1.02 - l), 0.2, 95 / 360
    else:
        nh = remap_hue(h, s)
        if l < 0.25:                               # 很暗的彩色底 → 很淡的同色底
            nl, ns = 0.93, min(s, 0.6)
        elif l >= 0.65:                            # 粉彩字（深底上的字）→ 深色字
            nl, ns = 0.28, min(1, s * 0.85)
        else:                                      # 一般彩色 → 稍微壓暗，淺底上才看得清楚
            nl, ns = min(l, 0.42), s
    return tuple(v * 255 for v in colorsys.hls_to_rgb(nh, nl, ns))


def light_of(color):
    rgb, a = parse(color)
    key = hexof(rgb)
    if a >= 1:
        if key in EXPLICIT:
            return EXPLICIT[key]
        if color.strip().lower() in EXPLICIT:
            return EXPLICIT[color.strip().lower()]
        return hexof(light_rgb(rgb))
    # 半透明（多半是淡淡的底色或光暈）
    r, g, b = (v / 255 for v in rgb)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if s < 0.2:
        if l > 0.5:                                # 深底上的白色薄膜 → 淺底上的墨色薄膜
            return f'rgba({INK[0]}, {INK[1]}, {INK[2]}, {min(1, round(a * 1.4, 3))})'
        return color
    nh = remap_hue(h, s)
    nrgb = tuple(v * 255 for v in colorsys.hls_to_rgb(nh, min(l, 0.5), s))
    return f'rgba({round(nrgb[0])}, {round(nrgb[1])}, {round(nrgb[2])}, {min(1, round(a * 1.35, 3))})'


def key_of(color):
    rgb, a = parse(color)
    k = hexof(rgb)[1:]
    if a < 1:
        k += f'-{round(a * 100):g}'.replace('.', '_')
    return '--lt-' + k


COLOR_RE = re.compile(r'#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b|rgba?\(\s*\d[^)]*\)')
