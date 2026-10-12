#!/usr/bin/env python3
"""Full BlueMove pool+escrow enumeration via public Sui JSON-RPC (sui-rpc.publicnode.com).
Read-only. Outputs full_state.json (+ summary print). Threaded; no batching on this endpoint.
"""
import json, time, urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

URLS = [
    "https://sui-mainnet-endpoint.blockvision.org",
    "https://sui.publicnode.com",
    "https://sui-rpc.publicnode.com",
]
URL = URLS[0]
UA = {"User-Agent": "Mozilla/5.0 (research; bluemove-phase2)", "Content-Type": "application/json"}
_ep_i = [0]

def _next_url():
    _ep_i[0] = (_ep_i[0] + 1) % len(URLS)
    return URLS[_ep_i[0]]
AMM = "0x3f2d9f724f4a1ce5e71676448dc452be9a6243dac9c5b975a588c8c867066e92"
SUI = "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI"
USDC = "0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC"
USDT = "0xc060006111016b8a020ad5b33834984a437aaa7d3c74c18e09a95d48aceab08c::coin::COIN"
WETH = "0xaf8cd5edc19c4512f4259f0bee101a40d41ebed738ade587435961f5450fe45::coin::COIN"
MAJ = {SUI: ("SUI", 9, 1.10), USDC: ("USDC", 6, 1.0), USDT: ("USDT", 6, 1.0), WETH: ("WETH", 8, 3000.0)}

def rpc(method, params, timeout=45, retries=18):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for i in range(retries):
        url = URLS[i % len(URLS)]
        try:
            req = urllib.request.Request(url, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read())
            if "error" in d:
                last = d["error"]
                if "rate" in str(d["error"]).lower() or "limit" in str(d["error"]).lower():
                    time.sleep(min(20, 1.5 * (i + 1))); continue
                raise RuntimeError(str(d["error"])[:200])
            return d.get("result")
        except urllib.error.HTTPError as e:
            last = e
            if e.code in (429, 502, 503, 504):
                time.sleep(min(20, 2.0 * (i + 1))); continue
            time.sleep(1.0 * (i + 1))
        except Exception as e:
            last = e
            time.sleep(0.8 * (i + 1))
    raise RuntimeError(f"rpc failed: {last}")

def usd(amt, tok):
    if tok in MAJ:
        _, d, p = MAJ[tok]
        return amt / 10**d * p
    return 0.0

