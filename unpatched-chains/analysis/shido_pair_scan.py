#!/usr/bin/env python3
"""Identify DEX pairs holding Shido ecosystem tokens via token-holder scan + ERC-20 pair probing.
Read-only. Public endpoints only. No secrets."""
import json, urllib.request, time, sys

RPC = "https://evm.shidoscan.net"
BS = "https://shidoscan.com/api/v2"
UA = {"User-Agent": "zombie-research/1.0"}

TOKENS = {
    "WSHIDO": "0x8cbafFD9b658997E7bf87E98FEbF6EA6917166F7",
    "SHDX":   "0xe550Bde2F0898552B38a41635d7a8DDB1Fd81276",
}
DEX_TOKENS = {  # additional ecosystem tokens to scan for pools
    "KENSEI": None,
    "USDC":   None,
}

def http(url, data=None, headers=None, timeout=25):
    req = urllib.request.Request(url, data=data, headers=headers or UA)
    return urllib.request.urlopen(req, timeout=timeout).read()

_rpc_id = [0]
def rpc_call(method, params):
    _rpc_id[0] += 1
    body = json.dumps({"jsonrpc": "2.0", "id": _rpc_id[0], "method": method, "params": params}).encode()
    out = http(RPC, data=body, headers={**UA, "Content-Type": "application/json"})
    return json.loads(out)

def rpc_batch(calls):
    payload = []
    for i, (m, p) in enumerate(calls):
        payload.append({"jsonrpc": "2.0", "id": i, "method": m, "params": p})
    out = http(RPC, data=json.dumps(payload).encode(), headers={**UA, "Content-Type": "application/json"})
    return json.loads(out)

def holders(addr, maxn=200):
    items, nxt = [], None
    while True:
        u = f"{BS}/tokens/{addr}/holders"
        if nxt: u += f"?next_page_params={urllib.parse.quote(json.dumps(nxt))}"
        d = json.loads(http(u))
        items += d.get("items", [])
        nxt = d.get("next_page_params")
        if not nxt or len(items) >= maxn:
            break
    return items

def call(to, sel, ret=None):
    data = "0x" + sel
    r = rpc_call("eth_call", [{"to": to, "data": data}, "latest"])
    return r.get("result")

def decode_addr(hexstr):
    if not hexstr or len(hexstr) < 42: return None
    return "0x" + hexstr[-40:]

def decode_uint(hexstr):
    if not hexstr or hexstr == "0x": return None
    return int(hexstr, 16)

if __name__ == "__main__":
    import urllib.parse
    pairs = {}
    token_holders = {}
    for name, taddr in TOKENS.items():
        hs = holders(taddr, 100)
        token_holders[name] = []
        for h in hs:
            a = (h.get("address") or {}).get("hash")
            bal = int(h.get("value") or 0)
            if a: token_holders[name].append({"addr": a, "bal": bal, "contract": (h.get("address") or {}).get("is_contract")})
        print(f"{name}: {len(token_holders[name])} holders scanned")

    # probe every distinct holder for pair-ness
    probe_set = {}
    for name, hs in token_holders.items():
        for h in hs:
            probe_set.setdefault(h["addr"], {"is_contract": h["contract"], "tokens": []})
            probe_set[h["addr"]]["tokens"].append(name)

    calls = []
    addrs = list(probe_set.keys())
    for a in addrs:
        calls.append(("eth_call", [{"to": a, "data": "0x0dfe1681"}, "latest"]))  # token0()
    res = rpc_batch(calls)
    token0 = {}
    for i, r in enumerate(res):
        token0[addrs[i]] = decode_addr(r.get("result"))

    calls2 = []
    addrs2 = [a for a in addrs if token0.get(a)]
    for a in addrs2:
        calls2.append(("eth_call", [{"to": a, "data": "0xd21220a7"}, "latest"]))  # token1()
    res2 = rpc_batch(calls2)
    token1 = {}
    for i, r in enumerate(res2):
        token1[addrs2[i]] = decode_addr(r.get("result"))

    for a in addrs2:
        t0, t1 = token0.get(a), token1.get(a)
        if t0 and t1 and t0.lower() != t1.lower():
            pairs[a] = {"token0": t0, "token1": t1, "holders_of": probe_set[a]["tokens"]}

    print(f"candidate pair contracts: {len(pairs)}")
    out = {"token_holders": token_holders, "pairs": pairs}
    json.dump(out, open("shido_pair_scan_raw.json", "w"), indent=1)
    for a, p in sorted(pairs.items()):
        print(a, p["token0"], p["token1"], p["holders_of"])
