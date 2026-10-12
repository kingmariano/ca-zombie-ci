#!/usr/bin/env python3
"""Enumerate SPL token accounts owned by an authority, grouped by mint.

Read-only. RPC URL from env SOLANA_RPC_URL (default: keyless publicnode).
Writes JSON to stdout (caller redirects). Never stores secrets.
"""
import json, os, sys, base64, urllib.request

RPC = os.environ.get("SOLANA_RPC_URL", "https://solana-rpc.publicnode.com")
OWNER = sys.argv[1] if len(sys.argv) > 1 else "7gpj9cpzBBW9Ci1yMwWz7iGbQYpm5fZmadNQyrYsqch8"
TOKEN_PROGRAM = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"

def rpc(method, params, timeout=180):
    req = urllib.request.Request(
        RPC,
        data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "research-readonly/1.0"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as r:
        d = json.loads(r.read())
    if "error" in d:
        raise RuntimeError(f"{method}: {d['error']}")
    return d["result"]

def main():
    res = rpc("getProgramAccounts", [
        TOKEN_PROGRAM,
        {
            "encoding": "base64",
            "filters": [{"memcmp": {"offset": 32, "bytes": OWNER}}],
            "withContext": True,
        },
    ], timeout=600)
    ctx_slot = res.get("context", {}).get("slot")
    accts = res["value"]
    by_mint = {}
    total_by_mint = {}
    out_accounts = []
    for a in accts:
        data = base64.b64decode(a["account"]["data"][0])
        mint = base64.b58encode(data[0:32]).decode() if False else None
        # base58 encode via solders if available
        from solders.pubkey import Pubkey
        mint = str(Pubkey.from_bytes(data[0:32]))
        owner_authority = str(Pubkey.from_bytes(data[32:64]))
        amt = int.from_bytes(data[64:72], "little")
        state = data[108]
        delegate_raw = data[72:104]
        delegated = int.from_bytes(data[104:112], "little")
        close_auth_raw = data[128:160] if len(data) >= 165 else b""
        out_accounts.append({
            "addr": a["pubkey"], "mint": mint, "amount": amt, "state": state,
            "delegate": (str(Pubkey.from_bytes(delegate_raw)) if any(delegate_raw) else None),
            "delegated_amount": delegated,
            "close_authority": (str(Pubkey.from_bytes(close_auth_raw)) if any(close_auth_raw) else None),
            "lamports": a["account"]["lamports"],
        })
        by_mint.setdefault(mint, {"accounts": 0, "nonzero": 0, "raw_total": 0})
        by_mint[mint]["accounts"] += 1
        if amt:
            by_mint[mint]["nonzero"] += 1
            by_mint[mint]["raw_total"] += amt
            total_by_mint[mint] = total_by_mint.get(mint, 0) + amt
    out = {
        "rpc": "public-or-env (redacted)",
        "slot": ctx_slot,
        "owner_authority": OWNER,
        "num_accounts": len(out_accounts),
        "by_mint": by_mint,
        "accounts": out_accounts,
    }
    json.dump(out, sys.stdout)

if __name__ == "__main__":
    main()
