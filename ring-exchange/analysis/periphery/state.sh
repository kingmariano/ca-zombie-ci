#!/usr/bin/env bash
# Live-state reader (read-only eth_call / eth_getBalance). HyperEVM 999.
set -u
RPC="${RPC:-https://rpc.hyperliquid.xyz/evm}"
BLK=$(cast block-number --rpc-url "$RPC")
echo "BLOCK=$BLK"
bal() { cast balance "$1" --rpc-url "$RPC" --block "$BLK"; }
b20() { cast call "$1" "balanceOf(address)(uint256)" "$2" --rpc-url "$RPC" --block "$BLK"; }
allow() { cast call "$1" "allowance(address,address)(uint256)" "$2" "$3" --rpc-url "$RPC" --block "$BLK"; }

UR=0xE65081EFa5ad4A196B1Df768716c337e6AB140E9
FEWE=0x068B60ECbC934b0a0dde20FdFf0dE925b97B971F
ROUTER=0x701D1d675415efA2d2429fB122ccC6dD4FCcA959
FACTORY=0x6B65ed7315274eB9EF06A48132EB04D808700b86
FWWETH=0x9e1148bC3665a9f7C35F313d89c0432c34928AEf
FWUETH=0x0C47cbbEDE5d8c6f9614cF770C26c3315205C397
FWUSDC=0xd2646b9B02859416D8cBc759F85f0676f6E19974
FWUSDT0=0x7576dd9a2775bFd789616d9eA7A2af21d06782D0
FWUSDH=0x09D21E89EF332347eb3E1E496f1265a600e364C1
WHYPE=0x5555555555555555555555555555555555555555
UETH=0xBe6727B535545C67d5cAa73dEa54865B92CF7907
USDC=0xb88339CB7199b77E23DB6E890353E22632Ba630f
USDT0=0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb
USDH=0x111111a1a0667d36bD57c0A9f569b98057111111
PERMIT2=0x000000000022D473030F116dDEE9F6B43aC78BA3

for pair in "UR:$UR" "FEWE:$FEWE" "ROUTER:$ROUTER" "FACTORY:$FACTORY"; do
  name=${pair%%:*}; addr=${pair##*:}
  echo "== $name ($addr) native=`bal $addr`"
  for t in "FWWETH:$FWWETH" "FWUETH:$FWUETH" "FWUSDC:$FWUSDC" "FWUSDT0:$FWUSDT0" "FWUSDH:$FWUSDH" "WHYPE:$WHYPE" "UETH:$UETH" "USDC:$USDC" "USDT0:$USDT0" "USDH:$USDH"; do
    tn=${t%%:*}; ta=${t##*:}
    echo "   $name.balanceOf($tn)=`b20 $ta $addr`"
  done
  sleep 1
done

echo "== allow(underlying, src, wrapped) - src allowances TO fw tokens"
for c in "UR:$UR" "FEWE:$FEWE" "ROUTER:$ROUTER"; do
  cn=${c%%:*}; ca=${c##*:}
  for w in "WHYPE:$WHYPE:$FWWETH" "UETH:$UETH:$FWUETH" "USDC:$USDC:$FWUSDC" "USDT0:$USDT0:$FWUSDT0" "USDH:$USDH:$FWUSDH"; do
    un=${w%%:*}; rest=${w#*:}; ua=${rest%%:*}; wa=${rest##*:}
    echo "   $cn: allowance($un, $cn, fw)=`allow $ua $ca $wa`"
  done
done

echo "== misc views"
echo "UR.receive? (no owner); FEWE.WETH()=`cast call $FEWE 'WETH()(address)' --rpc-url $RPC --block $BLK`"
echo "FEWE.fwWETH()=`cast call $FEWE 'fwWETH()(address)' --rpc-url $RPC --block $BLK`"
echo "ROUTER.factory()=`cast call $ROUTER 'factory()(address)' --rpc-url $RPC --block $BLK`"
echo "ROUTER.WETH()=`cast call $ROUTER 'WETH()(address)' --rpc-url $RPC --block $BLK`"
echo "ROUTER.fewFactory()=`cast call $ROUTER 'fewFactory()(address)' --rpc-url $RPC --block $BLK`"
echo "ROUTER.fwWETH()=`cast call $ROUTER 'fwWETH()(address)' --rpc-url $RPC --block $BLK`"
echo "FACTORY.core()=`cast call $FACTORY 'core()(address)' --rpc-url $RPC --block $BLK`"
echo "FACTORY.paused()=`cast call $FACTORY 'paused()(bool)' --rpc-url $RPC --block $BLK`"
echo "FACTORY.allWrappedTokensLength()=`cast call $FACTORY 'allWrappedTokensLength()(uint256)' --rpc-url $RPC --block $BLK`"
echo "FACTORY.parameter()=`cast call $FACTORY 'parameter()(address)' --rpc-url $RPC --block $BLK`"
echo "Permit2 allowance(UR as spender)?"; echo "done"
