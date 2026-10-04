# H-39 family — Harmony "ONE for BSC / ONE for Ethereum" LayerZero cluster

Generated 2026-10-04 (read-only: `eth_call`, `eth_getLogs`, explorer APIs). Machine-readable: `h39-family.json`.

## Headline

- Both Harmony ONE-OFTs (`0x5B18…` "ONE for BSC", `0x9055…` "ONE for Ethereum") were **fully disabled on 2026-08-30**: trusted remotes cleared and LZ v1 send/receive versions set to **65535 = BLOCK_VERSION**. Their supplies stay stranded inside the contracts (62,531,259.469 ONE and 13,101,396.431 ONE).
- The remote-side **ProxyOFT counterparts on BSC/Ethereum still trust Harmony chain 116**, and the current BSC proxy still custodies **211,111 ONE** (plus 10 ONE in the abandoned gen-1 proxy); the Ethereum side custodies 0.
- The owner EOA (`0xAC02…17E3C`, nonce 460) is a serial LZ deployer on Harmony: 92 direct creations, **90 of which are LayerZero v1 apps** on the same endpoint; only 6 expose `name()/symbol()`.
- No "ONE for <other chain>" sibling beyond BSC and Ethereum (two generations each).

## 1. Trusted-remote history — all SetTrustedRemote* events (both contracts)

Full-range Blockscout v1 log queries with topic0 `0xfa41487a…` (SetTrustedRemote) and `0x8c0400cf…` (SetTrustedRemoteAddress). Only these 6 exist.

| Contract | Event | chainId | remote | Block | Time (UTC) | Tx |
|---|---|---|---|---|---|---|
| 0x9055…B138 (ONE for Ethereum) | SetTrustedRemoteAddress | 101 | 0x768fa1abbc38054f9fb2218e97778cc7b110c779 (ETH gen-1) | 32,725,818 | 2022-10-17 02:35:21 | 0x390da857… |
| 0x5B18…46aA (ONE for BSC) | SetTrustedRemoteAddress | 102 | 0x55b9b75f2d456d010e6b8c6f62544c6efc1c101d (BSC gen-1) | 32,725,868 | 2022-10-17 02:37:01 | 0xc97a37fd… |
| 0x9055…B138 | SetTrustedRemoteAddress | 101 | 0x234784ec001db36c9c22785cad902221fd831352 (ETH gen-2) | 32,760,763 | 2022-10-17 22:04:39 | 0x02c04cfc… |
| 0x5B18…46aA | SetTrustedRemoteAddress | 102 | 0x2332137ae0386783ffbcf40d9f17e50890917e15 (BSC gen-2) | 32,760,784 | 2022-10-17 22:05:21 | 0x964e6473… |
| 0x5B18…46aA | SetTrustedRemote | 102 | **0x (cleared)** | 93,144,294 | 2026-08-30 10:01:37 | 0x4f91a924… |
| 0x9055…B138 | SetTrustedRemote | 101 | **0x (cleared)** | 93,144,382 | 2026-08-30 10:04:33 | 0x147e891b… |

Same day, immediately before the clears (all from owner EOA):

| Contract | Call | Block | Tx |
|---|---|---|---|
| 0x5B18…46aA | setReceiveVersion(65535) | 93,144,268 | 0xc2c666d2… |
| 0x5B18…46aA | setSendVersion(65535) | 93,144,279 | 0xf4e5a636… |
| 0x9055…B138 | setReceiveVersion(65535) | 93,144,314 | 0xc5fd4ef1… |
| 0x9055…B138 | setSendVersion(65535) | 93,144,328 | 0x40369fa9… |

## 2. Remote counterparts (on BSC / Ethereum)

All four are ProxyOFT bridge contracts (no `name/symbol/totalSupply`; `circulatingSupply() = token.totalSupply() - token.balanceOf(this)`).

| Chain | Gen | Address | Code | Verified | Owner | Underlying token held (wei) | Native | trustedRemote[116] |
|---|---|---|---|---|---|---|---|---|
| BSC | 1 | 0x55b9b75f2d456d010e6b8c6f62544c6efc1c101d | 20,092 B | no | 0xAC02…17E3C (owner EOA) | 10e18 (10 ONE) | 0 | set (0x5B18… ++ self) |
| BSC | 2 | 0x2332137ae0386783ffbcf40d9f17e50890917e15 | 18,800 B | ProxyHRC20 (Sourcify + BscScan) | 0xE3364CC2…5E35 (172-B Safe proxy) | 211111e18 (211,111 ONE) | 0 | set (0x5B18… ++ self) |
| ETH | 1 | 0x768fa1abbc38054f9fb2218e97778cc7b110c779 | 20,092 B | no | 0xAC02…17E3C | 0 | 0 | set (0x9055… ++ self) |
| ETH | 2 | 0x234784ec001db36c9c22785cad902221fd831352 | 18,800 B | ProxyERC20WithMint (Etherscan exact match) | 0x19565F47…B06C (172-B Safe proxy) | 0 | 0 | set (0x9055… ++ self) |

