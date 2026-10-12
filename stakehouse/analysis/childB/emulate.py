#!/usr/bin/env python3
"""
Minimal EVM path-exploring emulator for Stakehouse bytecode analysis (read-only research).

- Executes linearly, simple concrete values (int) + symbolic strings (Sym).
- Forks on EVERY JUMPI (both branches), dedupes states by (pc, stack, mem, storage, events-len).
- Simulates external calls: success=1, returndata = 32 symbolic bytes, records call info.
- Decodes revert strings (Error(string)) and Panic(uint256).
- Reports per-path event trails: FORK / SSTORE / CALL / REVERT / RETURN.

Usage: python3 emulate.py <bytecode.txt|hex> <start_pc_hex> <calldata_hex> [max_states] [max_steps]
"""
import sys, json
from eth_utils import keccak as keccak256

MASK = (1 << 256) - 1
UMASK = (1 << 256) - 1

def hx(b): return "0x" + b.hex()

class Sym:
    __slots__ = ("e",)
    def __init__(self, e): self.e = e
    def __repr__(self): return self.e

def is_con(v): return isinstance(v, int)

def fmt(v):
    if is_con(v): return str(v)
    return v.e

def b2i(b): return int.from_bytes(b, "big")
def i2b(i, n=32): return (i & ((1 << (8*n)) - 1)).to_bytes(n, "big")

class PathEvent(list):
    pass

def load_code(path):
    s = open(path).read().strip()
    if s.startswith("0x"): s = s[2:]
    return bytes.fromhex(s)

# instruction decoding
PUSH1, PUSH32 = 0x60, 0x7f
DUP1, DUP16 = 0x80, 0x8f
SWAP1, SWAP16 = 0x90, 0x9f
LOG0, LOG4 = 0xa0, 0xa4
POP, MLOAD, MSTORE, MSTORE8 = 0x50, 0x51, 0x52, 0x53
SLOAD, SSTORE, JUMP, JUMPI, PC, MSIZE, GAS, JUMPDEST = 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x5b
CREATE, CALL, CALLCODE, RETURN, DELEGATECALL, CREATE2, STATICCALL, REVERT, INVALID, SELFDESTRUCT = (
    0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xfa, 0xfd, 0xfe, 0xff)
ADDRESS, BALANCE, ORIGIN, CALLER, CALLVALUE, CALLDATALOAD, CALLDATASIZE, CALLDATACOPY = (
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37)
CODESIZE, CODECOPY, GASPRICE, EXTCODESIZE, EXTCODECOPY, RETURNDATASIZE, RETURNDATACOPY = (
    0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e)
BLOCKHASH, COINBASE, TIMESTAMP, NUMBER, DIFFICULTY, GASLIMIT, CHAINID, SELFBALANCE, BASEFEE = (
    0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48)
SHA3, STOP, ADD, MUL, SUB, DIV, SDIV, MOD = 0x20, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06

