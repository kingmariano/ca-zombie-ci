#!/usr/bin/env python3
"""C-35 heavy scan (CI):
1. Live balance + code snapshot of the target set at a pinned block.
2. PUSH4 selector extraction from live bytecode for every target.
3. Signature mapping against a vendored signature->selector map (from analysis
   artifacts) + OpenChain lookups for unmapped, plausible selectors (bounded).
4. Flag "value-out"-shaped selectors (withdraw/claim/exit/sell/redeem/refund/
   airdrop/potSwap/emergency/sweep/rescue) per contract.
5. Dump raw F3D-family state (rounds/vaults/pots) for FoMo3D Ultra and siblings.

Read-only: JSON-RPC eth_getBalance/eth_getCode/eth_call + OpenChain HTTP. No keys.
Writes ci-out/scan_report.json + ci-out/scan_report.md.
"""
import json, os, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "ci-out")
os.makedirs(OUT, exist_ok=True)

ENDPOINTS = ["https://ethereum-rpc.publicnode.com", "https://eth.drpc.org", "https://1rpc.io/eth", "https://rpc.flashbots.net"]
ENDPOINTS = [e for e in [os.environ.get("FORK_RPC_URL"), os.environ.get("RPC_URL")] + ENDPOINTS if e]

TARGETS_FILE = os.path.join(ROOT, "analysis", "targets.json")

# groups for the markdown report
GROUPS = {
    "C-35 named": ["HongCoin_HONG", "HongCoin_unlock_executor", "Liquality_ICO_2018"] + [f"Liquality_HTLC_{i}" for i in range(1, 8)],
    "top live ETH (§1.1)": ["IDEX_v1", "EtherDelta_v2", "zkSyncLite_distributor", "Neufund_EtherToken_v1", "Unknown_DEX_0x4d55",
                            "LastWinner_0xdd9f", "PoWH3D", "Old_WETH", "Fomo3D_Long", "Ethfinex_WrapperLockEth",
                            "SingularX", "Augur_v1", "Rewards_0x0", "GandhiJi", "Token_Store"],
    "focus (uncovered)": ["FoMo3D_Ultra", "CryptoCats_v0v1", "Transit_refund", "Zethr", "Zethr_Casino",
                          "Bingo4Beast_dep2", "ReadyPlayerONE", "DailyDivs", "FEG_WrappedETH"],
    "F3D/P3D clones": ["FoMo3Dshort_v2", "Fomo3D_Quick", "Fomo3D_Short", "FoMoJP", "FoMo3D_Ultra_clone_BingoLong",
                       "CryptoMinerToken", "AceDapp", "BlueChip", "EKS"],
    "other leads": ["SingularX_Fund", "Neufund_EtherToken_v2", "Celer_PaymentChannels", "Rook_kTokens",
                    "Aave_v1_LendingPoolCore", "OpenGSN_RelayHub_v1", "MCDEX_ETHPERP"],
}

VALUE_OUT_HINTS = ["withdraw", "claim", "exit(", "sell(", "redeem", "refund", "airdrop", "potswap",
                   "emergency", "sweep", "rescue", "collect", "cash", "payout", "distribute", "migrate",
                   "recover", "transfer(", "drain", "kill", "selfdestruct", "suicide"]


def rpc(method, params, tries=4):
    last = None
    for i in range(tries):
        for url in ENDPOINTS[i % len(ENDPOINTS):] + ENDPOINTS[:i % len(ENDPOINTS)]:
            try:
                req = urllib.request.Request(url, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                                             headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=25) as r:
                    d = json.loads(r.read())
                if "result" in d:
                    return d["result"]
                last = d.get("error")
            except Exception as e:
                last = e
        time.sleep(1)
    raise RuntimeError(f"rpc {method} failed: {last}")


def extract_selectors(code_hex):
    code = bytes.fromhex(code_hex[2:])
    sels = set()
    i = 0
    while i < len(code):
        if code[i] == 0x63 and i + 4 < len(code):
            sels.add(code[i + 1:i + 5].hex())
            i += 5
        else:
            i += 1
    return sorted(sels)


def plausible(sel):
    if sel in {"3b9aca00", "ffffffff", "10000011", "8161ffff", "0ecb93c0", "2f3f0bc3", "00000000", "deadbeef"}:
        return False
    b = bytes.fromhex(sel)
    return not all(32 <= c < 127 for c in b) and len(set(b)) > 1


def openchain_lookup(sels):
    out = {}
    for i in range(0, len(sels), 12):
        chunk = sels[i:i + 12]
        q = ",".join("0x" + s for s in chunk)
        try:
            req = urllib.request.Request(f"https://api.openchain.xyz/signature-database/v1/lookup?function={q}&filter=true",
                                         headers={"User-Agent": "Mozilla/5.0"})
            d = json.load(urllib.request.urlopen(req, timeout=25))
            res = (d.get("result") or {}).get("function") or {}
            for s in chunk:
                names = [x["name"] for x in (res.get("0x" + s) or [])]
                if names:
                    out[s] = names[:3]
        except Exception as e:
            out.setdefault("_errors", []).append(str(e))
        time.sleep(0.15)
    return out


