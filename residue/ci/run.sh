#!/usr/bin/env bash
# residue/ci/run.sh — pick a working Polygon RPC for the H2-03 PoC tests.
#
# The job-level POLYGON_RPC_URL secret proved unable to serve STATE reads ("header for hash not
# found" even at the chain tip; eth_blockNumber alone answered). This script probes all available
# candidates (including keyed endpoints built from the injected API keys) for:
#   (a) eth_blockNumber                       -> "latest"
#   (b) eth_call balanceOf(victim) at latest  -> "state"
#   (c) eth_getBalance(victim, archiveBlock)  -> "archive" (optional; the CI suite reconstructs
#       the incident at the latest block, so archive is a bonus, not a requirement)
# and exports the first working one via $GITHUB_ENV (new variable name, to avoid precedence
# questions with the job-level POLYGON_RPC_URL).
#
# Secrets are never printed: only "candidate #N: latest=.. state=.. archive=.." lines are emitted.
set -uo pipefail

cd "$(dirname "$0")/.."   # -> residue/
mkdir -p ci-out
OUT=ci-out/rpc-selection.txt
: > "$OUT"

CANDIDATES=()
[ -n "${POLYGON_RPC_URL:-}" ] && CANDIDATES+=("$POLYGON_RPC_URL")
[ -n "${ANKR_API_KEY:-}" ] && CANDIDATES+=("https://rpc.ankr.com/polygon/${ANKR_API_KEY}")
[ -n "${INFURA_API_KEY:-}" ] && CANDIDATES+=("https://polygon-mainnet.infura.io/v3/${INFURA_API_KEY}")
[ -n "${DRPC_API_KEY:-}" ] && CANDIDATES+=("https://lb.drpc.org/ogrpc?network=polygon&dkey=${DRPC_API_KEY}")
[ -n "${ALCHEMY_API_KEY:-}" ] && CANDIDATES+=("https://polygon-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}")
CANDIDATES+=("https://polygon-bor-rpc.publicnode.com" "https://polygon-rpc.com")

VICTIM=0x24Cb173Ae221AeA93369f34bdcF0Ddb35b436773
USDT=0xc2132D05D31c914a87C6611C10748AEb04B58e8F
BLK=0x5994220   # 93,930,000 (historical pre-fix fork block; archive probe only)

post() { # $1=url $2=payload
  curl -s -m 20 -X POST -H 'Content-Type: application/json' --data "$2" "$1" 2>/dev/null
}

probe() { # $1=url -> "<latest> <state> <archive>"
  local u="$1" latest state archive r
  latest=$(post "$u" '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}')
  case "$latest" in *'"result"'*) latest=ok ;; *) latest=fail ;; esac

  # multiple state reads: a single successful call is not enough (the injected secret answered
  # some accounts and failed others with "header for hash not found")
  state=ok
  for call in \
    "{\"to\":\"$USDT\",\"data\":\"0x70a08231000000000000000000000000${VICTIM:2}\"}" \
    "{\"to\":\"$USDT\",\"data\":\"0xdd62ed3e000000000000000000000000${VICTIM:2}000000000000000000000000f615bd7ea00c4cc7f39faad0895db5f40891359f\"}" \
    "{\"to\":\"0xF615bD7EA00C4Cc7F39Faad0895dB5f40891359f\",\"data\":\"0x74e861d6\"}" \
    "{\"to\":\"0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359\",\"data\":\"0x70a082310000000000000000000000000cfd862be942846cebad797d7c1bc6e47714959b\"}"; do
    r=$(post "$u" "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_call\",\"params\":[$call,\"latest\"]}")
    case "$r" in *'"result":"0x'*) : ;; *) state=fail; break ;; esac
  done

  archive=$(post "$u" "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getBalance\",\"params\":[\"$VICTIM\",\"$BLK\"]}")
  case "$archive" in *'"result"'*) archive=ok ;; *) archive=fail ;; esac

  echo "$latest $state $archive"
}

PICK=""
FALLBACK=""
FBIDX=0
PREF=""
PREFIDX=0
i=0
for u in "${CANDIDATES[@]}"; do
  i=$((i + 1))
  read -r l s a < <(probe "$u")
  echo "candidate #$i: latest=$l state=$s archive=$a" | tee -a "$OUT"
  if [ "$l" = ok ] && [ "$s" = ok ] && [ "$a" = ok ]; then PICK="$u"; break; fi
  if [ "$l" = ok ] && [ "$s" = ok ]; then
    # Fallback candidates: prefer the keyless public endpoint — the injected secret proved flaky
    # for state reads ("header for hash not found" on a subset of accounts).
    case "$u" in
      https://polygon-bor-rpc.publicnode.com*)
        FALLBACK="$u"; FBIDX="$i" ;;
      *)
        if [ -z "$PREF" ]; then PREF="$u"; PREFIDX="$i"; fi ;;
    esac
  fi
done

# Tip + state is sufficient (the CI suite reconstructs the incident at the latest block).
if [ -z "$PICK" ]; then
  if [ -n "$FALLBACK" ]; then
    PICK="$FALLBACK"; i="$FBIDX"
  elif [ -n "$PREF" ]; then
    PICK="$PREF"; i="$PREFIDX"
  fi
  [ -n "$PICK" ] && echo "no archive RPC; using tip+state candidate #$i (url redacted)" | tee -a "$OUT"
fi

if [ -z "$PICK" ]; then
  echo "ERROR: no usable Polygon RPC found" | tee -a "$OUT"
  exit 1
fi

echo "selected candidate #$i (url redacted)" | tee -a "$OUT"

# Pin a shallow recent block: load-balanced public RPCs occasionally miss the very newest block
# hash ("header for hash not found"), while state older than ~128 blocks needs an archive token.
# Try tip-48, then 32/16/8; only export if the pinned block is actually servable.
LATEST_HEX=$(post "$PICK" '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' | sed -E 's/.*"result":"0x([0-9a-fA-F]+)".*/\1/')
PIN=""
if [ -n "$LATEST_HEX" ]; then
  LATEST=$((16#$LATEST_HEX))
  for d in 48 32 16 8; do
    CAND=$((LATEST - d))
    HEXCAND=$(printf '0x%x' "$CAND")
    r=$(post "$PICK" "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_call\",\"params\":[{\"to\":\"$USDT\",\"data\":\"0x70a08231000000000000000000000000${VICTIM:2}\"},\"$HEXCAND\"]}")
    case "$r" in *'"result":"0x'*) PIN="$CAND"; break ;; esac
  done
fi

if [ -n "${GITHUB_ENV:-}" ]; then
  # New variable name to avoid any precedence issue with the job-level POLYGON_RPC_URL.
  echo "POLYGON_ARCHIVE_RPC=$PICK" >> "$GITHUB_ENV"
  if [ -n "$PIN" ]; then
    echo "POLYGON_FORK_BLOCK=$PIN" >> "$GITHUB_ENV"
  fi
fi
[ -n "$PIN" ] && echo "pinned fork block: $PIN" | tee -a "$OUT"
exit 0
