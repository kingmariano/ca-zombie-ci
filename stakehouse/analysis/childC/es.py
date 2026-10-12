#!/usr/bin/env python3
"""Etherscan V2 API helper (read-only). Reads key from /home/heisenberg/CA/.env at runtime.
Never prints or writes the key. Caches raw responses under childC/raw/."""
import json, os, sys, time, urllib.parse, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
os.makedirs(RAW, exist_ok=True)

def _load_key():
    k = os.environ.get("ETHERSCANV2_API_KEY")
    if k:
        return k
    env = "/home/heisenberg/CA/.env"
    with open(env) as f:
        for line in f:
            line = line.strip()
            if line.startswith("ETHERSCANV2_API_KEY="):
                v = line.split("=", 1)[1].strip().strip('"').strip("'")
                if v:
                    return v
    raise RuntimeError("no ETHERSCANV2_API_KEY")

_KEY = _load_key()

def es(**params):
    params.setdefault("chainid", "1")
    params["apikey"] = _KEY
    qs = urllib.parse.urlencode(params)
    url = "https://api.etherscan.io/v2/api?" + qs
    for i in range(5):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "zombie-research/1.0"})
            with urllib.request.urlopen(req, timeout=45) as r:
                out = json.loads(r.read().decode())
            if out.get("status") == "0" and "Max rate limit" in str(out.get("result", "")):
                time.sleep(1.5 * (i + 1)); continue
            return out
        except Exception as e:
            err = str(e)
            time.sleep(1.5 * (i + 1))
    raise RuntimeError(f"etherscan call failed: {err}")

def es_cached(name, **params):
    """Run es() and persist raw response to raw/<name>.json (no key inside)."""
    out = es(**params)
    p = os.path.join(RAW, name + ".json")
    with open(p, "w") as f:
        json.dump(out, f, indent=1)
    return out

def getlogs(address, topic0=None, topic1=None, fromblock=0, toblock="latest", offset=1000, page=1):
    p = {"module": "logs", "action": "getLogs", "address": address,
         "fromBlock": str(fromblock), "toBlock": str(toblock),
         "offset": str(offset), "page": str(page)}
    if topic0: p["topic0"] = topic0
    if topic1: p["topic1"] = topic1
    return es(**p)

def getabi(address):
    return es(module="contract", action="getabi", address=address)

def getsource(address):
    return es(module="contract", action="getsourcecode", address=address)

def txlist(address, startblock=0, endblock=99999999, page=1, offset=10000, sort="asc"):
    return es(module="account", action="txlist", address=address, startblock=startblock,
              endblock=endblock, page=page, offset=offset, sort=sort)

def txlistinternal(address, startblock=0, endblock=99999999, page=1, offset=10000, sort="asc"):
    return es(module="account", action="txlistinternal", address=address, startblock=startblock,
              endblock=endblock, page=page, offset=offset, sort=sort)

def tokentx(address, page=1, offset=10000, sort="asc"):
    return es(module="account", action="tokentx", address=address, page=page, offset=offset, sort=sort)

def tokenbalance(contract, address):
    return es(module="account", action="tokenbalance", contractaddress=contract, address=address)

def tokenholders(contract, page=1, offset=100):
    return es(module="token", action="tokenholderlist", contractaddress=contract, page=page, offset=offset)

if __name__ == "__main__":
    # quick self-test
    print(es(module="stats", action="ethsupply")["status"])
