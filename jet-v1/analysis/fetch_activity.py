#!/usr/bin/env python3
"""Task B: Jet v1 program activity census (read-only, keyless public RPCs).

1. getSignaturesForAddress on the Jet program, paginated (before=...), recent-first,
   until either ~30 days back or a candidates cap.
2. getTransaction (jsonParsed, maxSupportedTransactionVersion=0) for the most recent
   MAX_TX signatures, concurrency-limited with 429 backoff.
3. Classify Jet instructions by discriminator (snake_case anchor discriminators),
   scan both top-level and inner (CPI) instructions.
4. Flag txs touching the solBTC reserve (GqPX...) / solETH reserve (2X39...).

Outputs: activity_signatures.json, activity_census.json, activity_census.md
"""
import asyncio, base64, json, os, random, sys, time
import aiohttp

HERE = os.path.dirname(os.path.abspath(__file__))
JET_PROGRAM = "JPv1rCqrhagNNmJVM5J1he7msQ5ybtvE1nNuHpDHMNU"
BOT_PROGRAM_GUESS = "C3MPbLBQbREEJ56ku8SNHrHMh5q3iYKUkAYFQdvmcWP8"
SOLBTC_RESERVE = "GqPX7JNRKQ9eTqUxG9zZUm5zQqKSv2gnWqRzLRz6hN29"
SOLETH_RESERVE = "2X39AAQzsY7YFLvoLQ5kSd7cJDLn5EEDkgFrFUfqhG1M"
RPC_PRIMARY = "https://api.mainnet-beta.solana.com"
RPC_FALLBACK = "https://solana-rpc.publicnode.com"
MAX_SIGS = 3000          # signatures to list (recent first)
MAX_TX = 650             # getTransaction calls (recent first)
DAYS_COVER = 32
CONCURRENCY = 4
UA = {"Content-Type": "application/json", "User-Agent": "research-readonly/1.0"}

import hashlib, re
def snake(n): return re.sub(r"(?<!^)(?=[A-Z])", "_", n).lower()
IDL = json.load(open(os.path.join(HERE, "jet_idl_v020.json")))
DISC2NAME = {}
for ix in IDL["instructions"]:
    d = hashlib.sha256(("global:" + snake(ix["name"])).encode()).digest()[:8]
    DISC2NAME[d] = ix["name"]


async def rpc_call(session, url, payload, timeout=60):
    async with session.post(url, json=payload, headers=UA, timeout=aiohttp.ClientTimeout(total=timeout)) as r:
        if r.status == 429:
            raise RuntimeError("429")
        d = json.loads(await r.text())
        if "error" in d:
            raise RuntimeError(f"rpc: {json.dumps(d['error'])[:200]}")
        return d["result"]


async def rpc(session, method, params, retries=6):
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    last = None
    for i in range(retries):
        for url in (RPC_PRIMARY, RPC_FALLBACK):
            try:
                return await rpc_call(session, url, payload)
            except Exception as e:  # noqa: BLE001
                last = e
        await asyncio.sleep(min(2 ** i, 30) + random.random())
    raise RuntimeError(f"{method}: {last}")


def classify_instructions(tx):
    """Return list of {disc, name} for instructions sent TO the Jet program (top-level + inner)."""
    hits = []
    def scan(ixs):
        for ix in (ixs or []):
            pid = ix.get("programId")
            if pid != JET_PROGRAM:
                continue
            data = ix.get("data")
            if not data:
                continue
            try:
                raw = __import__("base58").b58decode(data)
            except Exception:  # noqa: BLE001
                try:
                    raw = base64.b64decode(data)
                except Exception:  # noqa: BLE001
                    raw = b""
            disc = raw[:8]
            hits.append({"disc": disc.hex(), "name": DISC2NAME.get(disc, "unknown:" + disc.hex()),
                         "accounts": ix.get("accounts", [])})
    for ix in tx.get("transaction", {}).get("message", {}).get("instructions", []) or []:
        if ix.get("programId") == JET_PROGRAM:
            scan([ix])
    meta = tx.get("meta") or {}
    for inner in meta.get("innerInstructions", []) or []:
        scan(inner.get("instructions", []))
    return hits


