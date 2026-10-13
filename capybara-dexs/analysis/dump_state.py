#!/usr/bin/env python3
"""Live-state dump for Capybara (Wombat fork) on Kaia — read-only eth_call batches."""
import json
import subprocess
import sys
import time
import urllib.request

RPC = "https://public-en.node.kaia.io"
OUT = sys.argv[1] if len(sys.argv) > 1 else "live_state.json"

def sig(fn):
    r = subprocess.run(["cast", "sig", fn], capture_output=True, text=True)
    s = r.stdout.strip()
    if not s.startswith("0x"):
        raise RuntimeError(f"sig failed {fn}: {s} {r.stderr}")
    return s[2:]

def enc_call(to, selector, args=None):
    data = "0x" + selector
    for a in args or []:
        if isinstance(a, int):
            data += f"{a:064x}"
        elif isinstance(a, str) and a.startswith("0x"):
            data += a[2:].lower().rjust(64, "0")
        else:
            raise ValueError(a)
    return {"to": to, "data": data}

def rpc_batch(calls):
    """Send eth_calls in small chunks (public RPC batch limits)."""
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i + 10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                    "params": [chunk[j], BLOCK_HEX]} for j in range(len(chunk))]
        req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json", "User-Agent": "research"})
        for attempt in range(3):
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    res = json.loads(r.read())
                break
            except Exception:
                if attempt == 2:
                    raise
                time.sleep(2)
        by_id = {x["id"]: x for x in res}
        for j in range(len(chunk)):
            x = by_id.get(j)
            out.append(x.get("result") or ("ERR:" + str(x.get("error", ""))[:80]) if x else "ERR:missing")
    return out

def decode_uint(hexstr):
    if hexstr.startswith("ERR") or hexstr in (None, "0x"):
        return hexstr
    return int(hexstr, 16)

def decode_addr(hexstr):
    if hexstr.startswith("ERR") or hexstr in (None, "0x"):
        return hexstr
    return "0x" + hexstr[-40:]

def decode_str(hexstr):
    if hexstr.startswith("ERR") or hexstr in (None, "0x"):
        return hexstr
    b = bytes.fromhex(hexstr[2:])
    if len(b) < 64:
        return ""
    ln = int.from_bytes(b[32:64], "big")
    return b[64:64 + ln].decode("utf-8", "replace")

def decode_bool(x):
    v = decode_uint(x)
    return v if isinstance(v, str) else bool(v)

def decode_str_array(hexstr, scale=None):
    """Decode address[] return value (static elements)."""
    if hexstr.startswith("ERR") or hexstr in (None, "0x"):
        return hexstr
    b = bytes.fromhex(hexstr[2:])
    n = int.from_bytes(b[32:64], "big")
    out = []
    for i in range(n):
        w = b[64 + 32 * i: 96 + 32 * i]
        out.append("0x" + w[-20:].hex())
    return out

# selector cache
sigs = {}
def S(fn):
    if fn not in sigs:
        sigs[fn] = sig(fn)
    return sigs[fn]

def blocks(block=None):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "research"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return int(json.loads(r.read())["result"], 16)

BN = blocks()
BLOCK_HEX = hex(BN)
print("block", BN)

MASTER = "0x3CA30C862769b5de7987D2E2db4c1A72800A1Da1"
NPOOL = 24

data = {"block": BN, "master": MASTER, "assets": []}

# --- enumerate pools (asset LP tokens staked) from master ---
calls = [enc_call(MASTER, S("poolInfo(uint256)"), [i]) for i in range(NPOOL)]
res = rpc_batch(calls)
asset_addrs = []
for i, r in enumerate(res):
    if isinstance(r, str) and r.startswith("0x") and len(r) >= 130:
        asset_addrs.append("0x" + r[2 + 24:2 + 64])

print("assets:", len(asset_addrs))

# --- asset-level reads ---
def asset_reads(a):
    return [
        ("pool", a, S("pool()")),
        ("underlying", a, S("underlyingToken()")),
        ("cash", a, S("cash()")),
        ("liability", a, S("liability()")),
        ("totalSupply", a, S("totalSupply()")),
        ("decimals", a, S("decimals()")),
        ("symbol", a, S("symbol()")),
        ("owner", a, S("owner()")),
        ("maxSupply", a, S("maxSupply()")),
    ]

