#!/usr/bin/env python3
"""Read-only state dump for Muscadine vaults on Base. No secrets: uses public keyless RPC."""
import json, urllib.request, sys, time

RPCS = ["https://mainnet.base.org", "https://base.publicnode.com", "https://base.drpc.org"]
RPC = RPCS[0]

SEL = {
 "asset":"0x38d52e0f","name":"0x06fdde03","symbol":"0x95d89b41","decimals":"0x313ce567",
 "totalAssets":"0x01e1d114","totalSupply":"0x18160ddd","owner":"0x8da5cb5b","curator":"0xe66f53b7",
 "guardian":"0x452a9320","receiveSharesGate":"0x7e729ac4","sendSharesGate":"0x93ab2ab7",
 "receiveAssetsGate":"0x54cde13e","sendAssetsGate":"0x8eede801","adapterRegistry":"0x50b5c16a",
 "adaptersLength":"0x5aa22bc8","adapters":"0x4ef501ac","liquidityAdapter":"0xad468d11",
 "liquidityData":"0x2e029228","maxRate":"0xece1d6e5","performanceFee":"0x87788782",
 "performanceFeeRecipient":"0xed27f7c9","managementFee":"0xa6f7f5d6","managementFeeRecipient":"0x6d9a3010",
 "virtualShares":"0xc719946c","lastUpdate":"0xc0463711","_totalAssets":"0xce04bebb",
 "isAllocator":"0x4dedf20e","isSentinel":"0xba03a75f","forceDeallocatePenalty":"0x99e99183",
 "allocation":"0xc69507dd","absoluteCap":"0xbc0dd374","relativeCap":"0xa68bafa3",
 "canReceiveShares":"0x98c9b49c","canSendShares":"0x8e511e4d","canReceiveAssets":"0x0d326b18",
 "canSendAssets":"0x20fe8d58","fee":"0xddca3f43","feeRecipient":"0x46904840","skimRecipient":"0x388af5b5",
 "timelock":"0xd33219b4","supplyQueueLength":"0xa17b3130","withdrawQueueLength":"0x33f91ebb",
 "supplyQueue":"0xf7d18521","withdrawQueue":"0x62518ddf","config":"0xcc718f76",
 "pendingTimelock":"0x7cc4d9a1","pendingGuardian":"0x762c31ba","timelock_sel":"0xe78ab14e",
 "abdicated":"0xe470b8bc","balanceOf":"0x70a08231","previewRedeem":"0x4cdad506",
 "previewWithdraw":"0x0a28a477","convertToAssets":"0x07a2d13a","convertToShares":"0xc6e6f592",
 "isAllocatorMM":"0x28c1ba97",  # MetaMorpho isAllocator(address) selector? verify later
}

def enc_addr(a): return a.lower().replace("0x","").rjust(64,"0")
def enc_uint(n): return hex(n)[2:].rjust(64,"0")
def enc_b32(b): return b.lower().replace("0x","").rjust(64,"0")

