#!/usr/bin/env python3
"""Rebuild compact inputs after an external cleanup deleted raw/ and some aggregates.

- Re-fetches the single shell-creation page -> raw/adapter_created_page_1.json,
  then rebuilds shells_parsed.json + adapter_created_events.json (same format as before).
- Reconstructs probe_tails.jsonl from census.json (tailSample arrays).
"""
import json, os, sys, time, urllib.request, urllib.parse

CENSUS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RAW = os.path.join(CENSUS, "raw")
PA = "0xfaafdc07907ff5120a76b34b731b278c38d6043c"
TOPIC0 = "0xf5d46ba34659b65cffb502ef745b2bc248a71051e48eaf9d62bfa59def02afad"

def fetch(params, tries=6):
    url = "https://api.etherscan.io/v2/api?" + urllib.parse.urlencode(params)
    for t in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 census/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                body = json.load(r)
            if body.get("status") == "1" or str(body.get("message", "")).startswith("No records"):
                return body
            time.sleep(0.8 + t)
        except Exception as e:
            sys.stderr.write(f"retry {t}: {e}\n")
            time.sleep(0.8 + t)
    raise RuntimeError("fetch failed")

def main():
    os.makedirs(RAW, exist_ok=True)
    # 1) shell creation page (fresh, full range)
    body = fetch({"chainid": "1", "module": "logs", "action": "getLogs", "fromBlock": "0", "toBlock": "latest",
                  "address": PA, "topic0": TOPIC0, "page": "1", "offset": "1000",
                  "apikey": os.environ["ETHERSCANV2_API_KEY"]})
    with open(os.path.join(RAW, "adapter_created_page_1.json"), "w") as f:
        json.dump(body, f)
    logs = body["result"]
    assert len(logs) < 1000, "more than one page! rerun paginated fetch"
    rows = []
    for lg in logs:
        t = lg["topics"]
        bt = int(t[1], 16)
        rows.append({
            "baseType": str(bt), "baseTypeHex": hex(bt), "shell": "0x" + lg["data"][-40:],
            "deployer": "0x" + t[2][-40:], "block": int(lg["blockNumber"], 16),
            "txHash": lg["transactionHash"], "logIndex": lg.get("logIndex"),
            "kind": "NFT" if (bt >> 247) & 1 else "FT",
        })
    rows.sort(key=lambda r: r["block"])
    json.dump({"count": len(rows), "shells": rows}, open(os.path.join(CENSUS, "shells_parsed.json"), "w"), indent=1)
    json.dump({"source": "Etherscan V2 logs API (getLogs, address=PA, topic0 shell creation, fromBlock=0, toBlock=latest, single page)",
               "count": len(rows), "decoded": rows, "rawLogs": logs},
              open(os.path.join(CENSUS, "adapter_created_events.json"), "w"), indent=1)
    print(f"shells_parsed.json + adapter_created_events.json rebuilt: {len(rows)} shells")

    # 2) probe_tails.jsonl from census.json (if census has data and tails file missing)
    tp = os.path.join(CENSUS, "probe_tails.jsonl")
    if not os.path.exists(tp):
        census = json.load(open(os.path.join(CENSUS, "census.json")))
        n = 0
        with open(tp, "w") as f:
            for rec in census["shells"]:
                ts = rec.get("tailSample")
                if not ts:
                    continue
                owners = [{"id": e["id"], "idx": e["idx"], "owner": e.get("owner")} for e in ts]
                line = {"shell": rec["shell"], "baseType": rec["baseType"], "totalSupply": rec["totalSupply"],
                        "block": 26152580, "sampled": [e["idx"] for e in ts], "owners": owners, "reconstructed": True}
                f.write(json.dumps(line) + "\n")
                n += 1
        print(f"probe_tails.jsonl reconstructed from census.json: {n} shells")
    else:
        print("probe_tails.jsonl already present")

    # 3) sanity: files present
    for fn in ["shells_parsed.json", "adapter_created_events.json", "probe_tails.jsonl", "probe_owners.jsonl",
               "probe_totalSupply.json", "envoy_full_scan.json", "live_verification.json", "nonshell_summary.json",
               "nonshell_verification.json", "ft_events_filtered.json", "ft_shell_meta.json"]:
        p = os.path.join(CENSUS, fn)
        print(("OK   " if os.path.exists(p) else "MISS "), fn)

if __name__ == "__main__":
    main()
