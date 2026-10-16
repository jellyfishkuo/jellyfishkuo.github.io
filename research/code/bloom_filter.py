"""Bloom Filter：用 m 格和 k 個雜湊函數判斷「這張發票登錄過沒有」（只會誤判成「可能在」）"""
import math

SEED1 = 2166136261              # FNV-1a 的標準起始值
SEED2 = 374761393               # 第二個雜湊換一個起始值，算出另一個數字


def fnv1a(s, seed):
    """FNV-1a 32 位元：把字串的每個位元組 XOR 進去、再乘上質數 16777619"""
    h = seed
    for b in s.encode("utf-8"):
        h ^= b
        h = (h * 16777619) & 0xFFFFFFFF         # 只留 32 位元
    return h


class BloomFilter:
    def __init__(self, m, k, counting=False):
        self.m, self.k = m, k                     # m 格、k 個雜湊函數
        self.counting = counting                  # True：每格是計數器（Counting Bloom Filter，可以刪除）
        self.cells = [0] * m                      # 一般版每格只會是 0 或 1；計數版是計數

    def positions(self, key):
        """第 i 個雜湊函數 g_i = (h1 + i·step) mod m（double hashing：兩個雜湊值湊出 k 個）"""
        h1, h2 = fnv1a(key, SEED1), fnv1a(key, SEED2)
        start = h1 % self.m
        step = 1 + h2 % (self.m - 1)              # 1 ~ m−1，不會原地踏步
        return [(start + i * step) % self.m for i in range(self.k)]

    def add(self, key):
        for c in self.positions(key):
            if self.counting:
                self.cells[c] += 1                # 計數版：+1
            else:
                self.cells[c] = 1                 # 一般版：設成 1（已經是 1 就不變）

    def might_contain(self, key):
        """k 格都不是 0 →「可能在」；看到第一個 0 就可以停 →「一定不在」"""
        for c in self.positions(key):
            if self.cells[c] == 0:
                return False                      # 一定不在
        return True                               # 可能在（也可能是別人剛好把這幾格都設過）

    def remove(self, key):
        """只有計數版可以刪，而且只能刪「真的加過」的"""
        if not self.counting:
            raise ValueError("一般 Bloom Filter 不能刪除")
        for c in self.positions(key):
            self.cells[c] -= 1



def false_positive_rate(m, k, n):
    """理論誤判率：每格還是 0 的機率約 e^(−kn/m)，k 格剛好都被設過的機率"""
    return (1 - math.exp(-k * n / m)) ** k


def test_key(i):
    """拿來測誤判率的發票號碼（ZZ 開頭，範例裡沒有登錄過）"""
    return "ZZ-%08d" % (i * 2654435761 % 100000000)


def measure(bf, added, trials=1000):
    """實測：拿 trials 張沒登錄過的發票去查，有幾張被誤判成「可能在」"""
    wrong, i, tried = 0, 0, 0
    while tried < trials:
        i += 1
        key = test_key(i)
        if key in added:
            continue
        tried += 1
        wrong += bf.might_contain(key)
    return wrong


INVOICES = ["TR-50227071", "GP-02708508", "QP-97769865", "GY-91586091",
            "CC-85488622", "HK-50362354", "GP-49874681", "UX-92068559"]   # 已經登錄過的發票
QUERIES = ["QP-97769865", "QW-58160533", "MN-14419200"]                  # 有登錄過、沒登錄過、沒登錄過
DELETE = "HK-50362354"                                                   # 計數版：取消登錄這一張

if __name__ == "__main__":
    m, k = 24, 3
    for counting in (False, True):
        bf = BloomFilter(m, k, counting)
        for key in INVOICES:
            bf.add(key)
        print(("計數版" if counting else "一般版") + f"：m = {m}、k = {k}、登錄 {len(INVOICES)} 張發票")
        print("  " + " ".join(str(c) for c in bf.cells))
        for key in QUERIES:
            got = bf.might_contain(key)
            truth = key in INVOICES
            print(f"  查 {key}：{'可能在' if got else '一定不在'}（實際{'有' if truth else '沒有'}登錄）"
                  + ("  ← 誤判" if got and not truth else ""))
        n = len(INVOICES)
        ones = sum(1 for c in bf.cells if c)
        print(f"  填滿 {ones}/{m} = {ones / m:.4f}，理論誤判率 (1 − e^(−kn/m))^k = {false_positive_rate(m, k, n):.4f}，"
              f"實測 {measure(bf, set(INVOICES))}/1000")
        print(f"  最佳 k = (m/n)·ln 2 = {m / n * math.log(2):.4f}")
        if counting:
            bf.remove(DELETE)
            left = [x for x in INVOICES if x != DELETE]
            print(f"  刪除 {DELETE} 之後：")
            print("  " + " ".join(str(c) for c in bf.cells))
            print(f"  查 {DELETE}：{'可能在' if bf.might_contain(DELETE) else '一定不在'}")
            print(f"  其他 {len(left)} 張都還是「可能在」：{all(bf.might_contain(x) for x in left)}")
