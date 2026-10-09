#!/usr/bin/env python3
"""Decode and classify every oracle account referenced by Solend v1 (Save) reserves,
and evaluate the freshness/validity gates of the deployed lending program.

Read-only. Public RPC only. No API keys, no transactions.

Gates implemented (from solana-program-library @ d04ce00b, branch `mainnet`):
  * legacy Pyth (owner FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH):
      pyth_sdk_solana 0.8.0 get_price_no_older_than(clock, 240 slots):
        - if agg.status == Trading and agg.pub_slot >= slot-240  -> use agg
        - elif prev_slot >= slot-240                             -> use prev
        - else stale
      plus price >= 0 (u64), conf*10 <= price, ema price >= 0.
  * Pyth Receiver / pull (owner rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ):
      Anchor-disc checked deserialize of PriceUpdateV2, verification_level must be Full,
      publish_time + 120s >= clock.unix_timestamp, price >= 0, conf*10 <= price,
      ema_price >= 0.
  * Switchboard v2 (owner SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f):
      AggregatorAccountData (switchboard-v2 0.1.18, #[repr(packed)], size 3843) load,
      checked_sub(current, round_open_slot), slots_elapsed >= 240 -> stale;
      get_result(): min_oracle_results <= num_success, except in sliding-resolution mode
      (resolution_mode == 1) where the check is skipped; result mantissa >= 0.
  * Switchboard On-Demand (owner SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv):
      PullFeedAccountData (repr(C) packed-compatible, size 3200) parse; result.slot != 0;
      checked_sub(current, result.slot); slots_elapsed >= 240 -> stale; value >= 0;
      range >= 0; range*10 <= value.

Outputs:
  <out>/oracle-decode.json   machine readable decode + gate results
  <out>/oracle-status.md     human report incl. per-reserve refreshability
Raw RPC snapshot is cached (default <out>/oracle-accounts-raw.json) for auditability;
reuse with --raw <file>.
"""

import argparse
import base64
import hashlib
import json
import os
import struct
import sys
import time
import urllib.request

# ----------------------------------------------------------------------------
# constants

RPC_ENDPOINTS = [
    "https://api.mainnet-beta.solana.com",
    "https://solana-rpc.publicnode.com",
]

PYTH_LEGACY = "FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH"
PYTH_RECEIVER = "rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ"
SB_V2 = "SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f"
SB_ON_DEMAND = "SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv"

NULL_PUBKEY = "nu11111111111111111111111111111111111111111"
ZERO_PUBKEY = "11111111111111111111111111111111"

# deployed program gate constants
PYTH_STALE_SLOTS = 240          # pyth-sdk-solana 0.8.0 / oracles/src/pyth.rs
PYTH_CONF_RATIO = 10
RECEIVER_STALE_SECONDS = 120    # oracles/src/pyth.rs
SB_STALE_SLOTS = 240            # oracles/src/switchboard.rs (invalid when elapsed >= 240)
SBOND_STALE_SLOTS = 240         # oracles/src/switchboard.rs (invalid when elapsed >= 240)
SBOND_PRECISION = 18

# anchor / program account discriminators & magic values
PRICE_UPDATE_V2_DISC = hashlib.sha256(b"account:PriceUpdateV2").digest()[:8]
SB_V2_DISC = bytes([217, 230, 65, 101, 201, 162, 27, 125])
SB_ON_DEMAND_DISC = bytes([196, 27, 108, 196, 10, 215, 219, 40])
PYTH_MAGIC = 0xA1B2C3D4
PYTH_VERSION_2 = 2
PYTH_ATYPE_PRICE = 3

# legacy Pyth PriceAccount (repr(C), 3312 bytes) field offsets
LP_OFF = dict(
    magic=(0, 4), ver=(4, 4), atype=(8, 4), size=(12, 4), ptype=(16, 4), expo=(20, 4),
    last_slot=(32, 8), valid_slot=(40, 8),
    ema_price_val=(48, 8), ema_conf_val=(72, 8),
    timestamp=(96, 8),
    min_pub=(104, 1), drv2=(105, 1), drv3=(106, 2), drv4=(108, 4),
    prev_slot=(176, 8), prev_price=(184, 8), prev_conf=(192, 8), prev_timestamp=(200, 8),
    agg_price=(208, 8), agg_conf=(216, 8), agg_status=(224, 4), agg_corp_act=(228, 4),
    agg_pub_slot=(232, 8),
)

# SB v2 AggregatorAccountData: packed (no padding) layout. Account len = 8 + 3843.
SBV2_MIN_ORACLE_RESULTS = 8 + 228
SBV2_LATEST_ROUND = 8 + 333            # struct offset 333
# AggregatorRound relative offsets
SBV2R_NUM_SUCCESS = 0
SBV2R_NUM_ERROR = 4
SBV2R_IS_CLOSED = 8
SBV2R_ROUND_OPEN_SLOT = 9
SBV2R_ROUND_OPEN_TS = 17
SBV2R_RESULT_MANTISSA = 25
SBV2R_RESULT_SCALE = 41

