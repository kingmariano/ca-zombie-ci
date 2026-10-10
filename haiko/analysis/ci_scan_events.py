#!/usr/bin/env python3
"""CI heavy scan: all Haiko strategy/MM events of interest. Writes ci-out/events_*.json."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from starknet_rpc import selector_from_name, block_number  # noqa
from scan_events import scan_events  # noqa

OUT = os.path.join(HERE, "..", "ci-out")
os.makedirs(OUT, exist_ok=True)

S = "0x2ffce9d48390d497f7dfafa9dfd22025d9c285135bcc26c955aea8741f081d2"
MM = "0x38925b0bcf4dce081042ca26a96300d9e181b910328db54a6c89e5451503f5"
START = 531808

MARKETS = {
    "M1_ETH_USDC": "0x6812a18046f6b1d926ce6d081ceee71cb0ec7fbdb38167cc07d618ee8f5713e",
    "M2_wstETH_ETH": "0x678fc48b8c618084ba8ac46fa94f004b4af4dc85c9f9e14c2f94f2816676cc2",
    "M3_USDC_USDT": "0xeb87f342e5267cb250240851fdeaa111ce548934e529c41137fea49ccebdf",
    "M4_STRK_USDC": "0xf62b32bcbb3f2662000bdd8f3c51b528f0131ed7ca6a964a3004b4cc0d586b",
    "M5_STRK_ETH": "0x3ddeeae1e54ed0b70d57e067fa696ef333e69cc6dbe8b4469ad0e9900546b54",
    "M6_ETH_WBTC": "0x16707e0f13b27d91c357a8294b28ff023e30acbf1456e5391f61fa22cdb0d76",
}

end = block_number()
print("latest block:", end)
summary = {"block": end, "scans": {}}

# per-market deposit/withdraw scans
for name, mid in MARKETS.items():
    for evname in ["Deposit", "Withdraw"]:
        sel = selector_from_name(evname)
        evs = scan_events(S, [[sel], [], [mid]], START, end, range_size=1_000_000, verbose=True, max_pages=60)
        fn = f"events_{evname}_{name}.json"
        json.dump(evs, open(os.path.join(OUT, fn), "w"))
        users = sorted({e["keys"][1] for e in evs})
        summary["scans"][f"{evname}_{name}"] = {"events": len(evs), "unique_users": len(users)}
        print(f"{evname} {name}: {len(evs)} events, {len(users)} unique users")

# MM-level scans
for label, addr, evname, keys in [
    ("CreateMarket_MM", MM, "CreateMarket", None),
    ("Sweep_MM", MM, "Sweep", None),
    ("UpdatePositions_S", S, "UpdatePositions", None),
]:
    sel = selector_from_name(evname)
    evs = scan_events(addr, [[sel]], START, end, range_size=1_000_000, verbose=True, max_pages=60)
    fn = f"events_{label}.json"
    json.dump(evs, open(os.path.join(OUT, fn), "w"))
    summary["scans"][label] = {"events": len(evs)}
    print(f"{label}: {len(evs)} events")

# ERC721 mints to strategy
sel = selector_from_name("Transfer")
mints = scan_events(MM, [[sel], ["0x0"], [S]], START, end, range_size=1_000_000, verbose=True, max_pages=60)
json.dump(mints, open(os.path.join(OUT, "events_mints_to_strategy.json"), "w"))
summary["scans"]["mints_to_strategy"] = {"events": len(mints)}
print("mints to strategy:", len(mints))

json.dump(summary, open(os.path.join(OUT, "scan_summary.json"), "w"), indent=1)
print("done")
