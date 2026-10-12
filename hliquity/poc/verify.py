#!/usr/bin/env python3
"""
HLiquity (Hedera mainnet, chain 295) — live-state census + gate verification.
READ-ONLY: every call below is an eth_call simulation. No transaction is signed or sent.
Public endpoints only (no API keys, no secrets).

Checks:
  1. live trove/pool/price census at a pinned block
  2. oracle exploit A/B: Bonzo-style zero-signature update rejected NOW, accepted at pre-fix block
  3. Supra S-Value storage write guard (restrictedSetSupraStorage) rejects external callers
  4. HCHF mint/burn guards
  5. setAddresses admin guards on 4 core contracts
  6. redemption simulation (closes the lowest-ICR trove) + no-arbitrage accounting
  7. liquidation attempt on the lowest-ICR trove must revert (no liquidatable troves)

Writes ci-out/state.json and ci-out/verification.json. Exit code 1 if any hard check fails.
"""
import json
import os
import sys
import time
import urllib.request
import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.abspath(os.path.join(HERE, "..", "ci-out"))
os.makedirs(OUTDIR, exist_ok=True)

RPC_URLS = ["https://mainnet.hashio.io/api", "https://295.rpc.thirdweb.com"]
MIRROR = "https://mainnet-public.mirrornode.hedera.com"
UA = "Mozilla/5.0 (compatible; zombie-research/1.0)"

# ---------------- addresses (Hedera EVM) ----------------
TM    = "0x00000000000000000000000000000000005c9f66"  # TroveManager 0.0.6070118
BO    = "0x00000000000000000000000000000000005c9F4e"  # BorrowerOperations 0.0.6070094
SP    = "0x00000000000000000000000000000000005c9F5c"  # StabilityPool 0.0.6070108
AP    = "0x00000000000000000000000000000000005c9f0b"  # ActivePool 0.0.6070027
DP    = "0x00000000000000000000000000000000005c9F19"  # DefaultPool 0.0.6070041
CSP   = "0x00000000000000000000000000000000005c9f0e"  # CollSurplusPool 0.0.6070030
CI    = "0x00000000000000000000000000000000005c9f14"  # CommunityIssuance 0.0.6070036
PF    = "0x00000000000000000000000000000000005c9F42"  # PriceFeed 0.0.6070082
SORT  = "0x00000000000000000000000000000000005c9F49"  # SortedTroves 0.0.6070089
STK   = "0x00000000000000000000000000000000005c9f30"  # HLQTStaking 0.0.6070064
HCHF  = "0x00000000000000000000000000000000005c9f6a"  # HCHF controller contract 0.0.6070122
HLQTF = "0x00000000000000000000000000000000005c9f6f"  # HLQT controller contract 0.0.6070127
HLQT  = "0x00000000000000000000000000000000005c9f70"  # HLQT HTS token 0.0.6070128
PYTHC = "0x00000000000000000000000000000000005c9f80"  # PythCaller 0.0.6070144
SUPRAC= "0x00000000000000000000000000000000005c9f83"  # SupraCaller 0.0.6070147
SUPRA_STORAGE = "0xd02cc7a670047b6b012556a88e275c685d25e0c9"  # Supra S-Value storage 0.0.4322850
SUPRA_PULL = "0x41ab2059baa4b73e9a3f55d30dff27179e0ea181"     # Supra pull oracle 0.0.4323024
EXISTING_EOA = "0x00000000000000000000000000000000003e76cd"  # 0.0.4093645 (real account)
WHALE = "0xfce55d8b693d87260eb66fc3dffbba9dcfc3e51b"        # 0.0.10478184 (10,517 HCHF)
PRE_FIX_BLOCK = "0x5cfcda5"  # block just before the 2026-07-11 verifier patch

