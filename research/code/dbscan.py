"""DBSCAN 密度分群（Ester et al., 1996）：鄰居夠多的點長成一群，不用先說要分幾群"""
from collections import deque

UNSEEN, NOISE = 0, -1   # 標籤：0 = 還沒看過、-1 = 雜訊、1, 2, 3… = 第幾群


def dbscan(points, eps, min_pts):
    """points: [(x, y)]；回傳每個點的標籤"""
    label = [UNSEEN] * len(points)          # 一開始全部是 0（還沒看過）
    c = 0                                   # 目前開到第幾群
    for p in range(len(points)):            # 照編號順序看每個點
        if label[p] != UNSEEN:              # 已經被某一群收走了，跳過
            continue
        nb = neighbors(points, p, eps)
        if len(nb) < min_pts:               # 鄰居不夠：先標成雜訊（之後可能被收編）
            label[p] = NOISE
            continue
        c += 1                              # p 是核心點：開一個新的群
        label[p] = c
        queued = {p}                        # 排過隊的點不再排第二次
        queue = deque()
        for q in nb:                        # 還沒歸屬（沒看過或雜訊）的鄰居排進佇列
            if q not in queued and label[q] <= 0:
                queued.add(q)
                queue.append(q)
        while queue:                        # 用佇列一圈一圈往外擴張
            q = queue.popleft()
            if label[q] == NOISE:           # 原本的雜訊被收編，成為邊界點
                label[q] = c
                continue
            label[q] = c
            nq = neighbors(points, q, eps)
            if len(nq) < min_pts:           # 鄰居不夠：q 是邊界點，不再往外擴
                continue
            for r in nq:                    # q 也是核心點：它還沒歸屬的鄰居也排進佇列
                if r not in queued and label[r] <= 0:
                    queued.add(r)
                    queue.append(r)
    return label


def neighbors(points, p, eps):
    """ε 鄰居：距離 ≤ eps 的點（包含自己）；用平方比，不用開根號"""
    px, py = points[p]
    return [q for q, (x, y) in enumerate(points) if (px - x) ** 2 + (py - y) ** 2 <= eps * eps]


# 兩個月牙＋幾個零星的點，編號照 x 由左到右
POINTS = [
    (14, 58), (16, 48), (16, 108), (22, 40), (30, 34), (30, 80), (40, 32), (44, 66),
    (46, 76), (50, 34), (52, 84), (58, 40), (60, 90), (64, 48), (66, 58), (70, 92),
    (80, 90), (88, 84), (94, 76), (96, 66), (98, 52), (108, 22),
]

if __name__ == "__main__":
    eps, min_pts = 12, 3
    label = dbscan(POINTS, eps, min_pts)
    print(f"ε = {eps}，MinPts = {min_pts}")
    for i, (x, y) in enumerate(POINTS):
        core = len(neighbors(POINTS, i, eps)) >= min_pts
        what = "雜訊" if label[i] == NOISE else f"第 {label[i]} 群（{'核心點' if core else '邊界點'}）"
        print(f"#{i} ({x},{y}) {what}")
    print(f"共 {max(label, default=0)} 群，雜訊 {label.count(NOISE)} 個")
