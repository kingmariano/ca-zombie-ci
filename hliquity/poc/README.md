# HLiquity PoC — method and tooling notes

## What this is
`verify.py` performs the full read-only verification of HLiquity's live state and gates against
Hedera mainnet using raw JSON-RPC `eth_call` simulations (state-changing calls are simulated,
never sent). It reproduces, against live state, the checks that a fork PoC would run:

- live census (troves, ICRs, TCR, price feed status, pools, balances),
- **oracle exploit A/B**: replays the exact Bonzo-style zero-signature update transaction
  (`exploit_tx_input.hex`, tx 0xd50c55e2…a10a60 of 2026-07-11) against (a) the current state
  (expect revert `DataNotVerified()` = 0x40ef6502) and (b) the pre-fix block 0x5cfcda5
  (expect success). This proves the Supra verifier fix is effective on the feed HLiquity reads,
- Supra S-Value storage write guard (`restrictedSetSupraStorage` → `UnauthorisedAccess()`),
- HCHF mint/burn guards, `setAddresses` admin guards,
- redemption simulation (closes the lowest-ICR trove) + no-arbitrage accounting,
- liquidation attempt on the lowest-ICR trove (expect revert).

## Fork-tooling limitation (why eth_call simulation instead of anvil/forge)
Anvil 1.8.5 and Foundry's fork backend cannot fork Hedera mainnet through its public relays
(`mainnet.hashio.io`, `295.rpc.thirdweb.com`): their genesis/fork account fetches send the fork
block as an EIP-1898 block object, which Hedera's relay rejects:

    Error: failed to create genesis
    - failed to get account for 0xf39Fd6e5…: Invalid parameter 1: The value passed is not valid:
      [object Object]. Expected 0x prefixed hexadecimal block number, or the string "latest"…

The same incompatibility breaks `vm.createSelectFork` in `forge test` ("failed to get account for
0x0000000000000000000000000000000000000000"). Raw `eth_call` with an explicit block parameter
works and is equivalent for every check above because each is a single transaction simulation.
The only capability a live fork would add is persistence across steps (write price → liquidate);
that consequence chain is moot because both write paths (verifier zero-signature, direct storage
write) are proven closed.

No transactions are ever signed or sent. No secrets are used (public endpoints only).
