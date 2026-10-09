import concurrent.futures, urllib.request, json, time, os
UA={"User-Agent":"Mozilla/5.0"}
targets = {
 "lcd_validators": "https://api.carbon.network/cosmos/staking/v1beta1/validators",
 "lcd_govparams": "https://api.carbon.network/cosmos/gov/v1/params",
 "lcd_govparams_abci": "https://api.carbon.network/cosmos/gov/v1beta1/params",
 "lcd_cp": "https://api.carbon.network/cosmos/distribution/v1beta1/community_pool",
 "lcd_supply": "https://api.carbon.network/cosmos/bank/v1beta1/supply",
 "lcd_proposals": "https://api.carbon.network/cosmos/gov/v1/proposals",
 "lcd_valset": "https://api.carbon.network/cosmos/base/tendermint/v1beta1/validatorsets/latest",
 "lcd_block_last": "https://api.carbon.network/cosmos/base/tendermint/v1beta1/blocks/100279059",
 "alt_lavender": "https://carbon-api.lavenderfive.com/cosmos/staking/v1beta1/validators",
 "alt_autostake": "https://carbon-mainnet-api.autostake.com/cosmos/staking/v1beta1/validators",
 "alt_blockhunters": "https://api-carbon.blockhunters.org/cosmos/staking/v1beta1/validators",
 "alt_kjnodes": "https://carbon.api.kjnodes.com/cosmos/staking/v1beta1/validators",
 "alt_nodestake": "https://carbon-api.nodestake.top/cosmos/staking/v1beta1/validators",
 "alt_stakecito": "https://carbon-api.stakecito.com/cosmos/staking/v1beta1/validators",
 "alt_nodesguru": "https://carbon-api.nodes.guru/cosmos/staking/v1beta1/validators",
 "alt_ecostake": "https://carbon-api.ecostake.com/cosmos/staking/v1beta1/validators",
 "alt_itrock": "https://carbon.api.itrocket.net/cosmos/staking/v1beta1/validators",
 "alt_publicnode": "https://carbon-rest.publicnode.com/cosmos/staking/v1beta1/validators",
 "llama_demex": "https://api.llama.fi/protocol/demex",
 "osmosis_pools": "https://lcd.osmosis.zone/cosmos/bank/v1beta1/supply",
}
def fetch(name,url):
    for i in range(4):
        try:
            req=urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=15) as r:
                data=r.read()
                return name, r.status, data
        except Exception as e:
            err=str(e); time.sleep(2)
    return name, "ERR", err.encode()
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as ex:
    futs=[ex.submit(fetch,n,u) for n,u in targets.items()]
    for f in concurrent.futures.as_completed(futs):
        name,status,data=f.result()
        if status==200:
            fn=f"raw/probe_{name}.json"
            open(fn,"wb").write(data)
            print(f"OK   {name} ({len(data)}b) -> {fn} :: {data[:100]!r}")
        else:
            print(f"FAIL {name} [{status}] {data[:80]!r}")
