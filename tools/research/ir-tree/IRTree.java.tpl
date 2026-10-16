import java.util.*; «hide»
 «hide»
/** IR-tree：R-tree 的每個節點多掛一份倒排表，找「最近、而且賣齊這些商品」的 k 家店 */ «hide»
public class IRTree { «hide»
 «hide»
    static class Shop {
        final int x, y;
        final Set<String> items;                      // 這家店賣的商品（關鍵字）
        int no = -1;                                  // 第幾家；距離一樣時編號小的排前面
        Shop(int x, int y, Collection<String> items) { this.x = x; this.y = y; this.items = new TreeSet<>(items); }
        public String toString() { return "#" + (no + 1) + "(" + x + "," + y + ")"; }
    }

    static class Node {
        final int id;
        final boolean leaf;
        final List<Object> entries;                   // 葉子放店家，內部節點放子節點
        final int[] mbr;                              // 剛好包住所有子孫的框 {x1, y1, x2, y2}
        final Map<String, List<Integer>> inv = new TreeMap<>();   // 倒排表：關鍵字 → 有它的子節點（店家）在 entries 的位置

        Node(int id, boolean leaf, List<Object> entries) { «inv{»
            this.id = id; this.leaf = leaf; this.entries = entries;
            mbr = bound(entries);
            for (int i = 0; i < entries.size(); i++)
                for (String w : wordsOf(entries.get(i)))
                    inv.computeIfAbsent(w, t -> new ArrayList<>()).add(i);
        } «}inv»
        Set<String> words() { return inv.keySet(); }  // 整棵子樹出現過的關鍵字 «inv»
    }

    static Set<String> wordsOf(Object e) { return e instanceof Shop s ? s.items : ((Node) e).words(); }
    static int[] rect(Object e) {
        if (e instanceof Shop s) return new int[]{s.x, s.y, s.x, s.y};
        return ((Node) e).mbr;
    }
    static int[] bound(List<Object> entries) {
        int[] r = rect(entries.get(0));
        for (Object e : entries) {
            int[] s = rect(e);
            r = new int[]{Math.min(r[0], s[0]), Math.min(r[1], s[1]), Math.max(r[2], s[2]), Math.max(r[3], s[3])};
        }
        return r;
    }
    /** 查詢點到框的最短距離（平方）；點在框裡就是 0 */
    static long mindist(int qx, int qy, int[] r) {
        long dx = Math.max(Math.max(r[0] - qx, 0), qx - r[2]);
        long dy = Math.max(Math.max(r[1] - qy, 0), qy - r[3]);
        return dx * dx + dy * dy;
    }
    static long dist2(int qx, int qy, Shop s) {
        long dx = s.x - qx, dy = s.y - qy;
        return dx * dx + dy * dy;
    }

    final int M; «build»
    int nextId = 0; «build»
    Node root; «build»
    int opened, checked, skipped;                     // 查詢的統計 «build»

    IRTree(List<Shop> shops, int M) { «build{»
        this.M = M;
        for (int i = 0; i < shops.size(); i++) shops.get(i).no = i;
        List<Object> level = shops.isEmpty() ? new ArrayList<>() : pack(new ArrayList<>(shops), true);
        while (level.size() > 1) level = pack(level, false);   // 一層一層往上包，直到剩一個根
        root = level.isEmpty() ? null : (Node) level.get(0);
    } «}build»

