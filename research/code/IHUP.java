import java.util.*;

/** IHUP：增量高效益樣式探勘。IHUP_L-Tree 照固定的字典序插入交易、節點記 TWU；新交易直接插、不用重建，要結果時才挖 */
public class IHUP {

    // 字典序：論文裡商品編號 a、b、c… 照字母排；這裡照貨架順序編號，之後永遠不變
    static final List<String> ORDER = List.of("咖啡", "麵包", "牛奶", "飯糰", "茶葉蛋", "洋芋片");
    // 排序用：照 ORDER 的位置；不在清單裡的商品排最後、照字碼
    static final Comparator<String> LEX = Comparator
            .comparingInt((String s) -> ORDER.contains(s) ? ORDER.indexOf(s) : ORDER.size())
            .thenComparing(Comparator.naturalOrder());

    static class Node {
        String item;
        Node parent;
        int count;                                          // 經過這個節點的交易筆數
        int twu;                                            // 經過這個節點的交易，TU 加起來
        Map<String, Node> children = new HashMap<>();
        Node(String item, Node parent) { this.item = item; this.parent = parent; }
    }

    /** 條件模式基底裡的一條路徑，帶著它的 TWU */
    static class Row {
        List<String> items;
        int twu;
        Row(List<String> items, int twu) { this.items = items; this.twu = twu; }
    }

    Map<String, Integer> profit;
    Node root = new Node(null, null);
    Map<String, List<Node>> header = new HashMap<>();      // 商品 → 樹上所有這個商品的節點（節點鏈）
    List<Map<String, Integer>> db = new ArrayList<>();     // 交易也留著，第二階段驗證要用
    int nodes = 0;

    IHUP(Map<String, Integer> profit) { this.profit = profit; }

    /** 插入一筆交易（商品 → 數量）：算出 TU，照字典序沿路徑走，路徑上每個節點的 TWU 加上 TU */
    void add(Map<String, Integer> t) {
        db.add(t);
        int tu = 0;                                         // 這筆交易的總效益
        for (String i : t.keySet()) tu += t.get(i) * profit.get(i);
        List<String> path = new ArrayList<>(t.keySet());
        path.sort(LEX);                                     // 順序固定，跟目前的 TWU 無關
        Node node = root;
        for (String item : path) {
            Node child = node.children.get(item);
            if (child == null) {                            // 沒有共用的前綴，長出新節點
                child = new Node(item, node);
                node.children.put(item, child);
                header.computeIfAbsent(item, k -> new ArrayList<>()).add(child);
                nodes++;
            }
            node = child;
            node.count++;
            node.twu += tu;                                 // 只有這條路徑上的節點會變
        }
    }

    /** 要結果時才挖：第一階段在樹上找 TWU 夠的候選，第二階段掃一次資料庫算真正的效益 */
    Map<List<String>, Integer> mine(int minUtil) {
        Map<List<String>, Integer> cands = new LinkedHashMap<>();   // 候選 → 它的 TWU
        List<String> items = new ArrayList<>(header.keySet());
        items.sort(LEX.reversed());                         // 從字典序最後面開始
        for (String item : items) {
            int twu = 0;
            for (Node n : header.get(item)) twu += n.twu;   // 節點鏈上的 TWU 加起來
            if (twu < minUtil)
                continue;                                   // TWU 不夠：含它的組合都不可能夠，跳過
            cands.put(List.of(item), twu);
            List<Row> base = new ArrayList<>();             // 條件模式基底
            for (Node n : header.get(item)) {
                List<String> path = prefixPath(n);
                if (!path.isEmpty()) base.add(new Row(path, n.twu));
            }
            grow(base, minUtil, List.of(item), cands);      // 之後跟 FP-Growth 一樣
        }
        Map<List<String>, Integer> result = new LinkedHashMap<>();
        for (List<String> c : cands.keySet()) {             // 第二階段：再掃一次資料庫
            int u = 0;
            for (Map<String, Integer> t : db)
                if (t.keySet().containsAll(c))
                    for (String i : c) u += t.get(i) * profit.get(i);   // 只加組合裡那幾樣
            if (u >= minUtil) result.put(c, u);
        }
        return result;
    }

