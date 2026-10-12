#!/usr/bin/env bash
# Custom CI job for the Stakehouse deep dive.
# Dumps live protocol state to ci-out/ for the record (tolerant to RPC hiccups).
# No secrets are written: only public chain data.
set -uo pipefail
mkdir -p ci-out

python3 - <<'PY' 2>&1 | tee ci-out/state_dump.txt
import json, os, time, urllib.request, subprocess

ENDPOINTS = []
for k in ("FORK_RPC_URL", "RPC_URL", "BLOCKPI_RPC_URL", "NODEREAL_ETH_RPC_URL"):
    v = os.environ.get(k)
    if v: ENDPOINTS.append(v)
ENDPOINTS += ["https://ethereum-rpc.publicnode.com", "https://eth.drpc.org"]

def rpc(method, params, tries=8):
    last = None
    for i in range(tries):
        url = ENDPOINTS[i % len(ENDPOINTS)]
        try:
            req = urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                                         headers={"Content-Type":"application/json","User-Agent":"ci-research/1.0"})
            with urllib.request.urlopen(req, timeout=25) as r:
                out = json.loads(r.read())
            if "result" in out: return out["result"]
            last = out.get("error")
        except Exception as e:
            last = str(e)
        time.sleep(1.0)
    raise RuntimeError(f"{method} failed: {last}")

def call(to, data):
    return rpc("eth_call", [{"to": to, "data": data}, "latest"])

def sig_cast(s):
    try:
        return subprocess.run(["cast","sig",s],capture_output=True,text=True,timeout=10).stdout.strip()
    except Exception:
        return ""

AM = "0xDd6E67942a9566A70446f7400a21240C5f71377C"
SLOTREG = "0xC01DC3c7F83B12CFdF6C0AAa09c880EB45c48569"
SWEEPR = "0x64f4fCFb8377DEaABF334eD42aC113E6813a55d0"
FW = "0x8F6839b0AcD8d7c7d2f01C1C7ECCa982Ca354333"
VERIFIER = "0x9785f8e50229ebd2b3788452abc31d1942394e0c"

out = {"block": int(rpc("eth_blockNumber", []), 16)}

bal = {}
for name, addr in {"AccountManager": AM, "TransactionRouter": "0x03F4310bfE3968934bC11DfA17B8DF809D7DEA80",
                   "SLOTRegistry": SLOTREG, "savETHRegistry": "0x88E6c7072B867F9546a232548a5D3271986B3C0c",
                   "SweepReporting": SWEEPR, "FullWithdrawals": FW, "Universe": "0xC6306C52ea0405D3630249f202751aE3043056bd"}.items():
    bal[name] = int(rpc("eth_getBalance", [addr, "latest"]), 16)
out["balances_wei"] = bal

KEY78 = "0x97d7b76dd71e01d3d0f6aeb9f7c329e956b75ebc51537f188dbe79fc0f4c9636aafc899e8001f331fa61ac00c9247ec7"
KEY44 = "0x8f691a275f2a741ea851897ad9833810237a25c9b200637c2970a232fcff0d3e06562bba4a154d0cb1742fccf859b9ad"
def enc_uint(i): return hex(i)[2:].rjust(64, "0")
def enc_addr(a): return a[2:].rjust(64, "0")
def enc_bytes(b):
    h = b[2:]
    ln = len(h)//2
    return enc_uint(ln) + h.ljust(((ln+31)//32)*32*2, "0")
def enc_bytes_arg(b): return enc_uint(0x20) + enc_bytes(b)

S = {
 "lifecycle": sig_cast("blsPublicKeyToLifecycleStatus(bytes)"),
 "reportedNotWithdrawn": sig_cast("totalReportedETHNotWithdrawn(bytes)"),
 "totalSent": sig_cast("totalETHSentToBlsPublicKey(bytes)"),
 "enabled": sig_cast("isUserEnabledForKnotWithdrawal(address,bytes)"),
 "withdrawn": sig_cast("userWithdrawn(address,bytes)"),
 "isFullSweepReported": sig_cast("isFullSweepReported(uint256)"),
 "isDesignatedVerifier": sig_cast("isDesignatedVerifier(address)"),
}
def hexres(x): return None if x in (None, "0x") else int(x, 16)

state = {}
try:
    state["knot78"] = {
        "key": KEY78,
        "user": "0xddb50ffdba4d89354e1088e4ea402de895562173",
        "lifecycle": hexres(call(AM, S["lifecycle"] + enc_bytes_arg(KEY78))),
        "reportedNotWithdrawn": hexres(call(SWEEPR, S["reportedNotWithdrawn"] + enc_bytes_arg(KEY78))),
        "enabled": hexres(call(SLOTREG, S["enabled"] + enc_addr("0xddb50ffdba4d89354e1088e4ea402de895562173") + enc_uint(0x40) + enc_bytes(KEY78))),
        "withdrawn": hexres(call(SLOTREG, S["withdrawn"] + enc_addr("0xddb50ffdba4d89354e1088e4ea402de895562173") + enc_uint(0x40) + enc_bytes(KEY78))),
        "fullSweepReported_1109420": hexres(call(FW, S["isFullSweepReported"] + enc_uint(1109420))),
    }
    state["knot44"] = {
        "key": KEY44,
        "wallet": "0x246269f844d538f02974e54c71c87a7e63c82a68",
        "lifecycle": hexres(call(AM, S["lifecycle"] + enc_bytes_arg(KEY44))),
        "reportedNotWithdrawn": hexres(call(SWEEPR, S["reportedNotWithdrawn"] + enc_bytes_arg(KEY44))),
        "enabled": hexres(call(SLOTREG, S["enabled"] + enc_addr("0x246269f844d538f02974e54c71c87a7e63c82a68") + enc_uint(0x40) + enc_bytes(KEY44))),
        "fullSweepReported_747994": hexres(call(FW, S["isFullSweepReported"] + enc_uint(747994))),
    }
    state["verifier"] = {
        "isDesignatedVerifier_FW": hexres(call(FW, S["isDesignatedVerifier"] + enc_addr(VERIFIER))),
        "isDesignatedVerifier_SR": hexres(call(SWEEPR, S["isDesignatedVerifier"] + enc_addr(VERIFIER))),
        "code_size": (len(rpc("eth_getCode", [VERIFIER, "latest"])) - 2)//2,
        "nonce": int(rpc("eth_getTransactionCount", [VERIFIER, "latest"]), 16),
    }
    state["numberOfAccounts"] = hexres(call(AM, "0x0f03e4c3"))
except Exception as e:
    state["error"] = str(e)
out["state"] = state

with open("ci-out/state.json", "w") as f:
    json.dump(out, f, indent=1)
print(json.dumps(out, indent=1))
PY

echo "[ci] state dump done"
exit 0
