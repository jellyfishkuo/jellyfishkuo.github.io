import java.util.*; «hide»
 «hide»
/** IUOIL：用 indexed list 在增量資料庫上找高效益佔有率樣式（Cho et al., Knowledge-Based Systems 306, 2024） */ «hide»
public class IUOIL { «hide»
    static final double EPS = 1e-9;                  // 小數比大小時的容許誤差 «hide»
 «hide»
    /** IUOI-List 的一格：uo、下一個商品 nid、它在那個商品串列的第幾格 nidx（從 1 數）、ruo */
    static class Entry {
        int tid;                                     // 只拿來印出來對照，演算法不靠它
        double uo, ruo, puo;                         // puo：條件串列才用，共同前綴 P 在這筆的 uo
        String nid = null; int nidx = 0;             // null 就是論文的 ^（後面沒有商品了）
        Entry(int tid, double uo, double ruo, double puo) { this.tid = tid; this.uo = uo; this.ruo = ruo; this.puo = puo; }
    }

    /** 一個樣式的 IUOI-List：suo、sruo 和一格一格的 entry（照交易進來的順序） */
    static class Node {
        List<String> items;
        List<Entry> entries = new ArrayList<>();
        double suo, sruo;
        Node(List<String> items) { this.items = items; }
        String last() { return items.get(items.size() - 1); }
    }

    Map<String, Integer> profit;
    int alpha;                                       // minSup = 讀過的交易數 × α
    double beta;
    Map<String, Node> gl = new HashMap<>();          // 全域 IUOI-List：商品 -> Node（支持度不夠的也留著）
    List<String> order = new ArrayList<>();          // 目前的總順序
    int n = 0, tid = 0;                              // 讀過幾筆交易、交易編號（只拿來印）
    boolean rebuilt = false;                         // 重建過了沒（還沒重建前照字典順序）

    IUOIL(Map<String, Integer> profit, int alphaPct, int betaPct) {
        this.profit = profit;
        this.alpha = alphaPct; «start»
        this.beta = betaPct / 100.0; «start»
    }

    /** 新的一批交易：接到每個商品的 list 後面，再重建、再挖 */
    Map<List<String>, double[]> addBatch(List<Map<String, Integer>> batch) { «loop»
        for (Map<String, Integer> t : batch) insert(t); «loop»
        n += batch.size(); «loop»
        reconstruct(); «loop»
        return mine(); «loop»
    } «loop»

    /** 一筆交易（商品 -> 數量）：每個商品的 list 加一格，前一格的 NId、NIdx 指過來 */
    void insert(Map<String, Integer> t) {
        int tu = 0;                                                // 這筆交易的總效益 «insert»
        for (String i : t.keySet()) tu += t.get(i) * profit.get(i); «insert»
        List<String> fresh = new ArrayList<>(); «insert»
        for (String i : t.keySet()) if (!gl.containsKey(i)) fresh.add(i); «insert»
        Collections.sort(fresh); «insert»
        order.addAll(fresh);                                       // 新商品排最後 «insert»
        if (!rebuilt) Collections.sort(order);                     // 還沒重建前照字典順序 «insert»
        List<String> items = new ArrayList<>(t.keySet()); «insert»
        items.sort(Comparator.comparingInt(order::indexOf));       // 照目前的順序串起來 «insert»
        Entry prev = null; «insert»
        for (String item : items) { «insert»
            Node node = gl.computeIfAbsent(item, k -> new Node(List.of(k))); «insert»
            Entry e = new Entry(tid, (double) (t.get(item) * profit.get(item)) / tu, 0, 0);   // uo = 自己的效益 / 整筆 «insert»
            node.entries.add(e); «insert»
            if (prev != null) { prev.nid = item; prev.nidx = node.entries.size(); }   // 指到「item 的第幾格」 «insert»
            prev = e; «insert»
        } «insert»
        tid++; «insert»
    }