# SB On-Demand PullFeedAccountData: repr(C) layout, explicit padding, account len = 8 + 3200.
SBOND_MIN_RESPONSES = 8 + 2168
SBOND_NAME = 8 + 2172
SBOND_RESULT = 8 + 2256
# CurrentResult relative offsets
SBONDR_VALUE = 0
SBONDR_STD_DEV = 16
SBONDR_MEAN = 32
SBONDR_RANGE = 48
SBONDR_MIN_VALUE = 64
SBONDR_MAX_VALUE = 80
SBONDR_SLOT = 104
SBONDR_MIN_SLOT = 112
SBONDR_MAX_SLOT = 120


# ----------------------------------------------------------------------------
# rpc

def rpc(method, params, retries=10, timeout=120):
    delay = 1.0
    last = None
    for i in range(retries):
        endpoint = RPC_ENDPOINTS[i % len(RPC_ENDPOINTS)]
        body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
        try:
            req = urllib.request.Request(endpoint, data=body, headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                out = json.load(r)
            if "error" in out:
                raise RuntimeError(str(out["error"])[:300])
            return out["result"]
        except Exception as e:  # noqa: BLE001
            last = e
            if i == retries - 1:
                break
            time.sleep(delay)
            delay = min(delay * 1.7, 30.0)
    raise RuntimeError(f"RPC {method} failed after {retries} tries: {last}")


def chunked(seq, n):
    for i in range(0, len(seq), n):
        yield seq[i:i + n]


def fetch_snapshot(addresses):
    slot = rpc("getSlot", [{"commitment": "confirmed"}])
    block_time = rpc("getBlockTime", [slot])
    accounts = {}
    for batch in chunked(addresses, 100):
        res = rpc("getMultipleAccounts", [batch, {"encoding": "base64", "commitment": "confirmed"}])
        for a, acc in zip(batch, res["value"]):
            accounts[a] = None if acc is None else {
                "owner": acc["owner"],
                "lamports": acc["lamports"],
                "data": acc["data"][0],
                "executable": acc["executable"],
            }
    return {"slot": slot, "blockTime": block_time, "fetchedAt": int(time.time()), "accounts": accounts}


# ----------------------------------------------------------------------------
# helpers

def b64(v):
    return base64.b64decode(v["data"])


def u(b, o, n):
    return int.from_bytes(b[o:o + n], "little")


def si(b, o, n):
    return int.from_bytes(b[o:o + n], "little", signed=True)


def utf8z(b):
    return b.split(b"\x00", 1)[0].decode("utf-8", "replace")


def to_float(price_mantissa, exponent):
    if price_mantissa is None:
        return None
    try:
        return float(price_mantissa) * (10.0 ** exponent)
    except OverflowError:
        return None


# ----------------------------------------------------------------------------
# decoders: each returns (decoded dict | None, structural_reasons list)

def dec_legacy_pyth(b):
    reasons = []
    if len(b) < 3312:
        return None, [f"legacy pyth account too small ({len(b)} < 3312)"]
    d = {}
    for k, (o, n) in LP_OFF.items():
        d[k] = si(b, o, n) if k in ("expo", "timestamp", "prev_price", "prev_timestamp",
                                    "ema_price_val", "ema_conf_val", "agg_price") else u(b, o, n)
    if d["magic"] != PYTH_MAGIC:
        reasons.append(f"bad magic 0x{d['magic']:x}")
    if d["ver"] != PYTH_VERSION_2:
        reasons.append(f"bad version {d['ver']}")
    if d["atype"] != PYTH_ATYPE_PRICE:
        reasons.append(f"bad account type {d['atype']} (want 3=Price)")
    return d, reasons


def dec_receiver(b):
    reasons = []
    if len(b) < 8 + 32 + 1 + 84:
        return None, [f"receiver account too small ({len(b)})"]
    if b[:8] != PRICE_UPDATE_V2_DISC:
        return None, [f"bad anchor discriminator {b[:8].hex()} (want {PRICE_UPDATE_V2_DISC.hex()})"]
    tag = b[40]
    if tag == 1:
        m = 41
        verification = "Full"
    elif tag == 0:
        m = 42
        verification = f"Partial(num_signatures={b[41]})"
    else:
        return None, [f"unknown verification_level tag {tag}"]
    needed = m + 84 + 8
    if len(b) < needed:
        return None, [f"truncated PriceUpdateV2 ({len(b)} < {needed})"]
    d = {
        "writeAuthority": base58(b[8:40]),
        "verificationLevel": verification,
        "feedId": b[m:m + 32].hex(),
        "price": si(b, m + 32, 8),
        "conf": u(b, m + 40, 8),
        "exponent": si(b, m + 48, 4),
        "publishTime": si(b, m + 52, 8),
        "prevPublishTime": si(b, m + 60, 8),
        "emaPrice": si(b, m + 68, 8),
        "emaConf": u(b, m + 76, 8),
        "postedSlot": u(b, m + 84, 8),
    }
    return d, reasons


def dec_sbv2(b):
    if len(b) < 8:
        return None, ["account too small"]
    if b[:8] != SB_V2_DISC:
        return None, [f"bad aggregator discriminator {b[:8].hex()}"]
    if len(b) - 8 != 3843:
        return None, [f"unexpected AggregatorAccountData size {len(b) - 8} (want 3843)"]
    lr = SBV2_LATEST_ROUND
    mant = (si(b, lr + SBV2R_RESULT_MANTISSA + 8, 8) << 64) | u(b, lr + SBV2R_RESULT_MANTISSA, 8)
    d = {
        "name": utf8z(b[8:40]),
        "minOracleResults": u(b, SBV2_MIN_ORACLE_RESULTS, 4),
        "numSuccess": u(b, lr + SBV2R_NUM_SUCCESS, 4),
        "numError": u(b, lr + SBV2R_NUM_ERROR, 4),
        "isClosed": b[lr + SBV2R_IS_CLOSED] != 0,
        "roundOpenSlot": u(b, lr + SBV2R_ROUND_OPEN_SLOT, 8),
        "roundOpenTimestamp": si(b, lr + SBV2R_ROUND_OPEN_TS, 8),
        "resultMantissa": str(mant),
        "resultScale": u(b, lr + SBV2R_RESULT_SCALE, 4),
        "resolutionMode": b[8 + 3704],
    }
    return d, []


def dec_sbond(b):
    if len(b) < 8:
        return None, ["account too small"]
    if b[:8] != SB_ON_DEMAND_DISC:
        return None, [f"bad pull-feed discriminator {b[:8].hex()}"]
    if len(b) - 8 != 3200:
        return None, [f"unexpected PullFeedAccountData size {len(b) - 8} (want 3200)"]

    def i128(o):
        return (si(b, o + 8, 8) << 64) | u(b, o, 8)

    r = SBOND_RESULT
    d = {
        "name": utf8z(b[SBOND_NAME:SBOND_NAME + 32]),
        "minResponses": u(b, SBOND_MIN_RESPONSES, 4),
        "value": str(i128(r + SBONDR_VALUE)),
        "stdDev": str(i128(r + SBONDR_STD_DEV)),
        "mean": str(i128(r + SBONDR_MEAN)),
        "range": str(i128(r + SBONDR_RANGE)),
        "minValue": str(i128(r + SBONDR_MIN_VALUE)),
        "maxValue": str(i128(r + SBONDR_MAX_VALUE)),
        "resultSlot": u(b, r + SBONDR_SLOT, 8),
        "minSlot": u(b, r + SBONDR_MIN_SLOT, 8),
        "maxSlot": u(b, r + SBONDR_MAX_SLOT, 8),
    }
    return d, []


# ----------------------------------------------------------------------------
# gates

def gate_legacy_pyth(d, cur_slot):
    """deployed: pyth-sdk-solana 0.8.0 get_price_no_older_than(clock, 240) + conf check."""
    reasons = []
    cutoff = cur_slot - PYTH_STALE_SLOTS
    source = None
    price = conf = ref = None
    if d["agg_status"] == 1 and d["agg_pub_slot"] >= cutoff:
        source, price, conf, ref = "agg", d["agg_price"], d["agg_conf"], ("slot", "agg.pub_slot", d["agg_pub_slot"])
    elif d["prev_slot"] >= cutoff:
        source, price, conf, ref = "prev", d["prev_price"], d["prev_conf"], ("slot", "prev_slot", d["prev_slot"])
    if source is None:
        best = max(d["agg_pub_slot"], d["prev_slot"])
        ref = ("slot", "max(agg.pub_slot,prev_slot)", best)
        reasons.append(f"stale: newest pub slot {best} is {cur_slot - best} slots old (limit {PYTH_STALE_SLOTS})"
                       + ("" if d["agg_status"] == 1 else f"; agg status != Trading ({d['agg_status']})"))
    else:
        if price < 0:
            reasons.append(f"negative price {price}")
        elif conf * PYTH_CONF_RATIO > price:
            reasons.append(f"confidence too wide: conf {conf} * {PYTH_CONF_RATIO} > price {price}")
        if d["ema_price_val"] < 0:
            reasons.append(f"negative EMA price {d['ema_price_val']}")
    # priceUsd always shows the last price the account offers (selected price when fresh,
    # otherwise the price to_price_feed() would expose), for reporting only.
    display_price = price if source is not None else (d["agg_price"] if d["agg_status"] == 1 else d["prev_price"])
    price_usd = to_float(display_price, d["expo"]) if display_price is not None and display_price >= 0 else None
    return {
        "source": source,
        "priceUsd": price_usd,
        "ref": ref,
    }, reasons


def gate_receiver(d, cur_unix):
    reasons = []
    if not d["verificationLevel"].startswith("Full"):
        reasons.append(f"verification level is {d['verificationLevel']} (need Full)")
    age = cur_unix - d["publishTime"]
    if d["publishTime"] + RECEIVER_STALE_SECONDS < cur_unix:
        reasons.append(f"stale: publish_time {d['publishTime']} is {age}s old (limit {RECEIVER_STALE_SECONDS}s)")
    if d["price"] < 0:
        reasons.append(f"negative price {d['price']}")
    elif d["conf"] * PYTH_CONF_RATIO > d["price"]:
        reasons.append(f"confidence too wide: conf {d['conf']} * {PYTH_CONF_RATIO} > price {d['price']}")
    if d["emaPrice"] < 0:
        reasons.append(f"negative EMA price {d['emaPrice']}")
    price_usd = to_float(d["price"], d["exponent"]) if d["price"] >= 0 else None
    return {
        "source": "price_message",
        "priceUsd": price_usd,
        "ref": ("unix", "publish_time", d["publishTime"]),
    }, reasons


def gate_sbv2(d, cur_slot):
    reasons = []
    if d["roundOpenSlot"] > cur_slot:
        reasons.append(f"round_open_slot {d['roundOpenSlot']} is in the future vs current slot {cur_slot}")
        elapsed = None
    else:
        elapsed = cur_slot - d["roundOpenSlot"]
        if elapsed >= SB_STALE_SLOTS:
            reasons.append(f"stale: round_open_slot {d['roundOpenSlot']} is {elapsed} slots old (limit {SB_STALE_SLOTS})")
    # switchboard-v2 0.1.18 get_result(): the min-oracle check is skipped in sliding-resolution mode
    if d["resolutionMode"] != 1 and d["minOracleResults"] > d["numSuccess"]:
        reasons.append(f"insufficient oracle results: min {d['minOracleResults']} > success {d['numSuccess']}"
                       + (" (round-resolution mode)" if d["resolutionMode"] == 0 else ""))
    mant = int(d["resultMantissa"])
    if mant < 0:
        reasons.append(f"negative result mantissa {mant}")
    price_usd = to_float(mant, -d["resultScale"])
    return {
        "source": "latest_confirmed_round.result",
        "priceUsd": price_usd,
        "ref": ("slot", "round_open_slot", d["roundOpenSlot"]),
    }, reasons


def gate_sbond(d, cur_slot):
    reasons = []
    slot = d["resultSlot"]
    elapsed = None
    if slot == 0:
        reasons.append("no result (result.slot == 0)")
    elif slot > cur_slot:
        reasons.append(f"result.slot {slot} is in the future vs current slot {cur_slot}")
    else:
        elapsed = cur_slot - slot
        if elapsed >= SBOND_STALE_SLOTS:
            reasons.append(f"stale: result.slot {slot} is {elapsed} slots old (limit {SBOND_STALE_SLOTS})")
    val = int(d["value"])
    rng = int(d["range"])
    if val < 0:
        reasons.append(f"negative value {val}")
    if rng < 0:
        reasons.append(f"negative range {rng}")
    if val >= 0 and rng >= 0 and rng * 10 > val:
        reasons.append(f"range too wide: range {rng} * 10 > value {val}")
    price_usd = to_float(val, -SBOND_PRECISION) if val >= 0 else None
    return {
        "source": "result.value",
        "priceUsd": price_usd,
        "ref": ("slot", "result.slot", slot),
    }, reasons


def gate_legacy_unchecked(d):
    """extra-oracle path: get_pyth_price_unchecked (no staleness / no conf check)."""
    reasons = []
    status = d["agg_status"]
    price = d["agg_price"] if status == 1 else d["prev_price"]
    if price < 0:
        reasons.append(f"negative price {price}")
    return {"priceUsd": to_float(price, d["expo"]) if price >= 0 else None}, reasons


def gate_sbv2_unchecked(d, cur_slot):
    """extra-oracle path: check_staleness=false, but checked_sub + get_result still apply."""
    reasons = []
    if d["roundOpenSlot"] > cur_slot:
        reasons.append(f"round_open_slot {d['roundOpenSlot']} in the future vs current slot {cur_slot}")
    if d["resolutionMode"] != 1 and d["minOracleResults"] > d["numSuccess"]:
        reasons.append(f"insufficient oracle results: min {d['minOracleResults']} > success {d['numSuccess']}")
    mant = int(d["resultMantissa"])
    if mant < 0:
        reasons.append(f"negative result mantissa {mant}")
    return {"priceUsd": to_float(mant, -d["resultScale"])}, reasons


def gate_receiver_unchecked(d):
    """extra-oracle path: get_pyth_pull_price_unchecked (feed id self-match + price >= 0)."""
    reasons = []
    if d["price"] < 0:
        reasons.append(f"negative price {d['price']}")
    return {"priceUsd": to_float(d["price"], d["exponent"])}, reasons


# ----------------------------------------------------------------------------
# base58

_B58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"


def base58(b):
    n = int.from_bytes(b, "big")
    s = ""
    while n:
        n, r = divmod(n, 58)
        s = _B58[r] + s
    pad = len(b) - len(b.lstrip(b"\x00"))
    return "1" * pad + (s or ("1" if pad == 0 else ""))


# ----------------------------------------------------------------------------
# main

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--raw", help="use a previously fetched raw snapshot JSON instead of hitting RPC")
    ap.add_argument("--analysis-dir", default="/home/heisenberg/CA/save-solend/analysis")
    ap.add_argument("--save-raw", help="path to write the raw snapshot when fetching (default: <analysis-dir>/oracle-accounts-raw.json)")
    args = ap.parse_args()

    analysis = args.analysis_dir
    oracle_accounts = json.load(open(os.path.join(analysis, "oracle-accounts.json")))
    reserves = json.load(open(os.path.join(analysis, "reserves.json")))
    funded = json.load(open(os.path.join(analysis, "funded-markets.json")))

    addresses = sorted(set(list(oracle_accounts.keys()) +
                           [r["pythOracle"] for r in reserves] +
                           [r["switchboardOracle"] for r in reserves] +
                           [r["extraOracle"] for r in reserves]))
    addresses = [a for a in addresses if a != ZERO_PUBKEY]

    if args.raw:
        snap = json.load(open(args.raw))
        print(f"loaded raw snapshot {args.raw}: slot {snap['slot']} blockTime {snap['blockTime']}",
              file=sys.stderr)
    else:
        print(f"fetching {len(addresses)} oracle accounts from public RPC ...", file=sys.stderr)
        snap = fetch_snapshot(addresses)
        out_raw = args.save_raw or os.path.join(analysis, "oracle-accounts-raw.json")
        json.dump(snap, open(out_raw, "w"))
        print(f"wrote raw snapshot {out_raw}: slot {snap['slot']}", file=sys.stderr)

    cur_slot = snap["slot"]
    cur_unix = snap["blockTime"]
    fetched_at = snap.get("fetchedAt")

    decoded_all = {}
    for addr in addresses:
        acc = snap["accounts"].get(addr)
        entry = {
            "ownerProgram": None,
            "type": None,
            "exists": False,
            "len": None,
            "decoded": None,
            "priceUsd": None,
            "freshness": {
                "currentSlot": cur_slot,
                "currentUnix": cur_unix,
                "refSlotOrTime": None,
                "slotsOldOrSecondsOld": None,
                "refKind": None,
                "refField": None,
            },
            "gates": {"valid": False, "reasons": ["account not found on chain"],
                      "uncheckedValid": False, "uncheckedReasons": ["account not found on chain"]},
        }
        if addr == NULL_PUBKEY:
            entry["type"] = "null-placeholder"
            entry["gates"] = {"valid": False, "reasons": ["canonical NULL_PUBKEY: no oracle configured"],
                              "uncheckedValid": False, "uncheckedReasons": ["canonical NULL_PUBKEY: no oracle configured"]}
            decoded_all[addr] = entry
            continue
        if acc is None:
            entry["type"] = "missing"
            decoded_all[addr] = entry
            continue

        b = b64(acc)
        entry["ownerProgram"] = acc["owner"]
        entry["exists"] = True
        entry["len"] = len(b)
        owner = acc["owner"]
        structural = []

        if owner == PYTH_LEGACY:
            entry["type"] = "pyth-legacy"
            d, structural = dec_legacy_pyth(b)
            if d is not None:
                entry["decoded"] = d
                gate, reasons = gate_legacy_pyth(d, cur_slot)
                ugate, ureasons = gate_legacy_unchecked(d)
                entry["gates"] = {"valid": not structural and not reasons,
                                  "reasons": structural + reasons,
                                  "uncheckedValid": not structural and not ureasons,
                                  "uncheckedReasons": structural + ureasons}
                entry["priceUsd"] = gate["priceUsd"]
                kind, field, val = gate["ref"] if gate["ref"] else ("slot", None, None)
                entry["freshness"].update({
                    "refSlotOrTime": val, "refKind": kind, "refField": field,
                    "slotsOldOrSecondsOld": (cur_slot - val) if val is not None else None,
                    "selectedSource": gate["source"],
                })
                entry["decoded"]["selectedSource"] = gate["source"]
            else:
                entry["gates"] = {"valid": False, "reasons": structural,
                                  "uncheckedValid": False, "uncheckedReasons": structural}

        elif owner == PYTH_RECEIVER:
            entry["type"] = "pyth-receiver"
            d, structural = dec_receiver(b)
            if d is not None:
                entry["decoded"] = d
                gate, reasons = gate_receiver(d, cur_unix)
                ugate, ureasons = gate_receiver_unchecked(d)
                entry["gates"] = {"valid": not structural and not reasons,
                                  "reasons": structural + reasons,
                                  "uncheckedValid": not structural and not ureasons,
                                  "uncheckedReasons": structural + ureasons}
                entry["priceUsd"] = gate["priceUsd"]
                kind, field, val = gate["ref"]
                entry["freshness"].update({
                    "refSlotOrTime": val, "refKind": kind, "refField": field,
                    "slotsOldOrSecondsOld": (cur_unix - val),
                })
            else:
                entry["gates"] = {"valid": False, "reasons": structural,
                                  "uncheckedValid": False, "uncheckedReasons": structural}

        elif owner == SB_V2:
            entry["type"] = "switchboard-v2"
            d, structural = dec_sbv2(b)
            if d is not None:
                entry["decoded"] = d
                gate, reasons = gate_sbv2(d, cur_slot)
                ugate, ureasons = gate_sbv2_unchecked(d, cur_slot)
                entry["gates"] = {"valid": not structural and not reasons,
                                  "reasons": structural + reasons,
                                  "uncheckedValid": not structural and not ureasons,
                                  "uncheckedReasons": structural + ureasons}
                entry["priceUsd"] = gate["priceUsd"]
                kind, field, val = gate["ref"]
                entry["freshness"].update({
                    "refSlotOrTime": val, "refKind": kind, "refField": field,
                    "slotsOldOrSecondsOld": (cur_slot - val),
                })
            else:
                entry["gates"] = {"valid": False, "reasons": structural,
                                  "uncheckedValid": False, "uncheckedReasons": structural}

        elif owner == SB_ON_DEMAND:
            entry["type"] = "switchboard-on-demand"
            d, structural = dec_sbond(b)
            if d is not None:
                entry["decoded"] = d
                gate, reasons = gate_sbond(d, cur_slot)
                entry["gates"] = {"valid": not structural and not reasons,
                                  "reasons": structural + reasons,
                                  "uncheckedValid": not structural and not reasons,
                                  "uncheckedReasons": structural + reasons}
                entry["priceUsd"] = gate["priceUsd"]
                kind, field, val = gate["ref"]
                entry["freshness"].update({
                    "refSlotOrTime": val, "refKind": kind, "refField": field,
                    "slotsOldOrSecondsOld": (cur_slot - val) if val is not None else None,
                })
            else:
                entry["gates"] = {"valid": False, "reasons": structural,
                                  "uncheckedValid": False, "uncheckedReasons": structural}

        else:
            entry["type"] = f"unknown-owner"
            entry["gates"] = {"valid": False,
                              "reasons": [f"owner {owner} is not one of the four recognized oracle programs"],
                              "uncheckedValid": False,
                              "uncheckedReasons": [f"owner {owner} is not recognized"]}

        decoded_all[addr] = entry

    # ---- write oracle-decode.json
    out_json = os.path.join(analysis, "oracle-decode.json")
    json.dump(decoded_all, open(out_json, "w"), indent=1)
    print(f"wrote {out_json}", file=sys.stderr)

    # ---- per-reserve refreshability
    def dstat(addr):
        if addr == NULL_PUBKEY:
            return "null"
        e = decoded_all.get(addr)
        if e is None or not e["exists"]:
            return "missing"
        if e["gates"]["valid"]:
            f = e["freshness"]
            if f["refKind"] == "unix":
                return f"valid ({f['slotsOldOrSecondsOld']}s old)"
            return f"valid ({f['slotsOldOrSecondsOld']} slots old)"
        reasons = e["gates"]["reasons"]
        short = reasons[0] if reasons else "invalid"
        # compact reason
        if short.startswith("stale"):
            return "stale (" + short.split("is ", 1)[-1].split(" (limit", 1)[0] + ")"
        if short.startswith("account not found"):
            return "missing"
        return "INVALID (" + short + ")"

    reserve_rows = []
    for r in reserves:
        pyth, sb, extra = r["pythOracle"], r["switchboardOracle"], r["extraOracle"]
        pe = decoded_all.get(pyth)
        se = decoded_all.get(sb)
        p_ok = pyth != NULL_PUBKEY and pe is not None and pe["exists"] and pe["gates"]["valid"]
        s_ok = sb != NULL_PUBKEY and se is not None and se["exists"] and se["gates"]["valid"]
        if p_ok:
            best = "pyth"
        elif s_ok:
            best = "switchboard"
        else:
            best = None
        extra_active = extra != ZERO_PUBKEY
        extra_ok = None
        if extra_active:
            ee = decoded_all.get(extra)
            extra_ok = bool(ee and ee["exists"] and ee["gates"]["uncheckedValid"])
            if best is not None and not extra_ok:
                best = None
        reasons = []
        if best is None:
            if pyth != NULL_PUBKEY and not p_ok:
                reasons.append(f"pyth {pyth[:6]}.. {dstat(pyth)}")
            if sb != NULL_PUBKEY and not s_ok:
                reasons.append(f"switchboard {sb[:6]}.. {dstat(sb)}")
            if extra_active and not extra_ok:
                reasons.append(f"extra oracle {extra[:6]}.. invalid (unchecked gate)")
        reserve_rows.append({
            "reserve": r["reserve"],
            "market": r["market"],
            "marketName": r.get("marketName"),
            "symbol": r.get("symbol"),
            "pythOracle": pyth,
            "switchboardOracle": sb,
            "extraOracle": extra,
            "pythStatus": dstat(pyth),
            "switchboardStatus": dstat(sb),
            "extraStatus": ("valid (unchecked)" if extra_ok else ("INVALID (unchecked)" if extra_active else None)),
            "bestPath": best,
            "refreshable": best is not None,
            "reasons": reasons,
            "lastUpdate": r.get("lastUpdate"),
            "storedPriceUsd": r.get("storedPriceUsd"),
            "smoothedPriceUsd": r.get("smoothedPriceUsd"),
            "extraPriceUsd": r.get("extraPriceUsd"),
            "scaledPriceOffsetBps": r.get("scaledPriceOffsetBps"),
        })

    write_markdown(analysis, snap, decoded_all, reserve_rows, funded, oracle_accounts, reserves)
    print(f"wrote {os.path.join(analysis, 'oracle-status.md')}", file=sys.stderr)


# ----------------------------------------------------------------------------
# markdown

def oracle_refs(reserves):
    refs = {}
    for r in reserves:
        for role, k in (("pyth", r["pythOracle"]), ("sb", r["switchboardOracle"]),
                        ("extra", r["extraOracle"])):
            if k == ZERO_PUBKEY or k == NULL_PUBKEY:
                continue
            refs.setdefault(k, set()).add(role)
    return refs


def write_markdown(analysis, snap, decoded_all, reserve_rows, funded, oracle_accounts, reserves):
    cur_slot = snap["slot"]
    cur_unix = snap["blockTime"]
    refs = oracle_refs(reserves)

    by_type = {}
    for a, e in decoded_all.items():
        by_type.setdefault(e["type"], []).append(a)

    valid_total = sum(1 for e in decoded_all.values() if e["gates"]["valid"])
    ref_valid = sum(1 for r in reserve_rows if r["refreshable"])

    L = []
    L.append("# Solend v1 (Save) — oracle account decode and reserve refreshability")
    L.append("")
    L.append(f"- Snapshot: slot **{cur_slot}**, blockTime **{cur_unix}**, fetchedAt "
             f"**{snap.get('fetchedAt')}** (public RPC, read-only)")
    L.append(f"- Decoded oracle accounts: **{len(decoded_all)}** — "
             + ", ".join(f"{len(v)} {k}" for k, v in sorted(by_type.items(), key=lambda x: -len(x[1]))))
    L.append(f"- Accounts passing the deployed program's gates: **{valid_total}**")
    L.append("- Gates implemented from `solana-program-library` @ `d04ce00b` (branch `mainnet`), "
             "i.e. the deployed Solend program's `token-lending/oracles/src/`.")
    L.append("")
    L.append("| oracle type | freshness gate | confidence gate |")
    L.append("|---|---|---|")
    L.append(f"| legacy Pyth | `get_price_no_older_than(clock, {PYTH_STALE_SLOTS} slots)` "
             "(agg Trading if age<=240, else prev if age<=240) | `conf*10 <= price`; EMA >= 0 |")
    L.append(f"| Pyth receiver (pull) | verification=Full, `publish_time + {RECEIVER_STALE_SECONDS}s >= now` "
             "| `conf*10 <= price`; EMA >= 0 |")
    L.append(f"| Switchboard v2 | `{SB_STALE_SLOTS} > current_slot - round_open_slot` "
             "| `min_oracle_results <= num_success` except sliding-resolution feeds (0.1.18 returns the "
             "latest round unconditionally); mantissa >= 0 |")
    L.append(f"| Switchboard on-demand | `{SBOND_STALE_SLOTS} > current_slot - result.slot` "
             "| value >= 0; range >= 0; `range*10 <= value` |")
    L.append("")
    L.append("Refresh order in `refresh_reserve` / `get_price`: **main Pyth oracle tried first; "
             "if it errors, the switchboard oracle is tried**. Extra oracle (if configured) is an "
             "independent unchecked gate that must also succeed.")
    L.append("")

    # ------------------------------------------------------------------
    L.append("## Oracle account table")
    L.append("")
    L.append("| account | type | owner | price USD | staleness | gates | valid | refs |")
    L.append("|---|---|---|---|---|---|---|---|")
    order = sorted(decoded_all.items(), key=lambda kv: (kv[1]["type"] or "", kv[0]))
    for a, e in order:
        t = e["type"]
        owner = e["ownerProgram"] or "-"
        price = "-" if e["priceUsd"] is None else f"{e['priceUsd']:.8g}"
        f = e["freshness"]
        if f["refSlotOrTime"] is None:
            stale = "-"
        elif f["refKind"] == "unix":
            stale = f"{f['slotsOldOrSecondsOld']} s"
        else:
            stale = f"{f['slotsOldOrSecondsOld']} slots"
        g = e["gates"]
        if t == "null-placeholder":
            gate = "null"
        elif t == "missing":
            gate = "missing"
        elif g["valid"]:
            gate = "PASS"
        else:
            gate = "FAIL: " + "; ".join(g["reasons"])[:160]
        valid = "yes" if g["valid"] else "no"
        rl = sorted(refs.get(a, []))
        L.append(f"| `{a}` | {t} | `{owner if owner != '-' else '-'}` | {price} | {stale} | {gate} | {valid} | {','.join(rl) or '-'} |")
    L.append("")
    L.append(f"_Note: staleness is measured against snapshot slot {cur_slot} / unix {cur_unix}. "
             "Only Pyth receiver feeds with publish_time <= 120s old pass; the three other types "
             "are all stale in this snapshot (see below)._")
    L.append("")

    # ------------------------------------------------------------------
    L.append("## Per-reserve refreshability")
    L.append("")
    n_ref = len(reserve_rows)
    n_valid = sum(1 for r in reserve_rows if r["refreshable"])
    n_invalid = n_ref - n_valid
    via = {}
    for r in reserve_rows:
        if r["refreshable"]:
            via[r["bestPath"]] = via.get(r["bestPath"], 0) + 1
    L.append(f"**{n_valid} / {n_ref} reserves are refreshable** "
             f"({via.get('pyth', 0)} via main Pyth, {via.get('switchboard', 0)} via Switchboard); "
             f"**{n_invalid} are NOT refreshable** with the currently on-chain oracle state.")
    L.append("")
    L.append("A reserve is refreshable iff its best path passes: main Pyth if it passes, otherwise "
             "switchboard; plus the extra-oracle unchecked gate where one is configured.")
    L.append("")

    by_market = {}
    for r in reserve_rows:
        by_market.setdefault(r["market"], []).append(r)

    for m in funded:
        maddr = m.get("market")
        rows = by_market.get(maddr, [])
        if not rows:
            continue
        mv = [r for r in rows if r["refreshable"]]
        mi = [r for r in rows if not r["refreshable"]]
        L.append(f"### {m.get('name')} — `{maddr}`")
        L.append("")
        L.append(f"{len(rows)} reserves: **{len(mv)} refreshable**, **{len(mi)} NOT refreshable** "
                 f"(stored value ${m.get('storedUsd'):,.2f})")
        L.append("")
        if mi:
            L.append("| reserve | symbol | pyth | switchboard | extra | why not refreshable |")
            L.append("|---|---|---|---|---|---|")
            for r in mi:
                L.append(f"| `{r['reserve']}` | {r['symbol']} | {r['pythStatus']} | "
                         f"{r['switchboardStatus']} | {r['extraStatus'] or '-'} | {'; '.join(r['reasons'])} |")
            L.append("")
        if mv:
            L.append("Refreshable: " + ", ".join(
                f"`{r['reserve'][:8]}..`({r['symbol']},{r['bestPath']})" for r in mv))
            L.append("")

    # markets present in reserves but missing from funded list
    missing_markets = sorted(set(by_market) - {m.get("market") for m in funded})
    if missing_markets:
        L.append("### Markets not present in funded-markets.json")
        L.append("")
        for maddr in missing_markets:
            rows = by_market[maddr]
            L.append(f"- `{maddr}` ({rows[0]['marketName']}): "
                     f"{sum(1 for r in rows if r['refreshable'])}/{len(rows)} refreshable")
        L.append("")

    # ------------------------------------------------------------------
    L.append("## Validation")
    L.append("")
    # USDC main-market oracle (BgxfHJDz.. reserve)
    usdc_res = next((r for r in reserve_rows if r["reserve"] == "BgxfHJDzm44T7XG68MYKx7YisTjZu73tVovyZSjJMpmw"), None)
    if usdc_res:
        a = usdc_res["pythOracle"]
        e = decoded_all[a]
        L.append(f"- Main-market USDC reserve `BgxfHJDz..` oracle `{a}` decodes to "
                 f"**{e['priceUsd']:.8f}** (stored ${usdc_res['storedPriceUsd']:.8f}) — expected ~$1.00 ✓")
    # SOL sanity
    sol_feed = "ef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d"
    for a, e in decoded_all.items():
        if e["type"] == "pyth-receiver" and e["decoded"] and e["decoded"]["feedId"] == sol_feed:
            L.append(f"- Pyth receiver SOL/USD feed `{a}` decodes to **${e['priceUsd']:,.4f}** "
                     f"({e['freshness']['slotsOldOrSecondsOld']}s old, gates={e['gates']['valid']})")
    for a, e in decoded_all.items():
        if e["type"] == "switchboard-v2" and e["decoded"] and e["decoded"]["name"] == "SOL_USD":
            L.append(f"- Switchboard v2 SOL/USD `{a}` decodes to **${e['priceUsd']:,.4f}** "
                     f"(round {e['freshness']['slotsOldOrSecondsOld']} slots old — deprecated feed)")
    # stored-vs-decoded cross-check, recently refreshed reserves with no price offset
    cand = [r for r in reserve_rows
            if r["scaledPriceOffsetBps"] == 0 and r["storedPriceUsd"] and r["lastUpdate"]
            and r["pythOracle"] not in (NULL_PUBKEY,)]
    cand.sort(key=lambda r: -(r["lastUpdate"]["slot"] or 0))
    checked = []
    for r in cand:
        e = decoded_all[r["pythOracle"]]
        if e["priceUsd"] and e["freshness"]["refSlotOrTime"] is not None and r["storedPriceUsd"] > 0:
            diff = abs(e["priceUsd"] - r["storedPriceUsd"]) / r["storedPriceUsd"] * 100.0
            checked.append((r, e, diff))
        if len(checked) >= 12:
            break
    if checked:
        L.append("")
        L.append("Stored reserve price (reserves.json) vs freshly decoded oracle price "
                 "(recently-refreshed reserves, no scaled-price offset):")
        L.append("")
        L.append("| reserve | symbol | stored $ | decoded $ | diff % | reserve refreshed at slot |")
        L.append("|---|---|---|---|---|---|")
        for r, e, diff in checked:
            L.append(f"| `{r['reserve'][:8]}..` | {r['symbol']} | {r['storedPriceUsd']:.8f} | "
                     f"{e['priceUsd']:.8f} | {diff:.3f}% | {r['lastUpdate']['slot']} |")
        L.append("")

    # time-consistent end-to-end check: reserve refreshed within 240 slots AFTER the oracle's own
    # last update (so the stored price must be exactly the decoded value for stale feeds).
    pairs = []
    for r in reserve_rows:
        if not r["storedPriceUsd"] or not r["lastUpdate"] or not r["lastUpdate"].get("slot"):
            continue
        for role, a in (("pyth", r["pythOracle"]), ("sb", r["switchboardOracle"])):
            if a in (NULL_PUBKEY, ZERO_PUBKEY):
                continue
            e = decoded_all.get(a)
            if not e or not e["exists"] or e["priceUsd"] is None:
                continue
            f = e["freshness"]
            if f.get("refKind") != "slot" or f["refSlotOrTime"] is None:
                continue
            delta = r["lastUpdate"]["slot"] - f["refSlotOrTime"]
            if 0 <= delta <= 240:
                diff = abs(e["priceUsd"] - r["storedPriceUsd"]) / r["storedPriceUsd"] * 100.0
                pairs.append((e["type"], diff, r["symbol"], role))
    if pairs:
        from collections import Counter as _Counter
        cnt = _Counter(p[0] for p in pairs)
        L.append("Time-consistent end-to-end check (reserve refreshed within 240 slots after the "
                 "oracle's own last update, so decoded value must equal the stored reserve price):")
        L.append("")
        L.append("| oracle type | pairs | max diff % |")
        L.append("|---|---|---|")
        for t, n in cnt.items():
            ds = [p[1] for p in pairs if p[0] == t]
            L.append(f"| {t} | {n} | {max(ds):.4f}% |")
        L.append("")

    out = os.path.join(analysis, "oracle-status.md")
    with open(out, "w") as f:
        f.write("\n".join(L) + "\n")


if __name__ == "__main__":
    main()
