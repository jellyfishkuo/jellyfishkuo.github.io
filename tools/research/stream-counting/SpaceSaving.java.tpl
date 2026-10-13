import java.util.*; «hide»
 «hide»
/** Space-Saving：只用 k 個計數器，近似計數資料串流裡每個商品出現幾次（高估不超過 N/k） */ «hide»
public class SpaceSaving { «hide»
    static final double TOL = 1e-9;     // 浮點數誤差：小數乘法不一定剛好（0.1 × 3 會算成 0.30000000000000004） «query»

    /** 一格計數器：記哪個商品、估計次數、誤差 */
    static class Slot {
        String item;
        int count, error;
        Slot(String item, int count, int error) { this.item = item; this.count = count; this.error = error; }
    }

    final int k;                        // 最多只能同時記 k 個商品 «start»
    int n = 0;                          // 到目前為止看過幾筆 «start»
    final List<Slot> slots = new ArrayList<>(); «start»

    SpaceSaving(int k) { this.k = k; } «start»

    void add(String item) {
        n++; «arrive»
        for (Slot sl : slots)           // 已經在記：次數 +1 «inc»
            if (sl.item.equals(item)) { sl.count++; return; } «inc»
        if (slots.size() < k) {         // 還有空格：直接記 «new»
            slots.add(new Slot(item, 1, 0)); «new»
            return; «new»
        } «new»
        int m = minSlot();              // 格子滿了：找次數最小的那格 «replace»
        int c = slots.get(m).count; «replace»
        slots.set(m, new Slot(item, c + 1, c));   // 踢掉它，新商品接手：次數 c+1、誤差 c «replace»
    }

    /** 次數最小的那格；一樣小的話取最前面那格 */
    int minSlot() { «replace{»
        int m = 0;
        for (int i = 1; i < slots.size(); i++)
            if (slots.get(i).count < slots.get(m).count) m = i;
        return m;
    } «}replace»

    /** 估計次數 ≥ sN 的都回報；次數 − 誤差 ≥ sN 的一定是真的頻繁 */
    List<Slot> query(double s) { «query{»
        List<Slot> out = new ArrayList<>();
        for (Slot sl : slots)
            if (sl.count >= s * n - TOL) out.add(sl);
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
        int k = 5;
        double s = 0.2;
        SpaceSaving ss = new SpaceSaving(k);
        Map<String, Integer> truth = new LinkedHashMap<>();
        for (String item : STREAM) {
            ss.add(item);
            truth.merge(item, 1, Integer::sum);
        }
        System.out.println("串流共 " + ss.n + " 筆，k = " + k + " 個計數器，s = " + s);
        for (int i = 0; i < ss.slots.size(); i++) {
            Slot sl = ss.slots.get(i);
            System.out.println("  第 " + (i + 1) + " 格 " + sl.item + "：估計 " + sl.count + "，誤差 " + sl.error + "，真實 " + truth.get(sl.item) + " 次");
        }
        List<String> rep = new ArrayList<>(), real = new ArrayList<>();
        for (Slot sl : ss.query(s)) rep.add(sl.item + " " + sl.count + (sl.count - sl.error >= s * ss.n - TOL ? "（保證）" : ""));
        for (Map.Entry<String, Integer> e : truth.entrySet()) if (e.getValue() >= s * ss.n - TOL) real.add(e.getKey());
        System.out.println("回報次數 ≥ sN 的商品：" + String.join("、", rep));
        System.out.println("真實次數 ≥ sN 的商品：" + String.join("、", real));
    }
} «}hide»
