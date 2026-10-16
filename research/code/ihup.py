"""IHUP：增量高效益樣式探勘。IHUP_L-Tree 照固定的字典序插入交易、節點記 TWU；新交易直接插、不用重建，要結果時才挖"""

# 字典序：論文裡商品編號 a、b、c… 照字母排；這裡照貨架順序編號，之後永遠不變
ORDER = ["咖啡", "麵包", "牛奶", "飯糰", "茶葉蛋", "洋芋片"]


def rank(item):
    """排序用：照 ORDER 的位置；不在清單裡的商品排最後、照字碼"""
    return (ORDER.index(item), "") if item in ORDER else (len(ORDER), item)


class Node:
    def __init__(self, item, parent):
        self.item = item
        self.parent = parent
        self.count = 0                             # 經過這個節點的交易筆數
        self.twu = 0                               # 經過這個節點的交易，TU 加起來
        self.children = {}


class IHUPTree:
    def __init__(self, profit):
        self.profit = profit
        self.root = Node(None, None)
        self.header = {}                           # 商品 → 樹上所有這個商品的節點（節點鏈）
        self.db = []                               # 交易也留著，第二階段驗證要用
        self.nodes = 0

    def add(self, t):
        """插入一筆交易（商品 → 數量）：算出 TU，照字典序沿路徑走，路徑上每個節點的 TWU 加上 TU"""
        self.db.append(t)
        tu = sum(q * self.profit[i] for i, q in t.items())   # 這筆交易的總效益
        node = self.root
        for item in sorted(t, key=rank):           # 順序固定，跟目前的 TWU 無關
            if item not in node.children:          # 沒有共用的前綴，長出新節點
                child = Node(item, node)
                node.children[item] = child
                self.header.setdefault(item, []).append(child)
                self.nodes += 1
            node = node.children[item]
            node.count += 1
            node.twu += tu                         # 只有這條路徑上的節點會變

    def mine(self, min_util):
        """要結果時才挖：第一階段在樹上找 TWU 夠的候選，第二階段掃一次資料庫算真正的效益"""
        cands = {}                                 # 候選 → 它的 TWU
        for item in sorted(self.header, key=rank, reverse=True):   # 從字典序最後面開始
            twu = sum(n.twu for n in self.header[item])   # 節點鏈上的 TWU 加起來
            if twu < min_util:
                continue                           # TWU 不夠：含它的組合都不可能夠，跳過
            cands[(item,)] = twu
            base = [(prefix_path(n), n.twu) for n in self.header[item]]   # 條件模式基底
            grow([b for b in base if b[0]], min_util, (item,), cands)   # 之後跟 FP-Growth 一樣
        util = {c: 0 for c in cands}               # 第二階段：再掃一次資料庫
        for t in self.db:
            for c in cands:
                if all(i in t for i in c):
                    util[c] += sum(t[i] * self.profit[i] for i in c)   # 只加組合裡那幾樣
        return {c: u for c, u in util.items() if u >= min_util}


def grow(base, min_util, suffix, cands):
    """跟 FP-Growth 一樣：數條件模式基底裡的 TWU、建條件樹、遞迴；只是「次數」換成 TWU"""
    twu = {}
    for path, u in base:
        for item in path:
            twu[item] = twu.get(item, 0) + u
    order = sorted((i for i in twu if twu[i] >= min_util), key=rank)   # 條件樹也照字典序

    root = Node(None, None)
    header = {i: [] for i in order}
    for path, u in base:
        insert_path(root, [i for i in path if i in header], u, header)

    for item in reversed(order):
        pattern = (item,) + suffix
        cands[pattern] = twu[item]                 # TWU 夠：記成候選
        sub = [(prefix_path(n), n.twu) for n in header[item]]
        grow([b for b in sub if b[0]], min_util, pattern, cands)   # 遞迴


def insert_path(root, path, u, header):
    node = root
    for item in path:
        if item not in node.children:
            child = Node(item, node)
            node.children[item] = child
            header[item].append(child)
        node = node.children[item]
        node.twu += u


def prefix_path(node):
    """從某個節點往上走到根，經過的商品就是它的前綴路徑"""
    path = []
    node = node.parent
    while node.item is not None:
        path.append(node.item)
        node = node.parent
    return path[::-1]


def show(result):
    for items, u in result.items():
        print("{" + ", ".join(items) + "} 效益 =", u)


if __name__ == "__main__":
    profit = {"咖啡": 30, "麵包": 15, "牛奶": 20, "飯糰": 10, "茶葉蛋": 5, "洋芋片": 25}
    db = [                                         # 每筆交易：商品 -> 購買數量
        {"咖啡": 4, "麵包": 2, "牛奶": 2},
        {"咖啡": 3, "麵包": 5, "茶葉蛋": 4},
        {"咖啡": 1, "麵包": 1, "牛奶": 2, "飯糰": 2},
        {"麵包": 3, "牛奶": 4, "洋芋片": 5},
        {"咖啡": 3, "牛奶": 2, "茶葉蛋": 2},
        {"咖啡": 1, "麵包": 2, "牛奶": 1, "茶葉蛋": 1},
        {"飯糰": 1, "茶葉蛋": 2, "洋芋片": 2},
        {"咖啡": 1, "麵包": 2, "飯糰": 1},
    ]
    tree = IHUPTree(profit)
    for t in db:
        tree.add(t)
    print("初始 8 筆，IHUP_L-Tree 節點數", tree.nodes)
    show(tree.mine(250))

    new_rows = [{"洋芋片": 3, "飯糰": 2}, {"茶葉蛋": 2, "洋芋片": 2, "飯糰": 1},
                {"牛奶": 1, "飯糰": 3}, {"洋芋片": 4, "飯糰": 1, "咖啡": 2}]
    for t in new_rows:
        tree.add(t)                                # 直接插，不用重排、不用重建
    print("再加 4 筆新交易，IHUP_L-Tree 節點數", tree.nodes)
    show(tree.mine(250))
