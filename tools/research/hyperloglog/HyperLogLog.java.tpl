import java.nio.charset.StandardCharsets; «hide»
import java.util.*; «hide»
 «hide»
/** HyperLogLog：只用 m 個小暫存器，估計串流裡有幾個「不同的」會員（Flajolet 等人，2007） */ «hide»
public class HyperLogLog { «hide»
    final int p, m;                 // 用雜湊值的前 p 個位元選暫存器，m = 2^p 個 «start»
    final int[] M;                  // 每格記「看過最長的開頭 0」+1，一開始全是 0 «start»

    HyperLogLog(int p) { «start{»
        this.p = p;
        this.m = 1 << p;
        M = new int[m];
    } «}start»

    /** FNV-1a 32 位元，再用 murmur3 的 fmix32 把位元攪勻（前幾個位元也要夠亂） */
    static int hash32(String s) { «hash{»
        int h = 0x811C9DC5;                     // 2166136261：int 只有 32 位元，溢位剛好就是 mod 2^32
        for (byte b : s.getBytes(StandardCharsets.UTF_8)) {
            h ^= (b & 0xff);
            h *= 16777619;
        }
        h ^= h >>> 16;
        h *= 0x85EBCA6B;
        h ^= h >>> 13;
        h *= 0xC2B2AE35;
        h ^= h >>> 16;
        return h;
    } «}hash»

    /** 修正係數 α_m：調和平均本身會偏高，乘上它拉回來 */
    static double alpha(int m) { «raw{»
        if (m == 16) return 0.673;
        if (m == 32) return 0.697;
        if (m == 64) return 0.709;
        return 0.7213 / (1 + 1.079 / m);
    } «}raw»

    void add(String key) {
        int h = hash32(key); «hash»
        int j = h >>> (32 - p);                 // 前 p 位元 → 第 j 個暫存器 «index»
        int w = h << p;                         // 剩下的 32−p 位元，移到最左邊 «rho»
        int rho = w == 0 ? 32 - p + 1 : Integer.numberOfLeadingZeros(w) + 1;   // 開頭幾個 0，再 +1 «rho»
        if (rho > M[j]) «update»
            M[j] = rho;                         // 只留最大值：同一個人再來，值一樣，不會變 «update»
    }

    double estimate() {
        double total = 0;
        int zeros = 0;
        for (int r : M) { «sum»
            total += Math.pow(2, -r);           // Σ 2^(−M[j]) «sum»
            if (r == 0) zeros++;                // 還沒被用到的暫存器 «sum»
        } «sum»
        double e = alpha(m) * m * m / total;    // 調和平均：E = α·m²／Σ «raw»
        if (e <= 2.5 * m && zeros > 0) «small»
            return m * Math.log((double) m / zeros);   // 人很少：改用 linear counting «small»
        double two32 = 4294967296.0; «large»
        if (e > two32 / 30) «large»
            return -two32 * Math.log(1 - e / two32);   // 快把 32 位元用完：修正碰撞 «large»
        return e; «raw»
    }

