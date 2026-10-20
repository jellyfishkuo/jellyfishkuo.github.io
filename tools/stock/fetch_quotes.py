"""抓台股（上市＋上櫃）當天收盤價，寫到 stock/data/，給 stock/index.html 算市值與當日損益。

由 .github/workflows/stock-quotes.yml 每個交易日收盤後執行；也可以手動跑：
    python3 tools/stock/fetch_quotes.py
輸出：
    stock/data/latest.json      {"date", "fetchedAt", "days": [...], "q": {代號: [收盤價, 漲跌]}}
    stock/data/dYYYYMMDD.json   {"date", "q"}，只留最近 60 個交易日
沒有新資料（假日、已經抓過）就什麼都不改。
"""
import datetime
import json
import os
import re
import sys
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
OUT = os.path.join(ROOT, "stock", "data")
KEEP_DAYS = 60
# 股票、ETF、特別股；權證（6 碼 03xxxx～08xxxx、7xxxxx）不需要，省掉一大半檔案大小
WANTED = re.compile(r"^(\d{4}[A-Z]?|00\d{2,4}[A-Z]?)$")
SOURCES = [
    # (網址, 代號欄, 收盤價欄, 漲跌欄)
    ("https://openapi.twse.com.tw/v1/exchangeReport/STOCK_DAY_ALL", "Code", "ClosingPrice", "Change"),
    ("https://www.tpex.org.tw/openapi/v1/tpex_mainboard_daily_close_quotes", "SecuritiesCompanyCode", "Close", "Change"),
]


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0", "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def num(x):
    try:
        return float(str(x).replace(",", "").replace("+", "").strip())
    except (TypeError, ValueError):
        return None


def to_date(d):
    """民國 1151020 / 115/10/20 或西元 20261020 → 2026-10-20"""
    d = str(d or "").strip().replace("/", "")
    if len(d) == 7 and d.isdigit():
        return f"{int(d[:3]) + 1911}-{d[3:5]}-{d[5:7]}"
    if len(d) == 8 and d.isdigit():
        return f"{d[:4]}-{d[4:6]}-{d[6:8]}"
    return None


def fetch():
    q, dates = {}, []
    for url, kc, kp, kd in SOURCES:
        try:
            rows = get(url)
        except Exception as e:  # 一邊掛了另一邊照樣寫
            print("抓不到", url, e, file=sys.stderr)
            continue
        n = 0
        for r in rows:
            code = str(r.get(kc, "")).strip().upper()
            p, ch = num(r.get(kp)), num(r.get(kd))
            if not WANTED.match(code) or not p or p <= 0:
                continue
            q[code] = [round(p, 2), round(ch, 2) if ch is not None else 0]
            n += 1
            d = to_date(r.get("Date"))
            if d:
                dates.append(d)
        print(url, n, "檔")
    return q, (max(dates) if dates else None)


def main():
    q, date = fetch()
    if len(q) < 300:
        sys.exit(f"只抓到 {len(q)} 檔，不寫入")
    if not date:
        date = (datetime.datetime.utcnow() + datetime.timedelta(hours=8)).strftime("%Y-%m-%d")
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "latest.json")
    old = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            old = json.load(f)
        if old.get("date") == date and old.get("q") == q:
            print("沒有新資料", date)
            return
    days = sorted(set(old.get("days", [])) | {date})[-KEEP_DAYS:]
    dump = lambda obj, name: json.dump(obj, open(os.path.join(OUT, name), "w", encoding="utf-8"),
                                       ensure_ascii=False, separators=(",", ":"))
    dump({"date": date, "q": q}, "d" + date.replace("-", "") + ".json")
    dump({"date": date, "fetchedAt": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
          "days": days, "q": q}, "latest.json")
    keep = {"d" + d.replace("-", "") + ".json" for d in days}
    for name in os.listdir(OUT):
        if name.startswith("d") and name.endswith(".json") and name not in keep:
            os.remove(os.path.join(OUT, name))
    print("寫入", date, len(q), "檔")


if __name__ == "__main__":
    main()
