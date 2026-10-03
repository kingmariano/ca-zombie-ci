# C-36 child-subagent KIT — forgotten-eth recovery index deep review

You are a child subagent of the C-36 deep-dive (zombie-hunt campaign). You review ONE segment
(seg-A/B/C/D/E) of the **forgotten-eth index** (295 legacy Ethereum contracts). Your goal:
for every contract in your segment decide **whether an external, unprivileged attacker can extract
value right now** — and prove it with on-chain evidence. Read-only. No mainnet transactions.

## Hard rules (same as parent brief)
- **Read-only on Ethereum mainnet.** No signing, no sending, no approvals, no private keys.
  Do NOT run `cast send`. Only `cast call`, `cast balance`, `cast code`, `cast storage`, `eth_getBalance`.
- **Write only inside `/home/heisenberg/CA/c-36/analysis/seg-<X>/`.** Do not touch other folders.
- **Do not commit anything** to git. Do not modify `/home/heisenberg/CA/zombie_hunt/` or other c-XX.
- **Do not spawn further subagents.**
- **No heavy local jobs** (no forge/anvil/fuzz). If a fork test is needed, flag the candidate to the
  parent — the parent runs CI. Light RPC reads and source downloads are fine.
- **No secrets** in any file. Use public RPC `https://ethereum-rpc.publicnode.com` (fallback
  `https://eth.drpc.org`, `https://1rpc.io/eth`). Always set a browser `User-Agent` header.

