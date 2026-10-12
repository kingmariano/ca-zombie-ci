#!/usr/bin/env python3
"""Generate the complete evidence JSON for the Splice fork-diff report."""
import json, sys, hashlib
sys.path.insert(0, "/tmp/opencode")
import final_compare as fc
from final_compare import compare, strip_meta, hexnorm

EVID = {"generated_at_utc": "2026-10-12", "chains": ["mode"], "build": {}, "pairs": [], "split_checks": {}, "metadata_hashes": {}, "wire_reads": {}}

def meta_hash(code):
    c = code[2:] if code.startswith("0x") else code
    meta = bytes.fromhex(c[-(53*2):-4])
    if meta[0] == 0xa2 and meta[2:6] == b'ipfs':
        return meta[10:42].hex()
    return None

# --- paris pairs ---
paris_pairs = [
    ("PendleMarketFactoryV3", "0x9e6d12097339ddd5402FDD39fc0Ef86Eec54AB39.json", "out/PendleMarketFactoryV3.sol/PendleMarketFactoryV3.json", "0x9e6d12097339ddd5402FDD39fc0Ef86Eec54AB39"),
    ("PendleYieldContractFactory", "0xD0135DddcAaf13f9Bd6054E830dA8cdc199C4F82.json", "out/PendleYieldContractFactory.sol/PendleYieldContractFactory.json", "0xD0135DddcAaf13f9Bd6054E830dA8cdc199C4F82"),
    ("PendleMarketV3 (weETH market)", "code-weETH-market.json", "out/PendleMarketV3.sol/PendleMarketV3.json", "0xbF14932e1A7962C77D0b31be80075936bE1A43D4"),
    ("PendlePrincipalToken (weETH PT)", "code-weETH-PT.json", "out/PendlePrincipalToken.sol/PendlePrincipalToken.json", "0x497D0106919FA821296261C0e9a9EAEF60b8d103"),
    ("PendleYieldToken (weETH YT)", "code-weETH-YT.json", "out/PendleYieldToken.sol/PendleYieldToken.json", "0x9DBf254Cc5721868f151e41413f8D5B6040c8156"),
    ("PendlePtOracle", "oracle.json", "out/PendlePtOracle.sol/PendlePtOracle.json", "0x75e33a93C33B9A3eE337926d978322422822B8c7"),
    ("ActionSwapPTV3 facet", "code-facet-swapPT.json", "out/ActionSwapPTV3.sol/ActionSwapPTV3.json", "0xDE7ddb8E8778759c16A0a73c743a5d38165cB1A4"),
    ("ActionAddRemoveLiqV3 facet", "code-facet-addRemoveLiq.json", "out/ActionAddRemoveLiqV3.sol/ActionAddRemoveLiqV3.json", "0xe239D43D568De53DEB27B0B145e8Ad0ab3958D61"),
    ("ActionSwapYTV3 facet", "code-facet-swapYT.json", "out/ActionSwapYTV3.sol/ActionSwapYTV3.json", "0xdDDFFE2a579658626Cf43Dd92dFf56dC8767fbbB"),
    ("ActionMiscV3 facet", "code-facet-misc.json", "out/ActionMiscV3.sol/ActionMiscV3.json", "0x8FD532444712f7807212638b03D111344a347eF9"),
    ("ActionCallbackV3 facet", "code-facet-callback.json", "out/ActionCallbackV3.sol/ActionCallbackV3.json", "0x19f73Aba87404c91878F719c129aEee028CEc6f8"),
    ("PendleRouterV3__Mode", "code-router.json", "out/PendleRouterV3__Mode.sol/PendleRouterV3__Mode.json", "0x7A3a94AE0fC1421A3eac23eA6371036ac8d8f448"),
]
for name, ocf, art, addr in paris_pairs:
    r = compare(name, ocf, art)
    r["address"] = addr; r["artifact"] = art; r["evm"] = "paris"; r["via_ir"] = True; r["optimizer_runs"] = 200
    EVID["pairs"].append(r)

r = compare("OracleLib (library)", "code-OracleLib.json", "out/OracleLib.sol/OracleLib.json", extra_oc_mask=[(8, 32)], extra_local_mask=[(8, 32)])
r.update({"address": "0x56aff1cacabe994760bf8505ed7916a356e20b69", "artifact": "out/OracleLib.sol/OracleLib.json", "evm": "paris", "via_ir": True, "optimizer_runs": 200})
EVID["pairs"].append(r)

