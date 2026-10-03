#!/usr/bin/env bash
# Enumerate Yearn v1 registry vaults and dump live state (read-only).
# Usage: bash enum_v1.sh <rpc-url> <block> <outfile.jsonl>
set -uo pipefail
RPC="${1:?rpc}"
BLOCK="${2:-latest}"
OUT="${3:-v1_vaults.jsonl}"
R=0x3eE41C098f9666ed2eA246f4D2558010e59d63A0
N=$(cast call $R 'getVaultsLength()(uint256)' --rpc-url "$RPC" --block "$BLOCK" | awk '{print $1}')
echo "{\"registry\":\"$R\",\"getVaultsLength\":$N}" > "$OUT"
for i in $(seq 0 $((N-1))); do
  V=$(cast call $R "getVault(uint256)(address)" $i --rpc-url "$RPC" --block "$BLOCK" 2>/dev/null | awk '{print $1}')
  [ -z "$V" ] && continue
  CALL() { cast call "$V" "$1" --rpc-url "$RPC" --block "$BLOCK" 2>/dev/null | awk '{print $1}'; }
  NAME=$(CALL 'name()(string)'); SYM=$(CALL 'symbol()(string)'); DEC=$(CALL 'decimals()(uint8)')
  TS=$(CALL 'totalSupply()(uint256)'); PPS=$(CALL 'getPricePerFullShare()(uint256)')
  TOK=$(CALL 'token()(address)'); WANT=$(CALL 'want()(address)'); BAL=$(CALL 'balance()(uint256)')
  CTRL=$(CALL 'controller()(address)'); STRAT=$(CALL 'strategy()(address)'); GOV=$(CALL 'governance()(address)')
  CPV=$(CALL 'calcPoolValueInToken()(uint256)'); TA=$(CALL 'totalAssets()(uint256)')
  python3 - "$i" "$V" "$NAME" "$SYM" "$DEC" "$TS" "$PPS" "$TOK" "$WANT" "$BAL" "$CTRL" "$STRAT" "$GOV" "$CPV" "$TA" >> "$OUT" <<'PY'
import json,sys
i,v,name,sym,dec,ts,pps,tok,want,bal,ctrl,strat,gov,cpv,ta = sys.argv[1:16]
def nz(x):
    x=(x or '').strip()
    return x if x and x!='' else None
print(json.dumps({"idx":int(i),"vault":v,"name":name,"sym":sym,"dec":dec,"totalSupply":ts,
 "pps":pps,"token":nz(tok),"want":nz(want),"balance":bal,"controller":nz(ctrl),
 "strategy":nz(strat),"governance":nz(gov),"calcPool":nz(cpv),"totalAssets":nz(ta)}))
PY
done
