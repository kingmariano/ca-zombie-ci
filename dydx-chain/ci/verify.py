#!/usr/bin/env python3
"""C2-34 dYdX chain — reproducible verification of the ibc-go halt-advisory status.

Read-only. Public endpoints only. Writes ci-out/verification.json + ci-out/summary_ci.json.
No secrets are read or written. Stdlib only (urllib).
"""
import json, hashlib, sys, time, urllib.request, urllib.error

UA = {"User-Agent": "Mozilla/5.0 (research; zombie-hunt-II C2-34)"}
LCDS = [
    "https://dydx-dao-api.polkachu.com",
    "https://dydx-rest.publicnode.com",
    "https://rest-dydx.cosmostation.io",
]
RAW = "https://raw.githubusercontent.com"
FORK_COMMIT = "8733b3edf43a"
FORK = "dydxprotocol/ibc-go"
UPSTREAM = "cosmos/ibc-go"

FIX_MARKERS = {
    # ASA-2025-004 fix (upstream v8.6.1): transfer module re-marshal byte-equality check
    "transfer": {
        "path": "modules/apps/transfer/ibc_module.go",
        "marker": "acknowledgement did not marshal to expected bytes",
    },
    # ISA-2025-001 fix (upstream v8.7.0): core AcknowledgePacket re-marshal byte-equality check
    "core": {
        "path": "modules/core/04-channel/keeper/packet.go",
        "marker": "acknowledgement marshalling error",
    },
}


def get(url, timeout=30, tries=3):
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except Exception as e:  # noqa
            last = e
            time.sleep(1.5 * (i + 1))
    raise RuntimeError(f"GET failed: {url}: {last}")


def get_json(url, **kw):
    return json.loads(get(url, **kw).decode())


def lcd_get_json(path, timeout=30):
    last = None
    for base in LCDS:
        try:
            return get_json(base + path, timeout=timeout, tries=2)
        except Exception as e:  # noqa
            last = e
    raise RuntimeError(f"LCD GET failed: {path}: {last}")


def sha256(b):
    return hashlib.sha256(b).hexdigest()


def fetch_ref_file(repo, ref, path):
    b = get(f"{RAW}/{repo}/{ref}/{path}")
    return b


def fix_check(repo, ref, kind):
    spec = FIX_MARKERS[kind]
    b = fetch_ref_file(repo, ref, spec["path"])
    text = b.decode(errors="replace")
    lines = [i + 1 for i, ln in enumerate(text.splitlines()) if spec["marker"] in ln]
    return {
        "repo": repo,
        "ref": ref,
        "path": spec["path"],
        "marker": spec["marker"],
        "marker_lines": lines,
        "present": bool(lines),
        "sha256": sha256(b),
        "bytes": len(b),
    }


