"""補過去每天的收盤價到 stock/data/hist/（每日損益要從第一筆交易那天開始算）。

    python3 tools/stock/backfill.py 2025-01-01            # 從這天補到昨天
    python3 tools/stock/backfill.py 2025-01-01 2025-01-10 # 指定區間

上市用證交所 MI_INDEX（每天全部股票），上櫃用櫃買中心每日收盤行情。證交所會擋太快的請求，
所以每天之間會等幾秒；已經有資料的日子（看 2330 和 6488 的檔案）會跳過，中斷了重跑就好。
由 .github/workflows/stock-backfill.yml 手動觸發。
"""
import datetime
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hist import HIST, add_days  # noqa: E402

WANTED = re.compile(r"^(\d{4}[A-Z]?|00\d{2,4}[A-Z]?)$")


def get(url, tries=4):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0", "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode("utf-8-sig"))
        except Exception as e:
            print("  重試", i + 1, url, e)
            time.sleep(10 * (i + 1))
    return None


def num(x):
    s = re.sub(r"<[^>]*>", "", str(x)).replace(",", "").replace("+", "").strip()
    try:
        return float(s)
    except ValueError:
        return None


def pick_table(js, code_word, close_word):
    """從回傳裡找有「代號」和「收盤」欄位的表，回傳 (欄位, 資料列)"""
    tables = []
    if isinstance(js, dict):
        tables += js.get("tables") or []
        if "fields" in js and "data" in js:
            tables.append(js)
    for t in tables:
        f = [str(x).strip() for x in (t.get("fields") or [])]
        if any(code_word in x for x in f) and any(close_word in x for x in f):
            return f, t.get("data") or []
    return None, []


def same_day(js, day):
    """回傳的日期跟要查的不一樣（還沒公布時有的會給最近一天）就不要用"""
    d = re.sub(r"\D", "", str((js or {}).get("date") or "")) if isinstance(js, dict) else ""
    if len(d) == 7:
        d = str(int(d[:3]) + 1911) + d[3:]
    return len(d) != 8 or d == f"{day:%Y%m%d}"


def twse(day):
    js = get(f"https://www.twse.com.tw/rwd/zh/afterTrading/MI_INDEX?date={day:%Y%m%d}&type=ALLBUT0999&response=json")
    f, rows = pick_table(js, "證券代號", "收盤價")
    if not f or not same_day(js, day):
        return {}
    ic, ip = f.index("證券代號"), f.index("收盤價")
    isg = next((i for i, x in enumerate(f) if "漲跌(+/-)" in x), None)
    idf = next((i for i, x in enumerate(f) if "漲跌價差" in x), None)
    q = {}
    for r in rows:
        code, p = str(r[ic]).strip().upper(), num(r[ip])
        if not WANTED.match(code) or not p or p <= 0:
            continue
        ch = num(r[idf]) if idf is not None else None
        if ch is not None and isg is not None and "-" in re.sub(r"<[^>]*>", "", str(r[isg])):
            ch = -abs(ch)
        q[code] = [round(p, 2), None if ch is None else round(ch, 2)]
    return q


def tpex(day):
    roc = f"{day.year - 1911}/{day:%m/%d}"
    js = get("https://www.tpex.org.tw/www/zh-tw/afterTrading/dailyQuotes?"
             + urllib.parse.urlencode({"date": f"{day:%Y/%m/%d}", "type": "EW", "response": "json"}))
    f, rows = pick_table(js, "代號", "收盤")
    if f and not same_day(js, day):
        return {}
    if f:
        ic = next(i for i, x in enumerate(f) if "代號" in x)
        ip = next(i for i, x in enumerate(f) if "收盤" in x)
        idf = next((i for i, x in enumerate(f) if x.startswith("漲跌")), None)
    else:  # 舊版網址
        js = get("https://www.tpex.org.tw/web/stock/aftertrading/otc_quotes_no1430/stk_wn1430_result.php?"
                 + urllib.parse.urlencode({"l": "zh-tw", "d": roc, "se": "EW", "o": "json"}))
        rows = (js or {}).get("aaData") or []
        ic, ip, idf = 0, 2, 3
    q = {}
    for r in rows:
        code, p = str(r[ic]).strip().upper(), num(r[ip])
        if not WANTED.match(code) or not p or p <= 0:
            continue
        ch = num(r[idf]) if idf is not None else None
        q[code] = [round(p, 2), None if ch is None else round(ch, 2)]
    return q


def have(date):
    """2330（上市）和 6488（上櫃）都有這天就當作補過了"""
    for code in ("2330", "6488"):
        path = os.path.join(HIST, code + ".json")
        if not os.path.exists(path):
            return False
        with open(path, encoding="utf-8") as f:
            if date not in json.load(f):
                return False
    return True


def fix_changes():
    """漲跌抓不到的（例如寫「除息」），用前一個交易日的收盤價補"""
    for name in os.listdir(HIST):
        path = os.path.join(HIST, name)
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
        prev, dirty = None, False
        for k in sorted(d):
            if d[k][1] is None:
                d[k][1] = round(d[k][0] - prev, 2) if prev else 0
                dirty = True
            prev = d[k][0]
        if dirty:
            with open(path, "w", encoding="utf-8") as f:
                json.dump(d, f, separators=(",", ":"))


def main():
    since = datetime.date.fromisoformat(sys.argv[1])
    today = (datetime.datetime.utcnow() + datetime.timedelta(hours=8)).date()
    until = datetime.date.fromisoformat(sys.argv[2]) if len(sys.argv) > 2 else today - datetime.timedelta(days=1)
    pending, done, day = {}, 0, since
    while day <= until:
        iso = day.isoformat()
        if day.weekday() < 5 and not have(iso):
            a = twse(day)
            time.sleep(3)
            b = tpex(day)
            time.sleep(1.5)
            print(iso, "上市", len(a), "上櫃", len(b))
            if a or b:
                pending[iso] = {**b, **a}
                done += 1
            if len(pending) >= 20:
                add_days(pending)
                pending = {}
        day += datetime.timedelta(days=1)
    if pending:
        add_days(pending)
    fix_changes()
    print("補了", done, "個交易日")


if __name__ == "__main__":
    main()
