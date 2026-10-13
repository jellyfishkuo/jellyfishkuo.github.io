import java.util.*;

/** Top-k 高效益樣式探勘（TKO 的做法）：不用給門檻，直接找效益最高的前 k 名 */
public class TopKHUI {

    /** 一個商品組合的 utility list：出現在哪些交易，以及在那筆交易裡的 iutil、rutil */
    static class UtilityList {
        List<String> items;
        Map<Integer, int[]> entries = new LinkedHashMap<>();   // tid -> {iutil, rutil}
        int sumIutil, sumRutil;
        UtilityList(List<String> items) { this.items = items; }
        void add(int tid, int iutil, int rutil) {
            entries.put(tid, new int[] { iutil, rutil });
            sumIutil += iutil;
            sumRutil += rutil;
        }
    }

    /** 目前的前 k 名。heap 是最小堆積，只放效益、最多 k 個，heap.peek() 就是目前的第 k 名 */
    static class TopK {
        int k, minUtil;                                    // 門檻：只會往上調，不會往下
        PriorityQueue<Integer> heap = new PriorityQueue<>();
        Map<List<String>, Integer> result = new LinkedHashMap<>();   // 效益 >= 門檻的組合（跟第 k 名同分的全部留著）
        TopK(int k, int minUtil) { this.k = k; this.minUtil = minUtil; }

        void offer(List<String> items, int util) {
            result.put(items, util);
            heap.add(util);
            if (heap.size() > k) heap.poll();              // 超過 k 個，把最小的踢掉
            if (heap.size() == k && heap.peek() > minUtil) {
                minUtil = heap.peek();                     // 堆積滿了：第 k 名的效益就是新門檻
                result.values().removeIf(u -> u < minUtil);
            }
        }
    }

    public static Map<List<String>, Integer> topKHUI(List<Map<String, Integer>> db, Map<String, Integer> profit, int k) {
        // 1. 第 1 次掃描：算每筆交易的效益 TU、每個商品的 TWU，順便算單一商品的效益
        Map<String, Integer> twu = new HashMap<>(), single = new HashMap<>();
        for (Map<String, Integer> t : db) {
            int tu = 0;
            for (String item : t.keySet()) tu += t.get(item) * profit.get(item);
            for (String item : t.keySet()) {
                twu.merge(item, tu, Integer::sum);
                single.merge(item, t.get(item) * profit.get(item), Integer::sum);
            }
        }
        // 預先提升門檻：單一商品本身就是組合，第 k 大的單品效益不會超過真正的第 k 名
        int minUtil = 0;
        if (single.size() >= k) {
            List<Integer> us = new ArrayList<>(single.values());
            us.sort(Collections.reverseOrder());
            minUtil = us.get(k - 1);
        }
        TopK board = new TopK(k, minUtil);
        // TWU 不到門檻的商品整個刪掉，剩下的照 TWU 由小到大排
        List<String> order = new ArrayList<>();
        for (String item : twu.keySet()) if (twu.get(item) >= minUtil) order.add(item);
        order.sort((a, b) -> twu.get(a).equals(twu.get(b)) ? a.compareTo(b) : twu.get(a) - twu.get(b));

        // 2. 第 2 次掃描：建每個商品的 utility list
        List<UtilityList> lists = new ArrayList<>();
        for (String item : order) lists.add(new UtilityList(List.of(item)));
        for (int tid = 0; tid < db.size(); tid++) {
            int rutil = 0;                       // 從最後面往前走：排在後面的商品效益總和
            for (int j = order.size() - 1; j >= 0; j--) {
                Integer q = db.get(tid).get(order.get(j));
                if (q == null) continue;
                int u = q * profit.get(order.get(j));
                lists.get(j).add(tid, u, rutil);
                rutil += u;
            }
        }

        // 3. 深度優先搜尋，邊找邊把門檻往上調
        search(null, lists, board);
        return board.result;
    }

    static void search(UtilityList p, List<UtilityList> uls, TopK board) {
        for (int i = 0; i < uls.size(); i++) {
            UtilityList x = uls.get(i);
            if (x.sumIutil >= board.minUtil) board.offer(x.items, x.sumIutil);     // 夠格進前 k 名
            if (x.sumIutil + x.sumRutil < board.minUtil) continue;                 // 上界連門檻都不到，剪掉
            List<UtilityList> ext = new ArrayList<>();
            for (int j = i + 1; j < uls.size(); j++) {
                UtilityList xy = construct(p, x, uls.get(j));
                if (!xy.entries.isEmpty()) ext.add(xy);                            // 沒有共同交易的就不要
            }
            search(x, ext, board);                                                 // 遞迴：以 x 為前綴往下找
        }
    }

    /** 合併 Px 和 Py 的 utility list，得到 Pxy 的（跟 HUI-Miner 一樣） */
    static UtilityList construct(UtilityList p, UtilityList px, UtilityList py) {
        List<String> items = new ArrayList<>(px.items);
        items.add(py.items.get(py.items.size() - 1));
        UtilityList pxy = new UtilityList(items);
        for (int tid : px.entries.keySet()) {
            int[] ex = px.entries.get(tid), ey = py.entries.get(tid);
            if (ey == null) continue;                                    // 這筆交易沒有 y
            int iutil = ex[0] + ey[0];
            if (p != null) iutil -= p.entries.get(tid)[0];               // P 的效益兩邊都算了，扣掉一次
            pxy.add(tid, iutil, ey[1]);                                  // rutil 用 Py 的（y 排在 x 後面）
        }
        return pxy;
    }


    public static void main(String[] args) {
        Map<String, Integer> profit = Map.of("咖啡", 30, "麵包", 15, "牛奶", 20, "飯糰", 10, "茶葉蛋", 5, "洋芋片", 25);
        List<Map<String, Integer>> db = List.of(        // 每筆交易：商品 -> 購買數量
            Map.of("咖啡", 4, "麵包", 2, "牛奶", 2),
            Map.of("咖啡", 3, "麵包", 5, "茶葉蛋", 4),
            Map.of("咖啡", 1, "麵包", 1, "牛奶", 2, "飯糰", 2),
            Map.of("麵包", 3, "牛奶", 4, "洋芋片", 5),
            Map.of("咖啡", 3, "牛奶", 2, "茶葉蛋", 2),
            Map.of("咖啡", 1, "麵包", 2, "牛奶", 1, "茶葉蛋", 1),
            Map.of("飯糰", 1, "茶葉蛋", 2, "洋芋片", 2),
            Map.of("咖啡", 1, "麵包", 2, "飯糰", 1));
        int k = 6;
        Map<List<String>, Integer> result = topKHUI(db, profit, k);
        System.out.println("前 " + k + " 名（跟第 " + k + " 名同分的也列出）：");
        List<Map.Entry<List<String>, Integer>> rows = new ArrayList<>(result.entrySet());
        rows.sort((a, b) -> !a.getValue().equals(b.getValue()) ? b.getValue() - a.getValue()
                : String.join(", ", a.getKey()).compareTo(String.join(", ", b.getKey())));
        for (Map.Entry<List<String>, Integer> e : rows)
            System.out.println("{" + String.join(", ", e.getKey()) + "} 效益 = " + e.getValue());
    }
}
