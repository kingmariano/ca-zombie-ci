#!/usr/bin/env python3
"""Aggregate scLINK events -> candidate addresses, net borrow/repay, net mint/redeem.
Compound v2 events carry NO indexed params; all fields are in data."""
import json
from collections import defaultdict

path = "/home/heisenberg/CA/scream/analysis/sclink_logs.jsonl"

net_borrow = defaultdict(int)
net_repay = defaultdict(int)
net_mint = defaultdict(int)
net_redeem = defaultdict(int)
liq = []
counts = defaultdict(int)
last_block = {}
first_block = {}

def w2a(w):
    return "0x" + w[-40:]

for line in open(path):
    lg = json.loads(line)
    t = lg["topic"]
    counts[t] += 1
    data = lg["data"][2:]
    words = [data[i:i+64] for i in range(0, len(data), 64)]
    blk = int(lg["blockNumber"], 16)
    if t == "Borrow":
        a = w2a(words[0])
        net_borrow[a] += int(words[1], 16)
        last_block[a] = max(last_block.get(a, 0), blk)
        first_block[a] = min(first_block.get(a, 1 << 62), blk)
    elif t == "RepayBorrow":
        b = w2a(words[1])
        net_repay[b] += int(words[2], 16)
        last_block[b] = max(last_block.get(b, 0), blk)
    elif t == "LiquidateBorrow":
        liquidator = w2a(words[0])
        borrower = w2a(words[1])
        repay = int(words[2], 16)
        coll = w2a(words[3])
        seize = int(words[4], 16)
        liq.append((blk, liquidator, borrower, coll, repay, seize))
        net_repay[borrower] += repay
        last_block[borrower] = max(last_block.get(borrower, 0), blk)
    elif t == "Mint":
        a = w2a(words[0])
        net_mint[a] += int(words[2], 16)
    elif t == "Redeem":
        a = w2a(words[0])
        net_redeem[a] += int(words[2], 16)

print("counts:", dict(counts))
print("unique borrowers:", len(net_borrow))
print("unique minters:", len(net_mint))
print("unique redeemers:", len(net_redeem))
print("liquidations:", len(liq))

print("\n== borrowers with net debt > 0 (borrowed - repaid > 0):")
cands = []
for a in set(net_borrow) | set(net_repay):
    nb, nr = net_borrow.get(a, 0), net_repay.get(a, 0)
    if nb - nr > 0:
        cands.append((nb - nr, a, nb, nr, last_block.get(a, 0), first_block.get(a, 0)))
for d, a, nb, nr, lb, fb in sorted(cands, reverse=True):
    print(f"{a} net={d/1e18:.6f} borrowed={nb/1e18:.6f} repaid={nr/1e18:.6f} first={fb} last={lb}")
print("total candidate net:", sum(x[0] for x in cands)/1e18)

print("\n== holders with net mint > redeem (cToken units, 8dec):")
h = []
for a in set(net_mint) | set(net_redeem):
    nm, nr = net_mint.get(a, 0), net_redeem.get(a, 0)
    if nm - nr > 0:
        h.append((nm - nr, a, nm, nr))
for d, a, nm, nr in sorted(h, reverse=True)[:40]:
    print(f"{a} net_ctokens={d/1e8:.4f} minted={nm/1e8:.4f} redeemed={nr/1e8:.4f}")
print("total net minted (top):", sum(x[0] for x in h)/1e8)

print("\n== last liquidations (last 10):")
for b, l, bo, c, r, s in liq[-10:]:
    print(f"blk={b} liq={l} borrower={bo} coll={c} repay={r/1e18:.4f} seize={s/1e8:.4f}")

json.dump({
    "borrowers": [{"addr": a, "net": d, "first": fb, "last": lb} for d, a, _, _, lb, fb in cands],
    "holders": [{"addr": a, "net_ctokens": d} for d, a, _, _ in h],
    "liquidations": [{"block": b, "liquidator": l, "borrower": bo, "collateral": c, "repay": r, "seize": s} for b, l, bo, c, r, s in liq],
}, open("/home/heisenberg/CA/scream/analysis/sclink_actors.json", "w"), indent=2)
