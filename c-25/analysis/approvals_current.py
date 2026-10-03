#!/usr/bin/env python3
"""Stage 2: resolve latest approval per (token, owner) to the proxy, verify live allowance + balance."""
import json, urllib.request, time

PROXY = "0xeEeEEe53033F7227d488ae83a27Bc9A9D5051756"
RPC = "https://ethereum-rpc.publicnode.com"
d = json.load(open("/home/heisenberg/CA/c-25/analysis/approvals_spender_proxy.json"))
logs = d["global_logs"]

latest = {}
for e in logs:
    tok = e["address"].lower()
    owner = "0x" + e["topics"][1][-40:]
    val = int(e["data"], 16) if e["data"] not in ("0x", "") else 0
    blk = int(e["blockNumber"], 16)
    key = (tok, owner.lower())
    if key not in latest or blk > latest[key]["block"]:
        latest[key] = {"block": blk, "value": val, "tx": e["transactionHash"], "ts": int(e["timeStamp"], 16)}

print(f"unique (token,owner) pairs: {len(latest)}")

def enc_addr(a): return a[2:].lower().rjust(64, "0")
calls = []
keys = list(latest.keys())
for tok, owner in keys:
    calls.append({"jsonrpc":"2.0","id":len(calls)+1,"method":"eth_call","params":[{"to":tok,"data":"0xdd62ed3e"+enc_addr(owner)+enc_addr(PROXY)},"latest"]})
    calls.append({"jsonrpc":"2.0","id":len(calls)+1,"method":"eth_call","params":[{"to":tok,"data":"0x70a08231"+enc_addr(owner)},"latest"]})
    calls.append({"jsonrpc":"2.0","id":len(calls)+1,"method":"eth_call","params":[{"to":tok,"data":"0x313ce567"},"latest"]})
    calls.append({"jsonrpc":"2.0","id":len(calls)+1,"method":"eth_call","params":[{"to":tok,"data":"0x95d89b41"},"latest"]})

def batch(items):
    out = {}
    for i in range(0, len(items), 200):
        chunk = items[i:i+200]
        data = json.dumps(chunk).encode()
        for a in range(4):
            try:
                req = urllib.request.Request(RPC, data=data, headers={"Content-Type":"application/json","User-Agent":"c25"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    o = json.loads(r.read().decode())
                for x in o: out[x["id"]] = x
                break
            except Exception:
                if a == 3: raise
                time.sleep(2*(a+1))
    return out

res = batch(calls)
rows = []
for i, (tok, owner) in enumerate(keys):
    base = i*4
    def val(j):
        o = res.get(base+j+1, {})
        r = o.get("result")
        return r
    al = val(0); bal = val(1); dec = val(2); sym = val(3)
    al = int(al, 16) if al and al != "0x" else 0
    bal = int(bal, 16) if bal and bal != "0x" else 0
    decv = int(dec, 16) if dec and dec != "0x" and len(dec) <= 66 else 18
    if sym and sym != "0x" and len(sym) > 2:
        try:
            b = bytes.fromhex(sym[2:])
            L = int.from_bytes(b[32:64], "big") if len(b) >= 64 else 0
            syms = b[64:64+L].decode("utf-8", "replace") if L else "?"
        except Exception:
            syms = "?"
    else:
        syms = "?"
    rows.append({"token": tok, "symbol": syms, "decimals": decv, "owner": owner, "last_approval_block": latest[(tok, owner)]["block"],
                 "last_approval_value": latest[(tok, owner)]["value"], "live_allowance": al, "owner_balance": bal,
                 "last_tx": latest[(tok, owner)]["tx"]})

rows.sort(key=lambda r: -r["live_allowance"])
json.dump(rows, open("/home/heisenberg/CA/c-25/analysis/approvals_current.json", "w"), indent=2)
print(f"{'token':12} {'owner':44} {'allowance':>30} {'balance':>30} block")
live = 0
for r in rows:
    if r["live_allowance"] > 0 or r["owner_balance"] > 0:
        live += 1
        print(f"{r['symbol']:12} {r['owner']:44} {r['live_allowance']:>30} {r['owner_balance']:>30} {r['last_approval_block']}")
print(f"pairs with live allowance>0 or balance>0: {live}")
both = [r for r in rows if r["live_allowance"] > 0 and r["owner_balance"] > 0]
print(f"pairs with live allowance>0 AND balance>0: {len(both)}")
for r in both:
    print("  BOTH:", r["symbol"], r["owner"], "allow=", r["live_allowance"]/10**r["decimals"], "bal=", r["owner_balance"]/10**r["decimals"])
