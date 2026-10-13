#!/usr/bin/env python3
"""Map InsureDAO markets: clone implementation, vault, pause state, pools.
Read-only. RPC URL from env (never written to disk)."""
import json, os, sys, urllib.request

RPCS = [u for u in [os.environ.get("RPC_URL"), "https://ethereum-rpc.publicnode.com",
                    "https://eth.drpc.org", "https://eth.llamarpc.com"] if u]
RPC = RPCS[0]
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"
MARKETS = [
    "0x1CF1195aFB01DD115647E4989e63AfE6DdD65030",
    "0xDFdFcFEdb96e0979825C6B463cb8a971fE367d5D",
    "0xC03Ab4bB777Edf97e8692bd125968358aD3b7F08",
    "0xbDB009e6C9dd3F77d6A7f507A4F817133677257c",
    "0x22453153978D0C25f86010c0fd405527feD9764b",
    "0x8dfFb0c2b2d0A126f13667C0825ba7c026ECb24a",
    "0x8c4943100bEc96e3381a544Da82B91713a4BC062",
    "0x961DfEcFf7C530505BC31FF7fa92dAa0eEED18c7",
    "0x641BE011738C65AAc8FF3f5d4e6dedbBD7411f47",
    "0x0a3f739246846fC024F7f8dd5CBe7E0adf77760F",
    "0xB0AC0465320E9289BE7a9dF0d86B136d56C83722",
    "0xbb236F4D55EAc44713e6A3E623f7775550266887",
    "0x58803187E676b180eD12b4F7d79b94cA011f4b8e",
    "0xB127A53646EEfF7a0a787b754258B101D782Db0C",
    "0x7a1815401D91307c883eb987C1Ec16D9812aC8dc",
    "0x3bfE4119De068710485704f974B16C563aEC715f",
    "0xdF7A7BC927a148B78850A789628627681977bb18",
    "0x947031FDDE0156acAd1Ef17C89889FA0c82A8597",
    "0xe0BEF490D49F3dBcbaedAC6F79713F02C73f87Ce",
    "0x772F71eF550a49f3fCd96d5cBdF5dEA2e9233A6a",
    "0x5E9aC74012B9924aC1bB0320d531aa7440c09Cb6",
    "0xB6e3816D4F3C263CAEDB15A6BA65ACA1FCa16318",
    "0x3005f4fA9B678F80216bc3cD8d8a5F7894fC70f2",
    "0x71571F8895803Ee067E4595f5dA3E2C4EF513A69",
    "0x197c8827621aa1A7276D7D7a83eed0D0b7B8B3F2",
    "0xDAea5b1B6b12Ac4c4f51aB12649e96ab3aB98C3A",
    "0xd5f1Ab3c61eF3a6a6f1AA6141256Aa008D2fb5A1",
    "0x7E08daB409Ad1bCeBc5bE5674CB2C0f3540A4d3d",
    "0x86c82E8cD8A865f01A8CeBed870Af5d58e69a439",
]
VAULT = "0x131fb74c6fede6d6710ff224e07ce0ed8123f144"

SIGS = {
    "paused()": "0x5c975abb",
    "vault()": "0xfbfa77cf",
    "parameters()": "0x671b0bdc",
    "registry()": "0x7b103999",
    "crowdPool()": None,   # computed below
    "surplusPool()": None,
    "totalSupply()": "0x18160ddd",
    "metadata()": "0x392f37e9",
    "owner()": "0x8da5cb5b",
    "getOwner()": "0x893d20e8",
    "underlying()": "0x6f307dc3",
    "attributionValue(uint256)": None,
}

def sel(s):
    import hashlib
    k = hashlib.sha3_256  # placeholder; use keccak via cast externally if needed
    return None

