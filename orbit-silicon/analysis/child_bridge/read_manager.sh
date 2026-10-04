#!/usr/bin/env bash
# Read-only reads of AgglayerManager (Silicon rollup ID 10). No signing, no writes.
set -u
RPC=${RPC:-https://ethereum-rpc.publicnode.com}
MGR=0x5132A183E9F3CB7C848b0AAC5Ae0c4f0491B7aB2
BLOCK=$(cast block-number --rpc-url "$RPC")
echo "eth_block $BLOCK"
r() { cast call --rpc-url "$RPC" --block "$BLOCK" "$MGR" "$@"; }
echo "version              $(r 'version()(string)')"
echo "rollupCount          $(r 'rollupCount()(uint32)')"
echo "isEmergencyState     $(r 'isEmergencyState()(bool)')"
echo "lastAggregationTs    $(r 'lastAggregationTimestamp()(uint64)')"
echo "lastDeactEmergStateTs $(r 'lastDeactivatedEmergencyStateTimestamp()(uint64)')"
echo "getRollupExitRoot    $(r 'getRollupExitRoot()(bytes32)')"
echo "bridgeAddress        $(r 'bridgeAddress()(address)')"
echo "globalExitRootMgr    $(r 'globalExitRootManager()(address)')"
echo "aggLayerGateway      $(r 'aggLayerGateway()(address)')"
echo "getLastVerifiedBatch(10) $(r 'getLastVerifiedBatch(uint32)(uint64)' 10)"
echo "-- rollupIDToRollupDataDeserialized(10) --"
r 'rollupIDToRollupDataDeserialized(uint32)(address,uint64,address,uint64,bytes32,uint64,uint64,uint64,uint64,uint64,uint64,uint8)' 10
echo "-- rollupIDToRollupDataV2Deserialized(10) --"
r 'rollupIDToRollupDataV2Deserialized(uint32)(address,uint64,address,uint64,bytes32,uint64,uint64,uint64,uint64,uint64,uint8,bytes32,bytes32)' 10
