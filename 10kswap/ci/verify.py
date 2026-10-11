#!/usr/bin/env python3
"""Class-hash / program verification for 10KSwap (CI).

Compares the Cairo-0 class definitions deployed on Starknet mainnet (vendored in
ci/inputs/*.json.gz, fetched read-only from a public RPC) against classes compiled
from the public source repo 10k-swap/10k_swap-contracts at commit
c47f2e158687a757d0834893d5b01ba4131a55ec with cairo-lang==0.9.1 +
openzeppelin-cairo-contracts==0.3.2.

Two-layer verification:
  1. deep equality of the program JSON (debug_info excluded - it is stripped by the
     class-hash algorithm in cairo-lang 0.9.1), plus entry_points_by_type and abi
  2. class-hash equality (compute_class_hash from cairo-lang 0.9.1), with a
     self-consistency check hashing the deployed class itself.

Exit code 0 iff all requested classes VERIFY; writes ci-out/classhash-verification.json.
"""
import json, gzip, base64, sys, os, argparse, dataclasses

EXPECTED = {
    "pair": "0x231adde42526bad434ca2eb983efdd64472638702f87f97e6e3c084f264e06f",
    "factory": "0x55373ed0e387ba6117b7bf65fa4a67af582f8de4e2a20cc75669d26ddb2df3",
    "router": "0x514718bb56ed2a8607554c7d393c2ffd73cbab971c120b00a2ce27cc58dd1c1",
}


def load_json(path):
    if path.endswith(".gz"):
        with gzip.open(path, "rt") as f:
            return json.load(f)
    with open(path) as f:
        return json.load(f)


def decode_deployed_program(cc):
    """RPC format: program is base64(gzip(json))."""
    raw = base64.b64decode(cc["program"])
    try:
        raw = gzip.decompress(raw)
    except Exception:
        pass
    return json.loads(raw)


def to_standard(raw):
    """Normalise both RPC-format and compiled-format class dicts to
    {program: dict, entry_points_by_type: dict, abi: list}."""
    prog = raw["program"]
    if isinstance(prog, str):
        prog = decode_deployed_program(raw)
    return {"program": prog, "entry_points_by_type": raw["entry_points_by_type"],
            "abi": raw.get("abi")}


def compute_hash(raw_class):
    """Compute a Cairo-0 class hash with cairo-lang 0.9.1 tooling."""
    from starkware.starknet.services.api.contract_class import ContractClass
    from starkware.starknet.core.os.class_hash import compute_class_hash
    std = to_standard(raw_class)
    errs = []
    for how in ("schema", "loads", "load", "direct"):
        try:
            if how == "schema":
                cc = ContractClass.Schema().load(std)
            elif how == "loads":
                cc = ContractClass.loads(json.dumps(std))
            elif how == "load":
                cc = ContractClass.load(json.dumps(std))
            else:
                from starkware.cairo.lang.compiler.program import Program
                prog_obj = Program.Schema().load(std["program"])
                cc = ContractClass(program=prog_obj,
                                   entry_points_by_type=std["entry_points_by_type"],
                                   abi=std.get("abi"))
            return int(compute_class_hash(cc)), None
        except Exception as e:
            errs.append(f"{how}: {type(e).__name__}: {str(e)[:160]}")
    return None, " | ".join(errs)


def strip_debug(prog):
    if isinstance(prog, dict):
        return {k: v for k, v in prog.items() if k != "debug_info"}
    return prog


def normalize_program(prog_dict):
    """Round-trip a program dict through cairo-lang's Program schema.
    This normalises cosmetic serialization differences (e.g. identifier cairo_type
    whitespace) the same way the class-hash algorithm does."""
    from starkware.cairo.lang.compiler.program import Program
    p = dict(prog_dict)
    p["debug_info"] = None
    prog = Program.Schema().load(p)
    return prog.dump()


