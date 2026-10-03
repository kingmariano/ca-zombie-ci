#!/usr/bin/env python3
"""Token balance enumeration for currently-enabled Safes without paid indexers:
1) Etherscan tokentx (last N transfers) per Safe to discover tokens.
2) JSON-RPC batch balanceOf for discovered tokens + curated majors.
3) Native balance.
Outputs analysis/balances/onchain_balances.json
"""
import json, os, time, urllib.request, urllib.parse

ANALYSIS = "/home/heisenberg/CA/c-26/analysis"
KEY = os.environ["ETHERSCANV2_API_KEY"]
RPC = os.environ.get("BLOCKPI_RPC_URL") or os.environ["RPC_URL"]

CURATED = {
    # symbol: address
    "USDC": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    "USDT": "0xdAC17F958D2ee523a2206206994597C13D831ec7",
    "DAI": "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    "WETH": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    "WBTC": "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
    "stETH": "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84",
    "wstETH": "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0",
    "LINK": "0x514910771AF9Ca656af840dff83E8264EcF986CA",
    "UNI": "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984",
    "AAVE": "0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9",
    "MKR": "0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2",
    "CRV": "0xD533a949740bb3306d119CC777fa900bA034cd52",
    "LDO": "0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32",
    "PEPE": "0x6982508145454Ce325dDbE47a25d4ec3d2311933",
    "SHIB": "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE",
    "ENS": "0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72",
    "MATIC": "0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0",
    "COMP": "0xc00e94Cb662C3520282E6f5717214004A7f26888",
    "SNX": "0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F",
    "GRT": "0xc944E90C64B2c07662A292be6244BDf05Cda44a7",
    "1INCH": "0x111111111117dC0aa78b770fA6A738034120C302",
    "SUSHI": "0x6B3595068778DD592e39A122f4f5a5cF09C90fE2",
    "YFI": "0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e",
    "BAL": "0xba100000625a3754423978a60c9317c58a424e3D",
    "RPL": "0xD33526068D116cE69F19A9ee46F0bd304F21A51f",
    "ARB": "0xB50721BCf8d664c30412Cfbc6cf7a15145234ad1",
    "OP": "0x4200000000000000000000000000000000000042",
    "PYUSD": "0x6c3ea9036406852006290770BEdFcAbA0e23A0e8",
    "FRAX": "0x853d955aCEf822Db058eb8505911ED77F175b99e",
    "USDe": "0x4c9EDD5852cd905f086C759E8383e09bff1E68B3",
    "sUSDe": "0x9D39A5DE30e57443BfF2A8307A4256c8797A3497",
    "USDS": "0xdC035D45d973E3EC169d2276DDab16f1e407384F",
    "GHO": "0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f",
    "cbETH": "0xBe9895146f7AF43049ca1c1AE358B0541Ea49704",
    "rETH": "0xae78736Cd615f374D3085123A210448E74Fc6393",
    "ETHx": "0xA35b1B31Ce002FBF2058D22F30f95D405200A15b",
    "ENA": "0x57e114B691Db790C35207b2e685D4A43181e6061",
    "ONDO": "0xfAbA6f8e4a5E8Ab82F62fe7C39859FA577269BE3",
    "JUP": "0x4B1E80cAC91e2216EEb63e29B357d1eBC0d4CEa5",
    "WLD": "0x163f8C2467924be0ae7B5347228CABF260318753",
    "MOG": "0xaaeE1A9723aaDB7afA2810263653A34bA2C21C7a",
    "MORPHO": "0x58D97B57BB95320F9a05dC918Aef65434969c2B2",
    "SPX": "0xE0f63A424a4439cBE457D80E4f4b51aD25b2c56C",
    "BLUR": "0x5283D291DBCF85356A21bA090E6db59121208b44",
    "CAKE": "0x152649eA73beAb28c5b49B26eb48f7EAD6d4c898",
}
# tokens that are not ERC20 `balanceOf(address)`-safe are excluded by try/catch via eth_call results.
SELECTOR = "0x70a08231"


def eth_token_transfers(addr, pages=2):
    out = []
    for page in range(1, pages + 1):
        q = {"chainid": "1", "module": "account", "action": "tokentx", "address": addr,
             "page": str(page), "offset": "500", "sort": "desc", "apikey": KEY}
        url = "https://api.etherscan.io/v2/api?" + urllib.parse.urlencode(q)
        for attempt in range(4):
            try:
                with urllib.request.urlopen(url, timeout=40) as r:
                    d = json.loads(r.read().decode())
                break
            except Exception:
                time.sleep(2)
        else:
            break
        rows = d.get("result") if isinstance(d.get("result"), list) else []
        if not rows:
            break
        out += rows
        if len(rows) < 500:
            break
        time.sleep(0.3)
    return out


def rpc_batch(calls):
    """calls: list of (to, data) -> list of hex results (None on failure)."""
    reqs = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
             "params": [{"to": to, "data": data}, "latest"]} for i, (to, data) in enumerate(calls)]
    body = json.dumps(reqs).encode()
    for attempt in range(4):
        try:
            req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json",
                                                                  "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                resp = json.loads(r.read().decode())
            break
        except Exception as e:
            print("rpc retry", e)
            time.sleep(2)
    else:
        return [None] * len(calls)
    out = [None] * len(calls)
    for item in resp:
        if "result" in item:
            out[item["id"]] = item["result"]
    return out


def main():
    state = json.load(open(os.path.join(ANALYSIS, "events_state.json")))
    safes = state["currently_enabled_by_events"]
    MODULE = "0x1f1d37a3bf840e35c6a860c7c2da71fe555123ca"
    safes = safes + [MODULE]

    # discover tokens per safe
    tokens = set(a.lower() for a in CURATED.values())
    per_safe_discovered = {}
    for i, s in enumerate(safes):
        rows = eth_token_transfers(s, pages=2 if s != MODULE else 1)
        disc = set((r.get("contractAddress") or "").lower() for r in rows if r.get("contractAddress"))
        per_safe_discovered[s] = sorted(disc)
        tokens |= disc
        print(f"[tokentx {i+1}/{len(safes)}] {s} transfers={len(rows)} tokens={len(disc)}", flush=True)
        time.sleep(0.3)
    print("unique tokens:", len(tokens))

    token_list = sorted(tokens)
    result = {"safes": {}, "tokens": token_list}
    for i, s in enumerate(safes):
        calls = [(t, SELECTOR + s[2:].rjust(64, "0")) for t in token_list]
        res = rpc_batch(calls)
        bals = {}
        for t, r in zip(token_list, res):
            if not r or r == "0x":
                continue
            try:
                v = int(r, 16)
            except Exception:
                continue
            if v > 0:
                bals[t] = v
        result["safes"][s] = {"token_balances_raw": bals,
                              "native_wei": None}
        print(f"[balance {i+1}/{len(safes)}] {s} nonzero_tokens={len(bals)}", flush=True)
        time.sleep(0.2)
    json.dump(result, open(os.path.join(ANALYSIS, "balances", "onchain_balances.json"), "w"), indent=1)
    print("saved onchain_balances.json")


if __name__ == "__main__":
    main()
