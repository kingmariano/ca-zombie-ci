#!/usr/bin/env bash
# E8: archwayd Go-ABI mint-path target analysis — CWA-2026-006 stage-2 groundwork.
# Read-only static analysis of the exact mainnet binary (v10.1.0, non-PIE ET_EXEC).
# No chain interaction, no keys.
#
# Deliverable targeted here:
#   * full pclntab function inventory of archwayd (works on the stripped release)
#   * candidate lists for the mint path (x/bank MintCoins/SendCoins/etc., x/mint,
#     wasmd keeper, sdk.Context construction, runtime stack machinery)
#   * disassembly of the top mint-chain targets (Go syntax)
#   * direct call-site xrefs for those targets (address -> callers)
#   * categorised ROP/JOP gadget catalog (rsp pivots, indirect branches, write prims)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"        # .../archway-mint/e8
ROOT="$(cd "$HERE/.." && pwd)"               # .../archway-mint
OUT="$ROOT/ci-out"
mkdir -p "$OUT"

ARCHWAYD_URL="https://github.com/archway-network/archway/releases/download/v10.1.0/archwayd_linux_amd64"

echo "=== [1/6] fetch archwayd v10.1.0 (cached) ==="
if [ ! -s /tmp/archwayd ]; then
  curl -sL --max-time 1200 -o /tmp/archwayd "$ARCHWAYD_URL" && echo "downloaded archwayd" || echo "download FAILED"
fi
if [ ! -s /tmp/archwayd ]; then echo "archwayd unavailable; abort E8"; exit 1; fi
sha256sum /tmp/archwayd | tee "$OUT/archwayd.sha256"
file /tmp/archwayd | tee "$OUT/archwayd_info.txt"
readelf -h /tmp/archwayd 2>/dev/null | grep -E "Type:|Entry point" | tee -a "$OUT/archwayd_info.txt"
ls -la /tmp/archwayd | tee -a "$OUT/archwayd_info.txt"

echo "=== [2/6] pclntab function inventory ==="
if (cd "$HERE/pclntab_dump" && go build -o /tmp/pclntab_dump .) 2>"$OUT/pclntab_build.err"; then
  timeout 900 /tmp/pclntab_dump /tmp/archwayd > "$OUT/archwayd_functions.txt" 2>"$OUT/pclntab_dump.err" || true
fi
if [ ! -s "$OUT/archwayd_functions.txt" ]; then
  echo "pclntab_dump failed; fallback: go tool objdump full dump" | tee -a "$OUT/archwayd_info.txt"
  [ -s /tmp/archwayd_go.asm ] || timeout 3000 go tool objdump /tmp/archwayd > /tmp/archwayd_go.asm 2>/dev/null || true
  grep -E '^TEXT ' /tmp/archwayd_go.asm 2>/dev/null | sed -E 's/^TEXT ([^ ]+)\(SB\).*/\1/' | sort -u > "$OUT/archwayd_functions.txt" || true
fi
N_FN=$(wc -l < "$OUT/archwayd_functions.txt" 2>/dev/null || echo 0)
echo "functions enumerated: $N_FN" | tee -a "$OUT/archwayd_info.txt"
head -10 "$OUT/archwayd_functions.txt" | tee -a "$OUT/archwayd_info.txt"

echo "=== [3/6] candidate extraction (mint / bank / wasmd / context / runtime) ==="
FNS="$OUT/archwayd_functions.txt"
grep -Ei 'bank(/|keeper)' "$FNS" > "$OUT/e8_bank_all.txt" || true
grep -Ei '(MintCoins|SendCoins|BurnCoins|AddCoins|InputOutputCoins|SetBalance|SendCoinsFromModule|SendCoinsFromAccount)' "$OUT/e8_bank_all.txt" > "$OUT/e8_mint_candidates.txt" || true
grep -Ei 'x/mint' "$FNS" > "$OUT/e8_xmint.txt" || true
grep -Ei 'x/wasm/keeper' "$FNS" > "$OUT/e8_wasmd.txt" || true
grep -Ei '(NewContext|WithGasMeter|CacheContext|KVStore|types\.Context)' "$FNS" > "$OUT/e8_ctx.txt" || true
grep -Ei 'runtime\.(morestack|newstack|growstack)' "$FNS" > "$OUT/e8_runtime.txt" || true
grep -Ei '(msgServer|MsgServer)' "$FNS" > "$OUT/e8_msgserver.txt" || true
for f in e8_bank_all e8_mint_candidates e8_xmint e8_wasmd e8_ctx e8_runtime e8_msgserver; do
  echo "--- $f: $(wc -l < "$OUT/$f.txt" 2>/dev/null || echo 0) entries" | tee -a "$OUT/archwayd_info.txt"
