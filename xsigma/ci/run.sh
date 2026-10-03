#!/usr/bin/env bash
# H-11 xSigma: live-state snapshot (read-only). Writes ci-out/live_state.json
set -euo pipefail
mkdir -p ci-out
RPC="${FORK_RPC_URL:-${RPC_URL:-https://ethereum-rpc.publicnode.com}}"
P=0x3333333ACdEdBbC9Ad7bda0876e60714195681c5
L=0x88E11412BB21d137C217fd8b73982Dc0ED3665d7
AU=0xb843B122ac2fF261f425Bf0F639B5718e25c0691
S2=0x77777777778E9F1259A32f4d605aDDe67d576c79
DAI=0x6B175474E89094C44Da98b954EedeAC495271d0F
USDC=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
USDT=0xdAC17F958D2ee523a2206206994597C13D831ec7

c(){ local to=$1; local sig=$2; shift 2; cast call "$to" "$sig" "$@" --rpc-url "$RPC" 2>/dev/null | head -1; }
BN=$(cast block-number --rpc-url "$RPC")
DAI_ACT=$(c $DAI "balanceOf(address)(uint256)" $P | awk '{print $1}')
USDC_ACT=$(c $USDC "balanceOf(address)(uint256)" $P | awk '{print $1}')
USDT_ACT=$(c $USDT "balanceOf(address)(uint256)" $P | awk '{print $1}')
DAI_INT=$(c $P "balances(uint256)(uint256)" 0 | awk '{print $1}')
USDC_INT=$(c $P "balances(uint256)(uint256)" 1 | awk '{print $1}')
USDT_INT=$(c $P "balances(uint256)(uint256)" 2 | awk '{print $1}')
VP=$(c $P "get_virtual_price()(uint256)" | awk '{print $1}')
LPS=$(c $L "totalSupply()(uint256)" | awk '{print $1}')
AU_DAI=$(c $DAI "balanceOf(address)(uint256)" $AU | awk '{print $1}')
AU_USDC=$(c $USDC "balanceOf(address)(uint256)" $AU | awk '{print $1}')
AU_USDT=$(c $USDT "balanceOf(address)(uint256)" $AU | awk '{print $1}')
S2_SUP=$(c $S2 "totalSupply()(uint256)" | awk '{print $1}')
ETH=$(cast balance $P --rpc-url "$RPC")

cat > ci-out/live_state.json <<EOF
{
  "block": $BN,
  "pool": "$P",
  "internal": {"DAI": "$DAI_INT", "USDC": "$USDC_INT", "USDT": "$USDT_INT"},
  "actual":   {"DAI": "$DAI_ACT", "USDC": "$USDC_ACT", "USDT": "$USDT_ACT"},
  "virtual_price": "$VP",
  "lp_total_supply": "$LPS",
  "auction": {"DAI": "$AU_DAI", "USDC": "$AU_USDC", "USDT": "$AU_USDT"},
  "sig2_total_supply": "$S2_SUP",
  "pool_eth_wei": "$ETH"
}
EOF
cat ci-out/live_state.json
