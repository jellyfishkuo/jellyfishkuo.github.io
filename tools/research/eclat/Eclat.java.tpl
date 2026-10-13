import java.util.*; «hide»
 «hide»
/** Eclat：把交易轉成「商品 → 出現在哪幾筆交易」的垂直格式，再用交集深度優先找出所有頻繁樣式 */ «hide»
public class Eclat { «hide»
 «hide»
    public static Map<List<String>, Integer> eclat(List<Set<String>> db, int minSup) { «start»
        Map<String, List<Integer>> vertical = toVertical(db);      // 只掃這一次資料庫 «scan»
        List<String> items = new ArrayList<>();                     // 第一層等價類（前綴是空的） «filter1»
        List<List<Integer>> tids = new ArrayList<>(); «filter1»
        for (String item : vertical.keySet()) «filter1»
            if (vertical.get(item).size() >= minSup) { «filter1»
                items.add(item); «filter1»
                tids.add(vertical.get(item)); «filter1»
            } «filter1»
        Map<List<String>, Integer> result = new LinkedHashMap<>(); «filter1»
        mine(new ArrayList<>(), items, tids, minSup, result); «filter1»
        return result; «end»
    }

    /** 掃一次資料庫：每個商品記下它出現在哪幾筆交易（交易編號從 1 開始） */
    static Map<String, List<Integer>> toVertical(List<Set<String>> db) { «scan{»
        Map<String, List<Integer>> vertical = new TreeMap<>();
        for (int tid = 1; tid <= db.size(); tid++)
            for (String item : db.get(tid - 1))
                vertical.computeIfAbsent(item, k -> new ArrayList<>()).add(tid);
        return vertical;
    } «}scan»

    /** 一個等價類：prefix 加上 items[i] 的組合，出現在 tids[i] 這些交易裡 */
    static void mine(List<String> prefix, List<String> items, List<List<Integer>> tids, «enter»
                     int minSup, Map<List<String>, Integer> result) { «enter»
        for (int i = 0; i < items.size(); i++) { «pick»
            List<String> pattern = new ArrayList<>(prefix); «pick»
            pattern.add(items.get(i)); «pick»
            result.put(pattern, tids.get(i).size());                 // 交易編號有幾個，支持度就是多少 «pick»
            List<String> nextItems = new ArrayList<>();               // 下一層等價類（前綴是 pattern） «pick»
            List<List<Integer>> nextTids = new ArrayList<>(); «pick»
            for (int j = i + 1; j < items.size(); j++) { «inter»
                List<Integer> t = intersect(tids.get(i), tids.get(j)); «inter»
                if (t.size() >= minSup) { «inter»
                    nextItems.add(items.get(j)); «inter»
                    nextTids.add(t); «inter»
                } «inter»
            } «inter»
            if (!nextItems.isEmpty()) «recurse»
                mine(pattern, nextItems, nextTids, minSup, result);   // 往下一層挖 «recurse,enter»
        }
    }

    /** 兩個排好序的交易編號清單取交集：兩個指標一起往前走 */
    static List<Integer> intersect(List<Integer> a, List<Integer> b) { «inter{»
        List<Integer> out = new ArrayList<>();
        int p = 0, q = 0;
        while (p < a.size() && q < b.size()) {
            int x = a.get(p), y = b.get(q);
            if (x == y) { out.add(x); p++; q++; }
            else if (x < y) p++;
            else q++;
        }
        return out;
    } «}inter»
 «hide{»
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
} «}hide»
