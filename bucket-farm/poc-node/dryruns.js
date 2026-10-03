/* Bucket Farm (Sui) — read-only dry-run proof suite.
 *
 * Every test uses `sui_dryRunTransactionBlock` only: no signature, no submission,
 * no state change. The sender/gas coin is the protocol deployer's public address.
 * All hot-potato results are consumed so the target function actually executes.
 *
 * Proven here:
 *   0) probe: dry-run pipeline works
 *   1) dispose: a `Sheet` (store, no drop) can be neutralised via dynamic_field + object::delete
 *   2) over-unstake: stake 1 SUI then unstake 2 SUI -> aborts stake::err_not_enough_to_unstake
 *   3) no-stake unstake -> aborts point::err_account_not_found
 *   4) v7-created StakeResponse fed to v1 pool::loan_by_stake_res -> InvalidLinkage
 *   5) v7 loan_by_stake_res with an unknown debtor type (bool) -> aborts err_invalid_debtor
 */
const { SuiClient } = require('@mysten/sui/client');
const { Transaction } = require('@mysten/sui/transactions');

const ENDPOINTS = [
  process.env.SUI_RPC,
  'https://sui.blockpi.network/v1/rpc/public',
  'https://sui-rpc.publicnode.com',
  'https://sui-mainnet.nodeinfra.com',
].filter(Boolean);

const FARM_V1 = '0x0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23';
const FARM_V7 = '0xf62488082fb7ad62c92d66c26b587728e987f160413b6b8aafe169d0c423098c';
const FLOAT_V1 = '0xa90218c8ec02c619b2b4db3e3d32cfeb5c1cf762879ef75bae9f27020751d0f8';
const FLOAT_V4 = '0xd2b2de20b6744388545eec928259eeed351cd6b347963ad569c68a7272a04b35';
const DROP = '0x1d627cecd34128bd6fe5a067a3a590d0f62fa514fe19d2a20a31205e3d51ea55::drop::DROP';
const SUI = '0x2::sui::SUI';
const POOL_SUI = '0xab90d38384dfaf833c57ce7802d2f87efd286ffa8dddf5474323dc2f2e20f052';
const CENTER = '0xc60fb4131a47aa52ac27fe5b6f9613ffe27832c5f52d27755511039d53908217';
const CLOCK = '0x6';
const SENDER = process.env.SENDER || '0xa7caa2a3e8d4dc1d35297ce32e46c4b05fa990968384cad74571c983ad6e598a';
const DEGEN_POOL_DROP = `${FARM_V1}::pool::DEGEN_POOL<${DROP}>`;
const LOAN_BOOL = `${FLOAT_V1}::sheet::Loan<${DEGEN_POOL_DROP}, bool, ${SUI}>`;

let client = null;
let GAS = null;
async function connect() {
  if (client) return client;
  for (const url of ENDPOINTS) {
    try {
      const c = new SuiClient({ url });
      await c.getLatestCheckpointSequenceNumber();
      console.log('# using Sui RPC:', url);
      client = c;
      return c;
    } catch (e) {
      console.log('# endpoint failed:', url, String(e.message || e).slice(0, 80));
    }
  }
  throw new Error('no working Sui RPC endpoint');
}
async function gasCoin() {
  if (GAS) return GAS;
  const coins = await client.getCoins({ owner: SENDER, coinType: SUI });
  if (!coins.data.length) throw new Error('no gas coins for ' + SENDER);
  GAS = coins.data.find((x) => BigInt(x.balance) > 2_000_000_000n) || coins.data[0];
  return GAS;
}
async function run(tx, label, expect) {
  tx.setSender(SENDER);
  const g = await gasCoin();
  tx.setGasPayment([{ objectId: g.coinObjectId, version: g.version, digest: g.digest }]);
  tx.setGasBudget(400_000_000n);
  const bytes = await tx.build({ client });
  const res = await client.dryRunTransactionBlock({ transactionBlock: bytes });
  const status = JSON.stringify(res.effects?.status);
  const ok = expect ? status.includes(expect) : status.includes('"success"');
  console.log(`\n[${ok ? 'PASS' : 'FAIL'}] ${label}`);
  console.log(`      expected: ${expect || 'success'}`);
  console.log(`      got     : ${status}`);
  return res;
}
function stakeFlow(tx, amount) {
  const acct = tx.moveCall({ target: `${FLOAT_V4}::account::request`, arguments: [] });
  const req = tx.moveCall({ target: `${FARM_V7}::pool::request_stake`, typeArguments: [DROP, SUI], arguments: [tx.object(POOL_SUI), acct, tx.pure.u64(amount)] });
  const wrapped = tx.moveCall({ target: `${FARM_V7}::wrapper::wrap_stake_request`, typeArguments: [DROP, SUI], arguments: [req] });
  const [coin] = tx.splitCoins(tx.gas, [amount]);
  const resp = tx.moveCall({ target: `${FARM_V7}::wrapper::fulfill_stake`, typeArguments: [DROP, SUI], arguments: [tx.object(POOL_SUI), wrapped, coin] });
  tx.moveCall({ target: `${FARM_V7}::point::fulfill_stake`, typeArguments: [DROP], arguments: [tx.object(CENTER), tx.object(CLOCK), resp] });
}

