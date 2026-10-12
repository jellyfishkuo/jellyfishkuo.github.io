"""FP-Growth：把交易壓成一棵 FP-tree，再從樹裡遞迴挖出所有頻繁樣式""" «hide»
 «hide»
 «hide»
class Node:
    def __init__(self, item, parent):
        self.item = item
        self.count = 0
        self.parent = parent
        self.children = {}


def fp_growth(db, min_sup): «start{»
    result = {}
    rows = [(t, 1) for t in db]       # (交易, 權重)；條件模式基底裡權重是路徑次數
    mine(rows, min_sup, [], result) «end»
    return result «}start,end»


def mine(db, min_sup, suffix, result):
    # 1. 數次數，只留下頻繁的商品，次數多的排前面 «count»
    count = {} «count»
    for items, n in db: «count»
        for item in items: «count»
            count[item] = count.get(item, 0) + n «count»
    order = [i for i in count if count[i] >= min_sup] «count»
    order.sort(key=lambda i: (-count[i], i)) «count»

    # 2. 建 FP-tree：每筆照 order 排好，沿著共同的前綴往下插 «insert»
    root = Node(None, None) «insert»
    header = {i: [] for i in order} «insert»
    for items, n in db: «insert»
        path = [i for i in order if i in items] «insert»
        insert(root, path, n, header) «insert»

    # 3. 從次數最少的商品開始挖 «loop»
    for item in reversed(order): «loop»
        pattern = [item] + suffix «pattern»
        result[tuple(pattern)] = count[item] «pattern»
        base = []                                  # 條件模式基底 «base»
        for node in header[item]: «base»
            path = prefix_path(node) «base»
            if path: «base»
                base.append((path, node.count)) «base»
        mine(base, min_sup, pattern, result)       # 遞迴 «recurse»


def insert(root, path, n, header): «insert{»
    node = root
    for item in path:
        if item not in node.children:              # 沒有共用的前綴，長出新節點
            child = Node(item, node)
            node.children[item] = child
            header[item].append(child)             # 串進同商品的節點鏈
        node = node.children[item]
        node.count += n «}insert»


def prefix_path(node): «base{»
    """從某個節點往上走到根，經過的商品就是它的前綴路徑"""
    path = []
    node = node.parent
    while node.item is not None:
        path.append(node.item)
        node = node.parent
    return path[::-1] «}base»
 «hide{»

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
    for pattern, sup in fp_growth(db, 3).items():
        print(list(pattern), sup) «}hide»
