#!/usr/bin/env python3
"""CI heavy job: enumerate ERC20 Approval events with spender = Socket Gateway (Ethereum).
Primary source: eth_getLogs via NODEREAL_ETH_RPC_URL (50k-block windows), fallbacks to
FORK_RPC_URL / RPC_URL, Etherscan V2, then Blockscout. Adaptive window splitting when a
provider errors on range or when a window returns a suspiciously full page. Read-only.
Output: ci-out/socket_approvals_raw.json
Env: NODEREAL_ETH_RPC_URL, FORK_RPC_URL, RPC_URL, ETHERSCANV2_API_KEY (all optional).
"""
import json, os, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "ci-out")
os.makedirs(OUT, exist_ok=True)
KEY = os.environ.get("ETHERSCANV2_API_KEY", "")
UA = {"User-Agent": "zombie-hunt/read-only", "Content-Type": "application/json"}
GW = "0x3a23F943181408EAC424116Af7b7790c94Cb97a5"
DEPLOY = 16_848_303
WINDOW = 49_000
APPROVAL = "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
GW_TOPIC = "0x" + "0" * 24 + GW[2:].lower()
RPC_CANDIDATES = [os.environ.get("NODEREAL_ETH_RPC_URL"), os.environ.get("FORK_RPC_URL"),
                  os.environ.get("RPC_URL"), "https://ethereum-rpc.publicnode.com"]
RPC_CANDIDATES = [u for u in RPC_CANDIDATES if u]
REQ = {"n": 0, "errors": 0}

def rpc_call(rpc_url, method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(rpc_url, data=body, headers=UA)
    REQ["n"] += 1
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            d = json.load(r)
        if "error" in d:
            return None, str(d["error"])[:160]
        return d.get("result"), None
    except Exception as e:
        REQ["errors"] += 1
        return None, str(e)[:120]

def latest_block():
    for u in RPC_CANDIDATES:
        r, e = rpc_call(u, "eth_blockNumber", [])
        if r:
            return int(r, 16)
    raise RuntimeError("no RPC for latest block")

def parse(res):
    out = []
    for e in res:
        out.append({"block": int(e["blockNumber"], 16),
                    "logIndex": int(e["logIndex"], 16) if e.get("logIndex") not in ("0x", "", None) else 0,
                    "tx": e["transactionHash"], "token": e["address"].lower(),
                    "owner": "0x" + e["topics"][1][-40:],
                    "value": int(e["data"], 16) if e.get("data") and e["data"] != "0x" else 0})
    return out

def fetch_rpc_window(start, end):
    """Try each RPC for the window. Returns (events, error)."""
    for u in RPC_CANDIDATES:
        res, err = rpc_call(u, "eth_getLogs", [{"fromBlock": hex(start), "toBlock": hex(end),
                                                "topics": [APPROVAL, None, GW_TOPIC]}])
        if res is not None:
            return parse(res), None
    return None, err or "all rpc failed"

def fetch_etherscan(start, end):
    if not KEY:
        return None
    url = (f"https://api.etherscan.io/v2/api?chainid=1&module=logs&action=getLogs"
           f"&fromBlock={start}&toBlock={end}&topic0={APPROVAL}&topic0_2_opr=and&topic2={GW_TOPIC}"
           f"&page=1&offset=1000&apikey={KEY}")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "zombie-hunt/read-only"})
        REQ["n"] += 1
        with urllib.request.urlopen(req, timeout=45) as r:
            d = json.load(r)
        res = d.get("result")
        if isinstance(res, list):
            return parse(res)
        if REQ["n"] < 20:
            print("  etherscan non-list:", d.get("status"), d.get("message"), str(res)[:100], flush=True)
    except Exception:
        REQ["errors"] += 1
    return None

def scan_window(start, end, depth=0):
    """Returns (events, truncated)."""
    if REQ["n"] > 4000:
        return [], True
    ev, err = fetch_rpc_window(start, end)
    if ev is None:
        es = fetch_etherscan(start, end)
        if es is None:
            if depth < 8 and end - start > 2000:
                mid = (start + end) // 2
                a, ta = scan_window(start, mid, depth + 1)
                b, tb = scan_window(mid + 1, end, depth + 1)
                return a + b, ta or tb
            return [], True
        ev = es
    # If a window looks saturated (provider caps), split.
    if len(ev) >= 9000 and end - start > 2000 and depth < 8:
        mid = (start + end) // 2
        a, ta = scan_window(start, mid, depth + 1)
        b, tb = scan_window(mid + 1, end, depth + 1)
        return a + b, ta or tb
    return ev, False

def main():
    end = latest_block()
    print("scanning blocks", DEPLOY, "->", end, "window", WINDOW, flush=True)
    events, truncated = [], []
    start = DEPLOY
    w = 0
    while start <= end:
        stop = min(start + WINDOW - 1, end)
        ev, tr = scan_window(start, stop)
        events += ev
        if tr:
            truncated.append([start, stop])
        w += 1
        if w % 10 == 0 or tr:
            print(f"window {w} [{start}-{stop}] events={len(ev)} total={len(events)} "
                  f"truncated={tr} requests={REQ['n']} errors={REQ['errors']}", flush=True)
        start = stop + 1
        time.sleep(0.1)
    seen, uniq = set(), []
    for e in events:
        k = (e["tx"], e["logIndex"], e["token"], e["owner"])
        if k in seen:
            continue
        seen.add(k)
        uniq.append(e)
    uniq.sort(key=lambda e: e["block"])
    json.dump({"gateway": GW, "deploy_block": DEPLOY, "latest_block": end,
               "truncated": bool(truncated), "truncated_windows": truncated,
               "requests": REQ["n"], "errors": REQ["errors"], "events": uniq},
              open(os.path.join(OUT, "socket_approvals_raw.json"), "w"))
    print("saved", len(uniq), "approval events; truncated windows:", len(truncated),
          "requests:", REQ["n"], "errors:", REQ["errors"])

if __name__ == "__main__":
    main()
