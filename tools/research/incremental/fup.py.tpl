"""FUP（Fast UPdate）：資料庫新增一批交易 db 時，更新頻繁樣式而不用全部重算""" «hide»
from itertools import combinations «hide»
 «hide»
reads = 0  # 一共讀了幾筆交易（拿來比較成本）
 «hide»

def need(n, pct):
    """n 筆交易、門檻 pct% 時，至少要出現幾次才算頻繁（無條件進位）"""
    return (n * pct + 99) // 100


def fup(DB, L, db, pct): «start»
    """DB：舊資料庫；L：DB 的頻繁樣式 {樣式: 次數}；db：新增的交易""" «start»
    N = len(DB) + len(db) «start»
    new_L = {}
    k = 1 «c1»
    C = sorted({(i,) for t in DB + db for i in t})  # 第 1 層：每個商品 «c1»
    while C: «c1,gen,stop»
        old = [c for c in C if c in L]       # 原本就頻繁：DB 裡的次數已經知道 «split»
        new = [c for c in C if c not in L]   # 新候選：DB 裡的次數不知道 «split»
        in_db = count(db, C)                 # 掃 db 一次（只有新增的那幾筆） «old»
        Lk = {} «old»
        for c in old:                        # 舊樣式：舊次數＋新次數，不用碰 DB «old»
            if L[c] + in_db[c] >= need(N, pct): «old»
                Lk[c] = L[c] + in_db[c] «old»
        # 引理：在 DB 不頻繁的樣式，要在 DB∪db 變頻繁，在 db 裡也一定頻繁 «lemma»
        new = [c for c in new if in_db[c] >= need(len(db), pct)] «lemma»
        if new: «scan»
            in_DB = count(DB, new)           # 只有通過引理的新候選，才回頭掃 DB «scan»
            for c in new: «scan»
                if in_DB[c] + in_db[c] >= need(N, pct): «scan»
                    Lk[c] = in_DB[c] + in_db[c] «scan»
        new_L.update(Lk) «level»
        k += 1 «gen»
        C = apriori_gen(Lk, k)               # 下一層候選：跟 Apriori 一樣，從新的 L(k) 產生 «gen»
    return new_L «end»


def apriori_gen(L, k): «gen{»
    """合併前 k-2 個相同的兩個樣式，再剪掉有不頻繁子集合的"""
    L = sorted(L)                            # 照字典順序排好，合併才不會漏
    frequent = set(L)
    C = []
    for i in range(len(L)):
        for j in range(i + 1, len(L)):
            a, b = L[i], L[j]
            if a[:k - 2] == b[:k - 2]:
                c = a + (b[-1],)
                if all(s in frequent for s in combinations(c, k - 1)):
                    C.append(c)
    return C «}gen»


def count(rows, C):
    """掃一次 rows，數每個候選出現在幾筆交易裡"""
    global reads
    reads += len(rows)
    cnt = {c: 0 for c in C}
    for t in rows:
        for c in C:
            if set(c) <= t:
                cnt[c] += 1
    return cnt


def apriori(DB, pct):
    """一般的 Apriori：用來算一開始的 L，也可以直接對 DB∪db 全部重算來比較"""
    L, k = {}, 1
    C = sorted({(i,) for t in DB for i in t})
    while C:
        cnt = count(DB, C)
        Lk = {c: cnt[c] for c in C if cnt[c] >= need(len(DB), pct)}
        L.update(Lk)
        k += 1
        C = apriori_gen(Lk, k)
    return L
 «hide{»

def fmt(c):
    return "{" + ", ".join(c) + "}"


def show(L):
    for c in sorted(L, key=lambda c: (len(c), c)):
        print("  " + fmt(c), L[c])


if __name__ == "__main__":
    DB = [
        {"咖啡", "麵包", "牛奶"},
        {"咖啡", "麵包", "茶葉蛋"},
        {"咖啡", "麵包", "牛奶", "飯糰"},
        {"麵包", "牛奶", "洋芋片"},
        {"咖啡", "牛奶", "茶葉蛋"},
        {"咖啡", "麵包", "牛奶", "茶葉蛋"},
        {"飯糰", "茶葉蛋", "洋芋片"},
        {"咖啡", "麵包", "飯糰"},
    ]
    db = [  # 新增的一批交易
        {"咖啡", "茶葉蛋"},
        {"咖啡", "麵包", "牛奶"},
        {"咖啡", "牛奶", "茶葉蛋"},
        {"牛奶", "飯糰", "茶葉蛋"},
    ]
    pct = 30
    L = apriori(DB, pct)
    print("原本的 L（DB 共 %d 筆，門檻 %d%%）：" % (len(DB), pct))
    show(L)

    reads = 0
    new_L = fup(DB, L, db, pct)
    fup_reads = reads
    print("FUP 更新後的 L（DB∪db 共 %d 筆）：" % (len(DB) + len(db)))
    show(new_L)
    order = lambda keys: sorted(keys, key=lambda c: (len(c), c))
    print("新增：" + ("、".join(fmt(c) for c in order(new_L.keys() - L.keys())) or "（沒有）"))
    print("掉出：" + ("、".join(fmt(c) for c in order(L.keys() - new_L.keys())) or "（沒有）"))

    reads = 0
    again = apriori(DB + db, pct)            # 對照組：直接對 DB∪db 全部重算
    print("FUP 讀了 %d 筆交易；全部重算讀了 %d 筆；兩邊結果%s" % (fup_reads, reads, "一樣" if new_L == again else "不一樣")) «}hide»
