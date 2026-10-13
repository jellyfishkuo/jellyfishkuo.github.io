import java.util.*; «hide»
 «hide»
/** CanTree：商品照固定的標準順序插入，新交易進來直接插、不用重排；要挖的時候再用 FP-Growth 的方法挖 */ «hide»
public class CanTree { «hide»
 «hide»
    // 標準順序（canonical order）：事先定好、之後永遠不變，跟商品賣了幾次無關 «order»
    static final List<String> ORDER = List.of("咖啡", "麵包", "牛奶", "飯糰", "茶葉蛋", "洋芋片"); «order»
    // 排序用：照 ORDER 的位置；不在清單裡的商品排最後、照字碼 «order»
    static final Comparator<String> CANON = Comparator «order»
            .comparingInt((String s) -> ORDER.contains(s) ? ORDER.indexOf(s) : ORDER.size()) «order»
            .thenComparing(Comparator.naturalOrder()); «order»

    static class Node {
        String item;
        int count;
        Node parent;
        Map<String, Node> children = new LinkedHashMap<>();
        Node(String item, Node parent) { this.item = item; this.parent = parent; }
    }

    /** 條件模式基底裡的一條路徑，帶著它出現的次數 */
    static class Row {
        List<String> items;
        int count;
        Row(List<String> items, int count) { this.items = items; this.count = count; }
    }

    Node root = new Node(null, null);
    Map<String, List<Node>> header = new HashMap<>();      // 商品 → 樹上所有這個商品的節點（節點鏈）
    int nodes = 0;

    /** 插入一筆交易：照標準順序排好，沿著共同的前綴往下走，沒有就長新節點 */
    void add(Collection<String> transaction) { «insert{»
        List<String> path = new ArrayList<>(transaction);
        path.sort(CANON);                                   // 順序固定，不看目前的次數
        Node node = root;
        for (String item : path) {
            Node child = node.children.get(item);
            if (child == null) {                            // 沒有共用的前綴，長出新節點
                child = new Node(item, node);
                node.children.put(item, child);
                header.computeIfAbsent(item, k -> new ArrayList<>()).add(child);
                nodes++;
            }
            child.count++;                                  // 只有路徑上的次數 +1，其他節點不動
            node = child;
        }
    } «}insert»

    /** 要挖的時候才用門檻：從標準順序最後面的商品開始，之後跟 FP-Growth 一樣 */
    Map<List<String>, Integer> mine(int minSup) { «mine»
        Map<List<String>, Integer> result = new LinkedHashMap<>(); «mine»
        List<String> items = new ArrayList<>(header.keySet()); «mine»
        items.sort(CANON.reversed()); «mine»
        for (String item : items) { «mine»
            int sup = 0; «sup»
            for (Node n : header.get(item)) sup += n.count;    // 節點鏈上的次數加起來 «sup»
            if (sup < minSup) «sup»
                continue;                                   // 不頻繁：跳過，但它還留在樹上 «skip»
            result.put(List.of(item), sup); «pattern»
            List<Row> base = new ArrayList<>();             // 條件模式基底 «base»
            for (Node n : header.get(item)) { «base»
                List<String> path = prefixPath(n); «base»
                if (!path.isEmpty()) base.add(new Row(path, n.count)); «base»
            } «base»
            fpMine(base, minSup, List.of(item), result);    // 之後跟 FP-Growth 完全一樣 «recurse»
        } «mine»
        return result; «end»
    }

    /** FP-Growth：在條件模式基底上數次數、建條件 FP-tree、再遞迴 */
    static void fpMine(List<Row> db, int minSup, List<String> suffix, Map<List<String>, Integer> result) {
        Map<String, Integer> count = new HashMap<>(); «count»
        for (Row r : db) «count»
            for (String item : r.items) count.merge(item, r.count, Integer::sum); «count»
        List<String> order = new ArrayList<>();             // 條件樹照「次數」排 «count»
        for (String item : count.keySet()) «count»
            if (count.get(item) >= minSup) order.add(item); «count»
        order.sort((a, b) -> count.get(a).equals(count.get(b)) «count»
                ? a.compareTo(b) : count.get(b) - count.get(a)); «count»

        Node root = new Node(null, null); «cinsert»
        Map<String, List<Node>> header = new HashMap<>(); «cinsert»
        for (String item : order) header.put(item, new ArrayList<>()); «cinsert»
        for (Row r : db) { «cinsert»
            List<String> path = new ArrayList<>(); «cinsert»
            for (String item : order) if (r.items.contains(item)) path.add(item); «cinsert»
            insertPath(root, path, r.count, header); «cinsert»
        } «cinsert»

        for (int i = order.size() - 1; i >= 0; i--) { «cloop»
            String item = order.get(i); «cpattern»
            List<String> pattern = new ArrayList<>(suffix); «cpattern»
            pattern.add(0, item); «cpattern»
            result.put(pattern, count.get(item)); «cpattern»
            List<Row> base = new ArrayList<>(); «cbase»
            for (Node n : header.get(item)) { «cbase»
                List<String> path = prefixPath(n); «cbase»
                if (!path.isEmpty()) base.add(new Row(path, n.count)); «cbase»
            } «cbase»
            fpMine(base, minSup, pattern, result);          // 遞迴 «crecurse»
        } «cloop»
    }

    static void insertPath(Node root, List<String> path, int n, Map<String, List<Node>> header) { «cinsert{»
        Node node = root;
        for (String item : path) {
            Node child = node.children.get(item);
            if (child == null) {
                child = new Node(item, node);
                node.children.put(item, child);
                header.get(item).add(child);
            }
            child.count += n;
            node = child;
        }
    } «}cinsert»

    /** 從某個節點往上走到根，經過的商品就是它的前綴路徑 */
    static List<String> prefixPath(Node node) { «base{,cbase{»
        LinkedList<String> path = new LinkedList<>();
        for (Node p = node.parent; p.item != null; p = p.parent)
            path.addFirst(p.item);
        return path;
    } «}base,}cbase»
 «hide{»
    static void show(Map<List<String>, Integer> result) {
        result.forEach((pattern, sup) -> System.out.println(pattern + " " + sup));
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
        CanTree tree = new CanTree();
        for (Set<String> t : db) tree.add(t);
        System.out.println("初始 8 筆，CanTree 節點數 " + tree.nodes);
        show(tree.mine(3));

        List<Set<String>> newRows = List.of(
            Set.of("飯糰", "洋芋片"), Set.of("茶葉蛋", "洋芋片", "飯糰"), Set.of("牛奶", "飯糰"), Set.of("洋芋片", "飯糰", "咖啡"));
        for (Set<String> t : newRows) tree.add(t);          // 直接插，不用重排、不用重建
        System.out.println("再加 4 筆新交易，CanTree 節點數 " + tree.nodes);
        show(tree.mine(3));
    }
} «}hide»
