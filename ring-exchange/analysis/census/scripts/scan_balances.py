#!/usr/bin/env python3
"""Incremental, resumable holder census via Etherscan V2 logs (chain 999).
Tiny state: running balance map + next window. Safe against process restarts and
repeated runs; ~2 MB state per target. Read-only.

Usage: python3 scan_balances.py [target ...]
"""
import json, os, time, urllib.request, urllib.parse, sys

HERE = os.path.dirname(os.path.abspath(__file__))
CENSUS = os.path.dirname(HERE)
STATE = os.path.join(CENSUS, "state")
os.makedirs(STATE, exist_ok=True)

KEY = os.environ["ETHERSCANV2_API_KEY"]
BASE = "https://api.etherscan.io/v2/api"
TRANSFER = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
APPROVAL = "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
RPC = "https://rpc.hyperliquid.xyz/evm"

TARGETS = {
    "fwWHYPE": "0x9e1148bC3665a9f7C35F313d89c0432c34928AEf",
    "fwUETH":  "0x0C47cbbEDE5d8c6f9614cF770C26c3315205C397",
    "fwUSDC":  "0xd2646b9B02859416D8cBc759F85f0676f6E19974",
    "fwUSDT0": "0x7576dd9a2775bFd789616d9eA7A2af21d06782D0",
    "fwUSDH":  "0x09D21E89EF332347eb3E1E496f1265a600e364C1",
    "pair1_LP_fwUETH_fwWHYPE":  "0x0185E8e8B7FDf22638ecB2D781b3EA7E8AA2452a",
    "pair2_LP_fwUSDH_fwUSDC":   "0xabEd9A9aDe03a80ED98f903Eb9db62DE55C9DDF3",
    "pair3_LP_fwUSDH_fwUSDT0":  "0xf37f1e83BEb55F1b88AF9A8Df1a746e79C222150",
    "pair4_LP_fwUSDT0_fwUSDC":  "0x8868a630dD13A954D3f8B186508EF6c733BE959F",
    "pair5_LP_fwUSDT0_fwWHYPE": "0xf3760B19f1Baa2bFcf6Bd6e5d174e129c80aeD17",
}
WIN = 2_000_000
TIME_LIMIT = float(os.environ.get("TIME_LIMIT", "240"))
CALLS = 0

def rpc_block():
    payload = [{"jsonrpc": "2.0", "id": 0, "method": "eth_blockNumber", "params": []}]
    for i in range(5):
        try:
            req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                         headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=30) as r:
                return int(json.loads(r.read())[0]["result"], 16)
        except Exception:
            time.sleep(2 * (i + 1))
    raise RuntimeError("rpc down")

def es(params, tries=7):
    global CALLS
    CALLS += 1
    q = {"chainid": 999, "apikey": KEY, **params}
    url = BASE + "?" + urllib.parse.urlencode(q)
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "research/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.loads(r.read())
        except Exception as e:
            time.sleep(2 * (attempt + 1)); continue
        if d.get("status") == "1" or d.get("message") == "No records found":
            return d
        msg = str(d.get("result", ""))[:160]
        if "rate limit" in msg.lower() or "max calls" in msg.lower() or d.get("status") == "":
            time.sleep(2.3 * (attempt + 1)); continue
        print("  api:", msg, file=sys.stderr)
        return d
    return {"status": "0", "result": None}

def get_page(addr, topic0, frm, to, page):
    d = es({"module": "logs", "action": "getLogs", "address": addr, "topic0": topic0,
            "fromBlock": frm, "toBlock": to, "page": page, "offset": 1000})
    r = d.get("result")
    return r if isinstance(r, list) else []

def fetch_range(addr, topic0, frm, to, depth=0):
    """All logs in [frm,to], splitting on the 10-page (10k) cap."""
    logs = []
    for page in range(1, 11):
        res = get_page(addr, topic0, frm, to, page)
        if not res: return logs
        logs += res
        if len(res) < 1000: return logs
    # saturated after 10 pages
    if to - frm <= 60000 or depth >= 5:
        print(f"  !! capped window {frm}-{to} d{depth} n={len(logs)}", file=sys.stderr)
        return logs
    logs = []
    step = (to - frm + 1) // 5 + 1
    for i in range(5):
        sf = frm + i * step
        st = min(to, sf + step - 1)
        if sf > to: break
        logs += fetch_range(addr, topic0, sf, st, depth + 1)
    return logs

