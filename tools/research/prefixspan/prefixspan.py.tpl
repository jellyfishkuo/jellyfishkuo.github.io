"""PrefixSpan：用「前綴投影」遞迴找出所有頻繁的序列樣式""" «hide»
 «hide»
 «hide»
def prefix_span(db, min_sup): «start{»
    """db：每位顧客一個序列，序列裡依時間排好每次來店買的東西（一次可以買好幾樣）"""
    db = [[sorted(set(e)) for e in seq] for seq in db]   # 同一次買的東西照字碼排
    result = {}
    proj = [(sid, -1, -1) for sid in range(len(db))]     # 還沒配對任何東西：整個序列都是後綴
    mine(db, min_sup, [], proj, result) «end»
    return result «}start,end»


def mine(db, min_sup, prefix, proj, result):
    """proj 裡每一筆 (sid, e, p)：前綴的最後一個商品配對在第 sid 位顧客、第 e 次來店的第 p 個位置"""
    # 1. 掃一遍投影資料庫，數每個商品能怎麼接在前綴後面 «scan»
    last = prefix[-1] if prefix else None                 # 前綴的最後一次（一個 itemset） «scan»
    i_cnt, s_cnt = {}, {} «scan»
    for sid, e, p in proj: «scan»
        seq = db[sid] «scan»
        i_seen, s_seen = set(), set()                     # 同一位顧客只算一次 «scan»
        if last: «scan,iscan»
            i_seen.update(seq[e][p + 1:])                 # 底線 _ 那一格：跟前綴最後一個商品同一次買的 «iscan»
            for k in range(e + 1, len(seq)):              # 後面某次也買齊了 last，排在後面的也算同一次 «iscan»
                if set(last) <= set(seq[k]): «iscan»
                    i_seen.update(x for x in seq[k] if x > last[-1]) «iscan»
        for k in range(e + 1, len(seq)):                  # 之後任何一次來店買的：下一次才買 «scan,sscan»
            s_seen.update(seq[k]) «scan,sscan»
        for x in i_seen: «scan»
            i_cnt[x] = i_cnt.get(x, 0) + 1 «scan»
        for x in s_seen: «scan»
            s_cnt[x] = s_cnt.get(x, 0) + 1 «scan»

    # 2. 夠多人的就接上去，變成新的樣式，再用它的投影資料庫遞迴 «loop»
    for x in sorted(i_cnt):                               # i-延伸：x 跟前綴最後一次「同一次」買 «iext»
        if i_cnt[x] >= min_sup: «iext»
            pattern = prefix[:-1] + [last + [x]] «iext»
            result[tuple(map(tuple, pattern))] = i_cnt[x] «iext»
            mine(db, min_sup, pattern, project(db, proj, last, x, True), result)  # 遞迴 «iext,recurse»
    for x in sorted(s_cnt):                               # s-延伸：x 在「下一次以後」才買 «sext»
        if s_cnt[x] >= min_sup: «sext»
            pattern = prefix + [[x]] «sext»
            result[tuple(map(tuple, pattern))] = s_cnt[x] «sext»
            mine(db, min_sup, pattern, project(db, proj, last, x, False), result)  # 遞迴 «sext,recurse»


def project(db, proj, last, x, same): «project{»
    """把每位顧客的投影點往後移到「第一個」能接上 x 的位置；接不上的顧客就不要了"""
    out = []
    for sid, e, p in proj:
        seq = db[sid]
        for k in range(e if same else e + 1, len(seq)):
            if x not in seq[k]:
                continue
            q = seq[k].index(x)
            if same and not (set(last) <= set(seq[k]) and q > seq[k].index(last[-1])):
                continue                                  # 同一次延伸：這次要買齊 last，x 還要排在後面
            out.append((sid, k, q))
            break
    return out «}project»
 «hide{»


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
    for pattern, sup in prefix_span(db, 3).items():
        print(show(pattern), sup) «}hide»
