#!/usr/bin/env python3
"""Find Mode-A borrowers with live debt and check their account liquidity (read-only)."""
import json
import time

import requests
from eth_utils import keccak, to_checksum_address as ck

U = "https://mainnet.mode.network"
COMP = "0xFB3323E24743Caf4ADD0fDCCFB268565c0685556"
MARKETS = [
    "0x71ef7EDa2Be775E5A7aa8afD02C45F059833e9d2",  # ionWETH?
    "0x2BE717340023C9e14C1Bb12cb3ecBcfd3c3fB038",  # ionUSDC?
    "0x94812F2eEa03A49869f95e1b5868C6f3206ee3D3",  # ionUSDT?
    "0xd70254C3baD29504789714A7c69d60Ec1127375C",  # ionWBTC?
    "0x59e710215d45F584f44c0FEe83DA6d43D762D857",  # ionezETH?
    "0x9a9072302B775FfBd3Db79a7766E75Cf82bcaC0A",  # ionweETH?
    "0x959FA710CCBb22c7Ce1e59Da82A247e686629310",  # ionSTONE?
    "0x49950319aBE7CE5c3A6C90698381b45989C99b46",
    "0x19F245782b1258cf3e11Eda25784A378cC18c108",
    "0xA0D844742B4abbbc43d8931a6Edb00C56325aA18",
    "0xBb2B9780BDB4Ccc168947050dFfC3181503c4D18",
    "0x4417A9B33bA8dD6fC9dfd8274B401AFd42299AA3",
    "0x5158ae44C1351682B3DC046541Edf84BF28c8ca4",
    "0x0aCC14dcFf35b731A3f9Bd70DCBa3c97C44EdBA0",
    "0xa48750877a83f7dEC11f722178C317b54a44d142",
    "0x48c234AB217f077dF3C7f541b67D90436cf59b27",
    "0x4EAd9639C8c0b2F0722a2409E6B912D85afa4474",
    "0xADE794534c05F79981337E73dc2A987cdFf1958d",
]


def rpc(method, params, tries=5):
    for _ in range(tries):
        try:
            r = requests.post(U, json={"jsonrpc": "2.0", "id": 1, "method": method, "params": params}, timeout=120).json()
            if "result" in r:
                return r["result"]
            if "rate" in str(r.get("error", "")).lower():
                time.sleep(3)
                continue
            return None
        except Exception:  # noqa: BLE001
            time.sleep(3)
    return None


def call(to, data):
    return rpc("eth_call", [{"to": to, "data": data}, "latest"])


def enc_sig(sig):
    return "0x" + keccak(text=sig)[:4].hex()


def dec_str(hexstr):
    try:
        b = bytes.fromhex(hexstr[2:])
        ln = int.from_bytes(b[32:64], "big")
        return b[64 : 64 + ln].decode()
    except Exception:  # noqa: BLE001
        return "?"


def main():
    T = "0x" + keccak(text="Borrow(address,uint256,uint256,uint256)").hex()
    debt = {}
    symbols = {}
    for m in MARKETS:
        sym = dec_str(call(m, enc_sig("symbol()")))
        symbols[m] = sym
        logs = rpc("eth_getLogs", [{"address": m, "topics": [T], "fromBlock": "0x0", "toBlock": "latest"}]) or []
        if isinstance(logs, dict):
            logs = []
        agg = {}
        for lg in logs:
            # Borrow(address borrower, uint256 amount, uint256 accountBorrows, uint256 totalBorrows)
            # borrower is NOT indexed -> first 32 bytes of data
            d = lg.get("data", "0x")
            if len(d) < 130:
                continue
            who = ck("0x" + d[2:66][-40:])
            amt = int(d[66:130], 16)
            agg[who] = agg.get(who, 0) + amt
        print(f"{sym:<12} events={len(logs):<6} unique={len(agg)}")
        debt[m] = agg
    json.dump({"symbols": symbols, "debt": debt}, open("mode_a_borrow_events.json", "w"), indent=1)

    # current borrow balances for borrowers with any event, only in markets where they borrowed
    live = {}
    for m, agg in debt.items():
        for who in agg:
            bal = call(m, enc_sig("borrowBalanceCurrent(address)") + "000000000000000000000000" + who[2:])
            if bal:
                v = int(bal, 16)
                if v > 0:
                    live.setdefault(who, {})[m] = v
    print("borrowers with live debt:", len(live))
    json.dump({"symbols": symbols, "live": live}, open("mode_a_live_borrowers.json", "w"), indent=1)

    # account liquidity for each live borrower
    liq = {}
    for who, positions in list(live.items()):
        res = call(COMP, enc_sig("getAccountLiquidity(address)") + "000000000000000000000000" + who[2:])
        if res:
            err, liquidity, shortfall = (int(res[i : i + 64], 16) for i in (2, 66, 130))
            liq[who] = {"err": err, "liquidity": liquidity, "shortfall": shortfall}
        else:
            liq[who] = {"err": "revert"}
    json.dump({"symbols": symbols, "live": live, "liquidity": liq}, open("mode_a_liquidity.json", "w"), indent=1)

    # summary
    tot = {}
    for m, agg in debt.items():
        bal = call(m, enc_sig("totalBorrows()"))
        tot[symbols[m]] = int(bal, 16) if bal else None
    print("totalBorrows:", json.dumps(tot))
    short = {w: l for w, l in liq.items() if isinstance(l, dict) and l.get("shortfall", 0) > 0}
    print("borrowers with shortfall:", len(short))
    for w, l in list(short.items())[:20]:
        print(" ", w, l, json.dumps(live[w]))


if __name__ == "__main__":
    main()
