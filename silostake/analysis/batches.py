import json, urllib.request, urllib.parse, base64, time
HUB="sei1e3gttzq5e5k49f9f5gzvrl0rltlav65xu6p9xc0aj7e84lantdjqp7cncc"
UA={"User-Agent":"Mozilla/5.0"}
def q(msg):
    b=base64.b64encode(json.dumps(msg).encode()).decode()
    req=urllib.request.Request(f"https://rest.sei-apis.com/cosmwasm/wasm/v1/contract/{HUB}/smart/{b}", headers=UA)
    return json.loads(urllib.request.urlopen(req, timeout=40).read().decode())["data"]

batches={}
start=None
for i in range(20):
    msg={"previous_batches":{"start_after":start,"limit":30}}
    d=q(msg)
    print("page",i,"got",len(d), flush=True)
    if not d: break
    for b in d: batches[b["id"]]=b
    start=d[-1]["id"]
    if len(d)<30: break
    time.sleep(0.3)
json.dump(batches, open("previous_batches.json","w"), indent=1)
print("total batches:", len(batches), "ids:", sorted(batches)[:5], "...", sorted(batches)[-5:])
