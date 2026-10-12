#!/usr/bin/env python3
"""Summarize all saved simulation responses in evidence/*.graphql_response.json.

Prints one row per simulation: label, digest, status, short error, gas, return values.
Also writes evidence/simulation_summary.json (machine-readable).
"""
import json
import pathlib

EVID = pathlib.Path(__file__).resolve().parent.parent / "evidence"


def short_err(effects_json: dict) -> str:
    err = (effects_json.get("status") or {}).get("error")
    if not err:
        return ""
    d = err.get("description") or ""
    if isinstance(d, str) and d:
        return d.replace("\n", " ")[:220]
    return json.dumps(err)[:220]


def main():
    rows = []
    for p in sorted(EVID.glob("*.graphql_response.json")):
        label = p.name.replace(".graphql_response.json", "")
        doc = json.loads(p.read_text())
        if doc.get("errors"):
            rows.append({"label": label, "graphql_errors": doc["errors"]})
            continue
        res = (doc.get("data") or {}).get("simulateTransaction") or {}
        eff = res.get("effects") or {}
        ej = eff.get("effectsJson") or {}
        row = {
            "label": label,
            "digest": eff.get("digest"),
            "status": eff.get("status"),
            "error": short_err(ej),
            "gasUsed": ej.get("gasUsed"),
            "outputs": res.get("outputs"),
            "changedObjects": ej.get("changedObjects"),
        }
        rows.append(row)

    out = EVID / "simulation_summary.json"
    out.write_text(json.dumps(rows, indent=1))
    for r in rows:
        if r.get("graphql_errors"):
            print(f"{r['label']:38s} GRAPHQL_ERROR {json.dumps(r['graphql_errors'])[:140]}")
            continue
        n_changed = len(r.get("changedObjects") or [])
        late = " ".join(f"{k}={r['gasUsed'][k]}" for k in ("computationCost", "storageCost", "storageRebate") if r.get("gasUsed"))
        print(f"{r['label']:38s} {str(r['status']):8s} digest={str(r['digest'])[:20]:20s} changed={n_changed} {late}")
        if r["error"]:
            print(f"{'':38s}   -> {r['error']}")
    print(f"\nsummary saved to {out}")


if __name__ == "__main__":
    main()
