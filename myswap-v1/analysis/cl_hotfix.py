#!/usr/bin/env python3
"""mySwap CL (sibling) hotfix evidence: class replacement after the 2026-06-19 hack.

Read-only. Writes ci-out/cl_hotfix.json.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from starknet_nodep import rpc, call, sel, norm, block_number  # noqa

CL = "0x1114c7103e12c2b2ecbd3a2472ba9c48ddcbf702b1c242dd570057e26212111"
OLD_CLASS = "0x8fade1a36f2bfcaa55b53c96dfb615e8e60110b87765cf449d09b6e0397b17"
NEW_CLASS = "0x40974d74561db5f6c5e66cb50989cfdfc0ec0d1a96b577f85f29695c769a7bd"
HACK_BLOCK = 10951100
UPGRADE_TX = "0xd42015cc38279748eec31ec1559c93fd59234bca6bf10f13a482e606abd0b8"
ADMIN = "0x1dec3416dc353a5b9fa9030016837df7226f2a8767b786fecd3566e8b57d3c8"


def chash(b):
    return rpc("starknet_getClassHashAt", {"block_id": {"block_number": b}, "contract_address": norm(CL)})


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "ci-out", "cl_hotfix.json")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    out = {"cl": CL, "read_only": True, "latest_block": block_number()}

    out["class_at_hack_block"] = chash(HACK_BLOCK)
    out["class_now"] = chash(block_number())

    # find the first block with the new class (binary search)
    lo, hi = HACK_BLOCK, 11000000
    if chash(hi) == NEW_CLASS:
        while hi - lo > 1:
            mid = (lo + hi) // 2
            if chash(mid) == NEW_CLASS:
                hi = mid
            else:
                lo = mid
        out["upgrade_block"] = hi
        out["class_at_upgrade_block_minus1"] = chash(hi - 1)
        try:
            blk = rpc("starknet_getBlockWithTxs", [{"block_number": hi}])
            out["upgrade_block_timestamp"] = blk.get("timestamp")
            up_sel = sel("upgrade")
            for tx in blk.get("transactions", []):
                cd = [str(x) for x in tx.get("calldata", [])]
                if up_sel in cd and norm(CL) in [norm(x) for x in cd if x.startswith("0x") and len(x) > 20]:
                    out["upgrade_tx"] = {
                        "hash": tx.get("transaction_hash"),
                        "sender": tx.get("sender_address"),
                        "calldata": cd[:8],
                    }
                    break
        except Exception as e:
            out["upgrade_block_error"] = str(e)

    # sierra program diff (old vs new)
    try:
        old = rpc("starknet_getClass", {"block_id": "latest", "class_hash": OLD_CLASS})
        new = rpc("starknet_getClass", {"block_id": "latest", "class_hash": NEW_CLASS})
        op, np_ = old.get("sierra_program", []), new.get("sierra_program", [])
        common = 0
        for a, b in zip(op, np_):
            if a == b:
                common += 1
            else:
                break
        out["sierra_program"] = {"old_len": len(op), "new_len": len(np_), "common_prefix": common}
    except Exception as e:
        out["sierra_error"] = str(e)

    for fn in ["owner", "migrator", "get_storage_version"]:
        try:
            out[fn] = call(CL, fn)
        except Exception as e:
            out[fn] = f"ERR {e}"

    with open(out_path, "w") as f:
        json.dump(out, f, indent=1)
    print(json.dumps({k: v for k, v in out.items() if k != "read_only"}, indent=1)[:1500])
    print("wrote", out_path)


if __name__ == "__main__":
    main()
