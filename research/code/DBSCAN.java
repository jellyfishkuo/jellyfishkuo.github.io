import java.util.*;

/** DBSCAN 密度分群（Ester et al., 1996）：鄰居夠多的點長成一群，不用先說要分幾群 */
public class DBSCAN {

    static final int UNSEEN = 0, NOISE = -1;   // 標籤：0 = 還沒看過、-1 = 雜訊、1, 2, 3… = 第幾群

    /** points[i] = {x, y}；回傳每個點的標籤 */
    static int[] dbscan(int[][] points, int eps, int minPts) {
        int n = points.length;
        int[] label = new int[n];                  // 一開始全部是 0（還沒看過）
        int c = 0;                                 // 目前開到第幾群
        for (int p = 0; p < n; p++) {              // 照編號順序看每個點
            if (label[p] != UNSEEN) continue;      // 已經被某一群收走了，跳過
            List<Integer> nb = neighbors(points, p, eps);
            if (nb.size() < minPts) {              // 鄰居不夠：先標成雜訊（之後可能被收編）
                label[p] = NOISE;
                continue;
            }
            c++;                                   // p 是核心點：開一個新的群
            label[p] = c;
            boolean[] queued = new boolean[n];     // 排過隊的點不再排第二次
            queued[p] = true;
            Deque<Integer> queue = new ArrayDeque<>();
            for (int q : nb)                       // 還沒歸屬（沒看過或雜訊）的鄰居排進佇列
                if (!queued[q] && label[q] <= 0) { queued[q] = true; queue.add(q); }
            while (!queue.isEmpty()) {             // 用佇列一圈一圈往外擴張
                int q = queue.poll();
                if (label[q] == NOISE) {           // 原本的雜訊被收編，成為邊界點
                    label[q] = c;
                    continue;
                }
                label[q] = c;
                List<Integer> nq = neighbors(points, q, eps);
                if (nq.size() < minPts) continue;  // 鄰居不夠：q 是邊界點，不再往外擴
                for (int r : nq)                   // q 也是核心點：它還沒歸屬的鄰居也排進佇列
                    if (!queued[r] && label[r] <= 0) { queued[r] = true; queue.add(r); }
            }
        }
        return label;
    }

    /** ε 鄰居：距離 ≤ eps 的點（包含自己）；用平方比，不用開根號 */
    static List<Integer> neighbors(int[][] points, int p, int eps) {
        List<Integer> out = new ArrayList<>();
        for (int q = 0; q < points.length; q++) {
            int dx = points[p][0] - points[q][0], dy = points[p][1] - points[q][1];
            if (dx * dx + dy * dy <= eps * eps) out.add(q);
        }
        return out;
    }

    // 兩個月牙＋幾個零星的點，編號照 x 由左到右
    static final int[][] POINTS = {
        {14, 58}, {16, 48}, {16, 108}, {22, 40}, {30, 34}, {30, 80}, {40, 32}, {44, 66},
        {46, 76}, {50, 34}, {52, 84}, {58, 40}, {60, 90}, {64, 48}, {66, 58}, {70, 92},
        {80, 90}, {88, 84}, {94, 76}, {96, 66}, {98, 52}, {108, 22},
    };

    public static void main(String[] args) {
        int eps = 12, minPts = 3;
        int[] label = dbscan(POINTS, eps, minPts);
        System.out.println("ε = " + eps + "，MinPts = " + minPts);
        int clusters = 0, noise = 0;
        for (int i = 0; i < POINTS.length; i++) {
            boolean core = neighbors(POINTS, i, eps).size() >= minPts;
            String what = label[i] == NOISE ? "雜訊" : "第 " + label[i] + " 群（" + (core ? "核心點" : "邊界點") + "）";
            System.out.println("#" + i + " (" + POINTS[i][0] + "," + POINTS[i][1] + ") " + what);
            clusters = Math.max(clusters, label[i]);
            if (label[i] == NOISE) noise++;
        }
        System.out.println("共 " + clusters + " 群，雜訊 " + noise + " 個");
    }
}
