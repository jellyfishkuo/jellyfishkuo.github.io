"""Top-k 高效益樣式探勘（TKO 的做法）：不用給門檻，直接找效益最高的前 k 名""" «hide»
import heapq «hide»
 «hide»
 «hide»
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


class TopK:
    """目前的前 k 名。heap 是最小堆積，只放效益、最多 k 個，heap[0] 就是目前的第 k 名"""
    def __init__(self, k, min_util): «riu»
        self.k = k «riu»
        self.min_util = min_util       # 門檻：只會往上調，不會往下 «riu»
        self.heap = [] «riu»
        self.result = {}               # 效益 >= 門檻的組合（跟第 k 名同分的全部留著） «riu»

    def offer(self, items, util): «offer{»
        self.result[tuple(items)] = util
        heapq.heappush(self.heap, util)
        if len(self.heap) > self.k:
            heapq.heappop(self.heap)   # 超過 k 個，把最小的踢掉 «}offer»
        if len(self.heap) == self.k and self.heap[0] > self.min_util: «raise{»
            self.min_util = self.heap[0]   # 堆積滿了：第 k 名的效益就是新門檻
            self.result = {s: u for s, u in self.result.items() if u >= self.min_util} «}raise»


def top_k_hui(db, profit, k): «start»
    # 1. 第 1 次掃描：算每筆交易的效益 TU、每個商品的 TWU，順便算單一商品的效益 «tu»
    twu, single = {}, {} «tu»
    for t in db: «tu»
        tu = sum(q * profit[item] for item, q in t.items()) «tu»
        for item, q in t.items(): «tu»
            twu[item] = twu.get(item, 0) + tu «tu»
            single[item] = single.get(item, 0) + q * profit[item] «tu»
    # 預先提升門檻：單一商品本身就是組合，第 k 大的單品效益不會超過真正的第 k 名 «riu»
    min_util = 0 «riu»
    if len(single) >= k: «riu»
        min_util = sorted(single.values(), reverse=True)[k - 1] «riu»
    board = TopK(k, min_util) «riu»
    # TWU 不到門檻的商品整個刪掉，剩下的照 TWU 由小到大排 «twu»
    order = [item for item in twu if twu[item] >= min_util] «twu»
    order.sort(key=lambda item: (twu[item], item)) «twu»

    # 2. 第 2 次掃描：建每個商品的 utility list «scan»
    lists = [UtilityList([item]) for item in order] «scan»
    for tid, t in enumerate(db): «scan»
        rutil = 0                      # 從最後面往前走：排在後面的商品效益總和 «scan»
        for k2 in reversed(range(len(order))): «scan»
            if order[k2] in t: «scan»
                u = t[order[k2]] * profit[order[k2]] «scan»
                lists[k2].add(tid, u, rutil) «scan»
                rutil += u «scan»

    # 3. 深度優先搜尋，邊找邊把門檻往上調 «search0»
    search(None, lists, board) «search0»
    return board.result «end»


def search(p, uls, board):
    for i, x in enumerate(uls): «check»
        if x.sum_iutil >= board.min_util:              # 夠格進前 k 名 «offer»
            board.offer(x.items, x.sum_iutil) «offer»
        if x.sum_iutil + x.sum_rutil < board.min_util: # 上界連門檻都不到，剪掉 «prune»
            continue «prune»
        ext = [] «expand»
        for y in uls[i + 1:]: «expand»
            xy = construct(p, x, y) «expand,call»
            if xy.entries:                             # 沒有共同交易的就不要 «expand,call»
                ext.append(xy) «expand,call»
        search(x, ext, board)                          # 遞迴：以 x 為前綴往下找 «recurse»


def construct(p, px, py): «construct{»
    """合併 Px 和 Py 的 utility list，得到 Pxy 的（跟 HUI-Miner 一樣）"""
    pxy = UtilityList(px.items + py.items[-1:])
    for tid, (iu_x, _) in px.entries.items():
        if tid not in py.entries:
            continue                                   # 這筆交易沒有 y
        iu_y, ru_y = py.entries[tid]
        iutil = iu_x + iu_y
        if p is not None:
            iutil -= p.entries[tid][0]                 # P 的效益兩邊都算了，扣掉一次
        pxy.add(tid, iutil, ru_y)                      # rutil 用 Py 的（y 排在 x 後面）
    return pxy «}construct»
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
    k = 6
    result = top_k_hui(db, profit, k)
    print("前", k, "名（跟第", k, "名同分的也列出）：")
    for items, u in sorted(result.items(), key=lambda e: (-e[1], ", ".join(e[0]))):
        print("{" + ", ".join(items) + "} 效益 =", u) «}hide»
