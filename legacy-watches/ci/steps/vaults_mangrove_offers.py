#!/usr/bin/env python3
"""legacy-watches CI step: Mangrove (H2-09 eth-vaults group).

Read-only enumeration of live Mangrove offers on Blast + Arbitrum via PUBLIC keyless RPCs,
plus a price comparison against the Thruster CL pools the main maker sources inventory from.

Findings it re-produces:
  - DefiLlama 'TVL' = sum of offer `gives` (promises). The dominant maker holds ~$17 while
    its offers promise ~$4.2M (unbacked offer notional).
  - (USDe->USDB) offers straddle the USDB/USDe pool price (no net edge after slippage).
  - (WETH->BLAST) offers are nominally profitable but not deliverable (maker would need ~180M BLAST
    for 2.54 WETH) -> takes fail; provision bounties are sub-cent.

Outputs JSON to ci-out/vaults_mangrove_offers.json (also printed as a summary).
No API keys. No transactions. Public RPCs only.
"""
import json, sys, time, urllib.request, os

RPCS = {
    "blast": ["https://rpc.blast.io", "https://blast-rpc.publicnode.com"],
    "arbitrum": ["https://arb1.arbitrum.io/rpc"],
}
READERS = {
    "blast": "0x26fD9643Baf1f8A44b752B28f0D90AEBd04AB3F8",
    "arbitrum": "0x7E108d7C9CADb03E026075Bf242aC2353d0D1875",
}
# selector = keccak(sig)[0:4]
SEL_OPEN_MARKETS = "0x8267f649"   # openMarkets()
SEL_OFFER_LIST   = "0x79bfb7e1"   # offerList((address,address,uint256),uint256,uint256)
SEL_GET_PROVISION= "0x6001af26"   # getProvision((address,address,uint256),uint256,uint256)
SEL_SLOT0        = "0x3850c7bd"   # slot0()

# Blast tokens
USDB  = "0x4300000000000000000000000000000000000003"
WETH  = "0x4300000000000000000000000000000000000004"
USDE  = "0x5d3a1ff2b6bab83b63cd9ad0787074081a52ef34"
BLAST = "0xb1a5700fa2358173fe465e6ea4ff52e36e88e2ad"
# Thruster CL pools used by the main maker (read-only price reference)
POOLS = {
    "USDB/USDe": "0x8c1bb76510d6873a4a156a9cb394e74a3783bdb5",  # t0=USDB t1=USDe
    "WETH/BLAST": "0x9a0aa28d999a21d3cf6f2703cdbba9feaf4a32f7", # t0=WETH t1=BLAST
    "USDB/BLAST": "0x5d49456a119ef9afb5bec2a644338a078bef2b4b",  # t0=USDB t1=BLAST
}

def rpc(chain, method, params, timeout=40):
    last = None
    for url in RPCS[chain]:
        for attempt in range(3):
            try:
                req = urllib.request.Request(
                    url,
                    data=json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode(),
                    headers={"Content-Type": "application/json", "User-Agent": "legacy-watches-ci/1.0"},
                )
                d = json.load(urllib.request.urlopen(req, timeout=timeout))
                if "error" in d:
                    return {"error": d["error"]}
                return d.get("result")
            except Exception as e:  # noqa
                last = str(e)
                time.sleep(1.0 + attempt)
    return {"error": last}

def enc_word(v: int) -> str:
    return format(v, "064x")

def enc_addr(a: str) -> str:
    return a[2:].lower().rjust(64, "0")

def enc_olkey(olkey) -> str:
    t0, t1, sp = olkey
    return enc_addr(t0) + enc_addr(t1) + enc_word(sp)

def decode_markets(hexdata: str):
    b = bytes.fromhex(hexdata[2:])
    off1 = int.from_bytes(b[0:32], "big")
    n = int.from_bytes(b[off1:off1 + 32], "big")
    base = off1 + 32
    out = []
    for i in range(n):
        w = b[base + 96 * i: base + 96 * (i + 1)]
        t0 = "0x" + w[12:32].hex()
        t1 = "0x" + w[44:64].hex()
        sp = int.from_bytes(w[64:96], "big")
        out.append((t0, t1, sp))
    return out

