#!/usr/bin/env python3
"""Detail liquidatable users: per-reserve collateral/debt, optimal liquidation plan + profit."""
import json, os, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
RPCS = {
    "optimism":  "https://mainnet.optimism.io",
    "metis":     "https://metis-rpc.publicnode.com",
    "arbitrum":  "https://arb1.arbitrum.io/rpc",
    "avalanche": "https://avalanche-c-chain-rpc.publicnode.com",
    "bsc":       "https://bsc-rpc.publicnode.com",
    "ethereum":  "https://ethereum-rpc.publicnode.com",
    "base":      "https://base-rpc.publicnode.com",
}
_id = [0]
def _post(url, payload, timeout=40):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "granary-audit/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())
def batch(url, calls, chunk=10, retries=2):
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i+chunk]
        payload = []
        for m, p in part:
            _id[0] += 1
            payload.append({"jsonrpc": "2.0", "id": _id[0], "method": m, "params": p})
        got = None
        for a in range(retries):
            try:
                res = _post(url, payload)
                byid = {r.get("id"): r for r in res}
                got = [byid.get(c["id"], {}).get("result") for c in payload]
                break
            except Exception as e:
                if a == retries - 1: got = [None]*len(part)
                else: time.sleep(0.7*(a+1))
        out.extend(got)
        time.sleep(0.05)
    return out

def detail(chain, users=None, topn=20):
    rpc = RPCS[chain]
    st = json.load(open(os.path.join(HERE, f"state-{chain}.json")))
    bl = json.load(open(os.path.join(HERE, f"borrowers-{chain}.json")))
    pool = st["pool"]
    reserves = [r for r in st["reserves"] if isinstance(r, dict) and "config" in r]
    if users is None:
        liq = sorted(bl["liquidatable"].items(), key=lambda kv: -kv[1]["totalDebtBase"])
        users = [u for u, a in liq[:topn]]
    print(f"[{chain}] detailing {len(users)} users")
    out = []
    for usr in users:
        # user configuration bitmap + per-reserve balances
        calls = [("eth_call", [{"to": pool, "data": "0x4417a583" + usr[2:].rjust(64, "0")}, "latest"])]
        for r in reserves:
            calls.append(("eth_call", [{"to": r["aToken"], "data": "0x70a08231" + usr[2:].rjust(64, "0")}, "latest"]))
            calls.append(("eth_call", [{"to": r["variableDebtToken"], "data": "0x70a08231" + usr[2:].rjust(64, "0")}, "latest"]))
            calls.append(("eth_call", [{"to": r["stableDebtToken"], "data": "0x70a08231" + usr[2:].rjust(64, "0")}, "latest"]))
        res = batch(rpc, calls, chunk=10)
        cfgdata = int(res[0], 16) if isinstance(res[0], str) and res[0] != "0x" else 0
        rows = []
        k = 1
        for i, r in enumerate(reserves):
            ab = int(res[k], 16) if isinstance(res[k], str) and res[k] != "0x" else 0
            vd = int(res[k+1], 16) if isinstance(res[k+1], str) and res[k+1] != "0x" else 0
            sd = int(res[k+2], 16) if isinstance(res[k+2], str) and res[k+2] != "0x" else 0
            k += 3
            dec = r.get("assetDecimals") or 18
            price = (r.get("oraclePrice") or 0) / 1e8
            coll_bit = bool(cfgdata & (1 << (2 * i + 1)))
            borrow_bit = bool(cfgdata & (1 << (2 * i)))
            row = {
                "symbol": r.get("assetSymbol"), "asset": r["asset"], "reserveId": i,
                "aTokenBal": ab, "stableDebt": sd, "variableDebt": vd,
                "aTokenBal_tokens": ab / 10**dec, "variableDebt_tokens": vd / 10**dec,
                "collateral_enabled": coll_bit, "borrow_bit": borrow_bit,
                "price": price,
                "collateral_usd": round(ab / 10**dec * price, 2),
                "debt_usd": round((vd + sd) / 10**dec * price, 2),
                "bonus": r["config"]["liq_bonus"], "lt": r["config"]["liq_threshold"],
            }
            if row["aTokenBal"] or row["variableDebt"] or row["stableDebt"]:
                rows.append(row)
        acct = bl["account"].get(usr, {})
        d = {"user": usr, "acct": acct, "rows": rows}
        out.append(d)
        print(f"== {usr} HF={acct.get('healthFactor',0)/1e18:.4f} coll=${acct.get('totalCollateralBase',0)/1e8:,.2f} debt=${acct.get('totalDebtBase',0)/1e8:,.2f}")
        for row in rows:
            print(f"   {str(row['symbol']):>8} coll={row['aTokenBal_tokens']:.6f} (${row['collateral_usd']:,.2f}) used={row['collateral_enabled']} debt={row['variableDebt_tokens']:.6f} (${row['debt_usd']:,.2f}) bonus={row['bonus']} lt={row['lt']}")
        # optimal plan
        debts = [r for r in rows if r["debt_usd"] > 0]
        colls = [r for r in rows if r["collateral_usd"] > 0 and r["collateral_enabled"]]
        if debts and colls:
            best = None
            for dbt in debts:
                for c in colls:
                    bonus = c["bonus"] / 1e4
                    repay = dbt["debt_usd"]              # close factor 1 when HF<0.95
                    seize = repay * bonus
                    if seize > c["collateral_usd"]:
                        seize = c["collateral_usd"]
                        repay = seize / bonus
                    profit = seize - repay
                    plan = {"debt_asset": dbt["symbol"], "coll_asset": c["symbol"], "repay_usd": round(repay, 2),
                            "seize_usd": round(seize, 2), "profit_usd": round(profit, 2), "bonus": c["bonus"]}
                    if best is None or plan["profit_usd"] > best["profit_usd"]:
                        best = plan
            d["best_plan"] = best
            print(f"   BEST: repay ${best['repay_usd']:,.2f} {best['debt_asset']} -> seize ${best['seize_usd']:,.2f} {best['coll_asset']} (bonus {best['bonus']}) profit=${best['profit_usd']:,.2f}")
        # full-repay option across all debts (if enough collateral)
    json.dump(out, open(os.path.join(HERE, f"liq-detail-{chain}.json"), "w"), indent=1)
    print(f"saved liq-detail-{chain}.json")

if __name__ == "__main__":
    chain = sys.argv[1]
    users = sys.argv[2:] or None
    detail(chain, users)
