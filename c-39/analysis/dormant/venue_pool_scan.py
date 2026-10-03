#!/usr/bin/env python3
"""Excess-reserve scan for dormant PulseChain venues' pools (same method as PulseX scan)."""
import json, os, time, urllib.request

RPC = "https://pulsechain-rpc.publicnode.com"
D = os.path.dirname(os.path.abspath(__file__))
gt = json.load(open(os.path.join(D, "gt_all_dexes.json")))

def rpc_batch(calls, retries=4):
    payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call", "params": [c, "latest"]} for i, c in enumerate(calls)]
    data = json.dumps(payload).encode()
    for a in range(retries):
        try:
            req = urllib.request.Request(RPC, data=data, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=90) as r:
                res = json.loads(r.read())
            out = [None] * len(calls)
            for item in res:
                out[item["id"]] = item.get("result")
            return out
        except Exception:
            time.sleep(1.5 * (a + 1))
    return [None] * len(calls)

SEL = {"getReserves()": "0x0902f1ac", "token0()": "0x0dfe1681", "token1()": "0xd21220a7",
       "totalSupply()": "0x18160ddd", "balanceOf(address)": "0x70a08231", "factory()": "0xc45a0155",
       "symbol()": "0x95d89b41", "decimals()": "0x313ce567"}

def pad(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def dec_str(h):
    if not h or h == "0x":
        return None
    try:
        b = bytes.fromhex(h[2:]); off = int.from_bytes(b[0:32], "big"); ln = int.from_bytes(b[off:off+32], "big")
        return b[off+32:off+32+ln].decode("utf8", "replace")
    except Exception:
        return None

def main():
    venues = [v for v in gt.keys() if v not in ("pulsex", "pulsex-v2")]
    pools = []
    seen = set()
    for v in venues:
        for p in gt[v][:40]:
            a = p["address"]
            if a and a not in seen:
                seen.add(a); pools.append((v, a))
    print("pools to scan:", len(pools))
    recs = []
    for i in range(0, len(pools), 25):
        group = pools[i:i+25]
        calls = []
        for v, a in group:
            calls.append({"to": a, "data": SEL["getReserves()"]})
            calls.append({"to": a, "data": SEL["token0()"]})
            calls.append({"to": a, "data": SEL["token1()"]})
            calls.append({"to": a, "data": SEL["totalSupply()"]})
            calls.append({"to": a, "data": SEL["factory()"]})
        res = rpc_batch(calls)
        for j, (v, a) in enumerate(group):
            try:
                r = res[j*5]
                if not r or r == "0x":
                    continue
                t0 = "0x" + res[j*5+1][26:66]
                t1 = "0x" + res[j*5+2][26:66]
                fac = "0x" + res[j*5+4][26:66] if res[j*5+4] and len(res[j*5+4]) >= 66 else None
                rec = {"venue": v, "pair": a, "r0": int(r[2:66], 16), "r1": int(r[66:130], 16),
                       "ts": int(res[j*5+3], 16) if res[j*5+3] and res[j*5+3] != "0x" else None,
                       "t0": t0, "t1": t1, "factory": fac}
                recs.append(rec)
            except Exception:
                pass
        time.sleep(0.1)
    # balances + token meta
    calls = []
    for rec in recs:
        calls.append({"to": rec["t0"], "data": SEL["balanceOf(address)"] + pad(rec["pair"])})
        calls.append({"to": rec["t1"], "data": SEL["balanceOf(address)"] + pad(rec["pair"])})
        calls.append({"to": rec["t0"], "data": SEL["symbol()"]})
        calls.append({"to": rec["t1"], "data": SEL["symbol()"]})
        calls.append({"to": rec["t0"], "data": SEL["decimals()"]})
        calls.append({"to": rec["t1"], "data": SEL["decimals()"]})
    for i in range(0, len(calls), 150):
        res = rpc_batch(calls[i:i+150])
        for j in range(i, min(i+150, len(calls))):
            k = j // 6; f = j % 6
            rec = recs[k]
            if f == 0 and res[j-i]: rec["b0"] = int(res[j-i], 16)
            if f == 1 and res[j-i]: rec["b1"] = int(res[j-i], 16)
            if f == 2: rec["sym0"] = dec_str(res[j-i])
            if f == 3: rec["sym1"] = dec_str(res[j-i])
            if f == 4 and res[j-i]: rec["dec0"] = int(res[j-i], 16)
            if f == 5 and res[j-i]: rec["dec1"] = int(res[j-i], 16)
        time.sleep(0.1)
    flagged = []
    for rec in recs:
        if "b0" in rec and "b1" in rec:
            rec["ex0"] = rec["b0"] - rec["r0"]; rec["ex1"] = rec["b1"] - rec["r1"]
            if rec["ex0"] > 0 or rec["ex1"] > 0:
                flagged.append(rec)
    json.dump({"pools": recs, "flagged": flagged}, open(os.path.join(D, "venue_pool_excess.json"), "w"), indent=1)
    print(f"scanned {len(recs)} pools, flagged {len(flagged)}")
    for rec in sorted(flagged, key=lambda x: max(x["ex0"], x["ex1"]), reverse=True)[:30]:
        e0 = rec["ex0"] / 10 ** rec.get("dec0", 18); e1 = rec["ex1"] / 10 ** rec.get("dec1", 18)
        print(f"  {rec['venue']:22s} {rec['pair']} {rec.get('sym0')}/{rec.get('sym1')} ex0={e0:.6f} ex1={e1:.6f}")

if __name__ == "__main__":
    main()
