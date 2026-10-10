"""CI CANDIDATE — enumerate v1 loan/lock accounts per pool (read-only, keyless).

Purpose: quantify the stale-oracle liquidation candidate (see REPORT.md §4/§5).
NOT executed during the sweep (heavy: thousands of indexer account calls).
Run this on CI (or locally with patience); it only READS public endpoints.

Notes / assumptions:
- Pools' local-state accounts = per-user loan apps and Lock&Enter apps (v1 SDK pattern).
- The per-user loan app's *global state* holds the position (keys observed via v1 SDK:
  collateral/borrow pool ids + balances, 'borrowed', 'latest_borrow_interest_index', 'S2' threshold...).
- Frozen v1 oracle prices (2023-02-20) are hardcoded below; live prices come from coins.llama.fi.
- Health/liquidation math should be re-derived from the v1 pool 'l' branch / v1 SDK math.js.
"""
import json
import sys
import time

sys.path.insert(0, "../../scripts")
import algo_lib as A  # noqa: E402

POOLS = {
    686498781: "ALGO", 686500029: "USDC", 686500844: "USDt", 694405065: "goETH", 686501760: "goBTC",
}
FROZEN_ORACLE_2023_02_20 = {"ALGO": 0.28955447, "USDC": 1.00012674, "USDt": 0.99999105}
OUT = "ci-out/v1_loan_accounts.json"


def accounts_for_pool(pool_id, max_pages=50):
    accs, nxt, pages = [], None, 0
    while pages < max_pages:
        q = f"/accounts?application-id={pool_id}&limit=1000"
        if nxt:
            q += f"&next={nxt}"
        d = A.indexer_get(q)
        accs.extend(d.get("accounts", []))
        nxt = d.get("next-token")
        pages += 1
        if not nxt:
            break
        time.sleep(0.2)
    return accs


def main():
    result = {}
    for pool, name in POOLS.items():
        accs = accounts_for_pool(pool)
        rows = []
        for a in accs:
            addr = a.get("address")
            local = None
            for ls in a.get("apps-local-state", []):
                if ls.get("id") == pool:
                    local = {e["key"]: e["value"] for e in ls.get("key-value", [])}
            rows.append({"address": addr, "local_state_raw": local})
        result[str(pool)] = {"pool": name, "count": len(rows), "accounts": rows}
        print(f"pool {pool} ({name}): {len(rows)} accounts", flush=True)
    with open(OUT, "w") as f:
        json.dump(result, f, indent=1)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
