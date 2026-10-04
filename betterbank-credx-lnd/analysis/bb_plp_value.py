#!/usr/bin/env python3
"""Value the LP-token reserves of the BetterBank Aave market + find aToken holders."""
import json, sys
sys.path.insert(0, '/home/heisenberg/CA/betterbank-credx-lnd/analysis')
from rpc import rpc, batch
from Crypto.Hash import keccak
URL = "https://rpc.pulsechain.com"
def k(s):
    h = keccak.new(digest_bits=256); h.update(s.encode()); return "0x" + h.hexdigest()
def sel(s): return k(s)[:10]
def u(h):
    if not h or h == '0x': return None
    return int(h, 16)
def sdec(h):
    try:
        b = bytes.fromhex(h[2:]); ln = int.from_bytes(b[32:64],'big'); return b[64:64+ln].decode()
    except Exception: return None
def adec(h):
    return "0x" + h[-40:]

BLOCK = int(rpc(URL, "eth_blockNumber", []), 16)
print("block", BLOCK)
PLPS = [
 "0xdca85efdce177b24de8b17811cec007fe5098586",
 "0xa0126ac1364606bafb150653c7bc9f1af4283dfa",
 "0x24264d580711474526e8f2a8ccb184f6438bb95c",
 "0xb75e32eb2994b9632d16d157c55731d2fc792b17",
 "0x6a7e018d334b8cc9116010d8779cb5b4b0143adc",
 "0xa1cbdc3d9cab3d9259ed18993f3ce224e2f333c9",
 "0xedcb808ddc390844049b1af42c8163e0e5c54405",
]
calls=[]
for p in PLPS:
    calls.append(("eth_call",[{"to":p,"data":sel("token0()")},"latest"]))
    calls.append(("eth_call",[{"to":p,"data":sel("token1()")},"latest"]))
    calls.append(("eth_call",[{"to":p,"data":sel("getReserves()")},"latest"]))
    calls.append(("eth_call",[{"to":p,"data":sel("totalSupply()")},"latest"]))
    calls.append(("eth_call",[{"to":p,"data":sel("factory()")},"latest"]))
res=batch(URL,calls)
out=[]
for i,p in enumerate(PLPS):
    t0=adec(res[i*5]); t1=adec(res[i*5+1])
    rr=res[i*5+2]; r0=int(rr[2:66],16) if rr and rr!='0x' else 0; r1=int(rr[66:130],16) if rr and rr!='0x' else 0
    ts=u(res[i*5+3]); fac=adec(res[i*5+4]) if res[i*5+4] and res[i*5+4]!='0x' else None
    row={"pair":p,"token0":t0,"token1":t1,"reserve0":r0,"reserve1":r1,"lp_totalSupply":ts,"factory":fac}
    out.append(row)
    print(json.dumps(row))
json.dump({"block":BLOCK,"pairs":out}, open('/home/heisenberg/CA/betterbank-credx-lnd/analysis/bb_plp_pairs.json','w'), indent=1)
