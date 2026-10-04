#!/usr/bin/env python3
"""H-22 CI state check — read-only Solana RPC proofs for Serum v3 / OpenBook v1.
Writes JSON results to ci-out/. Tolerates RPC failures (records errors)."""
import json, os, sys, time, urllib.request

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ci-out")
os.makedirs(OUT, exist_ok=True)

ENDPOINTS = [u for u in [
    os.environ.get("SOLANA_RPC_URL"),
    "https://api.mainnet-beta.solana.com",
    "https://solana-rpc.publicnode.com",
] if u]

def rpc(method, params, timeout=60, tries=3):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for a in range(tries):
        for ep in ENDPOINTS:
            try:
                req = urllib.request.Request(ep, data=body, headers={
                    "Content-Type": "application/json", "User-Agent": "Mozilla/5.0 zombie-hunt/1.0"})
                with urllib.request.urlopen(req, timeout=timeout) as r:
                    j = json.loads(r.read().decode())
                if "error" in j:
                    last = (ep, j["error"]); continue
                return j["result"]
            except Exception as e:
                last = (ep, str(e))
        time.sleep(2 * (a + 1))
    raise RuntimeError(f"{method} failed: {last}")

def b58_to_bytes(s):
    alpha = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    n = 0
    for ch in s:
        n = n * 58 + alpha.index(ch)
    b = n.to_bytes((n.bit_length() + 7) // 8, "big") if n else b""
    return b"\x00" * (len(s) - len(s.lstrip("1"))) + b

def bytes_to_b58(b):
    alpha = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    n = int.from_bytes(b, "big"); out = ""
    while n:
        n, r = divmod(n, 58); out = alpha[r] + out
    return "1" * (len(b) - len(b.lstrip(b"\x00"))) + out

import base64, struct

out = {"generated_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "checks": {}}

def acct(pk, enc="base64"):
    return rpc("getAccountInfo", [pk, {"encoding": enc, "commitment": "finalized"}])["value"]

# 1) programs: deploy slot + upgrade authority
for name, prog in [("serum_v3", "9xQeWvG816bUx9EPjHmaT23yvVM2ZWbrrpZb9PusVFin"),
                   ("openbook_v1", "srmqPvymJeFKQ4zGQed1GFppgkRHL9kaELCbyksJtPX")]:
    try:
        v = acct(prog)
        d = base64.b64decode(v["data"][0])
        pda = bytes_to_b58(d[4:36])
        pd = acct(pda)
        dd = base64.b64decode(pd["data"][0])
        slot = struct.unpack_from("<Q", dd, 4)[0]
        auth = bytes_to_b58(dd[13:45]) if dd[12] else None
        out["checks"][name] = {"program": prog, "programdata": pda, "deploy_slot": slot,
                               "upgrade_authority": auth, "programdata_len": pd["space"]}
    except Exception as e:
        out["checks"][name] = {"error": str(e)[:200]}

# 2) Serum v3 SOL/USDC market vault actual balances
try:
    b1 = rpc("getTokenAccountBalance", ["36c6YqAwyGKQG66XEp2dJc5JqjaBNv7sVghEtJv4c7u6", {"commitment": "finalized"}])["value"]
    b2 = rpc("getTokenAccountBalance", ["8CFo8bL8mZQK8abbFyypFMwEDd8tVJjHTTojMLgQTUSZ", {"commitment": "finalized"}])["value"]
    out["checks"]["serum_solusdc_vaults"] = {
        "market": "9wFFyRfZBsuAha4YcuxcXLKwMxJR43S7fPfQLusDBzvT",
        "coin_vault_wsol": b1, "pc_vault_usdc": b2}
except Exception as e:
    out["checks"]["serum_solusdc_vaults"] = {"error": str(e)[:200]}

# 3) zeroed OpenOrders shells (3228B, flags=0) — the one rent-claim candidate
try:
    z8 = bytes_to_b58((0).to_bytes(8, "little"))
    r = rpc("getProgramAccounts", ["srmqPvymJeFKQ4zGQed1GFppgkRHL9kaELCbyksJtPX", {
        "encoding": "base64", "commitment": "finalized",
        "filters": [{"dataSize": 3228}, {"memcmp": {"offset": 5, "bytes": z8}}],
        "dataSlice": {"offset": 0, "length": 0}}], timeout=90)
    out["checks"]["zeroed_openorders_shells"] = len(r)
except Exception as e:
    out["checks"]["zeroed_openorders_shells"] = {"error": str(e)[:200]}

# 4) zeroed MarketState shells (388B, flags=0)
try:
    z8 = bytes_to_b58((0).to_bytes(8, "little"))
    r = rpc("getProgramAccounts", ["srmqPvymJeFKQ4zGQed1GFppgkRHL9kaELCbyksJtPX", {
        "encoding": "base64", "commitment": "finalized",
        "filters": [{"dataSize": 388}, {"memcmp": {"offset": 5, "bytes": z8}}],
        "dataSlice": {"offset": 0, "length": 0}}], timeout=90)
    out["checks"]["zeroed_market_shells"] = len(r)
except Exception as e:
    out["checks"]["zeroed_market_shells"] = {"error": str(e)[:200]}

# 5) authorities existence
for name, a in [("openbook_fee_sweeper", "GTgd6NaobHDLSFAh2kG5DTNsL4SBJH42Qq11jpjWCfXA"),
                ("serum_fee_sweeper", "DeqYsmBd9BnrbgUwQjVH4sQWK71dEgE6eoZFw3Rp4ftE"),
                ("serum_disable_authority", "5ZVJgwWxMsqXxRMYHXqMwH2hd4myX5Ef4Au2iUsuNQ7V")]:
    try:
        v = acct(a)
        out["checks"][name] = {"exists": bool(v), "owner": (v or {}).get("owner"),
                               "lamports": (v or {}).get("lamports"), "space": (v or {}).get("space")}
    except Exception as e:
        out["checks"][name] = {"error": str(e)[:200]}

# 6) DefiLlama TVL cross-check
try:
    with urllib.request.urlopen("https://api.llama.fi/tvl/serum", timeout=30) as r:
        out["checks"]["defillama_serum_tvl"] = json.loads(r.read().decode())
    with urllib.request.urlopen("https://api.llama.fi/tvl/openbook", timeout=30) as r:
        out["checks"]["defillama_openbook_tvl"] = json.loads(r.read().decode())
except Exception as e:
    out["checks"]["defillama_tvl"] = {"error": str(e)[:200]}

out["summary"] = {
    "e_u_usd": 0,
    "h_o_usd_conservative": 11160385.92,
    "h_o_usd_upper": 17131473.29 + 1157329.30,
    "locked_openbook_rent_sol_est": 672806,
    "locked_openbook_rent_usd_est_at_120_98": 81380000,
}
json.dump(out, open(f"{OUT}/state_check.json", "w"), indent=1)
print(json.dumps(out, indent=1)[:6000])
print("WROTE", f"{OUT}/state_check.json")
