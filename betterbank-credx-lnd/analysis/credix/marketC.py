#!/usr/bin/env python3
"""Full enumeration of CrediX market C (pool 0x12144c9b3fdCc1E40083280C3FE28BB568814A91)."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpcx import rpc, batch, dec_u, addr_from_word  # noqa

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")

PROV = {
    "getPool": "0x026b1d5f", "getPoolConfigurator": "0x631adfca", "getPriceOracle": "0xfca513a8",
    "getACLManager": "0x707cd716", "getACLAdmin": "0x0e67178c", "getPoolDataProvider": "0xe860accb",
    "getPriceOracleSentinel": "0x5eb88d3d", "owner": "0x8da5cb5b", "getMarketId": "0x568ef470",
}
SEL = {
    "getReservesList": "0xd1946dbc", "getReserveData": "0x35ea6a75",
    "symbol": "0x95d89b41", "name": "0x06fdde03", "decimals": "0x313ce567",
    "balanceOf": "0x70a08231", "totalSupply": "0x18160ddd", "scaledTotalSupply": "0xb1bf962d",
}
ROLES = {
    "DEFAULT_ADMIN": "0x" + "00" * 32,
    "POOL_ADMIN": "0x12ad05bde78c5ab75238ce885307f96ecd482bb402ef831f99e7018a0f169b7b",
    "EMERGENCY_ADMIN": "0x5c91514091af31f62f596a314af7d5be40146b2f2355969392f055e12e0982fb",
    "RISK_ADMIN": "0x8aa855a911518ecfbe5bc3088c8f3dda7badf130faaf8ace33fdc33828e18167",
    "BRIDGE": "0x08fb31c3e81624356c3314088aa971b73bcc82d22bc3e3b184b4593077ae3278",
    "ASSET_LISTING_ADMIN": "0x19c860a63258efbd0ecb7d55c626237bf5c2044c26c073390b74f0c13c857433",
    "FLASH_BORROWER": "0x939b8dfb57ecef2aea54a93a15e86768b9d4089f1ba61c245e6ec980695f4ca4",
}
SUBJECTS = {
    "attacker": "0xF321683831Be16eeD74dfA58b02a37483cEC662e",
    "admin_0x0dd0": "0x0dd010513F7abB8F9c628dC164a24D953BCA09Cf",
    "safeB": "0xD3E02C92f59a0ba5601464299D658d3a0a7cf96F",
    "aclAdminA": "0x3d0c177E035C30bb8681e5859EB98d114b48b935",
    "deployer": "0xc7461891c88f6a609d9149d2826704bd178a80de",
    "zero": "0x0000000000000000000000000000000000000000",
}
ZERO = "0x0000000000000000000000000000000000000000"


def pad_a(a):
    return a[2:].lower().rjust(64, "0")


def dec_str(hexstr):
    if not isinstance(hexstr, str):
        return None
    try:
        h = hexstr[2:]
        if len(h) < 128:
            return None
        ln = int(h[64:128], 16)
        return bytes.fromhex(h[128:128 + ln * 2]).decode("utf-8", "replace")
    except Exception:
        return None


def decode_reserve_data(hexstr):
    h = hexstr[2:]
    w = [h[i * 64:(i + 1) * 64] for i in range(len(h) // 64)]
    if len(w) < 15:
        return {"raw": hexstr, "nwords": len(w)}
    return {"configuration": int(w[0], 16), "liquidityIndex": int(w[1], 16),
            "currentLiquidityRate": int(w[2], 16), "variableBorrowIndex": int(w[3], 16),
            "currentVariableBorrowRate": int(w[4], 16), "currentStableBorrowRate": int(w[5], 16),
            "lastUpdateTimestamp": int(w[6], 16), "id": int(w[7], 16),
            "aTokenAddress": addr_from_word(w[8]), "stableDebtTokenAddress": addr_from_word(w[9]),
            "variableDebtTokenAddress": addr_from_word(w[10]),
            "interestRateStrategyAddress": addr_from_word(w[11]),
            "accruedToTreasury": int(w[12], 16), "unbacked": int(w[13], 16),
            "isolationModeTotalDebt": int(w[14], 16)}


def main():
    block = int(rpc("eth_blockNumber", []), 16)
    out = {"block": block}
    provider = "0x3BC884500E670e184eF1421a6980455fd3FA3739"
    pool = "0x12144c9b3fdCc1E40083280C3FE28BB568814A91"
    res = batch([("eth_call", [{"to": provider, "data": s}, hex(block)]) for s in PROV.values()])
    prov = {}
    for k, v in zip(PROV, res):
        if k == "getMarketId":
            prov[k] = dec_str(v) if isinstance(v, str) else v
        elif isinstance(v, str):
            prov[k] = addr_from_word(v)
        else:
            prov[k] = v
    out["provider"] = {"address": provider, **prov}

    rl = rpc("eth_call", [{"to": pool, "data": SEL["getReservesList"]}, hex(block)])
    h = rl[2:]
    n = int(h[64:128], 16)
    reserves = [addr_from_word(h[128 + i * 64:192 + i * 64]) for i in range(n)]
    out["pool"] = {"address": pool, "reserves": []}
    for asset in reserves:
        rec = {"asset": asset}
        rd = rpc("eth_call", [{"to": pool, "data": SEL["getReserveData"] + pad_a(asset)}, hex(block)])
        rec["reserveData"] = decode_reserve_data(rd) if isinstance(rd, str) else rd
        names = batch([("eth_call", [{"to": asset, "data": s}, hex(block)])
                       for s in (SEL["symbol"], SEL["name"], SEL["decimals"])])
        rec["symbol"] = dec_str(names[0]); rec["name"] = dec_str(names[1])
        rec["decimals"] = dec_u(names[2]) if isinstance(names[2], str) else None
        for k, tok in (("aToken", rec["reserveData"].get("aTokenAddress")),
                       ("vToken", rec["reserveData"].get("variableDebtTokenAddress")),
                       ("sToken", rec["reserveData"].get("stableDebtTokenAddress"))):
            if not tok or tok.lower() == ZERO:
                continue
            bal = batch([
                ("eth_call", [{"to": asset, "data": SEL["balanceOf"] + pad_a(tok)}, hex(block)]),
                ("eth_call", [{"to": tok, "data": SEL["totalSupply"]}, hex(block)]),
                ("eth_call", [{"to": tok, "data": SEL["scaledTotalSupply"]}, hex(block)]),
                ("eth_call", [{"to": tok, "data": SEL["symbol"]}, hex(block)]),
            ])
            rec[k + "_held_underlying"] = dec_u(bal[0]) if isinstance(bal[0], str) else bal[0]
            rec[k + "_totalSupply"] = dec_u(bal[1]) if isinstance(bal[1], str) else bal[1]
            rec[k + "_scaledTotalSupply"] = dec_u(bal[2]) if isinstance(bal[2], str) else bal[2]
            rec[k + "_symbol"] = dec_str(bal[3])
        out["pool"]["reserves"].append(rec)

    # roles
    acl = prov.get("getACLManager")
    out["roles"] = {}
    if acl:
        calls, meta = [], []
        for rname, rh in ROLES.items():
            for sname, s in SUBJECTS.items():
                calls.append(("eth_call", [{"to": acl, "data": "0x91d14854" + rh[2:] + pad_a(s)}, hex(block)]))
                meta.append((rname, sname))
        res = batch(calls)
        for (rname, sname), v in zip(meta, res):
            out["roles"].setdefault(rname, {})[sname] = (int(v, 16) == 1) if isinstance(v, str) else v
    json.dump(out, open(os.path.join(RAW, "marketC.json"), "w"), indent=1)
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
