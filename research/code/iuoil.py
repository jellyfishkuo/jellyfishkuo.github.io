"""IUOIL：用 indexed list 在增量資料庫上找高效益佔有率樣式（Cho et al., Knowledge-Based Systems 306, 2024）"""
import math

EPS = 1e-9                             # 小數比大小時的容許誤差


class Entry:
    """IUOI-List 的一格：uo、下一個商品 nid、它在那個商品串列的第幾格 nidx（從 1 數）、ruo"""
    def __init__(self, tid, uo, ruo=0.0, puo=0.0):
        self.tid = tid                 # 只拿來印出來對照，演算法不靠它
        self.uo, self.ruo = uo, ruo
        self.nid, self.nidx = None, 0  # None 就是論文的 ^（後面沒有商品了）
        self.puo = puo                 # 條件串列才用：共同前綴 P 在這筆的 uo


class Node:
    """一個樣式的 IUOI-List：suo、sruo 和一格一格的 entry（照交易進來的順序）"""
    def __init__(self, items):
        self.items = items
        self.entries = []
        self.suo = self.sruo = 0.0


class IUOIL:
    def __init__(self, profit, alpha_pct, beta_pct):
        self.profit = profit
        self.alpha = alpha_pct         # minSup = 讀過的交易數 × α
        self.beta = beta_pct / 100     # 最小佔有率 β
        self.gl = {}                   # 全域 IUOI-List：商品 -> Node（支持度不夠的也留著）
        self.order = []                # 目前的總順序
        self.n = 0                     # 讀過幾筆交易
        self.tid = 0                   # 交易編號（只拿來印）
        self.rebuilt = False           # 重建過了沒（還沒重建前照字典順序）

    def add_batch(self, batch):
        """新的一批交易：接到每個商品的 list 後面，再重建、再挖"""
        for t in batch:
            self.insert(t)
        self.n += len(batch)
        self.reconstruct()
        return self.mine()

    def insert(self, t):
        """一筆交易（商品 -> 數量）：每個商品的 list 加一格，前一格的 NId、NIdx 指過來"""
        tu = sum(q * self.profit[i] for i, q in t.items())             # 這筆交易的總效益
        new = sorted(i for i in t if i not in self.gl)
        self.order = self.order + new if self.rebuilt else sorted(self.order + new)   # 新商品排最後
        rank = {i: k for k, i in enumerate(self.order)}
        prev = None
        for item in sorted(t, key=lambda i: rank[i]):                  # 照目前的順序串起來
            node = self.gl.setdefault(item, Node([item]))
            e = Entry(self.tid, t[item] * self.profit[item] / tu)   # uo = 自己的效益 / 整筆
            node.entries.append(e)
            if prev:
                prev.nid, prev.nidx = item, len(node.entries)          # 指到「item 的第幾格」
            prev = e
        self.tid += 1

    def reconstruct(self):
        """照新的支持度重排；順著索引把每筆交易的格子找出來，重接 NId、NIdx，算 ruo"""
        sup = {i: len(self.gl[i].entries) for i in self.order}
        old = {i: k for k, i in enumerate(self.order)}
        new_order = sorted(self.order, key=lambda i: (sup[i], old[i]))   # 支持度由小到大，一樣多照原本的順序
        rank = {i: k for k, i in enumerate(new_order)}
        for node in self.gl.values():
            node.suo = node.sruo = 0.0
        seen = set()
        for item in self.order:        # 照舊順序一個一個 list 看
            for k, e in enumerate(self.gl[item].entries):
                if id(e) in seen:      # 已經在別的交易鏈裡處理過了
                    continue
                chain = []             # 沒看過的格子 = 一筆交易的開頭，順著索引跳
                it, ix = item, k + 1
                while it is not None:
                    en = self.gl[it].entries[ix - 1]
                    seen.add(id(en))
                    chain.append((it, ix, en))
                    it, ix = en.nid, en.nidx
                chain.sort(key=lambda c: rank[c[0]])                       # 照新順序重排
                rest = 0.0
                for j in range(len(chain) - 1, -1, -1):                     # 從後面往前：ruo = 後面的 uo 加總
                    it, ix, en = chain[j]
                    en.ruo = rest
                    rest += en.uo
                    en.nid, en.nidx = chain[j + 1][:2] if j + 1 < len(chain) else (None, 0)
                for it, ix, en in chain:
                    self.gl[it].suo += en.uo
                    self.gl[it].sruo += en.ruo
        self.order = new_order
        self.rebuilt = True

    def mine(self):
        result = {}
        self.search([self.gl[i] for i in self.order], result)
        return result

    def search(self, cl, result):
        cms = -(-self.n * self.alpha // 100)                           # ⌈minSup⌉
        for x in cl:
            sup = len(x.entries)
            if sup * 100 < self.n * self.alpha:                         # ① 支持度不夠：自己和更長的都不可能
                continue
            if x.suo / sup >= self.beta - EPS:                          # 平均佔有率夠，輸出
                result[tuple(x.items)] = (sup, x.suo / sup)
            if (x.suo + x.sruo) / cms < self.beta - EPS:               # ② lubuo 不夠，剪掉
                continue
            if self.ubuo(x, cms) < self.beta - EPS:                     # ③ ubuo 不夠，剪掉
                continue
            ncl = self.extend(x, cl)
            if ncl:
                self.search(ncl, result)                                # 以 x 為前綴往下找

    def ubuo(self, x, cms):
        """uo + ruo 最大的 ⌈minSup⌉ 格取平均"""
        vec = sorted((e.uo + e.ruo for e in x.entries), reverse=True)
        return sum(vec[:cms]) / cms

    def extend(self, x, cl):
        """順著 x 每一格的索引往後跳，一次做出所有 x 再加一個商品的條件串列"""
        lists = {n.items[-1]: n for n in cl}
        new = {}
        for e in x.entries:
            prev = None
            it, ix = e.nid, e.nidx
            while it is not None:      # 同一筆交易裡、排在 x 後面的每個商品
                ey = lists[it].entries[ix - 1]
                node = new.setdefault(it, Node(x.items + [it]))
                ne = Entry(e.tid, e.uo + ey.uo - e.puo, ey.ruo, e.uo)   # 前綴 P 兩邊都算了，扣掉一次
                node.entries.append(ne)
                node.suo += ne.uo
                node.sruo += ne.ruo
                if prev:
                    prev.nid, prev.nidx = it, len(node.entries)
                prev = ne
                it, ix = ey.nid, ey.nidx
        rank = {i: k for k, i in enumerate(self.order)}
        return sorted(new.values(), key=lambda n: rank[n.items[-1]])



def fmt4(x):
    n = math.floor(x * 10000 + 0.5)    # 自己四捨五入，Java 和 Python 印出來才會一模一樣
    return "%d.%04d" % (n // 10000, n % 10000)


def run(profit, batches, alpha_pct, beta_pct):
    """一批一批加進去，每加一批就挖一次；回傳每次的結果"""
    h = IUOIL(profit, alpha_pct, beta_pct)
    return [h.add_batch(b) for b in batches]


if __name__ == "__main__":
    profit = {"咖啡": 30, "麵包": 15, "牛奶": 20, "飯糰": 10, "茶葉蛋": 5, "洋芋片": 25}
    batches = [                        # 每筆交易：商品 -> 購買數量
        [{"咖啡": 4, "麵包": 2, "牛奶": 2},                     # DB0：原始資料庫
         {"咖啡": 3, "麵包": 5, "茶葉蛋": 4},
         {"咖啡": 1, "麵包": 1, "牛奶": 2, "飯糰": 2},
         {"麵包": 3, "牛奶": 4, "洋芋片": 5},
         {"咖啡": 3, "牛奶": 2, "茶葉蛋": 2},
         {"咖啡": 1, "麵包": 2, "牛奶": 1, "茶葉蛋": 1},
         {"飯糰": 1, "茶葉蛋": 2, "洋芋片": 2},
         {"咖啡": 1, "麵包": 2, "飯糰": 1}],
        [{"洋芋片": 2, "飯糰": 1, "牛奶": 1},                   # DB1：新的一批
         {"洋芋片": 1, "麵包": 1, "茶葉蛋": 2}],
        [{"咖啡": 2, "洋芋片": 2},                              # DB2：再一批
         {"飯糰": 2, "茶葉蛋": 3, "洋芋片": 1}],
    ]
    # α = 30%（minSup = 讀過的筆數 × 30%）、β = 50%
    total = 0
    for k, result in enumerate(run(profit, batches, 30, 50)):
        total += len(batches[k])
        print("DB" + str(k) + " 進來後（共 " + str(total) + " 筆）：")
        for items, (sup, uo) in result.items():
            print("  {" + ", ".join(items) + "} sup = " + str(sup) + "  uo = " + fmt4(uo))
