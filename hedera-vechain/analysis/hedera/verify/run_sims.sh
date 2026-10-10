#!/usr/bin/env bash
# Read-only eth_call attack simulations. Keyless public RPC. Attacker 0.0.10912431.
set -u
RPC="https://mainnet.hashio.io/api"
ATK=0x0000000000000000000000000000000000a682af
ST=0x0000000000000000000000000000000000158d97
UD=0x0000000000000000000000000000000000158d71
RW=0x0000000000000000000000000000000000158dac
V2U=0x00000000000000000000000000000000000fae03
out=raw/sims_a682af.log
: > "$out"
echo "== block ==" >> "$out"; cast block-number --rpc-url "$RPC" >> "$out"
echo "== attacker=$ATK ==" >> "$out"
run() { desc="$1"; shift; printf '%s\n' "-- $desc" >> "$out"; cast call "$@" --from "$ATK" --rpc-url "$RPC" >> "$out" 2>&1; printf 'exit=%s\n' "$?" >> "$out"; }
run "st.queueAllFunds(attacker)" $ST "queueAllFunds(address)(uint256)" $ATK
run "st.queuePartialFunds(attacker,100000000)" $ST "queuePartialFunds(address,uint256)(uint256)" $ATK 100000000
run "st.withdraw(0)" $ST "withdraw(uint256)(uint256)" 0
run "st.withdraw(1)" $ST "withdraw(uint256)(uint256)" 1
run "st.cancelWithdraw(0)" $ST "cancelWithdraw(uint256)(uint256)" 0
run "st.updateNodeStakingActive()" $ST "updateNodeStakingActive()"
run "st.pause()" $ST "pause()"
run "st.unpause()" $ST "unpause()"
run "st.updateStakeIsPaused()" $ST "updateStakeIsPaused()"
run "st.updateUnStakeIsPaused()" $ST "updateUnStakeIsPaused()"
run "st.setUndelegationContractAddress(attacker)" $ST "setUndelegationContractAddress(address)" $ATK
run "st.setRewardsContractAddress(attacker)" $ST "setRewardsContractAddress(address)" $ATK
run "st.updateOperatorAddress(attacker)" $ST "updateOperatorAddress(address)" $ATK
run "st.proposeOwner(attacker)" $ST "proposeOwner(address)" $ATK
run "st.proposeTimelockOwner(attacker)" $ST "proposeTimelockOwner(address)" $ATK
run "st.acceptTimelockOwnership()" $ST "acceptTimelockOwnership()"
run "st.cancelTimelockOwnerProposal()" $ST "cancelTimelockOwnerProposal()"
run "st.acceptOwnership()" $ST "acceptOwnership()"
run "st.cancelOwnerProposal()" $ST "cancelOwnerProposal()"
run "st.setLockedPeriod(0)" $ST "setLockedPeriod(uint256)" 0
run "st.updateMinDeposit(0)" $ST "updateMinDeposit(uint256)" 0
run "st.updateMaxDeposit(1)" $ST "updateMaxDeposit(uint256)" 1
run "st.stakeWithNodes([],0)" $ST "stakeWithNodes(uint256[],uint256)" "[]" 0
run "st.collectRewards([0])" $ST "collectRewards(uint256[])" "[0]"
run "st.withdrawFromNodes()" $ST "withdrawFromNodes()"
run "st.unStake(100000000)" $ST "unStake(uint256)(uint256)" 100000000
run "st.unStake(1)" $ST "unStake(uint256)(uint256)" 1
run "ud.undelegate(attacker) value=1" $UD "undelegate(address)(uint256)" $ATK --value 1
run "ud.undelegate(attacker) value=0" $UD "undelegate(address)(uint256)" $ATK
run "ud.withdraw(0)" $UD "withdraw(uint256)" 0
run "ud.withdraw(1)" $UD "withdraw(uint256)" 1
run "ud.setStakingContractAddress(attacker)" $UD "setStakingContractAddress(address)" $ATK
run "ud.setUnbondingTime(1)" $UD "setUnbondingTime(uint256)" 1
run "ud.pause()" $UD "pause()"
run "rw.distributeStakingRewards()" $RW "distributeStakingRewards()"
run "rw.setStakerAddress(attacker)" $RW "setStakerAddress(address)" $ATK
run "rw.setDaoAddress(attacker)" $RW "setDaoAddress(address)" $ATK
run "rw.setEmissionRate(1)" $RW "setEmissionRate(uint256)" 1
run "rw.setDaoFeesPercentage(99)" $RW "setDaoFeesPercentage(uint256)" 99
run "rw.pause()" $RW "pause()"
run "v2u.withdraw(0)" $V2U "withdraw(uint256)" 0
run "v2u.withdraw(1)" $V2U "withdraw(uint256)" 1
run "v2u.withdraw(2)" $V2U "withdraw(uint256)" 2
run "v2u.undelegate(attacker) value=1" $V2U "undelegate(address)(uint256)" $ATK --value 1
run "v2u.pause()" $V2U "pause()"
echo "== block after ==" >> "$out"; cast block-number --rpc-url "$RPC" >> "$out"
