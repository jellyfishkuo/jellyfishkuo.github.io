import java.util.*;

/** Eclat：把交易轉成「商品 → 出現在哪幾筆交易」的垂直格式，再用交集深度優先找出所有頻繁樣式 */
public class Eclat {

    public static Map<List<String>, Integer> eclat(List<Set<String>> db, int minSup) {
        Map<String, List<Integer>> vertical = toVertical(db);      // 只掃這一次資料庫
        List<String> items = new ArrayList<>();                     // 第一層等價類（前綴是空的）
        List<List<Integer>> tids = new ArrayList<>();
        for (String item : vertical.keySet())
            if (vertical.get(item).size() >= minSup) {
                items.add(item);
                tids.add(vertical.get(item));
            }
        Map<List<String>, Integer> result = new LinkedHashMap<>();
        mine(new ArrayList<>(), items, tids, minSup, result);
        return result;
    }

    /** 掃一次資料庫：每個商品記下它出現在哪幾筆交易（交易編號從 1 開始） */
    static Map<String, List<Integer>> toVertical(List<Set<String>> db) {
        Map<String, List<Integer>> vertical = new TreeMap<>();
        for (int tid = 1; tid <= db.size(); tid++)
            for (String item : db.get(tid - 1))
                vertical.computeIfAbsent(item, k -> new ArrayList<>()).add(tid);
        return vertical;
    }

    /** 一個等價類：prefix 加上 items[i] 的組合，出現在 tids[i] 這些交易裡 */
    static void mine(List<String> prefix, List<String> items, List<List<Integer>> tids,
                     int minSup, Map<List<String>, Integer> result) {
        for (int i = 0; i < items.size(); i++) {
            List<String> pattern = new ArrayList<>(prefix);
            pattern.add(items.get(i));
            result.put(pattern, tids.get(i).size());                 // 交易編號有幾個，支持度就是多少
            List<String> nextItems = new ArrayList<>();               // 下一層等價類（前綴是 pattern）
            List<List<Integer>> nextTids = new ArrayList<>();
            for (int j = i + 1; j < items.size(); j++) {
                List<Integer> t = intersect(tids.get(i), tids.get(j));
                if (t.size() >= minSup) {
                    nextItems.add(items.get(j));
                    nextTids.add(t);
                }
            }
            if (!nextItems.isEmpty())
                mine(pattern, nextItems, nextTids, minSup, result);   // 往下一層挖
        }
    }

    /** 兩個排好序的交易編號清單取交集：兩個指標一起往前走 */
    static List<Integer> intersect(List<Integer> a, List<Integer> b) {
        List<Integer> out = new ArrayList<>();
        int p = 0, q = 0;
        while (p < a.size() && q < b.size()) {
            int x = a.get(p), y = b.get(q);
            if (x == y) { out.add(x); p++; q++; }
            else if (x < y) p++;
            else q++;
        }
        return out;
    }

    public static void main(String[] args) {
        List<Set<String>> db = List.of(
            Set.of("咖啡", "麵包", "牛奶"),
            Set.of("咖啡", "麵包", "茶葉蛋"),
            Set.of("咖啡", "麵包", "牛奶", "飯糰"),
            Set.of("麵包", "牛奶", "洋芋片"),
            Set.of("咖啡", "牛奶", "茶葉蛋"),
            Set.of("咖啡", "麵包", "牛奶", "茶葉蛋"),
            Set.of("飯糰", "茶葉蛋", "洋芋片"),
            Set.of("咖啡", "麵包", "飯糰"));
        eclat(db, 3).forEach((pattern, sup) -> System.out.println(pattern + " " + sup));
    }
}
