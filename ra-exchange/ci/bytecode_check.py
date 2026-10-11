#!/usr/bin/env python3
"""
Bytecode-equivalence check for Ra Exchange (Fraxtal).

For each verified implementation contract:
  1. reconstruct the exact standard-json source tree from the Etherscan V2 dump
     (analysis/src/<addr>.json) into a scratch Foundry project,
  2. replicate the recorded compiler settings exactly (solc, optimizer runs,
     evmVersion, viaIR, metadata.bytecodeHash),
  3. compile, patch library link references with the addresses found in the
     on-chain code, and compare the runtime bytecode with eth_getCode.

A full match proves: verified source == deployed code, so the source-level
audit is sound.

Writes ci-out/bytecode_check.json. Read-only, keyless.
"""
import json, os, subprocess, sys, urllib.request, glob, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC_DIR = os.path.join(ROOT, "analysis", "src")
OUT_DIR = os.path.join(ROOT, "ci-out")
WORK = "/tmp/ra-bytecode-check"
RPC = os.environ.get("FRAXTAL_RPC_URL", "https://rpc.frax.com")

TARGETS = [
    ("0x45cb3c8f281dc83bf5241c431e39d00b4e4d0773", "ClPool"),
    ("0x54bf8621e502c36a574a3ee63ef2004c5b694463", "NonfungiblePositionManager"),
    ("0xf5d139c3f51967505c532c42898ba47b15da4b9f", "Pair"),
    ("0x30fde68848d4463578e971e51652602ed9825c0c", "ClPoolFactory"),
    ("0xa54419918081e5b7638884acab0415c5964b8c0f", "PairFactory"),
    ("0x26ce5f861ad2c8b6b99a20d5694f1f372a5d3d5e", "FeeCollector"),
    ("0xb453976b702a7f0fef73523e47254a8260252c13", "FeeDistributor"),
    ("0xae41f746d245238f6d25befa86c8ee85b98b01bc", "Voter"),
]


def rpc_code(addr):
    payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_getCode", "params": [addr, "latest"]}
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())["result"]


def find_src(addr):
    m = [f for f in glob.glob(SRC_DIR + "/*.json") if os.path.basename(f).lower().startswith(addr.lower())]
    return m[0] if m else None


def reconstruct(addr, project):
    p = find_src(addr)
    if not p:
        return None, None
    d = json.load(open(p))
    r = d.get("result")
    if not isinstance(r, list) or not r:
        return None, None
    r0 = r[0]
    sc = r0.get("SourceCode") or ""
    if sc.startswith("{{"):
        sc = sc[1:-1]
    if not sc.strip().startswith("{"):
        return None, None
    j = json.loads(sc)
    sources = j.get("sources", {})
    shutil.rmtree(project, ignore_errors=True)
    os.makedirs(project, exist_ok=True)
    for path, body in sources.items():
        fp = os.path.join(project, path)
        os.makedirs(os.path.dirname(fp), exist_ok=True)
        open(fp, "w").write(body.get("content", ""))
    meta = {
        "solc": r0.get("CompilerVersion", "").split("+")[0].lstrip("v"),
        "settings": j.get("settings", {}),
    }
    return sources, meta


def default_evm(solc):
    """Map 'default' evmVersion to the solc default for that version."""
    try:
        parts = [int(x) for x in solc.split(".")]
    except Exception:
        return "istanbul"
    v = (parts + [0, 0, 0])[:3]
    if v >= [0, 8, 20]:
        return "shanghai"
    if v >= [0, 8, 18]:
        return "paris"
    if v >= [0, 8, 7]:
        return "london"
    if v >= [0, 8, 0]:
        return "london"
    if v >= [0, 7, 0]:
        return "istanbul"
    if v >= [0, 6, 0]:
        return "istanbul"
    return "istanbul"


