RPC=https://ethereum-rpc.publicnode.com
F=0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
WETH=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
SWRV=0xB8BAa0e4287890a5F79863aB62b7F175ceCbD433
echo "== UniV2 getPair(SWRV,WETH) =="
PAIR=$(cast call $F "getPair(address,address)(address)" $SWRV $WETH --rpc-url $RPC)
echo "pair=$PAIR"
if [ "$PAIR" != "0x0000000000000000000000000000000000000000" ]; then
  echo -n "token0: "; cast call $PAIR "token0()(address)" --rpc-url $RPC
  echo -n "reserves: "; cast call $PAIR "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC | head -3
  echo -n "pair WETH bal: "; cast call $WETH "balanceOf(address)(uint256)" $PAIR --rpc-url $RPC
  echo -n "pair SWRV bal: "; cast call $SWRV "balanceOf(address)(uint256)" $PAIR --rpc-url $RPC
fi
echo "== SWRV totalSupply =="; cast call $SWRV "totalSupply()(uint256)" --rpc-url $RPC
