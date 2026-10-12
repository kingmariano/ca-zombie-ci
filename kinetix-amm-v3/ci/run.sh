#!/usr/bin/env bash
# Kinetix AMM V3 — heavy CI job: bytecode-provenance proofs + live valuation.
# Writes results to ci-out/. Uses only keyless public RPCs as fallbacks;
# any keyed RPC URLs from the environment are never printed.
set -uo pipefail
cd "$(dirname "$0")/.."   # -> finding folder
mkdir -p ci-out

INIT=0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54
KF=0x2dBB6254231C5569B6A4313c6C1F5Fe1340b35C2
BF=0xddf5a3259a88ab79d5530eb3eb14c1c92cd97fcf
NFPM_K=0x8dB08eD2b460643974C64BE42087903470Df6a54
NFPM_E=0xC36442b4a4522E871399CD717aBDD847Ab11FE88

pick() {
  for u in "$@"; do
    [ -z "$u" ] && continue
    r=$(curl -s -m 12 -X POST -H 'Content-Type: application/json' \
          --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$u" 2>/dev/null)
    case "$r" in *result*) echo "$u"; return 0;; esac
  done
  echo ""
}
RK=$(pick "${KAVA_RPC_URL:-}" "https://kava-evm-rpc.publicnode.com" "https://rpc.ankr.com/kava_evm")
[ -z "$RK" ] && RK="https://kava-evm-rpc.publicnode.com"
RB=$(pick "${BASE_RPC_URL:-}" "https://base-rpc.publicnode.com")
[ -z "$RB" ] && RB="https://base-rpc.publicnode.com"
RE=$(pick "${FORK_RPC_URL:-}" "${RPC_URL:-}" "https://ethereum-rpc.publicnode.com" "https://eth.drpc.org")
[ -z "$RE" ] && RE="https://ethereum-rpc.publicnode.com"

echo "[kinetix] RPC endpoints selected (kava/base/eth)" > ci-out/run-info.txt
{
  echo "kava block: $(cast block-number --rpc-url "$RK")"
  echo "base block: $(cast block-number --rpc-url "$RB")"
  echo "eth block : $(cast block-number --rpc-url "$RE")"
} >> ci-out/run-info.txt
cat ci-out/run-info.txt

echo "== 1) CREATE2 provenance: every pool == canonical Uniswap V3 pool init code hash =="
python3 - "$RK" "$RB" <<'PY' | tee ci-out/create2-proof.txt
import subprocess, csv, json, sys
rk, rb = sys.argv[1], sys.argv[2]
INIT = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54"
KF = "0x2dbb6254231c5569b6a4313c6c1f5fe1340b35c2"
BF = "0xddf5a3259a88ab79d5530eb3eb14c1c92cd97fcf"

def create2(factory, t0, t1, fee):
    salt = subprocess.run(["cast","abi-encode","f(address,address,uint24)",t0,t1,str(fee)],capture_output=True,text=True).stdout.strip()
    salt = subprocess.run(["cast","keccak",salt],capture_output=True,text=True).stdout.strip()
    out = subprocess.run(["cast","create2","--deployer",factory,"--salt",salt,"--init-code-hash",INIT],capture_output=True,text=True).stdout.split()[0]
    return out.lower()

bad = 0; n = 0
for r in csv.DictReader(open("analysis/kava-pools.csv")):
    n += 1
    got = create2(KF, r["token0"], r["token1"], int(r["fee"]))
    if got != r["pool"].lower():
        bad += 1
        print(f"MISMATCH kava {r['pool']} got {got}")
print(f"KAVA pools: {n} checked, {n-bad} canonical, {bad} mismatched")

bn = 0; m = 0
for r in json.load(open("analysis/base-pools-raw.json")):
    m += 1
    got = create2(BF, r["t0"]["id"], r["t1"]["id"], int(r["fee"]))
    if got != r["pool"].lower():
        bn += 1
        print(f"MISMATCH base {r['pool']} got {got}")
print(f"BASE pools: {m} checked, {m-bn} canonical, {bn} mismatched")
sys.exit(1 if (bad or bn) else 0)
PY
C2=$?
[ $C2 -ne 0 ] && echo "CREATE2 PROOF FAILED" && exit 1

