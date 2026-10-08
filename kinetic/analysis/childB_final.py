#!/usr/bin/env python3
"""Child B final: all key reads pinned to ONE block for clean citations."""
import json, os, requests
from eth_utils import keccak
from eth_abi import encode as abi_encode, decode as abi_decode

HERE = os.path.dirname(os.path.abspath(__file__))
RPCS = ["https://14.rpc.thirdweb.com", "https://flare.public-rpc.com", "https://rpc.ankr.com/flare"]

def rpc(method, params):
    for r in RPCS:
        try:
            js = requests.post(r, json={"jsonrpc":"2.0","id":1,"method":method,"params":params}, timeout=45).json()
            if "result" in js or "error" in js: return js
        except Exception: pass
    return {}

BLK = int(rpc("eth_blockNumber", []).get("result"), 16)
BLK_HEX = hex(BLK)
def sel(sig): return keccak(text=sig)[:4].hex()
def enc(sig, atypes=None, avals=None):
    return "0x" + sel(sig) + (abi_encode(atypes or [], avals or []).hex() if atypes else "")
def call(to, data, frm=None):
    p = {"to": to, "data": data}
    if frm: p["from"] = frm
    js = rpc("eth_call", [p, BLK_HEX])
    return js.get("result") if "result" in js else {"ERR": js.get("error",{}).get("message")}

A = {
 "C1_oracle":"0x61f77Ef0064736Ffa68c31D960E55BAf67F79A4b",
 "C2_oracle":"0xC1d7029C970d9B683Da9d37b49d84D081dbeD54c",
 "C3_oracle":"0x30eDf82B2B75BbBf8e0b04b0F59086d321af964D",
 "C1_unitroller":"0x15F69897E6aEBE0463401345543C26d1Fd994abB",
 "C2_unitroller":"0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8",
 "kSFLR":"0x291487beC339c2fE5D83DD45F0a15EFC9Ac45656",
 "allowlist":"0x59f6559051c67bc3b2fe4b9275770eff6616e0b7",
 "tl_oracle_owner":"0x58b1b315319ce94fff3a665e2c4a7f61375aaba8",
 "utu_8127":"0x81274d9250C8a36c62d3F45F18BD34D44D433b45",
 "utu_5b8a":"0x5b8A5e0009cf617f739aE254AE2a6d83471F10aC",
 "ctu_fac3":"0xfaC3F74c3dDed68AAA5Cd6f37793fC792e74A4c7",
 "po_8f39":"0x8f39EC8683Ff5af8f8Ad18563981f2C020E7EF32",
 "safe":"0x37C6C7c719DB93085678cE72981CDd96219C9B72",
 "ftso_proxy":"0x7bde3df0624114edb3a67dfe6753e62f4e7c1d20",
 "ftso_b18d":"0xb18d3a5e5a85c65ce47f977d7f486b79f99d3d32",
 "ftso_impl_15f8":"0x15f816c9f9b0e80f684c88534c29cd618be32342",
 "registry":"0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019",
}
SFLR="0x12e605bc104e93b45e1ad99f9e555f659051c2bb"; USDC_E="0xfbda5f676cb37624f28265a144a48b0d6e87d3b6"
USDT="0x0b38e83b86d491735feaa0a791f65c2b99535396"; WETH="0x1502fa4be69d526124d453619276faccab275d3d"
FLRETH="0x26a1fab310bd080542dc864647d05985360b16a5"; USDT0="0xe7cd86e13ac4309349f30b3435a9d337750fc82d"
FXRP="0xad552a648c74d49e10027ab8a618a3ad4901c5be"; STXRP="0x4c18ff3c89632c3dd62e796c0afa5c07c4c1b2b3"
ZERO="0x0000000000000000000000000000000000000000"; RAND="0x1111111111111111111111111111111111111111"
FLR_FEED=bytes.fromhex("01464c522f55534400000000000000000000000000")

out={"block":BLK,"reads":{},"sims":{},"codes":{}}
R=out["reads"]
def rd(k,to,sig,t=None,v=None):
    R[k]=call(to,enc(sig,t,v))
for k,o in [("c1","C1_oracle"),("c2","C2_oracle"),("c3","C3_oracle")]:
    rd(f"oracle.{k}.owner",A[o],"owner()")
    rd(f"oracle.{k}.pendingOwner",A[o],"pendingOwner()")
    rd(f"oracle.{k}.ftsoV2",A[o],"ftsoV2()")
