#!/usr/bin/env bash
# Heliobond deep-dive CI job — READ-ONLY (no transactions, no keys).
#
# 1. Builds Heliobond's investment_vault at the vulnerable commit (parent of
#    the fix) and at current main with the repo's pinned toolchain (Rust
#    1.84.0, stellar-cli 26.1.0) and records the WASM sha256 hashes.
# 2. Runs a deterministic PoC on the vulnerable commit showing the queued
#    withdrawal double-count and the attacker extraction; runs the same
#    scenario on the fixed commit as a control.
# 3. Checks whether either WASM exists as a ContractCode entry on Stellar
#    mainnet/testnet (Soroban RPC getLedgerEntries) — i.e. whether this code
#    was ever deployed to a live network.
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"
mkdir -p ci-out
exec > >(tee -a ci-out/run.log) 2>&1

VULN_SHA="c79daec1feb1de2863de16ac9857977653ab74a1"
FIXED_SHA="b233e106fc4c7b2f8aa84bd9634ef5138359c321"
REPO="https://github.com/Heliobond/contracts.git"
WORK=/tmp/heliobond-contracts

echo "=== Heliobond CI $(date -u +%FT%TZ) ==="
uname -a; nproc; df -h / | tail -1

# ── toolchain ────────────────────────────────────────────────────────────────
# The workspace's rust-toolchain.toml pins 1.84.0, but a dependency in the
# current lockfile requires Cargo's edition2024 support (unstabilized in 1.84).
# The repo's own workflows use dtolnay/rust-toolchain@stable, so build with
# stable and override the pinned toolchain.
if ! command -v cargo >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
  # shellcheck disable=SC1091
  . "$HOME/.cargo/env"
fi
rustup toolchain install stable --profile minimal --target wasm32v1-none >/dev/null 2>&1 || true
rustup target add wasm32v1-none --toolchain stable >/dev/null 2>&1 || true
export RUSTUP_TOOLCHAIN=stable
rustc --version
cargo --version

if ! command -v stellar >/dev/null 2>&1; then
  curl -sSL https://github.com/stellar/stellar-cli/releases/download/v26.1.0/stellar-cli-26.1.0-x86_64-unknown-linux-gnu.tar.gz | tar -xz
  sudo mv stellar /usr/local/bin/stellar 2>/dev/null || {
    mkdir -p "$HOME/.local/bin"; mv stellar "$HOME/.local/bin/"; export PATH="$HOME/.local/bin:$PATH"
  }
fi
stellar --version || { echo "FATAL: stellar CLI unavailable"; exit 1; }

# ── clone ────────────────────────────────────────────────────────────────────
rm -rf "$WORK"
git clone --quiet "$REPO" "$WORK" || { echo "FATAL: clone failed"; exit 1; }
cd "$WORK"

run_poc() {
  local name="$1" ref="$2" testfile="$3" testname="$4"
  echo ""
  echo "=== [$name] checkout $ref ==="
  git reset --hard -q || true
  git checkout -q -f "$ref" || return 1
  git log -1 --format='%H %ad %s' --date=iso
  if [ "$name" = "vuln" ]; then
    # Compile-only fixes for the pre-fix commit (both landed 2h after it):
    #  - d2fabc8: storage.rs test module was garbled (`#c[cfg)test]`, missing paren)
    #  - 8e87d69: duplicate RegistryError discriminants 41/42 (E0081)
    # Neither touches vault logic; the vault crate does not include the
    # project_registry code, so investment_vault.wasm is unaffected.
    git show d2fabc8 -- investment_vault/src/storage.rs | git apply --whitespace=nowarn
    git show 8e87d69 -- project_registry/src/types.rs | git apply --whitespace=nowarn
    echo "[$name] applied compile-only fixes d2fabc8 + 8e87d69"
  fi
  rm -rf target
  echo "=== [$name] stellar contract build ==="
  stellar contract build 2>&1 | tail -30
  if [ ! -f target/wasm32v1-none/release/investment_vault.wasm ]; then
    echo "[$name] FATAL: investment_vault.wasm was not produced"
    return 1
  fi
  ls -la target/wasm32v1-none/release/*.wasm
  sha256sum target/wasm32v1-none/release/investment_vault.wasm \
            target/wasm32v1-none/release/project_registry.wasm \
    | tee "$HERE/ci-out/${name}_hashes.txt"
  cp target/wasm32v1-none/release/investment_vault.wasm  "$HERE/ci-out/${name}_investment_vault.wasm"
  cp target/wasm32v1-none/release/project_registry.wasm  "$HERE/ci-out/${name}_project_registry.wasm"

  echo "=== [$name] PoC: $testname ==="
  mkdir -p investment_vault/tests
  cp "$testfile" "investment_vault/tests/${testname}.rs"
  cargo test -p investment-vault --test "$testname" -- --nocapture 2>&1 | tee "$HERE/ci-out/${name}_test.log"
  local rc=${PIPESTATUS[0]}
  echo "[$name] cargo test exit=$rc"
  return $rc
}

FAIL=0
run_poc vuln  "$VULN_SHA"  "$HERE/poc/poc_vulnerable_it.rs" poc_vulnerable || FAIL=1
run_poc fixed "$FIXED_SHA" "$HERE/poc/poc_fixed_it.rs"      poc_fixed      || FAIL=1

# ── on-chain ContractCode presence checks ────────────────────────────────────
echo ""
echo "=== on-chain WASM hash checks (mainnet + testnet) ==="
ARGS=()
[ -f "$HERE/ci-out/vuln_investment_vault.wasm" ]  && ARGS+=("vuln=$HERE/ci-out/vuln_investment_vault.wasm")
[ -f "$HERE/ci-out/fixed_investment_vault.wasm" ] && ARGS+=("fixed=$HERE/ci-out/fixed_investment_vault.wasm")
if [ ${#ARGS[@]} -gt 0 ]; then
  python3 "$HERE/ci/check_wasm_on_chain.py" "${ARGS[@]}" | tee "$HERE/ci-out/wasm_hash_check.txt"
  python3 "$HERE/ci/check_wasm_on_chain.py" --json "${ARGS[@]}" > "$HERE/ci-out/wasm_hash_check.json"
else
  echo "no built WASMs to check"
fi

echo ""
echo "=== DONE (fail=$FAIL) ==="
exit $FAIL
