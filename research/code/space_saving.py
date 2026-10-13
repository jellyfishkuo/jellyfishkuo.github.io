"""Space-Saving：只用 k 個計數器，近似計數資料串流裡每個商品出現幾次（高估不超過 N/k）"""

TOL = 1e-9      # 浮點數誤差：小數乘法不一定剛好（0.1 × 3 會算成 0.30000000000000004）


class SpaceSaving:
    def __init__(self, k):
        self.k = k                          # 最多只能同時記 k 個商品
        self.n = 0                          # 到目前為止看過幾筆
        self.slots = []                     # 每一格 [商品, 估計次數, 誤差]

    def add(self, item):
        self.n += 1
        for slot in self.slots:             # 已經在記：次數 +1
            if slot[0] == item:
                slot[1] += 1
                return
        if len(self.slots) < self.k:        # 還有空格：直接記
            self.slots.append([item, 1, 0])
            return
        m = min_slot(self.slots)            # 格子滿了：找次數最小的那格
        c = self.slots[m][1]
        self.slots[m] = [item, c + 1, c]    # 踢掉它，新商品接手：次數 c+1、誤差 c

    def query(self, s):
        """估計次數 ≥ sN 的都回報；次數 − 誤差 ≥ sN 的一定是真的頻繁"""
        return [(x, c, e) for x, c, e in self.slots if c >= s * self.n - TOL]


def min_slot(slots):
    """次數最小的那格；一樣小的話取最前面那格"""
    m = 0
    for i in range(1, len(slots)):
        if slots[i][1] < slots[m][1]:
            m = i
    return m


STREAM = [
    "咖啡", "麵包", "咖啡", "布丁", "飯糰",
    "咖啡", "牛奶", "飯糰", "果汁", "咖啡",
    "茶葉蛋", "飯糰", "咖啡", "泡麵", "麵包",
    "咖啡", "飯糰", "巧克力", "茶葉蛋", "咖啡",
    "牛奶", "飯糰", "洋芋片", "咖啡", "茶葉蛋",
    "飯糰", "布丁", "咖啡", "洋芋片", "茶葉蛋",
]

if __name__ == "__main__":
    k, s = 5, 0.2
    ss = SpaceSaving(k)
    true = {}
    for item in STREAM:
        ss.add(item)
        true[item] = true.get(item, 0) + 1
    print(f"串流共 {ss.n} 筆，k = {k} 個計數器，s = {s}")
    for i, (x, c, e) in enumerate(ss.slots, 1):
        print(f"  第 {i} 格 {x}：估計 {c}，誤差 {e}，真實 {true[x]} 次")
    print("回報次數 ≥ sN 的商品：" + "、".join(f"{x} {c}" + ("（保證）" if c - e >= s * ss.n - TOL else "") for x, c, e in ss.query(s)))
    print("真實次數 ≥ sN 的商品：" + "、".join(x for x in true if true[x] >= s * ss.n - TOL))
