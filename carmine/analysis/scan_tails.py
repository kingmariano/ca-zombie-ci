#!/usr/bin/env python3
"""Scan option-list tails for Carmine pools: find last index + nonzero positions + max maturity."""
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/carmine/analysis")
from sn import call, call_batch, u256, arr

LEGACY = "0x076dbabc4293db346b0a56b29b6ea9fe18e93742c73f12348c8747ecfc1050aa"
NEW = "0x047472e6755afc57ada9550b6a3ac93129cc4b5f98f51c73e0644d129fd208d9"
POOLS = {
    "legacy": [("0x07aba50fdb4e024c1ba63e2c60565d0fd32566ff4b18aa5818fc80c30e749024", False),
               ("0x18a6abca394bd5f822cfa5f88783c01b13e593d1603e7b41b00d31d2ea4827a", False)],
    "new": [("0x70cad6be2c3fc48c745e4a4b70ef578d9c79b46ffac4cd93ec7b61f951c7c5c", True),
            ("0x466e3a6731571cf5d74c5b0d9c508bfb71438de10f9a13269177b01d6f07159", True),
            ("0x35db72a814c9b30301f646a8fa8c192ff63a0dc82beb390a36e6e9eba55b6db", True),
            ("0x1bf27366077765c922f342c8de257591d1119ebbcbae7a6c4ff2f50ede4c54c", True),
            ("0x6df66db6a4b321869b3d1808fc702713b6cbb69541d583d4b38e7b1406c09aa", True),
            ("0x4dcd9632353ed56e47be78f66a55a04e2c1303ebcb8ec7ea4c53f4fdf3834ec", True),
            ("0x2b629088a1d30019ef18b893cebab236f84a365402fa0df2f51ec6a01506b1d", True),
            ("0x6ebf1d8bd43b9b4c5d90fb337c5c0647b406c6c0045da02e6675c43710a326f", True),
            ("0x78a090c99bfc993fe8bbd19487351e501dbe7b50ab695966605e0839b34182a", True),
            ("0xe12a16c964dc68850c1f6cbea9062c36bed7676265eec7f563c728c53e536f", True)],
}
MAXI = 400


def opts_from(amm, lpt, new, start, count=50):
    idxs = list(range(start, min(start + count, MAXI)))
    fns = [("get_available_options", [lpt, i]) for i in idxs]
    out = call_batch(amm, fns)
    res = []
    for i, r in enumerate(out):
        if isinstance(r, Exception):
            # retry single
            try:
                r = call(amm, "get_available_options", [lpt, idxs[i]])
            except Exception:
                res.append((idxs[i], "ERR"))
                continue
        if new:
            if r[1] + r[2] == 0:
                res.append((idxs[i], None)); continue
            res.append((idxs[i], {"side": r[0], "maturity": r[1], "strike": r[2], "sign": r[3],
                                  "quote": hex(r[4]), "base": hex(r[5]), "type": r[6]}))
        else:
            if r[1] + r[2] == 0:
                res.append((idxs[i], None)); continue
            res.append((idxs[i], {"side": r[0], "maturity": r[1], "strike": r[2],
                                  "quote": hex(r[3]), "base": hex(r[4]), "type": r[5]}))
    return res


def main():
    out = {}
    for name, pools in POOLS.items():
        amm = LEGACY if name == "legacy" else NEW
        for lpt, new in pools:
            entries = []
            i = 0
            while i < MAXI:
                chunk = opts_from(amm, lpt, new, i)
                stop = False
                for idx, o in chunk:
                    if o is None:
                        stop = True
                        break
                    if o == "ERR":
                        continue
                    entries.append(o)
                if stop:
                    break
                i += len(chunk)
            # positions for all entries in batches
            fns = []
            for o in entries:
                st = [o["strike"], o["sign"]] if new else [o["strike"]]
                fns.append(("get_option_position", [lpt, 0, o["maturity"]] + st))
                fns.append(("get_option_position", [lpt, 1, o["maturity"]] + st))
            res = call_batch(amm, fns)
            nz = []
            for k, o in enumerate(entries):
                pl = res[2 * k][0] if not isinstance(res[2 * k], Exception) else -1
                ps = res[2 * k + 1][0] if not isinstance(res[2 * k + 1], Exception) else -1
                o["pos_long"] = pl; o["pos_short"] = ps
                if pl or ps:
                    nz.append(o)
            out[f"{name}:{lpt}"] = {
                "n_options": len(entries),
                "max_maturity": max(o["maturity"] for o in entries),
                "max_maturity_strike": [o["strike"] for o in entries if o["maturity"] == max(x["maturity"] for x in entries)][0],
                "nonzero_positions": nz,
                "last5": entries[-5:],
            }
            print(f"{name} {lpt[:12]} n={len(entries)} maxmat={out[f'{name}:{lpt}']['max_maturity']} nz={len(nz)}", file=sys.stderr)
    print(json.dumps(out, indent=1, default=str))


if __name__ == "__main__":
    main()
