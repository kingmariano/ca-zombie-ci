#!/usr/bin/env python3
"""Extract candidate function selectors from deployed bytecode (PUSH4 ... EQ dispatcher scan).
Read-only, keyless RPC."""
import json, sys, urllib.request, re

RPCS = {"ethereum": "https://ethereum-rpc.publicnode.com",
        "aurora": "https://mainnet.aurora.dev"}

def rpc(url, method, params):
    req = urllib.request.Request(url, json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                                 headers={"Content-Type":"application/json","User-Agent":"rift-research"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())["result"]

def selectors(code_hex):
    b = bytes.fromhex(code_hex[2:])
    sels = set()
    # PUSH4 = 0x63 ; EQ = 0x14 ; pattern: 63 xx xx xx xx 14
    for i in range(len(b)-5):
        if b[i] == 0x63 and b[i+5] == 0x14:
            sels.add("0x"+b[i+1:i+5].hex())
    return sorted(sels)

KNOWN = {
 "0x0dfe1681":"token0()","0xd21220a7":"token1()","0xa8aa1b31":"pair()","0x900cf0cf":"epoch()",
 "0x4ff0876a":"epochDuration()","0xd5bf91e3":"lastEpochStart()","0x5392fd1c":"depositsEnabled()",
 "0x5c975abb":"paused()","0xf2f4eb26":"core()","0xac896951":"token0Data()","0x930f7ee8":"token1Data()",
 "0xa21b927f":"isNativeVault()","0x41213a17":"token0FloorNum()","0xc2306acb":"token1FloorNum()",
 "0xef253eb6":"token0ValueLocked()","0x037a354c":"token1ValueLocked()","0xdcc3e06e":"rewarder()",
 "0xf1068454":"pid()","0x94db0595":"feesAccrued()","0x1c8e8568":"whitelistDisabled()",
 "0xf878996a":"nextEpoch(uint256,uint256)","0x971e3c43":"depositToken0(uint256)","0x71210a0d":"depositToken1(uint256)",
 "0x11e8416c":"withdrawToken0(uint256)","0xa5c0fd05":"withdrawToken1(uint256)","0x6e6c9041":"claimToken0()",
 "0x8a809095":"claimToken1()","0x470ea1d4":"setDepositsEnabled()","0x486f0673":"setDepositsDisabled()",
 "0x30024dfe":"setEpochDuration(uint256)","0xc59197e3":"setToken0Floor(uint256)","0x5c08bfc2":"setToken1Floor(uint256)",
 "0xc8796572":"collectFees()","0x3bf8d620":"rescueTokens(address[],uint256[])","0x4b4c489b":"unstakeLiquidity()",
 "0xa6241980":"token0Balance(address)","0x8fd57d3e":"token1Balance(address)","0x2addf608":"epochToToken0Rate(uint256)",
 "0xa523e580":"token0WithdrawRequests(address)","0x2a1f9d3e":"token1WithdrawRequests(address)",
 "0xbe7ed0be":"token0BalanceDay0(address)","0x63ecae42":"token1BalanceDay0(address)",
 "0x8456cb59":"pause()","0x3f4ba83a":"unpause()","0x5c60da1b":"implementation()","0xf851a440":"admin()",
 "0x3659cfe6":"upgradeTo(address)","0x4f1ef286":"upgradeToAndCall(address,bytes)","0x8f283970":"changeAdmin(address)",
 "0x8da5cb5b":"owner()","0xf2fde38b":"transferOwnership(address)","0x715018a6":"renounceOwnership()",
 "0xac4c25b2":"","0x2e1a7d4d":"withdraw(uint256)","0xa9059cbb":"transfer(address,uint256)",
 "0x9c4e6748":"","0x6a761202":"execTransaction(...)","0x01ffc9a7":"supportsInterface(bytes4)",
 "0x248a9ca3":"getRoleAdmin(bytes32)","0x2f2ff15d":"grantRole(bytes32,address)","0xd547741f":"revokeRole(bytes32,address)",
 "0x91d14854":"hasRole(bytes32,address)","0xa217fddf":"DEFAULT_ADMIN_ROLE()","0x8f2ff793":"",
 "0x93139472":"","0xf6d4244b":"","0x5d9b088c":"",
}

def main():
    chain = sys.argv[1]; out = {}
    for a in sys.argv[2:]:
        code = rpc(RPCS[chain], "eth_getCode", [a, "latest"])
        sels = selectors(code)
        out[a] = {"size": (len(code)-2)//2, "selectors": len(sels),
                  "named": {s: KNOWN.get(s, "") for s in sels if s in KNOWN},
                  "unknown": [s for s in sels if s not in KNOWN]}
    print(json.dumps(out, indent=1))

if __name__ == "__main__":
    main()
