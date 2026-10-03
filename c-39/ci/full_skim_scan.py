#!/usr/bin/env python3
"""C-39 heavy job: system-wide PulseX V1+V2 pair scan.

For every pair deployed by both factories, compare live token balances against stored
reserves. balance > reserve on BOTH sides (or one side, other >=) => anyone can call
skim() and take the excess. Also records balance < reserve (FOT/rebasing candidates)
and feeTo LP holdings.

Uses Multicall3 (0xcA11bde05977b3631167028862bE2a173976CA11) aggregate3 with
allowFailure=true. Output: ci-out/skim_scan_full.json
"""
import json, os, sys, time, urllib.request

RPC = os.environ.get("PULSECHAIN_RPC") or "https://pulsechain-rpc.publicnode.com"
MC3 = "0xcA11bde05977b3631167028862bE2a173976CA11"
OUTDIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ci-out")
os.makedirs(OUTDIR, exist_ok=True)

V1 = {"factory": "0x1715a3E4A142d8b698131108995174F37aEBA10D",
      "feeTo": "0xD46BD969d995A122AD5B803A45d309021A647B87"}
V2 = {"factory": "0x29eA7545DEf87022BAdc76323F373EA1e707C523",
      "feeTo": "0xd6cA7ee047a6F45d20d2962E4394E070cF27724F"}

SEL_GETRESERVES = "0x0902f1ac"
SEL_TOKEN0 = "0x0dfe1681"
SEL_TOKEN1 = "0xd21220a7"
SEL_BALANCE_OF = "0x70a08231"
SEL_ALL_PAIRS = "0x1e3dd18b"  # allPairs(uint256)
SEL_ALL_PAIRS_LEN = "0x574f2ba3"  # allPairsLength()
SEL_AGG3 = "0x82ad56cb"       # aggregate3((address,bool,bytes)[])

BATCH = int(os.environ.get("MC3_BATCH", "500"))


def word(n):
    return n.to_bytes(32, "big")


def enc_addr(a):
    return bytes.fromhex(a.lower().replace("0x", "").rjust(64, "0"))


def enc_aggregate3(calls):
    n = len(calls)
    tuple_datas = []
    for (t, af, d) in calls:
        b = bytes.fromhex(d[2:])
        td = enc_addr(t) + word(1 if af else 0) + word(96) + word(len(b)) + b + b"\x00" * ((32 - len(b) % 32) % 32)
        tuple_datas.append(td)
    offsets = []
    cur = 32 * n
    for td in tuple_datas:
        offsets.append(cur)
        cur += len(td)
    section = word(n) + b"".join(word(o) for o in offsets) + b"".join(tuple_datas)
    return SEL_AGG3 + word(32).hex() + section.hex()


def dec_results(hexstr):
    """Decode Result[] = (bool,bytes)[] returned by Multicall3.aggregate3."""
    if not hexstr or hexstr == "0x":
        return []
    raw = bytes.fromhex(hexstr[2:])
    if len(raw) < 64:
        return []
    off = int.from_bytes(raw[0:32], "big")
    if off + 32 > len(raw):
        return []
    n = int.from_bytes(raw[off:off + 32], "big")
    out = []
    base = off + 32
    for i in range(n):
        if base + 32 * (i + 1) > len(raw):
            break
        o = int.from_bytes(raw[base + 32 * i: base + 32 * (i + 1)], "big")
        p = base + o
        if p + 64 > len(raw):
            out.append((False, None))
            continue
        success = int.from_bytes(raw[p:p + 32], "big") == 1
        boff = int.from_bytes(raw[p + 32:p + 64], "big")
        bp = p + boff
        if bp + 32 > len(raw):
            out.append((success, None))
            continue
        ln = int.from_bytes(raw[bp:bp + 32], "big")
        out.append((success, raw[bp + 32:bp + 32 + ln]))
    return out


