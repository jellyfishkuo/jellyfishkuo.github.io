"""GSP：像 Apriori 一樣一層一層產生候選序列、掃資料庫計數"""


def gsp(db, min_sup):
    """db：每位顧客一個序列，序列裡依時間排好每次來店買的東西（一次可以買好幾樣）"""
    db = [[sorted(set(e)) for e in seq] for seq in db]     # 同一次買的東西照字碼排
    result = {}
    # 第 1 次掃描：每個商品有幾位顧客買過（一個人買幾次都只算 1）
    cnt = {}
    for seq in db:
        for x in set(x for e in seq for x in e):
            cnt[x] = cnt.get(x, 0) + 1
    level = {((x,),): n for x, n in sorted(cnt.items()) if n >= min_sup}
    k = 1
    while level:                                           # 上一層還有頻繁樣式，就往上找
        result.update(level)
        k += 1
        cands = join(list(level), k)                       # ① 合併：拼出 k 個商品的候選
        cands = [c for c in cands                          # ② 剪枝：連續子序列都要頻繁
                 if all(s in level for s in contiguous_subs(c))]
        counts = {c: sum(contains(seq, c) for seq in db)   # ③ 掃一次資料庫，數每個候選
                  for c in cands}
        level = {c: n for c, n in counts.items() if n >= min_sup}   # ④ 留下夠多人的
    return result


def join(level, k):
    """把兩個 (k-1) 個商品的樣式拼成 k 個商品的候選"""
    out = []
    if k == 2:                                             # 兩個商品 x、y 有兩種拼法
        items = [p[0][0] for p in level]
        for x in items:
            for y in items:
                out.append(((x,), (y,)))                   # <(x)(y)>：買 x 之後再買 y（x、y 可以一樣）
                if x < y:
                    out.append(((x, y),))                  # <(x y)>：同一次一起買
        return out
    for a in level:
        for b in level:
            if drop_first(a) == drop_last(b):              # a 去掉第一個商品 == b 去掉最後一個商品
                y = b[-1][-1]
                if len(b[-1]) == 1:
                    out.append(a + ((y,),))                # y 在 b 裡是自己一次 → 接成新的一次
                else:
                    out.append(a[:-1] + (a[-1] + (y,),))   # y 在 b 裡跟別的同一次買 → 放進 a 的最後一次
    return out


def drop_first(p):
    return ((p[0][1:],) if len(p[0]) > 1 else ()) + p[1:]


def drop_last(p):
    return p[:-1] + ((p[-1][:-1],) if len(p[-1]) > 1 else ())


def contiguous_subs(c):
    """連續子序列：從第一次或最後一次拿掉一個商品，或從買了 2 樣以上的那一次拿掉一個"""
    out = []
    for i, e in enumerate(c):
        if len(e) == 1 and 0 < i < len(c) - 1:
            continue                                       # 中間只買 1 樣的那次不能拿掉（前後就不連續了）
        for x in e:
            rest = tuple(y for y in e if y != x)
            out.append(c[:i] + ((rest,) if rest else ()) + c[i + 1:])
    return out


def contains(seq, pat):
    """由前往後比對：pat 的每一次都要依序被 seq 的某一次整個包含"""
    i = 0
    for e in seq:
        if i < len(pat) and set(pat[i]) <= set(e):
            i += 1
    return i == len(pat)



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
    for pattern, sup in gsp(db, 3).items():
        print(show(pattern), sup)
