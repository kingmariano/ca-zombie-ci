/**
 * SuiDex (C2-52) devInspect battery — READ-ONLY dry-run simulations. No tx signed/sent.
 *
 * Proves, against live state:
 *  - unprivileged attacker cannot claim SUI/VICTORY for any lock they do not own (abort ELOCK_NOT_FOUND=4)
 *  - double-claim replay for an already-claimed (user,epoch,lock) aborts EALREADY_CLAIMED=9
 *  - a real eligible holder claim succeeds and pays exactly floor(amount*pool_sui/pool_total_staked)
 *  - a real matured lock unlocks its own VICTORY (self-service)
 *  - a lock that was unlocked (removed) cannot claim any epoch (forfeited remainder)
 *
 * Candidates are selected dynamically from the fresh scans (locks_state.json / claims_keys.json /
 * epochs_state.json) so the battery adapts if a holder claims between scan and run.
 *
 * Usage: node devinspect_tests.mjs   (env: SUI_RPC_URL, SUIDEX_DATA_DIR, SUIDEX_OUT)
 */
import { SuiClient } from '@mysten/sui/client';
import { Transaction } from '@mysten/sui/transactions';
import fs from 'node:fs';
import path from 'node:path';

const RPC_LIST = [process.env.SUI_RPC_URL, 'https://sui-rpc.publicnode.com', 'https://rpc-mainnet.suiscan.xyz',
  'https://sui.blockpi.network/v1/rpc/public', 'https://1rpc.io/sui',
  'https://sui-mainnet-endpoint.blockvision.org', 'https://sui.api.onfinality.io/public',
  'https://mainnet.sui.rpcpool.com'].filter(Boolean);
const DATA = process.env.SUIDEX_DATA_DIR || '/home/heisenberg/CA/suidex/analysis';
const OUT = process.env.SUIDEX_OUT || path.join(DATA, 'devinspect_results.json');

const PKG = '0xbfac5e1c6bf6ef29b12f7723857695fd2f4da9a11a7d88162c15e9124c243a4a';
const LOCKER = '0xb604843d501173f9ea0762fbaa7cadaea3454c942deb527cb8905861ce39798b';
const SUI_VAULT = '0xd781268befec0270299d5089f182d8c1f1caed15f8b7db3fa1a267b73e89ce9f';
const VIC_VAULT = '0xb70212065c2af0107a799517517e9170fcd38211aaa66f0ebc5a764d0506e2cc';
const LOCKED_VAULT = '0x3632b8acce355fc8237998d44f1a68e58baac95f199714cdef5736d580dc6bf1';
const CONFIG = '0xfbd4d5f644cc82e7486ceb048b8951a6efffe39254a6646d99f0ea6b81b5c5f4';
const CLOCK = '0x6';
const ATTACKER = '0x0000000000000000000000000000000000000000000000000000000000c0ffee';

const clients = RPC_LIST.map(url => ({ url, client: new SuiClient({ url }) }));
const sleep = ms => new Promise(r => setTimeout(r, ms));

async function devInspectWithRetry(sender, tx) {
  let lastErr = null;
  for (let i = 0; i < clients.length * 3; i++) {
    const { client } = clients[i % clients.length];
    try {
      return await client.devInspectTransactionBlock({ sender, transactionBlock: tx });
    } catch (e) {
      lastErr = e;
      const msg = String(e?.message || e);
      if (!/429|Too Many|Unexpected status|fetch failed|ECONN|timeout|503|502|500/i.test(msg)) throw e;
      await sleep(Math.min(1000 * 2 ** i, 15000));
    }
  }
  throw lastErr || new Error('devInspect failed on all endpoints');
}

// ---------- candidate selection from fresh scans ----------
const locks = JSON.parse(fs.readFileSync(path.join(DATA, 'locks_state.json'), 'utf8'));
const claims = JSON.parse(fs.readFileSync(path.join(DATA, 'claims_keys.json'), 'utf8'));
const epochs = JSON.parse(fs.readFileSync(path.join(DATA, 'epochs_state.json'), 'utf8'));

