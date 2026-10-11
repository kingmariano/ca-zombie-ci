#!/usr/bin/env python3
"""Enosys Bridge — fresh live-state verification (local light run).

Read-only. Public keyless RPCs only; no secrets. Writes analysis/fresh_state.json.
Adds over the CI script: code hashes, EIP-1967 slots, native balances,
role-holder contract types (Timelock/Safe), mirror-token totalSupply backing,
token allowances from the custody contracts.
"""
import json
import time
import urllib.request

OUT = {}
RPC = {
    "ethereum": ["https://ethereum-rpc.publicnode.com", "https://eth.drpc.org"],
    "xdc": ["https://xdc.public-rpc.com", "https://rpc1.xinfin.network", "https://rpc.ankr.com/xdc"],
    "songbird": ["https://songbird-api.flare.network/ext/C/rpc"],
    "flare": ["https://flare-api.flare.network/ext/C/rpc"],
}


def rpc(chain, method, params, tries=2, tmo=12):
    last = None
    for url in RPC[chain]:
        for _ in range(tries):
            try:
                body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
                req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
                r = json.load(urllib.request.urlopen(req, timeout=tmo))
                if "result" in r:
                    return r["result"]
                last = r.get("error")
            except Exception as e:  # noqa: BLE001
                last = f"ERR:{e}"
            time.sleep(0.7)
    return last


def call(chain, to, data, block="latest"):
    return rpc(chain, "eth_call", [{"to": to, "data": data}, block])


def num(x):
    try:
        return int(x, 16)
    except Exception:  # noqa: BLE001
        return None


SEL = {
    "paused": "0x5c975abb",
    "migratedContract": "0x7486fa4e",
    "depositIndex": "0x7b898939",
    "nextExecutionIndex": "0xdff73307",
    "validatorFeeBPS": "0x842e8b81",
    "getRoleMemberCount": "0xca15c873",
    "getRoleMember": "0x9010d07c",
    "validatorInfo": "0x4f1811dd",
    "balanceOf": "0x70a08231",
    "totalSupply": "0x18160ddd",
    "mirrorTokens": "0xfeaeb43e",
    "getMinDelay": "0xf27a0c92",
    "getThreshold": "0xe75235b8",
    "getOwners": "0xa0e67e2b",
    "allowance": "0xdd62ed3e",
}

ROLES = {
    "DEFAULT_ADMIN": "00" * 32,
    "WEAK_ADMIN": "930fce5230a9f921042304dfd119e1ad0bbc7d9c38c01b0505d47cf8b65d228c",
    "PAUSE": "fcb9fcbfa83b897fb2d5cf4b58962164105c1e71489a37ef3ae0db3fdce576f6",
}

EIP1967 = {
    "impl": "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
    "admin": "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103",
    "beacon": "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50",
}

STATUS = {0: "Uninitialized", 1: "Removed", 2: "FirstCommittee", 3: "SecondCommittee"}

# custody ends
ENDS = [
    ("ethereum", "0x8936761f2903ed1af2b269e6fa3a79ebb0162c51", "ETH<->Songbird custody"),
    ("ethereum", "0x37aca97a99d1b4260a5e9821d0ef14947fb68970", "ETH<->Flare custody"),
    ("xdc", "0xcb71dc7b30205eb7ce27b2cb36b24ba331ecd42a", "XDC<->Songbird custody"),
]
# mint/burn ends (context: mirror-token supply)
MINTS = [
    ("songbird", "0x8936761f2903ed1af2b269e6fa3a79ebb0162c51", "Songbird exUSDT/exETH"),
    ("songbird", "0xcb71dc7b30205eb7ce27b2cb36b24ba331ecd42a", "Songbird exXDC"),
    ("flare", "0x37aca97a99d1b4260a5e9821d0ef14947fb68970", "Flare eUSDT/eETH/eQNT"),
]