    /** STR 批次建樹：依 x 排序切成幾條直的，每條再依 y 排序、每 M 個裝成一個節點 */
    List<Object> pack(List<Object> items, boolean leaf) { «build{»
        Comparator<Object> byX = Comparator.comparingInt((Object e) -> rect(e)[0] + rect(e)[2])
                .thenComparingInt(e -> rect(e)[1] + rect(e)[3]).thenComparingInt(e -> leaf ? ((Shop) e).no : ((Node) e).id);
        Comparator<Object> byY = Comparator.comparingInt((Object e) -> rect(e)[1] + rect(e)[3])
                .thenComparingInt(e -> rect(e)[0] + rect(e)[2]).thenComparingInt(e -> leaf ? ((Shop) e).no : ((Node) e).id);
        int pages = (items.size() + M - 1) / M;                  // 這一層要幾個節點
        int per = (int) Math.ceil(Math.sqrt(pages)) * M;         // 每一條放幾個
        items.sort(byX);
        List<Object> out = new ArrayList<>();
        for (int i = 0; i < items.size(); i += per) {
            List<Object> slab = new ArrayList<>(items.subList(i, Math.min(i + per, items.size())));
            slab.sort(byY);
            for (int j = 0; j < slab.size(); j += M)
                out.add(new Node(nextId++, leaf, new ArrayList<>(slab.subList(j, Math.min(j + M, slab.size())))));
        }
        return out;
    } «}build»

    /** 佇列裡的一項：距離²、0=框 1=店、編號 */
    record Item(long d, int type, int id, Object obj) {}
    static PriorityQueue<Item> newQueue() {
        return new PriorityQueue<>(Comparator.comparingLong(Item::d).thenComparingInt(Item::type).thenComparingInt(Item::id));
    }

    /** 回傳由近到遠的 k 家店（每一家都有 words 裡的每個關鍵字），dist 依序填入距離² */
    List<Shop> search(int qx, int qy, Set<String> words, int k, List<Long> dist) {
        opened = checked = skipped = 0; «qstart{»
        List<Shop> out = new ArrayList<>();
        if (root == null || !root.words().containsAll(words)) return out;   // 整棵樹都湊不齊這些關鍵字
        PriorityQueue<Item> heap = newQueue();
        heap.add(new Item(mindist(qx, qy, root.mbr), 0, root.id, root)); «}qstart»
        while (!heap.isEmpty() && out.size() < k) {
            Item it = heap.poll();                    // 取出佇列裡最近的 «pop»
            if (it.type() == 1) {                     // 是店家：剩下的都不會比它近，它就是下一個答案 «pop»
                out.add((Shop) it.obj()); «pop»
                dist.add(it.d()); «pop»
                continue; «pop»
            } «pop»
            Node e = (Node) it.obj(); «open»
            opened++;                                 // 是框：打開它，先查倒排表 «open»
            Set<Integer> ok = new TreeSet<>(); «kw{»
            for (int i = 0; i < e.entries.size(); i++) ok.add(i);
            for (String w : words) ok.retainAll(e.inv.get(w));   // 每個關鍵字的串列取交集：全部都有的才留下
            skipped += e.entries.size() - ok.size();  // 缺關鍵字的整個跳過，連距離都不用算 «}kw»
            for (int i : ok) { «push{»
                Object c = e.entries.get(i);
                if (e.leaf) {
                    checked++;
                    heap.add(new Item(dist2(qx, qy, (Shop) c), 1, ((Shop) c).no, c));
                } else {
                    heap.add(new Item(mindist(qx, qy, ((Node) c).mbr), 0, ((Node) c).id, c));
                }
            } «}push»
        }
        return out; «end»
    }

    /** 做法一：當成普通 R-tree，由近到遠一家一家拿出來，再看關鍵字對不對 */
    List<Shop> nearestThenFilter(int qx, int qy, Set<String> words, int k) { «cmp{»
        opened = checked = 0;
        List<Shop> out = new ArrayList<>();
        PriorityQueue<Item> heap = newQueue();
        if (root != null) heap.add(new Item(mindist(qx, qy, root.mbr), 0, root.id, root));
        while (!heap.isEmpty() && out.size() < k) {
            Item it = heap.poll();
            if (it.type() == 1) {
                if (((Shop) it.obj()).items.containsAll(words)) out.add((Shop) it.obj());
                continue;
            }
            Node e = (Node) it.obj();
            opened++;
            for (Object c : e.entries) {
                if (e.leaf) {
                    checked++;
                    heap.add(new Item(dist2(qx, qy, (Shop) c), 1, ((Shop) c).no, c));
                } else {
                    heap.add(new Item(mindist(qx, qy, ((Node) c).mbr), 0, ((Node) c).id, c));
                }
            }
        }
        return out;
    } «}cmp»

    /** 做法二：先用整份倒排表找出關鍵字都有的店，再全部算距離、排序；cand[0] 填入算了幾家 */
    static List<Shop> filterThenSort(List<Shop> shops, int qx, int qy, Set<String> words, int k, int[] cand) { «cmp{»
        Map<String, Set<Integer>> index = new HashMap<>();   // 關鍵字 → 店家編號（實際上會事先建好）
        for (Shop s : shops)
            for (String w : s.items) index.computeIfAbsent(w, t -> new TreeSet<>()).add(s.no);
        Set<Integer> ok = new TreeSet<>();
        for (int i = 0; i < shops.size(); i++) ok.add(i);
        for (String w : words) ok.retainAll(index.getOrDefault(w, Set.of()));
        cand[0] = ok.size();
        List<Shop> found = new ArrayList<>();
        for (int i : ok) found.add(shops.get(i));
        found.sort(Comparator.comparingLong((Shop s) -> dist2(qx, qy, s)).thenComparingInt(s -> s.no));
        return found.subList(0, Math.min(k, found.size()));
    } «}cmp»
 «hide{»
    static final List<String> ORDER = List.of("咖啡", "麵包", "牛奶", "飯糰", "茶葉蛋", "洋芋片");
    static final List<String> EMOJI = List.of("☕", "🍞", "🥛", "🍙", "🥚", "🥔");
    static String emo(Collection<String> ws) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < ORDER.size(); i++) if (ws.contains(ORDER.get(i))) sb.append(EMOJI.get(i));
        return sb.toString();
    }

