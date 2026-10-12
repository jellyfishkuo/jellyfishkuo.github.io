"""空間共位樣式探勘：哪些類型的店常常開在彼此附近"""



def near(p, q, r):
    """兩點距離 ≤ r 就算鄰近（用平方比，不用開根號）"""
    return (p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 <= r * r


def co_locations(points, r, min_prev):
    """points: [(x, y, 類型)]；回傳 {樣式(類型 tuple): 參與指數 PI}"""
    types = list(dict.fromkeys(t for _, _, t in points))     # 類型照第一次出現的順序
    total = {t: sum(1 for p in points if p[2] == t) for t in types}
    # 大小 1：每個點自己就是一個實例
    inst = {(t,): [(i,) for i, p in enumerate(points) if p[2] == t] for t in types}
    result = {}
    while inst:
        prev, nxt = list(inst), {}
        for a in range(len(prev)):
            for b in range(a + 1, len(prev)):
                P, Q = prev[a], prev[b]
                if P[:-1] != Q[:-1]:        # 前面的類型一樣才合併
                    continue
                cand = P + Q[-1:]
                if any(cand[:i] + cand[i + 1:] not in inst for i in range(len(cand))):
                    continue                # 剪枝：有子樣式不是共位樣式
                # 列實例：前面的點相同、最後兩個點又相鄰 → 兩兩都相鄰
                rows = [x + y[-1:] for x in inst[P] for y in inst[Q]
                        if x[:-1] == y[:-1] and near(points[x[-1]], points[y[-1]], r)]
                pi = participation_index(cand, rows, total)
                if pi >= min_prev:          # 達到門檻：是共位樣式
                    nxt[cand] = rows
                    result[cand] = pi
        inst = nxt                          # 只有共位樣式能再長大
    return result


def participation_index(cand, rows, total):
    pi = 1.0
    for j, t in enumerate(cand):
        part = {row[j] for row in rows}     # 有參與的 t 點（不重複）
        pi = min(pi, len(part) / total[t])  # PR(t)，取最小的就是 PI
    return pi


POINTS = [
    (26, 54, "超商"), (38, 36, "超商"), (54, 74, "超商"), (84, 56, "超商"),
    (108, 76, "超商"), (60, 114, "超商"), (12, 96, "超商"), (90, 26, "超商"),
    (20, 60, "公車站"), (44, 30, "公車站"), (48, 68, "公車站"), (78, 62, "公車站"),
    (102, 68, "公車站"), (96, 22, "公車站"), (44, 102, "公車站"), (100, 106, "公車站"),
    (84, 14, "咖啡店"), (110, 36, "咖啡店"), (118, 12, "咖啡店"), (70, 40, "咖啡店"),
    (60, 62, "咖啡店"), (22, 104, "咖啡店"), (72, 110, "咖啡店"),
    (88, 42, "飲料店"), (112, 22, "飲料店"), (74, 30, "飲料店"), (26, 70, "飲料店"),
    (110, 62, "飲料店"), (40, 42, "飲料店"), (16, 18, "飲料店"), (62, 64, "飲料店"),
]

if __name__ == "__main__":
    print("r = 16，門檻 minPrev = 0.5")
    for pattern, pi in co_locations(POINTS, 16, 0.5).items():
        print("[" + ", ".join(pattern) + f"] PI = {pi:.3f}")
