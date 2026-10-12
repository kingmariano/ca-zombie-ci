#!/usr/bin/env python3
"""Quote the isxusd / isiron / ispusd meta-pool swaps via cast (public RPC)."""
import subprocess

P = "https://polygon-bor-rpc.publicnode.com"
ISXUSD = "0xe440ccc13e6f273c110cf3cf4087c23a66b8e872"
ISIRON = "0xCaEb732167aF742032D13A9e76881026f91Cd087"
ISPUSD = "0x4a783cd1b4543559ece45db47e07e0cb59e55c09"

def quote(pool, i, j, amount_wei):
    out = subprocess.run(["cast", "call", pool,
        f"calculateSwap(uint8,uint8,uint256)(uint256)", str(i), str(j), str(amount_wei),
        "--rpc-url", P], capture_output=True, text=True)
    t = out.stdout.strip().split()[0]
    return int(t)

LP_USD = 1.0108

print("=== ISXUSD pool: xUSD (idx1) in -> IS3USD LP (idx0) out")
for amt in [1, 5, 10, 25, 50, 100, 200, 400, 800, 2000]:
    dy = quote(ISXUSD, 1, 0, amt * 10**18)
    lp = dy / 1e18
    print(f"  xUSD in {amt:>5} -> LP out {lp:>8.3f} | LP per xUSD {lp/amt:.4f} | gross USD {lp*LP_USD:.2f}")
print("=== ISXUSD pool: LP (idx0) in -> xUSD (idx1) out")
for amt in [1, 5, 10, 25, 100, 400]:
    dy = quote(ISXUSD, 0, 1, amt * 10**18)
    xu = dy / 1e18
    print(f"  LP in {amt:>5} -> xUSD out {xu:>8.3f} | xUSD per LP {xu/amt:.4f}")
print("=== ISIRON pool: IRON (idx1) in -> IS3USD LP (idx0) out")
for amt in [100_000, 500_000, 2_000_000, 5_000_000, 20_000_000]:
    dy = quote(ISIRON, 1, 0, amt * 10**18)
    lp = dy / 1e18
    print(f"  IRON in {amt:>10} -> LP out {lp:>8.3f} | LP per IRON {lp/amt:.7f} | gross USD {lp*LP_USD:.2f}")
print("=== ISPUSD pool: PUSD (idx1) in -> IS3USD LP (idx0) out")
for amt in [50, 100, 500, 2000]:
    dy = quote(ISPUSD, 1, 0, amt * 10**18)
    lp = dy / 1e18
    print(f"  PUSD in {amt:>6} -> LP out {lp:>8.3f} | LP per PUSD {lp/amt:.4f} | gross USD {lp*LP_USD:.2f}")
