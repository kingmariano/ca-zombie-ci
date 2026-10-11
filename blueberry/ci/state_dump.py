#!/usr/bin/env python3
"""CI state dump — read-only, public RPCs only (no keys written to files).

Writes blueberry/ci-out/state.json with the live state used in the report.
"""
import json, urllib.request, os, sys, time

MONAD = "https://rpc.monad.xyz"
ETH = os.environ.get("FORK_RPC_URL") or os.environ.get("RPC_URL") or "https://ethereum-rpc.publicnode.com"
HYPEREVM = "https://rpc.hyperliquid.xyz/evm"

V1 = "0xC2ddc1004CA0d6cC4bFd1dCD03Dcf855bED8E670"
V2 = "0x215394B5677Cb7a18B6fA8cc2cD155C024ee6b2E"
AUSD = "0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a"
USDC = "0x754704Bc059F8C67012fEd69BC8A327a5aafb603"
OPT1 = "0x460BBe066AA0ff94d7AFCd95580c41190FC4C7E4"
OPT2 = "0xe43b232FA6Ce535C6B4F8771427eBd4a77Bad593"
BANK = "0xa34F59F634d48E2c3606048f2367326c46a4B5fA"
COMPTROLLER = "0xcb0D9Ff5BDD34521c6f8CDbeAf15e1A76Fa4dd5D"
HL_ROUTER = "0x647a4D7F1F20Cf237C27b39fB6924f5a7691BB4b"
HOLDERS = {
    "0xa5190552e8A7902812C6F6Df07813BF6AEBfc6bd": "holder1",
    "0xbA1333333333a1BA1108E8412f11850A5C319bA9": "holder2",
    "0xf7e5c38800498d773c875d447413b3b30f816190": "accountant",
}
ADDRS_ROLE = {
    "0x72d19f7c71a2bD5E61871B1D3dF7a45ae5Ec9582": "mgmtSafe",
    "0xf6b6dA3bbA0caA61eC3C65ad87a61b9d0130457b": "keeperEOA",
    "0xe4d701c6e3BFBA3e50D1045a3cEF4797B6165119": "feeSafe",
    "0x5b79684891c55A9E042Cd5D7719c211Bee17Ab39": "roleManager",
    "0x02426745D31185B9946E7E513D6B25d07a633f3f": "deployer",
}

def rpc(url, method, params, tries=4):
    body = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
    last = None
    for _ in range(tries):
        try:
            req = urllib.request.Request(url, data=body,
                headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            r = json.loads(urllib.request.urlopen(req, timeout=45).read())
            if "result" in r:
                return r["result"]
            last = r.get("error")
        except Exception as e:
            last = str(e)
        time.sleep(1.5)
    return {"__error__": str(last)}

def call(url, to, data):
    return rpc(url, "eth_call", [{"to": to, "data": data}, "latest"])

def batch_call(url, items):
    """items: [(to,data)] -> list of results (batched x10)"""
    out = []
    for i in range(0, len(items), 10):
        chunk = items[i:i+10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                    "params": [{"to": c[0], "data": c[1]}, "latest"]} for j, c in enumerate(chunk)]
        try:
            req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            res = json.loads(urllib.request.urlopen(req, timeout=60).read())
            by = {r["id"]: r for r in res}
            out += [by[j].get("result") for j in range(len(chunk))]
        except Exception as e:
            out += [{"__error__": str(e)}] * len(chunk)
    return out

def n(v):
    if not v or not isinstance(v, str) or v == "0x":
        return None
    return int(v, 16)

def a(v):
    if not v or not isinstance(v, str) or len(v) < 42:
        return None
    return "0x" + v[-40:]

def pad(x):
    return x[2:].lower().rjust(64, "0")

