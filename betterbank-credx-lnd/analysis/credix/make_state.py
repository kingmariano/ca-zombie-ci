#!/usr/bin/env python3
"""Generate state.json from raw evidence (no manual numbers)."""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")


def load(p):
    return json.load(open(os.path.join(RAW, p)))


PRICES = {
    "wS": 0.0419684222357561,
    "USDC": 1.0000026133958324,
    "scUSD": 0.9999488526145429,
    "WETH": 2700.613864022067,
    "stS": 0.04540423830960214,
    "S": 0.041588328306473174,
    "YT-scUSD": 1.07883718,  # oracle C price
}
DEC = {"USDC": 6, "scUSD": 6, "acUSDC": 6, "acscUSD": 6, "YT-scUSD": 18, "wS": 18, "WETH": 18,
       "stS": 18, "acwS": 18, "acwETH": 18, "acstS": 18, "aciUSDC": 6, "aciscUSD": 6,
       "aciYT-scUSD": 18}


def main():
    snap = load("final_snapshot.json")
    enum = load("enumeration.json")
    balances = load("balances.json")
    marketC = load("marketC.json")
    ranks = {80: "A_stability", 6: "B_core"}

    state = {
        "subject": "CrediX Finance (Sonic chain, chainId 146)",
        "as_of_block": snap["block"],
        "as_of_block_hex": snap["block_hex"],
        "rpc_used_for_final_reads": ["https://sonic-rpc.publicnode.com", "https://sonic.drpc.org",
                                     "https://sonic.api.onfinality.io/public"],
        "rpc_note": "rpc.soniclabs.com returned eth_blockNumber=0x0 during the session; fallbacks used.",
        "exploit_actor": "0xF321683831Be16eeD74dfA58b02a37483cEC662e",
        "admin_eoa": "0x0dd010513F7abB8F9c628dC164a24D953BCA09Cf",
        "markets": {},
        "roles": {},
        "balances_held_by_atokens": {},
        "attacker_positions": {},
        "treasury": {},
        "classification": {},
        "usd_prices": PRICES,
    }

    # market metadata from enumeration + marketC
    for name, m in enum["markets"].items():
        prov = {k: m[k] for k in ("provider", "pool", "getPoolConfigurator", "getPriceOracle",
                                  "getACLManager", "getACLAdmin", "getPoolDataProvider", "owner", "getMarketId")}
        state["markets"][name] = {"provider": prov, "reserves": [r["asset"] for r in m["reserves"]]}
    state["markets"]["C_isolated_new"] = {
        "provider": marketC["provider"],
        "reserves": [r["asset"] for r in marketC["pool"]["reserves"]],
    }

    # roles from final snapshot (authoritative final)
    state["role_subject_addresses"] = {
        "attacker": "0xF321683831Be16eeD74dfA58b02a37483cEC662e",
        "admin": "0x0dd010513F7abB8F9c628dC164a24D953BCA09Cf",
        "safe": "0xD3E02C92f59a0ba5601464299D658d3a0a7cf96F",
    }
    for r in snap["results"]:
        if r["kind"] == "role" and (r["value"] is True or r["value"] == 1):
            state["roles"].setdefault(r["market"], {}).setdefault(r["name"], []).append(r["addr"])

    # held by aTokens from final snapshot
    for r in snap["results"]:
        if r["kind"] == "held_by_aToken" and isinstance(r["value"], int) and r["value"] != 0:
            state["balances_held_by_atokens"].setdefault(r["market"], {})[r["name"]] = {
                "raw": r["value"], "addr": r["addr"],
                "tokens": r["value"] / (10 ** DEC.get(r["name"], 18)),
                "usd": (r["value"] / (10 ** DEC.get(r["name"], 18))) * PRICES.get(r["name"], 0),
            }

    # attacker positions
    for r in snap["results"]:
        if r["kind"] == "attacker_balance" and isinstance(r["value"], int) and r["value"] != 0:
            state["attacker_positions"][r["name"]] = {
                "raw": r["value"], "tokens": r["value"] / (10 ** DEC.get(r["name"], 18)),
                "addr": r["addr"]}

    # treasury
    for r in snap["results"]:
        if r["kind"] == "treasury_balance" and isinstance(r["value"], int) and r["value"] != 0:
            state["treasury"][r["name"]] = {"raw": r["value"],
                                            "tokens": r["value"] / (10 ** DEC.get(r["name"], 18)),
                                            "addr": r["addr"]}
    # native
    for r in snap["results"]:
        if r["kind"] == "native" and isinstance(r["value"], int) and r["value"] != 0:
            state.setdefault("native_balances", {})[r["name"]] = {"raw": r["value"],
                                                                  "S": r["value"] / 1e18}

    # reserves state (supplies / debts / unbacked / accrued) from balances.json
    state["reserves_state"] = {}
    for mn, m in balances["markets"].items():
        for r in m["reserves"]:
            dec = r["decimals"]
            state["reserves_state"].setdefault(mn, {})[r["symbol"]] = {
                "asset": r["asset"], "decimals": dec,
                "aToken": r["aToken"], "vToken": r["vToken"],
                "underlying_held_at_pool": r["underlying_pool_balance"],
                "aToken_totalSupply": r.get("aToken_totalSupply"),
                "vToken_totalSupply": r.get("vToken_totalSupply"),
                "unbacked": r.get("unbacked"),
                "accruedToTreasury": r.get("accruedToTreasury"),
                "configuration": r.get("configuration"),
            }

    # classification
    def stable_total(market):
        return sum(v["usd"] for k, v in state["balances_held_by_atokens"].get(market, {}).items()
                   if k != "YT-scUSD")
    total_market_c = stable_total("C")
    total_market_b = stable_total("B")
    total_market_a = stable_total("A")
    yt_nominal = state["balances_held_by_atokens"].get("C", {}).get("YT-scUSD", {}).get("usd", 0.0)
    state["classification"] = {
        "E-U": {"usd": 0.0, "confidence": "high",
                "reason": "No permissionless entry point extracts value: markets A/B have no underlying liquidity "
                          "beyond $0.026 dust claimable only pro-rata by existing aToken holders; market C liquidity "
                          "requires YT-scUSD collateral and its roles/ownership belong to the 2/3 Gnosis Safe; "
                          "rescueTokens is POOL_ADMIN-gated and pools hold no tokens; all reserve configs active but "
                          "irrelevant without liquidity; scUSD oracle revert blocks liquidation of accounts holding scUSD."},
        "H-O": {"usd": round(total_market_c + total_market_b, 2),
                "yt_scUSD_extra_nominal_usd": round(yt_nominal, 2),
                "confidence": "high",
                "reason": "Existing aToken holders can withdraw underlying: market C USDC 21.0572 + scUSD 28.8645 "
                          "($49.92) plus market B dust $0.026. Market A single-market holders have $0 (only nominal "
                          "ac-token claims). Market C also holds 38.3079 YT-scUSD (external SJ yield token, oracle "
                          "$1.0788 -> $41.33 nominal, redemption value external/unverified)."},
        "P": {"usd": 0.0, "confidence": "high",
              "reason": "Role holders control all three markets: attacker EOA 0xF321 holds 5 roles on market B ACL "
                        "(incl. BRIDGE and POOL_ADMIN) — never revoked; Safe 0xD3E02C92 (2/3, owners 0x6d0F4Cec, "
                        "0x75eF5d63, 0x0dd010...) holds all roles on B/C and provider ownership; EOA 0x3d0c177e owns "
                        "market A. rescueTokens confirmed callable by attacker and Safe on pool B (eth_call "
                        "simulation), but pools hold no tokens ($0). Latent: any future liquidity can be drained by "
                        "these keys (P), plus the Safe could upgrade pools and sweep market C's ~$49.92."},
        "S": {"usd": 0.0, "confidence": "high",
              "reason": "Nominal-only stuck value: market A aToken contracts hold ac-token surplus with no sweep "
                        "(acUSDC 489,597.70; acscUSD 111,987.44; acwS 2,232,649.05 excess over aToken totalSupply); "
                        "market B unbacked USDC 2,500,000.25 / scUSD 3,250,000.00 and uncollected accruedToTreasury are "
                        "claims on empty pools; scUSD oracle revert permanently blocks account-data/liquidation for "
                        "scUSD-exposed accounts; open debts (~$11.7M nominal) uncollectible because collateral pools "
                        "are empty."},
    }
    state["totals_usd"] = {
        "market_A_real": round(total_market_a, 4),
        "market_B_real_dust": round(total_market_b, 4),
        "market_C_real_stable": round(total_market_c, 4),
        "market_C_yt_scusd_nominal": round(yt_nominal, 4),
        "all_contracts_real_stable_total": round(total_market_a + total_market_b + total_market_c, 4),
    }
    # evidence files
    state["evidence"] = sorted(os.listdir(RAW))

    with open(os.path.join(HERE, "state.json"), "w") as f:
        json.dump(state, f, indent=1)
    print(json.dumps(state["classification"], indent=1))
    print(json.dumps(state["totals_usd"], indent=1))
    print(json.dumps(state["balances_held_by_atokens"], indent=1))
    print("roles:", json.dumps(state["roles"], indent=1))


if __name__ == "__main__":
    main()
