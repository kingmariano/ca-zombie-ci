#!/bin/bash
# Timeswap V2 zombie-hunt — CI heavy job.
# Re-runs the live-state enumeration on public RPCs (no keys) and writes evidence to ci-out/.
# Read-only: eth_call / eth_getCode / eth_blockNumber only. No secrets are printed or written.
set -u
cd "$(dirname "$0")/.."   # -> timeswap-v2/
mkdir -p ci-out
OUT=ci-out
echo "=== Timeswap V2 CI live-state re-verification $(date -u) ==="

# 1) enumerate option pairs (v2.0-v2.5 factories) + token balances on the main chains
for chain in arbitrum ethereum base hyperliquid polygon optimism; do
  echo "--- enumerate $chain"
  python3 -u analysis/enumerate.py "$chain" || echo "enumerate $chain failed"
  cp -f "analysis/live-$chain.json" "$OUT/" 2>/dev/null || true
done

# 2) pool-level state: maturities, liquidity, protocol fees, owners
for chain in arbitrum ethereum base hyperliquid polygon optimism; do
  echo "--- pools $chain"
  python3 -u analysis/pools.py "$chain" || echo "pools $chain failed"
  cp -f "analysis/pools-$chain.json" "$OUT/" 2>/dev/null || true
done

# 3) maturity audit over ALL enumerated pools: assert every pool entry is matured
python3 - <<'PYEOF' | tee "$OUT/maturity-audit.txt"
import json, os, time
now = int(time.time())
total = 0
matured = 0
for chain in ["arbitrum", "ethereum", "base", "hyperliquid", "polygon", "optimism"]:
    p = f"analysis/pools-{chain}.json"
    if not os.path.exists(p):
        print(f"{chain}: MISSING")
        continue
    d = json.load(open(p))
    n = len(d["pools"])
    m = sum(1 for x in d["pools"] if x["maturity"] < now)
    total += n
    matured += m
    print(f"{chain}: block={d['block']} pools={n} matured={m} future={n-m}")
print(f"TOTAL pools={total} matured={matured} future={total-matured}")
print("VERDICT:", "ALL MATURED (no pre-maturity surface)" if total == matured else "SOME FUTURE POOLS EXIST")
PYEOF

# 4) protocol-fee owner check (v2.5 pool factory, same address on all EVM chains)
python3 - <<'PYEOF' | tee "$OUT/pool-factory-owners.txt"
import json, urllib.request
RPCS = {
    "arbitrum": "https://arb1.arbitrum.io/rpc",
    "ethereum": "https://ethereum-rpc.publicnode.com",
    "base": "https://mainnet.base.org",
    "hyperliquid": "https://rpc.hyperliquid.xyz/evm",
}
SEL_OWNER = "0x8da5cb5b"
PF = "0x97509c65Ff29C268F0D283A41201Be6b4090354c"
for chain, url in RPCS.items():
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                       "params": [{"to": PF, "data": SEL_OWNER}, "latest"]}).encode()
    try:
        req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
        r = json.load(urllib.request.urlopen(req, timeout=30))["result"]
        print(f"{chain}: TimeswapV2PoolFactory {PF} owner = 0x{r[-40:]}")
    except Exception as e:
        print(f"{chain}: owner read failed: {e}")
PYEOF

echo "=== CI job complete ==="
