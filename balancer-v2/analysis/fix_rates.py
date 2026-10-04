#!/usr/bin/env python3
"""Re-probe Balancer V2 pool rate data with CORRECT dynamic-array decoding.

For each ComposableStable / MetaStable / pool with rateProviders in a scan JSON:
  getRateProviders(), getScalingFactors(), getTokenRate(token) per token,
  getTokenRateCache(token), getPausedState(), getActualSupply(), version(), inRecoveryMode()
Writes chain-<name>-fixed.json.
"""
import json, sys, time, urllib.request

SEL_RATE_PROVIDERS = "0x238a2d59"
SEL_SCALING = "0x1dd746ea"
SEL_TOKEN_RATE = "0x54dea00a"
SEL_TOKEN_RATE_CACHE = "0x7f1260d1"
SEL_PAUSED_STATE = "0x1c0de051"
SEL_ACTUAL_SUPPLY = "0x876f303b"
SEL_VERSION = "0x54fd4d50"
SEL_RECOVERY = "0xb35056b8"


def rpc_batch(url, calls, chunk=15):
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i + chunk]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p}
                   for j, (m, p) in enumerate(part)]
        body = json.dumps(payload).encode()
        for attempt in range(4):
            try:
                req = urllib.request.Request(url, data=body, headers={
                    "Content-Type": "application/json", "User-Agent": "Mozilla/5.0 bal-fix"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    res = json.load(r)
                break
            except Exception:
                time.sleep(1 + attempt)
        else:
            raise RuntimeError("rpc batch failed")
        by_id = {x.get("id"): x for x in res}
        for j in range(len(part)):
            x = by_id.get(j, {})
            out.append(x.get("result") if "result" in x else None)
        time.sleep(0.03)
    return out


def words(h):
    h = h[2:] if h.startswith("0x") else h
    return [h[i:i + 64] for i in range(0, len(h), 64)]


def u(w):
    return int(w, 16)


def addr(w):
    return "0x" + w[-40:]


def dec_arr_addr(h):
    if not h or h == "0x":
        return None
    w = words(h)
    base = u(w[0]) // 32
    n = u(w[base])
    return [addr(x) for x in w[base + 1:base + 1 + n]]


def dec_arr_uint(h):
    if not h or h == "0x":
        return None
    w = words(h)
    base = u(w[0]) // 32
    n = u(w[base])
    return [u(x) for x in w[base + 1:base + 1 + n]]


def dec_str(h):
    if not h or h == "0x":
        return None
    w = words(h)
    try:
        base = u(w[0]) // 32
        n = u(w[base])
        return bytes.fromhex("".join(w[base + 1:base + 1 + n])).decode("utf-8", "replace")
    except Exception:
        return None


def main():
    rpc, path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    d = json.load(open(path))
    pools = d["pools"]
    targets = [p for p in pools if p.get("type") in ("ComposableStable", "MetaStable")]
    print(f"re-probing {len(targets)} pools", flush=True)

    for i, p in enumerate(targets):
        a = p["address"]
        toks = p["tokens"]
        calls = [
            ("eth_call", [{"to": a, "data": SEL_RATE_PROVIDERS}, "latest"]),
            ("eth_call", [{"to": a, "data": SEL_SCALING}, "latest"]),
            ("eth_call", [{"to": a, "data": SEL_PAUSED_STATE}, "latest"]),
            ("eth_call", [{"to": a, "data": SEL_ACTUAL_SUPPLY}, "latest"]),
            ("eth_call", [{"to": a, "data": SEL_VERSION}, "latest"]),
            ("eth_call", [{"to": a, "data": SEL_RECOVERY}, "latest"]),
        ]
        for t in toks:
            calls.append(("eth_call", [{"to": a, "data": SEL_TOKEN_RATE + "0" * 24 + t[2:]}, "latest"]))
        for t in toks:
            calls.append(("eth_call", [{"to": a, "data": SEL_TOKEN_RATE_CACHE + "0" * 24 + t[2:]}, "latest"]))
        res = rpc_batch(rpc, calls)
        rp, sf, ps, asup, ver, rec = res[0], res[1], res[2], res[3], res[4], res[5]
        rates = res[6:6 + len(toks)]
        caches = res[6 + len(toks):6 + 2 * len(toks)]

        probe = p.setdefault("probe", {})
        probe["rateProviders_fixed"] = dec_arr_addr(rp)
        probe["scalingFactors_fixed"] = dec_arr_uint(sf)
        probe["tokenRates_fixed"] = [u(w[0]) if w and w != "0x" else None for w in rates]
        probe["tokenRateCaches_fixed"] = []
        for w in caches:
            if w and w != "0x":
                ws = words(w)
                probe["tokenRateCaches_fixed"].append({"rate": u(ws[0]), "duration": u(ws[1]), "expires": u(ws[2])})
            else:
                probe["tokenRateCaches_fixed"].append(None)
        if ps and ps != "0x":
            ws = words(ps)
            probe["poolPausedState"] = {"paused": u(ws[0]) != 0, "pauseWindowEndTime": u(ws[1]), "bufferPeriodEndTime": u(ws[2])}
        else:
            probe["poolPausedState"] = None
        probe["actualSupply"] = u(words(asup)[0]) if asup and asup != "0x" else None
        probe["version"] = dec_str(ver)
        probe["recovery_fixed"] = (u(words(rec)[0]) != 0) if rec and rec != "0x" else None
        if (i + 1) % 20 == 0:
            print(f"  {i+1}/{len(targets)}", flush=True)

    json.dump(d, open(out_path, "w"), indent=1)
    print("wrote", out_path)


if __name__ == "__main__":
    main()
