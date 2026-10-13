"""CanTree：商品照固定的標準順序插入，新交易進來直接插、不用重排；要挖的時候再用 FP-Growth 的方法挖""" «hide»
 «hide»
# 標準順序（canonical order）：事先定好、之後永遠不變，跟商品賣了幾次無關 «order»
ORDER = ["咖啡", "麵包", "牛奶", "飯糰", "茶葉蛋", "洋芋片"] «order»


def rank(item): «order»
    """排序用：照 ORDER 的位置；不在清單裡的商品排最後、照字碼""" «order»
    return (ORDER.index(item), "") if item in ORDER else (len(ORDER), item) «order»


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

    def add(self, transaction): «insert{»
        """插入一筆交易：照標準順序排好，沿著共同的前綴往下走，沒有就長新節點"""
        node = self.root
        for item in sorted(transaction, key=rank):     # 順序固定，不看目前的次數
            if item not in node.children:              # 沒有共用的前綴，長出新節點
                child = Node(item, node)
                node.children[item] = child
                self.header.setdefault(item, []).append(child)
                self.nodes += 1
            node = node.children[item]
            node.count += 1                            # 只有路徑上的次數 +1，其他節點不動 «}insert»

    def mine(self, min_sup): «mine»
        """要挖的時候才用門檻：從標準順序最後面的商品開始，之後跟 FP-Growth 一樣""" «mine»
        result = {} «mine»
        for item in sorted(self.header, key=rank, reverse=True): «mine»
            sup = sum(n.count for n in self.header[item])   # 節點鏈上的次數加起來 «sup»
            if sup < min_sup: «sup»
                continue                               # 不頻繁：跳過，但它還留在樹上 «skip»
            result[(item,)] = sup «pattern»
            base = []                                  # 條件模式基底 «base»
            for node in self.header[item]: «base»
                path = prefix_path(node) «base»
                if path: «base»
                    base.append((path, node.count)) «base»
            fp_mine(base, min_sup, [item], result)     # 之後跟 FP-Growth 完全一樣 «recurse»
        return result «end»


def fp_mine(db, min_sup, suffix, result):
    """FP-Growth：在條件模式基底上數次數、建條件 FP-tree、再遞迴"""
    count = {} «count»
    for items, n in db: «count»
        for item in items: «count»
            count[item] = count.get(item, 0) + n «count»
    order = [i for i in count if count[i] >= min_sup]   # 條件樹照「次數」排 «count»
    order.sort(key=lambda i: (-count[i], i)) «count»

    root = Node(None, None) «cinsert»
    header = {i: [] for i in order} «cinsert»
    for items, n in db: «cinsert»
        path = [i for i in order if i in items] «cinsert»
        insert_path(root, path, n, header) «cinsert»

    for item in reversed(order): «cloop»
        pattern = [item] + suffix «cpattern»
        result[tuple(pattern)] = count[item] «cpattern»
        base = [] «cbase»
        for node in header[item]: «cbase»
            path = prefix_path(node) «cbase»
            if path: «cbase»
                base.append((path, node.count)) «cbase»
        fp_mine(base, min_sup, pattern, result)        # 遞迴 «crecurse»


def insert_path(root, path, n, header): «cinsert{»
    node = root
    for item in path:
        if item not in node.children:
            child = Node(item, node)
            node.children[item] = child
            header[item].append(child)
        node = node.children[item]
        node.count += n «}cinsert»


def prefix_path(node): «base{,cbase{»
    """從某個節點往上走到根，經過的商品就是它的前綴路徑"""
    path = []
    node = node.parent
    while node.item is not None:
        path.append(node.item)
        node = node.parent
    return path[::-1] «}base,}cbase»
 «hide{»

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
    show(tree.mine(3)) «}hide»
