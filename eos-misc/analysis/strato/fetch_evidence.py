#!/usr/bin/env python3
"""STRATO (H2-05 deep-dive) evidence regeneration script.
Read-only: only eth_call / eth_getCode / GET endpoints on public STRATO Mercata
endpoints + DefiLlama public APIs. No transactions are signed or sent.
Outputs JSON evidence into ./raw/.
"""
import json, os, subprocess, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
os.makedirs(RAW, exist_ok=True)
os.makedirs(os.path.join(RAW, "abis"), exist_ok=True)

RPC = "https://noderpc.strato.nexus/rpc"
EXPL = "https://stratoscan.strato.nexus/api"
CIRRUS = "https://app.strato.nexus/cirrus/search"

def sh(args, timeout=60):
    r = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    return r.stdout

def curl(url, timeout=60):
    return sh(["curl", "-s", "--max-time", str(timeout), url])

def rpc(method, params):
    payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params})
    out = sh(["curl", "-s", "--max-time", "40", "-X", "POST", RPC,
              "-H", "Content-Type: application/json", "-d", payload])
    try:
        return json.loads(out)
    except Exception:
        return {"raw": out}

def eth_call(to, data, frm=None):
    obj = {"to": to, "data": data}
    if frm:
        obj["from"] = frm
    return rpc("eth_call", [obj, "latest"]).get("result", rpc("eth_call", [obj, "latest"]))

def selector(sig):
    return sh(["cast", "sig", sig]).strip()

def calldata(sig, args):
    out = sh(["cast", "calldata", sig] + args)
    return out.strip()

def save(name, obj):
    with open(os.path.join(RAW, name), "w") as f:
        json.dump(obj, f, indent=1)

# ---------------------------------------------------------------- 0. chain probes
probes = {}
probes["chainId"] = rpc("eth_chainId", []).get("result")
probes["blockNumber"] = rpc("eth_blockNumber", []).get("result")
probes["net_version"] = rpc("net_version", []).get("result")
probes["metadata"] = json.loads(curl("https://app.strato.nexus/strato-api/eth/v1.2/metadata"))
save("rpc_probes.json", probes)
print("[0] chain", probes["chainId"], "block", probes["blockNumber"])

# ---------------------------------------------------------------- 1. DefiLlama
try:
    req = urllib.request.Request("https://api.llama.fi/protocol/strato",
                                 headers={"User-Agent": "curl/8"})
    save("llama_protocol_strato.json", json.load(urllib.request.urlopen(req, timeout=90)))
    req = urllib.request.Request("https://api.llama.fi/protocol/strato-bridge",
                                 headers={"User-Agent": "curl/8"})
    save("llama_protocol_strato_bridge.json", json.load(urllib.request.urlopen(req, timeout=90)))
except Exception as e:
    print("llama detail err", e)

# provenance: matched entries from the DefiLlama protocols list
try:
    req = urllib.request.Request("https://api.llama.fi/protocols",
                                 headers={"User-Agent": "curl/8"})
    allp = json.load(urllib.request.urlopen(req, timeout=150))
    hits = []
    for p in allp:
        n = (p.get("name") or "").lower(); s = (p.get("slug") or "").lower()
        if any(k in n or k in s for k in ("strato", "bdex", "anubis")):
            hits.append({k: p.get(k) for k in
                         ["id", "name", "slug", "chain", "chains", "category", "tvl",
                          "deadUrl", "listedAt", "url", "module", "twitter", "deadFrom"]})
    save("llama_protocols_matches.json", hits)
    print("[1] llama matches", len(hits))
except Exception as e:
    print("llama list err", e)

