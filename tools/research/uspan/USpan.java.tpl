import java.util.*; «hide»
 «hide»
/** USpan：在有數量、有利潤的序列資料庫裡，找出所有高效益序列樣式 */ «hide»
public class USpan { «hide»
 «hide»
    /** 效益矩陣的一格：商品、效益 u、剩餘效益 ru（排在這格後面的所有效益加起來） */
    record Cell(String item, int u, int ru) {}

    /** db：每位顧客一個序列，依時間排好每次來店買的東西，寫成 {商品: 數量} */ «start»
    public static Map<List<List<String>>, Integer> uspan(List<List<Map<String, Integer>>> db, Map<String, Integer> profit, int minUtil) { «start»
        // 1. SWU：每位顧客的總效益 su，加給他買過的每個商品（同一人只加一次） «swu»
        int[] su = new int[db.size()]; «swu»
        Map<String, Integer> swu = new HashMap<>(); «swu»
        for (int sid = 0; sid < db.size(); sid++) { «swu»
            Set<String> seen = new HashSet<>(); «swu»
            for (Map<String, Integer> e : db.get(sid)) «swu»
                for (var en : e.entrySet()) { su[sid] += en.getValue() * profit.get(en.getKey()); seen.add(en.getKey()); } «swu»
            for (String x : seen) swu.merge(x, su[sid], Integer::sum); «swu»
        } «swu»
        Set<String> keep = new HashSet<>();                  // SWU 不到門檻的商品整個刪掉 «swu»
        swu.forEach((x, w) -> { if (w >= minUtil) keep.add(x); }); «swu»

        // 2. 每位顧客建一張效益矩陣 «matrix»
        List<List<List<Cell>>> mats = new ArrayList<>(); «matrix»
        for (var seq : db) mats.add(buildMatrix(seq, profit, keep)); «matrix»
        Map<List<List<String>>, Integer> result = new LinkedHashMap<>(); «end»
        Map<Integer, List<int[]>> root = new LinkedHashMap<>(); // 空樣式：還沒配對，效益 0 «end»
        for (int sid = 0; sid < db.size(); sid++) root.put(sid, List.of(new int[]{-1, 0})); «end»
        extend(mats, su, minUtil, new ArrayList<>(), root, result); // 從空樣式開始長 «end»
        return result; «end»
    } «end»

    static List<List<Cell>> buildMatrix(List<Map<String, Integer>> seq, Map<String, Integer> profit, Set<String> keep) { «matrix{»
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
    } «}matrix»

