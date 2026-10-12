#!/usr/bin/env python3
"""CI heavy scan for swych-perpetual (BSC).

Read-only eth_calls / eth_getLogs over a single RPC (env BSC_RPC_URL).
Outputs JSON into ci-out/. Never prints or stores the RPC URL.
"""
import json
import os
import sys
import time
import urllib.request

RPC = os.environ.get("BSC_RPC_URL") or os.environ.get("FORK_RPC_URL") or "https://bsc-rpc.publicnode.com"
UA = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
    "Content-Type": "application/json",
}
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ci-out")
os.makedirs(OUT, exist_ok=True)

POOL = "0xF86f70fb4959a9FCF1e7dD67A05dC0AC95c3802d"
OM = "0x092D00a4965A6336c9C52BDf522b012C2DD42DCe"
ORACLE = "0xe4460109425EbC1CE34cAd59Ab7ce60535956BF5"
LPTOK = "0x03F9B914f605d732dd7d5B57e6B494be8d44b28A"
FD = "0x7c57c2F579175570E23CCc8C3C26723beD50D6b1"

TOKENS = {
    "BTCB": "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c",
    "WBNB": "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
    "USDT": "0x55d398326f99059fF775485246999027B3197955",
    "WETH": "0x2170Ed0880ac9A755fd29B2688956BD959F933F8",
    "SOL": "0x570A5D26f7765Ecb712C0924E4De545B89fD43dF",
}

SELS = {
    "balanceOf(address)": "0x70a08231",
    "getPrice(address,bool)": "0x76d69760",
    "lastAnswerTimestamp(address)": "0xef2955d4",
    "feeReserves(address)": "0x1ce9cb8f",
    "trancheAssets(address,address)": "0x13a8b3e5",
    "getPoolValue(bool)": "0xbab3e9e6",
    "totalSupply()": "0x18160ddd",
    "nextOrderId()": "0x2a58b330",
    "orders(uint256)": "0xa85c38ef",
    "requests(uint256)": "0x81d12c58",
    "getPositionKey(address,address,address,uint8)": "0x4b968f94",
    "positions(bytes32)": "0x514ea4bf",
    "isLiquidityProvider(address)": "0x99f7854a",
}

TOPICS = {
    "IncreasePosition": "0x8f1a004341b7c2e1e0799b80c6b849e04431c20757ba9b8c9064d5132405465d",
    "DecreasePosition": "0x83712b7229e761b4d6af877c4eeb3e7b709a492cc24f9b6af6df8c8b40ee67e1",
    "ClosePosition": "0x57646b4faf64a91c1ad76512fe716b11edf1056115e03bd65877e0640570ffb5",
    "LiquidatePosition": "0xc845c586a469ab2c089a84e9e19a17dba909df14f7def79de60c4198293924d4",
    "LiquidityAdded": "0xb5bf3f2c68363aa6e695c29010485bcfecb5439239c6b1306fdec5b26cb7c62e",
    "LiquidityRemoved": "0xd0aab0ed3b13a2551c0f217aa790c138f132954984c5d047ae27188f7205de11",
}


def sel(sig: str) -> str:
    return SELS[sig]


def topic(sig: str) -> str:
    short = sig.split("(")[0]
    return TOPICS[short]


def rpc(method, params, retries=5, timeout=60):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for a in range(retries):
        try:
            req = urllib.request.Request(RPC, data=body, headers=UA)
            r = json.load(urllib.request.urlopen(req, timeout=timeout))
            if "error" in r:
                last = r["error"]
                if r["error"].get("code") == -32602 or "range" in str(r["error"]).lower():
                    raise ValueError(str(r["error"]))
                time.sleep(0.4 * (a + 1))
                continue
            return r.get("result")
        except ValueError:
            raise
        except Exception as e:  # noqa: BLE001
            last = str(e)
            time.sleep(0.5 * (a + 1))
    raise RuntimeError(f"rpc {method} failed: {last}")


