"""R-tree：一個點一個點插入（Quadratic Split），再用 best-first search 找最近的 k 個點"""
import heapq
import math



class Point:
    def __init__(self, x, y, kind):
        self.x, self.y, self.kind = x, y, kind
        self.no = -1                    # 第幾個插入的；距離一樣時編號小的排前面

    def __str__(self):
        return f"{self.kind}({self.x},{self.y})"


class Node:
    def __init__(self, nid, leaf):
        self.id, self.leaf = nid, leaf
        self.entries = []               # 葉子放點，內部節點放子節點
        self.mbr = None                 # 剛好包住所有子孫的框 (x1, y1, x2, y2)


def rect(e):
    return (e.x, e.y, e.x, e.y) if isinstance(e, Point) else e.mbr


def union(a, b):
    return (min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3]))


def area(r):
    return (r[2] - r[0]) * (r[3] - r[1])


def bound(entries):
    r = rect(entries[0])
    for e in entries[1:]:
        r = union(r, rect(e))
    return r


def mindist(q, r):
    """查詢點到框的最短距離（平方）；點在框裡就是 0"""
    dx = max(r[0] - q[0], 0, q[0] - r[2])
    dy = max(r[1] - q[1], 0, q[1] - r[3])
    return dx * dx + dy * dy


class RTree:
    def __init__(self, M):
        self.M = M                      # 一個節點最多放幾個東西
        self.m = M // 2                 # 分裂後每個節點至少幾個
        self.next_id = 0
        self.count = 0
        self.root = self.new_node(True)

    def new_node(self, leaf):
        n = Node(self.next_id, leaf)
        self.next_id += 1
        return n

    def insert(self, p):
        p.no = self.count
        self.count += 1
        path = [self.root]
        while not path[-1].leaf:        # ChooseLeaf：一路往下，選「要擴大最少」的子框
            path.append(self.choose(path[-1], rect(p)))
        path[-1].entries.append(p)
        for i in range(len(path) - 1, -1, -1):          # 由下往上調整
            n = path[i]
            if len(n.entries) > self.M:                 # 超過 M 個：分裂
                new = self.split(n)
                if i > 0:
                    path[i - 1].entries.append(new)     # 新節點交給父節點，父節點可能也跟著滿
                else:
                    old = self.root
                    self.root = self.new_node(False)    # 根分裂：長出新的根，樹長高一層
                    self.root.entries = [old, new]
                    self.root.mbr = bound(self.root.entries)
            n.mbr = bound(n.entries)                    # 框擴大到包住新東西

    def choose(self, node, r):
        best = None
        for c in node.entries:
            key = (area(union(c.mbr, r)) - area(c.mbr), area(c.mbr))   # 先比擴大多少，再比面積
            if best is None or key < best[0]:
                best = (key, c)
        return best[1]

    def split(self, node):
        """Quadratic Split：把 M+1 個東西分成兩組"""
        E = node.entries
        seeds = None
        for i in range(len(E)):             # PickSeeds：挑「放同一組最浪費面積」的一對當種子
            for j in range(i + 1, len(E)):
                waste = area(union(rect(E[i]), rect(E[j]))) - area(rect(E[i])) - area(rect(E[j]))
                if seeds is None or waste > seeds[0]:
                    seeds = (waste, i, j)
        _, i, j = seeds
        g1, g2 = [E[i]], [E[j]]
        b1, b2 = rect(E[i]), rect(E[j])
        rest = [e for t, e in enumerate(E) if t != i and t != j]
        while rest:
            if len(g1) + len(rest) == self.m:   # 剩下的全給它，才湊得到 m 個
                g1 += rest
                break
            if len(g2) + len(rest) == self.m:
                g2 += rest
                break
            pick = None
            for t, e in enumerate(rest):        # PickNext：兩組擴大量差最多的（最有偏好的）先分
                d1 = area(union(b1, rect(e))) - area(b1)
                d2 = area(union(b2, rect(e))) - area(b2)
                if pick is None or abs(d1 - d2) > pick[0]:
                    pick = (abs(d1 - d2), t, d1, d2)
            _, t, d1, d2 = pick
            e = rest.pop(t)
            if (d1, area(b1), len(g1)) <= (d2, area(b2), len(g2)):   # 擴大少的 → 面積小的 → 東西少的
                g1.append(e)
                b1 = union(b1, rect(e))
            else:
                g2.append(e)
                b2 = union(b2, rect(e))
        node.entries = g1
        new = self.new_node(node.leaf)
        new.entries = g2
        node.mbr, new.mbr = bound(g1), bound(g2)
        return new

    def knn(self, q, k):
        """best-first search：回傳 [(點, 距離²)]，由近到遠"""
        self.opened = self.checked = self.pruned = 0
        out = []
        if self.root.mbr is None or k <= 0:
            return out
        heap = [(mindist(q, self.root.mbr), 0, self.root.id, self.root)]   # (距離², 0=框 1=點, 編號, 東西)
        best = []                       # 看過最近的 k 個點的距離²（存負數，當 max-heap 用）
        while heap and len(out) < k:
            d, typ, _, e = heapq.heappop(heap)     # 取出佇列裡最近的
            if typ == 1:                # 是點：剩下的都不會比它近，它就是下一個答案
                out.append((e, d))
                continue
            self.opened += 1            # 是框：打開它，子框算 MINDIST、點算真正的距離
            kids = []
            for c in e.entries:
                if e.leaf:
                    self.checked += 1
                    dd = (c.x - q[0]) ** 2 + (c.y - q[1]) ** 2
                    heapq.heappush(best, -dd)
                    if len(best) > k:
                        heapq.heappop(best)
                    kids.append((dd, 1, c.no, c))
                else:
                    kids.append((mindist(q, c.mbr), 0, c.id, c))
            dk = -best[0] if len(best) == k else math.inf   # 目前第 k 近的距離²
            for x in kids:
                if x[0] <= dk:
                    heapq.heappush(heap, x)
                else:
                    self.pruned += 1    # 比第 k 近還遠，不可能是答案：跳過
            keep = [x for x in heap if x[0] <= dk]          # 佇列裡太遠的也丟掉
            self.pruned += len(heap) - len(keep)
            heap = keep
            heapq.heapify(heap)
        return out



def fmt(r):
    return f"({r[0]},{r[1]})-({r[2]},{r[3]})"


def show(node, depth=0):
    head = "  " * depth + f"R{node.id} {fmt(node.mbr)}"
    if node.leaf:
        print(head + "：" + " ".join(str(p) for p in node.entries))
    else:
        print(head)
        for c in node.entries:
            show(c, depth + 1)


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
    tree = RTree(4)
    for x, y, kind in POINTS:
        tree.insert(Point(x, y, kind))
    print(f"插入 {len(POINTS)} 個點，M = {tree.M}、m = {tree.m}")
    show(tree.root)
    q, k = (70, 50), 3
    print(f"查詢點 ({q[0]},{q[1]})，找最近的 {k} 個：")
    for i, (p, d) in enumerate(tree.knn(q, k), 1):
        print(f"  {i}. {p} 距離 {math.sqrt(d):.2f}")
    print(f"打開 {tree.opened} 個框（樹上共 {tree.next_id} 個），算了 {tree.checked} 個點的距離（全部算要 {len(POINTS)} 個），剪掉 {tree.pruned} 項")