const claimedSet = new Set();
const claimedPairs = [];
for (const u of claims.users) {
  for (const k of u.keys) {
    claimedSet.add(`${u.user.toLowerCase()}|${k.epoch_id}|${k.lock_id}`);
    claimedPairs.push({ user: u.user, epoch: Number(k.epoch_id), lock: Number(k.lock_id) });
  }
}
const activeSet = new Set();
for (const [user, per] of Object.entries(locks.users)) {
  for (const lks of Object.values(per)) for (const lk of lks) activeSet.add(`${user.toLowerCase()}|${lk.id}`);
}

const POOLS = {
  week_pool_sui: [7, 'week_pool_claimed', 'week_pool_total_staked'],
  three_month_pool_sui: [90, 'three_month_pool_claimed', 'three_month_pool_total_staked'],
  year_pool_sui: [365, 'year_pool_claimed', 'year_pool_total_staked'],
  three_year_pool_sui: [1095, 'three_year_pool_claimed', 'three_year_pool_total_staked'],
};
const rem = new Map();
for (const e of epochs.epochs) {
  const ws = Number(e.week_start || 0), we = Number(e.week_end || 0);
  if (!ws) continue;
  for (const [ak, [p, ck, sk]] of Object.entries(POOLS)) {
    const a = BigInt(e.alloc[ak] || 0), c = BigInt(e.claimed[ck] || 0);
    if (a - c > 0n) rem.set(`${e.epoch_id}|${p}`, { eid: Number(e.epoch_id), period: p, ws, we, remaining: a - c, poolSui: a, staked: BigInt(e.alloc[sk] || 0) });
  }
}

let best = null;
for (const [user, per] of Object.entries(locks.users)) {
  const ua = user.toLowerCase();
  for (const lks of Object.values(per)) for (const lk of lks) {
    const p = Number(lk.lock_period), ts = Number(lk.stake_timestamp), le = Number(lk.lock_end);
    const lid = Number(lk.id), amt = BigInt(lk.amount);
    for (const v of rem.values()) {
      if (v.period !== p || !(ts < v.ws && le >= v.we)) continue;
      if (claimedSet.has(`${ua}|${v.eid}|${lid}`)) continue;
      const share = v.staked > 0n ? (amt * v.poolSui) / v.staked : 0n;
      if (share <= 0n) continue;
      if (!best || share > best.share) best = { user, ua, lock: lid, period: p, epoch: v.eid, share, amount: lk.amount, poolSui: v.poolSui.toString(), staked: v.staked.toString(), remaining: v.remaining.toString() };
    }
  }
}
let replay = claimedPairs.find(c => activeSet.has(`${c.user.toLowerCase()}|${c.lock}`)) || null;
let removed = null;
outer: for (const c of claimedPairs) {
  if (activeSet.has(`${c.user.toLowerCase()}|${c.lock}`)) continue;
  for (let e = 34; e >= 1; e--) {
    if (!claimedSet.has(`${c.user.toLowerCase()}|${e}|${c.lock}`)) { removed = { user: c.user, lock: c.lock, epoch: e }; break outer; }
  }
}
console.log('candidate holder:', best && JSON.stringify({ user: best.user, lock: best.lock, epoch: best.epoch, period: best.period, expectedShare: best.share.toString() }));
console.log('candidate replay:', replay && JSON.stringify(replay), '| removed:', removed && JSON.stringify(removed));

// ---------- battery ----------
async function run(name, sender, build) {
  const tx = new Transaction();
  tx.setSender(sender);
  build(tx);
  try {
    const res = await devInspectWithRetry(sender, tx);
    const status = res.effects?.status?.status;
    const err = res.effects?.status?.error || res.error || null;
    const m = err ? /},\s*(\d+)\)/s.exec(err) : null;
    const fn = err ? /function_name: Some\("([^"]+)"\)/.exec(err) : null;
    const rets = (res.results || []).map(r => (r.returnValues || []).map(v => Buffer.from(v[0], 'base64').toString('hex')));
    return {
      name, sender, status,
      abortCode: m ? parseInt(m[1]) : null,
      abortFunction: fn ? fn[1] : null,
      error: err,
      returnValuesHex: rets.length ? rets : null,
      events: (res.events || []).map(e => ({ type: e.type.split('::').slice(2).join('::'), json: e.parsedJson })),
    };
  } catch (e) {
    return { name, sender, status: 'rpc-error', error: String(e?.message || e) };
  }
}

