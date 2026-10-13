import java.util.*;

/** 關聯規則：從頻繁樣式 Z 切出「前件 X → 後件 Y」，留下信賴度夠高的，並算提升度 */
public class AssocRules {

    public static List<Rule> genRules(List<Set<String>> db, int minSup, double minConf) {
        Map<List<String>, Integer> sup = frequentItemsets(db, minSup);  // 先用 Apriori 找頻繁樣式和次數
        List<Rule> rules = new ArrayList<>();
        for (List<String> z : sup.keySet()) {
            if (z.size() < 2) continue;                   // 一個商品切不出規則
            List<List<String>> H = new ArrayList<>();
            for (String i : z) H.add(List.of(i));          // 後件先從 1 個商品開始
            for (int m = 1; !H.isEmpty() && m < z.size(); m++) {  // 前件至少要留 1 個
                List<List<String>> passed = new ArrayList<>();
                for (List<String> y : H) {
                    List<String> x = new ArrayList<>(z);
                    x.removeAll(y);                        // 前件 = Z 拿掉後件
                    double conf = (double) sup.get(z) / sup.get(x);
                    if (conf >= minConf) {
                        double lift = conf / ((double) sup.get(y) / db.size());
                        rules.add(new Rule(x, y, sup.get(z), conf, lift));
                        passed.add(y);
                    }
                }
                H = grow(passed, m + 1);                   // 只拿過關的後件拼成大一號的
            }
        }
        return rules;
    }

    /** Apriori（細節見上一頁）：回傳 {頻繁樣式: 出現次數}，一層一層、同層照字典順序 */
    static Map<List<String>, Integer> frequentItemsets(List<Set<String>> db, int minSup) {
        Map<List<String>, Integer> sup = new LinkedHashMap<>();
        TreeSet<String> items = new TreeSet<>();
        for (Set<String> t : db) items.addAll(t);
        List<List<String>> C = new ArrayList<>();
        for (String i : items) C.add(List.of(i));
        while (!C.isEmpty()) {
            List<List<String>> L = new ArrayList<>();
            for (List<String> c : C) {
                int n = 0;
                for (Set<String> t : db) if (t.containsAll(c)) n++;
                if (n >= minSup) { L.add(c); sup.put(c, n); }
            }
            C = grow(L, C.get(0).size() + 1);              // 同一套合併＋剪枝
        }
        return sup;
    }

    /** 合併＋剪枝：兩個前 k-2 個相同的拼成 k 個，而且它每個 k-1 個的子集合都要在 H 裡 */
    static List<List<String>> grow(List<List<String>> H, int k) {
        Set<List<String>> ok = new HashSet<>(H);
        List<List<String>> C = new ArrayList<>();
        for (int i = 0; i < H.size(); i++)
            for (int j = i + 1; j < H.size(); j++) {
                List<String> a = H.get(i), b = H.get(j);
                if (!a.subList(0, k - 2).equals(b.subList(0, k - 2))) continue;
                List<String> c = new ArrayList<>(a);
                c.add(b.get(k - 2));
                boolean allOk = true;
                for (int d = 0; d < k; d++) {
                    List<String> sub = new ArrayList<>(c);
                    sub.remove(d);                         // 拿掉第 d 個 = 一個子集合
                    if (!ok.contains(sub)) allOk = false;  // 子集合沒過關，c 一定也過不了
                }
                if (allOk) C.add(c);
            }
        return C;
    }

    static class Rule {
        final List<String> x, y;
        final int support;
        final double conf, lift;

        Rule(List<String> x, List<String> y, int support, double conf, double lift) {
            this.x = x; this.y = y; this.support = support; this.conf = conf; this.lift = lift;
        }

        @Override
        public String toString() {
            return String.format(Locale.ROOT, "%s -> %s  支持度=%d 信賴度=%.2f 提升度=%.2f", x, y, support, conf, lift);
        }
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
        for (Rule r : genRules(db, 3, 0.7))
            System.out.println(r);
    }
}
