#!/usr/bin/env python3
import json, base64, sys
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql

DI = "0x3f2d9f724f4a1ce5e71676448dc452be9a6243dac9c5b975a588c8c867066e92"
di_bytes = bytes.fromhex(DI[2:])
bcs = base64.b64encode(di_bytes).decode()

q = """query($addr: SuiAddress!, $name: DynamicFieldName!) {
  object(address: $addr) {
    dynamicObjectField(name: $name) {
      name { type { repr } json }
      value { __typename ... on MoveObject { address contents { type { repr } json } } }
    }
  }
}"""
d = gql(q, {"addr": DI, "name": {"type": "0x2::object::ID", "bcs": bcs}})
print("=== dynamicObjectField(ID) ===")
print(json.dumps(d, indent=1)[:2500])

# fallback: dynamicField
q2 = """query($addr: SuiAddress!, $name: DynamicFieldName!) {
  object(address: $addr) {
    dynamicField(name: $name) {
      name { type { repr } json }
      value { __typename ... on MoveObject { address contents { type { repr } json } } }
    }
  }
}"""
try:
    d2 = gql(q2, {"addr": DI, "name": {"type": "0x2::object::ID", "bcs": bcs}})
    print("=== dynamicField(ID) ===")
    print(json.dumps(d2, indent=1)[:2500])
except Exception as e:
    print("dynamicField err:", str(e)[:300])

# Also try a raw 32-byte bcs of the UID inner for 0x2::dynamic_object_field::Wrapper<ID>? and string key
