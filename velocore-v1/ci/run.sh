#!/usr/bin/env bash
# Velocore V1 (zkSync Era) — fork-based live-extraction tests.
# READ-ONLY on mainnet: everything runs against a local anvil-zksync fork.
# No secrets: the fork upstream is the keyless public zkSync RPC.
#
#   T1 (fresh fork)  Voter.distribute on the existing USDC/WETH gauge
#   T2 (fresh fork)  Full attacker path: new pool -> gauge -> lock VC -> vote -> distribute
#   T3 (fresh fork)  skim() excess on the biggest pool
# Outputs ci-out/fork-results.json + ci-out/fork-run.log
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$HERE/ci-out"
mkdir -p "$OUT"
LOG="$OUT/fork-run.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

WORK=/tmp/velocore-v1-ci
mkdir -p "$WORK"
RPC_PUBLIC="${ZKSYNC_RPC:-https://mainnet.era.zksync.io}"
PORT=8011
ANVIL_BIN="$WORK/anvil-zksync"
RESULTS="$OUT/fork-results.json"

note() { echo "[ci] $*"; }
rpc() { curl -s -m 10 -X POST "http://127.0.0.1:$PORT" -H 'Content-Type: application/json' --data "$1"; }

start_fork() {
  if rpc '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' | grep -q result; then return 0; fi
  if [ ! -x "$ANVIL_BIN" ]; then
    note "downloading anvil-zksync v0.7.1"
    curl -sL -m 300 -o "$WORK/az.tar.gz" \
      "https://github.com/matter-labs/anvil-zksync/releases/download/v0.7.1/anvil-zksync-v0.7.1-x86_64-unknown-linux-gnu.tar.gz"
    tar xzf "$WORK/az.tar.gz" -C "$WORK"; chmod +x "$ANVIL_BIN"
  fi
  note "starting fork of $RPC_PUBLIC"
  (setsid nohup "$ANVIL_BIN" fork --fork-url "$RPC_PUBLIC" > "$WORK/anvil.log" 2>&1 < /dev/null &)
  for i in $(seq 1 40); do
    sleep 2
    rpc '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' | grep -q result && { note "fork up"; return 0; }
  done
  note "FATAL: fork did not start"; tail -5 "$WORK/anvil.log" | sed 's/dkey=[^&"]*/dkey=<REDACTED>/g'; return 1
}
restart_fork() { pkill -x anvil-zksync >/dev/null 2>&1; sleep 3; start_fork; }

echo '{"rpc": "keyless public zkSync Era RPC", "tests": {}}' > "$RESULTS"

for T in T1 T2 T3; do
  restart_fork || exit 1
  note "running $T"
  python3 "$HERE/ci/fork_test.py" "$T" "$RESULTS"
done

note "results -> $RESULTS"
cat "$RESULTS"
