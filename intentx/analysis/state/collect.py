#!/usr/bin/env python3
"""Read-only log collector for IntentX/SYMMIO live-state reconstruction.

Fetches historical event logs per chain from Blockscout (Base) or Etherscan V2
(Arbitrum/Mantle/Blast), aggregates deposit/withdraw/role/partyB data.

Usage: python3 collect.py <chain> [--max-pages N]
Writes: raw/logs_<chain>_<label>.json and raw/agg_<chain>.json
NEVER sends transactions; HTTP GET only.
"""
import json
import os
import sys
import time
import argparse
import urllib.request
import urllib.parse

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")
os.makedirs(os.path.join(RAW, "logs"), exist_ok=True)

ES_KEY = os.environ.get("ETHERSCANV2_API_KEY", "")

TOPICS = {
    "RegisterPartyB": "0xb1e55b64272332caa21275155200a2bdbfa776c6b6051b41c899dc4d1e34cb42",
    "DeregisterPartyB": "0x72c7cb9f4f33062d91bf746c0d71c23b07089f1fdd54566bfb0b6977483bb56a",
    "RoleGranted": "0x2ae6a113c0ed5b78a53413ffbb7679881f11145ccfba4fb92e863dfcd5a1d2f3",
    "RoleRevoked": "0x155aaafb6329a2098580462df33ec4b7441b19729b9601c5fc17ae1cf99a8a52",
    "SetFeeCollector": "0x9ea5568f737dfb292c6112b470f5deda06c5b264cdc5b29687cbf6f27a73964d",
    "DepositForAccount": "0xb92f7c65176e3a873589352927ba42330e95085f34ab1a9721f2135b94a51883",
    "WithdrawFromAccount": "0x40e4447d271dea2a920b9669d305a3255d8783d59b016237e63b106f1c9dd5fa",
    "AddAccount": "0x1deb86e124d1a5f3b49977292b48e989b984bcd8944cfb14d63c8880482f2cff",
    "DeployContract": "0x6cbd957809e2aaf4d5e36136d06e71215f53a984b218c6d501e22f91d348d9ce",
    "AllocateForAccount": "0x13b84d799b5b8b235eafe52313197bb3dbf3d5c36c2ac0b62e4c45cc4d3a958e",
}

CHAINS = {
    "base": dict(
        id=8453, kind="rpc", url="https://base.blockscout.com/api",
        rpc_logs="https://rpc.ankr.com/base/{key}",
        diamond="0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43",
        mas=["0x8Ab178C07184ffD44F0ADfF4eA2ce6cFc33F3b86"],
        collateral="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", dec=6,
        rpc="https://base-rpc.publicnode.com"),
    "arb": dict(
        id=42161, kind="etherscan", url="https://api.etherscan.io/v2/api",
        diamond="0x8F06459f184553e5d04F07F868720BDaCAB39395",
        mas=["0x141269E29a770644C34e05B127AB621511f20109"],
        collateral="0xaf88d065e77c8cC2239327C5EDb3A432268e5831", dec=6,
        rpc="https://arb1.arbitrum.io/rpc"),
    "mantle": dict(
        id=5000, kind="etherscan", url="https://api.etherscan.io/v2/api",
        diamond="0x2Ecc7da3Cc98d341F987C85c3D9FC198570838B5",
        mas=["0xECbd0788bB5a72f9dFDAc1FFeAAF9B7c2B26E456"],
        collateral="0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34", dec=18,
        rpc="https://rpc.mantle.xyz"),
    "blast": dict(
        id=81457, kind="etherscan", url="https://api.etherscan.io/v2/api",
        diamond="0x3d17f073cCb9c3764F105550B0BCF9550477D266",
        mas=["0x083267D20Dbe6C2b0A83Bd0E601dC2299eD99015",
             "0xd6ee1fd75d11989e57B57AA6Fd75f558fBf02a5e"],
        collateral="0x4300000000000000000000000000000000000003", dec=18,
        rpc="https://blast-rpc.publicnode.com"),
}

RATE_SLEEP = {"etherscan": 0.25, "blockscout": 0.12}
_last_call = [0.0]


