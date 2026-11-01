import java.util.*;

/** PreTK：資料一批一批進來時的 top-k 高效益樣式（pre-large 概念＋門檻拉高策略） */
public class PreTK {

    /** 一個商品組合的 utility list：出現在哪些交易，以及在那筆交易裡的 iutil、rutil */
    static class UtilityList {
        List<String> items;
        Map<Integer, int[]> entries = new LinkedHashMap<>();   // tid -> {iutil, rutil}
        int sumIutil, sumRutil;
        UtilityList(List<String> items) { this.items = items; }
        void add(int tid, int iutil, int rutil) {
            entries.put(tid, new int[] { iutil, rutil });
            sumIutil += iutil;
            sumRutil += rutil;
        }
    }

    /** 挖掘時的前 k 名。heap 是最小堆積，只放效益、最多 k 個，heap.peek() 就是目前的第 k 名 */
    static class TopK {
        int k, minUtil;                                    // 起始門檻（S1、S2、S4 取最大的），只會往上調
        PriorityQueue<Integer> heap = new PriorityQueue<>();
        Map<List<String>, Integer> result = new LinkedHashMap<>();   // 效益 >= 門檻的組合
        TopK(int k, int minUtil) { this.k = k; this.minUtil = minUtil; }

        void offer(List<String> items, int util) {
            List<String> key = new ArrayList<>(items);
            Collections.sort(key);
            result.put(key, util);
            heap.add(util);
            if (heap.size() > k) heap.poll();              // 超過 k 個，把最小的踢掉
            if (heap.size() == k && heap.peek() > minUtil) {
                minUtil = heap.peek();                     // S3：第 k 名變高了，門檻跟著拉高
                result.values().removeIf(u -> u < minUtil);
            }
        }
    }

    /** 第 k 大的數；不到 k 個就是 0 */
    static int kth(Collection<Integer> values, int k) {
        List<Integer> v = new ArrayList<>(values);
        v.sort(Collections.reverseOrder());
        return v.size() >= k ? v.get(k - 1) : 0;
    }

    /** 排名：效益高的在前；同分時短的在前，再照商品名稱 */
    static int rank(Map.Entry<List<String>, Integer> a, Map.Entry<List<String>, Integer> b) {
        if (!a.getValue().equals(b.getValue())) return b.getValue() - a.getValue();
        List<String> x = a.getKey(), y = b.getKey();
        if (x.size() != y.size()) return x.size() - y.size();
        for (int i = 0; i < x.size(); i++) {
            int c = x.get(i).compareTo(y.get(i));
            if (c != 0) return c;
        }
        return 0;
    }

    // 樹上存前 kUpper 名（Large + Pre-large），答案是前 kLower 名（Large）
    Map<String, Integer> profit;
    int kLower, kUpper;
    Map<String, List<int[]>> gul = new LinkedHashMap<>();   // Global-Utility-List：商品 -> {tid, 效益}，讀過就不用再掃
    Map<String, Integer> gtwu = new HashMap<>();            // Global-TWU-Map：商品 -> 到目前為止的 TWU
    int n = 0;                                              // 一共讀了幾筆交易
    Map<List<String>, Integer> tree = new LinkedHashMap<>();  // itemset-tree：前 kUpper 名的組合 -> 效益
    int minUpper = 0;                                       // 樹上第 kLower 名的效益（Large 的門檻）
    int minLower = 0;                                       // 樹上第 kUpper 名的效益（Pre-large 的門檻）
    int ceiling = 0;                                        // 不在樹上的組合，效益最多這麼多

    PreTK(Map<String, Integer> profit, int kLower, int kUpper) {
        this.profit = profit;
        this.kLower = kLower;
        this.kUpper = kUpper;
    }

    /** 讀進一批新交易；回傳 true 表示這批有重新挖掘 */
    boolean addBatch(List<Map<String, Integer>> batch) {
        // 1. 讀這一批：存進 Global-Utility-List，更新全部的 TWU 和這一批的 TWU
        Map<String, Integer> twuBatch = new HashMap<>();
        for (Map<String, Integer> t : batch) {
            int tu = 0;
            for (String i : t.keySet()) tu += t.get(i) * profit.get(i);
            for (String i : t.keySet()) {
                gul.computeIfAbsent(i, x -> new ArrayList<>()).add(new int[] { n, t.get(i) * profit.get(i) });
                gtwu.merge(i, tu, Integer::sum);
                twuBatch.merge(i, tu, Integer::sum);
            }
            n++;
        }
        // 2. 重挖條件：樹外的組合這批最多長 max TWU，追不上第 kLower 名就不用重挖
        int grow = 0;
        for (int v : twuBatch.values()) grow = Math.max(grow, v);
        if (!tree.isEmpty() && grow < minUpper - ceiling) {
            updateTree(batch, grow);
            return false;
        }
        mine();
        return true;
    }

