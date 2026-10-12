#!/usr/bin/env python3
"""Cross-check deployed runtime bytecode selectors vs verified-source ABI selectors.
Also scans a watchlist of potentially-dangerous selectors.
Read-only. Public RPC only.
"""
import json, os, subprocess, urllib.request

RPC = os.environ.get("BSC_RPC_URL") or "https://bsc-rpc.publicnode.com"
UA = {"User-Agent": "Mozilla/5.0 child-audit", "Content-Type": "application/json"}

TARGETS = {
    "MasterChef":   ("0xe981676633dcf0256aa512f4923a7e8da180c595", "/home/heisenberg/CA/pinkswap/analysis/sources/MasterChef.abi.json"),
    "Factory":      ("0x7d2ce25c28334e40f37b2a068ec8d5a59f11ea54", "/home/heisenberg/CA/pinkswap/analysis/sources/PinkswapFactory.abi.json"),
    "Pair(PinkE/WBNB)": ("0xb9efbd2bb41f7a2136bf2b21e8b26641651adef9", "/home/heisenberg/CA/pinkswap/analysis/sources/PinkswapPair_top.abi.json"),
    "PINK":         ("0x702b3f41772e321aaccdea91e1fcef682d21125d", "/home/heisenberg/CA/pinkswap/analysis/sources/PinkSwapToken.abi.json"),
}

WATCH = {
    "mint(address,uint256)": "40c10f19",
    "mint(uint256)": "a0712d68",
    "burn(uint256)": "42966c68",
    "burnFrom(address,uint256)": "79cc6790",
    "sweep(address)": "01681a62",
    "sweep(address,uint256)": "6ea056a9",
    "withdrawToken(address,uint256)": "9e281a98",
    "claim()": "4e71d92d",
    "drain()": "b87570ab",
    "withdrawAll()": "853828b6",
    "upgradeTo(address)": "3659cfe6",
    "upgradeToAndCall(address,bytes)": "4f1ef286",
    "selfdestruct()": "9cb8a26a",
    "setMigrator(address)": "a9ea1b1e",
}

def rpc(method, params, timeout=30):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for url in [RPC, "https://bsc.drpc.org", "https://1rpc.io/bnb"]:
        try:
            req = urllib.request.Request(url, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read().decode())
            if "result" in d:
                return d["result"]
        except Exception:
            continue
    raise RuntimeError(f"rpc fail {method}")

def canonical_type(inp):
    t = inp["type"]
    if t.startswith("tuple"):
        inner = ",".join(canonical_type(c) for c in inp["components"])
        return f"({inner})" + t[len("tuple"):]
    return t

def sig_of(fn):
    return f"{fn['name']}({','.join(canonical_type(i) for i in fn.get('inputs', []))})"

def selector(sig):
    out = subprocess.run(["cast", "sig", sig], capture_output=True, text=True, check=True)
    return out.stdout.strip().lower().replace("0x", "")

def main():
    for name, (addr, abi_path) in TARGETS.items():
        abi = json.load(open(abi_path))
        fns = [e for e in abi if e.get("type") == "function"]
        code = rpc("eth_getCode", [addr, "latest"]).lower()[2:]
        nbytes = len(code) // 2
        print(f"\n===== {name} {addr} ({nbytes} bytes) =====")
        missing = []
        for fn in fns:
            sig = sig_of(fn)
            if sig in ("mint(address,uint256)", "mint(uint256)"):
                sig = "mint(address,uint256)" if sig == "mint(address,uint256)" else "mint(uint256)"
            try:
                sel = selector(sig)
            except subprocess.CalledProcessError:
                missing.append((sig, "sig-error"))
                continue
            present = sel in code
            if not present:
                missing.append((sig, sel))
            print(f"  [{'OK ' if present else 'MISS'}] {sig} {sel}")
        if missing:
            print(f"  !! ABI functions not found in code: {missing}")
        watch_hits = [w for w, s in WATCH.items() if s in code]
        print(f"  watchlist present: {watch_hits}")

if __name__ == "__main__":
    main()
