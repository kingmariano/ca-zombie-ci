# Homora V2 H-16 — CI heavy job
# Read-only on-chain measurement + fork PoCs. No mainnet transactions.
# Writes results to ci-out/ (uploaded as artifacts).
set -x
mkdir -p ci-out
cd "$(dirname "$0")/.."

# Record the block/state snapshot the analysis was based on (best-effort; RPC may be absent)
{
  echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "repo_commit: ${GITHUB_SHA:-local}"
} > ci-out/run-meta.txt

# If an AVAX RPC is available (public fallback), dump the broken-oracle evidence
AVAX_RPC="${AVAX_RPC_URL:-https://api.avax.network/ext/bc/C/rpc}"
{
  echo "AVAX oracle evidence (block $(cast block-number --rpc-url "$AVAX_RPC" 2>/dev/null || echo n/a))"
  echo "WAVAX px: $(cast call 0xa6BAE2f3EE27271B55779BC6071FA101431Dc8Da 'getETHPx(address)(uint256)' 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7 --rpc-url "$AVAX_RPC" 2>/dev/null)"
  echo "USDC  px: $(cast call 0xa6BAE2f3EE27271B55779BC6071FA101431Dc8Da 'getETHPx(address)(uint256)' 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E --rpc-url "$AVAX_RPC" 2>/dev/null)"
  echo "WBTC  px: $(cast call 0xa6BAE2f3EE27271B55779BC6071FA101431Dc8Da 'getETHPx(address)(uint256)' 0x50b7545627a5162F82A992c33b87aDc75187B218 --rpc-url "$AVAX_RPC" 2>/dev/null)"
} > ci-out/avax-oracle.txt 2>&1 || true

echo "ci/run.sh done"