SIG = {
    "name": "0x06fdde03", "asset": "0x38d52e0f", "totalAssets": "0x01e1d114",
    "totalSupply": "0x18160ddd", "totalIdle": "0x9aa7df94", "totalDebt": "0xfc7b9c18",
    "pricePerShare": "0x99530b06", "deposit_limit": "0xe46a5797", "isPaused": "0xb187bd26",
    "isShutdown": "0xbf86d690", "role_manager": "0x79b98917", "auto_allocate": "0xdd47db90",
    "default_queue": "0x8bf03b9e", "strategies": "0x39ebf823", "roles": "0x99374642",
    "balanceOf": "0x70a08231", "maxRedeem": "0xd905777e", "maxWithdraw": "0xce96cb77",
    "convertToAssets": "0x07a2d13a", "management": "0x88a8d602", "keeper": "0xaced1661",
    "open": "0xfcfff16f", "allowed": "0xd63a8e11", "lastReport": "0xc3535b52",
    "marketsLength": "0xa5402544", "markets": "0xb1283e77", "positionValue": "0x4de7c7bd",
    "marketMaxWithdraw": "0xd871d883", "getCash": "0x3b1d21a2", "totalBorrows": "0x47bd3718",
    "totalReserves": "0x8f840ddd", "exchangeRateStored": "0x182df0f5",
    "getNextPositionId": "0x067f4ddd", "getPositionValue": "0xb86a0aaa",
    "isLiquidatable": "0x211a4443", "getBankStatus": "0x0b6b8386",
    "tvl": "0xe5328e06", "owner": "0x8da5cb5b",
}

def vault_dump(url, vault, asset, strat):
    out = {"address": vault, "asset": asset, "strategy": strat}
    items = [
        (vault, SIG["name"]), (vault, SIG["totalAssets"]), (vault, SIG["totalSupply"]),
        (vault, SIG["totalIdle"]), (vault, SIG["totalDebt"]), (vault, SIG["pricePerShare"]),
        (vault, SIG["deposit_limit"]), (vault, SIG["isPaused"]), (vault, SIG["isShutdown"]),
        (vault, SIG["role_manager"]), (vault, SIG["auto_allocate"]), (vault, SIG["default_queue"]),
        (vault, SIG["strategies"] + pad(strat)),
        (asset, SIG["balanceOf"] + pad(vault)),
    ]
    r = batch_call(url, items)
    keys = ["name", "totalAssets", "totalSupply", "totalIdle", "totalDebt", "pricePerShare",
            "deposit_limit", "isPaused", "isShutdown", "role_manager", "auto_allocate",
            "default_queue", "strategies", "asset_bal"]
    for k, v in zip(keys, r):
        if k == "name":
            try:
                b = bytes.fromhex(v[2:]); ln = int.from_bytes(b[32:64], "big"); out[k] = b[64:64+ln].decode()
            except Exception: out[k] = None
        elif k in ("totalAssets", "totalSupply", "totalIdle", "totalDebt", "asset_bal"):
            out[k] = (n(v) or 0) / 1e6
        elif k == "strategies":
            out[k] = {"raw": v}
        elif k == "role_manager":
            out[k] = a(v)
        else:
            out[k] = n(v)
    # roles
    roles = {}
    for who, label in ADDRS_ROLE.items():
        roles[label] = n(call(url, vault, SIG["roles"] + pad(who)))
    out["roles"] = roles
    # strategy state
    s = {}
    sitems = [
        (strat, SIG["totalAssets"]), (strat, SIG["totalSupply"]), (strat, SIG["balanceOf"] + pad(vault)),
        (strat, SIG["management"]), (strat, SIG["keeper"]), (strat, SIG["open"]),
        (strat, SIG["allowed"] + pad(vault)), (strat, SIG["lastReport"]), (strat, SIG["marketsLength"]),
        (strat, SIG["maxRedeem"] + pad(vault)),
    ]
    sr = batch_call(url, sitems)
    skeys = ["totalAssets", "totalSupply", "balanceOf_vault", "management", "keeper", "open",
             "allowed_vault", "lastReport", "marketsLength", "maxRedeem_vault"]
    for k, v in zip(skeys, sr):
        if k in ("management", "keeper"): s[k] = a(v)
        elif k in ("open", "allowed_vault"): s[k] = n(v)
        else: s[k] = n(v)
    # markets
    ml = s.get("marketsLength") or 0
    mkts = []
    for i in range(ml):
        m = a(call(url, strat, SIG["markets"] + hex(i)[2:].rjust(64, "0")))
        if m:
            pv = n(call(url, strat, SIG["positionValue"] + pad(m)))
            mw = n(call(url, strat, SIG["marketMaxWithdraw"] + pad(m)))
            mkts.append({"market": m, "positionValue": pv, "marketMaxWithdraw": mw})
    s["markets"] = mkts
    out["strategy_state"] = s
    # holders
    hold = {}
    for h, label in HOLDERS.items():
        hold[label] = {
            "address": h,
            "shares": (n(call(url, vault, SIG["balanceOf"] + pad(h))) or 0) / 1e6,
            "maxRedeem": (n(call(url, vault, SIG["maxRedeem"] + pad(h))) or 0) / 1e6,
            "maxWithdraw": (n(call(url, vault, SIG["maxWithdraw"] + pad(h))) or 0) / 1e6,
        }
    out["holders"] = hold
    return out