TOKENS = {
    "ethereum": {
        "USDT": ("0xdac17f958d2ee523a2206206994597c13d831ec7", 6),
        "WETH": ("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", 18),
        "QNT": ("0x4a220e6096b25eadb88358cb44068a3248254675", 18),
    },
    "xdc": {"WXDC": ("0x951857744785e80e2de051c32ee7b25f9c458c42", 18)},
    "songbird": {
        "exUSDT": ("0x1a7b46656b2b8b29b1694229e122d066020503d0", 6),
        "exETH": ("0x36b84a93820175c02f57e5c87a7ea33df58e5c94", 18),
        "exXDC": ("0xc54de96302981f87a6f80e4607593681b44d670c", 18),
    },
    "flare": {
        "eUSDT": ("0x96b41289d90444b8add57e6f265db5ae8651df29", 6),
        "eETH": ("0xa76dcddce60a442d69bac7158f3660f50921b122", 18),
        "eQNT": ("0x60fdc7b744e886e96aa0def5f69ee440db9d8c77", 18),
    },
}

# plausible spenders to check allowances to (protocol routers)
SPENDERS = [
    "0x000000000022D473030F116dDEE9F6B43aC78BA3",  # Permit2
    "0x1111111254EEB25477B68fb85Ed929f73A960582",  # 1inch
    "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",  # UniV2 router
    "0xE592427A0AEce92De3Edee1F18E0157C05861564",  # UniV3 router
    "0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F",  # Sushi router
]


