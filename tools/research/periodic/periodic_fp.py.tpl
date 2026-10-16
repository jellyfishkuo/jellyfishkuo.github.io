"""PFP-tree：找出「夠常出現、而且出現得夠規律」的商品組合（週期性頻繁樣式）""" «hide»
 «hide»
 «hide»
class Node:
    def __init__(self, item, parent):
        self.item = item
        self.parent = parent
        self.children = {}
        self.tids = []          # 只有尾節點（某筆交易在這裡結束）才有


def periodicity(tids, n): «per{»
    """週期 = 相鄰兩次出現的間隔（含開頭到第一次、最後一次到結尾），取最大的"""
    prev = longest = 0
    for t in sorted(tids):
        longest = max(longest, t - prev)
        prev = t
    return max(longest, n - prev)                  # 最後一次到資料庫結尾 «}per»


def pfp_growth(db, min_sup, max_per): «start{»
    """回傳 {樣式: (支持度, 最大週期)}"""
    n = len(db)
    rows = [(t, [tid]) for tid, t in enumerate(db, 1)]   # 第幾筆交易就是第幾個時間點
    result = {}
    mine(rows, n, min_sup, max_per, [], result) «end»
    return result «}start,end»


def mine(db, n, min_sup, max_per, suffix, result):
    # 1. 每個商品出現在哪幾筆 → 支持度和週期，兩個門檻都過才留下 «count»
    tids = {} «count»
    for items, ts in db: «count»
        for item in items: «count»
            tids.setdefault(item, []).extend(ts) «count»
    order = [i for i in tids «count»
             if len(tids[i]) >= min_sup and periodicity(tids[i], n) <= max_per] «count»
    order.sort(key=lambda i: (-len(tids[i]), i)) «count»

    # 2. 建 PF-tree：節點不記次數，交易的 tid 記在路徑最後一個節點 «insert»
    root = Node(None, None) «insert»
    header = {i: [] for i in order} «insert»
    for items, ts in db: «insert»
        path = [i for i in order if i in items] «insert»
        if path: «insert»
            insert(root, path, ts, header) «insert»

    # 3. 從最下面（支持度最小）的商品往上挖 «loop»
    for item in reversed(order): «loop»
        all_tids = [t for node in header[item] for t in node.tids]   # 這時它的節點都是尾節點 «pattern»
        pattern = [item] + suffix «pattern»
        result[tuple(pattern)] = (len(all_tids), periodicity(all_tids, n)) «pattern»
        base = []                                  # 條件模式基底 «base»
        for node in header[item]: «base»
            path = prefix_path(node) «base»
            if path: «base»
                base.append((path, node.tids)) «base»
        mine(base, n, min_sup, max_per, pattern, result)   # 遞迴 «recurse»
        # 4. 把 tid 清單交給父節點，再把這個商品的節點拿掉 «push»
        for node in header[item]: «push»
            if node.parent.item is not None: «push»
                node.parent.tids.extend(node.tids) «push»
            del node.parent.children[item] «push»


def insert(root, path, tids, header): «insert{»
    node = root
    for item in path:
        if item not in node.children:              # 沒有共用的前綴，長出新節點
            child = Node(item, node)
            node.children[item] = child
            header[item].append(child)             # 串進同商品的節點鏈
        node = node.children[item]
    node.tids.extend(tids)                         # 只有尾節點記 tid «}insert»


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
    # 最小支持度 3、最大週期 3；每行印出：樣式 支持度 最大週期
    for pattern, (sup, per) in pfp_growth(db, 3, 3).items():
        print("[" + ", ".join(pattern) + "]", sup, per) «}hide»
