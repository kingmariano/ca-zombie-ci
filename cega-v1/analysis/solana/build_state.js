'use strict';
// Build the consolidated state.json for Cega V1 Solana analysis.
const fs = require('fs');
const path = require('path');
const D = __dirname;
const dec = JSON.parse(fs.readFileSync(path.join(D, 'decoded_state.json'), 'utf8'));
const bal = JSON.parse(fs.readFileSync(path.join(D, 'token_balances.json'), 'utf8'));
const act = JSON.parse(fs.readFileSync(path.join(D, 'tx_activity_100.json'), 'utf8'));
const idl = JSON.parse(fs.readFileSync(path.join(D, 'cega_vault_idl.json'), 'utf8'));
const paTokens = JSON.parse(fs.readFileSync(path.join(D, 'pa_tokens.json'), 'utf8'));
const USDC = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
const toSnake = (s) => s.replace(/[A-Z]/g, (c) => '_' + c.toLowerCase()).replace(/^_/, '');

const num = (x) => Number(x || 0);
const usdcBal = (tokenAcct) => (bal[tokenAcct] && bal[tokenAcct].exists && bal[tokenAcct].mint === USDC) ? num(bal[tokenAcct].amount) : 0;

// ---- custody ----
const products = dec.products.map(p => {
  const balUsdc = usdcBal(p.productUnderlyingTokenAccount);
  const vaults = dec.vaults.filter(v => v.productName === p.productName);
  return {
    name: p.productName, pda: p.pubkey, isActive: p.isActive,
    underlyingMint: p.underlyingMint, productUnderlyingTokenAccount: p.productUnderlyingTokenAccount,
    tokenAccountOwner: (bal[p.productUnderlyingTokenAccount] || {}).tokenOwner || null,
    currentUsdc: Number(balUsdc.toFixed(6)),
    underlyingAmountCounter: p.underlyingAmount / 1e6,
    maxDepositLimit: p.maxDepositLimit, productCounter: p.productCounter,
    managementFeePercentage: p.managementFeePercentage,
    depositQueueHeader: p.depositQueueHeader, depositQueueHeaderNonce: p.depositQueueHeaderNonce,
    productNonce: p.productNonce,
    vaultCount: vaults.length,
    vaultStatusCounts: vaults.reduce((m, v) => { m[v.status] = (m[v.status] || 0) + 1; return m; }, {}),
    vaultUnderlyingSumCounter: vaults.reduce((s, v) => s + v.underlyingAmount, 0) / 1e6
  };
}).sort((a, b) => b.currentUsdc - a.currentUsdc);

const programUsdcAccount = 'BTStJZTJvscGRive34P6ShujjqK4GBBRs93bg1Y4B7Y4';
const programUsdcBalance = 208068.264372; // read via getAccountInfo; owner = productAuthority
const activeUsdc = products.filter(p => p.isActive).reduce((s, p) => s + p.currentUsdc, 0);
const inactiveUsdc = products.filter(p => !p.isActive).reduce((s, p) => s + p.currentUsdc, 0);
const referencedUsdc = products.reduce((s, p) => s + p.currentUsdc, 0);

// productAuthority USDC accounts full list (25 accounts, incl. program account + 0.012 stray)
const paUsdc = [];
for (const v of paTokens.result.value) {
  const i = v.account.data.parsed.info;
  if (i.mint !== USDC) continue;
  paUsdc.push({ account: v.pubkey, uiAmount: num(i.tokenAmount.uiAmountString), owner: i.owner });
}
const paUsdcSum = paUsdc.reduce((s, a) => s + a.uiAmount, 0);

