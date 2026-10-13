import java.util.*; «hide»
 «hide»
/** CHARM：用垂直格式（每個商品出現在哪幾筆交易）找出所有封閉頻繁樣式，再從裡面挑出最大頻繁樣式 */ «hide»
public class Charm { «hide»
 «hide»
    /** 一個樣式：商品組合 + 它出現在哪幾筆交易（tidset） */
    record Node(TreeSet<String> items, TreeSet<Integer> tids) {}

    public static List<Node> charm(List<Set<String>> db, int minSup) { «start»
        Map<String, TreeSet<Integer>> tidset = new TreeMap<>();  // 垂直格式：商品 → 出現在哪幾筆 «vertical»
        for (int tid = 1; tid <= db.size(); tid++) «vertical»
            for (String item : db.get(tid - 1)) «vertical»
                tidset.computeIfAbsent(item, k -> new TreeSet<>()).add(tid); «vertical»
        List<Node> P = new ArrayList<>(); «order»
        for (var e : tidset.entrySet()) «order»
            if (e.getValue().size() >= minSup)                     // 只留頻繁的商品 «order»
                P.add(new Node(new TreeSet<>(Set.of(e.getKey())), e.getValue())); «order»
        P.sort(Comparator.comparingInt((Node n) -> n.tids().size())  // 支持度小的排前面 «order»
                .thenComparing(n -> n.items().first())); «order»
        List<Node> closed = new ArrayList<>();
        extend(P, minSup, closed);
        return closed; «end»
    }

    /** P 是同一個前綴底下的一群樣式（一個「類別」），兩兩比 tidset */
    static void extend(List<Node> P, int minSup, List<Node> closed) {
        for (int i = 0; i < P.size(); i++) { «pick»
            TreeSet<String> X = new TreeSet<>(P.get(i).items()); «pick»
            TreeSet<Integer> tX = P.get(i).tids(); «pick»
            List<Node> newClass = new ArrayList<>();          // 以 X 為前綴、往下長的新類別 «pick»
            for (int j = i + 1; j < P.size(); ) { «pair»
                Node xj = P.get(j); «pair»
                TreeSet<Integer> Y = new TreeSet<>(tX); «pair»
                Y.retainAll(xj.tids());                          // X ∪ Xj 出現在哪幾筆 «pair»
                if (Y.size() < minSup) {                         // 不頻繁：不用管 «infreq»
                    j++; «infreq»
                } else if (tX.equals(xj.tids())) {               // 性質 1：一樣 → 合併，Xj 刪掉 «p1»
                    X.addAll(xj.items()); «p1»
                    P.remove(j); «p1»
                } else if (xj.tids().containsAll(tX)) {          // 性質 2：t(X) ⊂ t(Xj) → Xj 吸收進 X «p2»
                    X.addAll(xj.items()); «p2»
                    j++; «p2»
                } else if (tX.containsAll(xj.tids())) {          // 性質 3：t(X) ⊃ t(Xj) → 新候選，Xj 刪掉 «p3»
                    newClass.add(new Node(xj.items(), Y)); «p3»
                    P.remove(j); «p3»
                } else {                                         // 性質 4：互不包含 → 新候選 «p4»
                    newClass.add(new Node(xj.items(), Y)); «p4»
                    j++; «p4»
                }
            }
            if (!newClass.isEmpty()) {                           // 往下一層：每個候選都補上最後的 X «recurse»
                List<Node> next = new ArrayList<>(); «recurse»
                for (Node n : newClass) { «recurse»
                    TreeSet<String> items = new TreeSet<>(X); «recurse»
                    items.addAll(n.items()); «recurse»
                    next.add(new Node(items, n.tids())); «recurse»
                } «recurse»
                extend(next, minSup, closed); «recurse»
            } «recurse»
            if (!isSubsumed(X, tX.size(), closed))               // 子集合檢查 «check»
                closed.add(new Node(X, tX)); «check»
        }
    }

    /** 已經找到一個支持度一樣、而且包含 X 的封閉樣式 → X 不是封閉的 */
    static boolean isSubsumed(Set<String> X, int sup, List<Node> closed) { «check{»
        for (Node c : closed)
            if (c.tids().size() == sup && c.items().containsAll(X)) return true;
        return false;
    } «}check»

    /** 最大頻繁樣式：沒有任何（封閉）頻繁樣式比它大 */
    static List<Node> maximal(List<Node> closed) { «maxfind{»
        List<Node> result = new ArrayList<>();
        for (Node c : closed) {
            boolean hasBigger = false;
            for (Node d : closed)
                if (d.items().size() > c.items().size() && d.items().containsAll(c.items())) hasBigger = true;
            if (!hasBigger) result.add(c);
        }
        return result;
    } «}maxfind»
 «hide{»
    static String fmt(Node n) {
        return "{" + String.join(", ", n.items()) + "}";
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
        List<Node> closed = charm(db, 2);
        System.out.println("封閉頻繁樣式（" + closed.size() + " 個，照找到的順序）");
        for (Node c : closed) System.out.println("  " + fmt(c) + " 支持度 " + c.tids().size());
        List<Node> mx = maximal(closed);
        System.out.println("最大頻繁樣式（" + mx.size() + " 個）");
        for (Node c : mx) System.out.println("  " + fmt(c) + " 支持度 " + c.tids().size());
    }
} «}hide»
