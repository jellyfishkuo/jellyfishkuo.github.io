"""HUI-Miner：用 utility list 找出所有高效益樣式（效益 >= min_util 的商品組合）"""


class UtilityList:
    """一個商品組合的 utility list：出現在哪些交易，以及在那筆交易裡的 iutil、rutil"""
    def __init__(self, items):
        self.items = items
        self.entries = {}              # tid -> (iutil, rutil)
        self.sum_iutil = 0
        self.sum_rutil = 0

    def add(self, tid, iutil, rutil):
        self.entries[tid] = (iutil, rutil)
        self.sum_iutil += iutil
        self.sum_rutil += rutil


def hui_miner(db, profit, min_util):
    # 1. 第 1 次掃描：算每筆交易的效益 TU，加進它裡面每個商品的 TWU
    twu = {}
    for t in db:
        tu = sum(q * profit[item] for item, q in t.items())
        for item in t:
            twu[item] = twu.get(item, 0) + tu
    # TWU 不到門檻的商品整個刪掉，剩下的照 TWU 由小到大排
    order = [item for item in twu if twu[item] >= min_util]
    order.sort(key=lambda item: (twu[item], item))

    # 2. 第 2 次掃描：建每個商品的 utility list
    lists = [UtilityList([item]) for item in order]
    for tid, t in enumerate(db):
        rutil = 0                      # 從最後面往前走：排在後面的商品效益總和
        for k in reversed(range(len(order))):
            if order[k] in t:
                u = t[order[k]] * profit[order[k]]
                lists[k].add(tid, u, rutil)
                rutil += u

    # 3. 從單一商品的 list 開始深度優先搜尋
    result = {}
    search(None, lists, min_util, result)
    return result


def search(p, uls, min_util, result):
    for i, x in enumerate(uls):
        if x.sum_iutil >= min_util:                    # 高效益，輸出
            result[tuple(x.items)] = x.sum_iutil
        if x.sum_iutil + x.sum_rutil < min_util:       # 再怎麼往下加也不夠，剪掉
            continue
        ext = []
        for y in uls[i + 1:]:
            xy = construct(p, x, y)
            if xy.entries:                             # 沒有共同交易的就不要
                ext.append(xy)
        search(x, ext, min_util, result)               # 遞迴：以 x 為前綴往下找


def construct(p, px, py):
    """合併 Px 和 Py 的 utility list，得到 Pxy 的"""
    pxy = UtilityList(px.items + py.items[-1:])
    for tid, (iu_x, _) in px.entries.items():
        if tid not in py.entries:
            continue                                   # 這筆交易沒有 y
        iu_y, ru_y = py.entries[tid]
        iutil = iu_x + iu_y
        if p is not None:
            iutil -= p.entries[tid][0]                 # P 的效益兩邊都算了，扣掉一次
        pxy.add(tid, iutil, ru_y)                      # rutil 用 Py 的（y 排在 x 後面）
    return pxy


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
    for items, u in hui_miner(db, profit, 250).items():
        print("{" + ", ".join(items) + "} 效益 =", u)