def http_get(url, params, tries=6):
    qs = urllib.parse.urlencode(params)
    full = url + "?" + qs
    delay = 1.0
    for attempt in range(tries):
        try:
            req = urllib.request.Request(full, headers={"User-Agent": "intentx-state-research/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                body = r.read().decode("utf-8", "replace")
            data = json.loads(body)
            return data
        except Exception as e:
            if attempt == tries - 1:
                raise
            time.sleep(delay)
            delay *= 1.8
    return None


def fetch_logs_rpc(chain, address, topic0, label, chunk=10_000_000, min_chunk=25_000):
    """Fetch logs via eth_getLogs over chunked block ranges (archive-capable RPC)."""
    import requests
    key = os.environ.get("ANKR_API_KEY", "")
    url = CHAINS[chain]["rpc_logs"].format(key=key)
    blk = requests.post(url, json={"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []},
                        timeout=60).json()
    latest = int(blk["result"], 16)
    out = []
    seen = set()
    ranges = [(0, latest)]
    calls = 0
    while ranges:
        lo, hi = ranges.pop(0)
        params = [{"address": address, "topics": [topic0], "fromBlock": hex(lo), "toBlock": hex(hi)}]
        payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_getLogs", "params": params}
        delay = 1.0
        resp = None
        for attempt in range(8):
            try:
                r = requests.post(url, json=payload, timeout=90)
                if r.status_code == 429:
                    raise RuntimeError("429")
                resp = r.json()
                break
            except Exception as e:
                if attempt == 7:
                    raise
                time.sleep(delay)
                delay = min(delay * 2, 30)
        calls += 1
        if "error" in resp:
            msg = json.dumps(resp["error"])
            if hi - lo > min_chunk and any(k in msg.lower() for k in ["more than", "limit", "too large", "exceed", "10000 results"]):
                mid = (lo + hi) // 2
                ranges.insert(0, (mid + 1, hi))
                ranges.insert(0, (lo, mid))
                continue
            raise RuntimeError(f"{chain}/{label}: rpc error {msg[:200]}")
        for lg in resp["result"]:
            k = (lg.get("transactionHash"), lg.get("logIndex"))
            if k in seen:
                continue
            seen.add(k)
            out.append(lg)
        time.sleep(0.25)
        if calls % 10 == 0:
            print(f"  [{chain}/{label}] rpc calls {calls}: {len(out)} logs", flush=True)
    return out


def fetch_logs(chain, address, topic0, label, max_pages=100000):
    """Incremental fromBlock pagination. Returns deduped list of logs (dicts)."""
    cfg = CHAINS[chain]
    cache = os.path.join(RAW, "logs", f"{chain}_{label}.json")
    if os.path.exists(cache):
        with open(cache) as f:
            return json.load(f)
    if cfg["kind"] == "rpc":
        out = fetch_logs_rpc(chain, address, topic0, label)
        with open(cache, "w") as f:
            json.dump(out, f)
        print(f"  [{chain}/{label}] DONE(rpc): {len(out)} logs saved", flush=True)
        return out
    out = []
    seen = set()
    from_block = 0
    pages = 0
    page = 1
    while True:
        if cfg["kind"] == "etherscan":
            params = {
                "chainid": cfg["id"], "module": "logs", "action": "getLogs",
                "address": address, "topic0": topic0,
                "fromBlock": str(from_block), "toBlock": "latest",
                "offset": 1000, "page": page, "apikey": ES_KEY,
            }
        else:
            params = {
                "module": "logs", "action": "getLogs",
                "address": address, "topic0": topic0,
                "fromBlock": str(from_block), "toBlock": "latest",
                "offset": 1000, "page": page,
            }
        # rate limit
        dt = time.time() - _last_call[0]
        need = RATE_SLEEP[cfg["kind"]] - dt
        if need > 0:
            time.sleep(need)
        _last_call[0] = time.time()

        data = http_get(cfg["url"], params)
        status = data.get("status")
        result = data.get("result")
        if status == "0":
            msg = str(data.get("message", "")) + " " + str(result)
            if "No logs" in msg or "No records" in msg or "No result" in msg:
                break
            if "Max calls" in msg or "rate limit" in msg.lower() or "429" in msg:
                time.sleep(1.5)
                continue
            raise RuntimeError(f"{chain}/{label}: explorer error {msg[:300]}")
        if not isinstance(result, list):
            raise RuntimeError(f"{chain}/{label}: unexpected result {str(result)[:200]}")
        if not result:
            break
        new = 0
        for lg in result:
            key = (lg.get("transactionHash"), lg.get("logIndex"))
            if key in seen:
                continue
            seen.add(key)
            out.append(lg)
            new += 1
        pages += 1
        if pages % 10 == 0:
            print(f"  [{chain}/{label}] page {pages}: {len(out)} logs, at block {int(result[-1]['blockNumber'],16)}", flush=True)
        last_block = int(result[-1]["blockNumber"], 16)
        if len(result) < 1000:
            break
        if new == 0 and page < 10:
            # same page returned; try next page of the same block window
            page += 1
            continue
        if new == 0:
            from_block = last_block + 1
            page = 1
        elif last_block <= from_block:
            from_block = last_block + 1
            page = 1
        else:
            from_block = last_block
            page = 1
        if pages >= max_pages:
            print(f"  [{chain}/{label}] MAX PAGES reached; coverage truncated", flush=True)
            break
    with open(cache, "w") as f:
        json.dump(out, f)
    print(f"  [{chain}/{label}] DONE: {len(out)} logs saved", flush=True)
    return out


def addr_from_word(word):
    if not word:
        return None
    w = word[2:] if word.startswith("0x") else word
    return "0x" + w[-40:]


def strip0x(d):
    return d[2:] if d and d.startswith("0x") else (d or "")


def collect(chain, max_pages):
    cfg = CHAINS[chain]
    diamond = cfg["diamond"]
    agg = {
        "chain": chain, "chain_id": cfg["id"], "diamond": diamond,
        "mas": cfg["mas"], "collateral": cfg["collateral"], "collateral_decimals": cfg["dec"],
        "topics": TOPICS,
    }
    # ---- diamond events ----
    reg = fetch_logs(chain, diamond, TOPICS["RegisterPartyB"], "diamond_RegisterPartyB", max_pages)
    dereg = fetch_logs(chain, diamond, TOPICS["DeregisterPartyB"], "diamond_DeregisterPartyB", max_pages)
    partyb_registered = []
    for lg in reg:
        a = addr_from_word(lg.get("data"))
        if a:
            partyb_registered.append(a)
    partyb_deregistered = []
    for lg in dereg:
        d = strip0x(lg.get("data", ""))
        if len(d) >= 64:
            partyb_deregistered.append(addr_from_word(d[0:64]))
    agg["partyB_registered"] = partyb_registered
    agg["partyB_deregistered"] = partyb_deregistered

    rg = fetch_logs(chain, diamond, TOPICS["RoleGranted"], "diamond_RoleGranted", max_pages)
    rv = fetch_logs(chain, diamond, TOPICS["RoleRevoked"], "diamond_RoleRevoked", max_pages)
    roles = {}
    for kind, logs in (("grant", rg), ("revoke", rv)):
        for lg in logs:
            d = strip0x(lg.get("data", ""))
            if len(d) < 128:
                continue
            role = "0x" + d[0:64]
            user = addr_from_word(d[64:128])
            roles.setdefault(role, {}).setdefault(user, {"grant_block": None, "revoke_block": None})
            roles[role][user][kind + "_block"] = int(lg["blockNumber"], 16)
    agg["roles"] = roles

    fc = fetch_logs(chain, diamond, TOPICS["SetFeeCollector"], "diamond_SetFeeCollector", max_pages)
    fee_events = []
    for lg in fc:
        d = strip0x(lg.get("data", ""))
        if len(d) >= 128:
            oldc = addr_from_word(d[0:64]); newc = addr_from_word(d[64:128])
            fee_events.append({"block": int(lg["blockNumber"], 16), "old": oldc, "new": newc})
    fee_events.sort(key=lambda x: x["block"])
    agg["fee_collector_events"] = fee_events
    agg["fee_collector_latest"] = fee_events[-1]["new"] if fee_events else None

    # ---- MultiAccount events ----
    deposits = {}
    withdrawals = {}
    accounts = {}
    deployed = []
    for ma in cfg["mas"]:
        tag = ma.lower()
        dep = fetch_logs(chain, ma, TOPICS["DepositForAccount"], f"ma_{tag}_DepositForAccount", max_pages)
        for lg in dep:
            d = strip0x(lg.get("data", ""))
            if len(d) < 192:
                continue
            user = addr_from_word(d[0:64])
            account = addr_from_word(d[64:128])
            amount = int(d[128:192], 16)
            rec = deposits.setdefault(account, {"deposit_units": 0, "count": 0, "last_block": 0, "user": user})
            rec["deposit_units"] += amount
            rec["count"] += 1
            rec["last_block"] = max(rec["last_block"], int(lg["blockNumber"], 16))
            if user and rec.get("user") in (None, "0x" + "0" * 40):
                rec["user"] = user
        wd = fetch_logs(chain, ma, TOPICS["WithdrawFromAccount"], f"ma_{tag}_WithdrawFromAccount", max_pages)
        for lg in wd:
            d = strip0x(lg.get("data", ""))
            if len(d) < 192:
                continue
            user = addr_from_word(d[0:64])
            account = addr_from_word(d[64:128])
            amount = int(d[128:192], 16)
            rec = withdrawals.setdefault(account, {"withdraw_units": 0, "count": 0, "last_block": 0, "user": user})
            rec["withdraw_units"] += amount
            rec["count"] += 1
            rec["last_block"] = max(rec["last_block"], int(lg["blockNumber"], 16))
        aa = fetch_logs(chain, ma, TOPICS["AddAccount"], f"ma_{tag}_AddAccount", max_pages)
        for lg in aa:
            d = strip0x(lg.get("data", ""))
            if len(d) < 128:
                continue
            user = addr_from_word(d[0:64])
            account = addr_from_word(d[64:128])
            # name offset pointer at 130, length + data after
            name = None
            try:
                off = int(d[128:192], 16) if len(d) >= 192 else None
                if off is not None and len(d) >= (off + 128):
                    ln = int(d[off:off + 64], 16)
                    raw = d[off + 64: off + 64 + ln * 2]
                    name = bytes.fromhex(raw).decode("utf-8", "replace")
            except Exception:
                pass
            accounts.setdefault(account, {"user": user, "name": name, "ma": ma,
                                          "block": int(lg["blockNumber"], 16)})
            if accounts[account].get("name") is None and name:
                accounts[account]["name"] = name
        dc = fetch_logs(chain, ma, TOPICS["DeployContract"], f"ma_{tag}_DeployContract", max_pages)
        for lg in dc:
            d = strip0x(lg.get("data", ""))
            if len(d) < 128:
                continue
            sender = addr_from_word(d[0:64])
            contract = addr_from_word(d[64:128])
            deployed.append({"sender": sender, "account": contract,
                             "block": int(lg["blockNumber"], 16), "ma": ma})

    agg["deposits"] = deposits
    agg["withdrawals"] = withdrawals
    agg["accounts"] = accounts
    agg["deployed"] = deployed
    agg["counts"] = {
        "partyB_registered": len(partyb_registered),
        "partyB_deregistered": len(partyb_deregistered),
        "deposit_accounts": len(deposits),
        "withdraw_accounts": len(withdrawals),
        "accounts": len(accounts),
        "deployed": len(deployed),
        "role_grant_events": len(rg),
        "role_revoke_events": len(rv),
    }
    with open(os.path.join(RAW, f"agg_{chain}.json"), "w") as f:
        json.dump(agg, f, indent=1)
    print(f"[{chain}] aggregation written: {json.dumps(agg['counts'])}", flush=True)
    # top deposits summary
    top = sorted(deposits.items(), key=lambda kv: -kv[1]["deposit_units"])[:15]
    dec = cfg["dec"]
    for a, r in top:
        print(f"   TOP {a} deposit={r['deposit_units']/10**dec:,.4f} n={r['count']} user={r['user']}", flush=True)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("chain", choices=list(CHAINS))
    ap.add_argument("--max-pages", type=int, default=100000)
    args = ap.parse_args()
    collect(args.chain, args.max_pages)
