#!/usr/bin/env bash
# =============================================================================
# H-07 ClayStack ETH — custom CI heavy job
# =============================================================================
# 1. Downloads heimdall-rs 0.9.3 (needs Ubuntu 24.04 / glibc 2.39; CI runner is
#    ubuntu-latest) and decompiles the unverified ClayStack contracts that hold
#    or control the live ETH.
# 2. Dumps live state with the python state_dump script.
# Read-only: only JSON-RPC reads against the fork RPC; no transactions signed.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
RPC="${FORK_RPC_URL:-${RPC_URL:-https://ethereum-rpc.publicnode.com}}"
mkdir -p ci-out/decomp ci-out/state

echo "[h-07] rpc=$RPC (redacted if it contains a key)"
echo "[h-07] block probe: $(curl -s -m 15 -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$RPC" | head -c 200)"

# ---- 1. heimdall 0.9.3 decompilations -------------------------------------
HEIMDALL=/tmp/heimdall-0.9.3
if [ ! -x "$HEIMDALL" ]; then
  curl -sL --max-time 120 -o "$HEIMDALL" \
    https://github.com/Jon-Becker/heimdall-rs/releases/download/0.9.3/heimdall-linux-amd64 || true
  chmod +x "$HEIMDALL" || true
fi
if "$HEIMDALL" --version 2>/dev/null; then
  declare -A TARGETS=(
    [impl_current_568AA6C2]=0x568AA6C21cCf558C47F2A01B60cc6D549cED2F59
    [impl_intermediate_78e1]=0x78e1c86474bd2f70d83bdc767ca303243bba18d0
    [impl_intermediate_4716]=0x471627b16214a31dd0fa6f5531abb0fdc14d3207
    [impl_2024_594e80]=0x594e80D1be1c7d0f574d3556eCacB8dF4b2f35B8
    [executor_proxy_4c06]=0x4c06a181edafe572c44ab2a818b625a927484519
    [xcseth_main_impl_8bfd]=0x8bfD6fE95C3c78c7101387068c09a72dF91dfF17
    [csmatic_main_impl_db15]=0xDB15A54Ea0Ecd4f86aFe653aAC16FbCB488D0948
    [rolemanager_impl_9cc5]=0x9cC565BCC55AA20E122BFe14cb316632A86970CB
    [impl_52d4]=0x52D4b98c506EE19295b4c707C16Aa0b6C196D56c
    [mgr_6570]=0x657010E159dEb03617519069Db7D7c1A8297aCE4
    [old_87393B_impl_096a]=0x096A454e0f567c2E47679af1E242e615e8C91b5B
    [nodemgr_impl_dcf7]=0xDcF7Dbe6865e52409A0fa2b4B23433DB2Af3646f
  )
  for name in "${!TARGETS[@]}"; do
    addr="${TARGETS[$name]}"
    echo "[h-07] decompiling $name $addr"
    timeout 600 "$HEIMDALL" decompile "$addr" -r "$RPC" -o print -d --include-sol \
      > "ci-out/decomp/$name.sol" 2> "ci-out/decomp/$name.err" || true
    # 0.9.x may write to a directory instead; keep both shapes
    if [ ! -s "ci-out/decomp/$name.sol" ]; then
      timeout 600 "$HEIMDALL" decompile "$addr" -r "$RPC" -o "ci-out/decomp/$name" -d \
        >> "ci-out/decomp/$name.sol" 2>> "ci-out/decomp/$name.err" || true
    fi
    wc -c "ci-out/decomp/$name.sol" || true
  done
else
  echo "[h-07] heimdall unavailable (glibc?) — skipping decompile" | tee ci-out/decomp/SKIPPED.txt
fi

# ---- 2. live state dump ----------------------------------------------------
python3 analysis/state_dump.py "$RPC" > ci-out/state/state_dump.json 2> ci-out/state/state_dump.err || true
tail -3 ci-out/state/state_dump.err 2>/dev/null || true

# ---- 3. selector tables for the current impl ------------------------------
if command -v cast >/dev/null; then
  CODE=$(cast code --rpc-url "$RPC" 0x568AA6C21cCf558C47F2A01B60cc6D549cED2F59 2>/dev/null || true)
  echo "$CODE" > ci-out/state/impl_568AA6C2_code.hex
  python3 - "$CODE" > ci-out/state/impl_selectors.txt <<'PY' || true
import sys, re
code = sys.argv[1] if len(sys.argv) > 1 else ""
# dispatcher selectors: 63<sel>14<dest> patterns
sels = sorted(set(re.findall(r'63([0-9a-f]{8})14', code)))
print("\n".join(sels))
PY
fi

echo "[h-07] done"
ls -la ci-out/decomp ci-out/state
