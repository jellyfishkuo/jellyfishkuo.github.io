import java.util.*;

/** HUOPS：用滑動視窗在資料串流上找高效益佔有率樣式（Park et al., Information Sciences 716, 2025） */
public class SWHUOP {
    static final double EPS = 1e-9;                  // 小數比大小時的容許誤差

    /** 一筆交易的紀錄：tid、樣式在這筆的佔有率 uo、排在後面的商品佔有率 ruo */
    static class Entry {
        int tid; double uo, ruo;
        Entry(int tid, double uo, double ruo) { this.tid = tid; this.uo = uo; this.ruo = ruo; }
    }

    /** HUOPS-List 的一個節點：一個樣式，底下照批次分組記每筆交易的 Entry */
    static class Node {
        List<String> items;
        Map<Integer, List<Entry>> batches = new LinkedHashMap<>();   // 批次編號 -> entries
        double sumUo, sumRuo;
        Node(List<String> items) { this.items = items; }
        List<Entry> entries() {
            List<Entry> all = new ArrayList<>();
            for (List<Entry> es : batches.values()) all.addAll(es);
            return all;
        }
        int support() { return entries().size(); }
    }

    Map<String, Integer> profit;
    int winSize;                                     // 視窗裡放幾批
    double minSup, beta;
    Map<String, Node> gl = new LinkedHashMap<>();    // 全域 HUOPS-List：商品 -> Node
    List<Integer> window = new ArrayList<>();        // 視窗裡的批次編號，最舊的在前面
    int tid = 0;

    SWHUOP(Map<String, Integer> profit, int batchSize, int winSize, int alphaPct, int betaPct) {
        this.profit = profit;
        this.winSize = winSize;
        this.minSup = batchSize * winSize * alphaPct / 100.0;     // 視窗交易數 × α
        this.beta = betaPct / 100.0;                               // 最小佔有率
    }

    /** 新的一批進來；視窗滿了就先把最舊的一批移出去 */
    void addBatch(int bid, List<Map<String, Integer>> batch) {
        if (window.size() == winSize) removeBatch(window.remove(0));
        window.add(bid);
        for (Map<String, Integer> t : batch) {                     // t：商品 -> 數量
            int tu = 0;                                            // 這筆交易的總效益
            for (String i : t.keySet()) tu += t.get(i) * profit.get(i);
            for (String item : t.keySet()) {
                Node node = gl.computeIfAbsent(item, k -> new Node(List.of(k)));
                Entry e = new Entry(tid, (double) (t.get(item) * profit.get(item)) / tu, 0);   // uo = 自己的效益 / 整筆
                node.batches.computeIfAbsent(bid, k -> new ArrayList<>()).add(e);
                node.sumUo += e.uo;
            }
            tid++;
        }
    }

    void removeBatch(int bid) {
        for (Iterator<Node> it = gl.values().iterator(); it.hasNext(); ) {
            Node node = it.next();
            List<Entry> es = node.batches.remove(bid);             // 整批的 entry 一起拿掉
            if (es != null) for (Entry e : es) node.sumUo -= e.uo;
            if (node.batches.isEmpty()) it.remove();               // 視窗裡已經沒有這個商品
        }
    }

    /** 視窗滿了、要結果時：先重整全域 list，再深度優先挖 */
    Map<List<String>, double[]> mine() {
        List<String> order = reconstruct();
        List<Node> cl = new ArrayList<>();
        for (String i : order) cl.add(gl.get(i));
        Map<List<String>, double[]> result = new LinkedHashMap<>();
        search(null, cl, result);
        return result;
    }

    List<String> reconstruct() {
        List<String> order = new ArrayList<>(gl.keySet());
        order.sort((a, b) -> gl.get(a).support() != gl.get(b).support()      // 照支持度由小到大
            ? gl.get(a).support() - gl.get(b).support() : a.compareTo(b));
        Map<Integer, Double> temp = new HashMap<>();               // tempArray：tid -> 排在後面的商品 uo 加總
        for (int k = order.size() - 1; k >= 0; k--) {             // 從最後面往前算 ruo
            Node node = gl.get(order.get(k));
            node.sumRuo = 0;
            for (Entry e : node.entries()) {
                if (node.support() < minSup) { e.ruo = 0; continue; }   // 支持度不夠，不用算，歸零就好
                e.ruo = temp.getOrDefault(e.tid, 0.0);
                temp.put(e.tid, e.ruo + e.uo);
                node.sumRuo += e.ruo;
            }
        }
        return order;
    }

