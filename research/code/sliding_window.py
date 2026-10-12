"""資料串流上的滑動視窗：只看最近 w 筆交易，每來一筆就即時更新頻繁樣式"""
from collections import deque
from itertools import combinations


class SlidingWindow:
    def __init__(self, w, min_sup):
        self.w = w                  # 視窗大小：只看最近 w 筆
        self.min_sup = min_sup      # 最小支持度
        self.window = deque()       # 視窗裡的交易，最舊的在最左邊
        self.count = {}             # 計數表：商品組合 -> 在視窗裡出現幾次

    def add(self, t):
        """新交易進來：它的每個非空子集合次數 +1"""
        t = tuple(sorted(t))
        self.window.append(t)
        for s in subsets(t):
            self.count[s] = self.count.get(s, 0) + 1
        if len(self.window) > self.w:   # 視窗滿了，最舊的要離開
            return self._expire()
        return None

    def _expire(self):
        """最舊的交易離開：它的每個非空子集合次數 -1，變成 0 就從表裡刪掉"""
        old = self.window.popleft()
        for s in subsets(old):
            self.count[s] -= 1
            if self.count[s] == 0:
                del self.count[s]
        return old

    def frequent(self):
        """頻繁樣式：次數 >= min_sup 的組合"""
        return {s: c for s, c in self.count.items() if c >= self.min_sup}

    def maximal(self):
        """最大頻繁樣式：頻繁、而且沒有任何超集合也頻繁"""
        f = self.frequent()
        return {s: c for s, c in f.items()
                if not any(set(s) < set(o) for o in f)}


def subsets(t):
    """一筆交易的所有非空子集合（6 個商品最多 63 個）"""
    for k in range(1, len(t) + 1):
        yield from combinations(t, k)


def run(stream, w, min_sup):
    """把串流一筆一筆餵進視窗，印出每一步頻繁樣式的變化"""
    sw = SlidingWindow(w, min_sup)
    before = {}
    for i, t in enumerate(stream, 1):
        old = sw.add(t)                       # 進來一筆，必要時擠掉最舊的一筆
        print(f"T{i} 進入 {fmt(t)}" + (f"，T{i - w} 離開 {fmt(old)}" if old else ""))
        now = sw.frequent()
        for s in ordered(now.keys() - before.keys()):
            print(f"  + 變成頻繁 {fmt(s)} {now[s]}")
        for s in ordered(before.keys() - now.keys()):
            print(f"  - 不再頻繁 {fmt(s)}")
        m = sw.maximal()
        print("  最大頻繁：" + " ".join(f"{fmt(s)}×{m[s]}" for s in ordered(m)))
        before = now


def fmt(s):
    return "{" + ", ".join(sorted(s)) + "}"


def ordered(patterns):
    """先比商品數、再比商品名稱，讓輸出順序固定"""
    return sorted(patterns, key=lambda s: (len(s), s))


if __name__ == "__main__":
    stream = [
        {"咖啡", "麵包", "牛奶"},              # T1–T8：早上，咖啡配麵包
        {"咖啡", "麵包", "茶葉蛋"},
        {"咖啡", "麵包", "牛奶", "飯糰"},
        {"麵包", "牛奶", "洋芋片"},
        {"咖啡", "牛奶", "茶葉蛋"},
        {"咖啡", "麵包", "牛奶", "茶葉蛋"},
        {"飯糰", "茶葉蛋", "洋芋片"},
        {"咖啡", "麵包", "飯糰"},
        {"咖啡", "飯糰", "茶葉蛋"},            # T9–T14：中午，飯糰配茶葉蛋
        {"飯糰", "茶葉蛋"},
        {"牛奶", "飯糰", "茶葉蛋"},
        {"麵包", "飯糰", "茶葉蛋"},
        {"飯糰", "茶葉蛋", "洋芋片"},
        {"咖啡", "飯糰"},
        {"牛奶", "洋芋片"},                    # T15–T20：晚上，洋芋片配牛奶
        {"麵包", "牛奶", "洋芋片"},
        {"牛奶", "茶葉蛋", "洋芋片"},
        {"麵包", "牛奶", "洋芋片"},
        {"咖啡", "洋芋片"},
        {"麵包", "牛奶", "洋芋片"},
    ]
    run(stream, 5, 3)
