#!/usr/bin/env python3
"""
C2-58 child subagent — exhaustive enumeration of Zilliqa legacy staking contracts.

READ-ONLY. No transactions. Keyless public RPC only (https://api.zilliqa.com).
Writes raw JSON evidence into ../raw/ and prints a summary table.

Targets:
  * phase-1.0 (Oct-2020 launch) deployer / SSNListProxy / SSNList implementation
  * phase-1.1 (May-2021 migration) SSNListProxy / SSNList implementation
  * gZIL governance token (ZRC-2 Scilla)
  * admin multisig wallet(s), verifier address(es) discovered from on-chain state
  * any further implementation address found in proxy state

For each address: eth_getCode, eth_getBalance (wei), legacy GetBalance (qa),
and, where relevant, GetSmartContractInit / GetSmartContractSubState fields.
The chain head block and its timestamp are recorded for every read.
"""
import json
import sys
import time
import urllib.request
from pathlib import Path

RPC = "https://api.zilliqa.com"
PRICE_URL = "https://coins.llama.fi/prices/current/coingecko:zilliqa"
UA = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (read-only research)"}

HERE = Path(__file__).resolve().parent.parent  # .../analysis/enumeration
RAW = HERE / "raw"
RAW.mkdir(parents=True, exist_ok=True)

sys.path.insert(0, "/home/heisenberg/CA/zilliqa/analysis/scripts")
from zil_bech32 import zil_bech32_to_hex, hex_to_zil_bech32  # noqa: E402


