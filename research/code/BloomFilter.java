import java.nio.charset.StandardCharsets;
import java.util.*;

/** Bloom Filter：用 m 格和 k 個雜湊函數判斷「這張發票登錄過沒有」（只會誤判成「可能在」） */
public class BloomFilter {
    static final long SEED1 = 2166136261L;      // FNV-1a 的標準起始值
    static final long SEED2 = 374761393L;       // 第二個雜湊換一個起始值，算出另一個數字

    final int m, k;                 // m 格、k 個雜湊函數
    final boolean counting;         // true：每格是計數器（Counting Bloom Filter，可以刪除）
    final int[] cells;              // 一般版每格只會是 0 或 1；計數版是計數

    BloomFilter(int m, int k, boolean counting) {
        this.m = m; this.k = k; this.counting = counting;
        cells = new int[m];
    }

    /** FNV-1a 32 位元：把字串的每個位元組 XOR 進去、再乘上質數 16777619 */
    static long fnv1a(String s, long seed) {
        long h = seed;
        for (byte b : s.getBytes(StandardCharsets.UTF_8)) {
            h ^= (b & 0xff);
            h = (h * 16777619L) & 0xffffffffL;  // 只留 32 位元
        }
        return h;
    }

    /** 第 i 個雜湊函數 g_i = (h1 + i·step) mod m（double hashing：兩個雜湊值湊出 k 個） */
    int[] positions(String key) {
        long h1 = fnv1a(key, SEED1), h2 = fnv1a(key, SEED2);
        int start = (int) (h1 % m);
        int step = 1 + (int) (h2 % (m - 1));    // 1 ~ m−1，不會原地踏步
        int[] pos = new int[k];
        for (int i = 0; i < k; i++) pos[i] = (int) ((start + (long) i * step) % m);
        return pos;
    }

    void add(String key) {
        for (int c : positions(key)) {
            if (counting) cells[c]++;           // 計數版：+1
            else cells[c] = 1;                  // 一般版：設成 1（已經是 1 就不變）
        }
    }

    /** k 格都不是 0 →「可能在」；看到第一個 0 就可以停 →「一定不在」 */
    boolean mightContain(String key) {
        for (int c : positions(key)) {
            if (cells[c] == 0)
                return false;                   // 一定不在
        }
        return true;                            // 可能在（也可能是別人剛好把這幾格都設過）
    }

    /** 只有計數版可以刪，而且只能刪「真的加過」的 */
    void remove(String key) {
        if (!counting)
            throw new UnsupportedOperationException("一般 Bloom Filter 不能刪除");
        for (int c : positions(key)) cells[c]--;
    }

    /** 理論誤判率：每格還是 0 的機率約 e^(−kn/m)，k 格剛好都被設過的機率 */
    static double falsePositiveRate(int m, int k, int n) {
        return Math.pow(1 - Math.exp(-(double) k * n / m), k);
    }

    /** 拿來測誤判率的發票號碼（ZZ 開頭，範例裡沒有登錄過） */
    static String testKey(int i) {
        return String.format("ZZ-%08d", i * 2654435761L % 100000000L);
    }

    /** 實測：拿 trials 張沒登錄過的發票去查，有幾張被誤判成「可能在」 */
    static int measure(BloomFilter bf, Set<String> added, int trials) {
        int wrong = 0, i = 0, tried = 0;
        while (tried < trials) {
            String key = testKey(++i);
            if (added.contains(key)) continue;
            tried++;
            if (bf.mightContain(key)) wrong++;
        }
        return wrong;
    }

    static String join(int[] a) {
        StringBuilder sb = new StringBuilder();
        for (int x : a) sb.append(sb.length() > 0 ? " " : "").append(x);
        return sb.toString();
    }

    static final String[] INVOICES = {"TR-50227071", "GP-02708508", "QP-97769865", "GY-91586091",
            "CC-85488622", "HK-50362354", "GP-49874681", "UX-92068559"};   // 已經登錄過的發票
    static final String[] QUERIES = {"QP-97769865", "QW-58160533", "MN-14419200"};   // 有登錄過、沒登錄過、沒登錄過
    static final String DELETE = "HK-50362354";                              // 計數版：取消登錄這一張

    public static void main(String[] args) {
        int m = 24, k = 3;
        Set<String> added = new HashSet<>(Arrays.asList(INVOICES));
        for (boolean counting : new boolean[]{false, true}) {
            BloomFilter bf = new BloomFilter(m, k, counting);
            for (String key : INVOICES) bf.add(key);
            System.out.println((counting ? "計數版" : "一般版") + "：m = " + m + "、k = " + k + "、登錄 " + INVOICES.length + " 張發票");
            System.out.println("  " + join(bf.cells));
            for (String key : QUERIES) {
                boolean got = bf.mightContain(key), truth = added.contains(key);
                System.out.println("  查 " + key + "：" + (got ? "可能在" : "一定不在") + "（實際" + (truth ? "有" : "沒有") + "登錄）"
                        + (got && !truth ? "  ← 誤判" : ""));
            }
            int n = INVOICES.length, ones = 0;
            for (int c : bf.cells) if (c != 0) ones++;
            System.out.println(String.format(Locale.ROOT, "  填滿 %d/%d = %.4f，理論誤判率 (1 − e^(−kn/m))^k = %.4f，實測 %d/1000",
                    ones, m, (double) ones / m, falsePositiveRate(m, k, n), measure(bf, added, 1000)));
            System.out.println(String.format(Locale.ROOT, "  最佳 k = (m/n)·ln 2 = %.4f", (double) m / n * Math.log(2)));
            if (counting) {
                bf.remove(DELETE);
                boolean all = true;
                int left = 0;
                for (String x : INVOICES) if (!x.equals(DELETE)) { left++; all &= bf.mightContain(x); }
                System.out.println("  刪除 " + DELETE + " 之後：");
                System.out.println("  " + join(bf.cells));
                System.out.println("  查 " + DELETE + "：" + (bf.mightContain(DELETE) ? "可能在" : "一定不在"));
                System.out.println("  其他 " + left + " 張都還是「可能在」：" + (all ? "True" : "False"));
            }
        }
    }
}
