import java.util.*; «hide»
 «hide»
/** Lossy Counting：記憶體有限，近似計數資料串流裡每個商品出現幾次（低估不超過 εN） */ «hide»
public class LossyCounting { «hide»
    static final double TOL = 1e-9;     // 浮點數誤差：(0.4 − 0.1) × 10 會算成 3.0000000000000004 «query»

    final double eps;                   // 允許的誤差比例 ε «start»
    final int w;                        // 桶寬：每 w 筆算一桶 «start»
    int n = 0;                          // 到目前為止看過幾筆 «start»
    final Map<String, int[]> table = new LinkedHashMap<>();   // 商品 -> {f 估計次數, Δ 最多漏算幾次} «start»

    LossyCounting(double eps) { this.eps = eps; this.w = (int) Math.ceil(1 / eps); } «start»

    void add(String item) {
        n++; «arrive»
        int b = (n + w - 1) / w;        // 現在是第幾桶（n / w 無條件進位） «arrive»
        int[] e = table.get(item); «inc,new»
        if (e != null) e[0]++;          // 已經在表裡：次數 +1 «inc»
        else table.put(item, new int[]{1, b - 1});   // 新來的：之前最多被刪掉過 b-1 次的量 «new»
        if (n % w == 0) prune(b);       // 一桶結束：清掉次數太少的 «pcall»
    }

    /** f + Δ ≤ b 的商品，真實次數最多 b 次，先忘掉它 */
    void prune(int b) { «prune{»
        Iterator<int[]> it = table.values().iterator();
        while (it.hasNext()) {
            int[] e = it.next();
            if (e[0] + e[1] <= b) it.remove();
        }
    } «}prune»

    /** f ≥ (s − ε)N 的都回報：真的頻繁的一個都不會漏 */
    Map<String, Integer> query(double s) { «query{»
        Map<String, Integer> out = new LinkedHashMap<>();
        for (Map.Entry<String, int[]> e : table.entrySet())
            if (e.getValue()[0] >= (s - eps) * n - TOL) out.put(e.getKey(), e.getValue()[0]);
        return out;
    } «}query»
 «hide{»
    static final String[] STREAM = {
        "咖啡", "麵包", "咖啡", "布丁", "飯糰",
        "咖啡", "牛奶", "飯糰", "果汁", "咖啡",
        "茶葉蛋", "飯糰", "咖啡", "泡麵", "麵包",
        "咖啡", "飯糰", "巧克力", "茶葉蛋", "咖啡",
        "牛奶", "飯糰", "洋芋片", "咖啡", "茶葉蛋",
        "飯糰", "布丁", "咖啡", "洋芋片", "茶葉蛋",
    };

    public static void main(String[] args) {
        double eps = 0.1, s = 0.2;
        LossyCounting lc = new LossyCounting(eps);
        Map<String, Integer> truth = new LinkedHashMap<>();
        for (String item : STREAM) {
            lc.add(item);
            truth.merge(item, 1, Integer::sum);
        }
        System.out.println("串流共 " + lc.n + " 筆，ε = " + eps + "（桶寬 w = " + lc.w + "），s = " + s);
        System.out.println("表裡還記著 " + lc.table.size() + " 個商品（出現過 " + truth.size() + " 種）：");
        for (Map.Entry<String, int[]> e : lc.table.entrySet())
            System.out.println("  " + e.getKey() + "：估計 f = " + e.getValue()[0] + "，Δ = " + e.getValue()[1] + "，真實 " + truth.get(e.getKey()) + " 次");
        List<String> rep = new ArrayList<>(), real = new ArrayList<>();
        for (Map.Entry<String, Integer> e : lc.query(s).entrySet()) rep.add(e.getKey() + " " + e.getValue());
        for (Map.Entry<String, Integer> e : truth.entrySet()) if (e.getValue() >= s * lc.n - TOL) real.add(e.getKey());
        System.out.println("回報 f ≥ (s - ε)N 的商品：" + String.join("、", rep));
        System.out.println("真實次數 ≥ sN 的商品：" + String.join("、", real));
    }
} «}hide»
