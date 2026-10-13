# PoC location

The exploit PoC for this finding is **fork-based**, not a Foundry unit test: zkSync Era executes
EraVM bytecode, which stock `forge`/`revm` cannot run. Instead we fork zkSync Era mainnet with
**anvil-zksync** and execute the real deployed bytecode.

* Driver: `../ci/fork_test.py` (T1 legacy-gauge `distribute`, T2 full attack chain, T3 `skim`)
* Runner: `../ci/run.sh` (downloads anvil-zksync v0.7.1, forks with the keyless public zkSync RPC,
  runs the three tests on fresh forks, writes `../ci-out/fork-results.json`)

Run locally:

```bash
bash ci/run.sh          # from the velocore-v1 folder
```

No mainnet transactions are sent. Fork cheats (storage write for attacker VC, account impersonation
for token funding) simulate attacker capital only; every protocol interaction is real mainnet code.
