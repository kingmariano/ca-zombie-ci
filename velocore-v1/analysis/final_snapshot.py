#!/usr/bin/env python3
"""Final live-state snapshot of Velocore V1 (zkSync Era) at an explicit block."""
import json, subprocess, urllib.request, datetime, sys

RPC = "https://mainnet.era.zksync.io"
BLOCK = sys.argv[1] if len(sys.argv) > 1 else "latest"

ADDR = {
    "VC": "0x85D84c774CF8e9fF85342684b0E795Df72A24908",
    "Voter": "0xe09A60FAe6d77658b9767A70e2f361b46Dd3f16A",
    "VotingEscrow": "0xbdE345771Eb0c6adEBc54F41A169ff6311fE096F",
    "RewardsDistributor": "0xD7107a47B4fBBc585b25BbEe3777B2EDC11D156C",
    "Minter": "0x8f0b4B3e211c84061ab5959Bd3D49C6B3EeC1d7D",
    "PairFactory_off": "0xE140EaC2bB748c8F456719a457F26636617Bb0E9",
    "PairFactory_old": "0xF5719b1Ea3C9bF6491E22C49379E31060d0FbFc1",
    "Pool_USDC_WETH_F2": "0xcD52cbc975fbB802F82A1F92112b1250b5a997Df",
    "Pool_USDC_WETH_F1": "0xA203424645D35C9B82B42E0303eC1867aBFAC3fA",
    "Gauge_USDC_WETH": "0xb3120Ad6C3285fc4E422581d9ad003277802CC47",
    "V2_Vault_zkSync": "0xf5E67261CB357eDb6C7719fEFAFaaB280cB5E2A6",
    "USDC": "0x3355df6D4c9C3035724Fd0e3914dE96A5a83aaf4",
    "WETH": "0x5AEa5775959fBC2557Cc8789bC1bf90A239D9a91",
    "OldWETH": "0x99cd063A128A35b44b9Fb4ce4b479f8247baF746",
}

def call(to, sig, *args):
    cmd = ["cast", "call", to, sig, *[str(a) for a in args], "--rpc-url", RPC, "--block", str(BLOCK)]
    p = subprocess.run(cmd, capture_output=True, text=True)
    return p.stdout.strip().split()[0] if p.returncode == 0 and p.stdout.strip() else None

def bal(token, who):
    v = call(token, "balanceOf(address)(uint256)", who)
    return int(v) if v and v.isdigit() else None

out = {"block": BLOCK, "captured_utc": datetime.datetime.utcnow().isoformat() + "Z", "state": {}}
s = out["state"]
s["voter_vc_balance"] = bal(ADDR["VC"], ADDR["Voter"])
s["escrow_vc_balance"] = bal(ADDR["VC"], ADDR["VotingEscrow"])
s["rewards_distributor_vc_balance"] = bal(ADDR["VC"], ADDR["RewardsDistributor"])
s["voter_totalWeight"] = call(ADDR["Voter"], "totalWeight()(uint256)")
s["voter_length_gauges"] = call(ADDR["Voter"], "length()(uint256)")
s["voter_governor"] = call(ADDR["Voter"], "governor()(address)")
s["minter_weekly"] = call(ADDR["Minter"], "weekly()(uint256)")
s["minter_active_period"] = call(ADDR["Minter"], "active_period()(uint256)")
s["vc_totalSupply"] = call(ADDR["VC"], "totalSupply()(uint256)")
s["vc_minter"] = call(ADDR["VC"], "minter()(address)")
s["factory_off_pairs"] = call(ADDR["PairFactory_off"], "allPairsLength()(uint256)")
s["factory_old_pairs"] = call(ADDR["PairFactory_old"], "allPairsLength()(uint256)")
s["pool_f2_usdc"] = bal(ADDR["USDC"], ADDR["Pool_USDC_WETH_F2"])
s["pool_f2_weth"] = bal(ADDR["WETH"], ADDR["Pool_USDC_WETH_F2"])
s["pool_f1_usdc"] = bal(ADDR["USDC"], ADDR["Pool_USDC_WETH_F1"])
s["pool_f1_oldweth"] = bal(ADDR["OldWETH"], ADDR["Pool_USDC_WETH_F1"])
s["gauge_usdcweth_vc"] = bal(ADDR["VC"], ADDR["Gauge_USDC_WETH"])
s["gauge_usdcweth_isAlive"] = call(ADDR["Voter"], "isAlive(address)(bool)", ADDR["Gauge_USDC_WETH"])
s["gauge_usdcweth_staked_lp"] = call(ADDR["Gauge_USDC_WETH"], "totalSupply()(uint256)")
s["v2_vault_eth_wei"] = subprocess.run(["cast", "balance", ADDR["V2_Vault_zkSync"], "--rpc-url", RPC, "--block", str(BLOCK)],
                                       capture_output=True, text=True).stdout.strip()
# token prices
try:
    url = ("https://coins.llama.fi/prices/current/era:0x5aea5775959fbc2557cc8789bc1bf90a239d9a91,"
           "era:0x3355df6d4c9c3035724fd0e3914de96a5a83aaf4")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=25) as r:
        out["prices"] = {k: v.get("price") for k, v in json.loads(r.read()).get("coins", {}).items()}
except Exception as e:
    out["prices_error"] = str(e)[:80]
try:
    req = urllib.request.Request("https://api.dexscreener.com/latest/dex/tokens/" + ADDR["VC"],
                                 headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=25) as r:
        ds = json.loads(r.read())
    out["vc_dex"] = [{"dex": p.get("dexId"), "pair": p.get("pairAddress"), "priceUsd": p.get("priceUsd"),
                      "liqUsd": (p.get("liquidity") or {}).get("usd"), "vol24h": (p.get("volume") or {}).get("h24")}
                     for p in (ds.get("pairs") or [])]
except Exception as e:
    out["vc_dex_error"] = str(e)[:80]

json.dump(out, open("/home/heisenberg/CA/velocore-v1/analysis/live_state_final.json", "w"), indent=1)
print(json.dumps(out, indent=1))
