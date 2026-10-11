#!/usr/bin/env bash
# 10KSwap deep-dive — heavy CI job (runs on GitHub Actions, ubuntu-latest).
#
# Goal: reproduce the deployed 10KSwap Cairo-0 class definitions from the public
# source repo and prove (or disprove) that the on-chain contracts are the audited
# source. Compiles inside a python:3.9 container (cairo-lang 0.9.1 needs py3.9).
# Loops over candidate sympy versions (the compiler's expression simplifier uses
# sympy; the contemporary 2022 version was 1.11) until the deployed pair program
# is reproduced, then compiles factory+router with the same version.
#
# Outputs -> ci-out/classhash-verification.json, ci-out/compile.log
# Public data only; no secrets.
set -uo pipefail
cd "$(dirname "$0")/.."
JOB="$(pwd)"
OUT="$JOB/ci-out"
mkdir -p "$OUT"
WORK=/tmp/10kswap-verify
rm -rf "$WORK"; mkdir -p "$WORK"

echo "== clone source repo at audited commit =="
git clone --quiet https://github.com/10k-swap/10k_swap-contracts.git "$WORK/repo" || { echo "CLONE FAILED"; exit 1; }
cd "$WORK/repo"
git checkout --quiet c47f2e158687a757d0834893d5b01ba4131a55ec || { echo "CHECKOUT FAILED"; exit 1; }
echo "repo HEAD: $(git rev-parse HEAD)"
git log -1 --format='%H %ad %s' --date=iso

echo "== compile in python:3.9 container (cairo-lang 0.9.1 + OZ 0.3.2) =="
docker run --rm -v "$WORK":/w -v "$JOB":/job -w /w/repo python:3.9 bash -lc '
set -e
apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq cmake >/dev/null 2>&1 || true
pip install --quiet "cairo-lang==0.9.1" "openzeppelin-cairo-contracts==0.3.2" \
  "marshmallow==3.17.1" "marshmallow-dataclass==8.5.9" "marshmallow-enum==1.5.1" \
  "marshmallow-oneofschema==3.0.1" "typeguard==2.13.3" "sympy==1.11"
echo "--- versions ---"
python -c "import starkware.cairo.lang.version as v; print(\"cairo-lang\", v.__version__)"
pip show openzeppelin-cairo-contracts 2>/dev/null | head -2
SITE=$(python -c "import openzeppelin,os;print(os.path.dirname(os.path.dirname(os.path.abspath(openzeppelin.__file__))))")
echo "OZ site-packages: $SITE"
which starknet-compile || true
mkdir -p /w/compiled
compile_one() {  # $1 = source, $2 = output
  starknet-compile "$1" --output "$2" --cairo_path "$SITE:/w/repo/contracts" --no_debug_info \
    || starknet-compile "$1" --output "$2" --cairo_path "$SITE:/w/repo/contracts"
}
MATCHED=""
for SY in 1.11 1.10.1 1.9; do
  echo "=== sympy $SY: import check + pair compile ==="
  pip install -q "sympy==$SY" || true
  if ! python -c "import starkware.starknet.compiler.compile" 2>/dev/null; then
    echo "  import of compiler failed with sympy $SY"; continue
  fi
  rm -f /w/compiled/pair.json
  if ! compile_one contracts/l0k_pair.cairo /w/compiled/pair.json; then
    echo "  pair compile failed with sympy $SY"; continue
  fi
  python /job/ci/verify.py --compiled /w/compiled --deployed /job/ci/inputs \
    --out /w/pair-check.json --classes pair || true
  if python -c "
import json,sys
d = json.load(open(\"/w/pair-check.json\"))
sys.exit(0 if d[\"classes\"][\"pair\"].get(\"VERIFIED\") else 1)"; then
    MATCHED="$SY"; echo "  PAIR MATCHED with sympy $SY"; break
  fi
  echo "  no match with sympy $SY"
done
SY="${MATCHED:-1.9}"
echo "=== final compile with sympy $SY (matched=${MATCHED:-none}) ==="
pip install -q "sympy==$SY" || true
rm -f /w/compiled/*.json
compile_one contracts/l0k_pair.cairo    /w/compiled/pair.json
compile_one contracts/l0k_factory.cairo /w/compiled/factory.json
compile_one contracts/l0k_router.cairo  /w/compiled/router.json
python /job/ci/verify.py --compiled /w/compiled --deployed /job/ci/inputs \
  --out /job/ci-out/classhash-verification.json
' 2>&1 | tee "$OUT/compile.log"

RC=${PIPESTATUS[0]}
echo "== verify result =="
cat "$OUT/classhash-verification.json" 2>/dev/null | head -160
echo "container rc=$RC"
if [ -f "$OUT/classhash-verification.json" ]; then
  exit 0
fi
exit $RC
