"""PreTK：資料一批一批進來時的 top-k 高效益樣式（pre-large 概念＋門檻拉高策略）""" «hide»
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
    """挖掘時的前 k 名。heap 是最小堆積，只放效益、最多 k 個，heap[0] 就是目前的第 k 名"""
    def __init__(self, k, min_util): «mine»
        self.k = k «mine»
        self.min_util = min_util       # 起始門檻（S1、S2、S4 取最大的），只會往上調 «mine»
        self.heap = [] «mine»
        self.result = {}               # 效益 >= 門檻的組合 «mine»

    def offer(self, items, util): «offer{»
        self.result[tuple(sorted(items))] = util
        heapq.heappush(self.heap, util)
        if len(self.heap) > self.k:
            heapq.heappop(self.heap)   # 超過 k 個，把最小的踢掉 «}offer»
        if len(self.heap) == self.k and self.heap[0] > self.min_util: «offer{»
            self.min_util = self.heap[0]   # S3：第 k 名變高了，門檻跟著拉高
            self.result = {s: u for s, u in self.result.items() if u >= self.min_util} «}offer»


def kth(values, k):
    """第 k 大的數；不到 k 個就是 0"""
    values = sorted(values, reverse=True)
    return values[k - 1] if len(values) >= k else 0


class PreTK:
    """樹上存前 k_upper 名（Large + Pre-large），答案是前 k_lower 名（Large）"""
    def __init__(self, profit, k_lower, k_upper): «start{»
        self.profit = profit
        self.k_lower, self.k_upper = k_lower, k_upper
        self.gul = {}                  # Global-Utility-List：商品 -> [(tid, 效益)]，讀過就不用再掃
        self.gtwu = {}                 # Global-TWU-Map：商品 -> 到目前為止的 TWU
        self.n = 0                     # 一共讀了幾筆交易
        self.tree = {}                 # itemset-tree：前 k_upper 名的組合 -> 效益
        self.min_upper = 0             # 樹上第 k_lower 名的效益（Large 的門檻）
        self.min_lower = 0             # 樹上第 k_upper 名的效益（Pre-large 的門檻）
        self.ceiling = 0               # 不在樹上的組合，效益最多這麼多 «}start»

    def add_batch(self, batch):
        """讀進一批新交易；回傳 True 表示這批有重新挖掘"""
        # 1. 讀這一批：存進 Global-Utility-List，更新全部的 TWU 和這一批的 TWU «read»
        twu_batch = {} «read»
        for t in batch: «read»
            tu = sum(q * self.profit[i] for i, q in t.items()) «read»
            for i, q in t.items(): «read»
                self.gul.setdefault(i, []).append((self.n, q * self.profit[i])) «read»
                self.gtwu[i] = self.gtwu.get(i, 0) + tu «read»
                twu_batch[i] = twu_batch.get(i, 0) + tu «read»
            self.n += 1 «read»
        # 2. 重挖條件：樹外的組合這批最多長 max TWU，追不上第 k_lower 名就不用重挖 «check»
        grow = max(twu_batch.values(), default=0) «check»
        if self.tree and grow < self.min_upper - self.ceiling: «check»
            self.update_tree(batch, grow) «update»
            return False «update»
        self.mine() «remine»
        return True «remine»

    def update_tree(self, batch, grow): «update{»
        """不重挖：只把這一批的效益加到樹上的組合"""
        for items in self.tree:
            for t in batch:
                if all(i in t for i in items):
                    self.tree[items] += sum(t[i] * self.profit[i] for i in items)
        self.ceiling += grow           # 樹外的組合這批最多也長了 grow
        ranked = sorted(self.tree.values(), reverse=True)
        self.min_upper = kth(ranked, self.k_lower)
        self.min_lower = kth(ranked, self.k_upper) «}update»

    def gliu(self): «raise{»
        """GLIU：商品照 TWU 排好，交易裡「排序上連在一起」的一段商品，效益加起來"""
        order = sorted(self.gul, key=lambda i: (self.gtwu[i], i))
        pos = {i: k for k, i in enumerate(order)}
        rows = [{} for _ in range(self.n)]
        for i, lst in self.gul.items():
            for tid, u in lst:
                rows[tid][i] = u
        table = {}
        for row in rows:
            ks = sorted(pos[i] for i in row)
            for a in range(len(ks)):
                acc = row[order[ks[a]]]
                for b in range(a + 1, len(ks)):
                    if ks[b] != ks[b - 1] + 1:
                        break              # 中間缺了一個，就不連續了
                    acc += row[order[ks[b]]]
                    table[(ks[a], ks[b])] = table.get((ks[a], ks[b]), 0) + acc
        return table «}raise»

    def mine(self):
        # 3. 門檻拉高：S1 單一商品、S2 GLIU、S4 上次的第 k_upper 名，取最大的當起始門檻 «raise»
        s1 = kth([sum(u for _, u in lst) for lst in self.gul.values()], self.k_upper) «raise»
        s2 = kth(self.gliu().values(), self.k_upper) «raise»
        min_util = max(s1, s2, self.min_lower) «raise»
        # 4. 從 Global-Utility-List 重建 utility list（不重掃舊交易），TWU 不夠的商品先不用 «mine»
        order = sorted((i for i in self.gul if self.gtwu[i] >= min_util), key=lambda i: (self.gtwu[i], i)) «mine»
        rua = [0] * self.n             # Remaining Utility Array：每筆交易排在後面的商品效益總和 «mine»
        lists = [] «mine»
        for i in reversed(order): «mine»
            ul = UtilityList([i]) «mine»
            for tid, u in self.gul[i]: «mine»
                ul.add(tid, u, rua[tid]) «mine»
                rua[tid] += u «mine»
            lists.insert(0, ul) «mine»
        board = TopK(self.k_upper, min_util) «mine»
        search(None, lists, board) «mine»
        # 5. 前 k_upper 名寫進新的 itemset-tree（同分的照商品名稱排） «tree»
        best = sorted(board.result.items(), key=lambda e: (-e[1], len(e[0]), e[0]))[:self.k_upper] «tree»
        self.tree = dict(best) «tree»
        ranked = [u for _, u in best] «tree»
        self.min_upper = kth(ranked, self.k_lower) «tree»
        self.min_lower = kth(ranked, self.k_upper) «tree»
        self.ceiling = self.min_lower  # 沒進樹的組合，效益都不超過第 k_upper 名 «tree»

    def answer(self): «end{»
        """前 k_lower 名直接從樹上拿"""
        best = sorted(self.tree.items(), key=lambda e: (-e[1], len(e[0]), e[0]))
        return best[:self.k_lower] «}end»


def search(p, uls, board): «mine{»
    for i, x in enumerate(uls):
        if x.sum_iutil >= board.min_util:              # 夠格進前 k_upper 名
            board.offer(x.items, x.sum_iutil)
        if x.sum_iutil + x.sum_rutil < board.min_util: # 上界連門檻都不到，剪掉
            continue
        ext = []
        for y in uls[i + 1:]:
            xy = construct(p, x, y)
            if xy.entries:                             # 沒有共同交易的就不要
                ext.append(xy)
        search(x, ext, board)                          # 遞迴：以 x 為前綴往下找


def construct(p, px, py):
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
    return pxy «}mine»
 «hide{»

if __name__ == "__main__":
    profit = {"咖啡": 30, "麵包": 15, "牛奶": 20, "飯糰": 10, "茶葉蛋": 5, "洋芋片": 25}
    batches = [                        # 每筆交易：商品 -> 購買數量；第一批是原始資料庫 D
        ("D", [{"咖啡": 4, "麵包": 2, "牛奶": 2},
               {"咖啡": 3, "麵包": 5, "茶葉蛋": 4},
               {"咖啡": 1, "麵包": 1, "牛奶": 2, "飯糰": 2},
               {"麵包": 3, "牛奶": 4, "洋芋片": 5},
               {"咖啡": 3, "牛奶": 2, "茶葉蛋": 2},
               {"咖啡": 1, "麵包": 2, "牛奶": 1, "茶葉蛋": 1},
               {"飯糰": 1, "茶葉蛋": 2, "洋芋片": 2},
               {"咖啡": 1, "麵包": 2, "飯糰": 1}]),
        ("ID1", [{"咖啡": 1, "麵包": 2, "牛奶": 1}]),
        ("ID2", [{"麵包": 2, "茶葉蛋": 2}]),
        ("ID3", [{"咖啡": 2, "牛奶": 2}]),
        ("ID4", [{"飯糰": 1, "茶葉蛋": 1}]),
    ]
    miner = PreTK(profit, 3, 10)       # 答案要前 3 名，樹上多存到第 10 名
    for label, batch in batches:
        remined = miner.add_batch(batch)
        print(label + "：" + ("重新挖掘" if remined else "不用重挖，只更新樹")
              + "　minU_upper = " + str(miner.min_upper) + "，minU_lower = " + str(miner.min_lower)
              + "，樹外上限 = " + str(miner.ceiling))
        for items, u in miner.answer():
            print("  {" + ", ".join(items) + "} 效益 = " + str(u)) «}hide»