echo "== 2) Deployed bytecode provenance vs canonical Uniswap deployments =="
python3 - "$RK" "$RE" <<'PY' | tee ci-out/bytecode-proof.txt
import subprocess, sys
rk, re_ = sys.argv[1], sys.argv[2]
KF = "0x2dbb6254231c5569b6a4313c6c1f5fe1340b35c2"

def code(addr, rpc):
    return subprocess.run(["cast","code",addr,"--rpc-url",rpc],capture_output=True,text=True).stdout.strip().lower().replace("0x","")

def norm(code, addrs):
    for a in addrs:
        pad = a.lower().replace("0x","").rjust(64,"0")
        code = code.replace(pad, "e"*64)
    return code

# factory: canonical Uniswap V3 factory bytecode; only its own address literal differs
kf = code("0x2dBB6254231C5569B6A4313c6C1F5Fe1340b35C2", rk)
ef = code("0x1F98431c8aD98523631AE4a59f267346ea31F984", re_)
kfn = norm(kf, [KF]); efn = norm(ef, ["0x1f98431c8ad98523631ae4a59f267346ea31f984"])
print("factory: kava bytes", len(kf)//2, "eth bytes", len(ef)//2)
print("factory bytecode identical after normalizing the embedded self-address:", kfn == efn)
assert kfn == efn, "factory bytecode mismatch"

# NFPM v1.3.0: immutables factory, WETH9, tokenDescriptor
kn = code("0x8dB08eD2b460643974C64BE42087903470Df6a54", rk)
en = code("0xC36442b4a4522E871399CD717aBDD847Ab11FE88", re_)
knn = norm(kn, ["0x2dbb6254231c5569b6a4313c6c1f5fe1340b35c2","0xc86c7c0efbd6a49b35e8714c5f59d99de09a225b","0x6d7f903f3b5713d0674675ca9a47a183b3365848"])
enn = norm(en, ["0x1f98431c8ad98523631ae4a59f267346ea31f984","0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2","0xee6a57ec80ea46401049e92587e52f5ec1c24785"])
print("NFPM: kava bytes", len(kn)//2, "eth bytes", len(en)//2)
print("NFPM bytecode identical after normalizing the 3 immutables:", knn == enn)
assert knn == enn, "NFPM bytecode mismatch"

print("PROVENANCE: Kinetix factory + pool creation code + NFPM are canonical Uniswap V3 (v1.0.0 / periphery v1.3.0) bytecode")
PY
B2=$?
[ $B2 -ne 0 ] && echo "BYTECODE PROOF FAILED" && exit 1

echo "== 3) live valuation of funded pools =="
python3 - "$RK" "$RB" <<'PY' | tee ci-out/valuation.txt
import subprocess, json, sys, urllib.request
rk, rb = sys.argv[1], sys.argv[2]
ALIAS = {
    "0x919c1c267bc06a7039e03fcc2ef738525769109c": 0.9992,
    "0xc86c7c0efbd6a49b35e8714c5f59d99de09a225b": 0.068008,
    "0x15932e26f5bd4923d46a2b205191c4b5d5f43fe3": 1.8387,
    "0xeb466342c4d449bc9f53a865d5cb90586f405215": 1.0,
    "0x7f5373ae26c3e8ffc4c77b7255df7ec1a9af52a6": 1.0,
    "0xb44a9b6905af7c801311e8f4e76932ee959c663c": 1.0,
    "0xfa9343c3897324496a05fc75abed6bac29f8a40f": 1.0,
    "0x2dfd4de5ae386cd3f4fc8e2cb39240852e47f5e8": 2509.7,
    "0xb829b68f57cc546da7e5806a929e53be32a4625d": 2509.7,
    "0xe3f5a90f9cb311505cd691a46596599aa1a0ad7d": 2509.7,
    "0x1a35ee4640b0a3b87705b0a4b45d227ba60ca2ad": 82379.0,
    "0x818ec0a7fe18ff94269904fced6ae3dae6d6dc0b": 82379.0,
    "0xb5c4423a65b953905949548276654c96fcae6992": 82379.0,
    "0xce82db637a2d750380ef27063518eaa263fbe10e": 0.00003452,
    "0xc19281f22a075e0f10351cd5d6ea9f0ac63d4327": 66.71,
    "0x7c598c96d02398d89fbcb9d41eab3df0c16f227d": 0.2356,
    "0xb51efaf2f7afb8a2f5be0b730281e414fb487636": 0.0013633,
    "0xf3c091ed43de9c270593445163a41a876a0bb3dd": 0.007173,
    "0x471ee749ba270eb4c1165b5ad95e614947f6fceb": 0.036763,
    "0x0b93109d05ef330acd2c75148891cc61d20c3ef1": 4.6709,
    "0x23a6486099f740b7688a0bb7aed7c912015ca2f0": 742.19,
    "0xaf20f5f19698f1d19351028cd7103b63d30de7d7": 0.0004481,  # WAGMI (geckoterminal, illiquid)
    "0x52369b1539ea8f4e1eadeef18d85462dcf9a3658": 0.000122,   # KAI
}
def call(to, data, arg, rpc):
    return subprocess.run(["cast","call",to,data,arg,"--rpc-url",rpc],capture_output=True,text=True).stdout.split("\n")[0].split()[0]

P = json.load(open("analysis/kava-pool-balances.json"))
meta = P["tokens"]
total = 0.0; rows = []
for p in P["pools"]:
    t0, t1 = p["token0"], p["token1"]
    b0 = int(call(t0, "balanceOf(address)(uint256)", p["pool"], rk)); b1 = int(call(t1, "balanceOf(address)(uint256)", p["pool"], rk))
    a0 = b0 / 10**meta[t0]["decimals"]; a1 = b1 / 10**meta[t1]["decimals"]
    u0 = a0 * ALIAS.get(t0, 0.0); u1 = a1 * ALIAS.get(t1, 0.0)
    total += u0 + u1
    if u0 + u1 > 1.0:
        rows.append({"pool": p["pool"], "fee": p["fee"], "sym0": meta[t0]["symbol"], "amt0": a0, "sym1": meta[t1]["symbol"], "amt1": a1, "usd": u0 + u1})
rows.sort(key=lambda r: -r["usd"])
print(f"KAVA funded-pool total (live balances x fixed prices): ${total:,.2f}")
for r in rows[:12]:
    print(f"  ${r['usd']:>10,.2f} {r['pool']} {r['sym0']}({r['amt0']:.6g}) / {r['sym1']}({r['amt1']:.6g})")
json.dump({"kava_total_usd": round(total,2), "rows": rows}, open("ci-out/valuation.json","w"), indent=1)

B = json.load(open("analysis/base-pools-raw.json"))
btot = 0.0
for r in B:
    a0 = int(r["bal0"]) / 10**int(r["t0"]["decimals"]) if r["bal0"] not in (None, "0") else 0
    a1 = int(r["bal1"]) / 10**int(r["t1"]["decimals"]) if r["bal1"] not in (None, "0") else 0
    btot += a0 * ALIAS.get(r["t0"]["id"], 0.0) + a1 * ALIAS.get(r["t1"]["id"], 0.0)
print(f"BASE funded-pool total: ${btot:,.2f}")
PY
V=$?
[ $V -ne 0 ] && echo "VALUATION FAILED" && exit 1

echo "== 4) position-manager spot checks ==" | tee ci-out/position-checks.txt
{
  echo "NFPM totalSupply: $(cast call 0x8dB08eD2b460643974C64BE42087903470Df6a54 'totalSupply()(uint256)' --rpc-url "$RK")"
  echo "ownerOf(511): $(cast call 0x8dB08eD2b460643974C64BE42087903470Df6a54 'ownerOf(uint256)(address)' 511 --rpc-url "$RK")"
  echo "ownerOf(849): $(cast call 0x8dB08eD2b460643974C64BE42087903470Df6a54 'ownerOf(uint256)(address)' 849 --rpc-url "$RK")"
  echo "staker NFT balance: $(cast call 0x8dB08eD2b460643974C64BE42087903470Df6a54 'balanceOf(address)(uint256)' 0x011C835aBF4BCeD2ECb51C466E157f467F6dB5AD --rpc-url "$RK")"
  echo "factory owner: $(cast call 0x2dBB6254231C5569B6A4313c6C1F5Fe1340b35C2 'owner()(address)' --rpc-url "$RK")"
  echo "pool 0xc81fde7f protocolFees: $(cast call 0xc81fde7f51e432ea173e87bb3d0c5670fc7b7ff9 'protocolFees()(uint128,uint128)' --rpc-url "$RK" | tr '\n' ' ')"
} | tee -a ci-out/position-checks.txt

echo "[kinetix] ci run.sh completed OK"
