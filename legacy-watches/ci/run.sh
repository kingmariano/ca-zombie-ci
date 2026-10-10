#!/usr/bin/env bash
# legacy-watches CI runner (H2-09).
# Runs every step in ci/steps/ (alphabetical): *.sh and *.py.
# All scripts must be read-only against public RPCs (no keys hardcoded; env allowed).
# Outputs go to ci-out/. Never print secrets.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
mkdir -p ci-out
echo "== legacy-watches CI $(date -u +%FT%TZ) =="
echo "env probe (presence only):"
for v in RPC_URL BSC_RPC_URL ALCHEMY_API_KEY GOLD_RUSH_API_KEY ETHERSCANV2_API_KEY; do
  if [ -n "${!v:-}" ]; then echo "  $v=set"; else echo "  $v=unset"; fi
done

fail=0
for step in ci/steps/*.sh ci/steps/*.py; do
  [ -e "$step" ] || continue
  name=$(basename "$step")
  echo "== STEP $name =="
  case "$step" in
    *.sh) timeout 3000 bash "$step" 2>&1 | tee "ci-out/${name%.sh}.log" ;;
    *.py) timeout 3000 python3 "$step" 2>&1 | tee "ci-out/${name%.py}.log" ;;
  esac
  rc=${PIPESTATUS[0]}
  echo "== STEP $name exit=$rc =="
  [ "$rc" -ne 0 ] && fail=1
done
echo "== all steps done (fail=$fail) =="
exit 0
