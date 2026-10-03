#!/usr/bin/env python3
"""C-26 supplementary: same module address on Base + Arbitrum.
Module-state verification on-chain, balances via Blockscout (with price fields), native via RPC.
Writes ci-out/crosschain.json. Read-only."""
import json, os, time, urllib.request, urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.environ.get("OUT", os.path.join(HERE, "..", "ci-out"))
os.makedirs(OUT, exist_ok=True)
MODULE = "0x1f1d37a3Bf840e35c6a860c7C2dA71Fe555123ca"
SEL_ISENABLED = "0x2d9ad53d"
SEL_PM = "0xfca402ed"
SEL_DELEG = "0x934cf4d1"
CHAINS = {
    "base": {"rpc": os.environ.get("BASE_RPC_URL") or "https://mainnet.base.org",
             "bs": "https://base.blockscout.com", "slug": "base"},
    "arbitrum": {"rpc": os.environ.get("ARB_RPC_URL") or "https://arb1.arbitrum.io/rpc",
                 "bs": "https://arbitrum.blockscout.com", "slug": "arb1"},
}


def http_json(url, tries=3):
    for a in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=45) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            print("retry", url[:70], e, flush=True)
            time.sleep(2 + 2 * a)
    return None


def rpc(url, method, params, tries=5):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for a in range(tries):
        try:
            req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json",
                                                                  "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=45) as r:
                return json.loads(r.read().decode()).get("result")
        except Exception as e:
            print("rpc retry", e, flush=True)
            time.sleep(2 + 2 * a)
    return None


def main():
    eth_price = None
    d = http_json("https://coins.llama.fi/prices/current/ethereum:0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2")
    try:
        eth_price = d["coins"]["ethereum:0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"]["price"]
    except Exception:
        pass

    out = {"module": MODULE, "eth_price": eth_price, "chains": {}}
    for chain, cfg in CHAINS.items():
        print("=====", chain, flush=True)
        rec = {"rpc": cfg["rpc"], "module_deployed": False, "safes": []}
        code = rpc(cfg["rpc"], "eth_getCode", [MODULE, "latest"])
        if not code or code == "0x":
            out["chains"][chain] = rec
            continue
        rec["module_deployed"] = True
        pm = rpc(cfg["rpc"], "eth_call", [{"to": MODULE, "data": SEL_PM}, "latest"])
        rec["permissions_manager"] = "0x" + pm[-40:] if pm and pm != "0x" else None
        d = http_json(f"https://api.safe.global/tx-service/{cfg['slug']}/api/v1/modules/{MODULE}/safes/?limit=100&offset=0") or {}
        safes = d.get("safes", [])
        rec["tx_service_safes"] = len(safes)
        enabled_count = 0
        usd_total = 0.0
        for i, s in enumerate(safes):
            en = rpc(cfg["rpc"], "eth_call", [{"to": s, "data": SEL_ISENABLED + MODULE[2:].rjust(64, "0")}, "latest"])
            enabled = en == "0x" + "0" * 63 + "1"
            native = rpc(cfg["rpc"], "eth_getBalance", [s, "latest"])
            nw = int(native, 16) if native else 0
            toks = http_json(f"{cfg['bs']}/api/v2/addresses/{s}/token-balances") or []
            keep = []
            usd = 0.0
            for it in toks:
                v = int(it.get("value") or 0)
                if v <= 0:
                    continue
                t = it.get("token") or {}
                rate = t.get("exchange_rate")
                try:
                    dec = int(t.get("decimals") or 18)
                except Exception:
                    dec = 18
                u = float(rate) * v / 10 ** dec if rate else None
                if u:
                    usd += u
                keep.append({"address": (t.get("address_hash") or "").lower(), "symbol": t.get("symbol"),
                             "decimals": dec, "value": str(v), "exchange_rate": rate, "usd": u})
            if enabled:
                enabled_count += 1
                usd_total += usd + (nw / 1e18 * eth_price if eth_price else 0)
                rec["safes"].append({"safe": s, "module_enabled_now": True, "native_wei": nw,
                                     "tokens": keep, "token_usd": round(usd, 4)})
            time.sleep(0.25)
            if (i + 1) % 10 == 0:
                print(f"  [{i+1}/{len(safes)}]", flush=True)
        rec["enabled_now"] = enabled_count
        rec["enabled_usd_estimate"] = round(usd_total, 2)
        out["chains"][chain] = rec
        print(f"{chain}: enabled={enabled_count} usd~{usd_total:.2f}", flush=True)
        json.dump(out, open(os.path.join(OUT, "crosschain.json"), "w"), indent=1)
    json.dump(out, open(os.path.join(OUT, "crosschain.json"), "w"), indent=1)
    print("saved crosschain.json", flush=True)


if __name__ == "__main__":
    main()
