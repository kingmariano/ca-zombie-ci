#!/usr/bin/env python3
"""Core Markets (Blast) — consolidated live-state snapshot, read-only.
Writes analysis/state_snapshot.json
"""
import json, urllib.request, subprocess, os, datetime

RPC = os.environ.get("BLAST_RPC_URL", "https://rpc.blast.io")
OUT = os.path.join(os.path.dirname(__file__), "state_snapshot.json")

def rpc_batch(calls, tries=3):
    payload = [{"jsonrpc":"2.0","id":i,"method":m,"params":p} for i,(m,p) in enumerate(calls)]
    last = None
    for t in range(tries):
        try:
            req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                headers={"Content-Type":"application/json","User-Agent":"research"})
            out = json.load(urllib.request.urlopen(req, timeout=120))
            return {r["id"]: r.get("result", r.get("error")) for r in out}
        except Exception as e:
            last = e
    raise last

def sel(sig):
    return subprocess.run(["cast","keccak",sig],capture_output=True,text=True).stdout.strip()[:10]

def pad(a): return a.lower().replace("0x","").rjust(64,"0")

ADDR = {
  "core_token":       "0x233b23de890a8c21f6198d03425a2b986ae05536",
  "xcore_vault":      "0xE659f8e705f86845e9de5c4d1e6f785697ac85e5",
  "xcore_rewarder":   "0x5cba6447894BC1D765A35300f1FBa3ab3a932b21",
  "team_vesting":     "0x9cD047D06A2daCf09cAC42324aD2b6cBa1CA8b44",
  "seed_vesting":     "0x769d266F54d407655cb6637AFe6b769f36FDfa0C",
  "advisor_vesting":  "0x6E7C824007D043CF5C57E5478264c9C28B1d7D6C",
  "lbp":              "0x9fb9af399c7E9bda57b89905c7D96091B895bfAe",
  "multi_account":    "0xd6ee1fd75d11989e57B57AA6Fd75f558fBf02a5e",
  "farm_multireward": "0xf1337755abe2f7bcac0b10736dc2b646c754a886",
  "emissions_keeper": "0xd8c1e4eac58ee0d9dd2763480adaeca43b06fe67",
  "treasury_safe":    "0xC793Bec2483465F9220852eeb614242e9a62C1d2",
  "symmio_diamond":   "0x3d17f073ccb9c3764f105550b0bcf9550477d266",
  "symm_executor":    "0x27ba1168a6df3681dd2f74c8f6dae165aab23229",
  "symmio_partyb":    "0xecbd0788bb5a72f9dfdac1ffeaaf9b7c2b26e456",
  "xcore_owner_eoa":  "0x395fadc41bacca22d69023310f2bfbf56afc9082",
  "team_owner_eoa":   "0xfe488b06ec2f26a9a23d4c1b14f7acfbbb62f6a7",
  "based_airdrop":    "0xb5d5375cce48bc2d9efcca0075a9c4f49ad20d00",
}
USDB = "0x4300000000000000000000000000000000000003"
CORE = ADDR["core_token"]

calls, labels = [], []
def add(label, to, data):
    labels.append(label); calls.append(("eth_call", [{"to": to, "data": data}, "latest"]))

add("block", "0x0000000000000000000000000000000000000000", "0x00")
calls[0] = ("eth_blockNumber", []); labels[0] = "block"

# balances
for name, a in ADDR.items():
    add(f"{name}.USDB", USDB, sel("balanceOf(address)") + pad(a))
    add(f"{name}.CORE", CORE, sel("balanceOf(address)") + pad(a))
    add(f"{name}.ETH", a, "0x00")  # placeholder replaced below

# fix ETH entries with getBalance
idx = 0
for i, l in enumerate(labels):
    if l.endswith(".ETH"):
        a = ADDR[l[:-4]]
        calls[i] = ("eth_getBalance", [a, "latest"])

