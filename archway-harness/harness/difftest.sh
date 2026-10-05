#!/usr/bin/env bash
# Differential test: same contract + inputs through the vulnerable engine
# (wasmvm v1.5.5 / Wasmer 4.2.2) and the patched engine (wasmvm v3.0.8 / Wasmer 7.4.2).
# Reports: exit-code differences (crashes!) and behavioral differences (responses/errors).
#
# Usage: difftest.sh <wasm> [init-json] [exec-json] [repeat] [outdir]
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
VULN="$HERE/harness"
FIXED="$HERE/../harness-fixed/harness-fixed"
WASM="${1:?usage: difftest.sh <wasm> [init] [exec] [repeat] [outdir]}"
INIT="${2:-{\}}"
EXEC="${3:-{\}}"
REPEAT="${4:-1}"
OUT="${5:-/tmp/difftest}"
mkdir -p "$OUT"

"$VULN"  -wasm "$WASM" -init "$INIT" -exec "$EXEC" -repeat "$REPEAT" -out "$OUT/vuln.json"  >"$OUT/vuln.stdout"  2>"$OUT/vuln.stderr"
C1=$?
"$FIXED" -wasm "$WASM" -init "$INIT" -exec "$EXEC" -repeat "$REPEAT" -out "$OUT/fixed.json" >"$OUT/fixed.stdout" 2>"$OUT/fixed.stderr"
C2=$?

python3 - "$OUT" "$C1" "$C2" <<'EOF'
import json, sys
out, c1, c2 = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])

def load(p):
    try:
        return json.load(open(p))
    except Exception:
        return None

def norm(r):
    if not r:
        return None
    inst = r.get("instantiate", {}) or {}
    execs = r.get("executes") or []
    return {
        "inst_err": inst.get("error", ""),
        "inst_resp": inst.get("response"),
        "execs": [(e.get("error", ""), e.get("response")) for e in execs],
    }

v, f = load(f"{out}/vuln.json"), load(f"{out}/fixed.json")
nv, nf = norm(v), norm(f)

findings = []
if c1 != c2:
    findings.append(f"EXIT-DIFF vuln={c1} fixed={c2}")
if c1 not in (0, 1) or c2 not in (0, 1):
    findings.append(f"CRASH-SUSPECT exitcodes vuln={c1} fixed={c2}")
if nv != nf:
    findings.append("BEHAVIOR-DIFF")
    findings.append(f"  vuln : {json.dumps(nv)[:300]}")
    findings.append(f"  fixed: {json.dumps(nf)[:300]}")

if findings:
    print("\n".join(findings))
    sys.exit(3)
print("SAME")
EOF
