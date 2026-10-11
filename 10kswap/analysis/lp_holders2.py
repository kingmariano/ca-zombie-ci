#!/usr/bin/env python3
"""LP holder reconstruction v2 — key-filtered Transfer-only scan (publicnode), streaming
and memory-safe. Also counts Mint/Burn events and finds their last blocks.
Writes analysis/lp_holders.json (v2).
"""
import json, sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sn

D = os.path.dirname(os.path.abspath(__file__))
URLS = ["https://starknet-rpc.publicnode.com", "https://api.cartridge.gg/x/starknet/mainnet"]
SEL = {n: sn.selector(n) for n in ("Transfer", "Mint", "Burn")}


def scan(addr, sel, chunk=5000, cap=500):
    """Streaming paginated scan; yields event lists."""
    tok = None
    pages = 0
    while True:
        filt = {"from_block": {"block_number": 0}, "to_block": {"block_number": 99999999},
                "address": addr, "keys": [[sel]], "chunk_size": chunk}
        if tok:
            filt["continuation_token"] = tok
        last = None
        for attempt in range(5):
            try:
                r = sn.rpc("starknet_getEvents", {"filter": filt}, urls=URLS, timeout=120)
                break
            except Exception as e:
                last = str(e)[:160]
                time.sleep(1.5 * (attempt + 1))
        else:
            raise RuntimeError(f"scan failed for {addr[:12]} sel {sel[:10]}: {last}")
        evs = r.get("events", [])
        tok = r.get("continuation_token")
        pages += 1
        if pages % 10 == 0 or not tok:
            print(f"    [{addr[:10]} {sel[:8]}] page {pages}, {len(evs)} ev, tok={'y' if tok else 'n'}", flush=True)
        yield evs
        if not tok or pages >= cap:
            return


def main():
    r1 = json.load(open(os.path.join(D, "recon1.json")))
    pairs = r1["pairs"]
    blk = sn.rpc("starknet_blockNumber", [], urls=URLS)
    out = {"block": blk, "pairs": {}}
    for p in pairs:
        bal = {}
        n_tr = 0
        for evs in scan(p, SEL["Transfer"]):
            for e in evs:
                d = [int(x, 16) for x in e["data"]]
                frm, to = d[0], d[1]
                val = d[2] + (d[3] << 128) if len(d) >= 4 else d[2]
                if frm == to:
                    continue
                if frm != 0:
                    bal[frm] = bal.get(frm, 0) - val
                if to != 0:
                    bal[to] = bal.get(to, 0) + val
                n_tr += 1
        holders = {hex(k): v for k, v in bal.items() if v > 0}
        rec = {"transfer_events": n_tr,
               "holders": dict(sorted(holders.items(), key=lambda x: -x[1])),
               "holder_count": len(holders)}
        for name in ("Mint", "Burn"):
            cnt = 0; lastb = 0; firstb = 10**9
            for evs in scan(p, SEL[name]):
                for e in evs:
                    cnt += 1
                    b = int(e["block_number"])
                    lastb = max(lastb, b); firstb = min(firstb, b)
            rec[name.lower() + "_events"] = cnt
            if cnt:
                rec[name.lower() + "_last_block"] = lastb
                rec[name.lower() + "_first_block"] = firstb
        out["pairs"][p] = rec
        print(f"{p[:14]} transfers={n_tr} holders={rec['holder_count']} "
              f"mint={rec['mint_events']} (last {rec.get('mint_last_block')}) "
              f"burn={rec['burn_events']} (last {rec.get('burn_last_block')})", flush=True)
    with open(os.path.join(D, "lp_holders.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("wrote lp_holders.json", flush=True)


if __name__ == "__main__":
    main()