    /** 兩家分店的 HLL 合併：每格取最大值 = 把兩邊的來客一起丟進去 */
    void merge(HyperLogLog other) { «merge{»
        for (int j = 0; j < m; j++)
            M[j] = Math.max(M[j], other.M[j]);
    } «}merge»
 «hide{»
    /** 給 main 印出來看：這位會員的雜湊、第幾格、ρ */
    int[] detail(String key) {
        int h = hash32(key);
        int j = h >>> (32 - p);
        int w = h << p;
        int rho = w == 0 ? 32 - p + 1 : Integer.numberOfLeadingZeros(w) + 1;
        return new int[]{h, j, rho};
    }

    /** 實驗用的會員卡號：k 不同，卡號就不同 */
    static String member(long k) {
        return String.format("M-%08d", k * 2654435761L % 100000000L);
    }

    static String join(int[] a) {
        StringBuilder sb = new StringBuilder();
        for (int x : a) sb.append(sb.length() > 0 ? " " : "").append(x);
        return sb.toString();
    }

    static final String[] STORE_A = {"M-07912728", "M-29287351", "M-38578460", "M-07912728", "M-17359750", "M-99101455",
            "M-29287351", "M-33234300", "M-53404922", "M-52472380", "M-66640001", "M-38578460"};   // A 店今天的來客順序
    static final String[] STORE_B = {"M-67098887", "M-29287351", "M-76880921", "M-01950523", "M-33234300", "M-83880784",
            "M-66640001", "M-88887737"};                                                           // B 店（有 3 位也去過 A 店）

    public static void main(String[] args) {
        int p = 4;
        HyperLogLog a = new HyperLogLog(p);
        System.out.println("A 店：p = " + p + "、m = " + a.m + " 個暫存器，來客 " + STORE_A.length + " 次");
        for (String key : STORE_A) {
            int[] d = a.detail(key);
            int before = a.M[d[1]];
            a.add(key);
            String bits = String.format("%32s", Integer.toBinaryString(d[0])).replace(' ', '0');
            System.out.println(String.format("  %s  %s %s  第 %2d 格  ρ = %d  M[%d] %d → %d",
                    key, bits.substring(0, p), bits.substring(p), d[1], d[2], d[1], before, a.M[d[1]]));
        }
        System.out.println("  暫存器：" + join(a.M));
        double total = 0;
        int zeros = 0;
        for (int r : a.M) { total += Math.pow(2, -r); if (r == 0) zeros++; }
        double raw = alpha(a.m) * a.m * a.m / total;
        System.out.println(String.format(Locale.ROOT, "  Σ2^(−M) = %.6f，空格 V = %d，調和平均 E = %.4f", total, zeros, raw));
        System.out.println(String.format(Locale.ROOT, "  估計 %.4f 人，實際 %d 人", a.estimate(), new HashSet<>(Arrays.asList(STORE_A)).size()));

        HyperLogLog b = new HyperLogLog(p);
        for (String key : STORE_B) b.add(key);
        System.out.println("B 店：暫存器 " + join(b.M));
        System.out.println(String.format(Locale.ROOT, "  估計 %.4f 人，實際 %d 人", b.estimate(), new HashSet<>(Arrays.asList(STORE_B)).size()));
        a.merge(b);
        Set<String> union = new HashSet<>(Arrays.asList(STORE_A));
        union.addAll(Arrays.asList(STORE_B));
        System.out.println("合併（每格取最大）：" + join(a.M));
        System.out.println(String.format(Locale.ROOT, "  估計 %.4f 人，實際兩店合計不同 %d 人", a.estimate(), union.size()));

        int n = 100000, distinct = 70000;
        String[] visits = new String[n];
        for (int i = 0; i < n; i++) visits[i] = member((long) i * 37 % distinct);
        System.out.println("大量測試：" + n + " 次來店、" + new HashSet<>(Arrays.asList(visits)).size() + " 位不同會員");
        for (p = 4; p <= 10; p++) {
            HyperLogLog hll = new HyperLogLog(p), half1 = new HyperLogLog(p), half2 = new HyperLogLog(p);
            for (int i = 0; i < n; i++) {
                hll.add(visits[i]);
                (i % 2 == 0 ? half1 : half2).add(visits[i]);
            }
            half1.merge(half2);
            double est = hll.estimate();
            System.out.println(String.format(Locale.ROOT, "  p = %2d  m = %4d  估計 %10.2f  誤差 %+7.2f%%  理論標準誤差 1.04/√m = %5.2f%%  拆兩半再合併相同：%s",
                    p, hll.m, est, (est - distinct) / distinct * 100, 1.04 / Math.sqrt(hll.m) * 100,
                    Arrays.equals(half1.M, hll.M) ? "True" : "False"));
        }
    }
} «}hide»