// ---- queues ----
const withdrawQueueEntries = [];
for (const [vault, q] of Object.entries(dec.withdrawQueues)) {
  if (q.total <= 0) continue;
  const v = dec.vaults.find(x => x.pubkey === vault);
  for (const n of q.nodes) withdrawQueueEntries.push({
    queueHeader: q.header ? q.header.pubkey : null,
    vault, product: v ? v.productName : null, vaultNumber: v ? v.vaultNumber : null, vaultStatus: v ? v.status : null,
    user: n.userKey, node: n.pubkey, amountUsdc: n.amount / 1e6
  });
}
const depositQueueEntries = [];
for (const [prod, q] of Object.entries(dec.depositQueues)) {
  const p = dec.products.find(x => x.pubkey === prod);
  for (const n of q.nodes) depositQueueEntries.push({ queueHeader: q.header ? q.header.pubkey : null, product: p ? p.productName : null, user: n.userKey, node: n.pubkey, amountUsdc: n.amount / 1e6 });
}
const withdrawQueueTotal = withdrawQueueEntries.reduce((s, e) => s + e.amountUsdc, 0);
const depositQueueTotal = depositQueueEntries.reduce((s, e) => s + e.amountUsdc, 0);

// ---- instruction surface ----
const instructions = idl.instructions.map(ix => ({
  name: ix.name,
  discriminatorHex: require('./solana_helpers.js').anchorDisc(toSnake(ix.name)).toString('hex'),
  signers: ix.accounts.filter(a => a.isSigner).map(a => a.name),
  accounts: ix.accounts.map(a => ({ name: a.name, writable: !!a.isWritable, signer: !!a.isSigner })),
  valueMoving: ['depositVault', 'addToDepositQueue', 'withdrawVault', 'processDepositQueue', 'processWithdrawQueue',
    'transferToProgramUnderlyingTokenAccount', 'sendFundsToMarketMakers', 'transferToProductUnderlyingTokenAccount',
    'transferToCega', 'collectFees', 'transferBetweenProducts', 'updateUnderlyingAmount', 'rollbackKnockOutEvent', 'overrideVaultStatus'].includes(ix.name)
}));

// ---- activity summary ----
const actSummary = {};
for (const t of act) {
  for (const n of t.ixNames || []) {
    actSummary[n] = actSummary[n] || { count: 0, fail: 0 };
    actSummary[n].count++; if (!t.success) actSummary[n].fail++;
  }
}
const signerSummary = {};
for (const t of act) for (const s of t.signers || []) signerSummary[s] = (signerSummary[s] || 0) + 1;