# core token state
add("core_token.paused", CORE, sel("paused()"))
add("core_token.owner", CORE, sel("owner()"))
add("core_token.totalSupply", CORE, sel("totalSupply()"))
# vault state
V = ADDR["xcore_vault"]
add("xcore_vault.paused", V, sel("paused()"))
add("xcore_vault.owner", V, sel("owner()"))
add("xcore_vault.asset", V, sel("asset()"))
add("xcore_vault.totalAssets", V, sel("totalAssets()"))
add("xcore_vault.totalSupply", V, sel("totalSupply()"))
add("xcore_vault.withdrawFee", V, sel("withdrawFee()"))
add("xcore_vault.previewRedeem1e18", V, sel("previewRedeem(uint256)") + pad(hex(10**18)))
# rewarder
R = ADDR["xcore_rewarder"]
add("rewarder.owner", R, sel("owner()"))
add("rewarder.coreTrustedAddress", R, sel("coreTrustedAddress()"))
add("rewarder.startTimestamp", R, sel("startTimestamp()"))
add("rewarder.totalRewardSinceStart", R, sel("totalRewardSinceStart()"))
# team vesting
add("team_vesting.owner", ADDR["team_vesting"], sel("owner()"))
# lbp
L = ADDR["lbp"]
add("lbp.closed", L, sel("closed()"))
add("lbp.cancelled", L, sel("cancelled()"))
add("lbp.totalPurchased", L, sel("totalPurchased()"))
add("lbp.manager", L, sel("manager()"))
add("lbp.platform", L, sel("platform()"))
add("lbp.saleStart", L, sel("saleStart()"))
add("lbp.saleEnd", L, sel("saleEnd()"))
# multi account
M = ADDR["multi_account"]
add("multi_account.paused", M, sel("paused()"))
add("multi_account.symmioAddress", M, sel("symmioAddress()"))
add("multi_account.accountsAdmin", M, sel("accountsAdmin()"))
add("multi_account.saltCounter", M, sel("saltCounter()"))
# farm
F = ADDR["farm_multireward"]
add("farm.owner", F, sel("owner()"))
add("farm.totalSupply", F, sel("totalSupply()"))
add("farm.xCore", F, sel("xCore()"))
add("farm.rewardData.USDB", F, sel("rewardData(address)") + pad(USDB))
add("farm.rewardData.CORE", F, sel("rewardData(address)") + pad(CORE))
# emissions keeper
E = ADDR["emissions_keeper"]
add("emissions.owner", E, sel("owner()"))
add("emissions.thrustedCaller", E, sel("thrustedCaller()"))
add("emissions.coreTradeRewarder", E, sel("coreTradeRewarder()"))
add("emissions.coreMultiRewarder", E, sel("coreMultiRewarder()"))
# symmio
S = ADDR["symmio_diamond"]
add("symmio.collateral", S, sel("getCollateral()"))
add("symmio.nextBridgeId", S, "0x" + subprocess.run(["cast","keccak","getNextBridgeTransactionId()"],capture_output=True,text=True).stdout.strip()[2:10])
# executor
add("symm_executor.owner", ADDR["symm_executor"], sel("owner()"))
# treasury safe
add("treasury.threshold", ADDR["treasury_safe"], sel("getThreshold()"))

res = rpc_batch(calls)
# retry any errored calls individually
for i, l in enumerate(labels):
    v = res.get(i)
    if isinstance(v, dict) or v is None:
        r2 = rpc_batch([calls[i]])
        res[i] = r2.get(0)
block = int(res[0], 16)

ADDRESS_LABELS = {"owner","symmioAddress","accountsAdmin","asset","collateral","manager","platform",
                  "coreTrustedAddress","thrustedCaller","coreTradeRewarder","coreMultiRewarder","xCore",
                  "multi_account.symmioAddress","xcore_vault.owner","core_token.owner","rewarder.owner",
                  "team_vesting.owner","farm.owner","emissions.owner","symm_executor.owner",
                  "rewarder.coreTrustedAddress","emissions.thrustedCaller","emissions.coreTradeRewarder",
                  "emissions.coreMultiRewarder","farm.xCore","lbp.manager","lbp.platform",
                  "xcore_vault.asset","symmio.collateral","multi_account.accountsAdmin"}

def decode(l, v):
    if l == "block": return block
    if not isinstance(v, str):
        return v
    if l.endswith(".ETH"):
        try:
            return {"raw": v, "eth": int(v, 16) / 1e18}
        except Exception:
            return v
    if l in ADDRESS_LABELS:
        return "0x" + v[2:][24:] if len(v) == 66 else v
    if len(v) == 66:
        return int(v, 16)
    return v

snap = {
    "chain": "blast", "chain_id": 81457, "block": block,
    "block_time_utc": datetime.datetime.utcfromtimestamp(
        int(rpc_batch([("eth_getBlockByNumber", [hex(block), False])])[0]["timestamp"], 16)
    ).isoformat() + "Z",
    "rpc": RPC,
    "values": {},
    "notes": [
        "All values read at the recorded block; USDB is Blast native stablecoin (18 decimals).",
        "CORE spot price ~$0.0000157 (GeckoTerminal Thruster CORE/USDB pool 0x6634e5cf..., total pool reserve ~$36, token-wide DEX reserve ~$15).",
        "USDB price ~$0.99 (DefiLlama coins.llama.fi / GoldRush).",
    ],
}
for i, l in enumerate(labels):
    snap["values"][l] = decode(l, res.get(i))

# Derived numbers
v = snap["values"]
def wei(x): return x if isinstance(x, int) else 0
snap["derived"] = {
    "usdb_price_usd": 0.99,
    "core_price_usd": 0.000015734,
    "farm_usdb_usd": round(v["farm_multireward.USDB"] / 1e18 * 0.99, 2),
    "symmio_usdb_usd": round(v["symmio_diamond.USDB"] / 1e18 * 0.99, 2),
    "treasury_usdb_usd": round(v["treasury_safe.USDB"] / 1e18 * 0.99, 2),
    "core_nominal_usd": round(v["core_token.totalSupply"] / 1e18 * 0.000015734, 2),
}
json.dump(snap, open(OUT, "w"), indent=1)
print("block", block)
for k in sorted(v):
    if k == "block": continue
    print(f"{k:38} {v[k]}")
print(json.dumps(snap["derived"], indent=1))
