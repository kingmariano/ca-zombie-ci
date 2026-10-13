#!/usr/bin/env python3
"""Probe token bytecode for 4-byte selectors and test mint-like entrypoints with eth_call
(READ-ONLY simulation - no transaction is sent). Outputs analysis/mint_probe.json"""
import json, os, urllib.request, re, time

D = os.path.dirname(os.path.abspath(__file__))
RPC = "https://base-rpc.publicnode.com"
UA = {"User-Agent": "research", "Content-Type": "application/json"}

def rpc(m, p):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": m, "params": p}).encode()
    req = urllib.request.Request(RPC, data=body, headers=UA)
    d = json.loads(urllib.request.urlopen(req, timeout=30).read().decode())
    if "result" in d:
        return d["result"]
    raise RuntimeError(str(d.get("error"))[:200])

def code(addr):
    return rpc("eth_getCode", [addr, "latest"])

def extract_push4(c):
    """Find PUSH4 selectors in bytecode (0x63 xx xx xx xx)."""
    b = bytes.fromhex(c[2:]) if c.startswith("0x") else b""
    out = []
    i = 0
    while i < len(b) - 4:
        if b[i] == 0x63:
            sel = b[i + 1:i + 5]
            out.append("0x" + sel.hex())
            i += 5
        else:
            i += 1
    return out

def fourbyte(sel):
    try:
        url = "https://www.4byte.directory/api/v1/signatures/?hex_signature=" + sel
        req = urllib.request.Request(url, headers={"User-Agent": "research"})
        d = json.loads(urllib.request.urlopen(req, timeout=20).read().decode())
        res = d.get("results", [])
        if res:
            return sorted(set(r["text_signature"] for r in res))[:3]
    except Exception:
        pass
    return []

TOKENS = {
    "wDAI_1": "0x5d0af35b4f6f4715961b56168de93bf0062b173d",
    "wDAI_impl1": "0x40a0c407e5f114df8be282f53c07e4a8d3f979d3",
    "wDAI_2": "0x73ea165665d3a8c8df77970251291d8ad6015b66",
    "SARF": "0xb18eaa707614ffa142736493850a7c95acb33112",
}

CALLER = "0x1111111111111111111111111111111111111111"
out = {}
for name, addr in TOKENS.items():
    c = code(addr)
    if c in ("0x", None):
        print(name, "no code"); continue
    sels = sorted(set(extract_push4(c)))
    sigs = {}
    print(f"== {name} {addr} code_bytes={len(c)//2-1} push4={len(sels)}")
    for s in sels:
        sig = fourbyte(s)
        if sig:
            sigs[s] = sig
    mint_sigs = {s: v for s, v in sigs.items() if any(re.search(r'\b(mint|deposit|wrap)\b', x) for x in v)}
    print("   mint/deposit-like:", json.dumps(mint_sigs))
    out[name] = {"address": addr, "selectors": sigs, "mint_like": mint_sigs}

    # probe each mint-like selector with eth_call, from = fresh EOA; args: try (caller,1e18) and (1e18,)
    for s, sigs_ in mint_sigs.items():
        for args in (CALLER[2:].rjust(64, "0") + hex(10**18)[2:].rjust(64, "0"),
                     hex(10**18)[2:].rjust(64, "0")):
            try:
                res = rpc("eth_call", [{"from": CALLER, "to": addr, "data": s + args}, "latest"])
                out[name].setdefault("probes", []).append(
                    {"sel": s, "sigs": sigs_, "args_len": len(args) // 64, "result": res[:80]})
                print(f"   PROBE {s} {sigs_} args64={len(args)//64} -> OK {res[:40]}")
            except Exception as e:
                pass
    time.sleep(0.5)

json.dump(out, open(os.path.join(D, "mint_probe.json"), "w"), indent=1)
print("wrote mint_probe.json")