const results = [];
const push = r => { results.push(r); console.log(JSON.stringify({ name: r.name, status: r.status, abortCode: r.abortCode, abortFunction: r.abortFunction, err: r.error ? r.error.slice(0, 160) : null, events: r.events?.map(e => e.json) })); };

const L = best ? best.lock : 1010, E = best ? best.epoch : 18, P = best ? best.period : 90;

push(await run('T1_attacker_claim_sui_nonexistent_lock', ATTACKER, tx => {
  tx.moveCall({ target: `${PKG}::victory_token_locker::claim_pool_sui_rewards`,
    arguments: [tx.object(LOCKER), tx.object(SUI_VAULT), tx.pure.u64(E), tx.pure.u64(1), tx.object(CONFIG), tx.object(CLOCK)] });
}));
push(await run('T2_attacker_claim_sui_foreign_lock', ATTACKER, tx => {
  tx.moveCall({ target: `${PKG}::victory_token_locker::claim_pool_sui_rewards`,
    arguments: [tx.object(LOCKER), tx.object(SUI_VAULT), tx.pure.u64(E), tx.pure.u64(L), tx.object(CONFIG), tx.object(CLOCK)] });
}));
push(await run('T3_attacker_claim_victory_foreign_lock', ATTACKER, tx => {
  tx.moveCall({ target: `${PKG}::victory_token_locker::claim_victory_rewards`,
    arguments: [tx.object(LOCKER), tx.object(VIC_VAULT), tx.object(CONFIG), tx.pure.u64(L), tx.pure.u64(P), tx.object(CLOCK)] });
}));
push(await run('T4_attacker_unlock_foreign_lock', ATTACKER, tx => {
  tx.moveCall({ target: `${PKG}::victory_token_locker::unlock_tokens`,
    arguments: [tx.object(LOCKER), tx.object(LOCKED_VAULT), tx.object(VIC_VAULT), tx.object(SUI_VAULT), tx.object(CONFIG), tx.pure.u64(L), tx.pure.u64(P), tx.object(CLOCK)] });
}));
push(await run('T5_attacker_batch_claim_foreign_lock', ATTACKER, tx => {
  tx.moveCall({ target: `${PKG}::victory_token_locker::batch_claim_epochs_for_lock`,
    arguments: [tx.object(LOCKER), tx.object(SUI_VAULT), tx.pure.u64(L), tx.pure('vector<u64>', [Math.max(1, E - 1), E]), tx.object(CONFIG), tx.object(CLOCK)] });
}));
if (best) {
  push(await run('T6_holder_claim_sui_positive', best.user, tx => {
    tx.moveCall({ target: `${PKG}::victory_token_locker::claim_pool_sui_rewards`,
      arguments: [tx.object(LOCKER), tx.object(SUI_VAULT), tx.pure.u64(E), tx.pure.u64(L), tx.object(CONFIG), tx.object(CLOCK)] });
  }));
}
if (replay) {
  push(await run('T7_double_claim_replay_already_claimed', replay.user, tx => {
    tx.moveCall({ target: `${PKG}::victory_token_locker::claim_pool_sui_rewards`,
      arguments: [tx.object(LOCKER), tx.object(SUI_VAULT), tx.pure.u64(replay.epoch), tx.pure.u64(replay.lock), tx.object(CONFIG), tx.object(CLOCK)] });
  }));
}
if (best) {
  push(await run('T8_holder_can_user_claim_epoch_view', best.user, tx => {
    tx.moveCall({ target: `${PKG}::victory_token_locker::can_user_claim_epoch`,
      arguments: [tx.object(LOCKER), tx.pure.address(best.user), tx.pure.u64(E), tx.pure.u64(L), tx.object(CLOCK)] });
  }));
  push(await run('T9_holder_claim_victory_positive', best.user, tx => {
    tx.moveCall({ target: `${PKG}::victory_token_locker::claim_victory_rewards`,
      arguments: [tx.object(LOCKER), tx.object(VIC_VAULT), tx.object(CONFIG), tx.pure.u64(L), tx.pure.u64(P), tx.object(CLOCK)] });
  }));
  push(await run('T10_holder_unlock_matured_lock', best.user, tx => {
    tx.moveCall({ target: `${PKG}::victory_token_locker::unlock_tokens`,
      arguments: [tx.object(LOCKER), tx.object(LOCKED_VAULT), tx.object(VIC_VAULT), tx.object(SUI_VAULT), tx.object(CONFIG), tx.pure.u64(L), tx.pure.u64(P), tx.object(CLOCK)] });
  }));
}
if (removed) {
  push(await run('T11_removed_lock_claim_forfeited', removed.user, tx => {
    tx.moveCall({ target: `${PKG}::victory_token_locker::claim_pool_sui_rewards`,
      arguments: [tx.object(LOCKER), tx.object(SUI_VAULT), tx.pure.u64(removed.epoch), tx.pure.u64(removed.lock), tx.object(CONFIG), tx.object(CLOCK)] });
  }));
}