def first_diff(a, b, path="", depth=0):
    if type(a) != type(b):
        return f"{path}: type {type(a).__name__} != {type(b).__name__}"
    if isinstance(a, dict):
        for k in sorted(set(a) | set(b)):
            if k not in a:
                return f"{path}.{k}: missing in deployed"
            if k not in b:
                return f"{path}.{k}: missing in compiled"
            d = first_diff(a[k], b[k], f"{path}.{k}", depth + 1)
            if d:
                return d
        return None
    if isinstance(a, list):
        if len(a) != len(b):
            return f"{path}: len {len(a)} != {len(b)}"
        for i, (x, y) in enumerate(zip(a, b)):
            d = first_diff(x, y, f"{path}[{i}]", depth + 1)
            if d:
                return d
        return None
    if a != b:
        sa, sb = str(a), str(b)
        return f"{path}: {sa[:70]} != {sb[:70]}"
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--compiled", required=True)
    ap.add_argument("--deployed", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--classes", default="pair,factory,router")
    args = ap.parse_args()
    wanted = [c for c in args.classes.split(",") if c]

    out = {"compiler": {}, "classes": {}}
    import starkware.cairo.lang.version as cv
    out["compiler"]["cairo_lang"] = getattr(cv, "__version__", "unknown")
    try:
        import sympy
        out["compiler"]["sympy"] = sympy.__version__
    except Exception:
        pass
    try:
        import openzeppelin
        out["compiler"]["openzeppelin_pkg_path"] = os.path.dirname(os.path.abspath(openzeppelin.__file__))
    except Exception as e:
        out["compiler"]["openzeppelin_pkg_path"] = f"ERR {e}"

    all_ok = True
    for name in wanted:
        cmp_path = os.path.join(args.compiled, f"{name}.json")
        if not os.path.exists(cmp_path):
            out["classes"][name] = {"error": "compiled file missing"}
            all_ok = False
            continue
        rec = {"expected_class_hash": EXPECTED[name]}
        dep = load_json(os.path.join(args.deployed, f"{name}_class_deployed.json.gz"))
        cmp_ = load_json(cmp_path)
        dep_std, cmp_std = to_standard(dep), to_standard(cmp_)

        # program comparison (debug_info stripped - the hash algorithm strips it too)
        dep_prog, cmp_prog = strip_debug(dep_std["program"]), strip_debug(cmp_std["program"])
        rec["program_equal_ignoring_debug_info"] = first_diff(dep_prog, cmp_prog) is None
        if not rec["program_equal_ignoring_debug_info"]:
            rec["program_first_diff"] = first_diff(dep_prog, cmp_prog)
        # normalised comparison (Program schema round-trip, same normalisation the
        # class-hash algorithm applies; cancels RPC serialization whitespace artifacts)
        try:
            dep_norm = normalize_program(dep_std["program"])
            cmp_norm = normalize_program(cmp_std["program"])
            rec["program_equal_normalized"] = first_diff(dep_norm, cmp_norm) is None
            if not rec["program_equal_normalized"]:
                rec["program_first_diff_normalized"] = first_diff(dep_norm, cmp_norm)
        except Exception as e:
            rec["program_equal_normalized"] = None
            rec["normalize_error"] = f"{type(e).__name__}: {str(e)[:200]}"
        rec["debug_info_equal"] = (dep_std["program"].get("debug_info") is None) == \
                                  (cmp_std["program"].get("debug_info") is None)
        rec["entrypoints_equal"] = (dep_std["entry_points_by_type"] == cmp_std["entry_points_by_type"])
        rec["abi_equal"] = (dep_std.get("abi") == cmp_std.get("abi"))
        if not rec["abi_equal"]:
            rec["abi_first_diff"] = first_diff(dep_std.get("abi"), cmp_std.get("abi"))

        dep_hash, dep_err = compute_hash(dep)
        cmp_hash, cmp_err = compute_hash(cmp_)
        rec["deployed_class_hash_computed"] = hex(dep_hash) if dep_hash else None
        rec["deployed_hash_error"] = dep_err
        rec["compiled_class_hash_computed"] = hex(cmp_hash) if cmp_hash else None
        rec["compiled_hash_error"] = cmp_err
        rec["class_hash_match"] = bool(cmp_hash is not None and hex(cmp_hash) == EXPECTED[name])
        rec["deployed_hash_selfconsistent"] = bool(dep_hash is not None and hex(dep_hash) == EXPECTED[name])
        prog_ok = bool(rec["program_equal_ignoring_debug_info"] or rec.get("program_equal_normalized"))
        rec["VERIFIED"] = bool(prog_ok and rec["class_hash_match"] and rec["entrypoints_equal"])
        out["classes"][name] = rec
        if not rec["VERIFIED"]:
            all_ok = False
        print(f"--- {name}: VERIFIED={rec['VERIFIED']} program_eq={rec['program_equal_ignoring_debug_info']} "
              f"program_eq_norm={rec.get('program_equal_normalized')} "
              f"class_hash_match={rec['class_hash_match']} deployed_selfconsistent={rec['deployed_hash_selfconsistent']}",
              flush=True)
        if rec.get("program_first_diff"):
            print("    first program diff:", rec["program_first_diff"], flush=True)
        if not rec["abi_equal"]:
            print("    first abi diff:", rec.get("abi_first_diff"), flush=True)
        if cmp_err:
            print("    compiled hash errs:", cmp_err[:300], flush=True)

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w") as f:
        json.dump(out, f, indent=1)
    print("wrote", args.out, flush=True)
    sys.exit(0 if all_ok else 1)


if __name__ == "__main__":
    main()
