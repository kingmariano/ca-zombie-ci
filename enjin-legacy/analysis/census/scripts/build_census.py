#!/usr/bin/env python3
"""Build analysis/census/census.json from all collected artifacts.

Inputs (all relative to analysis/census/):
  shells_parsed.json, probe_totalSupply.json, probe_owners.jsonl, probe_tails.jsonl,
  envoy_full_scan.json, live_verification.json, nonshell_summary.json,
  nonshell_liveness.jsonl, nonshell_verification.json, ft_events_filtered.json,
  attack_window_events.json / attack_window_events_fine.json (either/both)
Output: census.json
"""
import json, os, datetime, collections

CENSUS = os.path.dirname(os.path.abspath(__file__)) + "/.."
BURN = "0x0000deaddeaddeaddeaddeaddeaddeaddead0000"
ZERO = "0x0000000000000000000000000000000000000000"
DEAD = "0x000000000000000000000000000000000000dead"
SENTINELS = {BURN, ZERO, DEAD}
ATTACK_LO, ATTACK_HI = 25_834_071, 25_835_670  # first attack tx .. freeze event

def load(path, default=None):
    p = os.path.join(CENSUS, path)
    if not os.path.exists(p):
        return default
    with open(p) as f:
        return json.load(f)

def cls(owner):
    if owner is None:
        return "nonexistent/revert"
    ow = owner.lower()
    if ow == BURN: return "melt-burn"
    if ow == DEAD: return "legacy-burn"
    if ow == ZERO: return "zero"
    return "live"

