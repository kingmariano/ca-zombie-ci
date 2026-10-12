#!/usr/bin/env python3
"""Quote ezETH/WETH cAMM stable pool via on-chain getAmountOut + compute implied prices.
Keyless public RPC. Output: analysis/quotes_top_pair.json
"""
import json, urllib.request

import os
RPC = os.environ.get("LINEA_RPC_URL", "https://rpc.linea.build")
PAIR = "0xa9a1fb9f6664a0b6bfb1f52724fd7b23842248c5"
EZ = "0x2416092f143378750bb29b79eD961ab195CcEea5"
WETH = "0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f"

def eth_call(to, data):
    payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_call",
               "params": [{"to": to, "data": data}, "latest"]}
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        res = json.load(r)
    if "error" in res:
        return None, res["error"]
    return res["result"], None

def get_amount_out(amount_in, token_in):
    sel = "0x" + "f0b45d21"  # placeholder; use cast-derived selector
    # getAmountOut(uint256,address) selector
    sel = "0x"
    import subprocess
    return None

# compute selector via keccak (implement tiny keccak? easier: use cast)
import subprocess
sel = subprocess.run(["cast", "sig", "getAmountOut(uint256,address)"], capture_output=True, text=True).stdout.strip()
print("selector:", sel)

results = []
for token_in, name in [(EZ, "ezETH->WETH"), (WETH, "WETH->ezETH")]:
    for amt in [0.001, 0.01, 0.1, 0.5, 1, 2, 5, 10, 20, 30, 44, 80]:
        data = sel + hex(int(amt * 1e18))[2:].rjust(64, "0") + token_in[2:].lower().rjust(64, "0")
        out, err = eth_call(PAIR, data)
        if err:
            results.append({"dir": name, "in": amt, "out": None, "err": str(err)[:120]})
            continue
        val = int(out, 16) if out and out != "0x" else None
        results.append({"dir": name, "in": amt, "out_wei": val,
                        "out": (val / 1e18) if val is not None else None})

for r in results:
    print(r)

json.dump(results, open("analysis/quotes_top_pair.json", "w"), indent=1)
