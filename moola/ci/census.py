#!/usr/bin/env python3
"""CI census for C2-17 (Moola, Celo) — recompute the live extractable value from
liquidations of currently under-collateralised accounts, at the CI-run block.

Stdlib only. Read-only (eth_call/eth_blockNumber). Writes ci-out/liquidation_census.json.
"""
import json, os, sys, time, urllib.request

RPC = os.environ.get("CELO_RPC_URL", "https://forno.celo.org")
RPC_FALLBACKS = ["https://forno.celo.org", "https://celo-rpc.publicnode.com", "https://celo.drpc.org"]
POOL = "0x970b12522CA9b4054807a2c5B736149a5BE6f670"

RESERVES = {
    "CELO":  ("0x471EcE3750Da237f93B8E339c536989b8978a438",
              "0x7D00cd74FF385c955EA3d79e47BF06bD7386387D",
              "0xAF451D23d6f0FA680113CE2D27a891Aa3587f0C3",
              "0x02661dd90c6243Fe5cdF88De3E8cb74BcC3bD25E", 10500),
    "cUSD":  ("0x765DE816845861e75A25fCA122bb6898B8B1282a",
              "0x918146359264C492BD6934071c6Bd31C854EDBc3",
              "0xf602D9617564C07f1e128687798D8C699cED3961",
              None, 10500),
    "cEUR":  ("0xD8763CBa276a3738E6DE85b4b3bF5FDed6D6cA73",
              "0xE273Ad7ee11dCfAA87383aD5977EE1504aC07568",
              "0xfb6c830c13D8322b31b282Ef1Fe85cbb669d9aE8",
              "0x612599D8421F36b7dA4dDBA201a3854FF55e3d03", 11000),
    "cREAL": ("0xe8537a3d056DA446677B9E9d6c5dB704EaAb4787",
              "0x9802d866fdE4563d088a6619F7CeF82C0B991A55",
              "0xbd408042909351B649DC50353532dEeF6De9fAA9",
              None, 11000),
    "MOO":   ("0x17700282592D6917F6A73D0bF8AcCf4D578c131e",
              "0x3A5024E3AAB31A1d3184127B52b0e4B4E9ADcC34",
              "0x3d6d8A1562ff973aD89887C0a5c001f42Ad66CB8",
              "0x0bb14E95a4FF117F7f536D605E2B506e937619C4", 11000),
}
ORACLE = "0xBa2224905Ad3CDbA6c1b764CD62FDa52bd524d29"
RESERVE_PCT = 200  # treasury cut (bps) in LendingPoolCollateralManagerWithReserve

def selector(sig):
    return {
        "balanceOf(address)": "0x70a08231",
        "getUserAccountData(address)": "0xbf92857c",
        "getAssetPrice(address)": "0xb3596f07",
    }[sig]

SEL = {s: selector(s) for s in [
    "balanceOf(address)", "getUserAccountData(address)", "getAssetPrice(address)"]}

