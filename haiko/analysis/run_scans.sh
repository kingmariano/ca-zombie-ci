#!/usr/bin/env bash
# Run the remaining event scans sequentially (background job).
cd /home/heisenberg/CA/haiko/analysis
S=0x2ffce9d48390d497f7dfafa9dfd22025d9c285135bcc26c955aea8741f081d2
MM=0x38925b0bcf4dce081042ca26a96300d9e181b910328db54a6c89e5451503f5
echo "=== UpdatePositions scan"
python3 scan_events.py $S UpdatePositions 531811 > up_scan.log 2>&1 && tail -2 up_scan.log
echo "=== Sweep scan (MM)"
python3 - <<'EOF' > sweep_scan.log 2>&1
import sys, json
sys.path.insert(0,".")
from starknet_rpc import rpc, selector_from_name
from scan_events import scan_events
MM="0x38925b0bcf4dce081042ca26a96300d9e181b910328db54a6c89e5451503f5"
sel = selector_from_name("Sweep")
evs = scan_events(MM, [[sel]], 531808, 16155000, verbose=False)
json.dump(evs, open("events_Sweep.json","w"))
print("sweeps:", len(evs))
for e in evs:
    print(e["block_number"], e["keys"][1][:20], e["keys"][2][:20], e["data"][:2])
EOF
tail -30 sweep_scan.log
echo "=== ERC721 mints to strategy scan"
python3 - <<'EOF' > mints_scan.log 2>&1
import sys, json
sys.path.insert(0,".")
from starknet_rpc import rpc, selector_from_name
from scan_events import scan_events
MM="0x38925b0bcf4dce081042ca26a96300d9e181b910328db54a6c89e5451503f5"
S="0x2ffce9d48390d497f7dfafa9dfd22025d9c285135bcc26c955aea8741f081d2"
sel = selector_from_name("Transfer")
evs = scan_events(MM, [[sel], ["0x0"], [S]], 531808, 16155000, verbose=False)
json.dump(evs, open("events_mints_to_strategy.json","w"))
print("mints to strategy:", len(evs))
for e in evs:
    print(e["block_number"], "token_id:", e["keys"][3:], "data:", e["data"][:2])
EOF
tail -20 mints_scan.log
echo "ALL DONE"