def compile_project(project, meta):
    s = meta["settings"]
    opt = s.get("optimizer", {})
    runs = opt.get("runs", 200)
    evm = s.get("evmVersion", "default")
    if evm in ("default", ""):
        evm = default_evm(meta["solc"])
    via_ir = bool(s.get("viaIR", False))
    bhash = s.get("metadata", {}).get("bytecodeHash", "ipfs")
    via_line = f'via_ir = true\n' if via_ir else ''
    toml = f"""[profile.default]
src = "."
out = "out"
libs = []
solc = "{meta['solc']}"
optimizer = {"true" if opt.get("enabled", True) else "false"}
optimizer_runs = {runs}
evm_version = "{evm}"
{via_line}bytecode_hash = "{bhash}"
remappings = [
  "@openzeppelin-3.4.2/=./@openzeppelin-3.4.2/",
  "@openzeppelin-upgradeable/=./@openzeppelin-upgradeable/",
  "@openzeppelin/=./@openzeppelin/",
  "solmate/=./solmate/",
]
"""
    open(os.path.join(project, "foundry.toml"), "w").write(toml)
    r = subprocess.run(["forge", "build", "--force"], cwd=project, capture_output=True, text=True, timeout=1200)
    return r, {"runs": runs, "evm": evm, "via_ir": via_ir, "bytecode_hash": bhash}


def artifact(project, name):
    for root, _, files in os.walk(os.path.join(project, "out")):
        for f in files:
            if f == name + ".json":
                return json.load(open(os.path.join(root, f)))
    return None


def patch_links(compiled_hex, linkrefs, onchain_hex):
    out = list(compiled_hex)
    patched = 0
    for _path, libs in (linkrefs or {}).items():
        for _lib, refs in libs.items():
            for ref in refs:
                start = 2 + ref["start"] * 2
                length = ref["length"] * 2
                if start + length <= len(out) and start + length <= len(onchain_hex):
                    out[start:start + length] = list(onchain_hex[start:start + length])
                    patched += 1
    return "".join(out), patched


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    results = {}
    for addr, name in TARGETS:
        rec = {"address": addr, "contract": name}
        project = os.path.join(WORK, name)
        try:
            sources, meta = reconstruct(addr, project)
            if sources is None:
                rec["error"] = "no standard-json source dump found"
                results[name] = rec
                continue
            rec["sources"] = len(sources)
            rec["solc"] = meta["solc"]
            r, cfg = compile_project(project, meta)
            rec.update(cfg)
            rec["forge_ok"] = (r.returncode == 0)
            if r.returncode != 0:
                rec["forge_tail"] = (r.stdout + r.stderr)[-2500:]
                results[name] = rec
                continue
            a = artifact(project, name)
            if not a:
                rec["error"] = "artifact not found"
                results[name] = rec
                continue
            compiled = a["deployedBytecode"]["object"].lower()
            onchain = rpc_code(addr).lower()
            linkrefs = a["deployedBytecode"].get("linkReferences") or {}
            rec["link_refs"] = sum(len(refs) for libs in linkrefs.values() for refs in libs.values())
            patched, npatched = patch_links(compiled, linkrefs, onchain)
            rec["links_patched"] = npatched
            rec["match_full"] = (patched == onchain)
            rec["compiled_len"] = len(patched)
            rec["onchain_len"] = len(onchain)
            if not rec["match_full"]:
                # first difference offset
                n = min(len(patched), len(onchain))
                d = next((i for i in range(n) if patched[i] != onchain[i]), n)
                rec["first_diff_char"] = d
                rec["compiled_tail"] = patched[-120:]
                rec["onchain_tail"] = onchain[-120:]
            results[name] = rec
            print(f"{name}: match_full={rec.get('match_full')} links={rec.get('links_patched')}/{rec.get('link_refs')} len={rec.get('compiled_len')}/{rec.get('onchain_len')}", flush=True)
        except Exception as e:
            rec["error"] = repr(e)
            results[name] = rec
            print(json.dumps(rec, indent=1), flush=True)
    json.dump(results, open(os.path.join(OUT_DIR, "bytecode_check.json"), "w"), indent=1)
    ok = all(v.get("match_full") for v in results.values())
    print("ALL_MATCH" if ok else "MISMATCH")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
