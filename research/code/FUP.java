import java.util.*;

/** FUP（Fast UPdate）：資料庫新增一批交易 db 時，更新頻繁樣式而不用全部重算 */
public class FUP {

    static int reads = 0;   // 一共讀了幾筆交易（拿來比較成本）

    /** n 筆交易、門檻 pct% 時，至少要出現幾次才算頻繁（無條件進位） */
    static int need(int n, int pct) {
        return (n * pct + 99) / 100;
    }

    /** DB：舊資料庫；L：DB 的頻繁樣式和次數；db：新增的交易 */
    static Map<List<String>, Integer> fup(List<Set<String>> DB, Map<List<String>, Integer> L,
                                          List<Set<String>> db, int pct) {
        int N = DB.size() + db.size();
        Map<List<String>, Integer> newL = new LinkedHashMap<>();
        List<Set<String>> all = new ArrayList<>(DB);
        all.addAll(db);
        List<List<String>> C = singleItems(all);                   // 第 1 層：每個商品
        for (int k = 2; !C.isEmpty(); k++) {
            List<List<String>> old = new ArrayList<>(), fresh = new ArrayList<>();
            for (List<String> c : C)                                // 原本就頻繁的 / 新候選
                (L.containsKey(c) ? old : fresh).add(c);
            Map<List<String>, Integer> inDb = count(db, C);         // 掃 db 一次（只有新增的那幾筆）
            Map<List<String>, Integer> Lk = new LinkedHashMap<>();
            for (List<String> c : old)                              // 舊次數＋新次數，不用碰 DB
                if (L.get(c) + inDb.get(c) >= need(N, pct))
                    Lk.put(c, L.get(c) + inDb.get(c));
            // 引理：在 DB 不頻繁的樣式，要在 DB∪db 變頻繁，在 db 裡也一定頻繁
            fresh.removeIf(c -> inDb.get(c) < need(db.size(), pct));
            if (!fresh.isEmpty()) {
                Map<List<String>, Integer> inDB = count(DB, fresh); // 只有通過引理的新候選，才回頭掃 DB
                for (List<String> c : fresh)
                    if (inDB.get(c) + inDb.get(c) >= need(N, pct))
                        Lk.put(c, inDB.get(c) + inDb.get(c));
            }
            newL.putAll(Lk);
            C = aprioriGen(new ArrayList<>(Lk.keySet()), k);       // 下一層候選：跟 Apriori 一樣，從新的 L(k) 產生
        }
        return newL;
    }

    /** 合併前 k-2 個相同的兩個樣式，再剪掉有不頻繁子集合的 */
    static List<List<String>> aprioriGen(List<List<String>> L, int k) {
        L.sort(FUP::compare);                                    // 照字典順序排好，合併才不會漏
        Set<List<String>> frequent = new HashSet<>(L);
        List<List<String>> C = new ArrayList<>();
        for (int i = 0; i < L.size(); i++)
            for (int j = i + 1; j < L.size(); j++) {
                List<String> a = L.get(i), b = L.get(j);
                if (!a.subList(0, k - 2).equals(b.subList(0, k - 2))) continue;
                List<String> c = new ArrayList<>(a);
                c.add(b.get(k - 2));
                boolean ok = true;
                for (int x = 0; x < c.size(); x++) {
                    List<String> sub = new ArrayList<>(c);
                    sub.remove(x);
                    if (!frequent.contains(sub)) ok = false;
                }
                if (ok) C.add(c);
            }
        return C;
    }

    /** 掃一次 rows，數每個候選出現在幾筆交易裡 */
    static Map<List<String>, Integer> count(List<Set<String>> rows, List<List<String>> C) {
        reads += rows.size();
        Map<List<String>, Integer> cnt = new HashMap<>();
        for (List<String> c : C) cnt.put(c, 0);
        for (Set<String> t : rows)
            for (List<String> c : C)
                if (t.containsAll(c)) cnt.merge(c, 1, Integer::sum);
        return cnt;
    }

