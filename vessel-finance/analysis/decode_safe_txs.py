#!/usr/bin/env python3
"""Decode Gnosis Safe execTransaction txs (incl. MultiSend) for 0x9549F1d6... from Scrollscan API."""
import json, urllib.request, sys, time

SAFE = "0x9549F1d6428066BE58C315374676E9d244716d4F"

def api(path):
    url = f"https://scrollscan.com/api/v2/addresses/{SAFE}/{path}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    return json.load(urllib.request.urlopen(req, timeout=60))

def parse_safe_exec(inp):
    if inp[:10] != "0x6a761202":
        return None
    args = inp[10:]
    words = [args[i:i+64] for i in range(0, len(args), 64)]
    to = '0x' + words[0][24:]
    doff = int(words[2], 16) * 2
    dlen = int(args[doff:doff+64], 16)
    data = args[doff+64:doff+64+2*dlen]
    return to, data

def parse_multisend(data):
    if not data.startswith("8d80ff0a"):
        return None
    args = data[8:]
    off = int(args[:64], 16) * 2
    ln = int(args[off:off+64], 16)
    packed = args[off+64:off+64+2*ln]
    p = 0; out = []
    while p < len(packed):
        op = packed[p]; p += 1
        tgt = '0x' + packed[p:p+40]; p += 20
        val = int(packed[p:p+64], 16); p += 32
        dl = int(packed[p:p+64], 16); p += 32
        cd = packed[p:p+2*dl]; p += 2*dl
        out.append((op, tgt, val, cd))
    return out

def main():
    items = []
    d = api("transactions")
    while True:
        items.extend(d.get("items", []))
        nxt = d.get("next_page_params")
        if not nxt:
            break
        q = "&".join(f"{k}={v}" for k, v in nxt.items())
        d = api(f"transactions?{q}")
        time.sleep(0.3)
    print("total safe txs:", len(items))
    out = []
    for t in items:
        h = t.get("hash"); inp = t.get("raw_input") or ""
        dec = parse_safe_exec(inp)
        rec = dict(block=t.get("block_number"), ts=t.get("timestamp"), hash=h)
        if dec is None:
            rec["note"] = "not execTransaction"
            out.append(rec); continue
        to, data = dec
        calls = []
        if to.lower() == "0x40a2accbd92bca938b02010e17a5b8929b49130d":
            for op, tgt, val, cd in (parse_multisend(data) or []):
                calls.append(dict(target=tgt, value=val, selector="0x"+cd[:8], calldata=cd[:200]))
        else:
            calls.append(dict(target=to, value=t.get("value"), selector="0x"+data[:8], calldata=data[:200]))
        rec["calls"] = calls
        out.append(rec)
    json.dump(out, open(sys.argv[2] if len(sys.argv)>2 else "safe_txs.json", "w"), indent=1)
    for r in out:
        print(r["block"], r["ts"], r["hash"][:14])
        for c in r.get("calls", []):
            print("    ->", c["target"], "sel", c["selector"], "data", c["calldata"][:120])

if __name__ == "__main__":
    main()
