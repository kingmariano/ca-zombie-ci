# Evidence commands — H2-05 plasma_fluent (all read-only)

Pinned blocks: **Plasma 34,691,115** · **Fluent 17,863,118**. No keys, no transactions. Public RPCs only.

## RPC probes
```bash
cast chain-id    --rpc-url https://rpc.plasma.to            # 9745
cast block-number --rpc-url https://rpc.plasma.to           # 34691115+ (pin)
cast chain-id    --rpc-url https://rpc.fluent.xyz           # 25363
cast block-number --rpc-url https://rpc.fluent.xyz          # 17863118 (pin)
# Dead in this environment: plasma.drpc.org (paid only), plasma-rpc.publicnode.com (404),
# fluent.drpc.org (404), explorer.fluent.xyz (NXDOMAIN), plasma.blockscout.com (404)
```

## CHATEAU (Plasma)
```bash
B=34691115; R=https://rpc.plasma.to
cast call 0x22222215d4EdC5510d23D0886133E7ece7F5fdC1 "name()(string)"        --rpc-url $R --block $B   # "chUSD"
cast call 0x22222215d4EdC5510d23D0886133E7ece7F5fdC1 "totalSupply()(uint256)" --rpc-url $R --block $B   # 1,024,692.236150956e18
cast call 0x22222215d4EdC5510d23D0886133E7ece7F5fdC1 "minter()(address)"      --rpc-url $R --block $B   # 0xEA67…7296
cast call 0x22222215d4EdC5510d23D0886133E7ece7F5fdC1 "owner()(address)"       --rpc-url $R --block $B   # Safe 0x478F…E668
cast call 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb "name()(string)"        --rpc-url $R --block $B   # "USDT0"
cast call 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb "balanceOf(address)(uint256)" 0xea6709c29d4d4b5162d8c55d0c28c5ced6cd7296 --rpc-url $R --block $B  # 77.307860
cast call 0x22222215d4EdC5510d23D0886133E7ece7F5fdC1 "balanceOf(address)(uint256)" 0x9616042c61f08284f8f0d3a3931aadbc987aa2c6 --rpc-url $R --block $B  # 963,014.68
cast call 0xea6709c29d4d4b5162d8c55d0c28c5ced6cd7296 "hasRole(bytes32,address)(bool)" \
   0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6 0xa0fd0bd36bf8174ab2cc547049648703bb4e72af --rpc-url $R --block $B  # MINTER true

# Gate proof (eth_call simulation from unprivileged addresses; calldata = selector+ABI encode)
cast call 0xea6709c29d4d4b5162d8c55d0c28c5ced6cd7296 0x95165e8b<redeem-order-sig-calldata> --from 0x1111111111111111111111111111111111111111 --rpc-url $R
#   -> execution reverted: AccessControl: account 0x1111… is missing role 0x44ac9762eec3a11893fefb11d028bb3102560094137c3ed4518712475b2577cc (REDEEMER_ROLE)
cast call 0xea6709c29d4d4b5162d8c55d0c28c5ced6cd7296 0xd48c03e5<mint-order-route-sig-calldata>  --from 0x2222222222222222222222222222222222222222 --rpc-url $R
#   -> execution reverted: missing role 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6 (MINTER_ROLE)
cast call 0xea6709c29d4d4b5162d8c55d0c28c5ced6cd7296 0xe0f3fc9f<transferToCustody-calldata> --from 0x3333333333333333333333333333333333333333 --rpc-url $R
#   -> execution reverted: missing role 0x85e8f2d6819d6b2410…

# Selector/dispatch reconstruction of the unverified ChateauMinting:
cast code 0xea6709c29d4d4b5162d8c55d0c28c5ced6cd7296 --rpc-url $R > minting_bytecode.hex
cast disassemble "$(cat minting_bytecode.hex)" > minting_disasm.txt   # 42 unique selectors
heimdall decompile <bytecode> -o minting_decompiled.sol               # ABI (abi.json)
curl 'https://api.openchain.xyz/signature-database/v1/lookup?function=0x95165e8b,...&filter=true'  # redeem/mint/transferToCustody/…

# History/flows (Etherscan V2, chainid=9745; key from .env, never written to disk):
#   module=account&action=tokentx&address=<minting>          -> 674 USDT0 transfers (IN 431,243.64692 / OUT 431,166.33906)
#   module=account&action=txlist&address=<minting>           -> 654 txs; last = redeem @ blk 31,927,212 (ts 1788867779)
#   module=logs&action=getLogs&address=0x2222…&topic0=Transfer  -> 840 logs; aggregated to all current balances
#   RoleGranted found: DEFAULT_ADMIN -> 0xd9911e44…; MINTER+REDEEMER -> 0xa0fd0bd3…; custody role -> Safe 0x478F…
# Contract sources: api.etherscan.io/v2/api?chainid=9745&module=contract&action=getsourcecode  (chUSD + schUSD verified)

# Oracle-side: prices
curl 'https://coins.llama.fi/prices/current/plasma:0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb'  # USDT0 0.999096
```