    static void show(Node node, int depth) {
        String head = "  ".repeat(depth) + "R" + node.id + " 關鍵字 " + emo(node.words());
        if (node.leaf) {
            StringBuilder sb = new StringBuilder();
            for (Object o : node.entries) sb.append(sb.length() > 0 ? " " : "").append(o).append(emo(((Shop) o).items));
            System.out.println(head + "：" + sb);
        } else {
            System.out.println(head);
            for (Object o : node.entries) show((Node) o, depth + 1);
        }
    }

    static final Object[][] SHOPS = {
/*SHOPS_JAVA*/
    };

    public static void main(String[] args) {
        List<Shop> shops = new ArrayList<>();
        for (Object[] r : SHOPS) shops.add(new Shop((int) r[0], (int) r[1], List.of((String[]) r[2])));
        IRTree tree = new IRTree(shops, 4);
        System.out.println(shops.size() + " 家店，M = " + tree.M + "，共 " + tree.nextId + " 個節點");
        show(tree.root, 0);
/*QUERY_JAVA*/
        List<String> named = new ArrayList<>();
        for (String w : ORDER) if (words.contains(w)) named.add(w);
        System.out.println("查詢點 (" + qx + "," + qy + ")，要有 " + String.join("、", named) + "，找最近的 " + k + " 家：");
        List<Long> dist = new ArrayList<>();
        List<Shop> found = tree.search(qx, qy, words, k, dist);
        for (int i = 0; i < found.size(); i++)
            System.out.println("  " + (i + 1) + ". " + found.get(i) + " 距離 " + String.format("%.2f", Math.sqrt(dist.get(i))));
        System.out.println("IR-tree：打開 " + tree.opened + " 個節點，算了 " + tree.checked + " 家店的距離，關鍵字不符跳過 " + tree.skipped + " 項");
        List<Shop> res = tree.nearestThenFilter(qx, qy, words, k);
        System.out.println("做法一 先找最近再檢查關鍵字：打開 " + tree.opened + " 個節點，算了 " + tree.checked + " 家店的距離，答案" + (res.equals(found) ? "一樣" : "不一樣"));
        int[] cand = new int[1];
        res = filterThenSort(shops, qx, qy, words, k, cand);
        System.out.println("做法二 先查倒排表再全部排序：不用樹，算了 " + cand[0] + " 家店的距離，答案" + (res.equals(found) ? "一樣" : "不一樣"));
    }
} «}hide»