async def fetch_txs(session, sigs):
    sem = asyncio.Semaphore(CONCURRENCY)
    out = {}
    done = 0

    async def one(sig):
        nonlocal done
        async with sem:
            try:
                r = await rpc(session, "getTransaction", [
                    sig, {"encoding": "jsonParsed", "commitment": "finalized",
                          "maxSupportedTransactionVersion": 0}])
            except Exception as e:  # noqa: BLE001
                out[sig] = {"error": str(e)}
                done += 1
                return
        tx = r
        if tx is None:
            out[sig] = {"error": "null"}
            done += 1
            return
        hits = classify_instructions(tx)
        msg = tx.get("transaction", {}).get("message", {})
        keys = [k["pubkey"] if isinstance(k, dict) else k for k in msg.get("accountKeys", [])]
        signers = [k["pubkey"] for k in msg.get("accountKeys", []) if isinstance(k, dict) and k.get("signer")]
        programs = set()
        for ix in msg.get("instructions", []) or []:
            programs.add(ix.get("programId"))
        for inner in (tx.get("meta") or {}).get("innerInstructions", []) or []:
            for ix in inner.get("instructions", []) or []:
                programs.add(ix.get("programId"))
        out[sig] = {
            "slot": tx.get("slot"), "blockTime": tx.get("blockTime"),
            "err": bool(tx.get("meta", {}).get("err")), "fee": tx.get("meta", {}).get("fee"),
            "signers": signers, "feePayer": signers[0] if signers else None,
            "programs": sorted(p for p in programs if p),
            "jetIx": hits,
            "touches_solBTC_reserve": SOLBTC_RESERVE in keys,
            "touches_solETH_reserve": SOLETH_RESERVE in keys,
        }
        done += 1
        if done % 50 == 0:
            print(f"  txs fetched {done}/{len(sigs)}", file=sys.stderr)

    await asyncio.gather(*[one(s["signature"]) for s in sigs])
    return out


