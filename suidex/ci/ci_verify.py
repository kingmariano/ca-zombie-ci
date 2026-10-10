#!/usr/bin/env python3
"""C2-52 SuiDex CI verification orchestrator (read-only).

Runs the full reproducible battery against live Sui mainnet and writes evidence to SUIDEX_OUT_DIR:
  1. pairs_state.json      (all 54 pairs: reserves, balances, LP supply)
  2. epochs_state.json     (all 35 weekly revenue epochs + SUI vault)
  3. locks_state.json      (all active locks, heavy scan)
  4. claims_keys.json      (all (user,epoch,lock) claim keys, heavy scan)
  5. ho_split.json         (H-O vs S accounting of the remaining vault SUI)
  6. bytecode_check.json   (deployed bytecode identifiers)
  7. reconciliation.json   (deposits == claims + remaining == vault balance; pairs SUI total)
"""
import json, os, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "analysis"))

OUT = os.environ.get("SUIDEX_OUT_DIR", os.path.join(HERE, "..", "ci-out"))
os.makedirs(OUT, exist_ok=True)
os.environ["SUIDEX_OUT_DIR"] = OUT

import dump_pairs, dump_epochs, dump_locks, scan_claim_keys, compute_ho, verify_bytecode  # noqa: E402

t0 = time.time()
print(f"=== [1/7] pairs dump -> {OUT} ===", flush=True)
dump_pairs.main()
print(f"=== [2/7] epochs dump ({time.time()-t0:.0f}s) ===", flush=True)
dump_epochs.main()
print(f"=== [3/7] locks scan ({time.time()-t0:.0f}s) ===", flush=True)
dump_locks.main()
print(f"=== [4/7] claim keys scan ({time.time()-t0:.0f}s) ===", flush=True)
scan_claim_keys.main()
print(f"=== [5/7] H-O split ({time.time()-t0:.0f}s) ===", flush=True)
compute_ho.main()
print(f"=== [6/7] bytecode check ({time.time()-t0:.0f}s) ===", flush=True)
verify_bytecode.main()

print(f"=== [7/7] reconciliation ({time.time()-t0:.0f}s) ===", flush=True)
epochs = json.load(open(os.path.join(OUT, "epochs_state.json")))
pairs = json.load(open(os.path.join(OUT, "pairs_state.json")))
ho = json.load(open(os.path.join(OUT, "ho_split.json")))
vault = epochs["sui_vault"]
sum_rev = sum(int(e["total_sui_revenue"] or 0) for e in epochs["epochs"])
sum_claimed = sum(int(e["claimed"].get(k) or 0) for e in epochs["epochs"]
                  for k in ["week_pool_claimed", "three_month_pool_claimed", "year_pool_claimed", "three_year_pool_claimed"])
sum_alloc = sum(int(e["alloc"].get(k) or 0) for e in epochs["epochs"]
                for k in ["week_pool_sui", "three_month_pool_sui", "year_pool_sui", "three_year_pool_sui"])
# pairs SUI total (SUI side of balance0/balance1)
SUI = "0x2::sui::SUI"
pairs_sui = 0
for p in pairs["pairs"]:
    args = p["type_args"]
    if SUI in args:
        idx = args.index(SUI)
        pairs_sui += int(p["balance0_json"] if idx == 0 else p["balance1_json"])
rec = {
    "sui_vault_balance_mist": int(vault["balance"]),
    "sui_vault_deposited_mist": int(vault["total_deposited"]),
    "sui_vault_distributed_mist": int(vault["total_distributed"]),
    "sum_epoch_revenue_mist": sum_rev,
    "sum_epoch_alloc_mist": sum_alloc,
    "sum_epoch_claimed_mist": sum_claimed,
    "reconcile_deposits_eq_revenue": int(vault["total_deposited"]) == sum_rev,
    "reconcile_distributed_eq_claimed": int(vault["total_distributed"]) == sum_claimed,
    "reconcile_balance_eq_remaining": int(vault["balance"]) == sum_alloc - sum_claimed,
    "ho_mist": ho["ho_mist"],
    "stuck_mist": ho["stuck_mist"],
    "pairs_total_sui_mist": pairs_sui,
    "pairs_with_sui_gt0": sum(1 for p in pairs["pairs"]
                              if SUI in p["type_args"] and int(p["balance0_json"] if p["type_args"].index(SUI) == 0 else p["balance1_json"]) > 0),
    "factory_pairs": pairs["all_pairs_count"],
}
assert rec["reconcile_deposits_eq_revenue"], "deposits != sum revenue"
assert rec["reconcile_distributed_eq_claimed"], "distributed != sum claimed"
assert rec["reconcile_balance_eq_remaining"], "vault balance != unclaimed remainder"
json.dump(rec, open(os.path.join(OUT, "reconciliation.json"), "w"), indent=1)
print(json.dumps(rec, indent=1))
print(f"=== DONE ({time.time()-t0:.0f}s) ===")
