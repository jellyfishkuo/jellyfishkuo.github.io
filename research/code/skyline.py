"""Skyline 查詢：BNL（Block-Nested-Loops）與 SFS（Sort-Filter-Skyline）"""


class Point:
    """一家店：名字，以及每一維的值（這頁是價格、距離，都是越小越好）"""
    def __init__(self, name, *vals):
        self.name, self.vals = name, vals

    def __str__(self):
        return f"{self.name}({','.join(map(str, self.vals))})"


def dominates(p, q):
    """p 支配 q：每一維都 ≤ q（不比它差），而且至少一維 < q（真的比它好）。
    兩家完全一樣時誰也不支配誰，所以重複的點會一起留在 skyline 裡"""
    better = False
    for a, b in zip(p.vals, q.vals):
        if a > b:
            return False
        if a < b:
            better = True
    return better


class Entry:
    """視窗裡的一格：點，以及它進視窗時暫存檔已經寫了幾筆"""
    def __init__(self, p, written):
        self.p, self.written = p, written
        self.carried = False            # 上一輪留下來、還沒確定的點


def bnl(points, w):
    """BNL：視窗最多放 w 個點，放不下的寫到暫存檔、下一輪再讀"""
    skyline, comparisons, passes = [], 0, 0
    window, data = [], list(points)     # 第一輪的輸入就是全部的點
    while data:
        passes += 1
        temp = []                       # 暫存檔：視窗滿了放不下的點
        for i, p in enumerate(data):
            dominated = False
            for e in list(window):
                comparisons += 1
                if dominates(e.p, p):   # 被視窗裡的點支配：p 丟掉
                    dominated = True
                    break
                if dominates(p, e.p):   # p 支配視窗裡的點：把它踢出去
                    window.remove(e)
            if not dominated:
                if len(window) < w:
                    window.append(Entry(p, len(temp)))
                else:                   # 視窗滿了：先寫到暫存檔
                    temp.append(p)
            # 上一輪留下的點：暫存檔裡比它早寫的那幾筆都讀過了，就確定是 skyline
            for e in [e for e in window if e.carried and e.written <= i + 1]:
                skyline.append(e.p)
                window.remove(e)
        for e in list(window):          # 這一輪讀完了
            if e.written == 0:          # 進視窗時暫存檔還是空的：跟所有點都比過了
                skyline.append(e.p)
                window.remove(e)
            else:                       # 暫存檔裡有比它早寫的點還沒比：留到下一輪
                e.carried = True
        data = temp                     # 下一輪的輸入 = 這一輪的暫存檔
    return skyline, comparisons, passes



def score(p):
    """單調的分數：任何一維變小，分數就變小。支配別人的點分數一定比較小，所以會排在前面"""
    return sum(p.vals)


def sfs(points, w):
    """SFS：先照分數排好，之後進來的點不可能支配視窗裡的點，視窗只進不出"""
    skyline, comparisons, passes = [], 0, 0
    data = sorted(points, key=score)    # 分數由小到大（穩定排序：同分照原本的順序）
    while data:
        passes += 1
        window, temp = [], []
        for p in data:
            dominated = False
            for q in window:            # 只要看 p 有沒有被支配，不用踢人
                comparisons += 1
                if dominates(q, p):
                    dominated = True
                    break
            if not dominated:
                if len(window) < w:
                    window.append(p)    # 一進視窗就確定是 skyline，可以馬上輸出
                    skyline.append(p)
                else:
                    temp.append(p)      # 視窗滿了：寫到暫存檔（還是排好的順序）
        data = temp
    return skyline, comparisons, passes



SHOPS = [
    ("自助餐", 90, 120), ("咖哩飯", 130, 110), ("牛肉麵", 180, 60), ("便當", 100, 200),
    ("拉麵", 260, 40), ("滷肉飯", 60, 260), ("水餃", 80, 170), ("火鍋", 280, 180),
    ("義大利麵", 220, 150), ("早午餐", 160, 210), ("鍋燒意麵", 110, 170), ("炒飯", 120, 80),
    ("壽司", 250, 230), ("河粉", 150, 140), ("韓式拌飯", 170, 90), ("披薩", 230, 100),
    ("漢堡", 140, 250), ("泰式", 200, 190), ("清粥小菜", 70, 230), ("關東煮", 210, 30),
]


def show(title, result):
    sky, comps, passes = result
    print(f"{title}：skyline {len(sky)} 家，比較 {comps} 次，讀了 {passes} 輪")
    print("  " + " ".join(str(p) for p in sky))


if __name__ == "__main__":
    pts = [Point(*s) for s in SHOPS]
    print(f"{len(pts)} 家店（價格 元, 距離 公尺），視窗 3 格")
    show("BNL", bnl(pts, 3))
    show("SFS", sfs(pts, 3))