done
echo "--- mint candidates ---" | tee -a "$OUT/archwayd_info.txt"
head -60 "$OUT/e8_mint_candidates.txt" | tee -a "$OUT/archwayd_info.txt"

echo "=== [4/6] target disassembly (Go syntax, pclntab-based) ==="
: > "$OUT/e8_target_disasm.txt"
: > "$OUT/e8_objdump.err"
for pat in 'MintCoins' 'SendCoins' 'AddCoins' 'InputOutputCoins' 'SetBalance' 'FundCommunityPool' 'BeginBlocker'; do
  { echo "########## PATTERN: $pat"; timeout 600 go tool objdump -s "$pat" /tmp/archwayd 2>>"$OUT/e8_objdump.err" | head -600; } >> "$OUT/e8_target_disasm.txt"
done
wc -l "$OUT/e8_target_disasm.txt" | tee -a "$OUT/archwayd_info.txt"
if [ "$(wc -l < "$OUT/e8_target_disasm.txt")" -lt 120 ]; then
  echo "go tool objdump produced little; falling back to full-dump extraction" | tee -a "$OUT/archwayd_info.txt"
  [ -s /tmp/archwayd_go.asm ] || timeout 3000 go tool objdump /tmp/archwayd > /tmp/archwayd_go.asm 2>/dev/null || true
  if [ -s /tmp/archwayd_go.asm ]; then
    for pat in 'MintCoins' 'SendCoins' 'AddCoins' 'InputOutputCoins' 'SetBalance' 'FundCommunityPool' 'BeginBlocker'; do
      { echo "########## PATTERN: $pat (full-dump extract)"; awk -v p="$pat" '/^TEXT /{f=($0 ~ p)} f' /tmp/archwayd_go.asm | head -600; } >> "$OUT/e8_target_disasm.txt"
    done
  fi
fi

echo "=== [5/6] call-site xrefs for the mint targets (GNU dump addresses) ==="
if [ ! -s /tmp/archwayd.asm ]; then
  echo "building GNU dump (first time, ~15 min)"
  timeout 1800 objdump -d /tmp/archwayd > /tmp/archwayd.asm 2>/dev/null || true
fi
if [ -s /tmp/archwayd.asm ]; then
  timeout 900 python3 "$HERE/xref_scan.py" /tmp/archwayd.asm "$FNS" \
    'MintCoins' 'InputOutputCoins' 'FundCommunityPool' 'AddCoins' 'SetBalance' \
    'SendCoinsFromModuleToAccount' 'x/mint.*BeginBlocker' > "$OUT/e8_xrefs.txt" 2>&1 || true
  wc -l "$OUT/e8_xrefs.txt" | tee -a "$OUT/archwayd_info.txt"
else
  echo "GNU dump unavailable; xrefs skipped" | tee -a "$OUT/archwayd_info.txt"
fi

echo "=== [6/6] deep gadget catalog (pivots / reg-branches / write primitives) ==="
if [ -s /tmp/archwayd.asm ]; then
  timeout 1800 python3 "$HERE/gadget_scan.py" /tmp/archwayd.asm > "$OUT/e8_gadgets.txt" 2>&1 || true
  sed -n '/== SUMMARY ==/,$p' "$OUT/e8_gadgets.txt" | head -40 | tee -a "$OUT/archwayd_info.txt"
else
  echo "GNU dump unavailable; gadgets skipped" | tee -a "$OUT/archwayd_info.txt"
fi

echo "=== E8 results ==="
ls -la "$OUT"
exit 0
