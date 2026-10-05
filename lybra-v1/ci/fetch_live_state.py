#!/usr/bin/env python3
"""C2-03 CI job: refresh live Lybra V1 state at the CI tip (read-only).

Writes:
  ci-out/live_state_latest.json   - block, price, totals, all borrowers, underwater set,
                                    extraction model, Curve eUSD quotes, recent liquidations
  ci-out/live_state_summary.txt   - human-readable summary
Env: FORK_RPC_URL or RPC_URL (falls back to publicnode). Never prints secrets.
"""
import json, os, sys, time, urllib.request, urllib.parse, datetime

RPC = os.environ.get("FORK_RPC_URL") or os.environ.get("RPC_URL") or "https://ethereum-rpc.publicnode.com"
ETHERSCAN_KEY = os.environ.get("ETHERSCANV2_API_KEY", "")
LYBRA = "0x97de57eC338AB5d51557DA3434828C5DbFaDA371"
PRICE_FEED = "0x4c517D4e2C851CA76d7eC94B805269Df0f2201De"
CURVE = "0x880F2fB3704f1875361DE6ee59629c6c6497a5E3"
WAD = 10**18
SEL_DEP = "0x482ed2a2"    # depositedEther(address)
SEL_BOR = "0x05ad8308"    # getBorrowedOf(address)
SEL_BAL = "0x70a08231"    # balanceOf(address)
SEL_PRICE = "0x0fdb11cf"  # fetchPrice()
SEL_GETDY = "0x556d6e9f"  # get_dy(uint256,uint256,uint256)
SEL_TOTAL_DEP = "0x9b4d51f4"   # totalDepositedEther()
SEL_TOTAL_EUSD = "0x733346e5"  # totalEUSDCirculation()
LIQ_TOPIC = "0xb59dc9737d55b75fc6ca7522e82d6161da5d7c8337b9ab990a5846f95b5ccdad"

def _sig(name):
    import subprocess
    return subprocess.run(["cast", "sig", name], capture_output=True, text=True).stdout.strip()

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps(
        {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "zombie-ci/1.0"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read()).get("result")
        except Exception as e:
            print(f"  rpc retry {attempt}: {e}", file=sys.stderr)
            time.sleep(2 + attempt * 3)
    raise RuntimeError("rpc failed: " + method)

def batch(calls, block):
    payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                "params": [{"to": to, "data": data}, block]} for i, (to, data) in enumerate(calls)]
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "zombie-ci/1.0"})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                res = json.loads(r.read())
            return {it["id"]: it.get("result") for it in res}
        except Exception as e:
            print(f"  batch retry {attempt}: {e}", file=sys.stderr)
            time.sleep(2 + attempt * 3)
    raise RuntimeError("batch failed")

def addr_word(a):
    return "0" * 24 + a[2:].lower()

def recent_liquidations(blocks_back=20000):
    """Fetch the last LiquidationRecord events via Etherscan (best effort)."""
    if not ETHERSCAN_KEY:
        return []
    try:
        tip = int(rpc("eth_blockNumber", []), 16)
        params = {"chainid": "1", "module": "logs", "action": "getLogs", "address": LYBRA,
                  "fromBlock": str(tip - blocks_back), "toBlock": "latest",
                  "topic0": LIQ_TOPIC, "page": "1", "offset": "1000", "apikey": ETHERSCAN_KEY}
        url = "https://api.etherscan.io/v2/api?" + urllib.parse.urlencode(params)
        with urllib.request.urlopen(url, timeout=60) as r:
            d = json.loads(r.read())
        out = []
        for e in (d.get("result") or []):
            w = [e["data"][2:][i:i+64] for i in range(0, len(e["data"]) - 2, 64)]
            out.append({"block": int(e["blockNumber"], 16), "tx": e["transactionHash"],
                        "victim": "0x" + e["topics"][1][-40:],
                        "provider": "0x" + w[0][-40:], "keeper": "0x" + w[1][-40:],
                        "eusd": int(w[2], 16) / WAD, "eth_seized": int(w[3], 16) / WAD,
                        "super": int(w[5], 16) == 1, "ts": int(w[6], 16)})
        return out[-25:]
    except Exception as e:
        print("  liquidation fetch failed:", e, file=sys.stderr)
        return []

