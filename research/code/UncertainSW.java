import java.util.*;

/** 不確定資料＋滑動視窗：SWUPA（list 結構）一批一批地挖出期望支持度夠高的樣式 */
public class UncertainSW {
    static final double EPS = 1e-9;   // 浮點數誤差的容忍值：比門檻小不到 1e-9 也算達標

    /** SWUPA-List：一個樣式出現在視窗裡的哪幾筆（TID 由小到大＝由舊到新）、各自的存在機率 */
    static class UList {
        final List<String> items;                         // 樣式（商品照處理順序排）
        List<Integer> tids = new ArrayList<>();           // 交易編號，越大越新
        List<Double> eps = new ArrayList<>();             // 這個樣式在那一筆的存在機率
        double expSup = 0, maxEp = 0;                     // 期望支持度（機率加總）、最大的機率

        UList(List<String> items) { this.items = items; }

        void add(int tid, double ep) {
            tids.add(tid);
            eps.add(ep);
            expSup += ep;
            maxEp = Math.max(maxEp, ep);
        }

        /** 二分搜尋：這個樣式在 tid 那一筆的機率 */
        double epAt(int tid) {
            int lo = 0, hi = tids.size() - 1;
            while (lo < hi) {
                int mid = (lo + hi) / 2;
                if (tids.get(mid) < tid) lo = mid + 1; else hi = mid;
            }
            return eps.get(lo);
        }
    }

    final int b, w, delta;                                    // 一批幾筆、視窗裝幾批、門檻百分比 δ
    final Deque<List<Map.Entry<Integer, Map<String, Double>>>> window = new ArrayDeque<>(); // 視窗裡的批次
    final Map<String, UList> lists = new TreeMap<>();         // 全域 SWUPA-List：商品 -> UList
    final List<String> log = new ArrayList<>();               // 每一次合併的結果
    double minSup;
    Map<String, Double> max1;

    UncertainSW(int b, int w, int delta) { this.b = b; this.w = w; this.delta = delta; }

    /** 新的一批進來：視窗滿了先移掉最舊的一批，再把新的一批接到每個串列尾端 */
    Map<List<String>, Double> addBatch(List<Map.Entry<Integer, Map<String, Double>>> batch) {
        if (window.size() == w) removeOldest();
        window.addLast(batch);
        for (Map.Entry<Integer, Map<String, Double>> t : batch)
            for (String item : new TreeSet<>(t.getValue().keySet()))
                lists.computeIfAbsent(item, k -> new UList(List.of(k)))
                     .add(t.getKey(), t.getValue().get(item));   // 新的 TID 最大，接在尾端
        if (window.size() == w) return mine();                 // 視窗滿了才分析
        return null;
    }

    /** 最舊的一批離開：TID 由小到大排，所以要刪的都在每個串列的最前面 */
    void removeOldest() {
        List<Map.Entry<Integer, Map<String, Double>>> old = window.removeFirst();
        int last = old.get(old.size() - 1).getKey();           // 最舊那批的最後一個 TID
        for (Iterator<UList> it = lists.values().iterator(); it.hasNext(); ) {
            UList L = it.next();
            int k = 0;
            while (k < L.tids.size() && L.tids.get(k) <= last) k++;
            if (k == L.tids.size()) { it.remove(); continue; }   // 整個串列都空了
            List<Integer> tids = new ArrayList<>(L.tids.subList(k, L.tids.size()));
            List<Double> eps = new ArrayList<>(L.eps.subList(k, L.eps.size()));
            L.tids = new ArrayList<>(); L.eps = new ArrayList<>(); L.expSup = 0; L.maxEp = 0;
            for (int i = 0; i < tids.size(); i++) L.add(tids.get(i), eps.get(i));   // MaxEP 不能用減的，重新算
        }
    }

    /** 視窗裡的交易數 × δ 是門檻；串列照期望支持度由小到大排，夠的才往下合併 */
    Map<List<String>, Double> mine() {
        minSup = w * b * delta / 100.0;
        List<UList> order = sorted(lists.values());
        max1 = new HashMap<>();
        for (UList L : order) max1.put(L.items.get(0), L.maxEp);   // 每個商品在視窗裡的 MaxEP
        List<UList> valid = new ArrayList<>();
        Map<List<String>, Double> result = new HashMap<>();
        for (UList L : order)
            if (L.expSup >= minSup - EPS) { valid.add(L); result.put(L.items, L.expSup); }
        mineLists(null, valid, result);
        return result;
    }

    /** sl 裡的串列都有同樣的前綴 prefix；兩兩合併成長一個商品的樣式 */
    void mineLists(UList prefix, List<UList> sl, Map<List<String>, Double> result) {
        for (int k = 0; k < sl.size(); k++) {
            UList x = sl.get(k);
            List<UList> nxt = new ArrayList<>();
            for (UList y : sl.subList(k + 1, sl.size())) {
                String last = y.items.get(y.items.size() - 1);
                double over = x.expSup * max1.get(last);       // 上界 overExpSup = ExpSup(X) × MaxEP(最後一個商品)
                if (over < minSup - EPS) {
                    log.add("over " + fmt(plus(x.items, last)));
                    continue;                                   // 連串列都不用建
                }
                UList xy = join(prefix, x, y);
                if (xy == null) { log.add("ppclw " + fmt(plus(x.items, last))); continue; }
                if (xy.expSup >= minSup - EPS) {
                    result.put(xy.items, xy.expSup);
                    nxt.add(xy);
                    log.add("ok " + fmt(xy.items));
                } else log.add("low " + fmt(xy.items));
            }
            if (nxt.size() > 1) mineLists(x, nxt, result);     // 同一個前綴下至少兩個才合併得下去
        }
    }

