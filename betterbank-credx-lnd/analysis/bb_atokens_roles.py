#!/usr/bin/env python3
"""BetterBank aToken + ACL live state (read-only)."""
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

BLOCK = int(rpc(URL, "eth_blockNumber", []), 16)
print("block", BLOCK)
ATOKENS = [
 ("bPlsWPLS","0x1124DF53E5405AE1f0F0c05973Dd9f8f5eaB7125","0xa1077a294dde1b09bb078844df40758a5d0f9a27"),
 ("bPlsDAI","0xE527c42823fDd389b8A0f3aFBAF50Eff094e560b","0x6b175474e89094c44da98b954eedeac495271d0f"),
 ("bPlsPLSX","0x3E661918baA75E64FB5c7e2Ef29ab79AdFEEaD83","0x95b303987a60c71504d99aa1b13b4da07b0790ab"),
 ("bPlsPLP","0xE51C682e2b6Bb3cDEFab9E809e9B52b306624C7c","0xdca85efdce177b24de8b17811cec007fe5098586"),
 ("bPlsPLP","0xeD6cfd41888475F373dFee53aEAD5F2123C76e0A","0xa0126ac1364606bafb150653c7bc9f1af4283dfa"),
 ("bPlsPLP","0xA7561ac1c68d93b3143595028545A9575c01116c","0x24264d580711474526e8f2a8ccb184f6438bb95c"),
 ("bPlsPLP","0xb2235cE3B6D55E8bc089b799e4B8Db1A8A1659Ea","0xb75e32eb2994b9632d16d157c55731d2fc792b17"),
 ("bPlsPLP","0x29601fB5C87bE0fCE1A4438DF1d8992EC47c24d2","0x6a7e018d334b8cc9116010d8779cb5b4b0143adc"),
 ("bPlsPLP","0xca23D03Fa0F62906e1079bfC641aB849391AF16E","0xa1cbdc3d9cab3d9259ed18993f3ce224e2f333c9"),
 ("bPlsDAI","0xC20104e249786880988d70b7CEB66599b1C21203","0xefd766ccb38eaf1dfd701853bfce31359239f305"),
 ("bPlsEDAIFLP","0x9603E53129233d3767Af6C735c15166AD1aacc0d","0xedcb808ddc390844049b1af42c8163e0e5c54405"),
]
POOL = "0xdB2c92c63e0320511a278673F0dBF8c3ACa7C5Ee"
ACL = "0xB2e5A4e70eBC18C26E39a802622DE06d0ff78890"
calls = []
for sym, at, und in ATOKENS:
    calls.append(("eth_call", [{"to": at, "data": sel("totalSupply()")}, "latest"]))
    calls.append(("eth_call", [{"to": und, "data": sel("balanceOf(address)") + at[2:].rjust(64,'0')}, "latest"]))
res = batch(URL, calls)
out = {"block": BLOCK, "atokens": []}
print(f"{'aToken':16s} {'totalSupply':>26s} {'underlying_held':>26s}")
for i,(sym,at,und) in enumerate(ATOKENS):
    ts = u(res[i*2]); ub = u(res[i*2+1])
    out["atokens"].append({"symbol":sym,"atoken":at,"underlying":und,"atoken_totalSupply":ts,"underlying_in_atoken":ub})
    print(f"{sym:16s} {str(ts):>26s} {str(ub):>26s}")

# ACL roles
ROLES = {n: k(n) for n in ["POOL_ADMIN","EMERGENCY_ADMIN","RISK_ADMIN","FLASH_BORROWER","BRIDGE","ASSET_LISTING_ADMIN"]}
ROLES["DEFAULT_ADMIN_ROLE"] = "0x" + "00"*32
HOLDERS = {
 "provider_owner":"0x96F80a880A52533FAB2b51Ae4dCA719B2FCeCbD2",
 "team":"0x1EA35487AE62322F61f4C0F639a598d9eEB2F340",
 "custom_deployer":"0xc0702ae0374f83fc3ba71ce2b30a323b09ec19da",
 "pool":"0xdB2c92c63e0320511a278673F0dBF8c3ACa7C5Ee",
 "configurator":"0x8D49A4db99c8c336e45d42C18c15f3BA27221db1",
 "zero":"0x"+"00"*20,
}
calls=[]; keys=[]
for rn,rh in ROLES.items():
    for hn,ha in HOLDERS.items():
        calls.append(("eth_call",[{"to":ACL,"data":sel("hasRole(bytes32,address)")+rh[2:]+ha[2:].rjust(64,'0')},"latest"]))
        keys.append((rn,hn))
res=batch(URL,calls)
out["roles"]={}
for (rn,hn),v in zip(keys,res):
    held = u(v)==1
    if held:
        print("ROLE HELD:", rn, hn, HOLDERS[hn])
    out["roles"][rn+":"+hn]=held
# owner + acl admin
for f,addr in [("owner()","0x21597Ae2f941b5022c6E72fd02955B7f3C87f4Cb"),("getACLAdmin()","0x21597Ae2f941b5022c6E72fd02955B7f3C87f4Cb"),("admin()",POOL)]:
    r=rpc(URL,"eth_call",[{"to":addr,"data":sel(f)},"latest"])
    if r and r!='0x':
        print(f,"->","0x"+r[-40:])
        out[f]= "0x"+r[-40:]
json.dump(out, open('/home/heisenberg/CA/betterbank-credx-lnd/analysis/bb_atokens_roles.json','w'), indent=1)
print("saved")
