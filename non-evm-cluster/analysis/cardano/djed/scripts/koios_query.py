#!/usr/bin/env python3
"""Read-only Koios queries for the Djed audit. Keyless endpoint. Saves raw JSON with UTC timestamps.
Usage: python3 koios_query.py <outdir> <endpoint> <json-body-file-or-inline>
Endpoints: tip, address_info, address_assets, account_info, script_info, address_utxos (paginated)
"""
import json, sys, time, urllib.request, urllib.error, datetime

BASE = "https://api.koios.rest/api/v1"

def call(endpoint, body=None, retries=6, timeout=60):
    url = f"{BASE}/{endpoint}"
    data = json.dumps(body).encode() if body is not None else None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, data=data, method="POST" if data else "GET",
                                         headers={"Content-Type": "application/json", "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            wait = 2 * (i + 1)
            print(f"[retry {i+1}/{retries}] {endpoint}: {e} (sleep {wait}s)", file=sys.stderr)
            time.sleep(wait)
    raise SystemExit(f"FAILED after {retries} retries: {endpoint}")

def main():
    outdir = sys.argv[1]
    endpoint = sys.argv[2]
    if len(sys.argv) > 3:
        arg = sys.argv[3]
        body = json.load(open(arg)) if arg.startswith("@") is False and arg.endswith(".json") else json.loads(arg)
    else:
        body = None
    ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    tip = call("tip")
    res = call(endpoint, body)
    out = {"queried_at": ts, "tip": tip, "endpoint": endpoint, "request": body, "response": res}
    fn = f"{outdir}/koios_{endpoint}_{ts}.json".replace("/", "_")
    with open(fn, "w") as f:
        json.dump(out, f, indent=1)
    print(f"wrote {fn} ({len(json.dumps(res))} bytes) tip_slot={tip[0]['abs_slot']} tip_block={tip[0]['block_height']}")
    print(json.dumps(res, indent=1)[:2000])

if __name__ == "__main__":
    main()
