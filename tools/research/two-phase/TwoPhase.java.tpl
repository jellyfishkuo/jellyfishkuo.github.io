import java.util.*; «hide»
 «hide»
/** Two-Phase：先用 TWU 一層一層找出候選，再掃一次資料庫算真正的效益，留下高效益樣式 */ «hide»
public class TwoPhase { «hide»
 «hide»
    public static Map<List<String>, Integer> twoPhase(List<Map<String, Integer>> db, Map<String, Integer> profit, int minUtil) { «start»
        // ── 第一階段 ── 第 1 次掃描：每筆交易的效益 TU，加進它裡面每個商品的 TWU «tu»
        int[] tu = new int[db.size()]; «tu»
        Map<String, Integer> twu = new HashMap<>(); «tu»
        for (int tid = 0; tid < db.size(); tid++) { «tu»
            Map<String, Integer> t = db.get(tid); «tu»
            for (String item : t.keySet()) tu[tid] += t.get(item) * profit.get(item); «tu»
            for (String item : t.keySet()) twu.merge(item, tu[tid], Integer::sum); «tu»
        } «tu»
        // TWU 夠的商品照 TWU 由小到大排，就是第 1 層 «L1»
        List<String> order = new ArrayList<>(); «L1»
        for (String item : twu.keySet()) if (twu.get(item) >= minUtil) order.add(item); «L1»
        order.sort((a, b) -> twu.get(a).equals(twu.get(b)) ? a.compareTo(b) : twu.get(a) - twu.get(b)); «L1»
        List<List<String>> L = new ArrayList<>(); «L1»
        for (String item : order) L.add(List.of(item)); «L1»
        List<List<String>> cands = new ArrayList<>(L);   // 所有 TWU 夠的組合（HTWUI），留給第二階段驗證 «L1»
        for (int k = 2; !L.isEmpty(); k++) { «loop»
            List<List<String>> C = join(L, k);                       // ① 合併 «join»
            Set<List<String>> prev = new HashSet<>(L); «prune»
            C.removeIf(c -> hasLowSubset(c, prev));                   // ② 剪枝 «prune»
            if (C.isEmpty()) break; «prune»
            Map<List<String>, Integer> cTwu = countTwu(db, tu, C);   // ③ 再掃一次，算 TWU «count»
            L = new ArrayList<>(); «filter»
            for (List<String> c : C)                                 // ④ 篩選 «filter»
                if (cTwu.get(c) >= minUtil) L.add(c); «filter»
            cands.addAll(L); «filter»
        }
        // ── 第二階段 ── 最後再掃一次，算每個候選真正的效益 «phase2»
        Map<List<String>, Integer> util = countUtility(db, profit, cands); «phase2»
        Map<List<String>, Integer> result = new LinkedHashMap<>(); «verify»
        for (List<String> c : cands) «verify»
            if (util.get(c) >= minUtil) result.put(c, util.get(c));  // 真的夠才輸出 «verify»
        return result; «end»
    }

    /** 兩個 k-1 個的組合，前 k-2 個都一樣，才合併成 k 個的候選 */
    static List<List<String>> join(List<List<String>> L, int k) { «join{»
        List<List<String>> C = new ArrayList<>();
        for (int i = 0; i < L.size(); i++)
            for (int j = i + 1; j < L.size(); j++) {
                List<String> a = L.get(i), b = L.get(j);
                if (a.subList(0, k - 2).equals(b.subList(0, k - 2))) {
                    List<String> c = new ArrayList<>(a);
                    c.add(b.get(k - 2));
                    C.add(c);
                }
            }
        return C;
    } «}join»

    /** 只要有一個 k-1 個的子集合 TWU 不夠，這個候選的 TWU 也一定不夠 */
    static boolean hasLowSubset(List<String> c, Set<List<String>> prev) { «prune{»
        for (int i = 0; i < c.size(); i++) {
            List<String> sub = new ArrayList<>(c);
            sub.remove(i);                        // 拿掉第 i 個，就是一個子集合
            if (!prev.contains(sub)) return true;
        }
        return false;
    } «}prune»

    /** 掃一次資料庫：包含候選的交易，TU 加起來就是它的 TWU */
    static Map<List<String>, Integer> countTwu(List<Map<String, Integer>> db, int[] tu, List<List<String>> C) { «count{»
        Map<List<String>, Integer> twu = new HashMap<>();
        for (List<String> c : C) twu.put(c, 0);
        for (int tid = 0; tid < db.size(); tid++)
            for (List<String> c : C)
                if (db.get(tid).keySet().containsAll(c)) twu.merge(c, tu[tid], Integer::sum);
        return twu;
    } «}count»

    /** 掃一次資料庫：包含候選的交易，只加候選裡那幾樣的「數量 × 利潤」 */
    static Map<List<String>, Integer> countUtility(List<Map<String, Integer>> db, Map<String, Integer> profit, List<List<String>> cands) { «phase2{»
        Map<List<String>, Integer> util = new HashMap<>();
        for (List<String> c : cands) util.put(c, 0);
        for (Map<String, Integer> t : db)
            for (List<String> c : cands)
                if (t.keySet().containsAll(c))
                    for (String item : c) util.merge(c, t.get(item) * profit.get(item), Integer::sum);
        return util;
    } «}phase2»
 «hide{»
    public static void main(String[] args) {
        Map<String, Integer> profit = Map.of("咖啡", 30, "麵包", 15, "牛奶", 20, "飯糰", 10, "茶葉蛋", 5, "洋芋片", 25);
        List<Map<String, Integer>> db = List.of(        // 每筆交易：商品 -> 購買數量
            Map.of("咖啡", 4, "麵包", 2, "牛奶", 2),
            Map.of("咖啡", 3, "麵包", 5, "茶葉蛋", 4),
            Map.of("咖啡", 1, "麵包", 1, "牛奶", 2, "飯糰", 2),
            Map.of("麵包", 3, "牛奶", 4, "洋芋片", 5),
            Map.of("咖啡", 3, "牛奶", 2, "茶葉蛋", 2),
            Map.of("咖啡", 1, "麵包", 2, "牛奶", 1, "茶葉蛋", 1),
            Map.of("飯糰", 1, "茶葉蛋", 2, "洋芋片", 2),
            Map.of("咖啡", 1, "麵包", 2, "飯糰", 1));
        twoPhase(db, profit, 250).forEach((items, u) ->
            System.out.println("{" + String.join(", ", items) + "} 效益 = " + u));
    }
} «}hide»
