#!/usr/bin/env python3
"""
InsureDAO v2 L2 follow-up reads — READ-ONLY, keyless RPCs.
Adds per-market details (attributionDebt, lockedAmount, totalCredit, rewardPerCredit,
marketStatus uints, vault.debts) to state.json at the same block heights.
"""
import json
import time
import urllib.request

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36"

RPCS = {
    "arbitrum": ["https://arb1.arbitrum.io/rpc", "https://arbitrum.llamaindex.com" if False else "https://arbitrum.llamarpc.com"],
    "optimism": ["https://mainnet.optimism.io", "https://optimism.publicnode.com"],
    "astar": ["https://evm.astar.network", "https://astar.api.onfinality.io/public"],
}

SEL = {
    "attributionDebt": "0xefb6f55c",
    "lockedAmount": "0x6ab28bc8",
    "totalCredit": "0xa43d6404",
    "rewardPerCredit": "0x1e34b3d7",
    "pendingEnd": "0xca145f34",
    "allInsuranceCount": "0x9d4c6d91",
    "totalAllocatedCredit": "0xb1b044de",
    "totalAllocPoint": "0x17caf6f1",
    "targetLev": "0x5b4fb573",
    "marketStatus": "0xe0e081d7",
    "paused": "0x5c975abb",
    "locked": "0xcf309012",
    "totalLiquidity": "0x15770f92",
    "originalLiquidity": "0x00d89ed6",
    "availableBalance": "0xab2f0e51",
    "debts": "0x2ecd4e7d",
    "attributions": "0x6b4067af",
    "underlyingValue": "0x2f9ef012",
    "indexList0": "0x876ce18f",
    "marketList0": "0x232b956c",
}


def rpc_call(rpcs, method, params, timeout=45, retries=3):
    last = None
    for _ in range(retries):
        for url in rpcs:
            try:
                payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
                req = urllib.request.Request(
                    url, data=json.dumps(payload).encode(),
                    headers={"Content-Type": "application/json", "User-Agent": UA},
                )
                with urllib.request.urlopen(req, timeout=timeout) as r:
                    body = json.load(r)
                if "result" in body:
                    return body["result"], None
                last = f"{url}: {body.get('error', {}).get('message')}"
            except Exception as e:
                last = f"{url}: {e!r}"
        time.sleep(1)
    return None, last


def eth_call(rpcs, to, data, block):
    return rpc_call(rpcs, "eth_call", [{"to": to, "data": data}, block])


def dec(h):
    if h is None or h == "0x":
        return None
    try:
        return int(h, 16)
    except Exception:
        return None


def pad(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def main():
    state = json.load(open("state.json"))
    for chain, v in state.items():
        rpcs = RPCS[chain]
        block = hex(v["block"]) if v["block"] else "latest"
        vault = v["vault"]
        print(f"##### {chain} block {v['block']} #####", flush=True)
        for m, info in v["markets_info"].items():
            det = {}
            for key in ["attributionDebt", "lockedAmount", "totalCredit", "rewardPerCredit",
                        "pendingEnd", "allInsuranceCount", "totalAllocatedCredit",
                        "totalAllocPoint", "targetLev", "marketStatus", "paused", "locked",
                        "totalLiquidity", "originalLiquidity", "availableBalance"]:
                res, err = eth_call(rpcs, m, SEL[key], block)
                det[key] = dec(res)
                if err:
                    det[key + "_err"] = err
            det["vault_debts_live"] = dec(eth_call(rpcs, vault, SEL["debts"] + pad(m), block)[0])
            det["vault_attributions_live"] = dec(eth_call(rpcs, vault, SEL["attributions"] + pad(m), block)[0])
            det["vault_underlyingValue_live"] = dec(eth_call(rpcs, vault, SEL["underlyingValue"] + pad(m), block)[0])
            info["detail"] = det
            print(f"  {m} status={det['marketStatus']} debt={det['attributionDebt']} locked={det['lockedAmount']} "
                  f"credit={det['totalCredit']} OL={det['originalLiquidity']} TL={det['totalLiquidity']} "
                  f"avail={det['availableBalance']} vDebt={det['vault_debts_live']}", flush=True)
        with open("state.json", "w") as f:
            json.dump(state, f, indent=1, default=str)
    print("DONE", flush=True)


if __name__ == "__main__":
    main()
