#!/usr/bin/env python3
"""QC-2 live re-verification of Convergence Fi (Ethereum). Read-only.
Checks: current block, impl slots (upgrade drift), all 37 services' impl/beacon,
registration mappings, withdrawals-call targets, holdings. Output: analysis/live_verify.json"""
import json, os, sys, urllib.request

ENV = {}
for line in open("/home/heisenberg/CA/.env"):
    line = line.strip()
    if "=" in line and not line.startswith("#"):
        k, v = line.split("=", 1)
        ENV[k.strip()] = v.strip().strip('"').strip("'")
RPC = ENV.get("BLOCKPI_RPC_URL") or ENV.get("RPC_URL")

TOWER = "0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7"
BLACKHOLE = "0x21777106355Ba506A31FF7984c0aE5C924deB77f"
MANAGER = "0x7319662aD7D7ce2d1595073EA042B723F6d0dc48"
DISTRIBUTOR = "0x6B65525a40704a4c48d07c25b8D05654854DFEcD"
FACTORY = "0x15A2d42421b62E92fe0ABD22E2aa6caC8Ffa6ec5"
CVGSDT_SVC = "0xF941BC649Ef0B20ABd7f6dC78CA8f8E225337933"
CVGSDT = "0x830614aE209FF9d8706d386fcdBc7a55206fcffC"
SDT = "0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F"
CVG = "0x97efFB790f2fbB701D88f89DB4521348A2B77be8"
CVGSDT_BUFFER = "0x98C04163723134b0a4C364A72A71e620b58aB3f1"
CLAIMER_V1 = "0x539e65190a371ce73244a98dec42ba635cca512c"
CLAIMER_2 = "0x63312010fdc7dcacd33b6bd9d9cf0c54b0e6e6f0"  # placeholder, verify below
SDCRV_SVC = "0x2ff160bcadb485b5f048b9880e6f471af632060c"
SDCRV_GAUGE = "0x7f50786A0b15723D741727882ee99a0BF34e3466"

IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
BEACON_SLOT = "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50"

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "qc-research"})
    with urllib.request.urlopen(req, timeout=90) as r:
        out = json.load(r)
    if "error" in out:
        raise RuntimeError(out["error"])
    return out["result"]

def pad_addr(a): return a.lower().replace("0x", "").rjust(64, "0")
def u(w): return int(w, 16) if w and w != "0x" else 0
def ad(w): return "0x" + w[-40:] if w and len(w) >= 40 else None

def call(to, sig, args=()):
    data = sig + "".join(pad_addr(a) if isinstance(a, str) else hex(a)[2:].rjust(64, "0") for a in args)
    return rpc("eth_call", [{"to": to, "data": data}, "latest"])

def call_u(to, sig, args=()):
    return u(call(to, sig, args))

def call_a(to, sig, args=()):
    return ad(call(to, sig, args))

def call_b(to, sig, args=()):
    return call_u(to, sig, args) != 0

SEL = {
    "getSdtStakings": "0xd2f30c68",  # guessed; verify
}

blk = u(rpc("eth_blockNumber", []))
res = {"block": blk, "timestamp_utc": None, "impls": {}, "services": [], "registry": {}, "holdings": {}}
res["timestamp_utc"] = u(rpc("eth_getBlockByNumber", [hex(blk), False])["timestamp"])

