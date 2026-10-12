#!/usr/bin/env python3
"""Fetch full event set for v2 Trading contracts with block-range pagination (Etherscan 10k window)."""
import json, os, urllib.request, time, sys

key = os.environ["ETHERSCANV2_API_KEY"]
outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "state")

TOPICS = {
    "NewOrderV2": "0xe6f0e81a24c1b1c11cfcbbce67e7c5ef361e984c1e4f3528125c93f6f906680d",
    "PositionUpdatedV2": "0x722a60bf2980ad6565c04c8210c55454af895983660b33099a60a0af5e05037b",
    "ClosePositionV2": "0x1eba783f67334e9b95080299c6a95635568b5bf34dbe80586bc9f938307d7b9c",
}

def get_logs(addr, topic0, from_block, to_block):
    """Returns (logs, truncated_bool). Paginate up to 10 pages of 1000."""
    out = []
    for page in range(1, 11):
        url = (f"https://api.etherscan.io/v2/api?chainid=42161&module=logs&action=getLogs"
               f"&fromBlock={from_block}&toBlock={to_block}&address={addr}&topic0={topic0}"
               f"&apikey={key}&offset=1000&page={page}")
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        d = json.load(urllib.request.urlopen(req, timeout=60))
        res = d.get("result", [])
        if not isinstance(res, list):
            if d.get("message") == "No records found":
                return out, False
            # window too large -> truncated
            return out, True
        out.extend(res)
        if len(res) < 1000:
            return out, False
        time.sleep(0.15)
    return out, True

def fetch_range(addr, topic0, start, end, label):
    """Recursively split windows that hit the 10k cap."""
    logs, trunc = get_logs(addr, topic0, start, end)
    if not trunc:
        return logs
    if end - start < 2:
        return logs
    mid = (start + end) // 2
    left = fetch_range(addr, topic0, start, mid, label)
    right = fetch_range(addr, topic0, mid + 1, end, label)
    return left + right

if __name__ == "__main__":
    addr = sys.argv[1]
    label = sys.argv[2]
    start = int(sys.argv[3])
    end = int(sys.argv[4])
    all_logs = []
    for name, t0 in TOPICS.items():
        logs = fetch_range(addr, t0, start, end, label)
        for l in logs:
            l["_event"] = name
        print(f"{label} {name}: {len(logs)}", flush=True)
        all_logs.extend(logs)
    all_logs.sort(key=lambda l: int(l["blockNumber"], 16))
    fn = os.path.join(outdir, f"v2logs-{label}.json")
    json.dump(all_logs, open(fn, "w"), indent=1)
    print(f"saved {fn}: {len(all_logs)} logs")
