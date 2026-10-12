#!/usr/bin/env python3
"""Retry pass for activity txs that returned null/errors (Tatum public gateway).

Re-fetches failed entries from activity_census2.json one at a time (low concurrency),
retrying on null for up to 5 attempts. Merges results back into activity_census2.json.
"""
import asyncio, base64, json, os, sys, time
import aiohttp

HERE = os.path.dirname(os.path.abspath(__file__))
JET = "JPv1rCqrhagNNmJVM5J1he7msQ5ybtvE1nNuHpDHMNU"
BOT = "C3MPbLBQbREEJ56ku8SNHrHMh5q3iYKUkAYFQdvmcWP8"
SOLBTC = "GqPX7JNRKQ9eTqUxG9zZUm5zQqKSv2gnWqRzLRz6hN29"
SOLETH = "2X39AAQzsY7YFLvoLQ5kSd7cJDLn5EEDkgFrFUfqhG1M"
URL = os.environ.get("SOLANA_RPC_URL", "https://solana-mainnet.gateway.tatum.io")
UA = {"Content-Type": "application/json", "User-Agent": "research-readonly/1.0"}

import hashlib, re
def snake(n): return re.sub(r"(?<!^)(?=[A-Z])", "_", n).lower()
IDL = json.load(open(os.path.join(HERE, "jet_idl_v020.json")))
D2N = {hashlib.sha256(("global:" + snake(i["name"])).encode()).digest()[:8]: i["name"] for i in IDL["instructions"]}


def decode_data(data):
    try:
        return __import__("base58").b58decode(data)
    except Exception:  # noqa: BLE001
        try:
            return base64.b64decode(data)
        except Exception:  # noqa: BLE001
            return b""


def classify(tx):
    hits = []
    msg = (tx.get("transaction") or {}).get("message") or {}
    keys = [k["pubkey"] if isinstance(k, dict) else k for k in msg.get("accountKeys", [])]
    def scan(ixs):
        for ix in ixs or []:
            if ix.get("programId") != JET:
                continue
            raw = decode_data(ix.get("data") or "")
            hits.append({"disc": raw[:8].hex(), "name": D2N.get(raw[:8], "unknown:" + raw[:8].hex()),
                         "accounts": ix.get("accounts", [])})
    scan(msg.get("instructions"))
    for inner in ((tx.get("meta") or {}).get("innerInstructions") or []):
        scan(inner.get("instructions"))
    return hits, keys


def pack(tx, keys, hits):
    msg = (tx.get("transaction") or {}).get("message") or {}
    signers = [k["pubkey"] for k in msg.get("accountKeys", []) if isinstance(k, dict) and k.get("signer")]
    programs = set()
    for ix in msg.get("instructions", []) or []:
        programs.add(ix.get("programId"))
    for inner in (tx.get("meta") or {}).get("innerInstructions", []) or []:
        for ix in inner.get("instructions", []) or []:
            programs.add(ix.get("programId"))
    return {"slot": tx.get("slot"), "blockTime": tx.get("blockTime"),
            "err": bool((tx.get("meta") or {}).get("err")), "fee": (tx.get("meta") or {}).get("fee"),
            "signers": signers, "feePayer": signers[0] if signers else None,
            "programs": sorted(p for p in programs if p), "jetIx": hits,
            "touches_solBTC_reserve": SOLBTC in keys, "touches_solETH_reserve": SOLETH in keys,
            "accounts": keys}


async def fetch_one(sess, sig, attempts=6):
    for a in range(attempts):
        try:
            async with sess.post(URL, json={"jsonrpc": "2.0", "id": 1, "method": "getTransaction",
                                            "params": [sig, {"encoding": "jsonParsed",
                                                             "maxSupportedTransactionVersion": 0,
                                                             "commitment": "finalized"}]},
                                 headers=UA, timeout=aiohttp.ClientTimeout(total=60)) as r:
                txt = await r.text()
            d = json.loads(txt)
            tx = d.get("result")
            if tx:
                hits, keys = classify(tx)
                return pack(tx, keys, hits)
        except Exception:  # noqa: BLE001
            pass
        await asyncio.sleep(1.0 + a * 1.5)
    return None


async def main():
    path = os.path.join(HERE, "activity_census2.json")
    d = json.load(open(path))
    results = d["txs"]
    todo = [s for s, r in results.items() if not r or r.get("error")]
    todo.sort(key=lambda s: -len(results.get(s, {}).get("accounts", []) or []))  # noop, stable
    print(f"retrying {len(todo)} failed txs at concurrency 2", file=sys.stderr)
    sem = asyncio.Semaphore(2)
    done = [0]

    async def worker(sig):
        async with sem:
            r = await fetch_one(sess_holder["s"], sig)
            if r:
                results[sig] = r
            done[0] += 1
            if done[0] % 25 == 0:
                print(f"  {done[0]}/{len(todo)} (ok now: {sum(1 for v in todo if results.get(v) and not results[v].get('error'))})", file=sys.stderr)
                json.dump(d, open(path, "w"))

    async with aiohttp.ClientSession() as sess:
        sess_holder = {"s": sess}
        # limited parallelism but not too slow
        await asyncio.gather(*[worker(s) for s in todo])
    json.dump(d, open(path, "w"))
    ok = sum(1 for r in results.values() if r and not r.get("error"))
    print(f"done: {ok}/{len(results)} results OK", file=sys.stderr)


if __name__ == "__main__":
    asyncio.run(main())
