#!/usr/bin/env python3
"""Task B (robust): fetch recent Jet v1 transactions with an archival RPC.

Uses SOLANA_RPC_URL from the environment if set (may be a keyed endpoint, but the key is
NEVER written anywhere - only read from env at runtime); otherwise falls back to keyless
public endpoints. Parses standard jsonParsed getTransaction responses (base58 instruction
data), classifies Jet instructions by discriminator, and aggregates.

Reads:  activity_signatures.json (signature list), optional activity_census.json (cache)
Writes: activity_census2.json, activity_census.md
"""
import asyncio, base64, json, os, random, sys, time

import aiohttp

HERE = os.path.dirname(os.path.abspath(__file__))
JET_PROGRAM = "JPv1rCqrhagNNmJVM5J1he7msQ5ybtvE1nNuHpDHMNU"
BOT_PROGRAM = "C3MPbLBQbREEJ56ku8SNHrHMh5q3iYKUkAYFQdvmcWP8"
SOLBTC_RESERVE = "GqPX7JNRKQ9eTqUxG9zZUm5zQqKSv2gnWqRzLRz6hN29"
SOLETH_RESERVE = "2X39AAQzsY7YFLvoLQ5kSd7cJDLn5EEDkgFrFUfqhG1M"
XPUBKEYS_EXTRA = [
    "7gpj9cpzBBW9Ci1yMwWz7iGbQYpm5fZmadNQyrYsqch8",  # market authority
    "CkkWJtdPoq22CVdfWBhV5vo9MXNVaPXJAjrVmsRpYGC1",  # market owner
]
MAX_TX = 700
CONCURRENCY = 5
UA = {"Content-Type": "application/json", "User-Agent": "research-readonly/1.0"}

import hashlib, re
def snake(n): return re.sub(r"(?<!^)(?=[A-Z])", "_", n).lower()
IDL = json.load(open(os.path.join(HERE, "jet_idl_v020.json")))
DISC2NAME = {}
for ix in IDL["instructions"]:
    d = hashlib.sha256(("global:" + snake(ix["name"])).encode()).digest()[:8]
    DISC2NAME[d] = ix["name"]


def decode_data(data):
    try:
        return __import__("base58").b58decode(data)
    except Exception:  # noqa: BLE001
        try:
            return base64.b64decode(data)
        except Exception:  # noqa: BLE001
            return b""


def classify(tx):
    """Instruction hits sent to the Jet program (top-level + inner)."""
    hits = []
    msg = (tx.get("transaction") or {}).get("message") or {}
    keys = [k["pubkey"] if isinstance(k, dict) else k for k in msg.get("accountKeys", [])]
    def scan(ixs):
        for ix in ixs or []:
            if ix.get("programId") != JET_PROGRAM:
                continue
            raw = decode_data(ix.get("data") or "")
            disc = raw[:8]
            accs = ix.get("accounts", [])
            if accs and isinstance(accs[0], int):
                accs = [keys[i] if i < len(keys) else str(i) for i in accs]
            hits.append({"disc": disc.hex(), "name": DISC2NAME.get(disc, "unknown:" + disc.hex()), "accounts": accs})
    scan(msg.get("instructions"))
    for inner in ((tx.get("meta") or {}).get("innerInstructions") or []):
        scan(inner.get("instructions"))
    return hits, keys


