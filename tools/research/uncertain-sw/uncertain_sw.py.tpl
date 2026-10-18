"""不確定資料＋滑動視窗：SWUPA（list 結構）一批一批地挖出期望支持度夠高的樣式""" «hide»
from collections import deque «hide»
 «hide»
EPS = 1e-9   # 浮點數誤差的容忍值：比門檻小不到 1e-9 也算達標


class UList:
    """SWUPA-List：一個樣式出現在視窗裡的哪幾筆（TID 由小到大＝由舊到新）、各自的存在機率""" «start{»
    def __init__(self, items):
        self.items = items      # 樣式（商品照處理順序排）
        self.tids = []          # 交易編號，越大越新
        self.eps = []           # 這個樣式在那一筆的存在機率（各商品機率相乘）
        self.exp_sup = 0.0      # 期望支持度 ExpSup：機率加總
        self.max_ep = 0.0       # MaxEP：最大的那個機率

    def add(self, tid, ep):
        self.tids.append(tid)
        self.eps.append(ep)
        self.exp_sup += ep
        self.max_ep = max(self.max_ep, ep)

    def ep_at(self, tid):
        """二分搜尋：這個樣式在 tid 那一筆的機率"""
        lo, hi = 0, len(self.tids) - 1
        while lo < hi:
            mid = (lo + hi) // 2
            if self.tids[mid] < tid: lo = mid + 1
            else: hi = mid
        return self.eps[lo] «}start»


