#!/usr/bin/env bash
# H-09 Equilibrium — custom CI job: live-state dump + endpoint liveness probes.
# Read-only. Writes results to ci-out/. Never prints secrets. Always exits 0.
set -uo pipefail

OUT="ci-out"
mkdir -p "$OUT"
RPC="${FORK_RPC_URL:-${RPC_URL:-https://ethereum-rpc.publicnode.com}}"
CAST="cast"

V2_BRIDGE=0x267c4d894db79a3023e266B84401e58f7434e1F1
V2_HANDLER=0xe2a1D7C0c2ED4d3937bd6f93d9aCeA7498232F2F
V1_BRIDGE=0x13D3d12478044E6Ea1b76F2A52d4bb6Dd3Ec867F
V1_HANDLER=0x47840AfF8b7fd9fdE5C3f11D5Ebc66e867C2f288
EQ=0xA5eDE2FEE620ac3d68065EC01F26F9dd99850B82
EQD2=0xfB41E1074DbE88EEb0Da01D52565774165DA03d3
GENS=0x9D9152874294aC0489eCf191376F48db99014112
USDC=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
USDT=0xdAC17F958D2ee523a2206206994597C13D831ec7
DAI=0x6B175474E89094C44Da98b954EedeAC495271d0F
WETH=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
WBTC=0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599
CRV=0xD533a949740bb3306d119CC777fa900bA034cd52
ADMIN=0x81925a13D326420baEFD9f0b51bDd6309f778637
ATT=0x000000000000000000000000000000000000dEaD
RID_EQ=0x000000000000000000000000000000681f812b3d181df0437de3f3e9ba249400

# ---------- 1. Substrate endpoint liveness (Equilibrium / Genshiro) ----------
{
  echo "# Substrate endpoint probes ($(date -u +%FT%TZ))"
  echo "# method: HTTP POST system_chain; ws endpoints are probed with curl --http1.1 upgrade"
  for u in \
      "https://node.equilibrium.io" \
      "https://rpc.equilibrium.io" \
      "https://equilibrium-rpc.dwellir.com" \
      "https://equilibrium.api.onfinality.io/public" \
      "https://equilibrium.public.curie.radiumblock.co/http" \
      "https://node.ksm.genshiro.io" \
      "https://genshiro-rpc.dwellir.com" ; do
    code=$(curl -s -m 12 -o /tmp/probe.body -w '%{http_code}' -H 'Content-Type: application/json' \
             --data '{"jsonrpc":"2.0","id":1,"method":"system_chain","params":[]}' "$u" 2>/dev/null || echo "000")
    body=$(head -c 160 /tmp/probe.body 2>/dev/null | tr -d '\n')
    echo "$u => http=$code body=${body:-<empty>}"
  done
  echo
  echo "# ws probe (node.equilibrium.io:9944 tcp)"
  timeout 10 bash -c 'exec 3<>/dev/tcp/node.equilibrium.io/9944 && echo "tcp 9944 open"' 2>/dev/null || echo "tcp 9944 closed/unreachable"
} > "$OUT/substrate-endpoints.txt" 2>&1 || true