async def main():
    url = os.environ.get("SOLANA_RPC_URL", "https://api.mainnet-beta.solana.com")
    sigpath = os.path.join(HERE, "activity_signatures.json")
    sigs = json.load(open(sigpath))["signatures"]
    cached = {}
    cpath = os.path.join(HERE, "activity_census.json")
    if os.path.exists(cpath):
        old = json.load(open(cpath)).get("txs", {})
        cached = {k: v for k, v in old.items() if v and not v.get("error")}
    todo = [s for s in sigs[:MAX_TX] if s["signature"] not in cached]
    print(f"endpoint={url.split('?')[0][:60]}... cached={len(cached)} todo={len(todo)}", file=sys.stderr)
    sem = asyncio.Semaphore(CONCURRENCY)
    results = dict(cached)
    done = 0

    async def one(sig):
        nonlocal done
        async with sem:
            for attempt in range(5):
                try:
                    async with aiohttp.ClientSession() as sess:
                        async with sess.post(url, json={"jsonrpc": "2.0", "id": 1, "method": "getTransaction",
                                                        "params": [sig, {"encoding": "jsonParsed",
                                                                         "maxSupportedTransactionVersion": 0,
                                                                         "commitment": "finalized"}]},
                                             headers=UA, timeout=aiohttp.ClientTimeout(total=60)) as r:
                            txt = await r.text()
                    d = json.loads(txt)
                    if isinstance(d, dict) and d.get("result") is not None:
                        tx = d["result"]
                        hits, keys = classify(tx)
                        msg = (tx.get("transaction") or {}).get("message") or {}
                        signers = [k["pubkey"] for k in msg.get("accountKeys", []) if isinstance(k, dict) and k.get("signer")]
                        programs = set()
                        for ix in msg.get("instructions", []) or []:
                            programs.add(ix.get("programId"))
                        for inner in (tx.get("meta") or {}).get("innerInstructions", []) or []:
                            for ix in inner.get("instructions", []) or []:
                                programs.add(ix.get("programId"))
                        results[sig] = {"slot": tx.get("slot"), "blockTime": tx.get("blockTime"),
                                        "err": bool((tx.get("meta") or {}).get("err")),
                                        "fee": (tx.get("meta") or {}).get("fee"),
                                        "signers": signers, "feePayer": signers[0] if signers else None,
                                        "programs": sorted(p for p in programs if p),
                                        "jetIx": hits,
                                        "touches_solBTC_reserve": SOLBTC_RESERVE in keys,
                                        "touches_solETH_reserve": SOLETH_RESERVE in keys,
                                        "accounts": keys}
                        break
                    if isinstance(d, dict) and d.get("result") is None:
                        results[sig] = {"error": "null", "blockTime": None}
                        break
                    await asyncio.sleep(1)
                except Exception as e:  # noqa: BLE001
                    if attempt == 4:
                        results[sig] = {"error": str(e)[:200]}
                    await asyncio.sleep(1.5 * (attempt + 1))
            done += 1
            if done % 50 == 0:
                print(f"  {done}/{len(todo)}", file=sys.stderr)

    await asyncio.gather(*[one(s["signature"]) for s in todo])
    # persist
    json.dump({"summary": {}, "txs": results}, open(os.path.join(HERE, "activity_census2.json"), "w"))

    # aggregate
    ix_counts, ix_err = {}, {}
    signer_counts, fee_payers = {}, {}
    nonbot_bd = []
    touching = {"solBTC": [], "solETH": []}
    dates = []
    jet_n = 0
    bot_invoked = 0
    for s in sigs[:MAX_TX]:
        sig = s["signature"]
        r = results.get(sig)
        if not r or r.get("error") or r.get("jetIx") is None:
            continue
        bt = r.get("blockTime")
        if bt:
            dates.append(bt)
        if r["jetIx"]:
            jet_n += 1
        for h in r["jetIx"]:
            ix_counts[h["name"]] = ix_counts.get(h["name"], 0) + 1
            if r.get("err"):
                ix_err[h["name"]] = ix_err.get(h["name"], 0) + 1
        for sn in r.get("signers", []):
            signer_counts[sn] = signer_counts.get(sn, 0) + 1
        fp = r.get("feePayer")
        if fp:
            fee_payers[fp] = fee_payers.get(fp, 0) + 1
        if BOT_PROGRAM in (r.get("programs") or []):
            bot_invoked += 1
        names = {h["name"] for h in r["jetIx"]}
        if {"borrow", "deposit", "depositCollateral", "initObligation"} & names and BOT_PROGRAM not in (r.get("programs") or []):
            nonbot_bd.append({"sig": sig, "blockTime": bt, "feePayer": fp, "names": sorted(names), "signers": r.get("signers"), "err": r.get("err")})
        if r.get("touches_solBTC_reserve"):
            touching["solBTC"].append({"sig": sig, "blockTime": bt, "err": r.get("err"), "names": sorted(names), "feePayer": fp})
        if r.get("touches_solETH_reserve"):
            touching["solETH"].append({"sig": sig, "blockTime": bt, "err": r.get("err"), "names": sorted(names), "feePayer": fp})

    summary = {
        "endpoint_used_redacted": url.split("//", 1)[-1].split("/", 1)[0],
        "signatures_listed": len(sigs),
        "oldest_blockTime_listed": min((s.get("blockTime") or 9e18) for s in sigs if s.get("blockTime")),
        "txs_fetched_ok": sum(1 for r in results.values() if r and not r.get("error")),
        "txs_requested": min(len(sigs), MAX_TX),
        "jet_txs": jet_n,
        "date_range": {"min_iso": time.strftime("%Y-%m-%d %H:%M", time.gmtime(min(dates))) if dates else None,
                       "max_iso": time.strftime("%Y-%m-%d %H:%M", time.gmtime(max(dates))) if dates else None},
        "instruction_counts": dict(sorted(ix_counts.items(), key=lambda kv: -kv[1])),
        "instruction_counts_with_err": dict(sorted(ix_err.items(), key=lambda kv: -kv[1])),
        "distinct_signers": len(signer_counts),
        "top_signers": sorted(signer_counts.items(), key=lambda kv: -kv[1])[:30],
        "top_fee_payers": sorted(fee_payers.items(), key=lambda kv: -kv[1])[:30],
        "txs_invoking_bot_program": bot_invoked,
        "nonbot_borrow_deposit_like_txs": nonbot_bd,
        "touching_solBTC_reserve": touching["solBTC"],
        "touching_solETH_reserve": touching["solETH"],
    }
    # merge fetched data into activity_census2.json and write md
    json.dump({"summary": summary, "txs": results}, open(os.path.join(HERE, "activity_census2.json"), "w"), indent=1)
    lines = ["# Jet v1 program activity census (archival fetch)", ""]
    w = lines.append
    w(f"- signatures listed: {summary['signatures_listed']} (oldest {time.strftime('%Y-%m-%d', time.gmtime(summary['oldest_blockTime_listed']))} UTC)")
    w(f"- transactions fetched OK: {summary['txs_fetched_ok']} / {summary['txs_requested']}")
    w(f"- Jet txs: {summary['jet_txs']}; date range: {summary['date_range']['min_iso']} .. {summary['date_range']['max_iso']} UTC")
    w(f"- distinct signers: {summary['distinct_signers']}; bot-program-invoking txs: {summary['txs_invoking_bot_program']}")
    w("")
    w("## Instruction counts (top-level + inner CPI, successes and failures)")
    w("")
    w("| instruction | count | with err |")
    w("|---|---|---|")
    for name, c in summary["instruction_counts"].items():
        w(f"| {name} | {c} | {summary['instruction_counts_with_err'].get(name, 0)} |")
    w("")
    w("## Top signers")
    for s_, c in summary["top_signers"]:
        w(f"- {s_}: {c}")
    w("")
    w(f"## Non-bot borrow/deposit-like txs: {len(nonbot_bd)}")
    for t in nonbot_bd[:100]:
        w(f"- {t['sig']} {t.get('blockTime')} {t.get('names')} feePayer={t.get('feePayer')} err={t.get('err')}")
    w("")
    w(f"## Txs touching solBTC reserve: {len(touching['solBTC'])}; solETH reserve: {len(touching['solETH'])}")
    for k in ("solBTC", "solETH"):
        for t in touching[k][:60]:
            w(f"- [{k}] {t['sig']} {t.get('blockTime')} {t.get('names')} err={t.get('err')} feePayer={t.get('feePayer')}")
    open(os.path.join(HERE, "activity_census.md"), "w").write("\n".join(lines) + "\n")
    print(json.dumps({k: v for k, v in summary.items() if k not in ("top_signers", "top_fee_payers", "touching_solBTC_reserve", "touching_solETH_reserve")}, indent=1))


if __name__ == "__main__":
    asyncio.run(main())
