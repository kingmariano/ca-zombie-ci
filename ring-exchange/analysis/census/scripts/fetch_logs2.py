#!/usr/bin/env python3
"""Holder census v2 — Etherscan V2 logs on chain 999 with block-window pagination.
Etherscan caps getLogs pagination at ~10k records per (address,topic0) query, so we
split by block windows and recurse when a window is saturated. Read-only.
"""
import json, os, time, urllib.request, urllib.parse, sys

HERE = os.path.dirname(os.path.abspath(__file__))
CENSUS = os.path.dirname(HERE)
RAW = os.path.join(CENSUS, "raw")
WC = os.path.join(RAW, "window_cache")
os.makedirs(WC, exist_ok=True)

KEY = os.environ["ETHERSCANV2_API_KEY"]
BASE = "https://api.etherscan.io/v2/api"
TRANSFER = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
APPROVAL = "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
RPC = "https://rpc.hyperliquid.xyz/evm"

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

CALLS = [0]

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())["result"]

def es(params, tries=8):
    CALLS[0] += 1
    q = {"chainid": 999, "apikey": KEY, **params}
    url = BASE + "?" + urllib.parse.urlencode(q)
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "research/1.0"})
            with urllib.request.urlopen(req, timeout=90) as r:
                d = json.loads(r.read())
        except Exception as e:
            print("  net err:", e, file=sys.stderr); time.sleep(2 * (attempt + 1)); continue
        if d.get("status") == "1" or d.get("message") == "No records found":
            return d
        msg = str(d.get("result", ""))[:200]
        if "rate limit" in msg.lower() or "max calls" in msg.lower() or d.get("status") == "":
            time.sleep(2.5 * (attempt + 1)); continue
        print("  api msg:", msg, file=sys.stderr)
        return d
    print("  RETRY EXHAUSTED", file=sys.stderr)
    return {"status": "0", "result": None}

def get_page(addr, topic0, frm, to, page):
    d = es({"module": "logs", "action": "getLogs", "address": addr, "topic0": topic0,
            "fromBlock": frm, "toBlock": to, "page": page, "offset": 1000})
    res = d.get("result")
    return res if isinstance(res, list) else []


def fetch_window(addr, topic0, frm, to, depth=0):
    """Fetch all logs in [frm,to] handling the 10-page cap by recursive splitting."""
    tag = f"{addr[-8:]}_{topic0[2:10]}_{frm}_{to}"
    cf = os.path.join(WC, tag + ".json")
    if os.path.exists(cf):
        try:
            d = json.load(open(cf))
            if d.get("complete"): return d["logs"]
        except Exception: pass
    logs, page = [], 1
    saturated = False
    while page <= 10:
        res = get_page(addr, topic0, frm, to, page)
        if not res: break
        logs += res
        log_txt = f"    win[{frm}-{to}] d{depth} p{page}: {len(res)}"
        print(log_txt, flush=True)
        if len(res) < 1000: break
        page += 1
    else:
        saturated = True
    if saturated:
        if depth >= 6 or (to - frm) <= 50000:
            print(f"    !! TRUNCATION RISK window {frm}-{to} depth {depth} ({len(logs)} logs)", flush=True)
            json.dump({"complete": False, "logs": logs}, open(cf, "w"))
            return logs
        # drop partial result and split into 5 sub-windows
        logs = []
        step = (to - frm + 1) // 5 + 1
        for i in range(5):
            sf = frm + i * step
            st = min(to, sf + step - 1)
            if sf > to: break
            logs += fetch_window(addr, topic0, sf, st, depth + 1)
            time.sleep(0.3)
    json.dump({"complete": True, "logs": logs}, open(cf, "w"))
    return logs

def fetch_all(addr, topic0, latest):
    WIN = 2_000_000
    all_logs = []
    frm = 0
    while frm <= latest:
        to = min(latest, frm + WIN - 1)
        all_logs += fetch_window(addr, topic0, frm, to)
        frm = to + 1
        time.sleep(0.25)
    # dedupe
    seen, uniq = set(), []
    for e in all_logs:
        k = (e.get("transactionHash"), e.get("logIndex"))
        if k in seen: continue
        seen.add(k); uniq.append(e)
    uniq.sort(key=lambda e: (int(e["blockNumber"], 16), int(e.get("logIndex", "0x1") or "0x1", 16)))
    return uniq

def main():
    only = set(sys.argv[1:]) if len(sys.argv) > 1 else None
    latest = int(rpc("eth_blockNumber", []), 16)
    print("latest block:", latest, flush=True)
    summary_file = os.path.join(CENSUS, "logs_fetch_summary.json")
    summary = json.load(open(summary_file)) if os.path.exists(summary_file) else {}
    summary["latest_block"] = latest
    summary["generated"] = time.strftime("%Y-%m-%dT%H:%M:%SZ")
    for name, t in TARGETS.items():
        if only and name not in only: continue
        addr = t["addr"]
        tf = os.path.join(RAW, f"logs_transfer_{name}.json")
        af = os.path.join(RAW, f"logs_approval_{name}.json")
        if os.path.exists(tf) and os.path.exists(af):
            print(f"[{name}] already complete, skip", flush=True)
            continue
        print(f"[{name}] {addr}", flush=True)
        tl = fetch_all(addr, TRANSFER, latest)
        json.dump(tl, open(tf, "w"))
        print(f"  transfers: {len(tl)}", flush=True)
        al = fetch_all(addr, APPROVAL, latest)
        json.dump(al, open(af, "w"))
        print(f"  approvals: {len(al)}", flush=True)
        summary[name] = {"address": addr, "kind": t["kind"], "transfer_events": len(tl),
                         "approval_events": len(al),
                         "last_transfer_block": int(tl[-1]["blockNumber"], 16) if tl else 0}
        json.dump(summary, open(summary_file, "w"), indent=1)
    print("ETHERSCAN CALLS:", CALLS[0], flush=True)
    print("DONE", flush=True)

if __name__ == "__main__":
    main()