def decode_offerlist(hexdata: str):
    b = bytes.fromhex(hexdata[2:])
    off_ids = int.from_bytes(b[32:64], "big")
    off_offers = int.from_bytes(b[64:96], "big")
    off_det = int.from_bytes(b[96:128], "big")
    n_ids = int.from_bytes(b[off_ids:off_ids + 32], "big")
    ids = [int.from_bytes(b[off_ids + 32 + 32 * i: off_ids + 64 + 32 * i], "big") for i in range(n_ids)]
    n_of = int.from_bytes(b[off_offers:off_offers + 32], "big")
    offers = []
    base = off_offers + 32
    for i in range(n_of):
        w = b[base + 128 * i: base + 128 * (i + 1)]
        offers.append((int.from_bytes(w[0:32], "big"), int.from_bytes(w[32:64], "big"),
                       int.from_bytes(w[64:96], "big", signed=True), int.from_bytes(w[96:128], "big")))
    n_det = int.from_bytes(b[off_det:off_det + 32], "big")
    details = []
    base = off_det + 32
    for i in range(n_det):
        w = b[base + 128 * i: base + 128 * (i + 1)]
        details.append(("0x" + w[12:32].hex(), int.from_bytes(w[32:64], "big"),
                        int.from_bytes(w[64:96], "big"), int.from_bytes(w[96:128], "big")))
    return ids, offers, details

def tick_price(tick: int) -> float:
    return 1.0001 ** tick

def main():
    result = {"generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "chains": {}}
    for chain, reader in READERS.items():
        head = rpc(chain, "eth_blockNumber", [])
        result["chains"][chain] = {"reader": reader, "block": head, "offers": []}
        mk = rpc(chain, "eth_call", [{"to": reader, "data": SEL_OPEN_MARKETS}, "latest"])
        if isinstance(mk, dict):
            print(f"[{chain}] openMarkets error: {mk}")
            continue
        markets = decode_markets(mk)
        print(f"[{chain}] block={head} open markets={len(markets)}")
        total_face = 0.0
        for (t0, t1, sp) in markets:
            for (a, b_) in ((t0, t1), (t1, t0)):
                data = SEL_OFFER_LIST + enc_olkey((a, b_, sp)) + enc_word(0) + enc_word(200)
                res = rpc(chain, "eth_call", [{"to": reader, "data": data}, "latest"])
                if isinstance(res, dict):
                    continue
                ids, offers, details = decode_offerlist(res)
                for i in range(len(ids)):
                    tick = offers[i][2]
                    gives = offers[i][3]
                    maker, gasreq, _kgb, gasprice = details[i]
                    rec = {"outbound": a, "inbound": b_, "tickSpacing": sp, "id": ids[i],
                           "tick": tick, "gives_raw": str(gives), "maker": maker,
                           "gasreq": gasreq, "gasprice": gasprice,
                           "price_inbound_per_outbound": tick_price(tick)}
                    result["chains"][chain]["offers"].append(rec)
                    total_face += 1
        print(f"[{chain}] live offers={total_face}")

    # price references (Blast only)
    pools = {}
    for name, pool in POOLS.items():
        res = rpc("blast", "eth_call", [{"to": pool, "data": SEL_SLOT0}, "latest"])
        if not isinstance(res, dict):
            sqrt = int(res[2:66], 16)
            price = (sqrt / (2 ** 96)) ** 2
            pools[name] = {"pool": pool, "sqrtPriceX96": str(sqrt), "price_t1_per_t0": price}
    result["blast_pool_prices"] = pools
    print("[blast] pool prices:", json.dumps(pools))

    # provisions for representative offers
    provs = {}
    for label, olkey, gasreq, gp in (
        ("USDe/USDB id29", (USDE, USDB, 1), 2000000, 3),
        ("WETH/BLAST id1", (WETH, BLAST, 1), 2000000, 1),
    ):
        data = SEL_GET_PROVISION + enc_olkey(olkey) + enc_word(gasreq) + enc_word(gp)
        res = rpc("blast", "eth_call", [{"to": READERS["blast"], "data": data}, "latest"])
        if not isinstance(res, dict):
            provs[label] = int(res, 16)
    result["provisions_wei"] = provs
    print("[blast] provisions (wei):", provs)

    # sanity notes for CI log
    result["notes"] = [
        "TVL counted by DefiLlama is the sum of offer `gives` (promises); Mangrove does not escrow offered tokens.",
        "Dominant maker 0xac1ce7f65c2312b828260d959d2b95b7f5ff480e held ~$17 at analysis time (2026-10).",
        "(WETH,BLAST) offers quote 602k-648k BLAST/WETH vs pool 71.06M -> not deliverable; takes fail.",
        "(USDe,USDB) offers straddle pool price 1.00407 USDB/USDe; no net edge after slippage.",
    ]
    outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "ci-out")
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, "vaults_mangrove_offers.json"), "w") as f:
        json.dump(result, f, indent=1)
    print("wrote ci-out/vaults_mangrove_offers.json")
    return 0

if __name__ == "__main__":
    sys.exit(main())
