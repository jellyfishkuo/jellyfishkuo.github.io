import java.util.*;

/** USpan：在有數量、有利潤的序列資料庫裡，找出所有高效益序列樣式 */
public class USpan {

    /** 效益矩陣的一格：商品、效益 u、剩餘效益 ru（排在這格後面的所有效益加起來） */
    record Cell(String item, int u, int ru) {}

    /** db：每位顧客一個序列，依時間排好每次來店買的東西，寫成 {商品: 數量} */
    public static Map<List<List<String>>, Integer> uspan(List<List<Map<String, Integer>>> db, Map<String, Integer> profit, int minUtil) {
        // 1. SWU：每位顧客的總效益 su，加給他買過的每個商品（同一人只加一次）
        int[] su = new int[db.size()];
        Map<String, Integer> swu = new HashMap<>();
        for (int sid = 0; sid < db.size(); sid++) {
            Set<String> seen = new HashSet<>();
            for (Map<String, Integer> e : db.get(sid))
                for (var en : e.entrySet()) { su[sid] += en.getValue() * profit.get(en.getKey()); seen.add(en.getKey()); }
            for (String x : seen) swu.merge(x, su[sid], Integer::sum);
        }
        Set<String> keep = new HashSet<>();                  // SWU 不到門檻的商品整個刪掉
        swu.forEach((x, w) -> { if (w >= minUtil) keep.add(x); });

        // 2. 每位顧客建一張效益矩陣
        List<List<List<Cell>>> mats = new ArrayList<>();
        for (var seq : db) mats.add(buildMatrix(seq, profit, keep));
        Map<List<List<String>>, Integer> result = new LinkedHashMap<>();
        Map<Integer, List<int[]>> root = new LinkedHashMap<>(); // 空樣式：還沒配對，效益 0
        for (int sid = 0; sid < db.size(); sid++) root.put(sid, List.of(new int[]{-1, 0}));
        extend(mats, su, minUtil, new ArrayList<>(), root, result); // 從空樣式開始長
        return result;
    }

    static List<List<Cell>> buildMatrix(List<Map<String, Integer>> seq, Map<String, Integer> profit, Set<String> keep) {
        List<List<Cell>> out = new ArrayList<>();
        int rest = 0;
        for (int k = seq.size() - 1; k >= 0; k--) {                // 從最後一次往前加
            List<String> items = new ArrayList<>(new TreeSet<>(seq.get(k).keySet()));
            items.retainAll(keep);
            LinkedList<Cell> col = new LinkedList<>();
            for (int j = items.size() - 1; j >= 0; j--) {
                String x = items.get(j);
                int u = seq.get(k).get(x) * profit.get(x);
                col.addFirst(new Cell(x, u, rest));
                rest += u;
            }
            out.add(0, col);
        }
        return out;
    }