def batch_calls(calls, retries=5):
    """calls: list of (to, data) -> list of raw results (or None)."""
    out = []
    body = []
    for i, (to, data) in enumerate(calls):
        body.append({"jsonrpc": "2.0", "id": i, "method": "eth_call", "params": [{"to": to, "data": data}, "latest"]})
    payload = json.dumps(body).encode()
    for a in range(retries):
        try:
            req = urllib.request.Request(RPC, data=payload, headers=UA)
            r = json.load(urllib.request.urlopen(req, timeout=120))
            m = {}
            if isinstance(r, list):
                for x in r:
                    m[x.get("id")] = x.get("result")
            else:
                raise RuntimeError(str(r)[:200])
            return [m.get(i) for i in range(len(calls))]
        except Exception:  # noqa: BLE001
            time.sleep(1.0 * (a + 1))
    return [None] * len(calls)


def addr_word(a):
    return a[2:].lower().rjust(64, "0")


def u_word(v):
    return format(v, "064x")


# ---------------------------------------------------------------- snapshot
def snapshot():
    latest = int(rpc("eth_blockNumber", []), 16)
    snap = {"latest_block": latest, "tokens": {}}
    for name, t in TOKENS.items():
        bal = rpc("eth_call", [{"to": t, "data": sel("balanceOf(address)") + addr_word(POOL)}, "latest"])
        snap["tokens"][name] = {"address": t, "pool_balance": int(bal, 16) if bal and bal != "0x" else 0}
    # oracle max/min prices + reporter freshness
    for name, t in TOKENS.items():
        for mx in (True, False):
            res = rpc("eth_call", [{"to": ORACLE, "data": sel("getPrice(address,bool)") + addr_word(t) + u_word(1 if mx else 0)}, "latest"])
            snap["tokens"][name]["price_max" if mx else "price_min"] = int(res, 16) if res and res != "0x" else None
        ts = rpc("eth_call", [{"to": ORACLE, "data": sel("lastAnswerTimestamp(address)") + addr_word(t)}, "latest"])
        snap["tokens"][name]["last_answer_ts"] = int(ts, 16) if ts and ts != "0x" else None
    # pool fee reserves
    snap["fee_reserves"] = {}
    for name, t in TOKENS.items():
        fr = rpc("eth_call", [{"to": POOL, "data": sel("feeReserves(address)") + addr_word(t)}, "latest"])
        snap["fee_reserves"][name] = int(fr, 16) if fr and fr != "0x" else 0
    # tranche assets
    snap["tranche_assets"] = {}
    for name, t in TOKENS.items():
        res = rpc("eth_call", [{"to": POOL, "data": sel("trancheAssets(address,address)") + addr_word(LPTOK) + addr_word(t)}, "latest"])
        if res and res != "0x":
            h = res[2:]
            w = [int(h[i : i + 64], 16) for i in range(0, 256, 64)]
            snap["tranche_assets"][name] = {"poolAmount": w[0], "reservedAmount": w[1], "guaranteedValue": w[2], "totalShortSize": w[3]}
    v_max = rpc("eth_call", [{"to": POOL, "data": sel("getPoolValue(bool)") + u_word(1)}, "latest"])
    v_min = rpc("eth_call", [{"to": POOL, "data": sel("getPoolValue(bool)") + u_word(0)}, "latest"])
    snap["pool_value_max"] = int(v_max, 16) if v_max and v_max != "0x" else None
    snap["pool_value_min"] = int(v_min, 16) if v_min and v_min != "0x" else None
    snap["lp_total_supply"] = int(rpc("eth_call", [{"to": LPTOK, "data": sel("totalSupply()")}, "latest"]), 16)
    return snap


