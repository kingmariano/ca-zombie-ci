#!/usr/bin/env python3
"""H2-05 EOS re-verification harness (read-only; public endpoints only; no secrets).

Re-verifies, on every CI run:
  A. WhaleEx / whaleextrust live state (balances, permissions, code hash, issuer)
  B. DMD eosdmdpool11/12/13 live state (balances, permissions, stakepool totals)
  C. Static authorization facts on the pinned WASM binaries (wabt decompile):
       - whaleextrust: only action = clearextsym; its handler requires auth of the loaded account
       - tokens.wal: transfer handler calls require_auth(from)
       - DMD: exit/claim handlers require_auth(from); init/harvest/harvest2 require_auth(eosdmdworker)
Outputs ci-out/eos-misc-verify.json and exits non-zero on any failed assertion.
"""
import json
import os
import re
import subprocess
import sys
import urllib.request
import base64
import hashlib

EOS = "https://eos.greymass.com"
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "ci-out")
WABT_VERSION = "1.0.36"
WABT_URL = (
    "https://github.com/WebAssembly/wabt/releases/download/%s/wabt-%s-ubuntu-20.04.tar.gz"
    % (WABT_VERSION, WABT_VERSION)
)

results = []


def check(name, ok, detail):
    results.append({"check": name, "ok": bool(ok), "detail": detail})
    print(("PASS " if ok else "FAIL ") + name + " :: " + str(detail)[:300])


def post(path, payload):
    req = urllib.request.Request(
        EOS + path,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (research)"},
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())


def get_wabt():
    base = "/tmp/wabt-%s" % WABT_VERSION
    exe = os.path.join(base, "bin", "wasm2wat")
    if os.path.exists(exe):
        return base
    os.makedirs(base, exist_ok=True)
    tgz = base + ".tar.gz"
    urllib.request.urlretrieve(WABT_URL, tgz)
    subprocess.run(["tar", "xzf", tgz, "-C", "/tmp"], check=True)
    return base


def fetch_wasm(account):
    raw = post("/v1/chain/get_raw_code_and_abi", {"account_name": account})
    return base64.b64decode(raw["wasm"])


def wat(wasm_bytes, path, wabt_dir):
    with open(path, "wb") as f:
        f.write(wasm_bytes)
    out = path + ".wat"
    subprocess.run([os.path.join(wabt_dir, "bin", "wasm2wat"), path, "-o", out], check=True)
    return open(out).read()


