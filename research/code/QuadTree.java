import java.util.*;

/** 點區域四元樹（point-region quadtree）：插入、切割、範圍查詢 */
public class QuadTree {

    static final int MAX_DEPTH = 7;   // 地圖 128×128，切 7 層格子就只剩 1×1，疊在一起的點不再切

    static class Point {
        final int x, y;
        final String kind;
        Point(int x, int y, String kind) { this.x = x; this.y = y; this.kind = kind; }
        public String toString() { return kind + "(" + x + "," + y + ")"; }
    }

    /** 查詢框（含邊界）：x1 ≤ x ≤ x2、y1 ≤ y ≤ y2 */
    static class Rect {
        final int x1, y1, x2, y2;
        Rect(int x1, int y1, int x2, int y2) { this.x1 = x1; this.y1 = y1; this.x2 = x2; this.y2 = y2; }
        boolean contains(Point p) { return x1 <= p.x && p.x <= x2 && y1 <= p.y && p.y <= y2; }
    }

    /** 一個節點管一塊正方形：x ≤ 點的 x < x+size，y 也一樣 */
    static class Node {
        final int x, y, size, depth;
        List<Point> points = new ArrayList<>();
        Node[] children;                              // null 代表葉子
        Node(int x, int y, int size, int depth) { this.x = x; this.y = y; this.size = size; this.depth = depth; }
        boolean intersects(Rect q) {
            return q.x1 < x + size && x <= q.x2 && q.y1 < y + size && y <= q.y2;
        }
    }

    /** 中線右邊 +1、下面 +2：0 左上、1 右上、2 左下、3 右下 */
    static int quadrant(Node n, Point p) {
        int half = n.size / 2;
        return (p.x >= n.x + half ? 1 : 0) + (p.y >= n.y + half ? 2 : 0);
    }

    final int capacity;                               // 每個葉子最多放幾個點
    final Node root = new Node(0, 0, 128, 0);
    int visited, checked;                             // 查詢時拜訪的節點數、檢查的點數

    QuadTree(int capacity) { this.capacity = capacity; }

    void insert(Point p) { insert(root, p); }

    void insert(Node node, Point p) {
        while (node.children != null)                 // 已經切開的格子：看 p 在哪一塊，往下走
            node = node.children[quadrant(node, p)];
        if (node.points.size() < capacity || node.depth == MAX_DEPTH) {
            node.points.add(p);                       // 還沒滿，直接放進去
            return;
        }
        split(node);                                  // 滿了：切成四塊
        insert(node, p);                              // 再從這格往下走一次
    }

    void split(Node node) {
        int half = node.size / 2;
        node.children = new Node[4];
        for (int i = 0; i < 4; i++)
            node.children[i] = new Node(node.x + (i % 2) * half, node.y + (i / 2) * half, half, node.depth + 1);
        for (Point q : node.points)                   // 原本的點依位置重新分到子格
            node.children[quadrant(node, q)].points.add(q);
        node.points = new ArrayList<>();
    }

    List<Point> rangeQuery(Rect q) {
        visited = checked = 0;
        List<Point> out = new ArrayList<>();
        query(root, q, out);
        return out;
    }

    void query(Node node, Rect q, List<Point> out) {
        visited++;
        if (node.children == null) {                  // 葉子：一個一個檢查裡面的點
            for (Point p : node.points) {
                checked++;
                if (q.contains(p)) out.add(p);
            }
            return;
        }
        for (Node c : node.children)
            if (c.intersects(q)) query(c, q, out);    // 沒交集的子格整塊跳過
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
        QuadTree tree = new QuadTree(2);
        for (Object[] r : POINTS) tree.insert(new Point((int) r[0], (int) r[1], (String) r[2]));
        Rect q = new Rect(64, 8, 120, 48);
        List<Point> found = tree.rangeQuery(q);
        StringBuilder sb = new StringBuilder();
        for (Point p : found) sb.append(sb.length() > 0 ? " " : "").append(p);
        System.out.println("插入 " + POINTS.length + " 個點，容量 2");
        System.out.println("查詢框 (" + q.x1 + "," + q.y1 + ")-(" + q.x2 + "," + q.y2 + ")");
        System.out.println("找到 " + found.size() + " 個點：" + sb);
        System.out.println("拜訪 " + tree.visited + " 個節點，檢查 " + tree.checked + " 個點（全部掃一遍要 " + POINTS.length + " 個）");
    }
}
