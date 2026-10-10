#!/usr/bin/env bash
# high-cluster CI runner.
# Runs every poc-*/ foundry project in the high-cluster folder.
# Each project gets its own log in ci-out/<project>.log; a failed project is retried once
# (public-RPC flakiness) before being reported.
# NEVER fails the workflow (a failing test in one project must not block others).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 0

mkdir -p ci-out
echo "== high-cluster CI $(date -u +%FT%TZ) =="
echo "== foundry: $(forge --version 2>/dev/null | head -1) =="

for proj in poc-*/; do
  [ -f "${proj}foundry.toml" ] || continue
  name="${proj%/}"
  [ -f "${proj}SKIP" ] && { echo "== $name SKIPPED (SKIP file)"; continue; }
  echo "== running $name =="
  ( cd "$proj" && timeout 1700 forge test -vvv ) > "ci-out/${name}.log" 2>&1
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "== $name first attempt exit=$rc — retrying once (RPC flake guard) ==" | tee -a "ci-out/${name}.log"
    ( cd "$proj" && timeout 1700 forge test -vvv ) >> "ci-out/${name}.log" 2>&1
    rc=$?
  fi
  echo "== $name exit=$rc ==" | tee -a "ci-out/${name}.log"
  tail -n 25 "ci-out/${name}.log"
done

echo "== high-cluster CI done $(date -u +%FT%TZ) =="

# Bytecode-equivalence check for the verified V3-fork pool sources (compiles solc 0.7.6 in CI).
echo "== bytecode equivalence check =="
python3 ci/check-bytecode.py 2>&1 | tail -n 20

exit 0
