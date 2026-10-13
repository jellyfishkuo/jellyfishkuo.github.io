import java.util.*;

/** Count-Min Sketch：用 d 列 × w 欄的計數表，估計資料串流裡每個商品出現幾次（只會多算） */
public class CountMin {
    static final int P = 101;                           // 質數，要比所有商品編號都大
    static final int[] A = {90, 67, 79, 56, 33};        // 第 j 列的雜湊函數 h_j(x) = (A[j]·x + B[j]) mod P mod w
    static final int[] B = {10, 78, 20, 99, 71};        // 參數固定寫死，每次跑、每種語言都落在同一格

    final int w, d;                     // w 欄、d 列（d 最多 5，因為只準備了 5 組參數）
    final boolean conservative;         // 要不要用保守更新（conservative update）
    int n = 0;                          // 到目前為止看過幾筆
    final int[][] table;                // 計數表，一開始全部是 0

    CountMin(int w, int d, boolean conservative) {
        this.w = w; this.d = d; this.conservative = conservative;
        table = new int[d][w];
    }

    /** 第 j 列的雜湊函數：商品編號 x 落在第幾欄 */
    int h(int j, int x) { return (A[j] * x + B[j]) % P % w; }

    void add(int x) {
        n++;
        if (!conservative) {
            for (int j = 0; j < d; j++)         // 每一列各 +1 一格
                table[j][h(j, x)]++;
        } else {
            int m = estimate(x);                // 保守更新：先查目前的估計值 m
            for (int j = 0; j < d; j++) {       // 只把比 m+1 小的格子補到 m+1，其他不動
                int c = h(j, x);
                table[j][c] = Math.max(table[j][c], m + 1);
            }
        }
    }

    /** d 格裡取最小值：撞格子只會讓格子變大，所以最小的那格最接近真實 */
    int estimate(int x) {
        int m = Integer.MAX_VALUE;
        for (int j = 0; j < d; j++) m = Math.min(m, table[j][h(j, x)]);
        return m;
    }

    static final String[] ITEMS = {"咖啡", "麵包", "牛奶", "飯糰", "茶葉蛋", "洋芋片", "果汁", "布丁", "泡麵", "巧克力"};   // 商品編號 = 位置 + 1

    static final String[] STREAM = {
        "咖啡", "麵包", "咖啡", "布丁", "飯糰",
        "咖啡", "牛奶", "飯糰", "果汁", "咖啡",
        "茶葉蛋", "飯糰", "咖啡", "泡麵", "麵包",
        "咖啡", "飯糰", "巧克力", "茶葉蛋", "咖啡",
        "牛奶", "飯糰", "洋芋片", "咖啡", "茶葉蛋",
        "飯糰", "布丁", "咖啡", "洋芋片", "茶葉蛋",
    };

    public static void main(String[] args) {
        int w = 5, d = 3;
        double eps = Math.E / w, delta = Math.exp(-d);   // w = ⌈e/ε⌉、d = ⌈ln(1/δ)⌉ 反過來算
        List<String> items = Arrays.asList(ITEMS);
        for (boolean conservative : new boolean[]{false, true}) {
            CountMin cm = new CountMin(w, d, conservative);
            Map<String, Integer> truth = new HashMap<>();
            for (String item : STREAM) {
                cm.add(items.indexOf(item) + 1);
                truth.merge(item, 1, Integer::sum);
            }
            System.out.println("串流共 " + cm.n + " 筆，w = " + w + "、d = " + d + String.format("（ε = e/w = %.3f、δ = e^-d = %.3f），", eps, delta)
                    + (conservative ? "保守更新" : "一般更新"));
            for (int[] row : cm.table) {
                StringBuilder sb = new StringBuilder(" ");
                for (int c : row) sb.append(String.format(" %3d", c));
                System.out.println(sb);
            }
            int over = 0;
            for (int i = 0; i < ITEMS.length; i++) {
                int est = cm.estimate(i + 1), t = truth.getOrDefault(ITEMS[i], 0);
                if (est - t > eps * cm.n) over++;
                System.out.println("  " + ITEMS[i] + "（編號 " + (i + 1) + "）：估計 " + est + "，真實 " + t + "，多算 " + (est - t));
            }
            System.out.println(String.format("  多算超過 εN = %.2f 的商品：%d 個", eps * cm.n, over));
        }
    }
}
