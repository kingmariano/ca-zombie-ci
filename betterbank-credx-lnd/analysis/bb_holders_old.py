#!/usr/bin/env python3
"""Find LP-aToken holders + check old favor tokens + registered wrappers (read-only)."""
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
ATOKENS = {
 "bPlsPLP_0xE51C(PLSF/WPLS)": "0xE51C682e2b6Bb3cDEFab9E809e9B52b306624C7c",
 "bPlsPLP_0xeD6c(PDAIF/DAI)": "0xeD6cfd41888475F373dFee53aEAD5F2123C76e0A",
 "bPlsPLP_0xA756(PLSXF/PLSX)": "0xA7561ac1c68d93b3143595028545A9575c01116c",
 "bPlsPLP_0xb223(oldPLSF/WPLS)": "0xb2235cE3B6D55E8bc089b799e4B8Db1A8A1659Ea",
 "bPlsPLP_0x2960(oldPDAIF/DAI)": "0x29601fB5C87bE0fCE1A4438DF1d8992EC47c24d2",
 "bPlsPLP_0xca23(oldPLSXF/PLSX)": "0xca23D03Fa0F62906e1079bfC641aB849391AF16E",
 "bPlsEDAIFLP_0x9603": "0x9603E53129233d3767Af6C735c15166AD1aacc0d",
}
CAND = {
 "holding": "0x6831f815963FfCe95521271b94164eb4C82e7621",
 "team": "0x1EA35487AE62322F61f4C0F639a598d9eEB2F340",
 "deployer": "0xc0702ae0374f83fc3ba71ce2b30a323b09ec19da",
 "provider_owner": "0x96F80a880A52533FAB2b51Ae4dCA719B2FCeCbD2",
 "staking_owner": "0xfff365215805474cb1fd598926f435d1a5a1ab86",
 "StakingPDAIF": "0x42e8ea9cfd8eaabb35e82322609ebd55bddb1f22",
 "StakingPLSF": "0xd5c451660a5db203a143b6dd0a97e0112329aa8a",
 "StakingPLSXF": "0xd809e3b3b939e79354e005e5ff1807830f1e0f3c",
 "FavorTreasuryPDAIF": "0x9aea2185b4cc1a8fd5034112bf8429b13932af2c",
 "FavorTreasuryPLSF": "0x9361799b70fee9618d308190a8bf4b9fb63fc743",
 "FavorTreasuryPLSXF": "0xd333e60789622bab2d448aaa18c06537fd65e3b5",
 "LPZapper1": "0x26b7eb39bd506dfaaaa9f08d405f86764de6d3d5",
 "LPZapper2": "0x59e7374f4c8bb8e73b9ac671655dc2d2bb73a648",
 "MintRedeemer": "0x6bbc91c980780c393e9dac11ec58684191de611d",
 "Wrapper": "0x9361841a51bd90999fac8382abecf976273141f7",
 "old_token_owner": "0x5e9e3457433b4b767e458abecaf4128eeb3dcc97",
 "pool": "0xdB2c92c63e0320511a278673F0dBF8c3ACa7C5Ee",
 "acl_admin": "0xce04c590344c2bd8e2bfe49a280c1d501dc8c000",
 "zero": "0x" + "00"*20,
}
calls=[]; labels=[]
for an, aa in ATOKENS.items():
    for cn, ca in CAND.items():
        calls.append(("eth_call",[{"to":aa,"data":sel("balanceOf(address)")+b32(ca)},"latest"]))
        labels.append((an,cn))
res=batch(URL,calls)
holders={}
print("\n=== LP aToken holders (non-zero)")
idx=0
for an, aa in ATOKENS.items():
    for cn, ca in CAND.items():
        v=u(res[idx]); idx+=1
        if v:
            print(f"  {an:34s} {cn:18s} {ca} = {v}")
            holders.setdefault(an,{})[cn]={"addr":ca,"amount":v}
json.dump({"block":BLOCK,"holders":holders}, open('/home/heisenberg/CA/betterbank-credx-lnd/analysis/bb_atoken_holders.json','w'), indent=1)

# Old favor tokens state
OLD = {
 "oldPLSF":"0xff98af981c113488b91934e8af779194cc1b53ad",
 "oldPDAIF":"0xc8ccaec1e239c8591cbb8715bd0a43dd4c9cc95a",
 "oldPLSXF":"0xddbe64f89268026027d7823d1141846d546d6bac",
 "EDAIF":"0x2070ea9c18df743b3fdf37485fccc390a3694eb9",
}
calls=[]; labels=[]
for tn, ta in OLD.items():
    for sig in ["owner()","esteem()","esteemMinter()","bonusRate()","treasuryBonusRate()","sellTax()"]:
        calls.append(("eth_call",[{"to":ta,"data":sel(sig)},"latest"])); labels.append((tn,sig))
    for cn, ca in CAND.items():
        calls.append(("eth_call",[{"to":ta,"data":sel("isBuyWrapper(address)")+b32(ca)},"latest"])); labels.append((tn,f"isBuyWrapper:{cn}"))
    calls.append(("eth_call",[{"to":ta,"data":sel("isMinter(address)")+b32(CAND["MintRedeemer"])},"latest"])); labels.append((tn,"isMinter:MintRedeemer"))
    calls.append(("eth_call",[{"to":ta,"data":sel("isMinter(address)")+b32(CAND["Wrapper"])},"latest"])); labels.append((tn,"isMinter:Wrapper"))
res=batch(URL,calls)
oldout={}
print("\n=== old favor tokens")
for (tn,sig),r in zip(labels,res):
    v=u(r)
    if sig in ("owner()","esteem()","esteemMinter()"):
        v="0x"+hex(v)[2:].rjust(40,'0') if v else None
    oldout[f"{tn}:{sig}"]=v
    if v and (sig in ("owner()","esteem()","esteemMinter()","bonusRate()","treasuryBonusRate()","sellTax()") or sig.startswith("isBuyWrapper")):
        print(f"  {tn:10s} {sig:24s} {v}")
json.dump({"block":BLOCK,"old_favor":oldout}, open('/home/heisenberg/CA/betterbank-credx-lnd/analysis/bb_old_favor.json','w'), indent=1)
print("saved")
