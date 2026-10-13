"""CHARM：用垂直格式（每個商品出現在哪幾筆交易）找出所有封閉頻繁樣式，再從裡面挑出最大頻繁樣式""" «hide»
 «hide»
 «hide»
def charm(db, min_sup): «start»
    """回傳 [(商品組合, 支持度), ...]：所有封閉頻繁樣式"""
    tidset = {}                                    # 垂直格式：商品 → 出現在哪幾筆 «vertical»
    for tid, t in enumerate(db, 1): «vertical»
        for item in t: «vertical»
            tidset.setdefault(item, set()).add(tid) «vertical»
    P = [(frozenset([item]), tids) for item, tids in tidset.items() «order»
         if len(tids) >= min_sup]                  # 只留頻繁的商品 «order»
    P.sort(key=lambda p: (len(p[1]), sorted(p[0])))  # 支持度小的排前面 «order»
    closed = []
    extend(P, min_sup, closed)
    return closed «end»


def extend(P, min_sup, closed):
    """P 是同一個前綴底下的一群樣式（一個「類別」），兩兩比 tidset"""
    i = 0 «pick»
    while i < len(P): «pick»
        X, tX = P[i] «pick»
        new_class = []                             # 以 X 為前綴、往下長的新類別 «pick»
        j = i + 1 «pick»
        while j < len(P): «pair»
            Xj, tj = P[j] «pair»
            Y = tX & tj                            # X ∪ Xj 出現在哪幾筆 «pair»
            if len(Y) < min_sup:                   # 不頻繁：不用管 «infreq»
                j += 1 «infreq»
            elif tX == tj:                         # 性質 1：一樣 → 合併，Xj 刪掉 «p1»
                X = X | Xj «p1»
                del P[j] «p1»
            elif tX < tj:                          # 性質 2：t(X) ⊂ t(Xj) → Xj 吸收進 X «p2»
                X = X | Xj «p2»
                j += 1 «p2»
            elif tX > tj:                          # 性質 3：t(X) ⊃ t(Xj) → 新候選，Xj 刪掉 «p3»
                new_class.append((Xj, Y)) «p3»
                del P[j] «p3»
            else:                                  # 性質 4：互不包含 → 新候選 «p4»
                new_class.append((Xj, Y)) «p4»
                j += 1 «p4»
        if new_class:                              # 往下一層：每個候選都補上最後的 X «recurse»
            extend([(X | Xj, Y) for Xj, Y in new_class], min_sup, closed) «recurse»
        if not is_subsumed(X, len(tX), closed):     # 子集合檢查 «check»
            closed.append((tuple(sorted(X)), len(tX))) «check»
        i += 1 «check»


def is_subsumed(X, sup, closed): «check{»
    """已經找到一個支持度一樣、而且包含 X 的封閉樣式 → X 不是封閉的"""
    return any(s == sup and X <= set(c) for c, s in closed) «}check»


def maximal(closed): «maxfind{»
    """最大頻繁樣式：沒有任何（封閉）頻繁樣式比它大"""
    return [(c, s) for c, s in closed
            if not any(set(c) < set(d) for d, _ in closed)] «}maxfind»
 «hide{»


def fmt(c):
    return "{" + ", ".join(c) + "}"


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
    closed = charm(db, 2)
    print(f"封閉頻繁樣式（{len(closed)} 個，照找到的順序）")
    for c, s in closed:
        print(f"  {fmt(c)} 支持度 {s}")
    mx = maximal(closed)
    print(f"最大頻繁樣式（{len(mx)} 個）")
    for c, s in mx:
        print(f"  {fmt(c)} 支持度 {s}") «}hide»
