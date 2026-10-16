"""HyperLogLog：只用 m 個小暫存器，估計串流裡有幾個「不同的」會員（Flajolet 等人，2007）"""
import math

MASK = 0xFFFFFFFF                      # 只留 32 位元


def hash32(s):
    """FNV-1a 32 位元，再用 murmur3 的 fmix32 把位元攪勻（前幾個位元也要夠亂）"""
    h = 2166136261
    for b in s.encode("utf-8"):
        h = ((h ^ b) * 16777619) & MASK
    h ^= h >> 16
    h = (h * 0x85EBCA6B) & MASK
    h ^= h >> 13
    h = (h * 0xC2B2AE35) & MASK
    h ^= h >> 16
    return h


def alpha(m):
    """修正係數 α_m：調和平均本身會偏高，乘上它拉回來"""
    if m == 16: return 0.673
    if m == 32: return 0.697
    if m == 64: return 0.709
    return 0.7213 / (1 + 1.079 / m)


class HyperLogLog:
    def __init__(self, p):
        self.p = p                          # 用雜湊值的前 p 個位元選暫存器
        self.m = 1 << p                     # m = 2^p 個暫存器
        self.M = [0] * self.m               # 每格記「看過最長的開頭 0」+1，一開始全是 0

    def add(self, key):
        h = hash32(key)
        j = h >> (32 - self.p)              # 前 p 位元 → 第 j 個暫存器
        w = (h << self.p) & MASK            # 剩下的 32−p 位元，移到最左邊
        rho = 32 - self.p + 1 if w == 0 else 32 - w.bit_length() + 1   # 開頭幾個 0，再 +1
        if rho > self.M[j]:
            self.M[j] = rho                 # 只留最大值：同一個人再來，值一樣，不會變

    def estimate(self):
        m = self.m
        total = sum(2.0 ** -r for r in self.M)     # Σ 2^(−M[j])
        zeros = self.M.count(0)                    # 還沒被用到的暫存器
        e = alpha(m) * m * m / total               # 調和平均：E = α·m²／Σ
        if e <= 2.5 * m and zeros > 0:
            return m * math.log(m / zeros)         # 人很少：改用 linear counting
        if e > (1 << 32) / 30:
            return -(1 << 32) * math.log(1 - e / (1 << 32))   # 快把 32 位元用完：修正碰撞
        return e

    def merge(self, other):
        """兩家分店的 HLL 合併：每格取最大值 = 把兩邊的來客一起丟進去"""
        for j in range(self.m):
            self.M[j] = max(self.M[j], other.M[j])



def detail(hll, key):
    """給 main 印出來看：這位會員的雜湊、第幾格、ρ"""
    h = hash32(key)
    j = h >> (32 - hll.p)
    w = (h << hll.p) & MASK
    rho = 32 - hll.p + 1 if w == 0 else 32 - w.bit_length() + 1
    return h, j, rho


def member(k):
    """實驗用的會員卡號：k 不同，卡號就不同"""
    return "M-%08d" % (k * 2654435761 % 100000000)


STORE_A = ["M-07912728", "M-29287351", "M-38578460", "M-07912728", "M-17359750", "M-99101455",
           "M-29287351", "M-33234300", "M-53404922", "M-52472380", "M-66640001", "M-38578460"]   # A 店今天的來客順序
STORE_B = ["M-67098887", "M-29287351", "M-76880921", "M-01950523", "M-33234300", "M-83880784",
           "M-66640001", "M-88887737"]                                                            # B 店（有 3 位也去過 A 店）

if __name__ == "__main__":
    p = 4
    a = HyperLogLog(p)
    print(f"A 店：p = {p}、m = {a.m} 個暫存器，來客 {len(STORE_A)} 次")
    for key in STORE_A:
        h, j, rho = detail(a, key)
        before = a.M[j]
        a.add(key)
        bits = format(h, "032b")
        print(f"  {key}  {bits[:p]} {bits[p:]}  第 {j:2d} 格  ρ = {rho}  M[{j}] {before} → {a.M[j]}")
    print("  暫存器：" + " ".join(str(r) for r in a.M))
    total = sum(2.0 ** -r for r in a.M)
    raw = alpha(a.m) * a.m * a.m / total
    print(f"  Σ2^(−M) = {total:.6f}，空格 V = {a.M.count(0)}，調和平均 E = {raw:.4f}")
    print(f"  估計 {a.estimate():.4f} 人，實際 {len(set(STORE_A))} 人")

    b = HyperLogLog(p)
    for key in STORE_B:
        b.add(key)
    print(f"B 店：暫存器 " + " ".join(str(r) for r in b.M))
    print(f"  估計 {b.estimate():.4f} 人，實際 {len(set(STORE_B))} 人")
    a.merge(b)
    print(f"合併（每格取最大）：" + " ".join(str(r) for r in a.M))
    print(f"  估計 {a.estimate():.4f} 人，實際兩店合計不同 {len(set(STORE_A) | set(STORE_B))} 人")

    n, distinct = 100000, 70000
    visits = [member(i * 37 % distinct) for i in range(n)]
    print(f"大量測試：{n} 次來店、{len(set(visits))} 位不同會員")
    for p in range(4, 11):
        hll, half1, half2 = HyperLogLog(p), HyperLogLog(p), HyperLogLog(p)
        for i, key in enumerate(visits):
            hll.add(key)
            (half1 if i % 2 == 0 else half2).add(key)
        half1.merge(half2)
        est = hll.estimate()
        print(f"  p = {p:2d}  m = {hll.m:4d}  估計 {est:10.2f}  誤差 {(est - distinct) / distinct * 100:+7.2f}%"
              f"  理論標準誤差 1.04/√m = {1.04 / math.sqrt(hll.m) * 100:5.2f}%  拆兩半再合併相同：{half1.M == hll.M}")
