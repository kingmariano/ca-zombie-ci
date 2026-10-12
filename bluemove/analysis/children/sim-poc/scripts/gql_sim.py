#!/usr/bin/env python3
"""Sui GraphQL simulateTransaction harness (read-only, public endpoint only).

Usage:
    python3 gql_sim.py <tx.json> <label> [--checks] [--no-gas-selection]

Posts `query Sim($tx: JSON!) { simulateTransaction(transaction: $tx, ...) }`
to https://graphql.mainnet.sui.io/graphql.

Saves:
    evidence/<label>.graphql_request.json   (exact POST body)
    evidence/<label>.graphql_response.json  (exact raw response)

Never signs, never executes; simulation only.
"""
import json
import pathlib
import sys
import urllib.request

GQL = "https://graphql.mainnet.sui.io/graphql"
EVID = pathlib.Path(__file__).resolve().parent.parent / "evidence"

QUERY = """query Sim($tx: JSON!, $checks: Boolean, $gasSelect: Boolean) {
  simulateTransaction(transaction: $tx, checksEnabled: $checks, doGasSelection: $gasSelect) {
    effects {
      digest
      status
      executionError { message identifier abortCode constant module { name } function { name } }
      effectsJson
    }
    outputs {
      returnValues {
        value { json bcs type { repr } }
      }
    }
  }
}"""

HEADERS = {
    "Content-Type": "application/json",
    "User-Agent": "bluemove-phase2-sim-poc/0.1 (defensive research)",
}


def simulate(tx_json: dict, label: str, checks: bool = False, gas_select: bool = True):
    variables = {"tx": tx_json, "checks": checks, "gasSelect": gas_select}
    body = {"query": QUERY, "variables": variables, "operationName": "Sim"}
    EVID.mkdir(parents=True, exist_ok=True)
    req_path = EVID / f"{label}.graphql_request.json"
    res_path = EVID / f"{label}.graphql_response.json"
    req_path.write_text(json.dumps(body, indent=1))

    req = urllib.request.Request(GQL, data=json.dumps(body).encode(), headers=HEADERS)
    with urllib.request.urlopen(req, timeout=180) as r:
        raw = r.read()
    res_path.write_text(raw.decode())
    doc = json.loads(raw)
    if doc.get("errors"):
        print("TOP-LEVEL GRAPHQL ERRORS:")
        print(json.dumps(doc["errors"], indent=1)[:4000])
        return None
    return doc.get("data", {}).get("simulateTransaction")


def show(result):
    if result is None:
        return
    eff = result.get("effects") or {}
    print("digest      :", eff.get("digest"))
    print("status      :", eff.get("status"))
    err = eff.get("executionError")
    if err:
        print("execError   :", json.dumps(err))
    outs = result.get("outputs") or []
    for i, o in enumerate(outs):
        for rv in o.get("returnValues") or []:
            v = rv.get("value") or {}
            print(f"output[{i}] : type={((v.get('type') or {}).get('repr'))} json={json.dumps(v.get('json'))} bcs={v.get('bcs')}")


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    tx_path, label = sys.argv[1], sys.argv[2]
    checks = "--checks" in sys.argv
    gas_select = "--no-gas-selection" not in sys.argv
    tx = json.loads(pathlib.Path(tx_path).read_text())
    res = simulate(tx, label, checks=checks, gas_select=gas_select)
    show(res)
    # also dump a compact effectsJson summary
    if res:
        eff = res.get("effects") or {}
        ej = eff.get("effectsJson")
        if ej:
            keep = {k: ej.get(k) for k in
                    ("status", "gasUsed", "effectsDigest", "transactionDigest") if isinstance(ej, dict)}
            print("effectsJson keys:", sorted(ej.keys()) if isinstance(ej, dict) else type(ej))
            print(json.dumps(keep, indent=1)[:2000])


if __name__ == "__main__":
    main()