    /** proj：sid → [(k, acu)...]：前綴在第 sid 位顧客可以結束在第 k 次來店，結束在那裡的最大效益是 acu */
    static void extend(List<List<List<Cell>>> mats, int[] su, int minUtil, List<List<String>> prefix,
                       Map<Integer, List<int[]>> proj, Map<List<List<String>>, Integer> result) {
        // 1. 掃投影資料庫：哪些商品能 I-接（同一次）或 S-接（之後某次），順便算 SWU
        String last = prefix.isEmpty() ? null : prefix.get(prefix.size() - 1).get(prefix.get(prefix.size() - 1).size() - 1);
        Map<String, Integer> iSwu = new TreeMap<>(), sSwu = new TreeMap<>();
        for (var en : proj.entrySet()) {
            var mat = mats.get(en.getKey());
            List<int[]> ends = en.getValue();
            Set<String> iItems = new HashSet<>(), sItems = new HashSet<>();
            for (int[] end : ends)
                if (last != null && end[0] >= 0)
                    for (Cell c : mat.get(end[0])) if (c.item().compareTo(last) > 0) iItems.add(c.item()); // 同一次、排在 last 後面
            for (int k = ends.get(0)[0] + 1; k < mat.size(); k++)  // 最早的結束位置之後的每一次
                for (Cell c : mat.get(k)) sItems.add(c.item());
            for (String x : iItems) iSwu.merge(x, su[en.getKey()], Integer::sum);
            for (String x : sItems) sSwu.merge(x, su[en.getKey()], Integer::sum);
        }

        // 2. I-接：x 跟前綴最後一次「同一次」買
        for (String x : iSwu.keySet()) {
            if (iSwu.get(x) < minUtil) continue;                   // SWU 剪枝：有它的顧客總效益加起來都不夠
            Map<Integer, List<int[]>> next = new LinkedHashMap<>();
            for (var en : proj.entrySet()) {
                List<int[]> e2 = new ArrayList<>();
                for (int[] end : en.getValue())
                    for (Cell c : mats.get(en.getKey()).get(end[0]))
                        if (c.item().equals(x)) e2.add(new int[]{end[0], end[1] + c.u()});
                if (!e2.isEmpty()) next.put(en.getKey(), e2);
            }
            List<List<String>> pattern = new ArrayList<>(prefix);
            List<String> lastSet = new ArrayList<>(prefix.get(prefix.size() - 1));
            lastSet.add(x);
            pattern.set(pattern.size() - 1, lastSet);
            check(mats, su, minUtil, pattern, next, result);
        }

        // 3. S-接：x 在「之後某一次」才買
        for (String x : sSwu.keySet()) {
            if (sSwu.get(x) < minUtil) continue;
            Map<Integer, List<int[]>> next = new LinkedHashMap<>();
            for (var en : proj.entrySet()) {
                List<int[]> ends = en.getValue(), e2 = new ArrayList<>();
                var mat = mats.get(en.getKey());
                Integer best = null;
                int j = 0;
                for (int k = 0; k < mat.size(); k++) {
                    while (j < ends.size() && ends.get(j)[0] < k) {    // 結束在第 k 次之前的前綴，取效益最大的
                        best = best == null ? ends.get(j)[1] : Math.max(best, ends.get(j)[1]);
                        j++;
                    }
                    for (Cell c : mat.get(k))
                        if (c.item().equals(x) && best != null) e2.add(new int[]{k, best + c.u()});
                }
                if (!e2.isEmpty()) next.put(en.getKey(), e2);
            }
            List<List<String>> pattern = new ArrayList<>(prefix);
            pattern.add(List.of(x));
            check(mats, su, minUtil, pattern, next, result);
        }
    }

    /** 算新樣式的效益：每位顧客取最大的對應，再全部加起來 */
    static void check(List<List<List<Cell>>> mats, int[] su, int minUtil, List<List<String>> pattern,
                      Map<Integer, List<int[]>> proj, Map<List<List<String>>, Integer> result) {
        List<String> lastSet = pattern.get(pattern.size() - 1);
        String last = lastSet.get(lastSet.size() - 1);
        int util = 0, spu = 0;
        for (var en : proj.entrySet()) {
            int best = 0, bound = 0;
            for (int[] end : en.getValue()) {
                best = Math.max(best, end[1]);                     // 好幾種對應：取最大
                for (Cell c : mats.get(en.getKey()).get(end[0]))
                    if (c.item().equals(last) && c.ru() > 0) bound = Math.max(bound, end[1] + c.ru());
            }
            util += best;
            spu += bound;                                          // SPU：前綴效益 + 後面還拿得到的全部
        }
        if (util >= minUtil) result.put(pattern, util);
        if (spu >= minUtil) extend(mats, su, minUtil, pattern, proj, result); // SPU 剪枝：不夠就整棵子樹都不用看
    }


    static final Map<String, Integer> PROFIT = Map.of("咖啡", 30, "麵包", 15, "牛奶", 20, "飯糰", 10, "茶葉蛋", 5, "洋芋片", 25);

    static String show(List<List<String>> pattern) {
        StringBuilder sb = new StringBuilder("<");
        for (List<String> e : pattern) sb.append("(").append(String.join(",", e)).append(")");
        return sb.append(">").toString();
    }

    public static void main(String[] args) {
        List<List<Map<String, Integer>>> db = List.of(
            List.of(Map.of("咖啡", 1, "麵包", 2), Map.of("飯糰", 2, "茶葉蛋", 3), Map.of("咖啡", 2, "洋芋片", 1)),
            List.of(Map.of("咖啡", 2), Map.of("飯糰", 1, "茶葉蛋", 2), Map.of("咖啡", 1, "麵包", 1)),
            List.of(Map.of("麵包", 3, "牛奶", 1), Map.of("牛奶", 2), Map.of("飯糰", 3)),
            List.of(Map.of("麵包", 1, "牛奶", 2), Map.of("咖啡", 1, "麵包", 2), Map.of("飯糰", 1, "洋芋片", 2)),
            List.of(Map.of("咖啡", 3, "麵包", 1, "茶葉蛋", 2), Map.of("飯糰", 2, "茶葉蛋", 1)),
            List.of(Map.of("牛奶", 1), Map.of("麵包", 2), Map.of("洋芋片", 3)));
        uspan(db, PROFIT, 200).forEach((pattern, util) -> System.out.println(show(pattern) + " " + util));
    }
}