def norm(e):
    try:
        return (int(e["blockNumber"], 16), int(e.get("logIndex") or "0x0", 16))
    except Exception:
        return (10**18, 0)

def load_state(name, topic):
    p = os.path.join(STATE, f"{name}_{topic}.json")
    if os.path.exists(p):
        return json.load(open(p))
    return None

def save_state(name, topic, st):
    p = os.path.join(STATE, f"{name}_{topic}.json")
    tmp = p + ".tmp"
    json.dump(st, open(tmp, "w"))
    os.replace(tmp, p)

def scan_transfers(name, addr, t0):
    st = load_state(name, "transfer")
    if st is None:
        st = {"target_block": rpc_block(), "next_block": 0, "balances": {}, "events": 0, "windows_done": 0}
    T = st["target_block"]
    while st["next_block"] <= T:
        frm = st["next_block"]; to = min(T, frm + WIN - 1)
        logs = fetch_range(addr, TRANSFER, frm, to)
        bal = st["balances"]
        for e in logs:
            try:
                f = "0x" + e["topics"][1][-40:].lower(); t = "0x" + e["topics"][2][-40:].lower()
                v = int(e["data"], 16) if e["data"] not in ("0x", "") else 0
            except Exception:
                continue
            if v == 0: continue
            bal[f] = bal.get(f, 0) - v
            bal[t] = bal.get(t, 0) + v
        st["events"] += len(logs)
        st["next_block"] = to + 1
        st["windows_done"] += 1
        save_state(name, "transfer", st)
        print(f"    {name} win {frm}-{to}: +{len(logs)} (total {st['events']})", flush=True)
        if time.time() - t0 > TIME_LIMIT:
            print(f"  PAUSED {name} at block {st['next_block']}", flush=True)
            return False
    st["complete"] = True; save_state(name, "transfer", st)
    print(f"  DONE transfers {name}: {st['events']} events, target block {T}", flush=True)
    return True

def scan_approvals(name, addr, t0):
    st = load_state(name, "approval")
    if st is None:
        st = {"target_block": rpc_block(), "next_block": 0, "latest": {}, "events": 0, "windows_done": 0}
    T = st["target_block"]
    while st["next_block"] <= T:
        frm = st["next_block"]; to = min(T, frm + WIN - 1)
        logs = fetch_range(addr, APPROVAL, frm, to)
        for e in logs:
            try:
                o = "0x" + e["topics"][1][-40:].lower(); s = "0x" + e["topics"][2][-40:].lower()
                v = int(e["data"], 16) if e["data"] not in ("0x", "") else 0
                bn, li = norm(e)
            except Exception:
                continue
            k = o + ":" + s
            cur = st["latest"].get(k)
            if cur is None or (bn, li) > (cur["block"], cur["logIndex"]):
                st["latest"][k] = {"owner": o, "spender": s, "value": str(v), "block": bn, "logIndex": li}
        st["events"] += len(logs)
        st["next_block"] = to + 1
        st["windows_done"] += 1
        save_state(name, "approval", st)
        if time.time() - t0 > TIME_LIMIT:
            print(f"  PAUSED approvals {name} at {st['next_block']}", flush=True)
            return False
    st["complete"] = True; save_state(name, "approval", st)
    print(f"  DONE approvals {name}: {st['events']} events", flush=True)
    return True

def main():
    t0 = time.time()
    only = sys.argv[1:] if len(sys.argv) > 1 else None
    for name, addr in TARGETS.items():
        if only and name not in only: continue
        tr = os.path.join(STATE, f"{name}_transfer.json")
        ap = os.path.join(STATE, f"{name}_approval.json")
        tr_done = os.path.exists(tr) and json.load(open(tr)).get("complete")
        ap_done = os.path.exists(ap) and json.load(open(ap)).get("complete")
        if tr_done and ap_done:
            print(f"[{name}] complete, skip", flush=True); continue
        print(f"[{name}] {addr}", flush=True)
        if not tr_done and not scan_transfers(name, addr, t0):
            print("TIME LIMIT - rerun to continue", flush=True); return
        if not ap_done and not scan_approvals(name, addr, t0):
            print("TIME LIMIT - rerun to continue", flush=True); return
    print(f"ALL DONE (etherscan calls {CALLS}, {time.time()-t0:.0f}s)", flush=True)

if __name__ == "__main__":
    main()
