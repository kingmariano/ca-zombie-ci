#!/usr/bin/env python3
"""Enosys Bridge — live-state re-verification (CI heavy job, v2).

Read-only. Public keyless RPCs only; never reads or prints keyed URLs.
Writes ci-out/live-state.json and ci-out/live-state.txt.

Scope: Ethereum + XDC custody (headline) plus the Songbird/Flare mint ends.
v2 adds: code hashes, EIP-1967 proxy slots, native balances, role-holder
contract types (TimelockController delay / Safe threshold), mirror-token
totalSupply backing check, and USD totals for the ETH+XDC custody.
"""
import hashlib
import json
import sys
import time
import urllib.request

OUT = []


def log(msg):
    OUT.append(str(msg))
    print(msg, flush=True)


def rpc(urls, method, params, tries=2, tmo=20):
    last = None
    for url in urls:
        for _ in range(tries):
            try:
                body = json.dumps(
                    {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
                ).encode()
                req = urllib.request.Request(
                    url,
                    data=body,
                    headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"},
                )
                r = json.load(urllib.request.urlopen(req, timeout=tmo))
                if "result" in r:
                    return r["result"]
                last = r.get("error")
            except Exception as e:  # noqa: BLE001
                last = f"ERR:{e}"
            time.sleep(0.6)
    return last


def get_json(url, tmo=30):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    return json.load(urllib.request.urlopen(req, timeout=tmo))


CHAINS = {
    "ethereum": ["https://ethereum-rpc.publicnode.com", "https://eth.drpc.org"],
    "xdc": ["https://xdc.public-rpc.com", "https://rpc1.xinfin.network", "https://rpc.ankr.com/xdc"],
    "songbird": ["https://songbird-api.flare.network/ext/C/rpc"],
    "flare": ["https://flare-api.flare.network/ext/C/rpc"],
}

# deployed ends (same address on both ends of each pair, different chains)
ENDS = [
    ("ethereum", "0x8936761f2903ed1af2b269e6fa3a79ebb0162c51", "ETH<->Songbird custody (WrapDepositRedeem)", "custody"),
    ("ethereum", "0x37aca97a99d1b4260a5e9821d0ef14947fb68970", "ETH<->Flare custody (WrapDepositRedeem)", "custody"),
    ("xdc", "0xcb71dc7b30205eb7ce27b2cb36b24ba331ecd42a", "XDC<->Songbird custody (WrapDepositRedeem)", "custody"),
    ("songbird", "0x8936761f2903ed1af2b269e6fa3a79ebb0162c51", "Songbird mint/burn (WrapMintBurn)", "mint"),
    ("songbird", "0xcb71dc7b30205eb7ce27b2cb36b24ba331ecd42a", "Songbird mint/burn (WrapMintBurn)", "mint"),
    ("flare", "0x37aca97a99d1b4260a5e9821d0ef14947fb68970", "Flare mint/burn (WrapMintBurn)", "mint"),
]

SELECTORS = {
    "paused": "0x5c975abb",
    "migratedContract": "0x7486fa4e",
    "depositIndex": "0x7b898939",
    "nextExecutionIndex": "0xdff73307",
    "validatorFeeBPS": "0x842e8b81",
    "tokens(uint256)": "0x4f64b2be",
    "tokenInfos(address)": "0xba46ae72",
    "mirrorTokens(address)": "0xfeaeb43e",
    "validatorInfo(address)": "0x4f1811dd",
    "validatorFeeRecipients(address)": "0x36cdca74",
    "getRoleMemberCount(bytes32)": "0xca15c873",
    "getRoleMember(bytes32,uint256)": "0x9010d07c",
    "balanceOf(address)": "0x70a08231",
    "totalSupply()": "0x18160ddd",
    "decimals()": "0x313ce567",
    "symbol()": "0x95d89b41",
    "getMinDelay()": "0xf27a0c92",
    "getThreshold()": "0xe75235b8",
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

# signer universe per contract (from Add/RemoveSigner logs; see analysis/)
SIGNERS = {
    "0x8936761f2903ed1af2b269e6fa3a79ebb0162c51": [
        "0x8ae8cbbb85b8b83d146be42987aeec0835fc466f",
        "0x4370b2b6cebe373ebbe84e2e0eec5761af651e41",
        "0xd51be17f2e5b858f28a6c25e1e702a0c00e14c9d",
        "0x6bb6856fe0018409034136a8df83db9835d6996e",
        "0x6a5cb907c398a93d769b47d49f983bbf0672c0fa",
        "0xe027978ffbffa3c35b20328efb13d7001f69f84c",
    ],
    "0x37aca97a99d1b4260a5e9821d0ef14947fb68970": [
        "0x12d419be29adbac06a28f9c6a534a9c00e7fa66b",
        "0x90bc0578ec8966fc868e46f76220eb14d004c136",
        "0x08e4b7e52ef6e1d040da07821bc8edcdc5e0edef",
        "0x0a07f5a5d01a1fa9734f0e1ad4b50b44a976a94a",
        "0x600bf80c72a4e32354cef106cd9ddf04737dca96",
        "0xc78cfe9013770dfab657f84cd7a4b002e820e6af",
        "0xb0e09f188c2eade40c5a94967bc4fbfa7e831aa5",
    ],
    "0xcb71dc7b30205eb7ce27b2cb36b24ba331ecd42a": [
        "0xef7f2ad219aed662ad753f9dcefc0b4b94845a09",
        "0x833be161e9f24b7be8ef2852d3214a3e348bc7fb",
        "0x478aad282c8618babadee8871a099f1d2cf1e55b",
        "0x88d265063ac4b082d3ff38e28e03e162c3fdcebc",
        "0xa4d96279d9741970bb8fed137e1aa5e43f4e6f66",
        "0x43be403c12fe4bef43410c0b34965cc5c4730222",
    ],
}

STATUS = {0: "Uninitialized", 1: "Removed", 2: "FirstCommittee", 3: "SecondCommittee"}

TOKEN_ARRAY_SLOT = "0xa66cc928b5edb82af9bd49922954155ab7b0942694bea4ce44661d9a8736c688"

# mirror-token supply check: (mint chain, token, decimals, custody chain, custody addr, underlying symbol)
BACKING = [
    ("songbird", "0x1a7b46656b2b8b29b1694229e122d066020503d0", 6, "ethereum", "0x8936761f2903ed1af2b269e6fa3a79ebb0162c51", "USDT"),
    ("songbird", "0x36b84a93820175c02f57e5c87a7ea33df58e5c94", 18, "ethereum", "0x8936761f2903ed1af2b269e6fa3a79ebb0162c51", "WETH"),
    ("flare", "0x96b41289d90444b8add57e6f265db5ae8651df29", 6, "ethereum", "0x37aca97a99d1b4260a5e9821d0ef14947fb68970", "USDT"),
    ("flare", "0xa76dcddce60a442d69bac7158f3660f50921b122", 18, "ethereum", "0x37aca97a99d1b4260a5e9821d0ef14947fb68970", "WETH"),
    ("flare", "0x60fdc7b744e886e96aa0def5f69ee440db9d8c77", 18, "ethereum", "0x37aca97a99d1b4260a5e9821d0ef14947fb68970", "QNT"),
    ("songbird", "0xc54de96302981f87a6f80e4607593681b44d670c", 18, "xdc", "0xcb71dc7b30205eb7ce27b2cb36b24ba331ecd42a", "WXDC"),
]


def word(hexstr, i):
    return hexstr[2 + i * 64 : 2 + (i + 1) * 64]


def call(urls, to, data, block="latest"):
    return rpc(urls, "eth_call", [{"to": to, "data": data}, block])


def storage(urls, to, slot):
    return rpc(urls, "eth_getStorageAt", [to, hex(slot), "latest"])


def dec_string(hexstr):
    try:
        off = int(word(hexstr, 0), 16)
        ln = int(hexstr[2 + off * 2 : 2 + off * 2 + 64], 16)
        return bytes.fromhex(hexstr[2 + off * 2 + 64 : 2 + off * 2 + 64 + ln * 2]).decode("utf8", "replace")
    except Exception:  # noqa: BLE001
        return "?"


def main():
    result = {"generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "chains": {}, "ends": []}
    for chain, urls in CHAINS.items():
        bn = rpc(urls, "eth_blockNumber", [])
        result["chains"][chain] = {"block": int(bn, 16) if isinstance(bn, str) else bn}
        log(f"[{chain}] block {result['chains'][chain]['block']}")

    for chain, addr, label, kind in ENDS:
        urls = CHAINS[chain]
        entry = {"chain": chain, "address": addr, "label": label, "kind": kind}
        code = rpc(urls, "eth_getCode", [addr, "latest"])
        if isinstance(code, str) and len(code) > 2:
            entry["code_bytes"] = (len(code) - 2) // 2
            entry["code_sha256"] = hashlib.sha256(bytes.fromhex(code[2:])).hexdigest()
        else:
            entry["code_bytes"] = None
        entry["native_balance_wei"] = rpc(urls, "eth_getBalance", [addr, "latest"])
        if not entry["code_bytes"]:
            result["ends"].append(entry)
            log(f"[{chain}] {addr} NO CODE")
            continue
        entry["paused"] = int(call(urls, addr, SELECTORS["paused"]), 16)
        entry["migratedContract"] = call(urls, addr, SELECTORS["migratedContract"])
        entry["depositIndex"] = int(call(urls, addr, SELECTORS["depositIndex"]), 16)
        entry["nextExecutionIndex"] = int(call(urls, addr, SELECTORS["nextExecutionIndex"]), 16)
        entry["validatorFeeBPS"] = int(call(urls, addr, SELECTORS["validatorFeeBPS"]), 16)
        s8 = int(storage(urls, addr, 8), 16)
        entry["quorum"] = {"c1": s8 & 0xFF, "c2": (s8 >> 8) & 0xFF}
        entry["committeeSizes"] = {"c1": (s8 >> 16) & 0xFF, "c2": (s8 >> 24) & 0xFF}
        entry["eip1967"] = {k: storage(urls, addr, int(v, 16)) for k, v in EIP1967.items()}
        entry["roles"] = {}
        for rname, rh in ROLES.items():
            c = call(urls, addr, SELECTORS["getRoleMemberCount(bytes32)"] + rh)
            cnt = int(c, 16) if isinstance(c, str) and len(c) > 2 else None
            members = []
            if isinstance(cnt, int):
                for i in range(min(cnt, 8)):
                    m = call(urls, addr, SELECTORS["getRoleMember(bytes32,uint256)"] + rh + hex(i)[2:].zfill(64))
                    if isinstance(m, str) and len(m) == 66:
                        members.append("0x" + m[2 + 24 :])
            entry["roles"][rname] = {"count": cnt, "members": members}
        # role-holder contract types
        entry["role_holder_types"] = {}
        for rname in ("DEFAULT_ADMIN", "WEAK_ADMIN"):
            for m in entry["roles"][rname]["members"]:
                c = rpc(urls, "eth_getCode", [m, "latest"])
                size = (len(c) - 2) // 2 if isinstance(c, str) else None
                t = {"code_bytes": size}
                if size:
                    d = call(urls, m, SELECTORS["getMinDelay()"])
                    if isinstance(d, str) and len(d) >= 66:
                        t["timelock_min_delay_s"] = int(d, 16)
                    thr = call(urls, m, SELECTORS["getThreshold()"])
                    if isinstance(thr, str) and len(thr) >= 66:
                        t["safe_threshold"] = int(thr, 16)
                entry["role_holder_types"][m] = t
        # validators (only for the custody/mint ends we know)
        if addr in SIGNERS and chain in ("ethereum", "xdc", "songbird", "flare"):
            vals = []
            for s in SIGNERS[addr]:
                r = call(urls, addr, SELECTORS["validatorInfo(address)"] + s[2:].zfill(64))
                st = int(word(r, 0), 16) if isinstance(r, str) and len(r) >= 130 else None
                idx = int(word(r, 1), 16) if isinstance(r, str) and len(r) >= 130 else None
                vals.append({"signer": s, "status": STATUS.get(st, st), "index": idx})
            entry["validators"] = vals
            entry["active_signers"] = [v["signer"] for v in vals if v["status"] in ("FirstCommittee", "SecondCommittee")]
        # tokens
        tl = storage(urls, addr, 7)
        tl = int(tl, 16) if isinstance(tl, str) else 0
        toks = []
        for i in range(min(tl, 12)):
            t = "0x" + storage(urls, addr, int(TOKEN_ARRAY_SLOT, 16) + i)[2 + 24 :]
            bal = call(urls, t, SELECTORS["balanceOf(address)"] + addr[2:].zfill(64))
            bal = int(bal, 16) if isinstance(bal, str) else None
            dec = call(urls, t, SELECTORS["decimals()"])
            dec = int(dec, 16) if isinstance(dec, str) and len(dec) >= 66 else 18
            sym = call(urls, t, SELECTORS["symbol()"])
            ts = call(urls, t, SELECTORS["totalSupply()"])
            ts = int(ts, 16) if isinstance(ts, str) and len(ts) >= 66 else None
            toks.append(
                {
                    "token": t,
                    "symbol": dec_string(sym) if isinstance(sym, str) else "?",
                    "decimals": dec,
                    "balance": bal,
                    "balance_float": (bal / 10**dec) if bal is not None else None,
                    "totalSupply_float": (ts / 10**dec) if ts is not None else None,
                }
            )
        entry["tokens"] = toks
        result["ends"].append(entry)
        log(
            f"[{chain}] {addr[:10]} {label}: paused={entry['paused']} dep={entry['depositIndex']} "
            f"next={entry['nextExecutionIndex']} q={entry['quorum']} sizes={entry['committeeSizes']} "
            f"code={entry['code_bytes']}B tokens={[t['symbol'] for t in toks]}"
        )

    # mirror-token supply vs custody backing
    backing = []
    for mchain, mtok, mdec, cchain, caddr, usym in BACKING:
        s = call(CHAINS[mchain], mtok, SELECTORS["totalSupply()"])
        supply = int(s, 16) / 10**mdec if isinstance(s, str) and len(s) >= 66 else None
        cust_entry = next((e for e in result["ends"] if e["chain"] == cchain and e["address"] == caddr), None)
        custody = None
        if cust_entry:
            for t in cust_entry.get("tokens", []):
                if t["symbol"] == usym:
                    custody = t["balance_float"]
        backing.append(
            {
                "mirror": f"{mchain}:{mtok}",
                "mirror_decimals": mdec,
                "mirror_totalSupply": supply,
                "custody": f"{cchain}:{caddr}",
                "custody_underlying": usym,
                "custody_balance": custody,
                "surplus": round(custody - supply, 8) if (custody is not None and supply is not None) else None,
            }
        )
    result["backing"] = backing
    for b in backing:
        log(f"backing {b['mirror'][:18]} supply={b['mirror_totalSupply']} custody={b['custody_balance']} surplus={b['surplus']}")

    # prices + USD totals for the ETH/XDC custody
    ids = []
    for e in result["ends"]:
        if e["chain"] in ("ethereum", "xdc"):
            for t in e.get("tokens", []):
                ids.append(f"{e['chain']}:{t['token']}")
    prices = {}
    if ids:
        try:
            pr = get_json("https://coins.llama.fi/prices/current/" + ",".join(sorted(set(ids))))
            prices = {k: v["price"] for k, v in pr.get("coins", {}).items()}
        except Exception as e:  # noqa: BLE001
            log(f"prices err {e}")
    result["prices_usd"] = prices

    total_eth_xdc = 0.0
    for e in result["ends"]:
        subtotal = 0.0
        for t in e.get("tokens", []):
            p = prices.get(f"{e['chain']}:{t['token']}")
            if p is not None and t["balance_float"] is not None:
                t["usd"] = round(t["balance_float"] * p, 2)
                subtotal += t["usd"]
        e["usd_subtotal"] = round(subtotal, 2)
        if e["chain"] in ("ethereum", "xdc"):
            total_eth_xdc += subtotal
    result["total_usd_eth_xdc_custody"] = round(total_eth_xdc, 2)
    log(f"TOTAL USD (ETH+XDC custody): {result['total_usd_eth_xdc_custody']}")

    with open("ci-out/live-state.json", "w") as f:
        json.dump(result, f, indent=2)
    with open("ci-out/live-state.txt", "w") as f:
        f.write("\n".join(OUT) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
