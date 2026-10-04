# KiiChain live-version evidence (v7.4.2, cosmos/evm fork)

Question: what Cosmos EVM code is KiiChain actually running today, and does it
contain the GHSA-7g4w-cg88-2cq2 underflow guard plus fixes for the two defect
classes KiiChain says remain unfixed upstream?

## 1. Governance-deployed binary, hash-verified

Governance proposal 13 (`KiiChain/mainnets/kiichain/proposals/proposal_13.json`)
scheduled upgrade plan `v7.4.2` at height 10,250,221 and pinned the binary:

- URL: `https://kiichain-snapshots-public.s3.us-east-2.amazonaws.com/releases/v7.4.2/kiichaind-v7.4.2-linux-amd64`
- sha256: `e99e145379c65b9a1b8dae1a799d9a359a16740c07d0c3684820e6729ab34513`

We downloaded the current S3 object (189,834,536 bytes) and its sha256 is
**exactly `e99e1453…4513`** — the binary verified against the proposal is the
binary serving the chain today. (An initial truncated download produced a
mismatch; re-download with `-C -` matched. The final artifact is the full file.)

## 2. Embedded module versions (`go version -m` on the live binary)

```
path  github.com/kiichain/kiichain/v7/cmd/kiichaind
mod   github.com/kiichain/kiichain/v7  (devel)
dep   github.com/cosmos/evm  v0.6.0
=>    github.com/KiiChain/evm-private  v0.6.2-fork.2  h1:WaKy9LIbR9VmtmEU9j9T5+u+pq6qsVr1bKSYSYXrfyA=
build vcs.revision=0ef04d738aee0f54aca6f9dc82194b2c50483f6e
build vcs.time=2026-09-10T18:24:50Z
build -X github.com/cosmos/cosmos-sdk/version.Version=v7.4.2
build -X github.com/cometbft/cometbft/version.TMCoreSemVer=v0.38.21
```

So the live chain replaces upstream `cosmos/evm` with **KiiChain's own fork
`github.com/KiiChain/evm-private v0.6.2-fork.2`**. `v0.6.2` is the upstream
release that contains the public underflow patch (#1176). The fork is private;
the public mirror `github.com/KiiChain/evm` carries the same tag
`v0.6.2-fork.2` (module path `github.com/cosmos/evm`, zip hash
`h1:TCaztkGSm4R/O0zyw7cElmY7FZqdQ+C9wsyxWgqF3cI=` — different zip hash from the
private module, so public-fork source is *corroborating*, not byte-identical,
evidence; the definitive evidence for the live code is the binary itself).

## 3. Guard strings compiled into the live binary

`grep -a` over the exact live binary finds each of these once (code strings, not
dead data — they are the panic/error literals of the guards):

| Occurrences | String | Meaning |
|---|---|---|
| 1 | `state balance underflow for %s` | SubBalance underflow guard (upstream #1176) |
| 1 | `state balance overflow for %s` | AddBalance overflow guard (KiiChain fork, added 2026-08-24) |
| 1 | `cannot deploy EVM contract on top of non-base account` | CreateAccount guard `IsBaseAccountOrEmpty` (KiiChain fork) |
| 1 | `vesting account creation is disabled` | ante decorator rejecting all vesting-create msgs |
| 1 | `Enabling bank send restriction for incident addresses` | recovery blocklist activation log |
| 1 | `EMERGENCY FIX: starting funds recovery` | v7.4.0 upgrade recovery log |
| 2 | `IsBaseAccountOrEmpty` | keeper interface method name |
| 1 | `failed to mint to blocked address` / `failed to burn from blocked address` | tokenfactory module-account block (pre-existing) |

## 4. Public fork commit trail (github.com/KiiChain/evm)

| Date (UTC) | Commit | Message |
|---|---|---|
| 2026-07-15 | `d465850e40` | fix(statedb): snapshot locked balance on statedb account (backport #1187) |
| 2026-08-21 | `7876b83cad` | fix: harden statedb balance and event amount handling (backport #1176) (#1253) |
| 2026-08-24 | `27fe1aa3b0` | fix: implement overflow handling in AddBalance and add corresponding tests |
| 2026-08-24 | `8f31a33939` | feat: add IsBaseAccountOrEmpty method to EVMKeeper and VMKeeper interfaces… |

The two 2026-08-24 commits are KiiChain's own hardening beyond the upstream
patch — they fix exactly the two defect classes KiiChain publicly said were
"still unfixed upstream". The live v7.4.2 binary (built 2026-09-10) contains
both.

## 5. Upstream comparison (cosmos/evm)

- v0.6.1 → v0.6.2 (`x/vm/statedb/state_object.go`): adds `SubBalance` underflow
  panic; nothing else in that file.
- v0.6.2 → KiiChain fork (`state_object.go`): adds `AddOverflow` panic in
  `AddBalance`.
- v0.6.2 → KiiChain fork (`statedb.go`): adds
  `if !s.keeper.IsBaseAccountOrEmpty(...) { panic(...) }` at the top of
  `CreateAccount`, plus atomic commit staging (`CacheContext` + precompile-cache
  fold) — the fork is materially stricter than upstream.

Files: `analysis/raw/buildinfo.txt`, `analysis/raw/kii-v7.4.0.mod`.