    /** 照新的支持度重排；順著索引把每筆交易的格子找出來，重接 NId、NIdx，算 ruo */
    void reconstruct() {
        List<String> newOrder = new ArrayList<>(order); «sort»
        newOrder.sort(Comparator.comparingInt((String i) -> gl.get(i).entries.size()));   // 支持度由小到大，一樣多照原本的順序（sort 是穩定的） «sort»
        Map<String, Integer> rank = new HashMap<>(); «sort»
        for (int k = 0; k < newOrder.size(); k++) rank.put(newOrder.get(k), k); «sort»
        for (Node node : gl.values()) node.suo = node.sruo = 0; «sort»
        Set<Entry> seen = new HashSet<>(); «relink»
        for (String item : order) {                                // 照舊順序一個一個 list 看 «relink»
            List<Entry> es = gl.get(item).entries; «relink»
            for (int k = 0; k < es.size(); k++) { «relink»
                if (seen.contains(es.get(k))) continue;            // 已經在別的交易鏈裡處理過了 «relink»
                List<Object[]> chain = new ArrayList<>();          // 沒看過的格子 = 一筆交易的開頭，順著索引跳 «relink»
                String it = item; int ix = k + 1; «relink»
                while (it != null) { «relink»
                    Entry en = gl.get(it).entries.get(ix - 1); «relink»
                    seen.add(en); «relink»
                    chain.add(new Object[] { it, ix, en }); «relink»
                    it = en.nid; ix = en.nidx; «relink»
                } «relink»
                chain.sort(Comparator.comparingInt(c -> rank.get((String) c[0])));   // 照新順序重排 «relink»
                double rest = 0; «relink»
                for (int j = chain.size() - 1; j >= 0; j--) {      // 從後面往前：ruo = 後面的 uo 加總 «relink»
                    Entry en = (Entry) chain.get(j)[2]; «relink»
                    en.ruo = rest; «relink»
                    rest += en.uo; «relink»
                    en.nid = j + 1 < chain.size() ? (String) chain.get(j + 1)[0] : null; «relink»
                    en.nidx = j + 1 < chain.size() ? (int) chain.get(j + 1)[1] : 0; «relink»
                } «relink»
                for (Object[] c : chain) { «relink»
                    Node node = gl.get((String) c[0]); «relink»
                    node.suo += ((Entry) c[2]).uo; «relink»
                    node.sruo += ((Entry) c[2]).ruo; «relink»
                } «relink»
            } «relink»
        } «relink»
        order = newOrder; «sort»
        rebuilt = true; «sort»
    }

    Map<List<String>, double[]> mine() {
        Map<List<String>, double[]> result = new LinkedHashMap<>(); «result»
        List<Node> cl = new ArrayList<>(); «result»
        for (String i : order) cl.add(gl.get(i)); «result»
        search(cl, result); «result»
        return result; «result»
    }

    void search(List<Node> cl, Map<List<String>, double[]> result) {
        int cms = (n * alpha + 99) / 100;                          // ⌈minSup⌉ «check»
        for (Node x : cl) { «check»
            int sup = x.entries.size(); «check»
            if (sup * 100 < n * alpha) continue;                   // ① 支持度不夠：自己和更長的都不可能 «check»
            if (x.suo / sup >= beta - EPS)                         // 平均佔有率夠，輸出 «output»
                result.put(x.items, new double[] { sup, x.suo / sup }); «output»
            if ((x.suo + x.sruo) / cms < beta - EPS) continue;     // ② lubuo 不夠，剪掉 «lub»
            if (ubuo(x, cms) < beta - EPS) continue;               // ③ ubuo 不夠，剪掉 «ub»
            List<Node> ncl = extend(x, cl); «extend»
            if (!ncl.isEmpty()) search(ncl, result);               // 以 x 為前綴往下找 «extend»
        } «check»
    }

    /** uo + ruo 最大的 ⌈minSup⌉ 格取平均 */
    double ubuo(Node x, int cms) { «ub{»
        List<Double> vec = new ArrayList<>();
        for (Entry e : x.entries) vec.add(e.uo + e.ruo);
        vec.sort(Collections.reverseOrder());
        double s = 0;
        for (int k = 0; k < cms; k++) s += vec.get(k);
        return s / cms;
    } «}ub»

