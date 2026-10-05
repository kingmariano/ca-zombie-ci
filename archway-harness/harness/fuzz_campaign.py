#!/usr/bin/env python3
"""Differential fuzz campaign driver for CWA-2026-006 trigger research.

Generates random execute messages for a target contract, runs each through both
the vulnerable (wasmvm 1.5.5) and patched (wasmvm 3.0.8) engines, and records:
  - crashes (exit codes other than 0/1)
  - behavioral differences (response/error mismatch)

Usage:
  python3 fuzz_campaign.py --wasm <path> --cases 500 --seed 1 --out ci-out/harness
"""
import argparse
import json
import os
import random
import subprocess
import sys
import concurrent.futures as cf

HERE = os.path.dirname(os.path.abspath(__file__))
VULN = os.path.join(HERE, "harness")
FIXED = os.path.join(HERE, "..", "harness-fixed", "harness-fixed")


def gen_case(rng):
    """Random execute message for the minimal contract (extend per target contract)."""
    kind = rng.choice(["loop", "mix", "classify", "churn", "set", "get"])
    if kind == "loop":
        return {"loop": {"n": rng.choice([0, 1, 10, 1000, 100000, 10_000_000])}}
    if kind == "mix":
        return {"mix": {"a": rng.randint(-2**63, 2**63 - 1), "b": rng.randint(-2**63, 2**63 - 1)}}
    if kind == "classify":
        return {"classify": {"n": rng.choice([0, 1, 7, 1000, 1_000_000])}}
    if kind == "churn":
        return {"churn": {"n": rng.choice([0, 1, 100, 4096, 100_000])}}
    if kind == "set":
        key = "k" + str(rng.randint(0, 5))
        return {"set": {"key": key, "value": "v" * rng.choice([0, 1, 32, 1000])}}
    return {"get": {"key": "k" + str(rng.randint(0, 5))}}


def run_one(args):
    idx, wasm, init, exec_msg, outdir, repeat = args
    d = os.path.join(outdir, f"case_{idx:05d}")
    os.makedirs(d, exist_ok=True)
    init_json = json.dumps(init)
    exec_json = json.dumps(exec_msg)
    res = {}
    for tag, binpath in (("vuln", VULN), ("fixed", FIXED)):
        p = subprocess.run(
            [binpath, "-wasm", wasm, "-init", init_json, "-exec", exec_json,
             "-repeat", str(repeat), "-out", os.path.join(d, f"{tag}.json")],
            capture_output=True, text=True, timeout=600,
        )
        res[tag] = p.returncode
    c1, c2 = res["vuln"], res["fixed"]

    def load(tag):
        try:
            return json.load(open(os.path.join(d, f"{tag}.json")))
        except Exception:
            return None

    def norm(r):
        if not r:
            return None
        inst = r.get("instantiate", {}) or {}
        execs = r.get("executes") or []
        return {
            "inst_err": inst.get("error", ""),
            "inst_resp": inst.get("response"),
            "execs": [(e.get("error", ""), e.get("response")) for e in execs],
        }

    nv, nf = norm(load("vuln")), norm(load("fixed"))

    def has_oog(n):
        return bool(n) and any("out of gas" in (e[0] or "").lower() for e in n["execs"])

    anomaly = None
    gas_diff = False
    if c1 not in (0, 1) or c2 not in (0, 1):
        anomaly = f"CRASH-SUSPECT vuln={c1} fixed={c2}"
    elif has_oog(nv) != has_oog(nf):
        # one engine exhausted gas, the other completed: metering-scale artifact
        # (v1.5.5 burns ~1000x the gas of v3 for the same work), not a behavior bug
        gas_diff = True
    elif nv != nf:
        anomaly = "BEHAVIOR-DIFF"
    elif c1 != c2:
        anomaly = f"EXIT-DIFF vuln={c1} fixed={c2}"
    return {
        "idx": idx, "exec": exec_msg, "exit": [c1, c2],
        "anomaly": anomaly, "gas_diff": gas_diff,
        "vuln": nv, "fixed": nf,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wasm", required=True)
    ap.add_argument("--cases", type=int, default=200)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--repeat", type=int, default=1)
    ap.add_argument("--out", default="ci-out/harness")
    ap.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) // 2))
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    rng = random.Random(args.seed)
    cases = []
    for i in range(args.cases):
        init = {"seed": rng.randint(0, 2**32)}
        cases.append((i, args.wasm, init, gen_case(rng), args.out, args.repeat))

    anomalies = []
    gas_diffs = 0
    done = 0
    with cf.ThreadPoolExecutor(max_workers=args.workers) as ex:
        for r in ex.map(run_one, cases):
            done += 1
            if r["anomaly"]:
                anomalies.append(r)
                print(f"[{done}/{args.cases}] ANOMALY case {r['idx']}: {r['anomaly']} :: {json.dumps(r['exec'])[:120]}", flush=True)
            elif r.get("gas_diff"):
                gas_diffs += 1
                if gas_diffs <= 5:
                    print(f"[{done}/{args.cases}] gas-metering-diff case {r['idx']} (filtered)", flush=True)
            elif done % 50 == 0:
                print(f"[{done}/{args.cases}] clean", flush=True)

    summary = {
        "wasm": args.wasm, "cases": args.cases, "seed": args.seed,
        "anomalies": len(anomalies),
        "gas_metering_diffs_filtered": gas_diffs,
        "anomaly_cases": anomalies,
    }
    with open(os.path.join(args.out, "fuzz_summary.json"), "w") as f:
        json.dump(summary, f, indent=1)
    print(f"DONE cases={args.cases} anomalies={len(anomalies)} -> {args.out}/fuzz_summary.json")
    return 0 if not anomalies else 3


if __name__ == "__main__":
    sys.exit(main())
