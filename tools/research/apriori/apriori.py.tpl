"""Apriori：一層一層找出所有頻繁樣式（同時出現次數 >= min_sup 的商品組合）""" «hide»
from itertools import combinations «hide»
 «hide»
 «hide»
def apriori(db, min_sup): «start»
    result = []
    L = frequent_items(db, min_sup)               # L1：單一商品 «L1»
    k = 2 «loop»
    while L: «loop»
        result += L «loop»
        C = join(L, k)                            # ① 合併 «join»
        C = [c for c in C if not has_infrequent_subset(c, L)]  # ② 剪枝 «prune»
        count = count_support(db, C)              # ③ 計數 «count»
        L = [c for c in C if count[c] >= min_sup]  # ④ 篩選 «filter»
        k += 1 «filter»
    return result «end»


def frequent_items(db, min_sup): «L1{»
    """掃一次資料庫，數每個商品出現幾次"""
    count = {}
    for t in db:
        for item in t:
            count[item] = count.get(item, 0) + 1
    return [(item,) for item in sorted(count) if count[item] >= min_sup] «}L1»


def join(L, k): «join{»
    """兩個 k-1 個的樣式，前 k-2 個都一樣，才合併成 k 個的候選"""
    C = []
    for i in range(len(L)):
        for j in range(i + 1, len(L)):
            a, b = L[i], L[j]
            if a[:k - 2] == b[:k - 2]:
                C.append(a + (b[-1],))
    return C «}join»


def has_infrequent_subset(c, L): «prune{»
    """只要有一個 k-1 個的子集合不頻繁，這個候選就不可能頻繁"""
    frequent = set(L)
    for sub in combinations(c, len(c) - 1):
        if sub not in frequent:
            return True
    return False «}prune»


def count_support(db, C): «count{»
    """再掃一次資料庫，數每個候選出現在幾筆交易裡"""
    count = {c: 0 for c in C}
    for t in db:
        for c in C:
            if set(c) <= t:
                count[c] += 1
    return count «}count»
 «hide{»

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
    for pattern in apriori(db, 3):
        print(pattern) «}hide»
