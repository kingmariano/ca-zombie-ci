// Swirl stIOTA (C2-45) — READ-ONLY devInspect proofs on IOTA mainnet.
// Uses the public keyless RPC. Never signs or submits a transaction.
import fs from 'node:fs';
import path from 'node:path';
import { IotaClient } from '@iota/iota-sdk/client';
import { Transaction } from '@iota/iota-sdk/transactions';

const RPC = process.env.IOTA_RPC || 'https://api.mainnet.iota.cafe';
const OUT = path.resolve(process.cwd(), 'ci-out');
fs.mkdirSync(OUT, { recursive: true });

// ---- live target constants (verified locally) ----
const ORIG_PKG = '0x346778989a9f57480ec3fee15f2cd68409c73a62112d40a3efd13987997be68c';
const PKG      = '0xa38a034356187b52c603282198fc831f0f710e16a61b141986697372ef16b292'; // v9 (live)
const POOL     = '0x02d641d7b021b1cd7a2c361ac35b415ae8263be0641f9475ec32af4b9d8a8056';
const SYS      = '0x5';   // 0x3::iota_system::IotaSystemState
const CLOCK    = '0x6';
const META     = '0x8c25ec843c12fbfddc7e25d66869f8639e20021758cac1a3db0f6de3c9fda2ed'; // Metadata<CERT>
const OWNER_CAP = '0x024b8ee182db98e727c4ceca0c5c7202e92933dd96d2a92c38a28eaecb632f52';
const OPER_CAP  = '0xa78c4b44ea49620200994ba70712074e73675c4bb64989f35bb09dae6f178a5e';
const BAD_VALIDATOR  = '0xd7a5275f14f5297774fdd93cb5691045b38dab9f0a1870f5a1da79706b9d69e2'; // priority 0
const GOOD_VALIDATOR = '0xc978b43ab25813795d1513b3424e59105a5a44df45d0e42ffaf1be43c483145f';
// unprivileged random sender (no caps, no stake)
const SENDER = '0x' + '11'.repeat(32);

const client = new IotaClient({ url: RPC });
const results = { rpc: RPC, sender: SENDER, ts: new Date().toISOString(), tests: {} };
const log = (...a) => { console.log(...a); };

async function jget(method, params) {
  const r = await fetch(RPC, { method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }) });
  const j = await r.json();
  if (j.error) throw new Error(method + ': ' + JSON.stringify(j.error));
  return j.result;
}

function errStr(e) { return (e && (e.message || String(e))).slice(0, 500); }

async function devInspect(name, buildFn) {
  try {
    const tx = new Transaction();
    buildFn(tx);
    const res = await client.devInspectTransactionBlock({ sender: SENDER, transactionBlock: tx });
    // summarize effects
    const status = res?.effects?.status ?? res?.effects?.status;
    const out = {
      ok: true,
      status: status ?? null,
      gasUsed: res?.effects?.gasUsed ?? null,
      error: res?.error ?? null,
      events: (res?.events || []).map(e => ({ type: e.type, parsed: e.parsedJson })),
      effectsKeys: res?.effects ? Object.keys(res.effects) : [],
    };
    results.tests[name] = out;
    log(`[devInspect] ${name}: ok=${out.ok} status=${JSON.stringify(out.status)} err=${out.error}`);
    return out;
  } catch (e) {
    const out = { ok: false, thrown: errStr(e) };
    results.tests[name] = out;
    log(`[devInspect] ${name}: THREW ${out.thrown}`);
    return out;
  }
}

