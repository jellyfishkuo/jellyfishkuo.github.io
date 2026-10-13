"""Lossy Counting：記憶體有限，近似計數資料串流裡每個商品出現幾次（低估不超過 εN）"""
import math

TOL = 1e-9      # 浮點數誤差：(0.4 − 0.1) × 10 會算成 3.0000000000000004

class LossyCounting:
    def __init__(self, eps):
        self.eps = eps                      # 允許的誤差比例 ε
        self.w = math.ceil(1 / eps)         # 桶寬：每 w 筆算一桶
        self.n = 0                          # 到目前為止看過幾筆
        self.table = {}                     # 商品 -> [f 估計次數, Δ 最多漏算幾次]

    def add(self, item):
        self.n += 1
        b = math.ceil(self.n / self.w)      # 現在是第幾桶
        if item in self.table:              # 已經在表裡：次數 +1
            self.table[item][0] += 1
        else:                               # 新來的：之前最多被刪掉過 b-1 次的量
            self.table[item] = [1, b - 1]
        if self.n % self.w == 0:            # 一桶結束：清掉次數太少的
            self.prune(b)

    def prune(self, b):
        """f + Δ ≤ b 的商品，真實次數最多 b 次，先忘掉它"""
        for item in list(self.table):
            f, delta = self.table[item]
            if f + delta <= b:
                del self.table[item]

    def query(self, s):
        """f ≥ (s − ε)N 的都回報：真的頻繁的一個都不會漏"""
        return {x: f for x, (f, d) in self.table.items() if f >= (s - self.eps) * self.n - TOL}


STREAM = [
    "咖啡", "麵包", "咖啡", "布丁", "飯糰",
    "咖啡", "牛奶", "飯糰", "果汁", "咖啡",
    "茶葉蛋", "飯糰", "咖啡", "泡麵", "麵包",
    "咖啡", "飯糰", "巧克力", "茶葉蛋", "咖啡",
    "牛奶", "飯糰", "洋芋片", "咖啡", "茶葉蛋",
    "飯糰", "布丁", "咖啡", "洋芋片", "茶葉蛋",
]

if __name__ == "__main__":
    eps, s = 0.1, 0.2
    lc = LossyCounting(eps)
    true = {}
    for item in STREAM:
        lc.add(item)
        true[item] = true.get(item, 0) + 1
    print(f"串流共 {lc.n} 筆，ε = {eps}（桶寬 w = {lc.w}），s = {s}")
    print(f"表裡還記著 {len(lc.table)} 個商品（出現過 {len(true)} 種）：")
    for x, (f, d) in lc.table.items():
        print(f"  {x}：估計 f = {f}，Δ = {d}，真實 {true[x]} 次")
    print("回報 f ≥ (s - ε)N 的商品：" + "、".join(f"{x} {f}" for x, f in lc.query(s).items()))
    print("真實次數 ≥ sN 的商品：" + "、".join(x for x in true if true[x] >= s * lc.n - TOL))
