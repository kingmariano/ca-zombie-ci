#!/usr/bin/env python3
"""Arb research step 1: scan Celo DEX factories for all pairs touching Mobius-pool tokens.
Read-only. Keyless RPC. Outputs: analysis/_pairs_scan.json
"""
import json, urllib.request, os, time, sys

RPC = "https://forno.celo.org"
HERE = os.path.dirname(os.path.abspath(__file__))

# all tokens present in any Mobius pool (from live-state) + relevant bases
WATCH = {a.lower() for a in [
    # target pool tokens
    "0x765de816845861e75a25fca122bb6898b8b1282a",  # USDm
    "0xed193c4e69f591e42398ef54dea65aa1bb02835c",  # atUST
    "0xb4aa2986622249b1f45eb93f28cfca2b2606d809",  # pUSD
    "0xeadf4a7168a82d30ba0619e64d5bcf5b30b45226",  # pUSD cUSD
    "0x56072d4832642db29225da12d6fd1290e4744682",  # pEUR
    "0xd8761dd6c7cb54febd33add699f5e4440b62e01b",  # pEUR cEUR
    "0xe74abf23e1fdf7acbec2f3a30a772ef77f1601e1",  # pCELO
    "0x301a61d01a63c8d670c2b8a43f37d12ef181f997",  # pCELO 2
    "0x1bfc26ce035c368503fae319cc2596716428ca44",  # USDC old
    "0x2a3684e9dc20b857375ea04235f2f7edbe818fa7",  # USDCet
    "0xb70e0a782b058bfdb0d109a3599bec1f19328e36",  # aaUSDC
    "0xd629eb00deced2a080b7ec630ef6ac117e614f1b",  # BTC 18dp
    "0xbaab46e28388d2779e6e31fd00cf0e5ad95e327b",  # WBTC 8dp
    "0xbe50a3013a1c94768a1abb78c3cb79ab28fc1ace",  # WBTC old
    # other Mobius tokens
    "0x471ece3750da237f93b8e339c536989b8978a438",  # CELO
    "0xd8763cba276a3738e6de85b4b3bf5fded6d6ca73",  # EURm
    "0x2def4285787d58a2f811af24755a8150622f4361",  # cETH
    "0x122013fd7df1c6f636a5bb8f03108e876548b455",  # WETH
    "0x90ca507a5d4458a4c6c6249d186b6dcb02a5bccd",  # DAI
    "0x37f750b7cc259a2f741af45294f6a16572cf5cad",  # USDC 6dp
    "0xef4229c8c3250c675f21bcefa42f58efbff6002a",  # USDC 6dp b
    "0xdc5762753043327d74e0a538199c1488fc1f44cf",  # rstCELO
    "0xcc82628f6a8defa1e2b0ad7ed448bef3647f7941",  # USDC PoS
    "0xcd7d7ff64746c1909e44db8e95331f9316478817",  # asUSDC
    "0xcfffe0c89a779c09df3df5624f54cdf7ef5fdd5d",  # cUSDT
    "0x93db49be12b864019da9cb147ba75cdc0506190e",  # cUSDC
    "0xe919f65739c26a42616b7b8eedc6b5524d1e3ac4",  # WETH b
    # extra common bases likely used as quote
    "0x48065fbbe25f71c9282ddf5e1cd6d6a887483d5e",  # USDT (native)
    "0xe8537a3d056da446677b9e9d6c5db7046f052ab8",  # cREAL
    "0xd221812de1bd094f35587ee8e174b07b6167d9af",  # ?
    "0x8a567e2aef1ab8b8b496ac9e2c9ac9e5d5a1d0b3",  # ?
]}

BASE = {
    "usdm": "0x765de816845861e75a25fca122bb6898b8b1282a",
    "celo": "0x471ece3750da237f93b8e339c536989b8978a438",
    "eurm": "0xd8763cba276a3738e6de85b4b3bf5fded6d6ca73",
}

