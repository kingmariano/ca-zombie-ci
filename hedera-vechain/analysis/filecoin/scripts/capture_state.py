#!/usr/bin/env python3
"""Canonical state capture for H2-06 Filecoin (HashKing / FILLiquid) sub-scout.

READ-ONLY. Public keyless endpoints only. No secrets.
Reproduces the live-state numbers used in ../DOSSIER.md.

Usage: python3 capture_state.py [--rpc URL] [--out ../evidence/final_state.json]
"""
import argparse
import json
import sys
import time
import urllib.request

DEFAULT_RPC = "https://api.node.glif.io/rpc/v1"
UA = {"Content-Type": "application/json", "User-Agent": "h2-06-filecoin-readonly/1.0"}

# function selectors (keccak, computed with `cast sig`)
SEL = {
    "getStatus()": "0x4e69d560",
    "getTVL()": "0x97b3fcaa",
    "owner()": "0x8da5cb5b",
    "governance()": "0x5aa6e675",
    "hubPool()": "0xe1904402",
    "totalStakingFil()": "0x409b9c96",
    "getFactors()": "0xf8320e21",
    "balanceOf(address)": "0x70a08231",
    "totalSupply()": "0x18160ddd",
    "exchangeRate()": "0x8f7c1f18",
}


def rpc(url, method, params, retries=3):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=30) as r:
                d = json.loads(r.read())
            if "error" in d:
                raise RuntimeError(d["error"])
            return d["result"]
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(1 + i)
    raise RuntimeError(f"{method} failed: {last}")


def call(rpc_url, to, selector, block="latest"):
    return rpc(rpc_url, "eth_call", [{"to": to, "data": selector}, block])


def u(hexstr):
    return int(hexstr, 16)


