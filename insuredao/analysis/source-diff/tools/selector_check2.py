#!/usr/bin/env python3
"""Robust function signature extractor + selector comparison."""
import re, subprocess, json

SRC = "/home/heisenberg/CA/insuredao/analysis/sources/impl_open"
BYTECODE = "/home/heisenberg/CA/insuredao/analysis/source-diff/deployed_PoolTemplate_bytecode.hex"

def sel(sig):
    return subprocess.check_output(["cast", "sig", sig]).decode().strip()

def strip_comments(txt):
    txt = re.sub(r"/\*.*?\*/", "", txt, flags=re.S)
    txt = re.sub(r"//[^\n]*", "", txt)
    return txt

def extract(path):
    txt = strip_comments(open(path).read())
    out = []
    for m in re.finditer(r"function\s+([A-Za-z0-9_]+)\s*\(", txt):
        name = m.group(1)
        i = m.end()  # after '('
        depth = 1
        while i < len(txt) and depth:
            if txt[i] == "(": depth += 1
            elif txt[i] == ")": depth -= 1
            i += 1
        args = txt[m.end():i-1]
        # read rest of declaration until '{' or ';'
        j = i
        while j < len(txt) and txt[j] not in "{;":
            j += 1
        rest = txt[i:j]
        if "internal" in rest or "private" in rest:
            continue
        if "external" not in rest and "public" not in rest:
            continue
        args = re.sub(r"\b(memory|calldata|storage)\b", "", args)
        args = re.sub(r"\s+", " ", args).strip()
        types = []
        if args:
            depth = 0; cur = ""
            for ch in args:
                if ch == "," and depth == 0:
                    types.append(cur); cur = ""
                else:
                    if ch in "([": depth += 1
                    if ch in ")]": depth -= 1
                    cur += ch
            types.append(cur)
        norm = []
        for t in types:
            t = t.strip()
            if not t: continue
            parts = t.split()
            if len(parts) >= 2 and re.match(r"^[A-Za-z_]\w*$", parts[-1]) and "[" not in parts[-1]:
                parts = parts[:-1]
            # handle arrays with names: uint256[] xs -> uint256[]
            norm.append("".join(parts))
        out.append(f"{name}({','.join(norm)})")
    return sorted(set(out))

files = ["PoolTemplate.sol", "InsureDAOERC20.sol"]
allf = []
for f in files:
    fs = extract(f"{SRC}/{f}")
    allf += fs
    print(f"== {f}: {len(fs)} functions")
    print(" ", ", ".join(fs))
allf = sorted(set(allf))

bc = open(BYTECODE).read().strip().lstrip("0x").lower()
disp = set(re.findall(r"63([0-9a-f]{8})14", bc))
sig2sel = {}
for s in allf:
    try: sig2sel[s] = sel(s)[2:].lower()
    except Exception as e: print("SIGFAIL", s, e)

missing = [ (s,h) for s,h in sig2sel.items() if h not in bc ]
not_in_disp = [ (s,h) for s,h in sig2sel.items() if h not in disp ]
extra = sorted(d for d in disp if d not in set(sig2sel.values()))
print(json.dumps({
 "n_source_funcs": len(allf),
 "n_dispatcher": len(disp),
 "source_missing_from_bytecode": missing,
 "source_missing_from_dispatcher": not_in_disp,
 "dispatcher_not_in_source": extra,
}, indent=1))
json.dump({"source_functions": allf, "missing_from_bytecode": missing,
           "missing_from_dispatcher": not_in_disp, "dispatcher_not_in_source": extra,
           "dispatcher_selectors": sorted(disp)},
          open("/home/heisenberg/CA/insuredao/analysis/source-diff/selector-check-PoolTemplate.json","w"), indent=1)