rd("c1.unitroller.admin",A["C1_unitroller"],"admin()")
rd("c2.unitroller.admin",A["C2_unitroller"],"admin()")
rd("c1.unitroller.pendingAdmin",A["C1_unitroller"],"pendingAdmin()")
rd("c2.unitroller.pendingAdmin",A["C2_unitroller"],"pendingAdmin()")
rd("ksflr.admin",A["kSFLR"],"admin()")
rd("ksflr.implementation",A["kSFLR"],"implementation()")
rd("ksflr.approvalAllowList",A["kSFLR"],"approvalAllowList()")
rd("allowlist.owner",A["allowlist"],"owner()")
rd("allowlist.length",A["allowlist"],"allowedAddressesLength()")
rd("allowlist.entry0",A["allowlist"],"allowedAddresses(uint256)",["uint256"],[0])
rd("allowlist.allowed.rand",A["allowlist"],"allowed(address)",["address"],[RAND])
rd("allowlist.allowed.entry0",A["allowlist"],"allowed(address)",["address"],["0x72b8cb893bd9350fa175ef0e62a667d07c7ffc86"])
rd("registry.FtsoV2",A["registry"],"getContractAddressByName(string)",["string"],["FtsoV2"])
for k,o in [("c1","C1_oracle"),("c2","C2_oracle")]:
    for an,addr in [("native0",ZERO),("sFLR",SFLR),("USDC.e",USDC_E),("USDT",USDT),("WETH",WETH),("flrETH",FLRETH),("USDT0",USDT0),("FXRP",FXRP),("stXRP",STXRP)]:
        rd(f"cfg.{k}.{an}",A[o],"tokenConfigs(address)",["address"],[addr])
    rd(f"{k}.assetPrices.sFLR",A[o],"assetPrices(address)",["address"],[SFLR])
for k in ["tl_oracle_owner","utu_8127","utu_5b8a","ctu_fac3","po_8f39"]:
    rd(f"{k}.getMinDelay",A[k],"getMinDelay()")
