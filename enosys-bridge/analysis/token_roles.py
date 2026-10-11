#!/usr/bin/env python3
"""Enosys Bridge — mirror-token role audit (read-only, public RPCs).

Checks who holds DEFAULT_ADMIN / MINTER / PAUSER / BURNER roles on the
wrapped tokens minted by the WrapMintBurn ends. Any non-bridge holder of
MINTER would be a potential unprivileged mint->redeem path into custody.
"""
import json
import time
import urllib.request

RPC = {
    "songbird": ["https://songbird-api.flare.network/ext/C/rpc"],
    "flare": ["https://flare-api.flare.network/ext/C/rpc"],
}
TOKENS = [
    ("songbird", "0x1a7b46656b2b8b29b1694229e122d066020503d0", "exUSDT", "0x8936761f2903ed1af2b269e6fa3a79ebb0162c51"),
    ("songbird", "0x36b84a93820175c02f57e5c87a7ea33df58e5c94", "exETH", "0x8936761f2903ed1af2b269e6fa3a79ebb0162c51"),
    ("songbird", "0xc54de96302981f87a6f80e4607593681b44d670c", "exXDC", "0xcb71dc7b30205eb7ce27b2cb36b24ba331ecd42a"),
    ("flare", "0x96b41289d90444b8add57e6f265db5ae8651df29", "eUSDT", "0x37aca97a99d1b4260a5e9821d0ef14947fb68970"),
    ("flare", "0xa76dcddce60a442d69bac7158f3660f50921b122", "eETH", "0x37aca97a99d1b4260a5e9821d0ef14947fb68970"),
    ("flare", "0x60fdc7b744e886e96aa0def5f69ee440db9d8c77", "eQNT", "0x37aca97a99d1b4260a5e9821d0ef14947fb68970"),
]
ROLES = {
    "DEFAULT_ADMIN": "00" * 32,
    "MINTER_ROLE": "9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
    "PAUSER_ROLE": "65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a",
    "BURNER_ROLE": "3c11d16cbaffd01df69ce1c404f6340ee057498f5f00246190ea54220576a848",
}
SEL = {"getRoleMemberCount": "0xca15c873", "getRoleMember": "0x9010d07c", "owner": "0x8da5cb5b"}


def rpc(chain, method, params, tries=3, tmo=20):
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


def call(chain, to, data):
    return rpc(chain, "eth_call", [{"to": to, "data": data}, "latest"])


def num(x):
    try:
        return int(x, 16)
    except Exception:  # noqa: BLE001
        return None


out = {}
for chain, tok, sym, bridge in TOKENS:
    e = {"chain": chain, "token": tok, "bridge": bridge, "roles": {}, "owner": None}
    for rn, rh in ROLES.items():
        c = num(call(chain, tok, SEL["getRoleMemberCount"] + rh))
        members = []
        if c:
            for i in range(min(c, 10)):
                m = call(chain, tok, SEL["getRoleMember"] + rh + hex(i)[2:].zfill(64))
                if isinstance(m, str) and len(m) == 66:
                    members.append("0x" + m[2 + 24 :])
        e["roles"][rn] = {"count": c, "members": members}
    o = call(chain, tok, SEL["owner"])
    e["owner"] = "0x" + o[2 + 24 :] if isinstance(o, str) and len(o) == 66 else None
    out[f"{chain}:{sym}"] = e
    print(f"[{chain}] {sym} roles:", json.dumps(e["roles"]), "owner:", e["owner"], flush=True)

with open("analysis/token_roles.json", "w") as f:
    json.dump(out, f, indent=2)
print("written analysis/token_roles.json")
