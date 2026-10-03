#!/usr/bin/env python3
"""
C-40 Nostra (Starknet) — independent read-only verification harness.
Re-checks the live state at the CI run's latest block:
  * main Money Market fully paused (every value-moving entrypoint reverts)
  * IRM (liquidity pool) holdings + access controls on release_underlying/init_market
  * pools: no free output / invariant enforced
  * nstSTRK vault: withdrawals enabled, 1:1 backed
  * Alpha (v1) sibling market: unpaused, normal-risk, cash present
Writes ci-out/nostra_verification.json. No transactions; simulation only (SKIP_VALIDATE).
"""
import json, subprocess, sys, time

try:
    from Crypto.Hash import keccak
except ImportError:
    print("pycryptodome required: pip install pycryptodome")
    sys.exit(2)

RPC_FALLBACKS = [
    "https://starknet-rpc.publicnode.com",
    "https://api.cartridge.gg/x/starknet/mainnet",
]
MASK = (1 << 250) - 1


def keccak256(data: bytes) -> bytes:
    h = keccak.new(digest_bits=256)
    h.update(data)
    return h.digest()


def sn_keccak(s: str) -> int:
    return int.from_bytes(keccak256(s.encode()), "big") & MASK


RPC = None


def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params})
    last = None
    for attempt in range(3):
        for url in ([RPC] if RPC else RPC_FALLBACKS):
            try:
                out = subprocess.run(["curl", "-s", "-m", "40", "-X", "POST",
                                      "-H", "Content-Type: application/json",
                                      "-d", body, url], capture_output=True, text=True).stdout
                d = json.loads(out)
                if "result" in d or "error" in d:
                    globals()["RPC"] = url
                    return d
            except Exception as e:
                last = e
        time.sleep(3)
    return {"error": {"message": f"rpc failed: {last}"}}


def call(to, fn, calldata=None, block="latest"):
    return rpc("starknet_call", [{"contract_address": to,
                                  "entry_point_selector": hex(sn_keccak(fn)),
                                  "calldata": calldata or []}, block])


def revert_of(r):
    if "result" in r:
        return None
    e = r.get("error", {})
    d = e.get("data", {})
    rev = d.get("revert_error", "") if isinstance(d, dict) else str(d)
    try:
        return rev, bytes.fromhex(rev[2:]).decode("ascii", "replace")
    except Exception:
        return rev, ""


def build_calldata(calls):
    cd = [hex(len(calls))]
    for to, sel, args in calls:
        cd += [to, hex(sn_keccak(sel)), hex(len(args))] + [hex(a) if isinstance(a, int) else a for a in args]
    return cd


def sim(sender, calls, block="latest"):
    nonce = rpc("starknet_getNonce", [block, sender]).get("result", "0x0")
    tx = {
        "type": "INVOKE", "version": "0x3", "sender_address": sender,
        "calldata": build_calldata(calls), "signature": [], "nonce": nonce,
        "resource_bounds": {
            "l1_gas": {"max_amount": "0x186a0", "max_price_per_unit": "0x5f5e100"},
            "l2_gas": {"max_amount": "0x186a0", "max_price_per_unit": "0x5f5e100"},
            "l1_data_gas": {"max_amount": "0x186a0", "max_price_per_unit": "0x5f5e100"},
        },
        "tip": "0x0", "paymaster_data": [], "account_deployment_data": [],
        "nonce_data_availability_mode": "L1", "fee_data_availability_mode": "L1",
    }
    return rpc("starknet_simulateTransactions", [block, [tx], ["SKIP_VALIDATE", "SKIP_FEE_CHARGE"]])


def sim_revert(r):
    if "result" not in r:
        return f"SIMERR {json.dumps(r)[:200]}"
    t = r["result"][0]["transaction_trace"]
    ex = t.get("execute_invocation", {})
    rev = ex.get("revert_reason")
    if not rev:
        return "SUCCESS"
    # decode last ascii-looking segment
    return rev


