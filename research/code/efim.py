"""EFIM：在越來越小的投影資料庫上找出所有高效益樣式（效益 >= min_util 的商品組合）"""


def efim(db, profit, min_util):
    # 1. 第 1 次掃描：算每筆交易的效益 TU，加進它裡面每個商品的 TWU
    twu = {}
    for t in db:
        tu = sum(q * profit[item] for item, q in t.items())
        for item in t:
            twu[item] = twu.get(item, 0) + tu
    # TWU 不到門檻的商品整個刪掉，剩下的照 TWU 由小到大排，編號 0, 1, 2, ...
    order = [item for item in twu if twu[item] >= min_util]
    order.sort(key=lambda item: (twu[item], item))
    rank = {item: k for k, item in enumerate(order)}

    # 2. 第 2 次掃描：每筆交易只留下這些商品、照順序排好
    trans = []                         # 每筆交易：(商品編號, 各商品的效益, 前綴效益)
    for t in db:
        items = sorted(rank[i] for i in t if i in rank)
        if items:
            trans.append((items, [t[order[k]] * profit[order[k]] for k in items], 0))
    # 整份交易照「反向字典序」排（從最後一個商品往前比），投影後一樣的交易會排在一起
    trans.sort(key=lambda tr: tr[0][::-1])

    # 3. 用 utility-bin 掃一次，算每個商品的 su；su 夠的才當成第一層要展開的商品
    secondary = list(range(len(order)))
    su, _ = utility_bins(trans, secondary)
    primary = [z for z in secondary if su[z] >= min_util]
    result = {}
    search([], trans, primary, secondary, order, min_util, result)
    return result


def search(prefix, pdb, primary, secondary, order, min_util, result):
    for i in primary:                  # β = prefix 加上 i
        # 投影：有 i 的交易只留下 i 後面的部分，i 的效益加進前綴效益
        util = 0
        proj = []
        for items, utils, pu in pdb:
            if i not in items:
                continue
            k = items.index(i)
            util += pu + utils[k]      # β 在這筆交易的效益
            if k + 1 == len(items):    # i 後面沒有商品了，不用留
                continue
            t = (items[k + 1:], utils[k + 1:], pu + utils[k])
            if proj and proj[-1][0] == t[0]:   # 交易合併：跟上一筆剩下的商品完全一樣
                last = proj[-1]
                proj[-1] = (last[0], [a + b for a, b in zip(last[1], t[1])], last[2] + t[2])
            else:
                proj.append(t)
        beta = prefix + [order[i]]
        if util >= min_util:           # 高效益，輸出
            result[tuple(beta)] = util
        # 掃一次 β 的投影資料庫，算 i 後面每個商品 z 的 su、lu
        keep = [z for z in secondary if z > i]
        su, lu = utility_bins(proj, keep)
        new_secondary = [z for z in keep if lu[z] >= min_util]       # lu 不夠：下一層整個不考慮 z
        new_primary = [z for z in new_secondary if su[z] >= min_util] # su 不夠：β+z 不用展開
        search(beta, proj, new_primary, new_secondary, order, min_util, result)


def utility_bins(pdb, keep):
    """utility-bin：每個商品一個格子，掃一次投影資料庫就把 su、lu 都加好"""
    su = {z: 0 for z in keep}
    lu = {z: 0 for z in keep}
    for items, utils, pu in pdb:
        rest = sum(utils)              # 這筆剩下的效益全部加起來
        after = 0                      # 從最後面往前走：z 和排在 z 後面（還在名單上）的效益
        for k in reversed(range(len(items))):
            z = items[k]
            if z in su:
                after += utils[k]
                su[z] += pu + after    # sub-tree utility
                lu[z] += pu + rest     # local utility
    return su, lu


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
    for items, u in efim(db, profit, 250).items():
        print("{" + ", ".join(items) + "} 效益 =", u)