SEL = {
    "getTroveOwnersCount()": "0x49eefeee",
    "getTroveFromTroveOwnersArray(uint256)": "0xd9a72444",
    "getTroveDebt(address)": "0xd66a2553",
    "getTroveColl(address)": "0x480cd578",
    "getTroveStatus(address)": "0x21e37801",
    "getCurrentICR(address,uint256)": "0xd293c710",
    "getNominalICR(address)": "0xb0d8e181",
    "getEntireSystemColl()": "0x887105d3",
    "getEntireSystemDebt()": "0x795d26c3",
    "getTCR(uint256)": "0xb82f263d",
    "checkRecoveryMode(uint256)": "0x4e443d9e",
    "baseRate()": "0x1f68f20a",
    "getRedemptionRate()": "0x2b11551a",
    "lastFeeOperationTime()": "0xd380a37c",
    "MCR()": "0x794e5724",
    "CCR()": "0x5733d58f",
    "fetchPrice()": "0x0fdb11cf",
    "lastGoodPrice()": "0x0490be83",
    "status()": "0x200d2ed2",
    "getTotalHCHFDeposits()": "0x1985480d",
    "getETH()": "0x14f6c3be",
    "getHCHFDebt()": "0x6690df1f",
    "getFirst()": "0x1e223143",
    "getLast()": "0x4d622831",
    "getPrev(address)": "0xb72703ac",
    "getNext(address)": "0x765e0159",
    "liquidate(address)": "0x2f865568",
    "redeemCollateral(uint256,address,address,address,uint256,uint256,uint256)": "0xbcd37526",
    "setAddresses2": "0x90107afe",
    "setAddresses9": "0x66272044",
    "setAddresses8": "0xd733cfd0",
    "setAddresses5": "0x5dd68acd",
    "mint(address,uint256)": "0x40c10f19",
    "burn(address,uint256)": "0x9dc29fac",
    "balanceOf(address)": "0x70a08231",
    "totalSupply()": "0x18160ddd",
    "decimals()": "0x313ce567",
    "restrictedSetSupraStorage(uint256,bytes32)": "0xbed9d186",
    "getSupraCurrentValue(uint256,uint256)": "0x3a1ecf4c",
    "getPythCurrentValue(bytes32,bytes32)": "0x3ad26a12",
    "owner()": "0x8da5cb5b",
    "totalHLQTStaked()": "0x89b33c13",
}

EXPLOIT_TX_INPUT = None  # loaded from poc/exploit_tx_input.hex

HCHF_GAS_COMP = 20 * 10**8
DECIMAL_PRECISION = 10**8
TIMEOUT = 14400  # PriceFeed.TIMEOUT (4h)


def _post(url, payload, timeout=60, tries=3):
    data = json.dumps(payload).encode()
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, data=data,
                                         headers={"Content-Type": "application/json", "User-Agent": UA})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read())
        except Exception as e:
            last = e
            time.sleep(1.5 * (i + 1))
    raise RuntimeError(f"rpc failed: {last}")


def rpc(method, params, url=None):
    last = None
    for u in ([url] if url else RPC_URLS):
        try:
            resp = _post(u, {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}, tries=2)
            if "error" in resp:
                err = resp["error"]
                msg = str(err.get("message", ""))
                if err.get("code") in (3, -32000) and ("revert" in msg.lower() or err.get("data")):
                    return {"revert": True, "error": err}
                last = msg
                continue
            return {"result": resp.get("result"), "raw": resp}
        except Exception as e:
            last = e
    return {"error": str(last)}


def eth_call(to, data, frm=None, block="latest"):
    tx = {"to": to, "data": data}
    if frm:
        tx["from"] = frm
    r = rpc("eth_call", [tx, block])
    if "result" in r:
        return {"ok": True, "result": r["result"]}
    if "revert" in r:
        return {"ok": False, "revert": True, "data": r["error"].get("data"), "message": r["error"].get("message", "")[:160]}
    return {"ok": False, "error": r.get("error")}


def word(v):
    return hex(int(v))[2:].rjust(64, "0")


