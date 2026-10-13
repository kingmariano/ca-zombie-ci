#!/usr/bin/env python3
"""
Omm (ICON) Phase-2 heavy scan — read-only, public endpoints only.
1) Live state snapshot: reserves/freeze flags, custody balances, oracle + DEX prices,
   liquidation/admin flags, staking + rewards state.
2) Full user enumeration: all depositors/borrowers (paged) + getUserAccountData (concurrent)
   -> liquidatable/underwater analysis.
3) Event-log activity scan (tracker API): last Deposit/Borrow vs Redeem/Repay.
Writes JSON + SUMMARY.md to ci-out/. No secrets, no keyed endpoints.
"""
import json, time, urllib.request, urllib.error, os, sys
from concurrent.futures import ThreadPoolExecutor, as_completed

RPC = "https://ctz.solidwallet.io/api/v3"
TRACKER = "https://tracker.icon.community/api/v1"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ci-out")
os.makedirs(OUT, exist_ok=True)

LP   = "cxcb455f26a2c01c686fa7f30e1e3661642dd53c0d"
CORE = "cxfb312bbd0a244b9e7bb5794c91f4e4acc41dea94"
DP   = "cx5f9a6ca11b2b761a469965cedab40ada9e503cb5"
ORACLE = "cx189f03875da766878c68753da7492c080bcc2dbe"
STAKING = "cx43e2eec79eb76293c298f2b17aec06097be606e0"
REWARDS = "cx4f2d730ad969f5c839229de42184c5e47aefef6f"
FEEPROV = "cx4f3c2edf730f203b1ef1257d645415652ae8b4fb"
DEX = "cxa0af3165c08318e988cb30993b3048335b94af6c"
RESERVES = {
    "USDS": "cxbb2871f468a3008f80b08fdde5b8b951583acf06",
    "sICX": "cx2609b924e33ef00b648a409245c7ea394c467824",
    "IUSDC": "cxae3034235540b924dfcc1b45836c293dcc82bfb7",
    "bnUSD": "cx88fd7df7ddff82f7cc735c871dc519838cb235bb",
    "OMM": "cx1a29259a59f463a67bb2ef84398b30ca56b5830a",
    "BALN": "cxf61cd5a45dc9f91c15aa65831a30a90d59a09619",
}

