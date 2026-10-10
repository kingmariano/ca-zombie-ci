#!/usr/bin/env bash
# Read-only state dump. Keyless public RPC only. No secrets.
set -u
RPC="https://mainnet.hashio.io/api"
ST=0x0000000000000000000000000000000000158d97
UD=0x0000000000000000000000000000000000158d71
RW=0x0000000000000000000000000000000000158dac
V2U=0x00000000000000000000000000000000000fae03
V2S=0x00000000000000000000000000000000000fae04
out=raw/reads.log
: > "$out"
echo "== block before ==" >> "$out"
cast block-number --rpc-url "$RPC" >> "$out"
echo "== staking storage slots 0..26 ==" >> "$out"
for i in $(seq 0 26); do echo "slot$i: $(cast storage $ST $i --rpc-url "$RPC")" >> "$out"; done
echo "== undelegation storage slots 0..6 ==" >> "$out"
for i in $(seq 0 6); do echo "slot$i: $(cast storage $UD $i --rpc-url "$RPC")" >> "$out"; done
echo "== rewards storage slots 0..10 ==" >> "$out"
for i in $(seq 0 10); do echo "slot$i: $(cast storage $RW $i --rpc-url "$RPC")" >> "$out"; done
echo "== balances (wei) ==" >> "$out"
for a in $ST $UD $RW $V2U $V2S; do echo "$a: $(cast balance $a --rpc-url "$RPC")" >> "$out"; done
echo "== staking getters ==" >> "$out"
for sig in "owner()(address)" "ownerCandidate()(address)" "timelockOwnerNewCandidate()(address)" "paused()(bool)" "isStakePaused()(bool)" "isUnstakePaused()(bool)" "nodeStakingActive()(bool)" "minDeposit()(uint256)" "maxDeposit()(uint256)" "totalSupply()(uint256)" "balanceBefore()(uint256)" "hbarxAddress()(address)" "undelegationContractAddress()(address)" "lockedPeriod()(uint256)" "fixedLockedPeriod()(uint256)" "getExchangeRate()(uint256)" "decimals()(uint256)" "nodeProxyAddresses(uint256)(address)" ; do
  if [ "$sig" = "nodeProxyAddresses(uint256)(address)" ]; then
    echo "nodeProxyAddresses(0): $(cast call $ST "nodeProxyAddresses(uint256)(address)" 0 --rpc-url "$RPC" 2>&1)" >> "$out"
    echo "nodeProxyAddresses(25): $(cast call $ST "nodeProxyAddresses(uint256)(address)" 25 --rpc-url "$RPC" 2>&1)" >> "$out"
  else
    echo "$sig: $(cast call $ST "$sig" --rpc-url "$RPC" 2>&1)" >> "$out"
  fi
done
echo "== undelegation getters ==" >> "$out"
for sig in "owner()(address)" "ownerCandidate()(address)" "paused()(bool)" "unbondingTime()(uint256)" "stakingContractAddress()(address)"; do
  echo "$sig: $(cast call $UD "$sig" --rpc-url "$RPC" 2>&1)" >> "$out"
done
echo "== rewards getters ==" >> "$out"
for sig in "owner()(address)" "ownerCandidate()(address)" "paused()(bool)" "emissionRate()(uint256)" "getEmissionRate()(uint256)" "genesisTimestamp()(uint256)" "lastRedeemedTimestamp()(uint256)" "getLastRedeemedTimestamp()(uint256)" "epoch()(uint256)" "daoFeesPercentage()(uint256)" "daoAddress()(address)"; do
  echo "$sig: $(cast call $RW "$sig" --rpc-url "$RPC" 2>&1)" >> "$out"
done
echo "== withdrawQueue(0) probe (expect revert if empty) ==" >> "$out"
echo "staking.withdrawQueue(0): $(cast call $ST "withdrawQueue(uint256)(uint256,uint256,address)" 0 --rpc-url "$RPC" 2>&1)" >> "$out"
echo "== v2 getters ==" >> "$out"
echo "V2U.stakingContractAddress(): $(cast call $V2U "stakingContractAddress()(address)" --rpc-url "$RPC" 2>&1)" >> "$out"
echo "V2U.unbondingTime(): $(cast call $V2U "unbondingTime()(uint256)" --rpc-url "$RPC" 2>&1)" >> "$out"
echo "V2U.paused(): $(cast call $V2U "paused()(bool)" --rpc-url "$RPC" 2>&1)" >> "$out"
echo "V2U.owner(): $(cast call $V2U "owner()(address)" --rpc-url "$RPC" 2>&1)" >> "$out"
echo "V2S.undelegationContractAddress(): $(cast call $V2S "undelegationContractAddress()(address)" --rpc-url "$RPC" 2>&1)" >> "$out"
echo "V2S.totalSupply(): $(cast call $V2S "totalSupply()(uint256)" --rpc-url "$RPC" 2>&1)" >> "$out"
echo "V2S.hbarxAddress(): $(cast call $V2S "hbarxAddress()(address)" --rpc-url "$RPC" 2>&1)" >> "$out"
echo "== block after ==" >> "$out"
cast block-number --rpc-url "$RPC" >> "$out"