def rpc_batch(payload, retries=5):
    # normalize ids to positional 0..n-1
    for i, item in enumerate(payload):
        item["id"] = i
    data = json.dumps(payload).encode()
    for a in range(retries):
        try:
            req = urllib.request.Request(RPC, data=data,
                                         headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=180) as r:
                res = json.loads(r.read())
            out = [None] * len(payload)
            for item in res:
                if isinstance(item.get("id"), int) and 0 <= item["id"] < len(payload):
                    out[item["id"]] = item
            return out
        except Exception as e:
            sys.stderr.write(f"rpc retry {a}: {e}\n")
            sys.stderr.flush()
            time.sleep(2 * (a + 1))
    return [None] * len(payload)


BLOCK = None


def eth_call(to, data):
    tag = hex(BLOCK) if BLOCK else "latest"
    return {"jsonrpc": "2.0", "id": 0, "method": "eth_call", "params": [{"to": to, "data": data}, tag]}


def call_agg(calls, tag=""):
    """Run one aggregate3 call. Returns list of result bytes (None if sub-call failed)."""
    data = enc_aggregate3(calls)
    res = rpc_batch([{"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                      "params": [{"to": MC3, "data": data}, hex(BLOCK) if BLOCK else "latest"]}])[0]
    if not res or "result" not in res:
        sys.stderr.write(f"agg fail {tag}: {str(res)[:200]}\n")
        return [None] * len(calls)
    results = dec_results(res["result"])
    out = []
    for i in range(len(calls)):
        if i < len(results):
            ok, b = results[i]
            out.append(b if ok else None)
        else:
            out.append(None)
    return out


def run_subcalls(subcalls, tag, batch=BATCH, http_group=4):
    """subcalls: list of (target, allowFailure, calldata). Returns results list.

    Groups several aggregate3 eth_calls into one HTTP JSON-RPC batch to cut round trips.
    """
    out = []
    t0 = time.time()
    chunks = [subcalls[i:i + batch] for i in range(0, len(subcalls), batch)]
    for gi in range(0, len(chunks), http_group):
        group = chunks[gi:gi + http_group]
        payload = []
        for chunk in group:
            data = enc_aggregate3(chunk)
            payload.append({"jsonrpc": "2.0", "id": 0, "method": "eth_call",
                            "params": [{"to": MC3, "data": data},
                                       hex(BLOCK) if BLOCK else "latest"]})
        responses = rpc_batch(payload)
        for ci, chunk in enumerate(group):
            res = responses[ci]
            if not res or "result" not in res:
                sys.stderr.write(f"agg fail {tag} chunk {gi+ci}: {str(res)[:160]}\n")
                out.extend([None] * len(chunk))
                continue
            results = dec_results(res["result"])
            for i in range(len(chunk)):
                if i < len(results):
                    ok, b = results[i]
                    out.append(b if ok else None)
                else:
                    out.append(None)
        if (gi % (http_group * 20)) == 0:
            print(f"[{tag}] {gi*batch}/{len(subcalls)} ({time.time()-t0:.0f}s)", flush=True)
        time.sleep(0.05)
    return out


def block_number():
    res = rpc_batch([{"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}])[0]
    return int(res["result"], 16)


def get_all_pairs(factory):
    res = rpc_batch([eth_call(factory, SEL_ALL_PAIRS_LEN)])[0]
    n = int(res["result"], 16)
    print(f"factory {factory}: allPairsLength={n}", flush=True)
    limit = int(os.environ.get("PAIR_LIMIT", "0"))
    if limit > 0:
        n = min(n, limit)
    subs = []
    for i in range(n):
        subs.append((factory, True, SEL_ALL_PAIRS + word(i).hex()))
    outs = run_subcalls(subs, "allPairs")
    pairs = []
    for i, o in enumerate(outs):
        if o and len(o) >= 32:
            pairs.append("0x" + o[12:32].hex())
    print(f"  got {len(pairs)} pair addresses", flush=True)
    return pairs


def main():
    global BLOCK
    blk = block_number()
    BLOCK = blk
    print("pinned block", blk, flush=True)
    summary = {"block": blk, "factories": {}, "flagged_excess": [], "flagged_deficit": [],
               "stats": {}}
    all_pairs = {}
    for label, cfg in (("v1", V1), ("v2", V2)):
        pairs = get_all_pairs(cfg["factory"])
        all_pairs[label] = pairs
        summary["factories"][label] = {"factory": cfg["factory"], "feeTo": cfg["feeTo"],
                                       "allPairsLength": len(pairs)}
    # pass 2: reserves + tokens
    subs = []
    meta = []
    for label, pairs in all_pairs.items():
        for p in pairs:
            meta.append((label, p))
            subs.append((p, True, SEL_GETRESERVES))
            subs.append((p, True, SEL_TOKEN0))
            subs.append((p, True, SEL_TOKEN1))
    print("pass2 subcalls:", len(subs), flush=True)
    outs = run_subcalls(subs, "reserves")
    recs = []
    for i, (label, p) in enumerate(meta):
        r, t0, t1 = outs[3 * i], outs[3 * i + 1], outs[3 * i + 2]
        if not r or len(r) < 96 or not t0 or not t1:
            continue
        rec = {
            "label": label, "pair": p,
            "r0": int.from_bytes(r[0:32], "big"),
            "r1": int.from_bytes(r[32:64], "big"),
            "t0": "0x" + t0[12:32].hex(),
            "t1": "0x" + t1[12:32].hex(),
        }
        recs.append(rec)
    print("resolved pairs:", len(recs), flush=True)
    # pass 3: balances + feeTo LP
    subs = []
    idx = []
    for j, rec in enumerate(recs):
        subs.append((rec["t0"], True, SEL_BALANCE_OF + enc_addr(rec["pair"]).hex()))
        subs.append((rec["t1"], True, SEL_BALANCE_OF + enc_addr(rec["pair"]).hex()))
        fe = V1["feeTo"] if rec["label"] == "v1" else V2["feeTo"]
        subs.append((rec["pair"], True, SEL_BALANCE_OF + enc_addr(fe).hex()))
        idx.append(j)
    print("pass3 subcalls:", len(subs), flush=True)
    outs = run_subcalls(subs, "balances")
    n_excess = n_deficit = 0
    for j, rec in enumerate(recs):
        b0, b1, fee_lp = outs[3 * j], outs[3 * j + 1], outs[3 * j + 2]
        if not b0 or not b1:
            continue
        rec["b0"] = int.from_bytes(b0[0:32], "big") if len(b0) >= 32 else None
        rec["b1"] = int.from_bytes(b1[0:32], "big") if len(b1) >= 32 else None
        rec["feeToLP"] = int.from_bytes(fee_lp[0:32], "big") if fee_lp and len(fee_lp) >= 32 else None
        if rec["b0"] is None or rec["b1"] is None:
            continue
        rec["ex0"] = rec["b0"] - rec["r0"]
        rec["ex1"] = rec["b1"] - rec["r1"]
        if rec["ex0"] > 0 or rec["ex1"] > 0:
            n_excess += 1
            if rec["ex0"] >= 0 and rec["ex1"] >= 0:
                summary["flagged_excess"].append(rec)
        if rec["ex0"] < 0 or rec["ex1"] < 0:
            n_deficit += 1
            summary["flagged_deficit"].append(rec)
    summary["stats"] = {
        "pairs_total": len(recs),
        "pairs_with_excess": n_excess,
        "pairs_skim_able": len(summary["flagged_excess"]),
        "pairs_with_deficit": n_deficit,
        "feeTo_lp_pairs": sum(1 for r in recs if (r.get("feeToLP") or 0) > 0),
    }
    # sort flagged by max excess (raw units; USD needs prices)
    summary["flagged_excess"].sort(key=lambda r: max(r["ex0"], r["ex1"]), reverse=True)
    summary["flagged_deficit"].sort(key=lambda r: min(r["ex0"], r["ex1"]))
    json.dump(summary, open(os.path.join(OUTDIR, "skim_scan_full.json"), "w"), indent=1)
    print("STATS", json.dumps(summary["stats"]), flush=True)
    print("top excess (raw units):", flush=True)
    for r in summary["flagged_excess"][:20]:
        print(" ", r["pair"], r["label"], "ex0=", r["ex0"], "ex1=", r["ex1"], flush=True)
    print("top deficit (raw units):", flush=True)
    for r in summary["flagged_deficit"][:10]:
        print(" ", r["pair"], r["label"], "ex0=", r["ex0"], "ex1=", r["ex1"], flush=True)


if __name__ == "__main__":
    main()