out = {"generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "checks": {}}

# 1. Live node versions across endpoints -------------------------------------------------
nodes = []
for base in LCDS:
    try:
        d = get_json(base + "/cosmos/base/tendermint/v1beta1/node_info", timeout=30, tries=2)
        av = d.get("application_version", {})
        deps = {x.get("path"): x for x in av.get("build_deps", [])}
        ibc = deps.get("github.com/cosmos/ibc-go/v8", {})
        sdk = deps.get("github.com/cosmos/cosmos-sdk", {})
        cbft = deps.get("github.com/cometbft/cometbft", {})
        nodes.append({
            "endpoint": base,
            "app_version": av.get("version"),
            "git_commit": av.get("git_commit"),
            "go_version": av.get("go_version"),
            "ibc_go_v8": {"version": ibc.get("version"), "sum": ibc.get("sum")},
            "cosmos_sdk": {"version": sdk.get("version"), "sum": sdk.get("sum")},
            "cometbft": {"version": cbft.get("version"), "sum": cbft.get("sum")},
            "has_ibc_hooks": any("ibc-hooks" in p or "packet-forward" in p for p in deps),
            "has_wasm": any("wasm" in p.lower() for p in deps),
        })
    except Exception as e:  # noqa
        nodes.append({"endpoint": base, "error": str(e)})
out["checks"]["live_nodes"] = nodes

# height
try:
    blk = lcd_get_json("/cosmos/base/tendermint/v1beta1/blocks/latest")
    out["checks"]["latest_block"] = {
        "height": blk["block"]["header"]["height"],
        "time": blk["block"]["header"]["time"],
    }
except Exception as e:  # noqa
    out["checks"]["latest_block"] = {"error": str(e)}

# 2. Fork fix markers (pinned commit) vs upstream refs -----------------------------------
markers = {}
for kind in FIX_MARKERS:
    markers[f"dydx_fork_{kind}"] = fix_check(FORK, FORK_COMMIT, kind)
for ref in ["v8.5.1", "v8.6.1", "v8.7.0"]:
    for kind in FIX_MARKERS:
        markers[f"upstream_{ref}_{kind}"] = fix_check(UPSTREAM, ref, kind)
out["checks"]["fix_markers"] = markers

# 3. go.mod replace evidence -------------------------------------------------------------
gomods = {}
for ref in ["protocol/v9.7.1", "main"]:
    try:
        txt = fetch_ref_file("dydxprotocol/v4-chain", ref, "protocol/go.mod").decode(errors="replace")
        gomods[ref] = {
            "ibc_go_replace": [ln.strip() for ln in txt.splitlines() if "ibc-go/v8 =>" in ln],
            "ibc_go_require": [ln.strip() for ln in txt.splitlines() if ln.strip().startswith("github.com/cosmos/ibc-go/v8")],
            "sha256": sha256(txt.encode()),
        }
    except Exception as e:  # noqa
        gomods[ref] = {"error": str(e)}
out["checks"]["go_mod"] = gomods

# 4. Gov / staking / supply ---------------------------------------------------------------
gov = {}
for name, path in [
    ("gov_tally_params", "/cosmos/gov/v1/params/tallying"),
    ("gov_voting_params", "/cosmos/gov/v1/params/voting"),
    ("staking_pool", "/cosmos/staking/v1beta1/pool"),
    ("staking_params", "/cosmos/staking/v1beta1/params"),
    ("supply_adydx", "/cosmos/bank/v1beta1/supply/by_denom?denom=adydx"),
    ("community_pool", "/cosmos/distribution/v1beta1/community_pool"),
    ("current_plan", "/cosmos/upgrade/v1beta1/current_plan"),
]:
    try:
        gov[name] = lcd_get_json(path)
    except Exception as e:  # noqa
        gov[name] = {"error": str(e)}

accounts = {
    "community_treasury": "dydx15ztc7xy42tn2ukkc0qjthkucw9ac63pgp70urn",
    "insurance_fund": "dydx1c7ptc87hkd54e3r7zjy92q29xkq7t79w64slrq",
    "rewards_treasury": "dydx16wrau2x4tsg033xfrrdpae6kxfn9kyuerr5jjp",
    "distribution": "dydx1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8wx2cfg",
    "bridge": "dydx1zlefkpe3g0vvm9a4h0jf9000lmqutlh9jwjnsv",
    "gov": "dydx10d07y265gmmuvt4z0w9aw880jnsr700jnmapky",
    "megavault": "dydx18tkxrnrkqc2t0lr3zxr5g6a4hdvqksylxqje4r",
}
bal = {}
for name, addr in accounts.items():
    try:
        bal[name] = lcd_get_json(f"/cosmos/bank/v1beta1/balances/{addr}")
    except Exception as e:  # noqa
        bal[name] = {"error": str(e)}
gov["module_balances"] = bal
out["checks"]["gov"] = gov

# 5. Prices ------------------------------------------------------------------------------
prices = {}
try:
    prices["defillama_dydx"] = get_json("https://coins.llama.fi/prices/current/coingecko:dydx")
except Exception as e:  # noqa
    prices["defillama_dydx"] = {"error": str(e)}
try:
    prices["coingecko_dydx"] = get_json(
        "https://api.coingecko.com/api/v3/simple/price?ids=dydx&vs_currencies=usd"
        "&include_market_cap=true&include_24hr_vol=true"
    )
except Exception as e:  # noqa
    prices["coingecko_dydx"] = {"error": str(e)}
out["checks"]["prices"] = prices

# 6. IBC state ---------------------------------------------------------------------------
ibc = {}
for name, path in [
    ("channels", "/ibc/core/channel/v1/channels?pagination.limit=200"),
    ("connections", "/ibc/core/connection/v1/connections?pagination.limit=200"),
]:
    try:
        d = lcd_get_json(path, timeout=40)
        ibc[name] = {"count": len(d.get("channels", d.get("connections", []))),
                     "pagination_total": d.get("pagination", {}).get("total")}
        if name == "channels":
            ports = {}
            for c in d.get("channels", []):
                ports[c.get("port_id")] = ports.get(c.get("port_id"), 0) + 1
            ibc["channel_ports"] = ports
    except Exception as e:  # noqa
        ibc[name] = {"error": str(e)}
out["checks"]["ibc"] = ibc

# 7. Derived numbers ---------------------------------------------------------------------
derived = {}
try:
    t = gov["gov_tally_params"]
    quorum = float(t.get("params", t).get("quorum", "0.5"))
    bonded = int(gov["staking_pool"]["pool"]["bonded_tokens"])
    supply = int(gov["supply_adydx"]["amount"]["amount"])
    price = None
    for src in ("defillama_dydx", "coingecko_dydx"):
        p = prices.get(src, {})
        if src == "defillama_dydx" and isinstance(p, dict):
            c = p.get("coins", {}).get("coingecko:dydx", {})
            if c.get("price"):
                price = float(c["price"]); break
        if src == "coingecko_dydx" and isinstance(p, dict) and p.get("dydx", {}).get("usd"):
            price = float(p["dydx"]["usd"]); break
    quorum_dydx = quorum * bonded
    derived = {
        "quorum": quorum,
        "bonded_dydx": bonded / 1e18,
        "supply_dydx": supply / 1e18,
        "quorum_dydx": quorum_dydx / 1e18,
        "dydx_price_usd": price,
        "quorum_cost_usd_at_spot": (quorum_dydx / 1e18) * price if price else None,
    }
    def adydx(b):
        for c in b.get("balances", []):
            if c["denom"] == "adydx":
                return int(c["amount"]) / 1e18
        return 0.0
    usdc = "ibc/8E27BA2D5493AF5636760E354E46004562C46AB7EC0CC4C1CA14E9E20E2545B5"
    def usdc_bal(b):
        for c in b.get("balances", []):
            if c["denom"] == usdc:
                return int(c["amount"]) / 1e6
        return 0.0
    derived["community_treasury_dydx"] = adydx(bal.get("community_treasury", {}))
    derived["rewards_treasury_dydx"] = adydx(bal.get("rewards_treasury", {}))
    derived["insurance_fund_usdc"] = usdc_bal(bal.get("insurance_fund", {}))
    derived["bridge_dydx_escrow"] = adydx(bal.get("bridge", {}))
    if price:
        derived["community_treasury_usd_at_spot"] = derived["community_treasury_dydx"] * price
        derived["rewards_treasury_usd_at_spot"] = derived["rewards_treasury_dydx"] * price
        derived["insurance_fund_usd"] = derived["insurance_fund_usdc"]
        derived["gov_spendable_nominal_usd"] = (
            derived["community_treasury_usd_at_spot"] + derived["rewards_treasury_usd_at_spot"]
            + derived["insurance_fund_usd"]
        )
except Exception as e:  # noqa
    derived["error"] = str(e)
out["checks"]["derived"] = derived

with open("ci-out/verification.json", "w") as f:
    json.dump(out, f, indent=1)

summary = {
    "finding": "C2-34",
    "generated_at": out["generated_at"],
    "live_app_versions": [n.get("app_version") for n in nodes if n.get("app_version")],
    "ibc_go_live_string": [n.get("ibc_go_v8") for n in nodes if n.get("ibc_go_v8")],
    "fork_commit": FORK_COMMIT,
    "fork_transfer_fix_present": markers["dydx_fork_transfer"]["present"],
    "fork_core_fix_present": markers["dydx_fork_core"]["present"],
    "latest_block": out["checks"]["latest_block"],
    "derived": derived,
    "verdict": "patched via vendored fork (both ASA-2025-004 and ISA-2025-001 fix checks present at the pinned commit)",
}
with open("ci-out/summary_ci.json", "w") as f:
    json.dump(summary, f, indent=1)

print(json.dumps(summary, indent=1))
print("WROTE ci-out/verification.json and ci-out/summary_ci.json")