_id = 0
_rpc_i = 0
BLK = None
def rpc(method, params):
    global _id, _rpc_i
    _id += 1
    urls = [RPC] + [u for u in RPC_FALLBACKS if u != RPC]
    last = None
    for attempt in range(len(urls) * 2):
        url = urls[(_rpc_i + attempt) % len(urls)]
        try:
            req = urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":_id,"method":method,"params":params}).encode(),
                                         headers={"Content-Type":"application/json","User-Agent":"moola-census/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.load(r)
            if "error" in d: raise RuntimeError(d["error"])
            _rpc_i += attempt
            return d["result"]
        except Exception as e:
            last = e
            time.sleep(1.0)
    raise RuntimeError(f"all RPCs failed for {method}: {last}")

def call(to, data, blk=None):
    return rpc("eth_call", [{"to": to, "data": data}, blk or BLK or "latest"])

def enc_addr(a): return a[2:].rjust(64, "0")
def word(h, i): return int.from_bytes(bytes.fromhex(h[2:])[i*32:(i+1)*32], "big")

def main():
    global BLK
    blk = int(rpc("eth_blockNumber", []), 16)
    BLK = hex(blk)
    out = {"block": blk, "rpc": RPC, "positions": [], "total_profit_celo": 0.0}
    # candidate list: embedded from the pinned-block census if available
    cand_paths = ["analysis/liquidations_79583113.json", "ci/liquidations_79583113.json"]
    cands = []
    for p in cand_paths:
        if os.path.exists(p):
            d = json.load(open(p))
            cands = [x["addr"] for x in d.get("profitable_liquidations", []) if x.get("profit_celo", 0) > 0.01]
            break
    if not cands:
        print("WARNING: no candidate list found; falling back to empty census")
    print(f"block {blk}: checking {len(cands)} pinned-block under-collateralised accounts")

    prices = {}
    for name, (asset, aTok, vDebt, sDebt, bonus) in RESERVES.items():
        prices[name] = word(call(ORACLE, SEL["getAssetPrice(address)"] + enc_addr(asset)), 0) / 1e18

    total = 0.0
    checked = 0
    for i, addr in enumerate(cands):
        h = call(POOL, SEL["getUserAccountData(address)"] + enc_addr(addr))
        coll = word(h, 0) / 1e18; debt = word(h, 1) / 1e18; hf = word(h, 5) / 1e18
        if debt <= 0 or hf >= 1.0:
            continue
        checked += 1
        balances = {}
        for name, (asset, aTok, vDebt, sDebt, bonus) in RESERVES.items():
            a = word(call(aTok, SEL["balanceOf(address)"] + enc_addr(addr)), 0) / 1e18
            v = word(call(vDebt, SEL["balanceOf(address)"] + enc_addr(addr)), 0) / 1e18
            s = 0.0
            if sDebt:
                s = word(call(sDebt, SEL["balanceOf(address)"] + enc_addr(addr)), 0) / 1e18
            balances[name] = {"coll": a, "debt": v + s, "bonus": bonus}
        best = 0.0; best_pair = None
        for cn, cb in balances.items():
            if cb["coll"] <= 0: continue
            for dn, db in balances.items():
                if db["debt"] <= 0: continue
                cp, dp = prices[cn], prices[dn]
                adj = cb["bonus"] + RESERVE_PCT
                max_repay = db["debt"] * 0.5
                max_coll = dp * max_repay * adj / (cp * 10000)
                if max_coll > cb["coll"]:
                    seized = cb["coll"]
                    debt_needed = cp * seized / dp * 10000 / adj
                else:
                    seized = max_coll; debt_needed = max_repay
                proceeds = seized * cp * cb["bonus"] / adj
                profit = proceeds - debt_needed * dp
                if profit > best:
                    best = profit; best_pair = [cn, dn]
        if best > 0:
            total += best
            out["positions"].append({"addr": addr, "hf": hf, "profit_celo": best, "pair": best_pair})
        if i % 25 == 0:
            print(f"  {i}/{len(cands)} checked={checked} running_total={total:.6f} CELO", flush=True)
        time.sleep(0.02)
    out["total_profit_celo"] = total
    out["total_profit_usd_at_0_0895"] = total * 0.08948743769432425
    # net of gas: ~600k gas per liquidation at the current gas price
    gas_price = int(rpc("eth_gasPrice", []), 16)
    gas_per_liq = 600000 * gas_price / 1e18
    net = sum(max(p["profit_celo"] - gas_per_liq, 0) for p in out["positions"])
    out["gas_price_wei"] = gas_price
    out["gas_per_liquidation_celo"] = gas_per_liq
    out["total_net_celo"] = net
    out["total_net_usd_at_0_0895"] = net * 0.08948743769432425
    out["net_positive_positions"] = sum(1 for p in out["positions"] if p["profit_celo"] > gas_per_liq)
    os.makedirs("ci-out", exist_ok=True)
    json.dump(out, open("ci-out/liquidation_census.json", "w"), indent=1)
    print(f"\nTOTAL liquidatable profit at block {blk}: {total:.6f} CELO "
          f"(~${total*0.08948743769432425:.4f}); profitable positions: {len(out['positions'])}")
    print(f"gas price {gas_price/1e9:.1f} gwei -> gas/liquidation {gas_per_liq:.5f} CELO; "
          f"NET total {net:.6f} CELO (~${net*0.08948743769432425:.4f}) over "
          f"{out['net_positive_positions']} net-positive positions")

if __name__ == "__main__":
    main()
