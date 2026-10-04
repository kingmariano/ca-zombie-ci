#!/usr/bin/env python3
"""Read-only live probes against KiiChain mainnet (chain id 1783).

Evidence collector for the GHSA-7g4w-cg88-2cq2 residual-extractability review.
Writes JSON + a human-readable summary. No transactions are ever sent: only
eth_call / eth_getCode / eth_getBalance / eth_getBlockByNumber and Cosmos LCD
GET queries.
"""
import json
import sys
import time
import urllib.error
import urllib.request

RPC = "https://json-rpc.kiivalidator.com"
LCD = "https://lcd.kiivalidator.com"
UA = {"User-Agent": "Mozilla/5.0 (zombie-hunt research)"}

# 22 incident addresses from app/blockedaddrs/addrs.go @ KiiChain v7.4.0
# (2 attacker EOAs + 20 vesting/helper accounts; 19 of the latter were still
# delayed-vesting accounts at probe time).
ATTACKER_ADDRS = {
    "kii1peafvgnleuyl20tyfwnyvtvvwwvnaujxmqe5qe": "0x0e7a96227fcf09f53d644ba6462d8c73993ef246",
    "kii1vvwu93nya4ku9yds3v6ns2uq0fsmrnf4cf4yht": "0x631dc2c664ed6dc291b08b35382b807a61b1cd35",
    "kii1p3zmn7m6xq82jna6me04p8awt7k4u4k2alwu99": "0x0c45b9fb7a300ea94fbade5f509fae5fad5e56ca",
    "kii1zamzjyjcwl0dejjvr90rtrwttxx2zhspqx4sm5": "0x177629125877dedcca4c195e358dcb598ca15e01",
    "kii1zlqdn7706xym7q3k2mdleag0uqjnhv8wu4sfsj": "0x17c0d9fbcfd189bf023656dbfcf50fe0253bb0ee",
    "kii1rehngnge8qn3ngszw4a8xxf2kqwmact602wtm8": "0x1e6f344d19382719a202757a73192ab01dbee17a",
    "kii1y8m0qyc4n3m0rw4rcd7qnqahjh3r7p9uu3ert8": "0x21f6f013159c76f1baa3c37c0983b795e23f04bc",
    "kii19p9h2nw2y4fs85sgwgj2qrhhx7jmz6zujldh3n": "0x284b754dca255303d2087224a00ef737a5b1685c",
    "kii183h7rz9p4r8a7j8q2ardnrc7pgwnjp9jvhc8kq": "0x3c6fe188a1a8cfdf48e05746d98f1e0a1d3904b2",
    "kii1gp7ar4hdlqntl5qkerm5n8mfxhqkegm76zqskr": "0x407dd1d6edf826bfd016c8f7499f6935c16ca37e",
    "kii1gf9a9jjnnv8q3zcr8kczx0r5425zcfgpdw72tt": "0x424bd2ca539b0e088b033db0233c74aaa82c2501",
    "kii1t7gzjh4gsrcuyfx3xdsem05chluqfsa43j9g54": "0x5f90295ea880f1c224d133619dbe98bff804c3b5",
    "kii1wucgj4wxe0zvmmew2000cltc5qrl99eedtrzv4": "0x77308955c6cbc4cdef2e53defc7d78a007f29739",
    "kii1syetlh585kl6yv5hmflhfehla5re7ay4um2skh": "0x8132bfde87a5bfa23297da7f74e6ffed079f7495",
    "kii1s7jw5ffqgjfn4ywxtgtq3nhpgcn05z28fsmkhm": "0x87a4ea252044933a91c65a1608cee14626fa0947",
    "kii13ndtp734ntzx0jqvr80rlmj62slztqm9agzwce": "0x8cdab0fa359ac467c80c19de3fee5a543e258365",
    "kii13umhqxg56cxwa9wv4gu6l9v4vyz9e70g4hupvn": "0x8f37701914d60cee95ccaa39af959561045cf9e8",
    "kii156expaxlymu5uhepe2dh647c9lu4slxpyml28q": "0xa6b260f4df26f94e5f21ca9b7d57d82ff9587cc1",
    "kii1k8vyx8d9ru2hk3k207p3az84xedjxz2gkdyle0": "0xb1d8431da51f157b46ca7f831e88f5365b230948",
    "kii16tr429kvneexqf4jttueuecm75ptc5l3gtj34q": "0xd2c75516cc9e726026b25af99e671bf502bc53f1",
    "kii1mkhdmdgklsskgcgzz699nzhafav2hkea4qp2dj": "0xddaeddb516fc21646102168a598afd4f58abdb3d",
    "kii1a5v3eaeaugdh3vk57nlh8q8xcu7z46w0ttlrw9": "0xed191cf73de21b78b2d4f4ff7380e6c73c2ae9cf",
}

