#!/usr/bin/env bash
# C2-23 Enjin legacy — CI evidence job (runs before `forge test`).
# Writes evidence to ci-out/ (uploaded as a public artifact).
# NEVER prints keyed RPC URLs: only public addresses/selectors and state values.
set -uo pipefail

cd "$(dirname "$0")/.."
mkdir -p ci-out
OUT=ci-out/live_state.json
LOG=ci-out/ci_run.log
exec > >(tee "$LOG") 2>&1

URL="${FORK_RPC_URL:-${RPC_URL:-https://ethereum-rpc.publicnode.com}}"
PA=0xfaaFDc07907ff5120a76b34b731b278c38d6043c
ADAPTER=0x4e643a25a64952895f553f20252861258727174e
NFT=0x13fa4b9a6c2f2604c919f96f456e3b50e968b157
FT=0x268c039a3127d3107c014f0dc6c390a53e6db27f
ENJ=0xf629cbd94d3791c9250152bd8dfbdf380e2a3b9c
ATT=0x7083ddece38216c7741fa76c75326bea744ed321
SHELL_NFT=0x005ae6af58f5a14d6d993e91052e17c23af14a20
SHELL_FT=0x68e2098057c9341e1e7fb466bc05810ddc20bb35
RAND=0x1111111111111111111111111111111111111111

BLOCK=$(cast block-number --rpc-url "$URL")
echo "block=$BLOCK"

NFM=$(cast call "$NFT" "getManager()(address)" --rpc-url "$URL" | head -1)
FTM=$(cast call "$FT" "getManager()(address)" --rpc-url "$URL" | head -1)
RES=$(cast call "$ENJ" "balanceOf(address)(uint256)" "$ADAPTER" --rpc-url "$URL" | head -1)
DNS=$(cast call "$NFT" "delegates(bytes4)(address)" 0x6453dcf6 --rpc-url "$URL" | head -1)
DFS=$(cast call "$FT"  "delegates(bytes4)(address)" 0x23b872dd --rpc-url "$URL" | head -1)
DNI=$(cast call "$NFT" "delegates(bytes4)(address)" 0xfe4b84df --rpc-url "$URL" | head -1)
AOW=$(cast call "$ATT" "owner()(address)" --rpc-url "$URL" | head -1)

echo "nf_manager=$NFM"
echo "ft_manager=$FTM"
echo "reserve_enj_wei=$RES"
echo "delegate_nft_steal=$DNS"
echo "delegate_ft_steal=$DFS"
echo "delegate_nft_initialize=$DNI"
echo "attack_owner=$AOW"

DEPLOY_DATA=$(python3 - <<'PY'
base=0x7880000000000a2f000000000000000000000000000000000000000000000000
w=[base,0x60,0,3,int.from_bytes(b'PWN'.ljust(32,b'\x00'),'big')]
print('0x33d332ab'+''.join(f'{x:064x}' for x in w))
PY
)
MELT_DATA=$(python3 - <<'PY'
id=0x7880000000000a2f000000000000000000000000000000000000000000000001
w=[0x40,0x80,1,id,1,1]
print('0xf6089e12'+''.join(f'{x:064x}' for x in w))
PY
)

echo "== probe: deployAdapter route from random (expect revert 'Function does not exist.') =="
cast call "$PA" "$DEPLOY_DATA" --from "$RAND" --rpc-url "$URL" 2>&1 | head -1
echo "== probe: NFT gateway route from random (expect revert 'Function does not exist.') =="
cast call "$PA" "0x41c1df0e000000000000000000000000111111111111111111111111111111111111111100000000000000000000000050bf217523dc390b18f31bdb1099ebf937da1756000000000000000000000000111111111111111111111111111111111111111178800000000000a2f00000000000000000000000000000000000000000000001" --from "$RAND" --rpc-url "$URL" 2>&1 | head -1
echo "== probe: NFT shell stealNFT route from random (expect revert 'only pwn') =="
cast call "$SHELL_NFT" "0x6453dcf6000000000000000000000000111111111111111111111111111111111111111100000000000000000000000011111111111111111111111111111111111111117880000000000a2f000000000000000000000000000000000000000000000001" --from "$RAND" --rpc-url "$URL" 2>&1 | head -1
echo "== probe: FT shell transferFrom route from random (expect revert 'only pwn') =="
cast call "$SHELL_FT" "0x23b872dd000000000000000000000000111111111111111111111111111111111111111100000000000000000000000011111111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000001" --from "$RAND" --rpc-url "$URL" 2>&1 | head -1
echo "== probe: melt from random (non-owner; expect revert) =="
cast call "$PA" "$MELT_DATA" --from "$RAND" --rpc-url "$URL" 2>&1 | head -1

python3 - "$OUT" "$BLOCK" "$NFM" "$FTM" "$RES" "$DNS" "$DFS" "$DNI" "$AOW" <<'PY'
import json,sys
out,block,nfm,ftm,res,dns,dfs,dni,aow=sys.argv[1:10]
json.dump({
 "block": int(block),
 "nf_manager": nfm, "ft_manager": ftm,
 "reserve_enj_wei": res,
 "delegate_nft_steal": dns, "delegate_ft_steal": dfs, "delegate_nft_initialize": dni,
 "attack_contract_owner": aow,
 "note": "PA deployAdapter/gateway routes disabled by Enjin at block 25853511; templates' manager is the exploited attacker contract."
}, open(out,'w'), indent=2)
print(open(out).read())
PY
echo "== done =="