# prices
try:
    toks = ("strato:0xcdc93d30182125e05eec985b631c7c61b3f63ff0,"
            "strato:0x2c59ef92d08efde71fe1a1cb5b45f4f6d48fcc94,"
            "strato:0x937efa7e3a77e20bbdbd7c0d32b6514f368c1010,"
            "strato:0x93fb7295859b2d70199e0a4883b7c320cf874e6c,"
            "strato:0x7a99b5ba11ac280cdd5caf52c12fe89fb1b8d2f9,"
            "ethereum:0x4c93b9fbf7fd1777ccbcbc538b1d0a8b58fb1ad6")
    req = urllib.request.Request("https://coins.llama.fi/prices/current/" + toks,
                                 headers={"User-Agent": "curl/8"})
    save("llama_prices_strato.json", json.load(urllib.request.urlopen(req, timeout=60)))
except Exception as e:
    print("llama prices err", e)

# adapters
for slug in ("strato", "strato-bridge"):
    txt = curl("https://raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters/main/projects/%s/index.js" % slug)
    with open(os.path.join(RAW, "adapter_%s.js" % slug.replace("-", "_")), "w") as f:
        f.write(txt)

# ---------------------------------------------------------------- 2. core state
USDST = "0x937efa7e3a77e20bbdbd7c0d32b6514f368c1010"
GOLDST = "0xcdc93d30182125e05eec985b631c7c61b3f63ff0"
SILVST = "0x2c59ef92d08efde71fe1a1cb5b45f4f6d48fcc94"
PSM = "0xb1efdc86eecfbedf83d0295671214fee451786f3"
ADMIN = "0x000000000000000000000000000000000000100c"
ORACLE = "0x0000000000000000000000000000000000001002"
CDP_ENGINE = "0x0000000000000000000000000000000000001011"
CDP_VAULT = "0x0000000000000000000000000000000000001013"
LENDING_POOL = "0x0000000000000000000000000000000000001005"
SAVE = "0x22550671fcad04a213697ac7ae4f4366e96446ed"
STAKE = "0xf30a022ce83bed7adeafc286c719388dcc3b3988"
BRIDGE = "0x0000000000000000000000000000000000001008"
NBRIDGE = "0x4d9e9c39180a75091b9c35bbb9064d67c7fdde5a"

def rd(to, sig):
    d = selector(sig)
    r = eth_call(to, d)
    return r

state = {}
components = [
    (USDST, ["totalSupply()", "owner()", "paused()"]),
    (ADMIN, ["owner()", "defaultVotingThresholdBps()"]),
    (ORACLE, ["owner()", "queueSize()"]),
    ("0x0000000000000000000000000000000000001012", ["cdpVault()", "cdpEngine()", "usdst()", "priceOracle()"]),
    (CDP_ENGINE, ["totalDebtAll()", "collateralAssetCount()", "globalPaused()"]),
    (LENDING_POOL, ["owner()", "paused()", "totalScaledDebt()", "borrowIndex()", "badDebt()"]),
    (PSM, ["owner()", "mintPaused()", "burnPaused()"]),
    (SAVE, ["owner()", "totalAssets()", "totalSupply()", "paused()"]),
    ("0x0000000000000000000000000000000000001015", ["owner()", "totalAssets()"]),
    (STAKE, ["owner()", "totalUserStake()", "totalSelfBond()", "totalUnbonding()"]),
    ("0x000000000000000000000000000000000000100a", ["owner()", "swapFeeRate()", "lpSharePercent()"]),
    ("0x5d630126d908b46bcf8d00bc15e591a459375809", ["owner()"]),
    ("0x34bc729f66106a146b0864e673a3571b28fa23e1", ["owner()", "botExecutor()", "paused()"]),
    (BRIDGE, ["owner()", "withdrawalCounter()", "depositsPaused()", "withdrawalsPaused()"]),
    (NBRIDGE, ["owner()", "bridgeOperator()", "guardian()", "custodyVault()"]),
]
for to, sigs in components:
    for sig in sigs:
        r = rd(to, sig)
        key = "%s.%s" % (to, sig)
        if isinstance(r, str) and len(r) == 66:
            v = r
            if "(" in sig and sig.split("(")[0] in (
                    "owner", "cdpVault", "cdpEngine", "usdst", "priceOracle", "botExecutor",
                    "bridgeOperator", "guardian", "custodyVault"):
                v = "0x" + r[-40:]
            elif r == "0x" + "0" * 64:
                v = "0"
            else:
                v = str(int(r, 16))
        else:
            v = r
        state[key] = v
        time.sleep(0.15)
