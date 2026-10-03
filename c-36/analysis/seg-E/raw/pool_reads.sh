#!/bin/bash
RPC=https://ethereum-rpc.publicnode.com
call(){ cast call "$1" "$2" $3 --rpc-url $RPC 2>&1; }
WETH=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
for pair in "chicken:0x87ae4928f6582376a0489e9f70750334bbc2eb35" "gov:0x4dac3e07316d2a31baabb252d89663dee8f76f09" "mystery:0x07261a6e37adbfab11e6474bca54634c7782b195" "star:0xb60c12d2a4069d339f49943fc45df6785b436096" "bdp:0x0de845955e2bf089012f682fe9bc81dd5f11b372"; do
  n=${pair%%:*}; a=${pair##*:}
  echo "### $n $a"
  echo -n "poolLength: "; call $a "poolLength()(uint256)"
  echo -n "totalAllocPoint: "; call $a "totalAllocPoint()(uint256)"
  echo -n "owner: "; call $a "owner()(address)"
  echo -n "WETH bal: "; call $WETH "balanceOf(address)(uint256)" $a
  for i in 0 1 2 3; do
    echo -n "poolInfo($i): "; call $a "poolInfo(uint256)(address,uint256,uint256,uint256)" $i | tr '\n' ' '; echo
  done
done
