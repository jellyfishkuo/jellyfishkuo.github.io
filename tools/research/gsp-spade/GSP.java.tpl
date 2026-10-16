import java.util.*; «hide»
 «hide»
/** GSP：像 Apriori 一樣一層一層產生候選序列、掃資料庫計數 */ «hide»
public class GSP { «hide»
 «hide»
    /** db：每位顧客一個序列，序列裡依時間排好每次來店買的東西（一次可以買好幾樣） */
    public static Map<List<List<String>>, Integer> gsp(List<List<List<String>>> db, int minSup) { «start{»
        List<List<List<String>>> seqs = new ArrayList<>();
        for (List<List<String>> s : db) {
            List<List<String>> t = new ArrayList<>();
            for (List<String> e : s) t.add(new ArrayList<>(new TreeSet<>(e)));  // 同一次買的東西照字碼排
            seqs.add(t);
        }
        Map<List<List<String>>, Integer> result = new LinkedHashMap<>(); «}start»
        // 第 1 次掃描：每個商品有幾位顧客買過（一個人買幾次都只算 1） «L1{»
        Map<String, Integer> cnt = new TreeMap<>();
        for (List<List<String>> seq : seqs) {
            Set<String> seen = new HashSet<>();
            for (List<String> e : seq) seen.addAll(e);
            for (String x : seen) cnt.merge(x, 1, Integer::sum);
        }
        Map<List<List<String>>, Integer> level = new LinkedHashMap<>();
        cnt.forEach((x, n) -> { if (n >= minSup) level.put(List.of(List.of(x)), n); }); «}L1»
        int k = 1; «loop»
        while (!level.isEmpty()) {                                    // 上一層還有頻繁樣式，就往上找 «loop»
            result.putAll(level); «loop»
            k++; «loop»
            List<List<List<String>>> cands = join(new ArrayList<>(level.keySet()), k);  // ① 合併 «join»
            Map<List<List<String>>, Integer> next = new LinkedHashMap<>(); «prune,count,filter»
            for (List<List<String>> c : cands) { «prune,count,filter»
                boolean ok = true;                                    // ② 剪枝：連續子序列都要頻繁 «prune»
                for (List<List<String>> s : contiguousSubs(c)) «prune»
                    if (!level.containsKey(s)) { ok = false; break; } «prune»
                if (!ok) continue; «prune»
                int n = 0;                                            // ③ 掃一次資料庫，數每個候選 «count»
                for (List<List<String>> seq : seqs) if (contains(seq, c)) n++; «count»
                if (n >= minSup) next.put(c, n);                      // ④ 留下夠多人的 «filter»
            } «prune,count,filter»
            level.clear(); «filter»
            level.putAll(next); «filter»
        } «loop»
        return result; «end»
    }

    /** 把兩個 (k-1) 個商品的樣式拼成 k 個商品的候選 */
    static List<List<List<String>>> join(List<List<List<String>>> level, int k) { «join{»
        List<List<List<String>>> out = new ArrayList<>();
        if (k == 2) {                                                 // 兩個商品 x、y 有兩種拼法
            for (List<List<String>> a : level)
                for (List<List<String>> b : level) {
                    String x = a.get(0).get(0), y = b.get(0).get(0);
                    out.add(List.of(List.of(x), List.of(y)));         // <(x)(y)>：買 x 之後再買 y（x、y 可以一樣）
                    if (x.compareTo(y) < 0) out.add(List.of(List.of(x, y)));  // <(x y)>：同一次一起買
                }
            return out;
        }
        for (List<List<String>> a : level)
            for (List<List<String>> b : level) {
                if (!dropFirst(a).equals(dropLast(b))) continue;      // a 去掉第一個商品 == b 去掉最後一個商品
                List<String> bl = b.get(b.size() - 1);
                String y = bl.get(bl.size() - 1);
                List<List<String>> c = new ArrayList<>(a);
                if (bl.size() == 1) c.add(List.of(y));                // y 在 b 裡是自己一次 → 接成新的一次
                else {                                                // y 在 b 裡跟別的同一次買 → 放進 a 的最後一次
                    List<String> last = new ArrayList<>(c.get(c.size() - 1));
                    last.add(y);
                    c.set(c.size() - 1, last);
                }
                out.add(c);
            }
        return out;
    }

    static List<List<String>> dropFirst(List<List<String>> p) {
        List<List<String>> r = new ArrayList<>(p.subList(1, p.size()));
        if (p.get(0).size() > 1) r.add(0, p.get(0).subList(1, p.get(0).size()));
        return r;
    }

    static List<List<String>> dropLast(List<List<String>> p) {
        List<List<String>> r = new ArrayList<>(p.subList(0, p.size() - 1));
        List<String> e = p.get(p.size() - 1);
        if (e.size() > 1) r.add(e.subList(0, e.size() - 1));
        return r;
    } «}join»

    /** 連續子序列：從第一次或最後一次拿掉一個商品，或從買了 2 樣以上的那一次拿掉一個 */
    static List<List<List<String>>> contiguousSubs(List<List<String>> c) { «prune{»
        List<List<List<String>>> out = new ArrayList<>();
        for (int i = 0; i < c.size(); i++) {
            List<String> e = c.get(i);
            if (e.size() == 1 && i > 0 && i < c.size() - 1) continue;  // 中間只買 1 樣的那次不能拿掉（前後就不連續了）
            for (String x : e) {
                List<List<String>> s = new ArrayList<>(c);
                List<String> rest = new ArrayList<>(e);
                rest.remove(x);
                if (rest.isEmpty()) s.remove(i); else s.set(i, rest);
                out.add(s);
            }
        }
        return out;
    } «}prune»

    /** 由前往後比對：pat 的每一次都要依序被 seq 的某一次整個包含 */
    static boolean contains(List<List<String>> seq, List<List<String>> pat) { «count{»
        int i = 0;
        for (List<String> e : seq)
            if (i < pat.size() && e.containsAll(pat.get(i))) i++;
        return i == pat.size();
    } «}count»
 «hide{»

    static String show(List<List<String>> pattern) {
        StringBuilder sb = new StringBuilder("<");
        for (List<String> e : pattern) sb.append("(").append(String.join(",", e)).append(")");
        return sb.append(">").toString();
    }

    public static void main(String[] args) {
        List<List<List<String>>> db = List.of(
            List.of(List.of("咖啡", "麵包"), List.of("飯糰", "茶葉蛋"), List.of("洋芋片")),
            List.of(List.of("咖啡"), List.of("飯糰", "茶葉蛋"), List.of("咖啡", "麵包")),
            List.of(List.of("咖啡", "麵包"), List.of("牛奶"), List.of("飯糰")),
            List.of(List.of("麵包", "牛奶"), List.of("咖啡", "麵包"), List.of("飯糰", "洋芋片")),
            List.of(List.of("咖啡", "麵包", "茶葉蛋"), List.of("飯糰", "茶葉蛋")),
            List.of(List.of("牛奶"), List.of("麵包"), List.of("洋芋片")));
        gsp(db, 3).forEach((pattern, sup) -> System.out.println(show(pattern) + " " + sup));
    }
} «}hide»