    /** 不重挖：只把這一批的效益加到樹上的組合 */
    void updateTree(List<Map<String, Integer>> batch, int grow) {
        for (List<String> items : tree.keySet()) {
            for (Map<String, Integer> t : batch) {
                if (!t.keySet().containsAll(items)) continue;
                int u = 0;
                for (String i : items) u += t.get(i) * profit.get(i);
                tree.merge(items, u, Integer::sum);
            }
        }
        ceiling += grow;                                    // 樹外的組合這批最多也長了 grow
        minUpper = kth(tree.values(), kLower);
        minLower = kth(tree.values(), kUpper);
    }

    /** GLIU：商品照 TWU 排好，交易裡「排序上連在一起」的一段商品，效益加起來 */
    Map<String, Integer> gliu() {
        List<String> order = new ArrayList<>(gul.keySet());
        order.sort((a, b) -> gtwu.get(a).equals(gtwu.get(b)) ? a.compareTo(b) : gtwu.get(a) - gtwu.get(b));
        List<Map<Integer, Integer>> rows = new ArrayList<>();   // 每筆交易：排序位置 -> 效益
        for (int tid = 0; tid < n; tid++) rows.add(new TreeMap<>());
        for (int k = 0; k < order.size(); k++)
            for (int[] e : gul.get(order.get(k))) rows.get(e[0]).put(k, e[1]);
        Map<String, Integer> table = new HashMap<>();
        for (Map<Integer, Integer> row : rows) {
            List<Integer> ks = new ArrayList<>(row.keySet());
            for (int a = 0; a < ks.size(); a++) {
                int acc = row.get(ks.get(a));
                for (int b = a + 1; b < ks.size(); b++) {
                    if (ks.get(b) != ks.get(b - 1) + 1) break;  // 中間缺了一個，就不連續了
                    acc += row.get(ks.get(b));
                    table.merge(ks.get(a) + "-" + ks.get(b), acc, Integer::sum);
                }
            }
        }
        return table;
    }

    void mine() {
        // 3. 門檻拉高：S1 單一商品、S2 GLIU、S4 上次的第 kUpper 名，取最大的當起始門檻
        List<Integer> single = new ArrayList<>();
        for (List<int[]> lst : gul.values()) {
            int s = 0;
            for (int[] e : lst) s += e[1];
            single.add(s);
        }
        int s1 = kth(single, kUpper), s2 = kth(gliu().values(), kUpper);
        int minUtil = Math.max(Math.max(s1, s2), minLower);
        // 4. 從 Global-Utility-List 重建 utility list（不重掃舊交易），TWU 不夠的商品先不用
        List<String> order = new ArrayList<>();
        for (String i : gul.keySet()) if (gtwu.get(i) >= minUtil) order.add(i);
        order.sort((a, b) -> gtwu.get(a).equals(gtwu.get(b)) ? a.compareTo(b) : gtwu.get(a) - gtwu.get(b));
        int[] rua = new int[n];                  // Remaining Utility Array：每筆交易排在後面的商品效益總和
        LinkedList<UtilityList> lists = new LinkedList<>();
        for (int k = order.size() - 1; k >= 0; k--) {
            UtilityList ul = new UtilityList(List.of(order.get(k)));
            for (int[] e : gul.get(order.get(k))) {
                ul.add(e[0], e[1], rua[e[0]]);
                rua[e[0]] += e[1];
            }
            lists.addFirst(ul);
        }
        TopK board = new TopK(kUpper, minUtil);
        search(null, lists, board);
        // 5. 前 kUpper 名寫進新的 itemset-tree（同分的照商品名稱排）
        List<Map.Entry<List<String>, Integer>> best = new ArrayList<>(board.result.entrySet());
        best.sort(PreTK::rank);
        tree = new LinkedHashMap<>();
        for (Map.Entry<List<String>, Integer> e : best.subList(0, Math.min(kUpper, best.size()))) tree.put(e.getKey(), e.getValue());
        minUpper = kth(tree.values(), kLower);
        minLower = kth(tree.values(), kUpper);
        ceiling = minLower;                      // 沒進樹的組合，效益都不超過第 kUpper 名
    }