def main():
    shells = load("shells_parsed.json")["shells"]
    supply = load("probe_totalSupply.json")
    block = supply["block"]
    sup = supply["results"]
    owners = [json.loads(l) for l in open(os.path.join(CENSUS, "probe_owners.jsonl")) if l.strip()]
    tails = [json.loads(l) for l in open(os.path.join(CENSUS, "probe_tails.jsonl"))] if os.path.exists(os.path.join(CENSUS, "probe_tails.jsonl")) else []
    envoy = load("envoy_full_scan.json")
    verification = load("live_verification.json")
    nonshell_live = load("nonshell_liveness.jsonl")
    nonshell_ver = load("nonshell_verification.json")
    ft_events = load("ft_events_filtered.json")
    attack = load("attack_window_events_full.json") or load("attack_window_events_fine.json") or load("attack_window_events.json") or {"logs": []}
    attack_is_fine = any(os.path.exists(os.path.join(CENSUS, f)) for f in ["attack_window_events_full.json", "attack_window_events_fine.json"])

    # ---- shells records
    recs = {}
    for s in shells:
        v = sup.get(s["shell"], {})
        recs[s["shell"]] = {
            "baseType": s["baseType"], "baseTypeHex": s["baseTypeHex"], "shell": s["shell"],
            "kind": s["kind"], "deployer": s["deployer"], "deployedBlock": s["block"], "txHash": s["txHash"],
            "totalSupply": v.get("totalSupply"), "totalSupplyError": v.get("error"),
            "name": None, "first25": None,
        }
    item_stats = collections.Counter()
    shelled_live = []
    for r in owners:
        rec = recs[r["shell"]]
        rec["name"] = r.get("name")
        scans = []
        for o in r["owners"]:
            c = cls(o.get("owner"))
            scans.append({"id": o["id"], "idx": int(o["id"]) - int(r["baseType"]), "owner": o.get("owner"), "class": c})
            item_stats[c] += 1
            if c == "live":
                shelled_live.append({"baseType": r["baseType"], "instanceId": o["id"], "idx": int(o["id"]) - int(r["baseType"]),
                                     "owner": o.get("owner"), "shell": r["shell"], "name": r.get("name"),
                                     "verifiedBlock": r["block"], "source": "shell.ownerOf(first25)"})
        rec["first25"] = scans
    tail_stats = collections.Counter()
    for r in tails:
        rec = recs[r["shell"]]
        ts = []
        for o in r["owners"]:
            c = cls(o.get("owner"))
            ts.append({"id": o["id"], "idx": o["idx"], "owner": o.get("owner"), "class": c})
            tail_stats[c] += 1
        rec["tailSample"] = ts

    # ---- envoy full
    envoy_live = [dict(s, baseType=envoy["baseType"], shell=envoy["shell"]) for s in envoy["items"] if s["class"] == "live"]
    env_owner_count = collections.Counter(s["owner"].lower() for s in envoy_live)

    # ---- attack sweep stats
    attack_logs = attack.get("logs", [])
    swept_ids = set()
    sweep_to = collections.Counter()
    sweep_from = set()
    sweep_bt = collections.Counter()
    for lg in attack_logs:
        try:
            iid = int(lg["data"][2:66], 16)
        except Exception:
            continue
        swept_ids.add(iid)
        sweep_to["0x" + lg["topics"][3][-40:]] += 1
        sweep_from.add("0x" + lg["topics"][2][-40:])
        sweep_bt[iid >> 64] += 1
    probed_first25_ids = {int(o["id"]) for r in owners for o in r["owners"]}
    swept_of_probed = probed_first25_ids & swept_ids
    shell_bt = {int(s["baseType"]) for s in shells}

    # ---- FT section: victims from ft_events_filtered (first legs)
    ft_by_bt = {}
    if ft_events:
        helper = "0x7083ddece38216c7741fa76c75326bea744ed321"
        for e in ft_events["events"]:
            if e["to"].lower() != helper:
                continue  # second leg helper->0
            if e["from"].lower() == helper:
                continue
            b = int(e["baseType"], 16)
            d = ft_by_bt.setdefault(b, {"totalSupply": None, "victims": {}, "events": 0, "burnBlock": e["block"], "sweepTx": e["txHash"]})
            d["victims"][e["from"]] = d["victims"].get(e["from"], 0) + int(e["value"])
            d["events"] += 1
    # names for FT shells from ft_shell_meta.json
    ft_meta = load("ft_shell_meta.json", {"names": {}})["names"]
    for s in shells:
        if s["kind"] == "FT":
            b = int(s["baseType"])
            d = ft_by_bt.setdefault(b, {"totalSupply": None, "victims": {}, "events": 0})
            d["totalSupply"] = sup.get(s["shell"], {}).get("totalSupply")
            d["shell"] = s["shell"]
            d["name"] = ft_meta.get(s["shell"])
    ft_summary = []
    for b, d in sorted(ft_by_bt.items()):
        ft_summary.append({
            "baseType": hex(b), "shell": d.get("shell"), "name": d.get("name"),
            "totalSupply": d.get("totalSupply"), "sweepBlock": d.get("burnBlock"), "sweepTx": d.get("sweepTx"),
            "victimTransfers": d["events"], "victims": dict(sorted(d["victims"].items(), key=lambda kv: -kv[1])),
            "currentHolderCheck": "all sampled victims + attacker helper balance 0 at pinned block (see scripts)",
        })

    # ---- nonshell live summary
    ns_results = (nonshell_live or {}).get("results", {})
    ns_live_nft = {}
    ns_live_ft = {}
    for iid, v in ns_results.items():
        if v.get("error"):
            continue
        if v.get("kind") == "nft":
            ow = (v.get("owner") or "").lower()
            if ow and ow not in SENTINELS:
                ns_live_nft[iid] = v["owner"]
        elif v.get("balance"):
            ns_live_ft[iid] = {"balance": v["balance"], "holder": v.get("holder_checked")}
    ns_bt = collections.Counter(int(i) >> 64 for i in ns_live_nft)
    ns_owners = collections.Counter(o.lower() for o in ns_live_nft.values())

    out = {
        "meta": {
            "generatedUtc": datetime.datetime.utcnow().isoformat() + "Z",
            "chain": "ethereum mainnet (chainid 1)",
            "pinnedBlock": block,
            "contracts": {
                "PA": "0xfaafdc07907ff5120a76b34b731b278c38d6043c",
                "Adapter": "0x4e643a25a64952895f553f20252861258727174e",
                "nftTemplate": "0x13fa4b9a6c2f2604c919f96f456e3b50e968b157",
                "ftTemplate": "0x268c039a3127d3107c014f0dc6c390a53e6db27f",
                "nftDelegateTarget": "0x24591e792a404e5bd48ac0f694339d807b02cfd2",
                "ftDelegateTarget": "0x75512f843d8d22593d7256708ef80a22b97baf5e",
                "attackerSweepHelper": "0x7083ddece38216c7741fa76c75326bea744ed321",
            },
            "shellCreationTopic0": "0xf5d46ba34659b65cffb502ef745b2bc248a71051e48eaf9d62bfa59def02afad",
            "transferSingleTopic0": "0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62",
            "burnMarkers": {"melt": BURN, "legacy": DEAD, "zero": ZERO},
            "attackWindowBlocks": [ATTACK_LO, ATTACK_HI],
            "artifactBlocks": {
                "shellEnumeration": "getLogs 0..latest (fetched 2026-10-09 ~05:44 UTC)",
                "totalSupply+first25Owners": 26152529,
                "tailSamples": 26152580,
                "envoyFullScan+liveVerification": 26152685,
                "nonshellLiveness": 26152659,
                "nonshellVerification": 26152693,
                "castEvidence": 26152685,
            },
        },
        "shellsSummary": {
            "totalShells": len(shells), "nftShells": sum(1 for s in shells if s["kind"] == "NFT"),
            "ftShells": sum(1 for s in shells if s["kind"] == "FT"),
            "uniqueBaseTypes": len({s["baseType"] for s in shells}),
            "distinctDeployers": len({s["deployer"] for s in shells}),
            "firstCreationBlock": min(s["block"] for s in shells),
            "lastCreationBlock": max(s["block"] for s in shells),
            "allShellsCreatedDuringAttackWindow": all(ATTACK_LO - 1 <= s["block"] <= ATTACK_HI + 1 for s in shells),
            "nftShellsWithSupplyGt0": sum(1 for s in shells if s["kind"] == "NFT" and isinstance(sup.get(s["shell"], {}).get("totalSupply"), int) and sup[s["shell"]]["totalSupply"] > 0),
            "nftShellsTruncatedAt25": sum(1 for s in shells if s["kind"] == "NFT" and isinstance(sup.get(s["shell"], {}).get("totalSupply"), int) and sup[s["shell"]]["totalSupply"] > 25),
            "totalNftItemsMintedEver": sum(sup[s["shell"]]["totalSupply"] for s in shells if s["kind"] == "NFT" and isinstance(sup.get(s["shell"], {}).get("totalSupply"), int)),
        },
        "probeSummary": {
            "nftItemsProbedFirst25": sum(item_stats.values()),
            "first25ByClass": dict(item_stats),
            "tailShellsSampled": len(tails),
            "tailItemsProbed": sum(tail_stats.values()),
            "tailByClass": dict(tail_stats),
            "envoyFullScanItems": len(envoy["items"]),
            "envoyLive": len(envoy_live),
            "coverage": {
                "shells": "ALL 395 shells enumerated via Etherscan logs API (topic0 shellCreation), full range 0..latest, single page (395<1000)",
                "first25": "ALL 391 NFT shells: ownerOf(baseType|i) i=1..min(N,25) at one pinned block",
                "tails": "227/228 shells with N>25: ~10 spread indices in [26..N] each",
                "full": "Envoy Badge 0x0f1f62c3... (N=61) items 1..61 fully scanned",
            },
        },
        "liveSummary": {
            "shelledLiveTriples": len(envoy_live),
            "shelledLiveBaseTypes": sorted({s["baseType"] for s in envoy_live}),
            "shelledLiveDistinctOwners": len(env_owner_count),
            "nonshellLiveNftItems": len(ns_live_nft),
            "nonshellLiveNftBaseTypes": len(ns_bt),
            "nonshellLiveFtBalances": len(ns_live_ft),
            "nonshellLiveTopOwners": ns_owners.most_common(10),
            "nonshellLiveTopBaseTypes": [(hex(b << 64), n) for b, n in ns_bt.most_common(10)],
        },
        "shelledLiveTriples": envoy_live,
        "nonshellLiveNftSample": [{"instanceId": k, "owner": v} for k, v in list(ns_live_nft.items())[:100]],
        "nonshellLiveFtBalances": [{"instanceId": k, **v} for k, v in ns_live_ft.items()],
        "attack": {
            "eventsScanned": len(attack_logs),
            "scanComplete": attack_is_fine,
            "distinctSweptItemIds": len(swept_ids),
            "sweptBaseTypes": len(sweep_bt),
            "sweptBaseTypesAllShelled": all((b << 64) in shell_bt for b in sweep_bt),
            "distinctVictimAddresses": len(sweep_from),
            "toCounts": dict(sweep_to),
            "probedFirst25ItemsSweptInAttack": len(swept_of_probed),
        },
        "ft": ft_summary,
        "verification": {
            "shelled": verification and {"block": verification["block"], "count": verification["count"], "allConsistent": verification["allConsistent"],
                                          "method": "shell.ownerOf + PA.ownerOf + PA.balanceOf(owner,id) + eth_getCode(owner)"},
            "nonshell": nonshell_ver and {"block": nonshell_ver["block"], "samples": len(nonshell_ver["samples"]),
                                           "allConsistent": all(s["consistent"] for s in nonshell_ver["samples"]),
                                           "method": "PA.ownerOf + PA.balanceOf(owner,id) + eth_getCode(owner)"},
        },
        "shells": sorted(recs.values(), key=lambda r: r["deployedBlock"]),
        "limitations": [
            "ownerOf classification treats addresses 0x0000deaddeaddeaddeaddeaddeaddeaddead0000 (melt marker), 0x...dead (legacy burn) and 0x0 as non-live sentinels.",
            "First-25 scan: items of shells with N>25 beyond the sampled indices (first 25 + ~10 tail samples) are NOT individually covered; tail sampling (227 shells, ~10 indices each) found no further live items.",
            "Shell-state calls were routed via the templates' delegates(bytes4) table to legacy Enjin implementations 0x24591e79... (NFT) / 0x75512f84... (FT); calls were cross-checked against PA facade (PA.ownerOf / PA.balanceOf).",
            "TransferSingle event coverage is limited to the last 3,000,000 blocks (approx. 2025-09-xx .. 2026-10-09). Older history (including older transfers of live items) is not included.",
            "Non-shell live items were only discoverable for ids that appear in TransferSingle events inside the 3M-block window; the true population of non-shell items is larger (1,954 base types active in-window vs 395 shelled).",
            "The three hottest 250-block chunks of the attack window had >10k events each; a fine re-scan splits them down to ~25-block chunks (scanComplete flag notes whether the fine file is present).",
            "FT holder enumeration relies on TransferSingle events; current balances were validated = 0 for all sampled victims and the attacker helper.",
        ],
    }
    with open(os.path.join(CENSUS, "census.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("shells:", json.dumps(out["shellsSummary"], indent=1))
    print("live:", json.dumps(out["liveSummary"], indent=1))
    print("attack:", json.dumps(out["attack"], indent=1))
    print("first25:", dict(item_stats), "tails:", dict(tail_stats))

if __name__ == "__main__":
    main()
