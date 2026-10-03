#!/usr/bin/env python3
"""Build sphere-finance/summary.json from the CI kick enumeration artifact."""
import json, os

ROOT = "/home/heisenberg/CA/sphere-finance"
art = os.path.join(ROOT, "ci-artifacts", "result-sphere-finance", "ci-out", "kick_enum.json")
k = json.load(open(art))

# Balancer pool parameters (read live at block 94,893,xxx)
B_W, B_S, w_W, w_S, fee, p_pol = 9474.07, 766085095.9, 0.2, 0.8, 0.003, 0.10826
def out_wmatic(x):
    if x <= 0:
        return 0.0
    r = w_S / w_W
    return B_W - B_W * (B_S / (B_S + x * (1 - fee))) ** r

reward_sphere = float(k["total_kick_reward_sphere_human"])
out_w = out_wmatic(reward_sphere)
eu_usd = out_w * p_pol

summary = {
    "finding": "H-03",
    "title": "Sphere Finance (Polygon): dead OHM-fork ecosystem; only permissionless value is ylSPHERE kick incentive",
    "chains": ["polygon", "base", "optimism", "arbitrum", "bsc", "mantle"],
    "headline_extractable_usd": round(eu_usd, 2),
    "headline_confidence": "high",
    "categories": {
        "E-U": round(eu_usd, 2),
        "H-O": 31680,
        "P": 515600,
        "S": 0,
    },
    "latest_block": k["block"],
    "block_numbers": {"polygon": k["block"]},
    "targets_checked": 809,
    "live_targets": 2177,
    "closed_reasons": [
        "Polygon treasuries are 4-of-8 Gnosis Safes (EOA owners) - no permissionless exec",
        "Cross-chain Base/OP/ARB/BSC/Mantle Safes are 4-of-8 (4-of-7 Mantle) multisigs holding ~$490.6k - privileged",
        "SPHERE/Settings ProxyAdmin owned by TimelockController with zero roles - upgrades bricked",
        "BondDepo deposit capped by availableDebt=7.881 SPHERE; redeem reverts for non-bond-holders",
        "v1 token's $1.0k stranded balance is onlyOwner-rescuable",
        "Fair-launch claims require a real investment; pools otherwise empty",
        "BondTreasurySwapper/OvernightStrategy/SphereTreasury/SphereZap all role-gated",
        "Dyson strategy vaults (aPolDAI $19.3k, WMATIC $1.1k, ...) are controller/manager-gated and initialized",
    ],
    "poc": {
        "tests_passed": 19,
        "tests_total": 19,
        "ci_run_urls": [
            "https://github.com/kingmariano/ca-zombie-ci/actions/runs/37137398290",
            "https://github.com/kingmariano/ca-zombie-ci/actions/runs/37138265826",
        ],
    },
    "key_facts": [
        f"ylSPHERE kick enumeration over all {k['users']} lockers at block {k['block']}: "
        f"{reward_sphere:,.0f} SPHERE total permissionless kick reward ({k['active_users']} active lockers, "
        f"{k['bundle_path_users']} bundle-path)",
        f"Realizable via Balancer V2 WMATIC/SPHERE pool: {out_w:,.2f} WMATIC = ${eu_usd:,.2f}",
        "DefiLlama $6.20M is frozen 2023-08-23 and carried flat to 2025-11-20; live Polygon treasuries ~$24.2k priced",
        "ylSPHERE locker holds 2,233,132,276.9 SPHERE locked + 143,520 WMATIC/$16.4k unclaimed rewards (holder-only)",
        "Investment Treasury Safe holds 166,981 POL + $4.5k tokens (~$22.6k)",
        "Base Safe 1 (4-of-8, nonce 1471, actively operated) holds ~$473.5k; all cross-chain Safes ~$490.6k",
        "SPHERE token impl upgraded 7 times; current impl is a plain ERC20 with no mint/rebase",
        "Fork PoC: kick on 0x42dcc796... paid 25,632.74 SPHERE; BondDepo 0.04 USDC -> 7.55 SPHERE (loss); all gated paths revert",
    ],
    "caveats": [
        "kickExpiredLocks is a race: victims can self-process expired locks at any time",
        "SPHERE liquidity is thin (~$1.0k WMATIC in the only pool); USD value is realizable-proceeds, not book value",
        "Cross-chain Safes were checked for configuration/balances only, not exhaustively audited",
        "No key-compromise scenarios considered (deployer EOA / Safe signers assumed uncompromised)",
    ],
    "one_liner": (
        f"external unprivileged attacker can extract only ~${eu_usd:,.2f} of SPHERE via the permissionless "
        f"ylSPHERE kickExpiredLocks incentive; the ~$24.2k Polygon treasuries, ~$490.6k cross-chain Safes, "
        f"$1.0k stranded in the v1 token and all bond/fair-launch pools are 4-of-8 multisig or owner-gated"
    ),
}
json.dump(summary, open(os.path.join(ROOT, "summary.json"), "w"), indent=1)
print(json.dumps(summary, indent=1))
