#!/usr/bin/env python3
"""
C2-58 Zilliqa deep-dive — read-only evidence collector.

Collects and asserts, against Zilliqa 2 mainnet (chainId 32769) via the keyless
public RPC https://api.zilliqa.com:

  * live balances of the legacy SSNList staking implementation/proxy and the
    Z2 staking deposit proxy (+ escrow claim vault)
  * deposit-contract gating tests (version, reinitialize, withdraw, depositTopup)
  * Scilla-call precompile allowlist control tests (random vs allow-listed caller)
  * SSNList admin/paused state and the 2-of-5 multisig parameters
  * fork-schedule facts (legacy txn disable, escrow reroute, allowlist) with
    activation block timestamps

NO transactions are signed or sent. NO secrets / keyed URLs. Keyless endpoint only.

Usage: python3 collect_evidence.py [out.json]
Exit code 0 = all assertions passed; 1 = at least one assertion failed.
"""
import json
import sys
import time
import urllib.request
import urllib.error

RPC = "https://api.zilliqa.com"
PRICE_URL = "https://coins.llama.fi/prices/current/coingecko:zilliqa"
UA = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (read-only research)"}

# ---- addresses (mainnet, verified) -----------------------------------------
DEPOSIT_PROXY = "0x00000000005a494c4445504f53495450524f5859"   # Z2 staking deposit (EIP-1967)
DEPOSIT_IMPL_EXPECTED = "0x05dff05a33aca5d190f8f78a47aebaa002f55d31"
ESCROW_PROXY = "0x00000000005a494c31455343524f5750524f5859"    # Z2 claim vault (Z1->Z2 escrow)
SSNLIST_PROXY = "0x62a9d5d611cdcae8d78005f31635898330e06b93"    # legacy SSNListProxy v1.1
SSNLIST_IMPL = "0xa7c67d49c82c7dc1b73d231640b2e4d0661d37c1"     # legacy SSNList v1.1 (holds stake)
MULTISIG = "0x38c986f6252a32b1c0fa732784c1a94e9f42a394"         # SSNList admin (2-of-5)
VERIFIER = "0x412b55a0ebc1001f930aba8dc107022a3a2ba484"         # SSNList verifier EOA
SCILLA_CALL_PRE = "0x000000000000000000000000000000005a494c53"
SCILLA_STATE_READ_PRE = "0x000000000000000000000000000000005a494c92"
ALLOWLISTED_CALLER = "0x03A79429acc808e4261a68b0117aCD43Cb0FdBfa"  # in mainnet allowlist
RANDOM_CALLER = "0x1111111111111111111111111111111111111111"
IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"

# ---- selectors (keccak, computed offline) ----------------------------------
SEL = {
    "version()": "0x54fd4d50",
    "getTotalStake()": "0x7bc74225",
    "getFutureTotalStake()": "0xdef54646",
    "minimumStake()": "0xec5ffac2",
    "maximumStakers()": "0x8bbc9d11",
    "withdrawalPeriod()": "0xbca7093d",
    "blocksPerEpoch()": "0xf0682054",
    "currentEpoch()": "0x76671808",
    "getStakers()": "0x43352d61",
    "reinitialize()": "0x6c2eb350",
    "withdraw(bytes)": "0x0968f264",
    "depositTopup(bytes)": "0x218753e6",
    "unstake(bytes,uint256)": "0x80a07d2b",
    "setRewardAddress(bytes,address)": "0x550b0cbb",
}
CLAIM_SEL = "0xcf1c9461"  # claim(uint256[2],uint256[2][2],uint256[2],uint256[4])
# error selectors
ERR_UNAUTHORISED = "0xd7a2ae6a"          # deposit contract Unauthorised()
ERR_INVALID_INIT = "0xf92ee8a9"          # OZ InvalidInitialization()

report = {
    "finding": "C2-58",
    "chain": "zilliqa-2 (EVM, chainId 32769)",
    "rpc": RPC,
    "collected_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "reads": {},
    "checks": [],
}


