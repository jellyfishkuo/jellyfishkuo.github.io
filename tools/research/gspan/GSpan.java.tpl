import java.util.*; «hide»
 «hide»
/** gSpan：用 DFS code 一條邊一條邊長出所有頻繁的子圖（Yan & Han, 2002） */ «hide»
public class GSpan { «hide»
 «hide»
    /** DFS code 的一條邊：(i, j, 原子i, 鍵, 原子j)，i < j 是前進邊、i > j 是後退邊 */
    record Edge(int i, int j, String a, String b, String c) {
        public String toString() { return "(" + i + "," + j + "," + a + "," + b + "," + c + ")"; }
    }
    /** 一張圖：atoms[v] 是第 v 個點的原子，bonds 每一條是 {u, v}，鍵 "-" 單鍵、"=" 雙鍵 */
    record Graph(String[] atoms, int[][] bonds, String[] kinds) {}
    /** 樣式在第 gid 張圖裡的一種嵌入：map.get(k) = 樣式第 k 點對到圖上的哪個點 */
    record Emb(int gid, List<Integer> map) {}

    public static List<Map.Entry<List<Edge>, Integer>> gSpan(List<Graph> graphs, int minSup) { «start{»
        List<Map<Integer, String>[]> adj = new ArrayList<>();
        for (Graph g : graphs) adj.add(neighbors(g));
        List<Map.Entry<List<Edge>, Integer>> result = new ArrayList<>();
        // 1. 第一條邊：數每一種「原子-鍵-原子」出現在幾張圖；兩端照字母排，小的當 0 號點 «first»
        Map<Edge, List<Emb>> first = new TreeMap<>(DFS_ORDER); «first»
        for (int gid = 0; gid < graphs.size(); gid++) { «first»
            String[] atoms = graphs.get(gid).atoms(); «first»
            for (int u = 0; u < atoms.length; u++) «first»
                for (var nb : adj.get(gid)[u].entrySet()) { «first»
                    int v = nb.getKey(); «first»
                    if (atoms[u].compareTo(atoms[v]) <= 0) «first»
                        first.computeIfAbsent(new Edge(0, 1, atoms[u], nb.getValue(), atoms[v]), k -> new ArrayList<>()).add(new Emb(gid, List.of(u, v))); «first»
                } «first»
        } «first»
        for (var e : first.entrySet()) «first»
            if (support(e.getValue()) >= minSup) «first»
                mine(graphs, adj, minSup, List.of(e.getKey()), e.getValue(), result); «first,end»
        return result; «end»
    } «}start»

