import java.util.*; «hide»
 «hide»
/** 空間共位樣式探勘：哪些類型的店常常開在彼此附近 */ «hide»
public class CoLocation { «hide»
 «hide»
    record Point(int x, int y, String kind) {}

    /** 兩點距離 ≤ r 就算鄰近（用平方比，不用開根號） */
    static boolean near(Point p, Point q, int r) {
        int dx = p.x() - q.x(), dy = p.y() - q.y();
        return dx * dx + dy * dy <= r * r;
    }

    /** 回傳所有共位樣式：類型清單 → 參與指數 PI */
    static Map<List<String>, Double> coLocations(List<Point> pts, int r, double minPrev) { «start{»
        Map<String, Integer> total = new LinkedHashMap<>();       // 類型照第一次出現的順序，順便數點數
        for (Point p : pts) total.merge(p.kind(), 1, Integer::sum);
        // 大小 1：每個點自己就是一個實例
        Map<List<String>, List<int[]>> inst = new LinkedHashMap<>();
        for (String t : total.keySet()) inst.put(List.of(t), new ArrayList<>());
        for (int i = 0; i < pts.size(); i++) inst.get(List.of(pts.get(i).kind())).add(new int[]{i});
        Map<List<String>, Double> result = new LinkedHashMap<>(); «}start»
        while (!inst.isEmpty()) { «cands»
            List<List<String>> prev = new ArrayList<>(inst.keySet()); «cands»
            Map<List<String>, List<int[]>> next = new LinkedHashMap<>(); «cands»
            for (int a = 0; a < prev.size(); a++) «cands»
                for (int b = a + 1; b < prev.size(); b++) { «cands»
                    List<String> P = prev.get(a), Q = prev.get(b); «cands»
                    int k = P.size(); «cands»
                    if (!P.subList(0, k - 1).equals(Q.subList(0, k - 1))) continue;   // 前面的類型一樣才合併 «cands»
                    List<String> cand = new ArrayList<>(P); «cands»
                    cand.add(Q.get(k - 1)); «cands»
                    if (!allSubsPrevalent(cand, inst)) continue;                       // 剪枝 «prune»
                    // 列實例：前面的點相同、最後兩個點又相鄰 → 兩兩都相鄰 «rows»
                    List<int[]> rows = new ArrayList<>(); «rows»
                    for (int[] x : inst.get(P)) «rows»
                        for (int[] y : inst.get(Q)) «rows»
                            if (Arrays.equals(x, 0, k - 1, y, 0, k - 1) && near(pts.get(x[k - 1]), pts.get(y[k - 1]), r)) { «rows»
                                int[] row = Arrays.copyOf(x, k + 1); «rows»
                                row[k] = y[k - 1]; «rows»
                                rows.add(row); «rows»
                            } «rows»
                    double pi = participationIndex(cand, rows, total); «pr»
                    if (pi >= minPrev) {                                                // 達到門檻：是共位樣式 «pi»
                        next.put(cand, rows); «pi»
                        result.put(cand, pi); «pi»
                    } «pi»
                } «cands»
            inst = next;                                                                // 只有共位樣式能再長大 «cands»
        } «cands»
        return result; «end»
    }

    /** 拿掉任一個類型後的子樣式，都要是上一層的共位樣式 */
    static boolean allSubsPrevalent(List<String> cand, Map<List<String>, List<int[]>> inst) { «prune{»
        for (int i = 0; i < cand.size(); i++) {
            List<String> sub = new ArrayList<>(cand);
            sub.remove(i);
            if (!inst.containsKey(sub)) return false;
        }
        return true;
    } «}prune»

    static double participationIndex(List<String> cand, List<int[]> rows, Map<String, Integer> total) { «pr{»
        double pi = 1.0;
        for (int j = 0; j < cand.size(); j++) {
            Set<Integer> part = new HashSet<>();                  // 有參與的點（不重複）
            for (int[] row : rows) part.add(row[j]);
            pi = Math.min(pi, (double) part.size() / total.get(cand.get(j)));   // PR，取最小的就是 PI
        }
        return pi;
    } «}pr»
 «hide{»
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
        List<Point> pts = new ArrayList<>();
        for (Object[] r : POINTS) pts.add(new Point((int) r[0], (int) r[1], (String) r[2]));
        System.out.println("r = 16，門檻 minPrev = 0.5");
        coLocations(pts, 16, 0.5).forEach((pattern, pi) ->
            System.out.println(pattern + " PI = " + String.format("%.3f", pi)));
    }
} «}hide»