    /** 兩邊的 TID 一起往前走（two-way comparison），同一筆才算；邊算邊檢查 ppCLw */
    UList join(UList prefix, UList x, UList y) {
        UList xy = new UList(plus(x.items, y.items.get(y.items.size() - 1)));
        int i = 0, j = 0, n = x.tids.size();
        while (i < n && j < y.tids.size()) {
            int a = x.tids.get(i), c = y.tids.get(j);
            if (a == c) {
                double pe = prefix == null ? 1.0 : prefix.epAt(a);    // 前綴在兩邊各乘了一次，除掉一次
                xy.add(a, x.eps.get(i) * y.eps.get(j) / pe);
                i++;
                j++;
                // ppCLw：剩下 n - i 筆就算每筆都是 MaxEP(X)，加起來還是不到門檻 → 不用比了
                if (i < n && xy.expSup + (n - i) * x.maxEp < minSup - EPS) return null;
            } else if (a < c) i++;
            else j++;
        }
        return xy;
    }

    static List<String> plus(List<String> s, String item) {
        List<String> out = new ArrayList<>(s);
        out.add(item);
        return out;
    }

    /** 期望支持度由小到大；一樣大就比商品名稱（跟 Python 的 tuple 比較同一個順序） */
    static List<UList> sorted(Collection<UList> ls) {
        List<UList> out = new ArrayList<>(ls);
        out.sort((p, q) -> p.expSup != q.expSup ? Double.compare(p.expSup, q.expSup) : String.join("\u0000", p.items).compareTo(String.join("\u0000", q.items)));
        return out;
    }

    static String fmt(Collection<String> items) {
        return "{" + String.join(", ", new TreeSet<>(items)) + "}";
    }

    static String f(String p, double v) { return String.format(p, v); }

    /** 把交易切成一批一批餵進視窗；視窗每滿一次就印出這個視窗的結果 */
    static void run(List<Map<String, Double>> stream, int b, int w, int delta) {
        UncertainSW sw = new UncertainSW(b, w, delta);
        List<List<Map.Entry<Integer, Map<String, Double>>>> batches = new ArrayList<>();
        for (int k = 0; k + b <= stream.size(); k += b) {
            List<Map.Entry<Integer, Map<String, Double>>> batch = new ArrayList<>();
            for (int i = k; i < k + b; i++) batch.add(Map.entry(i + 1, stream.get(i)));
            batches.add(batch);
        }
        for (int h = 1; h <= batches.size(); h++) {
            sw.log.clear();
            Map<List<String>, Double> res = sw.addBatch(batches.get(h - 1));
            if (res == null) { System.out.println("B" + h + " 進入視窗（" + sw.window.size() + "/" + w + " 批，還沒滿）"); continue; }
            List<Integer> tids = new ArrayList<>();
            for (List<Map.Entry<Integer, Map<String, Double>>> bt : sw.window) for (Map.Entry<Integer, Map<String, Double>> t : bt) tids.add(t.getKey());
            System.out.println("B" + h + " 進入 → 視窗 T" + tids.get(0) + "–T" + tids.get(tids.size() - 1) + "，minSup = " + f("%.2f", sw.minSup));
            List<String> parts = new ArrayList<>();
            for (UList L : sorted(sw.lists.values())) parts.add(L.items.get(0) + " " + f("%.2f", L.expSup));
            System.out.println("  串列順序：" + String.join("、", parts));
            for (String e : sw.log) {
                String kind = e.substring(0, e.indexOf(' ')), items = e.substring(e.indexOf(' ') + 1);
                if (!kind.equals("ok")) System.out.println("  " + (kind.equals("over") ? "overExpSup 剪掉" : kind.equals("ppclw") ? "ppCLw 中途停" : "算完不夠") + " " + items);
            }
            List<List<String>> keys = new ArrayList<>(res.keySet());
            keys.sort((p, q) -> {
                if (p.size() != q.size()) return p.size() - q.size();
                List<String> a = new ArrayList<>(new TreeSet<>(p)), c = new ArrayList<>(new TreeSet<>(q));
                for (int i = 0; i < a.size(); i++) { int r = a.get(i).compareTo(c.get(i)); if (r != 0) return r; }
                return 0;
            });
            for (List<String> s : keys) System.out.println("  ✓ " + fmt(s) + " " + f("%.3f", res.get(s)));
        }
    }

    static Map<String, Double> tx(Object... kv) {
        Map<String, Double> m = new LinkedHashMap<>();
        for (int i = 0; i < kv.length; i += 2) m.put((String) kv[i], (Double) kv[i + 1]);
        return m;
    }

    public static void main(String[] args) {
        // 無人商店的攝影機辨識：每樣商品後面是「這筆真的有拿它」的信心
        List<Map<String, Double>> stream = List.of(
            tx("咖啡", 0.9, "麵包", 0.4, "牛奶", 0.4),
            tx("咖啡", 0.5, "麵包", 1.0, "茶葉蛋", 0.8),
            tx("咖啡", 0.8, "麵包", 0.6, "牛奶", 0.5, "飯糰", 0.3),
            tx("麵包", 0.3, "牛奶", 0.4, "洋芋片", 0.9),
            tx("咖啡", 0.8, "牛奶", 1.0, "茶葉蛋", 0.8),
            tx("咖啡", 0.7, "麵包", 0.3, "牛奶", 0.6, "茶葉蛋", 0.8),
            tx("飯糰", 1.0, "茶葉蛋", 0.4, "洋芋片", 0.6),
            tx("咖啡", 0.3, "麵包", 1.0, "飯糰", 0.6));
        run(stream, 2, 2, 30);
    }
}
