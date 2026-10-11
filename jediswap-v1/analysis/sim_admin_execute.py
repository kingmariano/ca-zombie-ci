#!/usr/bin/env python3
"""Read-only simulateTransactions: can a third party make the Argent admin account
execute calls (which would let it upgrade all JediSwap pair proxies)?
No tx is broadcast; simulateTransactions is a read-only RPC.
"""
import json, urllib.request, urllib.error
import sn

ADMIN = "0x284a1ad6382cffc520d8f711cf9519ccf43b3c105b89ef081cbe1a625322410"
FACT = "0xdad44c139a476c7a17fc8141e6db680e9abc9f56fe249a105094c44382c2fd"
FACT_IMPL = "0x2580632f25bbee45da5a1a1ef49d03a984f78dde4019069aa9f25aac06f941a"
RPC = "https://api.cartridge.gg/x/starknet/mainnet"


def raw(method, params, url=RPC):
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode())
        except Exception:
            return e.code, {"raw": "unparseable"}


def inner_admin_execute_calldata(target, sel, cd):
    # Array<Call> for ADMIN.__execute__: [1, target, selector, len(cd), cd...]
    return [1, int(target, 16), int(sel, 16), len(cd)] + cd


def simulate(sender, nonce, sender_calldata, flags):
    tx = {"type": "INVOKE", "version": "0x1", "sender_address": hex(int(sender, 16)),
          "calldata": [hex(x) for x in sender_calldata], "signature": [],
          "nonce": hex(nonce), "max_fee": "0x0"}
    return raw("starknet_simulateTransactions", {"block_id": "latest", "transactions": [tx],
                                                 "simulation_flags": flags})


def main():
    third = "0x2b9d17a44a0f747b6374ee5ea9fb1c2acdb1825adb0a1dd905b756617827ff9"
    nonce_third = int(sn.rpc("starknet_getNonce", ["latest", third]), 16)
    nonce_admin = int(sn.rpc("starknet_getNonce", ["latest", ADMIN]), 16)
    upgrade_sel = sn.selector("upgrade")
    exec_sel = sn.selector("__execute__")

    inner = inner_admin_execute_calldata(FACT, upgrade_sel, [int(FACT_IMPL, 16)])
    # outer: sender's __execute__ calls ADMIN.__execute__(inner)
    outer = [1, int(ADMIN, 16), int(exec_sel, 16), len(inner)] + inner

    print("inner (ADMIN.__execute__ calldata):", [hex(x) for x in inner])
    print("outer (sender.__execute__ calldata):", [hex(x) for x in outer])

    for flags in (["SKIP_VALIDATE", "SKIP_FEE_CHARGE"], ["SKIP_VALIDATE"]):
        print("\n=== TEST third-party sender, flags", flags, "===")
        st, resp = simulate(third, nonce_third, outer, flags)
        print("status", st)
        print(json.dumps(resp)[:900])

    print("\n=== CONTROL sender=ADMIN itself, flags [SKIP_VALIDATE, SKIP_FEE_CHARGE] ===")
    outer_admin = [1, int(ADMIN, 16), int(exec_sel, 16), len(inner)] + inner
    st, resp = simulate(ADMIN, nonce_admin, outer_admin, ["SKIP_VALIDATE", "SKIP_FEE_CHARGE"])
    print("status", st)
    print(json.dumps(resp)[:900])

    json.dump({"test": {"third_party": {"sender": third, "calldata": [hex(x) for x in outer]},
                        "control": {"sender": ADMIN, "calldata": [hex(x) for x in outer_admin]}},
               "admin": ADMIN, "factory": FACT, "factory_impl": FACT_IMPL},
              open("/home/heisenberg/CA/jediswap-v1/analysis/sim_admin_execute.json", "w"), indent=1)


if __name__ == "__main__":
    main()
