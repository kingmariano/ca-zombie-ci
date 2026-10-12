#!/usr/bin/env python3
"""Read-only live-state probe for Splice Finance Blast vaults + their SYs.
Public keyless RPCs only. No transactions. No secrets."""
import json, time, urllib.request, sys

RPCS = ["https://rpc.blast.io", "https://blast.drpc.org", "https://blast-rpc.publicnode.com"]
LATEST = None

def rpc_call(rpc, method, params, retries=4, timeout=45):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(rpc, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                j = json.loads(r.read())
            if "result" in j: return j["result"]
            last = str(j.get("error"))[:160]
            if "revert" in last.lower(): return "REVERT"
            time.sleep(0.5)
        except Exception as e:
            last = str(e)[:120]; time.sleep(0.7)
    return {"error": last}

def call(to, data, block="latest"):
    for rpc in RPCS:
        r = rpc_call(rpc, "eth_call", [{"to": to, "data": data}, block])
        if not isinstance(r, dict) or "error" not in r:
            return r
    return None

def w(hexs):
    h = hexs[2:] if hexs.startswith("0x") else hexs
    return [h[i:i+64] for i in range(0, len(h), 64)] if h else []

def addr_from(w):
    return "0x" + w[-40:].lower()

def u256(r):
    if r is None or r == "REVERT": return None
    return int(r, 16)

def as_addr(r):
    if r is None or r == "REVERT": return None
    return addr_from(w(r)[0]) if w(r) else None

def as_str(r):
    if r is None or r == "REVERT": return None
    ws = w(r)
    if len(ws) >= 3:
        try:
            off = int(ws[0], 16) // 32
            ln = int(ws[off], 16)
            data = "".join(ws[off+1:off+1+(ln+31)//32])[:ln*2]
            return bytes.fromhex(data).decode("utf-8", "replace").strip("\x00")
        except Exception: return None
    return None

def as_bool(r):
    v = u256(r)
    return None if v is None else bool(v)

def pad(a): return a.lower().replace("0x", "").rjust(64, "0")

def sig_call(sig):  # keccak selector via cast-free: precomputed only; use cast for new ones
    raise NotImplementedError

# --- precomputed selectors (verify with cast sig) ---
SEL = {
 "name":"0x06fdde03","symbol":"0x95d89b41","decimals":"0x313ce567","asset":"0x38d52e0f",
 "totalAssets":"0x01e1d114","totalSupply":"0x18160ddd","balanceOf":"0x70a08231",
 "convertToAssets":"0x07a2d13a","convertToShares":"0xc6e6f592","previewRedeem":"0x4cdad506",
 "previewWithdraw":"0x0a28a477","maxWithdraw":"0xce96cb77","maxRedeem":"0xd905777e",
 "owner":"0x8da5cb5b","paused":"0x5c975abb","exchangeRate":"0x3ba0b9a9","yieldToken":"0x76d5de85",
 "supplyCap":"0x8f770ad0","totalAssetValue":"0x8f90ae5a","getDepositCap":"0x01a598da",
 "interestFeeBips":"0x397f1133","longPool":"0x9c307ca2","shortPool":"0xb8fae763",
 "strategyDebt":"0x80d57855","getYieldMode":"0xa73ea62d","claimable":"0xaf38d757",
 "router":"0xf887ea40","depositCap":"0xdbd5edc7","totalDebt":"0xfc7b9c18",
 "getNewInterest":"0x0180983c","isPaused":"0xb187bd26",
}

def probe(addr):
    out = {}
    out["name"] = as_str(call(addr, SEL["name"]))
    out["symbol"] = as_str(call(addr, SEL["symbol"]))
    out["decimals"] = u256(call(addr, SEL["decimals"]))
    out["asset"] = as_addr(call(addr, SEL["asset"]))
    out["totalAssets"] = u256(call(addr, SEL["totalAssets"]))
    out["totalSupply"] = u256(call(addr, SEL["totalSupply"]))
    out["owner"] = as_addr(call(addr, SEL["owner"]))
    out["paused"] = as_bool(call(addr, SEL["paused"]))
    out["convertToAssets_1e18"] = u256(call(addr, SEL["convertToAssets"] + pad(hex(10**18)[2:])))
    out["convertToAssets_1"] = u256(call(addr, SEL["convertToAssets"] + pad("1")))
    out["totalAssetValue"] = u256(call(addr, SEL["totalAssetValue"]))
    out["getDepositCap"] = u256(call(addr, SEL["getDepositCap"]))
    out["interestFeeBips"] = u256(call(addr, SEL["interestFeeBips"]))
    out["exchangeRate"] = u256(call(addr, SEL["exchangeRate"]))
    out["yieldToken"] = as_addr(call(addr, SEL["yieldToken"]))
    out["supplyCap"] = u256(call(addr, SEL["supplyCap"]))
    return out

def probe_vault_extra(vaddr, sy):
    out = {}
    out["asset_balanceOf_vault"] = u256(call(vaddr, SEL["balanceOf"] + pad(vaddr)))
    out["sy_shares_held"] = u256(call(vaddr, SEL["balanceOf"] + pad(sy)))
    sh = out["sy_shares_held"]
    if sh:
        out["previewRedeem_sy_shares"] = u256(call(vaddr, SEL["previewRedeem"] + pad(hex(sh)[2:])))
        out["convertToAssets_sy_shares"] = u256(call(vaddr, SEL["convertToAssets"] + pad(hex(sh)[2:])))
        out["previewWithdraw_of_previewRedeem"] = None
        pr = out["previewRedeem_sy_shares"]
        if pr:
            out["previewWithdraw_of_previewRedeem"] = u256(call(vaddr, SEL["previewWithdraw"] + pad(hex(pr)[2:])))
    out["maxWithdraw_sy"] = u256(call(vaddr, SEL["maxWithdraw"] + pad(sy)))
    out["maxRedeem_sy"] = u256(call(vaddr, SEL["maxRedeem"] + pad(sy)))
    out["strategyDebt_probe"] = {}
    return out

VAULTS = {
 "hUSDB":  "0x390b781BAf1e6Db546cF4e3354b81446947838d2",
 "hWETH":  "0x1856C7e0B559E9d7287473CB4b4786398Db4032A",
 "wUSDB":  "0x4BeD2A922654cAcC2Be974689619768FaBF24855",
 "sWETH":  "0x8A444bF22B490fCcee46959678F070256F06729A",
 "sUSDB":  "0x33413CA090fD09127e0c8cA86a1b68ae00209Ae9",
}
SYS = {
 "hUSDB": "0x13293dacab830d8fa2e0e961fb997b3f37186f46",
 "hWETH": "0xb80ad10dffdd415c2159962c1b35ef6edcf1b505",
 "wUSDB": "0xf904fa59d1eacec21d758ccd2fe43261a1dd5470",
 "sWETH": "0xc28fb4cc69081f9f72c643c47e8fef7b4ab2e7aa",
 "sUSDB": "0x0e999eb7f4e553348703d4ed804079c89e8c92f5",
}

def main():
    global LATEST
    for rpc in RPCS:
        r = rpc_call(rpc, "eth_blockNumber", [])
        if isinstance(r, str):
            LATEST = int(r, 16); print("RPC", rpc, "block", LATEST); break
    res = {"block": LATEST, "vaults": {}, "sys": {}}
    for k, v in VAULTS.items():
        res["vaults"][k] = {"address": v, **probe(v)}
        print(k, json.dumps(res["vaults"][k], default=str)[:600], flush=True)
    for k, s in SYS.items():
        res["sys"][k] = {"address": s, **probe(s)}
        print("SY", k, json.dumps(res["sys"][k], default=str)[:600], flush=True)
    # extras
    for k, v in VAULTS.items():
        res["vaults"][k].update(probe_vault_extra(v, SYS[k]))
        print("extra", k, json.dumps({kk: vv for kk, vv in res["vaults"][k].items() if kk in ("asset_balanceOf_vault","sy_shares_held","previewRedeem_sy_shares","maxWithdraw_sy","maxRedeem_sy")}, default=str), flush=True)
    # vault balances of SYs (SY tokens held by others?)
    json.dump(res, open("/home/heisenberg/CA/splice-finance/analysis/vault_probe_raw.json", "w"), indent=1, default=str)
    print("saved, block", LATEST)

if __name__ == "__main__":
    main()
