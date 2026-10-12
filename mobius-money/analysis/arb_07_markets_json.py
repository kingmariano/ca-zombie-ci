#!/usr/bin/env python3
"""Arb final: assemble analysis/markets.json from cached data + final fresh reads.
"""
import json, urllib.request, os, time

RPC = "https://forno.celo.org"
HERE = os.path.dirname(os.path.abspath(__file__))

POOLS = [
    ("0x9f4adbd0af281c69a582eb2e6fa2a594d4204cae", "atUST/USDm"),
    ("0x02db089fb09fda92e05e92afcd41d9aafe9c7c7c", "pUSD(v1)/USDm"),
    ("0xa2f0e57d4ceacf025e81c76f28b9ad6e9fbe8735", "pUSD(v2)/USDm"),
    ("0x382ed834c6b7dbd10e4798b08889eaed1455e820", "pEUR(v1)/EURm"),
    ("0x23c95678862a229fac088bd9705622d78130bc3e", "pEUR(v2)/EURm"),
    ("0x413ffcc28e6cdde7e93625ef4742810fe9738578", "pCELO(v1)/CELO"),
    ("0xfc9e2c63370d8deb3521922a7b2b60f4cff7e75a", "pCELO(v2)/CELO"),
    ("0xcce0d62ce14fb3e4363eb92db37ff3630836c252", "USDC(OpticsV2)/USDm"),
    ("0xa5037661989789d0310ac2b796fa78f1b01f195d", "USDCet(OpticsV1)/USDm"),
    ("0x0986b42f5f9c42feeef66fc23eba9ea1164c916d", "aaUSDC/Allbridge)/USDm"),
    ("0xaefc4e8cf655a182e8346b24c8abce45616ee0d2", "d629BTC/WBTC_baab"),
    ("0x19260b9b573569ddb105780176547875fe9feda3", "d629BTC/WBTC_be50"),
]

SEL_TOKEN = "0x82b86600"
SEL_BAL = "0x91ceb3eb"
SEL_PAUSED = "0x5c975abb"


def rpc_batch(calls, tries=6, batch=50):
    out = []
    for i in range(0, len(calls), batch):
        chunk = calls[i:i + batch]
        body = json.dumps([{"jsonrpc": "2.0", "id": j, "method": m, "params": p}
                           for j, (m, p) in enumerate(chunk)]).encode()
        last = None
        for t in range(tries):
            try:
                req = urllib.request.Request(RPC, data=body,
                                             headers={"Content-Type": "application/json",
                                                      "User-Agent": "Mozilla/5.0 (research; read-only)"})
                with urllib.request.urlopen(req, timeout=90) as r:
                    d = json.loads(r.read().decode())
                if isinstance(d, dict):
                    raise RuntimeError(str(d)[:200])
                by_id = {it["id"]: it for it in d}
                out.extend((by_id.get(j) or {}).get("result") for j in range(len(chunk)))
                break
            except Exception as e:
                last = e
                time.sleep(1 + t)
        else:
            out.extend([None] * len(chunk))
    return out


