#!/usr/bin/env bash
# C2-09 Archway heavy job: read-only enumeration + economics model + version-hash check.
# Runs on GitHub Actions; writes all evidence to ci-out/.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out

echo "=== [1/5] environment ==="
python3 --version
curl -s --max-time 20 https://api.mainnet.archway.io/cosmos/base/tendermint/v1beta1/node_info > ci-out/node_info_raw.json || true
python3 - <<'EOF' > ci-out/version_hash_check.txt 2>&1
import json, urllib.request, re
def get(u):
    try:
        with urllib.request.urlopen(u, timeout=30) as r: return r.read().decode()
    except Exception as e: return "ERR "+str(e)
node = get("https://api.mainnet.archway.io/cosmos/base/tendermint/v1beta1/node_info")
sumline = get("https://sum.golang.org/lookup/github.com/!cosm!wasm/wasmvm@v1.5.5")
print("NODE BUILD DEPS (wasmvm):")
try:
    d=json.loads(node)
    for x in d["application_version"]["build_deps"]:
        if "wasm" in x["path"].lower() or x["path"].endswith("cometbft"):
            print(" ", x["path"], x["version"], x.get("sum"))
except Exception as e:
    print("parse err", e)
print("\nSUM.GOLANG.ORG wasmvm v1.5.5:")
print(sumline)
EOF
cat ci-out/version_hash_check.txt

echo "=== [2/5] wasmvm artifact verification (deployed module zip + linked lib) ==="
bash ci/wasmvm_poc.sh 2>&1 | tee ci-out/wasmvm_poc.log

echo "=== [4/6] full chain enumeration (codes/contracts/infos/balances) ==="
python3 ci/enumerate.py 2>&1 | tee ci-out/enumerate.log

echo "=== [5/6] code 31 (EvolvNFT, ~17.8k instances) dedicated sweep ==="
python3 ci/code31_check.py 2>&1 | tee ci-out/code31_check.log

echo "=== [6/6] economics model ==="
python3 ci/model.py 2>&1 | tee ci-out/model.log

echo "=== outputs ==="
ls -la ci-out/