def rpc(method, params, timeout=40, retries=4):
    last = None
    for i in range(retries):
        try:
            body = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
            req = urllib.request.Request(RPC, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(1.5 * (i + 1))
    return {"error": f"rpc failed: {last}"}


def hx(addr_hex):
    return addr_hex if addr_hex.startswith("0x") else "0x" + addr_hex


def account(addr_hex):
    """Balances + code for one 20-byte address."""
    a = hx(addr_hex)
    code = rpc("eth_getCode", [a, "latest"])
    bal = rpc("eth_getBalance", [a, "latest"])
    leg = rpc("GetBalance", [a[2:].lower()])
    out = {
        "hex": a,
        "bech32": hex_to_zil_bech32(a),
        "eth_getCode": code.get("result"),
        "eth_getBalance_hex": bal.get("result"),
        "eth_getBalance_wei": int(bal["result"], 16) if "result" in bal else None,
        "legacy_GetBalance": leg.get("result"),
        "raw": {"eth_getCode": code, "eth_getBalance": bal, "GetBalance": leg},
    }
    if out["eth_getBalance_wei"] is not None:
        out["eth_getBalance_zil"] = out["eth_getBalance_wei"] / 1e18
    return out


def substate(addr_hex, field, indices=None):
    r = rpc("GetSmartContractSubState", [hx(addr_hex)[2:].lower(), field, indices if indices is not None else []])
    return r


def init(addr_hex):
    return rpc("GetSmartContractInit", [hx(addr_hex)[2:].lower()])


def main():
    report = {
        "finding": "C2-58 (child: legacy staking contract enumeration)",
        "chain": "zilliqa-2 (EVM, chainId 32769)",
        "rpc": RPC,
        "collected_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "notes": "read-only; keyless public RPC; no transactions",
    }

    # ---------- chain head ----------
    bn = int(rpc("eth_blockNumber", [])["result"], 16)
    blk = rpc("eth_getBlockByNumber", [hex(bn), False])["result"]
    ts = int(blk["timestamp"], 16)
    report["head"] = {"block": bn, "timestamp": ts,
                      "utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(ts))}
    print(f"head block {bn} @ {report['head']['utc']}")

    # ---------- price ----------
    price = None
    try:
        with urllib.request.urlopen(PRICE_URL, timeout=25) as r:
            price = json.loads(r.read().decode())["coins"]["coingecko:zilliqa"]["price"]
    except Exception as e:  # noqa: BLE001
        print("price fetch failed:", e)
    report["zil_price_usd"] = price
    print("ZIL price:", price)

    # ---------- static candidate set (sources in comments) ----------
    static = [
        # Phase 1.0 — "Non-custodial seed node staking goes live today" blog, Oct 14 2020
        ("v1.0-deployer", "zil1d36l2vd46k6j3hw4dv0dslgrt85qhauk0vzppy", "blog.zilliqa.com Oct-2020: 'Seed Node Staking Deployer'"),
        ("v1.0-proxy", "zil1g029nmzsf36r99vupp4s43lhs40fsscx3jjpuy", "blog.zilliqa.com Oct-2020: 'Seed Node Staking Proxy'"),
        ("v1.0-impl-launch", "zil10xw6l0l9lhg36f87g65m8v74r5dxphyxvv8qhz", "blog.zilliqa.com Oct-2020: 'Seed Node Staking Implementation'"),
        # gZIL — same blog
        ("gzil", "zil14pzuzq6v6pmmmrfjhczywguu0e97djepxt8g3e", "blog.zilliqa.com Oct-2020: 'gZIL Governance token'"),
        # Phase 1.1 — "Staking Contract Migration Completed!" blog, May 15 2021
        ("v1.1-proxy", "zil1v25at4s3eh9w34uqqhe3vdvfsvcwq6un3fupc2", "blog.zilliqa.com May-2021: 'Seed Node Staking Phase 1.1 Proxy'"),
        ("v1.1-impl", "zil15lr86jwg937urdeayvtypvhy6pnp6d7p8n5z09", "blog.zilliqa.com May-2021: 'Seed Node Staking Phase 1.1 Implementation'"),
        # Parent-verified extras
        ("v1.1-multisig", "0x38c986f6252a32b1c0fa732784c1a94e9f42a394", "parent C2-58: SSNList admin 2-of-5 multisig"),
        ("verifier-eoa", "0x412b55a0ebc1001f930aba8dc107022a3a2ba484", "parent C2-58: SSNList verifier"),
    ]

    accts = {}
    for role, addr, src in static:
        a = hx(zil_bech32_to_hex(addr) if addr.startswith("zil1") else addr)
        print(f"[static] {role:18s} {addr} -> {a}")
        info = account(a)
        info["role"] = role
        info["source"] = src
        accts[a] = info

    # ---------- dynamic discovery ----------
    disc = {"reads": {}}
    P0 = hx(zil_bech32_to_hex("zil1g029nmzsf36r99vupp4s43lhs40fsscx3jjpuy"))
    I0L = hx(zil_bech32_to_hex("zil10xw6l0l9lhg36f87g65m8v74r5dxphyxvv8qhz"))
    P1 = hx(zil_bech32_to_hex("zil1v25at4s3eh9w34uqqhe3vdvfsvcwq6un3fupc2"))
    I1 = hx(zil_bech32_to_hex("zil15lr86jwg937urdeayvtypvhy6pnp6d7p8n5z09"))
    GZ = hx(zil_bech32_to_hex("zil14pzuzq6v6pmmmrfjhczywguu0e97djepxt8g3e"))

    # v1.0 proxy state -> current implementation + admin
    for f in ["admin", "implementation", "stagingadmin", "paused", "_balance"]:
        disc["reads"][f"v1.0-proxy.{f}"] = substate(P0, f)

    p0_impl = None
    r = disc["reads"]["v1.0-proxy.implementation"].get("result")
    if isinstance(r, dict):
        impl_field = r.get("implementation")
        if isinstance(impl_field, str) and impl_field.startswith("0x"):
            p0_impl = hx(impl_field)
    disc["v1.0-proxy.current_impl"] = p0_impl
    print("v1.0 proxy current impl:", p0_impl)

    # v1.0 impl fields (current impl + launch impl)
    for label, addr in [("v1.0-impl-current", p0_impl), ("v1.0-impl-launch", I0L)]:
        if not addr:
            continue
        for f in ["contractadmin", "paused", "verifier", "verifier_receiving_addr",
                  "gziladdr", "proxyaddr", "minstake", "totalstakeddeposit", "lastrewardblocknum", "_balance"]:
            key = f"{label}.{f}"
            disc["reads"][key] = substate(addr, f)
        disc["reads"][f"{label}.init"] = init(addr)

    # v1.1 impl fields
    for f in ["contractadmin", "paused", "verifier", "verifier_receiving_addr",
              "gziladdr", "proxyaddr", "minstake", "totalstakeamount", "lastrewardcycle",
              "bnum_req", "_balance"]:
        disc["reads"][f"v1.1-impl.{f}"] = substate(I1, f)
    disc["reads"]["v1.1-impl.init"] = init(I1)
    disc["reads"]["v1.1-proxy.admin"] = substate(P1, "admin")
    disc["reads"]["v1.1-proxy.implementation"] = substate(P1, "implementation")
    disc["reads"]["v1.1-proxy._balance"] = substate(P1, "_balance")

    # gZIL fields
    for f in ["total_supply", "minter", "end_block", "name", "symbol", "decimals", "_balance"]:
        disc["reads"][f"gzil.{f}"] = substate(GZ, f)
    disc["reads"]["gzil.init"] = init(GZ)

    # multisig wallets: owners + required signatures (v1.1 known; v1.0 if admin differs)
    MS1 = hx("0x38c986f6252a32b1c0fa732784c1a94e9f42a394")
    for f in ["owners", "required_signatures", "transactionCount", "_balance"]:
        disc["reads"][f"v1.1-multisig.{f}"] = substate(MS1, f)
    disc["reads"]["v1.1-multisig.init"] = init(MS1)

    # discover v1.0 impl admin / proxy admin (may be a different multisig)
    v10_admin = None
    r = disc["reads"].get("v1.0-impl-current.contractadmin", {}).get("result")
    if isinstance(r, dict):
        v10_admin = r.get("contractadmin")
    if not v10_admin:
        r = disc["reads"].get("v1.0-impl-launch.contractadmin", {}).get("result")
        if isinstance(r, dict):
            v10_admin = r.get("contractadmin")
    disc["v1.0-impl.contractadmin"] = v10_admin

    v10_proxy_admin = None
    r = disc["reads"]["v1.0-proxy.admin"].get("result")
    if isinstance(r, dict):
        v10_proxy_admin = r.get("admin")
    disc["v1.0-proxy.admin"] = v10_proxy_admin
    print("v1.0 impl contractadmin:", v10_admin, "| v1.0 proxy admin:", v10_proxy_admin)

    # v1.0 multisig wallet state (if it is a contract, not an EOA)
    if v10_admin and v10_admin.startswith("0x"):
        for f in ["owners", "required_signatures", "transactionCount", "_balance"]:
            disc["reads"][f"v1.0-multisig.{f}"] = substate(hx(v10_admin), f)
        disc["reads"]["v1.0-multisig.init"] = init(hx(v10_admin))

    # verifiers discovered (Option ByStr20: None = constructor dict, Some = string)
    def opt_addr(v):
        if isinstance(v, str) and v.startswith("0x"):
            return v.lower()
        if isinstance(v, dict):
            args = v.get("arguments") or []
            for a in args:
                if isinstance(a, str) and a.startswith("0x"):
                    return a.lower()
        return None

    verifiers = set()
    for k, v in disc["reads"].items():
        if k.endswith(".verifier"):
            a = opt_addr(v.get("result", {}).get("verifier") if isinstance(v.get("result"), dict) else None)
            if a:
                verifiers.add(a)
    disk_verifier = hx("0x412b55a0ebc1001f930aba8dc107022a3a2ba484")
    verifiers.add(disk_verifier)
    disc["verifiers"] = sorted(verifiers)

    # balances for all discovered extra addresses
    extra = set()
    for cand in [p0_impl, v10_admin, v10_proxy_admin] + sorted(verifiers):
        if cand and hx(cand) not in accts:
            extra.add(hx(cand))
    # verifier receiving addresses (Option ByStr20)
    for k, v in disc["reads"].items():
        if k.endswith(".verifier_receiving_addr"):
            res = v.get("result")
            if isinstance(res, dict):
                a = opt_addr(res.get("verifier_receiving_addr"))
                if a and a not in accts:
                    extra.add(a)
    for a in sorted(extra):
        print("[discovered]", a, hex_to_zil_bech32(a))
        info = account(a)
        info["role"] = "discovered-onchain"
        info["source"] = "discovered from on-chain state of v1.0/v1.1 contracts"
        accts[a] = info

    # second head read (all 'latest' reads happened between these)
    bn2 = int(rpc("eth_blockNumber", [])["result"], 16)
    report["head_end"] = bn2

    report["accounts"] = accts
    report["discovery"] = disc
    report["summary_rows"] = []
    for a, info in accts.items():
        zil = info.get("eth_getBalance_zil")
        report["summary_rows"].append({
            "role": info.get("role"), "hex": a, "bech32": info["bech32"],
            "code_size_hex": (len(info["eth_getCode"]) - 2) // 2 if info.get("eth_getCode") else None,
            "balance_zil": zil,
            "balance_usd": (zil * price) if (zil is not None and price) else None,
            "legacy_GetBalance": info.get("legacy_GetBalance"),
        })

    out = RAW / "legacy_staking_enumeration.json"
    out.write_text(json.dumps(report, indent=1))
    print("wrote", out)
    print(json.dumps(report["summary_rows"], indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
