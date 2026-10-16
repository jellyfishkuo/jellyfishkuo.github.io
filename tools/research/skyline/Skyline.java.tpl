import java.util.*; «hide»
 «hide»
/** Skyline 查詢：BNL（Block-Nested-Loops）與 SFS（Sort-Filter-Skyline） */ «hide»
public class Skyline { «hide»
 «hide»
    /** 一家店：名字，以及每一維的值（這頁是價格、距離，都是越小越好） */
    static class Point {
        final String name;
        final int[] vals;
        Point(String name, int... vals) { this.name = name; this.vals = vals; }
        public String toString() {
            StringBuilder sb = new StringBuilder(name + "(");
            for (int i = 0; i < vals.length; i++) sb.append(i > 0 ? "," : "").append(vals[i]);
            return sb.append(")").toString();
        }
    }

    /** 結果：skyline、比較了幾次、讀了幾輪 */
    static class Result {
        final List<Point> skyline = new ArrayList<>();
        int comparisons, passes;
    }

    /** p 支配 q：每一維都 ≤ q（不比它差），而且至少一維 < q（真的比它好）。 «dom{»
        兩家完全一樣時誰也不支配誰，所以重複的點會一起留在 skyline 裡 */
    static boolean dominates(Point p, Point q) {
        boolean better = false;
        for (int i = 0; i < p.vals.length; i++) {
            if (p.vals[i] > q.vals[i]) return false;
            if (p.vals[i] < q.vals[i]) better = true;
        }
        return better;
    } «}dom»
 «bnl{»
    /** 視窗裡的一格：點，以及它進視窗時暫存檔已經寫了幾筆 */
    static class Entry {
        final Point p;
        final int written;
        boolean carried;                              // 上一輪留下來、還沒確定的點
        Entry(Point p, int written) { this.p = p; this.written = written; }
    }

    /** BNL：視窗最多放 w 個點，放不下的寫到暫存檔、下一輪再讀 */
    static Result bnl(List<Point> points, int w) {
        Result r = new Result(); «init»
        List<Entry> window = new ArrayList<>(); «init»
        List<Point> data = new ArrayList<>(points);   // 第一輪的輸入就是全部的點 «init»
        while (!data.isEmpty()) {
            r.passes++; «pass»
            List<Point> temp = new ArrayList<>();     // 暫存檔：視窗滿了放不下的點 «pass»
            for (int i = 0; i < data.size(); i++) {
                Point p = data.get(i); «read»
                boolean dominated = false; «read»
                for (Iterator<Entry> it = window.iterator(); it.hasNext(); ) { «cmp»
                    Entry e = it.next(); «cmp»
                    r.comparisons++; «cmp»
                    if (dominates(e.p, p)) { dominated = true; break; }   // 被視窗裡的點支配：p 丟掉 «drop»
                    if (dominates(p, e.p)) it.remove();                   // p 支配視窗裡的點：把它踢出去 «kick»
                }
                if (!dominated) {
                    if (window.size() < w) window.add(new Entry(p, temp.size())); «insert»
                    else temp.add(p);                     // 視窗滿了：先寫到暫存檔 «temp»
                }
                // 上一輪留下的點：暫存檔裡比它早寫的那幾筆都讀過了，就確定是 skyline «confirm»
                for (Iterator<Entry> it = window.iterator(); it.hasNext(); ) { «confirm»
                    Entry e = it.next(); «confirm»
                    if (e.carried && e.written <= i + 1) { r.skyline.add(e.p); it.remove(); } «confirm»
                } «confirm»
            }
            for (Iterator<Entry> it = window.iterator(); it.hasNext(); ) {   // 這一輪讀完了 «passend»
                Entry e = it.next(); «passend»
                if (e.written == 0) { r.skyline.add(e.p); it.remove(); }   // 跟所有點都比過了 «passend»
                else e.carried = true;                // 暫存檔裡有比它早寫的點還沒比：留到下一輪 «passend»
            } «passend»
            data = temp;                              // 下一輪的輸入 = 這一輪的暫存檔 «passend»
        }
        return r; «end»
    }
 «}bnl»
 «sfs{»
    /** 單調的分數：任何一維變小，分數就變小。支配別人的點分數一定比較小，所以會排在前面 */
    static int score(Point p) {
        int s = 0;
        for (int v : p.vals) s += v;
        return s;
    }

    /** SFS：先照分數排好，之後進來的點不可能支配視窗裡的點，視窗只進不出 */
    static Result sfs(List<Point> points, int w) {
        Result r = new Result(); «s-init»
        List<Point> data = new ArrayList<>(points); «sort»
        data.sort(Comparator.comparingInt(Skyline::score));   // 分數由小到大（穩定排序：同分照原本的順序） «sort»
        while (!data.isEmpty()) {
            r.passes++; «s-pass»
            List<Point> window = new ArrayList<>(), temp = new ArrayList<>(); «s-pass»
            for (Point p : data) {
                boolean dominated = false; «s-read»
                for (Point q : window) {                  // 只要看 p 有沒有被支配，不用踢人 «s-cmp»
                    r.comparisons++; «s-cmp»
                    if (dominates(q, p)) { dominated = true; break; } «s-drop»
                }
                if (!dominated) {
                    if (window.size() < w) { «s-insert»
                        window.add(p);                    // 一進視窗就確定是 skyline，可以馬上輸出 «s-insert»
                        r.skyline.add(p); «s-insert»
                    } else temp.add(p);                   // 視窗滿了：寫到暫存檔（還是排好的順序） «s-temp»
                }
            }
            data = temp; «s-passend»
        }
        return r; «s-end»
    }
 «}sfs»
 «hide{»
    static final Object[][] SHOPS = {
        {"自助餐", 90, 120}, {"咖哩飯", 130, 110}, {"牛肉麵", 180, 60}, {"便當", 100, 200},
        {"拉麵", 260, 40}, {"滷肉飯", 60, 260}, {"水餃", 80, 170}, {"火鍋", 280, 180},
        {"義大利麵", 220, 150}, {"早午餐", 160, 210}, {"鍋燒意麵", 110, 170}, {"炒飯", 120, 80},
        {"壽司", 250, 230}, {"河粉", 150, 140}, {"韓式拌飯", 170, 90}, {"披薩", 230, 100},
        {"漢堡", 140, 250}, {"泰式", 200, 190}, {"清粥小菜", 70, 230}, {"關東煮", 210, 30},
    };

    static void show(String title, Result r) {
        System.out.println(title + "：skyline " + r.skyline.size() + " 家，比較 " + r.comparisons + " 次，讀了 " + r.passes + " 輪");
        StringBuilder sb = new StringBuilder();
        for (Point p : r.skyline) sb.append(sb.length() > 0 ? " " : "").append(p);
        System.out.println("  " + sb);
    }

    public static void main(String[] args) {
        List<Point> pts = new ArrayList<>();
        for (Object[] s : SHOPS) pts.add(new Point((String) s[0], (int) s[1], (int) s[2]));
        System.out.println(pts.size() + " 家店（價格 元, 距離 公尺），視窗 3 格");
        show("BNL", bnl(pts, 3));
        show("SFS", sfs(pts, 3));
    }
} «}hide»