async function main() {
  // ---------- 0) live state dump ----------
  const state = {};
  try {
    state.pool = (await jget('iota_getObject', [POOL, { showType: true, showContent: true, showOwner: true }])).data;
    state.metadata = (await jget('iota_getObject', [META, { showType: true, showContent: true }])).data;
    state.ownerCap = (await jget('iota_getObject', [OWNER_CAP, { showType: true, showOwner: true }])).data;
    state.operatorCap = (await jget('iota_getObject', [OPER_CAP, { showType: true, showOwner: true }])).data;
    state.epoch = (await jget('iotax_getLatestIotaSystemState', [])).epoch;
    state.checkpoint = await jget('iota_getLatestCheckpointSequenceNumber', []);
    const vsUid = state.pool.content.fields.validator_set.fields.id.id;
    const vtable = state.pool.content.fields.validator_set.fields.vaults.fields.id.id;
    state.validatorSetUid = vsUid;
    const df = await jget('iotax_getDynamicFields', [vtable, null, 50]);
    state.vaults = [];
    for (const f of df.data) {
      const v = (await jget('iota_getObject', [f.objectId, { showContent: true }])).data;
      const vf = v.content.fields.value.fields;
      state.vaults.push({
        validator: f.name.value,
        vaultObject: f.objectId,
        totalStaked: vf.total_staked,
        stakeEpoch: vf.stake_epoch,
        stakedInEpoch: vf.staked_in_epoch,
        nStakes: vf.stakes.fields.size,
      });
    }
    const pf = state.pool.content.fields;
    state.summary = {
      totalStaked: pf.total_staked,
      totalRewards: pf.total_rewards,
      pending: pf.pending,
      collectableFee: pf.collectable_fee,
      paused: pf.paused,
      protocolVersion: pf.version,
      maxValidatorStakePerEpoch: pf.max_validator_stake_per_epoch,
      minStake: pf.min_stake,
      rewardsThreshold: pf.rewards_threshold,
      certSupply: state.metadata.content.fields.total_supply.fields.value,
      ratioSharesPerIota1e18:
        (BigInt(state.metadata.content.fields.total_supply.fields.value) * 10n ** 18n /
         (BigInt(pf.total_staked) + BigInt(pf.total_rewards))).toString(),
    };
  } catch (e) {
    state.error = errStr(e);
  }
  fs.writeFileSync(path.join(OUT, 'state.json'), JSON.stringify(state, null, 2));

  // ---------- 1) rebalance (cap-less, public entry) ----------
  await devInspect('rebalance_public_no_cap', tx => {
    tx.moveCall({ target: `${PKG}::native_pool::rebalance`, arguments: [tx.object(POOL), tx.object(SYS)] });
  });

  // ---------- 2) rebalance_from_validator on BAD validator (cap-less) ----------
  await devInspect('rebalance_from_validator_bad', tx => {
    tx.moveCall({ target: `${PKG}::native_pool::rebalance_from_validator`,
      arguments: [tx.object(POOL), tx.object(SYS), tx.pure.address(BAD_VALIDATOR), tx.pure.u64(1_000_000_000n)] });
  });

  // ---------- 3) rebalance_from_validator on GOOD validator -> expect abort 112 ----------
  await devInspect('rebalance_from_validator_good_must_abort', tx => {
    tx.moveCall({ target: `${PKG}::native_pool::rebalance_from_validator`,
      arguments: [tx.object(POOL), tx.object(SYS), tx.pure.address(GOOD_VALIDATOR), tx.pure.u64(1_000_000_000n)] });
  });

  // ---------- 4) rabalance_overstaked (cap-less) -> expected no-op today ----------
  await devInspect('rabalance_overstaked_public', tx => {
    tx.moveCall({ target: `${PKG}::native_pool::rabalance_overstaked`, arguments: [tx.object(POOL), tx.object(SYS)] });
  });

  // ---------- 5) collect_fee from unprivileged sender (OwnerCap owned by 0x1191..) ----------
  await devInspect('collect_fee_no_cap', tx => {
    tx.moveCall({ target: `${PKG}::native_pool::collect_fee`,
      arguments: [tx.object(POOL), tx.pure.address(SENDER), tx.object(OWNER_CAP)] });
  });

  // ---------- 6) unstake round-trip math (static, from live ratio) ----------
  try {
    const S = BigInt(state.summary.certSupply);
    const N = BigInt(state.summary.totalStaked) + BigInt(state.summary.totalRewards);
    const r = S * 10n ** 18n / N;
    const cases = [1_000_000_000n, 10n ** 12n, 10n ** 15n, 10n ** 17n];
    results.roundTrip = cases.map(C => {
      const shares = C * r / 10n ** 18n;
      const back = shares * 10n ** 18n / r;
      return { C: C.toString(), shares: shares.toString(), back: back.toString(), gain: (back - C).toString() };
    });
  } catch (e) { results.roundTrip = { error: errStr(e) }; }

  // pending-exclusion theoretical cap: X^2/(4N)
  try {
    const N = BigInt(state.summary.totalStaked) + BigInt(state.summary.totalRewards);
    const X = BigInt('1948434338000000'); // bad-validator stake (IOTA nanos, at snapshot)
    results.pendingExclusionBoundNanos = ((X * X) / (4n * N)).toString();
  } catch (e) { results.pendingExclusionBoundNanos = errStr(e); }

  fs.writeFileSync(path.join(OUT, 'dryrun_results.json'), JSON.stringify(results, null, 2));
  log('[swirl-ci] results written to ci-out/dryrun_results.json');
}

main().catch(e => { console.error('FATAL', e); process.exit(1); });
