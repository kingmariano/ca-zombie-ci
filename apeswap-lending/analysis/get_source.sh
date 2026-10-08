#!/usr/bin/env bash
# Fetch verified source + ABI from Etherscan V2 for BSC contracts.
set -e
source /home/heisenberg/CA/.env 2>/dev/null || true
ADDR="${1:?addr}"
NAME="${2:-$ADDR}"
OUTDIR=/home/heisenberg/CA/apeswap-lending/analysis/src
mkdir -p "$OUTDIR"
curl -s "https://api.etherscan.io/v2/api?chainid=56&module=contract&action=getsourcecode&address=$ADDR&apikey=$ETHERSCANV2_API_KEY" -o "$OUTDIR/$NAME.json"
python3 - "$OUTDIR/$NAME.json" "$OUTDIR/$NAME.source.sol" <<'EOF'
import json,sys
d=json.load(open(sys.argv[1]))
r=d.get("result")
if isinstance(r,list) and r:
    r=r[0]
    src=r.get("SourceCode","")
    open(sys.argv[2],"w").write(src)
    print("ContractName:",r.get("ContractName"))
    print("Compiler:",r.get("CompilerVersion"))
    print("Proxy:",r.get("Proxy"),"Impl:",r.get("Implementation"))
    print("source_len:",len(src))
else:
    print("no result:",str(d)[:300])
EOF