# ---------------------------------------------------------------- orders
def scan_orders():
    n = int(rpc("eth_call", [{"to": OM, "data": sel("nextOrderId()")}, "latest"]), 16)
    print(f"[orders] nextOrderId={n}", flush=True)
    orders_sel = sel("orders(uint256)")
    reqs_sel = sel("requests(uint256)")
    found = []
    CHUNK = 40
    i = 1
    while i < n:
        ids = list(range(i, min(i + CHUNK, n)))
        calls = [(OM, orders_sel + u_word(oid)) for oid in ids]
        results = batch_calls(calls)
        pending = []
        for oid, out in zip(ids, results):
            if not out or out == "0x":
                continue
            h = out[2:]
            w = [h[j : j + 64] for j in range(0, 640, 64)]
            owner = "0x" + w[1][24:]
            if owner == "0x" + "0" * 40:
                continue
            pending.append(
                {
                    "orderId": oid,
                    "pool": "0x" + w[0][24:],
                    "owner": owner,
                    "indexToken": "0x" + w[2][24:],
                    "collateralToken": "0x" + w[3][24:],
                    "payToken": "0x" + w[4][24:],
                    "expiresAt": int(w[5], 16),
                    "submissionBlock": int(w[6], 16),
                    "price": int(w[7], 16),
                    "executionFee": int(w[8], 16),
                    "triggerAboveThreshold": bool(int(w[9], 16)),
                }
            )
        if pending:
            # fetch requests + current position for each
            for p in pending:
                r = rpc("eth_call", [{"to": OM, "data": reqs_sel + u_word(p["orderId"])}, "latest"])
                if r and r != "0x":
                    rh = r[2:]
                    rw = [int(rh[j : j + 64], 16) for j in range(0, 256, 64)]
                    p["request"] = {"side": rw[0], "sizeChange": rw[1], "collateral": rw[2], "updateType": rw[3]}
                key = rpc(
                    "eth_call",
                    [{"to": POOL, "data": sel("getPositionKey(address,address,address,uint8)") + addr_word(p["owner"]) + addr_word(p["indexToken"]) + addr_word(p["collateralToken"]) + u_word(p["request"]["side"])}, "latest"],
                )
                p["positionKey"] = key
                pos = rpc("eth_call", [{"to": POOL, "data": sel("positions(bytes32)") + key[2:]}, "latest"])
                if pos and pos != "0x":
                    ph = pos[2:]
                    pw = [int(ph[j : j + 64], 16) for j in range(0, 384, 64)]
                    p["position"] = {"size": pw[0], "collateralValue": pw[1], "reserveAmount": pw[2], "entryPrice": pw[3], "borrowIndex": pw[4], "lastIncreasedTime": pw[5]}
            found.extend(pending)
            print(f"[orders] chunk {i}: +{len(pending)} pending", flush=True)
        i += CHUNK
        time.sleep(0.05)
    return {"nextOrderId": n, "pending": found}


