#!/usr/bin/env bash
# c-27 custom CI job: dump a machine-readable live-state snapshot for the Renegade V1 finding.
# Read-only RPC calls only (eth_call / eth_getStorageAt / eth_getBalance / eth_getCode).
# Never prints secrets. Results land in c-27/ci-out/live-state.json (uploaded as artifact).
set -uo pipefail
mkdir -p ci-out

ARB="${ARB_RPC_URL:-https://arb1.arbitrum.io/rpc}"
BASE="${BASE_RPC_URL:-https://mainnet.base.org}"

ARB_RPC="$ARB" BASE_RPC="$BASE" python3 - <<'PYEOF' > ci-out/live-state.json
import json, os, subprocess

ARB = os.environ["ARB_RPC"]
BASE = os.environ["BASE_RPC"]
PROXY = "0x30bD8eAb29181F790D7e495786d4B96d7AfDC518"
FROZEN = "0x58f876aAeeCBD5a0fca8F87e1313a9188C155bcC"
BASE_POOL = "0xb4a96068577141749CC8859f586fE29016C935dB"
IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"
OZ5_SLOT = "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00"

TOKENS = {
 "SYNTH":"0x0721b3C9f19cfeF1d622C918DcD431960f35E060","PENDLE":"0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8",
 "CRV":"0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978","DeFAI":"0x13ad3f1150db0e1e05fd32bDEeB7C110ee023de6",
 "LDO":"0x13Ad51ed4F1B7e9Dc168d8a00cB3f4dDD85EfA60","LPT":"0x289ba1701C2F088cf0faf8B3705246331cB8A839",
 "WBTC":"0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f","FTW":"0x306fD3e7b169Aa4ee19412323e1a5995B8c1a1f4",
 "RDNT":"0x3082CC23568eA640225c2467653dB90e9250AaA0","COMP":"0x354A6dA3fcde098F8389cad84b0182725c6C91dE",
 "EVA":"0x45D9831d8751B2325f3DBf48db748723726e1C8c","XAI":"0x4Cb9a7AE498CEDcBb5EAe9f25736aE7d428C9D66",
 "HOL":"0x65C101E95D7DD475c7966330fa1A803205FF92aB","ZRO":"0x6985884C4392D348587B19cb9eAAf157F13271cd",
 "ETHFI":"0x7189fb5B6504bbfF6a852B13B7B82a3c118fDc27","WETH":"0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
 "ARB":"0x912CE59144191C1204E64559FE8253a0e49E6548","GRT":"0x9623063377AD1B27544C965cCd7342f7EA7e88C7",
 "USDC":"0xaf88d065e77c8cC2239327C5EDb3A432268e5831","BKC":"0xb1425d5Bafc89A069421F69Ba57DBE2F23fC45f6",
 "AAVE":"0xba5DdD1f9d7F570dc94a51479a000E3BCE967196","SNL":"0xC5a861787f3e173F2b004d5cfA6a717f5DC5484D",
 "LINK":"0xf97f4df75117a78c1A5a0DBb814Af92458539FB4","UNI":"0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0",
 "GMX":"0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a","USDT0":"0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9",
}

def run(args, timeout=45):
    try:
        r = subprocess.run(["cast"] + args, capture_output=True, text=True, timeout=timeout)
        return (r.stdout or "").strip(), (r.stderr or "").strip(), r.returncode
    except Exception as e:
        return "", str(e), -1

def rpc_call(to, data, rpc):
    out, err, rc = run(["call", to, data, "--rpc-url", rpc])
    return {"ok": rc == 0, "output": out if rc == 0 else "", "error": err[:200] if rc != 0 else ""}

out = {"generated_utc": subprocess.run(["date","-u","+%FT%TZ"],capture_output=True,text=True).stdout.strip()}

# --- Arbitrum ---
arb = {"proxy": PROXY}
arb["block"] = run(["block-number", "--rpc-url", ARB])[0]
impl_slot = run(["storage", PROXY, IMPL_SLOT, "--rpc-url", ARB])[0]
admin_slot = run(["storage", PROXY, ADMIN_SLOT, "--rpc-url", ARB])[0]
arb["impl_slot_raw"] = impl_slot
arb["impl"] = "0x" + impl_slot[-40:] if impl_slot else None
arb["admin"] = "0x" + admin_slot[-40:] if admin_slot else None
arb["oz5_init_slot"] = run(["storage", PROXY, OZ5_SLOT, "--rpc-url", ARB])[0]
arb["eth_balance"] = run(["balance", PROXY, "--rpc-url", ARB])[0]
arb["frozen_impl_codehash"] = run(["codehash", FROZEN, "--rpc-url", ARB])[0]

# exact original entrypoints, live
initdata = "0x92413afe" + "0" * (64 * 13)  # selector + 13 words of args; fallback reverts regardless
uw = "0x803f430a" + "0" * (64 * 4)
arb["initialize_live"] = rpc_call(PROXY, initdata, ARB)
arb["updateWallet_live"] = rpc_call(PROXY, uw, ARB)

# balances of the 26 incident tokens
bals = {}
for sym, tok in TOKENS.items():
    b, e, rc = run(["call", tok, "balanceOf(address)(uint256)", PROXY, "--rpc-url", ARB])
    bals[sym] = b if rc == 0 else ("ERR:" + e[:60])
arb["token_balances"] = bals
arb["nonzero_real_tokens"] = [k for k, v in bals.items() if v not in ("0", "") and not v.startswith("ERR")]
out["arbitrum"] = arb

# --- Base ---
base = {"darkpool": BASE_POOL}
base["block"] = run(["block-number", "--rpc-url", BASE])[0]
bi = run(["storage", BASE_POOL, IMPL_SLOT, "--rpc-url", BASE])[0]
base["impl"] = "0x" + bi[-40:] if bi else None
base["oz5_init_slot"] = run(["storage", BASE_POOL, OZ5_SLOT, "--rpc-url", BASE])[0]
base["paused"] = run(["call", BASE_POOL, "paused()(bool)", "--rpc-url", BASE])[0]
base["eth_balance"] = run(["balance", BASE_POOL, "--rpc-url", BASE])[0]
base["weth_balance"] = run(["call", "0x4200000000000000000000000000000000000006", "balanceOf(address)(uint256)", BASE_POOL, "--rpc-url", BASE])[0]
base["usdc_balance"] = run(["call", "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", "balanceOf(address)(uint256)", BASE_POOL, "--rpc-url", BASE])[0]
out["base"] = base

print(json.dumps(out, indent=2))
PYEOF

echo "== live-state.json written =="
python3 - <<'EOF'
import json
d=json.load(open('ci-out/live-state.json'))
print('arb block', d['arbitrum']['block'], 'impl', d['arbitrum']['impl'])
print('arb init live revert:', d['arbitrum']['initialize_live'].get('error','')[:90])
print('arb nonzero real tokens:', d['arbitrum']['nonzero_real_tokens'])
print('base block', d['base']['block'], 'impl', d['base']['impl'], 'oz slot', d['base']['oz5_init_slot'])
EOF
