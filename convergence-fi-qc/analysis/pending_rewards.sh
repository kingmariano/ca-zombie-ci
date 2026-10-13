#!/usr/bin/env bash
# Pending rewards / processSdtRewards windows + beacon impls. Read-only.
set -uo pipefail
cd "$(dirname "$0")"
set -a; source /home/heisenberg/CA/.env 2>/dev/null; set +a
R="${BLOCKPI_RPC_URL:-$RPC_URL}"
OUT=pending_rewards.txt
: > "$OUT"
say(){ echo "$@" | tee -a "$OUT"; }

T=0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7
BH=0x21777106355Ba506A31FF7984c0aE5C924deB77f
CS=0xF941BC649Ef0B20ABd7f6dC78CA8f8E225337933
CB=0x98C04163723134b0a4C364A72A71e620b58aB3f1
FC=0x15cbdf343fA37cD555D8F8CdeaA3948c1f0C42aE
VESDT=0x6ceE94bFCD5a7dEFDBEF337Bf79fE31D0982CF2A
SDFRAX=0x? # resolved below

say "block=$(cast block-number --rpc-url "$R")"
say "=== beacons ==="
# service beacon impl: slot of Beacon.implementation() = keccak? Beacon stores impl at slot 0? OZ 5 Beacon: _implementation at ERC-1967 beacon impl slot.
say "service beacon 0x8678186f5863a3013a180ba2b387de8e54573e06 impl=$(cast storage 0x8678186f5863a3013a180ba2b387de8e54573e06 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url "$R" | tail -c 41)"
say "buffer beacon 0x31ab49528b37af1ee3ef9665cdc22e494a44ddcb impl=$(cast storage 0x31ab49528b37af1ee3ef9665cdc22e494a44ddcb 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url "$R" | tail -c 41)"
say "=== cvgSDT service pending state (cycle 140) ==="
c(){ local v; v=$(cast call "$2" "$3" ${4:+$4} --rpc-url "$R" 2>&1 | tr '\n' ' '); say "$1 => $v"; }
c "cvgSdtSvc.cycleInfo(140)" $CS "cycleInfo(uint256)(uint256,uint256,bool)" 140
c "cvgSdtSvc.cycleInfo(141)" $CS "cycleInfo(uint256)(uint256,uint256,bool)" 141
c "cvgSdtSvc.nextToken" $CS "stakingCycle()(uint128)"
say "=== gauge services cycle-140 processed flags + last-cycle totalStaked ==="
SERVICES=$(cast call $T "getSdtStakings(uint256,uint256)((address,string)[])" 0 1000 --rpc-url "$R" | tr ',' '\n' | grep -oE '0x[0-9a-fA-F]{40}' | head -37)
i=0
for s in $SERVICES; do
  i=$((i+1))
  ci=$(cast call $s "cycleInfo(uint256)(uint256,uint256,bool)" 140 --rpc-url "$R" 2>/dev/null | tr '\n' ' ')
  say "svc$i $s cycle140=[$ci]"
done
say "=== buffers' token balances (sdCRV buffer + cvgSdt buffer) ==="
for tok in 0x7f50786A0b15723D741727882ee99a0BF34e3466 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F 0x830614aE209FF9d8706d386fcdBc7a55206fcffC 0xD533a949740bb3306d119CC777fa900bA034cd52 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E; do
  b1=$(cast call $tok "balanceOf(address)(uint256)" 0x8405FF734C157f51011FC7d7dfa22f4a32505B43 --rpc-url "$R" 2>/dev/null)
  b2=$(cast call $tok "balanceOf(address)(uint256)" $CB --rpc-url "$R" 2>/dev/null)
  say "buffer-token $tok sdCRVbuf=$b1 cvgSdtBuf=$b2"
done
say "=== fee collector state ==="
c "feeCollector.rootFees" $FC "rootFees()(uint256)"
c "feeCollector.sdt" $FC "sdt()(address)"
c "feeCollector.owner" $FC "owner()(address)"
c "feeCollector.SDTbal" 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F "balanceOf(address)(uint256)" $FC
say "=== veSdtMultisig sdFrax3Crv balance ==="
# find sdFrax3Crv token from cvgSdtBuffer.feeDistributor().token()
FD=$(cast call $CB "feeDistributor()(address)" --rpc-url "$R" 2>/dev/null)
say "cvgSdtBuffer.feeDistributor=$FD"
if [ -n "$FD" ]; then
  SDFRAX=$(cast call $FD "token()(address)" --rpc-url "$R" 2>/dev/null)
  say "feeDistributor.token(sdFrax3Crv)=$SDFRAX"
  c "veSdtMultisig.bal(sdFrax3Crv)" $SDFRAX "balanceOf(address)(uint256)" $VESDT
fi
say "=== cvgSDT service cvgSDT balance / distributor cvgSDT ==="
c "cvgSdtSvc.cvgSDTbal" 0x830614aE209FF9d8706d386fcdBc7a55206fcffC "balanceOf(address)(uint256)" $CS
c "distributor.cvgSDTbal" 0x830614aE209FF9d8706d386fcdBc7a55206fcffC "balanceOf(address)(uint256)" 0x6B65525a40704a4c48d07c25b8D05654854DFEcD
say "=== done ==="
