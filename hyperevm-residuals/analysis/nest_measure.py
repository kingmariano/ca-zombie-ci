#!/usr/bin/env python3
"""Stage 2: exact token-balance measurement of Nest protocol on HyperEVM at ONE block.

Reads (all at explicit block B):
  - every pool (69 V3 + 3 V2): token0/token1 (on-chain, cross-check API), balanceOf(pool)
  - every gauge: TOKEN(), totalSupply(), feeVault(); LP-token balanceOf(gauge)
  - every fees vault (72): pool(), token0/token1 balanceOf(vault)
  - Algebra community vault + factory balances for every measured token
  - veNEST / Voter / Minter / misc NEST balances and veNEST supply stats
  - Ichi/Steer third-party vault balances for their pool tokens (labelled)
  - token metadata (decimals/symbol) and DefiLlama prices (raw saved)
Output: nest_value_raw.json
"""
import sys, json, time, urllib.request
sys.path.insert(0, "/home/heisenberg/CA/hyperevm-residuals/analysis")
from hl_rpc import *

BASE = "/home/heisenberg/CA/hyperevm-residuals/analysis"
NEST = "0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035"
VENEST = "0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074"
MINTER = "0x574f6865140e6929bDed24596D78a8D9c07E356d"
VOTER = "0x566bdc5444fd5fe5d93ec379Bd66eC861ddbA901"
VENEST_IMPL = "0xf70526a0089fdc334814c3498ca1ba30c25aba91"
ADDR_6652 = "0x6652173b0cb3d96d8f0198bc49670440dec69e79"
ALG_VAULT = "0x15E408A37cE4D13218202C0054B0f485E38F5768"
ALG_FACTORY = "0xF77Bd082c627aA54591cF2f2EaA811fd1AB3b1F3"
ZERO = "0x0000000000000000000000000000000000000000"
SEL = {
    "token0": "0x0dfe1681",
    "token1": "0xd21220a7",
    "balanceOf": "0x70a08231",
    "totalSupply": "0x18160ddd",
    "decimals": "0x313ce567",
    "symbol": "0x95d89b41",
    "TOKEN": "0x82bfefc8",     # GaugeUpgradeable TOKEN()
    "feeVault": "0x478222c2",  # GaugeUpgradeable feeVault()
    "feeVault_alt": "0xc717a86e",
    "pool": "0x16f0115b",      # FeesVaultUpgradeable pool()
    "supply": "0x047fc9aa",
    "permanentTotalSupply": "0x94340b05",
    "votingPowerTotalSupply": "0xe1ba0c00",
    "getReserves": "0x0902f1ac",
}


