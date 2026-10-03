#!/usr/bin/env python3
"""Exhaustive check: every Safe seen in ActionExecuted logs + event sets -> isModuleEnabled now.
Also records whether each currently-enabled Safe has module grants (delegate permissions)."""
import json, os, subprocess, sys, time

ANALYSIS = "/home/heisenberg/CA/c-26/analysis"
RPC = os.environ.get("BLOCKPI_RPC_URL") or os.environ["RPC_URL"]
MODULE = "0x1f1d37a3Bf840e35c6a860c7C2dA71Fe555123ca"
PM = "0x03B8B1bA6B02b8A566cB757DFa627f7198c44cB7"


def num(v):
    return int(v, 16) if isinstance(v, str) and v.startswith("0x") else int(v)


def topic_addr(t):
    return "0x" + t[-40:]


def cast_call(args):
    for attempt in range(3):
        p = subprocess.run(["cast", "call"] + args + ["--rpc-url", RPC],
                           capture_output=True, text=True, timeout=45)
        if p.returncode == 0:
            return p.stdout.strip()
        time.sleep(1 + attempt)
    return "ERR"


act = json.load(open(os.path.join(ANALYSIS, "logs", "module_actions.json")))
state = json.load(open(os.path.join(ANALYSIS, "events_state.json")))
txs = json.load(open(os.path.join(ANALYSIS, "safe_tx_service", "safes_current.json")))
ever = set(a.lower() for a in state["ever_enabled"])
current = set(a.lower() for a in state["currently_enabled_by_events"])
act_safes = set(topic_addr(x["topics"][1]).lower() for x in act)

universe = sorted(ever | act_safes | set(a.lower() for a in txs))
print(f"ever_enabled={len(ever)} action_safes={len(act_safes)} tx_service={len(txs)} universe={len(universe)}")
print("action_safes NOT in ever_enabled:", sorted(act_safes - ever))

res = []
for i, s in enumerate(universe):
    out = cast_call([s, "isModuleEnabled(address)(bool)", MODULE])
    enabled = (out == "true")
    # if enabled, fetch grants
    grants = None
    if enabled:
        raw = cast_call([PM, "getAccountDelegatorsInfo(address)((address,(address,string[])[])[])", s])
        grants = raw
    res.append({"safe": s, "module_enabled_now": enabled, "delegators_raw": grants,
                "in_events": s in ever, "in_actions": s in act_safes, "in_tx_service": s in current})
    if (i + 1) % 20 == 0 or i == len(universe) - 1:
        print(f"[{i+1}/{len(universe)}]", flush=True)

json.dump(res, open(os.path.join(ANALYSIS, "exhaustive_enabled_check.json"), "w"), indent=1)
now = [r for r in res if r["module_enabled_now"]]
print(f"\ncurrently enabled (on-chain verified): {len(now)}")
for r in now:
    print(" ", r["safe"], "events=" + str(r["in_events"]), "actions=" + str(r["in_actions"]),
          "txsvc=" + str(r["in_tx_service"]))