class SWUPA:
    def __init__(self, batch_size, win_batches, delta_pct): «start{»
        self.b = batch_size       # 一批幾筆交易
        self.w = win_batches      # 視窗裝幾批
        self.delta = delta_pct    # 門檻百分比 δ
        self.window = deque()     # 視窗裡的批次，最舊的在最左邊
        self.lists = {}           # 全域 SWUPA-List：商品 -> UList
        self.log = []             # 每一次合併的結果（給網頁和測試對照） «}start»

    def add_batch(self, batch):
        """新的一批進來：視窗滿了先移掉最舊的一批，再把新的一批接到每個串列尾端"""
        if len(self.window) == self.w: «expire»
            self.remove_oldest() «expire»
        self.window.append(batch) «add{»
        for tid, t in batch:
            for item in sorted(t):
                if item not in self.lists:
                    self.lists[item] = UList((item,))
                self.lists[item].add(tid, t[item])   # 新的 TID 最大，接在尾端 «}add»
        if len(self.window) == self.w:   # 視窗滿了才分析 «sort»
            return self.mine() «sort»
        return None

    def remove_oldest(self): «expire{»
        """最舊的一批離開：TID 由小到大排，所以要刪的都在每個串列的最前面"""
        last = self.window.popleft()[-1][0]          # 最舊那批的最後一個 TID
        for item in list(self.lists):
            L = self.lists[item]
            k = 0
            while k < len(L.tids) and L.tids[k] <= last:
                k += 1
            if k == len(L.tids):
                del self.lists[item]                 # 整個串列都空了
                continue
            tids, eps = L.tids[k:], L.eps[k:]
            L.tids, L.eps, L.exp_sup, L.max_ep = [], [], 0.0, 0.0
            for tid, ep in zip(tids, eps):           # MaxEP 不能用減的，剩下的重新算
                L.add(tid, ep) «}expire»

    def mine(self): «sort{»
        """視窗裡的交易數 × δ 是門檻；串列照期望支持度由小到大排，夠的才往下合併"""
        self.min_sup = self.w * self.b * self.delta / 100
        order = sorted(self.lists.values(), key=lambda L: (L.exp_sup, L.items))
        self.max1 = {L.items[0]: L.max_ep for L in order}   # 每個商品在視窗裡的 MaxEP
        valid = [L for L in order if L.exp_sup >= self.min_sup - EPS]
        result = {L.items: L.exp_sup for L in valid} «}sort»
        self.mine_lists(None, valid, result) «sort»
        return result «sort»

    def mine_lists(self, prefix, sl, result): «over{»
        """sl 裡的串列都有同樣的前綴 prefix；兩兩合併成長一個商品的樣式"""
        for k, x in enumerate(sl):
            nxt = []
            for y in sl[k + 1:]:
                last = y.items[-1]
                over = x.exp_sup * self.max1[last]   # 上界 overExpSup = ExpSup(X) × MaxEP(最後一個商品)
                if over < self.min_sup - EPS:
                    self.log.append(("over", x.items + (last,)))
                    continue                          # 連串列都不用建 «}over»
                xy = self.join(prefix, x, y) «join»
                if xy is None: «ppclw»
                    self.log.append(("ppclw", x.items + (last,))) «ppclw»
                    continue «ppclw»
                if xy.exp_sup >= self.min_sup - EPS: «result{»
                    result[xy.items] = xy.exp_sup
                    nxt.append(xy)
                    self.log.append(("ok", xy.items))
                else:
                    self.log.append(("low", xy.items))
            if len(nxt) > 1:                          # 同一個前綴下至少兩個才合併得下去
                self.mine_lists(x, nxt, result) «}result»

    def join(self, prefix, x, y): «join{»
        """兩邊的 TID 一起往前走（two-way comparison），同一筆才算；邊算邊檢查 ppCLw"""
        xy = UList(x.items + (y.items[-1],))
        i = j = 0
        n = len(x.tids)
        while i < n and j < len(y.tids):
            if x.tids[i] == y.tids[j]:
                pe = prefix.ep_at(x.tids[i]) if prefix else 1.0   # 前綴在兩邊各乘了一次，除掉一次
                xy.add(x.tids[i], x.eps[i] * y.eps[j] / pe)
                i += 1
                j += 1
                # ppCLw：剩下 n - i 筆就算每筆都是 MaxEP(X)，加起來還是不到門檻 → 不用比了 «ppclw»
                if i < n and xy.exp_sup + (n - i) * x.max_ep < self.min_sup - EPS: «ppclw»
                    return None «ppclw»
            elif x.tids[i] < y.tids[j]:
                i += 1
            else:
                j += 1
        return xy «}join»


def run(stream, batch_size, win_batches, delta_pct):
    """把交易切成一批一批餵進視窗；視窗每滿一次就印出這個視窗的結果"""
    sw = SWUPA(batch_size, win_batches, delta_pct) «start»
    txs = [(k + 1, t) for k, t in enumerate(stream)]
    batches = [txs[k:k + batch_size] for k in range(0, len(txs) - batch_size + 1, batch_size)] «loop»
    for h, batch in enumerate(batches, 1): «loop»
        sw.log = [] «loop»
        res = sw.add_batch(batch) «loop»
        if res is None: «loop»
            print(f"B{h} 進入視窗（{len(sw.window)}/{win_batches} 批，還沒滿）") «loop»
            continue «loop»
        tids = [tid for b in sw.window for tid, _ in b] «loop»
        print(f"B{h} 進入 → 視窗 T{tids[0]}–T{tids[-1]}，minSup = {sw.min_sup:.2f}") «loop»
        print("  串列順序：" + "、".join(f"{L.items[0]} {L.exp_sup:.2f}" for L in sorted(sw.lists.values(), key=lambda L: (L.exp_sup, L.items)))) «loop»
        for kind, items in sw.log: «loop»
            if kind != "ok": «loop»
                print(f"  {'overExpSup 剪掉' if kind == 'over' else 'ppCLw 中途停' if kind == 'ppclw' else '算完不夠'} {fmt(items)}") «loop»
        for items in sorted(res, key=lambda s: (len(s), sorted(s))): «loop»
            print(f"  ✓ {fmt(items)} {res[items]:.3f}") «loop»


def fmt(items):
    return "{" + ", ".join(sorted(items)) + "}"
 «hide{»

if __name__ == "__main__":
    # 無人商店的攝影機辨識：每樣商品後面是「這筆真的有拿它」的信心
    stream = [
        {"咖啡": 0.9, "麵包": 0.4, "牛奶": 0.4},
        {"咖啡": 0.5, "麵包": 1.0, "茶葉蛋": 0.8},
        {"咖啡": 0.8, "麵包": 0.6, "牛奶": 0.5, "飯糰": 0.3},
        {"麵包": 0.3, "牛奶": 0.4, "洋芋片": 0.9},
        {"咖啡": 0.8, "牛奶": 1.0, "茶葉蛋": 0.8},
        {"咖啡": 0.7, "麵包": 0.3, "牛奶": 0.6, "茶葉蛋": 0.8},
        {"飯糰": 1.0, "茶葉蛋": 0.4, "洋芋片": 0.6},
        {"咖啡": 0.3, "麵包": 1.0, "飯糰": 0.6},
    ]
    run(stream, 2, 2, 30) «}hide»
