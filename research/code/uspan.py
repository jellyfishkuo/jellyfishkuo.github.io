"""USpan：在有數量、有利潤的序列資料庫裡，找出所有高效益序列樣式"""


def uspan(db, profit, min_util):
    """db：每位顧客一個序列，依時間排好每次來店買的東西，寫成 {商品: 數量}"""
    # 1. SWU：每位顧客的總效益 su，加給他買過的每個商品（同一人只加一次）
    su = [sum(q * profit[x] for e in seq for x, q in e.items()) for seq in db]
    swu = {}
    for sid, seq in enumerate(db):
        for x in {x for e in seq for x in e}:
            swu[x] = swu.get(x, 0) + su[sid]
    keep = {x for x in swu if swu[x] >= min_util}             # SWU 不到門檻的商品整個刪掉

    # 2. 每位顧客建一張效益矩陣
    mats = [build_matrix(seq, profit, keep) for seq in db]
    result = {}
    root = {sid: [(-1, 0)] for sid in range(len(db))}         # 空樣式：還沒配對，效益 0
    extend(mats, su, min_util, [], root, result)              # 從空樣式開始長
    return result


def build_matrix(seq, profit, keep):
    """一欄是一次來店，每格 (商品, 效益 u, 剩餘效益 ru)；ru = 排在這格後面的所有效益加起來"""
    cols = [sorted((x, q * profit[x]) for x, q in e.items() if x in keep) for e in seq]
    out, rest = [None] * len(cols), 0
    for k in range(len(cols) - 1, -1, -1):                     # 從最後一次往前加
        col = []
        for x, u in reversed(cols[k]):
            col.append((x, u, rest))
            rest += u
        out[k] = col[::-1]
    return out


def extend(mats, su, min_util, prefix, proj, result):
    """proj = {sid: [(k, acu), ...]}：前綴在第 sid 位顧客可以結束在第 k 次來店，結束在那裡的最大效益是 acu"""
    # 1. 掃投影資料庫：哪些商品能 I-接（同一次）或 S-接（之後某次），順便算 SWU
    last = prefix[-1][-1] if prefix else None                  # 前綴的最後一個商品
    i_swu, s_swu = {}, {}
    for sid, ends in proj.items():
        mat, i_items, s_items = mats[sid], set(), set()
        for k, acu in ends:
            if last is not None and k >= 0:
                i_items.update(x for x, u, ru in mat[k] if x > last)  # 同一次、排在 last 後面
        for k in range(ends[0][0] + 1, len(mat)):              # 最早的結束位置之後的每一次
            s_items.update(x for x, u, ru in mat[k])
        for x in i_items:
            i_swu[x] = i_swu.get(x, 0) + su[sid]
        for x in s_items:
            s_swu[x] = s_swu.get(x, 0) + su[sid]

    # 2. I-接：x 跟前綴最後一次「同一次」買
    for x in sorted(i_swu):
        if i_swu[x] < min_util:                                 # SWU 剪枝：有它的顧客總效益加起來都不夠
            continue
        new = {}
        for sid, ends in proj.items():
            e2 = [(k, acu + u) for k, acu in ends for y, u, ru in mats[sid][k] if y == x]
            if e2:
                new[sid] = e2
        check(mats, su, min_util, prefix[:-1] + [prefix[-1] + [x]], new, result)

    # 3. S-接：x 在「之後某一次」才買
    for x in sorted(s_swu):
        if s_swu[x] < min_util:
            continue
        new = {}
        for sid, ends in proj.items():
            e2, best, j = [], None, 0
            for k, col in enumerate(mats[sid]):
                while j < len(ends) and ends[j][0] < k:         # 結束在第 k 次之前的前綴，取效益最大的
                    best = ends[j][1] if best is None else max(best, ends[j][1])
                    j += 1
                for y, u, ru in col:
                    if y == x and best is not None:
                        e2.append((k, best + u))
            if e2:
                new[sid] = e2
        check(mats, su, min_util, prefix + [[x]], new, result)


def check(mats, su, min_util, pattern, proj, result):
    """算新樣式的效益：每位顧客取最大的對應，再全部加起來"""
    last = pattern[-1][-1]
    util, spu = 0, 0
    for sid, ends in proj.items():
        util += max(acu for k, acu in ends)                     # 好幾種對應：取最大
        bound = [acu + ru for k, acu in ends for y, u, ru in mats[sid][k] if y == last and ru > 0]
        spu += max(bound, default=0)                            # SPU：前綴效益 + 後面還拿得到的全部
    if util >= min_util:
        result[tuple(map(tuple, pattern))] = util
    if spu >= min_util:                                         # SPU 剪枝：不夠就整棵子樹都不用看
        extend(mats, su, min_util, pattern, proj, result)



PROFIT = {"咖啡": 30, "麵包": 15, "牛奶": 20, "飯糰": 10, "茶葉蛋": 5, "洋芋片": 25}


def show(pattern):
    return "<" + "".join("(" + ",".join(e) + ")" for e in pattern) + ">"


if __name__ == "__main__":
    db = [
        [{"咖啡": 1, "麵包": 2}, {"飯糰": 2, "茶葉蛋": 3}, {"咖啡": 2, "洋芋片": 1}],
        [{"咖啡": 2}, {"飯糰": 1, "茶葉蛋": 2}, {"咖啡": 1, "麵包": 1}],
        [{"麵包": 3, "牛奶": 1}, {"牛奶": 2}, {"飯糰": 3}],
        [{"麵包": 1, "牛奶": 2}, {"咖啡": 1, "麵包": 2}, {"飯糰": 1, "洋芋片": 2}],
        [{"咖啡": 3, "麵包": 1, "茶葉蛋": 2}, {"飯糰": 2, "茶葉蛋": 1}],
        [{"牛奶": 1}, {"麵包": 2}, {"洋芋片": 3}],
    ]
    for pattern, util in uspan(db, PROFIT, 200).items():
        print(show(pattern), util)
