"""Two-Phase：先用 TWU 一層一層找出候選，再掃一次資料庫算真正的效益，留下高效益樣式""" «hide»
from itertools import combinations «hide»
 «hide»
 «hide»
def two_phase(db, profit, min_util): «start»
    # ── 第一階段 ── 第 1 次掃描：每筆交易的效益 TU，加進它裡面每個商品的 TWU «tu»
    tu = [sum(q * profit[item] for item, q in t.items()) for t in db] «tu»
    twu = {} «tu»
    for t, u in zip(db, tu): «tu»
        for item in t: «tu»
            twu[item] = twu.get(item, 0) + u «tu»
    # TWU 夠的商品照 TWU 由小到大排，就是第 1 層 «L1»
    order = sorted((i for i in twu if twu[i] >= min_util), key=lambda i: (twu[i], i)) «L1»
    L = [(item,) for item in order] «L1»
    cands = list(L)                    # 所有 TWU 夠的組合（HTWUI），留給第二階段驗證 «L1»
    k = 2 «loop»
    while L: «loop»
        C = join(L, k)                                   # ① 合併 «join»
        C = [c for c in C if not has_low_subset(c, L)]    # ② 剪枝 «prune»
        if not C: «prune»
            break «prune»
        c_twu = count_twu(db, tu, C)                      # ③ 再掃一次，算 TWU «count»
        L = [c for c in C if c_twu[c] >= min_util]        # ④ 篩選 «filter»
        cands += L «filter»
        k += 1 «filter»
    # ── 第二階段 ── 最後再掃一次，算每個候選真正的效益 «phase2»
    util = count_utility(db, profit, cands) «phase2»
    result = {c: util[c] for c in cands if util[c] >= min_util}   # 真的夠才輸出 «verify»
    return result «end»


def join(L, k): «join{»
    """兩個 k-1 個的組合，前 k-2 個都一樣，才合併成 k 個的候選"""
    C = []
    for i in range(len(L)):
        for j in range(i + 1, len(L)):
            a, b = L[i], L[j]
            if a[:k - 2] == b[:k - 2]:
                C.append(a + (b[-1],))
    return C «}join»


def has_low_subset(c, L): «prune{»
    """只要有一個 k-1 個的子集合 TWU 不夠，這個候選的 TWU 也一定不夠"""
    ok = set(L)
    for sub in combinations(c, len(c) - 1):
        if sub not in ok:
            return True
    return False «}prune»


def count_twu(db, tu, C): «count{»
    """掃一次資料庫：包含候選的交易，TU 加起來就是它的 TWU"""
    twu = {c: 0 for c in C}
    for t, u in zip(db, tu):
        for c in C:
            if all(item in t for item in c):
                twu[c] += u
    return twu «}count»


def count_utility(db, profit, cands): «phase2{»
    """掃一次資料庫：包含候選的交易，只加候選裡那幾樣的「數量 × 利潤」"""
    util = {c: 0 for c in cands}
    for t in db:
        for c in cands:
            if all(item in t for item in c):
                util[c] += sum(t[item] * profit[item] for item in c)
    return util «}phase2»
 «hide{»

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
    for items, u in two_phase(db, profit, 250).items():
        print("{" + ", ".join(items) + "} 效益 =", u) «}hide»
