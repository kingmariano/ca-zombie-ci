#!/usr/bin/env python3
"""Background: LP Transfer scans + NAR filtered team-address scans. Checkpointed."""
import os, sys, json, time
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis")
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis/ecosystem")
from scan_lib import get_logs_paced
url = os.environ.get("ALT_RPC")

TRANSFER = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
LPS = ["0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2",
       "0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957",
       "0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3",
       "0x00eda48b05a72e518033c78ad8c140109136fe23",
       "0x8b1bbfaf50551d8427bc24beecd3406cdcef48b8",
       "0x6166911e31c55de58a32cd2abe379fe4382aec9d"]
print("== LP+rNLP transfer scan 1.30M..20M")
logs = get_logs_paced(LPS, [TRANSFER], 1300000, 20000000, 50000, ckpt="lp_transfers_ckpt.json", pace=0.25, url=url)
json.dump(logs, open("lp_transfers.json", "w"))
print("LP logs:", len(logs), flush=True)

NAR = "0xa1303e6199b319a891b79685f0537d289af1fc83"
WATCH = ["0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5",  # team EOA
         "0x507bdd06aca5facd19aa4b77037d3b9d48be2fb9",  # team wallet
         "0x18527a351db2435fa21db88cbb87d4155188b62b0",  # dev wallet (grandbanks)
         "0xab3921c5de7e3459ce07f7015b3fdf0ebec927ef",  # dev2 (grandbanks v2)
         "0xc76827cce55338cbd6b399f45a75df0cd5da2749",  # factory deployer
         "0xd68415507d4beb355aeec2f0d52938800c7b62e0",  # timelock v1
         "0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9",  # collecter
         "0x1d227f7e283d653a60f94d2350cab7a49bb85c6f",
         "0x6da9ee0c0571b63e38950d1e12e835d5343f601b",
         "0x1d791eaa684a21de92618dedea7bf373e2486956",
         "0xa1992a9777c3c11c466f44a4b9c7530719a22ea2",
         "0x08f886b14af4fc75e49d6475f46d041f5f257ce1",  # GrandBank V1
         "0x3d8fd880976a3ea0f53cad02463867013d331107",  # GrandBank V2
         "0xa02f5f32426f76b4f7a9ee87cd6b212e4ec08960",  # NAR rewardPool EOA
         "0x268a2c1acbeee3b74616b9fe3f07c1bf80841e5d",  # V3 farm (BTCB/NAR)
         "0x46d603e2b9c709454316ebd244b99a8abe3bd243",  # rNLP v3
         "0x512d86161ade81a3e01b6b2de8a994778f75f8cb",  # dev3 (NarwhalSwap deployer)
         "0x6abfae833ca1a4e9a9d482dfeebcc5ecec635e90",  # dev4 (strategy gov)
         "0x849b7b4541cde9cbe41cfd064d9d7ff459b9cea4",  # NarwhalSwap aggregator
         "0xe85c6ab56a3422e7bafd71e81eb7d0f290646078",  # Narwhalswap Router
         ]
def topic(a): return "0x" + a.lower().replace("0x", "").rjust(64, "0")

for name, pos in [("from", 0), ("to", 1)]:
    topics = [TRANSFER, None, None]
    topics[1 + pos] = [topic(a) for a in WATCH]
    print(f"== NAR transfers where {name} in WATCH set, 1.27M..20M")
    l2 = get_logs_paced(NAR, topics, 1270000, 20000000, 50000, ckpt=f"nar_{name}_ckpt.json", pace=0.25, url=url)
    json.dump(l2, open(f"nar_{name}.json", "w"))
    print(f"NAR {name} logs:", len(l2), flush=True)
print("ALL DONE")
