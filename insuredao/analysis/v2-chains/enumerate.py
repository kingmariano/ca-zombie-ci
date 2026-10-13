#!/usr/bin/env python3
"""
InsureDAO v2 L2 enumeration — READ-ONLY.
Keyless public RPCs only. Never sends transactions.

Enumerates registry.getAllPools/getAllMarkets per chain, extracts EIP-1167
implementation from each market, and reads vault/market state.

Output: state.json (raw hex + decoded), stdout summary.
"""
import json
import sys
import time
import urllib.request

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36"

CHAINS = {
    "arbitrum": {
        "chain_id": 42161,
        "rpcs": [
            "https://arb1.arbitrum.io/rpc",
            "https://arbitrum.llamarpc.com",
            "https://arbitrum-one.publicnode.com",
        ],
        "vault": "0x968C9718f420d5D4275C610C5c217598a6ade9f9",
        "registry": "0x0fa85C39c96A9172CcCa7F84CE68E08A2BB971C1",
        "ownership": "0x62B86b6274DFa4Cc16beD9995E302A56D18891E2",
        "controller": "0xE5E32AD53c183e7eEd57b226a93769DBcC21705F",
        "token": "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
        "token_decimals": 6,
        "list_fn": "getAllPools()(address[])",
    },
    "optimism": {
        "chain_id": 10,
        "rpcs": [
            "https://mainnet.optimism.io",
            "https://optimism.publicnode.com",
            "https://op.publicnode.com",
        ],
        "vault": "0x54F23d2fdC1E17D349B1Eb14d869fa4deD6A6D2b",
        "registry": "0x636938b5ff717f525c696f8961b9a1aec38749a1",
        "ownership": None,  # read from vault
        "controller": "0xdb8502a16efc7074ed1dd1e087d6616851c3374e",
        "token": "0x7F5c764cBc14f9669B88837ca1490cCa17c31607",
        "token_decimals": 6,
        "list_fn": "getAllPools()(address[])",
    },
    "astar": {
        "chain_id": 592,
        "rpcs": [
            "https://evm.astar.network",
            "https://astar.api.onfinality.io/public",
        ],
        "vault": "0x190dA1B9fA124BD872e9166bA3c7Dd656A11E8F8",
        "registry": "0xd0df5a352d74a746754c592a6277c9060a7c9c87",
        "ownership": None,  # read from vault
        "controller": None,  # read from vault
        "token": "0x6a2d262d56735dba19dd70682b39f6be9a931d98",
        "token_decimals": 6,
        "list_fn": "getAllMarkets()(address[])",
    },
}

# function selectors (cast sig)
SEL = {
    "getAllPools": "0xd88ff1f4",
    "getAllMarkets": "0xb0772d0b",
    "attributions": "0x6b4067af",       # attributions(address)
    "debts": "0x2ecd4e7d",              # debts(address)
    "underlyingValue": "0x2f9ef012",    # underlyingValue(address)
    "marketStatus": "0xe0e081d7",
    "paused": "0x5c975abb",
    "locked": "0xcf309012",
    "totalSupply": "0x18160ddd",
    "symbol": "0x95d89b41",
    "owner": "0x8da5cb5b",
    "vault": "0xfbfa77cf",
    "registry": "0x7b103999",
    "token": "0xfc0c546a",
    "balance": "0xb69ef8a8",
    "totalAttributions": "0x5f96a4eb",
    "valueAll": "0x55306252",
    "controller": "0xf77c4791",
    "ownership": "0x5d03147a",
    "managingFund": "0xbef05a21",
    "factory": "0xc45a0155",
    "isListed": "0xf794062e",
    "totalDebt": "0xfc7b9c18",
    "withdrawValue": "0x4b8a3529",  # placeholder, verify with cast sig below
    "totalLiquidity": "0x15770f92",
    "maxCapacity": "0x59b6a0c9",
    "version": "0x54fd4d50",
}


def rpc_call(rpcs, method, params, timeout=45, retries=2):
    last = None
    for attempt in range(retries):
        for url in rpcs:
            try:
                payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
                req = urllib.request.Request(
                    url,
                    data=json.dumps(payload).encode(),
                    headers={"Content-Type": "application/json", "User-Agent": UA},
                )
                with urllib.request.urlopen(req, timeout=timeout) as r:
                    body = json.load(r)
                if "result" in body:
                    return body["result"], None
                err = body.get("error", {})
                last = f"{url}: {err.get('message')} data={err.get('data')}"
            except Exception as e:
                last = f"{url}: {e!r}"
        time.sleep(1.0)
    return None, last


