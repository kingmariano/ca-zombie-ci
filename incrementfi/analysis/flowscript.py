#!/usr/bin/env python3
"""Run a Cadence script (read-only) against Flow mainnet public Access API.
Usage: flowscript.py <script.cdc> [Type=value ...]
Example: flowscript.py s.cdc Address=0xf80cb737bfe7c792
Arguments are JSON-Cadence encoded. No secrets; public endpoint only.
"""
import sys, json, base64, urllib.request, urllib.error

ENDPOINT = "https://rest-mainnet.onflow.org/v1/scripts"

def enc_arg(t, v):
    if t == "Address" and not v.startswith("0x"):
        v = "0x" + v
    return base64.b64encode(json.dumps({"type": t, "value": v}).encode()).decode()

def main():
    script_path = sys.argv[1]
    args = []
    for a in sys.argv[2:]:
        t, v = a.split("=", 1)
        args.append(enc_arg(t, v))
    code = open(script_path).read()
    body = json.dumps({
        "script": base64.b64encode(code.encode()).decode(),
        "arguments": args,
    }).encode()
    req = urllib.request.Request(ENDPOINT, data=body, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            data = json.loads(r.read())
    except urllib.error.HTTPError as e:
        data = json.loads(e.read())
    if isinstance(data, str):
        print(base64.b64decode(data).decode())
    else:
        print(json.dumps(data, indent=1)[:6000])

if __name__ == "__main__":
    main()
