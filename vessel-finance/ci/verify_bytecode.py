#!/usr/bin/env python3
"""
Reconstruct the explorer-verified Vault sources into a forge project and compare
the compiled runtime bytecode with the live deployed code at 0x8804201... (Scroll).
Tries both default and via-IR optimizer profiles. Informational, non-fatal.
Read-only. Keyless RPC.
"""
import json, os, subprocess, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
IMPL = "0x8804201FD6C0aBBcB62C158e51978893aA47785c"
RPC = "https://scroll-rpc.publicnode.com"
TAILS = (43, 53)  # metadata tail sizes (ipfs / bzzr0+solc)

def rpc(method, params):
    payload = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
    req = urllib.request.Request(RPC, data=payload, headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    return json.load(urllib.request.urlopen(req, timeout=60))["result"]

def norm(x): return x[2:].lower() if x.startswith("0x") else x.lower()

def main():
    d = json.load(open(os.path.join(ROOT, "analysis", "bs_impl.json")))
    proj = os.path.join(ROOT, "poc", "verify")
    if os.path.exists(proj):
        subprocess.run(["rm","-rf",proj])
    files = {d["file_path"]: d["source_code"]}
    for s in d.get("additional_sources") or []:
        files[s["file_path"]] = s["source_code"]
    for path, src in files.items():
        out = os.path.join(proj, path)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        open(out, "w").write(src)
    open(os.path.join(proj, "foundry.toml"), "w").write(
        '[profile.default]\n'
        'src = "src"\nout = "out"\nlibs = ["lib"]\n'
        'solc = "0.8.19"\noptimizer = true\noptimizer_runs = 10000\nevm_version = "paris"\n\n'
        '[profile.viair]\n'
        'src = "src"\nout = "out-viair"\nlibs = ["lib"]\n'
        'solc = "0.8.19"\noptimizer = true\noptimizer_runs = 10000\nevm_version = "paris"\nvia_ir = true\n\n'
        '[profile.viair_nometa]\n'
        'src = "src"\nout = "out-viair-nometa"\nlibs = ["lib"]\n'
        'solc = "0.8.19"\noptimizer = true\noptimizer_runs = 10000\nevm_version = "paris"\n'
        'via_ir = true\nbytecode_hash = "none"\ncbor_metadata = false\n'
    )
    print(f"[verify] reconstructed {len(files)} sources into poc/verify")
    live = norm(rpc("eth_getCode", [IMPL, "latest"]))
    print(f"[verify] live deployed runtime: {len(live)//2} bytes ({IMPL})")
    for profile in ("viair_nometa", "viair", "default"):
        env = dict(os.environ, FOUNDRY_PROFILE=profile)
        r = subprocess.run(["forge","inspect","src/vault/Vault.sol:Vault","deployedBytecode"],
                           cwd=proj, capture_output=True, text=True, timeout=2400, env=env)
        if r.returncode != 0:
            print(f"[verify] profile={profile}: forge inspect failed:")
            print(r.stderr[-2000:])
            continue
        comp = norm(r.stdout.strip())
        print(f"[verify] profile={profile}: compiled {len(comp)//2} bytes")
        if comp == live:
            print(f"[verify] profile={profile}: EXACT MATCH deployed == compiled verified source")
            return
        if len(live) <= len(comp) and comp.startswith(live):
            print(f"[verify] profile={profile}: MATCH — deployed runtime equals the first "
                  f"{len(live)//2} bytes of the compiled verified source (deployed code identical; "
                  f"deployment stripped the {len(comp)//2 - len(live)//2}-byte metadata suffix)")
            return
        matched_tail = None
        for tail in TAILS:
            if len(comp) > 2*tail + 100 and comp[:-2*tail] == live[:-2*tail]:
                matched_tail = tail
                break
        if matched_tail:
            print(f"[verify] profile={profile}: MATCH up to metadata tail ({matched_tail} bytes) "
                  f"— deployed code == verified source (only metadata differs)")
            return
        n = min(len(comp), len(live))
        i = 0
        while i < n and comp[i] == live[i]:
            i += 1
        print(f"[verify] profile={profile}: MISMATCH at byte {i//2} "
              f"(compiled {len(comp)//2}B vs live {len(live)//2}B)")
        print(f"[verify]   compiled ...{comp[max(0,i-40):i+40]}...")
        print(f"[verify]   live     ...{live[max(0,i-40):i+40]}...")
    print("[verify] done (no exact match found; see above)")

if __name__ == "__main__":
    main()
