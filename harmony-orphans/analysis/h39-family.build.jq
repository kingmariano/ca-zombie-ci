($p | map(select(.addr != null)) | INDEX(.addr|ascii_downcase)) as $probe |
($c[0] | map({block, ts, hash, addr,
  code_bytes: ($probe[.addr|ascii_downcase].code_bytes),
  name: ($probe[.addr|ascii_downcase].name),
  symbol: ($probe[.addr|ascii_downcase].symbol),
  balance_wei: ($probe[.addr|ascii_downcase].balance_wei)})) as $created |
{
  schema: "h39-family/v1",
  generated: "2026-10-04",
  owner_eoa: "0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C",
  owner_nonce: 460,
  key_finding: "Owner blocked LZ v1 send/receive (version 65535 = BLOCK_VERSION) and cleared trusted remotes on both Harmony ONE-OFTs on 2026-08-30; the BSC/Ethereum ProxyOFT counterparts remain configured in the other direction and the BSC side still custodies 211,121 ONE.",
  oft_contracts: [
    {name: "ONE for BSC", symbol: "ONE", generation: 2, address: "0x5B18a4E73F9A4fe337A072516b317863Ad3046aA", code_bytes: 24336, decimals: 18, totalSupply_wei: "62531259468551870330371539", native_balance_wei: "62531259468551870330371539", balanceOf_self_wei: "62531259468551870330371539", owner: "0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C", lz_endpoint: "0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4", sendVersion: 65535, receiveVersion: 65535, trustedRemote_101: null, trustedRemote_102: null, local_lz_chain_id_on_remotes: 116},
    {name: "ONE for Ethereum", symbol: "ONE", generation: 2, address: "0x905582f21fB9855c809d5b8933272a292dfbB138", code_bytes: 24336, decimals: 18, totalSupply_wei: "13101396431214960428021286", native_balance_wei: "13101396431214960428021286", balanceOf_self_wei: "13101396431214960428021286", owner: "0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C", lz_endpoint: "0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4", sendVersion: 65535, receiveVersion: 65535, trustedRemote_101: null, trustedRemote_102: null, local_lz_chain_id_on_remotes: 116},
    {name: "ONE for Ethereum", symbol: "ONE", generation: 1, address: "0xa2ba7aa169e5c77eb37a5330f2695fee8d1216ac", code_bytes: 23114, decimals: 18, totalSupply_wei: "0", native_balance_wei: "0", balanceOf_self_wei: "0", owner: "0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C", lz_endpoint: "0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4", trustedRemote_101: "0x768fa1abbc38054f9fb2218e97778cc7b110c779a2ba7aa169e5c77eb37a5330f2695fee8d1216ac", trustedRemote_102: null},
    {name: "ONE for BSC", symbol: "ONE", generation: 1, address: "0x8da02bedf802976a69627dd8ae081493d8fdf0f0", code_bytes: 23114, decimals: 18, totalSupply_wei: "10000000000000000000", native_balance_wei: "10000000000000000000", balanceOf_self_wei: "10000000000000000000", owner: "0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C", lz_endpoint: "0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4", trustedRemote_101: null, trustedRemote_102: "0x55b9b75f2d456d010e6b8c6f62544c6efc1c101d8da02bedf802976a69627dd8ae081493d8fdf0f0"}
  ],
  trusted_remote_events: [
    {contract: "0x905582f21fB9855c809d5b8933272a292dfbB138", event: "SetTrustedRemoteAddress", chainId: 101, remote: "0x768fa1abbc38054f9fb2218e97778cc7b110c779", block: 32725818, ts: "2022-10-17T02:35:21Z", tx: "0x390da857beff54a7b26fa282062e6e83ac4edd8fb500c7f49127dcdddf6a0c56"},
    {contract: "0x5B18a4E73F9A4fe337A072516b317863Ad3046aA", event: "SetTrustedRemoteAddress", chainId: 102, remote: "0x55b9b75f2d456d010e6b8c6f62544c6efc1c101d", block: 32725868, ts: "2022-10-17T02:37:01Z", tx: "0xc97a37fdb56733980989539dc40906aec7af5006c6eb5c96899247052acccfe6"},
    {contract: "0x905582f21fB9855c809d5b8933272a292dfbB138", event: "SetTrustedRemoteAddress", chainId: 101, remote: "0x234784ec001db36c9c22785cad902221fd831352", block: 32760763, ts: "2022-10-17T22:04:39Z", tx: "0x02c04cfcd17545267d34c9dd5afc5e3853d06d54bf8b201e6c031d1c9d464685"},
    {contract: "0x5B18a4E73F9A4fe337A072516b317863Ad3046aA", event: "SetTrustedRemoteAddress", chainId: 102, remote: "0x2332137ae0386783ffbcf40d9f17e50890917e15", block: 32760784, ts: "2022-10-17T22:05:21Z", tx: "0x964e6473d79bd1b9ecae266f3a6987f94b2881a3d2f3ce949c9953d82f443864"},
    {contract: "0x5B18a4E73F9A4fe337A072516b317863Ad3046aA", event: "SetTrustedRemote", chainId: 102, remote: "0x(cleared)", block: 93144294, ts: "2026-08-30T10:01:37Z", tx: "0x4f91a92423b042b13cc098342207f0b1d13a546498d1886c507404d76ca61cbf"},
    {contract: "0x905582f21fB9855c809d5b8933272a292dfbB138", event: "SetTrustedRemote", chainId: 101, remote: "0x(cleared)", block: 93144382, ts: "2026-08-30T10:04:33Z", tx: "0x147e891ba284fc33bbc2f5e07b11636e7b841a15bd487acba961df2b74725186"}
  ],
  version_block_events_2026_08_30: [
    {contract: "0x5B18a4E73F9A4fe337A072516b317863Ad3046aA", method: "setReceiveVersion(65535)", block: 93144268, tx: "0xc2c666d2ad35f6dbf01df1690e4209ebf51f6c4fb12b5d6f104200d7d8e123f2"},
    {contract: "0x5B18a4E73F9A4fe337A072516b317863Ad3046aA", method: "setSendVersion(65535)", block: 93144279, tx: "0xf4e5a63614d982f0095379d0e8a2250e0a5dee7b6eb2697d1ec9ab9a031f45a2"},
    {contract: "0x905582f21fB9855c809d5b8933272a292dfbB138", method: "setReceiveVersion(65535)", block: 93144314, tx: "0xc5fd4ef182381a72c9a6982fb219bdc0eb3d98a222bacce6e8bf89dae05f3c11"},
    {contract: "0x905582f21fB9855c809d5b8933272a292dfbB138", method: "setSendVersion(65535)", block: 93144328, tx: "0x40369fa97139f3b82fb434ea158eed6fcf9864f9b625a2de70cfa95bba9bbef0"}
  ],
  remotes: [
    {chain: "bsc", generation: 1, address: "0x55b9b75f2d456d010e6b8c6f62544c6efc1c101d", code_bytes: 20092, kind: "ProxyOFT (unverified)", owner: "0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C", token: "0x03fF0ff224f904be3118461335064bB48Df47938", multisig: "0x715CdDa5e9Ad30A0cEd14940F9997EE611496De6", bridgeManager: "0xfD53b1B4AF84D59B20bF2C20CA89a6BeeAa2c628", native_balance_wei: "0", token_balance_wei: "10000000000000000000", circulatingSupply_wei: "2461187178291210121486291060", trustedRemote_116: "0x5b18a4e73f9a4fe337a072516b317863ad3046aa55b9b75f2d456d010e6b8c6f62544c6efc1c101d"},
    {chain: "bsc", generation: 2, address: "0x2332137ae0386783ffbcf40d9f17e50890917e15", code_bytes: 18800, kind: "ProxyHRC20 (Sourcify+BscScan verified)", owner: "0xE3364CC2C65995c924Db6D1F467d9Be275E65E35", owner_kind: "Safe proxy (172B, Safe L2 v1.3.0 pattern)", token: "0x03fF0ff224f904be3118461335064bB48Df47938", multisig: "0x715CdDa5e9Ad30A0cEd14940F9997EE611496De6", bridgeManager: "0xfD53b1B4AF84D59B20bF2C20CA89a6BeeAa2c628", native_balance_wei: "0", token_balance_wei: "211111000000000000000000", circulatingSupply_wei: "2460976077291210121486291060", trustedRemote_116: "0x5b18a4e73f9a4fe337a072516b317863ad3046aa2332137ae0386783ffbcf40d9f17e50890917e15"},
    {chain: "ethereum", generation: 1, address: "0x768fa1abbc38054f9fb2218e97778cc7b110c779", code_bytes: 20092, kind: "ProxyOFT (unverified)", owner: "0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C", token: "0xD5cd84D6f044AbE314Ee7E414d37cae8773ef9D3", multisig: "0x715CdDa5e9Ad30A0cEd14940F9997EE611496De6", bridgeManager: "0x4D34E61CaF7A3622759D69e48CCDeB8dee5021e8", native_balance_wei: "0", token_balance_wei: "0", circulatingSupply_wei: "26018624868477960428021286", trustedRemote_116: "0x905582f21fb9855c809d5b8933272a292dfbb138768fa1abbc38054f9fb2218e97778cc7b110c779"},
    {chain: "ethereum", generation: 2, address: "0x234784ec001db36c9c22785cad902221fd831352", code_bytes: 18800, kind: "ProxyERC20WithMint (Etherscan+Sourcify verified)", owner: "0x19565F4771843467aAD632d6B56c75396785b06C", owner_kind: "Safe proxy (172B, Safe L2 v1.3.0 pattern)", token: "0xD5cd84D6f044AbE314Ee7E414d37cae8773ef9D3", multisig: "0x715CdDa5e9Ad30A0cEd14940F9997EE611496De6", bridgeManager: "0x4D34E61CaF7A3622759D69e48CCDeB8dee5021e8", native_balance_wei: "0", token_balance_wei: "0", circulatingSupply_wei: "26018624868477960428021286", trustedRemote_116: "0x905582f21fb9855c809d5b8933272a292dfbb138234784ec001db36c9c22785cad902221fd831352", note: "690 txs, still sending to LZ Ethereum endpoint as late as 2026-08-29"}
  ],
  underlying_tokens: [
    {chain: "bsc", address: "0x03fF0ff224f904be3118461335064bB48Df47938", name: "Harmony ONE", symbol: "ONE", decimals: 18, totalSupply_wei: "2461187188291210121486291060", labels: ["BEP-20", "Cross-Chain", "Bridged Token", "BscScan reputation NEUTRAL"], proxies_hold_wei: "211121000000000000000000"},
    {chain: "ethereum", address: "0xD5cd84D6f044AbE314Ee7E414d37cae8773ef9D3", name: "Harmony ONE", symbol: "1ONE", decimals: 18, totalSupply_wei: "26018624868477960428021286", labels: ["ERC-20", "Bridged Token", "Etherscan reputation NEUTRAL"], proxies_hold_wei: "0"}
  ],
  ens_cluster: [
    {chain: "ethereum", address: "0x7a04c0d1d07b3e3fc2d31a405f44b1a729cf16a6", code_bytes: 17637, kind: "ProxyOFT", owner: "0x19565F4771843467aAD632d6B56c75396785b06C", token: "0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85 (ENS BaseRegistrar .eth ERC721)", token_balance_wei: "6", trustedRemote_116: "0xdcb88a5f12c35961055da7d4b6bfd1210b1f21b47a04c0d1d07b3e3fc2d31a405f44b1a729cf16a6"},
    {chain: "harmony", address: "0xdcb88a5f12c35961055da7d4b6bfd1210b1f21b4", code_bytes: 16189, kind: "OFT (no ERC20 name)", owner: "0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C", trustedRemote_101: "0x7a04c0d1d07b3e3fc2d31a405f44b1a729cf16a6dcb88a5f12c35961055da7d4b6bfd1210b1f21b4"},
    {chain: "harmony", address: "0x925b03143cf250892aadef83306b830ca4786404", code_bytes: 14770, kind: "OFT/ERC20 token, name Ethereum Name Service, symbol ENS", owner: "0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C", trustedRemote_101: "0x7a04c0d1d07b3e3fc2d31a405f44b1a729cf16a6925b03143cf250892aadef83306b830ca4786404"},
    {chain: "harmony", address: "0x447853bc371cce9016df6e21ec1d97e18b8c167d", code_bytes: 16680, kind: "name Ethereum Name Service, symbol ENS (no owner found)"}
  ],
  factory_created_contracts: [
    {address: "0xf57fa3aB9479294DC39d732689A75FBA99364aF7", kind: "Gnosis Safe v1.3.0 (SafeL2 singleton 0xfb1bffC9d739B8D520DaF37dF666da4C687191EA)", created_by: "Safe ProxyFactory 0xC22834581EbC8527d974F8a1c97E1bEA4EF910BC via create2 (owner tx 0x2594010b3a23d8c7ad9fd9571eb9fa254ee6cf899afa3c62ebab1307e2c60508, block 37281009)", owners: ["0x18A5Af69DfC02dc950f7534Ae97A180F34B75d7a", "0x8c2641b5915171845EfDdC9fcAc20427B9347fF4", "0x3CA9A84E7c91F2167007cAce3017BaD23D2b14BC", "0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C"], threshold: 2, native_balance_wei: "20000000000000000000"}
  ],
  owner_created_count: ($created|length),
  owner_created_contracts: $created,
  endpoint_harmony: {
    address: "0x9740ff91f1985d8d2b71494ae1a2f723bb3ed9e4",
    code_bytes: 15283,
    owner: "0xE590a6730D7a8790E99ce3db11466Acb644c3942",
    sendVersion: "65535 (BLOCK_VERSION)",
    receiveVersion: "65535 (BLOCK_VERSION)",
    getSendLibraryAddress: "reverts: LayerZero: send version is BLOCK_VERSION",
    getReceiveLibraryAddress: "reverts: LayerZero: receive version is BLOCK_VERSION",
    hasStoredPayload: [
      {chainId: 101, src: "0x234784ec001db36c9c22785cad902221fd831352905582f21fb9855c809d5b8933272a292dfbb138", value: false},
      {chainId: 101, src: "0x905582f21fb9855c809d5b8933272a292dfbb138234784ec001db36c9c22785cad902221fd831352", value: false},
      {chainId: 101, src: "0x768fa1abbc38054f9fb2218e97778cc7b110c779905582f21fb9855c809d5b8933272a292dfbb138", value: false},
      {chainId: 101, src: "0x905582f21fb9855c809d5b8933272a292dfbb138768fa1abbc38054f9fb2218e97778cc7b110c779", value: false},
      {chainId: 102, src: "0x2332137ae0386783ffbcf40d9f17e50890917e155b18a4e73f9a4fe337a072516b317863ad3046aa", value: false},
      {chainId: 102, src: "0x5b18a4e73f9a4fe337a072516b317863ad3046aa2332137ae0386783ffbcf40d9f17e50890917e15", value: false},
      {chainId: 102, src: "0x55b9b75f2d456d010e6b8c6f62544c6efc1c101d5b18a4e73f9a4fe337a072516b317863ad3046aa", value: false},
      {chainId: 102, src: "0x5b18a4e73f9a4fe337a072516b317863ad3046aa55b9b75f2d456d010e6b8c6f62544c6efc1c101d", value: false}
    ],
    selector_0x0936e6d5: "not present in endpoint code; raw call reverts"
  },
  methods: {logs_v1: "explorer.harmony.one/api?module=logs&action=getLogs", calls: "cast call on public RPCs", verified: "Sourcify v2 + Etherscan/BscScan HTML (ETHERSCANV2_API_KEY unset)"}
}