def rpc_batch(calls):
    global RPC
    payload = []
    for i, (to, data) in enumerate(calls):
        payload.append({"jsonrpc": "2.0", "id": i, "method": "eth_call",
                        "params": [{"to": to, "data": data}, "latest"]})
    last_err = None
    for url in RPCS:
        try:
            req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                         headers={"Content-Type": "application/json",
                                                  "User-Agent": UA})
            resp = json.load(urllib.request.urlopen(req, timeout=60))
            if isinstance(resp, list):
                RPC = url
                out = {}
                for r in resp:
                    out[r["id"]] = r.get("result")
                return out
        except Exception as e:
            last_err = e
    raise RuntimeError(f"all rpcs failed: {last_err}")

def main():
    # use cast to compute selectors to avoid keccak dependency
    import subprocess
    def selector(sig):
        return subprocess.check_output(["cast", "sig", sig]).decode().strip()
    sigs = {
        "paused": selector("paused()"),
        "vault": selector("vault()"),
        "parameters": selector("parameters()"),
        "registry": selector("registry()"),
        "crowdPool": selector("crowdPool()"),
        "surplusPool": selector("surplusPool()"),
        "totalSupply": selector("totalSupply()"),
        "metadata": selector("metadata()"),
        "underlying": selector("underlying()"),
        "attributions": selector("attributions(address)"),
        "attributionAll": selector("attributionAll()"),
        "valueAll": selector("valueAll()"),
        "owner": selector("owner()"),
        "getOwner": selector("getOwner()"),
        "totalLiquidity": selector("totalLiquidity()"),
        "initialized": selector("initialized()"),
    }
    calls = []
    meta = []
    for m in MARKETS:
        calls.append((m, "0x" + sigs["paused"][2:]))
        meta.append((m, "paused"))
        calls.append((m, "0x" + sigs["vault"][2:]))
        meta.append((m, "vault"))
        calls.append((m, "0x" + sigs["parameters"][2:]))
        meta.append((m, "parameters"))
        calls.append((m, "0x" + sigs["crowdPool"][2:]))
        meta.append((m, "crowdPool"))
        calls.append((m, "0x" + sigs["surplusPool"][2:]))
        meta.append((m, "surplusPool"))
        calls.append((m, "0x" + sigs["totalSupply"][2:]))
        meta.append((m, "totalSupply"))
        calls.append((m, "0x" + sigs["metadata"][2:]))
        meta.append((m, "metadata"))
        calls.append((m, "0x" + sigs["underlying"][2:]))
        meta.append((m, "underlying"))
        calls.append((VAULT, sigs["attributions"] + m[2:].rjust(64, "0")))
        meta.append((m, "vaultAttrib"))
        calls.append((m, "0x" + sigs["totalLiquidity"][2:]))
        meta.append((m, "totalLiquidity"))
    res = rpc_batch(calls)
    # get code for each market to extract clone impl
    codes = {}
    payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_getCode",
                "params": [m, "latest"]} for i, m in enumerate(MARKETS)]
    last_err = None
    resp = None
    for url in RPCS:
        try:
            req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                         headers={"Content-Type": "application/json",
                                                  "User-Agent": UA})
            resp = json.load(urllib.request.urlopen(req, timeout=60))
            if isinstance(resp, list):
                break
            resp = None
        except Exception as e:
            last_err = e
    if resp is None:
        raise RuntimeError(f"all rpcs failed for codes: {last_err}")
    for r in resp:
        codes[MARKETS[r["id"]]] = r.get("result")
    def dec(x):
        if x is None or x == "0x":
            return None
        return int(x, 16)
    out = {}
    for i, (m, field) in enumerate(meta):
        v = res.get(i)
        if field == "metadata":
            try:
                b = bytes.fromhex(v[2:])
                ln = int.from_bytes(b[64:96], "big")
                v = b[96:96+ln].decode("utf-8", "replace")
            except Exception:
                v = None
        else:
            v = dec(v)
        out.setdefault(m, {})[field] = v
    for m in MARKETS:
        code = codes.get(m) or ""
        impl = None
        if code.startswith("0x363d3d373d3d3d363d73"):
            impl = "0x" + code[2+20:2+20+40]
        out[m]["impl"] = impl
    print(json.dumps({"block": None, "markets": out}, indent=1))

if __name__ == "__main__":
    main()
