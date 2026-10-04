#!/bin/bash
ADDR="celestia1vxzram63f7mvseufc83fs0gnt5383lvrle3qpt"
ENDPOINTS="
https://celestia.rpc.uquad.org:443
https://public-celestia-lcd.numia.xyz
https://api.lunaroasis.net
https://api.celestia.nodestake.org
https://rest.lavenderfive.com:443/celestia
https://celestia.rest.interchain.validao.xyz
https://celestia-rest.publicnode.com
https://celestia.rest.stakin-nodes.com
https://celestia.api.kjnodes.com
https://api-celestia.mzonder.com
https://celestia-lcd.enigma-validator.com
https://rest-celestia.theamsolutions.info
https://api.celestia.validatus.com
https://celestia-mainnet-lcd.autostake.com:443
https://celestia.api.cumulo.org.es
https://lcd.celestia-app.bronbro.io
https://celestia-api.noders.services
https://celestia-mainnet-api.itrocket.net
https://api.celestia.mainnet.dteam.tech:443
https://celestia-api.stakeandrelax.net
https://api.celestia.node75.org
https://api.archive.celestia.validatus.com
https://celestia-api.polkachu.com
https://celestia-api.cogwheel.zone
https://celestia-mainnet-api.crouton.digital
"
i=0
for base in $ENDPOINTS; do
  i=$((i+1))
  f="lcdprobe-$i"
  host=$(echo "$base" | sed 's|https\?://||; s|[:/]|_|g')
  code=$(curl -sS -m 12 -G --data-urlencode "query=message.sender='$ADDR'" --data-urlencode "limit=100" -o "$f.json" -w "%{http_code}" "$base/cosmos/tx/v1beta1/txs" 2>"$f.err")
  res=$(python3 -c "
import json,sys
try:
    d=json.load(open('$f.json'))
    t=d.get('total'); n=len(d.get('txs') or [])
    print(f'total={t} txs={n}')
except Exception as e:
    print('ERR', open('$f.json').read()[:80].replace(chr(10),' '))
" 2>/dev/null)
  echo "$host | HTTP $code | $res"
done