rd("utu8127.priceOracleUpgrader",A["utu_8127"],"priceOracleUpgrader()")
rd("utu5b8a.priceOracleUpgrader",A["utu_5b8a"],"priceOracleUpgrader()")
rd("utu8127.unitroller",A["utu_8127"],"unitroller()")
rd("utu5b8a.unitroller",A["utu_5b8a"],"unitroller()")
rd("ctuFac3.CERc20Delegator",A["ctu_fac3"],"CERc20Delegator()")
rd("safe.VERSION",A["safe"],"VERSION()")
rd("safe.getThreshold",A["safe"],"getThreshold()")
rd("safe.getOwners",A["safe"],"getOwners()")
# FTSO same-block
rd("ftso.proxy.FLR",A["ftso_proxy"],"getFeedById(bytes21)",["bytes21"],[FLR_FEED])
rd("ftso.b18d.FLR",A["ftso_b18d"],"getFeedById(bytes21)",["bytes21"],[FLR_FEED])
rd("c2.getEtherPrice",A["C2_oracle"],"getEtherPrice()")
rd("c1.getEtherPrice",A["C1_oracle"],"getEtherPrice()")
# sims
S=out["sims"]
S["c2.setPrice"]=call(A["C2_oracle"],enc("setPrice(address,uint256)",["address","uint256"],[USDC_E,1]),frm=RAND)
S["c2.setEtherPrice"]=call(A["C2_oracle"],enc("setEtherPrice(uint256)",["uint256"],[1]),frm=RAND)
S["c2.setTokenConfig"]=call(A["C2_oracle"],enc("setTokenConfig((address,bytes21,uint64,address))",["(address,bytes21,uint64,address)"],[(USDC_E,bytes.fromhex("01"+"00"*20),420,ZERO)]),frm=RAND)
S["c2.setFTSOV2"]=call(A["C2_oracle"],enc("setFTSOV2(address)",["address"],[RAND]),frm=RAND)
S["c1.setPrice"]=call(A["C1_oracle"],enc("setPrice(address,uint256)",["address","uint256"],[USDC_E,1]),frm=RAND)
S["c3.setTokenConfig"]=call(A["C3_oracle"],enc("setTokenConfig((address,bytes21,uint64,address))",["(address,bytes21,uint64,address)"],[(USDC_E,bytes.fromhex("01"+"00"*20),420,ZERO)]),frm=RAND)
S["ksflr.approve.rand"]=call(A["kSFLR"],enc("approve(address,uint256)",["address","uint256"],[RAND,1]),frm=RAND)
S["ksflr.approve.zero"]=call(A["kSFLR"],enc("approve(address,uint256)",["address","uint256"],[RAND,0]),frm=RAND)
S["ksflr.setApprovalAllowList"]=call(A["kSFLR"],enc("_setApprovalAllowList(address)",["address"],[RAND]),frm=RAND)
S["allowlist.allow.rand"]=call(A["allowlist"],enc("allow(address)",["address"],[RAND]),frm=RAND)
S["c1.unitroller.setPriceOracle"]=call(A["C1_unitroller"],enc("_setPriceOracle(address)",["address"],[RAND]),frm=RAND)
S["c2.unitroller.setPriceOracle"]=call(A["C2_unitroller"],enc("_setPriceOracle(address)",["address"],[RAND]),frm=RAND)
S["c2.unitroller.setCF"]=call(A["C2_unitroller"],enc("_setCollateralFactor(address,uint256)",["address","uint256"],[A["kSFLR"],0]),frm=RAND)
S["c2.unitroller.setBorrowCaps"]=call(A["C2_unitroller"],enc("_setMarketBorrowCaps(address[],uint256[])",["address[]","uint256[]"],[[A["kSFLR"]],[1]]),frm=RAND)
S["c2.unitroller.setPendingAdmin"]=call(A["C2_unitroller"],enc("_setPendingAdmin(address)",["address"],[RAND]),frm=RAND)
S["utu8127.setPriceOracle"]=call(A["utu_8127"],enc("_setPriceOracle(address)",["address"],[RAND]),frm=RAND)
S["utu8127.setCF"]=call(A["utu_8127"],enc("_setCollateralFactor(address,uint256)",["address","uint256"],[A["kSFLR"],0]),frm=RAND)
# codes
for k in ["C1_oracle","C2_oracle","C3_oracle","C1_unitroller","C2_unitroller","safe","tl_oracle_owner","utu_8127","utu_5b8a","ctu_fac3","po_8f39","ftso_proxy","ftso_b18d","ftso_impl_15f8"]:
    code=rpc("eth_getCode",[A[k],BLK_HEX]).get("result","0x")
    out["codes"][k]=max(0,(len(code)-2)//2)

# decode cfg tuples + addresses
def d_addr(h): return "0x"+h[-40:] if h and h!="0x" else h
def d_cfg(h):
    if not h or h=="0x" or not isinstance(h,str): return h
    try:
        v=abi_decode(["address","bytes21","uint64","address"],bytes.fromhex(h[2:]))
        return [v[0],"0x"+v[1].hex(),v[2],v[3]]
    except Exception as e: return f"err {e}"
def d_u(h):
    try: return int(h,16)
    except Exception: return h
pretty={}
for k in ["oracle.c1.owner","oracle.c2.owner","oracle.c3.owner","oracle.c1.pendingOwner","oracle.c2.pendingOwner","oracle.c3.pendingOwner","oracle.c1.ftsoV2","oracle.c2.ftsoV2","oracle.c3.ftsoV2",
          "c1.unitroller.admin","c2.unitroller.admin","c1.unitroller.pendingAdmin","c2.unitroller.pendingAdmin","ksflr.admin","ksflr.implementation","ksflr.approvalAllowList","allowlist.owner","allowlist.entry0","registry.FtsoV2",
          "utu8127.priceOracleUpgrader","utu5b8a.priceOracleUpgrader","utu8127.unitroller","utu5b8a.unitroller","ctuFac3.CERc20Delegator"]:
    pretty[k]=d_addr(R.get(k,""))
for k in ["allowlist.length","allowlist.allowed.rand","allowlist.allowed.entry0"]:
    pretty[k]=R.get(k)
for k in ["tl_oracle_owner.getMinDelay","utu_8127.getMinDelay","utu_5b8a.getMinDelay","ctu_fac3.getMinDelay","po_8f39.getMinDelay","c2.getEtherPrice","c1.getEtherPrice"]:
    pretty[k]=d_u(R.get(k))
for k in R:
    if k.startswith("cfg."): pretty[k]=d_cfg(R[k])
try:
    pretty["safe.getOwners"]=abi_decode(["address[]"],bytes.fromhex(R["safe.getOwners"][2:]))[0]
    pretty["safe.getThreshold"]=int(R["safe.getThreshold"],16)
except Exception as e: pretty["safe_err"]=str(e)
pretty["safe.VERSION"]=abi_decode(["string"],bytes.fromhex(R["safe.VERSION"][2:]))[0] if R.get("safe.VERSION") else None
for k in ["ftso.proxy.FLR","ftso.b18d.FLR"]:
    h=R.get(k)
    if h and h!="0x":
        raw=bytes.fromhex(h[2:]); pretty[k]={"price":int.from_bytes(raw[:32],"big"),"decimals":int.from_bytes(raw[32:64],"big",signed=True),"timestamp":int.from_bytes(raw[64:96],"big")}
out["pretty"]=pretty
with open(os.path.join(HERE,"childB-final-block.json"),"w") as f: json.dump(out,f,indent=2)
print("BLOCK",BLK)
print(json.dumps(pretty,indent=1,default=str)[:4000])
print("CODES",json.dumps(out["codes"]))
