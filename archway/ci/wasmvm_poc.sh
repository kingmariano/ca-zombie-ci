#!/usr/bin/env bash
# C2-09 wasmvm artifact verification (read-only, no chain interaction).
# 1) Downloads the exact Go module artifacts the Archway binary was built against
#    (hash-verified against the live node build_deps) and inspects their Rust pins.
# 2) Builds tiny Go programs linking the prebuilt libwasmvm from each module and
#    prints the libwasmvm version reported by the C library.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="$ROOT/ci-out"
mkdir -p "$OUT"

echo "### A. module zip inspection" | tee "$OUT/wasmvm_artifact_check.txt"
python3 - <<'EOF' | tee -a "$OUT/wasmvm_artifact_check.txt"
import urllib.request, hashlib, zipfile, io, re
def fetch(u):
    req=urllib.request.Request(u, headers={"User-Agent":"zombie-hunt-ci"})
    with urllib.request.urlopen(req, timeout=120) as r: return r.read()
for v in ["v1.5.5","v1.5.8"]:
    url=f"https://proxy.golang.org/github.com/!cosm!wasm/wasmvm/@v/{v}.zip"
    z=fetch(url)
    print(f"\n== wasmvm {v} module zip sha256={hashlib.sha256(z).hexdigest()}")
    zf=zipfile.ZipFile(io.BytesIO(z))
    root=[n for n in zf.namelist() if n.endswith("/libwasmvm/Cargo.toml")][0].rsplit("/libwasmvm",1)[0]
    cargo=zf.read(root+"/libwasmvm/Cargo.toml").decode()
    lock=zf.read(root+"/libwasmvm/Cargo.lock").decode()
    mem=zf.read(root+"/libwasmvm/src/memory.rs").decode()
    m=re.search(r'cosmwasm-vm = \{ git = "[^"]+", rev = "([^"]+)"', cargo)
    print("  cosmwasm-vm pin:", m.group(1) if m else "?")
    m=re.search(r'\[\[package\]\]\nname = "cosmwasm-vm"\nversion = "([^"]+)"', lock)
    print("  Cargo.lock cosmwasm-vm:", m.group(1) if m else "?")
    m=re.search(r'\[\[package\]\]\nname = "wasmer"\nversion = "([^"]+)"', lock)
    print("  Cargo.lock wasmer:", m.group(1) if m else "?")
    # CWA-2025-001 fix = conditional null ptr for empty slices in U8SliceView::new Some branch
    fixed = "if data.is_empty()" in mem
    print("  memory.rs CWA-2025-001 empty-slice fix present:", fixed)
    sos=[n for n in zf.namelist() if n.endswith("libwasmvm.x86_64.so")]
    print("  prebuilt libwasmvm.x86_64.so in module:", bool(sos), (zf.getinfo(sos[0]).file_size if sos else 0), "bytes")
EOF

echo "### B. linked-lib version smoke test" | tee -a "$OUT/wasmvm_artifact_check.txt"
if command -v go >/dev/null 2>&1; then
  for v in v1.5.5 v1.5.8; do
    D=/tmp/wvm-poc-$v; rm -rf "$D"; mkdir -p "$D"; cd "$D"
    go mod init wvmpoc >/dev/null 2>&1
    go get github.com/CosmWasm/wasmvm@$v >/dev/null 2>&1
    cat > main.go <<'GO'
package main
import ("fmt"; wasmvm "github.com/CosmWasm/wasmvm")
func main() {
    ver, err := wasmvm.LibwasmvmVersion()
    fmt.Printf("linked libwasmvm version: %q (err=%v)\n", ver, err)
}
GO
    go mod tidy >/dev/null 2>&1
    echo "== go run with wasmvm $v" >> "$OUT/wasmvm_artifact_check.txt"
    (go run . 2>&1 | tail -3) >> "$OUT/wasmvm_artifact_check.txt" || echo "  go run failed" >> "$OUT/wasmvm_artifact_check.txt"
    cd - >/dev/null
  done
else
  echo "go toolchain not available on runner" >> "$OUT/wasmvm_artifact_check.txt"
fi
echo "done" >> "$OUT/wasmvm_artifact_check.txt"
cat "$OUT/wasmvm_artifact_check.txt"
