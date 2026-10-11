#!/usr/bin/env bash
# Read key Convergence Fi registry/service state via cast (read-only, public data).
set -uo pipefail
cd "$(dirname "$0")"
set -a; source /home/heisenberg/CA/.env 2>/dev/null; set +a
R="${BLOCKPI_RPC_URL:-$RPC_URL}"
T=0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7
S=0x2ff160bcadb485b5f048b9880e6f471af632060c
C=0x7f50786a0b15723d741727882ee99a0bf34e3466
OUT=registry_reads.txt
: > "$OUT"
say(){ echo "$@" | tee -a "$OUT"; }
c(){ # label target sig
  local v
  v=$(cast call "$2" "$3" --rpc-url "$R" 2>&1 | head -3 | tr '\n' ' ')
  say "$1 | $2 | $3 => $v"
}
say "block=$(cast block-number --rpc-url "$R")  date=$(date -u +%FT%TZ)"
say "--- tower registry ---"
c "tower.owner" "$T" "owner()(address)"
c "tower.pendingOwner" "$T" "pendingOwner()(address)"
c "tower.cloneFactory" "$T" "cloneFactory()(address)"
c "tower.sdtBlackHole" "$T" "sdtBlackHole()(address)"
c "tower.cvgSdtStaking" "$T" "cvgSdtStaking()(address)"
c "tower.sdtStakingPositionManager" "$T" "sdtStakingPositionManager()(address)"
c "tower.sdtRewardDistributor" "$T" "sdtRewardDistributor()(address)"
c "tower.cvgSdtBuffer" "$T" "cvgSdtBuffer()(address)"
c "tower.cvgSDT" "$T" "cvgSDT()(address)"
c "tower.sdtStakingViewer" "$T" "sdtStakingViewer()(address)"
c "tower.cvgToken" "$T" "cvgToken()(address)"
c "tower.sdt" "$T" "sdt()(address)"
c "tower.cvgCycle" "$T" "cvgCycle()(uint128)"
say "--- sdCRV service ---"
c "svc.owner" "$S" "owner()(address)"
c "svc.pendingOwner" "$S" "pendingOwner()(address)"
c "svc.stakingAsset" "$S" "stakingAsset()(address)"
c "svc.vault" "$S" "vault()(address)"
c "svc.buffer" "$S" "buffer()(address)"
c "svc.symbol" "$S" "symbol()(string)"
c "svc.depositPaused" "$S" "depositPaused()(bool)"
c "svc.stakingCycle" "$S" "stakingCycle()(uint128)"
c "svc.sdtRewardDistributor" "$S" "sdtRewardDistributor()(address)"
c "svc.sdtStakingPositionManager" "$S" "sdtStakingPositionManager()(address)"
say "--- cvgSdt (sdCRV) gauge ---"
c "gauge.admin" "$C" "admin()(address)"
c "gauge.future_admin" "$C" "future_admin()(address)"
c "gauge.initialized" "$C" "initialized()(bool)"
c "gauge.staking_token" "$C" "staking_token()(address)"
c "gauge.SDT" "$C" "SDT()(address)"
c "gauge.totalSupply" "$C" "totalSupply()(uint256)"
c "gauge.name" "$C" "name()(string)"
c "gauge.symbol" "$C" "symbol()(string)"
say "--- token identity ---"
c "tok.0xd1b565.name" 0xd1b5651e55d4ceed36251c61c50c889b36f6abb5 "name()(string)"
c "tok.0xd1b565.symbol" 0xd1b5651e55d4ceed36251c61c50c889b36f6abb5 "symbol()(string)"
c "tok.svcAsset.name" "$(cast call "$S" 'stakingAsset()(address)' --rpc-url "$R" 2>/dev/null)" "name()(string)"
cat "$OUT"
