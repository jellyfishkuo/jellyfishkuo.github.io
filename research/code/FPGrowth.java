import java.util.*;

/** FP-Growth：把交易壓成一棵 FP-tree，再從樹裡遞迴挖出所有頻繁樣式 */
public class FPGrowth {

    static class Node {
        String item;
        int count;
        Node parent;
        Map<String, Node> children = new LinkedHashMap<>();
        Node(String item, Node parent) { this.item = item; this.parent = parent; }
    }

    /** 一筆（可能帶權重的）交易：一開始權重都是 1，條件模式基底裡則是路徑出現的次數 */
    static class Row {
        List<String> items;
        int count;
        Row(List<String> items, int count) { this.items = items; this.count = count; }
    }

    public static Map<List<String>, Integer> fpGrowth(List<Set<String>> db, int minSup) {
        List<Row> rows = new ArrayList<>();
        for (Set<String> t : db) rows.add(new Row(new ArrayList<>(t), 1));
        Map<List<String>, Integer> result = new LinkedHashMap<>();
        mine(rows, minSup, new ArrayList<>(), result);
        return result;
    }

    static void mine(List<Row> db, int minSup, List<String> suffix, Map<List<String>, Integer> result) {
        // 1. 數次數，只留下頻繁的商品，次數多的排前面
        Map<String, Integer> count = new HashMap<>();
        for (Row r : db)
            for (String item : r.items) count.merge(item, r.count, Integer::sum);
        List<String> order = new ArrayList<>();
        for (String item : count.keySet())
            if (count.get(item) >= minSup) order.add(item);
        order.sort((a, b) -> count.get(a).equals(count.get(b))
                ? a.compareTo(b) : count.get(b) - count.get(a));

        // 2. 建 FP-tree：每筆照 order 排好，沿著共同的前綴往下插
        Node root = new Node(null, null);
        Map<String, List<Node>> header = new HashMap<>();
        for (String item : order) header.put(item, new ArrayList<>());
        for (Row r : db) {
            List<String> path = new ArrayList<>();
            for (String item : order) if (r.items.contains(item)) path.add(item);
            insert(root, path, r.count, header);
        }

        // 3. 從次數最少的商品開始挖
        for (int i = order.size() - 1; i >= 0; i--) {
            String item = order.get(i);
            List<String> pattern = new ArrayList<>(suffix);
            pattern.add(0, item);
            result.put(pattern, count.get(item));
            List<Row> base = new ArrayList<>();                 // 條件模式基底
            for (Node node : header.get(item)) {
                List<String> path = prefixPath(node);
                if (!path.isEmpty()) base.add(new Row(path, node.count));
            }
            mine(base, minSup, pattern, result);               // 遞迴
        }
    }

    static void insert(Node root, List<String> path, int n, Map<String, List<Node>> header) {
        Node node = root;
        for (String item : path) {
            Node child = node.children.get(item);
            if (child == null) {                                // 沒有共用的前綴，長出新節點
                child = new Node(item, node);
                node.children.put(item, child);
                header.get(item).add(child);                    // 串進同商品的節點鏈
            }
            child.count += n;
            node = child;
        }
    }

    /** 從某個節點往上走到根，經過的商品就是它的前綴路徑 */
    static List<String> prefixPath(Node node) {
        LinkedList<String> path = new LinkedList<>();
        for (Node p = node.parent; p.item != null; p = p.parent)
            path.addFirst(p.item);
        return path;
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
        fpGrowth(db, 3).forEach((pattern, sup) -> System.out.println(pattern + " " + sup));
    }
}
