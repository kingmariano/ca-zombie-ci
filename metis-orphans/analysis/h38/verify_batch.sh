#!/bin/bash
# H-38 verification batch: holders, LP markets, admin contracts, recent txs
RPC="https://andromeda.metis.io/?owner=1088"
BLK=23238721
OUT="raw/verify_batch.txt"
: > "$OUT"
say(){ echo "$@" | tee -a "$OUT"; }
r(){ cast call --rpc-url "$RPC" --block "$BLK" "$1" "$2" "${@:3}" 2>&1; }

PAIRA=0x3D60aFEcf67e6ba950b499137A72478B2CA7c5A1
PAIRB=0x59051B5F5172b69E66869048Dc69D35dB0B3610d
PAIRC=0x5Ae3ee7fBB3Cb28C17e7ADc3a6Ae605ae2465091
PAIRD=0x9dAbD9257E55230Fa17415BF9a6946085f533a00
FACT=0x70f51d68D16e8f9e418441280342BD43AC9Dff9f

say "== LP holder balances at block $BLK =="
for H in 0xC92819F6497708D805F37FFFD082FE46E10Cac27 0x9d1dbB49b2744A1555EDbF1708D64dC71B0CB052 0x4a642be622EBa7C40eFC06A8f8E1B3278b1fce4E 0x5F80aC2F1562C82193692C6eB16d6C3A23852C1a; do
  say "pairA.bal($H) = $(r $PAIRA 'balanceOf(address)(uint256)' $H)"
done
for H in 0xCCa7A7952683e97af9cf8183064fd5EB6828dC16 0x9d1dbB49b2744A1555EDbF1708D64dC71B0CB052; do
  say "pairB.bal($H) = $(r $PAIRB 'balanceOf(address)(uint256)' $H)"
done
for H in 0x9d1dbB49b2744A1555EDbF1708D64dC71B0CB052 0x363F2fF189e499116baa89322F1a3Ade52EfE388 0x958d04d4b6bE440a54933523a88B2fe775b91c47 0xC92819F6497708D805F37FFFD082FE46E10Cac27; do
  say "pairC.bal($H) = $(r $PAIRC 'balanceOf(address)(uint256)' $H)"
done
for H in 0xDc6caB8F2E5024D493d9ba780f2223073303A822 0x4a642be622EBa7C40eFC06A8f8E1B3278b1fce4E; do
  say "pairD.bal($H) = $(r $PAIRD 'balanceOf(address)(uint256)' $H)"
done

say ""
say "== admin code checks =="
say "feeToSetter 0x9C003fdc... code len: $(cast code --rpc-url $RPC --block $BLK 0x9C003fdcb0815C1Cf4b3bd45220Ee891bBbEdE97 | wc -c)"
say "feeTo 0x4a642be6... code len: $(cast code --rpc-url $RPC --block $BLK 0x4a642be622EBa7C40eFC06A8f8E1B3278b1fce4E | wc -c)"
say "NETTFarm owner 0xa8131b0A... code len: $(cast code --rpc-url $RPC --block $BLK 0xa8131b0A154f20BDAe60f2D488273D967EC67900 | wc -c)"
say "ScoresFarm owner 0x963dCDB2... code len: $(cast code --rpc-url $RPC --block $BLK 0x963dCDB27305FcC5f025e6cF2d1Bcd6bB3C33762 | wc -c)"
say "pairD EOA 0xDc6caB8F... code len: $(cast code --rpc-url $RPC --block $BLK 0xDc6caB8F2E5024D493d9ba780f2223073303A822 | wc -c)"

say ""
say "== LP-as-token market check: factory.getPair(LP_X, token) =="
for LP in $PAIRA $PAIRC; do
  for T in 0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000 0x420000000000000000000000000000000000000A 0xbB06DCA3AE6887fAbF931640f67cab3e3a16F4dC 0xEA32A96608495e54156Ae48931A7c20f0dcc1a21 0x90fE084F877C65e1b577c7b2eA64B8D8dd1AB278; do
    say "getPair($LP,$T) = $(r $FACT 'getPair(address,address)(address)' $LP $T)"
  done
done

say ""
say "== NETT token =="
say "name: $(r 0x90fE084F877C65e1b577c7b2eA64B8D8dd1AB278 'name()(string)')"
say "symbol: $(r 0x90fE084F877C65e1b577c7b2eA64B8D8dd1AB278 'symbol()(string)')"
say "decimals: $(r 0x90fE084F877C65e1b577c7b2eA64B8D8dd1AB278 'decimals()(uint8)')"
say "totalSupply: $(r 0x90fE084F877C65e1b577c7b2eA64B8D8dd1AB278 'totalSupply()(uint256)')"
say "NETTFarm nett bal: $(r 0x90fE084F877C65e1b577c7b2eA64B8D8dd1AB278 'balanceOf(address)(uint256)' 0x9d1dbB49b2744A1555EDbF1708D64dC71B0CB052)"

say ""
say "== NETTFarm rewarders (pools 21-24) =="
for A in 0x4CCceDE3d5A6fc96FF921b8E765446c827f4B294 0x1DdF972f2cCBF896B4df62bEfb434f7e9F553634 0x876488D7BEb48EDe40E74346a70FE587E8F7da66 0xD8A5EE9C79f8b095653B60d19939bC7Db4236E08; do
  say "$A code len: $(cast code --rpc-url $RPC --block $BLK $A | wc -c) | rewardToken: $(r $A 'rewardToken()(address)')"
done
