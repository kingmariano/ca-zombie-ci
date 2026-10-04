#!/usr/bin/env python3
"""Aggregate holder census from raw Transfer logs; verify balances via RPC.
Read-only. Outputs census/holders_verified.json and census/holders_<name>.json
"""
import json, os, time, urllib.request, sys

HERE = os.path.dirname(os.path.abspath(__file__))
CENSUS = os.path.dirname(HERE)
RAW = os.path.join(CENSUS, "raw")
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
ZERO = "0x" + "0" * 40

SEL_BALANCE = "0x70a08231"   # balanceOf(address)
SEL_SUPPLY = "0x18160ddd"    # totalSupply()

def rpc_batch(payload, retries=6):
    for i in range(retries):
        try:
            req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                         headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                res = json.loads(r.read())
            if isinstance(res, list): return res
        except Exception as e:
            if i == retries - 1: raise
            time.sleep(2 * (i + 1))
    raise RuntimeError("rpc fail")

def call_many(calls):
    """calls: list of (to, data) -> list results or {'error':..}"""
    out, ID = [], 0
    for i in range(0, len(calls), 20):
        chunk = calls[i:i + 20]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                    "params": [{"to": to, "data": d}, "latest"]} for j, (to, d) in enumerate(chunk)]
        res = rpc_batch(payload)
        by = {r.get("id"): r for r in res}
        for j in range(len(chunk)):
            r = by.get(j, {})
            out.append(r.get("result") if "error" not in r else {"error": r.get("error")})
        ID += 1
        time.sleep(0.2)
    return out

def get_code(addrs):
    out = []
    for i in range(0, len(addrs), 20):
        chunk = addrs[i:i + 20]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_getCode", "params": [a, "latest"]}
                   for j, a in enumerate(chunk)]
        res = rpc_batch(payload)
        by = {r.get("id"): r for r in res}
        for j in range(len(chunk)):
            c = by.get(j, {}).get("result", "0x")
            out.append(c)
        time.sleep(0.2)
    return out

def get_block():
    res = rpc_batch([{"jsonrpc": "2.0", "id": 0, "method": "eth_blockNumber", "params": []}])
    return int(res[0]["result"], 16)

def addr_topic(addr):
    return "0x" + "0" * 24 + addr[2:].lower()

def main():
    block = get_block()
    print("block:", block)
    result = {"block": block, "tokens": {}}
    for name, addr in TARGETS.items():
        f = os.path.join(RAW, f"logs_transfer_{name}.json")
        if not os.path.exists(f):
            print("MISSING", f); continue
        logs = json.load(open(f))
        bal = {}
        n_events = len(logs)
        for e in logs:
            try:
                frm = "0x" + e["topics"][1][-40:].lower()
                to = "0x" + e["topics"][2][-40:].lower()
                v = int(e["data"], 16) if e["data"] not in ("0x", "") else 0
            except Exception:
                continue
            bal[frm] = bal.get(frm, 0) - v
            bal[to] = bal.get(to, 0) + v
        holders = {k: v for k, v in bal.items() if v > 0}
        supply_hex = call_many([(addr, SEL_SUPPLY)])[0]
        supply = int(supply_hex, 16) if isinstance(supply_hex, str) else None
        log_sum = sum(holders.values())
        # verify top 60 via balanceOf
        top = sorted(holders.items(), key=lambda x: -x[1])[:80]
        calls = [(addr, SEL_BALANCE + addr_topic(a)) for a, _ in top]
        res = call_many(calls) if calls else []
        verified = []
        for (a, v), r in zip(top, res):
            rb = int(r, 16) if isinstance(r, str) else None
            verified.append({"addr": a, "from_logs": str(v), "balanceOf": str(rb) if rb is not None else None,
                             "match": rb == v})
        bad = [x for x in verified if not x["match"]]
        # codesize for top 80 + any address with large balance
        codes = get_code([a for a, _ in top])
        for x, c in zip(verified, codes):
            x["code_size"] = (len(c) - 2) // 2
            x["is_contract"] = len(c) > 2
        result["tokens"][name] = {
            "address": addr, "transfer_events": n_events,
            "log_sum": str(log_sum), "totalSupply": str(supply) if supply is not None else None,
            "sum_matches_supply": log_sum == supply,
            "nonzero_holders_logs": len(holders),
            "top": verified,
            "mismatches": len(bad),
        }
        print(f"[{name}] holders={len(holders)} sum_match={log_sum == supply} mismatches={len(bad)} "
              f"top1={top[0][0]} {top[0][1]}")
        json.dump({"address": addr, "holders": {k: str(v) for k, v in sorted(holders.items(), key=lambda x: -x[1])}},
                  open(os.path.join(CENSUS, f"holders_{name}.json"), "w"), indent=1)
    json.dump(result, open(os.path.join(CENSUS, "holders_verified.json"), "w"), indent=1)
    print("WROTE holders_verified.json")

if __name__ == "__main__":
    main()