def main():
    res = {"generated_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    res["monad_block"] = n(rpc(MONAD, "eth_blockNumber", []))
    res["monad"] = {
        "vault1_ausd": vault_dump(MONAD, V1, AUSD, OPT1),
        "vault2_usdc": vault_dump(MONAD, V2, USDC, OPT2),
    }
    # ETH
    try:
        res["ethereum_block"] = n(rpc(ETH, "eth_blockNumber", []))
    except Exception:
        res["ethereum_block"] = None
    eth = {}
    np_ = n(call(ETH, BANK, SIG["getNextPositionId"]))
    eth["nextPositionId"] = np_
    eth["bankStatus"] = n(call(ETH, BANK, SIG["getBankStatus"]))
    eth["bankOwner"] = a(call(ETH, BANK, SIG["owner"]))
    pos = []
    for i in range(min(np_ or 0, 60)):
        v = n(call(ETH, BANK, SIG["getPositionValue"] + hex(i)[2:].rjust(64, "0")))
        if v:
            pos.append({"id": i, "value_1e18": v / 1e18,
                        "liquidatable": n(call(ETH, BANK, SIG["isLiquidatable"] + hex(i)[2:].rjust(64, "0")))})
    eth["positions_with_value"] = pos
    markets = [
        "0x045Cb2fFea4c2cef4e9a754Bd02bD6Bb9E0DF841", "0xb5A7D8c7f85BB48fcF10AD5C3EFB090a3fE40069",
        "0xfB8Ddd624E340204F32905692C3fD7da59335E81", "0xdeBd5D482C2B0feeA5527f9B832F7F894c8303eB",
        "0x643d448CEa0D3616F0b32E3718F563b164e7eDd2",
    ]
    mout = []
    for m in markets:
        mout.append({
            "market": m,
            "cash": n(call(ETH, m, SIG["getCash"])),
            "borrows": n(call(ETH, m, SIG["totalBorrows"])),
            "reserves": n(call(ETH, m, SIG["totalReserves"])),
            "cTokenSupply": n(call(ETH, m, SIG["totalSupply"])),
            "exchangeRateStored": n(call(ETH, m, SIG["exchangeRateStored"])),
        })
    eth["compound_fork_markets"] = mout
    res["ethereum"] = eth
    # HyperEVM
    res["hyperevm"] = {
        "chain_id": n(rpc(HYPEREVM, "eth_chainId", [])),
        "block": n(rpc(HYPEREVM, "eth_blockNumber", [])),
        "router": HL_ROUTER,
        "tvl_1e18": (n(call(HYPEREVM, HL_ROUTER, SIG["tvl"])) or 0) / 1e18,
        "owner": a(call(HYPEREVM, HL_ROUTER, SIG["owner"])),
    }
    os.makedirs("ci-out", exist_ok=True)
    with open("ci-out/state.json", "w") as f:
        json.dump(res, f, indent=1)
    print(json.dumps({k: res[k] for k in ("generated_at_utc", "monad_block", "ethereum_block")}, indent=1))
    print("wrote ci-out/state.json")

if __name__ == "__main__":
    main()
