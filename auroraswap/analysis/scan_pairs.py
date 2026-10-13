#!/usr/bin/env python3
"""Read-only scan of the AuroraSwap (Aurora) UniV2 factory and all pairs.

Keyless public RPC only (override with AURORA_RPC env). No transactions.
Outputs: pairs_scan.json  (reserves, balances, excess, LP supply, kLast).
"""
import json
import os
import time
import urllib.request

RPC = os.environ.get("AURORA_RPC", "https://mainnet.aurora.dev")
FACTORY = "0xC5E1DaeC2ad401eBEBdd3E32516d90Ab251A3aA3"

SEL = {
    "token0": "0x0dfe1681",
    "token1": "0xd21220a7",
    "getReserves": "0x0902f1ac",
    "totalSupply": "0x18160ddd",
    "kLast": "0x7464fc3d",
    "factory": "0xc45a0155",
    "balanceOf": "0x70a08231",
    "allPairs": "0x1e3dd18b",
    "allPairsLength": "0x574f2ba3",
    "feeTo": "0x017e7e58",
    "feeToSetter": "0x094b7415",
    "locked": "0xcf309012",
    "INIT_CODE_PAIR_HASH": "0x5855a25a",
}


def rpc(method, params):
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    req = urllib.request.Request(
        RPC,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"},
    )
    last = None
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                out = json.load(r)
            if "result" in out:
                return out["result"]
            last = out
        except Exception as e:  # noqa: BLE001
            last = e
        time.sleep(1.0 + 2.0 * attempt)
    raise RuntimeError(f"rpc fail {method}: {last}")


def rpc_batch(calls, block="latest", chunk=50):
    """calls: list of (to, data) -> list of hex results (None on error)."""
    results = []
    for i in range(0, len(calls), chunk):
        part = calls[i : i + chunk]
        payload = [
            {
                "jsonrpc": "2.0",
                "id": j,
                "method": "eth_call",
                "params": [{"to": to, "data": data}, block],
            }
            for j, (to, data) in enumerate(part)
        ]
        req = urllib.request.Request(
            RPC,
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"},
        )
        out = None
        for attempt in range(5):
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    out = json.load(r)
                break
            except Exception:  # noqa: BLE001
                time.sleep(1.0 + 2.0 * attempt)
        if out is None:
            raise RuntimeError("batch rpc fail")
        by_id = {item["id"]: item.get("result") for item in out}
        results.extend(by_id.get(j) for j in range(len(part)))
        time.sleep(0.15)
    return results


def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def enc_uint(v):
    return hex(v)[2:].rjust(64, "0")


def dec_uint(hexstr):
    if hexstr is None or hexstr == "0x":
        return None
    # NOTE: some Aurora tokens return >32 bytes from balanceOf; decode only the
    # first ABI word (a naive int(hex,16) on the whole payload inflates the value).
    return int(hexstr[2:66], 16)


def dec_addr(hexstr):
    if hexstr is None or hexstr == "0x":
        return None
    return "0x" + hexstr[-40:]


def main():
    block = int(rpc("eth_blockNumber", []), 16)
    print(f"block={block}")

    n = dec_uint(rpc("eth_call", [{"to": FACTORY, "data": SEL["allPairsLength"]}, hex(block)]))
    fee_to = dec_addr(rpc("eth_call", [{"to": FACTORY, "data": SEL["feeTo"]}, hex(block)]))
    fee_to_setter = dec_addr(rpc("eth_call", [{"to": FACTORY, "data": SEL["feeToSetter"]}, hex(block)]))
    locked = dec_uint(rpc("eth_call", [{"to": FACTORY, "data": SEL["locked"]}, hex(block)]))
    init_hash = rpc("eth_call", [{"to": FACTORY, "data": SEL["INIT_CODE_PAIR_HASH"]}, hex(block)])
    print(f"pairs={n} feeTo={fee_to} feeToSetter={fee_to_setter} locked={locked}")

    pairs = []
    calls = [(FACTORY, SEL["allPairs"] + enc_uint(i)) for i in range(n)]
    res = rpc_batch(calls, hex(block))
    for i, r in enumerate(res):
        a = dec_addr(r)
        if a:
            pairs.append(a)

    out = {
        "chain": "aurora",
        "factory": FACTORY,
        "block": block,
        "allPairsLength": n,
        "feeTo": fee_to,
        "feeToSetter": fee_to_setter,
        "locked": locked,
        "initCodePairHash": init_hash,
        "pairs": [],
    }

    # per-pair reads
    calls = []
    meta = []
    for p in pairs:
        calls += [
            (p, SEL["token0"]),
            (p, SEL["token1"]),
            (p, SEL["getReserves"]),
            (p, SEL["totalSupply"]),
            (p, SEL["kLast"]),
        ]
        meta.append(p)
    res = rpc_batch(calls, hex(block))
    per = {}
    for i, p in enumerate(pairs):
        base = i * 5
        per[p] = {
            "token0": dec_addr(res[base + 0]),
            "token1": dec_addr(res[base + 1]),
            "reserves_raw": res[base + 2],
            "totalSupply": dec_uint(res[base + 3]),
            "kLast": dec_uint(res[base + 4]),
        }

    # token balances of each pair
    calls = []
    idx = []
    for p in pairs:
        t0 = per[p]["token0"]
        t1 = per[p]["token1"]
        if t0:
            calls.append((t0, SEL["balanceOf"] + enc_addr(p)))
            idx.append((p, 0))
        if t1:
            calls.append((t1, SEL["balanceOf"] + enc_addr(p)))
            idx.append((p, 1))
    res = rpc_batch(calls, hex(block))
    for (p, side), r in zip(idx, res):
        per[p][f"balance{side}"] = dec_uint(r)

    for p in pairs:
        d = per[p]
        raw = d.pop("reserves_raw") or "0x"
        raw = raw[2:]
        r0 = int(raw[0:64] or "0", 16)
        r1 = int(raw[64:128] or "0", 16)
        ts = int(raw[128:192] or "0", 16)
        b0 = d.get("balance0")
        b1 = d.get("balance1")
        d["reserve0"] = r0
        d["reserve1"] = r1
        d["blockTimestampLast"] = ts
        d["excess0"] = None if b0 is None else b0 - r0
        d["excess1"] = None if b1 is None else b1 - r1
        out["pairs"].append(d)

    json.dump(out, open(os.path.join(os.path.dirname(__file__), "pairs_scan.json"), "w"), indent=1)
    n_excess = [d for d in out["pairs"] if (d["excess0"] or 0) > 0 or (d["excess1"] or 0) > 0]
    n_zero_supply = [d for d in out["pairs"] if (d["totalSupply"] == 0) and (d["reserve0"] > 0 or d["reserve1"] > 0)]
    print(f"pairs_scanned={len(out['pairs'])} pairs_with_excess={len(n_excess)} zero_supply_with_reserves={len(n_zero_supply)}")
    for d in n_excess[:20]:
        print("EXCESS", d)
    for d in n_zero_supply[:20]:
        print("ZEROSUP", d)


if __name__ == "__main__":
    main()
