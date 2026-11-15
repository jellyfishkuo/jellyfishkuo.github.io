import java.util.*;

/** IUOIL：用 indexed list 在增量資料庫上找高效益佔有率樣式（Cho et al., Knowledge-Based Systems 306, 2024） */
public class IUOIL {
    static final double EPS = 1e-9;                  // 小數比大小時的容許誤差

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
        this.alpha = alphaPct;
        this.beta = betaPct / 100.0;
    }

    /** 新的一批交易：接到每個商品的 list 後面，再重建、再挖 */
    Map<List<String>, double[]> addBatch(List<Map<String, Integer>> batch) {
        for (Map<String, Integer> t : batch) insert(t);
        n += batch.size();
        reconstruct();
        return mine();
    }

    /** 一筆交易（商品 -> 數量）：每個商品的 list 加一格，前一格的 NId、NIdx 指過來 */
    void insert(Map<String, Integer> t) {
        int tu = 0;                                                // 這筆交易的總效益
        for (String i : t.keySet()) tu += t.get(i) * profit.get(i);
        List<String> fresh = new ArrayList<>();
        for (String i : t.keySet()) if (!gl.containsKey(i)) fresh.add(i);
        Collections.sort(fresh);
        order.addAll(fresh);                                       // 新商品排最後
        if (!rebuilt) Collections.sort(order);                     // 還沒重建前照字典順序
        List<String> items = new ArrayList<>(t.keySet());
        items.sort(Comparator.comparingInt(order::indexOf));       // 照目前的順序串起來
        Entry prev = null;
        for (String item : items) {
            Node node = gl.computeIfAbsent(item, k -> new Node(List.of(k)));
            Entry e = new Entry(tid, (double) (t.get(item) * profit.get(item)) / tu, 0, 0);   // uo = 自己的效益 / 整筆
            node.entries.add(e);
            if (prev != null) { prev.nid = item; prev.nidx = node.entries.size(); }   // 指到「item 的第幾格」
            prev = e;
        }
        tid++;
    }

    /** 照新的支持度重排；順著索引把每筆交易的格子找出來，重接 NId、NIdx，算 ruo */
    void reconstruct() {
        List<String> newOrder = new ArrayList<>(order);
        newOrder.sort(Comparator.comparingInt((String i) -> gl.get(i).entries.size()));   // 支持度由小到大，一樣多照原本的順序（sort 是穩定的）
        Map<String, Integer> rank = new HashMap<>();
        for (int k = 0; k < newOrder.size(); k++) rank.put(newOrder.get(k), k);
        for (Node node : gl.values()) node.suo = node.sruo = 0;
        Set<Entry> seen = new HashSet<>();
        for (String item : order) {                                // 照舊順序一個一個 list 看
            List<Entry> es = gl.get(item).entries;
            for (int k = 0; k < es.size(); k++) {
                if (seen.contains(es.get(k))) continue;            // 已經在別的交易鏈裡處理過了
                List<Object[]> chain = new ArrayList<>();          // 沒看過的格子 = 一筆交易的開頭，順著索引跳
                String it = item; int ix = k + 1;
                while (it != null) {
                    Entry en = gl.get(it).entries.get(ix - 1);
                    seen.add(en);
                    chain.add(new Object[] { it, ix, en });
                    it = en.nid; ix = en.nidx;
                }
                chain.sort(Comparator.comparingInt(c -> rank.get((String) c[0])));   // 照新順序重排
                double rest = 0;
                for (int j = chain.size() - 1; j >= 0; j--) {      // 從後面往前：ruo = 後面的 uo 加總
                    Entry en = (Entry) chain.get(j)[2];
                    en.ruo = rest;
                    rest += en.uo;
                    en.nid = j + 1 < chain.size() ? (String) chain.get(j + 1)[0] : null;
                    en.nidx = j + 1 < chain.size() ? (int) chain.get(j + 1)[1] : 0;
                }
                for (Object[] c : chain) {
                    Node node = gl.get((String) c[0]);
                    node.suo += ((Entry) c[2]).uo;
                    node.sruo += ((Entry) c[2]).ruo;
                }
            }
        }
        order = newOrder;
        rebuilt = true;
    }

    Map<List<String>, double[]> mine() {
        Map<List<String>, double[]> result = new LinkedHashMap<>();
        List<Node> cl = new ArrayList<>();
        for (String i : order) cl.add(gl.get(i));
        search(cl, result);
        return result;
    }

    void search(List<Node> cl, Map<List<String>, double[]> result) {
        int cms = (n * alpha + 99) / 100;                          // ⌈minSup⌉
        for (Node x : cl) {
            int sup = x.entries.size();
            if (sup * 100 < n * alpha) continue;                   // ① 支持度不夠：自己和更長的都不可能
            if (x.suo / sup >= beta - EPS)                         // 平均佔有率夠，輸出
                result.put(x.items, new double[] { sup, x.suo / sup });
            if ((x.suo + x.sruo) / cms < beta - EPS) continue;     // ② lubuo 不夠，剪掉
            if (ubuo(x, cms) < beta - EPS) continue;               // ③ ubuo 不夠，剪掉
            List<Node> ncl = extend(x, cl);
            if (!ncl.isEmpty()) search(ncl, result);               // 以 x 為前綴往下找
        }
    }

    /** uo + ruo 最大的 ⌈minSup⌉ 格取平均 */
    double ubuo(Node x, int cms) {
        List<Double> vec = new ArrayList<>();
        for (Entry e : x.entries) vec.add(e.uo + e.ruo);
        vec.sort(Collections.reverseOrder());
        double s = 0;
        for (int k = 0; k < cms; k++) s += vec.get(k);
        return s / cms;
    }

    /** 順著 x 每一格的索引往後跳，一次做出所有 x 再加一個商品的條件串列 */
    List<Node> extend(Node x, List<Node> cl) {
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
    }


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
}
