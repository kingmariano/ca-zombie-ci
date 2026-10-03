#!/usr/bin/env bash
# Pac Finance (Blast) live-state snapshot — read-only, no transactions.
# Runs in CI before `forge test`; writes results to ci-out/ (uploaded as artifact).
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
RPC="${BLAST_RPC_URL:-https://blast-rpc.publicnode.com}"
P=0x688B5fd3C3E3724b4De08C4BCB3A755F9b579c9a
POOL=0xd2499b3c8611E36ca89A70Fda2A72C49eE19eAa8
ORACLE=0xAf77325317F109ee21459AFeEDE51b16C231e6b1
OUT=ci-out/state.txt
{
  echo "# Pac Finance (Blast) live state — read-only snapshot"
  echo "utc=$(date -u +%FT%TZ)"
  echo "rpc=$RPC"
  echo "block=$(cast block-number --rpc-url "$RPC" 2>&1)"
  echo "provider_owner=$(cast call $P 'owner()(address)' --rpc-url "$RPC" 2>&1 | head -1)"
  echo "oracle_oUSDB_price=$(cast call $ORACLE 'getAssetPrice(address)(uint256)' 0x9aECEdCD6A82d26F2f86D331B17a1C1676442A87 --rpc-url "$RPC" 2>&1 | head -1)"
  echo "oracle_WETH_price=$(cast call $ORACLE 'getAssetPrice(address)(uint256)' 0x4300000000000000000000000000000000000004 --rpc-url "$RPC" 2>&1 | head -1)"
  echo "oracle_USDB_price=$(cast call $ORACLE 'getAssetPrice(address)(uint256)' 0x4300000000000000000000000000000000000003 --rpc-url "$RPC" 2>&1 | head -1)"
  echo "aWETH_cash=$(cast call 0x4300000000000000000000000000000000000004 'balanceOf(address)(uint256)' 0x63749b03bdB4e86E5aAF7E5a723bF993DBf0c1c5 --rpc-url "$RPC" 2>&1 | head -1)"
  echo "aUSDB_cash=$(cast call 0x4300000000000000000000000000000000000003 'balanceOf(address)(uint256)' 0xc7206216f28c23b2da6537d296e789cfb81b31ef --rpc-url "$RPC" 2>&1 | head -1)"
  echo "aDETH_cash=$(cast call 0x1Da40C742F32bBEe81694051c0eE07485fC630f6 'balanceOf(address)(uint256)' 0x97257a7c033773d54dfe83bfcdce056af8321ae2 --rpc-url "$RPC" 2>&1 | head -1)"
  echo "aezETH_cash=$(cast call 0x2416092f143378750bb29b79eD961ab195CcEea5 'balanceOf(address)(uint256)' 0x01bfae5e4fdfcfb514b65b8ed4f515327bbe994d --rpc-url "$RPC" 2>&1 | head -1)"
  echo "awrsETH_cash=$(cast call 0xe7903B1F75C534Dd8159b313d92cDCfbC62cB3Cd 'balanceOf(address)(uint256)' 0xf5f8be345234487f6f574e821547342656aab417 --rpc-url "$RPC" 2>&1 | head -1)"
  echo "NYD_USDB_pot=$(cast call 0x4300000000000000000000000000000000000003 'balanceOf(address)(uint256)' 0xAd49EE1956704F1ec97CE7A9850A3608Bf0bECc3 --rpc-url "$RPC" 2>&1 | head -1)"
  echo "NYD_WETH_pot=$(cast call 0x4300000000000000000000000000000000000004 'balanceOf(address)(uint256)' 0x5eBe2de08276048A601646eb8FB911e0B47C4396 --rpc-url "$RPC" 2>&1 | head -1)"
  echo "GasRefund_ETH_wei=$(cast balance 0xBCD03b012a8457824ECbBA36E559401dB7B35EF0 --rpc-url "$RPC" 2>&1 | head -1)"
  echo "Treasury_aOUSDB=$(cast call 0xce7c5a6a86206b68a746615c1f6b473edb6470b3 'balanceOf(address)(uint256)' 0xe71Bba1805a334086b5BaD426d7aB15331e479a9 --rpc-url "$RPC" 2>&1 | head -1)"
  echo "deth_config=$(cast call $POOL 'getConfiguration(address)((uint256))' 0x1Da40C742F32bBEe81694051c0eE07485fC630f6 --rpc-url "$RPC" 2>&1 | head -1)"
} 2>&1 | tee "$OUT"
echo "[ci] state snapshot written to $OUT"
