#!/usr/bin/env bash
set -u
RPC='https://andromeda.metis.io/?owner=1088'
B=23238718
V=0x17A30350771d02409046A683b18Fe1C13cCFC4A8
ATT=0x1111111111111111111111111111111111111111
PAYER_ROLE=0x8ec07e268e32cae7f300b49ad34f20106d088445cb9d9b2d62cbd864638308b2
PAYEE_ROLE=0x95ed160efa56927d40641b26c79df8395a2e4f8f170168fedfa462234b4c3a46
try(){ local name=$1 from=$2; shift 2; local out rc; out=$(cast call $V "$@" --from $from --block $B --rpc-url "$RPC" 2>&1); rc=$?; if [ $rc -eq 0 ]; then echo "PASS | $name | out=$(echo "$out"|head -c 120)"; else echo "REVERT | $name | $(echo "$out" | sed 's/.*execution reverted[: ]*//;s/, data: .*//' | head -c 200)"; fi; }
TOK=0x2222222222222222222222222222222222222222
try "transferErc20(att)" $ATT "transferErc20(address,address,uint256)" $TOK $ATT 1
try "batchTransferErc20(att)" $ATT "batchTransferErc20(address[],address[],uint256[])" "[$TOK]" "[$ATT]" "[1]"
try "transferErc721(att)" $ATT "transferErc721(address,address,uint256)" $TOK $ATT 1
try "batchTransferErc721(att)" $ATT "batchTransferErc721(address[],address[],uint256[])" "[$TOK]" "[$ATT]" "[1]"
try "batchTransferEther(att)" $ATT "batchTransferEther(address[],uint256[])" "[$ATT]" "[1]"
try "renounceRole(PAYER,att)" $ATT "renounceRole(bytes32,address)" $PAYER_ROLE $ATT
try "renounceRole(PAYER,owner)" $ATT "renounceRole(bytes32,address)" $PAYER_ROLE 0x52c904aBC83fD537a508F56Fc6F3D723fF5403e1
try "revokeRole(PAYER,owner)" $ATT "revokeRole(bytes32,address)" $PAYER_ROLE 0x52c904aBC83fD537a508F56Fc6F3D723fF5403e1
try "initialize from owner" 0x52c904aBC83fD537a508F56Fc6F3D723fF5403e1 "initialize()"
try "supportsInterface(721)" $ATT "supportsInterface(bytes4)(bool)" 0x80ac58cd
try "setApprovalForAll-nonABI" $ATT "setApprovalForAll(address,bool)" $ATT true
