#!/bin/bash
# keyless public Sui GraphQL helper
curl -s -m 30 https://graphql.mainnet.sui.io/graphql -H 'Content-Type: application/json' --data-binary @- 
