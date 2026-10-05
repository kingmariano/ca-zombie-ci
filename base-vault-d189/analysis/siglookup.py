import json, urllib.request, urllib.parse, time
sels = json.load(open("selectors_evmole.json"))
allsels = set()
for name, rows in sels.items():
    for r in rows:
        allsels.add(r["selector"])
print("unique selectors:", len(allsels))
# OpenChain batch lookup
qs = "&".join("function=0x"+s for s in sorted(allsels))
url = "https://api.openchain.xyz/signature-database/v1/lookup?" + qs + "&filter=true"
try:
    d = json.load(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent":"Mozilla/5.0"}), timeout=30))
    res = d.get("result",{}).get("function",{})
except Exception as e:
    print("openchain fail", e); res = {}
# 4byte fallback for missing
missing = [s for s in sorted(allsels) if not res.get("0x"+s)]
for s in missing:
    try:
        u = "https://www.4byte.directory/api/v1/signatures/?hex_signature=0x"+s
        d = json.load(urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent":"Mozilla/5.0"}), timeout=20))
        names = [x["text_signature"] for x in d.get("results",[])]
        res["0x"+s] = [{"name":n} for n in names]
    except Exception as e:
        res["0x"+s] = []
    time.sleep(0.3)
for s in sorted(allsels):
    got = res.get("0x"+s) or []
    names = [g.get("name") for g in got] if isinstance(got, list) else []
    print(s, "->", names)
json.dump({s:[g.get("name") for g in (res.get("0x"+s) or [])] for s in sorted(allsels)}, open("selectors_named.json","w"), indent=1)