    void search(Node prefix, List<Node> cl, Map<List<String>, double[]> result) {
        int cms = (int) Math.ceil(minSup);
        for (int k = 0; k < cl.size(); k++) {
            Node x = cl.get(k);
            int sup = x.support();
            if (sup < minSup) continue;                            // 支持度不夠：自己和更長的都不可能
            if (x.sumUo / sup >= beta - EPS)                       // 平均佔有率夠，輸出
                result.put(x.items, new double[] { sup, x.sumUo / sup });
            if ((x.sumUo + x.sumRuo) / cms < beta - EPS) continue; // UBUO1 不夠，剪掉
            if (upperBound(x, cms) < beta - EPS) continue;         // UBUO2 不夠，剪掉
            List<Node> ncl = new ArrayList<>();
            for (int j = k + 1; j < cl.size(); j++) {
                Node xy = combine(prefix, x, cl.get(j));
                if (!xy.batches.isEmpty()) ncl.add(xy);
            }
            if (!ncl.isEmpty()) search(x, ncl, result);            // 以 x 為前綴往下找
        }
    }

    /** UBUO2：uo + ruo 最大的 ⌈minSup⌉ 筆取平均 */
    double upperBound(Node x, int cms) {
        List<Double> vec = new ArrayList<>();
        for (Entry e : x.entries()) vec.add(e.uo + e.ruo);
        vec.sort(Collections.reverseOrder());
        double s = 0;
        for (int k = 0; k < cms; k++) s += vec.get(k);
        return s / cms;
    }

    /** 合併 Px 和 Py 的節點，得到 Pxy 的（只留兩邊都有的交易） */
    Node combine(Node p, Node x, Node y) {
        List<String> items = new ArrayList<>(x.items);
        items.add(y.items.get(y.items.size() - 1));
        Node xy = new Node(items);
        Map<Integer, Entry> ys = new HashMap<>(), ps = new HashMap<>();
        for (Entry e : y.entries()) ys.put(e.tid, e);
        if (p != null) for (Entry e : p.entries()) ps.put(e.tid, e);
        for (Map.Entry<Integer, List<Entry>> b : x.batches.entrySet())
            for (Entry ex : b.getValue()) {
                Entry ey = ys.get(ex.tid);
                if (ey == null) continue;                          // 這筆交易沒有 y
                double uo = ex.uo + ey.uo - (p != null ? ps.get(ex.tid).uo : 0.0);   // P 兩邊都算了，扣掉一次
                Entry e = new Entry(ex.tid, uo, Math.min(ex.ruo, ey.ruo));
                xy.batches.computeIfAbsent(b.getKey(), k -> new ArrayList<>()).add(e);
                xy.sumUo += e.uo;
                xy.sumRuo += e.ruo;
            }
        return xy;
    }


    static String fmt4(double x) {
        long n = (long) Math.floor(x * 10000 + 0.5);   // 自己四捨五入，Java 和 Python 印出來才會一模一樣
        return String.format("%d.%04d", n / 10000, n % 10000);
    }

    static Map<String, Integer> tx(Object... kv) {     // 一筆交易：商品, 數量, 商品, 數量…（照寫的順序）
        Map<String, Integer> t = new LinkedHashMap<>();
        for (int i = 0; i < kv.length; i += 2) t.put((String) kv[i], (Integer) kv[i + 1]);
        return t;
    }

    public static void main(String[] args) {
        Map<String, Integer> profit = Map.of("咖啡", 30, "麵包", 15, "牛奶", 20, "飯糰", 10, "茶葉蛋", 5, "洋芋片", 25);
        List<Map<String, Integer>> db = List.of(        // 每筆交易：商品 -> 購買數量
            tx("咖啡", 4, "麵包", 2, "牛奶", 2),
            tx("咖啡", 3, "麵包", 5, "茶葉蛋", 4),
            tx("咖啡", 1, "麵包", 1, "牛奶", 2, "飯糰", 2),
            tx("麵包", 3, "牛奶", 4, "洋芋片", 5),
            tx("咖啡", 3, "牛奶", 2, "茶葉蛋", 2),
            tx("咖啡", 1, "麵包", 2, "牛奶", 1, "茶葉蛋", 1),
            tx("飯糰", 1, "茶葉蛋", 2, "洋芋片", 2),
            tx("咖啡", 1, "麵包", 2, "飯糰", 1));
        // 每批 2 筆、視窗放 3 批；α = 35%（6 筆 × 35% = 2.1，至少要 3 筆）、β = 65%
        int batchSize = 2, winSize = 3;
        SWHUOP h = new SWHUOP(profit, batchSize, winSize, 35, 65);
        for (int b = 0; b < db.size() / batchSize; b++) {
            h.addBatch(b, db.subList(b * batchSize, (b + 1) * batchSize));
            if (h.window.size() < winSize) continue;
            StringBuilder name = new StringBuilder();
            for (int w : h.window) name.append(name.length() > 0 ? "+B" : "B").append(w + 1);
            System.out.println("視窗 " + name + "：");
            h.mine().forEach((items, v) -> System.out.println(
                "  {" + String.join(", ", items) + "} sup = " + (int) v[0] + "  uo = " + fmt4(v[1])));
        }
    }
}
