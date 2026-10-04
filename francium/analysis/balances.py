#!/usr/bin/env python3
"""Fetch and summarize token balances of all Francium-controlled vault accounts (read-only)."""
import json, sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpc import batch

OUT = os.path.dirname(os.path.abspath(__file__))

def chunk(lst, n):
    for i in range(0, len(lst), n):
        yield lst[i:i+n]

def get_accounts(addrs):
    res = {}
    for c in chunk(addrs, 100):
        out = batch([("getMultipleAccounts", [c, {"encoding": "jsonParsed"}])])[0]
        vals = out["value"] if isinstance(out, dict) and "value" in out else out
        for a, v in zip(c, vals):
            res[a] = v
    return res

def main():
    strategies = json.load(open(os.path.join(OUT, "strategies.json")))
    lend = json.load(open(os.path.join(OUT, "lend_state.json")))
    farms = json.load(open(os.path.join(OUT, "farms.json")))

    roles = {}  # addr -> list of roles
    def add(addr, role):
        if not addr or addr == "11111111111111111111111111111111":
            return
        roles.setdefault(addr, []).append(role)

    for kind, arr in strategies.items():
        for x in arr:
            tag = f'{kind}:{x["strategy"][:8]}'
            if kind == "raydium":
                for f in ["tknAccount0", "tknAccount1", "lpAccount", "rewardAccount", "rewardAccountB",
                          "feeAccount", "strategyLendingCreditAccount0", "strategyLendingCreditAccount1",
                          "platformRewardsTknAccount", "stakePoolTkn"]:
                    add(x.get(f), f"{tag}:{f}")
            else:
                for f in ["tknAccount0", "tknAccount1", "lpTknAccount", "rewardsTknAccount", "farmTknAccount",
                          "strategyLendingCreditAccount0", "strategyLendingCreditAccount1",
                          "franciumRewardsTknAccount", "doubleDipStrategyRewardsTknAccount",
                          "doubleDipFarmTknAccount"]:
                    add(x.get(f), f"{tag}:{f}")

    for r in lend["reserves"]:
        tag = f'reserve:{r["reserve"][:8]}:{r["liquidityMintPubkey"][:6]}'
        for f in ["liquiditySupplyPubkey", "liquidityFeeReceiver", "shareSupplyPubkey", "creditSupplyPubkey"]:
            add(r.get(f), f"{tag}:{f}")

    for x in farms:
        tag = f'farm:{x["farm"][:8]}'
        for f in ["staked_token_account", "rewards_token_account", "rewards_token_account_b"]:
            add(x.get(f), f"{tag}:{f}")

    addrs = sorted(roles.keys())
    print(f"total distinct vault/token accounts: {len(addrs)}")
    accts = get_accounts(addrs)
    json.dump({"roles": roles, "accounts": accts}, open(os.path.join(OUT, "balances_raw.json"), "w"), indent=1)

    # summarize
    rows = []
    mints = {}
    for a in addrs:
        v = accts.get(a)
        if not v:
            rows.append({"account": a, "exists": False, "roles": roles[a]})
            continue
        if v.get("owner") == "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA":
            d = v["data"]
            if isinstance(d, dict) and d.get("parsed", {}).get("type") == "account":
                info = d["parsed"]["info"]
                rows.append({"account": a, "exists": True, "mint": info["mint"], "owner_wallet": info["owner"],
                             "amount": int(info["tokenAmount"]["amount"]), "decimals": info["tokenAmount"]["decimals"],
                             "ui": info["tokenAmount"].get("uiAmountString"), "roles": roles[a]})
                mints[info["mint"]] = info["tokenAmount"]["decimals"]
            else:
                rows.append({"account": a, "exists": True, "nonToken": True, "roles": roles[a]})
        else:
            rows.append({"account": a, "exists": True, "owner": v.get("owner"), "nonToken": True, "roles": roles[a]})

    json.dump({"rows": rows, "mints": mints}, open(os.path.join(OUT, "balances.json"), "w"), indent=1)
    nz = [r for r in rows if r.get("amount")]
    print(f"token accounts: {len([r for r in rows if r.get('mint')])}, nonzero: {len(nz)}, missing: {len([r for r in rows if not r.get('exists')])}")
    # aggregate by mint
    agg = {}
    for r in nz:
        agg.setdefault(r["mint"], {"amount": 0, "decimals": r["decimals"], "accounts": 0, "roles": []})
        agg[r["mint"]]["amount"] += r["amount"]
        agg[r["mint"]]["accounts"] += 1
        agg[r["mint"]]["roles"].extend(r["roles"])
    print("=" * 100)
    for m, v in sorted(agg.items(), key=lambda x: -x[1]["amount"]):
        print(f'{m} dec={v["decimals"]} total_raw={v["amount"]} accounts={v["accounts"]}')

if __name__ == "__main__":
    main()