// decode T8 view return (bool, String)
const t8 = results.find(r => r.name.startsWith('T8'));
if (t8?.returnValuesHex?.[0]?.length) {
  const boolBuf = Buffer.from(t8.returnValuesHex[0][0], 'hex');
  let message = null;
  if (t8.returnValuesHex[0][1]) {
    const sBuf = Buffer.from(t8.returnValuesHex[0][1], 'hex');
    let len = 0, shift = 0, i = 0;
    while (i < sBuf.length) { const b = sBuf[i++]; len |= (b & 0x7f) << shift; if (!(b & 0x80)) break; shift += 7; }
    message = sBuf.slice(i, i + len).toString('utf8');
  }
  t8.decoded = { canClaim: boolBuf[0] === 1, message };
  console.log('T8 decoded:', JSON.stringify(t8.decoded));
}

const out = {
  rpc: RPC_LIST[0], timestamp: new Date().toISOString(),
  objects: { package: PKG, locker: LOCKER, sui_vault: SUI_VAULT, victory_vault: VIC_VAULT, locked_vault: LOCKED_VAULT, config: CONFIG },
  candidate: best ? { user: best.user, lock: best.lock, epoch: best.epoch, period: best.period, expectedShare: best.share.toString(), poolSui: best.poolSui, totalStaked: best.staked } : null,
  replay_candidate: replay, removed_candidate: removed,
  results,
};
fs.writeFileSync(OUT, JSON.stringify(out, null, 1));
console.log('WROTE', OUT);

// ---------- hard assertions: CI fails if any gate expectation breaks ----------
const byName = n => results.find(r => r.name.startsWith(n));
const expect = (cond, msg) => { if (!cond) { console.error('ASSERT FAILED:', msg); process.exitCode = 1; } };
for (const t of ['T1', 'T2', 'T3', 'T4', 'T5', 'T11']) {
  const r = byName(t);
  if (!r) continue;
  expect(r.status === 'failure' && r.abortCode === 4, `${t}: expected abort 4 (ELOCK_NOT_FOUND), got ${r.status}/${r.abortCode}`);
}
if (best) {
  expect(byName('T6')?.status === 'success', 'T6 holder claim must succeed');
  const t6ev = byName('T6')?.events?.find(e => e.json?.sui_claimed);
  expect(t6ev && String(t6ev.json.sui_claimed) === best.share.toString(), `T6 payout ${t6ev?.json?.sui_claimed} != expected ${best.share}`);
  expect(byName('T9')?.status === 'success', 'T9 victory claim must succeed');
  expect(byName('T10')?.status === 'success', 'T10 unlock must succeed');
}
if (replay) expect(byName('T7')?.abortCode === 9, 'T7 replay must abort 9 (EALREADY_CLAIMED)');
console.log(process.exitCode ? 'BATTERY: FAILED' : 'BATTERY: ALL EXPECTATIONS PASS');
