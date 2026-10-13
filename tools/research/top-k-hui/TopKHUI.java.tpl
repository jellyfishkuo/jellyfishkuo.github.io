import java.util.*; «hide»
 «hide»
/** Top-k 高效益樣式探勘（TKO 的做法）：不用給門檻，直接找效益最高的前 k 名 */ «hide»
public class TopKHUI { «hide»
 «hide»
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
        int k, minUtil;                                    // 門檻：只會往上調，不會往下 «riu»
        PriorityQueue<Integer> heap = new PriorityQueue<>(); «riu»
        Map<List<String>, Integer> result = new LinkedHashMap<>();   // 效益 >= 門檻的組合（跟第 k 名同分的全部留著） «riu»
        TopK(int k, int minUtil) { this.k = k; this.minUtil = minUtil; } «riu»

        void offer(List<String> items, int util) { «offer{»
            result.put(items, util);
            heap.add(util);
            if (heap.size() > k) heap.poll();              // 超過 k 個，把最小的踢掉 «}offer»
            if (heap.size() == k && heap.peek() > minUtil) { «raise{»
                minUtil = heap.peek();                     // 堆積滿了：第 k 名的效益就是新門檻
                result.values().removeIf(u -> u < minUtil);
            } «}raise»
        }
    }

    public static Map<List<String>, Integer> topKHUI(List<Map<String, Integer>> db, Map<String, Integer> profit, int k) { «start»
        // 1. 第 1 次掃描：算每筆交易的效益 TU、每個商品的 TWU，順便算單一商品的效益 «tu»
        Map<String, Integer> twu = new HashMap<>(), single = new HashMap<>(); «tu»
        for (Map<String, Integer> t : db) { «tu»
            int tu = 0; «tu»
            for (String item : t.keySet()) tu += t.get(item) * profit.get(item); «tu»
            for (String item : t.keySet()) { «tu»
                twu.merge(item, tu, Integer::sum); «tu»
                single.merge(item, t.get(item) * profit.get(item), Integer::sum); «tu»
            } «tu»
        } «tu»
        // 預先提升門檻：單一商品本身就是組合，第 k 大的單品效益不會超過真正的第 k 名 «riu»
        int minUtil = 0; «riu»
        if (single.size() >= k) { «riu»
            List<Integer> us = new ArrayList<>(single.values()); «riu»
            us.sort(Collections.reverseOrder()); «riu»
            minUtil = us.get(k - 1); «riu»
        } «riu»
        TopK board = new TopK(k, minUtil); «riu»
        // TWU 不到門檻的商品整個刪掉，剩下的照 TWU 由小到大排 «twu»
        List<String> order = new ArrayList<>(); «twu»
        for (String item : twu.keySet()) if (twu.get(item) >= minUtil) order.add(item); «twu»
        order.sort((a, b) -> twu.get(a).equals(twu.get(b)) ? a.compareTo(b) : twu.get(a) - twu.get(b)); «twu»

        // 2. 第 2 次掃描：建每個商品的 utility list «scan»
        List<UtilityList> lists = new ArrayList<>(); «scan»
        for (String item : order) lists.add(new UtilityList(List.of(item))); «scan»
        for (int tid = 0; tid < db.size(); tid++) { «scan»
            int rutil = 0;                       // 從最後面往前走：排在後面的商品效益總和 «scan»
            for (int j = order.size() - 1; j >= 0; j--) { «scan»
                Integer q = db.get(tid).get(order.get(j)); «scan»
                if (q == null) continue; «scan»
                int u = q * profit.get(order.get(j)); «scan»
                lists.get(j).add(tid, u, rutil); «scan»
                rutil += u; «scan»
            } «scan»
        } «scan»

        // 3. 深度優先搜尋，邊找邊把門檻往上調 «search0»
        search(null, lists, board); «search0»
        return board.result; «end»
    }

    static void search(UtilityList p, List<UtilityList> uls, TopK board) {
        for (int i = 0; i < uls.size(); i++) { «check»
            UtilityList x = uls.get(i); «check»
            if (x.sumIutil >= board.minUtil) board.offer(x.items, x.sumIutil);     // 夠格進前 k 名 «offer»
            if (x.sumIutil + x.sumRutil < board.minUtil) continue;                 // 上界連門檻都不到，剪掉 «prune»
            List<UtilityList> ext = new ArrayList<>(); «expand»
            for (int j = i + 1; j < uls.size(); j++) { «expand»
                UtilityList xy = construct(p, x, uls.get(j)); «expand,call»
                if (!xy.entries.isEmpty()) ext.add(xy);                            // 沒有共同交易的就不要 «expand,call»
            } «expand»
            search(x, ext, board);                                                 // 遞迴：以 x 為前綴往下找 «recurse»
        } «check»
    }

    /** 合併 Px 和 Py 的 utility list，得到 Pxy 的（跟 HUI-Miner 一樣） */
    static UtilityList construct(UtilityList p, UtilityList px, UtilityList py) { «construct{»
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
    } «}construct»
 «hide{»

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
} «}hide»