    /** code：目前樣式的 DFS code；embs：它在各圖的每一種嵌入 */
    static void mine(List<Graph> graphs, List<Map<Integer, String>[]> adj, int minSup, List<Edge> code,
                     List<Emb> embs, List<Map.Entry<List<Edge>, Integer>> result) {
        result.add(Map.entry(code, support(embs)));                  // 頻繁、而且是最小 DFS code：記下來 «record»
        // 2. 最右延伸：只從「最右路徑」往外長，每個子圖才不會被同樣的方式重複長出來 «ext»
        List<Integer> rm = rightmostPath(code); «ext»
        int r = rm.get(rm.size() - 1);                               // 最右頂點：最後長出來的那個點 «ext»
        Map<Edge, List<Emb>> ext = new TreeMap<>(DFS_ORDER);        // 照 DFS code 的順序排好 «ext»
        for (Emb em : embs) { «ext»
            String[] atoms = graphs.get(em.gid()).atoms(); «ext»
            Map<Integer, String>[] g = adj.get(em.gid()); «ext»
            List<Integer> m = em.map(); «ext»
            for (int v : rm.subList(0, rm.size() - 1)) {             // 後退邊：最右頂點連回最右路徑上的點（多一個環） «back»
                String b = g[m.get(r)].get(m.get(v)); «back»
                if (b != null && !hasEdge(code, r, v)) «back»
                    ext.computeIfAbsent(new Edge(r, v, atoms[m.get(r)], b, atoms[m.get(v)]), k -> new ArrayList<>()).add(em); «back»
            } «back»
            for (int k = rm.size() - 1; k >= 0; k--) {               // 前進邊：從最右路徑上的點長出一個新的點（越深的越先） «fwd»
                int v = rm.get(k); «fwd»
                for (var nb : g[m.get(v)].entrySet()) { «fwd»
                    int w = nb.getKey(); «fwd»
                    if (m.contains(w)) continue; «fwd»
                    List<Integer> m2 = new ArrayList<>(m); «fwd»
                    m2.add(w); «fwd»
                    ext.computeIfAbsent(new Edge(v, m.size(), atoms[m.get(v)], nb.getValue(), atoms[w]), x -> new ArrayList<>()).add(new Emb(em.gid(), m2)); «fwd»
                } «fwd»
            } «fwd»
        } «ext»
        // 3. 照 DFS code 的順序一個一個試 «loop»
        for (var e : ext.entrySet()) { «loop»
            if (support(e.getValue()) < minSup) continue;            // 出現的圖不夠多：再長也不會變多 «loop»
            List<Edge> child = new ArrayList<>(code); «loop»
            child.add(e.getKey()); «loop»
            if (!minCode(child).equals(child)) continue;             // 同一個子圖有更小的寫法，那個寫法早就找過了 «prune»
            mine(graphs, adj, minSup, child, e.getValue(), result);  // 遞迴 «recurse»
        } «loop»
    }

    /** 把 code 畫成一張小圖，從頭重寫一次 DFS code，每一步都挑順序最小的邊 → 最小 DFS code */
    static List<Edge> minCode(List<Edge> code) { «min{»
        Map<Integer, String> atoms = new HashMap<>();
        Map<Integer, Map<Integer, String>> adj = new HashMap<>();
        for (Edge e : code) {
            atoms.put(e.i(), e.a());
            atoms.put(e.j(), e.c());
            adj.computeIfAbsent(e.i(), k -> new TreeMap<>()).put(e.j(), e.b());
            adj.computeIfAbsent(e.j(), k -> new TreeMap<>()).put(e.i(), e.b());
        }
        Edge best = null;
        for (int u : adj.keySet())
            for (var nb : adj.get(u).entrySet()) {
                Edge e = new Edge(0, 1, atoms.get(u), nb.getValue(), atoms.get(nb.getKey()));
                if (best == null || DFS_ORDER.compare(e, best) < 0) best = e;
            }
        List<Edge> mc = new ArrayList<>(List.of(best));
        List<List<Integer>> embs = new ArrayList<>();
        for (int u : adj.keySet())
            for (var nb : adj.get(u).entrySet())
                if (new Edge(0, 1, atoms.get(u), nb.getValue(), atoms.get(nb.getKey())).equals(best)) embs.add(List.of(u, nb.getKey()));
        while (mc.size() < code.size()) {
            List<Integer> rm = rightmostPath(mc);
            int r = rm.get(rm.size() - 1);
            Edge min = null;
            Map<Edge, List<List<Integer>>> cands = new HashMap<>();
            for (List<Integer> m : embs) {                           // 跟挖的時候一樣的最右延伸
                for (int v : rm.subList(0, rm.size() - 1)) {
                    String b = adj.get(m.get(r)).get(m.get(v));
                    if (b != null && !hasEdge(mc, r, v))
                        cands.computeIfAbsent(new Edge(r, v, atoms.get(m.get(r)), b, atoms.get(m.get(v))), k -> new ArrayList<>()).add(m);
                }
                for (int k = rm.size() - 1; k >= 0; k--) {
                    int v = rm.get(k);
                    for (var nb : adj.get(m.get(v)).entrySet()) {
                        if (m.contains(nb.getKey())) continue;
                        List<Integer> m2 = new ArrayList<>(m);
                        m2.add(nb.getKey());
                        cands.computeIfAbsent(new Edge(v, m.size(), atoms.get(m.get(v)), nb.getValue(), atoms.get(nb.getKey())), x -> new ArrayList<>()).add(m2);
                    }
                }
            }
            for (Edge e : cands.keySet()) if (min == null || DFS_ORDER.compare(e, min) < 0) min = e;
            mc.add(min);                                             // 挑最小的那條，只留走得出它的嵌入
            embs = cands.get(min);
        }
        return mc;
    } «}min»

