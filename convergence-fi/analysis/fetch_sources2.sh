#!/usr/bin/env bash
# Fetch additional verified sources + ABIs (public Etherscan data).
set -uo pipefail
cd "$(dirname "$0")"
set -a; source /home/heisenberg/CA/.env 2>/dev/null; set +a
mkdir -p sources
addrs=(
  0xbdbddc4bf67e9bc02706e4ce53bc14d6ce3038f1   # tower impl
  0xe789b78f66886d3ec9e393fb495ea726c5b371af   # stkCVGETH/stkCVGCVGSDT impl
  0x33dbaa43aabd534664aae56490c3b0aa26f06bac   # cvgCVX impl
  0x7f50786a0b15723d741727882ee99a0bf34e3466   # cvgSdt sdCRV
  0x2ff160bcadb485b5f048b9880e6f471af632060c   # StakeDAO sdCRV gauge/staking
  0x9da58ff69f95c1769913516faf3fad1325288860   # StakeDAO cvgSDTSDT gauge
  0x42ac76385de5eae2fcd5a04601aea8472e453882   # StakeDAO CVGETH gauge
)
for a in "${addrs[@]}"; do
  out="sources/${a}.json"
  if [ ! -s "$out" ]; then
    curl -s --max-time 30 -A "python-research" \
      "https://api.etherscan.io/v2/api?chainid=1&module=contract&action=getsourcecode&address=${a}&apikey=${ETHERSCANV2_API_KEY}" -o "$out"
    sleep 0.4
  fi
  python3 - "$out" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
r=(d.get("result") or [{}])[0]
print(f"{r.get('ContractName','?'):40s} verified={bool(r.get('SourceCode'))} proxy={r.get('Proxy','0')} impl={r.get('Implementation','')}")
PY
done
