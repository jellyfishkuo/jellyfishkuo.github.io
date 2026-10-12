import java.util.*;

/** 資料串流上的滑動視窗：只看最近 w 筆交易，每來一筆就即時更新頻繁樣式 */
public class SlidingWindow {
    final int w, minSup;                                      // 視窗大小、最小支持度
    final Deque<List<String>> window = new ArrayDeque<>();    // 視窗裡的交易，最舊的在最前面
    final Map<List<String>, Integer> count = new HashMap<>(); // 計數表：商品組合 -> 出現幾次

    SlidingWindow(int w, int minSup) { this.w = w; this.minSup = minSup; }

    /** 新交易進來：它的每個非空子集合次數 +1 */
    List<String> add(Collection<String> t) {
        List<String> items = new ArrayList<>(new TreeSet<>(t));
        window.addLast(items);
        for (List<String> s : subsets(items))
            count.merge(s, 1, Integer::sum);
        if (window.size() > w) return expire();               // 視窗滿了，最舊的要離開
        return null;
    }

    /** 最舊的交易離開：它的每個非空子集合次數 -1，變成 0 就從表裡刪掉 */
    List<String> expire() {
        List<String> old = window.removeFirst();
        for (List<String> s : subsets(old)) {
            count.merge(s, -1, Integer::sum);
            if (count.get(s) == 0) count.remove(s);
        }
        return old;
    }

    /** 頻繁樣式：次數 >= minSup 的組合 */
    Map<List<String>, Integer> frequent() {
        Map<List<String>, Integer> f = new TreeMap<>(ORDER);
        for (Map.Entry<List<String>, Integer> e : count.entrySet())
            if (e.getValue() >= minSup) f.put(e.getKey(), e.getValue());
        return f;
    }

    /** 最大頻繁樣式：頻繁、而且沒有任何超集合也頻繁 */
    Map<List<String>, Integer> maximal() {
        Map<List<String>, Integer> f = frequent(), m = new TreeMap<>(ORDER);
        for (List<String> s : f.keySet()) {
            boolean hasBigger = false;
            for (List<String> o : f.keySet())
                if (o.size() > s.size() && o.containsAll(s)) hasBigger = true;
            if (!hasBigger) m.put(s, f.get(s));
        }
        return m;
    }

    /** 一筆交易的所有非空子集合（用位元列舉，6 個商品最多 63 個） */
    static List<List<String>> subsets(List<String> t) {
        List<List<String>> out = new ArrayList<>();
        for (int mask = 1; mask < (1 << t.size()); mask++) {
            List<String> s = new ArrayList<>();
            for (int i = 0; i < t.size(); i++)
                if ((mask >> i & 1) == 1) s.add(t.get(i));
            out.add(s);
        }
        return out;
    }

    /** 把串流一筆一筆餵進視窗，印出每一步頻繁樣式的變化 */
    static void run(List<Set<String>> stream, int w, int minSup) {
        SlidingWindow sw = new SlidingWindow(w, minSup);
        Map<List<String>, Integer> before = new TreeMap<>(ORDER);
        for (int i = 1; i <= stream.size(); i++) {
            List<String> old = sw.add(stream.get(i - 1));     // 進來一筆，必要時擠掉最舊的一筆
            System.out.println("T" + i + " 進入 " + fmt(stream.get(i - 1))
                + (old != null ? "，T" + (i - w) + " 離開 " + fmt(old) : ""));
            Map<List<String>, Integer> now = sw.frequent();
            for (List<String> s : now.keySet())
                if (!before.containsKey(s)) System.out.println("  + 變成頻繁 " + fmt(s) + " " + now.get(s));
            for (List<String> s : before.keySet())
                if (!now.containsKey(s)) System.out.println("  - 不再頻繁 " + fmt(s));
            StringJoiner line = new StringJoiner(" ", "  最大頻繁：", "");
            sw.maximal().forEach((s, c) -> line.add(fmt(s) + "×" + c));
            System.out.println(line);
            before = now;
        }
    }

    static String fmt(Collection<String> s) {
        return "{" + String.join(", ", new TreeSet<>(s)) + "}";
    }

    /** 先比商品數、再逐個比商品名稱，讓輸出順序固定 */
    static final Comparator<List<String>> ORDER = (a, b) -> {
        if (a.size() != b.size()) return a.size() - b.size();
        for (int i = 0; i < a.size(); i++) {
            int c = a.get(i).compareTo(b.get(i));
            if (c != 0) return c;
        }
        return 0;
    };

    public static void main(String[] args) {
        List<Set<String>> stream = List.of(
            Set.of("咖啡", "麵包", "牛奶"),                 // T1–T8：早上，咖啡配麵包
            Set.of("咖啡", "麵包", "茶葉蛋"),
            Set.of("咖啡", "麵包", "牛奶", "飯糰"),
            Set.of("麵包", "牛奶", "洋芋片"),
            Set.of("咖啡", "牛奶", "茶葉蛋"),
            Set.of("咖啡", "麵包", "牛奶", "茶葉蛋"),
            Set.of("飯糰", "茶葉蛋", "洋芋片"),
            Set.of("咖啡", "麵包", "飯糰"),
            Set.of("咖啡", "飯糰", "茶葉蛋"),               // T9–T14：中午，飯糰配茶葉蛋
            Set.of("飯糰", "茶葉蛋"),
            Set.of("牛奶", "飯糰", "茶葉蛋"),
            Set.of("麵包", "飯糰", "茶葉蛋"),
            Set.of("飯糰", "茶葉蛋", "洋芋片"),
            Set.of("咖啡", "飯糰"),
            Set.of("牛奶", "洋芋片"),                       // T15–T20：晚上，洋芋片配牛奶
            Set.of("麵包", "牛奶", "洋芋片"),
            Set.of("牛奶", "茶葉蛋", "洋芋片"),
            Set.of("麵包", "牛奶", "洋芋片"),
            Set.of("咖啡", "洋芋片"),
            Set.of("麵包", "牛奶", "洋芋片"));
        run(stream, 5, 3);
    }
}
