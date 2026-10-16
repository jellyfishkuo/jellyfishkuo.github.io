"""gSpan：用 DFS code 一條邊一條邊長出所有頻繁的子圖（Yan & Han, 2002）""" «hide»
 «hide»
 «hide»
def gspan(graphs, min_sup): «start{»
    """graphs：每張圖是 (原子, 鍵)；原子[v] 是第 v 個點的標籤，鍵是 (u, v, "-" 單鍵 或 "=" 雙鍵)"""
    adj = [neighbors(len(atoms), bonds) for atoms, bonds in graphs]
    result = []
    # 1. 第一條邊：數每一種「原子-鍵-原子」出現在幾張圖；兩端照字母排，小的當 0 號點 «first»
    first = {} «first»
    for gid, (atoms, _) in enumerate(graphs): «first»
        for u in range(len(atoms)): «first»
            for v, b in adj[gid][u]: «first»
                if atoms[u] <= atoms[v]: «first»
                    first.setdefault((0, 1, atoms[u], b, atoms[v]), []).append((gid, [u, v])) «first»
    for e in sorted(first, key=dfs_order): «first»
        if support(first[e]) >= min_sup: «first»
            mine(graphs, adj, min_sup, [e], first[e], result) «first,end»
    return result «}start,end»


def mine(graphs, adj, min_sup, code, embs, result):
    """code：目前樣式的 DFS code（每條邊 (i, j, 原子i, 鍵, 原子j)）；embs：它在各圖的每一種嵌入 (gid, 樣式第 k 點 → 圖上的點)"""
    result.append((tuple(code), support(embs)))                   # 頻繁、而且是最小 DFS code：記下來 «record»
    # 2. 最右延伸：只從「最右路徑」往外長，每個子圖才不會被同樣的方式重複長出來 «ext»
    rm = rightmost_path(code) «ext»
    r = rm[-1]                                                    # 最右頂點：最後長出來的那個點 «ext»
    ext = {} «ext»
    for gid, m in embs: «ext»
        atoms = graphs[gid][0] «ext»
        for v in rm[:-1]:                                         # 後退邊：最右頂點連回最右路徑上的點（多一個環） «back»
            b = bond(adj[gid], m[r], m[v]) «back»
            if b and not has_edge(code, r, v): «back»
                ext.setdefault((r, v, atoms[m[r]], b, atoms[m[v]]), []).append((gid, m)) «back»
        for v in reversed(rm):                                    # 前進邊：從最右路徑上的點長出一個新的點（越深的越先） «fwd»
            for w, b in adj[gid][m[v]]: «fwd»
                if w not in m: «fwd»
                    ext.setdefault((v, len(m), atoms[m[v]], b, atoms[w]), []).append((gid, m + [w])) «fwd»
    # 3. 照 DFS code 的順序一個一個試 «loop»
    for e in sorted(ext, key=dfs_order): «loop»
        if support(ext[e]) < min_sup:                             # 出現的圖不夠多：再長也不會變多 «loop»
            continue «loop»
        child = code + [e] «loop»
        if min_code(child) != child:                              # 同一個子圖有更小的寫法，那個寫法早就找過了 «prune»
            continue «prune»
        mine(graphs, adj, min_sup, child, ext[e], result)        # 遞迴 «recurse»


def min_code(code): «min{»
    """把 code 畫成一張小圖，從頭重寫一次 DFS code，每一步都挑順序最小的邊 → 最小 DFS code"""
    atoms, adj = {}, {}
    for i, j, a, b, c in code:
        atoms[i], atoms[j] = a, c
        adj.setdefault(i, []).append((j, b))
        adj.setdefault(j, []).append((i, b))
    best = min((atoms[u], b, atoms[v]) for u in adj for v, b in adj[u])
    mc = [(0, 1) + best]
    embs = [[u, v] for u in adj for v, b in adj[u] if (atoms[u], b, atoms[v]) == best]
    while len(mc) < len(code):
        rm = rightmost_path(mc)
        r = rm[-1]
        cands = []
        for m in embs:                                            # 跟挖的時候一樣的最右延伸
            for v in rm[:-1]:
                b = bond(adj, m[r], m[v])
                if b and not has_edge(mc, r, v):
                    cands.append(((r, v, atoms[m[r]], b, atoms[m[v]]), m))
            for v in reversed(rm):
                for w, b in adj[m[v]]:
                    if w not in m:
                        cands.append(((v, len(m), atoms[m[v]], b, atoms[w]), m + [w]))
        e = min((c for c, _ in cands), key=dfs_order)             # 挑最小的那條，只留走得出它的嵌入
        mc.append(e)
        embs = [m for c, m in cands if c == e]
    return mc «}min»


def dfs_order(e): «order{»
    """同一個樣式往外長的邊怎麼排：後退邊先（連回越前面的點越小），再來前進邊（從越深的點長越小），最後比標籤"""
    i, j, a, b, c = e
    return (0, j, a, b, c) if i > j else (1, -i, a, b, c) «}order»


def rightmost_path(code):
    """從 0 號點沿著前進邊走到最右頂點"""
    parent = {j: i for i, j, *_ in code if i < j}
    path = [max(parent)]
    while path[-1] != 0:
        path.append(parent[path[-1]])
    return path[::-1]


def support(embs):
    return len({gid for gid, _ in embs})                          # 出現在幾張不同的圖（同一張圖不管幾處都只算 1）


def has_edge(code, u, v):
    return any({i, j} == {u, v} for i, j, *_ in code)


def bond(adj, u, v):
    for w, b in adj[u]:
        if w == v:
            return b
    return None


def neighbors(n, bonds):
    adj = [[] for _ in range(n)]
    for u, v, b in bonds:
        adj[u].append((v, b))
        adj[v].append((u, b))
    return adj «hide{»


def show(code):
    return " ".join("(%d,%d,%s,%s,%s)" % e for e in code)


if __name__ == "__main__":
    graphs = [
        (["C", "C", "O", "O"], [(0, 1, "-"), (1, 2, "="), (1, 3, "-")]),                    # 醋酸
        (["C", "C", "O"], [(0, 1, "-"), (1, 2, "-")]),                                     # 乙醇
        (["N", "C", "C", "O", "O"], [(0, 1, "-"), (1, 2, "-"), (2, 3, "="), (2, 4, "-")]),  # 甘胺酸
        (["C", "C", "O", "C"], [(0, 1, "-"), (1, 2, "="), (1, 3, "-")]),                    # 丙酮
        (["C", "C", "O"], [(0, 1, "-"), (1, 2, "=")]),                                     # 乙醛
    ]
    for code, sup in gspan(graphs, 3):
        print(show(code), sup) «}hide»
