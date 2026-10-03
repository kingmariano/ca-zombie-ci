#!/usr/bin/env python3
"""C-26 on-chain verification: module enabled? delegate permissions? ETH balance?
Read-only. Uses `cast` with BLOCKPI_RPC_URL (or RPC_URL fallback)."""
import json, os, re, subprocess, sys, time

ANALYSIS = os.path.dirname(os.path.abspath(__file__))
RPC = os.environ.get("BLOCKPI_RPC_URL") or os.environ.get("RPC_URL")
MODULE = "0x1f1d37a3Bf840e35c6a860c7C2dA71Fe555123ca"
MODULE_LC = MODULE.lower()
PM = "0x03B8B1bA6B02b8A566cB757DFa627f7198c44cB7"


def cast_call(args):
    for attempt in range(3):
        try:
            p = subprocess.run(["cast", "call"] + args + ["--rpc-url", RPC],
                               capture_output=True, text=True, timeout=45)
            if p.returncode == 0:
                return p.stdout.strip()
            err = p.stderr.strip()
            if "429" in err or "504" in err or "timeout" in err.lower():
                time.sleep(2 + attempt * 3)
                continue
            return "ERR:" + err[:200]
        except Exception as e:
            time.sleep(2)
            last = str(e)
    return "ERR:" + str(locals().get("last", "unknown"))


def is_module_enabled(safe):
    out = cast_call([safe, "isModuleEnabled(address)(bool)", MODULE])
    return out == "true" if out in ("true", "false") else out


def delegators_info(safe):
    """Returns raw text of getAccountDelegatorsInfo output."""
    return cast_call([PM, "getAccountDelegatorsInfo(address)((address,(address,string[])[])[])",
                      safe])


def parse_module_grants(raw, module_lc=MODULE_LC):
    """Extract every (delegate,module,permissions) tuple from cast output text."""
    grants = []
    # pattern: (delegate, [(module, [strings]), (...)])
    # split top-level delegate tuples: each starts with "(0x....., ["
    for m in re.finditer(r"\(0x[0-9a-fA-F]{40}, \[", raw):
        start = m.start() + 1
        # find matching close paren for this delegate tuple
        depth = 0
        i = m.start() + 1
        while i < len(raw):
            c = raw[i]
            if c == "(":
                depth += 1
            elif c == ")":
                if depth == 0:
                    break
                depth -= 1
            i += 1
        body = raw[start:i]
        delegate = body[:42]
        # module entries inside
        for mm in re.finditer(r"\((0x[0-9a-fA-F]{40}), \[([^\]]*)\]\)", body):
            mod = mm.group(1)
            perms = re.findall(r'"([^"]*)"', mm.group(2))
            grants.append({"delegate": delegate, "module": mod, "permissions": perms})
    return grants


def main():
    safes = set()
    cur = json.load(open(os.path.join(ANALYSIS, "safe_tx_service", "safes_current.json")))
    for s in cur:
        safes.add(s)
    victims = json.load(open(os.path.join(ANALYSIS, "attacker_drain_calls.json")))
    victim_set = set()
    for v in victims:
        safes.add(v["safe"])
        victim_set.add(v["safe"])
    safes = sorted(safes)
    print(f"candidate Safes: {len(safes)} (tx-service={len(cur)}, attack-list={len(victim_set)})")

    results = []
    for idx, s in enumerate(safes):
        rec = {"safe": s, "in_attack_list": s in victim_set}
        enabled = is_module_enabled(s)
        rec["module_enabled_now"] = enabled
        raw = delegators_info(s)
        if raw.startswith("ERR:"):
            rec["delegators_error"] = raw
            rec["module_grants"] = []
            rec["drainable_permissions"] = None
        else:
            grants = parse_module_grants(raw)
            mg = [g for g in grants if g["module"].lower() == MODULE_LC]
            rec["module_grants"] = mg
            rec["all_grants_for_module"] = mg
            rec["drainable_permissions"] = sorted({p for g in mg for p in g["permissions"]})
        # ETH balance
        p = subprocess.run(["cast", "balance", s, "--rpc-url", RPC], capture_output=True, text=True)
        rec["eth_wei"] = p.stdout.strip() if p.returncode == 0 else "ERR"
        results.append(rec)
        print(f"[{idx+1}/{len(safes)}] {s} enabled={enabled} grants={len(rec.get('module_grants',[]))} perms={rec.get('drainable_permissions')} eth={rec['eth_wei']}")
        sys.stdout.flush()

    out = os.path.join(ANALYSIS, "safe_verification.json")
    json.dump(results, open(out, "w"), indent=1)
    enabled_and_permitted = [r for r in results if r.get("module_enabled_now") is True and r.get("drainable_permissions")]
    print(f"\nENABLED + PERMISSIONED: {len(enabled_and_permitted)}")
    for r in enabled_and_permitted:
        print(r["safe"], r["drainable_permissions"], "ETH_wei=" + str(r["eth_wei"]))
    json.dump(enabled_and_permitted, open(os.path.join(ANALYSIS, "drainable_now.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