def rpc(method, params, timeout=30):
    body = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
    req = urllib.request.Request(RPC, data=body, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


def eth_call(to, data, frm=None, value=None, gas="0x1c9c380"):
    obj = {"to": to, "data": data, "gas": gas}
    if frm:
        obj["from"] = frm
    if value:
        obj["value"] = value
    return rpc("eth_call", [obj, "latest"])


def check(name, ok, detail):
    report["checks"].append({"name": name, "pass": bool(ok), "detail": detail})
    print(("PASS " if ok else "FAIL ") + name + " :: " + str(detail)[:220])
    return ok


def abi_encode_words(*words):
    return "0x" + "".join(words)


def enc_u256(v):
    return "%064x" % int(v)


def enc_address(a):
    return enc_u256(int(a, 16))


def enc_string(s):
    b = s.encode()
    return enc_u256(len(b)) + b.hex().ljust((len(b) + 31) // 32 * 64, "0")


def scilla_call_input(target, transition, mode, extra_words=None):
    """abi.encode(address target, string transition, uint256 mode [, ...words])"""
    head = enc_address(target) + enc_u256(0x60 if not extra_words else 0x80 if len(extra_words) == 1 else 0xA0) + enc_u256(mode)
    if extra_words:
        head += "".join(extra_words)
    return "0x" + head + enc_string(transition)


def decode_bytes_array(hexstr):
    raw = bytes.fromhex(hexstr.removeprefix("0x"))
    off = int.from_bytes(raw[0:32], "big")
    n = int.from_bytes(raw[off:off + 32], "big")
    items = []
    base = off + 32
    for i in range(n):
        item_off = int.from_bytes(raw[base + i * 32: base + (i + 1) * 32], "big")
        ln = int.from_bytes(raw[base + item_off: base + item_off + 32], "big")
        items.append(raw[base + item_off + 32: base + item_off + 32 + ln])
    return items


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else None
    all_ok = True

    # ---------------- chain head ----------------
    bn = int(rpc("eth_blockNumber", [])["result"], 16)
    blk = rpc("eth_getBlockByNumber", [hex(bn), False])["result"]
    ts = int(blk["timestamp"], 16)
    report["reads"]["head"] = {"block": bn, "timestamp": ts,
                               "utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(ts))}
    print(f"head block {bn} @ {report['reads']['head']['utc']}")

    # ---------------- price ----------------
    try:
        with urllib.request.urlopen(PRICE_URL, timeout=20) as r:
            price = json.loads(r.read().decode())["coins"]["coingecko:zilliqa"]["price"]
    except Exception as e:  # noqa: BLE001
        price = None
        print("price fetch failed:", e)
    report["reads"]["zil_price_usd"] = price

    # ---------------- deposit contract ----------------
    dep = {}
    dep["balance_wei"] = int(rpc("eth_getBalance", [DEPOSIT_PROXY, "latest"])["result"], 16)
    dep["impl_slot"] = rpc("eth_getStorageAt", [DEPOSIT_PROXY, IMPL_SLOT, "latest"])["result"]
    dep["admin_slot"] = rpc("eth_getStorageAt", [DEPOSIT_PROXY, ADMIN_SLOT, "latest"])["result"]
    for name in ["version()", "getTotalStake()", "getFutureTotalStake()", "minimumStake()",
                 "maximumStakers()", "withdrawalPeriod()", "blocksPerEpoch()", "currentEpoch()"]:
        r = eth_call(DEPOSIT_PROXY, SEL[name])
        dep[name] = int(r["result"], 16) if "result" in r and r["result"] != "0x" else r
    stakers_res = eth_call(DEPOSIT_PROXY, SEL["getStakers()"])
    keys = decode_bytes_array(stakers_res["result"]) if "result" in stakers_res else []
    dep["staker_count"] = len(keys)
    dep["first_bls_pubkey"] = keys[0].hex() if keys else None
    dep["balance_zil"] = dep["balance_wei"] / 1e18
    dep["balance_usd"] = dep["balance_zil"] * price if price else None
    dep["total_stake_zil"] = dep["getTotalStake()"] / 1e18
    report["reads"]["deposit_contract"] = dep

    all_ok &= check("deposit: impl slot is deposit v9 impl", dep["impl_slot"].endswith(DEPOSIT_IMPL_EXPECTED[2:]), dep["impl_slot"])
    all_ok &= check("deposit: EIP-1967 admin slot is zero (no admin fn)", int(dep["admin_slot"], 16) == 0, dep["admin_slot"])
    all_ok &= check("deposit: version()==9 (initialized, reinit guard armed)", dep["version()"] == 9, dep["version()"])
    all_ok &= check("deposit: total stake <= balance (funds == stakes)", dep["getTotalStake()"] <= dep["balance_wei"], f"total={dep['total_stake_zil']:.2f} bal={dep['balance_zil']:.2f}")
    all_ok &= check("deposit: holds > 3.5B ZIL", dep["balance_zil"] > 3.5e9, f"{dep['balance_zil']:,.2f} ZIL")

    # deposit gating tests
    r = eth_call(DEPOSIT_PROXY, SEL["reinitialize()"], frm=RANDOM_CALLER)
    all_ok &= check("deposit: reinitialize() from random reverts InvalidInitialization",
                    r.get("error", {}).get("data") == ERR_INVALID_INIT, r)
    if dep["first_bls_pubkey"]:
        key = "0x" + dep["first_bls_pubkey"]
        keydata = key[2:].ljust(128, "0")  # 48 bytes -> 2 ABI words
        # withdraw(bytes)
        data = SEL["withdraw(bytes)"] + enc_u256(0x20) + enc_u256(48) + keydata
        r = eth_call(DEPOSIT_PROXY, data, frm=RANDOM_CALLER)
        all_ok &= check("deposit: withdraw(real bls key) from random reverts Unauthorised",
                        r.get("error", {}).get("data") == ERR_UNAUTHORISED, r)
        # depositTopup(bytes)
        data = SEL["depositTopup(bytes)"] + enc_u256(0x20) + enc_u256(48) + keydata
        r = eth_call(DEPOSIT_PROXY, data, frm=RANDOM_CALLER, value="0x1")
        all_ok &= check("deposit: depositTopup(real key) from random reverts Unauthorised",
                        r.get("error", {}).get("data") == ERR_UNAUTHORISED, r)
        # unstake(bytes,uint256)
        data = SEL["unstake(bytes,uint256)"] + enc_u256(0x40) + enc_u256(1) + enc_u256(48) + keydata
        r = eth_call(DEPOSIT_PROXY, data, frm=RANDOM_CALLER)
        all_ok &= check("deposit: unstake(real key, 1) from random reverts Unauthorised",
                        r.get("error", {}).get("data") == ERR_UNAUTHORISED, r)
        # setRewardAddress(bytes,address)
        data = SEL["setRewardAddress(bytes,address)"] + enc_u256(0x40) + enc_address(RANDOM_CALLER) + enc_u256(48) + keydata
        r = eth_call(DEPOSIT_PROXY, data, frm=RANDOM_CALLER)
        all_ok &= check("deposit: setRewardAddress(real key) from random reverts Unauthorised",
                        r.get("error", {}).get("data") == ERR_UNAUTHORISED, r)

    # ---------------- escrow claim vault ----------------
    esc = {}
    esc["balance_wei"] = int(rpc("eth_getBalance", [ESCROW_PROXY, "latest"])["result"], 16)
    esc["impl_slot"] = rpc("eth_getStorageAt", [ESCROW_PROXY, IMPL_SLOT, "latest"])["result"]
    esc["balance_zil"] = esc["balance_wei"] / 1e18
    esc["balance_usd"] = esc["balance_zil"] * price if price else None
    # claim(garbage proof) — expect revert (No balance lodged / Zk-proof failed)
    garbage = CLAIM_SEL + enc_u256(1) + enc_u256(2) \
        + enc_u256(1) + enc_u256(2) + enc_u256(3) + enc_u256(4) \
        + enc_u256(5) + enc_u256(6) \
        + enc_u256(1) + enc_u256(2) + enc_u256(32769) + enc_u256(4)
    r = eth_call(ESCROW_PROXY, garbage, frm=RANDOM_CALLER)
    esc["claim_garbage_result"] = r
    report["reads"]["escrow_claim_vault"] = esc
    all_ok &= check("escrow: claim() with garbage proof reverts (proof-gated)", "error" in r, r)

    # ---------------- legacy SSNList staking ----------------
    ssn = {}
    ssn["proxy_balance_wei"] = int(rpc("eth_getBalance", [SSNLIST_PROXY, "latest"])["result"], 16)
    ssn["impl_balance_wei"] = int(rpc("eth_getBalance", [SSNLIST_IMPL, "latest"])["result"], 16)
    ssn["impl_balance_zil"] = ssn["impl_balance_wei"] / 1e18
    ssn["impl_balance_usd"] = ssn["impl_balance_zil"] * price if price else None
    ssn["legacy_get_balance"] = rpc("GetBalance", [SSNLIST_IMPL])
    # state-read precompile (works for some fields)
    for field in ["contractadmin", "implementation", "admin", "minstake"]:
        target = SSNLIST_IMPL if field in ("contractadmin", "minstake") else SSNLIST_PROXY
        r = eth_call(SCILLA_STATE_READ_PRE, "0x" + enc_address(target) + enc_u256(0x40) + enc_string(field),
                     frm=RANDOM_CALLER)
        ssn[f"state_read_{field}"] = r
    # substates
    for f in ["paused", "verifier"]:
        ssn[f"substate_{f}"] = rpc("GetSmartContractSubState", [SSNLIST_IMPL, f, []])
    ssn["multisig_init"] = rpc("GetSmartContractInit", [MULTISIG])
    report["reads"]["legacy_ssnlist"] = ssn

    admin_hex = None
    sr = ssn.get("state_read_contractadmin", {})
    if "result" in sr and sr["result"] != "0x":
        admin_hex = "0x" + sr["result"][-40:]
    all_ok &= check("SSNList: impl holds > 1.3B ZIL", ssn["impl_balance_zil"] > 1.3e9, f"{ssn['impl_balance_zil']:,.2f} ZIL")
    all_ok &= check("SSNList: contractadmin == 2-of-5 multisig", admin_hex == MULTISIG, admin_hex)
    try:
        init = ssn["multisig_init"]["result"]
        owners = next(x["value"] for x in init if x["vname"] == "owners_list")
        req = int(next(x["value"] for x in init if x["vname"] == "required_signatures"))
        all_ok &= check("multisig: 5 owners / required_signatures=2", len(owners) == 5 and req == 2, f"owners={len(owners)} req={req}")
    except Exception as e:  # noqa: BLE001
        all_ok &= check("multisig: init parsed", False, str(e))
    try:
        paused_obj = ssn["substate_paused"]["result"]["paused"]
        paused = paused_obj.get("constructor") if isinstance(paused_obj, dict) else paused_obj
        all_ok &= check("SSNList: paused==False (contract live but unreachable)", paused == "False", paused)
    except Exception as e:  # noqa: BLE001
        all_ok &= check("SSNList: paused substate parsed", False, str(e))

    # ---------------- scilla_call precompile allowlist ----------------
    pre = {}
    # random caller -> proxy AddFunds (expect revert due to allowlist)
    data = scilla_call_input(SSNLIST_PROXY, "AddFunds", 1)
    pre["random_addfunds"] = eth_call(SCILLA_CALL_PRE, data, frm=RANDOM_CALLER)
    # allow-listed caller -> proxy AddFunds (expect 0x)
    pre["allowed_addfunds"] = eth_call(SCILLA_CALL_PRE, data, frm=ALLOWLISTED_CALLER)
    # allow-listed caller -> impl drain_contract_balance(initiator=admin) (expect revert validate_proxy)
    data2 = scilla_call_input(SSNLIST_IMPL, "drain_contract_balance", 1, [enc_address(MULTISIG)])
    pre["allowed_drain_impl"] = eth_call(SCILLA_CALL_PRE, data2, frm=ALLOWLISTED_CALLER)
    report["reads"]["precompile_tests"] = pre
    all_ok &= check("precompile: random caller blocked (allowlist)", "error" in pre["random_addfunds"], pre["random_addfunds"].get("error", {}).get("message"))
    all_ok &= check("precompile: allow-listed caller executes Scilla call",
                    pre["allowed_addfunds"].get("result") == "0x", pre["allowed_addfunds"])
    all_ok &= check("precompile: allow-listed caller cannot drain SSNList impl (validate_proxy)",
                    "error" in pre["allowed_drain_impl"], pre["allowed_drain_impl"].get("error", {}).get("message"))

    # ---------------- fork schedule facts (with live timestamps) ----------------
    forks = {
        "allow_scilla_call_precompile_to_be_called_from_addresses": 29108584,
        "disable_zilliqa_txn_execution": 31759109,
        "blocked_recipients_start_height": 34844968,
        "deploy_escrow_contract_v1 + zil_transfers_only_to_escrow": 36383379,
        "blocked_recipients_start_height_v3": 37410000,
    }
    fork_info = {}
    for k, h in forks.items():
        b = rpc("eth_getBlockByNumber", [hex(h), False]).get("result")
        if b:
            t = int(b["timestamp"], 16)
            fork_info[k] = {"height": h, "utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(t))}
    fork_info["disable_permanently_scilla_precompiles (future)"] = {"height": 99999999}
    report["reads"]["fork_schedule"] = fork_info
    all_ok &= check("forks: legacy txn disable active (block now > 31,759,109)", bn > 31759109, f"{bn} > 31759109")
    all_ok &= check("forks: escrow-only reroute active (block now > 36,383,379)", bn > 36383379, f"{bn} > 36383379")
    all_ok &= check("forks: scilla precompiles not permanently disabled yet (block now < 99,999,999)", bn < 99999999, bn)

    # ---------------- totals ----------------
    tot_zil = dep["balance_zil"] + ssn["impl_balance_zil"] + esc["balance_zil"]
    report["summary"] = {
        "legacy_ssnlist_zil": ssn["impl_balance_zil"], "legacy_ssnlist_usd": ssn["impl_balance_usd"],
        "z2_deposit_zil": dep["balance_zil"], "z2_deposit_usd": dep["balance_usd"],
        "escrow_zil": esc["balance_zil"], "escrow_usd": esc["balance_usd"],
        "total_zil": tot_zil, "total_usd": tot_zil * price if price else None,
        "eu_extractable_usd": 0.0,
    }
    report["all_checks_passed"] = all_ok
    print(json.dumps(report["summary"], indent=1))

    if out_path:
        with open(out_path, "w") as f:
            json.dump(report, f, indent=1)
        print("wrote", out_path)
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