## Data you have (all under /home/heisenberg/CA/c-36/analysis/)
- `worklist.json` — 295 entries keyed by address: name, category, source, live_eth (measured
  2026-10-03 at block 26,111,001), mapped (index-reported claimable), idx_contract_eth,
  coverage_pct, desc (index's claim-path note), verified, bs_name, code_size, **selectors**
  (extracted 4-byte selectors from bytecode), owner_sel/admin_sel, meta_addrs, live_tokens.
- `live_295.json` — raw measurement incl. selector probe results per contract.
- `code_src_295.json` — selectors + Blockscout name/verified/proxy.
- `token_balances.json` — ETH/WETH/USDC/USDT/DAI/WBTC/stETH/wstETH/SAI balances for all 295
  + curated children (block 26,111,067).
- `seg_<X>_addrs.json` — YOUR segment's address list.
- `index_full.json`, `index_full_live.json` — full index metadata.

## How to fetch source / inspect a contract
1. Blockscout (free, works): `curl -s -H 'User-Agent: Mozilla/5.0' https://eth.blockscout.com/api/v2/smart-contracts/<addr>`
   → `.source_code`, `.abi`, `.is_verified`, `.name`, `.implementations`.
2. Sourcify: `https://repo.sourcify.dev/contracts/full_match/1/<addr>/metadata.json`.
3. If unverified: `cast disassemble <addr> --rpc-url https://ethereum-rpc.publicnode.com | head -200`,
   selector set from `worklist.json`, and resolve selectors at
   `https://www.4byte.directory/api/v1/signatures/?hex_signature=0x<sel>` (rate-limit friendly).
   Use `cast 4byte <sel>` if available.
4. Live reads: `cast call <addr> "<sig>" [args] --rpc-url <rpc>`; `cast storage` for slots.
   Record the block number for every claim: `cast block-number --rpc-url <rpc>`.

## Classification (use exactly these)
- **E-U** = extractable by an external unprivileged attacker (no holder status needed; buy-on-market
  is allowed if a real market exists and you verify liquidity/price).
- **H-O** = holder/self-service only (withdraw/refund/exit/redeem pays only the caller's own
  recorded position; no non-holder path found).
- **P** = privileged only (owner/admin/governance can move value; no permissionless path).
- **S** = stuck/bricked (nobody can move it: reverts, no function, dead admin, trapped by design).

## What to look for (priority bug classes — old-contract shapes)
1. **Refund/claim without eligibility or with broken math** — refund() that pays more than
   contributed; double-refund; overflow in `weiGiven`; missing `msg.sender` check; claim that
   credits a caller-supplied address.
2. **Permissionless state transition that unlocks funds** — `cancel()`, `finalize()`, `refundAll()`,
   `setClaim(bool)`, `unpause()`, `initialize()` callable by anyone; owner-action-required entries
   where the owner key is dead/renounced and the transition is unguarded.
3. **Sweep/rescue/withdrawAll/collect functions without access control** — any function that moves
   contract ETH/tokens to an attacker-controlled address.
4. **Merkle/proof flaws** — double-claim, leaf/domain confusion, claimTo arbitrary recipient,
   reused proof, missing nullifier.
5. **Share/vault math** — exchange-rate manipulation, donation/first-depositor inflation,
   redeem rounding, stale rate, broken `totalSupply` accounting, over/under-backed vaults.
6. **First-mover races (note as H-O unless a non-holder can enter without market)** — where claims
   exceed assets; state who wins and what an attacker would need.
7. **Unprotected proxy / uninitialized implementation** — EIP-1967 admin slot, `initialize()` open.
8. **Signature flaws** — replay, missing nonce/deadline/chainId, forgeable ECDSA, `ecrecover(0)`.
9. **Reentrancy / CEI violations** — state updated after external call; ERC-777/1155 callbacks.
10. **Admin additions to otherwise-known families** — compare selectors vs family rep and inspect
    any extra selectors (EtherDelta forks, P3D forks, presale templates).

## Output (write into your seg folder)
1. `seg-<X>/results.json` — JSON list, one object per contract:
```json
{
  "address": "0x...", "name": "...", "live_eth": 0.0, "mapped": 0.0,
  "classification": "E-U|H-O|P|S",
  "claim_model": "1-2 sentences: how users claim + what gates it",
  "evidence": ["verified source <url/name>", "cast call ... returned ...", "selector set matches X"],
  "eu_candidate": null,   // or {"function":"...","call_path":"...","why":"...","preconditions":"...","value_eth":0.0,"confidence":"high|medium|low"}
  "confidence": "high|medium|low",
  "notes": "family deviations, race notes, drain dynamics"
}
```
2. `seg-<X>/REPORT.md` — markdown: segment summary table (address | name | live ETH | class |
   one-line reason), then a short section for each E-U candidate and each notable H-O race, with
   block numbers and exact calls. Cite prior-verdict addresses (`PRIOR` list below) briefly.
3. `seg-<X>/raw/` — optional: saved sources, selector lists, call outputs.

## PRIOR verdicts (do NOT re-litigate; just confirm live balance and cite)
zombie-deep proved $0 for: IDEX v1 `0x2a0c0db…`, EtherDelta v2 `0x8d12a19…`, Unknown DEX
`0x4d55f76…`, Unknown DEX `0x5995ca6…`, Token.Store `0x1ce7ae5…`, SingularX `0x9a2d163…`,
Ethfinex `0xaa7427d…` (+v2 `0x50cb61a…`), 0x0 Rewards `0x02b15c4…`, Switcheo `0x7ee7ca6…`,
zkSync Lite `0x0a14b69…` (root verified), Neufund v1/v2 `0xb59a226…`/`0x0b7dc5a…`,
PoWH3D `0xb3775fb…`, Fomo3D Long `0xa621428…`, Last Winner `0xdd9fd6b…`, FoMo3D Ultra
`0xab83d96…`, FoMo3Dshort/Quick/FoMoJP/AceDapp/CryptoMinerToken/Bingo4Beast, Zethr/Zethr Casino,
MCDEX `0x220a9f0…`, Celer channels `0xa6cd930…`, Rook `0x35ffd6e…`, Keep `0x27321f8…`,
Hegic ETH pool `0x878f15f…`, CryptoCats `0x9508008…`, ReadyPlayerONE `0x6db9432…`,
DailyDivs `0xd2bfcee…`, FEG `0xf786c34…`, Transit `0xc213f25…`, Aave v1 core `0x3dfd23a…`,
dYdX Solo `0x1e0447b…` (≤$16-18), Opyn Crab `0x3b960e4…`.
For these, one line: "live X ETH (block N); prior $0 — no new surface". Only dig deeper if the live
balance or selectors differ materially from the prior measurement.

## Budget
Aim to finish within your segment's scope. Spend depth on contracts with >10 ETH live or >50 ETH
mapped, unclear claim paths, or E-U candidates. For dust (<1 ETH, <20 mapped) do a fast check:
code present? owner/admin? any ETH-moving function? classify with one line.
