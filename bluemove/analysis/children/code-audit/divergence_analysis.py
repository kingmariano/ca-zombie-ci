#!/usr/bin/env python3
"""Analyze cross-store divergence from escrow_sample.json (parent's 600-pool sample)."""
import json

e = json.load(open("/home/heisenberg/CA/bluemove/analysis/escrow_sample.json"))

def ratio(a):
    return (a[1] / a[0]) if a[0] else None

rows = []
for x in e:
    T, E2, EM, r, S = x["T"], x["E2"] or [0, 0], x["EM"] or [0, 0], x["r"], x["S"]
    st = {"T": T, "E2": E2, "EM": EM}
    populated = [k for k, v in st.items() if v != [0, 0]]
    if len(populated) >= 2:
        row = {"addr": x["addr"], "name": x["name"][:96], "r": r, "S": S, "populated": populated,
               "T": T, "E2": E2, "EM": EM, "last_writer": x["last_writer"]}
        # ratio divergence T vs E2, T vs EM, EM vs E2
        for A, B in (("T", "E2"), ("T", "EM"), ("EM", "E2")):
            a, b = st[A], st[B]
            if a[0] and b[0]:
                row[f"ratio_{A}_{B}"] = round((a[1]/a[0]) / (b[1]/b[0]), 6)
        rows.append(row)

print("pools with >=2 populated stores:", len(rows))
for row in rows:
    print(json.dumps(row))

# summary of divergence magnitudes
div = [row for row in rows if any(k.startswith("ratio_") and (v > 1.001 or v < 0.999) for k, v in row.items() if isinstance(v, float))]
print("with ratio mismatch:", len(div))
