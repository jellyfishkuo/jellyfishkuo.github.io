"""HUOPS：用滑動視窗在資料串流上找高效益佔有率樣式（Park et al., Information Sciences 716, 2025）"""
import math

EPS = 1e-9                             # 小數比大小時的容許誤差


class Entry:
    """一筆交易的紀錄：tid、樣式在這筆的佔有率 uo、排在後面的商品佔有率 ruo"""
    def __init__(self, tid, uo, ruo=0.0):
        self.tid, self.uo, self.ruo = tid, uo, ruo


class Node:
    """HUOPS-List 的一個節點：一個樣式，底下照批次分組記每筆交易的 Entry"""
    def __init__(self, items):
        self.items = items
        self.batches = {}              # 批次編號 -> [Entry, ...]
        self.sum_uo = 0.0
        self.sum_ruo = 0.0

    def entries(self):
        return [e for es in self.batches.values() for e in es]

    def support(self):
        return sum(len(es) for es in self.batches.values())


class HUOPS:
    def __init__(self, profit, batch_size, win_size, alpha_pct, beta_pct):
        self.profit = profit
        self.win_size = win_size       # 視窗裡放幾批
        self.min_sup = batch_size * win_size * alpha_pct / 100   # 視窗交易數 × α
        self.beta = beta_pct / 100     # 最小佔有率
        self.gl = {}                   # 全域 HUOPS-List：商品 -> Node
        self.window = []               # 視窗裡的批次編號，最舊的在前面
        self.tid = 0

    def add_batch(self, bid, batch):
        """新的一批進來；視窗滿了就先把最舊的一批移出去"""
        if len(self.window) == self.win_size:
            self.remove_batch(self.window.pop(0))
        self.window.append(bid)
        for t in batch:                # t：商品 -> 數量
            tu = sum(q * self.profit[i] for i, q in t.items())        # 這筆交易的總效益
            for item, q in t.items():
                node = self.gl.setdefault(item, Node([item]))
                e = Entry(self.tid, q * self.profit[item] / tu)        # uo = 自己的效益 / 整筆
                node.batches.setdefault(bid, []).append(e)
                node.sum_uo += e.uo
            self.tid += 1

    def remove_batch(self, bid):
        for item in list(self.gl):
            node = self.gl[item]
            for e in node.batches.pop(bid, []):                         # 整批的 entry 一起拿掉
                node.sum_uo -= e.uo
            if not node.batches:       # 視窗裡已經沒有這個商品
                del self.gl[item]

    def mine(self):
        """視窗滿了、要結果時：先重整全域 list，再深度優先挖"""
        order = self.reconstruct()
        result = {}
        self.search(None, [self.gl[i] for i in order], result)
        return result

    def reconstruct(self):
        sup = {i: n.support() for i, n in self.gl.items()}
        order = sorted(self.gl, key=lambda i: (sup[i], i))            # 照支持度由小到大
        temp = {}                      # tempArray：tid -> 排在後面的商品 uo 加總
        for item in reversed(order):   # 從最後面往前算 ruo
            node = self.gl[item]
            node.sum_ruo = 0.0
            for e in node.entries():
                if sup[item] < self.min_sup:                            # 支持度不夠，不用算，歸零就好
                    e.ruo = 0.0
                    continue
                e.ruo = temp.get(e.tid, 0.0)
                temp[e.tid] = e.ruo + e.uo
                node.sum_ruo += e.ruo
        return order

    def search(self, prefix, cl, result):
        cms = math.ceil(self.min_sup)
        for k, x in enumerate(cl):
            sup = x.support()
            if sup < self.min_sup:     # 支持度不夠：自己和更長的都不可能
                continue
            if x.sum_uo / sup >= self.beta - EPS:                       # 平均佔有率夠，輸出
                result[tuple(x.items)] = (sup, x.sum_uo / sup)
            if (x.sum_uo + x.sum_ruo) / cms < self.beta - EPS:         # UBUO1 不夠，剪掉
                continue
            if self.upper_bound(x, cms) < self.beta - EPS:             # UBUO2 不夠，剪掉
                continue
            ncl = []
            for y in cl[k + 1:]:
                xy = self.combine(prefix, x, y)
                if xy.batches:
                    ncl.append(xy)
            if ncl:
                self.search(x, ncl, result)                             # 以 x 為前綴往下找

    def upper_bound(self, x, cms):
        """UBUO2：uo + ruo 最大的 ⌈minSup⌉ 筆取平均"""
        vec = sorted((e.uo + e.ruo for e in x.entries()), reverse=True)
        return sum(vec[:cms]) / cms

    def combine(self, p, x, y):
        """合併 Px 和 Py 的節點，得到 Pxy 的（只留兩邊都有的交易）"""
        xy = Node(x.items + y.items[-1:])
        ys = {e.tid: e for e in y.entries()}
        ps = {e.tid: e for e in p.entries()} if p else {}
        for bid, es in x.batches.items():
            for ex in es:
                ey = ys.get(ex.tid)
                if ey is None:
                    continue           # 這筆交易沒有 y
                uo = ex.uo + ey.uo - (ps[ex.tid].uo if p else 0.0)     # P 兩邊都算了，扣掉一次
                e = Entry(ex.tid, uo, min(ex.ruo, ey.ruo))
                xy.batches.setdefault(bid, []).append(e)
                xy.sum_uo += e.uo
                xy.sum_ruo += e.ruo
        return xy



def fmt4(x):
    n = math.floor(x * 10000 + 0.5)    # 自己四捨五入，Java 和 Python 印出來才會一模一樣
    return "%d.%04d" % (n // 10000, n % 10000)


def run(profit, db, batch_size, win_size, alpha_pct, beta_pct):
    """把串流一批一批丟進去，每次視窗滿了就挖一次；回傳每個視窗的結果"""
    h = HUOPS(profit, batch_size, win_size, alpha_pct, beta_pct)
    out = []
    for b in range(len(db) // batch_size):
        h.add_batch(b, db[b * batch_size:(b + 1) * batch_size])
        if len(h.window) == win_size:
            out.append((h.window[:], h.mine()))
    return out


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
    # 每批 2 筆、視窗放 3 批；α = 35%（6 筆 × 35% = 2.1，至少要 3 筆）、β = 65%
    for win, result in run(profit, db, 2, 3, 35, 65):
        print("視窗 B" + "+B".join(str(b + 1) for b in win) + "：")
        for items, (sup, uo) in result.items():
            print("  {" + ", ".join(items) + "} sup = " + str(sup) + "  uo = " + fmt4(uo))