# --- shanghai SY pairs ---
fc.SPLICE = "/tmp/opencode/splice-contracts"
shanghai_pairs = [
    ("SpliceWeETHL2SY", "code-weETH-SY.json", "out-shanghai/SpliceWeETHL2SY.sol/SpliceWeETHL2SY.json", "0x356B2eBc41Fcc7A84b59e998231C14317A5e286c"),
    ("SpliceWrsETHL2SY", "code-wrsETH-SY.json", "out-shanghai/SpliceWrsETHL2SY.sol/SpliceWrsETHL2SY.json", "0x9bAF8D6A90c69944dD46fB46B0E620f8Ab23411d"),
    ("PendleEzETHL2SY", "code-ezETH-SY.json", "out-shanghai/PendleEzETHL2SY.sol/PendleEzETHL2SY.json", "0x0Cd0F94bBEAd98b6A05773426a783eFE8588A559"),
    ("PendleERC20SY (Splice MODE SY)", "code-MODE-SY.json", "out-shanghai/PendleERC20SY.sol/PendleERC20SY.json", "0x5763BA22463ffBef84d5aa1a6Df983420852bED7"),
]
for name, ocf, art, addr in shanghai_pairs:
    r = compare(name, ocf, art)
    r["address"] = addr; r["artifact"] = art; r["evm"] = "shanghai"; r["via_ir"] = True; r["optimizer_runs"] = 200
    EVID["pairs"].append(r)

# --- metadata hashes ---
meta_pairs = [(name, ocf, art, addr) for (name, ocf, art, addr) in paris_pairs + shanghai_pairs]
meta_pairs.append(("OracleLib (library)", "code-OracleLib.json", "out/OracleLib.sol/OracleLib.json", "0x56aff1cacabe994760bf8505ed7916a356e20b69"))
for name, ocf, art, addr in meta_pairs:
    oc = json.load(open(f"/tmp/opencode/splice-verify/{ocf}"))["result"]
    d = json.load(open(f"/tmp/opencode/splice-contracts/{art}"))
    EVID["metadata_hashes"][name] = {"address": addr, "on_chain": meta_hash(oc), "local": meta_hash(d["deployedBytecode"]["object"])}

# YCF-embedded PT metadata hash cross-check
ycf_oc = json.load(open("/tmp/opencode/splice-verify/0xD0135DddcAaf13f9Bd6054E830dA8cdc199C4F82.json"))["result"]
ycf_s, _ = strip_meta(ycf_oc)
lpt = json.load(open("/tmp/opencode/splice-contracts/out/PendlePrincipalToken.sol/PendlePrincipalToken.json"))
ptc_s, ptmeta = strip_meta(lpt["bytecode"]["object"])
pt_oc = json.load(open("/tmp/opencode/splice-verify/code-weETH-PT.json"))["result"]
idx = ycf_s.find(ptc_s)
oc_emb = meta_hash("0x" + ycf_s[idx:idx+len(ptc_s)+ptmeta*2+4]) if idx >= 0 else None
EVID["metadata_hashes"]["YCF-embedded PT creation-code hash"] = {
    "found_at_byte": idx // 2 if idx >= 0 else None,
    "on_chain_embedded": oc_emb,
    "deployed_weETH_PT_own": meta_hash(pt_oc),
    "match": oc_emb == meta_hash(pt_oc),
}

# --- split-code checks ---
def mask(c, ranges):
    l = list(c)
    for (s, n) in ranges:
        for i in range(s*2, (s+n)*2):
            l[i] = '0'
    return ''.join(l)

mk = json.load(open("/tmp/opencode/splice-contracts/out/PendleMarketV3.sol/PendleMarketV3.json"))
cc = hexnorm(mk["bytecode"]["object"])
mk_links = []
for k, v in mk["bytecode"].get("linkReferences", {}).items():
    for lib, refs in v.items():
        for r in refs:
            mk_links.append((r["start"], r["length"]))
