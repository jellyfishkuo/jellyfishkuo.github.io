"""CanTree：商品照固定的標準順序插入，新交易進來直接插、不用重排；要挖的時候再用 FP-Growth 的方法挖"""

# 標準順序（canonical order）：事先定好、之後永遠不變，跟商品賣了幾次無關
ORDER = ["咖啡", "麵包", "牛奶", "飯糰", "茶葉蛋", "洋芋片"]


def rank(item):
    """排序用：照 ORDER 的位置；不在清單裡的商品排最後、照字碼"""
    return (ORDER.index(item), "") if item in ORDER else (len(ORDER), item)


class Node:
    def __init__(self, item, parent):
        self.item = item
        self.count = 0
        self.parent = parent
        self.children = {}


class CanTree:
    def __init__(self):
        self.root = Node(None, None)
        self.header = {}                           # 商品 → 樹上所有這個商品的節點（節點鏈）
        self.nodes = 0

    def add(self, transaction):
        """插入一筆交易：照標準順序排好，沿著共同的前綴往下走，沒有就長新節點"""
        node = self.root
        for item in sorted(transaction, key=rank):     # 順序固定，不看目前的次數
            if item not in node.children:              # 沒有共用的前綴，長出新節點
                child = Node(item, node)
                node.children[item] = child
                self.header.setdefault(item, []).append(child)
                self.nodes += 1
            node = node.children[item]
            node.count += 1                            # 只有路徑上的次數 +1，其他節點不動

    def mine(self, min_sup):
        """要挖的時候才用門檻：從標準順序最後面的商品開始，之後跟 FP-Growth 一樣"""
        result = {}
        for item in sorted(self.header, key=rank, reverse=True):
            sup = sum(n.count for n in self.header[item])   # 節點鏈上的次數加起來
            if sup < min_sup:
                continue                               # 不頻繁：跳過，但它還留在樹上
            result[(item,)] = sup
            base = []                                  # 條件模式基底
            for node in self.header[item]:
                path = prefix_path(node)
                if path:
                    base.append((path, node.count))
            fp_mine(base, min_sup, [item], result)     # 之後跟 FP-Growth 完全一樣
        return result


def fp_mine(db, min_sup, suffix, result):
    """FP-Growth：在條件模式基底上數次數、建條件 FP-tree、再遞迴"""
    count = {}
    for items, n in db:
        for item in items:
            count[item] = count.get(item, 0) + n
    order = [i for i in count if count[i] >= min_sup]   # 條件樹照「次數」排
    order.sort(key=lambda i: (-count[i], i))

    root = Node(None, None)
    header = {i: [] for i in order}
    for items, n in db:
        path = [i for i in order if i in items]
        insert_path(root, path, n, header)

    for item in reversed(order):
        pattern = [item] + suffix
        result[tuple(pattern)] = count[item]
        base = []
        for node in header[item]:
            path = prefix_path(node)
            if path:
                base.append((path, node.count))
        fp_mine(base, min_sup, pattern, result)        # 遞迴


def insert_path(root, path, n, header):
    node = root
    for item in path:
        if item not in node.children:
            child = Node(item, node)
            node.children[item] = child
            header[item].append(child)
        node = node.children[item]
        node.count += n


def prefix_path(node):
    """從某個節點往上走到根，經過的商品就是它的前綴路徑"""
    path = []
    node = node.parent
    while node.item is not None:
        path.append(node.item)
        node = node.parent
    return path[::-1]


def show(result):
    for pattern, sup in result.items():
        print("[" + ", ".join(pattern) + "]", sup)


if __name__ == "__main__":
    db = [
        {"咖啡", "麵包", "牛奶"},
        {"咖啡", "麵包", "茶葉蛋"},
        {"咖啡", "麵包", "牛奶", "飯糰"},
        {"麵包", "牛奶", "洋芋片"},
        {"咖啡", "牛奶", "茶葉蛋"},
        {"咖啡", "麵包", "牛奶", "茶葉蛋"},
        {"飯糰", "茶葉蛋", "洋芋片"},
        {"咖啡", "麵包", "飯糰"},
    ]
    tree = CanTree()
    for t in db:
        tree.add(t)
    print("初始 8 筆，CanTree 節點數", tree.nodes)
    show(tree.mine(3))

    new_rows = [{"飯糰", "洋芋片"}, {"茶葉蛋", "洋芋片", "飯糰"}, {"牛奶", "飯糰"}, {"洋芋片", "飯糰", "咖啡"}]
    for t in new_rows:
        tree.add(t)                                    # 直接插，不用重排、不用重建
    print("再加 4 筆新交易，CanTree 節點數", tree.nodes)
    show(tree.mine(3))
