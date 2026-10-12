#!/usr/bin/env python3
"""Arb step 4: Uniswap V3 getPool checks for junk tokens; DefiLlama prices; Blockscout token/address metadata.
Outputs: analysis/_externals.json
"""
import json, urllib.request, os, time, urllib.error

RPC = "https://forno.celo.org"
HERE = os.path.dirname(os.path.abspath(__file__))
BS = "https://celo.blockscout.com/api/v2"

V3_FACTORY = "0xafe208a311b21f13ef87e33a90049fc17a7acdec"
SEL_GETPOOL = None  # fill below

JUNK = {
    "atUST": "0xed193c4e69f591e42398ef54dea65aa1bb02835c",
    "pUSD_b4aa": "0xb4aa2986622249b1f45eb93f28cfca2b2606d809",
    "pUSD_eadf": "0xeadf4a7168a82d30ba0619e64d5bcf5b30b45226",
    "pEUR_5607": "0x56072d4832642db29225da12d6fd1290e4744682",
    "pEUR_d876": "0xd8761dd6c7cb54febd33add699f5e4440b62e01b",
    "pCELO_e74a": "0xe74abf23e1fdf7acbec2f3a30a772ef77f1601e1",
    "pCELO_301a": "0x301a61d01a63c8d670c2b8a43f37d12ef181f997",
    "USDCold_1bfc": "0x1bfc26ce035c368503fae319cc2596716428ca44",
    "aaUSDC_b70e": "0xb70e0a782b058bfdb0d109a3599bec1f19328e36",
    "BTC_d629": "0xd629eb00deced2a080b7ec630ef6ac117e614f1b",
    "WBTC_baab": "0xbaab46e28388d2779e6e31fd00cf0e5ad95e327b",
    "WBTCold_be50": "0xbe50a3013a1c94768a1abb78c3cb79ab28fc1ace",
    "POOF": "0x00400fcbf0816bebb94654259de7273f4a05c762",
    "MOBI": "0x73a210637f6f6b7005512677ba6b3c96bb4aa44b",
    "mCUSD": "0x64defa3544c695db8c535d289d843a189aa26b98",
    "mcUSD": "0x918146359264c492bd6934071c6bd31c854edbc3",
}
BASES = {
    "USDm": "0x765de816845861e75a25fca122bb6898b8b1282a",
    "CELO": "0x471ece3750da237f93b8e339c536989b8978a438",
    "EURm": "0xd8763cba276a3738e6de85b4b3bf5fded6d6ca73",
    "USDCet": "0x2a3684e9dc20b857375ea04235f2f7edbe818fa7",
}
PRICE_TOKENS = {
    # tokens we want DefiLlama prices for
    "0xed193c4e69f591e42398ef54dea65aa1bb02835c": "atUST",
    "0xb4aa2986622249b1f45eb93f28cfca2b2606d809": "pUSD",
    "0xeadf4a7168a82d30ba0619e64d5bcf5b30b45226": "pUSD-2",
    "0x56072d4832642db29225da12d6fd1290e4744682": "pEUR",
    "0xd8761dd6c7cb54febd33add699f5e4440b62e01b": "pEUR-2",
    "0xe74abf23e1fdf7acbec2f3a30a772ef77f1601e1": "pCELO",
    "0x301a61d01a63c8d670c2b8a43f37d12ef181f997": "pCELO-2",
    "0x1bfc26ce035c368503fae319cc2596716428ca44": "USDC-old",
    "0x2a3684e9dc20b857375ea04235f2f7edbe818fa7": "USDCet",
    "0xb70e0a782b058bfdb0d109a3599bec1f19328e36": "aaUSDC",
    "0xd629eb00deced2a080b7ec630ef6ac117e614f1b": "BTC-d629",
    "0xbaab46e28388d2779e6e31fd00cf0e5ad95e327b": "WBTC-baab",
    "0xbe50a3013a1c94768a1abb78c3cb79ab28fc1ace": "WBTC-be50",
    "0x00400fcbf0816bebb94654259de7273f4a05c762": "POOF",
    "0x73a210637f6f6b7005512677ba6b3c96bb4aa44b": "MOBI",
    "0x64defa3544c695db8c535d289d843a189aa26b98": "mCUSD",
    "0x918146359264c492bd6934071c6bd31c854edbc3": "mcUSD",
    "0x765de816845861e75a25fca122bb6898b8b1282a": "USDm",
    "0x471ece3750da237f93b8e339c536989b8978a438": "CELO",
    "0xd8763cba276a3738e6de85b4b3bf5fded6d6ca73": "EURm",
    "0x2def4285787d58a2f811af24755a8150622f4361": "cETH",
    "0xe919f65739c26a42616b7b8eedc6b5524d1e3ac4": "WETH-2",
    "0x00be915b9dcf56a3cbe739d9b9c202ca692409ec": "UBE",
    "0xdc5762753043327d74e0a538199c1488fc1f44cf": "rstCELO",
    "0x90ca507a5d4458a4c6c6249d186b6dcb02a5bccd": "DAI",
    "0x37f750b7cc259a2f741af45294f6a16572cf5cad": "USDC-c",
}