A = hexnorm(json.load(open("/tmp/opencode/splice-verify/code-0x9edb4e8ae4948f9382efc8cd5c894f9c59fba161.json"))["result"])
B = hexnorm(json.load(open("/tmp/opencode/splice-verify/code-0x69969956fca56c58effe591c7f5d1c9da7d95fac.json"))["result"])
full = A + B
clusters_mkt = []
diffs = [i for i in range(len(cc)) if cc[i] != full[i]]
cur = [diffs[0]]
for x in diffs[1:]:
    if x - cur[-1] <= 8: cur.append(x)
    else: clusters_mkt.append((cur[0]//2, cur[-1]//2)); cur = [x]
clusters_mkt.append((cur[0]//2, cur[-1]//2))
masked_cc = mask(cc, mk_links + [(len(cc)//2-53, 53)])
masked_dep = mask(full, mk_links + [(len(cc)//2-53, 53)])
EVID["split_checks"]["market_creation_code"] = {
    "local_creation_code_len": len(cc)//2, "splitA_len": len(A)//2, "splitB_len": len(B)//2,
    "splitA": "0x9eDB4E8ae4948f9382EFC8cd5c894f9c59fBA161", "splitB": "0x69969956FCA56C58EFFe591C7f5d1C9Da7d95fAC",
    "diff_clusters_vs_local": clusters_mkt,
    "diff_explanation": "4 OracleLib link slots (deployed=0x56aff1.., local=solc placeholder __$fcd6a5a796f1bec599f7a6cb2dcb89ae26$__) + trailing metadata hash (build config)",
    "sha256_masked_local": hashlib.sha256(bytes.fromhex(masked_cc)).hexdigest(),
    "sha256_masked_deployed": hashlib.sha256(bytes.fromhex(masked_dep)).hexdigest(),
    "identical_after_masking": masked_cc == masked_dep,
}
yt = json.load(open("/tmp/opencode/splice-contracts/out/PendleYieldToken.sol/PendleYieldToken.json"))
ytc = hexnorm(yt["bytecode"]["object"])
YA = hexnorm(json.load(open("/tmp/opencode/splice-verify/code-0x5c80be8cff7a5d25cbbe63ea60b85230fde2432b.json"))["result"])
YB = hexnorm(json.load(open("/tmp/opencode/splice-verify/code-0x2225c1b706820c1b73cfe40c9d0119f60e0b2bac.json"))["result"])
fullY = YA + YB
diffs = [i for i in range(len(ytc)) if ytc[i] != fullY[i]]
clusters_yt = []
cur = [diffs[0]]
for x in diffs[1:]:
    if x - cur[-1] <= 8: cur.append(x)
    else: clusters_yt.append((cur[0]//2, cur[-1]//2)); cur = [x]
clusters_yt.append((cur[0]//2, cur[-1]//2))
masked_ytc = mask(ytc, [(len(ytc)//2-53, 53)])
masked_ytd = mask(fullY, [(len(ytc)//2-53, 53)])
EVID["split_checks"]["yt_creation_code"] = {
    "local_creation_code_len": len(ytc)//2, "splitA_len": len(YA)//2, "splitB_len": len(YB)//2,
    "splitA": "0x5C80bE8cFF7A5D25CbBE63EA60b85230Fde2432B", "splitB": "0x2225c1B706820c1b73cfE40c9D0119f60e0B2BAC",
    "diff_clusters_vs_local": clusters_yt,
    "diff_explanation": "trailing metadata hash only (build config)",
    "sha256_masked_local": hashlib.sha256(bytes.fromhex(masked_ytc)).hexdigest(),
    "sha256_masked_deployed": hashlib.sha256(bytes.fromhex(masked_ytd)).hexdigest(),
    "identical_after_masking": masked_ytc == masked_ytd,
}

# market link positions check
EVID["market_link_positions"] = {rm: "OracleLib address 0x56aff1cacabe994760bf8505ed7916a356e20b69 at runtime slots 3314/5074/10718 (from code-weETH-market.json)" for rm in ["check"]}

json.dump(EVID, open("/tmp/opencode/fork-diff-evidence.json", "w"), indent=1)
print("saved /tmp/opencode/fork-diff-evidence.json")
print(json.dumps(EVID["metadata_hashes"]["YCF-embedded PT creation-code hash"], indent=1))