    /** 同一個樣式往外長的邊怎麼排：後退邊先（連回越前面的點越小），再來前進邊（從越深的點長越小），最後比標籤 */
    static final Comparator<Edge> DFS_ORDER = (x, y) -> { «order{»
        boolean bx = x.i() > x.j(), by = y.i() > y.j();
        if (bx != by) return bx ? -1 : 1;
        int c = bx ? Integer.compare(x.j(), y.j()) : Integer.compare(y.i(), x.i());
        if (c == 0) c = x.a().compareTo(y.a());
        if (c == 0) c = x.b().compareTo(y.b());
        if (c == 0) c = x.c().compareTo(y.c());
        return c;
    }; «}order»

    /** 從 0 號點沿著前進邊走到最右頂點 */
    static List<Integer> rightmostPath(List<Edge> code) {
        Map<Integer, Integer> parent = new HashMap<>();
        for (Edge e : code) if (e.i() < e.j()) parent.put(e.j(), e.i());
        LinkedList<Integer> path = new LinkedList<>();
        path.add(Collections.max(parent.keySet()));
        while (path.getFirst() != 0) path.addFirst(parent.get(path.getFirst()));
        return path;
    }

    static int support(List<Emb> embs) {
        Set<Integer> gids = new HashSet<>();                          // 出現在幾張不同的圖（同一張圖不管幾處都只算 1）
        for (Emb e : embs) gids.add(e.gid());
        return gids.size();
    }

    static boolean hasEdge(List<Edge> code, int u, int v) {
        for (Edge e : code) if ((e.i() == u && e.j() == v) || (e.i() == v && e.j() == u)) return true;
        return false;
    }

    @SuppressWarnings("unchecked")
    static Map<Integer, String>[] neighbors(Graph g) {
        Map<Integer, String>[] adj = new Map[g.atoms().length];
        for (int v = 0; v < adj.length; v++) adj[v] = new LinkedHashMap<>();
        for (int k = 0; k < g.bonds().length; k++) {
            int u = g.bonds()[k][0], v = g.bonds()[k][1];
            adj[u].put(v, g.kinds()[k]);
            adj[v].put(u, g.kinds()[k]);
        }
        return adj;
    } «hide{»

    static Graph graph(String atoms, String... bonds) {              // 例如 graph("CCO", "0-1", "1=2")
        int[][] bs = new int[bonds.length][];
        String[] kinds = new String[bonds.length];
        for (int k = 0; k < bonds.length; k++) {
            String s = bonds[k];
            int at = Math.max(s.indexOf('-'), s.indexOf('='));
            bs[k] = new int[] { Integer.parseInt(s.substring(0, at)), Integer.parseInt(s.substring(at + 1)) };
            kinds[k] = s.substring(at, at + 1);
        }
        return new Graph(atoms.split(""), bs, kinds);
    }

    public static void main(String[] args) {
        List<Graph> graphs = List.of(
            graph("CCOO", "0-1", "1=2", "1-3"),          // 醋酸
            graph("CCO", "0-1", "1-2"),                  // 乙醇
            graph("NCCOO", "0-1", "1-2", "2=3", "2-4"),  // 甘胺酸
            graph("CCOC", "0-1", "1=2", "1-3"),          // 丙酮
            graph("CCO", "0-1", "1=2"));                 // 乙醛
        for (var e : gSpan(graphs, 3)) {
            StringJoiner sj = new StringJoiner(" ");
            for (Edge x : e.getKey()) sj.add(x.toString());
            System.out.println(sj + " " + e.getValue());
        }
    }
} «}hide»