- Underlying tokens: BSC **"Harmony ONE" (ONE)** `0x03fF0ff224f904be3118461335064bB48Df47938`, 18 dec, totalSupply 2,461,187,188.29 (tags: BEP-20, Cross-Chain, Bridged Token; BscScan reputation "NEUTRAL"); ETH **"Harmony ONE" (1ONE)** `0xD5cd84D6f044AbE314Ee7E414d37cae8773ef9D3`, 18 dec, totalSupply 26,018,624.87 (tags: ERC-20, Bridged Token). Proxies hold 211,121 ONE total on BSC; 0 on Ethereum.
- All four share `multisig() = 0x715CdDa5e9Ad30A0cEd14940F9997EE611496De6` (classic Gnosis MultiSigWallet, `required()=1`, owners [0xbDD7…88CE, BSC gen-2 proxy, 0xE3364CC2…]) and a `bridgeManager()` (BSC 0xfD53b1B4…, ETH 0x4D34E61C…).
- ETH gen-2 is still live: 690 txs, sends to the LZ Ethereum endpoint (`0x66A71Dce…`) as recently as **2026-08-29** (block 25,859,160). BscScan shows the BSC gen-2 holding 211,111 ONE (~$509 at $0.00241).
- Public tags via API not available (`ETHERSCANV2_API_KEY` unset); names/verification read from RPC + Etherscan/BscScan HTML.

## 3. Owner EOA and its created contracts (Harmony)

- `0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C`: 472 txs, nonce 460; first block 15,625,619, last 93,144,382.
- **92 direct deployments** (17 Oct 2022 → block 35,466,577). Code sizes cluster (14,770–24,336 B); **90/92 answer `lzEndpoint() = 0x9740FF91…`**.
- Sibling "ONE for X" OFTs (the only named ONE tokens):

| Name | Gen | Address | Code | totalSupply / balanceOf(self) | trustedRemote |
|---|---|---|---|---|---|
| ONE for Ethereum | 1 | 0xa2ba7aa169e5c77eb37a5330f2695fee8d1216ac | 23,114 B | 0 | [101] = 0x768fa1… ++ self (never cleared) |
| ONE for BSC | 1 | 0x8da02bedf802976a69627dd8ae081493d8fdf0f0 | 23,114 B | 10e18 | [102] = 0x55b9b75f… ++ self (never cleared) |
| ONE for Ethereum | 2 | 0x905582f21fB9855c809d5b8933272a292dfbB138 | 24,336 B | 13,101,396.431 (native ONE) | cleared 2026-08-30 |
| ONE for BSC | 2 | 0x5B18a4E73F9A4fe337A072516b317863Ad3046aA | 24,336 B | 62,531,259.469 (native ONE) | cleared 2026-08-30 |

- **ENS bridge cluster**: ETH ProxyOFT `0x7a04c0d1d07b3e3fc2d31a405f44b1a729cf16a6` (17,637 B, owner 0x19565F47…, trusts `0xdcb88a5f…`) holds **6 ENS BaseRegistrar (.eth) NFTs** (`token()=0x57f1887a…`); Harmony side `0xdcb88a5f12c35961055da7d4b6bfd1210b1f21b4` (16,189 B, OFT, owner AC02, trusts 0x7a04c0d1…), plus named ENS tokens `0x925b0314…` (14,770 B, name "Ethereum Name Service"/ENS) and `0x447853bc…` (16,680 B, non-LZ).
- **Factory-created (not in direct list)**: Gnosis Safe v1.3.0 `0xf57fa3aB9479294DC39d732689A75FBA99364aF7` created by owner via Safe ProxyFactory `0xC2283458…` (create2, tx 0x2594010b…, block 37,281,009); 2-of-4 (AC02 is a signer), holds 20 ONE. (330 ProxyCreation events total on the factory; only this one from an owner tx.)
- All other ~85 creations are unnamed LZ apps with 0 native balance; full list (block, code, name, balance, lzEndpoint) in `h39-family.json`.

## 4. Harmony LZ endpoint state — `0x9740ff91f1985d8d2b71494ae1a2f723bb3ed9e4`

- Code size **15,283 B**; `owner() = 0xE590a6730D7a8790E99ce3db11466Acb644c3942`.
- `getSendVersion`/`getReceiveVersion` for both OFTs = **65535 (BLOCK_VERSION)**.
- `getSendLibraryAddress`/`getReceiveLibraryAddress` revert with "LayerZero: send/receive version is BLOCK_VERSION".
- `hasStoredPayload` = **false** for all tested 40-byte src paths: (101) gen-2 both orders, gen-1 both orders; (102) gen-2 both orders, gen-1 both orders → no stuck messages.
- Selector `0x0936e6d5` is **not present** in the endpoint code (raw call reverts); actual v1 selectors: `hasStoredPayload(uint16,bytes)=0x0eaf6ea6`, `getSendLibraryAddress(address)=0x9c729da1`, `getReceiveLibraryAddress(address)=0x71ba2fd6`.

## Consequences

- Harmony → BSC/ETH is impossible now (empty trusted remotes + BLOCK_VERSION).
- BSC/ETH → Harmony messages can still be initiated by the remotes, but the Harmony OFTs are version-blocked; such messages would be rejected/stored at the endpoint (none pending today). Re-enabling requires the owner EOA (trusted remote + non-BLOCK_VERSION).
- The 211,121 ONE on BSC sit in ProxyOFTs controlled by Safe contracts (not directly AC02), so recovery requires action on both sides.