const state = {
  meta: {
    generatedAt: new Date().toISOString(),
    chain: 'solana-mainnet',
    program: '3HUeooitcfKX1TSCx2xEpg2W31n6Qfmizu7nnbaEWYzs',
    programData: '28qdJRKpfu1VGBbrSk7MEhdQV2fnfLyRNC4vsv6rVtQc',
    upgradeAuthority: '5d8d3PSxKDb6knunoweZ8jZYoDmgEEGMVJdqJBTgjvRx',
    lastDeploySlot: 317515655,
    binaryPayloadBytes: 2380576,
    binarySha256: 'b874c2cec6c96e90c43e98e4c9e443ee6113724226b92dfb5455e159acd3c14a',
    dataSource: 'Solana mainnet RPC (read-only), Solscan-free RPC only',
    noTransactionsSent: true
  },
  upgradeAuthority: {
    address: '5d8d3PSxKDb6knunoweZ8jZYoDmgEEGMVJdqJBTgjvRx',
    accountOwner: '11111111111111111111111111111111',
    space: 0, lamports: 1000000000,
    type: 'Squads v3 multisig vault PDA (system-owned, space 0; never observed as a direct signer)',
    squadsProgram: 'SMPLecH534NA9acpos4G6x7uf3LWbCAwZQE9e8ZekMu',
    multisigAccount: 'ETzCPEqBUk4ehX2Jqv9MhKLxiNaQpGiVGoqmj548nUpF',
    evidence: [
      { tx: 'k63Pvm6fQqtYyByGUqhn1yuRCskTGrWxM32WMT7u7ueLs8JSiSJpxcHjuS9ok9zARBa7PKxjyqS5LVLAVmzwCit', date: '2024-08-12', what: 'Squads ExecuteTransaction -> BPFLoader Upgrade of program 3HUeoo... (programData 28qdJRK...), authority 5d8d3PSx, signer member AmtZcfRfUXTCY8vpDXqwZKzpUyMKJ6VgjDwfEYge1rTu' },
      { tx: 'Ysvxg1VsrcimYc8E9JXhM3Xes8BVmvTFCnREnZo4epLoCPb4v8RZAWi3hcLUtzMkskEjXEaymbAzm8LerzqruWU', date: '2025-01-31', what: 'Squads ExecuteTransaction -> BPFLoader Upgrade of program 3HUeoo..., authority 5d8d3PSx, signer member DtEVWZdw6LU2MzgF51hLEfDwWWgzvFWdiUEt9gXA2aR1' },
      { tx: '5v6yzgbrvZGtT1tAYNQNuSxQzCw4H2figy1237vVyKh2rYPMnUCUjiQXUHfsMMHcPDkjGHh9Enae3CuE82SxSB9X', date: '2022-12-16', what: 'BPFLoader SetAuthority by 31Jum3ufLNgtLnJqJro5dvZ8GUVczfk4a79Q4XLeVQTa, newAuthority = 5d8d3PSx (authority handover into multisig)' }
    ],
    authorityHistory: { observedSigs: 19, firstSeen: '2022-12-16', lastSeen: '2025-01-31', errors: 0 }
  },
  cegaState: dec.state,
  custody: {
    usdcMint: USDC,
    programUsdcTokenAccountDerived: { account: programUsdcAccount, ownerAuthority: '4nhbsUdKEwVQXuYDotgdQHoMWW83GvjXENwLsf9QrRJT', usdc: programUsdcBalance, note: 'derived PDA seeds [program-usdc-token, usdcMint, productAuthority]; State.programUsdcTokenAccount field itself is default/unused' },
    productTokenAccountsUsdc: Number(referencedUsdc.toFixed(6)),
    activeProductsUsdc: Number(activeUsdc.toFixed(6)),
    inactiveProductsUsdc: Number(inactiveUsdc.toFixed(6)),
    totalProgramControlledUsdc: Number(paUsdcSum.toFixed(6)),
    productAuthorityUsdcAccounts: paUsdc,
    allReferencedUsdcAccountsOwnedBy: '4nhbsUdKEwVQXuYDotgdQHoMWW83GvjXENwLsf9QrRJT',
    defiLlamaReportedUsdc: 168626.82,
    defiLlamaMethod: 'sum of Product.underlyingAmount (cumulative counter) for isActive=true, non-test, products listed in PURE_OPTIONS/OPTIONS_AND_BONDS constants; options+bonds products are isActive=false on-chain so excluded',
    nonUsdcNotes: 'productAuthority also owns ~350 option/redeemable token accounts for 157 vaults; balances negligible (largest: 2 x 10,000 of obscure test mints; 821.42 starboard withdraw-queue redeemable)',
    token2022Accounts: 0
  },
  queues: {
    depositQueueTotalUsdc: Number(depositQueueTotal.toFixed(6)),
    depositQueueEntries,
    withdrawQueueTotalUsdc: Number(withdrawQueueTotal.toFixed(6)),
    withdrawQueueEntries
  },
  vaults: {
    count: dec.vaults.length,
    statusCounts: dec.vaults.reduce((m, v) => { m[v.status] = (m[v.status] || 0) + 1; return m; }, {}),
    statusNames: ['NotTraded', 'Traded', 'EpochEnded', 'PayoffCalculated', 'FeesCollected', 'ProcessingWithdrawQueue', 'WithdrawQueueProcessed', 'Zombie', 'ProcessingDepositQueue', 'DepositQueueProcessed'],
    underlyingAmountSumCounter: Number((dec.vaults.reduce((s, v) => s + v.underlyingAmount, 0) / 1e6).toFixed(6))
  },
  products,
  depositInfo: {
    accounts: dec.deposits.length,
    uniqueUsers: dec.aggregates.depositInfoUniqueUsers,
    sumUsdc: Number((dec.aggregates.depositInfoTotal / 1e6).toFixed(6)),
    note: 'PDA [userKey, vault], never closed; includes history since 2022. Sum is NOT current custody (exceeds real token balances by ~100x). Still created for new deposits.'
  },
  instructionSurface: {
    source: 'cega-fi/cega-sdk-sol src/idl/cega_vault.json (v0.1.0) + binary strings; on-chain Anchor IDL account does not exist',
    discriminatorScheme: 'Anchor standard, sha256("global:"+snake_case(name))[0..8] (verified against 100 recent mainnet txs)',
    permissionlessNoSigner: ['calculateCurrentYield', 'calculateVaultPayoff', 'calculationAgent'],
    adminGated: instructions.filter(i => i.signers.includes('admin') || i.signers.includes('programAdmin')).map(i => i.name),
    traderAdminGated: instructions.filter(i => i.signers.includes('traderAdmin')).map(i => i.name),
    userSigned: instructions.filter(i => i.signers.includes('userAuthority') || i.signers.includes('newAdmin') || i.signers.includes('payer')).map(i => i.name),
    instructions: instructions.map(i => ({ name: i.name, signers: i.signers, discriminatorHex: i.discriminatorHex, valueMoving: i.valueMoving, accounts: i.accounts })),
    errorChecksFromBinary: [
      'InvalidUsdMint', 'InvalidMarketMakerAddress', 'InvalidUserUnderlyingAccountOwner', 'InvalidUserRedeemableOwner',
      'InvalidVaultAdmin', 'InvalidTraderAdmin', 'RecieverTokenAccountMismatch (typo in source)', 'MismatchProductUnderlyingTokenAccount',
      'ProductUnderlyingTokenAccountMismatch', 'InvalidProductUnderlyingTokenAddress', 'IncorrectRemainingAccountsForProcessQueue',
      'UserDoesNotMatchQueueNode', 'QueueNodeToProcessDoesNotMatchHeaderHead', 'CannotTradeMoreThanVaultUnderlyingAmount',
      'WithdrawalQueueNotEmpty', 'DepositQueueNotEmpty', 'InvalidZombieVault', 'ProductIsInactive',
      'Anchor account constraints enforce owner/discriminator/has_one'
    ]
  },
  activity: {
    window: { txs: act.length, firstBlockTime: act.length ? Math.min(...act.map(t => t.blockTime || Infinity)) : null, lastBlockTime: act.length ? Math.max(...act.map(t => t.blockTime || 0)) : null },
    instructionCounts: actSummary,
    signerCounts: signerSummary,
    probeEvidence: {
      prober: 'FoCZvQdRkj7PuAqGupo9XXS7aEtSfGG8SpoZAxHg4DjN',
      window: '2026-09-24 .. 2026-09-25',
      sigs: 18, errors: 16,
      behavior: 'minimal-account calls to ProcessWithdrawQueue/OverrideVaultStatus; failed at state account ownership check (AnchorError 3007 AccountOwnedByWrongProgram) -> no access-control bypass observed',
      other: 'HWLAWoYXBuLGAyZYy4LtEa54mo4gyUjRyL3FXytoW8i9: 50 failed txs in 9s on 2026-07-28 invoking dozens of random programs with empty data (generic spam/fuzz, not Cega-specific)'
    }
  },
  sourceIdl: {
    sdkRepo: 'https://github.com/cega-fi/cega-sdk-sol',
    idl: 'https://raw.githubusercontent.com/cega-fi/cega-sdk-sol/main/src/idl/cega_vault.json',
    idlSavedAt: 'cega_vault_idl.json (48 instructions, 89 errors, 21 types)',
    npm: { '@cega-fi/cega-sdk-sol': '1.1.0', '@cega-fi/cega-sdk-sol-v2': '1.0.3' },
    sdkRepoLastCommit: '2024-10-15',
    onChainIdl: 'absent (checked PDA ["anchor:idl"] and legacy create_with_seed addresses)',
    programSource: 'not public; binary strings reveal source tree programs/cega-vault/src/{lib,account,context,utils,types,validation}.rs',
    zellic: { title: 'Cega Vault Smart Contract Patch Review', savedLocal: 'zellic_cega_vault_patch_review.pdf', url: 'https://github.com/Zellic/publications' }
  },
  verdict: {
    unprivilegedExtractionPath: 'NONE VISIBLE',
    reasons: [
      'All USDC custody accounts are owned by the productAuthority PDA 4nhbsUdKEwVQXuYDotgdQHoMWW83GvjXENwLsf9QrRJT, never by user accounts.',
      'Every USDC-outbound instruction requires admin or traderAdmin signer (has_one on State); permissionless instructions only recalculate accounting.',
      'User instructions (deposit/addToDepositQueue/withdraw/transferToCega) can only move user-signed funds into program accounts or enqueue claims; withdrawVault only creates a queue node, actual payout is traderAdmin-only processWithdrawQueue.',
      'Live probe txs calling ProcessWithdrawQueue/OverrideVaultStatus with wrong accounts were rejected with AnchorError 3007 (AccountOwnedByWrongProgram) and custom error 0x1.',
      'State-admin/traderAdmin are single keypairs; upgrade authority is under Squads v3 multisig (upgrades via ExecuteTransaction).'
    ],
    privilegedRisks: [
      'traderAdmin AuFniTGJZEibC4tBgkdZscPmVPUbSLn6xqmAgpPJpJFm can sendFundsToMarketMakers / transferToProductUnderlyingTokenAccount / processWithdrawQueue / collectFees (custody 473.5k USDC under program control).',
      'admin FMs1U19BfkLU3cunEa3yNZU69isCLBq59HK1eiFoLmx6 can transferBetweenProducts, updateUnderlyingAmount, overrideVaultStatus, rollbackKnockOutEvent and change fee/recipient settings.',
      'programAdmin/feeRecipient CX2zeerdycdmvanADFzrWe1p4N48hiwfzfq2mW8VYqop can updateAdmin (and change traderAdmin via updateTraderAdmin? traderAdmin is State field updated by programAdmin).',
      'Upgrade authority is a multisig vault; compromising a sufficient set of Squads members still allows arbitrary program replacement.'
    ],
    zombieAssets: {
      inactiveProductsUsdc: Number(inactiveUsdc.toFixed(6)),
      unprocessedWithdrawQueueUsdc: Number(withdrawQueueTotal.toFixed(6)),
      exampleStuck: 'cruise-control-test holds 9,999.92 USDC; user 9oBZdxxzrcSJbQkZhKqTVoi554zZhopDnh134h3iE62f has a queued withdrawal of 10,000 USDC (vault status 3=PayoffCalculated) awaiting traderAdmin processWithdrawQueue.',
      programBufferUsdc: programUsdcBalance
    }
  }
};
fs.writeFileSync(path.join(D, 'state.json'), JSON.stringify(state, null, 1));
console.log('state.json written', fs.statSync(path.join(D, 'state.json')).size, 'bytes');
console.log('products:', products.length, '| total USDC:', paUsdcSum.toFixed(6), '| active:', activeUsdc.toFixed(2), '| inactive:', inactiveUsdc.toFixed(2), '| buffer:', programUsdcBalance);
console.log('withdraw queue entries:', withdrawQueueEntries.length, 'total', withdrawQueueTotal.toFixed(6));