# Recovery payout list from app/upgrades/v7_4/upgrade.go @ KiiChain v7.4.0
PAYOUTS = [
    ("kii19c6q309u7c9atnvefqajdjzzjhn82cfcakx4cc", 1023953000000000000000),
    ("kii14r6lynfqtl6cznllajhms8xy9ce8udnqw73zwz", 366930000000000000000000),
    ("kii1af3ecamzq3zcllmdahx2sc0gaqxsp0r72h6x6j", 959472000000000000000000),
    ("kii10jtnkmhlkqnprvng9yenqgr0jtujp0guk3pysp", 982062000000000000000000),
    ("kii1meq2vy7rlnnceurju0uz9qeshfaaun0x5xsg06", 992286000000000000000000),
    ("kii196ceqskhhyj93hejczj6py8f0am7vs3fykark7", 1004832000000000000000000),
    ("kii1rt7arm6ckp0lcfuq9r0fmyl22urdcyfgfer35g", 1022706000000000000000000),
    ("kii18fqfr2j7v96xy4lggvaca5cef586jp7pry27v0", 1038420000000000000000000),
    ("kii1ehfns3qwnuhlunkhk5l2d0la8d8erenjn0482a", 1115262000000000000000000),
    ("kii18ufxrsncyegu9qactah4hzrn0xmqqlkxr6p3z5", 1116000000000000000000000),
    ("kii1qqyn3zg7g648pwc46y0depq8f82rj9400ulj4g", 1116000000000000000000000),
    ("kii13u7hu5lscvdc2yqg0x5t2qj27m8fj8jw4ez046", 3247115883451428571420551),
    ("kii1fc80es03yhle3xjpqp8e8pezl7an65h50fl2pm", 4496107929952857142857255),
    ("kii1syezrzevu6ycshvgtm4sxtreh3pxvk0mtfe6rd", 5139906382822857142856976),
    ("kii106tcwjead6wdj9xegyes80vfxd4da6sr4f5npu", 9000001000000000000000000),
    ("kii1n4mskp6c83rzvl9eraddqdgwuqt6zec46qv06q", 36000001000000000000000000),
]
REMAINDER = "kii1c6cgjmsx0ewl6j552sp06musutmfcvxcaq4n9h"
STAGING = "kii1vqu8rska6swzdmnhf90zuv0xmelej4lq5el7zh"

VALIDATOR = "kiivaloper1p98dndmkjwx8tc87f85cceae5jxq5rztecy5wp"
STAKING_PRECOMPILE = "0x0000000000000000000000000000000000000800"


def http_json(url, payload=None, timeout=30, tries=3):
    for attempt in range(tries):
        try:
            data = json.dumps(payload).encode() if payload is not None else None
            headers = dict(UA)
            if payload is not None:
                headers["Content-Type"] = "application/json"
            req = urllib.request.Request(url, data=data, headers=headers)
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return json.load(resp)
        except Exception as exc:  # noqa: BLE001
            if attempt == tries - 1:
                return {"_error": str(exc)}
            time.sleep(2)
    return {"_error": "unreachable"}


