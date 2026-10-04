#!/usr/bin/env python3
"""Completeness: union of tokens ever seen in tokentx per protocol address, then balanceOf now."""
import json
import os
import subprocess
import sys
import time
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpcx import rpc, batch, dec_u  # noqa

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
ES = os.path.join(RAW, "etherscan")
os.makedirs(ES, exist_ok=True)


def env_key():
    out = subprocess.run(["bash", "-lc",
                          "set -a; . /home/heisenberg/CA/.env; set +a; printf %s \"$ETHERSCANV2_API_KEY\""],
                         capture_output=True, text=True)
    return out.stdout.strip()


KEY = env_key()

TARGETS = {
    "treasury": "0x5dc4dd7969944300083994c60e2ce67b4b81457c",
    "poolA": "0x0850A9759165B25832E2cAa3dB3f2d04dc583D4E",
    "poolB": "0x56eb1bcB2aA011517fD7bf32641E79Bd8471770e",
    "providerA": "0x4b139f6E816934D580D9305Ca0f115145f698973",
    "providerB": "0x282eDE6BbD2d224D454C995e66f08569A5508e9a",
    "configuratorA": "0x1C5D4B5DFC1A47e5Db839Cb8A0Fb36bAb1E986B7",
    "configuratorB": "0xc9122E191d9bDaBf9b59A31C01D4e6c4cd719E89",
    "oracleA": "0xce767E508A17321C25117b44d246e4611bbEcFE4",
    "oracleB": "0xc131bA07e9a6533e46Ca539280d02a42AC9C131a",
    "aclA": "0x1637b78Dd5541F0dB2f3d04EeD39De37Df71BD08",
    "aclB": "0x8f0431F6Adb3e81D282d0508c16e2817DC95095b",
    "dataProviderA": "0x5d10c393F9DF12BbbA49B8E8d5D7Fc4674d2e115",
    "dataProviderB": "0xA298a88760c64dFA3D6774a9dbec04eF4297a850",
    "safeB": "0xD3E02C92f59a0ba5601464299D658d3a0a7cf96F",
    "attacker": "0xF321683831Be16eeD74dfA58b02a37483cEC662e",
    "admin_0x0dd0": "0x0dd010513F7abB8F9c628dC164a24D953BCA09Cf",
    "aclAdminA_eoa": "0x3d0c177E035C30bb8681e5859EB98d114b48b935",
    "deployer": "0xc7461891c88f6a609d9149d2826704bd178a80de",
    "safeOwner1": "0x6d0F4Cec05a7066D3f509A732D59Ede630989053",
    "safeOwner2": "0x75eF5d635388d7C97425596CE50c11844234128B",
}


def fetch_tokentx(tag, addr):
    path = os.path.join(ES, f"tokentx_{tag}.json")
    if os.path.exists(path) and os.path.getsize(path) > 50:
        return json.load(open(path))
    url = (f"https://api.etherscan.io/v2/api?chainid=146&module=account&action=tokentx"
           f"&address={addr}&startblock=0&endblock=99999999&sort=asc&apikey={KEY}")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        d = json.load(r)
    json.dump(d, open(path, "w"), indent=1)
    time.sleep(0.4)
    return d


def main():
    block = int(rpc("eth_blockNumber", []), 16)
    out = {"block": block, "targets": {}}
    token_union = {}
    for tag, addr in TARGETS.items():
        d = fetch_tokentx(tag, addr)
        toks = set()
        if d.get("status") == "1":
            for t in d["result"]:
                if t.get("contractAddress"):
                    toks.add(t["contractAddress"].lower())
        token_union[tag] = sorted(toks)
        out["targets"][tag] = {"address": addr, "tokens_seen": len(toks)}
    all_tokens = sorted({t for ts in token_union.values() for t in ts})
    print("unique tokens across all tokentx:", len(all_tokens))
    for t in all_tokens:
        print("  ", t)

    # symbols
    calls, meta = [], []
    for tok in all_tokens:
        for sel, k in (("0x95d89b41", "symbol"), ("0x313ce567", "decimals")):
            calls.append(("eth_call", [{"to": tok, "data": sel}, hex(block)]))
            meta.append((tok, k))
    res = batch(calls, timeout=180)
    tmeta = {}
    for (tok, k), v in zip(meta, res):
        tmeta.setdefault(tok, {})[k] = v

    def dec_str(hexstr):
        if not isinstance(hexstr, str):
            return None
        try:
            h = hexstr[2:]
            if len(h) < 128:
                return None
            ln = int(h[64:128], 16)
            return bytes.fromhex(h[128:128 + ln * 2]).decode("utf-8", "replace")
        except Exception:
            return None

    # balances: target x token
    calls, meta = [], []
    for tag, addr in TARGETS.items():
        for tok in all_tokens:
            calls.append(("eth_call", [{"to": tok, "data": "0x70a08231" + addr[2:].lower().rjust(64, "0")},
                                       hex(block)]))
            meta.append((tag, tok))
    print("balance calls:", len(calls))
    results = {}
    CH = 60
    for i in range(0, len(calls), CH):
        rs = batch(calls[i:i + CH], timeout=180)
        for (tag, tok), v in zip(meta[i:i + CH], rs):
            val = dec_u(v) if isinstance(v, str) else v
            if isinstance(val, int) and val != 0:
                results.setdefault(tag, {})[tok] = val
        print(f"  chunk {i}/{len(calls)}", flush=True)
    out["nonzero_balances"] = results
    out["token_meta"] = {t: {"symbol": dec_str(m.get("symbol")),
                             "decimals": dec_u(m.get("decimals")) if isinstance(m.get("decimals"), str) else None}
                         for t, m in tmeta.items()}
    json.dump(out, open(os.path.join(RAW, "completeness.json"), "w"), indent=1)
    print(json.dumps(results, indent=1))
    print(json.dumps(out["token_meta"], indent=1))


if __name__ == "__main__":
    main()