def main():
    sel_total_eusd = SEL_TOTAL_EUSD
    blk = int(rpc("eth_blockNumber", []), 16)
    block = hex(blk)
    price = int(rpc("eth_call", [{"to": PRICE_FEED, "data": SEL_PRICE}, block]), 16)
    total_dep = int(rpc("eth_call", [{"to": LYBRA, "data": SEL_TOTAL_DEP}, block]), 16)
    total_eusd = int(rpc("eth_call", [{"to": LYBRA, "data": sel_total_eusd}, block]), 16)

    users = json.load(open("analysis/borrowers.json"))
    print(f"block {blk}: price=${price/WAD:,.2f} totalDep={total_dep/WAD:,.4f} totalEUSD={total_eusd/WAD:,.2f} users={len(users)}", flush=True)

    positions = {}
    B = 60
    for start in range(0, len(users), B):
        chunk = users[start:start+B]
        calls, meta = [], []
        for u in chunk:
            calls.append((LYBRA, SEL_DEP + addr_word(u))); meta.append((u, "dep"))
            calls.append((LYBRA, SEL_BOR + addr_word(u))); meta.append((u, "bor"))
            calls.append((LYBRA, SEL_BAL + addr_word(u))); meta.append((u, "eusd"))
        out = batch(calls, block)
        for i, (u, kind) in enumerate(meta):
            r = out.get(i)
            positions.setdefault(u, {})[kind] = int(r, 16) if r and r != "0x" else 0
        if (start // B) % 4 == 0:
            print(f"  {min(start+B,len(users))}/{len(users)}", flush=True)

    quotes = {}
    for usdc_in in [50_000_000, 100_000_000, 500_000_000, 2_809_428_304]:
        data = SEL_GETDY + "0"*63 + "1" + "0"*63 + "0" + format(usdc_in, "064x")
        r = rpc("eth_call", [{"to": CURVE, "data": data}, block])
        eusd_out = int(r, 16)
        quotes[usdc_in] = {"usdc_in": usdc_in / 1e6, "eusd_out": eusd_out / WAD,
                           "eff_price": (usdc_in / 1e6) / (eusd_out / WAD) if eusd_out else None}

    underwater = []
    for u, d in positions.items():
        if d["bor"] == 0:
            continue
        cr = d["dep"] * price * 100 // d["bor"]
        if cr < 150 * WAD:
            underwater.append({"user": u, "dep": d["dep"] / WAD, "bor": d["bor"] / WAD,
                               "cr_pct": cr / 1e18, "eusd_bal": d["eusd"] / WAD})
    underwater.sort(key=lambda x: x["cr_pct"])

    def simulate(C, D):
        te = tx = rounds = 0
        while D > 0:
            if C * price * 100 // D >= 150 * WAD:
                break
            e = min(D * WAD // price, C // 2)
            if e == 0:
                break
            x = e * price // WAD
            if x == 0 or x > D:
                break
            C -= e * 11 // 10
            D -= x
            te += e
            tx += x
            rounds += 1
        return te, tx, rounds

    tot_e = tot_x = 0
    for r in underwater:
        e, x, _ = simulate(int(r["dep"] * WAD), int(r["bor"] * WAD))
        tot_e += e
        tot_x += x

    result = {
        "block": blk,
        "timestamp_utc": datetime.datetime.utcnow().isoformat() + "Z",
        "price_usd": price / WAD,
        "total_deposited_steth": total_dep / WAD,
        "total_eusd_circulation": total_eusd / WAD,
        "global_cr_pct": (total_dep * price * 100 / total_eusd) / 1e18,
        "n_borrowers": len([1 for d in positions.values() if d["bor"] > 0]),
        "n_underwater": len(underwater),
        "underwater": underwater,
        "multiround": {"eusd_deployed": tot_x / WAD, "steth_seized": tot_e / WAD,
                       "gross_bonus_steth": tot_e / WAD / 10,
                       "gross_bonus_usd": tot_e / WAD / 10 * price / WAD},
        "curve_eusd_quotes_usdc_to_eusd": quotes,
        "recent_liquidations": recent_liquidations(),
        "all_positions": {u: {"dep": d["dep"] / WAD, "bor": d["bor"] / WAD} for u, d in positions.items()},
        "note": "gross_bonus is protocol bonus in oracle terms; fresh-attacker net cash ~0 (see README)",
    }
    os.makedirs("ci-out", exist_ok=True)
    json.dump(result, open("ci-out/live_state_latest.json", "w"), indent=1)

    with open("ci-out/live_state_summary.txt", "w") as f:
        f.write(f"Lybra V1 live state @ block {blk} ({result['timestamp_utc']})\n")
        f.write(f"price=${price/WAD:,.2f} totalCollateral={total_dep/WAD:,.4f} stETH totalDebt={total_eusd/WAD:,.2f} eUSD globalCR={result['global_cr_pct']:.2f}%\n")
        f.write(f"borrowers with debt: {result['n_borrowers']}  underwater(<150%): {len(underwater)}\n")
        for r in underwater:
            f.write(f"  {r['user']} CR={r['cr_pct']:.2f}% coll={r['dep']:.6f} stETH debt={r['bor']:,.2f} eUSD\n")
        f.write(f"multi-round gross bonus: {tot_e/WAD/10:.5f} stETH (${tot_e/WAD/10*price/WAD:,.2f}), eUSD deployed {tot_x/WAD:,.2f}\n")
        for k, v in quotes.items():
            f.write(f"curve USDC->eUSD {v['usdc_in']:,.2f} -> {v['eusd_out']:.4f} eUSD (eff ${v['eff_price']:.4f}/eUSD)\n")
        for l in result["recent_liquidations"][-10:]:
            f.write(f"  liq blk {l['block']} victim={l['victim']} provider={l['provider']} eusd={l['eusd']:.2f} eth={l['eth_seized']:.4f}\n")
    print("wrote ci-out/live_state_latest.json and ci-out/live_state_summary.txt")
    print(open("ci-out/live_state_summary.txt").read())

if __name__ == "__main__":
    main()
