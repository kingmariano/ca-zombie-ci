#!/usr/bin/env python3
"""Sum claimable CELO over ALL transfer participants per gauge.

subsumes holders: claimable = claim_data>>128 + balance*(I - rif)/1e18.
Writes gauge-claimables-raw.json (final version).
"""
import json, time, urllib.request, sys

RPC = "https://forno.celo.org"
CELO = "0x471ece3750da237f93b8e339c536989b8978a438"
SEL_BAL = "0x70a08231"
SEL_CLAIMABLE = "0x33fd6f74"
SEL_RIF = "0xf05cc058"


def batch(calls, tries=6):
    out = []
    for i in range(0, len(calls), 60):
        chunk = calls[i:i + 60]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                    "params": [{"to": t, "data": d}, "latest"]} for j, (t, d) in enumerate(chunk)]
        for a in range(tries):
            try:
                req = urllib.request.Request(RPC, data=json.dumps(payload).encode(), headers={
                    "Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (research)"})
                with urllib.request.urlopen(req, timeout=90) as r:
                    res = json.loads(r.read().decode())
                break
            except Exception as e:
                print(" retry", i, e, file=sys.stderr, flush=True)
                time.sleep(2 + 3 * a)
        else:
            raise RuntimeError("batch failed")
        by_id = {x["id"]: x for x in res}
        for j in range(len(chunk)):
            x = by_id.get(j, {})
            out.append(x.get("result") if "error" not in x else None)
        time.sleep(0.2)
    return out


def enc(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def dec(x):
    if x is None or x == "0x":
        return 0
    return int(x, 16)


def main():
    raw = json.load(open("gauge-claims-raw.json"))
    raw["gauge_calls"] = {k.lower(): v for k, v in raw["gauge_calls"].items()}
    raw["token_balances"] = {k.lower(): v for k, v in raw["token_balances"].items()}
    parts = {k.lower(): v for k, v in json.load(open("gauge_participants_tmp.json")).items()}

    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json",
                                                          "User-Agent": "Mozilla/5.0 (research)"})
    with urllib.request.urlopen(req, timeout=60) as r:
        block = int(json.loads(r.read().decode())["result"], 16)

    result = {"block": block,
              "note": "CELO claimable over all transfer participants (subsumes holders). residual = gauge balance - sum.",
              "gauges": {}}
    for g, users in parts.items():
        if g not in raw["gauge_calls"]:
            continue
        users = [u for u in users if u != "0x0000000000000000000000000000000000000000" and u != g]
        I = dec(raw["gauge_calls"][g].get("reward_integral(CELO)"))
        gcelo = dec(raw["token_balances"][g]["CELO_gauge"])
        calls = []
        for u in users:
            calls.append((g, SEL_BAL + enc(u)))
            calls.append((g, SEL_CLAIMABLE + enc(u) + enc(CELO)))
            calls.append((g, SEL_RIF + enc(CELO) + enc(u)))
        res = batch(calls)
        total = 0
        rows = []
        for k, u in enumerate(users):
            bal = dec(res[3 * k]); stored = dec(res[3 * k + 1]); rif = dec(res[3 * k + 2])
            pending = bal * (I - rif) // 10**18 if I > rif else 0
            cl = stored + pending
            total += cl
            if cl > 0:
                rows.append({"user": u, "bal": str(bal), "stored": str(stored),
                             "rif": str(rif), "pending": str(pending), "claimable": str(cl)})
        rows.sort(key=lambda x: -int(x["claimable"]))
        residual = max(0, gcelo - total)
        result["gauges"][g] = {"participants": len(users), "sum_claimable_wei": str(total),
                               "gauge_CELO_wei": str(gcelo), "residual_wei": str(residual),
                               "n_claimable": len(rows), "reward_integral": str(I), "top": rows[:20]}
        print(f"{g}: participants={len(users)} sum={total/1e18:.6f} gauge={gcelo/1e18:.6f} "
              f"residual={residual/1e18:.6f} n={len(rows)}", flush=True)
    json.dump(result, open("gauge-claimables-raw.json", "w"), indent=1)
    print("block", block, "-> gauge-claimables-raw.json")


if __name__ == "__main__":
    main()
