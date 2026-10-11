#!/usr/bin/env python3
"""Final consolidated Nerve snapshot (BSC) — all numbers at one block.
Read-only. Uses BSC_RPC from env or a public fallback (no keys written)."""
import json, urllib.request, os

RPC = os.environ.get("BSC_RPC") or "https://bsc-rpc.publicnode.com"

def rpc(m, p):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p}).encode(),
                                 headers={"Content-Type":"application/json"})
    r = json.load(urllib.request.urlopen(req, timeout=60))
    if "error" in r: raise RuntimeError(r["error"])
    return r["result"]

def call(to, data, blk="latest"):
    return int(rpc("eth_call", [{"to": to, "data": data}, blk]), 16)

def u256(x): return hex(int(x))[2:].rjust(64, "0")
def u8(x): return hex(x)[2:].rjust(64, "0")

POOLS = {
    "3pool": {"a": "0x1b3771a66ee31180906972580ade9b81afc5fcdc",
              "tokens": [("BUSD","0xe9e7cea3dedca5984780bafc599bd69add087d56",18),
                         ("USDT","0x55d398326f99059ff775485246999027b3197955",18),
                         ("USDC","0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d",18)],
              "type": "swap"},
    "btcpool": {"a": "0x6c341938bb75dde823faafe7f446925c66e6270c",
                "tokens": [("BTCB","0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c",18),
                           ("anyBTC","0x54261774905f3e6e9718f2abb10ed6555cae308a",8)],
                "type": "swap"},
    "ethpool": {"a": "0x146cd24dcc9f4eb224dfd010c5bf2b0d25afa9c0",
                "tokens": [("ETH","0x2170ed0880ac9a755fd29b2688956bd959f933f8",18),
                           ("anyETH","0x6f817a0ce8f7640add3bc0c1c2298635043c2423",18)],
                "type": "swap"},
    "ustmeta": {"a": "0x2dcce1586b1664f41c72206900e404ec3ca130e0",
                "tokens": [("UST","0x23396cf899ca06c4472205fc903bdb4de249d6fc",18),
                           ("3poolLP","0xf2511b5e4fb0e5e2d123004b672ba14850478c14",18)],
                "type": "meta"},
    "fusdtmeta": {"a": "0xd0fbf0a224563d5ffc8a57e4fda6ae080ebcf3d3",
                  "tokens": [("fUSDT","0x049d68029688eabf473097a2fc38ef61633a3c7a",6),
                             ("3poolLP","0xf2511b5e4fb0e5e2d123004b672ba14850478c14",18)],
                  "type": "meta"},
    "nrvfusdtmeta": {"a": "0x96b849a73db2cc769b4abe770aab141aac9014d6",
                     "tokens": [("fUSDT","0x049d68029688eabf473097a2fc38ef61633a3c7a",6),
                                ("3poolLP","0xf2511b5e4fb0e5e2d123004b672ba14850478c14",18)],
                     "type": "meta"},
}
LP3 = "0xf2511b5e4fb0e5e2d123004b672ba14850478c14"
SAFE = "0xd94ac9fb78dd9b3feb0ec39f38d86d2ee5ba6b06"
FARM = "0x2ebe8cdbcb5fb8564bc45999dab8da264e31f24e"

PRICES = {"BUSD": 0.9999622903376613, "USDT": 0.9990598242060843, "USDC": 0.9996290152794088,
          "BTCB": 82828.52898574874, "ETH": 2500.1249603518713, "UST": 0.009159695849314657,
          "fUSDT": 1.0, "anyBTC": 0.0, "anyETH": 0.0, "3poolLP": None}

def main():
    blk_hex = rpc("eth_blockNumber", [])
    blk = int(blk_hex, 16)
    out = {"block": blk, "pools": {}, "lp3": {}, "safe": {}}

    for name, p in POOLS.items():
        pd = {"address": p["a"], "type": p["type"], "paused": bool(call(p["a"], "0x5c975abb")),
              "owner": "0x" + call(p["a"], "0x8da5cb5b").to_bytes(32,"big")[-20:].hex(),
              "vprice": call(p["a"], "0xe25aa5fa"), "tokens": []}
        for i, (sym, addr, dec) in enumerate(p["tokens"]):
            actual = call(addr, "0x70a08231" + u256(int(p["a"],16)))
            internal = call(p["a"], "0x91ceb3eb" + u8(i))
            admin = call(p["a"], "0xef0a712f" + u256(i))
            pd["tokens"].append({"sym": sym, "addr": addr, "dec": dec, "actual": actual,
                                 "internal": internal, "admin": admin,
                                 "actual_units": actual/10**dec, "internal_units": internal/10**dec,
                                 "admin_units": admin/10**dec})
        out["pools"][name] = pd

    out["lp3"] = {"totalSupply": call(LP3, "0x18160ddd"),
                  "farm": call(LP3, "0x70a08231" + u256(int(FARM,16))),
                  "fusdtmeta": call(LP3, "0x70a08231" + u256(int(POOLS["fusdtmeta"]["a"],16))),
                  "ustmeta": call(LP3, "0x70a08231" + u256(int(POOLS["ustmeta"]["a"],16))),
                  "nrvmeta": call(LP3, "0x70a08231" + u256(int(POOLS["nrvfusdtmeta"]["a"],16)))}
    out["safe"] = {"threshold": call(SAFE, "0xe75235b8")}

    with open("/home/heisenberg/CA/nerve/analysis/final_snapshot.json", "w") as f:
        json.dump(out, f, indent=2)

    # ---- value model ----
    px = PRICES
    v3pool = 0.0
    for t in out["pools"]["3pool"]["tokens"]:
        v3pool += t["internal_units"] * px[t["sym"]]
        v3pool += t["admin_units"] * px[t["sym"]]
    lp3_total = out["lp3"]["totalSupply"] / 1e18
    lp3_user_value = sum(t["internal_units"] * px[t["sym"]] for t in out["pools"]["3pool"]["tokens"])
    lp3_nav = lp3_user_value / lp3_total
    px["3poolLP"] = lp3_nav
    print(f"block {blk}")
    print(f"3pool total value          ${v3pool:,.2f} (user ${lp3_user_value:,.2f} + admin ${v3pool-lp3_user_value:,.2f})")
    print(f"3pool LP NAV               ${lp3_nav:.6f} x {lp3_total:,.2f} LP")
    admin_lp = (out["lp3"]["fusdtmeta"] + out["lp3"]["ustmeta"]) / 1e18
    print(f"metapool-held 3pool LP     {admin_lp:,.2f} LP = ${admin_lp*lp3_nav:,.2f} (owner-only adminBalances)")
    for name in ("btcpool","ethpool","ustmeta","fusdtmeta"):
        p = out["pools"][name]
        tot = sum(t["actual_units"] * px[t["sym"]] for t in p["tokens"])
        adm = sum(t["admin_units"] * px[t["sym"]] for t in p["tokens"])
        usr = sum(t["internal_units"] * px[t["sym"]] for t in p["tokens"])
        print(f"{name:12s} total ${tot:,.2f}  user ${usr:,.2f}  admin ${adm:,.2f}")
    print(f"farm LP {out['lp3']['farm']/1e18:,.2f} = ${out['lp3']['farm']/1e18*lp3_nav:,.2f} (user, H-O)")
    print(f"safe threshold {out['safe']['threshold']}")

if __name__ == "__main__":
    main()