    /** 一般的 Apriori：用來算一開始的 L，也可以直接對 DB∪db 全部重算來比較 */
    static Map<List<String>, Integer> apriori(List<Set<String>> DB, int pct) {
        Map<List<String>, Integer> L = new LinkedHashMap<>();
        List<List<String>> C = singleItems(DB);
        for (int k = 2; !C.isEmpty(); k++) {
            Map<List<String>, Integer> cnt = count(DB, C);
            List<List<String>> Lk = new ArrayList<>();
            for (List<String> c : C)
                if (cnt.get(c) >= need(DB.size(), pct)) {
                    Lk.add(c);
                    L.put(c, cnt.get(c));
                }
            C = aprioriGen(Lk, k);
        }
        return L;
    }

    static List<List<String>> singleItems(List<Set<String>> rows) {
        TreeSet<String> items = new TreeSet<>();
        for (Set<String> t : rows) items.addAll(t);
        List<List<String>> C = new ArrayList<>();
        for (String item : items) C.add(List.of(item));
        return C;
    }

    /** 兩個樣式照字典順序比大小 */
    static int compare(List<String> a, List<String> b) {
        for (int i = 0; i < Math.min(a.size(), b.size()); i++) {
            int c = a.get(i).compareTo(b.get(i));
            if (c != 0) return c;
        }
        return a.size() - b.size();
    }

    static String fmt(List<String> c) {
        return "{" + String.join(", ", c) + "}";
    }

    static List<List<String>> order(Collection<List<String>> keys) {
        List<List<String>> list = new ArrayList<>(keys);
        list.sort(Comparator.<List<String>>comparingInt(List::size).thenComparing(FUP::compare));
        return list;
    }

    static void show(Map<List<String>, Integer> L) {
        for (List<String> c : order(L.keySet()))
            System.out.println("  " + fmt(c) + " " + L.get(c));
    }

    static String changes(Map<List<String>, Integer> a, Map<List<String>, Integer> b) {
        List<String> out = new ArrayList<>();
        for (List<String> c : order(a.keySet()))
            if (!b.containsKey(c)) out.add(fmt(c));
        return out.isEmpty() ? "（沒有）" : String.join("、", out);
    }

    public static void main(String[] args) {
        List<Set<String>> DB = List.of(
            Set.of("咖啡", "麵包", "牛奶"),
            Set.of("咖啡", "麵包", "茶葉蛋"),
            Set.of("咖啡", "麵包", "牛奶", "飯糰"),
            Set.of("麵包", "牛奶", "洋芋片"),
            Set.of("咖啡", "牛奶", "茶葉蛋"),
            Set.of("咖啡", "麵包", "牛奶", "茶葉蛋"),
            Set.of("飯糰", "茶葉蛋", "洋芋片"),
            Set.of("咖啡", "麵包", "飯糰"));
        List<Set<String>> db = List.of(                          // 新增的一批交易
            Set.of("咖啡", "茶葉蛋"),
            Set.of("咖啡", "麵包", "牛奶"),
            Set.of("咖啡", "牛奶", "茶葉蛋"),
            Set.of("牛奶", "飯糰", "茶葉蛋"));
        int pct = 30;
        Map<List<String>, Integer> L = apriori(DB, pct);
        System.out.printf("原本的 L（DB 共 %d 筆，門檻 %d%%）：%n", DB.size(), pct);
        show(L);

        reads = 0;
        Map<List<String>, Integer> newL = fup(DB, L, db, pct);
        int fupReads = reads;
        System.out.printf("FUP 更新後的 L（DB∪db 共 %d 筆）：%n", DB.size() + db.size());
        show(newL);
        System.out.println("新增：" + changes(newL, L));
        System.out.println("掉出：" + changes(L, newL));

        reads = 0;
        List<Set<String>> all = new ArrayList<>(DB);
        all.addAll(db);
        Map<List<String>, Integer> again = apriori(all, pct);   // 對照組：直接對 DB∪db 全部重算
        System.out.printf("FUP 讀了 %d 筆交易；全部重算讀了 %d 筆；兩邊結果%s%n",
            fupReads, reads, newL.equals(again) ? "一樣" : "不一樣");
    }
}
