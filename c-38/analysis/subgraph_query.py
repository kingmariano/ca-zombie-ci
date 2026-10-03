#!/usr/bin/env python3
"""Query Tectonic subgraph: markets, borrowers (storedBorrowBalance>0), liquidations."""
import json
import urllib.request

SG = "https://graph-v2.cronoslabs.com/subgraphs/name/tectonic/tectonic-main"


def gql(query, variables=None, retries=3):
    body = json.dumps({"query": query, "variables": variables or {}}).encode()
    last = None
    for _ in range(retries):
        try:
            req = urllib.request.Request(SG, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                out = json.loads(r.read())
            if "errors" in out:
                last = out["errors"]
                continue
            return out["data"]
        except Exception as e:
            last = str(e)
    raise RuntimeError(last)


meta = gql("{ _meta { block { number } hasIndexingErrors } }")
print("subgraph meta:", meta)

markets = gql("""{ markets(first: 50) { id symbol name underlyingSymbol underlyingAddress underlyingDecimals
  cash totalBorrows reserves exchangeRate collateralFactor underlyingPrice underlyingPriceUSD borrowRate supplyRate accrualBlockNumber blockTimestamp } }""")["markets"]
print(f"\nmarkets: {len(markets)}")
for m in markets:
    print(f"{m['symbol']:10s} {m['id']} {m['underlyingSymbol']:8s} cash={m['cash']} borrows={m['totalBorrows']} cf={m['collateralFactor']} priceUSD={m['underlyingPriceUSD']}")

# borrowers pagination
borrowers = []
skip = 0
while True:
    q = """query($skip: Int!){ accountTTokens(first: 1000, skip: $skip, where: {storedBorrowBalance_gt: "0"}, orderBy: storedBorrowBalance, orderDirection: desc) {
      id storedBorrowBalance tTokenBalance account { id } market { id symbol underlyingSymbol } } }"""
    rows = gql(q, {"skip": skip})["accountTTokens"]
    if not rows:
        break
    borrowers.extend(rows)
    print(f"fetched borrowers page skip={skip} n={len(rows)}")
    if len(rows) < 1000:
        break
    skip += 1000
    if skip > 20000:
        print("WARNING: borrower pagination cap hit")
        break

print(f"\ntotal borrower positions (storedBorrowBalance>0): {len(borrowers)}")
uniq = sorted(set(b["account"]["id"] for b in borrowers))
print(f"unique borrower accounts: {len(uniq)}")
with open("subgraph_borrowers.json", "w") as f:
    json.dump({"markets": markets, "borrowers": borrowers}, f, indent=1)

liqs = gql("""{ liquidationEvents(first: 30, orderBy: blockNumber, orderDirection: desc) { id amount underlyingRepayAmount underlyingSymbol tTokenSymbol from to blockNumber blockTime } }""")["liquidationEvents"]
print(f"\nrecent liquidations: {len(liqs)}")
for l in liqs:
    print(l)
with open("subgraph_liquidations.json", "w") as f:
    json.dump(liqs, f, indent=1)