def main():
    t0 = time.time()
    ck = rpc("sui_getLatestCheckpointSequenceNumber", [])
    print("checkpoint:", ck, flush=True)
    # 1. page registry fields (checkpointed)
    import os
    pools, other = [], []
    if os.path.exists("pools_ckpt.json"):
        j = json.load(open("pools_ckpt.json"))
        pools, other = j["pools"], j["other"]
        print(f"resume pools: {len(pools)}", flush=True)
    else:
        cursor = None
        while True:
            res = rpc("suix_getDynamicFields", [AMM, cursor, 50])
            for n in res.get("data", []):
                name = (n.get("name") or {})
                otype = n.get("objectType") or ""
                if "::swap::Pool<" in otype:
                    pools.append({"addr": n["objectId"], "name": name.get("value"), "type": otype,
                                  "version": n.get("version"), "digest": n.get("digest")})
                else:
                    other.append({"name": name.get("value"), "objectType": otype, "objectId": n.get("objectId")})
            if not res.get("hasNextPage"):
                break
            cursor = res.get("nextCursor")
        json.dump({"pools": pools, "other": other}, open("pools_ckpt.json", "w"))
    print(f"pools: {len(pools)}, other: {other}", flush=True)

    # 2. batched contents of pool objects
    def fetch_contents(ids):
        return rpc("sui_multiGetObjects", [ids, {"showContent": True, "showType": True}])
    batches = [pools[i:i+50] for i in range(0, len(pools), 50)]
    contents = {}
    with ThreadPoolExecutor(max_workers=12) as ex:
        futs = {ex.submit(fetch_contents, [p["addr"] for p in b]): b for b in batches}
        done = 0
        for f in as_completed(futs):
            try:
                objs = f.result() or []
                for o in objs:
                    d = (o or {}).get("data") or {}
                    c = (d.get("content") or {})
                    contents[d.get("objectId")] = {"type": c.get("type"), "fields": c.get("fields"), "ver": d.get("version")}
            except Exception as e:
                print("  content batch err", str(e)[:120], flush=True)
            done += 1
            if done % 50 == 0:
                print(f"  contents {done}/{len(batches)} t={time.time()-t0:.0f}s", flush=True)

    # 3. per-pool dynamic fields (escrows) — resumable
    import os
    ckpt = "dynfields_ckpt.json"
    esc_ids = {}
    if os.path.exists(ckpt):
        try:
            esc_ids = json.load(open(ckpt))
            print(f"resume: {len(esc_ids)} pools already done", flush=True)
        except Exception:
            esc_ids = {}
    def fetch_pool_dyn(pid):
        try:
            res = rpc("suix_getDynamicFields", [pid, None, 10], retries=10)
            esc = []
            for n in res.get("data", []):
                ot = n.get("objectType") or ""
                if "EscownCoins" in ot: esc.append(("vmid", n["objectId"]))
                elif "EscrowCoinsV2" in ot: esc.append(("v2", n["objectId"]))
            return pid, esc
        except Exception as e:
            return pid, [("err", str(e)[:80])]
    todo = [p for p in pools if p["addr"] not in esc_ids]
    print(f"dynfields todo: {len(todo)}", flush=True)
    with ThreadPoolExecutor(max_workers=8) as ex:
        futs = {ex.submit(fetch_pool_dyn, p["addr"]): p for p in todo}
        done = 0
        for f in as_completed(futs):
            pid, esc = f.result()
            esc_ids[pid] = esc
            done += 1
            if done % 1000 == 0:
                print(f"  dynfields {done}/{len(todo)} t={time.time()-t0:.0f}s", flush=True)
                json.dump(esc_ids, open(ckpt, "w"))

    # 4. escrow contents
    all_esc = [(pid, kind, oid) for pid, lst in esc_ids.items() for (kind, oid) in lst if kind in ("vmid", "v2")]
    def fetch_esc(ids):
        return rpc("sui_multiGetObjects", [ids, {"showContent": True, "showType": True}])
    eb = [all_esc[i:i+50] for i in range(0, len(all_esc), 50)]
    esc_data = {}
    with ThreadPoolExecutor(max_workers=12) as ex:
        futs = {ex.submit(fetch_esc, [x[2] for x in b]): b for b in eb}
        for f in as_completed(futs):
            try:
                objs = f.result() or []
                for o in objs:
                    d = (o or {}).get("data") or {}
                    c = (d.get("content") or {})
                    esc_data[d.get("objectId")] = c.get("fields")
            except Exception as e:
                print("  escrow batch err", str(e)[:120], flush=True)
    print(f"escrow objects: {len(all_esc)}, fetched: {len(esc_data)} t={time.time()-t0:.0f}s", flush=True)

    # 5. aggregate
    agg = {"T": 0.0, "EM": 0.0, "E2": 0.0, "r": 0.0, "fees": 0.0, "T_SUI": 0, "r_SUI": 0}
    counts = {"total": len(pools), "frozen": 0, "vmid": 0, "v2": 0, "both": 0, "none": 0,
              "v2_extractable": 0, "t_extractable": 0, "lp_burn_zero_usd": 0.0}
    ex_pools = []
    rows = []
    for p in pools:
        f = (contents.get(p["addr"]) or {}).get("fields") or {}
        if not f:
            continue
        T = (int(f.get("token_x") or 0), int(f.get("token_y") or 0))
        r = (int(f.get("reserve_x") or 0), int(f.get("reserve_y") or 0))
        S = int((f.get("lsp_supply") or {}).get("value") or 0)
        freeze = bool(f.get("is_freeze"))
        EM = (0, 0); E2 = (0, 0)
        for kind, oid in esc_ids.get(p["addr"], []):
            ef = esc_data.get(oid) or {}
            if kind == "vmid":
                EM = (int(ef.get("token_x") or 0), int(ef.get("token_y") or 0)); counts["vmid"] += 1
            elif kind == "v2":
                E2 = (int(ef.get("token_x") or 0), int(ef.get("token_y") or 0)); counts["v2"] += 1
        if EM != (0, 0) and E2 != (0, 0): counts["both"] += 1
        elif EM == (0, 0) and E2 == (0, 0): counts["none"] += 1
        if freeze: counts["frozen"] += 1
        inner = p["type"].split("<", 1)[1].rstrip(">")
        tok0, tok1 = [x.strip() for x in inner.split(",", 1)]
        ok = (not freeze) and S > 0 and r[0] > 0 and r[1] > 0
        v2x = ok and E2[0] > r[0] and E2[1] > r[1]
        tx = ok and T[0] > r[0] and T[1] > r[1]
        if v2x: counts["v2_extractable"] += 1; ex_pools.append({"addr": p["addr"], "kind": "v2", "E2": E2, "r": r, "T": T})
        if tx: counts["t_extractable"] += 1; ex_pools.append({"addr": p["addr"], "kind": "T", "T": T, "r": r})
        agg["T"] += usd(T[0], tok0) + usd(T[1], tok1)
        agg["EM"] += usd(EM[0], tok0) + usd(EM[1], tok1)
        agg["E2"] += usd(E2[0], tok0) + usd(E2[1], tok1)
        agg["r"] += usd(r[0], tok0) + usd(r[1], tok1)
        agg["fees"] += usd(int(f.get("fee_x") or 0), tok0) + usd(int(f.get("fee_y") or 0), tok1)
        if tok0 == SUI: agg["T_SUI"] += T[0]; agg["r_SUI"] += r[0]
        if tok1 == SUI: agg["T_SUI"] += T[1]; agg["r_SUI"] += r[1]
        rows.append({"addr": p["addr"], "t0": tok0, "t1": tok1, "T": T, "r": r, "EM": EM, "E2": E2, "S": S,
                     "freeze": freeze, "v2_extractable": v2x, "t_extractable": tx,
                     "usd": round(usd(T[0], tok0)+usd(T[1], tok1)+usd(EM[0], tok0)+usd(EM[1], tok1)+usd(E2[0], tok0)+usd(E2[1], tok1), 2)})
    state = {"generated_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "checkpoint": ck,
             "counts": counts, "usd_totals": {k: round(v, 2) for k, v in agg.items()},
             "extractable_pools": ex_pools[:100], "pools": rows}
    json.dump(state, open("full_state_rpc.json", "w"))
    print(json.dumps({"checkpoint": ck, "counts": counts, "usd_totals": state["usd_totals"]}, indent=1), flush=True)
    print(f"WROTE full_state_rpc.json t={time.time()-t0:.0f}s", flush=True)

if __name__ == "__main__":
    main()
