#!/usr/bin/env python3
"""
Vessel Finance (Scroll) — full-history vault log scan + aggregates.
Read-only; keyless public RPCs only. Writes ci-out/ artifacts.
No secrets; no transactions.
"""
import json, os, sys, time, urllib.request, collections, datetime

RPC_CANDIDATES = [
    "https://scroll-rpc.publicnode.com",
    "https://rpc.scroll.io",
    "https://scroll.drpc.org",
]
VAULT = "0x6126E927627b8d9eb9aDb9faadC47B76F94B6bA2"
DEPLOY_BLOCK = 8015163  # proxy creation block (2024-08-03)

R = {"url": None}

def rpc(method, params, retries=8):
    payload = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
    for i in range(retries):
        urls = ([R["url"]] if R["url"] else []) + [u for u in RPC_CANDIDATES if u != R["url"]]
        for url in urls:
            try:
                req = urllib.request.Request(url, data=payload, headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
                d = json.load(urllib.request.urlopen(req, timeout=45))
                if "result" in d:
                    R["url"] = url
                    return d["result"]
                err = str(d.get("error"))
                if "range" in err.lower() or "limit" in err.lower():
                    return "RANGE_TOO_LARGE"
            except Exception:
                pass
        time.sleep(1.0 + i)
    return None

def api(url):
    req = urllib.request.Request(url, headers={"User-Agent":"Mozilla/5.0"})
    return json.load(urllib.request.urlopen(req, timeout=45))

TOPICS = {
 "LogDeposit":"0x9dbb0e7dda3e09710ce75b801addc87cf9d9c6c581641b3275fca409ad086c62",
 "LogWithdraw":"0xda9a10d7b992511ddadbfc7ff712c1424ce2058bbcdac8c9876d6f8de590d43f",
 "LogNewPendingWithdrawAmount":"0x3d5561b621e43465d6af38b20b2302af33b357ca3160cb1400a9eed6a781002e",
 "LogNewPendingDepositAmount":"0x2f2ccd37e471c83db2291eb3299af0750759b269e0f8554443e293783153a26b",
 "LogProofCommitted":"0x321d78cce2319e8a11f283f534aa49cf60de36fd115b20210f087b4d403505a2",
 "LogFastWithdrawBackfill":"0xcdead1999054fa62315134142ab2da2ccfc7b6f340cbf8964493460222cebe13",
 "LogVesselKeyRegister":"0x30cbe686e3ee93ad523b320b5f68a0d5625223af5b0aec7fab06fc7868a8a4c4",
 "LogOperatorAdded":"0x50a18c352ee1c02ffe058e15c2eb6e58be387c81e73cc1e17035286e54c19a57",
 "LogOperatorRemoved":"0xec5f6c3a91a1efb1f9a308bb33c6e9e66bf9090fad0732f127dfdbf516d0625d",
 "LogExitManagerAdded":"0x9a8520da740f574ac36dbc80915c3a2e124842ff8d870158bb2f07c4716d5d31",
 "LogExitManagerRemoved":"0xf6761acc00c18a126c54e9b64383c52bbdca25b815044f87c5f5d5d8c1858023",
 "AdminTransferred":"0xf8ccb027dfcd135e000e9d45e6cc2d662578a8825d4c45b5e32e0adf67e79ec6",
 "LogAssetRegistered":"0xe474e5671ab1255dfb9155a63d2c8230abae68026941ef08139a71486c1a07a3",
 "LogAssetActive":"0xd9e0246a72572ba7b3dce3886102dbf7ad34ee2f7a8c23f6eb4bd6726a1f254d",
 "LogAssetInactive":"0xbb3eb60234f4cf7d174b3ef3df6c43920999ff8fda5a7907efb34542710a5c43",
 "LogAmmPoolCreated":"0xac32822e6e43fe9fef55006be3a443452e4316a167e4b8a8e676a44935429e9a",
 "LogNewEternalTreeRoot":"0xc0be29b7ec0b30df5114f0303e84df73cbfe4edfa0ec51b31eaaf279f783e920",
 "LogNewEphemeralTreeRoot":"0x1aa7ea6469b3940f9a87c98ad31ffca7af2be0d18844f520319c3d0b03059414",
 "LogL1ToL2MessageQueueFastWithdraw":"0xa64a184913b18287f2ba9fe0e579c1bcdeb05d1dac1b7ca6ec5c47ec5c1339a4",
 "LogL1ToL2MessageQueueDeposit":"0x070589d8a6b7f7d7e8a5cd68adadc3ac4cdf10465981d9c4d060e3b4ed1afdc4",
 "LogL1ToL2MessageQueueRegister":"0x1cd7a88778ac7b85e7b035b44b5831b226446e48cc62cfd8e50ed522a755d01d",
 "LogL1ToL2MessageQueueUpdate":"0x93fe99441f323c380c582c7d6d40e9627e32aae706890eefb55978d74314ef3e",
 "LogL2ToL1MessageQueueUpdate":"0x4922d19a3dad367510434e1d8c74b309e5ca61ca7f8b98cdfdbe3f7778ffe26f",
 "LogMessageQueueEncoderAddressSet":"0x22cba1a6cd33415399386df90cdac6b0dee7888c51a291ff29f072fb0cda621e",
 "LogNewSnarkVerifier":"0x2ce3c40ed3c72fe4e2d959cf30644352b66239a8cf4ebcafb1d4f1b9fc2b6eeb",
 "LogNewCircuitVersion":"0x73c43acf2236432debda79a55628ce23164336d08e9c57c30543ece1f164e05f",
 "LogWethAddressSet":"0x92c432904f92dfe8bc09c616522801a30feeab25ddacfbe2a934d8b582f79c3a",
 "LogAssetLimitAndPrecisionUpdated":"0xf4e354e576104dfad1482c6a4fc528cea5127b712f91be7d808ec0c8fc8fbfbb",
 "Upgraded":"0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b",
 "AdminChanged":"0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f",
}
T2N = {v:k for k,v in TOPICS.items()}

ASSETS = {
 0:("ETH","0x0000000000000000000000000000000000000000",18,"scroll:0x5300000000000000000000000000000000000004"),
 1:("USDC","0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4",6,"scroll:0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4"),
 2:("USDT","0xf55BEC9cafDbE8730f096Aa55dad6D22d44099Df",6,"scroll:0xf55BEC9cafDbE8730f096Aa55dad6D22d44099Df"),
 3:("WBTC","0x3C1BCa5a656e69edCD0D4E36BEbb3FcDAcA60Cf1",8,"scroll:0x3C1BCa5a656e69edCD0D4E36BEbb3FcDAcA60Cf1"),
 4:("SCR","0xd29687c813D741E2F938F4aC377128810E217b1b",18,"scroll:0xd29687c813D741E2F938F4aC377128810E217b1b"),
}

def hexint(h): return int(h,16)

def aname(a): return ASSETS[a][0] if a in ASSETS else f"asset{a}"

def main():
    outdir = os.path.join(os.path.dirname(__file__), "..", "ci-out")
    os.makedirs(outdir, exist_ok=True)
    latest = hexint(rpc("eth_blockNumber",[]))
    print(f"[scan] latest Scroll block: {latest}", flush=True)

    all_logs = []
    chunk = 50_000
    b = int(os.environ.get("SCAN_FROM", DEPLOY_BLOCK))
    latest = int(os.environ.get("SCAN_TO", latest))
    tag = os.environ.get("SCAN_TAG", "")
    print(f"[scan] range {b}..{latest} tag={tag!r}", flush=True)
    topic_list = list(TOPICS.values())
    failed_chunks = []
    n_calls = 0
    while b <= latest:
        e = min(b+chunk-1, latest)
        res = rpc("eth_getLogs",[{"address":VAULT,"fromBlock":hex(b),"toBlock":hex(e),"topics":[topic_list]}])
        n_calls += 1
        if res == "RANGE_TOO_LARGE":
            chunk = chunk // 2
            if chunk < 2000: print("[scan] chunk too small; aborting", flush=True); break
            continue
        if res is None:
            failed_chunks.append([b, e])
            print(f"[scan] WARNING chunk failed {b}-{e}", flush=True)
        elif res:
            all_logs.extend(res)
            if n_calls % 25 == 0 or b == DEPLOY_BLOCK:
                print(f"[scan] block {e}: {len(all_logs)} logs so far", flush=True)
        b = e+1
    print(f"[scan] done: {len(all_logs)} logs from {n_calls} chunks; failed_chunks={len(failed_chunks)}", flush=True)

    bytopic = collections.defaultdict(list)
    for lg in all_logs:
        n = T2N.get(lg["topics"][0]) if lg.get("topics") else None
        if n: bytopic[n].append(lg)

    # timestamps for first/last of each type
    def blk_ts(bn):
        blk = rpc("eth_getBlockByNumber",[hex(bn),False])
        return hexint(blk["timestamp"]) if blk else None

    counts = {}
    for n, lgs in bytopic.items():
        lgs.sort(key=lambda l: (hexint(l["blockNumber"]), hexint(l["logIndex"])))
        counts[n] = {
            "count": len(lgs),
            "first_block": hexint(lgs[0]["blockNumber"]),
            "last_block": hexint(lgs[-1]["blockNumber"]),
        }
    # attach timestamps for the interesting types only
    for n in ["LogProofCommitted","LogWithdraw","LogL1ToL2MessageQueueFastWithdraw","LogL1ToL2MessageQueueDeposit","LogFastWithdrawBackfill","LogVesselKeyRegister","LogNewPendingWithdrawAmount","LogNewSnarkVerifier"]:
        if n in counts:
            fts, lts = blk_ts(counts[n]["first_block"]), blk_ts(counts[n]["last_block"])
            if fts: counts[n]["first_ts"] = fts; counts[n]["first_ts_iso"] = datetime.datetime.utcfromtimestamp(fts).isoformat()+"Z"
            if lts: counts[n]["last_ts"] = lts; counts[n]["last_ts_iso"] = datetime.datetime.utcfromtimestamp(lts).isoformat()+"Z"

    # --- pendingWithdraw last-write-wins per (account, asset)
    pend = {}
    for lg in bytopic["LogNewPendingWithdrawAmount"]:
        d = lg["data"][2:]
        w = [d[i:i+64] for i in range(0,len(d),64)]
        acct = "0x"+w[0][-40:]; aid = hexint(w[1]); amt = hexint(w[2])
        key = (acct, aid)
        cur = pend.get(key)
        bn = hexint(lg["blockNumber"])
        if cur is None or bn > cur[0]:
            pend[key] = (bn, amt, lg["transactionHash"])
    claimable = collections.defaultdict(int)
    for (acct, aid), (bn, amt, tx) in pend.items():
        if amt > 0: claimable[aid] += amt

    # --- withdrawals by asset
    wsum = collections.defaultdict(int); wcount = collections.Counter()
    for lg in bytopic["LogWithdraw"]:
        d = lg["data"][2:]
        w = [d[i:i+64] for i in range(0,len(d),64)]
        aid = hexint(w[1]); amt = hexint(w[2])
        wsum[aid] += amt; wcount[aid] += 1

    # --- L1->L2 deposits by asset (money into vault)
    dsum = collections.defaultdict(int); dcount = collections.Counter()
    for lg in bytopic["LogL1ToL2MessageQueueDeposit"]:
        d = lg["data"][2:]
        w = [d[i:i+64] for i in range(0,len(d),64)]
        aid = hexint(w[1]); amt = hexint(w[2])
        dsum[aid] += amt; dcount[aid] += 1

    # --- fastWithdraw queued amounts by asset, distinct recipients/lps
    fw = collections.defaultdict(lambda: {"amount":0,"count":0,"recipients":set(),"lps":set()})
    for lg in bytopic["LogL1ToL2MessageQueueFastWithdraw"]:
        d = lg["data"][2:]
        w = [d[i:i+64] for i in range(0,len(d),64)]
        lp = "0x"+w[0][-40:]; rec = "0x"+w[1][-40:]; aid = hexint(w[2]); amt = hexint(w[3])
        f = fw[aid]
        f["amount"] += amt; f["count"] += 1
        f["recipients"].add(rec); f["lps"].add(lp)

    # --- backfills to LPs by asset
    bsum = collections.defaultdict(int); bcount = collections.Counter()
    for lg in bytopic["LogFastWithdrawBackfill"]:
        d = lg["data"][2:]
        w = [d[i:i+64] for i in range(0,len(d),64)]
        aid = hexint(w[1]); amt = hexint(w[2])
        bsum[aid] += amt; bcount[aid] += 1

    # --- operators / exit managers final state from add/remove events
    def rolefinal(adds, removes):
        state = {}
        for ev, flag in ((adds, "added"), (removes, "removed")):
            for lg in bytopic.get(ev, []):
                d = lg["data"][2:]
                w = [d[i:i+64] for i in range(0, len(d), 64)]
                acct = "0x" + w[0][-40:]
                bn = hexint(lg["blockNumber"])
                if acct not in state or bn >= state[acct]["block"]:
                    state[acct] = {"state": flag, "block": bn}
        return state
    ops = rolefinal("LogOperatorAdded", "LogOperatorRemoved")
    exits = rolefinal("LogExitManagerAdded", "LogExitManagerRemoved")

    # --- proof commit last info
    pc = bytopic["LogProofCommitted"]
    pc_last = None
    if pc:
        lg = pc[-1]
        d = lg["data"][2:]
        w = [d[i:i+64] for i in range(0,len(d),64)]
        pc_last = {"block":hexint(lg["blockNumber"]), "tx":lg["transactionHash"],
                   "batchId":hexint(w[0]), "lastEventId":hexint(w[1])}

    # --- live balances at latest block
    def call(to, data):
        res = rpc("eth_call",[{"to":to,"data":data}, hex(latest)])
        return res
    balances = {}
    for aid,(sym,addr,dec,pricekey) in ASSETS.items():
        if aid == 0:
            res = rpc("eth_getBalance",[VAULT, hex(latest)])
            bal = hexint(res) if res else 0
        else:
            res = call(addr, "0x70a08231"+"0"*24+VAULT[2:])
            bal = hexint(res) if res else 0
        balances[aid] = {"symbol":sym,"raw":str(bal),"amount":bal/10**dec}

    # prices
    pricekeys = ",".join(a[3] for a in ASSETS.values())
    prices = {}
    try:
        pr = api(f"https://coins.llama.fi/prices/current/{pricekeys}")
        for k,v in pr.get("coins",{}).items():
            prices[k] = v.get("price")
    except Exception as e:
        print("[scan] price fetch failed:", e, flush=True)
    usd = {}
    for aid,(sym,addr,dec,key) in ASSETS.items():
        p = prices.get(key, 0)
        usd[aid] = balances[aid]["amount"]*p
    total_usd = sum(usd.values())

    claim_usd = {}
    for aid, amt in claimable.items():
        if aid not in ASSETS: continue
        dec = ASSETS[aid][2]; p = prices.get(ASSETS[aid][3],0)
        claim_usd[aid] = (amt/10**dec)*p

    summary = {
      "vault": VAULT,
      "latest_block": latest,
      "scan_from_block": DEPLOY_BLOCK,
      "failed_chunks": failed_chunks,
      "rpc_used": R["url"],
      "generated_utc": datetime.datetime.utcnow().isoformat()+"Z",
      "event_counts": counts,
      "last_proof_commit": pc_last,
      "operators_seen_events": ops,
      "exit_managers_seen_events": exits,
      "balances_latest": balances,
      "prices": {aname(a): prices.get(ASSETS[a][3]) for a in ASSETS},
      "vault_total_usd": round(total_usd,2),
      "claimable_now_raw": {aname(a): str(claimable[a]) for a in claimable if claimable[a]>0},
      "claimable_now_usd": round(sum(claim_usd.values()),2),
      "claimable_accounts": [{"account":k[0],"asset":aname(k[1]),"raw":str(v[1])} for k,v in sorted(pend.items(), key=lambda kv:-kv[1][1]) if v[1]>0],
      "withdrawals_by_asset": {aname(a): {"raw":str(wsum[a]),"count":wcount[a]} for a in wsum},
      "deposits_by_asset": {aname(a): {"raw":str(dsum[a]),"count":dcount[a]} for a in dsum},
      "fastwithdraw_by_asset": {aname(a): {"raw":str(fw[a]["amount"]),"count":fw[a]["count"],
                                "distinct_recipients":len(fw[a]["recipients"]),"distinct_lps":len(fw[a]["lps"])} for a in fw},
      "backfill_by_asset": {aname(a): {"raw":str(bsum[a]),"count":bcount[a]} for a in bsum},
    }
    json.dump(summary, open(os.path.join(outdir,f"scan_summary{tag}.json"),"w"), indent=1)
    # full pending list
    with open(os.path.join(outdir,f"pending_withdraw{tag}.csv"),"w") as f:
        f.write("account,asset_id,asset,raw_amount,last_block,tx\n")
        for (acct,aid),(bn,amt,tx) in sorted(pend.items(), key=lambda kv:-kv[1][1]):
            if amt>0:
                f.write(f"{acct},{aid},{aname(aid)},{amt},{bn},{tx}\n")
    # compact raw (strip to essentials) — gzipped to keep artifacts small
    import gzip
    compact = [{"t":T2N.get(l["topics"][0]),"b":hexint(l["blockNumber"]),"tx":l["transactionHash"],
                "topics":l["topics"],"data":l["data"]} for l in all_logs if l.get("topics")]
    with gzip.open(os.path.join(outdir,f"vault_logs_compact{tag}.json.gz"),"wt") as f:
        json.dump(compact, f)
    print(json.dumps({k:summary[k] for k in ["latest_block","vault_total_usd","claimable_now_usd","last_proof_commit"]}, indent=1), flush=True)
    print(f"[scan] wrote ci-out/scan_summary{tag}.json, pending_withdraw{tag}.csv, vault_logs_compact{tag}.json.gz", flush=True)

if __name__ == "__main__":
    main()
