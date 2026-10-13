"""Eclat：把交易轉成「商品 → 出現在哪幾筆交易」的垂直格式，再用交集深度優先找出所有頻繁樣式""" «hide»
 «hide»
 «hide»
def eclat(db, min_sup): «start»
    vertical = to_vertical(db)                     # 只掃這一次資料庫 «scan»
    items = [i for i in sorted(vertical)           # 第一層等價類（前綴是空的） «filter1»
             if len(vertical[i]) >= min_sup] «filter1»
    tids = [vertical[i] for i in items] «filter1»
    result = {} «filter1»
    mine([], items, tids, min_sup, result) «filter1»
    return result «end»


def to_vertical(db): «scan{»
    """掃一次資料庫：每個商品記下它出現在哪幾筆交易（交易編號從 1 開始）"""
    vertical = {}
    for tid, t in enumerate(db, start=1):
        for item in t:
            vertical.setdefault(item, []).append(tid)
    return vertical «}scan»


def mine(prefix, items, tids, min_sup, result): «enter»
    """一個等價類：prefix 加上 items[i] 的組合，出現在 tids[i] 這些交易裡""" «enter»
    for i in range(len(items)): «pick»
        pattern = prefix + [items[i]] «pick»
        result[tuple(pattern)] = len(tids[i])      # 交易編號有幾個，支持度就是多少 «pick»
        next_items, next_tids = [], []             # 下一層等價類（前綴是 pattern） «pick»
        for j in range(i + 1, len(items)): «inter»
            t = intersect(tids[i], tids[j]) «inter»
            if len(t) >= min_sup: «inter»
                next_items.append(items[j]) «inter»
                next_tids.append(t) «inter»
        if next_items: «recurse»
            mine(pattern, next_items, next_tids, min_sup, result)  # 往下一層挖 «recurse,enter»


def intersect(a, b): «inter{»
    """兩個排好序的交易編號清單取交集：兩個指標一起往前走"""
    out, p, q = [], 0, 0
    while p < len(a) and q < len(b):
        if a[p] == b[q]:
            out.append(a[p])
            p, q = p + 1, q + 1
        elif a[p] < b[q]:
            p += 1
        else:
            q += 1
    return out «}inter»
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
    for pattern, sup in eclat(db, 3).items():
        print('[' + ', '.join(pattern) + ']', sup) «}hide»
