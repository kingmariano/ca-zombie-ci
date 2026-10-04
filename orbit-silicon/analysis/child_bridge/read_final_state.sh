#!/usr/bin/env bash
# Final pinned state capture (read-only). Silicon rollup ID 10.
set -u
L1=https://ethereum-rpc.publicnode.com
L2=https://rpc.silicon.network
MGR=0x5132A183E9F3CB7C848b0AAC5Ae0c4f0491B7aB2
ROLLUP=0x419dcD0f72ebAFd3524b65a97ac96699C7fBebdB
GER_L1=0x580bda1e7A0CFAe92Fa7F6c20A3794F169CE3CFb
BRIDGE_L1=0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe
GER_L2=0xa40D5f56745a118D0906a34E69aeC8C0Db1cB8fA
BRIDGE_L2=0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe
B1=$(cast block-number --rpc-url "$L1")
B2=$(cast block-number --rpc-url "$L2")
echo "ETH_BLOCK $B1"
echo "SILICON_BLOCK $B2"
echo "SILICON_BLOCK_TS $(cast block "$B2" --rpc-url "$L2" --field timestamp)"
echo "SILICON_BLOCK_TIME $(date -u -d @$(cast block "$B2" --rpc-url "$L2" --field timestamp) '+%Y-%m-%d %H:%M:%S UTC')"
echo "--- AgglayerManager (L1 @ $B1) ---"
r() { cast call --rpc-url "$L1" --block "$B1" "$@"; }
echo "version $(r $MGR 'version()(string)')"
echo "rollupID(chainID 2355) $(r $MGR 'chainIDToRollupID(uint64)(uint32)' 2355)"
echo "isEmergencyState $(r $MGR 'isEmergencyState()(bool)')"
echo "lastAggregationTimestamp $(r $MGR 'lastAggregationTimestamp()(uint64)')"
echo "lastAggregationTime $(date -u -d @$(r $MGR 'lastAggregationTimestamp()(uint64)') '+%Y-%m-%d %H:%M:%S UTC')"
echo "getRollupExitRoot $(r $MGR 'getRollupExitRoot()(bytes32)')"
echo "getLastVerifiedBatch(10) $(r $MGR 'getLastVerifiedBatch(uint32)(uint64)' 10)"
echo "totalSequencedBatches $(r $MGR 'totalSequencedBatches()(uint64)')"
echo "totalVerifiedBatches $(r $MGR 'totalVerifiedBatches()(uint64)')"
echo "rollupCount $(r $MGR 'rollupCount()(uint32)')"
echo "-- rollupIDToRollupDataDeserialized(10) --"
r $MGR 'rollupIDToRollupDataDeserialized(uint32)(address,uint64,address,uint64,bytes32,uint64,uint64,uint64,uint64,uint64,uint64,uint8)' 10
echo "-- rollupIDToRollupDataV2Deserialized(10) --"
r $MGR 'rollupIDToRollupDataV2Deserialized(uint32)(address,uint64,address,uint64,bytes32,uint64,uint64,uint64,uint64,uint64,uint8,bytes32,bytes32)' 10 2>/dev/null || true
echo "-- rollupTypeMap(14) --"
r $MGR 'rollupTypeMap(uint32)(address,address,uint64,uint8,bool,bytes32,bytes32)' 14
echo "getRollupBatchNumToStateRoot(10,75940) $(r $MGR 'getRollupBatchNumToStateRoot(uint32,uint64)(bytes32)' 10 75940)"
echo "getRollupSequencedBatches(10,75940) $(r $MGR 'getRollupSequencedBatches(uint32,uint64)((bytes32,uint64,uint64))' 10 75940)"
echo "--- Silicon rollup contract (L1 @ $B1) ---"
echo "trustedSequencer $(r $ROLLUP 'trustedSequencer()(address)')"
echo "admin $(r $ROLLUP 'admin()(address)')"
echo "rollupManager $(r $ROLLUP 'rollupManager()(address)')"
echo "networkName $(r $ROLLUP 'networkName()(string)')"
echo "--- AgglayerGER L1 (@ $B1) ---"
echo "getLastGlobalExitRoot $(r $GER_L1 'getLastGlobalExitRoot()(bytes32)')"
echo "lastMainnetExitRoot $(r $GER_L1 'lastMainnetExitRoot()(bytes32)')"
echo "lastRollupExitRoot $(r $GER_L1 'lastRollupExitRoot()(bytes32)')"
echo "depositCount $(r $GER_L1 'depositCount()(uint256)')"
echo "rollupManager $(r $GER_L1 'rollupManager()(address)')"
echo "bridgeAddress $(r $GER_L1 'bridgeAddress()(address)')"
echo "version $(r $GER_L1 'version()(string)')"
echo "--- L1 bridge (@ $B1) ---"
echo "networkID $(r $BRIDGE_L1 'networkID()(uint32)')"
echo "isEmergencyState $(r $BRIDGE_L1 'isEmergencyState()(bool)')"
echo "depositCount $(r $BRIDGE_L1 'depositCount()(uint256)')"
echo "lastUpdatedDepositCount $(r $BRIDGE_L1 'lastUpdatedDepositCount()(uint32)')"
echo "--- L2 GER (@ $B2) ---"
q() { cast call --rpc-url "$L2" --block "$B2" "$@"; }
echo "lastRollupExitRoot $(q $GER_L2 'lastRollupExitRoot()(bytes32)')"
echo "bridgeAddress $(q $GER_L2 'bridgeAddress()(address)')"
echo "globalExitRootMap[current LER] $(q $GER_L2 'globalExitRootMap(bytes32)(uint256)' 0x02d6ec8cace61c90069033862c039c472563c051553c841cbbb9106b06e2c038)"
echo "impl_slot $(cast storage $GER_L2 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $L2 --block $B2)"
echo "--- L2 bridge (@ $B2) ---"
echo "networkID $(q $BRIDGE_L2 'networkID()(uint32)')"
echo "globalExitRootManager $(q $BRIDGE_L2 'globalExitRootManager()(address)')"
echo "isEmergencyState $(q $BRIDGE_L2 'isEmergencyState()(bool)')"
echo "depositCount $(q $BRIDGE_L2 'depositCount()(uint256)')"
echo "lastUpdatedDepositCount $(q $BRIDGE_L2 'lastUpdatedDepositCount()(uint32)')"
echo "getRoot $(q $BRIDGE_L2 'getRoot()(bytes32)')"
echo "--- relation checks ---"
echo "keccak(l1InfoTreeRoot,lastRollupExitRoot) = $(cast keccak $(cast concat-hex $(r $GER_L1 'lastMainnetExitRoot()(bytes32)') $(r $GER_L1 'lastRollupExitRoot()(bytes32)')))"
echo "GER.getLastGlobalExitRoot                     = $(r $GER_L1 'getLastGlobalExitRoot()(bytes32)')"
