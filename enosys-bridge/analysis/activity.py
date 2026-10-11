#!/usr/bin/env python3
"""Enosys Bridge — true last-activity dating v3 (read-only).

Explorer sort=desc is unreliable; scan descending block ranges and report the
max block/timestamp per topic per end.
"""
import json
import os
import time
import urllib.request

TOPICS = {
    "Executed": "0x775fb71ba106691d4fd81c953ace830d359f3b850e98fbc2a1ebf420af86428a",
    "Deposit": "0x3a58bc9c7c305b0dba42522c856c30706aadce643b5dc3c0a1a0c41fec127d99",
}
KEY = os.environ.get("ETHERSCANV2_API_KEY", "")


def get_json(url, tmo=40):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    return json.load(urllib.request.urlopen(req, timeout=tmo))


def es_logs(addr, topic, frm, to):
    url = (
        f"https://api.etherscan.io/v2/api?chainid=1&module=logs&action=getLogs"
        f"&address={addr}&topic0={topic}&fromBlock={frm}&toBlock={to}&page=1&offset=1000"
    )
    if KEY:
        url += f"&apikey={KEY}"
    for _ in range(3):
        try:
            r = get_json(url)
            if isinstance(r.get("result"), list):
                return r["result"]
            if r.get("message") == "No records found":
                return []
            return []
        except Exception:  # noqa: BLE001
            time.sleep(2)
    return None


def bs_logs(base, addr, topic, frm, to):
    url = f"{base}?module=logs&action=getLogs&address={addr}&fromBlock={frm}&toBlock={to}&topic0={topic}&page=1&offset=1000"
    try:
        r = get_json(url)
        if isinstance(r.get("result"), list):
            return r["result"]
        return []
    except Exception:  # noqa: BLE001
        return None


def summarize(rows):
    if not rows:
        return {"count": 0}
    blocks = [int(x["blockNumber"], 16) for x in rows]
    ts = [int(x.get("timeStamp", "0x0"), 16) for x in rows]
    return {"count": len(rows), "max_block": max(blocks), "max_ts": max(ts), "min_block": min(blocks)}


ETH_A = "0x8936761f2903ed1af2b269e6fa3a79ebb0162c51"
ETH_B = "0x37aca97a99d1b4260a5e9821d0ef14947fb68970"
XDC = "0xcb71dc7b30205eb7ce27b2cb36b24ba331ecd42a"
LATEST = {"eth": 26171961, "xdc": 108251475, "songbird": 135152406, "flare": 71883284}

out = {}
# ETH: descending range scan
for label, addr in (("ETH-A", ETH_A), ("ETH-B", ETH_B)):
    e = {}
    for name, topic in TOPICS.items():
        got = {"count": 0}
        for frm in (26000000, 25000000, 24000000, 22000000, 21000000):
            rows = es_logs(addr, topic, frm, LATEST["eth"])
            if rows:
                got = {"range_from": frm, **summarize(rows)}
                break
        e[name] = got
    out[label] = e
    print(label, json.dumps(e), flush=True)

# XDC: decimal blocks
e = {}
for name, topic in TOPICS.items():
    got = {"count": 0}
    for frm in (106000000, 100000000, 90000000, 80000000):
        rows = bs_logs("https://xdc.blocksscan.io/api", XDC, topic, str(frm), str(LATEST["xdc"]))
        if rows:
            got = {"range_from": frm, **summarize(rows)}
            break
    e[name] = got
out["XDC custody"] = e
print("XDC custody", json.dumps(e), flush=True)

# Songbird / Flare: Blockscout
for label, base, addr, lat in (
    ("Songbird-A", "https://songbird-explorer.flare.network/api", ETH_A, LATEST["songbird"]),
    ("Songbird-XDC", "https://songbird-explorer.flare.network/api", XDC, LATEST["songbird"]),
    ("Flare", "https://flare-explorer.flare.network/api", ETH_B, LATEST["flare"]),
):
    e = {}
    for name, topic in TOPICS.items():
        got = {"count": 0}
        for frm in (lat - 5000000, lat - 20000000, lat - 50000000, 0):
            if frm < 0:
                continue
            rows = bs_logs(base, addr, topic, str(frm), str(lat))
            if rows:
                got = {"range_from": frm, **summarize(rows)}
                break
        e[name] = got
    out[label] = e
    print(label, json.dumps(e), flush=True)

with open("analysis/activity.json", "w") as f:
    json.dump(out, f, indent=2)
print("written analysis/activity.json")
