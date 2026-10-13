#!/bin/bash
# ChildB: generate job list for all bridge + token + endpoint reads.
# Output: jobs.txt  (one job per line, format CHAIN|RPC|BLOCK|LABEL|TO|SIG|ARGS)
set -euo pipefail
cd "$(dirname "$0")"
BRIDGE=0x9C6D5a71FdD306329287a835e9B8EDb7F0F17898
TRUSTED_REMOTE=0x9c6d5a71fdd306329287a835e9b8edb7f0f178989c6d5a71fdd306329287a835e9b8edb7f0f17898
REMOTE_CHAIN=230
: > jobs.txt
while IFS='|' read -r chain cid rpc llama; do
  case "$chain" in ''|\#*) continue ;; esac
  block=$(grep "^${chain}|" blocks.txt | cut -d'|' -f2)
  emit() { printf '%s|%s|%s|%s|%s|%s|%s\n' "$chain" "$rpc" "$block" "$1" "$2" "$3" "$4" >> jobs.txt; }
  emit owner           "$BRIDGE" "owner()(address)" ""
  emit remoteChainId   "$BRIDGE" "remoteChainId()(uint16)" ""
  emit trustedRemote   "$BRIDGE" "trustedRemoteLookup(uint16)(bytes)" "$REMOTE_CHAIN"
  emit customAdapter   "$BRIDGE" "useCustomAdapterParams()(bool)" ""
  emit lzEndpoint      "$BRIDGE" "lzEndpoint()(address)" ""
done < chains.env
while IFS='|' read -r chain sym token; do
  case "$chain" in ''|\#*) continue ;; esac
  rpc=$(grep "^${chain}|" chains.env | cut -d'|' -f3)
  block=$(grep "^${chain}|" blocks.txt | cut -d'|' -f2)
  emit() { printf '%s|%s|%s|%s|%s|%s|%s\n' "$chain" "$rpc" "$block" "$1" "$2" "$3" "$4" >> jobs.txt; }
  emit "tok.${sym}.supported"  "$BRIDGE" "supportedTokens(address)(bool)" "$token"
  emit "tok.${sym}.rate"       "$BRIDGE" "LDtoSDConversionRate(address)(uint256)" "$token"
  emit "tok.${sym}.tvlSD"      "$BRIDGE" "totalValueLockedSD(address)(uint256)" "$token"
  emit "tok.${sym}.accrued"    "$BRIDGE" "accruedFeeLD(address)(uint256)" "$token"
  emit "tok.${sym}.balBridge"  "$token"  "balanceOf(address)(uint256)" "$BRIDGE"
  emit "tok.${sym}.decimals"   "$token"  "decimals()(uint8)" ""
done < tokens.env
wc -l jobs.txt
