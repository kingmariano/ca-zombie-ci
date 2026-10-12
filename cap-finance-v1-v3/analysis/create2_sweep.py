#!/usr/bin/env python3
"""Compute CREATE2 addresses from the v4 deployer's txs to the deterministic proxy,
then check code + balances of each deployed contract."""
import json, os, subprocess, urllib.request, time

key = os.environ["ETHERSCANV2_API_KEY"]
RPC = os.environ.get("ARB_RPC", "https://arb1.arbitrum.io/rpc")
PROXY = "0x4e59b44847b379578588920ca78fbf26c0b4956c"
DEPLOYER = "0x764E7f8798D8193bEd69030AE66eb304968C3F93"
USDC = "0xff970a61a04b1ca14834a43f5de4533ebddb5cc8"

def keccak(b):
    out = subprocess.check_output(["cast", "keccak", "0x" + b.hex()]).decode().strip()
    return bytes.fromhex(out[2:])

# fetch txs
txs = []
for page in range(1, 4):
    url = (f"https://api.etherscan.io/v2/api?chainid=42161&module=account&action=txlist"
           f"&address={DEPLOYER}&startblock=0&endblock=latest&page={page}&offset=1000&sort=asc&apikey={key}")
    d = json.load(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=60))
    res = d.get("result", [])
    if not isinstance(res, list):
        break
    txs.extend(res)
    if len(res) < 1000:
        break
print("total txs:", len(txs))

proxy_txs = [t for t in txs if (t.get("to") or "").lower() == PROXY and t.get("input", "").startswith("0x")]
print("txs to CREATE2 proxy:", len(proxy_txs))

addrs = []
for t in proxy_txs:
    inp = t["input"][2:]
    if len(inp) < 128:
        continue
    salt = bytes.fromhex(inp[:64])
    initcode = bytes.fromhex(inp[64:])
    h = keccak(b"\xff" + bytes.fromhex(PROXY[2:]) + salt + keccak(initcode))
    addr = "0x" + h[12:].hex()
    addrs.append({"addr": addr, "tx": t["hash"], "block": int(t["blockNumber"]), "ts": int(t["timeStamp"])})
print("computed CREATE2 addresses:", len(addrs))

# check code + balances
def rpc(method, params):
    payload = [{"jsonrpc": "2.0", "id": 0, "method": method, "params": params}]
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    d = json.load(urllib.request.urlopen(req, timeout=30))
    return d[0].get("result")

results = []
for a in addrs:
    code = rpc("eth_getCode", [a["addr"], "latest"]) or "0x"
    bal = int(rpc("eth_getBalance", [a["addr"], "latest"]) or "0x0", 16)
    # USDC balanceOf
    data = "0x70a08231" + a["addr"][2:].rjust(64, "0")
    r = rpc("eth_call", [{"to": USDC, "data": data}, "latest"])
    usdc = int(r, 16) if r and r != "0x" else 0
    rec = {**a, "codelen": (len(code) - 2) // 2, "eth": bal / 1e18, "usdc": usdc / 1e6}
    results.append(rec)
    time.sleep(0.05)

results.sort(key=lambda r: -(r["eth"] + r["usdc"]))
print(f"\n{'address':44} {'codelen':>7} {'ETH':>10} {'USDC':>10} block ts")
for r in results:
    print(f"{r['addr']:44} {r['codelen']:>7} {r['eth']:>10.5f} {r['usdc']:>10.3f} {r['block']} {r['ts']}")
json.dump(results, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "state", "create2-deployments.json"), "w"), indent=1)
