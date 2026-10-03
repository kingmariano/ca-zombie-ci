#!/usr/bin/env python3
"""Dump Tectonic (Cronos) full market state via batched eth_call. Read-only.
Tectonic fork notes: comptroller() -> tectonicCore(); isCToken() -> isTToken().
"""
import json
import time
import urllib.request

RPCS = [
    "https://cronos-evm-rpc.publicnode.com",
    "https://evm.cronos.org",
]
UNITROLLER = "0xb3831584acb95ED9cCb0C11f677B5AD01DeaeEc0"
ORACLE = "0xD360D8cABc1b2e56eCf348BFF00D2Bd9F658754A"
TEST = "0x00000000000000000000000000000000DeaDBeef"


def rpc(method, params):
    payload = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
    last = None
    for url in RPCS:
        for _ in range(3):
            try:
                req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=30) as r:
                    out = json.loads(r.read())
                if "result" in out:
                    return out["result"]
                last = out.get("error")
            except Exception as e:
                last = str(e)
            time.sleep(0.5)
    return {"__error__": last}


def batch_calls(calls, block="latest"):
    """calls: list of (to, data) or (to, data, from). Returns results aligned."""
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i + 10]
        payload = []
        for j, c in enumerate(chunk):
            obj = {"to": c[0], "data": c[1]}
            if len(c) > 2 and c[2]:
                obj["from"] = c[2]
            payload.append({"jsonrpc": "2.0", "method": "eth_call", "params": [obj, block], "id": j})
        body = json.dumps(payload).encode()
        got = None
        for attempt in range(3):
            for url in RPCS:
                try:
                    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
                    with urllib.request.urlopen(req, timeout=60) as r:
                        got = json.loads(r.read())
                    break
                except Exception as e:
                    got = [{"error": str(e)}]
            if isinstance(got, list) and any("result" in x for x in got):
                break
            time.sleep(1.0)
        by_id = {}
        if isinstance(got, list):
            for item in got:
                by_id[item.get("id")] = item
        for j in range(len(chunk)):
            item = by_id.get(j, {})
            if "result" in item:
                out.append(item["result"])
            else:
                out.append({"__error__": item.get("error")})
        time.sleep(0.15)
    return out


def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def enc_uint(n):
    return hex(n)[2:].rjust(64, "0")


def dec_uint(h):
    if isinstance(h, dict):
        return h
    if not h or h == "0x":
        return None
    return int(h, 16)


def dec_str(h):
    if isinstance(h, dict):
        return h
    try:
        b = bytes.fromhex(h[2:])
        if len(b) < 64:
            return None
        ln = int.from_bytes(b[32:64], "big")
        return b[64:64 + ln].decode("utf-8", "replace")
    except Exception:
        return None


def dec_addr(h):
    if isinstance(h, dict):
        return h
    if not h or len(h) < 42:
        return None
    return "0x" + h[-40:]


SEL = {
    "symbol": "0x95d89b41",
    "underlying": "0x6f307dc3",
    "tectonicCore": "0xc16a61ec",
    "totalSupply": "0x18160ddd",
    "totalBorrows": "0x47bd3718",
    "totalReserves": "0x8f840ddd",
    "getCash": "0x3b1d21a2",
    "exchangeRateStored": "0x182df0f5",
    "accrualBlockNumber": "0x6c540baf",
    "reserveFactorMantissa": "0x173b9904",
    "interestRateModel": "0xf3fdb15a",
    "decimals": "0x313ce567",
    "admin": "0xf851a440",
    "markets": "0x8e8f294b",
    "mintGuardianPaused": "0x731f0c2b",
    "borrowGuardianPaused": "0x6d154ea5",
    "borrowCaps": "0x4a584432",
    "supplyCaps": "0x02c3bcbb",
    "getUnderlyingPrice": "0xfc57d4df",
    "closeFactor": "0xe8755446",
    "liqIncentive": "0x4ada90af",
    "oracle": "0x7dc0d1d0",
    "pauseGuardian": "0x24a3d622",
    "getAllMarkets": "0xb0772d0b",
    "transferGuardianPaused": "0x87f76303",
    "seizeGuardianPaused": "0xac0b0bb7",
    "protocolSeizeShare": "0x6752e702",
    "borrowIndex": "0xaa5af0fd",
    "mintAllowed": "0x4ef4c3e1",
    "borrowAllowed": "0xda3d454c",
    "redeemAllowed": "0xeabe7d91",
    "repayBorrowAllowed": "0x24008a62",
    "liquidateBorrowAllowed": "0x5fc7e71e",
    "seizeAllowed": "0xd02f7351",
    "transferAllowed": "0xbdcdc258",
    "balanceOf": "0x70a08231",
    "getAccountSnapshot": "0xc37f68e2",
}

