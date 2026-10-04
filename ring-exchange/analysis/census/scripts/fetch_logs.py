#!/usr/bin/env python3
"""Holder census via Etherscan V2 logs (chain 999). Read-only.
Fetches Transfer + Approval logs for 5 fw tokens and 5 pair LP tokens,
aggregates net balances and latest approvals. Saves raw logs + JSON summaries.
"""
import json, os, time, urllib.request, urllib.parse, sys

HERE = os.path.dirname(os.path.abspath(__file__))
CENSUS = os.path.dirname(HERE)
RAW = os.path.join(CENSUS, "raw")
os.makedirs(RAW, exist_ok=True)

KEY = os.environ["ETHERSCANV2_API_KEY"]
BASE = "https://api.etherscan.io/v2/api"
TRANSFER = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
APPROVAL = "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"

TARGETS = {
    "fwWHYPE": {"addr": "0x9e1148bC3665a9f7C35F313d89c0432c34928AEf", "kind": "fw"},
    "fwUETH":  {"addr": "0x0C47cbbEDE5d8c6f9614cF770C26c3315205C397", "kind": "fw"},
    "fwUSDC":  {"addr": "0xd2646b9B02859416D8cBc759F85f0676f6E19974", "kind": "fw"},
    "fwUSDT0": {"addr": "0x7576dd9a2775bFd789616d9eA7A2af21d06782D0", "kind": "fw"},
    "fwUSDH":  {"addr": "0x09D21E89EF332347eb3E1E496f1265a600e364C1", "kind": "fw"},
    "pair1_LP_fwUETH_fwWHYPE":  {"addr": "0x0185E8e8B7FDf22638ecB2D781b3EA7E8AA2452a", "kind": "lp"},
    "pair2_LP_fwUSDH_fwUSDC":   {"addr": "0xabEd9A9aDe03a80ED98f903Eb9db62DE55C9DDF3", "kind": "lp"},
    "pair3_LP_fwUSDH_fwUSDT0":  {"addr": "0xf37f1e83BEb55F1b88AF9A8Df1a746e79C222150", "kind": "lp"},
    "pair4_LP_fwUSDT0_fwUSDC":  {"addr": "0x8868a630dD13A954D3f8B186508EF6c733BE959F", "kind": "lp"},
    "pair5_LP_fwUSDT0_fwWHYPE": {"addr": "0xf3760B19f1Baa2bFcf6Bd6e5d174e129c80aeD17", "kind": "lp"},
}

def es(params, tries=8):
    q = {"chainid": 999, "apikey": KEY, **params}
    url = BASE + "?" + urllib.parse.urlencode(q)
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "research/1.0"})
            with urllib.request.urlopen(req, timeout=90) as r:
                d = json.loads(r.read())
        except Exception as e:
            print("  net err:", e, file=sys.stderr); time.sleep(3 * (attempt + 1)); continue
        if d.get("status") == "1" or d.get("message") == "No records found":
            return d
        msg = str(d.get("result", ""))[:200]
        if "rate limit" in msg.lower() or "max calls" in msg.lower() or d.get("status") == "":
            time.sleep(3 * (attempt + 1)); continue
        print("  api msg:", msg, file=sys.stderr)
        return d
    print("  RETRY EXHAUSTED", file=sys.stderr)
    return d

def get_logs(addr, topic0, max_pages=80):
    logs, page = [], 1
    while page <= max_pages:
        d = es({"module": "logs", "action": "getLogs", "address": addr,
                "topic0": topic0, "fromBlock": 0, "toBlock": "latest",
                "page": page, "offset": 1000})
        res = d.get("result")
        if not isinstance(res, list) or len(res) == 0:
            break
        logs += res
        print(f"    page {page}: {len(res)} logs (total {len(logs)})")
        if len(res) < 1000:
            break
        page += 1
        time.sleep(0.4)
    return logs

def topic_to_addr(t):
    return "0x" + t[-40:].lower()

def run():
    summary = {}
    for name, t in TARGETS.items():
        addr = t["addr"]
        print(f"[{name}] {addr}")
        tl = get_logs(addr, TRANSFER)
        al = get_logs(addr, APPROVAL)
        json.dump(tl, open(os.path.join(RAW, f"logs_transfer_{name}.json"), "w"))
        json.dump(al, open(os.path.join(RAW, f"logs_approval_{name}.json"), "w"))
        bal = {}
        for e in tl:
            frm = topic_to_addr(e["topics"][1]); to = topic_to_addr(e["topics"][2])
            v = int(e["data"], 16) if e["data"] not in ("0x", "") else 0
            bal[frm] = bal.get(frm, 0) - v
            bal[to] = bal.get(to, 0) + v
        holders = {k: v for k, v in bal.items() if v != 0}
        top = sorted(holders.items(), key=lambda x: -x[1])[:60]
        last_block = max((int(e["blockNumber"], 16) for e in (tl + al)), default=0)
        # latest approval per (owner,spender)
        appr = {}
        for e in al:
            owner = topic_to_addr(e["topics"][1]); spender = topic_to_addr(e["topics"][2])
            key = (owner, spender)
            blk = int(e["blockNumber"], 16); li = int(e["logIndex"], 16)
            if key not in appr or (blk, li) > appr[key][:2]:
                appr[key] = (blk, li, int(e["data"], 16) if e["data"] not in ("0x", "") else 0)
        approvals = [{"owner": o, "spender": s, "value": v[2], "block": v[0]} for (o, s), v in appr.items()]
        approvals.sort(key=lambda x: -x["value"])
        summary[name] = {
            "address": addr, "kind": t["kind"],
            "transfer_events": len(tl), "approval_events": len(al),
            "last_activity_block": last_block,
            "holder_count_nonzero": len(holders),
            "top_holders": [{"addr": a, "raw": str(v)} for a, v in top],
            "approvals_n": len(approvals),
            "top_approvals": [{"owner": a["owner"], "spender": a["spender"], "raw": str(a["value"]), "block": a["block"]} for a in approvals[:80]],
        }
        print(f"  -> {len(tl)} transfers, {len(al)} approvals, {len(holders)} nonzero holders")
        time.sleep(0.5)
    json.dump(summary, open(os.path.join(CENSUS, "holders_summary.json"), "w"), indent=1)
    print("WROTE holders_summary.json")

if __name__ == "__main__":
    run()
