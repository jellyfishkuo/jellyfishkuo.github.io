"""關聯規則：從頻繁樣式 Z 切出「前件 X → 後件 Y」，留下信賴度夠高的，並算提升度"""
from itertools import combinations


def gen_rules(db, min_sup, min_conf):
    sup = frequent_itemsets(db, min_sup)      # 先用 Apriori 找頻繁樣式和次數
    rules = []
    for z in sup:
        if len(z) < 2:
            continue                          # 一個商品切不出規則
        H = [(i,) for i in z]                 # 後件先從 1 個商品開始
        m = 1
        while H and m < len(z):               # 前件至少要留 1 個
            passed = []
            for y in H:
                x = tuple(i for i in z if i not in y)  # 前件 = Z 拿掉後件
                conf = sup[z] / sup[x]
                if conf >= min_conf:
                    lift = conf / (sup[y] / len(db))
                    rules.append((x, y, sup[z], conf, lift))
                    passed.append(y)
            H = grow(passed, m + 1)           # 只拿過關的後件拼成大一號的
            m += 1
    return rules


def frequent_itemsets(db, min_sup):
    """Apriori（細節見上一頁）：回傳 {頻繁樣式: 出現次數}，一層一層、同層照字典順序"""
    sup = {}
    C = [(i,) for i in sorted({i for t in db for i in t})]
    while C:
        L = []
        for c in C:
            n = sum(1 for t in db if set(c) <= t)
            if n >= min_sup:
                L.append(c)
                sup[c] = n
        C = grow(L, len(C[0]) + 1)            # 同一套合併＋剪枝
    return sup


def grow(H, k):
    """合併＋剪枝：兩個前 k-2 個相同的拼成 k 個，而且它每個 k-1 個的子集合都要在 H 裡"""
    ok = set(H)
    C = []
    for i in range(len(H)):
        for j in range(i + 1, len(H)):
            a, b = H[i], H[j]
            if a[:k - 2] != b[:k - 2]:
                continue
            c = a + (b[-1],)
            # 子集合沒過關，c 一定也過不了
            if all(sub in ok for sub in combinations(c, k - 1)):
                C.append(c)
    return C


if __name__ == "__main__":
    db = [
        {"咖啡", "麵包", "牛奶"},
        {"咖啡", "麵包", "茶葉蛋"},
        {"咖啡", "麵包", "牛奶", "飯糰"},
        {"麵包", "牛奶", "洋芋片"},
        {"咖啡", "牛奶", "茶葉蛋"},
        {"咖啡", "麵包", "牛奶", "茶葉蛋"},
        {"飯糰", "茶葉蛋", "洋芋片"},
        {"咖啡", "麵包", "飯糰"},
    ]
    for x, y, s, conf, lift in gen_rules(db, 3, 0.7):
        print(f"[{', '.join(x)}] -> [{', '.join(y)}]  支持度={s} 信賴度={conf:.2f} 提升度={lift:.2f}")
