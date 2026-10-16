import java.util.*; «hide»
 «hide»
/** SPADE：把資料轉成垂直格式（id-list），用 temporal join 一路長出序列樣式 */ «hide»
public class SPADE { «hide»
 «hide»
    /** 一個位置：第 sid 位顧客的第 eid 次來店 */
    record Pos(int sid, int eid) {}

    /** 等價類裡的一個成員：樣式、它的 id-list、最後一個商品是不是自己一次（s） */
    record Atom(List<List<String>> pat, List<Pos> idList, boolean s) {}

    /** db：每位顧客一個序列，序列裡依時間排好每次來店買的東西（一次可以買好幾樣） */
    public static Map<List<List<String>>, Integer> spade(List<List<List<String>>> db, int minSup) { «start{»
        Map<List<List<String>>, Integer> result = new LinkedHashMap<>(); «}start»
        // 只掃一次資料庫：每個商品 → 出現在哪些 (sid, eid)＝第幾位顧客的第幾次來店 «vertical{»
        Map<String, List<Pos>> vert = new TreeMap<>();
        for (int sid = 0; sid < db.size(); sid++)
            for (int eid = 0; eid < db.get(sid).size(); eid++)
                for (String x : new TreeSet<>(db.get(sid).get(eid)))
                    vert.computeIfAbsent(x, z -> new ArrayList<>()).add(new Pos(sid, eid));
        List<Atom> atoms = new ArrayList<>();
        vert.forEach((x, list) -> {
            if (support(list) < minSup) return;
            result.put(List.of(List.of(x)), support(list));
            atoms.add(new Atom(List.of(List.of(x)), list, true));    // true：最後一個商品自己是「新的一次」
        }); «}vertical»
        enumerateClass(atoms, minSup, result); «end»
        return result; «end»
    }

    /** atoms：同一個等價類的成員（前綴都一樣，只差最後接上的那個商品） */
    static void enumerateClass(List<Atom> atoms, int minSup, Map<List<List<String>>, Integer> result) {
        for (Atom a : atoms) {                                        // 輪流當 A，跟同一類的每個 B 合併 «pair»
            List<Atom> children = new ArrayList<>(); «pair»
            List<String> aLast = a.pat().get(a.pat().size() - 1); «pair»
            for (Atom b : atoms) { «pair»
                List<String> bLast = b.pat().get(b.pat().size() - 1); «pair»
                String y = bLast.get(bLast.size() - 1);               // B 最後接上的那個商品 «pair»
                if (b.s() == a.s() && y.compareTo(aLast.get(aLast.size() - 1)) > 0) {  // I-step：y 跟 A 的最後一個商品同一次買 «istep»
                    List<List<String>> pat = new ArrayList<>(a.pat()); «istep»
                    List<String> last = new ArrayList<>(aLast); «istep»
                    last.add(y); «istep»
                    pat.set(pat.size() - 1, last); «istep»
                    keep(children, pat, equalJoin(a.idList(), b.idList()), false, minSup, result); «istep»
                } «istep»
                if (b.s()) {                                          // S-step：買 A 之後，後來再買 y «sstep»
                    List<List<String>> pat = new ArrayList<>(a.pat()); «sstep»
                    pat.add(List.of(y)); «sstep»
                    keep(children, pat, temporalJoin(a.idList(), b.idList()), true, minSup, result); «sstep»
                } «sstep»
            } «pair»
            enumerateClass(children, minSup, result);                 // A 長出來的樣式自成一類，往下挖 «recurse»
        }
    }

    /** 夠多人就記下來，也放進下一層的等價類 */
    static void keep(List<Atom> children, List<List<String>> pat, List<Pos> idList, boolean s, «keep{»
                     int minSup, Map<List<List<String>>, Integer> result) {
        if (support(idList) < minSup) return;
        result.put(pat, support(idList));
        children.add(new Atom(pat, idList, s));
    }

    static int support(List<Pos> idList) {
        Set<Integer> sids = new HashSet<>();                          // 支持度＝有幾位不同的顧客
        for (Pos p : idList) sids.add(p.sid());
        return sids.size();
    } «}keep»

    /** S-step：留下 B 的位置 (sid, eid)，條件是同一位顧客在更早的某一次就出現過 A */
    static List<Pos> temporalJoin(List<Pos> listA, List<Pos> listB) { «sstep{»
        Map<Integer, Integer> first = new HashMap<>();
        for (Pos p : listA) first.putIfAbsent(p.sid(), p.eid());     // id-list 照 (sid, eid) 排好，第一個就是最早的
        List<Pos> out = new ArrayList<>();
        for (Pos p : listB)
            if (first.containsKey(p.sid()) && first.get(p.sid()) < p.eid()) out.add(p);
        return out;
    } «}sstep»

    /** I-step：同一位顧客、同一次來店，A 和 B 都出現 */
    static List<Pos> equalJoin(List<Pos> listA, List<Pos> listB) { «istep{»
        Set<Pos> same = new HashSet<>(listA);
        List<Pos> out = new ArrayList<>();
        for (Pos p : listB) if (same.contains(p)) out.add(p);
        return out;
    } «}istep»
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
        spade(db, 3).forEach((pattern, sup) -> System.out.println(show(pattern) + " " + sup));
    }
} «}hide»