## Vena Finance (Fluent)
```bash
B=17863118; R=https://rpc.fluent.xyz
cast call 0xD6E69976C8Aea2A4075Bc637fE8881672FF14013 "getReservesList()(address[])" --rpc-url $R --block $B
cast storage 0xD6E69976C8Aea2A4075Bc637fE8881672FF14013 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $R --block $B  # impl 0xd5443A54…
cast call 0xB6eEF266933382661827E36fE3f936396e80166E "getReserveData(address)(...)" 0xD48e… --rpc-url $R --block $B
cast call 0xB6eEF266933382661827E36fE3f936396e80166E "getReserveConfigurationData(address)(...)" 0xFa9b… --rpc-url $R --block $B  # LTV 66% / LT 73%
# custody reads (aToken contracts hold the underlying):
cast call 0xD48e565561416dE59DA1050ED70b8d75e8eF28f9 "balanceOf(address)(uint256)" 0x3Ebf3cfcCDCd96edC1C506907C17eec2BdC31008 --rpc-url $R --block $B  # 545,341.402995
cast call 0xFa9b3B45587f9fcdE14759121C3868C2733DCbf4 "balanceOf(address)(uint256)" 0x3161bF68Bc6e582D682458F8766b219E8e2821Ed --rpc-url $R --block $B  # 8,457,557.196359
cast call 0x927C469E58Daab257Ea60B2D8c37bEDD2a203A54 "balanceOf(address)(uint256)" 0x8e2Ea47F850E2F899EB02f8a69f3635c73599a3a --rpc-url $R --block $B  # 0.0003883399…
# oracle chain:
cast call 0xC3Be4DDD4354Cd83FcfB3bE67686387b42A353Db "getSourceOfAsset(address)(address)" 0x927C… --rpc-url $R --block $B  # PythProAggregatorAdapter 0xEd3Af217…
cast call 0xEd3Af2179E18B755A06c6A4d5cc96d0554Cf7103 "latestAnswer()(int256)" --rpc-url $R --block $B   # 2495.19e8
cast call 0xdb653cf878c1e707D17282B19efcF5D6184BD531 "getFeedId()(uint32)" --rpc-url $R --block $B      # 3176 (USDnr)
cast call 0x132A7bAedF66f3778d7D53A04e5a5Fb5e1da7427 "latestAnswer()(int256)" --rpc-url $R --block $B   # 1.02016e8 (sUSDnr index)
# roles:
cast call 0x18797a361C79fD7b6d8C62d7eDe244353a7369Bf "hasRole(bytes32,address)(bool)" 0x12ad05bd… 0x2799ea13… --rpc-url $R --block $B  # POOL_ADMIN true (TimelockController)
cast call 0xc93Dd12974e0Df7aF91bd28A6B4B34786EA3b905 "hasRole(bytes32,address)(bool)" $(cast keccak PRICE_UPDATER_ROLE) 0x2799ea13… --rpc-url $R --block $B  # false (separate updater key)
# sources: fluentscan.xyz/api/v2/smart-contracts/<addr>  -> Pool, ACLManager, Provider, AaveOracle, adapters, VenaPythPrices
# ACL RoleGranted history: fluentscan.xyz/api/v2/addresses/0x18797a36…/logs
# prices: curl coins.llama.fi/prices/current/fluent:0xD48e…,fluent:0xFa9b…   # 1.000224 / 1.020390
```

## Explorers / references
- Plasma txs: `https://plasmascan.to/address/0xea6709c29d4d4b5162d8c55d0c28c5ced6cd7296` · `https://plasmascan.to/token/0x22222215d4EdC5510d23D0886133E7ece7F5fdC1`
- Fluent: `https://fluentscan.xyz/address/0xD6E69976C8Aea2A4075Bc637fE8881672FF14013`
- Docs: docs.chateau.capital (mint/redeem model, silo cooldown) · docs.vena.finance (contract addresses, pause/freeze, audits)
- DefiLlama: `api.llama.fi/protocol/chateau`, `api.llama.fi/protocol/vena-finance`
