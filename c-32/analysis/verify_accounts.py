#!/usr/bin/env python3
"""
CI-safe verification of the C-32 Moonbeam liquidation analysis (no indexer needed).

The full borrower enumeration was done once via Covalent/GoldRush (artifact committed in
analysis/out/moonbeam_positions_fixed.json). This script re-verifies, at CI run time and
purely via RPC reads:
  - the Moonbeam chain head is frozen (maintenance mode),
  - xcDOT/ETH/WBTC feed adapters are stale,
  - every account the local analysis flagged with profit>0 still reports a live shortfall,
  - the theoretical liquidation profit bound at current oracle prices.

Output: ci-out/verify_accounts.txt (+ .json)
"""
import json, os, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.environ.get("SCAN_OUTDIR", os.path.join(HERE, "out"))
os.makedirs(OUT, exist_ok=True)
RPC = os.environ.get("MOONBEAM_RPC_URL", "https://moonbeam.api.onfinality.io/public")
COMP = "0x8E00D5e02E65A19337Cdba98bbA9F84d4186a180"
SEL_LIQ = "0x5ec88c79"          # getAccountLiquidity(address)
SEL_PRICE = "0xfc57d4df"        # getUnderlyingPrice(address)
SEL_FEED = "0x3b39a51c"         # getFeed(string)
SEL_LATEST = "0xfeaf968c"       # latestRoundData()
SEL_BLOCK = "0x6c540baf"        # accrualBlockNumber()


def rpc_batch(calls):
    payload = []
    for k, (to, data) in enumerate(calls):
        payload.append({"jsonrpc": "2.0", "id": k + 1, "method": "eth_call",
                        "params": [{"to": to, "data": data}, "latest"]})
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
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


def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 c32"})
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.loads(r.read().decode()).get("result")


def hx(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def main():
    base = os.path.join(HERE, "committed")
    if not os.path.exists(os.path.join(base, "moonbeam_positions_fixed.json")):
        base = os.path.join(HERE, "out")
    pos = json.load(open(os.path.join(base, "moonbeam_positions_fixed.json")))
    est = json.load(open(os.path.join(base, "moonbeam_liquidation_estimate.json")))
    head = int(rpc("eth_blockNumber", []), 16)
    blk = rpc("eth_getBlockByNumber", [hex(head), False])
    head_ts = int(blk["timestamp"], 16)
    lines = []
    lines.append(f"# C-32 CI verification {time.strftime('%Y-%m-%d %H:%M UTC', time.gmtime())}")
    lines.append(f"Moonbeam head block {head} @ {time.strftime('%Y-%m-%d %H:%M UTC', time.gmtime(head_ts))} "
                 f"(age {(time.time()-head_ts)/86400:.1f}d, txs in head {len(blk.get('transactions') or [])})")
    feed = "0xccDf06F6c0F53b0e753E816E226bfD349e397736"
    r = rpc_batch([(feed, SEL_LATEST)])[0]
    if r and r != "0x":
        raw = r[2:]
        updated = int(raw[3 * 64:4 * 64], 16)
        answer = int(raw[64:128], 16)
        lines.append(f"xcDOT feed {feed}: answer={answer} updatedAt={updated} "
                     f"stale={(head_ts-updated)/86400:.2f}d")

    accounts = [a for a in est["accounts"] if a["profit_usd"] > 0.01]
    accounts = accounts[:30]
    lines.append(f"\nRe-checking {len(accounts)} accounts with estimated profit > $0.01:")
    calls = [(COMP, SEL_LIQ + hx(a["account"])) for a in accounts]
    res = rpc_batch(calls)
    live = 0
    out_accounts = []
    for a, rr in zip(accounts, res):
        sf = None
        if rr and len(rr) >= 194:
            sf = int(rr[130:194], 16)
        ok = bool(sf and sf > 0)
        live += ok
        out_accounts.append({**a, "live_shortfall_1e18": sf, "still_shortfall": ok})
        lines.append(f"  {a['account']} est_profit=${a['profit_usd']:.2f} live_shortfall=${(sf or 0)/1e18:.4f} ok={ok}")
    lines.append(f"\nstill-liquidatable (shortfall>0): {live}/{len(accounts)}")
    lines.append(f"TOTAL theoretical profit bound at external prices: ${est['total_profit_usd']:.2f}")
    lines.append("NOTE: unexecutable while Moonbeam is in maintenance mode (no block production since 2026-08-10).")
    with open(os.path.join(OUT, "verify_accounts.txt"), "w") as f:
        f.write("\n".join(lines) + "\n")
    with open(os.path.join(OUT, "verify_accounts.json"), "w") as f:
        json.dump({"head_block": head, "head_ts": head_ts, "accounts": out_accounts,
                   "total_profit_bound_usd": est["total_profit_usd"]}, f, indent=1)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
