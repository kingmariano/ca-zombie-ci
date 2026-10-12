#!/usr/bin/env python3
"""Fetch escrows for a pool subset and analyze attackability (local sample tool)."""
import json, random, sys, time
from concurrent.futures import ThreadPoolExecutor
from sui import dynamic_fields

SUI = "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI"
USDC = "0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC"
USDT = "0xc060006111016b8a020ad5b33834984a437aaa7d3c74c18e09a95d48aceab08c::coin::COIN"
WETH = "0xaf8cd5edc19c4512f4259f0bee101a40d41ebed738ade587435961f5450fe45::coin::COIN"
MAJ = {SUI: ("SUI", 9, 1.0), USDC: ("USDC", 6, 1.0), USDT: ("USDT", 6, 1.0), WETH: ("WETH", 8, 3000.0)}

def usd(amt, tok):
    if tok in MAJ:
        _, d, pr = MAJ[tok]
        return amt / 10**d * pr
    return 0.0

def fetch_escrow(pool_addr):
    res = {"vmid": None, "v2": None, "error": None}
    for attempt in range(3):
        try:
            df = dynamic_fields(pool_addr, first=5)
            for n in df.get("nodes") or []:
                v = n.get("value") or {}
                if not isinstance(v, dict):
                    continue
                c = v.get("contents") or {}
                if not isinstance(c, dict):
                    continue
                t = ((c.get("type") or {}).get("repr")) or ""
                j = c.get("json") or {}
                if "::swap::EscownCoins<" in t:
                    res["vmid"] = {"addr": v.get("address"), "x": int(j.get("token_x") or 0), "y": int(j.get("token_y") or 0)}
                elif "::swap::EscrowCoinsV2<" in t:
                    res["v2"] = {"addr": v.get("address"), "x": int(j.get("token_x") or 0), "y": int(j.get("token_y") or 0)}
            return res
        except Exception as e:
            res["error"] = str(e)[:150]
            time.sleep(1.0 * (attempt + 1))
    return res

def analyze(p, esc):
    T = (p["token_x"], p["token_y"]); r = (p["reserve_x"], p["reserve_y"])
    E2 = (esc["v2"]["x"], esc["v2"]["y"]) if esc.get("v2") else (0, 0)
    EM = (esc["vmid"]["x"], esc["vmid"]["y"]) if esc.get("vmid") else (0, 0)
    S = p["lsp_supply"]
    out = {"T": T, "r": r, "E2": E2, "EM": EM, "S": S}
    # last writer guess
    if r == T: lw = "V1"
    elif r == E2 and (E2 != (0,0)): lw = "vlatest"
    elif r == EM and (EM != (0,0)): lw = "vmid"
    else: lw = "?"
    out["last_writer"] = lw
    # inflation conditions (strict, ignoring small deposits):
    # vlatest mint inflates if E2 > r on both sides, r>0 both, S>0
    out["v2_drainable"] = (E2[0] > r[0] and E2[1] > r[1] and r[0] > 0 and r[1] > 0 and S > 0 and E2[0] > 0 and E2[1] > 0)
    # v1 mint inflates if T > r on both sides
    out["v1_drainable"] = (T[0] > r[0] and T[1] > r[1] and r[0] > 0 and r[1] > 0 and S > 0 and T[0] > 0 and T[1] > 0)
    # value of each store in USD (majors only)
    out["usd_E2"] = usd(E2[0], p["t0"]) + usd(E2[1], p["t1"])
    out["usd_EM"] = usd(EM[0], p["t0"]) + usd(EM[1], p["t1"])
    out["usd_T"] = usd(T[0], p["t0"]) + usd(T[1], p["t1"])
    out["usd_r"] = usd(r[0], p["t0"]) + usd(r[1], p["t1"])
    return out

def main():
    pools = json.load(open("pools_parsed.json"))
    def sui_res(p):
        v = 0
        if p["t0"] == SUI: v += p["reserve_x"]
        if p["t1"] == SUI: v += p["reserve_y"]
        return v
    def maj_res(p):
        return usd(p["reserve_x"], p["t0"]) + usd(p["reserve_y"], p["t1"])
    top = sorted(pools, key=lambda p: max(sui_res(p), maj_res(p)), reverse=True)[:300]
    rnd = random.Random(7).sample([p for p in pools if p not in top], 300)
    sample = top + rnd
    print(f"sample size: {len(sample)}", flush=True)
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=10) as ex:
        escs = list(ex.map(lambda p: fetch_escrow(p["addr"]), sample))
    print(f"fetched {len(escs)} in {time.time()-t0:.0f}s", flush=True)
    rows = []
    for p, e in zip(sample, escs):
        a = analyze(p, e)
        a["addr"] = p["addr"]; a["name"] = p["name"]; a["t0"] = p["t0"]; a["t1"] = p["t1"]
        a["esc_error"] = e.get("error")
        rows.append(a)
    json.dump(rows, open("escrow_sample.json", "w"), indent=1)

    n_v2 = sum(1 for a in rows if a["v2_drainable"])
    n_v1 = sum(1 for a in rows if a["v1_drainable"])
    tot_E2 = sum(a["usd_E2"] for a in rows)
    tot_EM = sum(a["usd_EM"] for a in rows)
    tot_T = sum(a["usd_T"] for a in rows)
    tot_r = sum(a["usd_r"] for a in rows)
    v2_usd = sum(a["usd_E2"] for a in rows if a["v2_drainable"])
    v1_usd = sum(a["usd_T"] for a in rows if a["v1_drainable"])
    print(f"\n== sample summary (n={len(rows)}) ==")
    print(f"v2_drainable pools: {n_v2}  (escrow USD in those: ${v2_usd:,.2f})")
    print(f"v1_drainable pools: {n_v1}  (T store USD in those: ${v1_usd:,.2f})")
    print(f"totals: E2=${tot_E2:,.2f} EM(vmid)=${tot_EM:,.2f} T=${tot_T:,.2f} reserves=${tot_r:,.2f}")
    from collections import Counter
    print("last_writer:", Counter(a["last_writer"] for a in rows))
    print("has v2 escrow:", sum(1 for a in rows if a["E2"] != (0,0)), " has vmid escrow:", sum(1 for a in rows if a["EM"] != (0,0)))
    print("\n== top v2_drainable by escrow USD ==")
    for a in sorted([x for x in rows if x["v2_drainable"]], key=lambda x: -x["usd_E2"])[:20]:
        print(f"  ${a['usd_E2']:9.2f} E2={a['E2']} r={a['r']} T={a['T']} S={a['S']} {a['addr'][:16]} lw={a['last_writer']}")
        print(f"      t0={a['t0'][:64]}")
        print(f"      t1={a['t1'][:64]}")

if __name__ == "__main__":
    main()
