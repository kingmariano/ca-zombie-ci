#!/bin/bash
# Fetch DefiLlama protocol data. Read-only.
cd "$(dirname "$0")"
UA="research/1.0"
curl -s -A "$UA" "https://api.llama.fi/protocols" -o llama_protocols_all.json
for slug in ring-few ring-swap ring-protocol ring ring-exchange; do
  curl -s -A "$UA" "https://api.llama.fi/protocol/$slug" -o "llama_protocol_$slug.json"
  sleep 1
done
# token prices
curl -s -A "$UA" "https://coins.llama.fi/prices/current/hyperevm:0x9e1148bC3665a9f7C35F313d89c0432c34928AEf,hyperevm:0x0C47cbbEDE5d8c6f9614cF770C26c3315205C397,hyperevm:0xd2646b9B02859416D8cBc759F85f0676f6E19974,hyperevm:0x7576dd9a2775bFd789616d9eA7A2af21d06782D0,hyperevm:0x09D21E89EF332347eb3E1E496f1265a600e364C1,hyperevm:0x5555555555555555555555555555555555555555,hyperevm:0xBe6727B535545C67d5cAa73dEa54865B92CF7907,hyperevm:0xb88339CB7199b77E23DB6E890353E22632Ba630f,hyperevm:0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb,hyperevm:0x111111a1a0667d36bD57c0A9f569b98057111111" -o llama_prices_fwtokens.json
echo "protocols with Ring in name:"
python3 - <<'EOF'
import json
d=json.load(open('llama_protocols_all.json'))
for p in d:
    if 'ring' in p.get('name','').lower() or 'ring' in str(p.get('url','')).lower() or 'few' in p.get('name','').lower():
        print(p.get('name'), '| slug:', p.get('slug'), '| chains:', p.get('chains'), '| tvl:', p.get('tvl'), '| category:', p.get('category'))
EOF
