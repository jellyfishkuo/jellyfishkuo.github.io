"""抓台股（上市＋上櫃）當天收盤價，寫到 stock/data/，給 stock/index.html 算市值與當日損益。

由 .github/workflows/stock-quotes.yml 每個交易日收盤後執行；也可以手動跑：
    python3 tools/stock/fetch_quotes.py
輸出：
    stock/data/latest.json      {"date", "fetchedAt", "q": {代號: [收盤價, 漲跌]}}
    stock/data/hist/<代號>.json  每檔每天的收盤價（見 hist.py；更早的用 backfill.py 補）
    stock/data/names.json       {代號: 名稱}，打代號時自動帶名稱用（下市的舊名稱會留著）
沒有新資料（假日、已經抓過）就什麼都不改。

收盤價一定用「指定日期」的證交所 MI_INDEX／櫃買中心每日收盤行情（backfill.py 的 twse()、tpex()），
這兩個查今天、今天還沒公布就是空的。OpenAPI 只拿來更新名稱：它在傍晚常常還是前一天的資料，
又沒有日期欄位，以前直接拿來當今天的收盤價，結果上市股票記成前一天的價格。
上市、上櫃都抓到才寫入，沒抓到就等下一次排程（workflow 一天跑好幾次）。
"""
import datetime
import json
import os
import re
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hist import HIST, add_days  # noqa: E402
from backfill import tpex, twse  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
OUT = os.path.join(ROOT, "stock", "data")
# 股票、ETF、特別股；權證（6 碼 03xxxx～08xxxx、7xxxxx）不需要，省掉一大半檔案大小
WANTED = re.compile(r"^(\d{4}[A-Z]?|00\d{2,4}[A-Z]?)$")
SOURCES = [
    # (網址, 代號欄, 名稱欄, 收盤價欄, 漲跌欄)
    ("https://openapi.twse.com.tw/v1/exchangeReport/STOCK_DAY_ALL", "Code", "Name", "ClosingPrice", "Change"),
    ("https://www.tpex.org.tw/openapi/v1/tpex_mainboard_daily_close_quotes", "SecuritiesCompanyCode", "CompanyName", "Close", "Change"),
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
    q, names, dates = {}, {}, []
    for url, kc, kn, kp, kd in SOURCES:
        try:
            rows = get(url)
        except Exception as e:  # 一邊掛了另一邊照樣寫
            print("抓不到", url, e, file=sys.stderr)
            continue
        n = 0
        for r in rows:
            code = str(r.get(kc, "")).strip().upper()
            # 名稱欄位名稱兩邊不一樣，櫃買中心的也改過，找不到就用任何名字有 Name 的欄位
            name = str(r.get(kn) or next((v for k, v in r.items() if "Name" in k and v), "") or "").strip()
            if WANTED.match(code) and name:
                names[code] = name
            p, ch = num(r.get(kp)), num(r.get(kd))
            if not WANTED.match(code) or not p or p <= 0:
                continue
            q[code] = [round(p, 2), round(ch, 2) if ch is not None else 0]
            n += 1
            d = to_date(r.get("Date"))
            if d:
                dates.append(d)
        print(url, n, "檔", "欄位：" + ",".join(rows[0].keys()) if rows else "")
    return q, names, (max(dates) if dates else None)


def main():
    _, names, _ = fetch()
    os.makedirs(OUT, exist_ok=True)
    npath = os.path.join(OUT, "names.json")
    old_names = {}
    if os.path.exists(npath):
        with open(npath, encoding="utf-8") as f:
            old_names = json.load(f)
    merged = {**old_names, **names}
    if merged != old_names:
        with open(npath, "w", encoding="utf-8") as f:
            json.dump(dict(sorted(merged.items())), f, ensure_ascii=False, separators=(",", ":"))
        print("名稱", len(merged), "檔")

    day = (datetime.datetime.utcnow() + datetime.timedelta(hours=8)).date()
    if len(sys.argv) > 1:
        day = datetime.date.fromisoformat(sys.argv[1])
    date = day.isoformat()
    a = twse(day)
    b = tpex(day)
    print(date, "上市", len(a), "上櫃", len(b))
    if len(a) < 300 or len(b) < 300:
        print("還沒公布（或今天沒開盤），先不寫入", date)
        return
    q = {**b, **a}
    # 漲跌抓不到（例如除息寫「除息」）就用前一天收盤價補
    for code, v in q.items():
        if v[1] is None:
            v[1] = 0
            path = os.path.join(HIST, code + ".json")
            if os.path.exists(path):
                with open(path, encoding="utf-8") as f:
                    prev = [k for k in json.load(f).items() if k[0] < date]
                if prev:
                    v[1] = round(v[0] - max(prev)[1][0], 2)
    path = os.path.join(OUT, "latest.json")
    old = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            old = json.load(f)
    if old.get("date") == date and old.get("q") == q:
        print("沒有新資料", date)
    else:
        with open(path, "w", encoding="utf-8") as f:
            json.dump({"date": date, "fetchedAt": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"), "q": q},
                      f, ensure_ascii=False, separators=(",", ":"))
        print("寫入", date, len(q), "檔")
    print("每檔歷史更新", add_days({date: q}), "檔")


if __name__ == "__main__":
    main()