def main():
    targets = json.load(open(TARGETS_FILE))
    rev = {}
    mapfile = os.path.join(ROOT, "analysis", "selector_to_sig.json")
    if os.path.exists(mapfile):
        rev = json.load(open(mapfile))
    block = int(rpc("eth_blockNumber", []), 16)
    report = {"block": block, "targets": {}, "groups": GROUPS}

    # balances in small batches
    for name, addr in targets.items():
        code = rpc("eth_getCode", [addr, "latest"])
        bal = rpc("eth_getBalance", [addr, "latest"])
        sels = extract_selectors(code)
        mapped = {s: rev.get(s) for s in sels if rev.get(s)}
        unknown = [s for s in sels if s not in mapped and plausible(s)]
        report["targets"][name] = {
            "address": addr,
            "balance_eth": int(bal, 16) / 1e18,
            "code_size": max(0, len(code) // 2 - 1),
            "selectors": sels,
            "mapped": {s: v for s, v in mapped.items()},
            "unknown_plausible": unknown,
            "value_out_selectors": {s: v for s, v in mapped.items() if any(h in "|".join(v).lower() for h in VALUE_OUT_HINTS)},
        }
        print(f"[scan] {name:34s} {int(bal,16)/1e18:>18.6f} ETH code={max(0,len(code)//2-1)} sel={len(sels)}")

    # openchain lookups for unknown selectors of the priority contracts only
    priority = set(GROUPS["focus (uncovered)"]) | set(GROUPS["C-35 named"]) | {"FoMo3D_Ultra", "LastWinner_0xdd9f", "Bingo4Beast_dep2", "FoMo3D_Ultra_clone_BingoLong"}
    lookups = {}
    for name in priority:
        t = report["targets"].get(name)
        if not t or not t["unknown_plausible"]:
            continue
        unk = t["unknown_plausible"][:90]
        lookups[name] = openchain_lookup(unk)
        print(f"[scan] openchain {name}: {len(unk)} unknown -> {len(lookups[name])} hits")
    report["openchain_lookups"] = lookups

    # raw state for F3D-family
    fam = {
        "FoMo3D_Ultra": "0xab83d96de35bad6f234178fbb6507203488e9626",
        "Fomo3D_Long": "0xa62142888aba8370742be823c1782d17a0389da1",
        "LastWinner": "0xdd9fd6b6f8f7ea932997992bbe67eabb3e316f3c",
        "FoMo3Dshort_v2": "0x0ad3227eb47597b566ec138b3afd78cfea752de5",
        "FoMoJP": "0xcb47c89cb17c10b719fc5ed9665bae157cac2cb1",
        "FoMo3D_Ultra_clone_BingoLong": "0x05aa2fdf9f58b426b49900834cce0565d88e52eb",
        "Bingo4Beast_dep2": "0x4fb7d68e0116f35ade131b6535b2db1027bf7650",
    }
    calls = [
        ("rID_", "0x624ae5c0"),
        ("airDropPot_", "0xd87574e0"),
        ("getTimeLeft", "0xc7e284b8"),
        ("getBuyPrice", "0x018a25e8"),
        ("activated_", "0xd53b2679"),
        ("getCurrentRoundInfo", "0x747dff42"),
        ("getPlayerVaults(1)", "0x63066434" + "0" * 63 + "1"),
        ("getPlayerVaults(2)", "0x63066434" + "0" * 63 + "2"),
    ]
    raw = {}
    for name, addr in fam.items():
        raw[name] = {}
        for label, data in calls:
            try:
                r = rpc("eth_call", [{"to": addr, "data": data}, "latest"])
                h = (r or "0x")[2:]
                words = [int(h[i:i + 64], 16) for i in range(0, len(h), 64)]
                raw[name][label] = words
            except Exception as e:
                raw[name][label] = f"error: {e}"
    report["f3d_family_state"] = raw

    with open(os.path.join(OUT, "scan_report.json"), "w") as f:
        json.dump(report, f, indent=1)

    # compact per-target verdict artifact
    verdicts = {}
    for name, t in report["targets"].items():
        flat = []
        for v in t["value_out_selectors"].values():
            flat.extend(v if isinstance(v, list) else [v])
        verdicts[name] = {
            "address": t["address"],
            "balance_eth": t["balance_eth"],
            "value_out": flat,
            "unknown_selectors": len(t["unknown_plausible"]),
        }
    with open(os.path.join(OUT, "verdicts.json"), "w") as f:
        json.dump({"block": block, "targets": verdicts}, f, indent=1)

    # markdown
    lines = [f"# C-35 selector + balance scan", "", f"Block: **{block}**", ""]
    for group, names in GROUPS.items():
        lines.append(f"## {group}")
        lines.append("")
        lines.append("| target | address | ETH | code | selectors | value-out mapped | unknown |")
        lines.append("|---|---|---:|---:|---:|---|---:|")
        for n in names:
            t = report["targets"].get(n)
            if not t:
                continue
            flat = []
            for v in t["value_out_selectors"].values():
                flat.extend(v if isinstance(v, list) else [v])
            vo = ", ".join(flat) if flat else "—"
            vo = vo.replace("|", "/")[:120]
            lines.append(f"| {n} | `{t['address']}` | {t['balance_eth']:.6f} | {t['code_size']} | {len(t['selectors'])} | {vo} | {len(t['unknown_plausible'])} |")
        lines.append("")
    lines.append("## F3D-family raw state (word dumps)")
    lines.append("")
    lines.append("```json")
    lines.append(json.dumps(raw, indent=1)[:20000])
    lines.append("```")
    with open(os.path.join(OUT, "scan_report.md"), "w") as f:
        f.write("\n".join(lines))
    print(f"[scan] wrote {OUT}/scan_report.json and scan_report.md; block={block}")


if __name__ == "__main__":
    main()
