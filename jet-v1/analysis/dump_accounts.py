#!/usr/bin/env python3
"""Dump the on-chain accounts needed for the Jet v1 PoC (read-only, public RPC).

Output: jet-v1/analysis/accounts.json  (pubkey -> {lamports, owner, data_b64, executable})
and jet-v1/analysis/jet_program.so (program binary, copied if present).
"""
import json, base64, os, sys, urllib.request, time

RPC = os.environ.get("SOLANA_RPC_URL", "https://api.mainnet-beta.solana.com")
OUT = os.path.join(os.path.dirname(__file__), "accounts.json")

ACCOUNTS = [
    # program + programdata
    "JPv1rCqrhagNNmJVM5J1he7msQ5ybtvE1nNuHpDHMNU",
    # market
    "9oiXzad28vLhT2TkFoVRRRcwYKrSF7E3XPUJpwcarCAo",
    # reserves
    "3ARjV1TvKbQoHAFyQW5P85F7AX5U58Hm2zwTRHGN4v4A",  # USDC
    "HBD5vNf9a7nnGyfXHEWHZN8Y6bKquB9mSzj6tbcqoXXZ",  # SOL
    "2X39AAQzsY7YFLvoLQ5kSd7cJDLn5EEDkgFrFUfqhG1M",  # solETH
    # vaults
    "63AEVgBicvYeaEwoTr8tkURPnszuB2H1pMBUoNnUPjTN",  # USDC
    "DvM98WWqFFAeCQi1QJbFREkHetRREqiymHBfaPckdHR3",  # SOL
    "FPwT6PEYNJvN2i9Pnz4rD9xS72fgStRdNGXq1kSVGeMH",  # solETH
    # deposit note mints
    "GwbEoYmrmYToCNpEvnhMuVw6hmvRWn6QBFYJCwGfEDAT",  # USDC notes
    "2YuVnXkSmW714ziXkfPfmvAnniBc1tHiAB7gYgRpx43a",  # SOL notes
    "65zGnhqrsqFKABMupVjU9FXVJLFzzH9aXGyVjnAzdB8A",  # solETH notes
    # loan note mints
    "G17Yu6f4emBeRLWS1Y4cNJMTmT5LUGJH95zK6253KoAH",  # USDC loans
    "A9S9XVCuNXHnJGFhxBhsTmJNHa6aPccF5NCAGgE4BxGF",  # SOL loans
    # fee note vaults
    "APU2N1S1qgLpQgpZFTocNuvuL7uNSMVX7X2J1QtAz1sY",  # USDC fee vault
    "ArUf8kRgWnWu7qVCfQUE5SkEz4eMA5MauYEqsSJo2ApL",  # solETH fee vault
    # token mints
    "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",  # USDC
    "So11111111111111111111111111111111111111112",     # wrapped SOL
    "2FPyTwcZLUg1MDrwsyoP4D6s1tM7hAkHYRjkNb5w6Pxk",  # solETH
    # pyth oracles
    "Gnt27xtC473ZT2Mw5u8wZ68Z3gULkSTb5DuxJy7eJotD",  # USDC
    "H6ARHf6YXhGYeQfUzQNGk6rDNnLBQKrenN712K4AQJEG",  # SOL
    "JBu1AL4obBcCMqKBBxhpWCNUt136ijcuMZLFvTP7iWdB",  # solETH
    # programs
    "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
    "SysvarRent111111111111111111111111111111111",
    "SysvarC1ock11111111111111111111111111111111",
]

def rpc(method, params, timeout=60, retries=4):
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                                         headers={"Content-Type":"application/json","User-Agent":"research-readonly/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read())
            if "error" in d:
                last = d["error"]; time.sleep(2*(i+1)); continue
            return d["result"]
        except Exception as e:
            last = e; time.sleep(2*(i+1))
    raise RuntimeError(f"{method}: {last}")

def main():
    out = {}
    slot = None
    for a in ACCOUNTS:
        r = rpc("getAccountInfo", [a, {"encoding":"base64","commitment":"finalized"}])
        slot = r["context"]["slot"]
        v = r["value"]
        if v is None:
            print(f"WARN {a} not found", file=sys.stderr); continue
        out[a] = {"lamports": v["lamports"], "owner": v["owner"], "executable": v["executable"],
                  "space": v["space"], "data_b64": v["data"][0]}
        print(f"ok {a} space={v['space']}", file=sys.stderr)
    with open(OUT, "w") as f:
        json.dump({"slot": slot, "rpc": "public (redacted)", "accounts": out}, f)
    print(f"saved {len(out)} accounts at slot {slot} -> {OUT}", file=sys.stderr)

if __name__ == "__main__":
    main()