def rpc_batch(calls, tries=3):
    """calls: list of (to, data). Returns list of results (hex strings or None on error)."""
    for attempt in range(tries):
        rpc = RPCS[attempt % len(RPCS)]
        payload = [{"jsonrpc":"2.0","id":i,"method":"eth_call","params":[{"to":t,"data":d},"latest"]} for i,(t,d) in enumerate(calls)]
        req = urllib.request.Request(rpc, data=json.dumps(payload).encode(), headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
        try:
            out = json.load(urllib.request.urlopen(req, timeout=40))
            res = {}
            for item in out:
                res[item["id"]] = item.get("result")
            return [res.get(i) for i in range(len(calls))]
        except Exception as e:
            print(f"  rpc batch failed ({rpc}): {e}", file=sys.stderr)
            time.sleep(2)
    return [None]*len(calls)

def dec_uint(h):
    if not h or h == "0x": return None
    return int(h,16)
def dec_addr(h):
    if not h or h == "0x": return None
    return "0x"+h[-40:]
def dec_str(h):
    if not h or h=="0x": return None
    b = bytes.fromhex(h[2:])
    try:
        if len(b) >= 64:
            off = int.from_bytes(b[:32],"big"); ln = int.from_bytes(b[off:off+32],"big")
            return b[off+32:off+32+ln].decode()
    except Exception: pass
    return h

VAULTS = {
 "usdc_v1":   ("0xf7e26Fa48A568b8b0038e104DfD8ABdf0f99074F","mm"),
 "cbbtc_v1":  ("0xAeCc8113a7bD0CFAF7000EA7A31afFD4691ff3E9","mm"),
 "weth_v1":   ("0x21e0d366272798da3A977FEBA699FCB91959d120","mm"),
 "usdc_prime":("0x89712980cb434ef5ae4ab29349419eb976b0b496","v2"),
 "weth_prime":("0xd6dcad2f7da91fbb27bda471540d9770c97a5a43","v2"),
 "cbbtc_prime":("0x99dcd0d75822ba398f13b2a8852b07c7e137ec70","v2"),
 "usdc_frontier":("0x314fD07319ef645bA7D548915CCd91F4788A1839","v2"),
}

out = {"rpc": RPC, "vaults": {}}
for name,(addr,kind) in VAULTS.items():
    print("=== ", name, addr)
    v = {"address": addr, "kind": kind}
    calls = []
    def add(key, sel, arg=None):
        d = SEL[sel] + (arg if arg else "")
        calls.append((addr, d)); return key
    keys = []
    keys.append(add("asset","asset")); keys.append(add("name","name")); keys.append(add("symbol","symbol"))
    keys.append(add("decimals","decimals")); keys.append(add("totalAssets","totalAssets")); keys.append(add("totalSupply","totalSupply"))
    keys.append(add("owner","owner")); keys.append(add("curator","curator"))
    if kind=="mm":
        keys.append(add("guardian","guardian")); keys.append(add("fee","fee")); keys.append(add("feeRecipient","feeRecipient"))
        keys.append(add("skimRecipient","skimRecipient")); keys.append(add("timelock","timelock"))
        keys.append(add("supplyQueueLength","supplyQueueLength")); keys.append(add("withdrawQueueLength","withdrawQueueLength"))
        keys.append(add("pendingTimelock","pendingTimelock")); keys.append(add("pendingGuardian","pendingGuardian"))
    else:
        keys.append(add("receiveSharesGate","receiveSharesGate")); keys.append(add("sendSharesGate","sendSharesGate"))
        keys.append(add("receiveAssetsGate","receiveAssetsGate")); keys.append(add("sendAssetsGate","sendAssetsGate"))
        keys.append(add("adapterRegistry","adapterRegistry")); keys.append(add("adaptersLength","adaptersLength"))
        keys.append(add("liquidityAdapter","liquidityAdapter")); keys.append(add("liquidityData","liquidityData"))
        keys.append(add("maxRate","maxRate")); keys.append(add("performanceFee","performanceFee"))
        keys.append(add("performanceFeeRecipient","performanceFeeRecipient"))
        keys.append(add("managementFee","managementFee")); keys.append(add("managementFeeRecipient","managementFeeRecipient"))
        keys.append(add("virtualShares","virtualShares")); keys.append(add("lastUpdate","lastUpdate")); keys.append(add("_totalAssets","_totalAssets"))
    res = rpc_batch(calls)
    for k,h in zip(keys,res):
        if k in ("name","symbol"): v[k]=dec_str(h)
        elif k in ("asset","owner","curator","guardian","feeRecipient","skimRecipient","receiveSharesGate","sendSharesGate","receiveAssetsGate","sendAssetsGate","adapterRegistry","liquidityAdapter","performanceFeeRecipient","managementFeeRecipient"): v[k]=dec_addr(h)
        elif k=="liquidityData": v[k]=h
        else: v[k]=dec_uint(h)
    print(json.dumps(v, indent=1))
    out["vaults"][name]=v

json.dump(out, open("state-dump.json","w"), indent=1)
print("saved state-dump.json")
