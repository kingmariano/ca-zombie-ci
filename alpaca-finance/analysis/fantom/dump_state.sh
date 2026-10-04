#!/usr/bin/env bash
# READ-ONLY state dump: cast call / eth_getStorageAt only. No transactions.
FTM=${FTM:-https://rpcapi.fantom.network}
BN=$(cast block-number --rpc-url $FTM)
TS=$(cast block latest --field timestamp --rpc-url $FTM)
echo "chain=fantom block=$BN ts=$TS"
echo

vaults=(
"ibFTM 0xc1018f4Bba361A1Cc60407835e156595e92EF7Ad 0x95bBd366FaA1D7F29484Cc33Cd5c89905fd29a12 0xd36B6cf6Aa96Eb7185798ebccb8c5c5a82434067"
"ibUSDC 0x831332f94C4A0092040b28ECe9377AfEfF34B25a 0xE986679b06E9D4c72C5B504c86Eb64d546710Aa6 0xBbf2a7FacDB318F7670cE87A5F6571Bb001d8F06"
"ibALPACA 0x2E7f32e38EA5a5fcb4494d9B626d2d393B176B1E 0x23ff13d43702cA95a6369736dBFf6Ea718b5F0b0 0xADaBC5FC5da42c85A84e66096460C769a151A8F8"
"ibTOMB 0x60dDe8BBE160fe033fACB3446Cf7795cC575B171 0x83875cB3B520275183c5c383C8745199293Cd89C 0xbA7A1e40A555135BE83F6B19E2efeA5332a0fa3B"
)
for row in "${vaults[@]}"; do
  set -- $row
  name=$1; v=$2; c=$3; model=$4
  echo "### VAULT $name $v"
  echo -n "token=";            cast call $v "token()(address)" --rpc-url $FTM
  echo -n "debtToken=";        cast call $v "debtToken()(address)" --rpc-url $FTM
  echo -n "owner=";            cast call $v "owner()(address)" --rpc-url $FTM
  echo -n "totalToken=";       cast call $v "totalToken()(uint256)" --rpc-url $FTM
  echo -n "totalSupply=";      cast call $v "totalSupply()(uint256)" --rpc-url $FTM
  echo -n "vaultDebtVal=";     cast call $v "vaultDebtVal()(uint256)" --rpc-url $FTM
  echo -n "vaultDebtShare=";   cast call $v "vaultDebtShare()(uint256)" --rpc-url $FTM
  echo -n "reservePool=";      cast call $v "reservePool()(uint256)" --rpc-url $FTM
  echo -n "fairLaunchPoolId="; cast call $v "fairLaunchPoolId()(uint256)" --rpc-url $FTM
  echo -n "nextPositionID=";   cast call $v "nextPositionID()(uint256)" --rpc-url $FTM
  echo -n "lastAccrueTime=";   cast call $v "lastAccrueTime()(uint256)" --rpc-url $FTM
  tok=$(cast call $v "token()(address)" --rpc-url $FTM)
  echo -n "token.balanceOf(vault)="; cast call $tok "balanceOf(address)(uint256)" $v --rpc-url $FTM
  echo -n "token.symbol=";     cast call $tok "symbol()(string)" --rpc-url $FTM
  echo -n "token.decimals=";   cast call $tok "decimals()(uint8)" --rpc-url $FTM
  echo -n "impl=";             cast storage $v 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $FTM | sed 's/^0x000000000000000000000000/0x/'
  echo -n "decimals()=";       cast call $v "decimals()(uint8)" --rpc-url $FTM
  echo -n "config.isWorker?";  cast call $c "isWorker(address)(bool)" 0x29A7929520ADdC7D3000a81129d4E5Aa7a571f49 --rpc-url $FTM 2>&1 | head -1
  echo
done
