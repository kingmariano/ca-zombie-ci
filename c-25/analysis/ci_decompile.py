#!/usr/bin/env python3
"""C-25 CI heavy job: decompile unverified impls + static token-pull reachability.

Runs inside GitHub Actions (or locally). Downloads runtime bytecode from an RPC,
then:
  1. evmole  -> function selectors, argument types, state mutability
  2. panoramix (if installed) -> decompiled pseudo-Solidity
  3. custom static scan -> locate PUSH4 transferFrom (0x23b872dd) / approve /
     CALL sites per function and classify reachable token pulls
  4. emit JSON + text report into ci-out/
"""
import json, os, re, subprocess, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "ci-out")
os.makedirs(OUT, exist_ok=True)

IMPLS = {
    "proxy":          "0xeEeEEe53033F7227d488ae83a27Bc9A9D5051756",
    "impl_rfq":       "0x88eb28009351Fb414A5746F5d8CA91cdc02760d8",
    "impl_owner":     "0x88099Fcf6aCdcf530607874452e7Ef6FaDcef2eB",
    "impl_registry":  "0x6831d0e09460e123f80219e0cdf11ffef99b89c1",
    "impl_A_5142":    "0x51429f2e88533de64d86fb86edabadac962c1743",
    "impl_B_1dfc":    "0x1dfc3511870a95808e691d497715f976e323d488",
    "impl_C_1be2":    "0x001be28e789a3fb98e00b357d2ebecf2cf036b52",
    "impl_D_c971":    "0xc971d92033124d299498a06fa5e03f7b0a1d35b9",
    "impl_rfq_old":   "0x626784d4af1e8d37b13b42f5fd2c9959c1711952",
}

def rpcs():
    envs = ["NODEREAL_ETH_RPC_URL", "BLOCKPI_RPC_URL", "RPC_URL", "FORK_RPC_URL",
            "DRPC_RPC_URL", "ANKR_RPC_URL", "INFURA_RPC_URL"]
    seen = []
    for e in envs:
        v = os.environ.get(e)
        if v and v not in seen:
            seen.append(v)
    for u in ["https://ethereum-rpc.publicnode.com", "https://eth.drpc.org", "https://1rpc.io/eth"]:
        if u not in seen:
            seen.append(u)
    return seen

def get_code(addr):
    payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_getCode",
                          "params": [addr, "latest"]}).encode()
    last = None
    for url in rpcs():
        for a in range(2):
            try:
                req = urllib.request.Request(url, data=payload,
                                             headers={"Content-Type": "application/json",
                                                      "User-Agent": "c25-ci"})
                with urllib.request.urlopen(req, timeout=45) as r:
                    o = json.loads(r.read().decode())
                if "result" in o and o["result"] and o["result"] != "0x":
                    return o["result"], url
            except Exception as e:
                last = str(e)
                time.sleep(1)
    raise RuntimeError(f"could not fetch code for {addr}: {last}")

def evmole_analyze(code):
    try:
        import evmole  # type: ignore
    except Exception as e:
        return {"available": False, "error": str(e)}
    out = {"available": True}
    try:
        sels = evmole.function_selector(code)
        out["selectors"] = sorted(set(sels))
    except Exception as e:
        out["selectors_error"] = str(e)
    try:
        res = {}
        for s in (out.get("selectors") or []):
            info = {}
            try:
                info["args"] = evmole.function_arguments(code, s)
            except Exception:
                pass
            try:
                info["state_mutability"] = evmole.function_state_mutability(code, s)
            except Exception:
                pass
            res[s] = info
        out["functions"] = res
    except Exception as e:
        out["functions_error"] = str(e)
    return out

def panoramix(hexcode, name):
    """Best-effort decompile. Returns text or error string."""
    for cmd in (["python3", "-m", "panoramix", hexcode],
                ["panoramix", hexcode]):
        try:
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
            if p.returncode == 0 and p.stdout.strip():
                return p.stdout
        except Exception:
            continue
    return None

