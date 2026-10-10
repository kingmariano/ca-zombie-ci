#!/usr/bin/env python3
"""Build ../raw/candidates.json from the xExchange service mainnet config + manual legacy list.
Reads raw/mx_exchange_service_mainnet.json (fetched from github raw; keyless).
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "..", "raw")
cfg = json.load(open(os.path.join(RAW, "mx_exchange_service_mainnet.json")))
sc = cfg["scAddress"]
farms = cfg["farms"]

targets = []
def add(name, addr, category):
    targets.append({"name": name, "address": addr, "category": category})

# --- scAddress entries ---
add("router_v2_current", sc["routerAddress"], "active_ref")
add("MEX_pair_WEGLD_USDC_current", sc["MEX-455c57"], "active_ref")
add("pair_WEGLD_USDC_current", sc["WEGLD_USDC"], "active_ref")
add("distribution_legacy", sc["distributionAddress"], "legacy_locked_asset")
add("proxy_dex_v1_legacy", sc["proxyDexAddress"]["v1"], "legacy_proxy")
add("proxy_dex_v2_current", sc["proxyDexAddress"]["v2"], "active_ref")
add("locked_asset_factory_legacy", sc["lockedAssetAddress"], "legacy_locked_asset")
add("metabonding_staking_legacy", sc["metabondingStakingAddress"], "legacy_staking")
for i, a in enumerate(sc["simpleLockAddress"]):
    add(f"simple_lock_legacy_{i}", a, "legacy_simple_lock")
for k, v in sc["wrappingAddress"].items():
    add(f"wegld_swap_{k}", v, "active_ref")
for i, a in enumerate(sc["priceDiscovery"]):
    add(f"price_discovery_{i}", a, "legacy_pricediscovery")
add("simple_lock_energy_current", sc["simpleLockEnergy"], "active_ref")
add("fees_collector_current", sc["feesCollector"], "active_ref")
add("energy_update_current", sc["energyUpdate"], "active_ref")
add("token_unstake_current", sc["tokenUnstake"], "active_ref")
add("locked_token_wrapper_current", sc["lockedTokenWrapper"], "active_ref")
add("escrow_current", sc["escrow"], "active_ref")
add("position_creator_current", sc["positionCreator"], "active_ref")
add("locked_token_position_creator_current", sc["lockedTokenPositionCreator"], "active_ref")
add("composable_tasks_current", sc["composableTasks"], "active_ref")
add("governance_old_energy", cfg["governance"]["oldEnergy"]["cvadratic"][0], "legacy_governance")
add("governance_token_snapshot_linear", cfg["governance"]["tokenSnapshot"]["linear"][0], "legacy_governance")

# --- farms ---
for i, a in enumerate(farms["v1.2"]):
    add(f"farm_v1.2_{i}", a, "legacy_farm")
for k in ["unlockedRewards", "lockedRewards", "customRewards"]:
    for i, a in enumerate(farms["v1.3"].get(k, [])):
        add(f"farm_v1.3_{k}_{i}", a, "legacy_farm")
for k in ["lockedRewards", "deprecated"]:
    for i, a in enumerate(farms["v2"].get(k, [])):
        add(f"farm_v2_{k}_{i}", a, ("legacy_farm_deprecated" if k == "deprecated" else "active_ref"))

# --- manual additions (legacy Maiar / other known) ---
# LKMEX token owner == locked_asset_factory_legacy already added.
# ESDT system SC (not a target) skip.

json.dump({"generated_from": "mx_exchange_service mainnet.json + manual", "targets": targets},
          open(os.path.join(RAW, "candidates.json"), "w"), indent=1)
print("targets:", len(targets))
for t in targets:
    print(f"{t['category']:28s} {t['name']:42s} {t['address']}")
