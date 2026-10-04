#!/usr/bin/env python3
"""BetterBank: reserve configs + account health for top aToken holders (read-only)."""
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
RESERVES = ["0xa1077a294dde1b09bb078844df40758a5d0f9a27","0x6b175474e89094c44da98b954eedeac495271d0f","0x95b303987a60c71504d99aa1b13b4da07b0790ab","0xdca85efdce177b24de8b17811cec007fe5098586","0xa0126ac1364606bafb150653c7bc9f1af4283dfa","0x24264d580711474526e8f2a8ccb184f6438bb95c","0xb75e32eb2994b9632d16d157c55731d2fc792b17","0x6a7e018d334b8cc9116010d8779cb5b4b0143adc","0xa1cbdc3d9cab3d9259ed18993f3ce224e2f333c9","0xefd766ccb38eaf1dfd701853bfce31359239f305","0xedcb808ddc390844049b1af42c8163e0e5c54405"]
calls=[]; labels=[]
for r in RESERVES:
    calls.append(("eth_call",[{"to":"0x2369cf50ee0e5727bd971c0d2d172ea6f376edaa","data":sel("getReserveConfigurationData(address)")+b32(r)},"latest"])); labels.append(("cfg",r))
res=batch(URL,calls)
print("=== reserve configs (decimals, ltv, liqThreshold, liqBonus, reserveFactor, usageAsCollateral, borrowingEnabled, stableEnabled, isActive, isFrozen)")
cfg={}
for (what,r),rr in zip(labels,res):
    if isinstance(rr,str) and len(rr)>2:
        b=bytes.fromhex(rr[2:]); w=[int.from_bytes(b[i*32:(i+1)*32],'big') for i in range(len(b)//32)]
        # Aave V3 returns (uint256 decimals, uint256 ltv, uint256 liquidationThreshold, uint256 liquidationBonus, uint256 reserveFactor, bool usageAsCollateralEnabled, bool borrowingEnabled, bool stableBorrowRateEnabled, bool isActive, bool isFrozen)
        cfg[r]=dict(decimals=w[0], ltv=w[1], liqThreshold=w[2], liqBonus=w[3], reserveFactor=w[4], usageAsCollateral=bool(w[5]), borrowing=bool(w[6]), stable=bool(w[7]), isActive=bool(w[8]), isFrozen=bool(w[9]))
        print(" ", r, cfg[r])
json.dump({"block":BLOCK,"configs":cfg}, open('/home/heisenberg/CA/betterbank-credx-lnd/analysis/bb_reserve_configs.json','w'), indent=1)