def addr_word(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def as_int(res):
    if res.get("ok") and isinstance(res.get("result"), str) and res["result"] != "0x":
        return int(res["result"], 16)
    return None


def as_addr(res):
    if res.get("ok") and isinstance(res.get("result"), str) and len(res["result"]) >= 42:
        return "0x" + res["result"][-40:]
    return None


def mirror_get(path):
    req = urllib.request.Request(MIRROR + path, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.loads(r.read())


def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.loads(r.read())


def main():
    checks = []
    state = {}
    t0 = time.time()

    bn = rpc("eth_blockNumber", [])
    latest_block = int(bn["result"], 16) if bn.get("result") else None
    print(f"[i] latest block: {latest_block}")

    # ---------- 1. census ----------
    price = as_int(eth_call(PF, SEL["fetchPrice()"]))
    last_good = as_int(eth_call(PF, SEL["lastGoodPrice()"]))
    status = as_int(eth_call(PF, SEL["status()"]))
    pyth = eth_call(PYTHC, SEL["getPythCurrentValue(bytes32,bytes32)"] +
                    "3728e591097635310e6341af53db8b7ee42da9b3a8d918f9463ce9cca886dfbd"
                    "0b1e3297e69f162877b577b0d6a47a0d63b2392bc8499e6540da4187a63e28f8")
    supra = eth_call(SUPRAC, SEL["getSupraCurrentValue(uint256,uint256)"] + word(75) + word(5012))
    now = int(time.time())

    def triple(res):
        if res.get("ok") and res.get("result") and len(res["result"]) >= 2 + 64 * 3:
            h = res["result"][2:]
            return (int(h[0:64], 16), int(h[64:128], 16), int(h[128:192], 16))
        return None

    pyth_t = triple(pyth)
    supra_t = triple(supra)

    n = as_int(eth_call(TM, SEL["getTroveOwnersCount()"]))
    troves = []
    for i in range(n or 0):
        owner = as_addr(eth_call(TM, SEL["getTroveFromTroveOwnersArray(uint256)"] + word(i)))
        debt = as_int(eth_call(TM, SEL["getTroveDebt(address)"] + addr_word(owner)))
        coll = as_int(eth_call(TM, SEL["getTroveColl(address)"] + addr_word(owner)))
        icr = as_int(eth_call(TM, SEL["getCurrentICR(address,uint256)"] + addr_word(owner) + word(price))) if price else None
        nicr = as_int(eth_call(TM, SEL["getNominalICR(address)"] + addr_word(owner)))
        troves.append({"owner": owner, "debt_1e8": debt, "coll_tinybar": coll, "icr_1e8": icr, "nicr_1e20": nicr})

    mcr = as_int(eth_call(TM, SEL["MCR()"]))
    ccr = as_int(eth_call(TM, SEL["CCR()"]))
    tcr = as_int(eth_call(TM, SEL["getTCR(uint256)"] + word(price))) if price else None
    recovery = as_int(eth_call(TM, SEL["checkRecoveryMode(uint256)"] + word(price))) if price else None
    entire_coll = as_int(eth_call(TM, SEL["getEntireSystemColl()"]))
    entire_debt = as_int(eth_call(TM, SEL["getEntireSystemDebt()"]))
    base_rate = as_int(eth_call(TM, SEL["baseRate()"]))
    red_rate = as_int(eth_call(TM, SEL["getRedemptionRate()"]))
    sp_dep = as_int(eth_call(SP, SEL["getTotalHCHFDeposits()"]))
    sp_eth = as_int(eth_call(SP, SEL["getETH()"]))
    ap_eth = as_int(eth_call(AP, SEL["getETH()"]))
    ap_debt = as_int(eth_call(AP, SEL["getHCHFDebt()"]))
    hchf_supply = as_int(eth_call(HCHF, SEL["totalSupply()"]))
    hchf_dec = as_int(eth_call(HCHF, SEL["decimals()"]))
    hlqt_supply = as_int(eth_call(HLQT, SEL["totalSupply()"]))
    ci_hlqt = as_int(eth_call(HLQT, SEL["balanceOf(address)"] + addr_word(CI)))
    stk_hlqt = as_int(eth_call(STK, SEL["totalHLQTStaked()"]))
    owners_zero = {name: as_addr(eth_call(a, SEL["owner()"]))
                   for name, a in [("TM", TM), ("BO", BO), ("SP", SP), ("AP", AP), ("PF", PF), ("STK", STK), ("CI", CI)]}

    bal = {}
    for name, a in [("ActivePool", AP), ("StabilityPool", SP), ("Staking", STK), ("CollSurplusPool", CSP)]:
        r = rpc("eth_getBalance", [a, "latest"])
        bal[name] = int(r["result"], 16) // 10**10 if r.get("result") else None  # wei-style -> tinybar (18-8)

    state = {
        "latest_block": latest_block,
        "chain_id": 295,
        "price_feed": {"fetchPrice_1e8": price, "lastGoodPrice_1e8": last_good, "status": status,
                       "status_name": {0: "pythWorking", 1: "usingSupraPythUntrusted", 2: "bothOraclesUntrusted",
                                       3: "usingSupraPythFrozen", 4: "usingPythSupraUntrusted"}.get(status),
                       "pyth": pyth_t, "supra": supra_t, "now": now,
                       "pyth_age_sec": (now - pyth_t[2]) if pyth_t else None,
                       "supra_age_sec": (now - supra_t[2]) if supra_t else None},
        "troves": troves,
        "system": {"MCR_1e8": mcr, "CCR_1e8": ccr, "TCR_1e8": tcr, "recoveryMode": recovery,
                   "entireColl_tinybar": entire_coll, "entireDebt_1e8": entire_debt,
                   "baseRate": base_rate, "redemptionRate": red_rate},
        "pools": {"SP_totalHCHFDeposits_1e8": sp_dep, "SP_getETH_tinybar": sp_eth,
                  "AP_getETH_tinybar": ap_eth, "AP_getHCHFDebt_1e8": ap_debt},
        "tokens": {"HCHF_totalSupply_1e8": hchf_supply, "HCHF_decimals": hchf_dec,
                   "HLQT_totalSupply_1e8": hlqt_supply, "CommunityIssuance_HLQT": ci_hlqt,
                   "Staking_totalHLQTStaked": stk_hlqt},
        "contract_hbar_tinybar": bal,
        "owners": owners_zero,
    }

    def add_check(name, ok, expected, actual, hard=True):
        checks.append({"check": name, "pass": bool(ok), "expected": expected, "actual": actual, "hard": hard})

    add_check("trove_count_11", n == 11, 11, n)
    min_icr = min((t["icr_1e8"] for t in troves if t["icr_1e8"]), default=None)
    add_check("no_liquidatable_troves", min_icr is not None and mcr is not None and min_icr > mcr,
              f"> MCR ({mcr})", f"min ICR {min_icr}")
    add_check("not_recovery_mode", recovery == 0, 0, recovery)
    add_check("pyth_frozen", pyth_t is not None and (now - pyth_t[2]) > TIMEOUT, f"> {TIMEOUT}s stale",
              f"age {now - pyth_t[2]}s" if pyth_t else None)
    add_check("supra_fresh", supra_t is not None and 0 <= (now - supra_t[2]) <= TIMEOUT + 3600, f"<= ~{TIMEOUT}s",
              f"age {now - supra_t[2]}s" if supra_t else None)
    add_check("status_using_supra_pyth_frozen", status == 3, 3, status)

    # ---------- 2. oracle exploit A/B ----------
    with open(os.path.join(HERE, "exploit_tx_input.hex")) as f:
        exploit = f.read().strip()
    now_res = eth_call(SUPRA_PULL, exploit)
    pre_res = eth_call(SUPRA_PULL, exploit, block=PRE_FIX_BLOCK)
    add_check("oracle_exploit_rejected_now", (not now_res.get("ok")) and (now_res.get("data") or "").startswith("0x40ef6502"),
              "revert 0x40ef6502 DataNotVerified()",
              {"ok": now_res.get("ok"), "data": now_res.get("data"), "msg": now_res.get("message")})
    add_check("oracle_exploit_accepted_pre_fix", pre_res.get("ok") is True,
              f"success at block {PRE_FIX_BLOCK}", {"ok": pre_res.get("ok"), "result_head": (pre_res.get("result") or "")[:66]})

    # ---------- 3. storage write guard ----------
    wi = "0xbed9d186" + word(75) + "00" * 32
    g = eth_call(SUPRA_STORAGE, wi, frm=EXISTING_EOA)
    add_check("supra_storage_write_guarded", (not g.get("ok")) and (g.get("data") or "").startswith("0x1a1a6da9"),
              "revert 0x1a1a6da9 UnauthorisedAccess()",
              {"ok": g.get("ok"), "data": g.get("data"), "msg": g.get("message")})

    # ---------- 4. token guards ----------
    m = eth_call(HCHF, SEL["mint(address,uint256)"] + addr_word(EXISTING_EOA) + word(10**8), frm=EXISTING_EOA)
    add_check("hchf_mint_guarded", not m.get("ok") and "BorrowerOperations" in (m.get("message") or ""),
              "revert (caller is not BorrowerOperations)", {"ok": m.get("ok"), "msg": m.get("message")})
    b = eth_call(HCHF, SEL["burn(address,uint256)"] + addr_word(EXISTING_EOA) + word(1), frm=EXISTING_EOA)
    add_check("hchf_burn_guarded", not b.get("ok"), "revert (not BO/TM/SP)", {"ok": b.get("ok"), "msg": b.get("message")})

    # ---------- 5. setAddresses guards ----------
    dummy = addr_word(EXISTING_EOA)
    sa_tests = [
        ("pricefeed_setAddresses", PF, SEL["setAddresses2"] + dummy + dummy, 2),
        ("trovermanager_setAddresses", TM, SEL["setAddresses9"] + dummy * 9, 9),
        ("borrowerops_setAddresses", BO, SEL["setAddresses8"] + dummy * 8, 8),
        ("stabilitypool_setAddresses", SP, SEL["setAddresses5"] + dummy * 5, 5),
    ]
    for name, to, data, _k in sa_tests:
        r = eth_call(to, data, frm=EXISTING_EOA)
        add_check(name + "_guarded", not r.get("ok"), "revert (not owner)", {"ok": r.get("ok"), "msg": r.get("message")})

    # ---------- 6. redemption simulation ----------
    last = as_addr(eth_call(SORT, SEL["getLast()"]))
    d_last = as_int(eth_call(TM, SEL["getTroveDebt(address)"] + addr_word(last)))
    amount = (d_last - HCHF_GAS_COMP) if d_last else None
    red = None
    if amount and amount > 0:
        red_data = (SEL["redeemCollateral(uint256,address,address,address,uint256,uint256,uint256)"]
                    + word(amount) + addr_word(last) + addr_word("0x0000000000000000000000000000000000000000")
                    + addr_word("0x0000000000000000000000000000000000000000") + word(0) + word(0) + word(10**8))
        r = eth_call(TM, red_data, frm=WHALE)
        eth_lot = amount * DECIMAL_PRECISION // price if price else 0
        fee = (red_rate or 0) * eth_lot // DECIMAL_PRECISION
        net = eth_lot - fee
        red = {"ok": r.get("ok"), "msg": r.get("message"), "trove": last, "amount_1e8": amount,
               "expected_eth_lot_tinybar": eth_lot, "expected_fee_tinybar": fee, "expected_net_tinybar": net,
               "net_hbar_per_hchf": (net / amount) if amount else None}
        add_check("redemption_simulation_succeeds", r.get("ok") is True, "eth_call success (no revert)",
                  {"ok": r.get("ok"), "msg": r.get("message")})

    # market prices (public APIs; optional)
    mkt = {}
    try:
        mkt["hbar_usd"] = fetch_json("https://api.saucerswap.finance/tokens")
        mkt["hbar_usd"] = next(t["priceUsd"] for t in mkt["hbar_usd"] if t.get("id") == "0.0.1456986")
    except Exception as e:
        mkt["hbar_usd"] = None
    try:
        ss = fetch_json("https://api.saucerswap.finance/tokens")
        mkt["hchf_usd"] = next(t["priceUsd"] for t in ss if t.get("id") == "0.0.6070123")
    except Exception as e:
        mkt["hchf_usd"] = None
    try:
        dl = fetch_json("https://coins.llama.fi/prices/current/hedera:0.0.6070123")
        mkt["hchf_usd_defillama"] = dl["coins"]["hedera:0.0.6070123"]["price"]
    except Exception:
        mkt["hchf_usd_defillama"] = None

    if red and red.get("net_hbar_per_hchf") and mkt.get("hbar_usd") and mkt.get("hchf_usd"):
        value_usd = red["net_hbar_per_hchf"] * mkt["hbar_usd"]
        arb_bps = (value_usd / mkt["hchf_usd"] - 1) * 10000
        red["redeem_value_usd_per_hchf"] = value_usd
        red["arb_profit_bps"] = arb_bps
        add_check("redemption_not_profitable", arb_bps <= 0, "<= 0 bps vs market", f"{arb_bps:.1f} bps")

    # ---------- 7. liquidation attempt ----------
    liq = eth_call(TM, SEL["liquidate(address)"] + addr_word(last), frm=EXISTING_EOA)
    add_check("liquidation_reverts", not liq.get("ok"), "revert (ICR > MCR)",
              {"ok": liq.get("ok"), "msg": liq.get("message")})

    result = {
        "finding": "hliquity (L2 Phase-2 deep dive)",
        "generated_utc": datetime.datetime.utcnow().isoformat() + "Z",
        "latest_block": latest_block,
        "state": state,
        "market": mkt,
        "redemption_sim": red,
        "checks": checks,
        "passed": sum(1 for c in checks if c["pass"]),
        "total": len(checks),
        "hard_failures": [c["check"] for c in checks if c["hard"] and not c["pass"]],
        "runtime_sec": round(time.time() - t0, 1),
    }
    with open(os.path.join(OUTDIR, "state.json"), "w") as f:
        json.dump(state, f, indent=1)
    with open(os.path.join(OUTDIR, "verification.json"), "w") as f:
        json.dump(result, f, indent=1)

    for c in checks:
        print(("PASS " if c["pass"] else "FAIL ") + c["check"] + f"  [{c['actual']}]")
    print(f"\n{result['passed']}/{result['total']} checks passed at block {latest_block}")
    return 1 if result["hard_failures"] else 0


if __name__ == "__main__":
    sys.exit(main())
