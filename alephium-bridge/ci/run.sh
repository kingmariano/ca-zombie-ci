#!/usr/bin/env bash
# Alephium Bridge — Phase-2 CI live-state dump (read-only, no secrets in output).
# Writes ci-out/live_state.json. RPC URLs come from env (never echoed).
set -u
cd "$(dirname "$0")/.." || exit 1
mkdir -p ci-out

ETH="${FORK_RPC_URL:-${RPC_URL:-https://ethereum-rpc.publicnode.com}}"
BSC="${BSC_RPC_URL:-https://bsc-rpc.publicnode.com}"

ETH_BRIDGE=0x579a3bDE631c3d8068CbFE3dc45B0F14EC18dD43
ETH_CORE=0x01e82b67367dE9f805E55de730D5007a752912A8
WALPH=0x590F820444fA3638e022776752c5eEF34E2F89A6
USDT=0xdAC17F958D2ee523a2206206994597C13D831ec7
USDC=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
WBTC=0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599
WETH=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
BSC_BRIDGE=0x2971F580C34d3D584e0342741c6a622f69424dD8
BSC_CORE=0xE674e61111ecE5988113DA56f0b2Cc3CB22D5304
BSC_WALPH=0x8683BA2F8b0f69b2105f26f488bADe1d3AB4dec8
WBNB=0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
BSC_USDT=0x55d398326f99059fF775485246999027B3197955
BSC_USDC=0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d

call() { cast call "$1" "$2" $3 --rpc-url "$4" 2>/dev/null | head -1; }

python3 - "$ETH" "$BSC" <<'PYEOF'
import json, subprocess, sys, urllib.request, datetime
eth, bsc = sys.argv[1], sys.argv[2]

def sh(*args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=60).stdout.strip()
    except Exception:
        return ""

def call(rpc, addr, sig, extra=[]):
    r = sh("cast", "call", addr, sig, *extra, "--rpc-url", rpc)
    return r.split()[0] if r else ""

def get(url, timeout=25):
    req = urllib.request.Request(url, headers={"User-Agent": "zombie-ci/1.0"})
    return json.loads(urllib.request.urlopen(req, timeout=timeout).read())

out = {"generated_utc": datetime.datetime.utcnow().isoformat() + "Z"}

# ---- ETH ----
out["eth_block"] = sh("cast", "block-number", "--rpc-url", eth)
out["eth_bridge"] = {
    "address": "0x579a3bDE631c3d8068CbFE3dc45B0F14EC18dD43",
    "chainId": call(eth, "0x579a3bDE631c3d8068CbFE3dc45B0F14EC18dD43", "chainId()(uint16)"),
    "usdt": call(eth, "0xdAC17F958D2ee523a2206206994597C13D831ec7", "balanceOf(address)(uint256)", ["0x579a3bDE631c3d8068CbFE3dc45B0F14EC18dD43"]),
    "usdc": call(eth, "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", "balanceOf(address)(uint256)", ["0x579a3bDE631c3d8068CbFE3dc45B0F14EC18dD43"]),
    "wbtc": call(eth, "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599", "balanceOf(address)(uint256)", ["0x579a3bDE631c3d8068CbFE3dc45B0F14EC18dD43"]),
    "weth": call(eth, "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", "balanceOf(address)(uint256)", ["0x579a3bDE631c3d8068CbFE3dc45B0F14EC18dD43"]),
    "native_eth": sh("cast", "balance", "0x579a3bDE631c3d8068CbFE3dc45B0F14EC18dD43", "--rpc-url", eth),
    "guardian_set_index": call(eth, "0x01e82b67367dE9f805E55de730D5007a752912A8", "getCurrentGuardianSetIndex()(uint32)"),
    "guardian_set_0": call(eth, "0x01e82b67367dE9f805E55de730D5007a752912A8", "getGuardianSet(uint32)((address[],uint32))", ["0"]),
    "impl_slot": sh("cast", "storage", "0x579a3bDE631c3d8068CbFE3dc45B0F14EC18dD43", "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc", "--rpc-url", eth),
}
out["walph_token"] = {
    "address": "0x590F820444fA3638e022776752c5eEF34E2F89A6",
    "totalSupply": call(eth, "0x590F820444fA3638e022776752c5eEF34E2F89A6", "totalSupply()(uint256)"),
    "stuck_walph_self": call(eth, "0x590F820444fA3638e022776752c5eEF34E2F89A6", "balanceOf(address)(uint256)", ["0x590F820444fA3638e022776752c5eEF34E2F89A6"]),
    "stuck_usdt": call(eth, "0xdAC17F958D2ee523a2206206994597C13D831ec7", "balanceOf(address)(uint256)", ["0x590F820444fA3638e022776752c5eEF34E2F89A6"]),
    "owner": call(eth, "0x590F820444fA3638e022776752c5eEF34E2F89A6", "owner()(address)"),
}

