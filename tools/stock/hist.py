"""每檔股票的每日收盤紀錄：stock/data/hist/<代號>.json = {"YYYY-MM-DD": [收盤價, 漲跌], ...}

頁面只下載自己有交易的那幾檔，用來算從第一筆交易開始每天的賺賠。
fetch_quotes.py 每天加一天；backfill.py 一次補很多天。
"""
import json
import os

HIST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "stock", "data", "hist")


def add_days(days):
    """days: {日期: {代號: [收盤價, 漲跌]}}，合併進每檔的檔案，回傳改到幾個檔案"""
    by_code = {}
    for date, q in days.items():
        for code, v in q.items():
            by_code.setdefault(code, {})[date] = v
    os.makedirs(HIST, exist_ok=True)
    changed = 0
    for code, new in by_code.items():
        path = os.path.join(HIST, code + ".json")
        old = {}
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                old = json.load(f)
        merged = {**old, **new}
        if merged == old:
            continue
        with open(path, "w", encoding="utf-8") as f:
            json.dump(dict(sorted(merged.items())), f, separators=(",", ":"))
        changed += 1
    return changed