if __name__ == "__main__":
    latest = rpc("eth_blockNumber", [])
    blk = int(latest, 16)
    print(f"latest block: {blk}")
    block = "latest"

    basics = batch_calls([
        (UNITROLLER, SEL["getAllMarkets"]),
        (UNITROLLER, SEL["oracle"]),
        (UNITROLLER, SEL["closeFactor"]),
        (UNITROLLER, SEL["liqIncentive"]),
        (UNITROLLER, SEL["pauseGuardian"]),
        (UNITROLLER, SEL["admin"]),
        (UNITROLLER, SEL["transferGuardianPaused"]),
        (UNITROLLER, SEL["seizeGuardianPaused"]),
    ], block=block)
    markets_raw = basics[0]
    markets = []
    if isinstance(markets_raw, str) and markets_raw != "0x":
        b = bytes.fromhex(markets_raw[2:])
        off = int.from_bytes(b[0:32], "big")
        ln = int.from_bytes(b[off:off + 32], "big")
        for i in range(ln):
            a = b[off + 32 + i * 32:off + 64 + i * 32]
            markets.append("0x" + a[12:].hex())
    print(f"markets: {len(markets)}")
    state = {
        "block": blk, "query_block": block, "unitroller": UNITROLLER,
        "oracle": dec_addr(basics[1]), "closeFactorMantissa": dec_uint(basics[2]),
        "liquidationIncentiveMantissa": dec_uint(basics[3]), "pauseGuardian": dec_addr(basics[4]),
        "admin": dec_addr(basics[5]), "transferGuardianPaused": dec_uint(basics[6]),
        "seizeGuardianPaused": dec_uint(basics[7]), "markets": {},
    }
    print(f"oracle={state['oracle']} closeFactor={state['closeFactorMantissa']} liqInc={state['liquidationIncentiveMantissa']}")
    print(f"pauseGuardian={state['pauseGuardian']} admin={state['admin']} transferPaused={state['transferGuardianPaused']} seizePaused={state['seizeGuardianPaused']}")

    for m in markets:
        calls = [
            (m, SEL["symbol"]),
            (m, SEL["underlying"]),
            (m, SEL["tectonicCore"]),
            (m, SEL["totalSupply"]),
            (m, SEL["totalBorrows"]),
            (m, SEL["totalReserves"]),
            (m, SEL["getCash"]),
            (m, SEL["exchangeRateStored"]),
            (m, SEL["accrualBlockNumber"]),
            (m, SEL["reserveFactorMantissa"]),
            (m, SEL["interestRateModel"]),
            (m, SEL["decimals"]),
            (m, SEL["admin"]),
            (m, SEL["protocolSeizeShare"]),
            (UNITROLLER, SEL["markets"] + enc_addr(m)),
            (UNITROLLER, SEL["mintGuardianPaused"] + enc_addr(m)),
            (UNITROLLER, SEL["borrowGuardianPaused"] + enc_addr(m)),
            (UNITROLLER, SEL["borrowCaps"] + enc_addr(m)),
            (UNITROLLER, SEL["supplyCaps"] + enc_addr(m)),
            (ORACLE, SEL["getUnderlyingPrice"] + enc_addr(m)),
        ]
        res = batch_calls(calls, block=block)
        d = {
            "symbol": dec_str(res[0]),
            "underlying": dec_addr(res[1]),
            "tectonicCore": dec_addr(res[2]),
            "totalSupply": dec_uint(res[3]),
            "totalBorrows": dec_uint(res[4]),
            "totalReserves": dec_uint(res[5]),
            "getCash": dec_uint(res[6]),
            "exchangeRateStored": dec_uint(res[7]),
            "accrualBlockNumber": dec_uint(res[8]),
            "reserveFactorMantissa": dec_uint(res[9]),
            "interestRateModel": dec_addr(res[10]),
            "decimals": dec_uint(res[11]),
            "admin": dec_addr(res[12]),
            "protocolSeizeShareMantissa": dec_uint(res[13]),
            "mintGuardianPaused": dec_uint(res[15]),
            "borrowGuardianPaused": dec_uint(res[16]),
            "borrowCaps": dec_uint(res[17]),
            "supplyCaps": dec_uint(res[18]),
        }
        mr = res[14]
        if isinstance(mr, str) and len(mr) >= 130:
            bb = bytes.fromhex(mr[2:])
            d["isListed"] = bool(int.from_bytes(bb[0:32], "big"))
            d["collateralFactorMantissa"] = int.from_bytes(bb[32:64], "big")
            if len(bb) > 64:
                d["markets_extra_words"] = len(bb) // 32
        else:
            d["markets_raw"] = mr
        pr = res[19]
        if isinstance(pr, str) and pr.startswith("0x") and len(pr) > 2:
            d["oracle_price"] = int(pr, 16)
        else:
            d["oracle_price"] = pr

        # gate checks: emulate msg.sender == cToken
        g = batch_calls([
            (UNITROLLER, SEL["mintAllowed"] + enc_addr(m) + enc_addr(TEST) + enc_uint(1), m),
            (UNITROLLER, SEL["borrowAllowed"] + enc_addr(m) + enc_addr(TEST) + enc_uint(1), m),
            (UNITROLLER, SEL["redeemAllowed"] + enc_addr(m) + enc_addr(TEST) + enc_uint(1), m),
            (UNITROLLER, SEL["repayBorrowAllowed"] + enc_addr(m) + enc_addr(TEST) + enc_addr(TEST) + enc_uint(1), m),
            (UNITROLLER, SEL["liquidateBorrowAllowed"] + enc_addr(m) + enc_addr(m) + enc_addr(TEST) + enc_addr(TEST) + enc_uint(1), m),
            (UNITROLLER, SEL["seizeAllowed"] + enc_addr(m) + enc_addr(m) + enc_addr(TEST) + enc_addr(TEST) + enc_uint(1), m),
            (UNITROLLER, SEL["transferAllowed"] + enc_addr(m) + enc_addr(TEST) + enc_addr(TEST) + enc_uint(1), m),
        ], block=block)
        d["gate_mintAllowed"] = dec_uint(g[0])
        d["gate_borrowAllowed"] = dec_uint(g[1])
        d["gate_redeemAllowed"] = dec_uint(g[2])
        d["gate_repayBorrowAllowed"] = dec_uint(g[3])
        d["gate_liquidateBorrowAllowed"] = dec_uint(g[4])
        d["gate_seizeAllowed"] = dec_uint(g[5])
        d["gate_transferAllowed"] = dec_uint(g[6])

        state["markets"][m] = d
        print(f"\n{m} {d['symbol']} dec={d['decimals']} listed={d.get('isListed')} CF={d.get('collateralFactorMantissa')}")
        print(f"   cash={d['getCash']} borrows={d['totalBorrows']} reserves={d['totalReserves']} supply={d['totalSupply']}")
        print(f"   exRate={d['exchangeRateStored']} accrualBlk={d['accrualBlockNumber']} rf={d['reserveFactorMantissa']} seizeShare={d['protocolSeizeShareMantissa']}")
        print(f"   borrowCap={d['borrowCaps']} supplyCap={d['supplyCaps']} oraclePrice={d['oracle_price']}")
        print(f"   paused: mint={d['mintGuardianPaused']} borrow={d['borrowGuardianPaused']}")
        print(f"   gates: mint={d['gate_mintAllowed']} borrow={d['gate_borrowAllowed']} redeem={d['gate_redeemAllowed']} repay={d['gate_repayBorrowAllowed']} liq={d['gate_liquidateBorrowAllowed']} seize={d['gate_seizeAllowed']} transfer={d['gate_transferAllowed']}")

    with open(f"state-{blk}.json", "w") as f:
        json.dump(state, f, indent=1)
    print(f"\nsaved state-{blk}.json")
