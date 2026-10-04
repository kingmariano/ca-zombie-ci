#!/usr/bin/env bash
# Brute-force actionId -> function mapping for Velocore authenticate() roles.
set -u
cd /home/heisenberg/CA/rho-velocore/analysis/velocore/ref
# collect signatures from ABI jsons
jq -r '.abi[]? | select(.type=="function") | .name + "(" + ([.inputs[]?.type] | join(",")) + ")"' CPP.json 2>/dev/null > /tmp/opencode/sigs.txt
jq -r '.abi[]? | select(.type=="function") | .name + "(" + ([.inputs[]?.type] | join(",")) + ")"' Vault.json 2>/dev/null >> /tmp/opencode/sigs.txt
# add known factory/other sigs
cat >> /tmp/opencode/sigs.txt <<'EOF'
setParam(uint256,uint256)
setFee(uint32)
setDecay(uint32)
setFeeToZero()
notifyWithdraw(uint128)
notifyMint(uint128)
notifyBurn(uint128)
deploy(address,address)
createPool(address,address)
EOF
sort -u /tmp/opencode/sigs.txt > /tmp/opencode/sigs-uniq.txt
wc -l /tmp/opencode/sigs-uniq.txt
# candidate 'where' addresses per chain
declare -A WHERES
WHERES[linea]="0x1d0188c4B276A09366D05d6Be06aF61a73bC7535 0xbe6c6a389b82306e88d74d1692b67285a9db9a47 0xaa18cdb16a4dd88a59f4c2f45b5c91d009549e06"
while read -r sig; do
  sel=$(cast sig "$sig" 2>/dev/null) || continue
  [ -z "$sel" ] && continue
  for w in ${WHERES[linea]}; do
    w32=0x$(printf '%064s' ${w:2} | tr ' ' '0')
    a=$(cast keccak $(cast concat-hex $w32 $sel) 2>/dev/null)
    echo "$a $sig $w"
  done
done < /tmp/opencode/sigs-uniq.txt > /tmp/opencode/actionids-linea.txt
echo "computed $(wc -l < /tmp/opencode/actionids-linea.txt) action ids"
echo "== match 0x797528e36e9ef696711f0c1e106e333fa4cf9e71819b8c2c88996334c2001171 =="
grep -i "797528e36e9ef696711f0c1e106e333fa4cf9e71819b8c2c88996334c2001171" /tmp/opencode/actionids-linea.txt || echo "NO MATCH"
echo "== match other granted roles =="
for r in 610b3247becfa7e9b00ec103786b931410bc6e0348277f70cb58228777e52635 5284f336a2d5437b18e080440af76441c2a4a804d26ef65bb17cfd851c677272 4221ced23fb5ab29ce648782f4a52959d3fb9b3b349307c6205cfab206d0b00b; do
  echo "--- $r"; grep -i "$r" /tmp/opencode/actionids-linea.txt || echo "no match"
done