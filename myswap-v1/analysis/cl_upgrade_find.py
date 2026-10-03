"""Find exact CL class-upgrade block + tx."""
import json
from starknet_nodep import rpc, norm, sel, block_number

CL = "0x1114c7103e12c2b2ecbd3a2472ba9c48ddcbf702b1c242dd570057e26212111"
NEW = "0x40974d74561db5f6c5e66cb50989cfdfc0ec0d1a96b577f85f29695c769a7bd"

def chash(b):
    return rpc("starknet_getClassHashAt", {"block_id": {"block_number": b}, "contract_address": norm(CL)})

lo, hi = 10951100, 11000000  # lo old, hi new
assert chash(lo) != NEW, chash(lo)
assert chash(hi) == NEW, chash(hi)
while hi - lo > 1:
    mid = (lo + hi) // 2
    if chash(mid) == NEW:
        hi = mid
    else:
        lo = mid
print("upgrade block:", hi, "prev class:", chash(hi - 1))

blk = rpc("starknet_getBlockWithTxs", [{"block_number": hi}])
print("block ts:", blk.get("timestamp"), "n_txs:", len(blk.get("transactions", [])))
up_sel = sel("upgrade")
for tx in blk["transactions"]:
    cd = tx.get("calldata", [])
    if any(str(x).lower().endswith(CL[-20:].lower()) for x in cd) or tx.get("sender_address", "").lower().endswith("1dec3416dc353a5b9fa9030016837df7226f2a8767b786fecd3566e8b57d3c8"):
        print("TX", tx.get("transaction_hash"), "type", tx.get("type"), "sender", tx.get("sender_address"))
        print("  calldata[:12]", cd[:12])
        if up_sel in cd:
            print("  *** contains upgrade selector ***")
