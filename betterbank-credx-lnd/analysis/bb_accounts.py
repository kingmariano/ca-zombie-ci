#!/usr/bin/env python3
"""BetterBank: user account data for LP-collateral holders and debtors -> liquidation candidates."""
import json, sys
sys.path.insert(0, '/home/heisenberg/CA/betterbank-credx-lnd/analysis')
from rpc import rpc, batch
from Crypto.Hash import keccak
URL = "https://rpc.pulsechain.com"
def k(s):
    h = keccak.new(digest_bits=256); h.update(s.encode()); return "0x" + h.hexdigest()
def sel(s): return k(s)[:10]
def b32(a): return a[2:].lower().rjust(64, '0')
def u(h):
    if not isinstance(h, str) or h == '0x': return None
    return int(h, 16)
BLOCK = int(rpc(URL, "eth_blockNumber", []), 16)
print("block", BLOCK)
POOL = "0xdB2c92c63e0320511a278673F0dBF8c3ACa7C5Ee"
holders = json.load(open('analysis/bb_atoken_holders_events.json'))
borrowers = json.load(open('analysis/bb_borrowers.json'))
cands = set()
for name, v in holders.items():
    for a in list(v['holders'].keys())[:12]: cands.add(a)
for res, v in borrowers.items():
    for a in list(v['borrowers'].keys())[:12]: cands.add(a)
cands = sorted(cands)
print("candidates:", len(cands))
calls = []
for a in cands:
    calls.append(("eth_call", [{"to": POOL, "data": sel("getUserAccountData(address)") + b32(a)}, "latest"]))
res = batch(URL, calls)
out = {"block": BLOCK, "accounts": {}}
print("\n=== accounts with debt (totalDebtBase>0)")
for a, r in zip(cands, res):
    if isinstance(r, str) and len(r) >= 2 + 64*6:
        b = bytes.fromhex(r[2:])
        w = [int.from_bytes(b[i*32:(i+1)*32], 'big') for i in range(len(b)//32)]
        # (totalCollateralBase, totalDebtBase, availableBorrowsBase, currentLiquidationThreshold, ltv, healthFactor)
        acc = dict(collateral=w[0], debt=w[1], avail=w[2], liqThreshold=w[3], ltv=w[4], hf=w[5])
        if acc['debt'] > 0:
            hf = acc['hf'] / 1e18 if acc['hf'] < 2**200 else float('inf')
            out["accounts"][a] = acc
            print(f"  {a} coll={w[0]} debt={w[1]} thr={w[3]} hf={hf:.6f}")
json.dump(out, open('analysis/bb_accounts.json', 'w'), indent=1)
print("saved", len(out["accounts"]), "accounts with debt")
