#!/bin/bash
RPC=https://ethereum-rpc.publicnode.com
P=0x2638d2680AB4914126ee05b9c5EE95bAC311A95E
A=0x996E539a1242a541f5909c6B20BbEf4CC63F34b1
POOL=0x329239599afB305DA0A2eC69c58F8a6697F9F88d
echo "== uninplemented-on-impl wrapper sims (admin caller) - all expected revert =="
echo -n "ramp_A: "; cast call $P "ramp_A(address,uint256,uint256)" $POOL 200 2000000000 --from $A --rpc-url $RPC 2>&1 | head -1
echo -n "stop_ramp_A: "; cast call $P "stop_ramp_A(address)" $POOL --from $A --rpc-url $RPC 2>&1 | head -1
echo -n "commit_new_fee: "; cast call $P "commit_new_fee(address,uint256,uint256)" $POOL 3000000 0 --from $A --rpc-url $RPC 2>&1 | head -1
echo -n "set_aave_referral: "; cast call $P "set_aave_referral(address,uint256)" $POOL 0 --from $A --rpc-url $RPC 2>&1 | head -1
echo -n "kill_me: "; cast call $P "kill_me(address)" $POOL --from $A --rpc-url $RPC 2>&1 | head -1
echo "== Aragon vote executability (block 26,174,xxx) =="
V=0xdff7beb0cbf54d6553e4702ae0ffa60718822478
for i in 0 1 2 3 4 5 6; do echo -n "canExecute($i): "; cast call $V "canExecute(uint256)(bool)" $i --rpc-url $RPC 2>&1 | head -1; done
echo -n "executeVote(3) from attacker: "; cast call $V "executeVote(uint256)" 3 --from 0x1111111111111111111111111111111111111111 --rpc-url $RPC 2>&1 | head -1
echo -n "Voting.execute() direct: "; cast call $V "execute(address,uint256,bytes)" $V 0 0x5eb24332 --from 0x1111111111111111111111111111111111111111 --rpc-url $RPC 2>&1 | head -1
echo "== vote3 script decode =="
echo "outer target=Voting 0xdff7beb0; selector=b61d27f6 (execute(address,uint256,bytes)); inner target=Voting; inner selector=5eb24332 (changeMinAcceptQuorumPct(uint64)); inner arg=90000000000000000 (9%); spec=0x1"
