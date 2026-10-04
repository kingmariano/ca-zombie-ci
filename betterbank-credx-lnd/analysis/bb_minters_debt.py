#!/usr/bin/env python3
"""BetterBank: favor-token minters, Aave debt state, treasury balances (read-only)."""
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
def toaddr(i):
    return None if i is None else "0x" + hex(i)[2:].rjust(40, '0')

BLOCK = int(rpc(URL, "eth_blockNumber", []), 16)
print("block", BLOCK)
FAVORS = {"PDAIF":"0xbc91e5ae4ce07d0455834d52a9a4df992e12fe12","PLSF":"0x30be72a397667fdfd641e3e5bd68db657711eb20","PLSXF":"0x47c3038ad52e06b9b4aca6d672ff9ff39b126806"}
ESTEEM = "0xdbb8fd196e804d05bb8047dd3e91a9245b7819a7"
PROTO = {
 "MintRedeemer":"0x6bbc91c980780c393e9dac11ec58684191de611d",
 "Wrapper":"0x9361841a51bd90999fac8382abecf976273141f7",
 "FavorTreasuryPDAIF":"0x9aea2185b4cc1a8fd5034112bf8429b13932af2c",
 "FavorTreasuryPLSF":"0x9361799b70fee9618d308190a8bf4b9fb63fc743",
 "FavorTreasuryPLSXF":"0xd333e60789622bab2d448aaa18c06537fd65e3b5",
 "StakingPDAIF":"0x42e8ea9cfd8eaabb35e82322609ebd55bddb1f22",
 "StakingPLSF":"0xd5c451660a5db203a143b6dd0a97e0112329aa8a",
 "StakingPLSXF":"0xd809e3b3b939e79354e005e5ff1807830f1e0f3c",
 "LPZapper1":"0x26b7eb39bd506dfaaaa9f08d405f86764de6d3d5",
 "LPZapper2":"0x59e7374f4c8bb8e73b9ac671655dc2d2bb73a648",
 "deployer":"0xc0702ae0374f83fc3ba71ce2b30a323b09ec19da",
 "team":"0x1EA35487AE62322F61f4C0F639a598d9eEB2F340",
 "holding":"0x6831f815963FfCe95521271b94164eb4C82e7621",
 "pool":"0xdB2c92c63e0320511a278673F0dBF8c3ACa7C5Ee",
}
calls=[]; labels=[]
for fn, fa in FAVORS.items():
    for pn, pa in PROTO.items():
        calls.append(("eth_call",[{"to":fa,"data":sel("isMinter(address)")+b32(pa)},"latest"])); labels.append((f"{fn}:isMinter",pn))
for pn, pa in PROTO.items():
    calls.append(("eth_call",[{"to":ESTEEM,"data":sel("isMinter(address)")+b32(pa)},"latest"])); labels.append(("ESTEEM:isMinter",pn))
res=batch(URL,calls)
print("=== minters (isMinter=1)")
for (what,pn),r in zip(labels,res):
    if u(r)==1: print("  ",what,pn,PROTO[pn])
# Aave debt tokens per reserve
POOL="0xdB2c92c63e0320511a278673F0dBF8c3ACa7C5Ee"
RESERVES=["0xa1077a294dde1b09bb078844df40758a5d0f9a27","0x6b175474e89094c44da98b954eedeac495271d0f","0x95b303987a60c71504d99aa1b13b4da07b0790ab","0xdca85efdce177b24de8b17811cec007fe5098586","0xa0126ac1364606bafb150653c7bc9f1af4283dfa","0x24264d580711474526e8f2a8ccb184f6438bb95c","0xb75e32eb2994b9632d16d157c55731d2fc792b17","0x6a7e018d334b8cc9116010d8779cb5b4b0143adc","0xa1cbdc3d9cab3d9259ed18993f3ce224e2f333c9","0xefd766ccb38eaf1dfd701853bfce31359239f305","0xedcb808ddc390844049b1af42c8163e0e5c54405"]
calls=[]; labels=[]
for r in RESERVES:
    calls.append(("eth_call",[{"to":POOL,"data":sel("getReserveData(address)")+b32(r)},"latest"])); labels.append(("reserveData",r))
res=batch(URL,calls)
print("\n=== Aave reserve data (totalAToken, totalStableDebt, totalVariableDebt, liquidityRate, ...)")
out={"block":BLOCK}
for (what,r),rr in zip(labels,res):
    if isinstance(rr,str) and len(rr)>=2+64*10:
        b=bytes.fromhex(rr[2:])
        # Aave V3 Pool getReserveData returns (uint256 totalAToken? actually struct: configuration, liquidityIndex, currentLiquidityRate, variableBorrowIndex, currentVariableBorrowRate, currentStableBorrowRate, lastUpdateTimestamp, id, aTokenAddress, stableDebtTokenAddress, variableDebtTokenAddress, interestRateStrategyAddress, accruedToTreasury, unbacked, isolationModeTotalDebt)
        words=[int.from_bytes(b[i*32:(i+1)*32],'big') for i in range(len(b)//32)]
        print(f"  {r}")
        print(f"    words[0..14]={words[:15]}")
        if len(words)>=13:
            at="0x"+hex(words[8])[2:].rjust(40,'0') if words[8] else None
            sd="0x"+hex(words[9])[2:].rjust(40,'0') if words[9] else None
            vd="0x"+hex(words[10])[2:].rjust(40,'0') if words[10] else None
            out[r]={"aToken":at,"stableDebt":sd,"variableDebt":vd}
            calls2=[("eth_call",[{"to":at,"data":sel("totalSupply()")},"latest"]),
                    ("eth_call",[{"to":vd,"data":sel("totalSupply()")},"latest"])] if at and vd else []
            if calls2:
                r2=batch(URL,calls2)
                print(f"    aToken.totalSupply={u(r2[0])} variableDebt.totalSupply={u(r2[1])}")
                out[r]["aToken_totalSupply"]=u(r2[0]); out[r]["variableDebt_totalSupply"]=u(r2[1])
json.dump(out, open('/home/heisenberg/CA/betterbank-credx-lnd/analysis/bb_minters_debt.json','w'), indent=1)
print("saved")
