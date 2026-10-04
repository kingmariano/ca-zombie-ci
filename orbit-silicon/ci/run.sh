#!/usr/bin/env bash
# CI custom job: capture a timestamped live-state snapshot of Orbit/Silicon.
# Read-only RPC calls; results written to ci-out/live_state.json (uploaded as artifact).
set -euo pipefail
mkdir -p ci-out
python3 - <<'PY' | tee ci-out/live_state.json
import json, urllib.request, datetime

SILICON = "https://rpc.silicon.network"
ETH = "https://ethereum-rpc.publicnode.com"

def rpc(url, method, params, timeout=40):
    req = urllib.request.Request(
        url, data=json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "zombie-ci/1.0"})
    return json.load(urllib.request.urlopen(req, timeout=timeout))["result"]

def call(url, to, data):
    return rpc(url, "eth_call", [{"to": to, "data": data}, "latest"])

def u(x):
    return int(x, 16) if x and x != "0x" else 0

out = {"captured_at_utc": datetime.datetime.utcnow().isoformat() + "Z"}

# --- Silicon L2 ---
sb = int(rpc(SILICON, "eth_blockNumber", []), 16)
out["silicon_block"] = sb
blk = rpc(SILICON, "eth_getBlockByNumber", [hex(sb), False])
out["silicon_block_time"] = int(blk["timestamp"], 16)

VOTING = "0x33fa9a4f2C06de9bD80A34663C72C797E257D3d9"
ORC    = "0x37908ffdEf18aDD36518e781a9a77C2C6f4A4260"
L2B    = "0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe"
out["voting_totalStaking"] = str(u(call(SILICON, VOTING, "0x165defa4")))
out["voting_totalPending"] = str(u(call(SILICON, VOTING, "0x3f90916a")))
out["orc_l2_totalSupply"] = str(u(call(SILICON, ORC, "0x18160ddd")))
out["orc_balance_voting"] = str(u(call(SILICON, ORC, "0x70a08231" + VOTING[2:].lower().rjust(64, "0"))))
out["l2_bridge_networkID"] = u(call(SILICON, L2B, "0xbab161bf"))
out["l2_bridge_depositCount"] = u(call(SILICON, L2B, "0x2dfdf0b5"))
# wrapped supplies
wrapped = {
    "USDC": ("0xa8ce8aee21bc2a48a5ef670afcc9274c7bbbc035", 6),
    "USDT": ("0x1e4a5963abfd975d8c9021ce480b42188849d41d", 6),
    "WBTC": ("0xea034fb02eb1808c2cc3adbc15f447b93cbe08e1", 8),
    "DAI":  ("0xc5015b9d9161dca7e18e32f6f25c4ad850731fd4", 18),
    "ORC":  (ORC, 18),
}
out["l2_wrapped_supply"] = {}
for sym, (addr, dec) in wrapped.items():
    out["l2_wrapped_supply"][sym] = u(call(SILICON, addr, "0x18160ddd")) / 10**dec
# net ETH bridged = 2^128 - balance (CDK gas-token pre-mint)
ethbal = u(rpc(SILICON, "eth_getBalance", [L2B, "latest"]))
out["l2_bridge_eth_net_bridged"] = (2**128 - ethbal) / 1e18 if ethbal > 2**127 else ethbal / 1e18

# --- Ethereum L1 ---
eb = int(rpc(ETH, "eth_blockNumber", []), 16)
out["ethereum_block"] = eb
L1B = "0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe"
tokens = {
    "USDC": ("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", 6),
    "USDT": ("0xdAC17F958D2ee523a2206206994597C13D831ec7", 6),
    "WBTC": ("0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599", 8),
    "DAI":  ("0x6B175474E89094C44Da98b954EedeAC495271d0F", 18),
    "ORC":  ("0x662b67d00A13FAf93254714DD601F5Ed49Ef2F51", 18),
}
out["l1_shared_bridge_balances"] = {}
for sym, (addr, dec) in tokens.items():
    out["l1_shared_bridge_balances"][sym] = u(call(ETH, addr, "0x70a08231" + L1B[2:].lower().rjust(64, "0"))) / 10**dec
out["l1_shared_bridge_eth"] = u(rpc(ETH, "eth_getBalance", [L1B, "latest"])) / 1e18
out["l1_bridge_emergency"] = bool(u(call(ETH, L1B, "0x15064c96")))

print(json.dumps(out, indent=2))
PY
echo "[ci] live_state.json written"
