#!/usr/bin/env python3
"""Verify the deployed SuiDex package bytecode carries the critical claim-path identifiers.

Fetches the package object BCS (module map), extracts module bytecode and checks that the
locker module contains the function identifiers audited in source. Writes bytecode_check.json.
"""
import json, sys, os, base64
sys.path.insert(0, os.path.dirname(__file__))
from sui_rpc import rpc

PKG = "0xbfac5e1c6bf6ef29b12f7723857695fd2f4da9a11a7d88162c15e9124c243a4a"
WANTED = ["find_user_lock_any_pool", "claim_pool_sui_rewards", "batch_claim_epochs_for_lock",
          "create_claim_key", "mark_pool_epoch_claimed", "update_epoch_pool_claimed",
          "has_user_claimed_pool_epoch", "admin_sweep_sui_reward_vault", "lock_tokens", "unlock_tokens"]

def main():
    outdir = os.environ.get("SUIDEX_OUT_DIR", os.path.dirname(__file__))
    o = rpc("sui_getObject", [PKG, {"showBcs": True}])
    d = o["data"]
    b = d["bcs"]
    mm = b["moduleMap"]
    out = {"package": PKG, "package_version": d.get("version"), "modules": {}, "checks": {}}
    for name, b64 in mm.items():
        raw = base64.b64decode(b64) if isinstance(b64, str) else base64.b64decode(b64.get("bcsBytes", ""))
        out["modules"][name] = len(raw)
        if name == "victory_token_locker":
            out["checks"] = {w: raw.count(w.encode()) for w in WANTED}
    out["all_present"] = all(v >= 1 for v in out["checks"].values()) and bool(out["checks"])
    with open(os.path.join(outdir, "bytecode_check.json"), "w") as fh:
        json.dump(out, fh, indent=1)
    print(json.dumps(out, indent=1))
    assert out["all_present"], "missing critical identifiers in deployed bytecode"

if __name__ == "__main__":
    main()
