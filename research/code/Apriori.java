import java.util.*;

/** Apriori：一層一層找出所有頻繁樣式（同時出現次數 >= minSup 的商品組合） */
public class Apriori {

    public static List<List<String>> apriori(List<Set<String>> db, int minSup) {
        List<List<String>> result = new ArrayList<>();
        List<List<String>> L = frequentItems(db, minSup);           // L1：單一商品
        for (int k = 2; !L.isEmpty(); k++) {
            result.addAll(L);
            List<List<String>> C = join(L, k);                       // ① 合併
            Set<List<String>> prev = new HashSet<>(L);
            C.removeIf(c -> hasInfrequentSubset(c, prev));           // ② 剪枝
            Map<List<String>, Integer> count = countSupport(db, C);  // ③ 計數
            L = new ArrayList<>();
            for (List<String> c : C)                                 // ④ 篩選
                if (count.get(c) >= minSup) L.add(c);
        }
        return result;
    }

    /** 掃一次資料庫，數每個商品出現幾次 */
    static List<List<String>> frequentItems(List<Set<String>> db, int minSup) {
        Map<String, Integer> count = new TreeMap<>();
        for (Set<String> t : db)
            for (String item : t)
                count.merge(item, 1, Integer::sum);
        List<List<String>> L = new ArrayList<>();
        for (String item : count.keySet())
            if (count.get(item) >= minSup) L.add(List.of(item));
        return L;
    }

    /** 兩個 k-1 個的樣式，前 k-2 個都一樣，才合併成 k 個的候選 */
    static List<List<String>> join(List<List<String>> L, int k) {
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
    }

    /** 只要有一個 k-1 個的子集合不頻繁，這個候選就不可能頻繁 */
    static boolean hasInfrequentSubset(List<String> c, Set<List<String>> prev) {
        for (int i = 0; i < c.size(); i++) {
            List<String> sub = new ArrayList<>(c);
            sub.remove(i);                        // 拿掉第 i 個，就是一個子集合
            if (!prev.contains(sub)) return true;
        }
        return false;
    }

    /** 再掃一次資料庫，數每個候選出現在幾筆交易裡 */
    static Map<List<String>, Integer> countSupport(List<Set<String>> db, List<List<String>> C) {
        Map<List<String>, Integer> count = new HashMap<>();
        for (List<String> c : C) count.put(c, 0);
        for (Set<String> t : db)
            for (List<String> c : C)
                if (t.containsAll(c)) count.merge(c, 1, Integer::sum);
        return count;
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
        for (List<String> pattern : apriori(db, 3))
            System.out.println(pattern);
    }
}
