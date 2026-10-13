#!/usr/bin/env python3
"""CI job: dump the live Mycelium state from a public Arbitrum RPC into ci-out/live-state.json.
No secrets: uses ARB_RPC_URL if provided, else a keyless public endpoint. Keys never printed."""
import json, os, subprocess, sys, urllib.request, time

RPC = os.environ.get("ARB_RPC_URL") or "https://arb1.arbitrum.io/rpc"

def rpc(method, params):
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json",
                                          "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read()).get("result")

def call(to, sig, args=None):
    cmd = ["cast", "calldata", sig] + (args or [])
    data = subprocess.check_output(cmd).decode().strip()
    for attempt in range(3):
        try:
            out = subprocess.check_output(["cast", "call", to, data, "--rpc-url", RPC]).decode().split()
            return int(out[0], 16)
        except Exception as e:
            if attempt == 2:
                return f"ERR:{e}"
            time.sleep(2)

def call_addr(to, sig):
    cmd = ["cast", "calldata", sig]
    data = subprocess.check_output(cmd).decode().strip()
    out = subprocess.check_output(["cast", "call", to, data, "--rpc-url", RPC]).decode().split()
    return out[0]

def call_bool(to, sig, args=None):
    return bool(call(to, sig, args))

VAULT = "0xDfbA8AD57d2c62F61F0a60B2C508bCdeb182f855"
MLPMGR = "0x2DE28AB4827112Cd3F89E5353Ca5A8D80dB7018f"
ORDERBOOK = "0x2eeef7852a306a580acf94f7c18c3ff124a59d4f"
TOKENS = {
    "WBTC": "0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f",
    "WETH": "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
    "USDC": "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
    "LINK": "0xf97f4df75117a78c1A5a0DBb814Af92458539FB4",
    "UNI": "0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0",
    "USDT": "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9",
    "FRAX": "0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F",
    "DAI": "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1",
}
STAKING = {
    "tracker2023": "0xF9B003Ee160dA9677115Ad3c5bd6BB6dADcB2F93",
    "feeMlpTracker": "0xF0BFB95087E611897096982c33B6934C8aBfA083",
    "stakedMlpTracker": "0xF7Bd2ed13BEf9C27a2188f541Dc5ED85C5325306",
}
WETH = TOKENS["WETH"]

def main():
    blk = int(rpc("eth_blockNumber", []), 16)
    out = {"block": blk, "rpc": "public-or-secret(redacted)", "vault": {}, "staking": {}, "flags": {}}
    out["flags"]["isSwapEnabled"] = call_bool(VAULT, "isSwapEnabled()(bool)")
    out["flags"]["isLeverageEnabled"] = call_bool(VAULT, "isLeverageEnabled()(bool)")
    out["flags"]["inPrivateLiquidationMode"] = call_bool(VAULT, "inPrivateLiquidationMode()(bool)")
    out["flags"]["inManagerMode"] = call_bool(VAULT, "inManagerMode()(bool)")
    out["flags"]["gov"] = call_addr(VAULT, "gov()(address)")
    out["flags"]["mlpManager.inPrivateMode"] = call_bool(MLPMGR, "inPrivateMode()(bool)")
    data = subprocess.check_output(["cast", "calldata", "getAum(bool)", "false"]).decode().strip()
    res = rpc("eth_call", [{"to": MLPMGR, "data": data}, "latest"])
    out["flags"]["mlpManager.getAum_reverts"] = res is None
    for name, addr in TOKENS.items():
        bal = call(addr, "balanceOf(address)(uint256)", [VAULT])
        pool = call(VAULT, "poolAmounts(address)(uint256)", [addr])
        buf = call(VAULT, "bufferAmounts(address)(uint256)", [addr])
        res = call(VAULT, "reservedAmounts(address)(uint256)", [addr])
        out["vault"][name] = {"balance": bal, "pool": pool, "buffer": buf, "reserved": res,
                              "swap_out_blocked_by_buffer": isinstance(buf, int) and isinstance(pool, int) and buf > pool}
    for name, addr in STAKING.items():
        out["staking"][name] = {
            "weth_balance": call(WETH, "balanceOf(address)(uint256)", [addr]),
            "totalSupply": call(addr, "totalSupply()(uint256)"),
        }
    # order book pending swap order 1 (known)
    out["orderbook"] = {"weth": call(WETH, "balanceOf(address)(uint256)", [ORDERBOOK])}
    os.makedirs("ci-out", exist_ok=True)
    with open("ci-out/live-state.json", "w") as f:
        json.dump(out, f, indent=1)
    print(json.dumps(out, indent=1))

if __name__ == "__main__":
    main()
