#!/usr/bin/env bash
# Read-only state dump. No transactions.
set -u
declare -A RPCS=( [base]="https://base-rpc.publicnode.com" [mantle]="https://rpc.mantle.xyz" [arbitrum]="https://arb1.arbitrum.io/rpc" [blast]="https://blast-rpc.publicnode.com" )
declare -A SYMMIO=( [base]="0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43" [mantle]="0x2Ecc7da3Cc98d341F987C85c3D9FC198570838B5" [arbitrum]="0x8F06459f184553e5d04F07F868720BDaCAB39395" [blast]="0x3d17f073cCb9c3764F105550B0BCF9550477D266" )
declare -A MA=( [base]="0x8Ab178C07184ffD44F0ADfF4eA2ce6cFc33F3b86" [mantle]="0xECbd0788bB5a72f9dFDAc1FFeAAF9B7c2B26E456" [arbitrum]="0x141269E29a770644C34e05B127AB621511f20109" [blast]="0x083267D20Dbe6C2b0A83Bd0E601dC2299eD99015" )
for chain in base mantle arbitrum blast; do
  rpc=${RPCS[$chain]}; sym=${SYMMIO[$chain]}; ma=${MA[$chain]}
  echo "############ $chain (block $(cast block-number --rpc-url $rpc 2>/dev/null)) ############"
  echo "-- symmio=$sym codesize=$(cast code --rpc-url $rpc $sym 2>/dev/null | wc -c)"
  echo -n "getCollateral: "; cast call --rpc-url $rpc $sym "getCollateral()(address)" 2>&1 | head -1
  echo -n "pauseState: "; cast call --rpc-url $rpc $sym "pauseState()(bool,bool,bool,bool,bool,bool)" 2>&1 | head -1
  echo -n "getFeeCollector: "; cast call --rpc-url $rpc $sym "getFeeCollector()(address)" 2>&1 | head -1
  echo -n "getMuonConfig: "; cast call --rpc-url $rpc $sym "getMuonConfig()(uint256,uint256,uint256,address)" 2>&1 | head -1
  echo "-- multiaccount=$ma codesize=$(cast code --rpc-url $rpc $ma 2>/dev/null | wc -c)"
  echo -n "  owner: "; cast call --rpc-url $rpc $ma "owner()(address)" 2>&1 | head -1
  echo -n "  paused: "; cast call --rpc-url $rpc $ma "paused()(bool)" 2>&1 | head -1
  echo -n "  symmioAddress: "; cast call --rpc-url $rpc $ma "symmioAddress()(address)" 2>&1 | head -1
  echo -n "  accountsAdmin: "; cast call --rpc-url $rpc $ma "accountsAdmin()(address)" 2>&1 | head -1
  echo -n "  apiExecutor: "; cast call --rpc-url $rpc $ma "apiExecutor()(address)" 2>&1 | head -1
done
