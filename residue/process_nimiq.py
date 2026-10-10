#!/usr/bin/env python3
"""H2-03 Nimiq: process approvals + HTLC events against live Polygon state.
- For every (token, owner) that ever approved a handler: read current allowance + balance.
- For every id ever seen in Open/Redeem/Refund: read htlcs(id) -> currently open set.
- Read handler deposits/registration/owner/hub.
Saves analysis/nimiq/live_state_<block>.json
"""
import json, os, urllib.request, time

RPC = os.environ.get("POLYGON_RPC_URL_PUBLIC", "https://polygon-bor-rpc.publicnode.com")
MULTICALL3 = "0xcA11bde05977b3631167028862bE2a173976CA11"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LOGDIR = os.path.join(BASE_DIR, "analysis", "nimiq", "logs")
OUTDIR = os.path.join(BASE_DIR, "analysis", "nimiq")

H1 = "0x0cFD862bE942846Cebad797d7c1BC6e47714959b"
H2 = "0xF615bD7EA00C4Cc7F39Faad0895dB5f40891359f"
HANDLERS = {"H1": H1, "H2": H2}
TOKENS = {
    "0x3c499c542cef5e3811e1192ce70d8cc03d5c3359": ("USDC", 6),
    "0x2791bca1f2de4661ed88a30c99a7a9449aa84174": ("USDC.e", 6),
    "0xc2132d05d31c914a87c6611c10748aeb04b58e8f": ("USDT", 6),
}
SEL_ALLOW = "0xdd62ed3e"
SEL_BAL = "0x70a08231"
SEL_HTLC = "0x91edd8f2"
SEL_DEPOSITS = "0xfc7e286d"
SEL_POOL = "0xdd12bb5b"
SEL_OWNER = "0x8da5cb5b"
SEL_HUB = "0x74e861d6"

def pad(a): return a.lower().replace("0x", "").rjust(64, "0")
def pad32(b): return b.lower().replace("0x", "").rjust(64, "0")

def rpc_call(method, params, _id=1):
    body = json.dumps({"jsonrpc": "2.0", "id": _id, "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                out = json.loads(r.read())
            return out.get("result") if "error" not in out else {"__error__": out["error"]}
        except Exception as e:
            time.sleep(1.5 + attempt)
    return {"__error__": "rpc failed"}

def rpc_batch(calls):
    """calls: list of (to, data) -> eth_call latest"""
    payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                "params": [{"to": to, "data": data}, "latest"]} for i, (to, data) in enumerate(calls)]
    body = json.dumps(payload).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                out = json.loads(r.read())
            res = [None] * len(calls)
            for item in out:
                res[item["id"]] = item.get("result") if "error" not in item else {"__error__": item["error"]}
            return res
        except Exception:
            time.sleep(2 + attempt)
    return [{"__error__": "batch failed"}] * len(calls)

def multicall(target_calls):
    """target_calls: list of (target, calldata). Returns list of result hex or None.
    Uses Multicall3.aggregate3((address,bool,bytes)[]) -> (bool,bytes)[]"""
    results = []
    CHUNK = 120
    chunks = [target_calls[i:i+CHUNK] for i in range(0, len(target_calls), CHUNK)]
    for ci, chunk in enumerate(chunks):
        # encode aggregate3((address,bool,bytes)[])
        # layout: top-offset(32) || len(32) || offsets(32*n, relative to offsets-block start) || tuples
        n = len(chunk)
        tuples = []
        for (t, data) in chunk:
            d = bytes.fromhex(data[2:] if data.startswith("0x") else data)
            tb = (bytes.fromhex(pad(t)) + (1).to_bytes(32, "big")
                  + (96).to_bytes(32, "big") + len(d).to_bytes(32, "big") + d
                  + b"\x00" * ((32 - len(d) % 32) % 32))
            tuples.append(tb)
        offs = []
        cur = 32 * n  # first element starts right after the offsets block
        for tb in tuples:
            offs.append(cur); cur += len(tb)
        array_data = n.to_bytes(32, "big") + b"".join(o.to_bytes(32, "big") for o in offs) + b"".join(tuples)
        calldata = "0x82ad56cb" + (32).to_bytes(32, "big").hex() + array_data.hex()
        r = rpc_call("eth_call", [{"to": MULTICALL3, "data": calldata}, "latest"])
        if not isinstance(r, str) or not r.startswith("0x"):
            print("multicall chunk failed", ci, r); results.extend([None]*n); continue
        raw = bytes.fromhex(r[2:])
        base = int.from_bytes(raw[0:32], "big")           # top-level offset -> array data
        cnt = int.from_bytes(raw[base:base+32], "big")
        offs_start = base + 32
        for i in range(cnt):
            e = offs_start + int.from_bytes(raw[offs_start+32*i:offs_start+32*(i+1)], "big")
            success = int.from_bytes(raw[e:e+32], "big") == 1
            off = int.from_bytes(raw[e+32:e+64], "big")   # -> length word of bytes member
            ln = int.from_bytes(raw[e+off:e+off+32], "big")
            data = raw[e+off+32:e+off+32+ln].hex()
            results.append(("0x"+data) if success else None)
        if ci % 10 == 0:
            print(f"  multicall {ci+1}/{len(chunks)} chunks", flush=True)
    return results

# ---- load logs
def load(fn):
    p = os.path.join(LOGDIR, fn)
    return json.load(open(p)) if os.path.exists(p) else []

approvals = {}
for hname in HANDLERS:
    approvals[hname] = load(f"{hname}_Approval_all_tokens.json")