def eth_call(rpcs, to, data, block="latest"):
    res, err = rpc_call(rpcs, "eth_call", [{"to": to, "data": data}, block])
    return res, err


def pad(addr):
    return addr.lower().replace("0x", "").rjust(64, "0")


def decode_uint(hexstr):
    if hexstr is None or hexstr in ("0x", "0x0", "0x" + "0" * 64):
        return 0 if hexstr else None
    try:
        return int(hexstr, 16)
    except Exception:
        return None


def decode_addr(hexstr):
    if not hexstr or len(hexstr) < 42:
        return None
    a = "0x" + hexstr[-40:]
    if a == "0x" + "0" * 40:
        return None
    return a


def decode_bool(hexstr):
    if not hexstr:
        return None
    v = decode_uint(hexstr)
    return bool(v) if v is not None else None


def decode_string(hexstr):
    if not hexstr or hexstr == "0x":
        return None
    try:
        raw = bytes.fromhex(hexstr[2:])
        if len(raw) < 64:
            return None
        off = int.from_bytes(raw[0:32], "big")
        ln = int.from_bytes(raw[off : off + 32], "big")
        s = raw[off + 32 : off + 32 + ln].decode("utf-8", "replace")
        return s.strip("\x00")
    except Exception:
        return None


def extract_impl(code):
    """Extract EIP-1167 minimal proxy target, else None."""
    if not code or len(code) < 92:
        return None
    c = code[2:].lower()
    # 363d3d373d3d3d363d73 <20b> 5af43d82803e903d91602b57fd5bf3
    marker = "363d3d373d3d3d363d73"
    suffix = "5af43d82803e903d91602b57fd5bf3"
    i = c.find(marker)
    if i >= 0 and c[i + len(marker) + 40 : i + len(marker) + 40 + len(suffix)] == suffix:
        return "0x" + c[i + len(marker) : i + len(marker) + 40]
    return None


