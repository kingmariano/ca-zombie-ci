#!/usr/bin/env python3
"""Read feeTo EOA LP-token balances across all Dfyn pairs (all 3 chains)."""
import json, urllib.request, time

UA = {"User-Agent": "Mozilla/5.0 dfyn-research", "Content-Type": "application/json"}
RPC = {"polygon": ["https://polygon-bor-rpc.publicnode.com", "https://polygon.drpc.org"],
       "fantom": ["https://fantom.drpc.org", "https://fantom-rpc.publicnode.com"],
       "okc": ["https://exchainrpc.okex.org"]}
CUR = {k: [0] for k in RPC}

def rpc_batch(chain, calls, timeout=90, tries=8):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    body = json.dumps(payload).encode()
    last = None
    urls = RPC[chain]
    for t in range(tries):
        url = urls[CUR[chain][0] % len(urls)]
        try:
            req = urllib.request.Request(url, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read().decode())
            if isinstance(d, list):
                out = [None] * len(calls)
                for item in d:
                    i = item.get("id")
                    if isinstance(i, int) and 0 <= i < len(calls):
                        out[i] = item["result"] if "result" in item else {"error": item.get("error")}
                return out
        except Exception as e:
            last = str(e)[:100]; CUR[chain][0] += 1; time.sleep(1.5 * (t + 1))
    raise RuntimeError(f"batch fail {chain}: {last}")

def pad(a): return a.lower().replace("0x", "").rjust(64, "0")
def dec_addr(h): return "0x" + h[-40:] if isinstance(h, str) and len(h) >= 42 else None
def dec_int(h):
    try: return int(h, 16)
    except: return None

FAC = {"polygon": "0xe7fb3e833efe5f9c441105eb65ef8b261266423b",
       "fantom": "0xd9820a17053d6314b20642e465a84bf01a3d64f5",
       "okc": "0xe7fb3e833efe5f9c441105eb65ef8b261266423b"}
FEE_TO = "0x74665b21461f8d9b23bab7d599bfd7566a95fd70"

out = {}
for chain, fac in FAC.items():
    n = dec_int(rpc_batch(chain, [("eth_call", [{"to": fac, "data": "0x574f2ba3"}, "latest"])])[0])
    print(chain, "pairs", n, flush=True)
    pairs = []
    for i in range(0, n, 50):
        idxs = list(range(i, min(i+50, n)))
        r = rpc_batch(chain, [("eth_call", [{"to": fac, "data": "0x1e3dd18b" + hex(j)[2:].rjust(64, "0")}, "latest"]) for j in idxs])
        pairs += [dec_addr(x) for x in r]
    pairs = [p for p in pairs if p]
    res = []
    for i in range(0, len(pairs), 50):
        chunk = pairs[i:i+50]
        r = rpc_batch(chain, [("eth_call", [{"to": p, "data": "0x70a08231" + pad(FEE_TO)}, "latest"]) for p in chunk])
        res += [(p, dec_int(x) if isinstance(x, str) else None) for p, x in zip(chunk, r)]
        print(f"  {min(i+50,len(pairs))}/{len(pairs)}", flush=True)
    out[chain] = {p: b for p, b in res}
json.dump(out, open("/home/heisenberg/CA/dfyn-network/analysis/feeto-lp.json", "w"), indent=1)
for chain, d in out.items():
    nz = [(p, b) for p, b in d.items() if b]
    print(chain, "pairs with feeTo LP > 0:", len(nz), "of", len(d))
    for p, b in nz[:10]:
        print("  ", p, b)
