#!/usr/bin/env python3
"""Verify deployed GRXswap pair/factory bytecode against the verified source recompiled
with the factory's own compiler settings (solc 0.5.16, optimizer off).

Three independent checks:
  A. Pair runtime == recompiled TokenPair runtime (modulo the trailing CBOR metadata hash,
     which depends only on compiler input paths).
  B. Factory runtime == recompiled factory runtime, where the ONLY difference is the bzzr1
     metadata hash *inside the embedded TokenPair creation code* (the factory embeds the
     pair creation code as data). Normalized comparison must be byte-for-byte equal.
  C. The on-chain factory's INIT_CODE_PAIR_HASH() equals keccak256 of the pair creation
     code embedded in the factory runtime (i.e. the factory really deploys this pair).
"""
import json, subprocess, sys, urllib.request, time, os

RPC = os.environ.get("GRX_RPC_URL", "https://rpc.grxchain.io")
FACTORY = "0xc7316818841f355c5107753a3f3fdea799bd25f6"
PAIR1 = "0x47b7f566a7c2f827d16a2336684b31929e1cb386"

def rpc(method, params):
    req = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    r = urllib.request.Request(RPC, data=json.dumps(req).encode(),
                               headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for _ in range(3):
        try:
            return json.load(urllib.request.urlopen(r, timeout=60)).get("result")
        except Exception:
            time.sleep(2)
    return None

def keccak(h):
    return subprocess.check_output(["cast", "keccak", h]).decode().strip()

def strip_meta(code_hex):
    c = code_hex[2:] if code_hex.startswith("0x") else code_hex
    if len(c) < 4:
        return c, ""
    try:
        ln = int(c[-4:], 16)
    except ValueError:
        return c, ""
    if ln == 0 or ln * 2 + 4 > len(c):
        return c, ""
    return c[: len(c) - ln * 2 - 4], c[len(c) - ln * 2 - 4:]

def load_artifact(path):
    with open(path) as f:
        a = json.load(f)
    return a.get("deployedBytecode", {}).get("object", ""), a.get("bytecode", {}).get("object", "")

def diff_regions(a, b):
    diffs = [i for i in range(0, min(len(a), len(b)), 2) if a[i:i+2] != b[i:i+2]]
    if not diffs:
        return []
    regions, s, prev = [], diffs[0], diffs[0]
    for d in diffs[1:]:
        if d != prev + 2:
            regions.append([s // 2, prev // 2 + 1]); s = d
        prev = d
    regions.append([s // 2, prev // 2 + 1])
    return regions

def main():
    out = {"rpc": RPC, "block": int(rpc("eth_blockNumber", []), 16)}
    pair_dep, pair_cre = load_artifact("poc/out-pair/TokenPair.sol/TokenPair.json")
    fact_dep, _ = load_artifact("poc/out-factory/GRXSwapFactoryV2.sol/GRXSwapFactoryV2.json")
    on_pair = rpc("eth_getCode", [PAIR1, "latest"])
    on_fact = rpc("eth_getCode", [FACTORY, "latest"])

    # --- A. pair runtime ---
    ps, pm = strip_meta(pair_dep); os_, om = strip_meta(on_pair)
    out["A_pair_runtime"] = {
        "local_len": len(pair_dep) // 2, "onchain_len": len(on_pair) // 2,
        "match_full": pair_dep == on_pair,
        "match_metadata_stripped": ps == os_,
        "local_metadata_len": len(pm) // 2, "onchain_metadata_len": len(om) // 2,
        "note": "metadata = trailing CBOR {bzzr1, solc} only; differs by compile input path",
    }

    # --- B. factory runtime, normalized at the embedded pair bzzr1 hash ---
    fs, fm = strip_meta(fact_dep); ofs, ofm = strip_meta(on_fact)
    cre = (pair_cre[2:] if pair_cre.startswith("0x") else pair_cre)
    needle = cre[:64]
    loc_pos = fs.find(needle); on_pos = ofs.find(needle)
    norm_ok = None
    if loc_pos >= 0 and on_pos >= 0:
        # replace the 32-byte bzzr1 hash inside the embedded creation code with the local value
        def find_meta_hash(h, pos):
            # creation code metadata tail: ... a2 65 627a7a7231 5820 <32B hash> 64 736f6c63 ...
            i = h.find("a265627a7a72315820", pos)
            return i + len("a265627a7a72315820") if i >= 0 else -1
        lh = find_meta_hash(fs, loc_pos); oh = find_meta_hash(ofs, on_pos)
        if lh > 0 and oh > 0:
            on_norm = ofs[:oh] + fs[lh:lh+64] + ofs[oh+64:]
            norm_ok = (on_norm == fs)
            out["B_factory_runtime"] = {
                "local_len": len(fact_dep) // 2, "onchain_len": len(on_fact) // 2,
                "match_metadata_stripped": fs == ofs,
                "diff_regions_bytes": diff_regions(fs, ofs),
                "match_after_embedded_pair_metadata_normalization": norm_ok,
                "note": "only difference = bzzr1 hash of the embedded TokenPair creation code (compile-input dependent)",
            }
    if "B_factory_runtime" not in out:
        out["B_factory_runtime"] = {"match_metadata_stripped": fs == ofs,
                                    "diff_regions_bytes": diff_regions(fs, ofs)}

    # --- C. factory constant vs embedded creation code ---
    embedded = on_fact[2:] if on_fact.startswith("0x") else on_fact
    start = embedded.find(cre[:64])
    ich = None
    try:
        ich = rpc("eth_call", [{"to": FACTORY, "data": "0x5855a25a"}, "latest"])  # INIT_CODE_PAIR_HASH()
    except Exception:
        pass
    out["C_init_code_pair_hash"] = {
        "onchain_getter": ich,
        "keccak_of_embedded_creation_code": keccak("0x" + embedded[start:start + len(cre)]) if start >= 0 else None,
        "embedded_creation_code_offset": start // 2 if start >= 0 else -1,
    }
    if ich and start >= 0:
        out["C_init_code_pair_hash"]["match"] = (
            ich[2:].lower() == keccak("0x" + embedded[start:start + len(cre)])[2:].lower())
    print(json.dumps(out, indent=1))

if __name__ == "__main__":
    main()
