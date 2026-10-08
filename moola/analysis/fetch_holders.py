#!/usr/bin/env python3
"""Enumerate Moola holders (debt + aTokens) via Blockscout Celo API."""
import json, urllib.request, time

BS = "https://celo.blockscout.com/api/v2"
TOKENS = {
 "CELO_vDebt": "0xAF451D23d6f0FA680113CE2D27a891Aa3587f0C3",
 "cUSD_vDebt": "0xf602D9617564C07f1e128687798D8C699cED3961",
 "cEUR_vDebt": "0xfb6c830c13D8322b31b282Ef1Fe85cbb669d9aE8",
 "cREAL_vDebt": "0xbd408042909351B649DC50353532dEeF6De9fAA9",
 "MOO_vDebt": "0x3d6d8A1562ff973aD89887C0a5c001f42Ad66CB8",
 "CELO_sDebt": "0x02661dd90c6243Fe5cdF88De3E8cb74BcC3bD25E",
 "cEUR_sDebt": "0x612599D8421F36b7dA4dDBA201a3854FF55e3d03",
 "MOO_sDebt": "0x0bb14E95a4FF117F7f536D605E2B506e937619C4",
 "aCELO": "0x7D00cd74FF385c955EA3d79e47BF06bD7386387D",
 "aCUSD": "0x918146359264C492BD6934071c6Bd31C854EDBc3",
 "aCEUR": "0xE273Ad7ee11dCfAA87383aD5977EE1504aC07568",
 "aCREAL": "0x9802d866fdE4563d088a6619F7CeF82C0B991A55",
 "aMOO": "0x3A5024E3AAB31A1d3184127B52b0e4B4E9ADcC34",
}

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent":"moola-audit/1.0"})
    for _ in range(3):
        try:
            with urllib.request.urlopen(req, timeout=45) as r:
                return json.load(r)
        except Exception as e:
            print("retry", e); time.sleep(2)
    return None

out = {}
for name, addr in TOKENS.items():
    holders = []
    npt = None
    for page in range(1, 8):
        url = f"{BS}/tokens/{addr}/holders"
        if npt: url += f"?next_page_params={urllib.parse.quote(json.dumps(npt))}"
        d = get(url)
        if not d or "items" not in d: break
        for it in d["items"]:
            holders.append({"addr": it["address"]["hash"], "value": it["value"],
                            "is_contract": it["address"]["is_contract"]})
        npt = d.get("next_page_params")
        if not npt: break
    out[name] = holders
    print(name, len(holders), "holders")
json.dump(out, open("/home/heisenberg/CA/moola/analysis/holders.json","w"), indent=1)
