#!/usr/bin/env python3
"""ChildB: find last SendToken/ReceiveToken per chain via Etherscan V2 getLogs.
Reads ETHERSCANV2_API_KEY from /home/heisenberg/CA/.env at runtime (key never printed/saved).
Walks logs ascending in 1000-result pages using the block of the last log as the next cursor."""
import json, sys, time, urllib.request, urllib.parse, re

ENV = "/home/heisenberg/CA/.env"
BRIDGE = "0x9C6D5a71FdD306329287a835e9B8EDb7F0F17898".lower()
TOPICS = {
    "SendToken":    "0x49b9b5358c9580b3e6c5ee10b8b260c1e64bede87cb8a212e9e20a0b7dc20e5a",
    "ReceiveToken": "0x5e3da8fba24af91505c66214c9e629ba712ce2c1b8c318f14f7024fdcba544a8",
}

def get_key():
    key = None
    for line in open(ENV):
        m = re.match(r'^ETHERSCANV2_API_KEY=(.*)$', line.strip())
        if m:
            key = m.group(1).strip().strip('"').strip("'")
    assert key, "key not found"
    return key

def api(chainid, params, key, tries=4):
    params = dict(params); params["apikey"] = key
    url = f"https://api.etherscan.io/v2/api?chainid={chainid}&" + urllib.parse.urlencode(params)
    for i in range(tries):
        try:
            with urllib.request.urlopen(url, timeout=40) as r:
                d = json.load(r)
            if d.get("status") == "1" or d.get("message", "").startswith("No"):  # "No logs found"
                return d
            if "rate limit" in json.dumps(d).lower() or d.get("result") == "Max rate limit reached":
                time.sleep(1.2); continue
            return d
        except Exception as e:
            time.sleep(1.0 + i)
    raise RuntimeError("etherscan api failed " + json.dumps(params)[:120])

def walk(chainid, topic, key, latest):
    logs, curse, page = [], 0, 1
    calls = 0
    while True:
        d = api(chainid, {"module": "logs", "action": "getLogs", "address": BRIDGE,
                          "topic0": topic, "fromBlock": curse, "toBlock": latest,
                          "page": page, "offset": 1000}, key)
        calls += 1
        if d.get("status") != "1":
            break
        res = d["result"]
        if not res:
            break
        logs.extend(res)
        if len(res) < 1000:
            break
        last_blk = int(res[-1]["blockNumber"], 16)
        if last_blk >= latest:
            break
        if page >= 10:            # jump cursor after 10k logs from same block window
            curse = last_blk + 1
            page = 1
        else:
            page += 1             # continue same cursor (handles block boundary)
        time.sleep(0.28)
    return logs, calls

def main():
    key = get_key()
    latest = {}
    for l in open("blocks.txt"):
        c, b = l.strip().split("|"); latest[c] = int(b)
    chainmap = {"ethereum": 1, "polygon": 137, "arbitrum": 42161}
    out = {}
    for cname, cid in chainmap.items():
        out[cname] = {}
        for ev, topic in TOPICS.items():
            logs, calls = walk(cid, topic, key, latest[cname])
            item = {"count": len(logs), "api_calls": calls,
                    "first": None, "last": None}
            if logs:
                f = logs[0]; l = logs[-1]
                item["first"] = {"block": int(f["blockNumber"], 16), "tx": f["transactionHash"],
                                 "timeStamp": int(f["timeStamp"], 16), "logIndex": int(f["logIndex"], 16)}
                item["last"] = {"block": int(l["blockNumber"], 16), "tx": l["transactionHash"],
                                "timeStamp": int(l["timeStamp"], 16), "logIndex": int(l["logIndex"], 16)}
            out[cname][ev] = item
            print(cname, ev, "count:", len(logs), "api_calls:", calls,
                  "last:", item["last"]["block"] if item["last"] else None,
                  flush=True)
            time.sleep(0.4)
    json.dump(out, open("raw/etherscan-last-events.json", "w"), indent=1)

if __name__ == "__main__":
    main()
