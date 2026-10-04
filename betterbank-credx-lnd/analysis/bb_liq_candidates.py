#!/usr/bin/env python3
"""BetterBank liquidation candidates: exact collateral/debt per account + profitability."""
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
POOL = "0xdB2c92c63e0320511a278673F0dBF8c3ACa7C5Ee"
ORACLE = "0xe4eaad63b27af9e04d059136fd0f3c791c7e2bf8"
RESERVES = ["0xa1077a294dde1b09bb078844df40758a5d0f9a27","0x6b175474e89094c44da98b954eedeac495271d0f","0x95b303987a60c71504d99aa1b13b4da07b0790ab","0xdca85efdce177b24de8b17811cec007fe5098586","0xa0126ac1364606bafb150653c7bc9f1af4283dfa","0x24264d580711474526e8f2a8ccb184f6438bb95c","0xb75e32eb2994b9632d16d157c55731d2fc792b17","0x6a7e018d334b8cc9116010d8779cb5b4b0143adc","0xa1cbdc3d9cab3d9259ed18993f3ce224e2f333c9","0xefd766ccb38eaf1dfd701853bfce31359239f305","0xedcb808ddc390844049b1af42c8163e0e5c54405"]
ATOKENS = ["0x1124DF53E5405AE1f0F0c05973Dd9f8f5eaB7125","0xE527c42823fDd389b8A0f3aFBAF50Eff094e560b","0x3E661918baA75E64FB5c7e2Ef29ab79AdFEEaD83","0xE51C682e2b6Bb3cDEFab9E809e9B52b306624C7c","0xeD6cfd41888475F373dFee53aEAD5F2123C76e0A","0xA7561ac1c68d93b3143595028545A9575c01116c","0xb2235cE3B6D55E8bc089b799e4B8Db1A8A1659Ea","0x29601fB5C87bE0fCE1A4438DF1d8992EC47c24d2","0xca23D03Fa0F62906e1079bfC641aB849391AF16E","0xC20104e249786880988d70b7CEB66599b1C21203","0x9603E53129233d3767Af6C735c15166AD1aacc0d"]
USERS = ["0x281c0f611ddaa6f5db41ad7a1026c2f452b90822","0x9517c8c1159db9296dabe557d40b0b55eeae6c93","0xb123a367e2c783a814719abbcddfd8016daa2bed","0x7d1a292d3947c858233dc714e5cb79637c0ab77f"]
out = {"block": BLOCK, "users": {}}
for user in USERS:
    rr = rpc(URL, "eth_call", [{"to": POOL, "data": sel("getUserConfiguration(address)") + b32(user)}, "latest"])
    data = u(rr)
    coll = [i for i in range(128) if data & (1 << (2*i+1))]
    borr = [i for i in range(128) if data & (1 << (2*i))]
    print(f"\n{user}: collateral reserves {coll}, debt reserves {borr}")
    calls = []
    for i in coll:
        calls.append(("eth_call", [{"to": ATOKENS[i], "data": sel("balanceOf(address)") + b32(user)}, "latest"]))
    for i in borr:
        # variable debt balance via vd token
        calls.append(("eth_call", [{"to": POOL, "data": sel("getUserAccountData(address)") + b32(user)}, "latest"]))
    # get vd token addresses from saved json
    vd = json.load(open('analysis/bb_minters_debt.json'))
    vdtoks = {r: v['variableDebt'] for r, v in vd.items() if isinstance(v, dict)}
    for i in borr:
        calls.append(("eth_call", [{"to": vdtoks[RESERVES[i]], "data": sel("balanceOf(address)") + b32(user)}, "latest"]))
    res = batch(URL, calls)
    uout = {"collateral": [], "debt": [], "coll_res": coll, "borr_res": borr}
    idx = 0
    for i in coll:
        bal = u(res[idx]); idx += 1
        uout["collateral"].append({"reserve": RESERVES[i], "atoken": ATOKENS[i], "balance": bal})
        print(f"   COLL {RESERVES[i]} balance={bal}")
    acc = u(res[idx]); idx += 1
    for i in borr:
        bal = u(res[idx]); idx += 1
        uout["debt"].append({"reserve": RESERVES[i], "vd": vdtoks[RESERVES[i]], "balance": bal})
        print(f"   DEBT {RESERVES[i]} balance={bal}")
    out["users"][user] = uout
json.dump(out, open('analysis/bb_liquidation_candidates.json', 'w'), indent=1)
print("saved")
