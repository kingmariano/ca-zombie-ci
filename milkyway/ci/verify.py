#!/usr/bin/env python3
"""
H-27 MilkyWay live-state verification (READ-ONLY).

Runs a fixed set of on-chain checks against public endpoints and writes:
  ci-out/evidence.json  - raw captures + computed numbers
  ci-out/checks.log     - PASS/FAIL per check

No transactions, no secrets. Designed to run on GitHub Actions (ubuntu-latest).
"""
import base64
import json
import os
import sys
import time
import urllib.parse
import urllib.request

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ci-out")
OUT_DIR = os.path.abspath(OUT_DIR)
os.makedirs(OUT_DIR, exist_ok=True)

OSMOSIS_LCDS = [
    "https://osmosis-rest.publicnode.com",
    "https://osmosis-api.polkachu.com",
    "https://lcd-osmosis.keplr.app",
]
CELESTIA_LCD = "https://rest.cosmos.directory/celestia"

CONTRACT = "osmo1f5vfcph2dvfeqcqkhetwv75fda69z7e5c2dldm3kvgj23crkv6wqcn47a0"
MILKTIA_DENOM = "factory/osmo1f5vfcph2dvfeqcqkhetwv75fda69z7e5c2dldm3kvgj23crkv6wqcn47a0/umilkTIA"
TIA_OSMOSIS = "ibc/D79E7D83AB399BFFF93433E54FAA480C191248FC556924A2A8351AE2638B3877"
STAKER_CELESTIA = "celestia1vxzram63f7mvseufc83fs0gnt5383lvrle3qpt"
REWARD_CELESTIA = "celestia1vr00egrck8a0dax68fgglrm3n8v4yz9wjj7cj2"
CL_POOLS = ["1335", "1475", "3365"]  # milkTIA/TIA concentrated liquidity pools

