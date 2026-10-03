#!/usr/bin/env python3
"""Price flagged pairs from ci-out/skim_scan_full.json.

- fetch symbol/decimals for involved tokens
- price via DefiLlama coins API
- simulate skim() from an unprivileged EOA via eth_call
Output: ci-out/flagged_excess_priced.json
"""
import json, os, sys, time, urllib.request

RPC = os.environ.get("PULSECHAIN_RPC") or "https://pulsechain-rpc.publicnode.com"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "ci-out")
src = json.load(open(os.path.join(OUT, "skim_scan_full.json")))
BLOCK = src["block"]

SIMFROM = "0x00000000000000000000000000000000000BeEf1"


def rpc_batch(payload, retries=4):
    for i, item in enumerate(payload):
        item["id"] = i
    data = json.dumps(payload).encode()
    for a in range(retries):
        try:
            req = urllib.request.Request(RPC, data=data,
                                         headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=120) as r:
                res = json.loads(r.read())
            out = [None] * len(payload)
            for item in res:
                if isinstance(item.get("id"), int) and 0 <= item["id"] < len(payload):
                    out[item["id"]] = item.get("result")
            return out
        except Exception as e:
            sys.stderr.write(f"rpc retry {a}: {e}\n")
            time.sleep(2 * (a + 1))
    return [None] * len(payload)


def eth_call(to, data):
    return {"jsonrpc": "2.0", "id": 0, "method": "eth_call",
            "params": [{"to": to, "data": data}, hex(BLOCK)]}


def dec_str(h):
    if not h or h == "0x":
        return None
    try:
        b = bytes.fromhex(h[2:])
        off = int.from_bytes(b[0:32], "big")
        ln = int.from_bytes(b[off:off + 32], "big")
        return b[off + 32:off + 32 + ln].decode("utf8", "replace")
    except Exception:
        return None


def main():
    flagged = src.get("flagged_excess", [])
    deficit = src.get("flagged_deficit", [])
    # cap pricing work
    flagged = sorted(flagged, key=lambda r: max(r["ex0"], r["ex1"]), reverse=True)[:400]
    deficit = sorted(deficit, key=lambda r: min(r["ex0"], r["ex1"]))[:200]
    print(f"flagged_excess={len(src.get('flagged_excess', []))} (pricing {len(flagged)}), "
          f"deficit={len(src.get('flagged_deficit', []))} (pricing {len(deficit)})")

    tokens = set()
    for r in flagged + deficit:
        tokens.add(r["t0"]); tokens.add(r["t1"])
    tokens = sorted(tokens)
    calls = []
    for t in tokens:
        calls.append(eth_call(t, "0x95d89b41"))  # symbol()
        calls.append(eth_call(t, "0x313ce567"))  # decimals()
    meta = {}
    for i in range(0, len(calls), 200):
        res = rpc_batch(calls[i:i + 200])
        for j in range(i, min(i + 200, len(calls))):
            t = tokens[j // 2]
            if t not in meta:
                meta[t] = {}
            if j % 2 == 0:
                meta[t]["symbol"] = dec_str(res[j - i])
            else:
                try:
                    meta[t]["decimals"] = int(res[j - i], 16)
                except Exception:
                    meta[t]["decimals"] = 18
        time.sleep(0.1)

    # prices
    prices = {}
    for i in range(0, len(tokens), 50):
        chunk = tokens[i:i + 50]
        ids = ",".join(f"pulsechain:{t}" for t in chunk)
        try:
            with urllib.request.urlopen(f"https://coins.llama.fi/prices/current/{ids}", timeout=30) as r:
                j = json.loads(r.read())
            prices.update(j.get("coins", {}))
        except Exception as e:
            print("price err", e)
        time.sleep(0.3)

    # skim simulation for flagged
    sim_calls = []
    for r in flagged:
        data = "0xbc25cf77" + SIMFROM[2:].lower().rjust(64, "0")
        sim_calls.append(eth_call(r["pair"], data))
    sim = []
    for i in range(0, len(sim_calls), 100):
        res = rpc_batch(sim_calls[i:i + 100])
        sim.extend(res)
        time.sleep(0.1)

    out = []
    for k, r in enumerate(flagged):
        m0 = meta.get(r["t0"], {}); m1 = meta.get(r["t1"], {})
        d0 = m0.get("decimals") or 18; d1 = m1.get("decimals") or 18
        p0 = prices.get(f"pulsechain:{r['t0']}", {}).get("price")
        p1 = prices.get(f"pulsechain:{r['t1']}", {}).get("price")
        usd0 = (max(r["ex0"], 0) / 10 ** d0) * (p0 or 0)
        usd1 = (max(r["ex1"], 0) / 10 ** d1) * (p1 or 0)
        out.append({**r, "sym0": m0.get("symbol"), "sym1": m1.get("symbol"),
                    "dec0": d0, "dec1": d1, "price0": p0, "price1": p1,
                    "excess_usd": usd0 + usd1,
                    "skim_sim_ok": bool(sim[k] and sim[k] != "0x" and not sim[k].startswith("0x08c379a0"))})
    out.sort(key=lambda x: x["excess_usd"], reverse=True)
    total = sum(x["excess_usd"] for x in out)
    priced = [x for x in out if x["excess_usd"] > 0]
    json.dump({"block": BLOCK, "total_flagged": len(src.get("flagged_excess", [])),
               "priced_total_usd": total, "priced": out},
              open(os.path.join(OUT, "flagged_excess_priced.json"), "w"), indent=1)
    print(f"TOTAL skim-able excess USD (priced tokens only): ${total:.2f} across {len(priced)} pairs")
    for x in out[:25]:
        print(f"  {x['pair']} {x['label']} {x['sym0']}/{x['sym1']} "
              f"ex0={x['ex0']} ex1={x['ex1']} usd={x['excess_usd']:.2f} skim={x['skim_sim_ok']}")


if __name__ == "__main__":
    main()