def main():
    for chain in RPC:
        OUT.setdefault("chains", {})[chain] = {"block": num(rpc(chain, "eth_blockNumber", []))}
        print(f"[{chain}] block {OUT['chains'][chain]['block']}", flush=True)

    ends = []
    for chain, addr, label in ENDS:
        e = {"chain": chain, "address": addr, "label": label}
        code = rpc(chain, "eth_getCode", [addr, "latest"])
        e["code_bytes"] = (len(code) - 2) // 2 if isinstance(code, str) else None
        e["code_sha256_prefix"] = None
        import hashlib
        if isinstance(code, str):
            e["code_keccak_hint"] = None
            e["code_sha256"] = hashlib.sha256(bytes.fromhex(code[2:])).hexdigest()
        e["native_balance_wei"] = num(rpc(chain, "eth_getBalance", [addr, "latest"]))
        e["paused"] = num(call(chain, addr, SEL["paused"]))
        e["migratedContract"] = call(chain, addr, SEL["migratedContract"])
        e["depositIndex"] = num(call(chain, addr, SEL["depositIndex"]))
        e["nextExecutionIndex"] = num(call(chain, addr, SEL["nextExecutionIndex"]))
        e["validatorFeeBPS"] = num(call(chain, addr, SEL["validatorFeeBPS"]))
        s8 = num(rpc(chain, "eth_getStorageAt", [addr, hex(8), "latest"]))
        e["quorum"] = {"c1": s8 & 0xFF, "c2": (s8 >> 8) & 0xFF} if s8 is not None else None
        e["committeeSizes"] = {"c1": (s8 >> 16) & 0xFF, "c2": (s8 >> 24) & 0xFF} if s8 is not None else None
        e["eip1967"] = {}
        for k, slot in EIP1967.items():
            e["eip1967"][k] = rpc(chain, "eth_getStorageAt", [addr, slot, "latest"])
        e["roles"] = {}
        for rname, rh in ROLES.items():
            c = num(call(chain, addr, SEL["getRoleMemberCount"] + rh))
            members = []
            if c:
                for i in range(min(c, 8)):
                    m = call(chain, addr, SEL["getRoleMember"] + rh + hex(i)[2:].zfill(64))
                    if isinstance(m, str) and len(m) == 66:
                        members.append("0x" + m[2 + 24 :])
            e["roles"][rname] = {"count": c, "members": members}
        # role-holder contract types
        e["role_holder_code"] = {}
        for m in {x for r in e["roles"].values() for x in r["members"]}:
            c = rpc(chain, "eth_getCode", [m, "latest"])
            e["role_holder_code"][m] = (len(c) - 2) // 2 if isinstance(c, str) else None
        # TimelockController / Safe probes on DEFAULT_ADMIN + WEAK_ADMIN holders
        e["timelock"] = {}
        for rname in ("DEFAULT_ADMIN", "WEAK_ADMIN"):
            for m in e["roles"][rname]["members"]:
                delay = call(chain, m, SEL["getMinDelay"])
                thr = call(chain, m, SEL["getThreshold"])
                e["timelock"][m] = {
                    "minDelay_s": num(delay) if isinstance(delay, str) and delay not in ("0x",) else None,
                    "safe_threshold": num(thr) if isinstance(thr, str) and thr not in ("0x",) else None,
                }
        # token balances + allowances from custody to plausible spenders
        e["tokens"] = []
        for sym, (t, dec) in TOKENS[chain].items():
            bal = num(call(chain, t, SEL["balanceOf"] + addr[2:].zfill(64)))
            allow = {}
            for sp in SPENDERS:
                a = num(call(chain, t, SEL["allowance"] + addr[2:].zfill(64) + sp[2:].zfill(64)))
                if a:
                    allow[sp] = a
            e["tokens"].append({"symbol": sym, "token": t, "decimals": dec, "balance": bal, "balance_float": bal / 10**dec if bal is not None else None, "nonzero_allowances": allow})
        # mirror-token mapping probes for known mirror tokens
        e["mirror_map"] = {}
        if chain == "ethereum" and addr.startswith("0x8936"):
            e["mirror_map"]["exUSDT"] = call(chain, addr, SEL["mirrorTokens"] + "1a7b46656b2b8b29b1694229e122d066020503d0".zfill(64))
            e["mirror_map"]["exETH"] = call(chain, addr, SEL["mirrorTokens"] + "36b84a93820175c02f57e5c87a7ea33df58e5c94".zfill(64))
        if chain == "ethereum" and addr.startswith("0x37ac"):
            e["mirror_map"]["eUSDT"] = call(chain, addr, SEL["mirrorTokens"] + "96b41289d90444b8add57e6f265db5ae8651df29".zfill(64))
            e["mirror_map"]["eQNT"] = call(chain, addr, SEL["mirrorTokens"] + "60fdc7b744e886e96aa0def5f69ee440db9d8c77".zfill(64))
        if chain == "xdc":
            e["mirror_map"]["exXDC"] = call(chain, addr, SEL["mirrorTokens"] + "c54de96302981f87a6f80e4607593681b44d670c".zfill(64))
        ends.append(e)
        print(f"[{chain}] {addr[:10]} {label}: paused={e['paused']} dep={e['depositIndex']} next={e['nextExecutionIndex']} q={e['quorum']} code={e['code_bytes']}B native={e['native_balance_wei']}", flush=True)
    OUT["ends"] = ends

    # mirror token supplies
    supplies = {}
    for chain, _addr, label in MINTS:
        for sym, (t, dec) in TOKENS[chain].items():
            ts = num(call(chain, t, SEL["totalSupply"]))
            supplies[f"{chain}:{sym}"] = {"token": t, "totalSupply": ts, "float": ts / 10**dec if ts is not None else None}
    OUT["mirror_supplies"] = supplies
    for k, v in supplies.items():
        print(f"supply {k}: {v['float']}")

    # older deployments (negative results)
    old = []
    for addr in ["0xb3902647015c17fc3c2f5ca5f5cb68bbf2d9b1e2", "0xe246269e87b48c54ca971a079cedc4b967af3224"]:
        code = rpc("ethereum", "eth_getCode", [addr, "latest"])
        old.append({
            "address": addr,
            "code_bytes": (len(code) - 2) // 2 if isinstance(code, str) else None,
            "native": num(rpc("ethereum", "eth_getBalance", [addr, "latest"])),
            "paused": num(call("ethereum", addr, SEL["paused"])),
            "depositIndex": num(call("ethereum", addr, SEL["depositIndex"])),
            "migratedContract": call("ethereum", addr, SEL["migratedContract"]),
            "usdt": num(call("ethereum", "0xdac17f958d2ee523a2206206994597c13d831ec7", SEL["balanceOf"] + addr[2:].zfill(64))),
            "weth": num(call("ethereum", "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", SEL["balanceOf"] + addr[2:].zfill(64))),
            "qnt": num(call("ethereum", "0x4a220e6096b25eadb88358cb44068a3248254675", SEL["balanceOf"] + addr[2:].zfill(64))),
        })
    OUT["old_deployments"] = old

    with open("analysis/fresh_state.json", "w") as f:
        json.dump(OUT, f, indent=2)
    print("written analysis/fresh_state.json")


if __name__ == "__main__":
    main()
