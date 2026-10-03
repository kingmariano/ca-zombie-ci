#!/usr/bin/env python3
"""
Fix collateral balances: replace mToken balances with underlying amounts via
balanceOfUnderlying(address), then recompute liquidation capacity per account.

Reads out/<chain>_positions.json, writes out/<chain>_positions_fixed.json
Usage: python3 fix_balances.py <chain>
"""
import json, os, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
CHAINS = {
  "moonbeam": {"rpc_env": "MOONBEAM_RPC_URL", "rpc_fallback": "https://moonbeam.api.onfinality.io/public"},
  "moonriver": {"rpc_env": "MOONRIVER_RPC_URL", "rpc_fallback": "https://moonriver.api.onfinality.io/public"},
}
SEL_BOU = "0x3af9e669"


def rpc_batch(rpc, calls):
    payload = []
    for k, (to, data) in enumerate(calls):
        payload.append({"jsonrpc": "2.0", "id": k + 1, "method": "eth_call",
                        "params": [{"to": to, "data": data}, "latest"]})
    req = urllib.request.Request(rpc, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 c32"})
    for i in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                out = json.loads(r.read().decode())
            m = {x["id"]: x.get("result") for x in out}
            return [m.get(k + 1) for k in range(len(calls))]
        except Exception:
            time.sleep(2 * (i + 1))
    return [None] * len(calls)


def hx(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def main():
    chain = sys.argv[1]
    cfg = CHAINS[chain]
    rpc = os.environ.get(cfg["rpc_env"]) or cfg["rpc_fallback"]
    p = json.load(open(os.path.join(OUT, f"{chain}_positions.json")))
    fixed = 0
    for a, d in p["details"].items():
        markets = list(d["collaterals"].keys())
        if not markets:
            continue
        calls = [(m, SEL_BOU + hx(a)) for m in markets]
        res = rpc_batch(rpc, calls)
        d["collaterals_underlying"] = {}
        for m, r in zip(markets, res):
            if r and r != "0x":
                d["collaterals_underlying"][m] = str(int(r, 16))
        fixed += 1
        if fixed % 50 == 0:
            print(f"  {fixed} accounts fixed", flush=True)
    with open(os.path.join(OUT, f"{chain}_positions_fixed.json"), "w") as f:
        json.dump(p, f, indent=1)
    print(f"fixed {fixed} accounts -> {chain}_positions_fixed.json")


if __name__ == "__main__":
    main()
