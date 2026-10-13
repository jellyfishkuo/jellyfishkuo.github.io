import java.util.*;

/** R-tree：一個點一個點插入（Quadratic Split），再用 best-first search 找最近的 k 個點 */
public class RTree {

    static class Point {
        final int x, y;
        final String kind;
        int no = -1;                                  // 第幾個插入的；距離一樣時編號小的排前面
        Point(int x, int y, String kind) { this.x = x; this.y = y; this.kind = kind; }
        public String toString() { return kind + "(" + x + "," + y + ")"; }
    }

    static class Node {
        final int id;
        final boolean leaf;
        List<Object> entries = new ArrayList<>();     // 葉子放點，內部節點放子節點
        int[] mbr;                                    // 剛好包住所有子孫的框 {x1, y1, x2, y2}
        Node(int id, boolean leaf) { this.id = id; this.leaf = leaf; }
    }

    static int[] rect(Object e) {
        if (e instanceof Point p) return new int[]{p.x, p.y, p.x, p.y};
        return ((Node) e).mbr;
    }
    static int[] union(int[] a, int[] b) {
        return new int[]{Math.min(a[0], b[0]), Math.min(a[1], b[1]), Math.max(a[2], b[2]), Math.max(a[3], b[3])};
    }
    static long area(int[] r) { return (long) (r[2] - r[0]) * (r[3] - r[1]); }
    static int[] bound(List<Object> entries) {
        int[] r = rect(entries.get(0));
        for (Object e : entries) r = union(r, rect(e));
        return r;
    }
    /** 查詢點到框的最短距離（平方）；點在框裡就是 0 */
    static long mindist(int qx, int qy, int[] r) {
        long dx = Math.max(Math.max(r[0] - qx, 0), qx - r[2]);
        long dy = Math.max(Math.max(r[1] - qy, 0), qy - r[3]);
        return dx * dx + dy * dy;
    }

    final int M, m;
    int nextId = 0, count = 0;
    Node root;
    int opened, checked, pruned;                      // kNN 的統計

    RTree(int M) {
        this.M = M;                                   // 一個節點最多放幾個東西
        this.m = M / 2;                               // 分裂後每個節點至少幾個
        root = newNode(true);
    }

    Node newNode(boolean leaf) { return new Node(nextId++, leaf); }

    void insert(Point p) {
        p.no = count++;
        List<Node> path = new ArrayList<>(List.of(root));
        while (!path.get(path.size() - 1).leaf)       // ChooseLeaf：一路往下，選「要擴大最少」的子框
            path.add(choose(path.get(path.size() - 1), rect(p)));
        path.get(path.size() - 1).entries.add(p);
        for (int i = path.size() - 1; i >= 0; i--) {  // 由下往上調整
            Node n = path.get(i);
            if (n.entries.size() > M) {               // 超過 M 個：分裂
                Node fresh = split(n);
                if (i > 0) {
                    path.get(i - 1).entries.add(fresh);   // 新節點交給父節點，父節點可能也跟著滿
                } else {
                    Node old = root;
                    root = newNode(false);            // 根分裂：長出新的根，樹長高一層
                    root.entries.add(old);
                    root.entries.add(fresh);
                    root.mbr = bound(root.entries);
                }
            }
            n.mbr = bound(n.entries);                 // 框擴大到包住新東西
        }
    }

    Node choose(Node node, int[] r) {
        Node best = null;
        long bestEnl = 0, bestArea = 0;
        for (Object o : node.entries) {
            Node c = (Node) o;
            long enl = area(union(c.mbr, r)) - area(c.mbr), a = area(c.mbr);   // 先比擴大多少，再比面積
            if (best == null || enl < bestEnl || (enl == bestEnl && a < bestArea)) {
                best = c; bestEnl = enl; bestArea = a;
            }
        }
        return best;
    }

    /** Quadratic Split：把 M+1 個東西分成兩組 */
    Node split(Node node) {
        List<Object> E = node.entries;
        int si = -1, sj = -1;
        long worst = 0;
        for (int i = 0; i < E.size(); i++)            // PickSeeds：挑「放同一組最浪費面積」的一對當種子
            for (int j = i + 1; j < E.size(); j++) {
                long waste = area(union(rect(E.get(i)), rect(E.get(j)))) - area(rect(E.get(i))) - area(rect(E.get(j)));
                if (si < 0 || waste > worst) { worst = waste; si = i; sj = j; }
            }
        List<Object> g1 = new ArrayList<>(List.of(E.get(si))), g2 = new ArrayList<>(List.of(E.get(sj)));
        int[] b1 = rect(E.get(si)), b2 = rect(E.get(sj));
        List<Object> rest = new ArrayList<>();
        for (int t = 0; t < E.size(); t++) if (t != si && t != sj) rest.add(E.get(t));
        while (!rest.isEmpty()) {
            if (g1.size() + rest.size() == m) { g1.addAll(rest); break; }   // 剩下的全給它，才湊得到 m 個
            if (g2.size() + rest.size() == m) { g2.addAll(rest); break; }
            int pick = -1;
            long pd1 = 0, pd2 = 0;
            for (int t = 0; t < rest.size(); t++) {   // PickNext：兩組擴大量差最多的（最有偏好的）先分
                long d1 = area(union(b1, rect(rest.get(t)))) - area(b1);
                long d2 = area(union(b2, rect(rest.get(t)))) - area(b2);
                if (pick < 0 || Math.abs(d1 - d2) > Math.abs(pd1 - pd2)) { pick = t; pd1 = d1; pd2 = d2; }
            }
            Object e = rest.remove(pick);
            long a1 = area(b1), a2 = area(b2);        // 擴大少的 → 面積小的 → 東西少的
            boolean toFirst = pd1 != pd2 ? pd1 < pd2 : a1 != a2 ? a1 < a2 : g1.size() <= g2.size();
            if (toFirst) { g1.add(e); b1 = union(b1, rect(e)); }
            else { g2.add(e); b2 = union(b2, rect(e)); }
        }
        node.entries = g1;
        Node fresh = newNode(node.leaf);
        fresh.entries = g2;
        node.mbr = bound(g1);
        fresh.mbr = bound(g2);
        return fresh;
    }