plan = []
for a in asset_addrs:
    plan.extend(asset_reads(a))
calls = [enc_call(t, s) for (_, t, s) in plan]
res = rpc_batch(calls)
idx = 0
tmp = {}
for a in asset_addrs:
    d = {"asset": a}
    d["pool"] = decode_addr(res[idx]); idx += 1
    d["underlying"] = decode_addr(res[idx]); idx += 1
    d["cash"] = decode_uint(res[idx]); idx += 1
    d["liability"] = decode_uint(res[idx]); idx += 1
    d["totalSupply"] = decode_uint(res[idx]); idx += 1
    d["decimals"] = decode_uint(res[idx]); idx += 1
    d["symbol"] = decode_str(res[idx]); idx += 1
    d["owner"] = decode_addr(res[idx]); idx += 1
    d["maxSupply"] = decode_uint(res[idx]); idx += 1
    tmp[a] = d
    data["assets"].append(d)

# --- underlying token reads ---
plan = []
for d in data["assets"]:
    u = d["underlying"]
    plan += [("sym", u, S("symbol()")), ("dec", u, S("decimals()")),
             ("bal_pool", u, S("balanceOf(address)")), ("bal_asset", u, S("balanceOf(address)")),
             ("bal_master", u, S("balanceOf(address)")), ("totalSupply", u, S("totalSupply()"))]
calls = []
for (kind, u, s) in plan:
    arg = None
    if kind == "bal_pool":
        arg = None
    calls.append((kind, u, s))

# need per-asset pool/master addresses -> rebuild carefully
calls = []
meta = []
for d in data["assets"]:
    u = d["underlying"]
    calls.append(enc_call(u, S("symbol()"))); meta.append((d, "usym", None))
    calls.append(enc_call(u, S("decimals()"))); meta.append((d, "udec", None))
    calls.append(enc_call(u, S("balanceOf(address)"), [d["pool"]])); meta.append((d, "bal_pool", None))
    calls.append(enc_call(u, S("balanceOf(address)"), [d["asset"]])); meta.append((d, "bal_asset", None))
    calls.append(enc_call(u, S("balanceOf(address)"), [MASTER])); meta.append((d, "bal_master", None))
    calls.append(enc_call(u, S("totalSupply()"))); meta.append((d, "usupply", None))
res = rpc_batch(calls)
for (d, kind, _), r in zip(meta, res):
    d[kind] = decode_str(r) if kind == "usym" else (decode_uint(r) if kind in ("udec", "bal_pool", "bal_asset", "bal_master", "usupply") else r)

# --- pool-level reads (unique pools) ---
pools = sorted(set(d["pool"] for d in data["assets"] if isinstance(d["pool"], str) and d["pool"].startswith("0x")))
data["pools"] = []
for p in pools:
    pd = {"pool": p, "assets": []}
    for fn, key, dec in [("owner()", "owner", decode_addr), ("dev()", "dev", decode_addr),
                         ("feeTo()", "feeTo", decode_addr), ("masterWombat()", "masterWombat", decode_addr),
                         ("ampFactor()", "ampFactor", decode_uint), ("haircutRate()", "haircutRate", decode_uint),
                         ("lpDividendRatio()", "lpDividendRatio", decode_uint), ("retentionRatio()", "retentionRatio", decode_uint),
                         ("mintFeeThreshold()", "mintFeeThreshold", decode_uint), ("paused()", "paused", decode_bool)]:
        r = rpc_batch([enc_call(p, S(fn))])[0]
        pd[key] = dec(r)
    r = rpc_batch([enc_call(p, S("getTokens()"))])[0]
    pd["tokens"] = decode_str_array(r)
    # per-token tip bucket, exchange rate, coverageRatio-ish
    for t in pd["tokens"]:
        tb = rpc_batch([enc_call(p, S("tipBucketBalance(address)"), [t])])[0]
        xr = rpc_batch([enc_call(p, S("exchangeRate(address)"), [t])])[0]
        pd["assets"].append({"token": t, "tipBucket": decode_uint(tb), "exchangeRate": decode_uint(xr)})
    data["pools"].append(pd)
    print("pool", p, "tokens", len(pd["tokens"]), "owner", pd["owner"], "paused", pd["paused"])

json.dump(data, open(OUT, "w"), indent=1)
print("wrote", OUT)
