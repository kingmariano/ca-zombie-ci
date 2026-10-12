#!/usr/bin/env python3
"""Rate-limited activity fetch (Tatum public gateway allows 5 requests/minute).

Priority order: (P1) signatures in the last 30 days; (P2) signatures in the Jul 19-23
burst window; (P3) everything else newest-first. Writes merged results into
activity_census2.json (all previously fetched entries are kept).
"""
import asyncio, base64, json, os, sys, time
import aiohttp

HERE = os.path.dirname(os.path.abspath(__file__))
JET = "JPv1rCqrhagNNmJVM5J1he7msQ5ybtvE1nNuHpDHMNU"
BOT = "C3MPbLBQbREEJ56ku8SNHrHMh5q3iYKUkAYFQdvmcWP8"
SOLBTC = "GqPX7JNRKQ9eTqUxG9zZUm5zQqKSv2gnWqRzLRz6hN29"
SOLETH = "2X39AAQzsY7YFLvoLQ5kSd7cJDLn5EEDkgFrFUfqhG1M"
URL = "https://solana-mainnet.gateway.tatum.io"
UA = {"Content-Type": "application/json", "User-Agent": "research-readonly/1.0"}
RATE_PER_MIN = 4.5   # stay under 5/min
MAX_TOTAL = 1000

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


class RateGate:
    def __init__(self, per_min):
        self.interval = 60.0 / per_min
        self.last = 0.0
        self.lock = asyncio.Lock()
    async def wait(self):
        async with self.lock:
            now = time.time()
            wait = self.last + self.interval - now
            if wait > 0:
                await asyncio.sleep(wait)
                now = time.time()
            self.last = now


async def main():
    d = json.load(open(os.path.join(HERE, "activity_census2.json")))
    results = d["txs"]
    sigs = json.load(open(os.path.join(HERE, "activity_signatures.json")))["signatures"]
    now = time.time()
    need = [s for s in sigs if not (results.get(s["signature"]) and not results[s["signature"]].get("error"))]
    p1 = [s for s in need if (s.get("blockTime") or 0) >= now - 30 * 86400]
    p2 = [s for s in need if 1784000000 <= (s.get("blockTime") or 0) < 1784800000]  # Jul 19-23ish
    p3 = [s for s in need if s not in p1 and s not in p2]
    order = p1 + p2 + p3
    order = order[:MAX_TOTAL]
    print(f"todo P1(30d)={len(p1)} P2(Jul burst)={len(p2)} P3(rest)={len(p3)}; fetching {len(order)} at {RATE_PER_MIN}/min", file=sys.stderr)

    gate = RateGate(RATE_PER_MIN)
    fetched = [0]
    log = open(os.path.join(HERE, "rate_limited_progress.log"), "a", buffering=1)
    async with aiohttp.ClientSession() as sess:
        for s in order:
            sig = s["signature"]
            stored = False
            for attempt in range(5):
                await gate.wait()
                try:
                    async with sess.post(URL, json={"jsonrpc": "2.0", "id": 1, "method": "getTransaction",
                                                    "params": [sig, {"encoding": "jsonParsed",
                                                                     "maxSupportedTransactionVersion": 0,
                                                                     "commitment": "finalized"}]},
                                         headers=UA, timeout=aiohttp.ClientTimeout(total=60)) as r:
                        txt = await r.text()
                    dd = json.loads(txt)
                    if isinstance(dd, dict) and dd.get("result"):
                        hits, keys = classify(dd["result"])
                        results[sig] = pack(dd["result"], keys, hits)
                        stored = True
                        break
                    if isinstance(dd, dict) and "statusCode" in dd and dd.get("statusCode") == 429:
                        log.write(f"{time.strftime('%H:%M:%S')} 429 {sig[:12]} attempt {attempt}\n")
                        continue
                    # genuine null (not found)
                    results[sig] = {"error": "null"}
                    stored = True
                    break
                except Exception as e:  # noqa: BLE001
                    log.write(f"{time.strftime('%H:%M:%S')} EXC {sig[:12]} {type(e).__name__} attempt {attempt}\n")
                    if attempt == 4:
                        results[sig] = {"error": str(e)[:150]}
            if not stored and not results.get(sig):
                results[sig] = {"error": "unfetched"}
            fetched[0] += 1
            okn = sum(1 for r in results.values() if r and not r.get("error"))
            log.write(f"{time.strftime('%H:%M:%S')} [{fetched[0]}/{len(order)}] {sig[:12]} ok={okn}\n")
            if fetched[0] % 20 == 0:
                print(f"  {fetched[0]}/{len(order)} done; total OK {okn}/{len(results)}", file=sys.stderr)
                json.dump(d, open(os.path.join(HERE, "activity_census2.json"), "w"))
    json.dump(d, open(os.path.join(HERE, "activity_census2.json"), "w"))
    ok = sum(1 for r in results.values() if r and not r.get("error"))
    print(f"done: {ok}/{len(results)} OK", file=sys.stderr)


if __name__ == "__main__":
    asyncio.run(main())
