#!/usr/bin/env python3
"""Read-only vm-values/query helper (keyless public API).
Usage:
  python3 vmq.py <scAddress> <funcName> [argHex ...] [--caller <bech32>]
Examples:
  python3 vmq.py erd1... isPaused
  python3 vmq.py erd1... getTotalStakeByType
"""
import json, sys, urllib.request

BASE = "https://api.multiversx.com"

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    caller = None
    if "--caller" in sys.argv:
        i = sys.argv.index("--caller")
        caller = sys.argv[i + 1]
        args = [a for a in args if a != caller]
    sc, func = args[0], args[1]
    fargs = args[2:]
    payload = {"scAddress": sc, "funcName": func, "args": fargs}
    if caller:
        payload["caller"] = caller
    req = urllib.request.Request(
        BASE + "/vm-values/query",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            out = json.loads(r.read().decode())
        d = out.get("data", {})
        rdata = d.get("data", {})
        rets = rdata.get("returnData", [])
        import base64
        dec = []
        for x in rets:
            try:
                raw = base64.b64decode(x).hex()
                num = int.from_bytes(bytes.fromhex(raw), "big") if raw else None
                dec.append({"hex": raw, "int": num})
            except Exception as e:
                dec.append({"raw": x, "err": str(e)})
        print(json.dumps({"sc": sc, "func": func, "returns": dec, "rc": rdata.get("returnCode")}, indent=1))
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:300]
        print(json.dumps({"sc": sc, "func": func, "http_error": e.code, "body": body}, indent=1))

if __name__ == "__main__":
    main()