FACTORIES = {
    # name: address, verify via allPairsLength
    "ubeswap_v2": "0x62d5b84be28a183abb507e125b384122d2c25fae",
    "sushiswap_v2": "0xc35dadb65012ec5796536bd9864ed8773abc74c4",
    "apeswap_v2": "0xcf083be4164828f00cae704ec15a36d711491284",
    "uniswap_v3_celo": "0xafe208a311b21f13ef87e33a90049fc17a7acdec",
    "pancake_v2_celo": "0x02a84c1b3bbd7401a5f7fa98a384ebc70bb5749e",
}


def rpc_batch(calls, tries=6, batch=60):
    out = []
    for i in range(0, len(calls), batch):
        chunk = calls[i:i + batch]
        body = json.dumps([{"jsonrpc": "2.0", "id": j, "method": m, "params": p}
                           for j, (m, p) in enumerate(chunk)]).encode()
        last = None
        for t in range(tries):
            try:
                req = urllib.request.Request(RPC, data=body,
                                             headers={"Content-Type": "application/json",
                                                      "User-Agent": "Mozilla/5.0 (research; read-only)"})
                with urllib.request.urlopen(req, timeout=90) as r:
                    d = json.loads(r.read().decode())
                if isinstance(d, dict):  # error response
                    raise RuntimeError(str(d)[:300])
                by_id = {it["id"]: it for it in d}
                for j in range(len(chunk)):
                    it = by_id.get(j)
                    out.append(it.get("result") if it and "result" in it else None)
                break
            except Exception as e:
                last = e
                time.sleep(1 + t)
        else:
            raise RuntimeError(f"rpc failed: {last}")
    return out


def enc_addr_ret(h):
    return "0x" + h[2:][-40:].lower() if h else None


def main():
    result = {"rpc": RPC, "watch": sorted(WATCH), "factories": {}}
    # block
    r = rpc_batch([("eth_blockNumber", [])])
    result["block"] = int(r[0], 16)
    print("block", result["block"])

    for name, fac in FACTORIES.items():
        code = rpc_batch([("eth_getCode", [fac, "latest"])])[0]
        info = {"address": fac, "code_len": (len(code) - 2) // 2 if code else 0}
        if not code or code == "0x":
            info["note"] = "no code"
            result["factories"][name] = info
            print(name, "no code")
            continue
        ln = rpc_batch([("eth_call", [{"to": fac, "data": "0x574f2ba3"}, "latest"])])[0]  # allPairsLength()
        if ln:
            info["allPairsLength"] = int(ln, 16)
        result["factories"][name] = info
        print(name, info)

    # focus: Ubeswap V2 full pair scan
    fac = FACTORIES["ubeswap_v2"]
    n = result["factories"]["ubeswap_v2"].get("allPairsLength")
    if not n:
        print("no allPairsLength; abort")
        return
    calls = []
    for i in range(n):
        calls.append(("eth_call", [{"to": fac, "data": "0x1e3dd18b" + hex(i)[2:].rjust(64, "0")}, "latest"]))
    pairs = rpc_batch(calls, batch=80)
    pair_addrs = [enc_addr_ret(p) for p in pairs if p]
    print("pairs fetched:", len(pair_addrs))

    # token0/token1 for each pair
    calls = []
    for p in pair_addrs:
        calls.append(("eth_call", [{"to": p, "data": "0x0dfe1681"}, "latest"]))  # token0()
        calls.append(("eth_call", [{"to": p, "data": "0xd21220a7"}, "latest"]))  # token1()
    toks = rpc_batch(calls, batch=60)
    pairs_info = {}
    for i, p in enumerate(pair_addrs):
        t0 = enc_addr_ret(toks[2 * i])
        t1 = enc_addr_ret(toks[2 * i + 1])
        pairs_info[p] = {"token0": t0, "token1": t1}
    result["ubeswap_pairs"] = pairs_info

    # filter pairs touching watchlist
    hits = {}
    for p, info in pairs_info.items():
        t0, t1 = info["token0"], info["token1"]
        if (t0 in WATCH) or (t1 in WATCH):
            hits[p] = info
    result["watch_pairs"] = hits
    print("pairs touching watchlist:", len(hits))
    for p, info in sorted(hits.items()):
        print(" ", p, info["token0"], info["token1"])

    with open(os.path.join(HERE, "_pairs_scan.json"), "w") as f:
        json.dump(result, f, indent=1)
    print("wrote _pairs_scan.json")


if __name__ == "__main__":
    main()
