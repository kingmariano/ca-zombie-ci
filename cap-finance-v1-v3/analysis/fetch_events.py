#!/usr/bin/env python3
"""Fetch & summarize Cap Finance event logs (Arbitrum) via Etherscan V2."""
import json, os, urllib.request, time, sys

key = os.environ["ETHERSCANV2_API_KEY"]
outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "state")
os.makedirs(outdir, exist_ok=True)

TOPICS = {
    "Deposit": "0xdcbc1c05240f31ff3ad067ef1ee35ce4997762752e3a095284754544f4c709d7",
    "Withdraw": "0xf341246adaac6f497bc2a656f546ab9e182111d630394f0c57c710a59a2cb567",
    "NewOrderV2": "0xe6f0e81a24c1b1c11cfcbbce67e7c5ef361e984c1e4f3528125c93f6f906680d",
    "PositionUpdatedV2": "0x722a60bf2980ad6565c04c8210c55454af895983660b33099a60a0af5e05037b",
    "ClosePositionV2": "0x1eba783f67334e9b95080299c6a95635568b5bf34dbe80586bc9f938307d7b9c",
    "NewPositionV3": "0x897d6fcabf4b287cf55d40cdf4e9923429552cb0ba629749a59024bd2820d690",
    "ClosePositionV3": "0x99f336bf3300897d4a21c55ae526f14794b0dfde386d0d58eb8da45e368b4557",
    "StakedV3": "0x18dcd430020e4d4899772fd94a8b40451dc5044dfb70bc46b532eeae431c864f",
    "RedeemedV3": "0x7a46f35a1788485b78dbde530d394514fb913933c784f7e4415c9dc69793a7a8",
}

def get_logs(addr, topic0=None, from_block=0, to_block="latest", offset=1000):
    out = []
    page = 1
    while True:
        url = (f"https://api.etherscan.io/v2/api?chainid=42161&module=logs&action=getLogs"
               f"&fromBlock={from_block}&toBlock={to_block}&address={addr}"
               f"&apikey={key}&offset={offset}&page={page}")
        if topic0:
            url += f"&topic0={topic0}"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        d = json.load(urllib.request.urlopen(req, timeout=60))
        res = d.get("result", [])
        if not isinstance(res, list):
            print("ERR", addr, topic0, d.get("message"), str(d.get("result"))[:200])
            break
        out.extend(res)
        if len(res) < offset:
            break
        page += 1
        time.sleep(0.25)
    return out

def fetch_all(addr, label):
    fn = os.path.join(outdir, f"logs-{label}-{addr[:10]}.json")
    all_logs = []
    for name, t0 in TOPICS.items():
        logs = get_logs(addr, t0)
        for l in logs:
            l["_event"] = name
        all_logs.extend(logs)
        print(f"  {label} {addr} {name}: {len(logs)}")
        time.sleep(0.2)
    all_logs.sort(key=lambda l: int(l["blockNumber"], 16))
    with open(fn, "w") as f:
        json.dump(all_logs, f, indent=1)
    print(f"saved {fn}: {len(all_logs)} logs")
    return all_logs

if __name__ == "__main__":
    targets = [
        ("ethpool", "0xE0cCd451BB57851c1B2172c07d8b4A7c6952a54e"),
        ("usdcpool", "0x958cc92297e6F087f41A86125BA8E121F0FbEcF2"),
        ("poolcap", "0xC8CDd2Ea6A5149ced1F2d225D16a775ee081C67D"),
        ("tradev1", "0xA55Eee92a46A50A4C65908F28A0BE966D3e71633"),
        ("tradev2a", "0xCAEc650502F15c1a6bFf1C2288fC8F819776B2eC"),
        ("tradev2b", "0xbEd32937D8A5D1421241F52809908f1a17D75bDb"),
        ("tradev3", "0x9BC357bc5b312AaCD41a84F3C687F031B8786853"),
    ]
    for label, addr in targets:
        print(f"== {label} {addr}")
        fetch_all(addr, label)
