#!/usr/bin/env python3
"""CI verification for JediSwap V1 (read-only, public keyless RPCs).
Re-reads the whole protocol state at the latest block:
  factory + proxy state, all 1051 pairs (reserves, totalSupply, token balances),
  raw storage checks (_locked, _factory), skim-excess detection, USD valuation.
Writes ci-out/ci_verify.json
"""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sn

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ci-out")
os.makedirs(OUT, exist_ok=True)

FACT = "0xdad44c139a476c7a17fc8141e6db680e9abc9f56fe249a105094c44382c2fd"
ADMIN = "0x284a1ad6382cffc520d8f711cf9519ccf43b3c105b89ef081cbe1a625322410"
PAIR_IMPL = "0x2b39bc3f4c1fd5bef8b7d21504c44e0da59cf27b350551b13d913da52e40d3b"
FACT_IMPL = "0x2580632f25bbee45da5a1a1ef49d03a984f78dde4019069aa9f25aac06f941a"

result = {"generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}

block = sn.rpc("starknet_blockNumber", [])
result["block"] = block
print("block:", block, flush=True)

# ---------- factory ----------
factory = {"addr": FACT}
for f in ["get_num_of_pairs", "get_fee_to", "get_fee_to_setter", "get_pair_contract_class_hash",
          "get_implementation_hash", "get_admin"]:
    try:
        factory[f] = sn.call(FACT, f)[0]
    except Exception as e:
        factory[f] = "ERR:" + str(e)[:80]
factory["class_hash"] = sn.get_class_hash_at(FACT)
allpairs = sn.call(FACT, "get_all_pairs")
pairs = allpairs[1:]
result["factory"] = factory
result["pairs_count"] = len(pairs)
print("pairs:", len(pairs), "| fee_to:", factory["get_fee_to"], "| admin:", factory["get_admin"], flush=True)

# ---------- all pairs: reserves / totalSupply / tokens ----------
SEL = {k: sn.selector(k) for k in ["get_reserves", "totalSupply", "token0", "token1", "balanceOf"]}
calls = []
for p in pairs:
    calls += [(p, SEL["get_reserves"], []), (p, SEL["totalSupply"], []),
              (p, SEL["token0"], []), (p, SEL["token1"], [])]
res = sn.batch_calls(calls, chunk=100)
state = []
for i, p in enumerate(pairs):
    rr, ts, t0, t1 = res[4*i:4*i+4]
    rec = {"pair": p}
    if isinstance(rr, list) and len(rr) >= 5:
        rec["r0"] = int(rr[0], 16) + (int(rr[1], 16) << 128)
        rec["r1"] = int(rr[2], 16) + (int(rr[3], 16) << 128)
    if isinstance(ts, list) and len(ts) >= 2:
        rec["ts"] = int(ts[0], 16) + (int(ts[1], 16) << 128)
    if isinstance(t0, list) and t0:
        rec["t0"] = t0[0]
    if isinstance(t1, list) and t1:
        rec["t1"] = t1[0]
    state.append(rec)
print("pair state read", flush=True)

# balances
calls = []
idx = []
for i, rec in enumerate(state):
    if "t0" in rec:
        calls.append((rec["t0"], SEL["balanceOf"], [int(rec["pair"], 16)])); idx.append((i, 0))
    if "t1" in rec:
        calls.append((rec["t1"], SEL["balanceOf"], [int(rec["pair"], 16)])); idx.append((i, 1))
res2 = sn.batch_calls(calls, chunk=100)
for (i, side), r in zip(idx, res2):
    if isinstance(r, list) and len(r) >= 2:
        state[i][f"b{side}"] = int(r[0], 16) + (int(r[1], 16) << 128)

anom = {"TS0_WITH_BALANCE": [], "ONE_ZERO_RESERVE": [], "BALANCE_GT_RESERVE": [],
        "BALANCE_LT_RESERVE": [], "ZERO_RESERVES_WITH_BALANCE": []}
for rec in state:
    r0 = rec.get("r0", 0); r1 = rec.get("r1", 0); b0 = rec.get("b0", 0); b1 = rec.get("b1", 0)
    ts = rec.get("ts", 0)
    if ts == 0 and (b0 > 0 or b1 > 0): anom["TS0_WITH_BALANCE"].append(rec["pair"])
    if (r0 == 0) != (r1 == 0): anom["ONE_ZERO_RESERVE"].append(rec["pair"])
    if b0 > r0 or b1 > r1: anom["BALANCE_GT_RESERVE"].append(rec["pair"])
    if b0 < r0 or b1 < r1: anom["BALANCE_LT_RESERVE"].append(rec["pair"])
    if r0 == 0 and r1 == 0 and (b0 > 0 or b1 > 0): anom["ZERO_RESERVES_WITH_BALANCE"].append(rec["pair"])
result["anomalies"] = {k: v for k, v in anom.items()}
print("anomalies:", {k: len(v) for k, v in anom.items()}, flush=True)

# ---------- raw storage: _locked and _factory for all pairs ----------
def sn_keccak(s):
    return int.from_bytes(sn.keccak256(s.encode()), "big") & ((1 << 250) - 1)

locked_bad, fac_bad, unread = [], [], []
from concurrent.futures import ThreadPoolExecutor

CARTRIDGE = "https://api.cartridge.gg/x/starknet/mainnet"

def get_storage_retry(pair, key, tries=6):
    for i in range(tries):
        try:
            return int(sn.rpc("starknet_getStorageAt", [pair, key, "latest"], urls=[CARTRIDGE]), 16)
        except Exception:
            time.sleep(0.4 * (i + 1))
    return None

def check_storage(p):
    lv = get_storage_retry(p, hex(sn_keccak("_locked")))
    fv = get_storage_retry(p, hex(sn_keccak("_factory")))
    return p, lv, fv

with ThreadPoolExecutor(max_workers=4) as ex:
    for p, lv, fv in ex.map(check_storage, pairs):
        if lv is None or fv is None:
            unread.append(p)
        else:
            if lv != 0: locked_bad.append([p, hex(lv)])
            if fv != int(FACT, 16): fac_bad.append([p, hex(fv)])
result["storage"] = {"locked_nonzero": locked_bad, "factory_mismatch": fac_bad, "unread": unread}
print("storage: locked_nonzero:", len(locked_bad), "factory_mismatch:", len(fac_bad),
      "unread:", len(unread), flush=True)
result["storage"] = {"locked_nonzero": locked_bad, "factory_mismatch": fac_bad}
print("storage: locked_nonzero:", len(locked_bad), "factory_mismatch:", len(fac_bad), flush=True)

# ---------- uniform proxy state (sample + counts) ----------
imp_sel = sn.selector("get_implementation_hash"); adm_sel = sn.selector("get_admin")
calls = []
for p in pairs:
    calls += [(p, imp_sel, []), (p, adm_sel, [])]
res3 = sn.batch_calls(calls, chunk=100)
from collections import Counter
imps = Counter(); adms = Counter()
for i in range(len(pairs)):
    imps[res3[2*i][0] if isinstance(res3[2*i], list) else "ERR"] += 1
    adms[res3[2*i+1][0] if isinstance(res3[2*i+1], list) else "ERR"] += 1
result["impl_counter"] = {k: v for k, v in imps.items()}
result["admin_counter"] = {k: v for k, v in adms.items()}
print("impls:", result["impl_counter"], flush=True)
print("admins:", result["admin_counter"], flush=True)

# ---------- USD valuation (DefiLlama public API) ----------
import urllib.request
tokens = sorted({r.get("t0") for r in state if r.get("t0")} | {r.get("t1") for r in state if r.get("t1")})
prices = {}
for i in range(0, len(tokens), 50):
    part = tokens[i:i + 50]
    url = "https://coins.llama.fi/prices/current/" + ",".join(f"starknet:{t}" for t in part)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=45) as r:
            prices.update(json.loads(r.read().decode()).get("coins", {}))
    except Exception as e:
        print("price chunk err", str(e)[:80])
    time.sleep(0.2)

