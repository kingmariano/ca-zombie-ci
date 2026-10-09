#!/usr/bin/env python3
"""Scan PA TransferSingle logs over the last N blocks via Etherscan V2, chunked by block
windows because Etherscan caps each query at 10k results (page<=10 x 1000).

Writes raw pages to analysis/census/raw/ft_ts_<from>_<to>_p<page>.json
and a filtered event list to ft_events_filtered.json for the 4 FT base types.
"""
import json, os, sys, time, urllib.request, urllib.parse

CENSUS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RAW = os.path.join(CENSUS, "raw")
PA = "0xfaafdc07907ff5120a76b34b731b278c38d6043c"
TS_TOPIC = "0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62"
LATEST = 26152527  # pinned block
SPAN = 3_000_000
WIN = 100_000
API = "https://api.etherscan.io/v2/api"

def fetch(params, tries=6):
    key = os.environ["ETHERSCANV2_API_KEY"]
    url = API + "?" + urllib.parse.urlencode(params)
    for t in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 census/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                body = json.load(r)
            if body.get("status") == "1" or str(body.get("message", "")).startswith("No records"):
                return body
            if "window is too large" in str(body.get("message", "")):
                return body  # caller handles by splitting
            time.sleep(0.8 + t)
        except Exception as e:
            sys.stderr.write(f"retry {t}: {e}\n")
            time.sleep(0.8 + t)
    raise RuntimeError("fetch failed")

def get_window(frm, to):
    """Return list of logs for [frm,to], splitting recursively if >10k results."""
    out = []
    stack = [(frm, to)]
    while stack:
        a, b = stack.pop()
        pages = []
        for page in range(1, 11):
            fn = os.path.join(RAW, f"ft_ts_{a}_{b}_p{page}.json")
            if os.path.exists(fn):
                with open(fn) as f:
                    body = json.load(f)
            else:
                body = fetch({
                    "chainid": "1", "module": "logs", "action": "getLogs",
                    "fromBlock": str(a), "toBlock": str(b), "address": PA, "topic0": TS_TOPIC,
                    "page": str(page), "offset": "1000",
                    "apikey": os.environ["ETHERSCANV2_API_KEY"],
                })
                with open(fn, "w") as f:
                    json.dump(body, f)
                time.sleep(0.35)
            logs = body.get("result") if isinstance(body.get("result"), list) else []
            pages.append(len(logs))
            out.extend(logs)
            if len(logs) < 1000:
                break
        else:
            # all 10 pages full -> window truncated
            if b - a <= 10_000:
                sys.stderr.write(f"WARNING: window {a}-{b} still full at 10k, keeping first 10k\n")
                continue
            # drop this window's results, split in half and re-fetch
            out = out[: len(out) - 10_000]
            mid = (a + b) // 2
            stack.append((mid + 1, b))
            stack.append((a, mid))
            sys.stderr.write(f"split window {a}-{b} (10k full) -> {a}-{mid}, {mid+1}-{b}\n")
    return out

def main():
    os.makedirs(RAW, exist_ok=True)
    base_types = set()
    with open(os.path.join(CENSUS, "shells_parsed.json")) as f:
        for s in json.load(f)["shells"]:
            if s["kind"] == "FT":
                base_types.add(int(s["baseType"]))
    mask = ~((1 << 64) - 1)
    hi = {b & mask for b in base_types}

    per_window = {}
    all_logs = []
    frm0 = LATEST - SPAN
    a = frm0
    while a <= LATEST:
        b = min(a + WIN - 1, LATEST)
        logs = get_window(a, b)
        per_window[f"{a}-{b}"] = len(logs)
        all_logs.extend(logs)
        print(f"window {a}-{b}: {len(logs)} logs (cum {len(all_logs)})", flush=True)
        a = b + 1

    # dedupe by (txHash, logIndex)
    seen = set()
    events = []
    for lg in all_logs:
        k = (lg["transactionHash"], lg["logIndex"])
        if k in seen:
            continue
        seen.add(k)
        topics = lg["topics"]
        # topics: [sig, operator, from, to], data: id, value
        data = lg["data"][2:]
        iid = int(data[0:64], 16)
        val = int(data[64:128], 16)
        if (iid & mask) not in hi:
            continue
        events.append({
            "id": str(iid),
            "idHex": hex(iid),
            "baseType": hex(iid & mask),
            "from": "0x" + topics[2][-40:],
            "to": "0x" + topics[3][-40:],
            "value": str(val),
            "block": int(lg["blockNumber"], 16),
            "txHash": lg["transactionHash"],
            "logIndex": lg["logIndex"],
        })
    events.sort(key=lambda e: e["block"])
    with open(os.path.join(CENSUS, "ft_events_filtered.json"), "w") as f:
        json.dump({"window": f"{frm0}-{LATEST}", "windows": per_window, "count": len(events), "events": events}, f)

    print(f"total TransferSingle raw logs: {len(all_logs)}; FT-filtered events: {len(events)}")
    for b in sorted(base_types):
        ev = [e for e in events if e["baseType"] == hex(b)]
        holders = {}
        for e in ev:
            if e["to"] != "0x0000000000000000000000000000000000000000" and int(e["value"]) > 0:
                holders[e["to"]] = holders.get(e["to"], 0) + int(e["value"])
        print(f"baseType {hex(b)}: events={len(ev)} distinct recipients={len(holders)}")

if __name__ == "__main__":
    main()
