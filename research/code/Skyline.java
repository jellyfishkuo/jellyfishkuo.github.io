import java.util.*;

/** Skyline 查詢：BNL（Block-Nested-Loops）與 SFS（Sort-Filter-Skyline） */
public class Skyline {

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

    /** p 支配 q：每一維都 ≤ q（不比它差），而且至少一維 < q（真的比它好）。
        兩家完全一樣時誰也不支配誰，所以重複的點會一起留在 skyline 裡 */
    static boolean dominates(Point p, Point q) {
        boolean better = false;
        for (int i = 0; i < p.vals.length; i++) {
            if (p.vals[i] > q.vals[i]) return false;
            if (p.vals[i] < q.vals[i]) better = true;
        }
        return better;
    }

    /** 視窗裡的一格：點，以及它進視窗時暫存檔已經寫了幾筆 */
    static class Entry {
        final Point p;
        final int written;
        boolean carried;                              // 上一輪留下來、還沒確定的點
        Entry(Point p, int written) { this.p = p; this.written = written; }
    }

    /** BNL：視窗最多放 w 個點，放不下的寫到暫存檔、下一輪再讀 */
    static Result bnl(List<Point> points, int w) {
        Result r = new Result();
        List<Entry> window = new ArrayList<>();
        List<Point> data = new ArrayList<>(points);   // 第一輪的輸入就是全部的點
        while (!data.isEmpty()) {
            r.passes++;
            List<Point> temp = new ArrayList<>();     // 暫存檔：視窗滿了放不下的點
            for (int i = 0; i < data.size(); i++) {
                Point p = data.get(i);
                boolean dominated = false;
                for (Iterator<Entry> it = window.iterator(); it.hasNext(); ) {
                    Entry e = it.next();
                    r.comparisons++;
                    if (dominates(e.p, p)) { dominated = true; break; }   // 被視窗裡的點支配：p 丟掉
                    if (dominates(p, e.p)) it.remove();                   // p 支配視窗裡的點：把它踢出去
                }
                if (!dominated) {
                    if (window.size() < w) window.add(new Entry(p, temp.size()));
                    else temp.add(p);                     // 視窗滿了：先寫到暫存檔
                }
                // 上一輪留下的點：暫存檔裡比它早寫的那幾筆都讀過了，就確定是 skyline
                for (Iterator<Entry> it = window.iterator(); it.hasNext(); ) {
                    Entry e = it.next();
                    if (e.carried && e.written <= i + 1) { r.skyline.add(e.p); it.remove(); }
                }
            }
            for (Iterator<Entry> it = window.iterator(); it.hasNext(); ) {   // 這一輪讀完了
                Entry e = it.next();
                if (e.written == 0) { r.skyline.add(e.p); it.remove(); }   // 跟所有點都比過了
                else e.carried = true;                // 暫存檔裡有比它早寫的點還沒比：留到下一輪
            }
            data = temp;                              // 下一輪的輸入 = 這一輪的暫存檔
        }
        return r;
    }


    /** 單調的分數：任何一維變小，分數就變小。支配別人的點分數一定比較小，所以會排在前面 */
    static int score(Point p) {
        int s = 0;
        for (int v : p.vals) s += v;
        return s;
    }

    /** SFS：先照分數排好，之後進來的點不可能支配視窗裡的點，視窗只進不出 */
    static Result sfs(List<Point> points, int w) {
        Result r = new Result();
        List<Point> data = new ArrayList<>(points);
        data.sort(Comparator.comparingInt(Skyline::score));   // 分數由小到大（穩定排序：同分照原本的順序）
        while (!data.isEmpty()) {
            r.passes++;
            List<Point> window = new ArrayList<>(), temp = new ArrayList<>();
            for (Point p : data) {
                boolean dominated = false;
                for (Point q : window) {                  // 只要看 p 有沒有被支配，不用踢人
                    r.comparisons++;
                    if (dominates(q, p)) { dominated = true; break; }
                }
                if (!dominated) {
                    if (window.size() < w) {
                        window.add(p);                    // 一進視窗就確定是 skyline，可以馬上輸出
                        r.skyline.add(p);
                    } else temp.add(p);                   // 視窗滿了：寫到暫存檔（還是排好的順序）
                }
            }
            data = temp;
        }
        return r;
    }


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
}
