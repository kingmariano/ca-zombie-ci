#!/usr/bin/env python3
"""
C2-29 LikeCoin — CI evidence puller (read-only, public endpoints only; no secrets).

Pulls the raw state used by analysis/model.py into <outdir>/raw/:
  - likecoin-mainnet-2: latest block, staking pool/params, community pool, dist params,
    supply, module accounts + balances, validators, gov proposals, IBC channels + escrows;
  - Osmosis: all pools (LIKE market depth);
  - DefiLlama prices;
  - Base: LIKE v3 token (totalSupply, treasury multisig balance) — context only.
"""
import hashlib, json, os, subprocess, sys, time

UA = "Mozilla/5.0 (X11; Linux x86_64) research"
LIKE_LCD = "https://mainnet-node.like.co"
OSM_LCD = "https://lcd.osmosis.zone"
DL = "https://coins.llama.fi/prices/current/"
BASE_RPC = "https://mainnet.base.org"
V3_TOKEN = "0x1ee5dd1794c28f559f94d2cc642bae62dc3be5cf"
V3_TREASURY = "0x3aFaEA57802E0b8380d6461a62efbd5346752e83"


def curl(url, timeout=45, retries=4):
    for i in range(retries):
        r = subprocess.run(["curl", "-s", "--max-time", str(timeout), "-A", UA, url],
                           capture_output=True, text=True)
        try:
            return json.loads(r.stdout)
        except Exception:
            time.sleep(2)
    return None


def post(url, payload, timeout=45, retries=3):
    for i in range(retries):
        r = subprocess.run(["curl", "-s", "--max-time", str(timeout), "-X", "POST",
                            "-H", "Content-Type: application/json", "-d", json.dumps(payload), url],
                           capture_output=True, text=True)
        try:
            return json.loads(r.stdout)
        except Exception:
            time.sleep(2)
    return None


def save(d, name):
    with open(os.path.join(RAW, name), "w") as f:
        json.dump(d, f, indent=1)
    print(f"  saved {name}")


# ---- bech32 (module/escrow address derivation) ----
CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"


def _polymod(values):
    GEN = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
    chk = 1
    for v in values:
        b = chk >> 25
        chk = (chk & 0x1ffffff) << 5 ^ v
        for i in range(5):
            chk ^= GEN[i] if ((b >> i) & 1) else 0
    return chk


def _hrp_expand(h):
    return [ord(x) >> 5 for x in h] + [0] + [ord(x) & 31 for x in h]


def _convertbits(data, f, t):
    acc = bits = 0
    ret = []
    m = (1 << t) - 1
    for v in data:
        acc = (acc << f) | v
        bits += f
        while bits >= t:
            bits -= t
            ret.append((acc >> bits) & m)
    if bits:
        ret.append((acc << (t - bits)) & m)
    return ret


def bech32(hrp, data):
    pm = _polymod(_hrp_expand(hrp) + data + [0, 0, 0, 0, 0, 0]) ^ 1
    return hrp + "1" + "".join(CHARSET[d] for d in data + [(pm >> 5 * (5 - i)) & 31 for i in range(6)])


def escrow_addr(port, ch):
    pre = b"ics20-1" + b"\x00" + f"{port}/{ch}".encode()
    return bech32("like", _convertbits(hashlib.sha256(pre).digest()[:20], 8, 5))


def main(outdir):
    global RAW
    RAW = os.path.join(outdir, "raw")
    os.makedirs(RAW, exist_ok=True)
    print(f"[evidence] C2-29 likecoin -> {RAW}")

    save(curl(f"{LIKE_LCD}/cosmos/base/tendermint/v1beta1/blocks/latest"), "blocks_latest.json")
    save(curl(f"{LIKE_LCD}/cosmos/staking/v1beta1/pool"), "staking_pool.json")
    save(curl(f"{LIKE_LCD}/cosmos/staking/v1beta1/params"), "staking_params.json")
    save(curl(f"{LIKE_LCD}/cosmos/distribution/v1beta1/community_pool"), "community_pool.json")
    save(curl(f"{LIKE_LCD}/cosmos/distribution/v1beta1/params"), "dist_params.json")
    save(curl(f"{LIKE_LCD}/cosmos/bank/v1beta1/supply"), "supply.json")
    save(curl(f"{LIKE_LCD}/cosmos/mint/v1beta1/inflation"), "inflation.json")
    save(curl(f"{LIKE_LCD}/cosmos/upgrade/v1beta1/current_plan"), "upgrade_plan.json")
    save(curl(f"{LIKE_LCD}/cosmos/gov/v1/proposals?pagination.limit=200&pagination.reverse=true"), "proposals_all_v1.json")
    save(curl(f"{LIKE_LCD}/ibc/core/channel/v1/channels?pagination.limit=100"), "ibc_channels.json")
    save(curl(f"{LIKE_LCD}/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=100"), "validators_bonded.json")
    save(curl(f"{LIKE_LCD}/cosmos/staking/v1beta1/validators?pagination.limit=200"), "validators_all.json")

    ma = curl(f"{LIKE_LCD}/cosmos/auth/v1beta1/module_accounts?pagination.limit=200")
    save(ma, "module_accounts.json")
    mb = {}
    for a in (ma or {}).get("accounts", []):
        name = a["name"]
        addr = a["base_account"]["address"]
        b = curl(f"{LIKE_LCD}/cosmos/bank/v1beta1/balances/{addr}?pagination.limit=200")
        mb[name] = {"address": addr, "balances": b}
        time.sleep(0.4)
    save(mb, "module_balances.json")

    # IBC escrow balances
    chs = (json.load(open(os.path.join(RAW, "ibc_channels.json"))) if os.path.exists(os.path.join(RAW, "ibc_channels.json")) else {}).get("channels", [])
    esc = {}
    for c in chs:
        ch = c["channel_id"]
        addr = escrow_addr("transfer", ch)
        b = curl(f"{LIKE_LCD}/cosmos/bank/v1beta1/balances/{addr}?pagination.limit=100")
        esc[ch] = {"address": addr, "balances": (b or {}).get("balances", [])}
        time.sleep(0.4)
    save(esc, "escrow_balances.json")

    # Osmosis market depth
    save(curl(f"{OSM_LCD}/osmosis/poolmanager/v1beta1/all-pools"), "osmosis_all_pools.json")
    save(curl(DL + "coingecko:likecoin-2,coingecko:osmosis,coingecko:cosmos,coingecko:akash-network"), "prices.json")

    # Base v3 token context (not v2-gov controlled)
    def eth_call(to, data):
        d = post(BASE_RPC, {"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                            "params": [{"to": to, "data": data}, "latest"]})
        return (d or {}).get("result")
    v3 = {
        "token": V3_TOKEN, "treasury": V3_TREASURY,
        "total_supply_raw": eth_call(V3_TOKEN, "0x18160ddd"),
        "decimals_raw": eth_call(V3_TOKEN, "0x313ce567"),
        "treasury_balance_raw": eth_call(V3_TOKEN, "0x70a08231000000000000000000000000" + V3_TREASURY[2:]),
    }
    save(v3, "v3_base_token.json")

    print("[evidence] done")
    return 0


if __name__ == "__main__":
    outdir = sys.argv[1] if len(sys.argv) > 1 else "ci-out"
    sys.exit(main(outdir))