def main():
    out = {}
    for name, cfg in CHAINS.items():
        print(f"##### {name} #####", flush=True)
        rpcs = cfg["rpcs"]
        d = {"chain_id": cfg["chain_id"], "vault": cfg["vault"], "registry": cfg["registry"]}
        bn, err = rpc_call(rpcs, "eth_blockNumber", [])
        block = int(bn, 16) if bn else None
        d["block"] = block
        print(f"block={block} err={err}", flush=True)

        # vault global state
        vs = {}
        for key, sig in [
            ("token()", "0xfc0c546a"),
            ("registry()", "0x7b103999"),
            ("ownership()", SEL["ownership"]),
            ("balance()", "0xb69ef8a8"),
            ("totalAttributions()", "0x5f96a4eb"),
            ("valueAll()", "0x55306252"),
            ("controller()", SEL["controller"]),
            ("totalDebt()", SEL["totalDebt"]),
        ]:
            res, e = eth_call(rpcs, cfg["vault"], sig, hex(block) if block else "latest")
            vs[key] = res
            if e:
                vs[key + "_err"] = e
        # decode
        d["vault_state_raw"] = vs
        d["vault_state"] = {
            "token": decode_addr(vs.get("token()")),
            "registry": decode_addr(vs.get("registry()")),
            "ownership": decode_addr(vs.get("ownership()")),
            "balance": decode_uint(vs.get("balance()")),
            "totalAttributions": decode_uint(vs.get("totalAttributions()")),
            "valueAll": decode_uint(vs.get("valueAll()")),
            "controller": decode_addr(vs.get("controller()")),
            "totalDebt": decode_uint(vs.get("totalDebt()")),
        }
        ctrl = d["vault_state"]["controller"]
        if ctrl:
            res, e = eth_call(rpcs, ctrl, SEL["managingFund"], hex(block) if block else "latest")
            d["controller_managingFund"] = decode_uint(res)
            if e:
                d["controller_managingFund_err"] = e
            # some controllers may not have managingFund; try valueAll
            if res is None:
                res2, e2 = eth_call(rpcs, ctrl, "0x55306252", hex(block) if block else "latest")
                d["controller_valueAll"] = decode_uint(res2)
                d["controller_valueAll_err"] = e2
        # ownership owner
        own = d["vault_state"]["ownership"]
        if own:
            res, e = eth_call(rpcs, own, SEL["owner"], hex(block) if block else "latest")
            d["ownership_owner_raw"] = res
            d["ownership_owner"] = decode_addr(res)
            # is owner a contract?
            if d["ownership_owner"]:
                code, _ = rpc_call(rpcs, "eth_getCode", [d["ownership_owner"], hex(block) if block else "latest"])
                d["ownership_owner_code_len"] = len(code) // 2 - 1 if code else 0
        # registry factory + market list
        res, e = eth_call(rpcs, cfg["registry"], SEL["factory"], hex(block) if block else "latest")
        d["registry_factory"] = decode_addr(res)
        if e:
            d["registry_factory_err"] = e

        list_sig = SEL["getAllPools"] if "Pools" in cfg["list_fn"] else SEL["getAllMarkets"]
        res, e = eth_call(rpcs, cfg["registry"], list_sig, hex(block) if block else "latest")
        markets = []
        if res and res != "0x":
            try:
                raw = bytes.fromhex(res[2:])
                off = int.from_bytes(raw[0:32], "big")
                ln = int.from_bytes(raw[off : off + 32], "big")
                markets = ["0x" + raw[off + 32 + j * 32 : off + 64 + j * 32].hex()[-40:] for j in range(ln)]
            except Exception as ex:
                d["markets_parse_err"] = repr(ex)
        else:
            d["markets_call_err"] = e
        d["markets"] = markets
        print(f"markets({len(markets)}):", flush=True)

        vault = cfg["vault"]
        minfo = {}
        for i, m in enumerate(markets):
            info = {}
            code, _ = rpc_call(rpcs, "eth_getCode", [m, hex(block) if block else "latest"])
            info["code_len"] = len(code) // 2 - 1 if code else 0
            impl = extract_impl(code)
            info["impl"] = impl
            calls = [
                ("vault_attributions", vault, SEL["attributions"] + pad(m)),
                ("vault_debts", vault, SEL["debts"] + pad(m)),
                ("vault_underlyingValue", vault, SEL["underlyingValue"] + pad(m)),
                ("marketStatus", m, SEL["marketStatus"]),
                ("paused", m, SEL["paused"]),
                ("locked", m, SEL["locked"]),
                ("totalSupply", m, SEL["totalSupply"]),
                ("symbol", m, SEL["symbol"]),
                ("market_vault", m, SEL["vault"]),
                ("market_registry", m, SEL["registry"]),
                ("totalLiquidity", m, SEL["totalLiquidity"]),
                ("maxCapacity", m, SEL["maxCapacity"]),
                ("owner", m, SEL["owner"]),
            ]
            raw = {}
            for key, to, data in calls:
                r, e = eth_call(rpcs, to, data, hex(block) if block else "latest")
                raw[key] = r
                if e:
                    raw[key + "_err"] = e
            info["raw"] = raw
            info["vault_attributions"] = decode_uint(raw.get("vault_attributions"))
            info["vault_debts"] = decode_uint(raw.get("vault_debts"))
            info["vault_underlyingValue"] = decode_uint(raw.get("vault_underlyingValue"))
            info["marketStatus"] = decode_string(raw.get("marketStatus"))
            info["marketStatus_u"] = decode_uint(raw.get("marketStatus"))
            info["paused"] = decode_bool(raw.get("paused"))
            info["locked"] = decode_uint(raw.get("locked"))
            info["totalSupply"] = decode_uint(raw.get("totalSupply"))
            info["symbol"] = decode_string(raw.get("symbol"))
            info["market_vault"] = decode_addr(raw.get("market_vault"))
            info["market_registry"] = decode_addr(raw.get("market_registry"))
            info["totalLiquidity"] = decode_uint(raw.get("totalLiquidity"))
            info["maxCapacity"] = decode_uint(raw.get("maxCapacity"))
            info["owner"] = decode_addr(raw.get("owner"))
            minfo[m.lower()] = info
            st = info["marketStatus"]
            print(
                f"  [{i:02d}] {m} impl={impl} attr={info['vault_attributions']} und={info['vault_underlyingValue']} "
                f"status={st!r} paused={info['paused']} locked={info['locked']} supply={info['totalSupply']} sym={info['symbol']!r}",
                flush=True,
            )
        d["markets_info"] = minfo
        out[name] = d
        with open("state.json", "w") as f:
            json.dump(out, f, indent=1, default=str)
    print("DONE -> state.json", flush=True)


if __name__ == "__main__":
    main()