def rpc(method, params):
    return http_json(RPC, {"jsonrpc": "2.0", "id": 1, "method": method, "params": params})


def lcd(path):
    return http_json(LCD + path)


def evm_address_to_bech32_not_needed(hex_addr):  # pragma: no cover - documentation
    raise NotImplementedError


def delegate_calldata(delegator_hex, amount):
    sel = "53266bbb"  # delegate(address,string,uint256)
    a = delegator_hex[2:].lower().rjust(64, "0")
    off = "0000000000000000000000000000000000000000000000000000000000000060"
    amt = hex(amount)[2:].rjust(64, "0")
    slen = hex(len(VALIDATOR))[2:].rjust(64, "0")
    v = VALIDATOR.encode().hex()
    pad = (64 - len(v)) * "0"
    return "0x" + sel + a + off + amt + slen + v + pad


def main():
    out = {
        "collected_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "rpc": RPC,
        "lcd": LCD,
    }

    # --- chain access -------------------------------------------------------
    out["chain_id"] = rpc("eth_chainId", []).get("result")
    blk = rpc("eth_getBlockByNumber", ["latest", False]).get("result") or {}
    out["latest_block"] = int(blk["number"], 16) if blk.get("number") else None
    out["latest_block_time"] = blk.get("timestamp")
    out["client_version"] = rpc("web3_clientVersion", []).get("result")
    node = lcd("/cosmos/base/tendermint/v1beta1/node_info")
    app = node.get("application_version", {}) if isinstance(node, dict) else {}
    out["app_version"] = app.get("version")
    out["app_git_commit"] = app.get("git_commit")
    out["cosmos_sdk"] = next(
        (d.get("version") for d in app.get("build_deps", []) if d.get("path") == "github.com/cosmos/cosmos-sdk"),
        None,
    )
    supply = lcd("/cosmos/bank/v1beta1/supply")
    out["supply"] = {c["denom"]: c["amount"] for c in supply.get("supply", [])} if isinstance(supply, dict) else supply

    # --- attacker / helper addresses: code, balance, delegate probe ---------
    out["attacker_addresses"] = {}
    blocked_n = 0
    underflow_n = 0
    for bech, hex_addr in ATTACKER_ADDRS.items():
        entry = {"bech32": bech}
        bal = rpc("eth_getBalance", [hex_addr, "latest"]).get("result")
        entry["balance_akii"] = int(bal, 16) if bal else None
        code = rpc("eth_getCode", [hex_addr, "latest"]).get("result")
        entry["has_code"] = bool(code and code != "0x")
        probe = rpc(
            "eth_call",
            [
                {
                    "from": hex_addr,
                    "to": STAKING_PRECOMPILE,
                    # Delegate 1 wei: any amount above the account's *spendable*
                    # balance (0 for these drained vesting accounts) triggers the
                    # post-delegation StateDB write-back, which is where the
                    # GHSA-7g4w-cg88-2cq2 underflow occurred.
                    "data": delegate_calldata(hex_addr, 1),
                    "gas": "0x2faf080",
                },
                "latest",
            ],
        )
        err = (probe.get("error") or {}).get("message")
        if err and "address is blocked" in err:
            entry["delegate_probe"] = "BLOCKED"
            blocked_n += 1
        elif err and "state balance underflow" in err:
            entry["delegate_probe"] = "UNDERFLOW_GUARD_PANIC"
            entry["delegate_probe_error"] = err
            underflow_n += 1
        elif err:
            entry["delegate_probe"] = "OTHER_ERROR"
            entry["delegate_probe_error"] = err
        else:
            entry["delegate_probe"] = "SUCCEEDED"
        # Secondary probe with the exact incident amount (2 KII + 1 wei).
        probe2 = rpc(
            "eth_call",
            [
                {
                    "from": hex_addr,
                    "to": STAKING_PRECOMPILE,
                    "data": delegate_calldata(hex_addr, 2000000000000000001),
                    "gas": "0x2faf080",
                },
                "latest",
            ],
        )
        entry["delegate_probe_incident_amount"] = (probe2.get("error") or {}).get("message", "SUCCEEDED")[:160]
        entry["account_type"] = (
            lcd(f"/cosmos/auth/v1beta1/accounts/{bech}").get("account", {}).get("@type")
            if isinstance(lcd(f"/cosmos/auth/v1beta1/accounts/{bech}"), dict)
            else None
        )
        out["attacker_addresses"][hex_addr] = entry
    out["blocklist_probe_summary"] = {
        "total": len(ATTACKER_ADDRS),
        "blocked": blocked_n,
        "underflow_guard": underflow_n,
    }

    # --- exploit tx replay (sweep call, owner = attacker) -------------------
    out["exploit_tx_replay"] = rpc(
        "eth_call",
        [
            {
                "from": "0x0e7a96227fcf09f53d644ba6462d8c73993ef246",
                "to": "0x424bd2ca539b0e088b033db0233c74aaa82c2501",
                "data": "0x01681a620000000000000000000000000e7a96227fcf09f53d644ba6462d8c73993ef246",
                "gas": "0x2faf080",
            },
            "latest",
        ],
    )

    # --- recovery accounting -------------------------------------------------
    def balance_of(bech):
        d = lcd(f"/cosmos/bank/v1beta1/balances/{bech}")
        if not isinstance(d, dict):
            return None
        for c in d.get("balances", []):
            if c["denom"] == "akii":
                return int(c["amount"])
        return 0

    out["recovery"] = {
        "payout_recipients": {},
        "remainder": {"address": REMAINDER, "balance_akii": balance_of(REMAINDER)},
        "staging": {"address": STAGING, "balance_akii": balance_of(STAGING)},
    }
    payout_total = 0
    for bech, amount in PAYOUTS:
        payout_total += amount
        out["recovery"]["payout_recipients"][bech] = {
            "planned_akii": amount,
            "current_balance_akii": balance_of(bech),
        }
    out["recovery"]["payout_total_akii"] = payout_total

    # --- price (best effort, informational only) -----------------------------
    price = http_json("https://api.coingecko.com/api/v3/simple/price?ids=kiichain&vs_currencies=usd")
    out["kii_price_usd"] = price.get("kiichain", {}).get("usd") if isinstance(price, dict) else None

    with open("ci-out/live_probes.json", "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)

    # human-readable summary
    with open("ci-out/live_probes.txt", "w") as fh:
        fh.write(f"collected_at: {out['collected_at']}\n")
        fh.write(f"chain_id: {out['chain_id']}  latest_block: {out['latest_block']}\n")
        fh.write(f"app_version: {out['app_version']}  commit: {out['app_git_commit']}\n")
        fh.write(f"client_version: {out['client_version']}\n")
        fh.write(f"supply: {out['supply']}\n")
        fh.write(f"blocklist probes: {out['blocklist_probe_summary']}\n")
        fh.write(f"exploit sweep replay: {out['exploit_tx_replay']}\n")
        fh.write(f"payout_total: {out['recovery']['payout_total_akii']} akii\n")
        fh.write(f"remainder balance: {out['recovery']['remainder']['balance_akii']} akii\n")
        fh.write(f"staging balance: {out['recovery']['staging']['balance_akii']} akii\n")
        fh.write(f"kii_price_usd: {out['kii_price_usd']}\n")
        for hex_addr, entry in out["attacker_addresses"].items():
            fh.write(
                f"  {hex_addr}  balance={entry['balance_akii']}  code={entry['has_code']}  "
                f"probe={entry['delegate_probe']}  type={entry['account_type']}\n"
            )

    print(json.dumps(out["blocklist_probe_summary"], indent=1))
    print(f"latest_block={out['latest_block']} app={out['app_version']}")
    print("wrote ci-out/live_probes.json and ci-out/live_probes.txt")


if __name__ == "__main__":
    sys.exit(main())