results = {"generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "checks": [], "raw": {}}
checks = []


def http_get(url, timeout=45):
    req = urllib.request.Request(url, headers={"User-Agent": "zombie-hunt-h27/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.status, r.read()


def get_json(url, timeout=45):
    st, body = http_get(url, timeout)
    return st, json.loads(body)


def smart(msg, base=None):
    q = base64.b64encode(json.dumps(msg).encode()).decode()
    last = None
    for b in ([base] if base else OSMOSIS_LCDS):
        try:
            st, d = get_json(f"{b}/cosmwasm/wasm/v1/contract/{CONTRACT}/smart/{q}")
            if st == 200 and "data" in d:
                return d["data"]
        except Exception as e:  # noqa
            last = e
    raise RuntimeError(f"smart query failed: {msg} ({last})")


def record(name, ok, detail):
    checks.append({"check": name, "pass": bool(ok), "detail": detail})
    print(f"[{'PASS' if ok else 'FAIL'}] {name}: {detail}")


def main():
    # ---- 1. contract config / state -------------------------------------
    cfg = smart({"config": {}})
    results["raw"]["config"] = cfg
    record("contract.stopped == true", cfg["stopped"] is True, f"stopped={cfg['stopped']}")
    record("contract.admin", cfg is not None, f"admin={smart({'admin':{}})['admin']}")
    record("liquid_stake_denom", cfg["liquid_stake_token_denom"] == MILKTIA_DENOM, cfg["liquid_stake_token_denom"])
    record("ibc_token_denom == TIA", cfg["protocol_chain_config"]["ibc_token_denom"] == TIA_OSMOSIS, cfg["protocol_chain_config"]["ibc_token_denom"])
    staker = cfg["native_chain_config"]["staker_address"]
    record("staker_address matches expected", staker == STAKER_CELESTIA, staker)

    state = smart({"state": {}})
    results["raw"]["state"] = state
    record("total_liquid_stake_token > 0", int(state["total_liquid_stake_token"]) > 0, state["total_liquid_stake_token"])

    # ---- 2. contract bank balance ---------------------------------------
    st, bal = get_json(f"{OSMOSIS_LCDS[0]}/cosmos/bank/v1beta1/balances/{CONTRACT}?pagination.limit=100")
    balances = {b["denom"]: int(b["amount"]) for b in bal["balances"]}
    results["raw"]["contract_balances"] = bal["balances"]
    tia_held = balances.get(TIA_OSMOSIS, 0)
    record("contract holds TIA", tia_held > 0, f"{tia_held} utia = {tia_held/1e6} TIA")

    st, sup = get_json(f"{OSMOSIS_LCDS[0]}/cosmos/bank/v1beta1/supply/by_denom?denom={urllib.parse.quote(MILKTIA_DENOM, safe='')}")
    milk_supply = int(sup["amount"]["amount"])
    results["raw"]["milkTIA_supply"] = milk_supply
    record("milkTIA supply > 0", milk_supply > 0, f"{milk_supply/1e6} milkTIA")

    # ---- 3. batches ------------------------------------------------------
    batches = []
    start = None
    while True:
        msg = {"batches": {"limit": 30}}
        if start is not None:
            msg["batches"]["start_after"] = start
        page = smart(msg)["batches"]
        if not page:
            break
        batches.extend(page)
        start = page[-1]["id"]
        if len(batches) > 400:
            break
    results["raw"]["batches_count"] = len(batches)
    statuses = {}
    for b in batches:
        statuses[b["status"]] = statuses.get(b["status"], 0) + 1
    results["raw"]["batch_statuses"] = statuses
    received = sum(int(b["received_native_unstaked"]) for b in batches if b["status"] == "received")
    expected = sum(int(b["expected_native_unstaked"]) for b in batches)
    results["raw"]["sum_received_utia"] = received
    results["raw"]["sum_expected_utia"] = expected
    record("232 received / 1 submitted / 1 pending", statuses.get("received") == 232 and statuses.get("submitted") == 1 and statuses.get("pending") == 1, json.dumps(statuses))

    # ---- 4. outstanding unstake requests + solvency ----------------------
    reqs = None
    for b in OSMOSIS_LCDS:
        try:
            q = base64.b64encode(json.dumps({"all_unstake_requests": {"limit": 6000}}).encode()).decode()
            st, d = get_json(f"{b}/cosmwasm/wasm/v1/contract/{CONTRACT}/smart/{q}", timeout=120)
            if st == 200 and isinstance(d.get("data"), list):
                reqs = d["data"]
                break
        except Exception:
            continue
    if reqs is None:
        record("outstanding requests fetched", False, "all LCDs failed")
        reqs = []
    else:
        record("outstanding requests fetched", True, f"count={len(reqs)}")

    bmap = {b["id"]: b for b in batches}
    claimable = 0
    in_flight_batches = 0
    for r in reqs:
        b = bmap.get(r["batch_id"])
        if b is None or b["status"] != "received":
            in_flight_batches += 1
            continue
        claimable += int(b["received_native_unstaked"]) * int(r["amount"]) // int(b["batch_total_liquid_stake"])
    results["raw"]["outstanding_requests_count"] = len(reqs)
    results["raw"]["claimable_utia"] = claimable
    results["raw"]["requests_in_non_received_batches"] = in_flight_batches
    surplus = tia_held - claimable
    record("contract solvent (claims <= balance)", claimable <= tia_held, f"claimable={claimable/1e6} TIA, held={tia_held/1e6} TIA, surplus={surplus/1e6} TIA")

    # ---- 5. no pending IBC packets --------------------------------------
    try:
        ibcq = smart({"ibc_queue": {"limit": 50}})["ibc_queue"]
        results["raw"]["ibc_queue"] = ibcq
        record("no inflight IBC packets", len(ibcq) == 0, f"count={len(ibcq)}")
    except Exception as e:
        record("no inflight IBC packets", False, str(e))

    # ---- 6. Celestia staker account empty -------------------------------
    try:
        st, d = get_json(f"{CELESTIA_LCD}/cosmos/bank/v1beta1/balances/{STAKER_CELESTIA}?pagination.limit=20")
        stak_bal = {b["denom"]: int(b["amount"]) for b in d["balances"]}
        st, d2 = get_json(f"{CELESTIA_LCD}/cosmos/staking/v1beta1/delegations/{STAKER_CELESTIA}?pagination.limit=20")
        delegs = len(d2["delegation_responses"])
        results["raw"]["celestia_staker_balances"] = d["balances"]
        results["raw"]["celestia_staker_delegations"] = delegs
        record("Celestia staker has no delegations", delegs == 0, f"delegations={delegs}, balance={stak_bal.get('utia',0)} utia")
    except Exception as e:
        record("Celestia staker has no delegations", False, str(e))

    # ---- 7. CL pool market liquidity (context) ---------------------------
    cl = {}
    for pid in CL_POOLS:
        try:
            addr = {
                "1335": "osmo1m263qln83ultreafq7get8690ymukh0sju8jt7w3ae8akvt6ve6sq9ua5w",
                "1475": "osmo10jfc84rq0ppv9yyw4lqgcjuurrg9j5n043r8cwprpt4l0ta97qhq5qag50",
                "3365": "osmo17n48pe659u2nh6kwr4hx9q4wne220h8vrvpdzcc2k3x8whwkfv9qf4k3q9",
            }[pid]
            st, d = get_json(f"{OSMOSIS_LCDS[0]}/cosmos/bank/v1beta1/balances/{addr}?pagination.limit=20")
            cl[pid] = d["balances"]
        except Exception as e:
            cl[pid] = {"error": str(e)}
    results["raw"]["cl_pools"] = cl
    record("CL pool market liquidity captured", all(isinstance(v, list) for v in cl.values()), json.dumps({k: len(v) for k, v in cl.items()}))

    # ---- 8. MilkyWay L1 endpoint liveness --------------------------------
    l1_probes = {}
    for url in [
        "https://rpc.mainnet.milkyway.zone/status",
        "https://lcd.mainnet.milkyway.zone/cosmos/base/tendermint/v1beta1/blocks/latest",
        "https://milkyway-api.polkachu.com/cosmos/base/tendermint/v1beta1/blocks/latest",
        "https://milkyway-rpc.polkachu.com/status",
    ]:
        try:
            st, body = http_get(url, timeout=15)
            head = body[:400].decode(errors="replace")
            l1_probes[url] = {"http": st, "body": head}
        except Exception as e:
            l1_probes[url] = {"http": None, "error": str(e)}
    results["raw"]["l1_probes"] = l1_probes
    official_dead = all(l1_probes[u].get("http") in (None, 404, 502, 503, 504) for u in list(l1_probes)[:2])
    polkachu_other = "allora" in json.dumps(l1_probes.get("https://milkyway-api.polkachu.com/cosmos/base/tendermint/v1beta1/blocks/latest", {}))
    record("official MilkyWay L1 endpoints dead", official_dead, json.dumps({k: v.get("http") for k, v in l1_probes.items()}))
    record("polkachu 'milkyway' subdomain serves another chain", polkachu_other, "allora-mainnet-1 observed" if polkachu_other else "not observed")

    # ---- write outputs ---------------------------------------------------
    passed = sum(1 for c in checks if c["pass"])
    results["checks"] = checks
    results["summary"] = {"passed": passed, "total": len(checks)}
    with open(os.path.join(OUT_DIR, "evidence.json"), "w") as f:
        json.dump(results, f, indent=2)
    with open(os.path.join(OUT_DIR, "checks.log"), "w") as f:
        f.write(f"H-27 MilkyWay verification - {results['generated_at']}\n")
        for c in checks:
            f.write(f"[{'PASS' if c['pass'] else 'FAIL'}] {c['check']}: {c['detail']}\n")
        f.write(f"\n{passed}/{len(checks)} checks passed\n")
    print(f"\n{passed}/{len(checks)} checks passed")
    # Always exit 0 after writing evidence; FAILs are data, not job failures.
    return 0


if __name__ == "__main__":
    sys.exit(main())