# ---------- 2. Ethereum bridge live state ----------
block=$("$CAST" block-number --rpc-url "$RPC" 2>/dev/null || echo 0)
{
  echo "block=$block"
  echo "rpc_host=$(echo "$RPC" | sed 's#https://##;s#/.*##')"
  echo
  echo "## v2 bridge $V2_BRIDGE"
  echo "relayerThreshold=$("$CAST" call --rpc-url "$RPC" "$V2_BRIDGE" '_relayerThreshold()(uint8)' 2>&1)"
  echo "totalRelayers=$("$CAST" call --rpc-url "$RPC" "$V2_BRIDGE" '_totalRelayers()(uint256)' 2>&1)"
  echo "paused=$("$CAST" call --rpc-url "$RPC" "$V2_BRIDGE" 'paused()(bool)' 2>&1)"
  echo "chainID=$("$CAST" call --rpc-url "$RPC" "$V2_BRIDGE" '_chainID()(uint8)' 2>&1)"
  echo "version=$("$CAST" call --rpc-url "$RPC" "$V2_BRIDGE" '_version()(string)' 2>&1)"
  echo "ethBalance=$("$CAST" balance --rpc-url "$RPC" "$V2_BRIDGE" 2>&1)"
  echo "depositsEnabled_chain0=$("$CAST" call --rpc-url "$RPC" "$V2_BRIDGE" '0x6e01d9fd0000000000000000000000000000000000000000000000000000000000000000' 2>&1 | head -c 80)"
  echo "depositsEnabled_chain1=$("$CAST" call --rpc-url "$RPC" "$V2_BRIDGE" '0x6e01d9fd0000000000000000000000000000000000000000000000000000000000000001' 2>&1 | head -c 80)"
  echo "depositsEnabled_chain7=$("$CAST" call --rpc-url "$RPC" "$V2_BRIDGE" '0x6e01d9fd0000000000000000000000000000000000000000000000000000000000000007' 2>&1 | head -c 80)"
  echo
  echo "## v2 handler $V2_HANDLER balances"
  for tp in "EQ:$EQ" "EQD:$EQD2" "USDC:$USDC" "USDT:$USDT" "DAI:$DAI" "WETH:$WETH" "WBTC:$WBTC" "CRV:$CRV"; do
    t=${tp%%:*}; a=${tp#*:}
    echo "$t=$("$CAST" call --rpc-url "$RPC" "$a" 'balanceOf(address)(uint256)' "$V2_HANDLER" 2>&1)"
  done
  echo "ethBalance=$("$CAST" balance --rpc-url "$RPC" "$V2_HANDLER" 2>&1)"
  echo
  echo "## v2 resource list (0x5096c417) -> handler/token (9 registered)"
  echo "resourceList=$("$CAST" call --rpc-url "$RPC" "$V2_BRIDGE" '0x5096c417' 2>&1 | head -c 120)"
  for rid in \
      0x0000000000000000000000000000007a05c51f15d366ac77bc86672166836100 \
      0x000000000000000000000000000000074f3176c2cfbbc7bba48d64535e071500 \
      0x0000000000000000000000000000002167b82cfd0cb1a577e338e65331e87f00 \
      0x000000000000000000000000000000e7af8cdba234ffeeddccbbaa3458798700 \
      0x000000000000000000000000000000e54dd1f11e2fd2474af64f487e911b5900 \
      0x000000000000000000000000000000b23802d01aeb6d2af5f66bc49383d20d00 \
      0x00000000000000000000000000000062ced3722c69d04d18c5ce5fa6ef9a8a00 \
      0x000000000000000000000000000000f0ec6d6364bce9df4a3037c6d78bfe7900 \
      0x000000000000000000000000000000681f812b3d181df0437de3f3e9ba249400 ; do
    echo "rid=$rid token=$("$CAST" call --rpc-url "$RPC" "$V2_HANDLER" '_resourceIDToTokenContractAddress(bytes32)' "$rid" 2>&1)"
  done
  echo
  echo "## v1 bridge $V1_BRIDGE"
  echo "paused=$("$CAST" call --rpc-url "$RPC" "$V1_BRIDGE" 'paused()(bool)' 2>&1)"
  echo "relayerThreshold=$("$CAST" call --rpc-url "$RPC" "$V1_BRIDGE" '_relayerThreshold()(uint8)' 2>&1)"
  echo "ethBalance=$("$CAST" balance --rpc-url "$RPC" "$V1_BRIDGE" 2>&1)"
  echo "v1handler_USDC=$("$CAST" call --rpc-url "$RPC" "$USDC" 'balanceOf(address)(uint256)' "$V1_HANDLER" 2>&1)"
  echo
  echo "## role checks"
  echo "bridge_admin=$("$CAST" call --rpc-url "$RPC" "$V2_BRIDGE" 'getRoleMember(bytes32,uint256)(address)' 0x0000000000000000000000000000000000000000000000000000000000000000 0 2>&1)"
  echo "eq_minter_count=$("$CAST" call --rpc-url "$RPC" "$EQ" 'getRoleMemberCount(bytes32)(uint256)' 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6 2>&1)"
  echo "eq_minter0=$("$CAST" call --rpc-url "$RPC" "$EQ" 'getRoleMember(bytes32,uint256)(address)' 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6 0 2>&1)"
  echo
  echo "## unprivileged path simulations (eth_call from 0x...dEaD)"
  echo "attacker_adminWithdraw=$("$CAST" call --rpc-url "$RPC" --from "$ATT" "$V2_BRIDGE" 'adminWithdraw(address,address,address,uint256)' "$V2_HANDLER" "$USDC" "$ATT" 1 2>&1 | head -c 200)"
  echo "attacker_executeProposal=$("$CAST" call --rpc-url "$RPC" --from "$ATT" "$V2_BRIDGE" 'executeProposal(uint8,uint64,bytes,bytes32)' 1 1 0x "$RID_EQ" 2>&1 | head -c 200)"
  echo "attacker_voteProposal=$("$CAST" call --rpc-url "$RPC" --from "$ATT" "$V2_BRIDGE" 'voteProposal(uint8,uint64,bytes32,bytes32)' 1 1 "$RID_EQ" 0x0000000000000000000000000000000000000000000000000000000000000000 2>&1 | head -c 200)"
  echo "attacker_handlerWithdraw=$("$CAST" call --rpc-url "$RPC" --from "$ATT" "$V2_HANDLER" 'withdraw(address,address,uint256)' "$USDC" "$ATT" 1 2>&1 | head -c 200)"
  echo "attacker_eq_mint=$("$CAST" call --rpc-url "$RPC" --from "$ATT" "$EQ" 'mint(address,uint256)' "$ATT" 1000000000000000000 2>&1 | head -c 200)"
  echo "admin_adminWithdraw_amount0=$("$CAST" call --rpc-url "$RPC" --from "$ADMIN" "$V2_BRIDGE" 'adminWithdraw(address,address,address,uint256)' "$V2_HANDLER" "$USDC" "$ADMIN" 0 2>&1 | head -c 80)"
  echo "admin_adminWithdraw_amount1=$("$CAST" call --rpc-url "$RPC" --from "$ADMIN" "$V2_BRIDGE" 'adminWithdraw(address,address,address,uint256)' "$V2_HANDLER" "$USDC" "$ADMIN" 1 2>&1 | head -c 200)"
} > "$OUT/evm-state-dump.txt" 2>&1 || true

# machine-readable JSON
python3 - "$OUT/evm-state-dump.txt" "$OUT/evm-state-dump.json" <<'PY' || true
import json, sys
src, dst = sys.argv[1], sys.argv[2]
data = {}
for line in open(src):
    line = line.strip()
    if "=" in line and not line.startswith("#"):
        k, v = line.split("=", 1)
        data[k] = v
json.dump(data, open(dst, "w"), indent=1)
print("wrote", dst)
PY

echo "[ci] equilibrium-lending state dump done; block=$block"
exit 0
