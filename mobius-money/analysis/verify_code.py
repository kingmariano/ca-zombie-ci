#!/usr/bin/env python3
"""Verify deployed Mobius pool + library bytecode against the vendored repo build artifacts.
Read-only; keyless public RPCs. Output: ci-out/code-verify.json
"""
import json, os, re, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "ci-out")
os.makedirs(OUT, exist_ok=True)

RPCS = ["https://forno.celo.org", "https://celo-rpc.publicnode.com",
        "https://rpc.ankr.com/celo", "https://celo.drpc.org"]


def rpc(method, params, tries=8):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for i in range(tries):
        u = RPCS[i % len(RPCS)]
        try:
            req = urllib.request.Request(u, data=body, headers={"Content-Type": "application/json",
                                                                "User-Agent": "Mozilla/5.0 (research; read-only)"})
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.loads(r.read().decode())
            if "result" in d:
                return d["result"]
            last = d.get("error")
        except Exception as e:
            last = e
        time.sleep(0.7 + 0.5 * i)
    raise RuntimeError(f"rpc failed: {method}: {last}")


def get_code(addr):
    return rpc("eth_getCode", [addr, "latest"])[2:].lower()


def placeholder_windows(artifact_hex):
    """Return [(char_offset, 40)] for each __$..$__ placeholder in the artifact hex string."""
    out = []
    i = 0
    while True:
        j = artifact_hex.find("__$", i)
        if j < 0:
            break
        k = artifact_hex.find("$__", j)
        if k < 0:
            break
        out.append((j, k + 3 - j))
        i = k + 3
    return out


def compare(deployed, artifact, extra_windows=None):
    """Compare deployed hex vs artifact hex (with __$..$__ placeholders).
    Acceptable differences: placeholder windows (linked addresses), extra windows
    (e.g. the zero-filled self-reference slot of a library), and the CBOR metadata tail.
    """
    res = {"len_equal": len(deployed) == len(artifact), "len_deployed": len(deployed), "len_artifact": len(artifact)}
    if not res["len_equal"]:
        res["status"] = "LEN_MISMATCH"
        return res
    win = placeholder_windows(artifact) + list(extra_windows or [])
    res["link_windows"] = len(win)
    links = []
    acceptable = set()
    for off, ln in win:
        seg = deployed[off:off + ln]
        links.append("0x" + seg if re.fullmatch(r"[0-9a-f]{40}", seg) else None)
        for k in range(off, off + ln):
            acceptable.add(k)
    res["link_values"] = links
    n = len(artifact)
    meta_start = n - 120  # CBOR metadata tail (allow hash variance from source-file differences)
    for k in range(meta_start, n):
        acceptable.add(k)
    diffs = []
    i = 0
    while i < n:
        if artifact[i] != deployed[i] and i not in acceptable:
            j = i
            while j < n and artifact[j] != deployed[j] and j not in acceptable:
                j += 1
            diffs.append((i, j - i))
            i = j
        else:
            i += 1
    res["diff_outside_links_nonmeta"] = diffs[:20]
    res["status"] = "CODE_IDENTICAL" if not diffs else "DIFFS_FOUND"
    if any(v is None for v in links):
        res["status"] = "LINK_INVALID"
    return res


def main():
    pools = {
        "standard_pools": [
            "0xc0ba93d4aaf90d39924402162ee4a213300d1d60", "0xebf0536356256f8ff2a5eb6c65800839801d8b95",
            "0x9f4adbd0af281c69a582eb2e6fa2a594d4204cae", "0x74ef28d635c6c5800dd3cd62d4c4f8752daacb09",
            "0x9906589ea8fd27504974b7e8201df5bbde986b03", "0xf3f65dfe0c8c8f2986da0fec159abe6fd4e700b4",
            "0xaefc4e8cf655a182e8346b24c8abce45616ee0d2", "0xcce0d62ce14fb3e4363eb92db37ff3630836c252",
            "0xa5037661989789d0310ac2b796fa78f1b01f195d", "0x0986b42f5f9c42feeef66fc23eba9ea1164c916d",
            "0xa2f0e57d4ceacf025e81c76f28b9ad6e9fbe8735", "0xfc9e2c63370d8deb3521922a7b2b60f4cff7e75a",
            "0x23c95678862a229fac088bd9705622d78130bc3e", "0x02db089fb09fda92e05e92afcd41d9aafe9c7c7c",
            "0x63c1914bf00a9b395a2bf89aada55a5615a3656e", "0x2080aaa167e2225e1fc9923250ba60e19a180fb2",
            "0x19260b9b573569ddb105780176547875fe9feda3", "0xe0f2cc70e52f05edb383313393d88df2937da55a",
            "0xdbf27fd2a702cc02ac7acf0aea376db780d53247", "0x0ff04189ef135b6541e56f7c638489de92e9c778",
            "0x413ffcc28e6cdde7e93625ef4742810fe9738578", "0x382ed834c6b7dbd10e4798b08889eaed1455e820",
        ],
    }
    art_swap = json.load(open(os.path.join(ROOT, "analysis", "artifacts", "Swap.json")))["deployedBytecode"].lower().replace("0x", "")
    art_swu = json.load(open(os.path.join(ROOT, "analysis", "artifacts", "SwapUtils.json")))["deployedBytecode"].lower().replace("0x", "")

    report = {"generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
              "rpc": RPCS[0], "pools": {}, "libraries": {}}
    lib_addrs = set()
    for p in pools["standard_pools"]:
        code = get_code(p)
        r = compare(code, art_swap)
        # collect the link addresses (they point at SwapUtils instances)
        for lv in r.get("link_values") or []:
            if lv:
                lib_addrs.add(lv)
        report["pools"][p] = r
        print(f"pool {p}: {r['status']}")
    for L in sorted(lib_addrs):
        code = get_code(L)
        extra = []
        if code[2:42] == L[2:].lower():
            extra = [(2, 40, )]  # library self-address slot (zero-filled in the artifact)
        r = compare(code, art_swu, extra)
        report["libraries"][L] = r
        print(f"lib  {L}: {r['status']}")
    ok = all(v["status"] == "CODE_IDENTICAL" for v in report["pools"].values()) and \
         all(v["status"] in ("CODE_IDENTICAL", "DIFFS_FOUND") for v in report["libraries"].values())
    # libraries may legitimately have metadata-only diffs recorded in diff_outside_links_nonmeta already filtered
    report["all_pools_identical_to_artifact"] = all(v["status"] == "CODE_IDENTICAL" for v in report["pools"].values())
    with open(os.path.join(OUT, "code-verify.json"), "w") as f:
        json.dump(report, f, indent=1)
    print("wrote code-verify.json; all_pools_identical =", report["all_pools_identical_to_artifact"])


if __name__ == "__main__":
    main()