(async () => {
  const which = process.argv[2] || 'all';
  const doAll = which === 'all';
  await connect();
  try {
    if (doAll || which === '0') {
      const tx = new Transaction();
      const [c] = tx.splitCoins(tx.gas, [1_000n]);
      tx.transferObjects([c], SENDER);
      await run(tx, '0) probe: dry-run pipeline', 'success');
    }
    if (doAll || which === '1') {
      const tx = new Transaction();
      const sheet = tx.moveCall({ target: `${FLOAT_V1}::sheet::new`, typeArguments: ['bool', SUI], arguments: [tx.pure.bool(true)] });
      const uid = tx.moveCall({ target: '0x2::object::new', arguments: [] });
      tx.moveCall({ target: '0x2::dynamic_field::add', typeArguments: ['bool', `${FLOAT_V1}::sheet::Sheet<bool, ${SUI}>`], arguments: [uid, tx.pure.bool(true), sheet] });
      tx.moveCall({ target: '0x2::object::delete', arguments: [uid] });
      await run(tx, '1) dispose Sheet via dynamic_field+object::delete', 'success');
    }
    if (doAll || which === '2') {
      const tx = new Transaction();
      stakeFlow(tx, 1_000_000_000n);
      const acct = tx.moveCall({ target: `${FLOAT_V4}::account::request`, arguments: [] });
      const req = tx.moveCall({ target: `${FARM_V7}::pool::request_unstake`, typeArguments: [DROP, SUI], arguments: [tx.object(POOL_SUI), acct, tx.pure.u64(2_000_000_000n)] });
      const wrapped = tx.moveCall({ target: `${FARM_V7}::wrapper::wrap_unstake_request`, typeArguments: [DROP, SUI], arguments: [req] });
      const [coin, resp] = tx.moveCall({ target: `${FARM_V7}::wrapper::fulfill_unstake`, typeArguments: [DROP, SUI], arguments: [tx.object(POOL_SUI), wrapped] });
      tx.transferObjects([coin], SENDER);
      tx.moveCall({ target: `${FARM_V7}::point::fulfill_unstake`, typeArguments: [DROP], arguments: [tx.object(CENTER), tx.object(CLOCK), resp] });
      await run(tx, '2) stake 1 SUI then unstake 2 SUI', 'err_not_enough_to_unstake');
    }
    if (doAll || which === '3') {
      const tx = new Transaction();
      const acct = tx.moveCall({ target: `${FLOAT_V4}::account::request`, arguments: [] });
      const req = tx.moveCall({ target: `${FARM_V7}::pool::request_unstake`, typeArguments: [DROP, SUI], arguments: [tx.object(POOL_SUI), acct, tx.pure.u64(1_000_000_000n)] });
      const wrapped = tx.moveCall({ target: `${FARM_V7}::wrapper::wrap_unstake_request`, typeArguments: [DROP, SUI], arguments: [req] });
      const [coin, resp] = tx.moveCall({ target: `${FARM_V7}::wrapper::fulfill_unstake`, typeArguments: [DROP, SUI], arguments: [tx.object(POOL_SUI), wrapped] });
      tx.transferObjects([coin], SENDER);
      tx.moveCall({ target: `${FARM_V7}::point::fulfill_unstake`, typeArguments: [DROP], arguments: [tx.object(CENTER), tx.object(CLOCK), resp] });
      await run(tx, '3) unstake with no stake at all', 'err_account_not_found');
    }
    if (doAll || which === '4') {
      const tx = new Transaction();
      const acct = tx.moveCall({ target: `${FLOAT_V4}::account::request`, arguments: [] });
      const req = tx.moveCall({ target: `${FARM_V7}::pool::request_stake`, typeArguments: [DROP, SUI], arguments: [tx.object(POOL_SUI), acct, tx.pure.u64(1_000_000_000n)] });
      const wrapped = tx.moveCall({ target: `${FARM_V7}::wrapper::wrap_stake_request`, typeArguments: [DROP, SUI], arguments: [req] });
      const [coin] = tx.splitCoins(tx.gas, [1_000_000_000n]);
      const resp = tx.moveCall({ target: `${FARM_V7}::wrapper::fulfill_stake`, typeArguments: [DROP, SUI], arguments: [tx.object(POOL_SUI), wrapped, coin] });
      tx.moveCall({ target: `${FARM_V1}::pool::loan_by_stake_res`, typeArguments: [DROP, SUI, 'bool'], arguments: [tx.object(POOL_SUI), resp] });
      await run(tx, '4) v7-created StakeResponse -> v1 pool::loan_by_stake_res', 'InvalidLinkage');
    }
    if (doAll || which === '5') {
      const tx = new Transaction();
      const acct = tx.moveCall({ target: `${FLOAT_V4}::account::request`, arguments: [] });
      const req = tx.moveCall({ target: `${FARM_V7}::pool::request_stake`, typeArguments: [DROP, SUI], arguments: [tx.object(POOL_SUI), acct, tx.pure.u64(1_000_000_000n)] });
      const wrapped = tx.moveCall({ target: `${FARM_V7}::wrapper::wrap_stake_request`, typeArguments: [DROP, SUI], arguments: [req] });
      const [coin] = tx.splitCoins(tx.gas, [1_000_000_000n]);
      const resp = tx.moveCall({ target: `${FARM_V7}::wrapper::fulfill_stake`, typeArguments: [DROP, SUI], arguments: [tx.object(POOL_SUI), wrapped, coin] });
      const loanOpt = tx.moveCall({ target: `${FARM_V7}::pool::loan_by_stake_res`, typeArguments: [DROP, SUI, 'bool'], arguments: [tx.object(POOL_SUI), resp] });
      tx.moveCall({ target: '0x1::option::destroy_none', typeArguments: [LOAN_BOOL], arguments: [loanOpt] });
      tx.moveCall({ target: `${FARM_V7}::point::fulfill_stake`, typeArguments: [DROP], arguments: [tx.object(CENTER), tx.object(CLOCK), resp] });
      await run(tx, '5) v7 loan_by_stake_res with unknown debtor (bool)', 'err_invalid_debtor');
    }
  } catch (e) {
    console.error('FATAL', e.message);
    process.exit(1);
  }
})();