    /** 前 kLower 名直接從樹上拿 */
    List<Map.Entry<List<String>, Integer>> answer() {
        List<Map.Entry<List<String>, Integer>> best = new ArrayList<>(tree.entrySet());
        best.sort(PreTK::rank);
        return best.subList(0, Math.min(kLower, best.size()));
    }

    static void search(UtilityList p, List<UtilityList> uls, TopK board) {
        for (int i = 0; i < uls.size(); i++) {
            UtilityList x = uls.get(i);
            if (x.sumIutil >= board.minUtil) board.offer(x.items, x.sumIutil);     // 夠格進前 kUpper 名
            if (x.sumIutil + x.sumRutil < board.minUtil) continue;                 // 上界連門檻都不到，剪掉
            List<UtilityList> ext = new ArrayList<>();
            for (int j = i + 1; j < uls.size(); j++) {
                UtilityList xy = construct(p, x, uls.get(j));
                if (!xy.entries.isEmpty()) ext.add(xy);                            // 沒有共同交易的就不要
            }
            search(x, ext, board);                                                 // 遞迴：以 x 為前綴往下找
        }
    }

    /** 合併 Px 和 Py 的 utility list，得到 Pxy 的（跟 HUI-Miner 一樣） */
    static UtilityList construct(UtilityList p, UtilityList px, UtilityList py) {
        List<String> items = new ArrayList<>(px.items);
        items.add(py.items.get(py.items.size() - 1));
        UtilityList pxy = new UtilityList(items);
        for (int tid : px.entries.keySet()) {
            int[] ex = px.entries.get(tid), ey = py.entries.get(tid);
            if (ey == null) continue;                                    // 這筆交易沒有 y
            int iutil = ex[0] + ey[0];
            if (p != null) iutil -= p.entries.get(tid)[0];               // P 的效益兩邊都算了，扣掉一次
            pxy.add(tid, iutil, ey[1]);                                  // rutil 用 Py 的（y 排在 x 後面）
        }
        return pxy;
    }


    public static void main(String[] args) {
        Map<String, Integer> profit = Map.of("咖啡", 30, "麵包", 15, "牛奶", 20, "飯糰", 10, "茶葉蛋", 5, "洋芋片", 25);
        String[] labels = { "D", "ID1", "ID2", "ID3", "ID4" };
        List<List<Map<String, Integer>>> batches = List.of(   // 每筆交易：商品 -> 購買數量；第一批是原始資料庫 D
            List.of(Map.of("咖啡", 4, "麵包", 2, "牛奶", 2),
                    Map.of("咖啡", 3, "麵包", 5, "茶葉蛋", 4),
                    Map.of("咖啡", 1, "麵包", 1, "牛奶", 2, "飯糰", 2),
                    Map.of("麵包", 3, "牛奶", 4, "洋芋片", 5),
                    Map.of("咖啡", 3, "牛奶", 2, "茶葉蛋", 2),
                    Map.of("咖啡", 1, "麵包", 2, "牛奶", 1, "茶葉蛋", 1),
                    Map.of("飯糰", 1, "茶葉蛋", 2, "洋芋片", 2),
                    Map.of("咖啡", 1, "麵包", 2, "飯糰", 1)),
            List.of(Map.of("咖啡", 1, "麵包", 2, "牛奶", 1)),
            List.of(Map.of("麵包", 2, "茶葉蛋", 2)),
            List.of(Map.of("咖啡", 2, "牛奶", 2)),
            List.of(Map.of("飯糰", 1, "茶葉蛋", 1)));
        PreTK miner = new PreTK(profit, 3, 10);         // 答案要前 3 名，樹上多存到第 10 名
        for (int b = 0; b < batches.size(); b++) {
            boolean remined = miner.addBatch(batches.get(b));
            System.out.println(labels[b] + "：" + (remined ? "重新挖掘" : "不用重挖，只更新樹")
                + "　minU_upper = " + miner.minUpper + "，minU_lower = " + miner.minLower + "，樹外上限 = " + miner.ceiling);
            for (Map.Entry<List<String>, Integer> e : miner.answer())
                System.out.println("  {" + String.join(", ", e.getKey()) + "} 效益 = " + e.getValue());
        }
    }
}
