#!/usr/bin/env python3
"""Decode raw batchSwap calldata (A) and correlate with receipt Swap events (B)."""
import json, csv

ASSET_NAMES = {
    "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2": "WETH",
    "0xdacf5fa19b1f720111609043ac67a9818262850c": "BPT_osETH-WETH",
    "0xf1c9acdc66974dfb6decb12aa385b9cd01190e38": "osETH",
    "0x93d199263632a4ef4bb438f1feb99e57b4b5f0bd": "BPT_wstETH-WETH",
    "0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0": "wstETH",
}

def word(hexstr, i):
    # 2 chars "0x" + 8 chars selector = ABI body starts at index 10
    return int(hexstr[10 + i * 64: 10 + (i + 1) * 64], 16)

def decode_batch_swap(path):
    h = open(path).read().strip()
    assert h.startswith("0x945bcec9"), h[:12]
    kind = word(h, 0)
    off_steps, off_assets = word(h, 1), word(h, 2)
    deadline = word(h, 8)
    # steps: dynamic array of dynamic tuples (BatchSwapStep contains bytes userData)
    arr = 10 + off_steps * 2
    n = int(h[arr:arr + 64], 16)
    elems_base = arr + 64  # offsets are relative to here
    steps = []
    for i in range(n):
        elem_off = int(h[elems_base + i * 64: elems_base + (i + 1) * 64], 16)
        p = elems_base + elem_off * 2
        pool_id = h[p:p + 64]
        a_in = int(h[p + 64:p + 128], 16)
        a_out = int(h[p + 128:p + 192], 16)
        amount = int(h[p + 192:p + 256], 16)
        steps.append({"poolId": pool_id, "in": a_in, "out": a_out, "amount": amount})
    # assets array
    base = 10 + off_assets * 2
    n_assets = int(h[base:base + 64], 16)
    assets = ["0x" + h[base + 64 + i * 64 + 24: base + 64 + (i + 1) * 64].lower() for i in range(n_assets)]
    return kind, steps, assets, deadline

def parse_swap_events(path):
    receipt = json.load(open(path))
    SWAP = "0x2170c741c41531aec20e7c107c24eecfdd15e69c9bb0a8dd37b1840b9e0b207b"
    evs = []
    for log in receipt["logs"]:
        if log["topics"][0] != SWAP:
            continue
        data = log["data"][2:]
        evs.append({
            "poolId": log["topics"][1].lower(),
            "tokenIn": "0x" + log["topics"][2][-40:],
            "tokenOut": "0x" + log["topics"][3][-40:],
            "amountIn": int(data[0:64], 16),
            "amountOut": int(data[64:128], 16),
        })
    return evs

def fmt(x):
    return f"{x/1e18:,.6f}"

def classify(r):
    if r["tokenIn"].startswith("BPT"):
        return "BPT_OUT(exitSwap)"
    if r["tokenOut"].startswith("BPT"):
        return "BPT_IN(joinSwap)"
    return "regular"

rows = []
evs = parse_swap_events("receipt-deploy-raw.json")
ei = 0
for b, path in enumerate(["bs1.hex", "bs2.hex"], start=1):
    kind, steps, assets, deadline = decode_batch_swap(path)
    net = {}
    print(f"BS{b}: kind={kind} (1=GIVEN_OUT) steps={len(steps)} deadline={deadline}")
    print(f"  assets = {[ASSET_NAMES.get(a,a) for a in assets]}")
    for i, s in enumerate(steps):
        ev = evs[ei + i]
        assert s["poolId"] == ev["poolId"][2:]
        tin, tout = ev["tokenIn"], ev["tokenOut"]
        declared_in, declared_out = assets[s["in"]], assets[s["out"]]
        match = (declared_in == tin and declared_out == tout)
        rows.append({
            "batch": b, "idx": i, "declaredIn": ASSET_NAMES.get(declared_in, declared_in),
            "declaredOut": ASSET_NAMES.get(declared_out, declared_out),
            "exactAmountOut": s["amount"], "tokenIn": ASSET_NAMES.get(tin, tin),
            "tokenOut": ASSET_NAMES.get(tout, tout), "amountIn": ev["amountIn"], "amountOut": ev["amountOut"],
            "match": match,
        })
        net[tin] = net.get(tin, 0) - ev["amountIn"]
        net[tout] = net.get(tout, 0) + ev["amountOut"]
    ei += len(steps)
    print(f"  net attacker: " + ", ".join(f"{ASSET_NAMES.get(k,k)}={fmt(v)}" for k, v in net.items()))
    phases = {}
    for r in rows:
        if r["batch"] != b:
            continue
        phases[classify(r)] = phases.get(classify(r), 0) + 1
    print(f"  phases: {phases}")

print(f"\nTotal steps={len(rows)}, swap events={len(evs)}, mismatches={sum(1 for r in rows if not r['match'])}")

with open("steps-correlated.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    w.writeheader()
    w.writerows(rows)

for b in (1, 2):
    r = [x for x in rows if x["batch"] == b]
    print(f"\n=== BS{b} first 24 steps ===")
    for x in r[:24]:
        print(f"{x['idx']:3d} {x['declaredIn']:>18} -> {x['declaredOut']:<18} exactOut={x['exactAmountOut']:<24} in={x['amountIn']:<24} out={x['amountOut']}")
    print(f"=== BS{b} last 12 steps ===")
    for x in r[-12:]:
        print(f"{x['idx']:3d} {x['declaredIn']:>18} -> {x['declaredOut']:<18} exactOut={x['exactAmountOut']:<24} in={x['amountIn']:<24} out={x['amountOut']}")

# triplet analysis for BS1 and BS2: find the critical small-outs (17) and neighbors
for b in (1, 2):
    r = [x for x in rows if x["batch"] == b]
    crit = [x for x in r if x["exactAmountOut"] == 17]
    print(f"\nBS{b}: critical exactOut==17 swaps: {len(crit)}")
    for x in crit:
        j = r.index(x)
        nxt = r[j + 1]
        print(f"  idx {x['idx']}: {x['declaredIn']}->{x['declaredOut']} out=17 actualIn={x['amountIn']} | next: {nxt['declaredIn']}->{nxt['declaredOut']} out={nxt['exactAmountOut']}")