# token metadata (decimals/symbol)
need = [t for t in tokens]
meta = {}
calls = []
for t in need:
    calls += [(t, sn.selector("decimals"), []), (t, sn.selector("symbol"), [])]
res4 = sn.batch_calls(calls, chunk=100)
for i, t in enumerate(need):
    d, s = res4[2*i], res4[2*i+1]
    rec = {}
    if isinstance(d, list) and d:
        rec["decimals"] = int(d[0], 16)
    if isinstance(s, list) and s:
        try:
            rec["symbol"] = bytes.fromhex(s[0][2:]).decode("utf-8", "ignore").strip("\x00")
        except Exception:
            pass
    meta[t] = rec

total_usd = 0.0
skim_usd = 0.0
unpriced = {}
skim_rows = []
for rec in state:
    for side in ("0", "1"):
        t = rec.get(f"t{side}"); raw = rec.get(f"r{side}", 0)
        if not t or raw == 0: continue
        pr = prices.get(f"starknet:{t}")
        if pr:
            total_usd += raw / (10 ** meta.get(t, {}).get("decimals", 18)) * pr["price"]
        else:
            unpriced[t] = unpriced.get(t, 0) + raw
    for side in ("0", "1"):
        t = rec.get(f"t{side}")
        exc = rec.get(f"b{side}", 0) - rec.get(f"r{side}", 0)
        if exc > 0 and t:
            pr = prices.get(f"starknet:{t}")
            u = exc / (10 ** meta.get(t, {}).get("decimals", 18)) * pr["price"] if pr else 0.0
            skim_usd += u
            skim_rows.append({"pair": rec["pair"], "side": side, "token": t,
                              "symbol": meta.get(t, {}).get("symbol"), "excess": exc, "usd": round(u, 6)})

result["total_usd_priced_legs"] = round(total_usd, 2)
result["skim_excess_usd"] = round(skim_usd, 6)
result["skim_rows"] = skim_rows
result["unpriced_legs"] = len(unpriced)
result["pair_state"] = state
result["token_meta"] = meta
result["prices"] = prices
json.dump(result, open(os.path.join(OUT, "ci_verify.json"), "w"), indent=1)
print("TOTAL USD (priced legs):", round(total_usd, 2), flush=True)
print("SKIM EXCESS USD:", round(skim_usd, 6), flush=True)
print("DONE", flush=True)
