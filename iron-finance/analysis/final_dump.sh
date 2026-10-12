#!/usr/bin/env bash
# Final state dump at pinned blocks. RPCs overridable via env (PRPC/ARPC/FRPC).
# Writes only numbers/addresses - never the RPC URLs themselves.
PRPC="${PRPC:-https://polygon-bor-rpc.publicnode.com}"
ARPC="${ARPC:-https://avalanche-c-chain-rpc.publicnode.com}"
FRPC="${FRPC:-https://rpcapi.fantom.network}"
OUT="${OUT:-analysis/final-state-dump.txt}"
: > "$OUT"

PB=95383464
AB=$(cast block-number --rpc-url "$ARPC" 2>/dev/null); AB=${AB:-97324376}
FB=123651628

{
echo "=== POLYGON block $PB ==="
for pool in 0x837503e8a8753ae17fb8c8151b8e6f586defcb57 0x4a783cd1b4543559ece45db47e07e0cb59e55c09 0xe440ccc13e6f273c110cf3cf4087c23a66b8e872 0xCaEb732167aF742032D13A9e76881026f91Cd087; do
  echo "--- pool $pool @$PB"
  echo -n "tokens: "; cast call $pool "getTokens()(address[])" --rpc-url "$PRPC" --block $PB
  echo -n "balances: "; cast call $pool "getTokenBalances()(uint256[])" --rpc-url "$PRPC" --block $PB
  echo -n "adminBalances: "; cast call $pool "getAdminBalances()(uint256[])" --rpc-url "$PRPC" --block $PB
  echo -n "paused: "; cast call $pool "paused()(bool)" --rpc-url "$PRPC" --block $PB
  echo -n "owner: "; cast call $pool "owner()(address)" --rpc-url "$PRPC" --block $PB
  echo -n "vp: "; cast call $pool "getVirtualPrice()(uint256)" --rpc-url "$PRPC" --block $PB
  L=$(cast call $pool "getLpToken()(address)" --rpc-url "$PRPC" --block $PB | head -1)
  echo "lpToken: $L"
  echo -n "lpSupply: "; cast call "$L" "totalSupply()(uint256)" --rpc-url "$PRPC" --block $PB
done
echo "--- IS3USD pool actual token balances @$PB"
echo -n "USDC.e: "; cast call 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174 "balanceOf(address)(uint256)" 0x837503e8a8753ae17fb8c8151b8e6f586defcb57 --rpc-url "$PRPC" --block $PB
echo -n "USDT: ";   cast call 0xc2132D05D31c914a87C6611C10748AEb04B58e8F "balanceOf(address)(uint256)" 0x837503e8a8753ae17fb8c8151b8e6f586defcb57 --rpc-url "$PRPC" --block $PB
echo -n "DAI: ";    cast call 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063 "balanceOf(address)(uint256)" 0x837503e8a8753ae17fb8c8151b8e6f586defcb57 --rpc-url "$PRPC" --block $PB
echo "--- holders @$PB"
echo -n "IronChef IS3USD LP: ";  cast call 0xb4d09ff3dA7f9e9A2BA029cb0A81A989fd7B8f17 "balanceOf(address)(uint256)" 0x1fd1259fa8cdc60c6e8c86cfa592ca1b8403dfad --rpc-url "$PRPC" --block $PB
echo -n "IronChef IRONLP: ";     cast call 0x985D40feDAA3208DAbaCDFDCA00CbeAAc9543949 "balanceOf(address)(uint256)" 0x1fd1259fa8cdc60c6e8c86cfa592ca1b8403dfad --rpc-url "$PRPC" --block $PB
echo -n "IronChef DFYNLP_USDC_ICE: "; cast call 0x34832D9AC4127a232C1919d840f7aaE0fcb7315B "balanceOf(address)(uint256)" 0x1fd1259fa8cdc60c6e8c86cfa592ca1b8403dfad --rpc-url "$PRPC" --block $PB
echo -n "IronChef DFYNLP_ICE_IRON: "; cast call 0x7e2cc09d3d36b3aF6EdfF55B214fd62885234E95 "balanceOf(address)(uint256)" 0x1fd1259fa8cdc60c6e8c86cfa592ca1b8403dfad --rpc-url "$PRPC" --block $PB
echo -n "IronChef FLP: ";        cast call 0xf1EE78544a1118F2efb87f7EaCd9f1E6e80e1ea5 "balanceOf(address)(uint256)" 0x1fd1259fa8cdc60c6e8c86cfa592ca1b8403dfad --rpc-url "$PRPC" --block $PB
echo -n "ERCFund2 IS3USD LP: ";  cast call 0xb4d09ff3dA7f9e9A2BA029cb0A81A989fd7B8f17 "balanceOf(address)(uint256)" 0x43c085b5aba4e83a7dd1a478b7458d1d472ff6b4 --rpc-url "$PRPC" --block $PB
echo -n "BeefyStrat IS3USD LP: ";cast call 0xb4d09ff3dA7f9e9A2BA029cb0A81A989fd7B8f17 "balanceOf(address)(uint256)" 0x6195187d06948fb14b20fd3c639f8cb8a335c29c --rpc-url "$PRPC" --block $PB
echo -n "GnosisSafe IS3USD LP: ";cast call 0xb4d09ff3dA7f9e9A2BA029cb0A81A989fd7B8f17 "balanceOf(address)(uint256)" 0xeae55893cc8637c16cf93d43b38aa022d689fa62 --rpc-url "$PRPC" --block $PB
echo -n "feeController IS3USD LP: "; cast call 0xb4d09ff3dA7f9e9A2BA029cb0A81A989fd7B8f17 "balanceOf(address)(uint256)" 0x66c8096fa2f5fd21062a27c202a330e64e0ae2fc --rpc-url "$PRPC" --block $PB
echo -n "Beefy vault balance(): "; cast call 0x0C4705EBd2BF69660b72f9E9B684714c9e341942 "balance()(uint256)" --rpc-url "$PRPC" --block $PB
echo -n "Beefy vault totalSupply: "; cast call 0x0C4705EBd2BF69660b72f9E9B684714c9e341942 "totalSupply()(uint256)" --rpc-url "$PRPC" --block $PB
} >> "$OUT" 2>&1

