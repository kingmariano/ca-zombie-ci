#!/usr/bin/env python3
"""Fetch Etherscan V2 contract source/ABI for a list of targets into analysis/src/."""
import json, os, sys, urllib.request, time

KEY = os.environ["ETHERSCANV2_API_KEY"]
OUT = os.path.join(os.path.dirname(__file__), "src")
os.makedirs(OUT, exist_ok=True)

TARGETS = {
    "FoMo3D_Ultra": "0xab83d96de35bad6f234178fbb6507203488e9626",
    "CryptoCats": "0x9508008227b6b3391959334604677d60169ef540",
    "Transit_refund": "0xc213f258f4142f53d086f9edb7a36e67eb347f63",
    "Zethr": "0xd48b633045af65ff636f3c6edd744748351e020d",
    "Zethr_Casino": "0xb9ab8eed48852de901c13543042204c6c569b811",
    "Bingo4Beast_dep2": "0x4fb7d68e0116f35ade131b6535b2db1027bf7650",
    "ReadyPlayerONE": "0x6db943251e4126f913e9733821031791e75df713",
    "DailyDivs": "0xd2bfceeab8ffa24cdf94faa2683df63df4bcbdc8",
    "FEG_WrappedETH": "0xf786c34106762ab4eeb45a51b42a62470e9d5332",
    "Fomo3D_Long": "0xa62142888aba8370742be823c1782d17a0389da1",
    "LastWinner": "0xdd9fd6b6f8f7ea932997992bbe67eabb3e316f3c",
    "PoWH3D": "0xb3775fb83f7d12a36e0475abdd1fca35c091efbe",
    "GandhiJi": "0x167cb3f2446f829eb327344b66e271d1a7efec9a",
    "Fomo3Dshort_v2": "0x0ad3227eb47597b566ec138b3afd78cfea752de5",
    "FoMoJP": "0xcb47c89cb17c10b719fc5ed9665bae157cac2cb1",
    "Bingo4Beast_Long": "0x05aa2fdf9f58b426b49900834cce0565d88e52eb",
    "Liquality_ICO_2018": "0xf8602dfa933a34d513e6e1aab3f3cc6861254d51",
    "Ethfinex_WrapperLockEth": "0xaa7427d8f17d87a28f5e1ba3adbb270badbe1011",
    "Rewards_0x0": "0x02b15c47b4b516a22fd2d8b1fc662afb808a2169",
    "Augur_v1": "0xd5524179cb7ae012f5b642c1d6d700bbaa76b96b",
    "SingularX_Fund": "0x0286f920f893513c7ec9fe35ba0a4760229a243e",
    "MCDEX_ETHPERP": "0x220a9f0dd581cbc58fcfb907de0454cbf3777f76",
    "OpenGSN_RelayHub_v1": "0xd216153c06e857cd7f72665e0af1d7d82172f494",
    "CryptoMinerToken": "0x0a97094c19295e320d5121d72139a150021a2702",
    "AceDapp": "0xe65f525ec48c7e95654b9824ecc358454ea9185e",
    "BlueChip": "0xabefec93451a2cd5d864ff7b0b1604dfc60e9688",
    "EKS": "0xe01e2a3ceafa8233021fc759e5a69863558326b6",
}


def get(url):
    return json.load(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=40))


for name, addr in TARGETS.items():
    f = os.path.join(OUT, name + ".json")
    if os.path.exists(f):
        continue
    try:
        d = get(f"https://api.etherscan.io/v2/api?chainid=1&module=contract&action=getsourcecode&address={addr}&apikey={KEY}")
        r = d["result"][0] if d.get("result") else {}
        json.dump(r, open(f, "w"), indent=1)
        print(f"{name:24s} {r.get('ContractName','?'):28s} verified={bool(r.get('SourceCode'))} compiler={r.get('CompilerVersion','?')} proxy={r.get('Proxy')}")
    except Exception as e:
        print(f"{name:24s} ERROR {e}")
    time.sleep(0.25)