    /** 跟 FP-Growth 一樣：數條件模式基底裡的 TWU、建條件樹、遞迴；只是「次數」換成 TWU */
    static void grow(List<Row> base, int minUtil, List<String> suffix, Map<List<String>, Integer> cands) {
        Map<String, Integer> twu = new HashMap<>();
        for (Row r : base)
            for (String item : r.items) twu.merge(item, r.twu, Integer::sum);
        List<String> order = new ArrayList<>();             // 條件樹也照字典序
        for (String item : twu.keySet())
            if (twu.get(item) >= minUtil) order.add(item);
        order.sort(LEX);

        Node root = new Node(null, null);
        Map<String, List<Node>> header = new HashMap<>();
        for (String item : order) header.put(item, new ArrayList<>());
        for (Row r : base) {
            List<String> path = new ArrayList<>();
            for (String item : r.items) if (header.containsKey(item)) path.add(item);
            insertPath(root, path, r.twu, header);
        }

        for (int k = order.size() - 1; k >= 0; k--) {
            String item = order.get(k);
            List<String> pattern = new ArrayList<>(suffix);
            pattern.add(0, item);
            cands.put(pattern, twu.get(item));              // TWU 夠：記成候選
            List<Row> sub = new ArrayList<>();
            for (Node n : header.get(item)) {
                List<String> path = prefixPath(n);
                if (!path.isEmpty()) sub.add(new Row(path, n.twu));
            }
            grow(sub, minUtil, pattern, cands);             // 遞迴
        }
    }

    static void insertPath(Node root, List<String> path, int u, Map<String, List<Node>> header) {
        Node node = root;
        for (String item : path) {
            Node child = node.children.get(item);
            if (child == null) {
                child = new Node(item, node);
                node.children.put(item, child);
                header.get(item).add(child);
            }
            node = child;
            node.twu += u;
        }
    }

    /** 從某個節點往上走到根，經過的商品就是它的前綴路徑 */
    static List<String> prefixPath(Node node) {
        LinkedList<String> path = new LinkedList<>();
        for (Node p = node.parent; p.item != null; p = p.parent)
            path.addFirst(p.item);
        return path;
    }

    static void show(Map<List<String>, Integer> result) {
        result.forEach((items, u) -> System.out.println("{" + String.join(", ", items) + "} 效益 = " + u));
    }

    public static void main(String[] args) {
        Map<String, Integer> profit = Map.of("咖啡", 30, "麵包", 15, "牛奶", 20, "飯糰", 10, "茶葉蛋", 5, "洋芋片", 25);
        List<Map<String, Integer>> db = List.of(            // 每筆交易：商品 -> 購買數量
            Map.of("咖啡", 4, "麵包", 2, "牛奶", 2),
            Map.of("咖啡", 3, "麵包", 5, "茶葉蛋", 4),
            Map.of("咖啡", 1, "麵包", 1, "牛奶", 2, "飯糰", 2),
            Map.of("麵包", 3, "牛奶", 4, "洋芋片", 5),
            Map.of("咖啡", 3, "牛奶", 2, "茶葉蛋", 2),
            Map.of("咖啡", 1, "麵包", 2, "牛奶", 1, "茶葉蛋", 1),
            Map.of("飯糰", 1, "茶葉蛋", 2, "洋芋片", 2),
            Map.of("咖啡", 1, "麵包", 2, "飯糰", 1));
        IHUP tree = new IHUP(profit);
        for (Map<String, Integer> t : db) tree.add(t);
        System.out.println("初始 8 筆，IHUP_L-Tree 節點數 " + tree.nodes);
        show(tree.mine(250));

        List<Map<String, Integer>> newRows = List.of(
            Map.of("洋芋片", 3, "飯糰", 2), Map.of("茶葉蛋", 2, "洋芋片", 2, "飯糰", 1),
            Map.of("牛奶", 1, "飯糰", 3), Map.of("洋芋片", 4, "飯糰", 1, "咖啡", 2));
        for (Map<String, Integer> t : newRows) tree.add(t);  // 直接插，不用重排、不用重建
        System.out.println("再加 4 筆新交易，IHUP_L-Tree 節點數 " + tree.nodes);
        show(tree.mine(250));
    }
}