{
echo "=== AVALANCHE block $AB (latest) ==="
echo "--- avax pool 0x952BDA8A"
echo -n "tokens: "; cast call 0x952BDA8A83c3D5F398a686bb4e8C6DD90072d523 "getTokens()(address[])" --rpc-url "$ARPC"
echo -n "balances: "; cast call 0x952BDA8A83c3D5F398a686bb4e8C6DD90072d523 "getTokenBalances()(uint256[])" --rpc-url "$ARPC"
echo -n "adminBalances: "; cast call 0x952BDA8A83c3D5F398a686bb4e8C6DD90072d523 "getAdminBalances()(uint256[])" --rpc-url "$ARPC"
echo -n "paused: "; cast call 0x952BDA8A83c3D5F398a686bb4e8C6DD90072d523 "paused()(bool)" --rpc-url "$ARPC"
echo -n "owner: "; cast call 0x952BDA8A83c3D5F398a686bb4e8C6DD90072d523 "owner()(address)" --rpc-url "$ARPC"
echo -n "lpSupply: "; cast call 0xc143a1500ca4a471eE9cc70B9AC0C739576F84bb "totalSupply()(uint256)" --rpc-url "$ARPC"
echo -n "farm(0x073667be) LP: "; cast call 0xc143a1500ca4a471eE9cc70B9AC0C739576F84bb "balanceOf(address)(uint256)" 0x073667be2bc3efc8c03caf6c35632eb8ad6dfc47 --rpc-url "$ARPC"
} >> "$OUT" 2>&1

{
echo "=== FANTOM block $FB ==="
echo "--- fantom pool 0x952BDA8A"
echo -n "tokens: "; cast call 0x952BDA8A83c3D5F398a686bb4e8C6DD90072d523 "getTokens()(address[])" --rpc-url "$FRPC" --block $FB
echo -n "balances: "; cast call 0x952BDA8A83c3D5F398a686bb4e8C6DD90072d523 "getTokenBalances()(uint256[])" --rpc-url "$FRPC" --block $FB
echo -n "adminBalances: "; cast call 0x952BDA8A83c3D5F398a686bb4e8C6DD90072d523 "getAdminBalances()(uint256[])" --rpc-url "$FRPC" --block $FB
echo -n "paused: "; cast call 0x952BDA8A83c3D5F398a686bb4e8C6DD90072d523 "paused()(bool)" --rpc-url "$FRPC" --block $FB
echo -n "owner: "; cast call 0x952BDA8A83c3D5F398a686bb4e8C6DD90072d523 "owner()(address)" --rpc-url "$FRPC" --block $FB
echo -n "lpSupply: "; cast call 0xc143a1500ca4a471eE9cc70B9AC0C739576F84bb "totalSupply()(uint256)" --rpc-url "$FRPC" --block $FB
echo "--- fantom controller markets @$FB"
for m in 0xf20E5dD9bb5bA61a30Eb7E0F4568d52cCfa21412 0xdfce3E14a8c77D32fe2455a9E56424F149E2F271 0xa52022FDda46CDD4e6305adf1842726D6983aEe7 0xCa5427DB7aD27acbCF53F3CFA94714ef86111CA4 0xA06a706b2AD8FAABE5cB1CE01E0C705c24C4E71e; do
  echo -n "$m cash="; cast call $m "getCash()(uint256)" --rpc-url "$FRPC" --block $FB | head -1
  echo -n "$m borrows="; cast call $m "totalBorrows()(uint256)" --rpc-url "$FRPC" --block $FB | head -1
done
} >> "$OUT" 2>&1
wc -l "$OUT"
