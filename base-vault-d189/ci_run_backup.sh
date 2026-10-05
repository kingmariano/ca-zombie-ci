#!/usr/bin/env bash
# C2-02 heavy job — independent live-state measurement + max-drain binary search
# for the Base credit vault 0xD1895f2019c2152FC2b9022D57f19198c4CFCABC.
# READ-ONLY: only eth_call/eth_getCode/eth_blockNumber/eth_getTransactionReceipt.
# No transactions. Results -> ci-out/state.json (uploaded as artifact).
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out

R="${BASE_RPC_URL:-}"
[ -z "$R" ] && R="https://base-rpc.publicnode.com"
export D189_RPC="$R"

python3 - <<'PYEOF' > ci-out/state.json
import json, os, urllib.request, sys, traceback

R = os.environ["D189_RPC"]
def rpc(method, params):
    req = urllib.request.Request(R,
        data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
        headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    return json.load(urllib.request.urlopen(req, timeout=60))

def call(to, data, blk=None, frm="0x0000000000000000000000000000000000000000"):
    p = [{"from": frm, "to": to, "data": data}]
    if blk is not None: p.append(hex(blk))
    r = rpc("eth_call", p)
    return r.get("result")

def num(x):
    return int(x, 16) if x and x != "0x" else 0

def pad(a): return "0"*24 + a[2:].lower()

V      = "0xD1895f2019c2152FC2b9022D57f19198c4CFCABC"
HELPER = "0xcdFE91301356da873562EF513828a60dba1F569d"
COPY   = "0x13Fed10846B5fE35601452731d7b847adC7722a9"
ATT    = "0x0B5126e1bc27C0de77e02e97945760A674EdB034"
AWETH  = "0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7"
WETH   = "0x4200000000000000000000000000000000000006"
POOL   = "0xA238Dd80C259a72e81d7e4664a9801593F98d1c5"
ORACLE = "0x2Cc0Fc26eD4563A5ce5e8bdcfe1A2878676Ae156"
DP     = "0x0F43731EB8d45A581f4a36DD74F5f358bc90C73A"
FRESH  = "0x2222222222222222222222222222222222222222"

out = {"rpc_reachable": False}
try:
    bn = num(rpc("eth_blockNumber", [])["result"])
    out["rpc_reachable"] = True
    out["latest_block"] = bn
    # try a pinned block (archive); fall back to latest
    B = bn - 50
    try:
        call(V, "0x8da5cb5b", B)
    except Exception:
        B = None
    out["read_block"] = B if B is not None else bn

    out["vault_owner"]  = "0x" + call(V, "0x8da5cb5b", B)[-40:]
    out["helper_owner"] = "0x" + call(HELPER, "0x8da5cb5b", B)[-40:]
    out["minHealth"]    = num(call(V, "0x455166a2", B))
    out["whitelist_helper"]  = num(call(V, "0x9b19251a" + pad(HELPER), B)) == 1
    out["whitelist_copycat"] = num(call(V, "0x9b19251a" + pad(COPY), B)) == 1
    out["aWETH_balance"] = num(call(AWETH, "0x70a08231" + pad(V), B)) / 1e18
    out["weth_price_usd"] = num(call(ORACLE, "0xb3596f07" + pad(WETH), B)) / 1e8
    acct = call(POOL, "0xbf92857c" + pad(V), B)
    a = [num("0x" + acct[i:i+64]) for i in range(2, len(acct), 64)]
    out["aave"] = {"collateral_usd": a[0]/1e8, "debt_usd": a[1]/1e8,
                   "lt_bps": a[3], "health_factor": a[5]/1e18}
    cfg = call(DP, "0x3e150141" + pad(WETH), B)
    c = [num("0x" + cfg[i:i+64]) for i in range(2, 2+64*5, 64)]
    out["weth_reserve_lt_bps"] = c[2]

    def probe(amt):
        data = "0x9a39f8dd" + pad(AWETH) + format(amt, "064x")
        r = rpc("eth_call", [{"from": ATT, "to": HELPER, "data": data, "gas": "0x1c9c380"}, hex(B) if B else "latest"])
        return "result" in r, str(r.get("error", {}).get("data", ""))[:12]

    ok, _ = probe(7000 * 10**18)
    out["probe_7000_ok"] = ok
    lo, hi = 7000 * 10**18, int(out["aWETH_balance"] * 10**18)
    for _ in range(60):
        mid = (lo + hi) // 2
        ok, _ = probe(mid)
        if ok: lo = mid
        else:  hi = mid
        if hi - lo < 10**15: break
    out["max_borrow_aWETH"] = lo / 1e18
    out["max_borrow_usd"] = round(lo / 1e18 * out["weth_price_usd"], 2)
    ok_bad, err = probe(hi)
    out["next_fail_revert_prefix"] = err

    def borrow_from(frm, receiver):
        data = ("0xa415bcad" + pad(AWETH) + format(10**18, "064x") + format(0, "064x")
                + format(0, "064x") + pad(receiver))
        r = rpc("eth_call", [{"from": frm, "to": V, "data": data, "gas": "0x1c9c380"}, hex(B) if B else "latest"])
        if "result" in r: return "SUCCESS"
        d = str(r.get("error", {}).get("data", ""))
        try:
            if d.startswith("0x08c379a0") and len(d) >= 2+64*3:
                raw = bytes.fromhex(d[2:])
                return "REVERT:" + raw[68:68+int.from_bytes(raw[36:68], "big")].decode(errors="replace")
        except Exception:
            pass
        return "REVERT:" + d[:20]

    out["fresh_borrow_direct"]  = borrow_from(FRESH, FRESH)
    out["fresh_borrow_receiver_helper"] = borrow_from(FRESH, HELPER)
    r = rpc("eth_call", [{"from": FRESH, "to": HELPER,
            "data": "0x9a39f8dd" + pad(AWETH) + format(10**18, "064x"), "gas": "0x1c9c380"},
            hex(B) if B else "latest"])
    out["fresh_helper_withdraw"] = "SUCCESS" if "result" in r else "REVERT"

    try:
        rec = rpc("eth_getTransactionReceipt",
                  ["0x77b5a7463d2492413de6f95c2c4e7c3f450cb6c39605330645f3540eb64b2be8"])
        out["copycat_tx_status"] = rec.get("result", {}).get("status") if rec.get("result") else None
    except Exception as e:
        out["copycat_tx_status"] = "unavailable"
except Exception:
    out["error"] = traceback.format_exc().splitlines()[-1]

json.dump(out, sys.stdout, indent=2)
print()
PYEOF

echo "[d189] wrote ci-out/state.json"
cat ci-out/state.json
