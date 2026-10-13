"""UP-Growth：把交易壓成 UP-Tree（DGU、DGN），挖條件樹時再用 DLU、DLN 收緊上界，最後掃一次資料庫驗證候選""" «hide»
 «hide»
 «hide»
class Node:
    def __init__(self, item, parent):
        self.item, self.parent = item, parent
        self.count = 0                     # 經過這個節點的交易數
        self.nu = 0                        # 節點效益（上界）
        self.children = {}


class UPTree:
    def __init__(self, order):
        self.root = Node(None, None)
        self.order = order                 # 表頭的商品順序
        self.links = {i: [] for i in order}   # 同一個商品的所有節點

    def add(self, path, nus, count):
        """沿著 path 往下走，第 k 個節點的 nu 加上 nus[k]"""
        node = self.root
        for item, nu in zip(path, nus):
            if item not in node.children:
                node.children[item] = Node(item, node)
                self.links[item].append(node.children[item])
            node = node.children[item]
            node.count += count
            node.nu += nu


def up_growth(db, profit, min_util): «start»
    # 第 1 次掃描：每筆交易的效益 TU，加進它裡面每個商品的 TWU «tu»
    twu, miu = {}, {} «tu»
    for t in db: «tu»
        tu = sum(q * profit[i] for i, q in t.items()) «tu»
        for i, q in t.items(): «tu»
            twu[i] = twu.get(i, 0) + tu «tu»
            miu[i] = min(miu.get(i, q * profit[i]), q * profit[i])   # 這個商品在一筆交易裡最少賺多少 «tu»
    # DGU：TWU 不夠的商品刪掉，留下的照 TWU 由大到小排 «dgu»
    order = sorted((i for i in twu if twu[i] >= min_util), key=lambda i: (-twu[i], i)) «dgu»
    tree = UPTree(order) «dgu»
    # 第 2 次掃描：每筆交易照這個順序插進 UP-Tree «insert»
    for t in db: «insert»
        path = [i for i in order if i in t] «insert»
        nus, acc = [], 0 «insert»
        for i in path:                     # DGN：節點只記「到自己為止」的效益 «insert»
            acc += t[i] * profit[i] «insert»
            nus.append(acc) «insert»
        tree.add(path, nus, 1) «insert»
    cands = {}                             # 候選（PHUI）-> 它的上界 «mine»
    mine(tree, (), min_util, miu, cands) «mine»
    # 第 3 次掃描：算候選真正的效益，夠的才輸出 «verify»
    util = {c: 0 for c in cands} «verify»
    for t in db: «verify»
        for c in cands: «verify»
            if all(i in t for i in c): «verify»
                util[c] += sum(t[i] * profit[i] for i in c) «verify»
    return {c: u for c, u in util.items() if u >= min_util} «end»


def mine(tree, suffix, min_util, miu, cands):
    for item in reversed(tree.order):      # 從表頭最下面往上挖
        est = sum(n.nu for n in tree.links[item])   # 這個商品的節點效益加起來 «check»
        if est < min_util:                 # 上界不夠：含它的組合都不可能，跳過 «check»
            continue «check»
        pattern = (item,) + suffix «check»
        cands[pattern] = est «check»
        # 條件模式基底：從每個 item 節點往上走到根 «cpb»
        paths, lu = [], {} «cpb»
        for n in tree.links[item]: «cpb»
            path, p = [], n.parent «cpb»
            while p.item is not None: «cpb»
                path.insert(0, p.item) «cpb»
                lu[p.item] = lu.get(p.item, 0) + n.nu   # 局部效益：經過它的路徑效益加起來 «dlu»
                p = p.parent «cpb»
            paths.append(path) «cpb»
        # DLU：局部效益不夠的商品刪掉 «dlu»
        local = UPTree([i for i in tree.order if lu.get(i, 0) >= min_util]) «dlu»
        for n, path in zip(tree.links[item], paths): «dln»
            pu, pc = n.nu, n.count         # 路徑效益、路徑次數 «dln»
            keep = [i for i in path if lu[i] >= min_util] «dlu»
            pu -= sum(miu[i] * pc for i in path if lu[i] < min_util)   # 刪掉的商品至少值 miu × 次數 «dlu»
            rest = sum(miu[i] * pc for i in keep) «dln»
            nus = [] «dln»
            for i in keep:                 # DLN：每個節點扣掉排在它後面的商品 «dln»
                rest -= miu[i] * pc «dln»
                nus.append(pu - rest) «dln»
            local.add(keep, nus, pc) «dln»
        if local.order: «recurse»
            mine(local, pattern, min_util, miu, cands) «recurse»
 «hide{»

if __name__ == "__main__":
    profit = {"咖啡": 30, "麵包": 15, "牛奶": 20, "飯糰": 10, "茶葉蛋": 5, "洋芋片": 25}
    db = [                             # 每筆交易：商品 -> 購買數量
        {"咖啡": 4, "麵包": 2, "牛奶": 2},
        {"咖啡": 3, "麵包": 5, "茶葉蛋": 4},
        {"咖啡": 1, "麵包": 1, "牛奶": 2, "飯糰": 2},
        {"麵包": 3, "牛奶": 4, "洋芋片": 5},
        {"咖啡": 3, "牛奶": 2, "茶葉蛋": 2},
        {"咖啡": 1, "麵包": 2, "牛奶": 1, "茶葉蛋": 1},
        {"飯糰": 1, "茶葉蛋": 2, "洋芋片": 2},
        {"咖啡": 1, "麵包": 2, "飯糰": 1},
    ]
    for items, u in up_growth(db, profit, 250).items():
        print("{" + ", ".join(items) + "} 效益 =", u) «}hide»
