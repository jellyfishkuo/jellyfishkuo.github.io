import java.util.*;

/** FOTH：不用 join，靠 IndexSet 自我傳播找出所有高效益樣式（效益 >= minUtil 的商品組合） */
public class FOTH {

    /** 一筆交易裡某個組合的效益：每個商品各多少、加總，以及 fixedPos */
    static class Vector {
        int[] utils;                         // utils[位元位置] = 這個商品在這筆交易的效益（0 = 沒有）
        int utilSum, size, fixedPos;         // 位置 >= fixedPos 的商品已經固定，不能再拿掉
        Vector(int[] utils, int fixedPos) {
            this.utils = utils;
            this.fixedPos = fixedPos;
            for (int u : utils) if (u > 0) { utilSum += u; size++; }
        }
    }

    /** 同一個組合（同一個編碼）在每筆交易裡的 vector，全部收在一起 */
    static class IndexSet {
        long code;
        int utilSum;                         // 收齊之後就是這個組合的效益
        List<Vector> vectors = new ArrayList<>();
        IndexSet(long code) { this.code = code; }
        void merge(Vector v) {               // 不用比對 tid，接在後面就好
            vectors.add(v);
            utilSum += v.utilSum;
        }
    }

    static List<String> order;
    static Map<List<String>, Integer> result;

    public static Map<List<String>, Integer> foth(List<Map<String, Integer>> db, Map<String, Integer> profit, int minUtil) {
        // 1. 第 1 次掃描：算每筆交易的 TU，加進它裡面每個商品的 TWU
        Map<String, Integer> twu = new HashMap<>();
        for (Map<String, Integer> t : db) {
            int tu = 0;
            for (String item : t.keySet()) tu += t.get(item) * profit.get(item);
            for (String item : t.keySet()) twu.merge(item, tu, Integer::sum);
        }
        // TWU 不到門檻的刪掉；剩下的照 TWU 由小到大排，排越前面的放在越高的位元
        order = new ArrayList<>();
        for (String item : twu.keySet()) if (twu.get(item) >= minUtil) order.add(item);
        order.sort((a, b) -> twu.get(a).equals(twu.get(b)) ? a.compareTo(b) : twu.get(a) - twu.get(b));
        int n = order.size();                // 編碼用 long，最多 63 個商品

        // 2. 第 2 次掃描：每筆交易變成一個 vector，放進同樣編碼的 IndexSet
        TreeMap<Long, IndexSet> R = new TreeMap<>();   // 編碼 -> IndexSet（TreeMap 就是紅黑樹）
        for (Map<String, Integer> t : db) {
            int[] utils = new int[n];
            long code = 0;
            for (int k = 0; k < n; k++) {
                Integer q = t.get(order.get(k));
                if (q == null) continue;
                utils[n - 1 - k] = q * profit.get(order.get(k));   // 第 k 個商品放在位元 n-1-k
                code |= 1L << (n - 1 - k);
            }
            if (code != 0) put(R, code, new Vector(utils, n));
        }

        // 3. 從最高位開始，一區一區往下挖
        result = new LinkedHashMap<>();
        for (int b = n - 1; b >= 0; b--) mine(R, 1L << b, minUtil);
        return result;
    }

    /** 找編碼一樣的 IndexSet（沒有就新建），把 vector 接上去 */
    static void put(TreeMap<Long, IndexSet> R, long code, Vector v) {
        R.computeIfAbsent(code, IndexSet::new).merge(v);
    }

    static void mine(TreeMap<Long, IndexSet> R, long low, int minUtil) {
        long bit = low & -low;               // low 最低的那個 1；比它高的位元都固定了
        List<Long> area = new ArrayList<>(R.subMap(low, true, low + bit, false).descendingKeySet());   // mining area
        int vs = 0;
        for (long c : area) vs += R.get(c).utilSum;   // = U(X) + RU(X)，X 是 low 代表的組合
        if (vs >= minUtil) {                 // 還有機會：再固定下一個位元，分成小區
            for (long b = bit >> 1; b > 0; b >>= 1) mine(R, low + b, minUtil);
            area = R.containsKey(low) ? List.of(low) : List.of();   // 小區都做完了，只剩 low 自己
        }
        for (long c : area) {                // 不夠的話：整區不再細分（剪掉）
            IndexSet s = R.remove(c);
            if (s.utilSum >= minUtil) {
                List<String> items = new ArrayList<>();
                for (int k = 0; k < order.size(); k++) if ((c >> (order.size() - 1 - k) & 1) == 1) items.add(order.get(k));
                result.put(items, s.utilSum);
            }
            propagate(R, s, low);
        }
    }

    /** 每個 vector 自己拿掉一個商品變成子 vector，直接併進對應的 IndexSet（不用 join） */
    static void propagate(TreeMap<Long, IndexSet> R, IndexSet s, long low) {
        for (Vector v : s.vectors) {
            for (int y = 0; y < v.utils.length; y++) {
                // 只拿掉 low 裡的、而且在 fixedPos 下面的商品：同一筆交易的同一個子集合只會出現一次
                if (v.utils[y] == 0 || (low >> y & 1) == 0 || y >= v.fixedPos || v.size == 1) continue;
                int[] utils = v.utils.clone();
                utils[y] = 0;
                put(R, s.code - (1L << y), new Vector(utils, y));   // 子 vector 的 fixedPos = y
            }
        }
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
        foth(db, profit, 250).forEach((items, u) ->
            System.out.println("{" + String.join(", ", items) + "} 效益 = " + u));
    }
}
