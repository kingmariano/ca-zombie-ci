#!/usr/bin/env python3
"""
C2-50 Vesu V1.1 — consolidate analysis outputs into summary_analysis.json.

Reads (from $CI_OUT or analysis/):
  live_state.json, pools_snapshot.json, positions.jsonl, liquidation_econ.json,
  gate_proofs.json, pools.json
Writes: summary_analysis.json
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
OUTDIR = os.environ.get("CI_OUT") or os.path.join(HERE, "..", "ci-out")
if not os.path.isabs(OUTDIR):
    OUTDIR = os.path.abspath(OUTDIR)

ASSETS = {
    "USDC": "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",
    "USDT": "0x068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8",
    "ETH": "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
    "wBTC": "0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac",
    "STRK": "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
    "wstETH": "0x0057912720381af14b0e5c87aa4718ed5e527eab60b3801ebf702ab09139e38b",
    "wstETH_legacy": "0x042b8f0484674ca266ac5d08e4ac6a3fe65bd3129795def2dca5c34ecc5f96d2",
    "xSTRK": "0x028d709c875c0ceac3dce7065bec5328186dc89fe254527084d1689910954b0a",
    "sSTRK": "0x0356f304b154d29d2a8fe22f1cb9107a9b564a733cf6b4cc47fd121ac1af90c9",
    "rUSDC": "0x02019e47a0bc54ea6b4853c6123ffc8158ea3ae2af4166928b0de6e89f06de6c",
    "EKUBO": "0x075afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87",
    "DOG": "0x040e81cfeb176bfdbc5047bbc55eb471cfab20a6b221f38d8fda134e1bfffca4",
}


def load(name, default=None):
    p = os.path.join(OUTDIR, name)
    if not os.path.exists(p):
        return default
    with open(p) as f:
        if name.endswith(".jsonl"):
            return [json.loads(l) for l in f]
        return json.load(f)


def main():
    state = load("live_state.json", {})
    pools = load("pools_snapshot.json", {})
    positions = load("positions.jsonl", [])
    liq_econ = load("liquidation_econ.json", [])
    gates = load("gate_proofs.json", {})
    pools_meta = load("pools.json", {})

    out = {"block": state.get("block"), "singleton_v11": {}, "balances_usd": {},
           "total_singleton_usd": 0.0, "pools": {}, "positions": {}, "liquidations": {},
           "gates": {}, "verdict": {}}

    # balances + USD
    dec = state.get("decimals", {})
    prices = state.get("prices", {})
    total = 0.0
    for a, bal in state.get("balances", {}).get("V1.1_singleton", {}).items():
        dd = dec.get(a)
        amt = int(bal) / (10 ** dd) if dd is not None else float(bal)
        price = None
        for k, v in prices.items():
            if k == f"starknet:{ASSETS[a]}":
                price = v.get("price")
        usd = amt * price if price else None
        out["balances_usd"][a] = {"amount": amt, "price_usd": price, "usd": usd}
        if usd:
            total += usd
    out["total_singleton_usd"] = round(total, 2)
    out["singleton_v11"] = {
        "owner_raw": state.get("singleton_v11", {}).get("owner"),
        "singleton_v1_raw": state.get("singleton_v11", {}).get("singleton_v1"),
        "upgrade_name_raw": state.get("singleton_v11", {}).get("upgrade_name"),
        "class_hashes": state.get("classes", {}),
        "whitelist": state.get("whitelist", {}),
    }

    # pools
    for pid, p in pools.items():
        meta = pools_meta.get(pid, {})
        out["pools"][pid] = {"extension": meta.get("extension"),
                             "n_assets": len(p.get("assets", {})),
                             "reserves": {a: c["reserve"] for a, c in p.get("assets", {}).items()}}

    # positions
    n = len(positions)
    with_debt = [r for r in positions if int(r.get("debt_value", 0)) > 0]
    under = [r for r in positions if r.get("collateralized") is False and int(r.get("debt_value", 0)) > 0]
    out["positions"] = {"total_checked": n, "with_debt": len(with_debt),
                        "undercollateralized": len(under),
                        "undercollateralized_rows": under[:50]}
    # liquidation economics
    prof = [r for r in liq_econ if int(r.get("profit_usd18", 0)) > 0]
    out["liquidations"] = {
        "undercollateralized_with_debt": len(liq_econ),
        "profitable": len(prof),
        "total_profit_usd18": str(sum(int(r.get("profit_usd18", 0)) for r in prof)),
        "rows": liq_econ,
    }

    # gates
    known = ["no-delegation", "caller-not-extension", "Caller is not the owner",
             "caller-not-singleton-owner", "not-undercollateralized", "u256_sub Overflow",
             "extension-not-whitelisted", "caller-not-migrator"]
    gv = {}
    for k, v in gates.items():
        if k.startswith("_"):
            gv[k] = v
            continue
        if k == "live_liquidation":
            gv[k] = {"revert": (v or {}).get("revert"), "transfers": (v or {}).get("transfers"),
                     "bad_debt": (v or {}).get("bad_debt")}
            continue
        if isinstance(v, dict) and "error" in v:
            gv[k] = "RPC_ERROR: " + json.dumps(v["error"])[:120]
            continue
        verdict = None
        if isinstance(v, list):
            for item in v:
                rr = (item.get("transaction_trace", {}).get("execute_invocation", {}) or {}).get("revert_reason")
                if rr:
                    for kn in known:
                        if kn in rr:
                            verdict = "REVERT: " + kn
                            break
                    if verdict is None:
                        verdict = "REVERT: " + rr[-140:].replace("\n", " ")
                    break
            if verdict is None:
                verdict = "SUCCESS"
        gv[k] = verdict
    out["gates"] = gv

    # verdict
    eu = 0.0
    if prof:
        eu = float(sum(int(r.get("profit_usd18", 0)) for r in prof)) / 1e18
    live = gates.get("live_liquidation") or {}
    out["verdict"] = {
        "E-U_usd": round(eu, 2),
        "E-U_gross_usd": round(eu, 2),
        "E-U_net_usd_est": round(eu - 0.25, 2),  # minus ~gas (2.3 STRK ~ $0.17) and ~0.05% swap (~$0.08)
        "live_liquidation_proven": bool(live.get("transfers")) and not live.get("revert"),
        "note": "E-U = profitable permissionless liquidation(s) proven live by simulateTransactions from a funded external account. "
                "Singleton-held funds are H-O (suppliers/positions) unless a gate fails.",
        "closed_reasons": [
            "assert_ownership on modify_position (collateral out / debt in) -> revert 'no-delegation' (simulated from external account)",
            "transfer_position gated on from-side (collateral out) and to-side (debt in) -> 'no-delegation'",
            "vToken unwrap of extension fee shares blocked by vToken burn (insufficient balance -> 'u256_sub Overflow')",
            "liquidate_position only for undercollateralized positions -> 'not-undercollateralized' on healthy",
            "retrieve_from_reserve extension-gated -> 'caller-not-extension'",
            "set_extension_whitelist / upgrade owner-gated -> 'Caller is not the owner'",
        ],
    }

    p = os.path.join(OUTDIR, "summary_analysis.json")
    with open(p, "w") as f:
        json.dump(out, f, indent=2)
    print(f"[summary] wrote {p}")
    print(f"[summary] V1.1 singleton USD: {out['total_singleton_usd']}")
    print(f"[summary] positions checked {n}, with debt {len(with_debt)}, undercollateralized {len(under)}")
    print(f"[summary] gate verdicts: {json.dumps(gv, indent=1)[:1200]}")


if __name__ == "__main__":
    main()
