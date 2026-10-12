import java.util.*; «hide»
 «hide»
/** HUI-Miner：用 utility list 找出所有高效益樣式（效益 >= minUtil 的商品組合） */ «hide»
public class HUIMiner { «hide»
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

    public static Map<List<String>, Integer> huiMiner(List<Map<String, Integer>> db, Map<String, Integer> profit, int minUtil) { «start»
        // 1. 第 1 次掃描：算每筆交易的效益 TU，加進它裡面每個商品的 TWU «tu»
        Map<String, Integer> twu = new HashMap<>(); «tu»
        for (Map<String, Integer> t : db) { «tu»
            int tu = 0; «tu»
            for (String item : t.keySet()) tu += t.get(item) * profit.get(item); «tu»
            for (String item : t.keySet()) twu.merge(item, tu, Integer::sum); «tu»
        } «tu»
        // TWU 不到門檻的商品整個刪掉，剩下的照 TWU 由小到大排 «twu»
        List<String> order = new ArrayList<>(); «twu»
        for (String item : twu.keySet()) if (twu.get(item) >= minUtil) order.add(item); «twu»
        order.sort((a, b) -> twu.get(a).equals(twu.get(b)) ? a.compareTo(b) : twu.get(a) - twu.get(b)); «twu»

        // 2. 第 2 次掃描：建每個商品的 utility list «scan»
        List<UtilityList> lists = new ArrayList<>(); «scan»
        for (String item : order) lists.add(new UtilityList(List.of(item))); «scan»
        for (int tid = 0; tid < db.size(); tid++) { «scan»
            int rutil = 0;                       // 從最後面往前走：排在後面的商品效益總和 «scan»
            for (int k = order.size() - 1; k >= 0; k--) { «scan»
                Integer q = db.get(tid).get(order.get(k)); «scan»
                if (q == null) continue; «scan»
                int u = q * profit.get(order.get(k)); «scan»
                lists.get(k).add(tid, u, rutil); «scan»
                rutil += u; «scan»
            } «scan»
        } «scan»

        // 3. 從單一商品的 list 開始深度優先搜尋 «search0»
        Map<List<String>, Integer> result = new LinkedHashMap<>(); «search0»
        search(null, lists, minUtil, result); «search0»
        return result; «end»
    }

    static void search(UtilityList p, List<UtilityList> uls, int minUtil, Map<List<String>, Integer> result) {
        for (int i = 0; i < uls.size(); i++) { «check»
            UtilityList x = uls.get(i); «check»
            if (x.sumIutil >= minUtil) result.put(x.items, x.sumIutil);   // 高效益，輸出 «output»
            if (x.sumIutil + x.sumRutil < minUtil) continue;             // 再怎麼往下加也不夠，剪掉 «prune»
            List<UtilityList> ext = new ArrayList<>(); «expand»
            for (int j = i + 1; j < uls.size(); j++) { «expand»
                UtilityList xy = construct(p, x, uls.get(j)); «expand,call»
                if (!xy.entries.isEmpty()) ext.add(xy);                  // 沒有共同交易的就不要 «expand,call»
            } «expand»
            search(x, ext, minUtil, result);                             // 遞迴：以 x 為前綴往下找 «recurse»
        } «check»
    }

    /** 合併 Px 和 Py 的 utility list，得到 Pxy 的 */
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
        huiMiner(db, profit, 250).forEach((items, u) ->
            System.out.println("{" + String.join(", ", items) + "} 效益 = " + u));
    }
} «}hide»