save("state_components.json", state)
print("[2] state components", len(state))

# oracle reads
oracle = {}
for sym, a in [("GOLDST", GOLDST), ("SILVST", SILVST), ("USDST", USDST),
               ("ETH", "0x93fb7295859b2d70199e0a4883b7c320cf874e6c"),
               ("WBTC", "0x7a99b5ba11ac280cdd5caf52c12fe89fb1b8d2f9")]:
    p = eth_call(ORACLE, selector("getAssetPrice(address)") + a[2:].rjust(64, "0"))
    pt = eth_call(ORACLE, selector("getAssetPriceWithTimestamp(address)") + a[2:].rjust(64, "0"))
    oracle[sym] = {"price_raw": p, "price_with_ts_raw": pt}
    time.sleep(0.15)
save("oracle_reads.json", oracle)
print("[3] oracle", list(oracle))

# CDP params for GOLDST
cp = eth_call(CDP_ENGINE, selector("collateralParams(address)") + GOLDST[2:].rjust(64, "0"))
td = eth_call(CDP_ENGINE, selector("totalDebt(address)") + GOLDST[2:].rjust(64, "0"))
save("cdp_params.json", {"collateralParams_GOLDST": cp, "totalDebt_GOLDST": td})
print("[4] cdp params")

# ---------------------------------------------------------------- 3. Cirrus balances
def cirrus(table, params):
    return curl("%s/%s?%s" % (CIRRUS, table, params), timeout=60)

holders = {
    "CDPVault": "0000000000000000000000000000000000001013",
    "LiquidityPool": "0000000000000000000000000000000000001004",
    "CollateralVault": "0000000000000000000000000000000000001003",
    "PSM": "b1efdc86eecfbedf83d0295671214fee451786f3",
    "SafetyModule": "0000000000000000000000000000000000001015",
    "SaveVault": "22550671fcad04a213697ac7ae4f4366e96446ed",
    "botExecutor": "3f5c7de300b7940e46459ed9a8b098f9a8cc2dfb",
    "NativeCustodyVault": "db967ac5c497e6a2bd6f89036d2b63851760318f",
}
bal = {}
for name, a in holders.items():
    txt = cirrus("BlockApps-Token-_balances", "key=eq.%s&value=gt.0&select=address,value&limit=200" % a)
    try:
        bal[name] = json.loads(txt)
    except Exception:
        bal[name] = {"error": txt[:200]}
    time.sleep(0.4)
save("cirrus_holder_balances.json", bal)
print("[5] balances", {k: len(v) if isinstance(v, list) else "err" for k, v in bal.items()})

# admins + whitelist
adm = cirrus("BlockApps-AdminRegistry-admins", "address=eq.000000000000000000000000000000000000100c&limit=50")
wl = cirrus("BlockApps-AdminRegistry-whitelist", "address=eq.000000000000000000000000000000000000100c&limit=500")
try:
    save("cirrus_admins_100c.json", json.loads(adm))
except Exception:
    save("cirrus_admins_100c.json", adm)
try:
    save("cirrus_whitelist_100c.json", json.loads(wl))
except Exception:
    save("cirrus_whitelist_100c.json", wl)
print("[6] admins/whitelist saved")

