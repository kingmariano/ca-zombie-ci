#!/usr/bin/env python3
"""ChildB: assemble live-state.json from raw cast reads + DefiLlama prices."""
import json, re
from decimal import Decimal, getcontext
from datetime import datetime, timezone
getcontext().prec = 60

BASE = "/home/heisenberg/CA/shimmerbridge/analysis/childB"
BRIDGE = "0x9C6D5a71FdD306329287a835e9B8EDb7F0F17898"

def load_kv(path, fields=4):
    d = {}
    for line in open(path):
        p = line.rstrip("\n").split("|", fields-1)
        if len(p) < fields: continue
        d[(p[0], p[1])] = p[2:]
    return d

chains = [l.strip().split("|") for l in open(f"{BASE}/chains.env") if l.strip() and not l.startswith("#")]
tokens = [l.strip().split("|") for l in open(f"{BASE}/tokens.env") if l.strip() and not l.startswith("#")]
blocks = {l.split("|")[0]: l.strip().split("|") for l in open(f"{BASE}/blocks.txt")}
binfo = {p[0]: p for p in (l.strip().split("|") for l in open(f"{BASE}/raw/blocks-info.txt"))}
state = {}
for l in open(f"{BASE}/raw/state-merged.txt"):
    c, label, v = l.rstrip("\n").split("|", 2)
    state[(c, label)] = v
endpoint = {}
for f in ["raw/endpoint-raw.txt", "raw/endpoint-retry.txt"]:
    try:
        for l in open(f"{BASE}/{f}"):
            p = l.rstrip("\n").split("|")
            if len(p) >= 4 and p[2] == "OK":
                endpoint[(p[0], p[1])] = {"value": int(p[3].replace(" [", " [").split(" [")[0]), "rpc": p[4] if len(p) > 4 else None}
    except FileNotFoundError:
        pass
prices = json.load(open(f"{BASE}/raw/prices.json"))["coins"]

def to_int(s):
    return int(s.replace(" [", " [").split(" [")[0])

out = {
    "title": "ShimmerBridge OriginalTokenBridge — live state at pinned blocks",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "bridge_address": BRIDGE,
    "remote_chain_id": 230,
    "method": (
        "read-only eth_call at pinned block heights using foundry cast 1.8.5 against keyless public RPCs; "
        "prices from keyless DefiLlama coins API. No transactions signed/sent."
    ),
    "units_note": (
        "All raw integer values are strings (wei / LD units / SD units as labelled). "
        "totalValueLockedSD is in shared decimals; principal_LD = totalValueLockedSD * LDtoSDConversionRate. "
        "accruedFeeLD = balanceOf(bridge) - principal_LD. USD values are spot estimates from DefiLlama."
    ),
    "chains": {},
    "totals": {},
}

grand_principal = Decimal(0)
grand_fee = Decimal(0)
grand_balance = Decimal(0)

for name, cid, rpc, llama in chains:
    tb = binfo[name]
    ch = {
        "chain_id": int(cid),
        "block": int(tb[1]),
        "block_hash": tb[2],
        "block_timestamp_utc": datetime.fromtimestamp(int(tb[3]), tz=timezone.utc).isoformat(),
        "rpc_primary": rpc,
        "owner": state[(name, "owner")],
        "remoteChainId": int(to_int(state[(name, "remoteChainId")])),
        "trustedRemoteLookup_230": state[(name, "trustedRemote")],
        "useCustomAdapterParams": state[(name, "customAdapter")] == "true",
        "lz_endpoint": state[(name, "lzEndpoint")],
        "lz_endpoint_inbound_nonce_from_230": endpoint.get((name, "endpoint.inbound"), {}).get("value"),
        "lz_endpoint_outbound_nonce_to_230": endpoint.get((name, "endpoint.outbound"), {}).get("value"),
        "tokens": {},
    }
    chain_principal = Decimal(0); chain_fee = Decimal(0); chain_balance = Decimal(0)
    for tchain, sym, addr in tokens:
        if tchain != name: continue
        supported = state[(name, f"tok.{sym}.supported")] == "true"
        dec = to_int(state[(name, f"tok.{sym}.decimals")])
        rate = to_int(state[(name, f"tok.{sym}.rate")]) if supported else 0
        tvl_sd = to_int(state[(name, f"tok.{sym}.tvlSD")]) if supported else 0
        bal = to_int(state[(name, f"tok.{sym}.balBridge")])
        fee = to_int(state[(name, f"tok.{sym}.accrued")]) if supported else 0
        principal_ld = tvl_sd * rate
        fee_computed = bal - principal_ld
        pc = prices.get(f"{llama}:{addr.lower()}")
        price = Decimal(str(pc["price"])) if pc else None
        scale = Decimal(10) ** dec
        def usd(v):
            if price is None: return None
            return (Decimal(v) / scale * price)
        tok = {
            "address": addr,
            "decimals": dec,
            "supported": supported,
            "LDtoSDConversionRate": str(rate),
            "totalValueLockedSD_raw": str(tvl_sd),
            "principal_locked_LD_raw": str(principal_ld),
            "balanceOf_bridge_raw": str(bal),
            "accruedFeeLD_raw": str(fee),
            "accruedFeeLD_recomputed_raw": str(fee_computed),
            "balance_usd": None if price is None else str(usd(bal).quantize(Decimal("0.01"))),
            "principal_usd": None if price is None else str(usd(principal_ld).quantize(Decimal("0.01"))),
            "accrued_fee_usd": None if price is None else str(usd(fee).quantize(Decimal("0.01"))),
            "price_usd": None if price is None else str(price),
            "price_timestamp": None if price is None else pc["timestamp"],
            "price_confidence": None if price is None else pc["confidence"],
        }
        ch["tokens"][sym] = tok
        if price is not None:
            chain_principal += usd(principal_ld); chain_fee += usd(fee); chain_balance += usd(bal)
    ch["total_principal_usd"] = str(chain_principal.quantize(Decimal("0.01")))
    ch["total_accrued_fee_usd"] = str(chain_fee.quantize(Decimal("0.01")))
    ch["total_balance_usd"] = str(chain_balance.quantize(Decimal("0.01")))
    out["chains"][name] = ch
    grand_principal += chain_principal; grand_fee += chain_fee; grand_balance += chain_balance

out["totals"] = {
    "total_principal_usd": str(grand_principal.quantize(Decimal("0.01"))),
    "total_accrued_fee_usd": str(grand_fee.quantize(Decimal("0.01"))),
    "total_balance_usd": str(grand_balance.quantize(Decimal("0.01"))),
}
json.dump(out, open(f"{BASE}/live-state.json", "w"), indent=1)
print("total principal USD:", out["totals"]["total_principal_usd"])
print("total accrued fee USD:", out["totals"]["total_accrued_fee_usd"])
print("total balance USD:", out["totals"]["total_balance_usd"])
for n, c in out["chains"].items():
    print(f'{n:10s} principal={c["total_principal_usd"]:>12s} fee={c["total_accrued_fee_usd"]:>10s} balance={c["total_balance_usd"]:>12s}')
