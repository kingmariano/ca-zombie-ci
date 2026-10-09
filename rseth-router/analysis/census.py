#!/usr/bin/env python3
import os as _os; _os.chdir(_os.path.dirname(_os.path.abspath(__file__)))
"""Global census of Safe EnabledModule/DisabledModule events (Ethereum).

Primary source: GoldRush (1M-block windows, page-number pagination).
Fallback: Etherscan V2 getLogs (address-less, recursive block-window splitting) — used when
GoldRush rejects the runner (observed HTTPError from GitHub Actions).
Bounded retries + global deadline so CI can never hang; partial results are still written.
"""
import json, os, time, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

def _env(name):
    v = os.environ.get(name)
    if v:
        v = v.strip().strip('"').strip("'")
        if v:
            return v
    try:
        for line in open("/home/heisenberg/CA/.env"):
            if line.startswith(name + "="):
                return line.strip().split("=", 1)[1].strip('"').strip("'")
    except FileNotFoundError:
        pass
    return None

GR_KEY = _env("GOLD_RUSH_API_KEY")
ES_KEY = _env("ETHERSCANV2_API_KEY")
RPC = _env("NODEREAL_ETH_RPC_URL") or _env("FORK_RPC_URL") or _env("RPC_URL")

def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.load(r)

def http_get(url, headers=None, tries=4, timeout=60):
    req = urllib.request.Request(url, headers=headers or {"User-Agent": "Mozilla/5.0"})
    last = None
    for attempt in range(tries):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.load(r)
        except urllib.error.HTTPError as he:
            last = he
            if he.code in (401, 403, 404):
                raise
            time.sleep(2 * (attempt + 1))
        except Exception as e:
            last = e
            time.sleep(2 * (attempt + 1))
    raise last

def goldrush_get(url):
    import base64
    h = {"User-Agent": "Mozilla/5.0", "Authorization": "Basic " + base64.b64encode((GR_KEY + ":").encode()).decode()}
    return http_get(url, h)

LATEST = int(rpc("eth_blockNumber", [])["result"], 16)
print("latest", LATEST, flush=True)

TOPICS = {
    "enabled": "0xecdf3a3effea5783a3c4c2140e677577666428d44ed9d474a0b3a4c9943f8440",
    "disabled": "0xaab4fa2b463f581b2b32cb3b7e3b704b9ce37cc209b5fb4d77e593ace4054276",
}
WIN = 999_999
DEADLINE = time.time() + float(os.environ.get("CENSUS_DEADLINE_MIN", "25")) * 60  # hard cap; partial results still written
SOURCE = "goldrush"

# ── pre-check: is GoldRush usable from this runner? ─────────────────────────────────────────────
def goldrush_ok():
    try:
        d = goldrush_get(f"https://api.covalenthq.com/v1/1/events/topics/{TOPICS['enabled']}/"
                         "?starting-block=18000001&ending-block=18001000&page-size=5&page-number=0")
        return not d.get("error")
    except Exception as e:
        print("goldrush pre-check failed:", type(e).__name__, flush=True)
        return False

def parse_gr(x):
    dec = x.get("decoded") or {}
    mod = None
    for p in dec.get("params") or []:
        if p.get("name") == "module":
            mod = p.get("value")
    if not mod:
        topics = x.get("raw_log_topics") or []
        if len(topics) > 1 and isinstance(topics[1], str) and len(topics[1]) >= 42:
            mod = "0x" + topics[1][-40:]
    if not mod:
        data = x.get("raw_log_data") or ""
        if isinstance(data, str) and len(data) >= 42:
            mod = "0x" + data[-40:]
    return {"block": x.get("block_height"), "tx": x.get("tx_hash"),
            "safe": (x.get("sender_address") or "").lower(), "module": (mod or "").lower(),
            "log": x.get("log_offset")}

def scan_goldrush(name, topic):
    windows = []
    start = 1
    while start <= LATEST:
        end = min(start + WIN, LATEST)
        windows.append((start, end))
        start = end + 1

    def work(w):
        start, end = w
        ev, page, fails = [], 0, 0
        while True:
            if time.time() > DEADLINE:
                print(name, start, end, "DEADLINE hit", flush=True)
                break
            url = (f"https://api.covalenthq.com/v1/1/events/topics/{topic}/"
                   f"?starting-block={start}&ending-block={end}&page-size=1000&page-number={page}")
            try:
                d = goldrush_get(url)
            except Exception as e:
                fails += 1
                if fails > 5:
                    print(name, start, end, page, "giving up:", type(e).__name__, flush=True)
                    break
                time.sleep(4 * fails)
                continue
            if d.get("error"):
                fails += 1
                if fails > 6:
                    print(name, start, end, page, "api error, skipping:", d.get("error_message"), flush=True)
                    break
                time.sleep(3 * fails)
                continue
            fails = 0
            data = d.get("data") or {}
            ev.extend(parse_gr(x) for x in (data.get("items") or []))
            pag = data.get("pagination") or {}
            if pag.get("has_more"):
                page += 1
                time.sleep(0.15)
            else:
                break
        return ev

    events = []
    with ThreadPoolExecutor(max_workers=2) as ex:
        for i, ev in enumerate(ex.map(work, windows)):
            events.extend(ev)
            if (i + 1) % 4 == 0:
                print(f"{name}: {i+1}/{len(windows)} windows, cumulative {len(events)}", flush=True)
    print(f"{name}: done, {len(events)} events (goldrush)", flush=True)
    return events