def pad(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def dec_u(res):
    if not res or res == "0x":
        return None
    try:
        return int(res, 16)
    except Exception:
        return None


def dec_addr(res):
    if not res or len(res) < 42:
        return None
    return "0x" + res[-40:]


def dec_str(res):
    if not res or res == "0x":
        return None
    try:
        b = bytes.fromhex(res[2:])
        if len(b) >= 64:
            off = int.from_bytes(b[0:32], "big")
            ln = int.from_bytes(b[off:off + 32], "big")
            return b[off + 32:off + 32 + ln].decode(errors="replace")
        return None
    except Exception:
        return None


def main():
    pools = json.load(open(f"{BASE}/nest_pools_api.json"))
    probe = json.load(open(f"{BASE}/nest_probe1.json"))
    BN = block_number()
    B = hex(BN)
    print("block:", BN)

    # gather distinct tokens (API + on-chain will be cross-checked)
    api_tokens = []
    for p in pools:
        for k in ("token0", "token1"):
            t = p.get(k)
            if isinstance(t, dict) and t.get("tokenAddress"):
                a = t["tokenAddress"]
                if a.lower() not in [x.lower() for x in api_tokens]:
                    api_tokens.append(a)
    print("distinct API tokens:", len(api_tokens))

    # third-party vaults from API
    tp_vaults = {}  # lowercase vault -> set of pool addrs
    for p in pools:
        for v in (p.get("vaults") or []):
            va = (v.get("address") or "").lower()
            if va:
                tp_vaults.setdefault(va, set()).add(p["id"])

    calls, meta = [], []

    # --- pool token0/token1 + balances ---
    for p in pools:
        a = p["id"]
        calls.append(("eth_call", [{"to": a, "data": SEL["token0"]}, B])); meta.append(("pool", a, "token0"))
        calls.append(("eth_call", [{"to": a, "data": SEL["token1"]}, B])); meta.append(("pool", a, "token1"))
    for p in pools:
        a = p["id"]
        for k in ("token0", "token1"):
            t = p.get(k)
            if isinstance(t, dict) and t.get("tokenAddress"):
                calls.append(("eth_call", [{"to": t["tokenAddress"], "data": SEL["balanceOf"] + pad(a)}, B]))
                meta.append(("poolbal", a, k))

    # --- V2 pair LP supply ---
    for p in pools:
        if p.get("poolType") == "V2":
            a = p["id"]
            calls.append(("eth_call", [{"to": a, "data": SEL["totalSupply"]}, B])); meta.append(("pair", a, "totalSupply"))
            calls.append(("eth_call", [{"to": a, "data": SEL["getReserves"]}, B])); meta.append(("pair", a, "getReserves"))

    # --- gauges ---
    gauges = {}
    for a, v in probe["per_pool"].items():
        g = (v.get("poolToGauge") or "").lower()
        if g and g != ZERO:
            gauges.setdefault(g, []).append(a)
    print("distinct real gauges:", len(gauges))
    for g in gauges:
        calls.append(("eth_call", [{"to": g, "data": SEL["TOKEN"]}, B])); meta.append(("gauge", g, "TOKEN"))
        calls.append(("eth_call", [{"to": g, "data": SEL["totalSupply"]}, B])); meta.append(("gauge", g, "totalSupply"))
        calls.append(("eth_call", [{"to": g, "data": SEL["feeVault"]}, B])); meta.append(("gauge", g, "feeVault"))
        calls.append(("eth_call", [{"to": g, "data": SEL["feeVault_alt"]}, B])); meta.append(("gauge", g, "feeVault_alt"))

    # --- fees vaults ---
    vaults = {}
    for a, v in probe["per_pool"].items():
        f = (v.get("feesVault") or "").lower()
        if f and f != ZERO:
            vaults.setdefault(f, []).append(a)
    print("distinct fees vaults:", len(vaults))
    for f in vaults:
        calls.append(("eth_call", [{"to": f, "data": SEL["pool"]}, B])); meta.append(("vault", f, "pool"))

    # --- core veNEST etc ---
    core_calls = [
        ("core", NEST, "totalSupply"), ("core", VENEST, "supply"), ("core", VENEST, "totalSupply"),
        ("core", VENEST, "permanentTotalSupply"), ("core", VENEST, "votingPowerTotalSupply"),
    ]
    for kind, to, what in core_calls:
        calls.append(("eth_call", [{"to": to, "data": SEL[what]}, B])); meta.append((kind, to, what))
    for label, h in (("veNEST", VENEST), ("veNEST_impl", VENEST_IMPL), ("Minter", MINTER), ("Voter", VOTER), ("0x6652", ADDR_6652), ("AlgebraVault", ALG_VAULT), ("AlgebraFactory", ALG_FACTORY)):
        calls.append(("eth_call", [{"to": NEST, "data": SEL["balanceOf"] + pad(h)}, B])); meta.append(("nestbal", label, h))

    # --- Algebra vault/factory for all API tokens ---
    for t in api_tokens:
        for holder, hname in ((ALG_VAULT, "AlgebraVault"), (ALG_FACTORY, "AlgebraFactory")):
            calls.append(("eth_call", [{"to": t, "data": SEL["balanceOf"] + pad(holder)}, B])); meta.append(("algbal", hname, t))

    # --- third-party vault balances (their token + pool tokens) ---
    tp_tokens = {}  # vault -> tokens to read
    for va, poolset in tp_vaults.items():
        toks = set()
        for p in pools:
            if p["id"] in poolset:
                for k in ("token0", "token1"):
                    t = p.get(k)
                    if isinstance(t, dict) and t.get("tokenAddress"):
                        toks.add(t["tokenAddress"])
        tp_tokens[va] = sorted(toks)
    for va, toks in tp_tokens.items():
        for t in toks:
            calls.append(("eth_call", [{"to": t, "data": SEL["balanceOf"] + pad(va)}, B])); meta.append(("tpbal", va, t))

    # --- token metadata ---
    for t in api_tokens:
        calls.append(("eth_call", [{"to": t, "data": SEL["decimals"]}, B])); meta.append(("tokmeta", t, "decimals"))
        calls.append(("eth_call", [{"to": t, "data": SEL["symbol"]}, B])); meta.append(("tokmeta", t, "symbol"))

    print("total calls:", len(calls))
    results = {}
    t0 = time.time()
    cm = list(zip(calls, meta))
    for i in range(0, len(cm), 20):
        part = cm[i:i + 20]
        res = batch([c for c, _ in part], chunk=20)
        for (c, m), r in zip(part, res):
            results.setdefault(m[0], [])
            results[m[0]].append((m[1], m[2], r))
    print("rpc done in %.1fs" % (time.time() - t0))

    out = {"block": BN, "block_hex": B, "pool_rows": [], "gauge_rows": {}, "vault_rows": {},
           "core": {}, "nest_balances": {}, "algebra": {}, "token_meta": {}, "tp_balances": {},
           "pair_lp": {}}

    # organize pool data
    pool_tok = {}
    pool_bal = {}
    for a, k, r in results.get("pool", []):
        pool_tok.setdefault(a, {})[k] = dec_addr(r)
    for a, k, r in results.get("poolbal", []):
        pool_bal.setdefault(a, {})[k] = dec_u(r)
    for p in pools:
        a = p["id"]
        toks = pool_tok.get(a, {})
        bals = pool_bal.get(a, {})
        out["pool_rows"].append({
            "pool": a, "type": p.get("poolType"), "fee": p.get("fee"),
            "gauge": p.get("gauge"), "tvlUSD_api": float(p.get("tvlUSD") or 0),
            "token0": toks.get("token0"), "token1": toks.get("token1"),
            "token0_api": (p.get("token0") or {}).get("tokenAddress"),
            "token1_api": (p.get("token1") or {}).get("tokenAddress"),
            "bal0": bals.get("token0", 0), "bal1": bals.get("token1", 0),
        })
    for a, k, r in results.get("pair", []):
        out["pair_lp"].setdefault(a, {})[k] = (dec_u(r) if k == "totalSupply" else r)
    for g, what, r in results.get("gauge", []):
        v = out["gauge_rows"].setdefault(g, {"pools": gauges[g]})
        if what in ("TOKEN", "feeVault", "feeVault_alt"):
            v[what] = dec_addr(r)
        else:
            v[what] = dec_u(r)
    for f, what, r in results.get("vault", []):
        out["vault_rows"].setdefault(f, {})[what] = dec_addr(r)
    for to, what, r in results.get("core", []):
        out["core"].setdefault(to, {})[what] = dec_u(r)
    for label, h, r in results.get("nestbal", []):
        out["nest_balances"][label] = dec_u(r)
    for hname, t, r in results.get("algbal", []):
        out["algebra"].setdefault(hname, {})[t] = dec_u(r)
    for t, what, r in results.get("tokmeta", []):
        out["token_meta"].setdefault(t, {})[what] = (dec_u(r) if what == "decimals" else dec_str(r))
    for va, t, r in results.get("tpbal", []):
        out["tp_balances"].setdefault(va, {})[t] = dec_u(r)

    out["gauges_map"] = gauges
    out["vaults_map"] = vaults
    out["tp_vaults"] = {k: sorted(v) for k, v in tp_vaults.items()}

    json.dump(out, open(f"{BASE}/nest_value_raw.json", "w"), indent=1)
    print("saved nest_value_raw.json")
    # quick sanity
    tok0_ok = sum(1 for r in out["pool_rows"] if r["token0"] and r["token0_api"] and r["token0"].lower() == r["token0_api"].lower())
    tok1_ok = sum(1 for r in out["pool_rows"] if r["token1"] and r["token1_api"] and r["token1"].lower() == r["token1_api"].lower())
    print("token0 match", tok0_ok, "/72; token1 match", tok1_ok, "/72")
    print("nest_balances:", out["nest_balances"])
    print("sample gauge:", list(out["gauge_rows"].items())[:2])


if __name__ == "__main__":
    main()
