#!/usr/bin/env python3
"""Phase 3: for every pair, check class hash / implementation hash / admin (proxy state).
Also fetch token metadata (symbol, decimals) for all tokens. Read-only.
"""
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/jediswap-v1/analysis")
import sn

BASE = "/home/heisenberg/CA/jediswap-v1/analysis/"
st = json.load(open(BASE + "pair_state.json"))
pairs = [p["pair"] for p in st["pairs"]]

# --- proxy state per pair ---
imp_sel = sn.selector("get_implementation_hash")
adm_sel = sn.selector("get_admin")
calls = []
for p in pairs:
    calls.append((p, imp_sel, []))
    calls.append((p, adm_sel, []))
res = sn.batch_calls(calls, chunk=100)
proxy = {}
for i, p in enumerate(pairs):
    imp = res[2*i]; adm = res[2*i+1]
    proxy[p] = {"impl": imp[0] if isinstance(imp, list) else str(imp)[:60],
                "admin": adm[0] if isinstance(adm, list) else str(adm)[:60]}
from collections import Counter
print("impl counter:", Counter(v["impl"] for v in proxy.values()))
print("admin counter:", Counter(v["admin"] for v in proxy.values()))
json.dump(proxy, open(BASE + "pair_proxy_state.json", "w"), indent=0)

# --- class hash per pair (batched via individual rpc, no batch method) ---
ch = {}
for i, p in enumerate(pairs):
    try:
        ch[p] = sn.get_class_hash_at(p)
    except Exception as e:
        ch[p] = "ERR:" + str(e)[:40]
    if i % 100 == 0:
        print("class hash", i)
print("class hash counter:", Counter(ch.values()))
json.dump(ch, open(BASE + "pair_class_hash.json", "w"), indent=0)

# --- token metadata ---
tokens = sorted({p.get("token0") for p in st["pairs"] if p.get("token0")} |
                {p.get("token1") for p in st["pairs"] if p.get("token1")})
print("unique tokens:", len(tokens))
sym_sel = sn.selector("symbol")
dec_sel = sn.selector("decimals")
calls = []
for t in tokens:
    calls.append((t, dec_sel, []))
    calls.append((t, sym_sel, []))
res = sn.batch_calls(calls, chunk=100)
meta = {}
for i, t in enumerate(tokens):
    d = res[2*i]; s = res[2*i+1]
    rec = {}
    if isinstance(d, list) and d:
        try: rec["decimals"] = int(d[0], 16)
        except Exception: pass
    if isinstance(s, list) and s:
        # short string felt decode
        try:
            b = bytes.fromhex(s[0][2:])
            rec["symbol"] = b.decode("utf-8", "ignore").strip("\x00")
        except Exception:
            rec["symbol_raw"] = s[0]
    meta[t] = rec
json.dump(meta, open(BASE + "token_meta.json", "w"), indent=1)
print("token meta saved; sample:", list(meta.items())[:5])