# ---- BSC ----
out["bsc_block"] = sh("cast", "block-number", "--rpc-url", bsc)
out["bsc_bridge"] = {
    "address": "0x2971F580C34d3D584e0342741c6a622f69424dD8",
    "chainId": call(bsc, "0x2971F580C34d3D584e0342741c6a622f69424dD8", "chainId()(uint16)"),
    "wbnb": call(bsc, "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c", "balanceOf(address)(uint256)", ["0x2971F580C34d3D584e0342741c6a622f69424dD8"]),
    "usdt": call(bsc, "0x55d398326f99059fF775485246999027B3197955", "balanceOf(address)(uint256)", ["0x2971F580C34d3D584e0342741c6a622f69424dD8"]),
    "usdc": call(bsc, "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d", "balanceOf(address)(uint256)", ["0x2971F580C34d3D584e0342741c6a622f69424dD8"]),
    "guardian_set_index": call(bsc, "0xE674e61111ecE5988113DA56f0b2Cc3CB22D5304", "getCurrentGuardianSetIndex()(uint32)"),
    "guardian_set_0": call(bsc, "0xE674e61111ecE5988113DA56f0b2Cc3CB22D5304", "getGuardianSet(uint32)((address[],uint32))", ["0"]),
    "impl_slot": sh("cast", "storage", "0x2971F580C34d3D584e0342741c6a622f69424dD8", "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc", "--rpc-url", bsc),
}
out["bsc_walph"] = {
    "address": "0x8683BA2F8b0f69b2105f26f488bADe1d3AB4dec8",
    "totalSupply": call(bsc, "0x8683BA2F8b0f69b2105f26f488bADe1d3AB4dec8", "totalSupply()(uint256)"),
    "owner": call(bsc, "0x8683BA2F8b0f69b2105f26f488bADe1d3AB4dec8", "owner()(address)"),
}

# ---- Alephium custody (explorer backend, public) ----
cust = "226T1XspViny5o6Ce1jQR6UCGrDXuq5NBVoCFNufMEWBZ"
try:
    bal = get(f"https://backend.mainnet.alephium.org/addresses/{cust}")["balance"]
    out["alephium_custody"] = {"address": cust, "attoAlph": bal, "alph": int(bal) / 1e18}
except Exception as e:
    out["alephium_custody"] = {"address": cust, "error": str(e)[:120]}

# ---- USD valuation ----
try:
    px = get("https://coins.llama.fi/prices/current/coingecko:alephium,ethereum:0xdAC17F958D2ee523a2206206994597C13D831ec7,ethereum:0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,ethereum:0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,ethereum:0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,bsc:0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c")["coins"]
    out["prices"] = {k.split(":")[-1]: v["price"] for k, v in px.items()}

    def f(x):
        try:
            return float(x) if x else 0.0
        except Exception:
            return 0.0
    p_alph = px["coingecko:alephium"]["price"]
    usd = {
        "eth_bridge": f(out["eth_bridge"]["usdt"]) / 1e6 * px["ethereum:0xdAC17F958D2ee523a2206206994597C13D831ec7"]["price"]
        + f(out["eth_bridge"]["usdc"]) / 1e6 * px["ethereum:0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"]["price"]
        + f(out["eth_bridge"]["wbtc"]) / 1e8 * px["ethereum:0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599"]["price"]
        + f(out["eth_bridge"]["weth"]) / 1e18 * px["ethereum:0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"]["price"]
        + f(out["eth_bridge"]["native_eth"]) / 1e18 * px["ethereum:0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"]["price"],
        "bsc_bridge": f(out["bsc_bridge"]["wbnb"]) / 1e18 * px["bsc:0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"]["price"]
        + f(out["bsc_bridge"]["usdt"]) / 1e18 * px["ethereum:0xdAC17F958D2ee523a2206206994597C13D831ec7"]["price"]
        + f(out["bsc_bridge"]["usdc"]) / 1e18 * px["ethereum:0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"]["price"],
        "alephium_custody": out.get("alephium_custody", {}).get("alph", 0) * p_alph,
        "stuck_at_walph_token": f(out["walph_token"]["stuck_walph_self"]) / 1e18 * p_alph
        + f(out["walph_token"]["stuck_usdt"]) / 1e6 * px["ethereum:0xdAC17F958D2ee523a2206206994597C13D831ec7"]["price"],
    }
    usd["total_bridge_custody"] = usd["eth_bridge"] + usd["bsc_bridge"] + usd["alephium_custody"]
    out["usd"] = {k: round(v, 2) for k, v in usd.items()}
except Exception as e:
    out["prices_error"] = str(e)[:200]

with open("ci-out/live_state.json", "w") as fh:
    json.dump(out, fh, indent=1)
print(json.dumps(out, indent=1)[:4000])
PYEOF
echo "[ci] live_state written to ci-out/live_state.json"
exit 0