    /** 順著 x 每一格的索引往後跳，一次做出所有 x 再加一個商品的條件串列 */
    List<Node> extend(Node x, List<Node> cl) { «extend{»
        Map<String, Node> lists = new HashMap<>(), fresh = new HashMap<>();
        for (Node y : cl) lists.put(y.last(), y);
        for (Entry e : x.entries) {
            Entry prev = null;
            String it = e.nid; int ix = e.nidx;
            while (it != null) {                                   // 同一筆交易裡、排在 x 後面的每個商品
                Entry ey = lists.get(it).entries.get(ix - 1);
                List<String> items = new ArrayList<>(x.items);
                items.add(it);
                Node node = fresh.computeIfAbsent(it, k -> new Node(items));
                Entry ne = new Entry(e.tid, e.uo + ey.uo - e.puo, ey.ruo, e.uo);   // 前綴 P 兩邊都算了，扣掉一次
                node.entries.add(ne);
                node.suo += ne.uo;
                node.sruo += ne.ruo;
                if (prev != null) { prev.nid = it; prev.nidx = node.entries.size(); }
                prev = ne;
                it = ey.nid; ix = ey.nidx;
            }
        }
        List<Node> out = new ArrayList<>(fresh.values());
        out.sort(Comparator.comparingInt(y -> order.indexOf(y.last())));
        return out;
    } «}extend»
 «hide{»

    static String fmt4(double x) {
        long n = (long) Math.floor(x * 10000 + 0.5);   // 自己四捨五入，Java 和 Python 印出來才會一模一樣
        return String.format("%d.%04d", n / 10000, n % 10000);
    }

    static Map<String, Integer> tx(Object... kv) {     // 一筆交易：商品, 數量, 商品, 數量…（照寫的順序）
        Map<String, Integer> t = new LinkedHashMap<>();
        for (int i = 0; i < kv.length; i += 2) t.put((String) kv[i], (Integer) kv[i + 1]);
        return t;
    }

    public static void main(String[] args) {
        Map<String, Integer> profit = Map.of("咖啡", 30, "麵包", 15, "牛奶", 20, "飯糰", 10, "茶葉蛋", 5, "洋芋片", 25);
        List<List<Map<String, Integer>>> batches = List.of(   // 每筆交易：商品 -> 購買數量
            List.of(tx("咖啡", 4, "麵包", 2, "牛奶", 2),         // DB0：原始資料庫
                    tx("咖啡", 3, "麵包", 5, "茶葉蛋", 4),
                    tx("咖啡", 1, "麵包", 1, "牛奶", 2, "飯糰", 2),
                    tx("麵包", 3, "牛奶", 4, "洋芋片", 5),
                    tx("咖啡", 3, "牛奶", 2, "茶葉蛋", 2),
                    tx("咖啡", 1, "麵包", 2, "牛奶", 1, "茶葉蛋", 1),
                    tx("飯糰", 1, "茶葉蛋", 2, "洋芋片", 2),
                    tx("咖啡", 1, "麵包", 2, "飯糰", 1)),
            List.of(tx("洋芋片", 2, "飯糰", 1, "牛奶", 1),       // DB1：新的一批
                    tx("洋芋片", 1, "麵包", 1, "茶葉蛋", 2)),
            List.of(tx("咖啡", 2, "洋芋片", 2),                  // DB2：再一批
                    tx("飯糰", 2, "茶葉蛋", 3, "洋芋片", 1)));
        // α = 30%（minSup = 讀過的筆數 × 30%）、β = 50%
        IUOIL h = new IUOIL(profit, 30, 50);
        int total = 0;
        for (int k = 0; k < batches.size(); k++) {
            Map<List<String>, double[]> result = h.addBatch(batches.get(k));
            total += batches.get(k).size();
            System.out.println("DB" + k + " 進來後（共 " + total + " 筆）：");
            result.forEach((items, v) -> System.out.println(
                "  {" + String.join(", ", items) + "} sup = " + (int) v[0] + "  uo = " + fmt4(v[1])));
        }
    }
} «}hide»
