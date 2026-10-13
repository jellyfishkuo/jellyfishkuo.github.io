import java.util.*;

/** PrefixSpan：用「前綴投影」遞迴找出所有頻繁的序列樣式 */
public class PrefixSpan {

    /** 投影點：前綴的最後一個商品配對在第 sid 位顧客、第 e 次來店的第 p 個位置 */
    static class Proj {
        int sid, e, p;
        Proj(int sid, int e, int p) { this.sid = sid; this.e = e; this.p = p; }
    }

    /** db：每位顧客一個序列，序列裡依時間排好每次來店買的東西（一次可以買好幾樣） */
    public static Map<List<List<String>>, Integer> prefixSpan(List<List<List<String>>> db, int minSup) {
        List<List<List<String>>> seqs = new ArrayList<>();
        for (List<List<String>> s : db) {
            List<List<String>> t = new ArrayList<>();
            for (List<String> e : s) t.add(new ArrayList<>(new TreeSet<>(e)));  // 同一次買的東西照字碼排
            seqs.add(t);
        }
        List<Proj> proj = new ArrayList<>();
        for (int i = 0; i < seqs.size(); i++) proj.add(new Proj(i, -1, -1));  // 整個序列都是後綴
        Map<List<List<String>>, Integer> result = new LinkedHashMap<>();
        mine(seqs, minSup, new ArrayList<>(), proj, result);
        return result;
    }

    static void mine(List<List<List<String>>> db, int minSup, List<List<String>> prefix,
                     List<Proj> proj, Map<List<List<String>>, Integer> result) {
        // 1. 掃一遍投影資料庫，數每個商品能怎麼接在前綴後面
        List<String> last = prefix.isEmpty() ? null : prefix.get(prefix.size() - 1);
        Map<String, Integer> iCnt = new TreeMap<>(), sCnt = new TreeMap<>();
        for (Proj pr : proj) {
            List<List<String>> seq = db.get(pr.sid);
            Set<String> iSeen = new HashSet<>(), sSeen = new HashSet<>();  // 同一位顧客只算一次
            if (last != null) {
                List<String> cur = seq.get(pr.e);
                iSeen.addAll(cur.subList(pr.p + 1, cur.size()));  // 底線 _ 那一格：跟前綴最後一個商品同一次買的
                for (int k = pr.e + 1; k < seq.size(); k++)        // 後面某次也買齊了 last，排在後面的也算同一次
                    if (seq.get(k).containsAll(last))
                        for (String x : seq.get(k))
                            if (x.compareTo(last.get(last.size() - 1)) > 0) iSeen.add(x);
            }
            for (int k = pr.e + 1; k < seq.size(); k++)            // 之後任何一次來店買的：下一次才買
                sSeen.addAll(seq.get(k));
            for (String x : iSeen) iCnt.merge(x, 1, Integer::sum);
            for (String x : sSeen) sCnt.merge(x, 1, Integer::sum);
        }

        // 2. 夠多人的就接上去，變成新的樣式，再用它的投影資料庫遞迴
        for (String x : iCnt.keySet()) {                           // i-延伸：x 跟前綴最後一次「同一次」買
            if (iCnt.get(x) < minSup) continue;
            List<List<String>> pattern = new ArrayList<>(prefix);
            List<String> merged = new ArrayList<>(last);
            merged.add(x);
            pattern.set(pattern.size() - 1, merged);
            result.put(pattern, iCnt.get(x));
            mine(db, minSup, pattern, project(db, proj, last, x, true), result);  // 遞迴
        }
        for (String x : sCnt.keySet()) {                           // s-延伸：x 在「下一次以後」才買
            if (sCnt.get(x) < minSup) continue;
            List<List<String>> pattern = new ArrayList<>(prefix);
            pattern.add(List.of(x));
            result.put(pattern, sCnt.get(x));
            mine(db, minSup, pattern, project(db, proj, last, x, false), result);  // 遞迴
        }
    }

    /** 把每位顧客的投影點往後移到「第一個」能接上 x 的位置；接不上的顧客就不要了 */
    static List<Proj> project(List<List<List<String>>> db, List<Proj> proj, List<String> last, String x, boolean same) {
        List<Proj> out = new ArrayList<>();
        for (Proj pr : proj) {
            List<List<String>> seq = db.get(pr.sid);
            for (int k = same ? pr.e : pr.e + 1; k < seq.size(); k++) {
                int q = seq.get(k).indexOf(x);
                if (q < 0) continue;
                if (same && !(seq.get(k).containsAll(last) && q > seq.get(k).indexOf(last.get(last.size() - 1))))
                    continue;                                      // 同一次延伸：這次要買齊 last，x 還要排在後面
                out.add(new Proj(pr.sid, k, q));
                break;
            }
        }
        return out;
    }


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
        prefixSpan(db, 3).forEach((pattern, sup) -> System.out.println(show(pattern) + " " + sup));
    }
}