# --- custom static scan -----------------------------------------------------
OPS_PUSH4 = 0x63
TRANSFER_FROM = "23b872dd"
APPROVE = "095ea7b3"
CALL = 0xf1
DELEGATECALL = 0xf4
STATICCALL = 0xfa

def static_scan(hexcode):
    b = bytes.fromhex(hexcode[2:])
    findings = {"transferFrom_refs": [], "approve_refs": [], "calls": 0, "delegatecalls": 0,
                "staticcalls": 0, "selector_jump_table_pushes": []}
    i = 0
    while i < len(b):
        op = b[i]
        if op == OPS_PUSH4:
            v = b[i+1:i+5].hex()
            if v == TRANSFER_FROM:
                findings["transferFrom_refs"].append(i)
            elif v == APPROVE:
                findings["approve_refs"].append(i)
            i += 5
        elif 0x60 <= op <= 0x7f:
            i += 1 + (op - 0x5f)
        else:
            if op == CALL: findings["calls"] += 1
            elif op == DELEGATECALL: findings["delegatecalls"] += 1
            elif op == STATICCALL: findings["staticcalls"] += 1
            i += 1
    # window around each transferFrom ref: check for nearby DELEGATECALL-less CALL to token
    windows = []
    for pos in findings["transferFrom_refs"]:
        lo = max(0, pos - 300)
        hi = min(len(b), pos + 300)
        windows.append(b[lo:hi].hex())
    findings["transferFrom_windows"] = windows
    return findings

def main():
    report = {"implements": {}, "notes": []}
    codes = {}
    for name, addr in IMPLS.items():
        try:
            code, used_rpc = get_code(addr)
            codes[name] = code
            with open(os.path.join(OUT, f"code_{name}.hex"), "w") as f:
                f.write(code)
            report["implements"][name] = {"address": addr, "size": (len(code) - 2) // 2,
                                          "rpc": used_rpc.split("//")[-1].split("/")[0]}
            print(f"[code] {name} {addr} size={(len(code)-2)//2}")
        except Exception as e:
            report["implements"][name] = {"address": addr, "error": str(e)}
            print(f"[code] {name} FAILED: {e}")

    # evmole
    for name, code in codes.items():
        r = evmole_analyze(code)
        report["implements"].setdefault(name, {})["evmole"] = r
        print(f"[evmole] {name}: available={r.get('available')} selectors={len(r.get('selectors') or [])}")

    # panoramix for the still-registered custom impls
    for name in ["impl_rfq", "impl_A_5142", "impl_D_c971", "impl_registry", "impl_owner"]:
        code = codes.get(name)
        if not code:
            continue
        txt = panoramix(code, name)
        if txt:
            with open(os.path.join(OUT, f"decompiled_{name}.sol"), "w") as f:
                f.write(txt)
            report["implements"][name]["panoramix"] = "ok"
            print(f"[panoramix] {name}: ok ({len(txt)} chars)")
        else:
            report["implements"][name]["panoramix"] = "unavailable"
            print(f"[panoramix] {name}: unavailable")

    # static scan
    for name, code in codes.items():
        s = static_scan(code)
        report["implements"].setdefault(name, {})["static"] = s
        print(f"[static] {name}: transferFrom_refs={len(s['transferFrom_refs'])} "
              f"approve_refs={len(s['approve_refs'])} calls={s['calls']}")

    with open(os.path.join(OUT, "decompile_report.json"), "w") as f:
        json.dump(report, f, indent=2)

    # short human summary
    lines = ["C-25 CI decompile/static summary", "=" * 40]
    for name, meta in report["implements"].items():
        ev = meta.get("evmole", {})
        st = meta.get("static", {})
        lines.append(f"{name} {meta.get('address')} size={meta.get('size')}")
        lines.append(f"  evmole selectors: {ev.get('selectors')}")
        lines.append(f"  transferFrom refs: {len(st.get('transferFrom_refs', []))}, "
                     f"approve refs: {len(st.get('approve_refs', []))}")
    with open(os.path.join(OUT, "decompile_summary.txt"), "w") as f:
        f.write("\n".join(lines))
    print("\n".join(lines))

if __name__ == "__main__":
    main()
