import java.util.*;

/** UP-Growth：把交易壓成 UP-Tree（DGU、DGN），挖條件樹時再用 DLU、DLN 收緊上界，最後掃一次資料庫驗證候選 */
public class UPGrowth {

    static class Node {
        String item;
        Node parent;
        int count;                           // 經過這個節點的交易數
        int nu;                              // 節點效益（上界）
        Map<String, Node> children = new HashMap<>();
        Node(String item, Node parent) { this.item = item; this.parent = parent; }
    }

    static class UPTree {
        Node root = new Node(null, null);
        List<String> order;                  // 表頭的商品順序
        Map<String, List<Node>> links = new HashMap<>();   // 同一個商品的所有節點
        UPTree(List<String> order) {
            this.order = order;
            for (String i : order) links.put(i, new ArrayList<>());
        }

        /** 沿著 path 往下走，第 k 個節點的 nu 加上 nus[k] */
        void add(List<String> path, List<Integer> nus, int count) {
            Node node = root;
            for (int k = 0; k < path.size(); k++) {
                String item = path.get(k);
                Node child = node.children.get(item);
                if (child == null) {
                    child = new Node(item, node);
                    node.children.put(item, child);
                    links.get(item).add(child);
                }
                node = child;
                node.count += count;
                node.nu += nus.get(k);
            }
        }
    }

    public static Map<List<String>, Integer> upGrowth(List<Map<String, Integer>> db, Map<String, Integer> profit, int minUtil) {
        // 第 1 次掃描：每筆交易的效益 TU，加進它裡面每個商品的 TWU
        Map<String, Integer> twu = new HashMap<>(), miu = new HashMap<>();
        for (Map<String, Integer> t : db) {
            int tu = 0;
            for (String i : t.keySet()) tu += t.get(i) * profit.get(i);
            for (String i : t.keySet()) {
                twu.merge(i, tu, Integer::sum);
                miu.merge(i, t.get(i) * profit.get(i), Math::min);   // 這個商品在一筆交易裡最少賺多少
            }
        }
        // DGU：TWU 不夠的商品刪掉，留下的照 TWU 由大到小排
        List<String> order = new ArrayList<>();
        for (String i : twu.keySet()) if (twu.get(i) >= minUtil) order.add(i);
        order.sort((a, b) -> twu.get(a).equals(twu.get(b)) ? a.compareTo(b) : twu.get(b) - twu.get(a));
        UPTree tree = new UPTree(order);
        // 第 2 次掃描：每筆交易照這個順序插進 UP-Tree
        for (Map<String, Integer> t : db) {
            List<String> path = new ArrayList<>();
            List<Integer> nus = new ArrayList<>();
            int acc = 0;
            for (String i : order)
                if (t.containsKey(i)) {          // DGN：節點只記「到自己為止」的效益
                    acc += t.get(i) * profit.get(i);
                    path.add(i);
                    nus.add(acc);
                }
            tree.add(path, nus, 1);
        }
        Map<List<String>, Integer> cands = new LinkedHashMap<>();   // 候選（PHUI）-> 它的上界
        mine(tree, new ArrayList<>(), minUtil, miu, cands);
        // 第 3 次掃描：算候選真正的效益，夠的才輸出
        Map<List<String>, Integer> util = new LinkedHashMap<>();
        for (List<String> c : cands.keySet()) util.put(c, 0);
        for (Map<String, Integer> t : db)
            for (List<String> c : cands.keySet())
                if (t.keySet().containsAll(c))
                    for (String i : c) util.merge(c, t.get(i) * profit.get(i), Integer::sum);
        util.values().removeIf(u -> u < minUtil);
        return util;
    }

    static void mine(UPTree tree, List<String> suffix, int minUtil, Map<String, Integer> miu, Map<List<String>, Integer> cands) {
        for (int x = tree.order.size() - 1; x >= 0; x--) {    // 從表頭最下面往上挖
            String item = tree.order.get(x);
            List<Node> nodes = tree.links.get(item);
            int est = 0;
            for (Node n : nodes) est += n.nu;   // 這個商品的節點效益加起來
            if (est < minUtil) continue;     // 上界不夠：含它的組合都不可能，跳過
            List<String> pattern = new ArrayList<>();
            pattern.add(item);
            pattern.addAll(suffix);
            cands.put(pattern, est);
            // 條件模式基底：從每個 item 節點往上走到根
            List<List<String>> paths = new ArrayList<>();
            Map<String, Integer> lu = new HashMap<>();
            for (Node n : nodes) {
                LinkedList<String> path = new LinkedList<>();
                for (Node p = n.parent; p.item != null; p = p.parent) {
                    path.addFirst(p.item);
                    lu.merge(p.item, n.nu, Integer::sum);   // 局部效益：經過它的路徑效益加起來
                }
                paths.add(path);
            }
            // DLU：局部效益不夠的商品刪掉
            List<String> localOrder = new ArrayList<>();
            for (String i : tree.order) if (lu.getOrDefault(i, 0) >= minUtil) localOrder.add(i);
            UPTree local = new UPTree(localOrder);
            for (int k = 0; k < nodes.size(); k++) {
                int pu = nodes.get(k).nu, pc = nodes.get(k).count, rest = 0;   // 路徑效益、路徑次數
                List<String> keep = new ArrayList<>();
                for (String i : paths.get(k)) {
                    if (lu.get(i) >= minUtil) { keep.add(i); rest += miu.get(i) * pc; }
                    else pu -= miu.get(i) * pc;   // 刪掉的商品至少值 miu × 次數
                }
                List<Integer> nus = new ArrayList<>();
                for (String i : keep) {          // DLN：每個節點扣掉排在它後面的商品
                    rest -= miu.get(i) * pc;
                    nus.add(pu - rest);
                }
                local.add(keep, nus, pc);
            }
            if (!localOrder.isEmpty()) mine(local, pattern, minUtil, miu, cands);
        }
    }

    public static void main(String[] args) {
        Map<String, Integer> profit = Map.of("咖啡", 30, "麵包", 15, "牛奶", 20, "飯糰", 10, "茶葉蛋", 5, "洋芋片", 25);
        List<Map<String, Integer>> db = List.of(        // 每筆交易：商品 -> 購買數量
            Map.of("咖啡", 4, "麵包", 2, "牛奶", 2),
            Map.of("咖啡", 3, "麵包", 5, "茶葉蛋", 4),
            Map.of("咖啡", 1, "麵包", 1, "牛奶", 2, "飯糰", 2),
            Map.of("麵包", 3, "牛奶", 4, "洋芋片", 5),
            Map.of("咖啡", 3, "牛奶", 2, "茶葉蛋", 2),
            Map.of("咖啡", 1, "麵包", 2, "牛奶", 1, "茶葉蛋", 1),
            Map.of("飯糰", 1, "茶葉蛋", 2, "洋芋片", 2),
            Map.of("咖啡", 1, "麵包", 2, "飯糰", 1));
        upGrowth(db, profit, 250).forEach((items, u) ->
            System.out.println("{" + String.join(", ", items) + "} 效益 = " + u));
    }
}
