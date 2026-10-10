#!/usr/bin/env python3
"""Targeted checks: CreateMarket count, ERC721 mints to strategy, order ownership."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from starknet_rpc import rpc, selector_from_name, call, block_number  # noqa
from scan_events import scan_events  # noqa

MM = "0x38925b0bcf4dce081042ca26a96300d9e181b910328db54a6c89e5451503f5"
S = "0x2ffce9d48390d497f7dfafa9dfd22025d9c285135bcc26c955aea8741f081d2"

out = {}

# 1) CreateMarket events on MM (all markets ever)
cm_sel = selector_from_name("CreateMarket")
evs = scan_events(MM, [[cm_sel]], 531808, 16160000, verbose=False)
out["create_market_count"] = len(evs)
json.dump(evs, open(os.path.join(os.path.dirname(__file__), "events_CreateMarket.json"), "w"))
print("CreateMarket events:", len(evs))
for e in evs[:5]:
    print("   block", e["block_number"], "keys", [k[:20] for k in e["keys"]], "data", [d[:20] for d in e["data"][:6]])

# 2) ERC721 Transfer mints to strategy
t_sel = selector_from_name("Transfer")
mints = scan_events(MM, [[t_sel], ["0x0"], [S]], 531808, 16160000, verbose=False)
out["mints_to_strategy"] = len(mints)
json.dump(mints, open(os.path.join(os.path.dirname(__file__), "events_mints_to_strategy.json"), "w"))
print("mints to strategy:", len(mints))
for e in mints[:10]:
    print("   block", e["block_number"], "token_id:", e["keys"][3:], "data", e["data"][:2])

with open(os.path.join(os.path.dirname(__file__), "targeted_checks.json"), "w") as f:
    json.dump(out, f, indent=1)
print("done")