    /** 佇列裡的一項：距離²、0=框 1=點、編號 */
    record Item(long d, int type, int id, Object obj) {}

    /** best-first search：回傳由近到遠的 k 個點，dist 依序填入距離² */
    List<Point> knn(int qx, int qy, int k, List<Long> dist) {
        opened = checked = pruned = 0;
        List<Point> out = new ArrayList<>();
        if (root.mbr == null || k <= 0) return out;
        PriorityQueue<Item> heap = new PriorityQueue<>(Comparator.comparingLong(Item::d)
                .thenComparingInt(Item::type).thenComparingInt(Item::id));
        heap.add(new Item(mindist(qx, qy, root.mbr), 0, root.id, root));
        PriorityQueue<Long> best = new PriorityQueue<>(Comparator.reverseOrder());   // 看過最近的 k 個點的距離²
        while (!heap.isEmpty() && out.size() < k) {
            Item it = heap.poll();                    // 取出佇列裡最近的
            if (it.type() == 1) {                     // 是點：剩下的都不會比它近，它就是下一個答案
                out.add((Point) it.obj());
                dist.add(it.d());
                continue;
            }
            Node e = (Node) it.obj();
            opened++;                                 // 是框：打開它，子框算 MINDIST、點算真正的距離
            List<Item> kids = new ArrayList<>();
            for (Object o : e.entries) {
                if (e.leaf) {
                    Point c = (Point) o;
                    checked++;
                    long dx = c.x - qx, dy = c.y - qy, dd = dx * dx + dy * dy;
                    best.add(dd);
                    if (best.size() > k) best.poll();
                    kids.add(new Item(dd, 1, c.no, c));
                } else {
                    Node c = (Node) o;
                    kids.add(new Item(mindist(qx, qy, c.mbr), 0, c.id, c));
                }
            }
            long dk = best.size() == k ? best.peek() : Long.MAX_VALUE;   // 目前第 k 近的距離²
            for (Item x : kids) {
                if (x.d() <= dk) heap.add(x);
                else pruned++;                        // 比第 k 近還遠，不可能是答案：跳過
            }
            int before = heap.size();
            heap.removeIf(x -> x.d() > dk);           // 佇列裡太遠的也丟掉
            pruned += before - heap.size();
        }
        return out;
    }

    static String fmt(int[] r) { return "(" + r[0] + "," + r[1] + ")-(" + r[2] + "," + r[3] + ")"; }

    static void show(Node node, int depth) {
        String head = "  ".repeat(depth) + "R" + node.id + " " + fmt(node.mbr);
        if (node.leaf) {
            StringBuilder sb = new StringBuilder();
            for (Object o : node.entries) sb.append(sb.length() > 0 ? " " : "").append(o);
            System.out.println(head + "：" + sb);
        } else {
            System.out.println(head);
            for (Object o : node.entries) show((Node) o, depth + 1);
        }
    }

    static final Object[][] POINTS = {
        {26, 54, "超商"}, {38, 36, "超商"}, {54, 74, "超商"}, {84, 56, "超商"},
        {108, 76, "超商"}, {60, 114, "超商"}, {12, 96, "超商"}, {90, 26, "超商"},
        {20, 60, "公車站"}, {44, 30, "公車站"}, {48, 68, "公車站"}, {78, 62, "公車站"},
        {102, 68, "公車站"}, {96, 22, "公車站"}, {44, 102, "公車站"}, {100, 106, "公車站"},
        {84, 14, "咖啡店"}, {110, 36, "咖啡店"}, {118, 12, "咖啡店"}, {70, 40, "咖啡店"},
        {60, 62, "咖啡店"}, {22, 104, "咖啡店"}, {72, 110, "咖啡店"},
        {88, 42, "飲料店"}, {112, 22, "飲料店"}, {74, 30, "飲料店"}, {26, 70, "飲料店"},
        {110, 62, "飲料店"}, {40, 42, "飲料店"}, {16, 18, "飲料店"}, {62, 64, "飲料店"},
    };

    public static void main(String[] args) {
        RTree tree = new RTree(4);
        for (Object[] r : POINTS) tree.insert(new Point((int) r[0], (int) r[1], (String) r[2]));
        System.out.println("插入 " + POINTS.length + " 個點，M = " + tree.M + "、m = " + tree.m);
        show(tree.root, 0);
        int qx = 70, qy = 50, k = 3;
        System.out.println("查詢點 (" + qx + "," + qy + ")，找最近的 " + k + " 個：");
        List<Long> dist = new ArrayList<>();
        List<Point> found = tree.knn(qx, qy, k, dist);
        for (int i = 0; i < found.size(); i++)
            System.out.println("  " + (i + 1) + ". " + found.get(i) + " 距離 " + String.format("%.2f", Math.sqrt(dist.get(i))));
        System.out.println("打開 " + tree.opened + " 個框（樹上共 " + tree.nextId + " 個），算了 " + tree.checked
                + " 個點的距離（全部算要 " + POINTS.length + " 個），剪掉 " + tree.pruned + " 項");
    }
}