# token metadata for the main tokens
meta = cirrus("BlockApps-Token",
              "address=in.(cdc93d30182125e05eec985b631c7c61b3f63ff0,2c59ef92d08efde71fe1a1cb5b45f4f6d48fcc94,"
              "937efa7e3a77e20bbdbd7c0d32b6514f368c1010,93fb7295859b2d70199e0a4883b7c320cf874e6c,"
              "7a99b5ba11ac280cdd5caf52c12fe89fb1b8d2f9,2ca3e170e6714282da77815f7864b17f612f5f83,"
              "6aeacaa19c68e53035bf495d15e0a328fc600ba8,5ed0bdfb378ac0d06249d70759536d7a41906216,"
              "c6c3e9881665d53ae8c222e24ca7a8d069aa56ca,6e2d93d323edf1b3cc4672a909681b6a430cae64)&select=address,_name,_symbol,customDecimals&limit=50")
try:
    save("cirrus_token_meta.json", json.loads(meta))
except Exception:
    save("cirrus_token_meta.json", meta)
print("[7] token meta saved")

# ---------------------------------------------------------------- 4. ABIs
abi_addrs = [USDST, ADMIN, ORACLE, CDP_ENGINE, CDP_VAULT, LENDING_POOL, PSM, SAVE, STAKE,
             BRIDGE, NBRIDGE, "0x000000000000000000000000000000000000100a",
             "0x5d630126d908b46bcf8d00bc15e591a459375809",
             "0x34bc729f66106a146b0864e673a3571b28fa23e1",
             "0x0000000000000000000000000000000000001012",
             "0x0000000000000000000000000000000000001007",
             "0x0000000000000000000000000000000000001014",
             "0x0000000000000000000000000000000000001015",
             "0xdb967ac5c497e6a2bd6f89036d2b63851760318f",
             "0x1cc5bad32dc8667878fa7c53cc5cfd6e76fdb113"]
for a in abi_addrs:
    try:
        out = curl("%s?module=contract&action=getabi&address=%s" % (EXPL, a))
        save("abis/%s.json" % a, json.loads(out))
    except Exception as e:
        save("abis/%s.json" % a, {"error": str(e)})
    time.sleep(0.3)
print("[8] abis saved")

# ---------------------------------------------------------------- 5. gating tests
ATT = "0x1111111111111111111111111111111111111111"
gating = {}
tests = [
    ("USDST.mint(att,1e18)", USDST, "mint(address,uint256)", [ATT, "1000000000000000000"]),
    ("USDST.setLogicContract(att)", USDST, "setLogicContract(address)", [ATT]),
    ("USDST.pause()", USDST, "pause()", []),
    ("GOLDST.mint(att,1e18)", GOLDST, "mint(address,uint256)", [ATT, "1000000000000000000"]),
    ("Oracle.setAssetPrice(GOLDST,1e18)", ORACLE, "setAssetPrice(address,uint256)", [GOLDST, "1000000000000000000"]),
    ("PSM.pauseMint()", PSM, "pauseMint()", []),
    ("PSM.setMintEnabled(USDC,false)", PSM, "setMintEnabled(address,bool)",
     ["0x6aeacaa19c68e53035bf495d15e0a328fc600ba8", "false"]),
    ("CDPEngine.setPausedGlobal(true)", CDP_ENGINE, "setPausedGlobal(bool)", ["true"]),
    ("CDPReserve.transferTo(att,1e18)", "0x0000000000000000000000000000000000001014",
     "transferTo(address,uint256)", [ATT, "1000000000000000000"]),
    ("LendingPool.pause()", LENDING_POOL, "pause()", []),
    ("PoolFactory.updatePoolImplementation()", "0x000000000000000000000000000000000000100a",
     "updatePoolImplementation()", []),
    ("Staking.setParams(0,0,0,0)", STAKE, "setParams(uint256,uint256,uint256,uint256)", ["0", "0", "0", "0"]),
    ("SaveVault.setPerSecondSavingsRate(2e18)", SAVE, "setPerSecondSavingsRate(uint256)",
     ["2000000000000000000"]),
    ("VaultBot.setBotExecutor(att)", "0x34bc729f66106a146b0864e673a3571b28fa23e1",
     "setBotExecutor(address)", [ATT]),
    ("MercataBridge.confirmWithdrawal(742,x)", BRIDGE, "confirmWithdrawal(uint256,string)", ["742", "x"]),
    ("NativeBridge.confirmDeposit(1,att,1e18)", NBRIDGE, "confirmDeposit(uint256,address,uint256)",
     ["1", ATT, "1000000000000000000"]),
    ("AdminRegistry.addAdmin(att)", ADMIN, "addAdmin(address)", [ATT]),
]
for name, to, sig, args in tests:
    data = calldata(sig, args)
    r = rpc("eth_call", [{"from": ATT, "to": to, "data": data}, "latest"])
    gating[name] = r
    time.sleep(0.2)
