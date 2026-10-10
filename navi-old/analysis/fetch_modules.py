#!/usr/bin/env python3
"""Fetch module disassemblies for NAVI package lineages from the public keyless
Sui mainnet GraphQL endpoint. Saves raw JSON under analysis/raw/modules_all/.
No secrets; small sleep between requests; retries on transient errors."""
import json, os, time, urllib.request, sys

EP = "https://graphql.mainnet.sui.io/graphql"
RAW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "raw")
SLEEP = 0.15

LINEAGES = [
    # name, original package address, subdir under modules_all
    ("main", "0xd899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca", "modules_all"),
    ("oracle", "0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f", "modules_all/oracle"),
    ("lineage_c", "0xacc64a324fc6f68b47fefd484419dedc4d620630665ead67f393c90d11b387b9", "modules_all/lineage_c"),
]

def gql(query, retries=5):
    body = json.dumps({"query": query}).encode()
    last = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(EP, data=body, headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.loads(r.read())
            if "errors" in d:
                raise RuntimeError(json.dumps(d["errors"])[:400])
            return d
        except Exception as e:  # noqa
            last = e
            time.sleep(1.0 * (attempt + 1))
    raise last

def jdump(path, obj):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(obj, f)
    os.replace(tmp, path)

def fetch_lineage(name, root, subdir):
    outdir = os.path.join(RAW, subdir)
    os.makedirs(outdir, exist_ok=True)
    vpath = os.path.join(outdir, "_versions.json")
    if os.path.exists(vpath) and os.path.getsize(vpath) > 50:
        d = json.load(open(vpath))
    else:
        d = gql('{ packageVersions(address: "%s", first: 50) { pageInfo { hasNextPage endCursor } nodes { address version } } }' % root)
        jdump(vpath, d)
        time.sleep(SLEEP)
    nodes = sorted(d["data"]["packageVersions"]["nodes"], key=lambda x: x["version"])
    print(f"[{name}] {len(nodes)} versions", flush=True)
    for node in nodes:
        v = node["version"]
        vdir = os.path.join(outdir, f"v{v}")
        os.makedirs(vdir, exist_ok=True)
        mpath = os.path.join(vdir, "_modules.json")
        # always re-fetch module list WITH explicit pagination (default page size
        # on this endpoint is 20 and silently truncates otherwise)
        q = ('{ package(address: "%s", version: %d) { modules(first: 50) '
             '{ pageInfo { hasNextPage endCursor } nodes { name } } } }' % (root, v))
        d = gql(q)
        mnodes = list(d["data"]["package"]["modules"]["nodes"])
        pi = d["data"]["package"]["modules"]["pageInfo"]
        while pi["hasNextPage"]:
            q2 = ('{ package(address: "%s", version: %d) { modules(first: 50, after: "%s") '
                  '{ pageInfo { hasNextPage endCursor } nodes { name } } } }' % (root, v, pi["endCursor"]))
            d2 = gql(q2)
            mnodes += list(d2["data"]["package"]["modules"]["nodes"])
            pi = d2["data"]["package"]["modules"]["pageInfo"]
            time.sleep(SLEEP)
        d["data"]["package"]["modules"]["nodes"] = mnodes
        jdump(mpath, d)
        time.sleep(SLEEP)
        mods = [m["name"] for m in mnodes]
        for m in mods:
            fpath = os.path.join(vdir, m + ".json")
            if os.path.exists(fpath) and os.path.getsize(fpath) > 100:
                continue
            d2 = gql('{ package(address: "%s", version: %d) { module(name: "%s") { disassembly } } }' % (root, v, m))
            jdump(fpath, d2)
            time.sleep(SLEEP)
        print(f"[{name}] v{v}: {len(mods)} modules done", flush=True)

if __name__ == "__main__":
    only = sys.argv[1] if len(sys.argv) > 1 else None
    for name, root, subdir in LINEAGES:
        if only and name != only:
            continue
        fetch_lineage(name, root, subdir)
    print("ALL DONE", flush=True)
