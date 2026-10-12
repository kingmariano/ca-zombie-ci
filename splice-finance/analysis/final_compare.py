#!/usr/bin/env python3
"""Definitive bytecode comparison: deployed (on-chain) vs local solc 0.8.22 build.
Handles: metadata strip, immutable masking, library linkReference masking."""
import json, hashlib, sys

VERIFY = "/tmp/opencode/splice-verify"
SPLICE = "/tmp/opencode/splice-contracts"

def hexnorm(c):
    return c[2:] if c.startswith("0x") else c

def strip_meta(c):
    c = hexnorm(c)
    n = int(c[-4:], 16)
    stripped = c[:-(n * 2 + 4)]
    return stripped, n

def mask_ranges(c, ranges):
    l = list(c)
    for (start, length) in ranges:
        for i in range(start * 2, (start + length) * 2):
            l[i] = '0'
    return ''.join(l)

def ref_ranges(obj_references):
    """Handle both immutableReferences {id: [refs]} and linkReferences {path: {lib: [refs]}}."""
    rr = []
    for key, val in obj_references.items():
        if isinstance(val, list):
            for r in val:
                rr.append((r['start'], r['length']))
        elif isinstance(val, dict):
            for libname, refs in val.items():
                for r in refs:
                    rr.append((r['start'], r['length']))
    return rr

def diff_clusters(a, b):
    diffs = [i for i in range(len(a)) if a[i] != b[i]]
    if not diffs:
        return []
    clusters = []
    cur = [diffs[0]]
    for x in diffs[1:]:
        if x - cur[-1] <= 8:
            cur.append(x)
        else:
            clusters.append((cur[0] // 2, cur[-1] // 2))
            cur = [x]
    clusters.append((cur[0] // 2, cur[-1] // 2))
    return clusters

def compare(name, ocfile, artifact, extra_oc_mask=None, extra_local_mask=None, quiet=False):
    oc = json.load(open(f"{VERIFY}/{ocfile}"))
    oc = oc["result"] if isinstance(oc, dict) and "result" in oc else oc
    d = json.load(open(f"{SPLICE}/{artifact}"))
    ocs, ocmeta = strip_meta(oc)
    lcs, lcmeta = strip_meta(d["deployedBytecode"]["object"])
    imm = ref_ranges(d["deployedBytecode"].get("immutableReferences", {}))
    links = ref_ranges(d["deployedBytecode"].get("linkReferences", {}))
    ocm = mask_ranges(ocs, imm + links)
    lcm = mask_ranges(lcs, imm + links)
    if extra_oc_mask:
        ocm = mask_ranges(ocm, extra_oc_mask)
    if extra_local_mask:
        lcm = mask_ranges(lcm, extra_local_mask)
    match = ocm == lcm
    ok_len = len(ocs) == len(lcs)
    sha_oc = hashlib.sha256(bytes.fromhex(ocm)).hexdigest()
    sha_lc = hashlib.sha256(bytes.fromhex(lcm)).hexdigest()
    status = "MATCH" if match else ("LEN-ONLY" if ok_len else "MISMATCH")
    print(f"{name}:")
    print(f"   on-chain {len(ocs)//2}b (meta {ocmeta}) | local {len(lcs)//2}b (meta {lcmeta}) | imm:{len(imm)} links:{len(links)} -> {status}")
    print(f"   sha256(masked) on-chain {sha_oc}")
    print(f"   sha256(masked) local    {sha_lc}")
    if not match and ok_len:
        cl = diff_clusters(ocm, lcm)
        print(f"   diff byte clusters: {cl[:15]}")
        total = sum(e - s + 1 for s, e in cl)
        print(f"   total differing bytes: {total}")
    return {
        "name": name, "status": status, "oc_bytes": len(ocs)//2, "local_bytes": len(lcs)//2,
        "sha_oc": sha_oc, "sha_local": sha_lc, "imm": len(imm), "links": len(links),
        "clusters": diff_clusters(ocm, lcm) if (not match and ok_len) else [],
    }