# ---------------------------------------------------------------- logs
def scan_logs():
    topics = [
        topic("IncreasePosition(bytes32,address,address,address,uint256,uint256,uint8,uint256,uint256)"),
        topic("DecreasePosition(bytes32,address,address,address,uint256,uint256,uint8,uint256,tuple,uint256)"),
        topic("ClosePosition(bytes32,uint256,uint256,uint256,uint256,uint256)"),
        topic("LiquidatePosition(bytes32,address,address,address,uint8,uint256,uint256,uint256,uint256,tuple,uint256)"),
        topic("LiquidityAdded(address,address,address,uint256,uint256)"),
        topic("LiquidityRemoved(address,address,address,uint256,uint256)"),
    ]
    start, end = 33_000_000, 67_000_000
    names = {
        topics[0]: "IncreasePosition",
        topics[1]: "DecreasePosition",
        topics[2]: "ClosePosition",
        topics[3]: "LiquidatePosition",
        topics[4]: "LiquidityAdded",
        topics[5]: "LiquidityRemoved",
    }
    events = []
    chunk = 250_000
    cur = start
    budget = 700
    used = 0
    failures = 0
    while cur <= end and used < budget:
        hi = min(cur + chunk - 1, end)
        try:
            logs = rpc("eth_getLogs", [{"address": POOL, "fromBlock": hex(cur), "toBlock": hex(hi), "topics": [topics]}], retries=2, timeout=90)
        except Exception as e:  # noqa: BLE001
            if "range" in str(e).lower() or "query returned more" in str(e).lower() or "limit" in str(e).lower():
                chunk = max(chunk // 2, 5_000)
                failures += 1
                if failures > 40:
                    break
                continue
            failures += 1
            if failures > 6:
                break
            time.sleep(1.0)
            continue
        used += 1
        for lg in logs or []:
            t0 = lg["topics"][0]
            d = lg["data"][2:]
            w = [d[j : j + 64] for j in range(0, len(d) - len(d) % 64, 64)]
            ev = {
                "name": names.get(t0, t0),
                "block": int(lg["blockNumber"], 16),
                "tx": lg["transactionHash"],
                "key": lg["topics"][1] if len(lg["topics"]) > 1 else None,
            }
            if ev["name"] in ("IncreasePosition", "DecreasePosition", "LiquidatePosition"):
                ev["account"] = "0x" + w[0][24:]
                ev["collateralToken"] = "0x" + w[1][24:]
                ev["indexToken"] = "0x" + w[2][24:]
            if ev["name"] == "IncreasePosition":
                ev["collateralValue"] = int(w[3], 16)
                ev["sizeChanged"] = int(w[4], 16)
                ev["side"] = int(w[5], 16)
                ev["indexPrice"] = int(w[6], 16)
            elif ev["name"] == "DecreasePosition":
                ev["collateralChanged"] = int(w[3], 16)
                ev["sizeChanged"] = int(w[4], 16)
                ev["side"] = int(w[5], 16)
            elif ev["name"] == "LiquidatePosition":
                ev["side"] = int(w[3], 16)
                ev["size"] = int(w[4], 16)
            elif ev["name"] in ("LiquidityAdded", "LiquidityRemoved"):
                ev["sender"] = "0x" + lg["topics"][2][24:]
                ev["token"] = "0x" + w[0][24:]
                ev["amounts"] = [int(w[1], 16), int(w[2], 16)]
            events.append(ev)
        cur = hi + 1
        if used % 20 == 0:
            print(f"[logs] scanned to {cur} chunk={chunk} events={len(events)} reqs={used}", flush=True)
    return {"range": [start, end], "chunk_final": chunk, "requests_used": used, "events": events}


# ---------------------------------------------------------------- positions now
def open_positions(events):
    keys = {}
    for e in events:
        if e["name"] == "IncreasePosition":
            keys[e["key"]] = e
        elif e["name"] in ("ClosePosition", "DecreasePosition", "LiquidatePosition"):
            # do not delete on Decrease (partial); Close removes
            if e["name"] == "ClosePosition":
                keys.pop(e["key"], None)
    out = []
    for k, e in keys.items():
        res = rpc("eth_call", [{"to": POOL, "data": sel("positions(bytes32)") + k[2:]}, "latest"])
        if res and res != "0x":
            h = res[2:]
            w = [int(h[j : j + 64], 16) for j in range(0, 384, 64)]
            if w[0] != 0:
                out.append({"key": k, "lastIncreaseEvent": e, "size": w[0], "collateralValue": w[1], "reserveAmount": w[2], "entryPrice": w[3], "lastIncreasedTime": w[5]})
    return out


def main():
    snap = snapshot()
    print("[snapshot] latest block", snap["latest_block"], flush=True)
    orders = scan_orders()
    logs = scan_logs()
    opens = open_positions(logs["events"])
    json.dump(snap, open(os.path.join(OUT, "state_snapshot.json"), "w"), indent=1)
    json.dump(orders, open(os.path.join(OUT, "pending_orders.json"), "w"), indent=1)
    json.dump(logs, open(os.path.join(OUT, "position_events.json"), "w"), indent=1)
    json.dump(opens, open(os.path.join(OUT, "open_positions.json"), "w"), indent=1)
    print(f"[done] pending_orders={len(orders['pending'])} events={len(logs['events'])} open_positions={len(opens)}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # noqa: BLE001
        print("SCAN ERROR:", type(e).__name__, str(e)[:300], file=sys.stderr)
        sys.exit(1)
