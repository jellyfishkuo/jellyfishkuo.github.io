import java.util.*; «hide»
 «hide»
/** PFP-tree：找出「夠常出現、而且出現得夠規律」的商品組合（週期性頻繁樣式） */ «hide»
public class PeriodicFP { «hide»
 «hide»
    static class Node {
        String item;
        Node parent;
        Map<String, Node> children = new LinkedHashMap<>();
        List<Integer> tids = new ArrayList<>();   // 只有尾節點（某筆交易在這裡結束）才有
        Node(String item, Node parent) { this.item = item; this.parent = parent; }
    }

    /** 一筆交易（或條件模式基底裡的一條路徑）和它出現在哪幾筆（tid） */
    static class Row {
        List<String> items;
        List<Integer> tids;
        Row(List<String> items, List<Integer> tids) { this.items = items; this.tids = tids; }
    }

    static int n, minSup, maxPer;   // 交易筆數、兩個門檻：整個探勘過程都一樣

    /** 週期 = 相鄰兩次出現的間隔（含開頭到第一次、最後一次到結尾），取最大的 */
    static int periodicity(List<Integer> tids) { «per{»
        List<Integer> sorted = new ArrayList<>(tids);
        Collections.sort(sorted);
        int prev = 0, max = 0;
        for (int t : sorted) {
            max = Math.max(max, t - prev);
            prev = t;
        }
        return Math.max(max, n - prev);                // 最後一次到資料庫結尾
    } «}per»

    /** 回傳每個週期性頻繁樣式的 {支持度, 最大週期} */
    public static Map<List<String>, int[]> pfpGrowth(List<Set<String>> db, int minSup, int maxPer) { «start{»
        PeriodicFP.n = db.size();
        PeriodicFP.minSup = minSup;
        PeriodicFP.maxPer = maxPer;
        List<Row> rows = new ArrayList<>();
        for (int i = 0; i < db.size(); i++)            // 第 i 筆交易就是時間點 i + 1
            rows.add(new Row(new ArrayList<>(db.get(i)), List.of(i + 1)));
        Map<List<String>, int[]> result = new LinkedHashMap<>();
        mine(rows, new ArrayList<>(), result); «end»
        return result; «end»
    } «}start»

    static void mine(List<Row> db, List<String> suffix, Map<List<String>, int[]> result) {
        // 1. 每個商品出現在哪幾筆 → 支持度和週期，兩個門檻都過才留下 «count»
        Map<String, List<Integer>> tids = new HashMap<>(); «count»
        for (Row r : db) «count»
            for (String item : r.items) «count»
                tids.computeIfAbsent(item, k -> new ArrayList<>()).addAll(r.tids); «count»
        List<String> order = new ArrayList<>(); «count»
        for (String item : tids.keySet()) { «count»
            List<Integer> t = tids.get(item); «count»
            if (t.size() >= minSup && periodicity(t) <= maxPer) order.add(item); «count»
        } «count»
        order.sort((a, b) -> tids.get(a).size() == tids.get(b).size() «count»
                ? a.compareTo(b) : tids.get(b).size() - tids.get(a).size()); «count»

        // 2. 建 PF-tree：節點不記次數，交易的 tid 記在路徑最後一個節點 «insert»
        Node root = new Node(null, null); «insert»
        Map<String, List<Node>> header = new HashMap<>(); «insert»
        for (String item : order) header.put(item, new ArrayList<>()); «insert»
        for (Row r : db) { «insert»
            List<String> path = new ArrayList<>(); «insert»
            for (String item : order) if (r.items.contains(item)) path.add(item); «insert»
            if (!path.isEmpty()) insert(root, path, r.tids, header); «insert»
        } «insert»

        // 3. 從最下面（支持度最小）的商品往上挖 «loop»
        for (int i = order.size() - 1; i >= 0; i--) { «loop»
            String item = order.get(i); «pattern»
            List<Integer> all = new ArrayList<>();            // 這時它的節點都是尾節點 «pattern»
            for (Node node : header.get(item)) all.addAll(node.tids); «pattern»
            List<String> pattern = new ArrayList<>(suffix); «pattern»
            pattern.add(0, item); «pattern»
            result.put(pattern, new int[]{all.size(), periodicity(all)}); «pattern»
            List<Row> base = new ArrayList<>();                 // 條件模式基底 «base»
            for (Node node : header.get(item)) { «base»
                List<String> path = prefixPath(node); «base»
                if (!path.isEmpty()) base.add(new Row(path, node.tids)); «base»
            } «base»
            mine(base, pattern, result);                       // 遞迴 «recurse»
            // 4. 把 tid 清單交給父節點，再把這個商品的節點拿掉 «push»
            for (Node node : header.get(item)) { «push»
                if (node.parent.item != null) node.parent.tids.addAll(node.tids); «push»
                node.parent.children.remove(item); «push»
            } «push»
        } «loop»
    }

    static void insert(Node root, List<String> path, List<Integer> tids, Map<String, List<Node>> header) { «insert{»
        Node node = root;
        for (String item : path) {
            Node child = node.children.get(item);
            if (child == null) {                                // 沒有共用的前綴，長出新節點
                child = new Node(item, node);
                node.children.put(item, child);
                header.get(item).add(child);                    // 串進同商品的節點鏈
            }
            node = child;
        }
        node.tids.addAll(tids);                                 // 只有尾節點記 tid
    } «}insert»

    /** 從某個節點往上走到根，經過的商品就是它的前綴路徑 */
    static List<String> prefixPath(Node node) { «base{»
        LinkedList<String> path = new LinkedList<>();
        for (Node p = node.parent; p.item != null; p = p.parent)
            path.addFirst(p.item);
        return path;
    } «}base»
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
        // 最小支持度 3、最大週期 3；每行印出：樣式 支持度 最大週期
        pfpGrowth(db, 3, 3).forEach((pattern, v) -> System.out.println(pattern + " " + v[0] + " " + v[1]));
    }
} «}hide»
