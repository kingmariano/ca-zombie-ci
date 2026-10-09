#!/usr/bin/env python3
"""C2-28 Sommelier cellars / gravity dust — CI evidence job (light, read-only).

Runs on the public ca-zombie-ci runner. Public endpoints only; no secrets used.
  1. analysis/fetch_state.py  -> ci-out/state.json + ci-out/raw/*.json
  2. analysis/cellar_balances.py (cork v2 managed cellars, Ethereum) -> raw amounts
  3. analysis/price_cellars.py (DefiLlama prices + native ETH) -> priced totals
  4. best-effort L2 managed-cellar scan (Optimism / Arbitrum / Scroll)
  5. ci-out/summary_ci.json  (headline numbers + invariant checks)
"""
import json
import os
import subprocess
import sys
import time
import urllib.request

UA = {"User-Agent": "zombie-hunt-ci/1.0 (read-only research)"}
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "ci-out")


def run(cmd):
    print(f"[ci] $ {' '.join(cmd)}", flush=True)
    r = subprocess.run(cmd, cwd=ROOT)
    if r.returncode != 0:
        print(f"[ci] WARN: command exited {r.returncode}")


def http_json(url, data=None, timeout=45):
    req = urllib.request.Request(url, data=json.dumps(data).encode() if data is not None else None,
                                 headers={**UA, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


def l2_scan():
    """Best-effort balance scan of the axelarcork managed cellars (L2 Blockscout)."""
    ids_path = os.path.join(OUT, "raw", "axelarcork_cellar_ids.json")
    if not os.path.exists(ids_path):
        return {"error": "no axelarcork ids"}
    ids = json.load(open(ids_path)).get("cellar_ids", [])
    bases = {"10": "https://optimism.blockscout.com",
             "42161": "https://arbitrum.blockscout.com",
             "534352": "https://scroll.blockscout.com"}
    out = []
    for ch in ids:
        base = bases.get(ch.get("chain_id"))
        if not base:
            continue
        for addr in ch.get("ids", []):
            row = {"chain_id": ch["chain_id"], "address": addr}
            for attempt in range(3):
                try:
                    d = http_json(f"{base}/api/v2/addresses/{addr}/token-balances")
                    row["tokens"] = [(t.get("token", {}).get("symbol"),
                                      int(t.get("value") or 0) / 10 ** int(t.get("token", {}).get("decimals") or 0)
                                      if (t.get("token", {}).get("decimals") or 0) else int(t.get("value") or 0))
                                     for t in (d if isinstance(d, list) else [])]
                    break
                except Exception as e:
                    row["error"] = str(e)
                    time.sleep(3)
            out.append(row)
            time.sleep(0.7)
    res = {"source": "L2 Blockscout (keyless, best-effort)", "cellars": out}
    json.dump(res, open(os.path.join(OUT, "l2_cellar_balances_raw.json"), "w"), indent=1)
    return res


def main():
    os.makedirs(OUT, exist_ok=True)
    run([sys.executable, "analysis/fetch_state.py", "ci-out"])
    run([sys.executable, "analysis/cellar_balances.py",
         "ci-out/raw/cork_v2_cellar_ids.json", "ci-out/cellar_balances_raw.json"])
    run([sys.executable, "analysis/price_cellars.py",
         "ci-out/cellar_balances_raw.json", "ci-out/raw/cork_v2_cellar_ids.json",
         "ci-out/cellar_balances_priced.json"])
    l2 = l2_scan()

    state = json.load(open(os.path.join(OUT, "state.json")))
    priced = json.load(open(os.path.join(OUT, "cellar_balances_priced.json")))

    def bal(name, denom):
        for b in state["module_balances"][name]["balances"]:
            if b.get("denom") == denom:
                return int(b["amount"])
        return 0

    # ERC-20 cross-asset: gravity module escrow vs Ethereum-side total supply
    sup_raw = state["somm_erc20"].get("totalSupply_raw")
    erc20_supply = int(sup_raw, 16) if sup_raw and sup_raw.startswith("0x") else None
    gravity_escrow = bal("gravity", "usomm")

    price = state.get("somm_price_usd")
    cp_somm = None
    for p in state["community_pool"]:
        if p.get("denom") == "usomm":
            cp_somm = float(p["amount"])
    cellarfees_usd = sum(b.get("usd_value", 0)
                         for b in state["cellarfees"]["fee_token_balances"].get("balances", []))

    summary = {
        "finding": "C2-28",
        "chain": "sommelier-3",
        "height": state["sommelier"].get("height"),
        "time": state["sommelier"].get("time"),
        "somm_price_usd": price,
        "gravity_module_usomm": gravity_escrow,
        "gravity_module_usd_paper": round(gravity_escrow / 1e6 * price, 2) if price else None,
        "erc20_somm_total_supply": erc20_supply,
        "gravity_escrow_equals_erc20_supply": (erc20_supply == gravity_escrow),
        "gravity_unbatched_sends": state["gravity_kv"]["unbatched_sends"]["count"],
        "gravity_pending_batches": sum(1 for k in state["gravity_kv"]["outgoing_txs"]["keys"]
                                       if k[2:4] == "02"),
        "gravity_last_send_id": state["gravity_kv"]["last_send_to_ethereum_id"],
        "gravity_last_batch_nonce": state["gravity_kv"]["last_outgoing_batch_nonce"],
        "cellarfees_usd": round(cellarfees_usd, 2),
        "cellarfees_params": state["cellarfees"]["params"].get("params"),
        "community_pool_usomm": cp_somm,
        "community_pool_usd_paper": round(cp_somm / 1e6 * price, 2) if (cp_somm and price) else None,
        "bonded_usomm": int(state["staking_pool"]["bonded_tokens"]),
        "bonded_somm": int(state["staking_pool"]["bonded_tokens"]) / 1e6,
        "cork_authority": state["cork_v2_params"].get("params", {}).get("cork_authority"),
        "cork_managed_cellars_ethereum": len(state["cork_v2_cellar_ids"].get("cellar_ids", [])),
        "cork_managed_cellars_value_usd": priced["total_usd"],
        "cork_managed_cellars_with_value": priced["cellars_with_value"],
        "sommelier_defillama_tvl_usd": state.get("sommelier_tvl"),
        "l2_scan_cellars": len(l2.get("cellars", [])),
    }
    json.dump(summary, open(os.path.join(OUT, "summary_ci.json"), "w"), indent=1)

    print("== C2-28 Sommelier headline ==")
    for k in ("height", "somm_price_usd", "gravity_module_usomm", "gravity_module_usd_paper",
              "erc20_somm_total_supply", "gravity_escrow_equals_erc20_supply",
              "gravity_unbatched_sends", "gravity_pending_batches",
              "cellarfees_usd", "community_pool_usomm", "community_pool_usd_paper",
              "bonded_somm", "cork_authority",
              "cork_managed_cellars_value_usd", "sommelier_defillama_tvl_usd"):
        print(f"  {k}: {summary.get(k)}")
    print("[ci] OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
