#!/usr/bin/env python3
"""Find the last Moonriver block containing transactions (gasUsed>0) and the
first block of Maintenance Mode (2026-08-01T00:00:00Z). Read-only."""
import json
from mr import Rpc

R = Rpc()
HEAD = int(R.head, 16)  # 17381654

# 1) coarse scan backwards for gasUsed>0 transition
samples = list(range(HEAD, HEAD - 120001, -500)) + [HEAD - 120000]
res = R.batch_rpc([("eth_getBlockByNumber", [hex(n), False]) for n in samples], chunk=40)
info = []
for n, b in zip(samples, res):
    if isinstance(b, dict):
        info.append((n, int(b.get("gasUsed", "0x0"), 16), int(b.get("timestamp", "0x0"), 16), len(b.get("transactions", []) or [])))
# find first (highest n) sample with gasUsed>0
last_tx_sample = None
for n, gas, ts, ntx in info:
    if gas > 0:
        last_tx_sample = (n, gas, ts, ntx)
        break
print("first gasUsed>0 sample scanning down:", last_tx_sample)
# find the adjacent empty sample (just above it)
above = None
for i, (n, gas, ts, ntx) in enumerate(info):
    if last_tx_sample and n == last_tx_sample[0] and i > 0:
        above = info[i - 1]
print("sample above (empty):", above)

# 2) binary search between above (empty) and last_tx_sample (nonempty)
lo = above[0]      # empty
hi = last_tx_sample[0]  # nonempty
while hi - lo > 1:
    mid = (lo + hi) // 2
    b = R.block(hex(mid))
    gas = int(b.get("gasUsed", "0x0"), 16)
    if gas > 0:
        hi = mid
    else:
        lo = mid
last_tx_block = hi
b = R.block(hex(last_tx_block))
first_empty = lo
be = R.block(hex(first_empty))
out = {
    "head": HEAD,
    "last_tx_block": last_tx_block,
    "last_tx_block_gasUsed": b.get("gasUsed"),
    "last_tx_block_timestamp": b.get("timestamp"),
    "last_tx_block_n_tx": len(b.get("transactions", []) or []),
    "last_tx_block_hash": b.get("hash"),
    "first_empty_block": first_empty,
    "first_empty_timestamp": be.get("timestamp"),
}
print(json.dumps(out, indent=2))

# 3) first block with timestamp >= 2026-08-01T00:00:00Z (maintenance mode start)
import datetime
MAINT = int(datetime.datetime(2026, 8, 1, tzinfo=datetime.timezone.utc).timestamp())
# estimate: head ts - maint ts = seconds; /12s blocks
hts = int(b.get("timestamp", "0x0"), 16)
est = HEAD - (hts - MAINT) // 12
print("maint ts:", MAINT, "estimate block:", est)
lo2, hi2 = est - 3000, est + 3000
# ensure range brackets
bl = R.block(hex(lo2)); bh = R.block(hex(hi2))
print("lo ts", int(bl.get("timestamp"), 16), "hi ts", int(bh.get("timestamp"), 16))
while hi2 - lo2 > 1:
    mid = (lo2 + hi2) // 2
    bm = R.block(hex(mid))
    ts = int(bm.get("timestamp", "0x0"), 16)
    if ts >= MAINT:
        hi2 = mid
    else:
        lo2 = mid
print("first block with ts>=maint:", hi2)
bm = R.block(hex(hi2))
print("  ts:", int(bm.get("timestamp"), 16), "gasUsed:", bm.get("gasUsed"), "nTx:", len(bm.get("transactions", []) or []))
# sample 5 blocks after maintenance start to check emptiness
res2 = R.batch_rpc([("eth_getBlockByNumber", [hex(hi2 + k), False]) for k in (1, 10, 100, 1000, 10000, 60000)])
print("sampled gasUsed after maintenance start:", [int(x.get("gasUsed", "0x0"), 16) for x in res2 if isinstance(x, dict)])
json.dump({"last_tx": out, "maintenance_start_block": hi2,
           "maintenance_start_ts": int(bm.get("timestamp"), 16),
           "sampled_gas_after": [int(x.get("gasUsed", "0x0"), 16) for x in res2 if isinstance(x, dict)]},
          open("halt_blocks.json", "w"), indent=2)
