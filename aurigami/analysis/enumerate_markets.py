#!/usr/bin/env python3
"""Enumerate Aurigami markets on Aurora at a pinned block via JSON-RPC batches."""
import json
import urllib.request

RPC = "https://mainnet.aurora.dev"
UNIT = "0x817af6cfAF35BdC1A634d6cC94eE9e4c68369Aeb"
ORACLE = "0x5A7B8E3CDc6ee2E0E6Ad0d4fab8dCD70990157EE"

MARKETS = [
    "0x4f0d864b1ABf4B701799a0b30b57A22dFEB5917b",
    "0xca9511B610bA5fc7E311FDeF9cE16050eE4449E9",
    "0xCFb6b0498cb7555e7e21502E0F449bf28760Adbb",
    "0xaD5A2437Ff55ed7A8Cad3b797b3eC7c5a19B1c54",
    "0xCE4166363E3a584DAc84A47bCD3414B43EfCDd1c",
    "0xaE4fac24dCdAE0132C6d04f564dCf059616E9423",
    "0x3195949f267702723bc614cAE037cdc8D1E94786",
    "0x8888682E24dd4Df7B7Ff2B91fccB575737E433bf",
    "0x6Ea6C03061bDdCE23d4Ec60B6E6e880c33d24dca",
    "0xC9011e629c9d0b8B1e4A2091e123fBB87B3A792c",
    "0x5cCAD065400341db391FD3a4B7F50087B678D7CC",
    "0xC7ea819ebf08E5FF481D4708a602f92380AFbB0a",
    "0x10D56d6E5968016dF5930E8Ce50d2d08EC59774c",
    "0xdDfd0407220026c6566979B5be6A4983d1247a3E",
]

UNKNOWN_UNDERLYING = {
    "0xca9511B610bA5fc7E311FDeF9cE16050eE4449E9": "ETH (CEther)",
}


def call(to, data, tag="latest"):
    return {"to": to, "data": data, "tag": tag}


def batch(reqs):
    res = {}
    CH = 20
    rid = 0
    for i in range(0, len(reqs), CH):
        chunk = reqs[i:i + CH]
        payload = json.dumps([{"jsonrpc": "2.0", "id": j, "method": "eth_call", "params": [r, r.get("tag", "latest")]} for j, r in enumerate(chunk)]).encode()
        req = urllib.request.Request(RPC, data=payload, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
        out = json.load(urllib.request.urlopen(req, timeout=60))
        for item in out:
            res[rid + item["id"]] = item
        rid += len(chunk)
    return [res[i] for i in range(len(reqs))]


def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def enc_arr(addrs):
    n = len(addrs)
    head = "%064x" % 32
    ln = "%064x" % n
    body = "".join(enc_addr(a) for a in addrs)
    return head + ln + body


def main():
    bn = json.load(urllib.request.urlopen(urllib.request.Request(
        RPC, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})))["result"]
    block = int(bn, 16)
    print("block", block)

    out = {"block": block, "unitroller": UNIT, "oracle": ORACLE, "markets": {}}

    # per market calls
    reqs, meta = [], []
    for m in MARKETS:
        for label, data in [
            ("underlying", "0x6f307dc3"),
            ("decimals", "0x313ce567"),
            ("totalSupply", "0x18160ddd"),
            ("totalBorrows", "0x47bd3718"),
            ("totalReserves", "0x8f840ddd"),
            ("exchangeRateStored", "0x182df0f5"),
            ("borrowIndex", "0xaa5af0fd"),
            ("accrualBlockTimestamp", "0xcfa99201"),
            ("initialExchangeRateMantissa", "0x675d972c"),
            ("reserveFactorMantissa", "0x173b9904"),
            ("protocolSeizeShareMantissa", "0x6752e702"),
            ("admin", "0xf851a440"),
            ("interestRateModel", "0xf3fdb15a"),
        ]:
            reqs.append(call(m, data))
            meta.append((m, label))
        # comptroller state
        reqs.append(call(UNIT, "0x8e8f294b" + enc_addr(m)))          # markets(m)
        meta.append((m, "marketInfo"))
        reqs.append(call(UNIT, "0x4a584432" + enc_addr(m)))          # borrowCaps(m)
        meta.append((m, "borrowCap"))
        reqs.append(call(UNIT, "0x731f0c2b" + enc_addr(m)))          # mintGuardianPaused
        meta.append((m, "mintPaused"))
        reqs.append(call(UNIT, "0x6d154ea5" + enc_addr(m)))          # borrowGuardianPaused
        meta.append((m, "borrowPaused"))
        reqs.append(call(ORACLE, "0xfc57d4df" + enc_addr(m)))        # getUnderlyingPrice
        meta.append((m, "price"))

    resp = batch(reqs)
    per = {m: {} for m in MARKETS}
    for (m, label), r in zip(meta, resp):
        val = r.get("result")
        if isinstance(r, dict) and "error" in r:
            val = {"error": r["error"].get("message", "err")}
        per[m][label] = val

    # underlying balances (cash) - need underlying addr per market
    reqs, meta = [], []
    unds = {}
    for m in MARKETS:
        u = per[m].get("underlying")
        if isinstance(u, str) and len(u) == 66:
            unds[m] = "0x" + u[-40:]
        else:
            unds[m] = None
    for m in MARKETS:
        if unds[m]:
            reqs.append(call(unds[m], "0x70a08231" + enc_addr(m)))
            meta.append((m, "cash"))
    resp = batch(reqs)
    for (m, label), r in zip(meta, resp):
        per[m][label] = r.get("result")

    out["markets"] = per
    json.dump(out, open("/home/heisenberg/CA/aurigami/analysis/markets_raw.json", "w"), indent=1)
    print("wrote markets_raw.json")


if __name__ == "__main__":
    main()
