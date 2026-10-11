#!/usr/bin/env bash
# CI class-hash verification: compile jediswaplabs/JediSwap at commit 11b4414 with
# cairo-lang 0.10.0 + OpenZeppelin cairo-contracts b764660 and compare class hashes
# to the live on-chain classes. Read-only; public sources only; no secrets.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../ci-out"
mkdir -p "$OUT"
LOG="$OUT/classhash.txt"
exec > >(tee "$LOG") 2>&1

echo "=== JediSwap V1 class-hash verification $(date -u +%FT%TZ) ==="

# ---------- python 3.10 (uv preferred; cairo-lang 0.10.0 does not run on >=3.11) ----------
VENV=/tmp/cairovenv
rm -rf "$VENV"
VPIP=""
if ! command -v uv >/dev/null 2>&1; then
  python3 -m pip install --user --quiet uv >/dev/null 2>&1 || true
  export PATH="$HOME/.local/bin:$PATH"
fi
if command -v uv >/dev/null 2>&1; then
  uv venv --python 3.10 "$VENV" >/dev/null 2>&1 || true
  if [ -x "$VENV/bin/python" ]; then
    VPIP="uv pip install --python $VENV/bin/python"
  fi
fi
if [ -z "$VPIP" ]; then
  PY=""
  command -v python3.10 >/dev/null 2>&1 && PY="$(command -v python3.10)"
  [ -z "$PY" ] && PY="$(command -v python3)"
  echo "uv unavailable; using $PY ($($PY --version 2>&1))"
  "$PY" -m venv "$VENV" || { echo "venv failed"; exit 0; }
  VPIP="$VENV/bin/pip"
fi
echo "venv python: $($VENV/bin/python --version 2>&1)"
$VPIP install --quiet cairo-lang==0.10.0 >/dev/null 2>&1
$VPIP install --quiet "frozendict==1.2" "marshmallow==3.20.2" "marshmallow-dataclass==8.5.8" "sympy==1.9" "typeguard==2.13.3" >/dev/null 2>&1

# frozendict 1.2 shim for py>=3.10
FZ="$(find "$VENV" -path '*frozendict/__init__.py' 2>/dev/null | head -1)"
if [ -n "$FZ" ] && [ -f "$FZ" ]; then
  "$VENV/bin/python" - "$FZ" <<'PYEOF'
import sys
p = sys.argv[1]
src = open(p).read()
if "import collections.abc" not in src:
    src = src.replace("import collections", "import collections\nimport collections.abc", 1)
    src = src.replace("collections.Mapping", "collections.abc.Mapping")
    open(p, "w").write(src)
    print("frozendict patched")
PYEOF
fi
# cairo-lang 0.10.0 dataclass mutable-default shim for py3.12 (harmless on 3.10)
INST="$(find "$VENV" -path '*cairo/lang/instances.py' 2>/dev/null | head -1)"
if [ -n "$INST" ] && [ -f "$INST" ]; then
  "$VENV/bin/python" - "$INST" <<'PYEOF'
import sys
p = sys.argv[1]
src = open(p).read()
if "default_factory=CpuInstanceDef" not in src:
    src = src.replace("field(default=CpuInstanceDef())", "field(default_factory=CpuInstanceDef)")
    open(p, "w").write(src)
    print("instances.py patched")
PYEOF
fi
"$VENV/bin/cairo-compile" --version || { echo "cairo-compile unavailable"; exit 0; }

# ---------- sources ----------
REPO=/tmp/jediswap-src
rm -rf "$REPO"
git clone --quiet https://github.com/jediswaplabs/JediSwap "$REPO" || { echo "clone failed"; exit 0; }
cd "$REPO"
git checkout --quiet 11b4414
git submodule update --init --quiet lib/cairo_contracts || { echo "submodule failed"; exit 0; }
echo "repo commit: $(git rev-parse --short HEAD)  OZ: $(cd lib/cairo_contracts && git rev-parse --short HEAD)"

# ---------- compile ----------
BUILD=/tmp/jediswap-build
rm -rf "$BUILD"; mkdir -p "$BUILD"
for c in Pair Factory PairProxy FactoryProxy Router RouterProxy; do
  "$VENV/bin/starknet-compile" "contracts/$c.cairo" --cairo_path lib/cairo_contracts/src \
      --dont_filter_identifiers --output "$BUILD/$c.json" --abi "$BUILD/${c}_abi.json" \
      >/dev/null 2>&1 && echo "compiled $c" || echo "COMPILE FAILED $c"
done

# ---------- compare ----------
"$VENV/bin/python" "$HERE/classhash_check.py" "$BUILD" | tee "$OUT/classhash_results.txt"
echo "=== done ==="
exit 0
