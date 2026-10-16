import java.util.*;

/** EFIM：在越來越小的投影資料庫上找出所有高效益樣式（效益 >= minUtil 的商品組合） */
public class EFIM {

    /** 一筆（投影過的）交易：剩下的商品編號、各自的效益，以及前綴在這筆的效益 */
    static class Trans {
        int[] items, utils;
        int pu;
        Trans(int[] items, int[] utils, int pu) { this.items = items; this.utils = utils; this.pu = pu; }
    }

    public static Map<List<String>, Integer> efim(List<Map<String, Integer>> db, Map<String, Integer> profit, int minUtil) {
        // 1. 第 1 次掃描：算每筆交易的效益 TU，加進它裡面每個商品的 TWU
        Map<String, Integer> twu = new HashMap<>();
        for (Map<String, Integer> t : db) {
            int tu = 0;
            for (String item : t.keySet()) tu += t.get(item) * profit.get(item);
            for (String item : t.keySet()) twu.merge(item, tu, Integer::sum);
        }
        // TWU 不到門檻的商品整個刪掉，剩下的照 TWU 由小到大排，編號 0, 1, 2, ...
        List<String> order = new ArrayList<>();
        for (String item : twu.keySet()) if (twu.get(item) >= minUtil) order.add(item);
        order.sort((a, b) -> twu.get(a).equals(twu.get(b)) ? a.compareTo(b) : twu.get(a) - twu.get(b));

        // 2. 第 2 次掃描：每筆交易只留下這些商品、照順序排好
        List<Trans> trans = new ArrayList<>();
        for (Map<String, Integer> t : db) {
            List<Integer> ks = new ArrayList<>();
            for (int k = 0; k < order.size(); k++) if (t.containsKey(order.get(k))) ks.add(k);
            if (ks.isEmpty()) continue;
            int[] items = new int[ks.size()], utils = new int[ks.size()];
            for (int x = 0; x < items.length; x++) {
                items[x] = ks.get(x);
                utils[x] = t.get(order.get(items[x])) * profit.get(order.get(items[x]));
            }
            trans.add(new Trans(items, utils, 0));
        }
        // 整份交易照「反向字典序」排（從最後一個商品往前比），投影後一樣的交易會排在一起
        trans.sort(EFIM::reverseLex);

        // 3. 用 utility-bin 掃一次，算每個商品的 su；su 夠的才當成第一層要展開的商品
        List<Integer> secondary = new ArrayList<>(), primary = new ArrayList<>();
        for (int k = 0; k < order.size(); k++) secondary.add(k);
        int[][] bins = utilityBins(trans, secondary, order.size());
        for (int z : secondary) if (bins[0][z] >= minUtil) primary.add(z);
        Map<List<String>, Integer> result = new LinkedHashMap<>();
        search(new ArrayList<>(), trans, primary, secondary, order, minUtil, result);
        return result;
    }

    static void search(List<String> prefix, List<Trans> pdb, List<Integer> primary, List<Integer> secondary,
                       List<String> order, int minUtil, Map<List<String>, Integer> result) {
        for (int i : primary) {                          // β = prefix 加上 i
            // 投影：有 i 的交易只留下 i 後面的部分，i 的效益加進前綴效益
            int util = 0;
            List<Trans> proj = new ArrayList<>();
            for (Trans t : pdb) {
                int k = indexOf(t.items, i);
                if (k < 0) continue;
                util += t.pu + t.utils[k];               // β 在這筆交易的效益
                if (k + 1 == t.items.length) continue;   // i 後面沒有商品了，不用留
                Trans p = new Trans(Arrays.copyOfRange(t.items, k + 1, t.items.length),
                                    Arrays.copyOfRange(t.utils, k + 1, t.utils.length), t.pu + t.utils[k]);
                Trans last = proj.isEmpty() ? null : proj.get(proj.size() - 1);
                if (last != null && Arrays.equals(last.items, p.items)) {   // 交易合併：跟上一筆剩下的商品完全一樣
                    for (int x = 0; x < p.utils.length; x++) last.utils[x] += p.utils[x];
                    last.pu += p.pu;
                } else proj.add(p);
            }
            List<String> beta = new ArrayList<>(prefix);
            beta.add(order.get(i));
            if (util >= minUtil) result.put(beta, util);  // 高效益，輸出
            // 掃一次 β 的投影資料庫，算 i 後面每個商品 z 的 su、lu
            List<Integer> keep = new ArrayList<>();
            for (int z : secondary) if (z > i) keep.add(z);
            int[][] bins = utilityBins(proj, keep, order.size());
            List<Integer> newSecondary = new ArrayList<>(), newPrimary = new ArrayList<>();
            for (int z : keep) if (bins[1][z] >= minUtil) newSecondary.add(z);       // lu 不夠：下一層整個不考慮 z
            for (int z : newSecondary) if (bins[0][z] >= minUtil) newPrimary.add(z); // su 不夠：β+z 不用展開
            search(beta, proj, newPrimary, newSecondary, order, minUtil, result);
        }
    }

    /** utility-bin：每個商品一個格子，掃一次投影資料庫就把 su（bins[0]）、lu（bins[1]）都加好 */
    static int[][] utilityBins(List<Trans> pdb, List<Integer> keep, int n) {
        int[][] bins = new int[2][n];
        boolean[] in = new boolean[n];
        for (int z : keep) in[z] = true;
        for (Trans t : pdb) {
            int rest = 0;                                // 這筆剩下的效益全部加起來
            for (int u : t.utils) rest += u;
            int after = 0;                               // 從最後面往前走：z 和排在 z 後面（還在名單上）的效益
            for (int k = t.items.length - 1; k >= 0; k--) {
                int z = t.items[k];
                if (!in[z]) continue;
                after += t.utils[k];
                bins[0][z] += t.pu + after;              // sub-tree utility
                bins[1][z] += t.pu + rest;               // local utility
            }
        }
        return bins;
    }


    static int indexOf(int[] a, int x) {
        for (int k = 0; k < a.length; k++) if (a[k] == x) return k;
        return -1;
    }

    /** 反向字典序：從最後一個商品往前比 */
    static int reverseLex(Trans a, Trans b) {
        for (int x = a.items.length - 1, y = b.items.length - 1; x >= 0 && y >= 0; x--, y--)
            if (a.items[x] != b.items[y]) return a.items[x] - b.items[y];
        return a.items.length - b.items.length;
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
        efim(db, profit, 250).forEach((items, u) ->
            System.out.println("{" + String.join(", ", items) + "} 效益 = " + u));
    }
}
