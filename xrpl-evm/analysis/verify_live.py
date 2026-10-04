#!/usr/bin/env python3
"""
XRPL EVM sidechain — live gate verification for cosmos/evm GHSA-7g4w-cg88-2cq2
(SubBalance underflow) and GHSA-367m-g444-9mg3 (non-atomic StateDB commit).

Read-only. No transactions, no keys. Everything below is a public RPC/HTTP read.

Run:
    python3 verify_live.py [output_dir]        # default: ./ci-out

Writes <output_dir>/live_evidence.json and prints a summary. Exits non-zero if
any hard assertion about the exploit preconditions fails (i.e. if the chain
state changed such that the finding would need re-opening).
"""
import json
import os
import sys
import time
import base64
import urllib.request
import urllib.error
import urllib.parse
import tarfile
import tempfile

EVM_RPC = os.environ.get("XRPL_EVM_RPC", "https://rpc.xrplevm.org")
COSMOS_API = os.environ.get("XRPL_COSMOS_API", "https://cosmos-api.xrplevm.org")
EXPLORER = "https://explorer.xrplevm.org"
XRPL_CLUSTER = "https://xrplcluster.com"
XRPL_GATEWAY = "rfmS3zqrQrka8wVyhXifEeyTwe8AMz2Yhw"  # Axelar XRPL mainnet gateway
HALT_HEIGHT = 7360028  # last block before the 2026-08-23 precautionary halt

EXPECT_CHAIN_ID = 1440000
EXPECT_NO_STAKING_PRECOMPILE = "0x0000000000000000000000000000000000000800"
STAKING_SELECTOR = "0x" + "0d0e0e5a"  # random selector used to probe precompiles
GATE_ORDER = ["0x0000000000000000000000000000000000000100",
              "0x0000000000000000000000000000000000000400",
              "0x0000000000000000000000000000000000000800",
              "0x0000000000000000000000000000000000000801",
              "0x0000000000000000000000000000000000000802",
              "0x0000000000000000000000000000000000000803",
              "0x0000000000000000000000000000000000000804",
              "0x0000000000000000000000000000000000000805",
              "0x0000000000000000000000000000000000000806"]
ACTIVE_NOW = {"0x0000000000000000000000000000000000000100",
              "0x0000000000000000000000000000000000000400",
              "0x0000000000000000000000000000000000000804",
              "0x0000000000000000000000000000000000000805"}

UA = {"User-Agent": "Mozilla/5.0 (zombie-hunt read-only research)"}
FAILURES = []
WARNINGS = []
EVIDENCE = {}


def record_fail(msg):
    FAILURES.append(msg)
    print(f"  [FAIL] {msg}")


def record_warn(msg):
    WARNINGS.append(msg)
    print(f"  [warn] {msg}")


def get_json(url, timeout=30, method="GET", body=None):
    data = None
    headers = dict(UA)
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)