def main():
    quotes = json.load(open(os.path.join(HERE, "_quotes.json")))
    profit = json.load(open(os.path.join(HERE, "_profit.json")))
    markets = json.load(open(os.path.join(HERE, "_markets_raw.json")))
    ext = json.load(open(os.path.join(HERE, "_externals.json")))

    # fresh snapshot
    calls, keys = [], []
    for p, _ in POOLS:
        for i in (0, 1):
            calls.append(("eth_call", [{"to": p, "data": SEL_TOKEN + hex(i)[2:].rjust(64, "0")}, "latest"]))
            keys.append((p, i, "token"))
            calls.append(("eth_call", [{"to": p, "data": SEL_BAL + hex(i)[2:].rjust(64, "0")}, "latest"]))
            keys.append((p, i, "bal"))
        calls.append(("eth_call", [{"to": p, "data": SEL_PAUSED}, "latest"]))
        keys.append((p, None, "paused"))
    res = rpc_batch(calls)
    snap = {}
    for (p, i, k), r in zip(keys, res):
        e = snap.setdefault(p, {"tokens": [None, None], "balances": [None, None], "paused": None})
        if k == "paused":
            e["paused"] = bool(r and int(r[2:66], 16))
        else:
            v = ("0x" + r[2:][-40:].lower()) if k == "token" else (str(int(r[2:66], 16)) if r and r != "0x" else None)
            e[{"token": "tokens", "bal": "balances"}[k]][i] = v
    blk = int(rpc_batch([("eth_blockNumber", [])])[0], 16)

    # metadata for tokens
    dec = {}
    for t, m in quotes["tokens"].items():
        dec[t] = m
    for t, m in markets["unknown_tokens"].items():
        dec.setdefault(t, m)
    for t, rec in (ext.get("blockscout") or {}).items():
        tok = rec.get("token") or {}
        if t not in dec and tok.get("symbol"):
            dec[t] = tok

    # per-pool static evidence (identities, market pairs) -----------------
    EVID = {
        "0x9f4adbd0af281c69a582eb2e6fa2a594d4204cae": {
            "junk": {"addr": "0xed193c4e69f591e42398ef54dea65aa1bb02835c", "name": "atUST (Wormhole-wrapped UST, WrappedToken)", "idx": 1},
            "market_pairs": [{"pair": "0x752875e07e20bf03908d9f5d5c5e7dc330c801a1", "venue": "ubeswap_v2",
                              "kind": "USDm/atUST", "spot_hint": "reserve1/reserve0 = 333.15 atUST per USDm (spot 0.003002 USDm/atUST)",
                              "last_trade": "2025-11-18 (block 51593124)"}],
            "route": "buy atUST with USDm from Ubeswap pair -> approve+swap into Mobius pool for USDm",
            "circular": False,
            "notes": "Only external market for atUST; pair untouched since Nov 2025 flash-loan arb tx. Pool marginal for atUST is ~4.9x the pair spot."
        },
        "0x02db089fb09fda92e05e92afcd41d9aafe9c7c7c": {
            "junk": {"addr": "0xb4aa2986622249b1f45eb93f28cfca2b2606d809", "name": "pUSD (Poof v1, PoofMintableLendable zk shielded)", "idx": 1},
            "market_pairs": [{"pair": "0xec3741fb21352af9251f5232b929a0c3150e577c", "venue": "ubeswap_v2",
                              "kind": "USDm/pUSD", "last_trade": "2025-08-12"}],
            "route": "buy pUSD with USDm from Ubeswap pair -> swap into Mobius pool for USDm",
            "circular": False,
            "notes": "Pool marginal 0.976 USDm/pUSD vs pair spot 0.562; drained market caps size."
        },
        "0xa2f0e57d4ceacf025e81c76f28b9ad6e9fbe8735": {
            "junk": {"addr": "0xeadf4a7168a82d30ba0619e64d5bcf5b30b45226", "name": "pUSD (Poof v2, PToken)", "idx": 1},
            "market_pairs": [{"pair": "0x79769896a42187b07056379d0a476d07ea7926ad", "venue": "ubeswap_v2", "kind": "USDm/pUSD(v2) - 2 wei USDm, DEAD"},
                             {"pair": "0x7aef68d7eb24f7ae09baf4d10e647b9ffebc6040", "venue": "ubeswap_v2", "kind": "MOBI/pUSD(v2) - pUSD side 0.0504, expensive to buy"}],
            "route": "buy pUSD(v2) with MOBI, MOBI with USDm -> swap into pool (result: negative)",
            "circular": False,
            "notes": "Pool pays 0.000158 USDm per pUSD at margin (pUSD extremely abundant). No profitable route. NOTE: privileged PToken supply manager 0x14874877865e minted 10k pUSD(v2) and swapped into this pool then burned pool-held pUSD in June 2026 - admin capability, not unprivileged."
        },
        "0x382ed834c6b7dbd10e4798b08889eaed1455e820": {
            "junk": {"addr": "0x56072d4832642db29225da12d6fd1290e4744682", "name": "pEUR (Poof v1 zk)", "idx": 1},
            "market_pairs": [{"pair": "0x9b4ebb6f5c879faf4599a5ce21d338902b2b55bb", "venue": "ubeswap_v2", "kind": "EURm/pEUR(v1) - reserves 1000/1003 wei, DEAD"}],
            "route": "none",
            "circular": False,
            "notes": "No usable market. Pool marginal 0.0372 EURm/pEUR radically above the dead market price."
        },
        "0x23c95678862a229fac088bd9705622d78130bc3e": {
            "junk": {"addr": "0xd8761dd6c7cb54febd33add699f5e4440b62e01b", "name": "pEUR (Poof v2, PToken)", "idx": 1},
            "market_pairs": [],
            "route": "none",
            "circular": False,
            "notes": "NO market anywhere (Ubeswap 882 pairs, Sushi 257 pairs, Uniswap V3 factory getPool all fee tiers)."
        },
        "0x413ffcc28e6cdde7e93625ef4742810fe9738578": {
            "junk": {"addr": "0xe74abf23e1fdf7acbec2f3a30a772ef77f1601e1", "name": "pCELO (Poof v1 zk)", "idx": 1},
            "market_pairs": [{"pair": "0x993b0d1a2c7eff889f7e4ddc9a03b5085a2d1f27", "venue": "ubeswap_v2", "kind": "POOF/pCELO(v1)"},
                             {"pair": "0x3ea1e47f5126f6a6077a92965b9d1b1aa241893e", "venue": "ubeswap_v2", "kind": "CELO/pCELO(v1) - tiny"},
                             {"pair": "0x0931738d2c2998173058b635524e437172a6a96c", "venue": "ubeswap_v2", "kind": "POOF/CELO (for POOF acquisition)"}],
            "route": "buy POOF with CELO -> buy pCELO(v1) with POOF -> swap into Mobius pool for CELO",
            "circular": False,
            "notes": "Best route nets ~$0.0043 before gas (gas ~$0.006-0.008) => net negative."
        },
        "0xfc9e2c63370d8deb3521922a7b2b60f4cff7e75a": {
            "junk": {"addr": "0x301a61d01a63c8d670c2b8a43f37d12ef181f997", "name": "pCELO (Poof v2, PToken)", "idx": 1},
            "market_pairs": [{"pair": "0xbdfc22680b72f0b127d70988feb4b1a68c0b99eb", "venue": "ubeswap_v2", "kind": "POOF/pCELO(v2)"},
                             {"pair": "0x0931738d2c2998173058b635524e437172a6a96c", "venue": "ubeswap_v2", "kind": "POOF/CELO"}],
            "route": "buy POOF with CELO -> buy pCELO(v2) with POOF -> swap into Mobius pool for CELO",
            "circular": False,
            "notes": "Best route nets ~$0.00015 before gas. Bot 0xf9e41C21... actively harvests this exact route (last 2026-09-29)."
        },
        "0xcce0d62ce14fb3e4363eb92db37ff3630836c252": {
            "junk": {"addr": "0x1bfc26ce035c368503fae319cc2596716428ca44", "name": "USDC (Optics v2, UpgradeBeaconProxy, name 'USD Coin (PoS)')", "idx": 1},
            "market_pairs": [{"pair": "0xff4aa942966297cc5dc3a5439af68fd9bd1fcc1f", "venue": "ubeswap_v2", "kind": "USDCold/CELO (0.158 USDC / 1.427 CELO)"},
                             {"pair": "0x04e34632f7a500f8caaec792def13d4612bfbdf9", "venue": "sushiswap_v2", "kind": "USDCold/USDm - 171 wei, DEAD"},
                             {"pair": "0xd943d18cadb584163acab92a7be6d9bf74a2e6a0", "venue": "uniswap_v3", "kind": "USDCold/CELO 1% fee (unused depth unknown)"}],
            "route": "buy CELO with USDm -> buy USDCold with CELO -> swap into Mobius pool for USDm (result: negative)",
            "circular": False,
            "notes": "Pool pays 1.0366 USDm per USDCold (premium) but market acquisition averages above it at any size >~0.03 USDC. Optimum gross -0.0007 USD."
        },
        "0xa5037661989789d0310ac2b796fa78f1b01f195d": {
            "junk": {"addr": "0x2a3684e9dc20b857375ea04235f2f7edbe818fa7", "name": "USDCet (Optics v1, UpgradeBeaconProxy)", "idx": 1},
            "market_pairs": [{"pair": "0xcd1d049abdff6d1781d419ca7a897c389f2440e5", "venue": "ubeswap_v2", "kind": "USDCet/USDm"},
                             {"pair": "0x684da04524b1a6baf99566d722de94ce989ea722", "venue": "ubeswap_v2", "kind": "USDCet/CELO (used by arb bots with CELO/USDm)"},
                             {"pair": "0xf683db6e60b3f5acf5278984d94a12da6777a0df", "venue": "ubeswap_v2", "kind": "USDCet/EURm"}],
            "route": "buy USDCet with USDm -> swap into pool (result negative); bots instead buy via CELO triangle for ~0.2% margin",
            "circular": False,
            "notes": "Pool marginal 0.9773 vs Ubeswap USDm spot 0.989 => no direct arb. Arbitrage bots actively feed USDCet into this pool (pool +5.83 USDCet within 20 min on 2026-10-12)."
        },
        "0x0986b42f5f9c42feeef66fc23eba9ea1164c916d": {
            "junk": {"addr": "0xb70e0a782b058bfdb0d109a3599bec1f19328e36", "name": "aaUSDC (Avalanche USDC.e via Allbridge, eip1167 proxy)", "idx": 1},
            "market_pairs": [],
            "route": "none",
            "circular": False,
            "notes": "No DEX market anywhere. Allbridge protocol paused 2026 after flash-loan attack; return leg for aaUSDC is the bridge itself (cost>=1.00 vs pool pays 0.9919 => no arb even if bridge reopened)."
        },
        "0xaefc4e8cf655a182e8346b24c8abce45616ee0d2": {
            "junk": {"addr": "0xbaab46e28388d2779e6e31fd00cf0e5ad95e327b", "name": "WBTC (Optics v2, UpgradeBeaconProxy)", "idx": 1},
            "market_pairs": [{"pair": "0x0448e99ab5f8230713a9f5d7e64ec2ab6e5952a3", "venue": "ubeswap_v2", "kind": "mcUSD/WBTC_baab"},
                             {"pair": "0x3b41526e92dd519f93addd44172402cff17089b4", "venue": "ubeswap_v2", "kind": "WBTC_baab/d629BTC"},
                             {"pair": "0xda2123291ef077e10d08916e5482dedcf5d96846", "venue": "uniswap_v3", "kind": "WBTC_baab/USDm 0.3%"},
                             {"pair": "0xce1508dc992f13cdc2f77df0a5f031e80504eac2", "venue": "uniswap_v3", "kind": "WBTC_baab/USDm 1%"}],
            "route": "A) buy baab with mcUSD -> pool -> sell d629 for mCUSD; B) buy d629 with mCUSD -> pool -> sell baab for mcUSD",
            "circular": "partially - pools are part of the live d629/baab price-discovery loop",
            "notes": "Bots 0x3f5305C955.../0xae6D7D47... cycle both directions (Oct 2026). Best gross A: -0.002, B: +0.002 USD; gas ~0.008 => net negative."
        },
        "0x19260b9b573569ddb105780176547875fe9feda3": {
            "junk": {"addr": "0xbe50a3013a1c94768a1abb78c3cb79ab28fc1ace", "name": "WBTC (Optics v1, UpgradeBeaconProxy)", "idx": 1},
            "market_pairs": [{"pair": "0x724ff4aafa4fd2c44a1726707c2f1b3d1650eab9", "venue": "ubeswap_v2", "kind": "mcUSD/WBTC_be50"},
                             {"pair": "0x9f3574dae1aeffd65ef739e9f50e2b9dd8831056", "venue": "ubeswap_v2", "kind": "CELO/WBTC_be50"},
                             {"pair": "0x8600d5bc0459d9965a0f591c65bf773288585d47", "venue": "sushiswap_v2", "kind": "CELO/WBTC_be50 - thin"}],
            "route": "A) buy be50 -> pool -> sell d629; B) buy d629 -> pool -> sell be50",
            "circular": "partially",
            "notes": "Bots 0xD87D4843... arb be50 between its two pairs (2026-10-12). Best gross A: -0.00025, B: -0.0387 USD => net negative."
        },
    }

    out = {
        "meta": {
            "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "chain_id": 42220, "network": "celo",
            "state_block": blk,
            "rpcs_used": [RPC, "https://celo-rpc.publicnode.com"],
            "gas": {"base_fee_gwei": 200.0,
                    "observed_gas_price_gwei": 202.5,
                    "observed_mobius_swap_gas": 149203,
                    "celo_usd": 0.09416068042565741,
                    "est_full_arb_gas_usd": 0.0062,
                    "est_full_arb_gas_note": "~295k-400k gas (1-2 pair swaps + 1 approve + 1 pool swap) at 202.5 gwei ~= $0.006-0.008"},
            "prices_usd": {k: v.get("price") for k, v in ext["llama_prices"].items()},
            "univ2_fee": "0.30%",
            "valuation_notes": "USDm ~ $1.0001; CELO $0.09416; mcUSD ~ $1.0001; mCUSD taken as $1.00 (conservative); EURm $1.1152. Pool-side quotes are exact calculateSwap() values; market-side costs are exact UniV2 getAmountIn chains on current reserves.",
        },
        "pools": {},
        "totals": {},
        "routes_profit": profit["routes"],
        "marginal_eps": profit["marginal_eps"],
    }

    route_map = {
        "0x9f4adbd0af281c69a582eb2e6fa2a594d4204cae": ["P1"],
        "0x02db089fb09fda92e05e92afcd41d9aafe9c7c7c": ["P2"],
        "0xa2f0e57d4ceacf025e81c76f28b9ad6e9fbe8735": ["P3"],
        "0x413ffcc28e6cdde7e93625ef4742810fe9738578": ["P6A", "P6B"],
        "0xfc9e2c63370d8deb3521922a7b2b60f4cff7e75a": ["P7"],
        "0xcce0d62ce14fb3e4363eb92db37ff3630836c252": ["P8"],
        "0xa5037661989789d0310ac2b796fa78f1b01f195d": ["P9"],
        "0xaefc4e8cf655a182e8346b24c8abce45616ee0d2": ["P11A", "P11B"],
        "0x19260b9b573569ddb105780176547875fe9feda3": ["P12A", "P12B"],
    }
    gas_usd = 0.0062
    positive_total = 0.0
    positive_after_gas = 0.0
    for p, label in POOLS:
        s = snap[p]
        e = EVID[p]
        entry = {
            "label": label,
            "paused": s["paused"],
            "tokens": [
                {"index": 0, "address": s["tokens"][0], "symbol": (dec.get(s["tokens"][0]) or {}).get("symbol"),
                 "decimals": (dec.get(s["tokens"][0]) or {}).get("decimals"), "balance_raw": s["balances"][0]},
                {"index": 1, "address": s["tokens"][1], "symbol": (dec.get(s["tokens"][1]) or {}).get("symbol"),
                 "decimals": (dec.get(s["tokens"][1]) or {}).get("decimals"), "balance_raw": s["balances"][1]},
            ],
            "pool_quotes": quotes["quotes"].get(p, {}),
            "junk_token": e["junk"],
            "market_pairs": e["market_pairs"],
            "route": e["route"], "circular": e["circular"], "notes": e["notes"],
            "arb_routes": {},
        }
        best_gross = None
        for rk in route_map.get(p, []):
            r = profit["routes"].get(rk)
            if r:
                entry["arb_routes"][rk] = {
                    "label": r["label"], "best_dx_raw": str(r["best_dx"]), "pool_out_raw": str(r["pool_out"]),
                    "cost_usd": r["cost_usd"], "revenue_usd": r["revenue_usd"], "gross_profit_usd": r["profit_usd"],
                    "net_after_gas_usd": r["profit_usd"] - gas_usd,
                }
                if best_gross is None or r["profit_usd"] > best_gross:
                    best_gross = r["profit_usd"]
        entry["best_gross_profit_usd"] = best_gross
        entry["best_net_after_gas_usd"] = (best_gross - gas_usd) if best_gross is not None else None
        if best_gross:
            positive_total += max(best_gross, 0)
            positive_after_gas += max(best_gross - gas_usd, 0)
        out["pools"][p] = entry

    out["totals"] = {
        "sum_of_positive_best_gross_usd": round(positive_total, 6),
        "sum_of_positive_best_net_after_gas_usd": round(positive_after_gas, 6),
        "headline": "Only pool 0x9f4adbd0 (atUST) is net-positive after gas: ~+$0.077 one-shot. All other pools are net-negative or exactly zero after gas.",
        "biggest_pool_side_prize_not_reachable": {
            "pool2_pUSD_USDm": "330.4 USDm protected by pUSD v1 zk-gated shielded token with only a 0.078-USDm-deep external market",
            "pool8_USDCold": "3741 USDm protected by USDCold market with only 0.158 USDC depth",
            "pool9_USDCet": "24,427 USDm protected by a market that is fair-priced and actively arbed by bots",
            "pool10_aaUSDC": "280 USDm unreachable - no market at all for aaUSDC",
        },
    }

    with open(os.path.join(HERE, "markets.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("wrote markets.json; block", blk)
    for p, entry in out["pools"].items():
        print(p, entry["label"], "best_gross=", entry["best_gross_profit_usd"],
              "net=", entry["best_net_after_gas_usd"])


if __name__ == "__main__":
    main()
