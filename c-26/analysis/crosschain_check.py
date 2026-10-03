#!/usr/bin/env python3
"""Supplementary: quantify the same SquidRouterModule surface on Base and Arbitrum.
Checks module code, PM address, per-Safe isModuleEnabled + balances (Blockscout + RPC)."""
import json, os, time, urllib.request, urllib.parse

ANALYSIS = "/home/heisenberg/CA/c-26/analysis"
MODULE = "0x1f1d37a3Bf840e35c6a860c7C2dA71Fe555123ca"
CHAINS = {
    "base": {"rpc": "https://mainnet.base.org", "bs": "https://base.blockscout.com", "id": 8453},
    "arbitrum": {"rpc": "https://arb1.arbitrum.io/rpc", "bs": "https://arbitrum.blockscout.com", "id": 42161},
}
SEL_ISENABLED = "0x2d9ad53d"
SEL_PM = "0xb745ae52"  # permissionsManager() placeholder, computed below
SEL_BALOF = "0x70a08231"


def sig(name):
    return name


def http_json(url, tries=4):
    for a in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=45) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            print("retry", url[:80], e, flush=True)
            time.sleep(2 + a)
    return None


def rpc(url, method, params, tries=4):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for a in range(tries):
        try:
            req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json",
                                                                  "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=45) as r:
                return json.loads(r.read().decode()).get("result")
        except Exception as e:
            print("rpc retry", e, flush=True)
            time.sleep(2 + a)
    return None


def main():
    out = {}
    for chain, cfg in CHAINS.items():
        print("=====", chain, flush=True)
        code = rpc(cfg["rpc"], "eth_getCode", [MODULE, "latest"])
        print("module code size:", len(code or ""), flush=True)
        if not code or code == "0x":
            out[chain] = {"module_deployed": False}
            continue
        # discover permissionsManager from the module: use cast-computed selector via python keccak? use known ABI selector from module source
        # permissionsManager() selector = keccak("permissionsManager()")[:4]
        # computed offline: 0x
        pm_sel = "0xfca402ed"
        pm = rpc(cfg["rpc"], "eth_call", [{"to": MODULE, "data": pm_sel}, "latest"])
        pm_addr = "0x" + pm[-40:] if pm and pm != "0x" else None
        print("permissionsManager:", pm_addr, flush=True)
        # tx service safes
        slug = {"base": "base", "arbitrum": "arb1"}[chain]
        u = f"https://api.safe.global/tx-service/{slug}/api/v1/modules/{MODULE}/safes/?limit=100&offset=0"
        d = http_json(u) or {}
        safes = d.get("safes", [])
        print("tx-service safes:", len(safes), flush=True)
        recs = []
        for i, s in enumerate(safes):
            en = rpc(cfg["rpc"], "eth_call", [{"to": s, "data": SEL_ISENABLED + MODULE[2:].rjust(64, "0")}, "latest"])
            enabled = en == "0x" + "0" * 63 + "1"
            native = rpc(cfg["rpc"], "eth_getBalance", [s, "latest"])
            bal = http_json(f"{cfg['bs']}/api/v2/addresses/{s}/token-balances") or []
            toks = []
            for it in bal:
                v = int(it.get("value") or 0)
                if v > 0:
                    t = it.get("token") or {}
                    toks.append({"address": (t.get("address_hash") or "").lower(),
                                 "symbol": t.get("symbol"), "decimals": t.get("decimals"),
                                 "value": str(v), "exchange_rate": t.get("exchange_rate")})
            grants = None
            if enabled:
                gr = rpc(cfg["rpc"], "eth_call",
                         [{"to": pm_addr, "data": "0x934cf4d1" + s[2:].rjust(64, "0")}, "latest"])
                grants = gr
            recs.append({"safe": s, "module_enabled_now": enabled,
                         "native_wei": int(native, 16) if native else None,
                         "tokens": toks, "delegators_raw": grants})
            time.sleep(0.3)
            if (i + 1) % 10 == 0:
                print(f"  [{i+1}/{len(safes)}]", flush=True)
        out[chain] = {"module_deployed": True, "permissions_manager": pm_addr, "safes": recs}
        json.dump(out, open(os.path.join(ANALYSIS, "crosschain", f"{chain}.json"), "w"), indent=1)
    print(json.dumps({k: (len(v.get("safes", [])) if v.get("module_deployed") else 0) for k, v in out.items()}))


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "sel":
        # compute selectors without external libs: keccak not available; hardcode after cast
        pass
    os.makedirs(os.path.join(ANALYSIS, "crosschain"), exist_ok=True)
    main()
