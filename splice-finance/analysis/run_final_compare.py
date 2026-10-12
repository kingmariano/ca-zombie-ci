#!/usr/bin/env python3
import json, sys, hashlib
sys.path.insert(0, "/tmp/opencode")
from final_compare import compare, strip_meta, hexnorm

pairs = [
    ("PendleMarketFactoryV3 (Mode 0x9e6d..)", "0x9e6d12097339ddd5402FDD39fc0Ef86Eec54AB39.json", "out/PendleMarketFactoryV3.sol/PendleMarketFactoryV3.json"),
    ("PendleYieldContractFactory (Mode 0xD013..)", "0xD0135DddcAaf13f9Bd6054E830dA8cdc199C4F82.json", "out/PendleYieldContractFactory.sol/PendleYieldContractFactory.json"),
    ("PendleMarketV3 weETH market (Mode 0xbF14..)", "code-weETH-market.json", "out/PendleMarketV3.sol/PendleMarketV3.json"),
    ("PendlePrincipalToken weETH PT (Mode 0x497D..)", "code-weETH-PT.json", "out/PendlePrincipalToken.sol/PendlePrincipalToken.json"),
    ("PendleYieldToken weETH YT (Mode 0x9DBf..)", "code-weETH-YT.json", "out/PendleYieldToken.sol/PendleYieldToken.json"),
    ("PendlePtOracle (Mode 0x75e3..)", "oracle.json", "out/PendlePtOracle.sol/PendlePtOracle.json"),
    ("ActionSwapPTV3 facet (Mode 0xDE7d..)", "code-facet-swapPT.json", "out/ActionSwapPTV3.sol/ActionSwapPTV3.json"),
    ("ActionAddRemoveLiqV3 facet (Mode 0xe239..)", "code-facet-addRemoveLiq.json", "out/ActionAddRemoveLiqV3.sol/ActionAddRemoveLiqV3.json"),
    ("ActionSwapYTV3 facet (Mode 0xdDDF..)", "code-facet-swapYT.json", "out/ActionSwapYTV3.sol/ActionSwapYTV3.json"),
    ("ActionMiscV3 facet (Mode 0x8FD5..)", "code-facet-misc.json", "out/ActionMiscV3.sol/ActionMiscV3.json"),
    ("ActionCallbackV3 facet (Mode 0x19f7..)", "code-facet-callback.json", "out/ActionCallbackV3.sol/ActionCallbackV3.json"),
    ("PendleRouterV3__Mode (Mode 0x7A3a..)", "code-router.json", "out/PendleRouterV3__Mode.sol/PendleRouterV3__Mode.json"),
]
results = []
for name, ocf, art in pairs:
    try:
        r = compare(name, ocf, art)
        results.append(r)
    except KeyError as e:
        print(f"{name}: ARTIFACT MISSING {art}: {e}")
print()

# OracleLib library: self-address placeholder at byte offset 8 (after 604060808152307f), 32 bytes
try:
    r = compare("OracleLib library (Mode 0x56aff1..)", "code-OracleLib.json", "out/OracleLib.sol/OracleLib.json",
                extra_oc_mask=[(8, 32)], extra_local_mask=[(8, 32)])
    results.append(r)
except KeyError as e:
    print("OracleLib comparison failed:", e)
print()

# check that the market embeds the OracleLib address at its link positions
d = json.load(open(f"/tmp/opencode/splice-contracts/out/PendleMarketV3.sol/PendleMarketV3.json"))
links = d["deployedBytecode"].get("linkReferences", {})
oc = json.load(open("/tmp/opencode/splice-verify/code-weETH-market.json"))["result"][2:]
libaddr = "56aff1cacabe994760bf8505ed7916a356e20b69"
print("== market link positions (deployed code) ==")
for p, libs in links.items():
    for libname, refs in libs.items():
        for rr in refs:
            seg = oc[rr["start"]*2:(rr["start"]+rr["length"])*2]
            print(f"  {libname} @{rr['start']}: on-chain bytes = {seg} -> {'OracleLib 0x56aff1..' if libaddr in seg else 'MISMATCH'}")
print()

# split-code concatenation checks (Mode factories)
print("== split creation-code checks ==")
def hexnorm_c(c): return c[2:] if c.startswith("0x") else c

# market creation code split (PendleMarketV3)
cc = hexnorm_c(json.load(open("/tmp/opencode/splice-contracts/out/PendleMarketV3.sol/PendleMarketV3.json"))["bytecode"]["object"])
A = json.load(open("/tmp/opencode/splice-verify/code-0x9edb4e8ae4948f9382efc8cd5c894f9c59fba161.json"))["result"]
B = json.load(open("/tmp/opencode/splice-verify/code-0x69969956fca56c58effe591c7f5d1c9da7d95fac.json"))["result"]
A = A[2:]; B = B[2:]
sizeA = 11825; sizeB = 11826
print(f"market creation code: local={len(cc)//2}b  splitA={len(A)//2}b  splitB={len(B)//2}b")
print(f"  A == cc[:{sizeA}] : {A == cc[:sizeA*2]}")
print(f"  B == cc[{sizeA}:] : {B == cc[sizeA*2:]}")

# YT creation code split (PendleYieldToken)
ytc = hexnorm_c(json.load(open("/tmp/opencode/splice-contracts/out/PendleYieldToken.sol/PendleYieldToken.json"))["bytecode"]["object"])
YA = json.load(open("/tmp/opencode/splice-verify/code-0x5c80be8cff7a5d25cbbe63ea60b85230fde2432b.json"))["result"][2:]
YB = json.load(open("/tmp/opencode/splice-verify/code-0x2225c1b706820c1b73cfe40c9d0119f60e0b2bac.json"))["result"][2:]
print(f"YT creation code: local={len(ytc)//2}b  splitA={len(YA)//2}b  splitB={len(YB)//2}b")
print(f"  A == ytc[:{len(YA)//2}] : {YA == ytc[:len(YA)]}")
print(f"  B == ytc[{len(YA)//2}:] : {YB == ytc[len(YA):]}")

# Ethereum canonical Pendle deployments (sanity, may differ by build config)
print()
for name, ocf, art in [
    ("[eth-canonical] PendleMarketFactoryV3 (Ethereum 0x1A6f..)", "eth-0x1A6fCc85557BC4fB7B534ed835a03EF056552D52.json", "out/PendleMarketFactoryV3.sol/PendleMarketFactoryV3.json"),
    ("[eth-canonical] PendleYieldContractFactory (Ethereum 0xdF36..)", "eth-0xdF3601014686674e53d1Fa52F7602525483F9122.json", "out/PendleYieldContractFactory.sol/PendleYieldContractFactory.json"),
]:
    try:
        r = compare(name, ocf, art)
        results.append(r)
    except KeyError as e:
        print(f"{name}: missing artifact: {e}")

json.dump(results, open("/tmp/opencode/final_compare_results.json", "w"), indent=1)
print("\nsaved -> /tmp/opencode/final_compare_results.json")