    /** proj：sid → [(k, acu)...]：前綴在第 sid 位顧客可以結束在第 k 次來店，結束在那裡的最大效益是 acu */
    static void extend(List<List<List<Cell>>> mats, int[] su, int minUtil, List<List<String>> prefix,
                       Map<Integer, List<int[]>> proj, Map<List<List<String>>, Integer> result) {
        // 1. 掃投影資料庫：哪些商品能 I-接（同一次）或 S-接（之後某次），順便算 SWU «scan»
        String last = prefix.isEmpty() ? null : prefix.get(prefix.size() - 1).get(prefix.get(prefix.size() - 1).size() - 1); «scan»
        Map<String, Integer> iSwu = new TreeMap<>(), sSwu = new TreeMap<>(); «scan»
        for (var en : proj.entrySet()) { «scan»
            var mat = mats.get(en.getKey()); «scan»
            List<int[]> ends = en.getValue(); «scan»
            Set<String> iItems = new HashSet<>(), sItems = new HashSet<>(); «scan»
            for (int[] end : ends) «scan»
                if (last != null && end[0] >= 0) «scan»
                    for (Cell c : mat.get(end[0])) if (c.item().compareTo(last) > 0) iItems.add(c.item()); // 同一次、排在 last 後面 «scan»
            for (int k = ends.get(0)[0] + 1; k < mat.size(); k++)  // 最早的結束位置之後的每一次 «scan»
                for (Cell c : mat.get(k)) sItems.add(c.item()); «scan»
            for (String x : iItems) iSwu.merge(x, su[en.getKey()], Integer::sum); «scan»
            for (String x : sItems) sSwu.merge(x, su[en.getKey()], Integer::sum); «scan»
        } «scan»

        // 2. I-接：x 跟前綴最後一次「同一次」買 «iext»
        for (String x : iSwu.keySet()) { «iext»
            if (iSwu.get(x) < minUtil) continue;                   // SWU 剪枝：有它的顧客總效益加起來都不夠 «width»
            Map<Integer, List<int[]>> next = new LinkedHashMap<>(); «iext»
            for (var en : proj.entrySet()) { «iext»
                List<int[]> e2 = new ArrayList<>(); «iext»
                for (int[] end : en.getValue()) «iext»
                    for (Cell c : mats.get(en.getKey()).get(end[0])) «iext»
                        if (c.item().equals(x)) e2.add(new int[]{end[0], end[1] + c.u()}); «iext»
                if (!e2.isEmpty()) next.put(en.getKey(), e2); «iext»
            } «iext»
            List<List<String>> pattern = new ArrayList<>(prefix); «iext»
            List<String> lastSet = new ArrayList<>(prefix.get(prefix.size() - 1)); «iext»
            lastSet.add(x); «iext»
            pattern.set(pattern.size() - 1, lastSet); «iext»
            check(mats, su, minUtil, pattern, next, result); «iext»
        } «iext»

        // 3. S-接：x 在「之後某一次」才買 «sext»
        for (String x : sSwu.keySet()) { «sext»
            if (sSwu.get(x) < minUtil) continue; «width»
            Map<Integer, List<int[]>> next = new LinkedHashMap<>(); «sext»
            for (var en : proj.entrySet()) { «sext»
                List<int[]> ends = en.getValue(), e2 = new ArrayList<>(); «sext»
                var mat = mats.get(en.getKey()); «sext»
                Integer best = null; «sext»
                int j = 0; «sext»
                for (int k = 0; k < mat.size(); k++) { «sext»
                    while (j < ends.size() && ends.get(j)[0] < k) {    // 結束在第 k 次之前的前綴，取效益最大的 «sext»
                        best = best == null ? ends.get(j)[1] : Math.max(best, ends.get(j)[1]); «sext»
                        j++; «sext»
                    } «sext»
                    for (Cell c : mat.get(k)) «sext»
                        if (c.item().equals(x) && best != null) e2.add(new int[]{k, best + c.u()}); «sext»
                } «sext»
                if (!e2.isEmpty()) next.put(en.getKey(), e2); «sext»
            } «sext»
            List<List<String>> pattern = new ArrayList<>(prefix); «sext»
            pattern.add(List.of(x)); «sext»
            check(mats, su, minUtil, pattern, next, result); «sext»
        } «sext»
    }

    /** 算新樣式的效益：每位顧客取最大的對應，再全部加起來 */ «check»
    static void check(List<List<List<Cell>>> mats, int[] su, int minUtil, List<List<String>> pattern, «check»
                      Map<Integer, List<int[]>> proj, Map<List<List<String>>, Integer> result) { «check»
        List<String> lastSet = pattern.get(pattern.size() - 1); «check»
        String last = lastSet.get(lastSet.size() - 1); «check»
        int util = 0, spu = 0; «check»
        for (var en : proj.entrySet()) { «check»
            int best = 0, bound = 0; «check»
            for (int[] end : en.getValue()) { «check»
                best = Math.max(best, end[1]);                     // 好幾種對應：取最大 «util»
                for (Cell c : mats.get(en.getKey()).get(end[0])) «spu»
                    if (c.item().equals(last) && c.ru() > 0) bound = Math.max(bound, end[1] + c.ru()); «spu»
            } «check»
            util += best; «util»
            spu += bound;                                          // SPU：前綴效益 + 後面還拿得到的全部 «spu»
        } «check»
        if (util >= minUtil) result.put(pattern, util); «util»
        if (spu >= minUtil) extend(mats, su, minUtil, pattern, proj, result); // SPU 剪枝：不夠就整棵子樹都不用看 «spu»
    } «check»
 «hide{»

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
} «}hide»
