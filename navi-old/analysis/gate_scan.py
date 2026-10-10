#!/usr/bin/env python3
"""Static version-gate analysis for NAVI Sui packages.

Parses Move bytecode disassemblies fetched into analysis/raw/modules_all/
(main lineage vN/, oracle/vN/, lineage_c/vN/) and, per package version:
  - builds a same-package call graph,
  - marks functions transitively reaching a version gate
    (any *::version_verification / *::pre_check_version, inline LdConst
    equality on a `version: u64` field, or external oracle::version_verification),
  - lists PUBLIC/ENTRY functions that are NOT transitively gated,
  - flags ungated functions performing value-moving calls,
  - flags ungated functions transferring/returning Coin/Balance.

Outputs: gate-analysis.json and gate-analysis.md next to this script.
No network access, no secrets. Read-only wrt chain state.
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
MODROOT = os.path.join(RAW, "modules_all")

LINEAGES = [
    ("main", MODROOT, "versions"),
    ("oracle", os.path.join(MODROOT, "oracle"), "oracle"),
    ("lineage_c", os.path.join(MODROOT, "lineage_c"), "lineage_c"),
]

GATE_FUNC_NAMES = {"version_verification", "pre_check_version"}

# value-moving external calls (module, function) exactly as specified
VALUE_CALLS = {
    ("coin", "from_balance"), ("coin", "take"), ("coin", "split"),
    ("coin", "divide_into_n"), ("balance", "split"), ("balance", "withdraw"),
    ("balance", "decrease_supply"), ("transfer", "public_transfer"),
    ("transfer", "transfer"), ("transfer", "public_share_object"),
    ("balance", "join"), ("coin", "transfer"),
}
# broader movement set used only for reporting extra observations
VALUE_CALLS_BROAD = VALUE_CALLS | {
    ("coin", "put"), ("coin", "join"), ("coin", "into_balance"),
    ("coin", "zero"), ("balance", "into_coin"), ("coin", "destroy_zero"),
    ("balance", "destroy_zero"), ("coin", "mint"), ("coin", "burn"),
}

CALL_RE = re.compile(r"\bCall\s+([A-Za-z0-9_]+(?:::[A-Za-z0-9_]+)*)\s*(<[^(]*>)?\s*\(")
FUNC_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*(<.*?>)?\s*\((.*)\)\s*(?::\s*(.*))?$")
USE_RE = re.compile(r"^use\s+([0-9a-fA-Fx]+)::([A-Za-z_][A-Za-z0-9_]*)(?:\s+as\s+([A-Za-z_][A-Za-z0-9_]*))?;")
MOD_RE = re.compile(r"^module\s+([0-9a-fA-Fx]+)\.([A-Za-z_][A-Za-z0-9_]*)\s*\{")
LDCONST_U64_RE = re.compile(r"LdConst\[\d+\]\(u64:\s*(\d+)\)")
LDU64_RE = re.compile(r"LdU64\((\d+)\)")
PREFIXES = [
    ("entry ", "entry"),
    ("public(friend) ", "friend"),
    ("public(package) ", "package"),
    ("public ", "public"),
    ("private ", "private"),
    ("friend ", "friend"),
]


def norm_addr(a):
    a = a.lower()
    if a.startswith("0x"):
        a = a[2:]
    return a.rjust(64, "0")


def parse_header(line):
    s = line.rstrip()
    if not s.endswith("{") or s.startswith(("//", "use ", "friend ", "struct ", "enum ")):
        return None
    s = s[:-1].rstrip()
    if "(" not in s:
        return None
    vis, entry = [], False
    changed = True
    while changed:
        changed = False
        for pref, tag in PREFIXES:
            if s.startswith(pref):
                if tag == "entry":
                    entry = True
                else:
                    vis.append(tag)
                s = s[len(pref):]
                changed = True
                break
    m = FUNC_RE.match(s)
    if not m:
        return None
    return {
        "name": m.group(1),
        "generics": m.group(2) or "",
        "args": m.group(3),
        "ret": (m.group(4) or "").strip(),
        "vis": vis,
        "entry": entry,
    }


def parse_module(dis, modname):
    """Return dict: self_addr, uses {alias: addr}, funcs [ {name, vis, entry, ret,
    body, internal_calls [(mod,fn)], external_calls [(mod,fn)], call_generics [(mod,fn,gens)],
    inline_gate_value} ]"""
    out = {"self_addr": None, "uses": {}, "funcs": []}
    lines = dis.splitlines()
    for line in lines[:40]:
        m = MOD_RE.match(line)
        if m:
            out["self_addr"] = norm_addr(m.group(1))
            break
    for line in lines:
        m = USE_RE.match(line)
        if m:
            out["uses"][m.group(3) or m.group(2)] = norm_addr(m.group(1))
        elif line.startswith("use ") and " as " not in line:
            pass
    # split functions
    i = 0
    while i < len(lines):
        h = parse_header(lines[i])
        if h:
            body = []
            j = i + 1
            while j < len(lines) and lines[j].rstrip() != "}":
                body.append(lines[j])
                j += 1
            h["body"] = body
            out["funcs"].append(h)
            i = j + 1
        else:
            i += 1
    # resolve calls + inline gates
    for f in out["funcs"]:
        internal, external, gens = [], [], []
        instrs = [l for l in f["body"] if re.match(r"^\s*\d+:", l)]
        for l in f["body"]:
            m = CALL_RE.search(l)
            if m:
                target = m.group(1)
                parts = target.split("::")
                gen = (m.group(2) or "")
                if len(parts) == 1:
                    internal.append((modname, parts[0]))
                elif len(parts) == 2:
                    alias, fn = parts
                    addr = out["uses"].get(alias)
                    if addr is not None and addr == out["self_addr"]:
                        internal.append((alias, fn))
                    else:
                        external.append((alias, fn))
                elif len(parts) == 3:
                    addr, mod, fn = parts
                    if norm_addr(addr) == out["self_addr"]:
                        internal.append((mod, fn))
                    else:
                        external.append((mod, fn))
                gens.append((target, gen))
        f["internal_calls"] = internal
        f["external_calls"] = external
        f["call_generics"] = gens
        # immediate-abort stub: deprecated entry points that abort unconditionally
        f["abort_stub"] = (len(instrs) == 2
                           and bool(re.match(r"^\s*\d+:\s*Ld(U64|Const)", instrs[0]))
                           and instrs[1].strip().endswith("Abort"))
        # inline version gate: field read of `version: u64` then LdConst u64 then Eq
        f["inline_gate_value"] = None
        for idx, l in enumerate(instrs):
            if re.search(r"\bversion:\s*u64", l):
                win = instrs[idx + 1: idx + 6]
                for k, w in enumerate(win):
                    vm = LDCONST_U64_RE.search(w)
                    if vm:
                        tail = " ".join(win[k + 1: k + 3])
                        if "Eq" in tail:
                            f["inline_gate_value"] = int(vm.group(1))
                        break
                if f["inline_gate_value"] is not None:
                    break
    return out


def scan_version(version_dir, lineage, version, package_address):
    mods_path = os.path.join(version_dir, "_modules.json")
    with open(mods_path) as fh:
        md = json.load(fh)
    module_names = [m["name"] for m in md["data"]["package"]["modules"]["nodes"]]
    modules = {}
    for name in module_names:
        p = os.path.join(version_dir, name + ".json")
        if not os.path.exists(p):
            continue
        with open(p) as fh:
            d = json.load(fh)
        dis = d["data"]["package"]["module"]["disassembly"]
        modules[name] = parse_module(dis, name)

    func_index = {}  # (mod, fn) -> func dict
    for mod, m in modules.items():
        for f in m["funcs"]:
            func_index[(mod, f["name"])] = f

    # gate roots
    gate_roots = set()
    for key, f in func_index.items():
        if f["name"] in GATE_FUNC_NAMES or f["inline_gate_value"] is not None:
            gate_roots.add(key)

    # closure within package
    gated = set(gate_roots)
    changed = True
    while changed:
        changed = False
        for key, f in func_index.items():
            if key in gated:
                continue
            hit = False
            for c in f["internal_calls"]:
                if c in gated:
                    hit = True
                    break
            if not hit:
                for (mod, fn) in f["external_calls"]:
                    if fn in GATE_FUNC_NAMES:
                        hit = True
                        break
            if hit:
                gated.add(key)
                changed = True

    # public/entry surface
    def is_public_entry(f):
        v = f["vis"]
        return (("public" in v) or f["entry"]) and ("friend" not in v) and ("package" not in v)

    pub_entry, ungated_pub_entry = [], []
    ungated_pub_entry_stubs, ungated_pub_entry_nonstub = [], []
    ungated_pub_entry_state_touching = []
    ungated_value_moving, ungated_coin_balance = [], []
    for key, f in sorted(func_index.items()):
        mod, fn = key
        if is_public_entry(f):
            pub_entry.append(f"{mod}::{fn}")
            if key not in gated:
                ungated_pub_entry.append(f"{mod}::{fn}")
                if f["abort_stub"]:
                    ungated_pub_entry_stubs.append(f"{mod}::{fn}")
                else:
                    ungated_pub_entry_nonstub.append(f"{mod}::{fn}")
                    if "&mut" in f["args"]:
                        ungated_pub_entry_state_touching.append(f"{mod}::{fn}")
        if key in gated:
            continue
        ext = {(m, n) for (m, n) in f["external_calls"]}
        vc = sorted(ext & VALUE_CALLS)
        vcb = sorted(ext & VALUE_CALLS_BROAD)
        caps = sorted(set(re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*Cap)\b", f["args"])))
        transfer_cb = False
        for (target, gen) in f["call_generics"]:
            parts = target.split("::")
            if len(parts) >= 2 and parts[-2:] == ["transfer", "public_transfer"] or \
               (len(parts) >= 2 and parts[-1] in ("public_transfer", "transfer", "public_share_object")
                    and parts[-2] == "transfer"):
                if "Coin" in gen or "Balance" in gen:
                    transfer_cb = True
        ret_cb = ("Coin" in f["ret"]) or ("Balance" in f["ret"])
        if vc:
            ungated_value_moving.append({
                "function": f"{mod}::{fn}",
                "visibility": "|".join(f["vis"]) or "private",
                "entry": f["entry"],
                "abort_stub": f["abort_stub"],
                "args": f["args"],
                "capability_args": caps,
                "value_calls": [f"{m}::{n}" for (m, n) in vc],
                "also_broad_value_calls": [f"{m}::{n}" for (m, n) in vcb if (m, n) not in vc],
                "returns_coin_balance": ret_cb,
                "transfer_coin_balance": transfer_cb,
            })
        if transfer_cb or ret_cb:
            if transfer_cb or ret_cb:
                ungated_coin_balance.append({
                    "function": f"{mod}::{fn}",
                    "visibility": "|".join(f["vis"]) or "private",
                    "entry": f["entry"],
                    "abort_stub": f["abort_stub"],
                    "args": f["args"],
                    "capability_args": caps,
                    "transfer_public_transfer_coin_balance": transfer_cb,
                    "returns_coin_balance": ret_cb,
                })

    # gate classification / expected value
    gate_type, gate_expected = "none", None
    # constants-style gate: any module defines pre_check_version that calls M::version()
    for key, f in func_index.items():
        if f["name"] != "pre_check_version":
            continue
        for (cm, cf) in f["internal_calls"]:
            if cf == "version":
                g = func_index.get((cm, cf))
                if g:
                    body = " ".join(g["body"])
                    m = LDU64_RE.search(body) or LDCONST_U64_RE.search(body)
                    if m:
                        gate_type, gate_expected = "constants", int(m.group(1))
        if gate_type != "none":
            break
    if gate_type == "none":
        sv = func_index.get(("storage", "version_verification"))
        if sv and sv["inline_gate_value"] is not None:
            gate_type, gate_expected = "inline", sv["inline_gate_value"]
        else:
            inline_vals = [f["inline_gate_value"] for k, f in func_index.items()
                           if f["inline_gate_value"] is not None]
            if inline_vals:
                gate_type, gate_expected = "inline", sorted(set(inline_vals))[0]

    inline_gate_funcs = sorted(f"{key[0]}::{f['name']}" for key, f in func_index.items()
                               if f["inline_gate_value"] is not None)
    return {
        "lineage": lineage,
        "version": version,
        "package_address": package_address,
        "gate_type": gate_type,
        "gate_expected": gate_expected,
        "module_count": len(module_names),
        "public_entry_functions": pub_entry,
        "public_entry_count": len(pub_entry),
        "ungated_public_entry_functions": ungated_pub_entry,
        "ungated_public_entry_stubs": ungated_pub_entry_stubs,
        "ungated_public_entry_non_stub": ungated_pub_entry_nonstub,
        "ungated_public_entry_state_touching": ungated_pub_entry_state_touching,
        "ungated_value_moving": ungated_value_moving,
        "ungated_coin_balance_transfer_or_return": ungated_coin_balance,
        "inline_gate_functions": inline_gate_funcs,
    }


def load_lineage(name, root, key):
    vpath = os.path.join(root, "_versions.json")
    with open(vpath) as fh:
        d = json.load(fh)
    nodes = sorted(d["data"]["packageVersions"]["nodes"], key=lambda x: x["version"])
    out = []
    for n in nodes:
        vdir = os.path.join(root, f"v{n['version']}")
        if not os.path.isdir(vdir):
            print(f"WARN: missing {vdir}", file=sys.stderr)
            continue
        try:
            out.append(scan_version(vdir, name, n["version"], n["address"]))
        except Exception as e:
            print(f"ERROR scanning {name} v{n['version']}: {e}", file=sys.stderr)
            raise
        print(f"scanned {name} v{n['version']}: gate={out[-1]['gate_type']}"
              f" expected={out[-1]['gate_expected']}"
              f" ungated_pub_entry={len(out[-1]['ungated_public_entry_functions'])}"
              f" ungated_vm={len(out[-1]['ungated_value_moving'])}", flush=True)
    return out


EXPECTED_MAIN = {1: 2, 2: 2, 3: 3, 4: 3, 5: 3, 6: 5, 7: 5, 8: 5, 9: 6, 10: 6, 11: 6,
                 12: 6, 13: 6, 14: 7, 15: 8, 16: 8, 17: 9, 18: 10, 19: 10, 20: 11,
                 21: 12, 22: 13, 23: 14, 24: 15, 25: 15, 26: 16}


def main():
    results = {"versions": [], "oracle": [], "lineage_c": [], "notes": []}
    by_lineage = {}
    for name, root, key in LINEAGES:
        if not os.path.exists(os.path.join(root, "_versions.json")):
            results["notes"].append(f"{name}: no raw data at {root}, skipped")
            continue
        res = load_lineage(name, root, key)
        results[key] = res
        by_lineage[name] = res

    # sanity checks on known cases
    checks = []
    mainv = {r["version"]: r for r in results["versions"]}
    r26, r9 = mainv.get(26), mainv.get(9)
    if r26:
        # explicit edge check: storage::version_verification calls version::pre_check_version
        edge26 = False
        try:
            with open(os.path.join(MODROOT, "v26", "storage.json")) as fh:
                dis = json.load(fh)["data"]["package"]["module"]["disassembly"]
            i = dis.find("public version_verification(")
            seg = dis[i:i + 500]
            j = seg.find("\n}")
            edge26 = "version::pre_check_version" in (seg[:j] if j > 0 else seg)
        except Exception:
            pass
        v26_ok = edge26 and \
                 ("storage::version_verification" not in r26["ungated_public_entry_functions"]) and \
                 ("storage::version_verification" not in [x["function"] for x in r26["ungated_value_moving"]])
        checks.append(("v26 storage::version_verification transitively gated (calls version::pre_check_version)", bool(v26_ok)))
    if r9:
        inline_ok = r9["gate_type"] == "inline" and r9["gate_expected"] == 6 and \
                    "storage::version_verification" in r9["inline_gate_functions"]
        checks.append(("v9 storage::version_verification is inline gate with LdConst 6", bool(inline_ok)))
        cr = "incentive_v2::claim_reward"
        gated9 = cr not in r9["ungated_public_entry_functions"] and cr not in [x["function"] for x in r9["ungated_value_moving"]]
        # confirm the call edge exists
        edge = False
        try:
            p = os.path.join(MODROOT, "v9", "incentive_v2.json")
            with open(p) as fh:
                dis = json.load(fh)["data"]["package"]["module"]["disassembly"]
            i = dis.find("claim_reward")
            seg = dis[i:i + 3000]
            j = seg.find("}\n")
            edge = "version_verification" in seg[:j if j > 0 else 3000]
        except Exception:
            pass
        checks.append(("v9 incentive_v2::claim_reward calls version_verification and is gated", bool(gated9 and edge)))

    # cross-check expected gate values
    mismatches = []
    for r in results["versions"]:
        exp = EXPECTED_MAIN.get(r["version"])
        if exp is not None and r["gate_expected"] != exp:
            mismatches.append(f"main v{r['version']}: parsed expected={r['gate_expected']} vs known {exp}")

    notes = results["notes"]
    notes.append("Gate roots: functions named version_verification/pre_check_version (any module, internal or external call), "
                 "plus functions with an inline `version: u64` LdConst+Eq check. Transitive closure computed over same-package calls.")
    notes.append("External gate calls (e.g. oracle::version_verification) count as gates per task definition, even though they "
                 "verify the oracle object's version rather than Storage.version.")
    notes.append("ungated_value_moving includes ungated functions of any visibility (each entry records visibility/entry); "
                 "ungated public/entry surface is listed separately.")
    notes.append("Immediate-abort deprecation stubs (bytecode shape `LdU64(..); Abort`) are flagged per function "
                 "(`abort_stub`); they cannot move value. `ungated_public_entry_stubs` / `ungated_public_entry_non_stub` split the "
                 "ungated public/entry surface accordingly.")
    notes.append("Module lists were fetched with explicit pagination (first: 50 + cursor): the public endpoint's default page size "
                 "is 20 and silently truncates packages with more than 20 modules.")
    notes.append("Live-object context (checked via public GraphQL): Storage / IncentiveV2 / IncentiveV3 all have version field = 16; "
                 "the legacy d899...::incentive::Incentive object 0xaaf735bf83ff564e1b219a0d644de894ef5bdc4b2250b126b2a46dd002331821 "
                 "still exists and has no version field, so incentive::claim_reward cannot be version-gated.")
    for name, ok in checks:
        notes.append(f"SANITY CHECK {'PASS' if ok else 'FAIL'}: {name}")
    if mismatches:
        notes += ["GATE VALUE MISMATCH vs parent-known values:"] + mismatches
    else:
        notes.append("All parsed main-lineage gate_expected values match the known v1..v26 mapping.")

    out_json = os.path.join(HERE, "gate-analysis.json")
    with open(out_json, "w") as fh:
        json.dump(results, fh, indent=1)
    print("wrote", out_json)
    for name, ok in checks:
        print(("PASS" if ok else "FAIL"), "-", name)
    print("mismatches:", mismatches or "none")

    write_md(results, checks)
    return results


def short(addr):
    return addr[:10] + "..." + addr[-6:] if addr else "?"


def compact_versions(versions):
    """[1,2,3,5] -> 'v1–v3, v5' (duplicates tolerated)."""
    out, start, prev = [], None, None
    for v in sorted(set(versions)):
        if start is None:
            start = prev = v
        elif v == prev + 1:
            prev = v
        else:
            out.append((start, prev))
            start = prev = v
    if start is not None:
        out.append((start, prev))
    return ", ".join(f"v{a}" if a == b else f"v{a}–v{b}" for a, b in out)


def group_by_function(results, picker):
    """Group per-version entries by function signature; returns {key: {lineage: [versions]}}."""
    groups = {}
    for key in ("versions", "oracle", "lineage_c"):
        for r in results.get(key) or []:
            for x in picker(r):
                gk = (x["function"], x["visibility"], x["entry"],
                      tuple(x.get("value_calls") or []), tuple(x.get("capability_args") or []),
                      bool(x.get("returns_coin_balance")),
                      bool(x.get("transfer_coin_balance")),
                      bool(x.get("transfer_public_transfer_coin_balance")),
                      bool(x.get("abort_stub")))
                groups.setdefault(gk, {}).setdefault(r["lineage"], []).append(r["version"])
    return groups


def present_in(per):
    return "; ".join(f"{lin} {compact_versions(vs)}" for lin, vs in sorted(per.items()))


def write_md(results, checks):
    lines = []
    lines.append("# NAVI Sui — version-gate analysis (all package versions)")
    lines.append("")
    lines.append("Static analysis of Move bytecode disassembly fetched from the public Sui mainnet GraphQL endpoint. "
                 "For every published version of the main lending lineage, the oracle lineage and lineage C, the same-package "
                 "call graph was built and each function was checked for a transitive version-gate check "
                 "(`*::version_verification` / `version::pre_check_version` / inline `version: u64` LdConst+Eq). "
                 "See `gate_scan.py` and `gate-analysis.json` for raw detail.")
    lines.append("")
    live = ("Live objects today: Storage `0xbb4e...42fe` version=16, IncentiveV2 `0xf87a...559c` version=16, "
            "IncentiveV3 `0x6298...6c80` version=16.")
    lines.append(live)
    lines.append("")
    for title, key in [("Main lending lineage", "versions"), ("Oracle lineage", "oracle"), ("Lineage C", "lineage_c")]:
        res = results.get(key) or []
        if not res:
            continue
        lines.append(f"## {title}")
        lines.append("")
        lines.append("| v | package | gate | expected | modules | pub/entry | ungated pub/entry | of which stubs | ungated value-moving |")
        lines.append("|---|---------|------|----------|---------|-----------|-------------------|----------------|----------------------|")
        for r in res:
            lines.append(f"| {r['version']} | `{short(r['package_address'])}` | {r['gate_type']} | "
                         f"{r['gate_expected'] if r['gate_expected'] is not None else '—'} | {r['module_count']} | "
                         f"{r['public_entry_count']} | {len(r['ungated_public_entry_functions'])} | "
                         f"{len(r.get('ungated_public_entry_stubs', []))} | {len(r['ungated_value_moving'])} |")
        lines.append("")
    # complete list of ungated value-moving functions (grouped by function, all versions covered)
    lines.append("## Ungated value-moving functions (complete list, all lineages)")
    lines.append("")
    lines.append("Grouped by function signature; every scanned version that contains the function is listed. "
                 "Entries of any visibility are shown (friend/private ones are not externally callable).")
    lines.append("")
    vm_groups = group_by_function(results, lambda r: r["ungated_value_moving"])
    if not vm_groups:
        lines.append("- **None found.**")
    for gk, per in sorted(vm_groups.items(), key=lambda kv: kv[0][0]):
        fn, vis, entry, vc, caps, ret, tcb, _pcb, _stub = gk
        extra = ""
        if ret:
            extra += "; returns Coin/Balance"
        if tcb:
            extra += "; transfer::public_transfer on Coin/Balance"
        lines.append(f"- `{fn}` — visibility: {vis}, entry: {'yes' if entry else 'no'}; value calls: {', '.join(vc)}; "
                     f"capability args: {', '.join(caps) or 'none'}{extra} — present in: {present_in(per)}")
    lines.append("")
    # ungated public/entry surface (state-touching, non-stub; full lists in JSON)
    lines.append("## Ungated public/entry functions that mutate state (non-stub, `&mut` args)")
    lines.append("")
    lines.append("Full ungated public/entry lists (including read-only getters and immediate-abort stubs) are in "
                 "`gate-analysis.json` per version. Below: ungated, non-stub public/entry functions that take at least one "
                 "`&mut` argument, grouped by function.")
    lines.append("")
    st_groups = group_by_function(results, lambda r: [
        {"function": x, "visibility": "", "entry": True} for x in (r.get("ungated_public_entry_state_touching") or [])
    ])
    if not st_groups:
        lines.append("- None: every state-mutating public/entry function in every scanned version is transitively gated.")
    for gk, per in sorted(st_groups.items(), key=lambda kv: kv[0][0]):
        lines.append(f"- `{gk[0]}` — present in: {present_in(per)}")
    lines.append("")
    # coin/balance transfer-or-return flags
    lines.append("## Ungated Coin/Balance transfer-or-return flags")
    lines.append("")
    cb_groups = group_by_function(results, lambda r: r["ungated_coin_balance_transfer_or_return"])
    if not cb_groups:
        lines.append("- None: no ungated function transfers Coin/Balance via transfer::public_transfer or returns Coin/Balance.")
    for gk, per in sorted(cb_groups.items(), key=lambda kv: kv[0][0]):
        fn, vis, entry, _vc, caps, ret, _tcb, pcb, _stub = gk
        lines.append(f"- `{fn}` — visibility: {vis}, entry: {'yes' if entry else 'no'}; "
                     f"transfer::public_transfer on Coin/Balance: {'yes' if pcb else 'no'}; "
                     f"returns Coin/Balance: {'yes' if ret else 'no'}; capability args: {', '.join(caps) or 'none'} — "
                     f"present in: {present_in(per)}")
    lines.append("")
    lines.append("## Sanity checks")
    lines.append("")
    for name, ok in checks:
        lines.append(f"- {'PASS' if ok else 'FAIL'}: {name}")
    lines.append("")
    # assessment
    all_res = [r for k in ("versions", "oracle", "lineage_c") for r in results.get(k) or []]
    vm_total = sum(len(r["ungated_value_moving"]) for r in all_res)
    pe_total = sum(len(r["ungated_public_entry_functions"]) for r in all_res)
    stub_total = sum(len(r.get("ungated_public_entry_stubs", [])) for r in all_res)
    nocap = {}
    for r in all_res:
        for x in list(r["ungated_value_moving"]) + list(r["ungated_coin_balance_transfer_or_return"]):
            ext_callable = x["entry"] or ("public" in x["visibility"] and "friend" not in x["visibility"])
            if not x.get("capability_args") and not x.get("abort_stub") and ext_callable:
                nocap.setdefault(x["function"], {}).setdefault(r["lineage"], []).append(r["version"])
    lines.append("## Reachability context (verified live via public Sui GraphQL)")
    lines.append("")
    lines.append("- Live Storage object `0xbb4e...42fe` type `d899...::storage::Storage`, version field = **16**.")
    lines.append("- Live IncentiveV2 object `0xf87a...559c` type `e66f07e2...::incentive_v2::Incentive` (defining pkg = main v9), version field = **16**.")
    lines.append("- Live IncentiveV3 object `0x6298...6c80` type `81c40844...::incentive_v3::Incentive` (defining pkg = main v22), version field = **16**.")
    lines.append("- Legacy `d899...::incentive::Incentive` object `0xaaf735bf...` still exists and has **no version field** "
                 "(fields: creator/owners/admins/pools/assets), so no version gate is possible on it; `incentive::claim_reward` "
                 "operates on it ungated in every version, including current v26.")
    lines.append("- Old package versions remain callable on Sui (each version keeps its own package ID); their gate aborts when "
                 "the live object's version field != the version expected by that package.")
    lines.append("")
    lines.append("## Assessment")
    lines.append("")
    lines.append(f"Scanned {len(all_res)} package versions: {vm_total} ungated value-moving function entries "
                 f"({len(nocap)} distinct names without any capability argument), {pe_total} ungated public/entry functions of "
                 f"which {stub_total} are immediate-abort deprecation stubs (inert: they abort unconditionally).")
    lines.append("")
    if nocap:
        lines.append("Ungated, externally-callable value-moving paths with NO capability argument:")
        for fn, per in sorted(nocap.items()):
            lines.append(f"- `{fn}` — present in: {present_in(per)}")
        lines.append("")
    lines.append("(Private/friend no-capability helpers such as `pool::withdraw`, `pool::deposit_balance`, "
                 "`incentive::base_claim_reward`, `incentive_v3::deposit_borrow_fee` are not externally callable; they are "
                 "reachable only from within the package, i.e. through the gated entry paths. The full list is in the "
                 "value-moving section above.)")
    lines.append("")
    lines.append("**Bottom line:** No old package version exposes an ungated value-moving path that the current version does not "
                 "also expose: every value-moving entry that touches the versioned live objects (Storage / IncentiveV2 / IncentiveV3, "
                 "all at version=16) is transitively gated in every old version and aborts on the version check; the remaining "
                 "ungated, externally-callable value movers are the legacy v1-incentive claim family "
                 "(`incentive::claim_reward`, `claim_reward_non_entry`, `claim_reward_with_account_cap` — the latter "
                 "requiring only the user's own AccountCap; all ungated in the current v26 too because the legacy "
                 "`incentive::Incentive` object has no version field), the caller's-own-coin helpers "
                 "`utils::split_coin` / `split_coin_to_balance`, and the vSUI redemption `pool::unstake_vsui` (unversioned "
                 "`Pool<SUI>` / staking objects; user provides their own CERT coin); everything else is either an immediate-abort "
                 "stub or capability-gated (protocol-held `OwnerCap` / `StorageAdminCap` / `PoolAdminCap`).")
    lines.append("")
    with open(os.path.join(HERE, "gate-analysis.md"), "w") as fh:
        fh.write("\n".join(lines))
    print("wrote", os.path.join(HERE, "gate-analysis.md"))


if __name__ == "__main__":
    main()
