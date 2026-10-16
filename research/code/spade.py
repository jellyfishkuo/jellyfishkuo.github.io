"""SPADE：把資料轉成垂直格式（id-list），用 temporal join 一路長出序列樣式"""


def spade(db, min_sup):
    """db：每位顧客一個序列，序列裡依時間排好每次來店買的東西（一次可以買好幾樣）"""
    db = [[sorted(set(e)) for e in seq] for seq in db]     # 同一次買的東西照字碼排
    result = {}
    # 只掃一次資料庫：每個商品 → 出現在哪些 (sid, eid)＝第幾位顧客的第幾次來店
    vert = {}
    for sid, seq in enumerate(db):
        for eid, e in enumerate(seq):
            for x in e:
                vert.setdefault(x, []).append((sid, eid))
    atoms = []
    for x in sorted(vert):
        if support(vert[x]) >= min_sup:
            result[((x,),)] = support(vert[x])
            atoms.append((((x,),), vert[x], True))         # True：最後一個商品自己是「新的一次」
    enumerate_class(atoms, min_sup, result)
    return result


def enumerate_class(atoms, min_sup, result):
    """atoms：同一個等價類的成員（前綴都一樣，只差最後接上的那個商品）"""
    for pat_a, list_a, s_a in atoms:                       # 輪流當 A，跟同一類的每個 B 合併
        children = []
        for pat_b, list_b, s_b in atoms:
            y = pat_b[-1][-1]                              # B 最後接上的那個商品
            if s_b == s_a and y > pat_a[-1][-1]:           # I-step：y 跟 A 的最後一個商品同一次買
                keep(children, pat_a[:-1] + (pat_a[-1] + (y,),),
                     equal_join(list_a, list_b), False, min_sup, result)
            if s_b:                                        # S-step：買 A 之後，後來再買 y
                keep(children, pat_a + ((y,),),
                     temporal_join(list_a, list_b), True, min_sup, result)
        enumerate_class(children, min_sup, result)         # A 長出來的樣式自成一類，往下挖


def keep(children, pat, idlist, s, min_sup, result):
    """夠多人就記下來，也放進下一層的等價類"""
    if support(idlist) >= min_sup:
        result[pat] = support(idlist)
        children.append((pat, idlist, s))


def support(idlist):
    return len({sid for sid, _ in idlist})                 # 支持度＝有幾位不同的顧客


def temporal_join(list_a, list_b):
    """S-step：留下 B 的位置 (sid, eid)，條件是同一位顧客在更早的某一次就出現過 A"""
    first = {}
    for sid, eid in list_a:
        first.setdefault(sid, eid)                         # id-list 照 (sid, eid) 排好，第一個就是最早的
    return [(sid, eid) for sid, eid in list_b if sid in first and first[sid] < eid]


def equal_join(list_a, list_b):
    """I-step：同一位顧客、同一次來店，A 和 B 都出現"""
    same = set(list_a)
    return [p for p in list_b if p in same]



def show(pattern):
    return "<" + "".join("(" + ",".join(e) + ")" for e in pattern) + ">"


if __name__ == "__main__":
    db = [
        [["咖啡", "麵包"], ["飯糰", "茶葉蛋"], ["洋芋片"]],
        [["咖啡"], ["飯糰", "茶葉蛋"], ["咖啡", "麵包"]],
        [["咖啡", "麵包"], ["牛奶"], ["飯糰"]],
        [["麵包", "牛奶"], ["咖啡", "麵包"], ["飯糰", "洋芋片"]],
        [["咖啡", "麵包", "茶葉蛋"], ["飯糰", "茶葉蛋"]],
        [["牛奶"], ["麵包"], ["洋芋片"]],
    ]
    for pattern, sup in spade(db, 3).items():
        print(show(pattern), sup)