def http(url, data=None, timeout=40, retries=3):
    for i in range(retries):
        try:
            req = urllib.request.Request(url, data=json.dumps(data).encode() if data else None,
                                         headers={"Content-Type": "application/json", "User-Agent": "omm-audit/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            if i == retries - 1:
                return {"__error__": str(e)}
            time.sleep(1.5 * (i + 1))

def rpc_call(to, method, params=None):
    j = http(RPC, {"jsonrpc": "2.0", "id": 1, "method": "icx_call",
                   "params": {"to": to, "dataType": "call", "data": {"method": method, "params": params or {}}}})
    if isinstance(j, dict) and "result" in j:
        return j["result"]
    return {"__error__": j.get("error", j)}

def rpc_balance(addr):
    j = http(RPC, {"jsonrpc": "2.0", "id": 1, "method": "icx_getBalance", "params": {"address": addr}})
    return j.get("result")

def last_block():
    j = http(RPC, {"jsonrpc": "2.0", "id": 1, "method": "icx_getLastBlock", "params": {}})
    return j.get("result", {}).get("height")

def hexint(v, default=0):
    try:
        return int(v, 16)
    except Exception:
        return default

def live_state():
    out = {"last_block": last_block()}
    res = {}
    for sym, addr in RESERVES.items():
        d = rpc_call(CORE, "getReserveData", {"_reserve": addr})
        if isinstance(d, dict) and "reserveAddress" in d:
            res[sym] = {k: d.get(k) for k in
                        ("reserveAddress", "isActive", "isFreezed", "borrowingEnabled",
                         "usageAsCollateralEnabled", "baseLTVasCollateral", "liquidationThreshold",
                         "liquidationBonus", "borrowThreshold", "availableBorrows",
                         "availableLiquidity", "totalBorrows", "totalLiquidity",
                         "oTokenAddress", "dTokenAddress", "decimals")}
    out["reserves"] = res
    out["liquidation_enabled"] = rpc_call(LP, "isLiquidationEnabled", {})
    out["lending_pool_admin"] = rpc_call(LP, "getAdmin", {})
    out["core_balances"] = {}
    for sym, addr in RESERVES.items():
        dec = {"IUSDC": 6}.get(sym, 18)
        b = rpc_call(addr, "balanceOf", {"_owner": CORE})
        out["core_balances"][sym] = hexint(b) / 10 ** dec if isinstance(b, str) else b
    out["core_icx"] = hexint(rpc_balance(CORE)) / 1e18
    out["oracle"] = {}
    for base in ["ICX", "USDS", "USDC", "bnUSD", "OMM", "BALN"]:
        p = rpc_call(ORACLE, "get_reference_data", {"_base": base, "_quote": "USD"})
        out["oracle"][base] = hexint(p) / 1e18 if isinstance(p, str) else p
    out["dex_prices_bnUSD"] = {}
    for name in ["USDS/bnUSD", "IUSDC/bnUSD", "sICX/bnUSD", "BALN/bnUSD"]:
        p = rpc_call(DEX, "getPriceByName", {"_name": name})
        out["dex_prices_bnUSD"][name] = hexint(p) / 1e18 if isinstance(p, str) else p
    out["dex_pools"] = {}
    for pid in [2, 3, 5, 10, 6, 7, 8]:
        st = rpc_call(DEX, "getPoolStats", {"_id": hex(pid)})
        if isinstance(st, dict):
            out["dex_pools"][pid] = {k: st.get(k) for k in
                                     ("name", "base_token", "quote_token", "base", "quote", "price",
                                      "base_decimals", "quote_decimals")}
    out["staking"] = {
        "getTotalStake": rpc_call(STAKING, "getTotalStake", {}),
        "getUndelegatedICX": rpc_call(STAKING, "getUndelegatedICX", {}),
        "getTodayRate": rpc_call(STAKING, "getTodayRate", {}),
        "getStakingOn": rpc_call(STAKING, "getStakingOn", {}),
        "icx_balance": hexint(rpc_balance(STAKING)) / 1e18,
        "claimableICX_core": rpc_call(STAKING, "claimableICX", {"_address": CORE}),
    }
    out["rewards"] = {
        "isRewardClaimEnabled": rpc_call(REWARDS, "isRewardClaimEnabled", {}),
        "omm_balance": hexint(rpc_call(RESERVES["OMM"], "balanceOf", {"_owner": REWARDS})) / 1e18,
        "distributedDay": rpc_call(REWARDS, "getDistributedDay", {}),
    }
    out["fee_provider_balances"] = {}
    for sym, addr in RESERVES.items():
        dec = {"IUSDC": 6}.get(sym, 18)
        b = rpc_call(addr, "balanceOf", {"_owner": FEEPROV})
        out["fee_provider_balances"][sym] = hexint(b) / 10 ** dec if isinstance(b, str) else b
    return out

def paged(method, max_pages=120):
    out, idx = [], 0
    while idx < max_pages:
        r = rpc_call(LP, method, {"_index": hex(idx)})
        if not isinstance(r, list) or not r:
            break
        out.extend(r)
        if len(r) < 50:
            break
        idx += 1
    return out

def account_of(u):
    a = rpc_call(DP, "getUserAccountData", {"_user": u})
    return u, a

def enumerate_users():
    dep = paged("getDepositWallets")
    bor = paged("getBorrowWallets")
    users = sorted(set(dep) | set(bor))
    accts = {}
    with ThreadPoolExecutor(max_workers=24) as ex:
        futs = {ex.submit(account_of, u): u for u in users}
        done = 0
        for f in as_completed(futs):
            try:
                u, a = f.result()
                accts[u] = a
            except Exception as e:
                accts[futs[f]] = {"__error__": str(e)}
            done += 1
            if done % 250 == 0:
                print(f"  accounts {done}/{len(users)}", flush=True)
    return {"depositors": dep, "borrowers": bor}, accts

def log_scan():
    methods = {}
    newest = {}
    blocks = []
    for page in range(6):
        L = http(f"{TRACKER}/logs?address={LP}&limit=100&skip={page*100}")
        if not isinstance(L, list) or not L:
            break
        for l in L:
            m = l.get("method") or "?"
            methods[m] = methods.get(m, 0) + 1
            bn = l.get("block_number") or 0
            blocks.append(bn)
            if m not in newest or bn > newest[m]:
                newest[m] = bn
    return {"counts": methods, "newest_block_by_method": newest,
            "block_min": min(blocks) if blocks else None, "block_max": max(blocks) if blocks else None}

def main():
    t0 = time.time()
    print("[1/3] live state ...", flush=True)
    state = live_state()
    json.dump(state, open(f"{OUT}/live_state.json", "w"), indent=1, default=str)
    print("[2/3] user enumeration ...", flush=True)
    users, accts = enumerate_users()
    json.dump(users, open(f"{OUT}/users.json", "w"), indent=1)
    json.dump(accts, open(f"{OUT}/accounts.json", "w"), indent=1, default=str)
    print("[3/3] log scan ...", flush=True)
    logs = log_scan()
    json.dump(logs, open(f"{OUT}/logs_summary.json", "w"), indent=1)

    # summary
    below = 0
    total_col = 0
    total_bor = 0
    errs = 0
    worst = []
    for u, a in accts.items():
        if not isinstance(a, dict) or "__error__" in a:
            errs += 1
            continue
        if a.get("healthFactorBelowThreshold") is True:
            below += 1
        try:
            total_col += hexint(a.get("totalCollateralBalanceUSD"))
            total_bor += hexint(a.get("totalBorrowBalanceUSD"))
        except Exception:
            pass
        hf = a.get("healthFactor")
        if isinstance(hf, str):
            worst.append((hexint(hf), u))
    worst.sort()
    lines = [
        "# Omm (ICON) — CI heavy-scan summary",
        f"- last block: {state.get('last_block')}",
        f"- users: depositors={len(users['depositors'])} borrowers={len(users['borrowers'])} "
        f"unique={len(set(users['depositors'])|set(users['borrowers']))}",
        f"- accounts fetched: {len(accts)} (errors={errs})",
        f"- healthFactorBelowThreshold users: {below}",
        f"- aggregate collateral USD (contract oracle): {total_col/1e18:,.2f}",
        f"- aggregate borrow USD (contract oracle): {total_bor/1e18:,.2f}",
        f"- 10 worst health factors: {[ (h/1e18, u) for h,u in worst[:10] ]}",
        f"- liquidation enabled: {state.get('liquidation_enabled')}  admin: {state.get('lending_pool_admin')}",
        f"- reserves frozen: { {s: v.get('isFreezed') for s, v in state.get('reserves', {}).items()} }",
        f"- core balances: {state.get('core_balances')}  core ICX: {state.get('core_icx')}",
        f"- oracle: {state.get('oracle')}",
        f"- DEX marginal prices (bnUSD): {state.get('dex_prices_bnUSD')}",
        f"- staking: {state.get('staking')}",
        f"- rewards: {state.get('rewards')}",
        f"- feeProvider balances: {state.get('fee_provider_balances')}",
        f"- log methods (last ~600 logs): {logs.get('counts')}",
        f"- newest block per method: {logs.get('newest_block_by_method')}",
        f"- elapsed: {time.time()-t0:,.0f}s",
    ]
    open(f"{OUT}/SUMMARY.md", "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))

if __name__ == "__main__":
    main()
