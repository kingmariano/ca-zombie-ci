#!/usr/bin/env bash
# H2-06 Filecoin — negative-path proofs (read-only eth_call simulations).
# Every command below is a *simulation* (eth_call). Nothing is signed or sent.
# Requires: foundry `cast`. Uses only keyless public RPC.
#
# Observed outputs for every line are recorded in ../evidence/negatives_output.txt
# (session 2026-10-10, block 6,444,339, chain 314).

RPC="${RPC:-https://api.node.glif.io/rpc/v1}"
ATT="0x1111111111111111111111111111111111111111"

echo "== FIL price =="
curl -s -m 15 "https://coins.llama.fi/prices/current/coingecko:filecoin"

POOL=0xFD669BDDfbb0d085135cBd92521785C39c95bA4b     # FILLiquid pool
FIT=0x87006Fb444878A69D6692Dc944D1dd418f52F053      # FIT (FILTrust)
STK=0xB153Cb3efF3e7330DDF4962c22aA8DC63B7fa952      # FITStake farm (212k FIT)
FIGSTK=0xD44bfE4523f1B2703DDE9C7dBc010Ad39EF668f7   # FIGStaking (1,046 FIL)
FEE=0x7201166FAD30f26f27c36842209b1A35e9f6f0d3      # FILLiquid feeReceiver (2,911 FIL)
VAULT=0xe012F3957226894B1a2a44b3ef5070417a069dC2    # HashKing KingHash vault (9,414 FIL)
NFIL=0x84B038DB0fCde4fae528108603c7376695dc217f     # nFIL receipt token
WFIL=0xD9A724840a46370c01a50C1E511087ab3a07FB53     # wFIL wrapper

echo; echo "== FILLiquid: pool has no cash =="
cast balance $POOL --rpc-url $RPC --ether
cast call $POOL "availableFIL()(uint256)" --rpc-url $RPC      # phantom accounting
cast call $POOL "utilizedLiquidity()(uint256)" --rpc-url $RPC
cast call $POOL "getFitByRedeem(uint256)(uint256)" 1000000000000000000 --rpc-url $RPC

echo; echo "== FILLiquid: redeem reverts for ANY caller (pool balance = 0) =="
# 1 FIT from a real FIT holder (7,875 FIT) -> revert at the payout transfer
cast call $POOL "redeem(uint256,uint256)" 1000000000000000000 0 \
  --from 0xD48CF590228dcC9Dc3661eA00728127a6949477A --rpc-url $RPC
# top FIT holder = FITStake farm (208k FIT) -> same
cast call $POOL "redeem(uint256,uint256)" 1000000000000000000 0 \
  --from $STK --rpc-url $RPC
# someone with no FIT -> earlier revert "ERC20: burn amount exceeds balance"
cast call $POOL "redeem(uint256,uint256)" 1000000000000000000 0 \
  --from $ATT --rpc-url $RPC

echo; echo "== FILLiquid: borrow path needs a bound miner + cash (both absent) =="
cast call $POOL "getBorrowable(uint64)(bool,string)" 3825752 --rpc-url $RPC   # miner was un-collateralized
cast call $POOL "allMinersCount()(uint256)" --rpc-url $RPC

echo; echo "== FILLiquid feeReceiver: owner-gated (owner 0x6dc515...) =="
cast call $FEE "getFactors()(address)" --rpc-url $RPC
cast call $FEE "transferAll(address)" $ATT --from $ATT --rpc-url $RPC
cast call $FEE "transfer(address,uint256)" $ATT 1000000000000000000 --from $ATT --rpc-url $RPC

echo; echo "== FILLiquid FIGStaking: withdraw() is staker-scoped (stranger -> 0) =="
cast call $FIGSTK "withdraw()(uint256)" --from $ATT --rpc-url $RPC
cast call $FIGSTK "unStake(uint256)" 1000000000000000000 --from $ATT --rpc-url $RPC

echo; echo "== HashKing vault: every write-path from a random address =="
cast call $VAULT "initialize(address)" $ATT --from $ATT --rpc-url $RPC
cast call $VAULT "upgradeTo(address)" $ATT --from $ATT --rpc-url $RPC
cast call $VAULT "upgradeToAndCall(address,bytes)" $ATT 0x --from $ATT --rpc-url $RPC
cast call $VAULT "transferOwnership(address)" $ATT --from $ATT --rpc-url $RPC
cast call $VAULT "renounceOwnership()" --from $ATT --rpc-url $RPC
cast call $VAULT "setGovernance(address)" $ATT --from $ATT --rpc-url $RPC
cast call $VAULT "setHubPool(address)" $ATT --from $ATT --rpc-url $RPC
cast call $VAULT "addBeneficiary(address)" $ATT --from $ATT --rpc-url $RPC
cast call $VAULT "delBeneficiary(address)" $ATT --from $ATT --rpc-url $RPC
cast call $VAULT "setTotalPoolFilLimit(uint256)" 1 --from $ATT --rpc-url $RPC
cast call $VAULT "depositFil(uint256)" 1000000000000000000 --from $ATT --rpc-url $RPC
# unstake paths (0xcebbfa44, 0xc3178389): nFIL-burn gated
cast call $VAULT "0xcebbfa44$(printf '%064x' 1000000000000000000)" --from $ATT --rpc-url $RPC
cast call $VAULT "0xc3178389$(printf '%064x' 1000000000000000000)" --from $ATT --rpc-url $RPC
cast call $VAULT "0x88f9184f000000000000000000000000$ATT" --from $ATT --rpc-url $RPC  # hubPool-only
cast call $VAULT "0x0e6878a3$(printf '%064x' 1)" --from $ATT --rpc-url $RPC          # beneficiary-gated

echo; echo "== nFIL token: mint/burn/admin gated =="
cast call $NFIL "whiteListMint(uint256,address)" 1000000000000000000 $ATT --from $ATT --rpc-url $RPC
cast call $NFIL "whiteListBurn(uint256,address)" 1000000000000000000 $ATT --from $ATT --rpc-url $RPC
cast call $NFIL "initialize()" --from $ATT --rpc-url $RPC
cast call $NFIL "upgradeTo(address)" $ATT --from $ATT --rpc-url $RPC
cast call $NFIL "setLiquidStaking(address)" $ATT --from $ATT --rpc-url $RPC

echo; echo "== wFIL: 1:1 wrapper; supply == balance (no privileged paths) =="
cast call $WFIL "totalSupply()(uint256)" --rpc-url $RPC
cast balance $WFIL --rpc-url $RPC --ether