async def main():
    connector = aiohttp.TCPConnector(limit=CONCURRENCY + 2)
    async with aiohttp.ClientSession(connector=connector) as session:
        # 1. signatures
        sigfile = os.path.join(HERE, "activity_signatures.json")
        if os.path.exists(sigfile):
            sigd = json.load(open(sigfile))
            sigs = sigd["signatures"]
            print(f"reuse {len(sigs)} signatures", file=sys.stderr)
        else:
            sigs = []
            before = None
            while len(sigs) < MAX_SIGS:
                params = [JET_PROGRAM, {"limit": 1000, "commitment": "finalized"}]
                if before:
                    params[1]["before"] = before
                page = await rpc(session, "getSignaturesForAddress", params)
                if not page:
                    break
                sigs.extend(page)
                before = page[-1]["signature"]
                print(f"  sigs {len(sigs)} (oldest blockTime {page[-1]['blockTime']})", file=sys.stderr)
                if page[-1]["blockTime"] and (time.time() - page[-1]["blockTime"]) > DAYS_COVER * 86400:
                    break
            sigd = {"fetched_at": time.time(), "count": len(sigs),
                    "oldest_blockTime": sigs[-1]["blockTime"] if sigs else None, "signatures": sigs}
            json.dump(sigd, open(sigfile, "w"))

        # 2. transactions (recent first)
        txs = [s for s in sigs[:MAX_TX]]
        print(f"fetching {len(txs)} transactions ...", file=sys.stderr)
        results = await fetch_txs(session, txs)

    # 3. aggregate
    ix_counts, ix_err_counts = {}, {}
    signer_counts = {}
    fee_payers = {}
    bot_prog_txs = []
    nonbot_borrow_deposit = []
    jet_tx_count = 0
    touching = {"solBTC": [], "solETH": []}
    dates = []
    for s in txs:
        sig = s["signature"]
        r = results.get(sig, {})
        if not r or r.get("error"):
            continue
        bt = r.get("blockTime")
        if bt:
            dates.append(bt)
        if r["jetIx"]:
            jet_tx_count += 1
        for h in r["jetIx"]:
            ix_counts[h["name"]] = ix_counts.get(h["name"], 0) + 1
            if r.get("err"):
                ix_err_counts[h["name"]] = ix_err_counts.get(h["name"], 0) + 1
        for sn in r["signers"]:
            signer_counts[sn] = signer_counts.get(sn, 0) + 1
        fp = r.get("feePayer")
        if fp:
            fee_payers[fp] = fee_payers.get(fp, 0) + 1
        if BOT_PROGRAM_GUESS in r["programs"]:
            bot_prog_txs.append(sig)
        names = {h["name"] for h in r["jetIx"]}
        if ({"borrow", "deposit", "depositCollateral", "initObligation"} & names):
            # non-bot if the bot program is not involved and fee payer != jet program owner wallets
            if BOT_PROGRAM_GUESS not in r["programs"]:
                nonbot_borrow_deposit.append({"sig": sig, "blockTime": bt, "feePayer": fp,
                                              "names": sorted(names), "signers": r["signers"],
                                              "err": r.get("err")})
        if r.get("touches_solBTC_reserve"):
            touching["solBTC"].append({"sig": sig, "blockTime": bt, "err": r.get("err"),
                                       "names": sorted(names), "feePayer": fp})
        if r.get("touches_solETH_reserve"):
            touching["solETH"].append({"sig": sig, "blockTime": bt, "err": r.get("err"),
                                       "names": sorted(names), "feePayer": fp})

    summary = {
        "signatures_listed": len(sigs),
        "oldest_blockTime_listed": min(d["blockTime"] for d in sigs if d.get("blockTime")) if sigs else None,
        "txs_fetched_ok": sum(1 for s in txs if results.get(s["signature"]) and not results[s["signature"]].get("error")),
        "txs_fetched_requested": len(txs),
        "date_range": {"min": min(dates) if dates else None, "max": max(dates) if dates else None,
                       "min_iso": time.strftime("%Y-%m-%d %H:%M", time.gmtime(min(dates))) if dates else None,
                       "max_iso": time.strftime("%Y-%m-%d %H:%M", time.gmtime(max(dates))) if dates else None},
        "jet_txs": jet_tx_count,
        "instruction_counts": dict(sorted(ix_counts.items(), key=lambda kv: -kv[1])),
        "instruction_counts_with_err": dict(sorted(ix_err_counts.items(), key=lambda kv: -kv[1])),
        "distinct_signers": len(signer_counts),
        "top_signers": sorted(signer_counts.items(), key=lambda kv: -kv[1])[:25],
        "top_fee_payers": sorted(fee_payers.items(), key=lambda kv: -kv[1])[:25],
        "txs_invoking_bot_program": len(bot_prog_txs),
        "nonbot_borrow_deposit_like_txs": nonbot_borrow_deposit,
        "touching_solBTC_reserve": touching["solBTC"],
        "touching_solETH_reserve": touching["solETH"],
        "bot_program": BOT_PROGRAM_GUESS,
    }
    json.dump({"summary": summary, "txs": results},
              open(os.path.join(HERE, "activity_census.json"), "w"), indent=1)

    lines = ["# Jet v1 program activity census", ""]
    w = lines.append
    w(f"- signatures listed: {summary['signatures_listed']} (oldest blockTime {summary['oldest_blockTime_listed']})")
    w(f"- transactions fetched: {summary['txs_fetched_ok']}/{summary['txs_fetched_requested']} (recent first)")
    w(f"- date range of fetched txs: {summary['date_range']['min_iso']} .. {summary['date_range']['max_iso']} UTC")
    w(f"- Jet txs among fetched: {summary['jet_txs']}")
    w(f"- distinct signers: {summary['distinct_signers']}; txs invoking bot program ({BOT_PROGRAM_GUESS}): {summary['txs_invoking_bot_program']}")
    w("")
    w("## Instruction counts (Jet, top-level + inner)")
    w("")
    w("| instruction | count | with err |")
    w("|---|---|---|")
    for name, c in summary["instruction_counts"].items():
        w(f"| {name} | {c} | {summary['instruction_counts_with_err'].get(name, 0)} |")
    w("")
    w("## Top signers")
    w("")
    for s, c in summary["top_signers"]:
        w(f"- {s}: {c}")
    w("")
    w(f"## Non-bot borrow/deposit-like txs: {len(nonbot_borrow_deposit)}")
    for t in nonbot_borrow_deposit[:50]:
        w(f"- {t['sig']} {t.get('names')} feePayer {t.get('feePayer')} err={t.get('err')}")
    w("")
    w(f"## Txs touching solBTC reserve: {len(touching['solBTC'])}; solETH reserve: {len(touching['solETH'])}")
    for k in ("solBTC", "solETH"):
        for t in touching[k][:30]:
            w(f"- [{k}] {t['sig']} {t.get('names')} err={t.get('err')} feePayer {t.get('feePayer')}")
    open(os.path.join(HERE, "activity_census.md"), "w").write("\n".join(lines) + "\n")
    print(json.dumps({k: v for k, v in summary.items() if k not in ("top_signers", "top_fee_payers")}, indent=1)[:3000])


if __name__ == "__main__":
    asyncio.run(main())