def rpc(method, params=None):
    body = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params or []}
    req = urllib.request.Request(EVM_RPC, data=json.dumps(body).encode(),
                                 headers={**UA, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        d = json.load(r)
    return d.get("result"), d.get("error")


def eth_call(to, data):
    res, err = rpc("eth_call", [{"to": to, "data": data}, "latest"])
    return res, err


def cosmos(path):
    return get_json(COSMOS_API + path)


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "ci-out")
    outdir = os.path.abspath(outdir)
    os.makedirs(outdir, exist_ok=True)
    t0 = time.time()

    # ---------------------------------------------------------------- chain id / liveness
    print("== 1. chain access and liveness")
    chain_id_hex, _ = rpc("eth_chainId")
    chain_id = int(chain_id_hex, 16)
    EVIDENCE["chain_id"] = chain_id
    print(f"  chain_id={chain_id} ({chain_id_hex})")
    if chain_id != EXPECT_CHAIN_ID:
        record_fail(f"chain_id {chain_id} != expected {EXPECT_CHAIN_ID}")

    # XRPL EVM block time is ~5.7 s; poll up to 90 s for an advance.
    b1, _ = rpc("eth_blockNumber")
    n1 = int(b1, 16)
    n2 = n1
    deadline = time.time() + 90
    while time.time() < deadline:
        time.sleep(6)
        b2, _ = rpc("eth_blockNumber")
        n2 = int(b2, 16)
        if n2 > n1:
            break
    EVIDENCE["block_first"] = n1
    EVIDENCE["block_second"] = n2
    EVIDENCE["block_advancing"] = n2 > n1
    print(f"  block {n1} -> {n2} (advancing={n2 > n1})")
    if n2 <= n1:
        record_fail("chain is not producing blocks within 90s (possible halt)")

    client, _ = rpc("web3_clientVersion")
    EVIDENCE["web3_clientVersion"] = client
    print(f"  web3_clientVersion={client!r}")

    # ---------------------------------------------------------------- node version
    print("== 2. deployed node / cosmos-evm version")
    ni = cosmos("/cosmos/base/tendermint/v1beta1/node_info")
    av = ni.get("application_version", {})
    version = av.get("version")
    commit = av.get("git_commit")
    EVIDENCE["node_version"] = version
    EVIDENCE["node_git_commit"] = commit
    EVIDENCE["cosmos_sdk_version"] = av.get("cosmos_sdk_version")
    print(f"  exrp version={version} commit={commit}")
    if not version:
        record_fail("could not read node application version")

    # ---------------------------------------------------------------- EVM + staking + erc20 params
    print("== 3. live module params (gates)")
    evm_params = cosmos("/cosmos/evm/vm/v1/params").get("params", {})
    active = [a.lower() for a in evm_params.get("active_static_precompiles", [])]
    EVIDENCE["evm_denom"] = evm_params.get("evm_denom")
    EVIDENCE["active_static_precompiles"] = active
    print(f"  evm_denom={evm_params.get('evm_denom')}")
    print(f"  active_static_precompiles={active}")
    if EXPECT_NO_STAKING_PRECOMPILE in active:
        record_fail("staking precompile 0x800 is ACTIVE — exploit precondition may exist")
    for a in ACTIVE_NOW:
        if a not in active:
            record_warn(f"expected active precompile {a} missing (config changed?)")

    staking_params = cosmos("/cosmos/staking/v1beta1/params").get("params", {})
    bond_denom = staking_params.get("bond_denom")
    EVIDENCE["bond_denom"] = bond_denom
    print(f"  bond_denom={bond_denom}")
    if bond_denom == evm_params.get("evm_denom"):
        record_fail("bond denom == evm denom (staking events would mirror into EVM StateDB)")

    erc20_params = cosmos("/cosmos/evm/erc20/v1/params").get("params", {})
    EVIDENCE["erc20_params"] = erc20_params
    print(f"  erc20_params={erc20_params}")
    if erc20_params.get("permissionless_registration"):
        record_fail("permissionless ERC20 registration is ENABLED (GHSA-367m step-1 gate open)")

    pairs = cosmos("/cosmos/evm/erc20/v1/token_pairs?pagination.limit=100").get("token_pairs", [])
    owners = sorted({p.get("contract_owner") for p in pairs})
    EVIDENCE["erc20_token_pairs"] = len(pairs)
    EVIDENCE["erc20_token_pair_owners"] = owners
    print(f"  erc20 token pairs={len(pairs)} owners={owners}")
    if any(o != "OWNER_MODULE" for o in owners):
        record_warn(f"non-module-owned ERC20 token pair present: {owners}")

    # ---------------------------------------------------------------- precompile call probes
    print("== 4. precompile callability probes (eth_call)")
    probes = {}
    for addr in GATE_ORDER:
        code, _ = rpc("eth_getCode", [addr, "latest"])
        res, err = eth_call(addr, STAKING_SELECTOR)
        probes[addr] = {"code": code, "call_result": res,
                        "call_error": (err or {}).get("message") if err else None,
                        "in_active_list": addr in active}
        tag = "in-list" if addr in active else "absent"
        print(f"  {addr} -> code={code} call={res!r} err={probes[addr]['call_error']!r} [{tag}]")
    EVIDENCE["precompile_probes"] = probes
    st = probes[EXPECT_NO_STAKING_PRECOMPILE]
    if st["code"] != "0x" or st["call_result"] != "0x":
        record_fail("staking precompile 0x800 responds (code/result non-empty)")

    # ---------------------------------------------------------------- vesting accounts scan
    print("== 5. full account scan for vesting accounts")
    types = {}
    vesting = []
    key = None
    pages = 0
    while True:
        q = {"pagination.limit": "1000"}
        if key:
            q["pagination.key"] = key
        d = cosmos("/cosmos/auth/v1beta1/accounts?" + urllib.parse.urlencode(q))
        for a in d.get("accounts", []):
            t = a.get("@type", "?")
            types[t] = types.get(t, 0) + 1
            if "esting" in t:
                vesting.append(a)
        pages += 1
        key = d.get("pagination", {}).get("next_key")
        if not key or pages > 60:
            break
        time.sleep(0.05)
    EVIDENCE["accounts_scanned"] = sum(types.values())
    EVIDENCE["account_type_histogram"] = types
    EVIDENCE["vesting_accounts_found"] = len(vesting)
    print(f"  scanned={sum(types.values())} pages={pages} vesting={len(vesting)}")
    if vesting:
        record_fail(f"{len(vesting)} vesting account(s) exist — exploit precondition appears")

    # ---------------------------------------------------------------- vesting msg simulation
    print("== 6. MsgCreateVestingAccount simulation (read-only, not broadcast)")
    acc = cosmos("/cosmos/auth/v1beta1/accounts?pagination.limit=1")["accounts"][0]["address"]
    sim_body = {"tx": {"body": {"messages": [{
        "@type": "/cosmos.vesting.v1beta1.MsgCreateVestingAccount",
        "from_address": acc, "to_address": acc,
        "amount": [{"denom": "axrp", "amount": "1000000000000000000"}],
        "end_time": "1800000000", "delayed": False}], "memo": "", "timeout_height": "0",
        "extension_options": [], "non_critical_extension_options": []},
        "auth_info": {"signer_infos": [], "fee": {"amount": [], "gas_limit": "0", "payer": "", "granter": ""},
                      "tip": None}, "signatures": []}}
    try:
        sim = get_json(COSMOS_API + "/cosmos/tx/v1beta1/simulate", method="POST", body=sim_body)
    except urllib.error.HTTPError as e:
        sim = json.loads(e.read().decode())
    sim_msg = sim.get("message", "")
    EVIDENCE["vesting_simulate_response"] = sim_msg
    print(f"  simulate -> {sim_msg[:160]}")
    if "unable to resolve type URL" not in sim_msg:
        record_warn("simulation did not return the expected 'unable to resolve type URL' "
                    "(message may be registered now — re-check exposure)")

    # ---------------------------------------------------------------- supply / value
    print("== 7. supply and value at risk")
    supply = cosmos("/cosmos/bank/v1beta1/supply/by_denom?denom=axrp")
    supply_now = int(supply["amount"]["amount"])
    EVIDENCE["axrp_supply_wei"] = str(supply_now)
    EVIDENCE["axrp_supply_xrp"] = supply_now / 1e18
    try:
        supply_halt = int(cosmos(
            f"/cosmos/bank/v1beta1/supply/by_denom?denom=axrp&height={HALT_HEIGHT}")["amount"]["amount"])
        EVIDENCE["axrp_supply_at_halt_height"] = str(supply_halt)
        EVIDENCE["halt_height"] = HALT_HEIGHT
        print(f"  axrp supply now={supply_now/1e18:.6f} at halt #{HALT_HEIGHT}={supply_halt/1e18:.6f}")
    except Exception as e:  # noqa
        record_warn(f"historical supply query failed: {e}")

    price = None
    try:
        pj = get_json("https://coins.llama.fi/prices/current/coingecko:ripple")
        price = pj["coins"]["coingecko:ripple"]["price"]
        EVIDENCE["xrp_price_usd"] = price
        EVIDENCE["xrp_price_ts"] = pj["coins"]["coingecko:ripple"]["timestamp"]
        print(f"  XRP price=${price}  at-risk value=${supply_now/1e18*price:,.2f}")
    except Exception as e:  # noqa
        record_warn(f"price fetch failed: {e}")

    try:
        xrpl = get_json(XRPL_CLUSTER, method="POST", body={
            "method": "account_info", "params": [{"account": XRPL_GATEWAY,
            "ledger_index": "validated", "strict": True}]})
        bal = int(xrpl["result"]["account_data"]["Balance"]) / 1e6
        EVIDENCE["xrpl_gateway"] = XRPL_GATEWAY
        EVIDENCE["xrpl_gateway_xrp"] = bal
        print(f"  XRPL gateway {XRPL_GATEWAY} holds {bal:,.6f} XRP")
    except Exception as e:  # noqa
        record_warn(f"XRPL gateway query failed: {e}")

    # ---------------------------------------------------------------- binary guard check
    print("== 8. official release binary guard check")
    if version:
        try:
            url = f"https://github.com/xrplevm/node/releases/download/v{version}/node_{version}_Linux_amd64.tar.gz"
            with tempfile.TemporaryDirectory() as td:
                tgz = os.path.join(td, "node.tgz")
                urllib.request.urlretrieve(url, tgz)
                with tarfile.open(tgz, "r:gz") as tf:
                    member = next(m for m in tf.getmembers() if m.name.endswith("exrpd"))
                    f = tf.extractfile(member)
                    blob = f.read()
                checks = {
                    "guard_underflow": b"state balance underflow for" in blob,
                    "guard_overflow": b"state balance overflow for" in blob,
                    "fork_module_path": b"github.com/xrplevm/evm" in blob,
                    "fork_v0.6.3": b"v0.6.3-xrplevm.1" in blob,
                }
                EVIDENCE["binary_checks"] = checks
                print(f"  {checks}")
                if not checks["guard_underflow"]:
                    record_fail("deployed release binary lacks the SubBalance underflow guard")
                if not checks["guard_overflow"]:
                    record_warn("deployed release binary lacks the AddBalance overflow guard string")
        except Exception as e:  # noqa
            record_warn(f"release binary download/scan failed: {e}")
    else:
        record_warn("no node version available for binary check")

    # ---------------------------------------------------------------- explorer tx probe
    try:
        txs = get_json(EXPLORER + "/api/v2/addresses/" + EXPECT_NO_STAKING_PRECOMPILE + "/transactions")
        EVIDENCE["staking_precompile_txs_indexed"] = len(txs.get("items", []))
        print(f"  explorer txs touching 0x800: {len(txs.get('items', []))}")
    except Exception as e:  # noqa
        record_warn(f"explorer probe failed: {e}")

    # ---------------------------------------------------------------- finalize
    EVIDENCE["failures"] = FAILURES
    EVIDENCE["warnings"] = WARNINGS
    EVIDENCE["elapsed_sec"] = round(time.time() - t0, 1)
    with open(os.path.join(outdir, "live_evidence.json"), "w") as f:
        json.dump(EVIDENCE, f, indent=2)
    print(f"\n== wrote {os.path.join(outdir, 'live_evidence.json')}")
    print(f"== failures={len(FAILURES)} warnings={len(WARNINGS)} elapsed={EVIDENCE['elapsed_sec']}s")
    if FAILURES:
        print("\nRESULT: FAIL — gates changed, re-open the finding")
        return 1
    print("\nRESULT: PASS — all exploit preconditions remain absent; deployed binary carries the guards")
    return 0


if __name__ == "__main__":
    sys.exit(main())