# ── Etherscan fallback ──────────────────────────────────────────────────────────────────────────
def es_fetch(topic, fb, tb):
    url = (f"https://api.etherscan.io/v2/api?chainid=1&module=logs&action=getLogs"
           f"&fromBlock={fb}&toBlock={tb}&topic0={topic}&apikey={ES_KEY}")
    d = http_get(url, tries=3)
    if d.get("status") == "1":
        return d.get("result") or []
    if d.get("message") == "No records found":
        return []
    raise RuntimeError(d.get("message") or str(d)[:120])

def scan_etherscan(name, topic):
    events, fails, done = [], 0, 0
    stack = [(s, min(s + 49_999, LATEST)) for s in range(1, LATEST + 1, 50_000)]
    while stack:
        if time.time() > DEADLINE:
            print(name, "DEADLINE hit", flush=True)
            break
        fb, tb = stack.pop()  # most-recent windows first
        try:
            res = es_fetch(topic, fb, tb)
        except Exception as e:
            fails += 1
            if fails > 15:
                print(name, fb, tb, "giving up:", type(e).__name__, str(e)[:80], flush=True)
                break
            time.sleep(2 * fails)
            stack.append((fb, tb))
            continue
        fails = 0
        if len(res) >= 1000 and tb - fb > 1000:
            mid = (fb + tb) // 2
            stack.append((mid + 1, tb))
            stack.append((fb, mid))
            continue

        def h2i(v, default=0):
            try:
                s = str(v)
                return int(s, 16) if s.startswith("0x") and len(s) > 2 else int(s)
            except Exception:
                return default

        for x in res:
            data = x.get("data") or "0x"
            topics = x.get("topics") or []
            mod = ""
            if len(data) >= 42:
                mod = data[-40:]
            elif len(topics) > 1 and isinstance(topics[1], str) and len(topics[1]) >= 42:
                mod = topics[1][-40:]
            events.append({"block": h2i(x.get("blockNumber")), "tx": x.get("transactionHash"),
                           "safe": (x.get("address") or "").lower(),
                           "module": ("0x" + mod).lower() if mod else "",
                           "log": h2i(x.get("logIndex"))})
        done += 1
        if done % 100 == 0:
            print(f"{name}: {done} windows done, {len(events)} events, stack {len(stack)}", flush=True)
        time.sleep(0.1)
    print(f"{name}: done, {len(events)} events (etherscan)", flush=True)
    return events

# ── run ─────────────────────────────────────────────────────────────────────────────────────────
if os.environ.get("CENSUS_FORCE") != "etherscan" and goldrush_ok():
    print("source: goldrush", flush=True)
    scan = scan_goldrush
else:
    SOURCE = "etherscan"
    print("source: etherscan (fallback)", flush=True)
    scan = scan_etherscan

out, partial = {}, False
for name, topic in TOPICS.items():
    if time.time() > DEADLINE:
        partial = True
        out[name] = []
        continue
    out[name] = scan(name, topic)
    json.dump(out[name], open(f"census_{name}_events.json", "w"))

en, dis = {}, {}
for e in out["enabled"]:
    key = (e["safe"], e["module"])
    if key not in en or (e["block"], e["log"] or 0) > (en[key]["block"], en[key]["log"] or 0):
        en[key] = e
for e in out["disabled"]:
    key = (e["safe"], e["module"])
    if key not in dis or (e["block"], e["log"] or 0) > (dis[key]["block"], dis[key]["log"] or 0):
        dis[key] = e

current = []
for key, e in en.items():
    d = dis.get(key)
    if d and (d["block"], d["log"] or 0) > (e["block"], e["log"] or 0):
        continue
    current.append({"safe": key[0], "module": key[1], "enabled_block": e["block"], "enabled_tx": e["tx"]})
print("distinct safe-module pairs ever enabled:", len(en))
print("current enabled set size:", len(current))
if partial:
    json.dump(current, open("census_current_set.partial.json", "w"), indent=1)
    json.dump({"enabled": len(out["enabled"]), "disabled": len(out["disabled"]), "current": len(current),
               "partial": True, "latest_block": LATEST, "source": SOURCE},
              open("census_counts.partial.json", "w"))
else:
    json.dump(current, open("census_current_set.json", "w"), indent=1)
    json.dump({"enabled": len(out["enabled"]), "disabled": len(out["disabled"]), "current": len(current),
               "partial": False, "latest_block": LATEST, "source": SOURCE},
              open("census_counts.json", "w"))
print("DONE partial=" + str(partial) + " source=" + SOURCE)
