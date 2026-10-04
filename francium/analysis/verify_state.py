#!/usr/bin/env python3
"""Read-only live-state summary for H-29 (Francium). Writes a compact report to stdout/ci-out."""
import json, sys, os, base64
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "analysis"))
from rpc import rpc_call

ROOT = os.path.dirname(os.path.abspath(__file__))

PROGS = {
    "lending": "FC81tbGt6JWRXidaWYFXxGnTk4VgobhJHATvTRVMqgWj",
    "reward": "3Katmm9dhvLQijAvomteYMo6rfVbY5NaCRNq9ZBqBgr6",
    "lyfRaydium": "2nAAsYdXF3eTQzaeUQS3fr4o782dDg8L28mX39Wr5j8N",
    "lyfOrca": "DmzAmomATKpNp2rCBfYLS7CSwQqeQTsgRYJA1oSSAJaP",
}

def main():
    out = {"slot": rpc_call("getSlot", []), "programs": {}}
    for name, pid in PROGS.items():
        info = rpc_call("getAccountInfo", [pid, {"encoding": "jsonParsed"}])
        pdata = info["value"]["data"]["parsed"]["info"]["programData"]
        pd = rpc_call("getAccountInfo", [pdata, {"encoding": "base64"}])
        raw = base64.b64decode(pd["value"]["data"][0])
        state = int.from_bytes(raw[0:4], "little")
        slot = int.from_bytes(raw[4:12], "little")
        opt = raw[12]
        auth = raw[13:45].hex() if opt == 1 else None
        out["programs"][name] = {"program": pid, "programData": pdata, "state": state, "last_deploy_slot": slot, "has_upgrade_authority": opt == 1, "upgrade_authority_hex": auth}
    # strategy 34eXEXyp (SOL-USDC) live state
    s = rpc_call("getAccountInfo", ["34eXEXypQiwyQhMRAMbCEJSs16SVaN3C6wzPicEcBTH1", {"encoding": "base64"}])
    out["strategy_34eXEXyp_len"] = len(base64.b64decode(s["value"]["data"][0]))
    # token balances of the strategy vaults
    for label, acct in [("strategy_tkn0_USDC", "88NCYVzm9kXCkNFrQgACyeHRnPYWuUKx7ePC4HeTkCps"), ("strategy_tkn1_WSOL", "BCMcGhuqdPZo1LxDqJg9MrDKedvoHd92e67uvtoRhrEn")]:
        b = rpc_call("getTokenAccountBalance", [acct])
        out[label] = b["value"]
    # category totals from local analysis (if present)
    bal_path = os.path.join(ROOT, "analysis", "balances.json")
    if os.path.exists(bal_path):
        bal = json.load(open(bal_path))
        nz = [r for r in bal["rows"] if r.get("amount")]
        out["vault_token_accounts_with_balance"] = len(nz)
    print(json.dumps(out, indent=1))
    os.makedirs(os.path.join(ROOT, "ci-out"), exist_ok=True)
    json.dump(out, open(os.path.join(ROOT, "ci-out", "state_summary.json"), "w"), indent=1)

if __name__ == "__main__":
    main()
