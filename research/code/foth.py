"""FOTH：不用 join，靠 IndexSet 自我傳播找出所有高效益樣式（效益 >= min_util 的商品組合）"""


class Vector:
    """一筆交易裡某個組合的效益：每個商品各多少、加總，以及 fixedPos"""
    def __init__(self, utils, fixed_pos):
        self.utils = utils                  # 位元位置 -> 這個商品在這筆交易的效益
        self.util_sum = sum(utils.values())
        self.fixed_pos = fixed_pos          # 位置 >= fixed_pos 的商品已經固定，不能再拿掉


class IndexSet:
    """同一個組合（同一個編碼）在每筆交易裡的 vector，全部收在一起"""
    def __init__(self, code):
        self.code = code
        self.util_sum = 0                   # 收齊之後就是這個組合的效益
        self.vectors = []

    def merge(self, v):                     # 不用比對 tid，接在後面就好
        self.vectors.append(v)
        self.util_sum += v.util_sum


def foth(db, profit, min_util):
    # 1. 第 1 次掃描：算每筆交易的 TU，加進它裡面每個商品的 TWU
    twu = {}
    for t in db:
        tu = sum(q * profit[item] for item, q in t.items())
        for item in t:
            twu[item] = twu.get(item, 0) + tu
    # TWU 不到門檻的刪掉；剩下的照 TWU 由小到大排，排越前面的放在越高的位元
    order = [item for item in twu if twu[item] >= min_util]
    order.sort(key=lambda item: (twu[item], item))
    n = len(order)
    pos = {item: n - 1 - k for k, item in enumerate(order)}   # 商品 -> 位元位置

    # 2. 第 2 次掃描：每筆交易變成一個 vector，放進同樣編碼的 IndexSet
    R = {}                                  # 編碼 -> IndexSet（論文用紅黑樹）
    for t in db:
        utils = {pos[i]: q * profit[i] for i, q in t.items() if i in pos}
        if utils:
            put(R, sum(1 << b for b in utils), Vector(utils, n))

    # 3. 從最高位開始，一區一區往下挖
    result = {}
    for b in reversed(range(n)):
        mine(R, 1 << b, min_util, order, result)
    return result


def put(R, code, v):
    """找編碼一樣的 IndexSet（沒有就新建），把 vector 接上去"""
    s = R.get(code)
    if s is None:
        s = R[code] = IndexSet(code)
    s.merge(v)


def mine(R, low, min_util, order, result):
    bit = low & -low                        # low 最低的那個 1；比它高的位元都固定了
    area = [c for c in sorted(R, reverse=True) if low <= c < low + bit]   # mining area
    vs = sum(R[c].util_sum for c in area)   # = U(X) + RU(X)，X 是 low 代表的組合
    if vs >= min_util:                      # 還有機會：再固定下一個位元，分成小區
        b = bit >> 1
        while b:
            mine(R, low + b, min_util, order, result)
            b >>= 1
        area = [low] if low in R else []    # 小區都做完了，只剩 low 自己
    for c in area:                          # 不夠的話：整區不再細分（剪掉）
        s = R.pop(c)
        if s.util_sum >= min_util:
            n = len(order)
            result[tuple(order[k] for k in range(n) if c >> (n - 1 - k) & 1)] = s.util_sum
        propagate(R, s, low)


def propagate(R, s, low):
    """每個 vector 自己拿掉一個商品變成子 vector，直接併進對應的 IndexSet（不用 join）"""
    for v in s.vectors:
        for y in list(v.utils):
            # 只拿掉 low 裡的、而且在 fixedPos 下面的商品：同一筆交易的同一個子集合只會出現一次
            if low >> y & 1 and y < v.fixed_pos and len(v.utils) > 1:
                utils = dict(v.utils)
                del utils[y]
                put(R, s.code - (1 << y), Vector(utils, y))   # 子 vector 的 fixedPos = y


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
    for items, u in foth(db, profit, 250).items():
        print("{" + ", ".join(items) + "} 效益 =", u)