ARITH2 = {
    0x01: ("add", lambda a, b: a + b),
    0x02: ("mul", lambda a, b: a * b),
    0x03: ("sub", lambda a, b: a - b),
    0x04: ("div", lambda a, b: a // b if b else 0),
    0x06: ("mod", lambda a, b: a % b if b else 0),
    0x10: ("lt", lambda a, b: 1 if a < b else 0),
    0x11: ("gt", lambda a, b: 1 if a > b else 0),
    0x14: ("eq", lambda a, b: 1 if a == b else 0),
    0x16: ("and", lambda a, b: a & b),
    0x17: ("or", lambda a, b: a | b),
    0x18: ("xor", lambda a, b: a ^ b),
    0x1b: ("shl", lambda a, b: (b << a) & UMASK),
    0x1c: ("shr", lambda a, b: b >> a if a < 256 else 0),
    0x0a: ("exp", lambda a, b: pow(b, a, 1 << 256) if (is_con(a) and a < 64) else None),
}
UNARY = {
    0x15: ("iszero", lambda a: 1 if a == 0 else 0),
    0x19: ("not", lambda a: (~a) & UMASK),
}

class Abort(Exception):
    pass

class State:
    __slots__ = ("pc", "stack", "mem", "storage", "retdata", "events", "steps", "calls")
    def __init__(self, pc, stack, mem, storage, retdata, events, steps, calls):
        self.pc, self.stack, self.mem, self.storage = pc, stack, mem, storage
        self.retdata, self.events, self.steps, self.calls = retdata, events, steps, calls
    def key(self):
        # hashable-ish representation; do not include events content (only length)
        return (self.pc, tuple(repr(x) for x in self.stack),
                tuple(sorted((str(k), repr(v)) for k, v in self.mem.items())),
                tuple(sorted((str(k), repr(v)) for k, v in self.storage.items())),
                len(self.calls))

def mem_read(mem, off, size):
    out = b""
    pos = off
    while len(out) < size:
        if pos in mem:
            v = mem[pos]
            if isinstance(v, Sym):
                return Sym(f"mem[{off}+{len(out)}..]")
            out += v.to_bytes(1, "big")
        else:
            out += b"\x00"
        pos += 1
    return out[:size]

def mem_read_word(mem, off):
    b = mem_read(mem, off, 32)
    if isinstance(b, Sym): return b
    return b2i(b)

def mem_write(mem, off, data: bytes):
    for i, byte in enumerate(data):
        mem[off + i] = byte

def decode_revert(mem, off, size):
    if not is_con(off) or not is_con(size): return "revert(symbolic)"
    data = mem_read(mem, off, min(size, 4096))
    if isinstance(data, Sym): return "revert(symbolic)"
    if len(data) >= 4:
        sel = data[:4]
        if sel == bytes.fromhex("08c379a0"):
            try:
                ln = b2i(data[36:68]); s = data[68:68+ln].decode(errors="replace")
                return f'Error("{s}")'
            except Exception: pass
        if sel == bytes.fromhex("4e487b71"):
            code = b2i(data[36:68]) if len(data) >= 68 else 0
            names = {0x01:"assert",0x11:"overflow",0x12:"div0",0x21:"enum",0x22:"storage",0x31:"pop",0x32:"bounds",0x41:"alloc",0x51:"zerobytes"}
            return f'Panic({names.get(code, hex(code))})'
    return "revert(" + data.hex() + ")"

def encode_abi_head(*vals):
    # naive abi encoder for the calldata we build
    raise NotImplementedError

def run(code, start_pc, calldata: bytes, max_states=4000, max_steps=400000, fork_all=True,
        verbose_result=True, hook=None):
    cd = calldata
    cdsize = len(cd)
    hook = dict(hook or {})

    def cdl(off):
        if not is_con(off): return Sym(f"cd[{fmt(off)}]")
        if off + 32 <= len(cd):
            return b2i(cd[off:off+32])
        tail = cd[off:] if off < len(cd) else b""
        return b2i(tail + b"\x00" * (32 - len(tail)))

    results = []
    init = State(start_pc, [], {}, {}, b"", PathEvent(), 0, [])
    work = [init]
    seen = set()
    total_states = 0

    while work:
        st = work.pop()
        k = st.key()
        if k in seen: continue
        seen.add(k)
        total_states += 1
        if total_states > max_states:
            results.append(("ABORT", "max states", st))
            break
        stack, mem, storage = st.stack, st.mem, st.storage
        events, calls = st.events, st.calls
        pc = st.pc
        retdata = st.retdata
        steps = st.steps
        aborted = None
        tail = []

        while True:
            steps += 1
            if hook.get("watch_pcs") and pc in hook["watch_pcs"]:
                print(f"WATCH pc={pc} 0x{pc:05x} stack={[fmt(x) for x in stack]}")
                vals = sorted((k, repr(v)[:40]) for k,v in mem.items() if isinstance(k,int))
                print("   mem:", vals[:24], "..." if len(vals)>24 else "")
                print("   storage:", {str(k):fmt(v) for k,v in storage.items()})
            if hook.get("trace") and pc >= hook.get("trace_from", 0) and steps <= hook.get("trace_until", 200):
                full = [fmt(x) for x in stack]
                print(f"  pc={pc:6d} 0x{pc:05x} op={hex(code[pc])} stack={full if len(full)<=16 else full[-6:]}")
            if steps > max_steps:
                aborted = ("ABORT", "max steps", list(events)); break
            if pc >= len(code):
                aborted = ("ABORT", "pc out of code", list(events)); break
            op = code[pc]
            if 0x60 <= op <= 0x7f:
                n = op - PUSH1 + 1
                v = b2i(code[pc+1:pc+1+n])
                stack.append(v); pc += 1 + n; continue
            if DUP1 <= op <= DUP16:
                stack.append(stack[-(op - DUP1 + 1)]); pc += 1; continue
            if SWAP1 <= op <= SWAP16:
                i = op - SWAP1 + 1
                stack[-1], stack[-1-i] = stack[-1-i], stack[-1]; pc += 1; continue
            if LOG0 <= op <= LOG4:
                n = op - LOG0
                for _ in range(n+2): stack.pop()
                pc += 1; continue
            if op in (POP,):
                stack.pop(); pc += 1; continue
            if op == MLOAD:
                o = stack.pop()
                if is_con(o):
                    stack.append(mem_read_word(mem, o))
                else:
                    stack.append(Sym(f"mload({fmt(o)})"))
                pc += 1; continue
            if op == MSTORE:
                o, v = stack.pop(), stack.pop()
                if is_con(o):
                    if is_con(v): mem_write(mem, o, i2b(v))
                    else:
                        # store symbolic word as 32-byte marker
                        mem[o] = v
                        for i in range(1, 32): mem.pop(o+i, None)
                pc += 1; continue
            if op == MSTORE8:
                o, v = stack.pop(), stack.pop()
                if is_con(o) and is_con(v): mem[o] = v & 0xff
                pc += 1; continue
            if op == SLOAD:
                s = stack.pop()
                if is_con(s):
                    if s not in storage and s in hook.get("storage_init", {}):
                        storage[s] = hook["storage_init"][s]
                    if s in storage: stack.append(storage[s])
                    elif ("sym", s) in storage: stack.append(storage[("sym", s)])
                    else:
                        sv = Sym(f"sload[{s}]"); storage[("sym", s)] = sv; stack.append(sv)
                else:
                    stack.append(Sym(f"sload[{fmt(s)}]"))
                pc += 1; continue
            if op == SSTORE:
                s, v = stack.pop(), stack.pop()
                if is_con(s):
                    storage[s] = v
                    if ("sym", s) in storage: del storage[("sym", s)]
                    events.append(f"SSTORE slot={s} value={fmt(v)} @pc={pc}")
                else:
                    events.append(f"SSTORE slot={fmt(s)} value={fmt(v)} @pc={pc}")
                pc += 1; continue
            if op == JUMP:
                d = stack.pop()
                if is_con(d) and 0 <= d < len(code) and code[d] == JUMPDEST:
                    pc = d; continue
                aborted = ("ABORT", f"bad dynamic jump to {fmt(d)}", list(events)); break
            if op == JUMPI:
                d, c = stack.pop(), stack.pop()
                parent_events = list(events)
                fork_desc = f"JUMPI @pc={pc} cond={fmt(c)}"
                if fork_all:
                    # taken branch
                    st_t = State(d, list(stack), dict(mem), dict(storage), retdata,
                                 PathEvent(parent_events + [favail(f"THEN {fork_desc}")]), steps, list(calls))
                    st_f = State(pc+1, list(stack), dict(mem), dict(storage), retdata,
                                 PathEvent(parent_events + [favail(f"ELSE {fork_desc}")]), steps, list(calls))
                    # order: push ELSE first so THEN runs first (DFS pop last)
                    if is_con(d) and 0 <= d < len(code) and code[d] == JUMPDEST:
                        work.append(st_f); work.append(st_t)
                    else:
                        work.append(st_f)
                        aborted = ("ABORT", f"bad jumpi dest {fmt(d)}", list(events)); 
                    break
                else:
                    if is_con(c):
                        if c != 0:
                            if is_con(d) and 0 <= d < len(code) and code[d] == JUMPDEST:
                                pc = d; continue
                            aborted = ("ABORT", f"bad jumpi dest {fmt(d)}", list(events)); break
                        else:
                            pc += 1; continue
                    else:
                        # must fork
                        st_t = State(d, list(stack), dict(mem), dict(storage), retdata,
                                     PathEvent(parent_events + [f"THEN {fork_desc}"]), steps, list(calls))
                        st_f = State(pc+1, list(stack), dict(mem), dict(storage), retdata,
                                     PathEvent(parent_events + [f"ELSE {fork_desc}"]), steps, list(calls))
                        work.append(st_f); work.append(st_t)
                        break
            if op in ARITH2:
                name, fn = ARITH2[op]
                a, b = (stack.pop(), stack.pop())  # a = top
                if op == 0x0a:  # EXP: top=base? EVM: μs[0]**μs[1]; a**b
                    if is_con(a) and is_con(b): stack.append(pow(a, b, 1 << 256))
                    else: stack.append(Sym(f"(exp {fmt(a)} {fmt(b)})"))
                elif name == "sub":
                    if is_con(a) and is_con(b): stack.append((a - b) & UMASK)
                    else: stack.append(Sym(f"(- {fmt(a)} {fmt(b)})"))
                elif is_con(a) and is_con(b):
                    stack.append(fn(a, b) & UMASK if name not in ("lt","gt","eq") else fn(a, b))
                else:
                    stack.append(Sym(f"({name} {fmt(a)} {fmt(b)})"))
                pc += 1; continue
            if op in UNARY:
                name, fn = UNARY[op]
                a = stack.pop()
                if is_con(a): stack.append(fn(a))
                else: stack.append(Sym(f"({name} {fmt(a)})"))
                pc += 1; continue
            if op == 0x05 or op == 0x07:  # SDIV/SMOD
                a, b = stack.pop(), stack.pop()
                stack.append(Sym(f"(sdiv/smod {fmt(a)} {fmt(b)})")); pc += 1; continue
            if hook.get("trace_tail"):
                tail.append((pc, hex(op)))
                if len(tail) > hook["trace_tail"]: tail.pop(0)
            if op == 0x12:  # SLT
                a, b = stack.pop(), stack.pop()
                if is_con(a) and is_con(b):
                    sa = a - (1 << 256) if a >= (1 << 255) else a
                    sb = b - (1 << 256) if b >= (1 << 255) else b
                    stack.append(1 if sa < sb else 0)
                else:
                    stack.append(Sym(f"(slt {fmt(a)} {fmt(b)})"))
                pc += 1; continue
            if op == 0x13:  # SGT
                a, b = stack.pop(), stack.pop()
                if is_con(a) and is_con(b):
                    sa = a - (1 << 256) if a >= (1 << 255) else a
                    sb = b - (1 << 256) if b >= (1 << 255) else b
                    stack.append(1 if sa > sb else 0)
                else:
                    stack.append(Sym(f"(sgt {fmt(a)} {fmt(b)})"))
                pc += 1; continue
            if op == 0x08 or op == 0x09:  # ADDMOD/MULMOD
                c, b, a = stack.pop(), stack.pop(), stack.pop()
                if all(is_con(x) for x in (a, b, c)): stack.append((a + b) % c if op == 8 else (a * b) % c)
                else: stack.append(Sym(f"(({fmt(a)} op {fmt(b)}) mod {fmt(c)})"))
                pc += 1; continue
            if op == SHA3:
                o, n = stack.pop(), stack.pop()
                if is_con(o) and is_con(n):
                    data = mem_read(mem, o, n)
                    if isinstance(data, bytes):
                        stack.append(b2i(keccak256(data)))
                    else:
                        stack.append(Sym(f"keccak(mem[{o}:{n}])"))
                else:
                    stack.append(Sym(f"keccak(mem[{fmt(o)}:{fmt(n)}])"))
                pc += 1; continue
            if op == ADDRESS: stack.append(0xAAAA00000000000000000000000000000000AAAA); pc += 1; continue
            if op == BALANCE: stack.pop(); stack.append(Sym("balance")); pc += 1; continue
            if op == ORIGIN: stack.append(0x0000AAAA0000000000000000000000000000AAAA); pc += 1; continue
            if op == CALLER: stack.append(hook.get("caller", 0x0000DEAD0000000000000000000000000000BEEF)); pc += 1; continue
            if op == CALLVALUE: stack.append(hook.get("callvalue", 0)); pc += 1; continue
            if op == CALLDATALOAD:
                o = stack.pop(); stack.append(cdl(o)); pc += 1; continue
            if op == CALLDATASIZE: stack.append(cdsize); pc += 1; continue
            if op == CALLDATACOPY:
                dst, src, n = stack.pop(), stack.pop(), stack.pop()
                if is_con(dst) and is_con(src) and is_con(n):
                    d = cd[src:src+n]
                    if len(d) < n: d = d + b"\x00" * (n - len(d))
                    mem_write(mem, dst, d)
                pc += 1; continue
            if op == CODESIZE: stack.append(len(code)); pc += 1; continue
            if op == CODECOPY:
                dst, src, n = stack.pop(), stack.pop(), stack.pop()
                if is_con(dst) and is_con(src) and is_con(n):
                    d = code[src:src+n]
                    if len(d) < n: d = d + b"\x00" * (n - len(d))
                    mem_write(mem, dst, d)
                pc += 1; continue
            if op == GASPRICE: stack.append(0); pc += 1; continue
            if op == EXTCODESIZE: stack.pop(); stack.append(1); pc += 1; continue
            if op == EXTCODECOPY:
                for _ in range(4): stack.pop()
                stack.append(1); pc += 1; continue
            if op == RETURNDATASIZE: stack.append(len(retdata)); pc += 1; continue
            if op == RETURNDATACOPY:
                dst, src, n = stack.pop(), stack.pop(), stack.pop()
                if is_con(dst) and is_con(src) and is_con(n):
                    d = retdata[src:src+n]
                    if len(d) < n: d = d + b"\x00" * (n - len(d))
                    mem_write(mem, dst, d)
                pc += 1; continue
            if op == BLOCKHASH: stack.pop(); stack.append(0); pc += 1; continue
            if op == COINBASE: stack.append(0); pc += 1; continue
            if op == TIMESTAMP: stack.append(hook.get("timestamp", 1700000000)); pc += 1; continue
            if op == NUMBER: stack.append(hook.get("number", 26178883)); pc += 1; continue
            if op == DIFFICULTY: stack.append(0); pc += 1; continue
            if op == GASLIMIT: stack.append(30000000); pc += 1; continue
            if op == CHAINID: stack.append(1); pc += 1; continue
            if op == SELFBALANCE: stack.append(Sym("selfbalance")); pc += 1; continue
            if op == BASEFEE: stack.append(0); pc += 1; continue
            if op == PC: stack.append(pc); pc += 1; continue
            if op == MSIZE: stack.append(Sym("msize")); pc += 1; continue
            if op == GAS: stack.append(10**6); pc += 1; continue
            if op == JUMPDEST: pc += 1; continue
            if op == STOP:
                aborted = ("STOP", "", list(events)); break
            if op == RETURN:
                o, n = stack.pop(), stack.pop()
                aborted = ("RETURN", f"mem[{fmt(o)}:{fmt(n)}]", list(events)); break
            if op == REVERT:
                o, n = stack.pop(), stack.pop()
                aborted = ("REVERT", decode_revert(mem, o, n), list(events)); break
            if op == INVALID:
                aborted = ("REVERT", "INVALID", list(events)); break
            if op == SELFDESTRUCT:
                stack.pop(); aborted = ("STOP", "selfdestruct", list(events)); break
            if op in (CALL, CALLCODE, DELEGATECALL, STATICCALL):
                gas, tgt = stack.pop(), stack.pop()
                if op in (CALL, CALLCODE):
                    val, ao, an, ro, rn = stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
                else:
                    val = None; ao, an, ro, rn = stack.pop(), stack.pop(), stack.pop(), stack.pop()
                # try decode selector from memory
                sel = None
                if is_con(ao):
                    b4 = mem_read(mem, ao, 4)
                    if isinstance(b4, bytes) and len(b4) == 4: sel = hx(b4)
                argdump = None
                if is_con(ao) and is_con(an) and is_con(an) and an >= 4:
                    raw = mem_read(mem, ao, min(an, 4+32*8))
                    if isinstance(raw, bytes): argdump = "0x" + raw.hex()
                rec = {"pc": pc, "kind": {0xf1:"CALL",0xf2:"CALLCODE",0xf4:"DELEGATECALL",0xfa:"STATICCALL"}[op],
                       "target": fmt(tgt), "selector": sel, "args": argdump, "value": fmt(val) if val is not None else None}
                calls.append(rec)
                events.append("CALL " + json.dumps(rec))
                # assume success; 32-byte returndata (ecrecover / overrides)
                if is_con(tgt) and tgt == 1:
                    retdata = bytes.fromhex("0000000000000000000000009785f8e50229ebd2b3788452abc31d1942394e0c")
                elif sel is not None and sel in hook.get("ret_overrides", {}):
                    ov = hook["ret_overrides"][sel]
                    if isinstance(ov, (bytes, bytearray)):
                        retdata = bytes(ov)
                    elif isinstance(ov, str) and ov.startswith("0x"):
                        retdata = bytes.fromhex(ov[2:])
                    else:
                        retdata = (ov & ((1<<256)-1)).to_bytes(32, "big")
                else:
                    retdata = pure_bytes(32)
                # write return data into the requested output area
                if is_con(ro) and is_con(rn) and rn > 0:
                    mem_write(mem, ro, retdata[:rn])
                stack.append(1)
                pc += 1; continue
            if op == CREATE or op == CREATE2:
                aborted = ("ABORT", "create", list(events)); break
            aborted = ("ABORT", f"unhandled opcode {hex(op)}", list(events)); break

        if aborted:
            evs = aborted[2]
            if hook.get("trace_tail"):
                evs = list(evs) + ["TAIL: " + ", ".join(f"{p}({o})" for p, o in tail)]
            results.append((aborted[0], aborted[1], evs))
    return results

def pure_bytes(n):
    # symbolic bytes marker: we treat as concrete zeros for reads, but the caller can look at 'sym'
    return Sym(f"returndata({n})") if False else b"\x00" * n

favail = lambda s: s

if __name__ == "__main__":
    code = load_code(sys.argv[1])
    start = int(sys.argv[2], 16)
    calldata = bytes.fromhex(sys.argv[3][2:] if sys.argv[3].startswith("0x") else sys.argv[3])
    ms = int(sys.argv[4]) if len(sys.argv) > 4 else 4000
    stp = int(sys.argv[5]) if len(sys.argv) > 5 else 400000
    res = run(code, start, calldata, max_states=ms, max_steps=stp)
    from collections import Counter
    cnt = Counter(r[1] for r in res)
    print("== result summary ==")
    for reason, n in cnt.most_common():
        print(f"{n:5d}  {reason}")
    print("== paths ==")
    for kind, reason, evs in res:
        print("=" * 100)
        print(kind, reason)
        for e in evs[-40:]:
            print("   ", e)
