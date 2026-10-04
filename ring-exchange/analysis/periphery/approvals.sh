#!/usr/bin/env bash
# Etherscan V2 queries for approvals / creation (read-only). HyperEVM chainid 999.
set -u
set -a; . /home/heisenberg/CA/.env; set +a
API="https://api.etherscan.io/v2/api?chainid=999"
K="$ETHERSCANV2_API_KEY"

UR=0xE65081EFa5ad4A196B1Df768716c337e6AB140E9
FEWE=0x068B60ECbC934b0a0dde20FdFf0dE925b97B971F
ROUTER=0x701D1d675415efA2d2429fB122ccC6dD4FCcA959
FACTORY=0x6B65ed7315274eB9EF06A48132EB04D808700b86
FWWETH=0x9e1148bC3665a9f7C35F313d89c0432c34928AEf
FWUETH=0x0C47cbbEDE5d8c6f9614cF770C26c3315205C397
FWUSDC=0xd2646b9B02859416D8cBc759F85f0676f6E19974
FWUSDT0=0x7576dd9a2775bFd789616d9eA7A2af21d06782D0
FWUSDH=0x09D21E89EF332347eb3E1E496f1265a600e364C1
WHYPE=0x5555555555555555555555555555555555555555
UETH=0xBe6727B535545C67d5cAa73dEa54865B92CF7907
USDC=0xb88339CB7199b77E23DB6E890353E22632Ba630f
USDT0=0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb
USDH=0x111111a1a0667d36bD57c0A9f569b98057111111
PERMIT2=0x000000000022D473030F116dDEE9F6B43aC78BA3
APPR20=0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925
APPP2=0xda9fa7c1b00402c17d0161b249b1ab8bbec047c5a52207b9c112deffd817036b

pad() { printf '0x%064s' "${1#0x}" | tr ' ' 0; }

q() { # $1=url
  curl -s --max-time 60 -A "Mozilla/5.0 research" "$1" | jq -c '{status:.status,message:.message,result:(if (.result|type)=="array" then (.result|length) else .result end)}'
}

echo "### contract creation UR"
curl -s --max-time 60 "$API&module=contract&action=getcontractcreation&contractaddresses=$UR&apikey=$K" | jq -c '.result'
echo "### UR txlist (last 20)"
curl -s --max-time 60 "$API&module=account&action=txlist&address=$UR&startblock=0&endblock=99999999&page=1&offset=25&sort=desc&apikey=$K" | jq -c '[.result[]? | {blockNumber,from,to:.to,methodId:.methodId,hash:.hash}]'

echo
echo "### Permit2 Approval events, spender=UR (topic3)"
q "$API&module=logs&action=getLogs&fromBlock=0&toBlock=latest&address=$PERMIT2&topic0=$APPP2&topic0_3_opr=and&topic3=$(pad $UR)&apikey=$K"
echo "### Permit2 Approval events, spender=ROUTER (topic3)"
q "$API&module=logs&action=getLogs&fromBlock=0&toBlock=latest&address=$PERMIT2&topic0=$APPP2&topic0_3_opr=and&topic3=$(pad $ROUTER)&apikey=$K"
echo "### Permit2 Approval events, spender=FEWE (topic3)"
q "$API&module=logs&action=getLogs&fromBlock=0&toBlock=latest&address=$PERMIT2&topic0=$APPP2&topic0_3_opr=and&topic3=$(pad $FEWE)&apikey=$K"
echo "### Permit2 Approval events, spender=FACTORY (topic3)"
q "$API&module=logs&action=getLogs&fromBlock=0&toBlock=latest&address=$PERMIT2&topic0=$APPP2&topic0_3_opr=and&topic3=$(pad $FACTORY)&apikey=$K"

echo
for t in "FWWETH:$FWWETH" "FWUETH:$FWUETH" "FWUSDC:$FWUSDC" "FWUSDT0:$FWUSDT0" "FWUSDH:$FWUSDH" "WHYPE:$WHYPE" "UETH:$UETH" "USDC:$USDC" "USDT0:$USDT0" "USDH:$USDH"; do
  tn=${t%%:*}; ta=${t##*:}
  for sp in "UR:$UR" "ROUTER:$ROUTER" "FEWE:$FEWE" "FACTORY:$FACTORY"; do
    sn=${sp%%:*}; sa=${sp##*:}
    r=$(curl -s --max-time 60 "$API&module=logs&action=getLogs&fromBlock=0&toBlock=latest&address=$ta&topic0=$APPR20&topic0_2_opr=and&topic2=$(pad $sa)&apikey=$K")
    n=$(echo "$r" | jq '.result|length' 2>/dev/null)
    echo "ERC20-Approval $tn spender=$sn count=${n}"
    if [ "${n:-0}" != "0" ] && [ "${n:-0}" != "null" ]; then
      echo "$r" | jq -c '[.result[] | {blockNumber,topic1:.topics[1],value:.data}] | .[-5:]'
      sleep 1
    fi
    sleep 0.4
  done
done
