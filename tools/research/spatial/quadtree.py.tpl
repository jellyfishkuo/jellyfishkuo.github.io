"""點區域四元樹（point-region quadtree）：插入、切割、範圍查詢""" «hide»
 «hide»
MAX_DEPTH = 7       # 地圖 128×128，切 7 層格子就只剩 1×1，疊在一起的點不再切 «init»


class Point:
    def __init__(self, x, y, kind):
        self.x, self.y, self.kind = x, y, kind

    def __str__(self):
        return f"{self.kind}({self.x},{self.y})"


class Node:
    """一個節點管一塊正方形：x ≤ 點的 x < x+size，y 也一樣"""
    def __init__(self, x, y, size, depth):
        self.x, self.y, self.size, self.depth = x, y, size, depth
        self.points = []
        self.children = None            # None 代表葉子

    def intersects(self, q):            # q = (x1, y1, x2, y2)，含邊界
        x1, y1, x2, y2 = q
        return x1 < self.x + self.size and self.x <= x2 and y1 < self.y + self.size and self.y <= y2


def quadrant(node, p):
    """中線右邊 +1、下面 +2：0 左上、1 右上、2 左下、3 右下"""
    half = node.size // 2
    return (p.x >= node.x + half) + 2 * (p.y >= node.y + half)


class QuadTree:
    def __init__(self, capacity): «init{»
        self.capacity = capacity        # 每個葉子最多放幾個點
        self.root = Node(0, 0, 128, 0)
        self.visited = self.checked = 0 # 查詢時拜訪的節點數、檢查的點數 «}init»

    def insert(self, p, node=None):
        node = node or self.root «descend»
        while node.children:            # 已經切開的格子：看 p 在哪一塊，往下走 «descend»
            node = node.children[quadrant(node, p)] «descend»
        if len(node.points) < self.capacity or node.depth == MAX_DEPTH: «add»
            node.points.append(p)       # 還沒滿，直接放進去 «add»
            return «add»
        self.split(node)                # 滿了：切成四塊 «split»
        self.insert(p, node)            # 再從這格往下走一次 «split»

    def split(self, node): «split{»
        half = node.size // 2
        node.children = [Node(node.x + (i % 2) * half, node.y + (i // 2) * half, half, node.depth + 1)
                         for i in range(4)]
        for q in node.points:           # 原本的點依位置重新分到子格
            node.children[quadrant(node, q)].points.append(q)
        node.points = [] «}split»

    def range_query(self, q): «qstart{»
        self.visited = self.checked = 0
        out = []
        self._query(self.root, q, out)
        return out «}qstart,qend»

    def _query(self, node, q, out):
        self.visited += 1 «visit»
        if node.children is None:       # 葉子：一個一個檢查裡面的點 «leaf»
            x1, y1, x2, y2 = q «leaf»
            for p in node.points: «leaf»
                self.checked += 1 «leaf»
                if x1 <= p.x <= x2 and y1 <= p.y <= y2: «leaf»
                    out.append(p) «leaf»
            return «leaf»
        for c in node.children: «kids»
            if c.intersects(q):         # 沒交集的子格整塊跳過 «kids»
                self._query(c, q, out) «kids»
 «hide{»

POINTS = [
    (26, 54, "超商"), (38, 36, "超商"), (54, 74, "超商"), (84, 56, "超商"),
    (108, 76, "超商"), (60, 114, "超商"), (12, 96, "超商"), (90, 26, "超商"),
    (20, 60, "公車站"), (44, 30, "公車站"), (48, 68, "公車站"), (78, 62, "公車站"),
    (102, 68, "公車站"), (96, 22, "公車站"), (44, 102, "公車站"), (100, 106, "公車站"),
    (84, 14, "咖啡店"), (110, 36, "咖啡店"), (118, 12, "咖啡店"), (70, 40, "咖啡店"),
    (60, 62, "咖啡店"), (22, 104, "咖啡店"), (72, 110, "咖啡店"),
    (88, 42, "飲料店"), (112, 22, "飲料店"), (74, 30, "飲料店"), (26, 70, "飲料店"),
    (110, 62, "飲料店"), (40, 42, "飲料店"), (16, 18, "飲料店"), (62, 64, "飲料店"),
]

if __name__ == "__main__":
    tree = QuadTree(2)
    for x, y, kind in POINTS:
        tree.insert(Point(x, y, kind))
    q = (64, 8, 120, 48)
    found = tree.range_query(q)
    print(f"插入 {len(POINTS)} 個點，容量 2")
    print(f"查詢框 ({q[0]},{q[1]})-({q[2]},{q[3]})")
    print(f"找到 {len(found)} 個點：" + " ".join(str(p) for p in found))
    print(f"拜訪 {tree.visited} 個節點，檢查 {tree.checked} 個點（全部掃一遍要 {len(POINTS)} 個）") «}hide»
