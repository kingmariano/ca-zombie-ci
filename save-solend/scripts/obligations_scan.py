#!/usr/bin/env python3
"""
Solend / Save v1 (So1endDq2YkqhipRh3WViPa8hdiSpxWy6z3Z6tMCpAo) obligation
scanner -- READ ONLY.

Uses only public, keyless RPC endpoints. Sends no transactions, signs nothing.

What it does
------------
1. For every Solend v1 market whose stored value is >= --min-usd (plus the main
   market 4UpD2fh7xH3VP9QQaXtsS1YY3bxzWhtfpks7FatyKvdY), enumerates all
   obligation accounts (dataSize == 1300) belonging to that market via
   getProgramAccounts with a 204-byte header dataSlice.

2. Decodes each obligation header (Pack layout of deployed build d04ce00b):
     byte   0        version
     bytes  1..9     last_update slot (u64 LE)
     byte   9        stale
     bytes  10..42   lending_market pubkey
     bytes  42..74   owner pubkey
     bytes  74..90   deposited_value            (u128 LE / 1e18)
     bytes  90..106  borrowed_value             (u128 LE / 1e18)
     bytes 106..122  allowed_borrow_value       (u128 LE / 1e18)
     bytes 122..138  unhealthy_borrow_value     (u128 LE / 1e18)
     bytes 138..154  borrowed_value_upper_bound (u128 LE / 1e18)
     byte  154       borrowing_isolated_asset
     bytes 155..171  super_unhealthy_borrow_value
     bytes 171..187  unweighted_borrowed_value
     byte  187       closeable
     byte  202       deposits_len        (byte 202)
     byte  203       borrows_len         (byte 203)
   Deposits follow the header (88 bytes each):
     reserve pubkey 32, deposited_amount u64, market_value u128,
     attributed_borrow_value u128, pad 16
   Borrows follow the deposits (112 bytes each):
     reserve pubkey 32, cumulative_borrow_rate u128, borrowed_amount_wads u128,
     market_value u128, pad 32
   Lists are packed sequentially; bytes beyond deposits_len/borrows_len can
   contain stale residue and MUST be ignored.

   Classification (integer comparisons on the raw stored values):
     live debt        : borrows_len > 0 (a stale header may carry nonzero
                        values with an empty borrow list -- those are not
                        liquidatable, so they are excluded)
     insane           : stored borrowed_value > $1B (garbage values observed
                        on a handful of stale main-pool accounts; excluded
                        from bucket sums and classification, counted separately)
     liquidatable_now : live, sane, unhealthy_borrow_value > 0
                        and borrowed_value >= unhealthy_borrow_value
     near95           : live, sane, not liquidatable_now, and
                        borrowed_value >= 0.95 * unhealthy_borrow_value
     health           : allowed_borrow_value / borrowed_value_upper_bound
                        (when upper bound > 0)
   Ratio buckets (borrowed USD sums by borrowed/unhealthy ratio) are computed
   over live+sane obligations with unhealthy > 0, mirroring the parent
   session's main-obligation-stats.json for cross-checking.

3. Fetches the full 1300-byte accounts for the liquidatable + near95 set via
   getMultipleAccounts (batches of 100) and decodes deposits/borrows with the
   layout above. Reserve pubkeys are joined to symbols via reserves.json.

4. Writes:
     analysis/obligations-summary.md      per-market table + top-30 liquidatable
     analysis/obligations-unhealthy.json  full decoded liquidatable+near list
     analysis/obligations-counts.json     per-market counts (cheap recompute)

RPC politeness: strictly sequential calls, >= --sleep seconds (default 1.0)
between call starts, exponential backoff on 429/5xx/network errors, endpoint
failover across the two public endpoints. If a single getProgramAccounts call
for a market fails, the market is re-scanned in 256 owner-first-byte shards;
as a last resort a shard is counted with a 74-byte dataSlice (count only).
Coverage gaps are recorded per market and reported honestly.

No cache is written anywhere outside the output directory; nothing is written
outside --outdir.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import random
import sys
import time
from datetime import datetime, timezone

try:
    import requests
except ImportError:  # pragma: no cover
    sys.exit("requires: pip install requests")

try:
    import base58
except ImportError:  # pragma: no cover
    sys.exit("requires: pip install base58")


PROGRAM_ID = "So1endDq2YkqhipRh3WViPa8hdiSpxWy6z3Z6tMCpAo"
MAIN_MARKET = "4UpD2fh7xH3VP9QQaXtsS1YY3bxzWhtfpks7FatyKvdY"
DEFAULT_RPCS = [
    "https://api.mainnet-beta.solana.com",
    "https://solana-rpc.publicnode.com",
]

OBLIGATION_SIZE = 1300
HEADER_LEN = 204
DEPOSIT_LEN = 88
BORROW_LEN = 112
SCALE = 10 ** 18
FULL_BATCH = 100

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)  # .../save-solend


def b58(b: bytes) -> str:
    return base58.b58encode(b).decode()


def u64(b: bytes) -> int:
    return int.from_bytes(b, "little")


def u128(b: bytes) -> int:
    return int.from_bytes(b, "little")


def usd(v: int) -> float:
    return v / SCALE


def iso_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class RpcError(Exception):
    pass


class Rpc:
    """Minimal sequential JSON-RPC client with throttling, retries, failover."""

    def __init__(self, endpoints, sleep_s=1.0, timeout=180, max_attempts=9):
        self.endpoints = endpoints
        self.sleep_s = sleep_s
        self.timeout = timeout
        self.max_attempts = max_attempts
        self._last_call = 0.0
        self._ep = 0
        self.calls = 0
        self.retries = 0
        self.bytes_in = 0
        self.session = requests.Session()
        self.session.trust_env = False
        self.session.headers.update({"Content-Type": "application/json"})

    def _throttle(self):
        wait = self.sleep_s - (time.time() - self._last_call)
        if wait > 0:
            time.sleep(wait)

    def call(self, method, params):
        backoff = 1.0
        last_err = None
        for attempt in range(1, self.max_attempts + 1):
            ep = self.endpoints[self._ep % len(self.endpoints)]
            self._throttle()
            try:
                resp = self.session.post(
                    ep,
                    data=json.dumps(
                        {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
                    ),
                    timeout=self.timeout,
                )
                self._last_call = time.time()
                self.calls += 1
                self.bytes_in += len(resp.content)

                if resp.status_code in (403, 429) or resp.status_code >= 500:
                    # public endpoints temporarily "Request blocked" heavy methods
                    msg = f"HTTP {resp.status_code} from {ep}: {resp.text[:120]}"
                    if attempt < self.max_attempts:
                        self.retries += 1
                        time.sleep(backoff + random.random())
                        backoff = min(backoff * 2, 150.0)
                        self._ep += 1
                        continue
                    raise RpcError(msg)
                if resp.status_code != 200:
                    raise RpcError(f"HTTP {resp.status_code}: {resp.text[:200]}")

                body = resp.json()
                if "error" in body:
                    err = body["error"]
                    msg = str(err.get("message", err))
                    retryable = (
                        err.get("code") == -32005
                        or "rate" in msg.lower()
                        or "429" in msg
                        or "timeout" in msg.lower()
                        or "blocked" in msg.lower()
                    )
                    if retryable and attempt < self.max_attempts:
                        self.retries += 1
                        time.sleep(backoff + random.random())
                        backoff = min(backoff * 2, 150.0)
                        self._ep += 1
                        continue
                    raise RpcError(f"RPC error {err.get('code')}: {msg}")
                return body["result"]
            except RpcError:
                raise
            except requests.RequestException as exc:
                self._last_call = time.time()
                last_err = RpcError(f"network error from {ep}: {exc}")
                if attempt < self.max_attempts:
                    self.retries += 1
                    time.sleep(backoff + random.random())
                    backoff = min(backoff * 2, 150.0)
                    self._ep += 1
                    continue
                raise last_err
        raise last_err or RpcError("unreachable")


def gpa(rpc: Rpc, market: str, slice_len: int = HEADER_LEN, owner_prefix=None):
    """getProgramAccounts for obligations of one market, header slice only."""
    filters = [
        {"dataSize": OBLIGATION_SIZE},
        {"memcmp": {"offset": 10, "bytes": market}},
    ]
    if owner_prefix is not None:
        filters.append({"memcmp": {"offset": 42, "bytes": b58(owner_prefix)}})
    params = [
        PROGRAM_ID,
        {
            "encoding": "base64",
            "filters": filters,
            "dataSlice": {"offset": 0, "length": slice_len},
        },
    ]
    return rpc.call("getProgramAccounts", params)


def decode_header(pubkey: str, b: bytes) -> dict:
    if len(b) < 74:
        return {"obligation": pubkey, "countOnly": True, "headerLen": len(b)}
    rec = {
        "obligation": pubkey,
        "version": b[0],
        "lastUpdateSlot": u64(b[1:9]),
        "stale": b[9] != 0,
        "lendingMarket": b58(b[10:42]),
        "owner": b58(b[42:74]),
    }
    if len(b) >= HEADER_LEN:
        rec.update(
            {
                "depositedRaw": u128(b[74:90]),
                "borrowedRaw": u128(b[90:106]),
                "allowedBorrowRaw": u128(b[106:122]),
                "unhealthyRaw": u128(b[122:138]),
                "borrowedUpperRaw": u128(b[138:154]),
                "borrowingIsolated": b[154] != 0,
                "superUnhealthyRaw": u128(b[155:171]),
                "unweightedBorrowedRaw": u128(b[171:187]),
                "closeable": b[187] != 0,
                "depositsLen": b[202],
                "borrowsLen": b[203],
            }
        )
    return rec


INSANE_BORROWED_RAW = 10 ** 27  # $1B stored borrowed_value => garbage


def classify(rec: dict) -> str:
    """Status of an obligation per its stored header values.

    'no_debt'  : borrows_len == 0 (empty borrow list; header may be stale)
    'insane'   : absurd stored borrowed value (garbage)
    'liquidatable_now' / 'near95' / 'healthy'
    """
    if rec.get("borrowsLen", 0) == 0:
        return "no_debt"
    if rec["borrowedRaw"] > INSANE_BORROWED_RAW:
        return "insane"
    bv = rec["borrowedRaw"]
    ubv = rec["unhealthyRaw"]
    if ubv > 0 and bv >= ubv:
        return "liquidatable_now"
    if ubv > 0 and bv * 100 >= ubv * 95:
        return "near95"
    return "healthy"


def scan_market(rpc: Rpc, market: str, log) -> tuple:
    """Return (gpa_items, info). Falls back to owner-prefix sharding."""
    info = {"path": "single", "errors": [], "partial": False, "countOnly": False}
    try:
        items = gpa(rpc, market)
        info["count"] = len(items)
        return items, info
    except RpcError as exc:
        info["errors"].append(f"single-call failed: {exc}")
        log(f"      single call failed ({exc}); retrying in 256 owner shards")

    items = []
    failed = []
    for i in range(256):
        try:
            items.extend(gpa(rpc, market, owner_prefix=bytes([i])))
        except RpcError as exc:
            failed.append((i, str(exc)))
    if failed:
        log(f"      {len(failed)} shards failed, retrying count-only")
        still = []
        for i, _ in failed:
            try:
                items.extend(gpa(rpc, market, slice_len=74, owner_prefix=bytes([i])))
                info["countOnly"] = True
            except RpcError as exc:
                still.append((i, str(exc)))
        info["errors"].extend(f"shard {i}: {m}" for i, m in still)
        info["partial"] = len(still) > 0
    info["path"] = "sharded" + ("+count_only" if info["countOnly"] else "")
    info["count"] = len(items)
    return items, info


def decode_full(pubkey: str, raw: bytes) -> dict:
    """Decode a full 1300-byte obligation account."""
    rec = decode_header(pubkey, raw)
    rec.pop("countOnly", None)
    d = raw[202]
    bl = raw[203]
    rec["depositsLen"] = d
    rec["borrowsLen"] = bl
    rec["malformed"] = HEADER_LEN + DEPOSIT_LEN * d + BORROW_LEN * bl > len(raw)
    off = HEADER_LEN
    deposits = []
    for _ in range(d):
        chunk = raw[off : off + DEPOSIT_LEN]
        off += DEPOSIT_LEN
        deposits.append(
            {
                "reserve": b58(chunk[0:32]),
                "depositedAmount": u64(chunk[32:40]),
                "marketValueRaw": u128(chunk[40:56]),
                "attributedBorrowRaw": u128(chunk[56:72]),
            }
        )
    borrows = []
    for _ in range(bl):
        chunk = raw[off : off + BORROW_LEN]
        off += BORROW_LEN
        borrows.append(
            {
                "reserve": b58(chunk[0:32]),
                "cumulativeBorrowRateRaw": u128(chunk[32:48]),
                "borrowedAmountWadsRaw": u128(chunk[48:64]),
                "marketValueRaw": u128(chunk[64:80]),
            }
        )
    rec["deposits"] = deposits
    rec["borrows"] = borrows
    return rec


def jrec(rec: dict, market: dict, rmap: dict, status: str) -> dict:
    """Build the JSON output record."""

    def dep_out(x):
        meta = rmap.get(x["reserve"], {})
        dec = meta.get("decimals", 9)
        return {
            "reserve": x["reserve"],
            "symbol": meta.get("symbol", x["reserve"][:8] + ".."),
            "decimals": dec,
            "amount": x["depositedAmount"] / (10 ** dec),
            "marketValueUsd": round(usd(x["marketValueRaw"]), 6),
            "attributedBorrowValueUsd": round(usd(x["attributedBorrowRaw"]), 6),
        }

    def bor_out(x):
        meta = rmap.get(x["reserve"], {})
        dec = meta.get("decimals", 9)
        return {
            "reserve": x["reserve"],
            "symbol": meta.get("symbol", x["reserve"][:8] + ".."),
            "decimals": dec,
            "amount": x["borrowedAmountWadsRaw"] / SCALE,
            "cumulativeBorrowRate": x["cumulativeBorrowRateRaw"] / SCALE,
            "marketValueUsd": round(usd(x["marketValueRaw"]), 6),
        }

    upper = rec["borrowedUpperRaw"]
    health = round(rec["allowedBorrowRaw"] / upper, 6) if upper > 0 else None
    liq_ratio = (
        round(rec["borrowedRaw"] / rec["unhealthyRaw"], 6)
        if rec["unhealthyRaw"] > 0
        else None
    )
    return {
        "market": market["market"],
        "marketName": market["name"],
        "obligation": rec["obligation"],
        "owner": rec["owner"],
        "status": status,
        "fullAccountDecoded": "deposits" in rec,
        "fetchError": rec.get("fetchError"),
        "lastUpdateSlot": rec["lastUpdateSlot"],
        "stale": rec["stale"],
        "borrowingIsolatedAsset": rec["borrowingIsolated"],
        "closeable": rec["closeable"],
        "depositedValueUsd": round(usd(rec["depositedRaw"]), 6),
        "borrowedValueUsd": round(usd(rec["borrowedRaw"]), 6),
        "borrowedValueUpperBoundUsd": round(usd(rec["borrowedUpperRaw"]), 6),
        "allowedBorrowValueUsd": round(usd(rec["allowedBorrowRaw"]), 6),
        "unhealthyBorrowValueUsd": round(usd(rec["unhealthyRaw"]), 6),
        "superUnhealthyBorrowValueUsd": round(usd(rec["superUnhealthyRaw"]), 6),
        "unweightedBorrowedValueUsd": round(usd(rec["unweightedBorrowedRaw"]), 6),
        "health": health,
        "liqRatio": liq_ratio,
        "deposits": [dep_out(x) for x in rec.get("deposits", [])],
        "borrows": [bor_out(x) for x in rec.get("borrows", [])],
    }


def fmt_usd(x: float) -> str:
    if x is None:
        return "-"
    if abs(x) >= 1_000:
        return f"{x:,.0f}"
    if abs(x) >= 1:
        return f"{x:,.2f}"
    return f"{x:.6f}"


def md_safe(s: str) -> str:
    return str(s).replace("|", "/").replace("\n", " ").strip()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--markets-file",
        default=os.path.join(ROOT, "analysis", "funded-markets.json"),
    )
    ap.add_argument(
        "--reserves-file",
        default=os.path.join(ROOT, "analysis", "reserves.json"),
    )
    ap.add_argument("--outdir", default=os.path.join(ROOT, "analysis"))
    ap.add_argument(
        "--cache-dir",
        default=os.path.join(ROOT, ".cache", "obligations"),
        help="resumable cache for full-account fetches (inside the repo)",
    )
    ap.add_argument("--no-cache", action="store_true")
    ap.add_argument("--min-usd", type=float, default=1000.0)
    ap.add_argument("--sleep", type=float, default=1.0)
    ap.add_argument("--rpc", action="append", default=None)
    ap.add_argument("--max-markets", type=int, default=0)
    ap.add_argument("--markets", default=None, help="comma-separated market ids")
    args = ap.parse_args()

    endpoints = args.rpc or DEFAULT_RPCS
    rpc = Rpc(endpoints, sleep_s=args.sleep)

    markets = json.load(open(args.markets_file))
    reserves = json.load(open(args.reserves_file))
    rmap = {r["reserve"]: r for r in reserves}

    if args.markets:
        wanted = set(args.markets.split(","))
        targets = [m for m in markets if m["market"] in wanted]
    else:
        targets = [
            m
            for m in markets
            if m["storedUsd"] >= args.min_usd or m["market"] == MAIN_MARKET
        ]
    if args.max_markets:
        targets = targets[: args.max_markets]

    log = lambda s: print(s, flush=True)
    started = iso_now()
    slot_start = rpc.call("getSlot", [])
    log(f"[{started}] program={PROGRAM_ID}")
    log(f"scan start slot={slot_start}; targets={len(targets)} markets")

    market_results = []
    unhealthy_recs = []  # (market dict, header rec)
    market_of = {}

    for idx, m in enumerate(targets, 1):
        market = m["market"]
        t0 = time.time()
        try:
            slot_at = rpc.call("getSlot", [])
        except RpcError as exc:
            slot_at = None
            log(f"  !! getSlot failed: {exc}")
        try:
            items, info = scan_market(rpc, market, log)
        except RpcError as exc:
            info = {"path": "failed", "errors": [str(exc)], "partial": True, "count": 0}
            items = []
        recs = []
        for it in items:
            try:
                raw = base64.b64decode(it["account"]["data"][0])
                recs.append(decode_header(it["pubkey"], raw))
            except Exception as exc:  # malformed inline
                recs.append({"obligation": it.get("pubkey", "?"), "decodeError": str(exc)})

        n = len(recs)
        n_with_debt = 0
        n_liq = 0
        n_near = 0
        n_stale = 0
        n_unh = 0
        n_iso = 0
        n_count_only = 0
        liq_borrowed = 0
        for rec in recs:
            if rec.get("countOnly") or rec.get("decodeError"):
                n_count_only += 1
                continue
            if rec.get("borrowsLen", 0) > 0:
                n_with_debt += 1
            if rec["stale"]:
                n_stale += 1
            if rec["unhealthyRaw"] > 0:
                n_unh += 1
            if rec["borrowingIsolated"]:
                n_iso += 1
            st = classify(rec)
            if st == "liquidatable_now":
                n_liq += 1
                liq_borrowed += rec["borrowedRaw"]
                unhealthy_recs.append((m, rec))
                market_of[rec["obligation"]] = m
            elif st == "near95":
                n_near += 1
                unhealthy_recs.append((m, rec))
                market_of[rec["obligation"]] = m

        market_results.append(
            {
                "market": market,
                "name": m["name"],
                "storedUsd": m["storedUsd"],
                "nReserves": m.get("nReserves"),
                "slotAtScan": slot_at,
                "nObligations": n,
                "nWithDebt": n_with_debt,
                "nLiquidatableNow": n_liq,
                "nNear95": n_near,
                "nStale": n_stale,
                "nUnhealthyPositive": n_unh,
                "nBorrowingIsolated": n_iso,
                "nCountOnly": n_count_only,
                "liquidatableBorrowedUsd": round(liq_borrowed / SCALE, 6),
                "path": info["path"],
                "partial": info["partial"],
                "errors": info["errors"],
                "seconds": round(time.time() - t0, 1),
            }
        )
        log(
            f"  [{idx}/{len(targets)}] {m['name'][:32]:32s} n={n:>7,} debt={n_with_debt:>6,} "
            f"liq={n_liq:>6,} near={n_near:>6,} stale={n_stale:>6,} "
            f"path={info['path']} {time.time()-t0:.1f}s"
        )

    log(
        f"phase 1 done: {len(unhealthy_recs):,} liquidatable+near records across "
        f"{len(market_results)} markets; fetching full accounts..."
    )

    # ---- phase 2: full accounts for liquidatable + near95 ----
    # Resumable cache: fetched accounts are appended to a JSONL file so a
    # re-run (or a retry after a public-RPC block) does not refetch.
    keys = [rec["obligation"] for _, rec in unhealthy_recs]
    full = {}
    fetch_errors = {}
    cache_path = os.path.join(args.cache_dir, "full-accounts.jsonl")
    if os.path.exists(cache_path) and not args.no_cache:
        with open(cache_path) as f:
            for line in f:
                try:
                    item = json.loads(line)
                    full[item["k"]] = item["a"]
                except Exception:
                    continue
        log(f"cache: {len(full):,} full accounts loaded from {cache_path}")
    cache_f = None
    if not args.no_cache:
        os.makedirs(args.cache_dir, exist_ok=True)
        cache_f = open(cache_path, "a")

    def cache_put(batch, res):
        for k, acct in zip(batch, res["value"]):
            full[k] = acct
        if cache_f is not None:
            for k, acct in zip(batch, res["value"]):
                cache_f.write(json.dumps({"k": k, "a": acct}, separators=(",", ":")) + "\n")
            cache_f.flush()

    def fetch_keys(batch):
        """Fetch a list of keys; split on repeated failure."""
        if not batch:
            return
        missing = [k for k in batch if k not in full and k not in fetch_errors]
        if not missing:
            return
        try:
            res = rpc.call("getMultipleAccounts", [missing, {"encoding": "base64"}])
            cache_put(missing, res)
            return
        except RpcError as exc:
            if len(missing) == 1:
                fetch_errors[missing[0]] = str(exc)
                return
            half = len(missing) // 2
            log(f"      batch of {len(missing)} failed ({str(exc)[:90]}); splitting")
            fetch_keys(missing[:half])
            fetch_keys(missing[half:])

    todo = [k for k in keys if k not in full]
    log(f"phase 2: {len(keys):,} keys, {len(todo):,} still to fetch")
    for i in range(0, len(todo), FULL_BATCH):
        fetch_keys(todo[i : i + FULL_BATCH])
        done = min(i + FULL_BATCH, len(todo))
        if (i // FULL_BATCH) % 25 == 0 or done >= len(todo):
            log(f"    fetched {done:,}/{len(todo):,} (total cached {len(full):,})")
    if cache_f is not None:
        cache_f.close()

    # ---- decode + validate + shape records ----
    anomalies = {"reserveMembership": 0, "depositValueMismatch": 0, "borrowValueMismatch": 0,
                 "malformed": 0, "vanished": 0, "fetchFailed": 0, "symbolMiss": 0}
    out_records = []
    market_reserves = {m["market"]: set(m["reserves"]) for m in markets}

    for m, rec in unhealthy_recs:
        key = rec["obligation"]
        acct = full.get(key)
        status = classify(rec)
        if acct is None:
            anomalies["vanished" if key not in fetch_errors else "fetchFailed"] += 1
            base = dict(rec)
            base["status"] = status
            base["fetchError"] = fetch_errors.get(key)
            out_records.append(jrec(base, m, rmap, status))
            continue
        raw = base64.b64decode(acct["data"][0])
        frec = decode_full(key, raw)
        frec["status"] = status
        if frec["malformed"]:
            anomalies["malformed"] += 1
        for x in frec["deposits"] + frec["borrows"]:
            if x["reserve"] not in market_reserves.get(m["market"], set()):
                anomalies["reserveMembership"] += 1
            if x["reserve"] not in rmap:
                anomalies["symbolMiss"] += 1
        dep_sum = sum(x["marketValueRaw"] for x in frec["deposits"])
        bor_sum = sum(x["marketValueRaw"] for x in frec["borrows"])
        for got, want, ctr in (
            (frec["depositedRaw"], dep_sum, "depositValueMismatch"),
            (frec["borrowedRaw"], bor_sum, "borrowValueMismatch"),
        ):
            tol = max(1_000_000_000_000, int(got * 0.005))  # 0.000001 USD / 0.5%
            if abs(got - want) > tol:
                anomalies[ctr] += 1
        out_records.append(jrec(frec, m, rmap, status))

    slot_end = rpc.call("getSlot", [])
    finished = iso_now()
    log(f"scan end slot={slot_end} finished={finished}")

    # ---- outputs ----
    os.makedirs(args.outdir, exist_ok=True)

    totals = {
        "markets": len(market_results),
        "obligations": sum(x["nObligations"] for x in market_results),
        "withDebt": sum(x["nWithDebt"] for x in market_results),
        "liquidatableNow": sum(x["nLiquidatableNow"] for x in market_results),
        "near95": sum(x["nNear95"] for x in market_results),
        "stale": sum(x["nStale"] for x in market_results),
        "unhealthyPositive": sum(x["nUnhealthyPositive"] for x in market_results),
        "liquidatableBorrowedUsd": round(
            sum(x["liquidatableBorrowedUsd"] for x in market_results), 6
        ),
    }

    counts = {
        "program": PROGRAM_ID,
        "mainMarket": MAIN_MARKET,
        "slotStart": slot_start,
        "slotEnd": slot_end,
        "startedAtIso": started,
        "finishedAtIso": finished,
        "rpcEndpoints": endpoints,
        "targetFilter": f"storedUsd >= {args.min_usd} or market == main",
        "criteria": {
            "liquidatableNow": "live (borrows_len > 0) AND sane (borrowed <= $1B) AND unhealthy_borrow_value > 0 AND borrowed_value >= unhealthy_borrow_value",
            "near95": "live AND sane AND not liquidatable AND unhealthy_borrow_value > 0 AND borrowed_value >= 0.95 * unhealthy_borrow_value",
            "health": "allowed_borrow_value / borrowed_value_upper_bound",
            "note": "classification uses the obligation's own stored (last-updated) values; stale obligations may not reflect current reserve prices. Accounts with an empty borrow list can carry stale header values and are excluded from classification (no_debt).",
        },
        "totals": totals,
        "validation": {
            **anomalies,
            "fullAccountsFetched": len(keys) - anomalies["vanished"] - anomalies["fetchFailed"],
            "recordsWritten": len(out_records),
        },
        "rpcStats": {"calls": rpc.calls, "retries": rpc.retries, "bytesIn": rpc.bytes_in},
        "markets": market_results,
    }
    with open(os.path.join(args.outdir, "obligations-counts.json"), "w") as f:
        json.dump(counts, f, indent=1)
    log("wrote obligations-counts.json")

    unhealthy_doc = {
        "program": PROGRAM_ID,
        "slotStart": slot_start,
        "slotEnd": slot_end,
        "scannedAtIso": finished,
        "criteria": counts["criteria"],
        "validation": counts["validation"],
        "total": len(out_records),
        "records": out_records,
    }
    with open(os.path.join(args.outdir, "obligations-unhealthy.json"), "w") as f:
        json.dump(unhealthy_doc, f, separators=(",", ":"))
    log(f"wrote obligations-unhealthy.json ({len(out_records):,} records)")

    # ---- markdown summary ----
    lines = []
    lines.append("# Solend v1 obligations scan -- liquidatable / near-liquidation\n")
    lines.append(f"- Program: `{PROGRAM_ID}`")
    lines.append(
        f"- Scan window: slot **{slot_start}** .. **{slot_end}** "
        f"({started} .. {finished} UTC), public RPC only, sequential calls "
        f"(~{args.sleep:.1f}s spacing)"
    )
    lines.append(
        f"- Targets: **{len(market_results)}** markets "
        f"(stored value >= ${args.min_usd:,.0f} + main)"
    )
    lines.append(
        f"- Totals: **{totals['obligations']:,}** obligations scanned, "
        f"**{totals['withDebt']:,}** with debt, "
        f"**{totals['liquidatableNow']:,}** liquidatable now, "
        f"**{totals['near95']:,}** near (>=95% of unhealthy threshold)"
    )
    lines.append(
        f"- Total debt in liquidatable positions: "
        f"**${totals['liquidatableBorrowedUsd']:,.0f}** (per each obligation's stored values)"
    )
    lines.append(
        "- Classification uses each obligation's own stored (last-updated) values; "
        "`stale=1` marks obligations not recently refreshed. Deposits are the "
        "collateral side; the liquidation path test is "
        "`borrowed_value >= unhealthy_borrow_value` with `unhealthy > 0`.\n"
    )
    lines.append(
        "## Per-market counts\n"
    )
    lines.append(
        "| market | name | storedUsd | nObligations | nWithDebt | nLiquidatableNow "
        "| nNear95 | liqBorrowedUsd | notes/errors |"
    )
    lines.append("|---|---|---|---|---|---|---|---|---|")
    for r in market_results:
        notes = [f"stale={r['nStale']:,}"]
        if r["path"] != "single":
            notes.append(f"path={r['path']}")
        if r["partial"]:
            notes.append("**PARTIAL**")
        if r["errors"]:
            notes.append(f"{len(r['errors'])} error(s)")
        lines.append(
            f"| `{r['market']}` | {md_safe(r['name'])} | {r['storedUsd']:,.0f} | "
            f"{r['nObligations']:,} | {r['nWithDebt']:,} | {r['nLiquidatableNow']:,} | "
            f"{r['nNear95']:,} | {r['liquidatableBorrowedUsd']:,.0f} | {'; '.join(notes)} |"
        )
    lines.append("")

    top = sorted(
        [
            (rec, m)
            for m, rec in unhealthy_recs
            if classify(rec) == "liquidatable_now"
        ],
        key=lambda t: t[0]["borrowedRaw"],
        reverse=True,
    )[:30]
    lines.append("## Top 30 largest liquidatable obligations (by stored borrowed value)\n")
    lines.append(
        "| # | market (name) | owner | borrowedUsd | unhealthyUsd | ratio | collateral deposits |"
    )
    lines.append("|---|---|---|---|---|---|---|")
    for n, (rec, m) in enumerate(top, 1):
        frec = full.get(rec["obligation"])
        coll = "-"
        if frec is not None:
            raw = base64.b64decode(frec["data"][0])
            fr = decode_full(rec["obligation"], raw)
            parts = []
            for x in fr["deposits"]:
                meta = rmap.get(x["reserve"], {})
                dec = meta.get("decimals", 9)
                sym = meta.get("symbol", x["reserve"][:6] + "..")
                parts.append(f"{sym} {x['depositedAmount'] / 10**dec:,.6g}")
            if parts:
                coll = "; ".join(parts)
        ratio = (
            rec["borrowedRaw"] / rec["unhealthyRaw"] if rec["unhealthyRaw"] > 0 else 0
        )
        lines.append(
            f"| {n} | `{rec['lendingMarket'][:6]}..` {md_safe(m['name'])} | "
            f"`{rec['owner']}` | {fmt_usd(usd(rec['borrowedRaw']))} | "
            f"{fmt_usd(usd(rec['unhealthyRaw']))} | {ratio:.4f} | {md_safe(coll)} |"
        )
    lines.append("")

    err_markets = [r for r in market_results if r["errors"] or r["partial"]]
    if err_markets:
        lines.append("## Coverage gaps / errors\n")
        for r in err_markets:
            lines.append(f"- `{r['market']}` ({md_safe(r['name'])}): path={r['path']}, partial={r['partial']}")
            for e in r["errors"]:
                lines.append(f"  - {md_safe(e)}")
        lines.append("")

    lines.append("## Method notes / caveats\n")
    lines.append(
        f"- Full 1300-byte accounts were fetched for every liquidatable/near95 obligation "
        f"({len(out_records):,} records; {counts['validation']['fullAccountsFetched']:,} accounts decoded)."
    )
    lines.append(
        f"- Validation: reserve-membership anomalies={anomalies['reserveMembership']}, "
        f"deposit value mismatches={anomalies['depositValueMismatch']}, "
        f"borrow value mismatches={anomalies['borrowValueMismatch']}, "
        f"malformed={anomalies['malformed']}, vanished accounts={anomalies['vanished']}, "
        f"fetch failures={anomalies['fetchFailed']}."
    )
    lines.append(
        "- Slots differ slightly per market (each market has its own `slotAtScan` in "
        "obligations-counts.json); the scan is a point-in-time sequence, not an atomic snapshot."
    )
    lines.append(
        "- Obligation values are as of each obligation's last update slot; many positions "
        "have not been touched for months/years (see `stale` and `lastUpdateSlot` in the JSON). "
        "Liquidatability under *current* prices may differ from these stored values."
    )
    lines.append(
        "- Only reads: getSlot / getProgramAccounts / getMultipleAccounts against public, "
        "keyless endpoints; no transactions, no signing, no keyed RPC."
    )
    with open(os.path.join(args.outdir, "obligations-summary.md"), "w") as f:
        f.write("\n".join(lines) + "\n")
    log("wrote obligations-summary.md")
    log(
        f"DONE: markets={len(market_results)} obligations={totals['obligations']:,} "
        f"withDebt={totals['withDebt']:,} liquidatable={totals['liquidatableNow']:,} "
        f"near95={totals['near95']:,} records={len(out_records):,} "
        f"calls={rpc.calls} retries={rpc.retries} bytesIn={rpc.bytes_in:,}"
    )


if __name__ == "__main__":
    main()