events = {}
for hname in HANDLERS:
    for ev in ["Open", "Redeem", "Refund"]:
        events[(hname, ev)] = load(f"{hname}_{ev}.json")

block = rpc_call("eth_blockNumber", [])
blockn = int(block, 16)
print("latest block", blockn)

# ---- build (handler, token, owner) set from approvals
pairs = set()
for hname, logs in approvals.items():
    for x in logs:
        tok = x["address"].lower()
        owner = "0x" + x["topics"][1][-40:]
        pairs.add((hname, tok, owner.lower()))
print("unique (handler,token,owner) approval pairs:", len(pairs))

# ---- build candidate ids
ids = set()
for (hname, ev), logs in events.items():
    for x in logs:
        if x.get("topics") and len(x["topics"]) > 1:
            ids.add(x["topics"][1].lower())
print("unique HTLC ids seen in events:", len(ids))

# ---- read allowances + balances
pair_list = sorted(pairs)
calls = []
meta = []
for (hname, tok, owner) in pair_list:
    h = HANDLERS[hname]
    calls.append((tok, SEL_ALLOW + pad(owner) + pad(h))); meta.append(("allow", hname, tok, owner))
for (hname, tok, owner) in pair_list:
    calls.append((tok, SEL_BAL + pad(owner))); meta.append(("bal", hname, tok, owner))
res = multicall(calls)
allow = {}
bal = {}
for (kind, hname, tok, owner), r in zip(meta, res):
    v = int(r, 16) if isinstance(r, str) and len(r) > 2 else None
    if kind == "allow":
        allow[(hname, tok, owner)] = v
    else:
        bal[(hname, tok, owner)] = v

# ---- read htlcs
id_list = sorted(ids)
calls = [(HANDLERS["H1"], SEL_HTLC + pad32(i)) for i in id_list]
res1 = multicall(calls)
calls = [(HANDLERS["H2"], SEL_HTLC + pad32(i)) for i in id_list]
res2 = multicall(calls)

def decode_htlc(r):
    if not isinstance(r, str) or len(r) < 2 + 64*6:
        return None
    w = [r[2+64*i:2+64*(i+1)] for i in range(6)]
    return {
        "token": "0x" + w[0][-40:],
        "amount": int(w[1], 16),
        "refund": "0x" + w[2][-40:],
        "recipient": "0x" + w[3][-40:],
        "hash": "0x" + w[4],
        "timeout": int(w[5], 16),
    }

open_htlcs = {"H1": [], "H2": []}
for i, r in zip(id_list, res1):
    d = decode_htlc(r)
    if d and d["amount"] > 0:
        d["id"] = i; open_htlcs["H1"].append(d)
for i, r in zip(id_list, res2):
    d = decode_htlc(r)
    if d and d["amount"] > 0:
        d["id"] = i; open_htlcs["H2"].append(d)

# ---- handler deposits + config
extra_calls = []
extra_meta = []
for hname, h in HANDLERS.items():
    extra_calls.append((h, SEL_OWNER)); extra_meta.append(("owner", hname))
    extra_calls.append((h, SEL_HUB)); extra_meta.append(("hub", hname))
    for tok in TOKENS:
        extra_calls.append((h, SEL_DEPOSITS + pad(tok))); extra_meta.append(("deposits", hname, tok))
        extra_calls.append((h, SEL_POOL + pad(tok))); extra_meta.append(("pool", hname, tok))
extra_res = multicall(extra_calls)
extra = {}
for m, r in zip(extra_meta, extra_res):
    v = r if isinstance(r, str) else None
    extra["|".join(m)] = v

# ---- summarize live effective allowances
live = []
for (hname, tok, owner) in pair_list:
    a = allow.get((hname, tok, owner))
    b = bal.get((hname, tok, owner))
    if a is None or b is None: continue
    if a > 0 and b > 0:
        eff = min(a, b)
        live.append({"handler": hname, "token": TOKENS.get(tok, (tok, 6))[0], "token_addr": tok,
                     "owner": owner, "allowance": str(a), "balance": str(b), "effective_raw": str(eff),
                     "effective_units": eff / 10**TOKENS.get(tok, (tok, 6))[1]})

out = {
    "block": blockn,
    "rpc": "<polygon-public>",
    "pairs_checked": len(pair_list),
    "ids_checked": len(id_list),
    "live_allowances": sorted(live, key=lambda x: -int(x["effective_raw"])),
    "open_htlcs": open_htlcs,
    "handler_config": extra,
}
json.dump(out, open(os.path.join(OUTDIR, f"live_state_{blockn}.json"), "w"), indent=1)

print("\n== live effective allowances (allowance>0 AND balance>0) ==")
for x in out["live_allowances"][:40]:
    print(f"  {x['handler']} {x['token']:7s} owner={x['owner']} eff={x['effective_units']:.6f} (allow={x['allowance'][:12]}.. bal={x['balance'][:12]}..)")
print(f"  total entries: {len(live)}")
tot = sum(x['effective_units'] for x in live if x['token'] in ('USDC','USDC.e','USDT'))
print(f"  total effective units (stables, raw units sum): {tot:.6f}")

print("\n== open HTLCs ==")
for hname in ["H1","H2"]:
    print(f" {hname}: {len(open_htlcs[hname])} open")
    for d in open_htlcs[hname][:20]:
        tn = TOKENS.get(d["token"], (d["token"], 6))[0]
        print(f"   id={d['id'][:18]}.. token={tn} amount={d['amount']/1e6:.6f} recipient={d['recipient']} refund={d['refund']} timeout={d['timeout']}")
print("\nhandler config:")
for k, v in extra.items():
    print(" ", k, "=", v)
