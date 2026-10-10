#!/usr/bin/env python3
"""Refine the last-tx block boundary and find maintenance-mode start block."""
import json, datetime
from mr import Rpc

R = Rpc()
HEAD = int(R.head, 16)  # 17381654
MAINT = int(datetime.datetime(2026, 8, 1, tzinfo=datetime.timezone.utc).timestamp())

# A) refine boundary in [17268154 nonempty, 17268654 empty]
lo, hi = 17268154, 17268654
bl = R.block(hex(lo)); bh = R.block(hex(hi))
print("bracket:", lo, int(bl.get("gasUsed"), 16), int(bl.get("timestamp"), 16),
      "|", hi, int(bh.get("gasUsed"), 16), int(bh.get("timestamp"), 16))
while hi - lo > 1:
    mid = (lo + hi) // 2
    bm = R.block(hex(mid))
    gas = int(bm.get("gasUsed", "0x0"), 16)
    if gas > 0:
        lo = mid
    else:
        hi = mid
last_tx = lo; first_empty = hi
b = R.block(hex(last_tx))
be = R.block(hex(first_empty))
print("LAST_TX_BLOCK:", last_tx, "gasUsed:", b.get("gasUsed"), "nTx:", len(b.get("transactions", []) or []),
      "ts:", int(b.get("timestamp"), 16), datetime.datetime.fromtimestamp(int(b.get("timestamp"), 16), datetime.timezone.utc).isoformat())
print("FIRST_EMPTY:", first_empty, "ts:", datetime.datetime.fromtimestamp(int(be.get("timestamp"), 16), datetime.timezone.utc).isoformat())

# B) first block with ts >= maintenance start: lo=17268654 (ts<maint), hi=HEAD
lo2, hi2 = 17268654, HEAD
while hi2 - lo2 > 1:
    mid = (lo2 + hi2) // 2
    bm = R.block(hex(mid))
    ts = int(bm.get("timestamp", "0x0"), 16)
    if ts >= MAINT:
        hi2 = mid
    else:
        lo2 = mid
bm = R.block(hex(hi2))
print("MAINT_START_BLOCK:", hi2, "ts:", int(bm.get("timestamp"), 16),
      datetime.datetime.fromtimestamp(int(bm.get("timestamp"), 16), datetime.timezone.utc).isoformat(),
      "gasUsed:", bm.get("gasUsed"), "nTx:", len(bm.get("transactions", []) or []))
# sample after maintenance start + a full sweep at 2000-block steps to confirm emptiness
samples = [hi2 + k for k in (1, 100, 1000, 5000, 10000, 20000, 40000, 60000, 67000)]
res = R.batch_rpc([("eth_getBlockByNumber", [hex(n), False]) for n in samples])
gas_after = [(n, int(x.get("gasUsed", "0x0"), 16) if isinstance(x, dict) else None) for n, x in zip(samples, res)]
print("gas after maint start samples:", gas_after)
sweep = list(range(hi2, HEAD, 2000))
res2 = R.batch_rpc([("eth_getBlockByNumber", [hex(n), False]) for n in sweep], chunk=40)
nonempty = [(n, int(x.get("gasUsed", "0x0"), 16)) for n, x in zip(sweep, res2)
            if isinstance(x, dict) and int(x.get("gasUsed", "0x0"), 16) > 0]
print("nonempty blocks in sweep (maint->head):", nonempty[:10], "count:", len(nonempty))

out = {
    "head": HEAD,
    "head_utc": "2026-08-10T08:27:48Z",
    "last_tx_block": last_tx,
    "last_tx_block_ts": int(b.get("timestamp"), 16),
    "last_tx_block_utc": datetime.datetime.fromtimestamp(int(b.get("timestamp"), 16), datetime.timezone.utc).isoformat(),
    "last_tx_block_hash": b.get("hash"),
    "last_tx_block_gasUsed": b.get("gasUsed"),
    "last_tx_block_nTx": len(b.get("transactions", []) or []),
    "first_empty_block": first_empty,
    "first_empty_utc": datetime.datetime.fromtimestamp(int(be.get("timestamp"), 16), datetime.timezone.utc).isoformat(),
    "maintenance_start_block": hi2,
    "maintenance_start_utc": datetime.datetime.fromtimestamp(int(bm.get("timestamp"), 16), datetime.timezone.utc).isoformat(),
    "maintenance_gas_samples": gas_after,
    "nonempty_blocks_maint_to_head": nonempty,
    "sweep_step": 2000,
}
json.dump(out, open("halt_blocks.json", "w"), indent=2)
print("wrote halt_blocks.json")
