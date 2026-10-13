"""Count-Min Sketch：用 d 列 × w 欄的計數表，估計資料串流裡每個商品出現幾次（只會多算）""" «hide»
import math «hide»
 «hide»
P = 101                         # 質數，要比所有商品編號都大 «hash»
A = [90, 67, 79, 56, 33]        # 第 j 列的雜湊函數 h_j(x) = (A[j]·x + B[j]) mod P mod w «hash»
B = [10, 78, 20, 99, 71]        # 參數固定寫死，每次跑、每種語言都落在同一格 «hash»
 «hide»
 «hide»
class CountMin:
    def __init__(self, w, d, conservative=False): «start{»
        self.w, self.d = w, d                     # w 欄、d 列（d 最多 5，因為只準備了 5 組參數）
        self.conservative = conservative          # 要不要用保守更新（conservative update）
        self.n = 0                                # 到目前為止看過幾筆
        self.table = [[0] * w for _ in range(d)]  # 計數表，一開始全部是 0 «}start»

    def h(self, j, x): «hash{»
        """第 j 列的雜湊函數：商品編號 x 落在第幾欄"""
        return (A[j] * x + B[j]) % P % self.w «}hash»

    def add(self, x):
        self.n += 1 «arrive»
        if not self.conservative: «inc,cu»
            for j in range(self.d):               # 每一列各 +1 一格 «inc»
                self.table[j][self.h(j, x)] += 1 «inc»
        else: «cu»
            m = self.estimate(x)                  # 保守更新：先查目前的估計值 m «cu»
            for j in range(self.d):               # 只把比 m+1 小的格子補到 m+1，其他不動 «cu»
                c = self.h(j, x) «cu»
                self.table[j][c] = max(self.table[j][c], m + 1) «cu»

    def estimate(self, x): «query{»
        """d 格裡取最小值：撞格子只會讓格子變大，所以最小的那格最接近真實"""
        return min(self.table[j][self.h(j, x)] for j in range(self.d)) «}query»
 «hide{»

ITEMS = ["咖啡", "麵包", "牛奶", "飯糰", "茶葉蛋", "洋芋片", "果汁", "布丁", "泡麵", "巧克力"]   # 商品編號 = 位置 + 1

STREAM = [
    "咖啡", "麵包", "咖啡", "布丁", "飯糰",
    "咖啡", "牛奶", "飯糰", "果汁", "咖啡",
    "茶葉蛋", "飯糰", "咖啡", "泡麵", "麵包",
    "咖啡", "飯糰", "巧克力", "茶葉蛋", "咖啡",
    "牛奶", "飯糰", "洋芋片", "咖啡", "茶葉蛋",
    "飯糰", "布丁", "咖啡", "洋芋片", "茶葉蛋",
]

if __name__ == "__main__":
    w, d = 5, 3
    eps, delta = math.e / w, math.exp(-d)       # w = ⌈e/ε⌉、d = ⌈ln(1/δ)⌉ 反過來算
    for conservative in (False, True):
        cm = CountMin(w, d, conservative)
        true = {}
        for item in STREAM:
            cm.add(ITEMS.index(item) + 1)
            true[item] = true.get(item, 0) + 1
        print(f"串流共 {cm.n} 筆，w = {w}、d = {d}（ε = e/w = {eps:.3f}、δ = e^-d = {delta:.3f}），"
              + ("保守更新" if conservative else "一般更新"))
        for row in cm.table:
            print("  " + " ".join(f"{c:3d}" for c in row))
        over = 0
        for i, item in enumerate(ITEMS):
            est, t = cm.estimate(i + 1), true.get(item, 0)
            over += est - t > eps * cm.n
            print(f"  {item}（編號 {i + 1}）：估計 {est}，真實 {t}，多算 {est - t}")
        print(f"  多算超過 εN = {eps * cm.n:.2f} 的商品：{over} 個") «}hide»
