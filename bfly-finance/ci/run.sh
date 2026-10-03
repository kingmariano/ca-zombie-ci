#!/usr/bin/env bash
# Heavy CI job for bfly-finance (H-15 / Starcoin).
#
# Builds the Starcoin-fork Move disassembler at the exact rev used by starcoin v1.13.22
# and disassembles every module deployed at the BFly account
# (analysis/modules/*.mv were fetched from Starcoin mainnet via state.list_code).
#
# Output: ci-out/disasm/<Module>.txt (full disassembly), ci-out/logs/*.
set -euo pipefail
cd "$(dirname "$0")/.."   # -> bfly-finance/
mkdir -p ci-out/disasm ci-out/logs
ROOT="$(pwd)"

MOVE_REV="7b6ac7bb04515ee4ced5b1c1cdafb6ea6cb4eadc"
WORK="${RUNNER_TEMP:-/tmp}/stc-move"
if [ ! -d "$WORK/.git" ]; then
  rm -rf "$WORK"
  git init -q "$WORK"
  cd "$WORK"
  git remote add origin https://github.com/starcoinorg/move.git
  git fetch --depth 1 -q origin "$MOVE_REV"
  git checkout -q FETCH_HEAD
else
  cd "$WORK"
fi
echo "[ci] move repo at $(git rev-parse HEAD)"

# The move repo pins rustc 1.65.0 and passes -fuse-ld=lld; ensure lld is present.
sudo apt-get update -qq >/dev/null 2>&1 || true
sudo apt-get install -y -qq lld >/dev/null 2>&1 || true

# Build only the disassembler binary.
set +e
cargo build --release -p move-disassembler >"$ROOT/ci-out/logs/cargo-build.log" 2>&1
BUILD_RC=$?
set -e
tail -n 20 "$ROOT/ci-out/logs/cargo-build.log" || true
if [ $BUILD_RC -ne 0 ]; then
  echo "[ci] cargo build failed (rc=$BUILD_RC); see cargo-build.log"
  exit 1
fi

BIN="$WORK/target/release/move-disassembler"
ls -la "$BIN"
"$BIN" --help > "$ROOT/ci-out/disasm/_help.txt" 2>&1 || true

cd "$ROOT"
: > ci-out/disasm/_failures.txt
for f in analysis/modules/*.mv; do
  name="$(basename "$f" .mv)"
  if "$BIN" --bytecode "$f" > "ci-out/disasm/$name.txt" 2> "ci-out/logs/$name.err"; then
    echo "[ci] ok $name ($(wc -l < "ci-out/disasm/$name.txt") lines)"
  else
    echo "[ci] FAILED $name"
    echo "$name" >> ci-out/disasm/_failures.txt
  fi
done
echo "[ci] done: $(ls ci-out/disasm/*.txt | wc -l) files"

# Disassemble the Starswap DEX modules too (flash-swap semantics evidence).
mkdir -p ci-out/disasm-dex
for f in analysis/dex_modules/*.mv; do
  name="$(basename "$f" .mv)"
  "$BIN" --bytecode "$f" > "ci-out/disasm-dex/$name.txt" 2>/dev/null || echo "[ci] dex disasm failed: $name"
done
echo "[ci] dex modules disassembled: $(ls ci-out/disasm-dex/*.txt 2>/dev/null | wc -l)"

# Disassemble the other Starcoin DeFi protocols found by the whole-chain scan
# (WEN LendingPoolV2, second BFly deployment, AWW, bridge, Kiko).
mkdir -p ci-out/disasm-extra
for d in analysis/extra_modules/*/; do
  label="$(basename "$d")"
  mkdir -p "ci-out/disasm-extra/$label"
  for f in "$d"*.mv; do
    [ -e "$f" ] || continue
    name="$(basename "$f" .mv)"
    "$BIN" --bytecode "$f" > "ci-out/disasm-extra/$label/$name.txt" 2>/dev/null || echo "[ci] extra disasm failed: $label/$name"
  done
done
echo "[ci] extra modules disassembled: $(find ci-out/disasm-extra -name '*.txt' | wc -l)"

# ---------------------------------------------------------------------------
# Whole-chain flash-liquidity scan (read-only): fetch every module of the
# Starcoin DeFi surface (framework, Starswap, BFly, bridge, token issuers),
# scan for flash/hot-potato/callback/lending identifiers + call graphs.
# ---------------------------------------------------------------------------
echo "[ci] running whole-chain flash-liquidity scan..."
python3 poc/flash_scan.py > ci-out/flash-scan.log 2>&1 || echo "flash scan rc=$?"
tail -n 30 ci-out/flash-scan.log || true

# ---------------------------------------------------------------------------
# Live verification PoC (read-only RPC): re-reads protocol state and reproduces
# the deployed liquidation math from the bytecode to compute attacker net P&L.
# ---------------------------------------------------------------------------
echo "[ci] running live verification (read-only RPC)..."
python3 poc/verify_bfly.py > ci-out/verification.log 2>&1 || echo "verify script rc=$?"
tail -n 40 ci-out/verification.log || true