ATT = "0x06d48ef7ab62c26e3ef1987c322096cd508e9034c82048783a6b438fc1344bc3"  # public exploit account (Braavos)
CM = "0x073f6addc9339de9822cab4dac8c9431779c09077f02ba7bc36904ea342dd9eb"
IRM = "0x059a943ca214c10234b9a3b61c558ac20c005127d183b86a99a8f3c60a08b4ff"
FLASH = "0x01bcfcb651e98317dc042cb34d0e0226c7f83bca309b6c54d8f0df6ee4e5f721"
NSTR = "0x00c530f2c0aa4c16a0806365b0898499fba372e5df7a7172dc6fe9ba777e8007"
NSTR_DEBT = "0x3e0576565c1b51fcac3b402eb002447f21e97abb5da7011c0a2e0b465136814"
USDC_DEBT = "0x063d69ae657bd2f40337c39bf35a870ac27ddf91e6623c2f52529db4c1619a51"
NSTR_IBC = "0x46ab56ec0c6a6d42384251c97e9331aa75eb693e05ed8823e2df4de5713e9a4"
ETH = "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7"
ETH_IB = "0x01fecadfe7cda2487c66291f2970a629be8eecdcb006ba4e71d1428c2b7605c7"
POOL_STRK_ETH = "0x068400056dccee818caa7e8a2c305f9a60d255145bac22d6c5c9bf9e2e046b71"
STRK = "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d"
NSTSTRK = "0x04619e9ce4109590219c5263787050726be63382148538f3f936c22aa87d2fc2"
ALPHA_CM = "0x06d272e18e66289eeb874d0206a23afba148ef35f250accfdfdca085a478aec0"
ALPHA_ETH_NOSTRA = "0x04f89253e37ca0ab7190b2e9565808f105585c9cacca6b2fa6145553fa061a41"
NSTR_FEED = "0x683852789848dea686fcfb66aaebf6477d83b25d8894aae73b15ff19b765bf0"


def u256(x):
    return [x & ((1 << 128) - 1), x >> 128]


def val(r):
    if r and "result" in r and r["result"]:
        v = r["result"]
        return int(v[0], 16) + (int(v[1], 16) << 128) if len(v) >= 2 else int(v[0], 16)
    return None