def word_addr(word):
    return "0x" + word[-40:]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rpc", default=DEFAULT_RPC)
    ap.add_argument("--out", default="../evidence/final_state.json")
    args = ap.parse_args()
    rpc_url = args.rpc

    block = u(rpc(rpc_url, "eth_blockNumber", []))
    bh = hex(block)
    chain_id = u(rpc(rpc_url, "eth_chainId", []))
    state = {"meta": {"chain_id": chain_id, "block": block, "captured_at_unix": int(time.time())}}

    try:
        req = urllib.request.Request("https://coins.llama.fi/prices/current/coingecko:filecoin",
                                     headers={"User-Agent": UA["User-Agent"]})
        with urllib.request.urlopen(req, timeout=20) as r:
            p = json.loads(r.read())["coins"]["coingecko:filecoin"]
        state["meta"]["fil_price_usd"] = p["price"]
        state["meta"]["fil_price_timestamp"] = p["timestamp"]
    except Exception as e:  # noqa: BLE001
        state["meta"]["fil_price_error"] = str(e)

    def bal(a):
        return u(rpc(rpc_url, "eth_getBalance", [a, bh])) / 1e18

    def read_addr(to, sel):
        return word_addr(call(rpc_url, to, SEL[sel]))

    def read_uint(to, sel):
        return u(call(rpc_url, to, SEL[sel])) / 1e18

    # =====================================================================
    # FILLiquid (Filecoin mainnet, chain 314)
    # =====================================================================
    pool = "0xFD669BDDfbb0d085135cBd92521785C39c95bA4b"
    static = "0xA25F892cF2731ba89b88750423Fc618De0959C43"
    fit = "0x87006Fb444878A69D6692Dc944D1dd418f52F053"
    fitstake = "0xB153Cb3efF3e7330DDF4962c22aA8DC63B7fa952"
    fig = "0xc87FAb479B450993E8A7b498C631AdF81f3ca5B4"
    figstake = "0xD44bfE4523f1B2703DDE9C7dBc010Ad39EF668f7"
    feereceiver = "0x7201166FAD30f26f27c36842209b1A35e9f6f0d3"
    governance = "0xfb1473ba128B9c8146C899cf9455c0037631D389"

    st = call(rpc_url, pool, SEL["getStatus()"])
    words = [st[i:i + 64] for i in range(2, 2 + 64 * 23, 64)]
    names = ["totalFIL", "availableFIL", "utilizedLiquidity", "accumulatedDeposit",
             "accumulatedRedeem", "accumulatedBurntFILTrust", "accumulatedMintFILTrust",
             "accumulatedBorrow", "accumulatedPayback", "accumulatedInterest",
             "accumulatedRedeemFee", "accumulatedBorrowFee", "accumulatedBadDebt",
             "accumulatedLiquidateReward", "accumulatedLiquidateFee", "accumulatedDeposits",
             "accumulatedBorrows", "utilizationRate", "exchangeRate", "interestRate",
             "collateralizedMiner", "minerWithBorrows", "rateBase"]
    int_names = {"accumulatedDeposits", "accumulatedBorrows", "utilizationRate",
                 "exchangeRate", "interestRate", "collateralizedMiner",
                 "minerWithBorrows", "rateBase"}
    status = {}
    for n, wd in zip(names, words):
        v = u(wd)
        status[n] = v if n in int_names else v / 1e18

    state["filliquid"] = {
        "pool": pool,
        "pool_native_fil": bal(pool),
        "static_tvl_contract": static,
        "static_getTVL_fil": read_uint(static, "getTVL()"),
        "getStatus": status,
        "owner": read_addr(pool, "owner()"),
        "fit_token": fit,
        "fit_total_supply": read_uint(fit, "totalSupply()"),
        "fitstake_contract": fitstake,
        "fitstake_native_fil": bal(fitstake),
        "fitstake_fit_balance": u(call(rpc_url, fit, SEL["balanceOf(address)"] + "0" * 24 + fitstake[2:])) / 1e18,
        "fig_token": fig,
        "figstake_contract": figstake,
        "figstake_native_fil": bal(figstake),
        "feereceiver": feereceiver,
        "feereceiver_native_fil": bal(feereceiver),
        "feereceiver_owner": read_addr(feereceiver, "getFactors()"),
        "governance_contract": governance,
        "governance_native_fil": bal(governance),
        "sep3_sweep": {
            "note": "static record captured from Blockscout tx/internal-tx/log APIs at block 6337055",
            "tx": "0x0041111742c27b6f1e6706dc8399fff0a68ec1ff387d7631edb7050bcb4fe7be",
            "block": 6337055,
            "timestamp": "2026-09-03T06:47:30Z",
            "pre_balance_fil": 254877.20017925594,
            "post_balance_fil": 0.0,
            "executor_eoa": "0x005C3c4e041Af89E7009F7ddc23D6CA34Cb28672",
            "coordinator_contract": "0x2F57c9e9703f6b04A711206e0CAB4eB42408987c",
            "worker_contract": "0xc18787B51E8f69Aaca908AF9775Ad902051CcCF5",
            "miner_used": "f03825752",
            "borrows_in_tx": 15,
            "borrow_sum_fil": 252328.42817746336,
            "fees_to_foundation_fil": 2548.7719,
            "forwarded_to_executor_fil": 252338.428177,
            "bridged_via_squid_router": "0xce16F69375520ab01377ce7b88f5ba8c48f8d666",
        },
    }

    # =====================================================================
    # HashKing (KingHash vault; nFIL receipt token)
    # =====================================================================
    vault = "0xe012F3957226894B1a2a44b3ef5070417a069dC2"
    vault_impl = "0x73D1Ef868bd977292151B6E309e389D4035ACA9C"
    nfil = "0x84B038DB0fCde4fae528108603c7376695dc217f"
    nfil_impl = "0xb95292314aDf18F2C8c4c9996DF83ed22b28b0f0"
    wfil = "0xD9A724840a46370c01a50C1E511087ab3a07FB53"
    msig = "0x0AaD51Ed6d3b75C7852D5D620402a6D85cd26f6e"
    hubpool = "0xfeB16A48dbBB0E637F68215b19B4DF5b12449676"

    validators = [
        "0x780FB8AD5972DB932bFfcde072941C6188B9c78C",
        "0x08AEea278B603978790Ea45D5875B60ACB149d46",
        "0xECffA69f488C57CEbbb571aa7dA3815dDc9C03AE",
        "0x1615870C387F2000a194aA4D4b28eAe57de9dB31",
        "0xD0B4f6183cd4ab00c92e6B010Eeb76945893Bcb1",
        "0x9b555C2A703aD85D4f4725b61416f16A5C8A1EB5",
        "0xAA30fB03D5ba3d461C835Bb1fD68bEF9b6cA638a",
        "0xf5d8Fd07Bd5b6D24718E9A13081Ebe6527A865fD",
        "0x151Cdb2068Ea090b0d416C8302C1005F46D15990",
        "0x0A0512321A1c0E56729d19eeB42793b6559955d5",
    ]
    vlist = []
    vsum = 0.0
    for v in validators:
        ts = u(call(rpc_url, v, SEL["totalStakingFil()"])) / 1e18
        vsum += ts
        vlist.append({"address": v, "totalStakingFil_fil": ts, "native_fil": bal(v)})

    state["hashking"] = {
        "vault": vault,
        "vault_impl": vault_impl,
        "vault_native_fil": bal(vault),
        "vault_owner_multisig": msig,
        "vault_governance": read_addr(vault, "governance()"),
        "vault_hubpool": read_addr(vault, "hubPool()"),
        "nfil_token": nfil,
        "nfil_impl": nfil_impl,
        "nfil_total_supply": read_uint(nfil, "totalSupply()"),
        "nfil_owner": read_addr(nfil, "owner()"),
        "wfil_token": wfil,
        "wfil_total_supply": read_uint(wfil, "totalSupply()"),
        "wfil_native_fil": bal(wfil),
        "validators": vlist,
        "validators_totalStakingFil_sum": round(vsum, 8),
        "notes": "vault idle since 2026-01-03; validators are beacon-proxies (beacon 0xe48b0d6fcadf5594fd734ae6c8947595653390b5)",
    }
    rec = state["hashking"]["vault_native_fil"] + state["hashking"]["wfil_native_fil"] + vsum
    state["hashking"]["total_tracked_fil"] = round(rec, 8)
    state["hashking"]["total_tracked_usd"] = round(rec * state["meta"].get("fil_price_usd", 0), 2)

    # =====================================================================
    # STFIL legacy token (2024 stfil.io incident token) - screened
    # =====================================================================
    stfil = "0x3C3501E6c353DbaEDDFA90376975Ce7aCe4Ac7a8"
    state["stfil_legacy"] = {
        "token": stfil,
        "total_supply": read_uint(stfil, "totalSupply()"),
        "native_fil": bal(stfil),
        "proxy_impl": word_addr(rpc(rpc_url, "eth_getStorageAt", [stfil, "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc", bh])),
        "proxy_admin": word_addr(rpc(rpc_url, "eth_getStorageAt", [stfil, "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103", bh])),
        "pool": "0xC8E4EF1148D11F8C557f677eE3C73901CD796Bf6",
        "pool_native_fil": bal("0xC8E4EF1148D11F8C557f677eE3C73901CD796Bf6"),
        "treasury_eoa": "0x8ca2fb7E86b440163666DC32186E1Dc0b74a505b",
        "treasury_native_fil": bal("0x8ca2fb7E86b440163666DC32186E1Dc0b74a505b"),
    }

    with open(args.out, "w") as f:
        json.dump(state, f, indent=1)
    print(json.dumps(state, indent=1)[:2600])
    print(f"\nwritten: {args.out}")


if __name__ == "__main__":
    sys.exit(main())
