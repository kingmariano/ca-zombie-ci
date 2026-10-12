#!/usr/bin/env python3
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql

q = """{ __type(name: "ProgrammableTransaction") { name fields { name type { kind name ofType { kind name ofType { kind name } } } } } }"""
try:
    print(json.dumps(gql(q), indent=1)[:3000])
except Exception as e:
    print("err", str(e)[:300])

q2 = """{ __type(name: "MoveCallCommand") { name fields { name type { kind name ofType { kind name ofType { kind name } } } } } }"""
try:
    print(json.dumps(gql(q2), indent=1)[:3000])
except Exception as e:
    print("err2", str(e)[:300])

# find union member names of TransactionKind
q3 = """{ __type(name: "TransactionKind") { name kind possibleTypes { name } } }"""
try:
    print(json.dumps(gql(q3), indent=1)[:2000])
except Exception as e:
    print("err3", str(e)[:300])
