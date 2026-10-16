"""IR-tree：R-tree 的每個節點多掛一份倒排表，找「最近、而且賣齊這些商品」的 k 家店""" «hide»
import heapq «hide»
import math «hide»
 «hide»


class Shop:
    def __init__(self, x, y, items):
        self.x, self.y = x, y
        self.items = frozenset(items)       # 這家店賣的商品（關鍵字）
        self.no = -1                        # 第幾家；距離一樣時編號小的排前面

    def __str__(self):
        return f"#{self.no + 1}({self.x},{self.y})"


class Node:
    def __init__(self, nid, leaf, entries): «inv{»
        self.id, self.leaf, self.entries = nid, leaf, entries   # 葉子放店家，內部節點放子節點
        self.mbr = bound(entries)           # 剛好包住所有子孫的框 (x1, y1, x2, y2)
        self.inv = {}                       # 倒排表：關鍵字 → 有這個關鍵字的子節點（店家）在 entries 的位置
        for i, e in enumerate(entries):
            for w in sorted(words_of(e)):
                self.inv.setdefault(w, []).append(i)
        self.words = set(self.inv)          # 整棵子樹出現過的關鍵字 «}inv»


def words_of(e):
    return e.items if isinstance(e, Shop) else e.words


def rect(e):
    return (e.x, e.y, e.x, e.y) if isinstance(e, Shop) else e.mbr


def bound(entries):
    r = rect(entries[0])
    for e in entries[1:]:
        s = rect(e)
        r = (min(r[0], s[0]), min(r[1], s[1]), max(r[2], s[2]), max(r[3], s[3]))
    return r


def mindist(q, r):
    """查詢點到框的最短距離（平方）；點在框裡就是 0"""
    dx = max(r[0] - q[0], 0, q[0] - r[2])
    dy = max(r[1] - q[1], 0, q[1] - r[3])
    return dx * dx + dy * dy


def dist2(q, s):
    return (s.x - q[0]) ** 2 + (s.y - q[1]) ** 2


class IRTree:
    def __init__(self, shops, M): «build{»
        self.M, self.next_id = M, 0
        for i, s in enumerate(shops):
            s.no = i
        level = self.pack(list(shops), True) if shops else []
        while len(level) > 1:               # 一層一層往上包，直到剩一個根
            level = self.pack(level, False)
        self.root = level[0] if level else None «}build»

    def pack(self, items, leaf): «build{»
        """STR 批次建樹：依 x 排序切成幾條直的，每條再依 y 排序、每 M 個裝成一個節點"""
        key = lambda e: (rect(e)[0] + rect(e)[2], rect(e)[1] + rect(e)[3], e.no if leaf else e.id)
        pages = math.ceil(len(items) / self.M)          # 這一層要幾個節點
        per = math.ceil(math.sqrt(pages)) * self.M      # 每一條放幾個
        items.sort(key=key)
        out = []
        for i in range(0, len(items), per):
            slab = sorted(items[i:i + per], key=lambda e: (key(e)[1], key(e)[0], key(e)[2]))
            for j in range(0, len(slab), self.M):
                out.append(Node(self.next_id, leaf, slab[j:j + self.M]))
                self.next_id += 1
        return out «}build»

    def search(self, q, words, k):
        """回傳 [(店家, 距離²)]，由近到遠；店家要有 words 裡的每一個關鍵字"""
        self.opened = self.checked = self.skipped = 0 «qstart{»
        out = []
        if self.root is None or not words <= self.root.words:
            return out                      # 整棵樹都湊不齊這些關鍵字
        heap = [(mindist(q, self.root.mbr), 0, self.root.id, self.root)]   # (距離², 0=框 1=店, 編號, 東西) «}qstart»
        while heap and len(out) < k:
            d, typ, _, e = heapq.heappop(heap)     # 取出佇列裡最近的 «pop»
            if typ == 1:                    # 是店家：剩下的都不會比它近，它就是下一個答案 «pop»
                out.append((e, d)) «pop»
                continue «pop»
            self.opened += 1                # 是框：打開它，先查倒排表 «open»
            ok = set(range(len(e.entries))) «kw{»
            for w in words:                 # 每個關鍵字的串列取交集：全部都有的才留下
                ok &= set(e.inv[w])
            self.skipped += len(e.entries) - len(ok)       # 缺關鍵字的整個跳過，連距離都不用算 «}kw»
            for i in sorted(ok): «push{»
                c = e.entries[i]
                if e.leaf:
                    self.checked += 1
                    heapq.heappush(heap, (dist2(q, c), 1, c.no, c))
                else:
                    heapq.heappush(heap, (mindist(q, c.mbr), 0, c.id, c)) «}push»
        return out «end»

    def nearest_then_filter(self, q, words, k): «cmp{»
        """做法一：當成普通 R-tree，由近到遠一家一家拿出來，再看關鍵字對不對"""
        self.opened = self.checked = 0
        out = []
        heap = [(mindist(q, self.root.mbr), 0, self.root.id, self.root)] if self.root else []
        while heap and len(out) < k:
            d, typ, _, e = heapq.heappop(heap)
            if typ == 1:
                if words <= e.items:
                    out.append((e, d))
                continue
            self.opened += 1
            for c in e.entries:
                if e.leaf:
                    self.checked += 1
                    heapq.heappush(heap, (dist2(q, c), 1, c.no, c))
                else:
                    heapq.heappush(heap, (mindist(q, c.mbr), 0, c.id, c))
        return out


def filter_then_sort(shops, q, words, k):
    """做法二：先用整份倒排表找出關鍵字都有的店，再全部算距離、排序"""
    index = {}                              # 關鍵字 → 店家編號（實際上會事先建好）
    for s in shops:
        for w in s.items:
            index.setdefault(w, set()).add(s.no)
    cand = set(range(len(shops)))
    for w in words:
        cand &= index.get(w, set())
    found = sorted((dist2(q, shops[i]), i) for i in cand)
    return [(shops[i], d) for d, i in found[:k]], len(cand) «}cmp»
 «hide{»


EMOJI = {"咖啡": "☕", "麵包": "🍞", "牛奶": "🥛", "飯糰": "🍙", "茶葉蛋": "🥚", "洋芋片": "🥔"}


def show(node, depth=0):
    head = "  " * depth + f"R{node.id} 關鍵字 {''.join(EMOJI[w] for w in sorted(node.words, key=list(EMOJI).index))}"
    if node.leaf:
        print(head + "：" + " ".join(f"{s}{''.join(EMOJI[w] for w in sorted(s.items, key=list(EMOJI).index))}" for s in node.entries))
    else:
        print(head)
        for c in node.entries:
            show(c, depth + 1)


SHOPS = [
/*SHOPS_PY*/
]

if __name__ == "__main__":
    shops = [Shop(x, y, items) for x, y, items in SHOPS]
    tree = IRTree(shops, 4)
    print(f"{len(shops)} 家店，M = {tree.M}，共 {tree.next_id} 個節點")
    show(tree.root)
    q, words, k = /*QUERY_PY*/
    print(f"查詢點 ({q[0]},{q[1]})，要有 {'、'.join(sorted(words, key=list(EMOJI).index))}，找最近的 {k} 家：")
    found = tree.search(q, words, k)
    for i, (s, d) in enumerate(found, 1):
        print(f"  {i}. {s} 距離 {math.sqrt(d):.2f}")
    print(f"IR-tree：打開 {tree.opened} 個節點，算了 {tree.checked} 家店的距離，關鍵字不符跳過 {tree.skipped} 項")
    same = lambda res: "一樣" if [s.no for s, _ in res] == [s.no for s, _ in found] else "不一樣"
    res = tree.nearest_then_filter(q, words, k)
    print(f"做法一 先找最近再檢查關鍵字：打開 {tree.opened} 個節點，算了 {tree.checked} 家店的距離，答案{same(res)}")
    res, n = filter_then_sort(shops, q, words, k)
    print(f"做法二 先查倒排表再全部排序：不用樹，算了 {n} 家店的距離，答案{same(res)}") «}hide»