def dcmp(wasm_bytes, path, wabt_dir):
    with open(path, "wb") as f:
        f.write(wasm_bytes)
    out = path + ".dcmp"
    subprocess.run([os.path.join(wabt_dir, "bin", "wasm-decompile"), path, "-o", out], check=True)
    return open(out).read()


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    info = post("/v1/chain/get_info", {})
    head = info["head_block_num"]
    print("EOS head block:", head, info["head_block_time"])

    # ---------- A. WhaleEx ----------
    usdt = post("/v1/chain/get_currency_balance",
                {"code": "tokens.wal", "account": "whaleextrust", "symbol": "USDT"})
    btc = post("/v1/chain/get_currency_balance",
               {"code": "tokens.wal", "account": "whaleextrust", "symbol": "BTC"})
    check("whaleex.usdt_balance", usdt == ["2426381.86411885 USDT"], usdt)
    check("whaleex.btc_balance", btc == ["14.80068211 BTC"], btc)

    acc = post("/v1/chain/get_account", {"account_name": "whaleextrust"})
    perms = {p["perm_name"]: p["required_auth"] for p in acc["permissions"]}
    active = perms.get("active", {})
    owner = perms.get("owner", {})
    keys_a = [k["key"] for k in active.get("keys", [])]
    keys_o = [k["key"] for k in owner.get("keys", [])]
    check("whaleex.owner_active_single_key",
          keys_a == keys_o and len(keys_a) == 1 and not active.get("accounts"),
          {"active_keys": keys_a, "owner_keys": keys_o})
    check("whaleex.active_has_no_eosio_code",
          not active.get("accounts"), active.get("accounts"))

    code = post("/v1/chain/get_code", {"account_name": "whaleextrust"})
    check("whaleex.code_hash",
          code["code_hash"] == "e1f01c19d2a1539da73e2ff5926727d7003a279d5ca963bd1844b90e22dfea8b",
          code["code_hash"])

    stat_u = post("/v1/chain/get_currency_stats", {"code": "tokens.wal", "symbol": "USDT"})
    stat_b = post("/v1/chain/get_currency_stats", {"code": "tokens.wal", "symbol": "BTC"})
    check("tokens.wal.usdt_issuer_self", stat_u["USDT"]["issuer"] == "tokens.wal", stat_u)
    check("tokens.wal.btc_issuer_self", stat_b["BTC"]["issuer"] == "tokens.wal", stat_b)

    # ---------- B. DMD ----------
    dmd_expected = {
        "eosdmdpool11": ("eosio.token", "EOS", "44728.4875 EOS"),
        "eosdmdpool12": ("tethertether", "USDT", "135410.8398 USDT"),
        "eosdmdpool13": ("organixtoken", "OGX", "75235.9113 OGX"),
    }
    dmd_codes = {
        "eosdmdpool11": "80d2195e3d30371d46ffa68a4c5bf6c607a22e72fc823192f667bf423051629b",
        "eosdmdpool12": "d878289aecc6a8581bfcf16776b206dd302eee7bb8f97f8fd2f8004ffedd0dbb",
        "eosdmdpool13": "4f9527b706c525ba8dd991dd535cddc279d4ff3ad63037b4d5bca0c0a6591858",
    }
    for acct, (tok, sym, expected) in dmd_expected.items():
        bal = post("/v1/chain/get_currency_balance",
                   {"code": tok, "account": acct, "symbol": sym})
        check("dmd.%s.balance" % acct, bal == [expected], bal)
        c = post("/v1/chain/get_code", {"account_name": acct})
        check("dmd.%s.code_hash" % acct, c["code_hash"] == dmd_codes[acct], c["code_hash"])
        a = post("/v1/chain/get_account", {"account_name": acct})
        pm = {p["perm_name"]: p["required_auth"] for p in a["permissions"]}
        act = pm["active"]
        own = pm["owner"]
        check("dmd.%s.active_self_code_only" % acct,
              act.get("keys", []) == [] and
              [x["permission"] for x in act.get("accounts", [])] == [{"actor": acct, "permission": "eosio.code"}],
              act.get("accounts"))
        check("dmd.%s.owner_3of4" % acct,
              own.get("threshold") == 22 and own.get("keys", []) == [],
              {x["permission"]["actor"]: x["weight"] for x in own.get("accounts", [])})
        rows = post("/v1/chain/get_table_rows",
                    {"json": True, "code": acct, "scope": acct, "table": "stakepool", "limit": 10})
        ts = rows["rows"][0]["total_staked"] if rows.get("rows") else None
        check("dmd.%s.stakepool_total" % acct, ts == expected, ts)

    # ---------- C. Static auth facts ----------
    wabt_dir = get_wabt()
    tmp = "/tmp/h205"
    os.makedirs(tmp, exist_ok=True)

    # whaleextrust: single action clearextsym -> handler requires auth of the account loaded from the action struct
    w = fetch_wasm("whaleextrust")
    check("whaleextrust.wasm.sha256",
          hashlib.sha256(w).hexdigest() == "e1f01c19d2a1539da73e2ff5926727d7003a279d5ca963bd1844b90e22dfea8b",
          hashlib.sha256(w).hexdigest())
    t = wat(w, tmp + "/whaleextrust.wasm", wabt_dir)
    check("whaleextrust.dispatch_only_clearextsym",
          t.count("i64.const 4923678677923243008") >= 1 and
          t.count("i64.const 8421045207927095296") == 0,  # no init etc.
          "clearextsym const present")
    check("whaleextrust.clearextsym_requires_auth_of_loaded_account",
          bool(re.search(r"local\.get 0\s+i64\.load\s+call 4\b", t)),
          "require_auth(*(i64*)arg) pattern present")

    # tokens.wal: transfer handler requires auth(from)
    w = fetch_wasm("tokens.wal")
    check("tokens.wal.wasm.sha256",
          hashlib.sha256(w).hexdigest() == "a866784930cd7bf62620debfc8bd31645c777c4ccbe2a955fc1a13159da9e5a4",
          hashlib.sha256(w).hexdigest())
    d = dcmp(w, tmp + "/tokens.wal.wasm", wabt_dir)
    m = re.search(r"export function ZN5eosio5token8transferEyy[^\{]*\{(.{0,2500})", d, re.S)
    body = m.group(1) if m else ""
    check("tokens.wal.transfer_requires_auth_from",
          "env_require_auth(b);" in body, (body[:120] if body else "transfer fn not found"))
    check("tokens.wal.retire_requires_issuer_auth",
          bool(re.search(r"export function ZN5eosio5token6retireE[^\{]*\{(.{0,4000})", d, re.S)) and
          "env_require_auth(f[4]:long);" in re.search(
              r"export function ZN5eosio5token6retireE[^\{]*\{(.{0,4000})", d, re.S).group(1),
          "retire -> require_auth(stat.issuer)")

    # DMD pools: handler auth structure (all three pools, same structure)
    for pool, expected_sha in [
        ("eosdmdpool11", "80d2195e3d30371d46ffa68a4c5bf6c607a22e72fc823192f667bf423051629b"),
        ("eosdmdpool12", "d878289aecc6a8581bfcf16776b206dd302eee7bb8f97f8fd2f8004ffedd0dbb"),
        ("eosdmdpool13", "4f9527b706c525ba8dd991dd535cddc279d4ff3ad63037b4d5bca0c0a6591858"),
    ]:
        w = fetch_wasm(pool)
        check("dmd.%s.wasm.sha256" % pool, hashlib.sha256(w).hexdigest() == expected_sha,
              hashlib.sha256(w).hexdigest())
        t = wat(w, tmp + "/%s.wasm" % pool, wabt_dir)
        ra = None
        for mm in re.finditer(r'\(import "env" "require_auth" \(func \(;(\d+);\)', t):
            ra = int(mm.group(1))
        check("dmd.%s.imports_require_auth" % pool, ra is not None, ra)
        if ra is not None:
            pat = re.compile(r"\(func \(;(\d+);\) \(type 1\) \(param i32 i64\)\s*\n\s*local\.get 1\s*\n\s*call %d\b" % ra)
            name_handlers = [int(x.group(1)) for x in pat.finditer(t)]
            check("dmd.%s.exit_claim_require_auth_from" % pool, len(name_handlers) == 2, name_handlers)
            elem = re.search(r"\(elem \(;0;\) \(i32\.const 0\) func ([0-9 ]+)\)", t)
            tbl = [int(x) for x in elem.group(1).split()] if elem else []
            check("dmd.%s.elem_table" % pool, tbl == [103, 23, 32, 27, 28, 30, 25], tbl)
            if len(tbl) == 7 and len(name_handlers) == 2:
                check("dmd.%s.exit_table3_is_auth_handler" % pool, tbl[3] in name_handlers, (tbl[3], name_handlers))
                check("dmd.%s.claim_table6_is_auth_handler" % pool, tbl[6] in name_handlers, (tbl[6], name_handlers))
            check("dmd.%s.dispatch_has_exit_claim_constants" % pool,
                  "i64.const 6295346183808221184" in t and "i64.const 4921564679018381312" in t,
                  "exit/claim constants present")
            check("dmd.%s.dispatch_has_harvest_constants" % pool,
                  "i64.const 7615504932250058752" in t and "i64.const 7615504932283613184" in t,
                  "harvest/harvest2 constants present")
        d = dcmp(w, tmp + "/%s.wasm" % pool, wabt_dir)
        check("dmd.%s.worker_admin_name" % pool, "eosdmdworker" in d, "eosdmdworker name present")
        check("dmd.%s.worker_auth_calls" % pool, d.count("env_require_auth") >= 5, d.count("env_require_auth"))

    failed = [r for r in results if not r["ok"]]
    out = {
        "head_block": head,
        "head_block_time": info["head_block_time"],
        "checks_total": len(results),
        "checks_failed": len(failed),
        "results": results,
    }
    with open(os.path.join(OUT_DIR, "eos-misc-verify.json"), "w") as f:
        json.dump(out, f, indent=2)
    print("checks: %d/%d passed" % (len(results) - len(failed), len(results)))
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
