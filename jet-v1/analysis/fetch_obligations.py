#!/usr/bin/env python3
"""Fetch all Jet v1 Obligation accounts (read-only, keyless public RPCs).

Step 1: getProgramAccounts + memcmp(discriminator) + dataSlice -> pubkey list.
Step 2: getMultipleAccounts in batches of 100 -> full account data (base64).
Raw batches are gzipped to analysis/raw_batches/ for resumability.
No secrets are stored; endpoints are keyless public RPCs.
"""
import asyncio, base64, gzip, json, os, sys, time, random

import aiohttp

HERE = os.path.dirname(os.path.abspath(__file__))
DISC = bytes.fromhex("a8ce8d6a584caca7")
DISC_B58 = "VEdzkJnDweW"  # base58 of disc (memcmp filter encoding)
PROGRAM = "JPv1rCqrhagNNmJVM5J1he7msQ5ybtvE1nNuHpDHMNU"

RPC_PRIMARY = "https://api.mainnet-beta.solana.com"
RPC_FALLBACK = "https://solana-rpc.publicnode.com"
KEYS_FILE = os.path.join(HERE, "obligations_keys.json")
RAW_DIR = os.path.join(HERE, "raw_batches")
BATCH = 100
CONCURRENCY = 3

UA = {"Content-Type": "application/json", "User-Agent": "research-readonly/1.0"}


async def rpc_call(session, url, payload, timeout=90):
    async with session.post(url, json=payload, headers=UA, timeout=aiohttp.ClientTimeout(total=timeout)) as r:
        txt = await r.text()
        if r.status == 429:
            raise RuntimeError(f"429 from {url}")
        d = json.loads(txt)
        if "error" in d:
            err = d["error"]
            raise RuntimeError(f"rpc error {json.dumps(err)[:300]}")
        return d["result"]


async def rpc(session, method, params, retries=7):
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    last = None
    for i in range(retries):
        for url in (RPC_PRIMARY, RPC_FALLBACK):
            try:
                return await rpc_call(session, url, payload)
            except Exception as e:  # noqa: BLE001
                last = e
        await asyncio.sleep(min(2 ** i, 45) + random.random() * 0.5)
    raise RuntimeError(f"{method} failed after {retries} retries: {last}")


async def fetch_keys():
    if os.path.exists(KEYS_FILE):
        d = json.load(open(KEYS_FILE))
        print(f"reuse keys file: {len(d['pubkeys'])} keys, slot {d['slot']}", file=sys.stderr)
        return d["pubkeys"]
    async with aiohttp.ClientSession() as s:
        res = await rpc(s, "getProgramAccounts", [
            PROGRAM,
            {"encoding": "base64", "commitment": "finalized",
             "filters": [{"memcmp": {"offset": 0, "bytes": DISC_B58}}],
             "dataSlice": {"offset": 0, "length": 8}},
        ])
    pubkeys = [r["pubkey"] for r in res]
    # sanity: every returned account is 8 bytes of the right discriminator
    bad = [r for r in res if r["account"]["data"][0] != base64.b64encode(DISC).decode()]
    assert not bad, f"{len(bad)} accounts with unexpected discriminator"
    d = {"slot": None, "count": len(pubkeys), "pubkeys": pubkeys}
    json.dump(d, open(KEYS_FILE, "w"))
    print(f"fetched {len(pubkeys)} obligation keys -> {KEYS_FILE}", file=sys.stderr)
    return pubkeys


async def fetch_batch(session, sem, idx, keys, slot):
    """Fetch one batch of <=100 accounts; gzip raw result. Returns dict pk->b64."""
    path = os.path.join(RAW_DIR, f"batch_{idx:04d}.json.gz")
    if os.path.exists(path):
        with gzip.open(path, "rt") as f:
            return json.load(f)
    async with sem:
        res = await rpc(session, "getMultipleAccounts", [
            keys, {"encoding": "base64", "commitment": "finalized"}])
        ctx_slot = res.get("context", {}).get("slot") if isinstance(res, dict) and "context" in res else None
        vals = res["value"] if isinstance(res, dict) and "value" in res else res
        out = {}
        for pk, v in zip(keys, vals):
            if v is None:
                print(f"WARN missing account {pk}", file=sys.stderr)
                out[pk] = None
            else:
                out[pk] = {"lamports": v["lamports"], "owner": v["owner"], "space": v["space"],
                           "data_b64": v["data"][0]}
        tmp = path + ".tmp"
        with gzip.open(tmp, "wt") as f:
            json.dump({"ctx_slot": ctx_slot, "accounts": out}, f)
        os.replace(tmp, path)
        print(f"batch {idx}: {len(out)} accounts (slot~{ctx_slot})", file=sys.stderr)
        return out


async def main():
    os.makedirs(RAW_DIR, exist_ok=True)
    keys = await fetch_keys()
    n_batches = (len(keys) + BATCH - 1) // BATCH
    batches = [keys[i * BATCH:(i + 1) * BATCH] for i in range(n_batches)]
    sem = asyncio.Semaphore(CONCURRENCY)
    connector = aiohttp.TCPConnector(limit=CONCURRENCY + 2)
    async with aiohttp.ClientSession(connector=connector) as s:
        results = await asyncio.gather(*[fetch_batch(s, sem, i, b, None) for i, b in enumerate(batches)])
    total = sum(len(r) for r in results)
    missing = sum(1 for r in results for pk, v in r.items() if v is None)
    print(f"done: {total} accounts in {n_batches} batches, {missing} missing", file=sys.stderr)


if __name__ == "__main__":
    asyncio.run(main())