save("gating_tests_randomsender.json", gating)
print("[9] gating tests", len(gating))

# ---------------------------------------------------------------- 6. free-money sims
fm = {}
sims = [
    ("LendingPool.borrow(1e18)", LENDING_POOL, "borrow(uint256)", ["1000000000000000000"]),
    ("LendingPool.withdrawCollateral(USDC,1e18)", LENDING_POOL, "withdrawCollateral(address,uint256)",
     ["0x6aeacaa19c68e53035bf495d15e0a328fc600ba8", "1000000000000000000"]),
    ("SaveVault.redeem(1e18,att,att)", SAVE, "redeem(uint256,address,address)",
     ["1000000000000000000", ATT, ATT]),
    ("Staking.unstake(att,1e18)", STAKE, "unstake(address,uint256)", [ATT, "1000000000000000000"]),
    ("SafetyModule.redeem(1e18,0)", "0x0000000000000000000000000000000000001015",
     "redeem(uint256,uint256)", ["1000000000000000000", "0"]),
    ("PSM.mint(1e18,ATT)", PSM, "mint(uint256,address)", ["1000000000000000000", ATT]),
    ("CDPEngine.mint(GOLDST,1e18)", CDP_ENGINE, "mint(address,uint256)",
     [GOLDST, "1000000000000000000"]),
    ("MercataBridge.requestWithdrawal(1,att,att,att,1e18)", BRIDGE,
     "requestWithdrawal(uint256,address,address,address,uint256)",
     ["1", ATT, ATT, ATT, "1000000000000000000"]),
]
for name, to, sig, args in sims:
    data = calldata(sig, args)
    r = rpc("eth_call", [{"from": ATT, "to": to, "data": data}, "latest"])
    fm[name] = r
    time.sleep(0.2)
save("freemoney_sims.json", fm)
print("[10] free-money sims", len(fm))

# ---------------------------------------------------------------- 7. code types
types = {}
for name, a in {
    "admin1": "0x7630b673862a2807583834908f10192e00c58b00",
    "admin2": "0x292dd9591f506845ef05a9f3b8116e641cbcb4bb",
    "admin3": "0xf1ba16a6cfb2a17fb34ad477eaaf0c76eac64f14",
    "pricebot1": "0x523fef378674d39363aa8b6ac5122e301c528432",
    "pricebot2": "0x96714c4a2163a3ee55356e20bc23fe8ea5e7aaf0",
    "bridgeOp": "0x882f3d3a7b97ea24ab5aeae6996a695b26ea9089",
    "botExecutor": "0x3f5c7de300b7940e46459ed9a8b098f9a8cc2dfb",
    "usdst_minter_contract": "0x390ba7f7807c97f134f25c8462c65c353e55c177",
    "custodyVault": "0xdb967ac5c497e6a2bd6f89036d2b63851760318f",
}.items():
    types[name] = {"address": a, "eth_getCode": rpc("eth_getCode", [a, "latest"]).get("result")}
    time.sleep(0.15)
save("code_types.json", types)
print("[11] code types")

# final block
final = rpc("eth_blockNumber", []).get("result")
save("snapshot_block.json", {"block_hex": final, "block_dec": int(final, 16)})
print("DONE. final block", final, int(final, 16))
