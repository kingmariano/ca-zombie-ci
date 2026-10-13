#!/usr/bin/env bash
# QC-2 Convergence Fi live re-verification (read-only). Writes analysis/live_verify.txt
set -uo pipefail
cd "$(dirname "$0")"
set -a; source /home/heisenberg/CA/.env 2>/dev/null; set +a
R="${BLOCKPI_RPC_URL:-$RPC_URL}"
OUT=live_verify.txt
: > "$OUT"
say(){ echo "$@" | tee -a "$OUT"; }
c(){ local v; v=$(cast call "$2" "$3" ${4:+$4} --rpc-url "$R" 2>&1 | tr '\n' ' '); say "$1 | $2 | $3 ${4:+args=$4} => $v"; }
impl(){ cast storage "$1" 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url "$R" 2>/dev/null | tail -c 41; }
beacon(){ cast storage "$1" 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50 --rpc-url "$R" 2>/dev/null | tail -c 41; }

T=0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7
BH=0x21777106355Ba506A31FF7984c0aE5C924deB77f
MG=0x7319662aD7D7ce2d1595073EA042B723F6d0dc48
DS=0x6B65525a40704a4c48d07c25b8D05654854DFEcD
FC=0x15A2d42421b62E92fe0ABD22E2aa6caC8Ffa6ec5
CS=0xF941BC649Ef0B20ABd7f6dC78CA8f8E225337933
CB=0x98C04163723134b0a4C364A72A71e620b58aB3f1
S1=0x2FF160bcADb485b5F048b9880e6f471Af632060c
G1=0x7f50786A0b15723D741727882ee99a0BF34e3466
BU1=0x8405FF734C157f51011FC7d7dfa22f4a32505B43

say "block=$(cast block-number --rpc-url "$R")  ts=$(cast block latest --field timestamp --rpc-url "$R")"
say "=== proxy impls / beacons ==="
for n in tower:$T blackhole:$BH manager:$MG distributor:$DS factory:$FC cvgSdtService:$CS cvgSdtBuffer:$CB sdCRVsvc:$S1 sdCRVgauge:$G1 sdCRVbuffer:$BU1; do
  name=${n%%:*}; addr=${n#*:}
  say "$name impl=$(impl $addr) beacon=$(beacon $addr)"
done
say "=== tower registry ==="
c "tower.owner" $T "owner()(address)"
c "tower.cloneFactory" $T "cloneFactory()(address)"
c "tower.sdtBlackHole" $T "sdtBlackHole()(address)"
c "tower.cvgSdtStaking" $T "cvgSdtStaking()(address)"
c "tower.sdtStakingPositionManager" $T "sdtStakingPositionManager()(address)"
c "tower.sdtRewardDistributor" $T "sdtRewardDistributor()(address)"
c "tower.cvgSdtBuffer" $T "cvgSdtBuffer()(address)"
c "tower.cvgSDT" $T "cvgSDT()(address)"
c "tower.sdt" $T "sdt()(address)"
c "tower.sdtFeeCollector" $T "sdtFeeCollector()(address)"
c "tower.sdtUtilities" $T "sdtUtilities()(address)"
c "tower.cvgRewards" $T "cvgRewards()(address)"
c "tower.veSdtMultisig" $T "veSdtMultisig()(address)"
c "tower.cvgCycle" $T "cvgCycle()(uint128)"
say "=== all 37 services: asset/vault/buffer/cycle/totalStaked/depositPaused/impl ==="
SERVICES=$(cast call $T "getSdtStakings(uint256,uint256)((address,string)[])" 0 1000 --rpc-url "$R" | tr ',' '\n' | grep -oE '0x[0-9a-fA-F]{40}' | head -37)
i=0
for s in $SERVICES; do
  i=$((i+1))
  asset=$(cast call $s "stakingAsset()(address)" --rpc-url "$R" 2>/dev/null)
  vault=$(cast call $s "vault()(address)" --rpc-url "$R" 2>/dev/null)
  buffer=$(cast call $s "buffer()(address)" --rpc-url "$R" 2>/dev/null)
  cycle=$(cast call $s "stakingCycle()(uint128)" --rpc-url "$R" 2>/dev/null)
  paused=$(cast call $s "depositPaused()(bool)" --rpc-url "$R" 2>/dev/null)
  ci=$(cast call $s "cycleInfo(uint256)(uint256,uint256,bool)" "$cycle" --rpc-url "$R" 2>/dev/null | tr '\n' ' ')
  im=$(impl $s); be=$(beacon $s)
  say "svc$i $s impl=$im beacon=$be asset=$asset vault=$vault buffer=$buffer cycle=$cycle paused=$paused cycleInfo=[$ci]"
done
say "=== registration mappings for candidates ==="
for a in $SERVICES $CS $CB $BU1 0x539e65190a371ce73244a98dec42ba635cca512c $MG $DS $BH $FC $T $G1 0xe789b78f66886d3ec9e393fb495ea726c5b371af; do
  is1=$(cast call $T "isSdtStaking(address)(bool)" $a --rpc-url "$R" 2>/dev/null)
  is2=$(cast call $T "isStakingContract(address)(bool)" $a --rpc-url "$R" 2>/dev/null)
  say "reg $a isSdtStaking=$is1 isStakingContract=$is2"
done
say "=== cvgSDT service detail ==="
c "cvgSdtSvc.stakingAsset" $CS "stakingAsset()(address)"
c "cvgSdtSvc.vault" $CS "vault()(address)"
c "cvgSdtSvc.buffer" $CS "buffer()(address)"
c "cvgSdtSvc.stakingCycle" $CS "stakingCycle()(uint128)"
c "cvgSdtSvc.symbol" $CS "symbol()(string)"
c "cvgSdtSvc.owner" $CS "owner()(address)"
say "=== gauges: claimer + rewards_receiver(blackhole) for first 5 services ==="
n=0
for s in $SERVICES; do
  n=$((n+1)); [ $n -gt 5 ] && break
  g=$(cast call $s "stakingAsset()(address)" --rpc-url "$R" 2>/dev/null)
  cl=$(cast call $g "claimer()(address)" --rpc-url "$R" 2>/dev/null)
  rr=$(cast call $g "rewards_receiver(address)(address)" $BH --rpc-url "$R" 2>/dev/null)
  adm=$(cast call $g "admin()(address)" --rpc-url "$R" 2>/dev/null)
  say "gauge$n $g claimer=$cl rewards_receiver(blackhole)=$rr admin=$adm"
done
say "=== distributor holdings ==="
for t in 0x7f50786A0b15723D741727882ee99a0BF34e3466 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E 0xD533a949740bb3306d119CC777fa900bA034cd52 0xdAC17F958D2ee523a2206206994597C13D831ec7 0x50dc9ae51f78c593d4138263da7088a973b8184e 0x7f39C581F595B53c5cb19BD0B3f8DA6c935E2Ca0 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F 0x830614aE209FF9d8706d386fcdBc7a55206fcffC; do
  b=$(cast call $t "balanceOf(address)(uint256)" $DS --rpc-url "$R" 2>/dev/null)
  say "distributor $t bal=$b"
done
say "=== blackhole holdings for all stakingAssets ==="
for s in $SERVICES; do
  g=$(cast call $s "stakingAsset()(address)" --rpc-url "$R" 2>/dev/null)
  b=$(cast call $g "balanceOf(address)(uint256)" $BH --rpc-url "$R" 2>/dev/null)
  say "bh $g bal=$b"
done
say "=== done ==="
