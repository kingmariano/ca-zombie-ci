#!/usr/bin/env python3
"""Read-only probes (child-audit-1). Public RPCs only. No secrets.

 - Fetch runtime bytecode for a list of tokens and search for 4-byte selectors.
 - Fetch live owner() and code size of owner.
"""
import json, os, sys, urllib.request
from concurrent.futures import ThreadPoolExecutor

RPC = os.environ.get("BSC_RPC_URL") or "https://bsc-rpc.publicnode.com"
FALLBACKS = ["https://bsc.drpc.org", "https://1rpc.io/bnb"]
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) child-audit", "Content-Type": "application/json"}

TOKENS = {
    "PINK":     "0x702b3f41772e321aaccdea91e1fcef682d21125d",
    "PinkE":    "0x8DA0F18e4deB7Ba81dBD061DF57325a894014B5a",
    "MEV":      "0x0d51df3eDBe1fa664c6499A6E28C7B65a2fEd9c7",
    "ARS":      "0x05a0E3f9ca0394f9C83DC2b47D1FD3807Cc51d1F",
    "ERODE":    "0x35EbCb2dde0d407CdF67cE9DbEC363079D78A6CB",
    "PinkM":    "0xb6090a50f66046E3c6aFB9311846a6432E45060A",
    "Infi":     "0x6fe7ba1331bF4Cc59479a34773b64cb6C6c3d2af",
    "McDOGE":   "0x65D06b352cA71099CE65B9C7EcB22151da5fD37A",
    "SAFEHOLD": "0xEce59e58046179A762513727607629641190e421",
    "COG":      "0xCE1dB03de797Ffb5bFE98e3903f2CBEc841b26f8",
    "BNBC":     "0x64F6b684a2d14C7681d001D7357ecD888c9473cC",
}

SEL = {
    "mint(address,uint256)": "40c10f19",
    "mint(uint256)": "a0712d68",
    "burn(uint256)": "42966c68",
    "burnFrom(address,uint256)": "79cc6790",
    "owner()": "8da5cb5b",
    "getOwner()": "893d20e8",
    "renounceOwnership()": "715018a6",
    "transferOwnership(address)": "f2fde38b",
}

def rpc(method, params, timeout=30):
    last = None
    for url in [RPC] + FALLBACKS:
        try:
            body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
            req = urllib.request.Request(url, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read().decode())
            if "result" in d:
                return d["result"]
            raise RuntimeError(f"jsonrpc error: {d.get('error')}")
        except RuntimeError:
            raise
        except Exception as e:
            last = f"{type(e).__name__}: {e}"
    raise RuntimeError(f"rpc fail {method}: {last}")

def code(addr):
    return rpc("eth_getCode", [addr, "latest"])

def call(addr, data):
    return rpc("eth_call", [{"to": addr, "data": data}, "latest"])

def main():
    print("== runtime bytecode selector presence (hex substring) ==")
    for name, addr in TOKENS.items():
        c = code(addr).lower()
        nbytes = (len(c) - 2) // 2
        found = [s for s, h in SEL.items() if h in c[2:]]
        print(f"{name:9s} {addr} code={nbytes}B selectors={found}")

    print("\n== live owner() / getOwner() ==")
    for name, addr in TOKENS.items():
        for fn, sel in (("owner()", "0x8da5cb5b"), ("getOwner()", "0x893d20e8")):
            try:
                r = call(addr, sel)
                own = "0x" + r[-40:]
                if len(r) >= 42:
                    oc = code(own)
                    osz = (len(oc) - 2) // 2
                    print(f"{name:9s} {fn} -> {own} (owner code size {osz}B)")
                break
            except Exception as e:
                continue
        else:
            print(f"{name:9s} owner()/getOwner() -> REVERT/absent")

    print("\n== revert-data probe for mint/burn selectors (with dummy args) ==")
    # if function exists but gated, revert WITH reason; absent -> empty revert (assuming no fallback)
    probes = {
        "mint(uint256)": "0xa0712d68" + "0" * 64,
        "mint(address,uint256)": "0x40c10f19" + "1".rjust(64, "0") + "0" * 64,
        "burn(uint256)": "0x42966c68" + "0" * 64,
    }
    for name, addr in TOKENS.items():
        out = []
        for fn, data in probes.items():
            try:
                r = call(addr, data)
                out.append(f"{fn}:RETURNED({r[:20]})")
            except Exception as e:
                msg = str(e)
                if "execution reverted" in msg:
                    out.append(f"{fn}:revert")
                else:
                    out.append(f"{fn}:ERR")
        print(f"{name:9s} " + " | ".join(out))

if __name__ == "__main__":
    main()
