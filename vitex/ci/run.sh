#!/usr/bin/env bash
# H-05 ViteX — independent endpoint/liveness scan from the GitHub Actions runner.
# Read-only network checks only. Results -> ci-out/.
set -uo pipefail
cd "$(dirname "$0")/.."   # vitex/
mkdir -p ci-out
TS="$(date -u +%FT%TZ)"
OUT="ci-out/endpoint-scan.txt"
JSON="ci-out/endpoint-scan.json"

echo '{"scan_utc":"'"$TS"'","hosts":[],"rpc":[]}' > "$JSON"

log() { echo "$@" | tee -a "$OUT"; }

: > "$OUT"
log "# H-05 ViteX endpoint scan"
log "utc: $TS"
log "runner: $(uname -srm) / $(nproc) vCPU"
log ""

doh() { # $1 = host
  curl -sS -m 15 "https://dns.google/resolve?name=$1&type=A" 2>/dev/null
}

probe_http() { # $1 = url
  curl -sS -m 15 -A 'Mozilla/5.0' -o /dev/null -w '%{http_code}' "$1" 2>/dev/null || echo "ERR"
}

log "## 1. DNS status (Google DoH) + TCP/HTTP probe"
HOSTS="node.vite.net vitex.vite.net config.vite.net api.vite.net gateway.vite.net crosschain.vite.net biforst.vite.net buidl.vite.net explorer.vite.net wallet.vite.net vitescan.io mainnet.viteview.xyz viteview.xyz vitex.net api.vitex.net forum.vite.net wiki.vite.net bootnodes.vite.net stats.vite.net reward.vite.net static.vite.net x.vite.net api.vitewallet.com vitex.network"
for h in $HOSTS; do
  R=$(doh "$h")
  STATUS=$(printf '%s' "$R" | python3 -c "
import sys,json
try:
  d=json.load(sys.stdin); ans=d.get('Answer',[])
  a=[x['data'] for x in ans if x['type']==1]; c=[x['data'] for x in ans if x['type']==5]
  print('A='+','.join(a) if a else ('CNAME='+','.join(c) if c else 'Status='+str(d.get('Status'))))
except Exception as e: print('ERR')")
  H=$(probe_http "https://$h/")
  log "$(printf '%-24s %-70s http=%s' "$h" "$STATUS" "$H")"
  printf '%s' "$R" > "ci-out/doh-$h.json" 2>/dev/null || true
done
log ""

log "## 2. Vite JSON-RPC POST to candidate endpoints"
RPC_BODY='{"jsonrpc":"2.0","id":1,"method":"ledger_getSnapshotChainHeight","params":[]}'
for u in "https://node.vite.net/gvite" "https://vitex.vite.net" "https://mainnet.viteview.xyz/gvite" "https://viteview.xyz/gvite" "https://buidl.vite.net/gvite"; do
  RESP=$(curl -sS -m 15 -X POST -H 'Content-Type: application/json' -A 'Mozilla/5.0' -d "$RPC_BODY" "$u" 2>&1 | head -c 300)
  log "POST $u -> $RESP"
  printf '{"url":"%s","response":"%s"}\n' "$u" "$(printf '%s' "$RESP" | tr '\n' ' ' | sed 's/"/\\"/g')" >> "$JSON.rpc.tmp"
done
log ""

log "## 3. Global reachability via check-host.net (independent vantage points)"
for target in "https://vitescan.io/" "https://node.vite.net/"; do
  REQ=$(curl -sS -m 30 -H 'Accept: application/json' "https://check-host.net/check-http?host=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" "$target")&max_nodes=6" 2>/dev/null)
  RID=$(printf '%s' "$REQ" | python3 -c "import sys,json;print(json.load(sys.stdin).get('request_id',''))" 2>/dev/null)
  log "check-host $target request_id=$RID"
  sleep 15
  RES=$(curl -sS -m 30 -H 'Accept: application/json' "https://check-host.net/check-result/$RID" 2>/dev/null)
  printf '%s' "$RES" | python3 -c "
import sys,json
try:
  d=json.load(sys.stdin)
  for node,res in d.items():
    r=res[0] if res else None
    print('  %-28s %s' % (node, (str(r[2]) if r else 'no result')))
except Exception as e: print('  parse error',e)" | tee -a "$OUT"
  printf '%s' "$RES" > "ci-out/checkhost-$(echo "$target" | tr -c 'a-zA-Z0-9' '_').json"
done
log ""

log "## 4. Official web wallet bundle endpoint config (live site)"
curl -sS -m 60 -A 'Mozilla/5.0' 'https://vite.net/assets/index-CavhrjZ6.js' -o ci-out/vitenet-app.js 2>/dev/null || true
if [ -s ci-out/vitenet-app.js ]; then
  log "endpoints referenced in live vite.net bundle:"
  grep -oE '(wss?|https)://[a-zA-Z0-9._/-]+' ci-out/vitenet-app.js | sort -u | grep -iE 'vite.net|vitex' | head -30 | tee -a "$OUT"
else
  log "could not fetch vite.net bundle"
fi

log ""
log "scan complete: $TS"
cat "$JSON.rpc.tmp" >> "$JSON" 2>/dev/null || true
rm -f "$JSON.rpc.tmp"
# make JSON valid-ish
python3 - <<'EOF'
import json
p='ci-out/endpoint-scan.json'
try:
    d=json.load(open(p))
except Exception:
    d={"scan_utc":"","hosts":[],"rpc":[]}
lines=[l for l in open(p) if l.strip()]
if len(lines)>1:
    try:
        d=json.loads(lines[0])
        d['rpc']=[json.loads(l) for l in lines[1:]]
    except Exception:
        pass
json.dump(d,open(p,'w'),indent=1)
EOF
echo "=== ci-out contents ==="
ls -la ci-out/
