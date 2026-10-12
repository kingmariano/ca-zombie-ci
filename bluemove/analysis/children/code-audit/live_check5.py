#!/usr/bin/env python3
"""Recent activity + which package emits pool-creation events; find newest package lineage."""
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql

# 1) last Created_Pool_Event events
q = """query {
  events(last: 5, filter: {type: "0xb24b6789e088b876afabca733bed2299fbc9e2d6369be4d1acfa17d8145454d9::swap::Created_Pool_Event"}) {
    nodes {
      timestamp
      transaction { digest }
      contents { json }
    }
  }
}"""
try:
    d = gql(q)
    print("=== last Created_Pool_Event ===")
    print(json.dumps(d, indent=1)[:3000])
except Exception as e:
    print("events err:", str(e)[:400])

# 2) last Swap_Event to see recent trading
q2 = """query {
  events(last: 5, filter: {type: "0xb24b6789e088b876afabca733bed2299fbc9e2d6369be4d1acfa17d8145454d9::swap::Swap_Event"}) {
    nodes { timestamp transaction { digest } }
  }
}"""
try:
    d2 = gql(q2)
    print("=== last Swap_Event ===")
    print(json.dumps(d2, indent=1)[:2000])
except Exception as e:
    print("events2 err:", str(e)[:400])

# 3) latest checkpoint for 'now'
try:
    d3 = gql("{ checkpoint { sequenceNumber timestamp } }")
    print("=== now ===", json.dumps(d3))
except Exception as e:
    print("ckpt err", str(e)[:200])

# 4) dev address recent transactions (publish upgrades)
q4 = """query($addr: SuiAddress!) {
  address(address: $addr) {
    transactions(last: 10) {
      nodes { digest effects { status } }
    }
  }
}"""
try:
    d4 = gql(q4, {"addr": "0x049cc391ab4d3503e03dbb24c4f9e28f3cdd2ddf8a459e0d43012c3868ffefa1"})
    print("=== dev txs ===")
    print(json.dumps(d4, indent=1)[:2500])
except Exception as e:
    print("devtx err:", str(e)[:400])
