#!/usr/bin/env bash
# Read-only state probes for Alpaca AUSD on BSC. Usage: ./query.sh [block]
# Uses NodeReal BSC archive endpoint if NODEREAL_API_KEY is set (sourced from /home/heisenberg/CA/.env).
set -u
if [ -z "${NODEREAL_API_KEY:-}" ] && [ -f /home/heisenberg/CA/.env ]; then
  set -a; . /home/heisenberg/CA/.env >/dev/null 2>&1; set +a
fi
if [ -n "${NODEREAL_API_KEY:-}" ]; then
  RPC="https://bsc-mainnet.nodereal.io/v1/${NODEREAL_API_KEY}"
else
  RPC="https://bsc-rpc.publicnode.com"
fi
BLOCK="${1:-$(command cast block-number --rpc-url "$RPC")}"
cast() { command cast call "$@" --rpc-url "$RPC" --block "$BLOCK" 2>&1; }

AUSD=0xDCEcf0664C33321CECA2effcE701E710A2D28A3F
BK=0xD0AEcee1520B5F9925D952405F9A06Dcd8fd6e6C
SDE=0xe09E20aB1F91D1f7EAa0e73446b0617d89501b0E
SS=0x9b601FBAd19036D6E074caDAF61CD70ea2513318
CPC=0x06D280abee1073B83A01fE778B6145e850e87162
PM=0xABA0b03eaA3684EB84b51984add918290B41Ee19
FMM=0xE7a49Ae5c9500d18481e0E0EFBFF1D5d0FF75DE3
SSM=0xd16004424b9C3f0A7C74C4c8dcDa0D8C4D513fAC
LE=0x51B893FF705b04188784da29d9BAdE2d72dD353C
SAD=0xD409DA25D32473EFB0A1714Ab3D0a6763bCe4749

echo "=== block $BLOCK rpc=$(echo "$RPC" | sed -E 's#(https://[^/]+).*#\1#') ==="
echo "ausd.name:        $(cast $AUSD 'name()(string)')"
echo "ausd.symbol:      $(cast $AUSD 'symbol()(string)')"
echo "ausd.decimals:    $(cast $AUSD 'decimals()(uint8)')"
echo "ausd.totalSupply: $(cast $AUSD 'totalSupply()(uint256)')"
echo "ausd.bal(SDE):    $(cast $AUSD 'balanceOf(address)(uint256)' $SDE)"
echo "ausd.bal(FMM):    $(cast $AUSD 'balanceOf(address)(uint256)' $FMM)"
echo "ausd.bal(SSM):    $(cast $AUSD 'balanceOf(address)(uint256)' $SSM)"
echo "ausd.bal(PM):     $(cast $AUSD 'balanceOf(address)(uint256)' $PM)"
echo "bk.paused:        $(cast $BK 'paused()(bool)')"
echo "bk.live:          $(cast $BK 'live()(uint256)' 2>/dev/null)"
echo "bk.totalStablecoinIssued: $(cast $BK 'totalStablecoinIssued()(uint256)')"
echo "bk.stablecoin(SDE):       $(cast $BK 'stablecoin(address)(uint256)' $SDE)"
echo "bk.systemBadDebt(SDE):    $(cast $BK 'systemBadDebt(address)(uint256)' $SDE)"
echo "bk.stablecoin(FMM):       $(cast $BK 'stablecoin(address)(uint256)' $FMM)"
echo "ss.live:          $(cast $SS 'live()(uint256)')"
echo "ss.cagedTimestamp:$(cast $SS 'cagedTimestamp()(uint256)')"
echo "ss.cageCoolDown:  $(cast $SS 'cageCoolDown()(uint256)')"
echo "ss.debt:          $(cast $SS 'debt()(uint256)')"
echo "sde.live:         $(cast $SDE 'live()(uint256)')"
echo "sde.paused:       $(cast $SDE 'paused()(bool)')"
echo "sde.surplusBuffer:$(cast $SDE 'surplusBuffer()(uint256)')"
echo "le.live:          $(cast $LE 'live()(uint256)')"
echo "le.paused:        $(cast $LE 'paused()(bool)')"
echo "pm.paused:        $(cast $PM 'paused()(bool)')"
echo "pm.lastPositionId:$(cast $PM 'lastPositionId()(uint256)')"
echo "fmm.max:          $(cast $FMM 'max()(uint256)')"
echo "fmm.feeRate:      $(cast $FMM 'feeRate()(uint256)')"
echo "fmm.paused:       $(cast $FMM 'paused()(bool)')"
echo "ssm.paused:       $(cast $SSM 'paused()(bool)')"
echo "ssm.feeIn:        $(cast $SSM 'feeIn()(uint256)')"
echo "ssm.feeOut:       $(cast $SSM 'feeOut()(uint256)')"
echo "ssm.poolId:       $(cast $SSM 'collateralPoolId()(bytes32)')"
echo "sad.live:         $(cast $SAD 'live()(uint256)')"
echo "sad.paused:       $(cast $SAD 'paused()(bool)')"
echo "sad.stablecoin:   $(cast $SAD 'stablecoin()(address)')"
echo "sad.bookKeeper:   $(cast $SAD 'bookKeeper()(address)')"