def main():
    out = {"finding": "C-40", "chain": "starknet", "checks": {}, "assertions": {}}
    block = rpc("starknet_blockNumber", []).get("result")
    out["block"] = block
    print(f"[i] RPC={RPC} block={block}")

    # 1. main market pause state
    out["checks"]["cdp_is_paused"] = val(call(CM, "is_paused"))
    out["checks"]["cdp_when_not_paused"] = revert_of(call(CM, "when_not_paused"))
    out["checks"]["cdp_owner"] = (call(CM, "owner").get("result") or [None])[0]

    # 2. every value-moving entrypoint reverts (impersonated sim from public exploit account)
    sims = {
        "borrow_nstr": [(NSTR_DEBT, "borrow", [ATT] + u256(10 ** 18))],
        "borrow_usdc": [(USDC_DEBT, "borrow", [ATT] + u256(10 ** 6))],
        "repay_nstr": [(NSTR_DEBT, "repay", [ATT] + u256(10 ** 18))],
        "deposit_eth": [(ETH, "approve", [ETH_IB] + u256(10 ** 15)), (ETH_IB, "deposit", [ATT] + u256(10 ** 15))],
        "withdraw_ibc": [(NSTR_IBC, "withdraw", [ATT, ATT] + u256(10 ** 18))],
        "liquidate": [(CM, "liquidate", [ATT, "0x0", "0x0"])],
        "flash_loan": [(FLASH, "flash_loan", [ATT, NSTR_DEBT] + u256(10 ** 18) + [0])],
    }
    for k, calls in sims.items():
        r = sim(ATT, calls)
        rev = sim_revert(r)
        out["checks"][f"sim_{k}"] = rev[-160:] if isinstance(rev, str) else rev
        print(f"[i] sim_{k}: {'paused' if 'CDP Manager is paused' in str(rev) else str(rev)[:120]}")

    # 3. IRM custody + access control
    out["checks"]["irm_nstr_balance"] = val(call(NSTR, "balanceOf", [IRM]))
    out["checks"]["irm_release_unauth"] = sim_revert(sim(ATT, [(IRM, "release_underlying", [NSTR_DEBT, ATT] + u256(10 ** 18))]))
    out["checks"]["irm_init_market"] = sim_revert(sim(ATT, [(IRM, "init_market",
        ["0x0123456789abcdef0123456789abcdef01234567"] * 3 + u256(0) * 5 + [ATT])]))

    # 4. pools: free-output rejected; invariant enforced
    out["checks"]["pool_free_out"] = sim_revert(sim(ATT, [(POOL_STRK_ETH, "swap", u256(0) + u256(10 ** 18) + [ATT, 0])]))
    out["checks"]["pool_invariant"] = sim_revert(sim(ATT, [
        (STRK, "transfer", [POOL_STRK_ETH] + u256(10 ** 15)),
        (POOL_STRK_ETH, "swap", u256(0) + u256(10 ** 18) + [ATT, 0]),
    ]))

    # 5. nstSTRK vault
    out["checks"]["nststrk_withdrawal_disabled"] = val(call(NSTSTRK, "is_withdrawal_disabled"))
    out["checks"]["nststrk_total_supply"] = val(call(NSTSTRK, "totalSupply"))
    out["checks"]["nststrk_strk_held"] = val(call(STRK, "balanceOf", [NSTSTRK]))

    # 6. Alpha sibling
    out["checks"]["alpha_when_not_paused"] = revert_of(call(ALPHA_CM, "whenNotPaused"))
    out["checks"]["alpha_eth_cash"] = val(call(ETH, "balanceOf", [ALPHA_ETH_NOSTRA]))

    # 7. NSTR feed live price > 0
    out["checks"]["nstr_feed_price"] = val(call(NSTR_FEED, "getAssetPrice", [NSTR]))

    a = out["assertions"]
    a["market_paused"] = out["checks"]["cdp_is_paused"] == 1 and "CDP Manager is paused" in str(out["checks"]["cdp_when_not_paused"])
    a["all_value_paths_paused"] = all("CDP Manager is paused" in str(v) for k, v in out["checks"].items() if k.startswith("sim_"))
    a["irm_holds_nstr"] = (out["checks"]["irm_nstr_balance"] or 0) > 5_000_000 * 10 ** 18
    a["irm_release_unauthorized"] = "Unauthorized call" in str(out["checks"]["irm_release_unauth"])
    a["pool_invariant_enforced"] = "invariant" in str(out["checks"]["pool_invariant"])
    a["pool_free_out_rejected"] = "INSUFFICIENT_INPUT_AMOUNT" in str(out["checks"]["pool_free_out"]) or "invariant" in str(out["checks"]["pool_free_out"])
    a["nststrk_withdrawable"] = out["checks"]["nststrk_withdrawal_disabled"] == 0
    a["nststrk_backed"] = out["checks"]["nststrk_strk_held"] is not None and out["checks"]["nststrk_total_supply"] is not None and abs(out["checks"]["nststrk_strk_held"] - out["checks"]["nststrk_total_supply"]) < 10 ** 18
    a["alpha_unpaused"] = out["checks"]["alpha_when_not_paused"] is None
    a["nstr_feed_positive"] = (out["checks"]["nstr_feed_price"] or 0) > 0

    out["all_pass"] = all(a.values())
    print(json.dumps({"assertions": a, "all_pass": out["all_pass"]}, indent=1))
    with open("ci-out/nostra_verification.json", "w") as f:
        json.dump(out, f, indent=1, default=str)
    return 0 if out["all_pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