# Blockscout metadata targets: junk + Poof + interesting
BS_TOKENS = list(JUNK.values()) + list(BASES.values()) + [
    "0x765de816845861e75a25fca122bb6898b8b1282a",
]


def rpc_batch(calls, tries=6, batch=50):
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
                if isinstance(d, dict):
                    raise RuntimeError(str(d)[:200])
                by_id = {it["id"]: it for it in d}
                out.extend((by_id.get(j) or {}).get("result") for j in range(len(chunk)))
                break
            except Exception as e:
                last = e
                time.sleep(1 + t)
        else:
            out.extend([None] * len(chunk))
    return out


def a(h): return "0x" + h[2:][-40:].lower() if h and len(h) >= 42 else None


def get_json(url, tries=3):
    for t in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (research; read-only)"})
            with urllib.request.urlopen(req, timeout=45) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            if t == tries - 1:
                return {"error": str(e)}
            time.sleep(1 + t)


def main():
    out = {}
    # keccak selectors via known values
    import hashlib
    # compute keccak? use cast elsewhere; here hardcode verified selectors:
    getPool_sel = "0x1698ee82"  # getPool(address,address,uint24)
    out["v3_checks"] = {}
    calls, keys = [], []
    for name, addr in JUNK.items():
        for bname, b in BASES.items():
            if addr == b:
                continue
            for fee in (500, 3000, 10000):
                data = getPool_sel + addr[2:].rjust(64, "0") + b[2:].rjust(64, "0") + hex(fee)[2:].rjust(64, "0")
                calls.append(("eth_call", [{"to": V3_FACTORY, "data": data}, "latest"]))
                keys.append((name, bname, fee))
    res = rpc_batch(calls, batch=60)
    for (name, bname, fee), r in zip(keys, res):
        p = a(r)
        if p and p != "0x" + "0" * 40:
            out["v3_checks"][f"{name}/{bname}/{fee}"] = p
    print("V3 pools found:", len(out["v3_checks"]))
    for k, v in out["v3_checks"].items():
        print("  ", k, v)

    # llama prices
    out["llama_prices"] = {}
    adds = list(PRICE_TOKENS.keys())
    for i in range(0, len(adds), 20):
        ch = adds[i:i + 20]
        d = get_json("https://coins.llama.fi/prices/current/" + ",".join(f"celo:{x}" for x in ch))
        for k, v in (d.get("coins") or {}).items():
            out["llama_prices"][k.split(":")[1].lower()] = v
        time.sleep(0.4)
    for addr, v in out["llama_prices"].items():
        print("llama", PRICE_TOKENS.get(addr, addr), v.get("symbol"), v.get("price"), "conf", v.get("confidence"))

    # Blockscout metadata
    out["blockscout"] = {}
    for addr in sorted(set(BS_TOKENS)):
        d = get_json(f"{BS}/addresses/{addr}")
        t = get_json(f"{BS}/tokens/{addr}")
        rec = {}
        if isinstance(d, dict) and "hash" in d:
            rec["is_contract"] = d.get("is_contract")
            rec["is_verified"] = d.get("is_verified")
            rec["creator"] = d.get("creator_address_hash")
            rec["creation_tx"] = d.get("creation_transaction_hash")
            rec["name"] = d.get("name")
            rec["proxy_type"] = d.get("proxy_type")
            rec["implementations"] = [i.get("address") for i in (d.get("implementations") or [])]
            tags = []
            for tg in (d.get("metadata") or {}).get("tags") or []:
                tags.append({"type": tg.get("tagType"), "name": tg.get("name"),
                             "project": ((tg.get("meta") or {}).get("projectName"))})
            rec["tags"] = tags
        else:
            rec["error"] = (d or {}).get("error")
        if isinstance(t, dict) and "name" in t:
            rec["token"] = {"name": t.get("name"), "symbol": t.get("symbol"),
                            "decimals": t.get("decimals"), "total_supply": t.get("total_supply"),
                            "holders": t.get("holders_count") or t.get("holders"),
                            "exchange_rate": t.get("exchange_rate"), "type": t.get("type")}
        out["blockscout"][addr] = rec
        print("bs", addr, rec.get("token", {}).get("symbol") or rec.get("name"), "creator", rec.get("creator"),
              "tags", [x["name"] for x in rec.get("tags", []) if x.get("name")][:3])
        time.sleep(0.25)

    with open(os.path.join(HERE, "_externals.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("wrote _externals.json")


if __name__ == "__main__":
    main()
