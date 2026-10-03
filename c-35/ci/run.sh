#!/usr/bin/env bash
# C-35 heavy job: live balance/selector scan + F3D-family state dump (read-only RPC).
# Runs from c-35/ in CI. Writes ci-out/scan_report.json + .md (uploaded as artifact).
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
python3 ci/scan.py
echo "[ci] running liquidity/openchain sanity checks..."
python3 - <<'PY'
import json, os, urllib.request
# FEG fETH: confirm no live Uniswap V2 pair on Ethereum (E-U market path closed)
EP = os.environ.get("FORK_RPC_URL") or os.environ.get("RPC_URL") or "https://ethereum-rpc.publicnode.com"
def call(to, data):
    req = urllib.request.Request(EP, data=json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":to,"data":data},"latest"]}).encode(),
                                 headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    return json.load(urllib.request.urlopen(req, timeout=25)).get("result","0x")
FACTORY = "0x5c69bee701ef814a2b6a3edd4b1652cb9cc5aa6f"
FEG = "0xf786c34106762ab4eeb45a51b42a62470e9d5332"
WETH = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
data = "0xe6a43905" + FEG[2:].rjust(64,"0") + WETH[2:].rjust(64,"0")
pair = call(FACTORY, data)
out = {"feg_weth_pair_univ2": "0x"+pair[-40:] if len(pair)>=42 else pair}
json.dump(out, open("ci-out/liquidity_check.json","w"), indent=1)
print("[ci] liquidity:", out)
PY
echo "[ci] scan done"
