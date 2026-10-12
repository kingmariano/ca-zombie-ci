#!/usr/bin/env python3
"""
CI integrity check: prove the deployed NarwhalswapPair implementation is the
Sourcify-verified source.

Method:
  1. read factory.pairCodeHash() = keccak256(type(NarwhalswapPair).creationCode)
  2. recompile analysis/sources/NarwhalswapFactory.sol (Sourcify bundle incl. the pair)
     with solc 0.6.12, optimizer 200, evm=istanbul, source path "NarwhalswapFactory.sol"
  3. fetch one deployed pair's runtime code
  4. my compiled runtime differs from the deployed runtime ONLY in the trailing 51-byte
     IPFS metadata block -> splice the on-chain metadata into my compiled creation code
  5. keccak256(spliced creation code) must equal pairCodeHash, and
     sha256(spliced runtime) must equal sha256(on-chain runtime)

Read-only; RPC URLs are redacted from all output.
"""
import json, os, re, subprocess, sys, time, urllib.request, hashlib

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "ci-out")
os.makedirs(OUT, exist_ok=True)
UA = {"User-Agent": "Mozilla/5.0 zombie-ci"}
URL_RE = re.compile(r"https?://\S+")
RPCS = [os.environ.get("BSC_RPC_URL") or "", "https://bsc-rpc.publicnode.com",
        "https://bsc-dataseed.bnbchain.org", "https://1rpc.io/bnb"]
RPCS = [u for u in RPCS if u]
FACTORY = "0xb9fa84912ff2383a617d8b433e926adf0dd3fea1"
SAMPLE_PAIR = "0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2"  # NAR/WBNB

def redact(s): return URL_RE.sub("<url-redacted>", str(s))[:150]

def rpc(method, params, timeout=25):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    errs = []
    for url in RPCS:
        try:
            req = urllib.request.Request(url, data=body, headers={**UA, "Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read().decode())
            if "result" in d:
                return d["result"]
            errs.append(redact(d.get("error")))
        except Exception as e:
            errs.append(redact(e))
        time.sleep(0.3)
    raise RuntimeError("rpc fail: " + " | ".join(errs[-2:]))

def main():
    res = {"method": "recompile verified bundle + splice on-chain metadata", "match": False}
    res["block"] = int(rpc("eth_blockNumber", []), 16)
    try:
        sel = subprocess.run(["cast", "sig", "pairCodeHash()"], capture_output=True, text=True, timeout=30).stdout.strip()
    except Exception:
        sel = "0x9aab9248"
    res["selector"] = sel
    res["pairCodeHash"] = rpc("eth_call", [{"to": FACTORY, "data": sel}, "latest"])
    print("factory.pairCodeHash =", res["pairCodeHash"])

    tmp = "/tmp/paircheck"
    os.makedirs(os.path.join(tmp, "src"), exist_ok=True)
    shutil_target = os.path.join(tmp, "NarwhalswapFactory.sol")
    with open(os.path.join(HERE, "analysis", "sources", "NarwhalswapFactory.sol")) as f:
        bundle = f.read()
    with open(shutil_target, "w") as f:
        f.write(bundle)
    with open(os.path.join(tmp, "foundry.toml"), "w") as f:
        f.write('[profile.default]\nsrc = "."\nout = "out"\nlibs = []\nsolc = "0.6.12"\n'
                'optimizer = true\noptimizer_runs = 200\nevm_version = "istanbul"\n')
    p = subprocess.run(["forge", "build", "--root", tmp], capture_output=True, text=True, timeout=900)
    print("forge build rc:", p.returncode)
    if p.returncode != 0:
        res["build_error"] = redact((p.stderr or p.stdout)[-400:])
        json.dump(res, open(os.path.join(OUT, "integrity.json"), "w"), indent=1)
        sys.exit(1)

    art = os.path.join(tmp, "out", "NarwhalswapFactory.sol", "NarwhalswapPair.json")
    a = json.load(open(art))
    cc = a["bytecode"]["object"]; cc = bytes.fromhex(cc[2:] if cc.startswith("0x") else cc)
    mine = a["deployedBytecode"]["object"]; mine = bytes.fromhex(mine[2:] if mine.startswith("0x") else mine)
    onchain = bytes.fromhex(rpc("eth_getCode", [SAMPLE_PAIR, "latest"])[2:])

    res.update({"creation_bytes": len(cc), "runtime_bytes": len(onchain),
                "compiled_runtime_bytes": len(mine), "sample_pair": SAMPLE_PAIR})
    res["runtime_identical"] = (mine == onchain)
    # trailing CBOR metadata length (last 2 bytes) — typically 51 for solc 0.6.x
    cb = (mine[-2] << 8) | mine[-1]
    res["metadata_bytes"] = cb
    spliced_rt = mine[:len(mine) - cb] + onchain[len(onchain) - cb:]
    res["spliced_runtime_sha256"] = hashlib.sha256(spliced_rt).hexdigest()
    res["onchain_runtime_sha256"] = hashlib.sha256(onchain).hexdigest()
    res["runtime_identical_after_metadata_splice"] = (spliced_rt == onchain)
    spliced_cc = cc[:len(cc) - cb] + onchain[len(onchain) - cb:]
    kh = subprocess.run(["cast", "keccak", "0x" + spliced_cc.hex()], capture_output=True, text=True, timeout=60).stdout.strip()
    if kh.startswith("0x0x"):
        kh = kh[2:]
    res["spliced_creation_keccak"] = kh
    res["match"] = kh.lower() == (res["pairCodeHash"] or "").lower()
    print("keccak(spliced creation) =", kh, "| match:", res["match"])
    print("runtime identical after metadata splice:", res["runtime_identical_after_metadata_splice"])
    json.dump(res, open(os.path.join(OUT, "integrity.json"), "w"), indent=1)
    if not res["match"]:
        sys.exit(1)

if __name__ == "__main__":
    main()