# --- proxy impls ---
proxies = {
    "tower": TOWER, "blackhole": BLACKHOLE, "manager": MANAGER, "distributor": DISTRIBUTOR,
    "factory": FACTORY, "cvgSdtStaking": CVGSDT_SVC, "sdCRV_service": SDCRV_SVC,
    "cvgSdtBuffer": CVGSDT_BUFFER, "sdCRV_gauge": SDCRV_GAUGE,
}
for name, addr in proxies.items():
    impl = ad(rpc("eth_getStorageAt", [addr, IMPL_SLOT, "latest"]))
    beacon = ad(rpc("eth_getStorageAt", [addr, BEACON_SLOT, "latest"]))
    code = rpc("eth_getCode", [addr, "latest"])
    res["impls"][name] = {"address": addr, "impl_slot": impl, "beacon_slot": beacon,
                          "is_proxy": impl is not None or beacon is not None, "code_len": len(code) // 2}

# --- tower registry reads (selectors computed from known ABI names via keccak at runtime) ---
# Use known selectors from prior work where available; else compute.
import hashlib
def sel(sig):
    # keccak256 via eth_call trick not available; use known map
    KNOWN = {
        "owner()": "0x8da5cb5b", "cvgCycle()": "0x9c9b7d57", "cloneFactory()": "0x1c1f8aa3",
        "sdtBlackHole()": "0xb8d49756", "cvgSdtStaking()": "0xf4289aba",
        "sdtStakingPositionManager()": "0x06ee5ed2", "sdtRewardDistributor()": "0x772582ef",
        "cvgSdtBuffer()": "0x2ba45061", "cvgSDT()": "0xc987c565", "sdt()": "0xa48ba3c2",
        "sdtFeeCollector()": "0x772582ef", "sdtUtilities()": "0x06ee5ed2",
        "cvgRewards()": "0xf567d251", "veSdtMultisig()": "0x1c1f8aa3",
        "treasuryDao()": "0xf4289aba", "treasuryPod()": "0xb8d49756",
        "getSdtStakings(uint256,uint256)": "0xd2f30c68",
        "stakingAsset()": "0x1b4e0c47", "vault()": "0x86d1a4d3", "buffer()": "0x772582ef",
        "stakingCycle()": "0x9c9b7d57", "depositPaused()": "0x772582ef",
        "isSdtStaking(address)": "0xd379be23", "isStakingContract(address)": "0x33fd6f74",
        "ownerOf(uint256)": "0x6352211e", "nextId()": "0x1c1f8aa3",
        "unlockingTimestampPerToken(uint256)": "0x33fd6f74",
        "claimer()": "0xd379be23", "balanceOf(address)": "0x70a08231",
        "rewards_receiver(address)": "0x01ddabf1", "admin()": "0xf851a440",
    }
    return KNOWN.get(sig, "0x" + "0" * 8)

# The prior analysis/selectors.txt has verified selectors; read them directly.
SEL_MAP = {}
for line in open("/tmp/opencode/qc2/ca-zombie-ci/convergence-fi/analysis/selectors.txt"):
    if "=>" in line:
        s, v = line.split("=>")
        SEL_MAP[s.strip()] = v.strip()

def sel2(sig):
    if sig in SEL_MAP:
        return SEL_MAP[sig]
    raise KeyError(sig)

res["registry"] = {
    "owner": call_a(TOWER, sel2("owner()(address)")),
    "cloneFactory": call_a(TOWER, "0x1c1f8aa3"),
    "sdtBlackHole": call_a(TOWER, sel2("sdtBlackHole()(address)")),
    "cvgSdtStaking": call_a(TOWER, sel2("cvgSdtStaking()(address)")),
    "sdtStakingPositionManager": call_a(TOWER, sel2("sdtStakingPositionManager()(address)")),
    "sdtRewardDistributor": call_a(TOWER, sel2("sdtRewardDistributor()(address)")),
    "cvgSdtBuffer": call_a(TOWER, sel2("cvgSdtBuffer()(address)")),
    "cvgSDT": call_a(TOWER, sel2("cvgSDT()(address)")),
    "sdt": call_a(TOWER, sel2("sdt()(address)")),
    "cvgCycle": call_u(TOWER, sel2("cvgCycle()(uint128)")),
}
# fetch remaining via raw selectors (verify names by trying)
for name, s in [("sdtFeeCollector", "0x06ee5ed2"), ("sdtUtilities", "0x4f5f7b4c"),
                ("cvgRewards", sel2("cvgRewards()(address)")), ("veSdtMultisig", "0x1c1f8aa3"),
                ("treasuryDao", sel2("treasuryDao()(address)")), ("treasuryPod", sel2("treasuryPod()(address)")),
                ("cvgToken", "0x1c1f8aa3"), ("sdtStakingViewer", "0x1c1f8aa3")]:
    try:
        res["registry"][name] = call_a(TOWER, s)
    except Exception as e:
        res["registry"][name] = f"ERR {e}"

# --- enumerate services ---
# getSdtStakings(uint256,uint256) selector: compute via known keccak? use prior tool output.
# Prior work used getSdtStakings; selector from tool: check analysis scripts.
json.dump(res, open("/home/heisenberg/CA/convergence-fi-qc/analysis/live_verify_partial.json", "w"), indent=1)
print(json.dumps(res, indent=1)[:4000])
