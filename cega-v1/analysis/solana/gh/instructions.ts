import * as anchor from '@project-serum/anchor';
import {
  PublicKey,
  TransactionInstruction,
  SYSVAR_RENT_PUBKEY,
  SystemProgram,
  AccountMeta,
} from '@solana/web3.js';
import { getAssociatedTokenAddress, TOKEN_PROGRAM_ID } from '@solana/spl-token';
import { CegaVault } from '../types/cega_vault';
import * as utils from './utils';
import * as vaultTypes from './types';

export async function initializeStateIx(
  admin: PublicKey,
  programAdmin: PublicKey,
  managementFeePercentage: number,
  yieldFeePercentage: number,
  feeRecipient: PublicKey,
  programId: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const [state, _stateNonce] = await utils.getStateAddress(programId);

  const [productAuthority, productAuthorityNonce] =
    await utils.getProductAuthorityAddress(programId);

  const args: InitializeStateArgs = {
    productAuthorityNonce,
    yieldFeePercentage,
    managementFeePercentage,
  };

  const accounts = {
    state,
    productAuthority,
    admin,
    programAdmin,
    feeRecipient,
    systemProgram: SystemProgram.programId,
    rent: SYSVAR_RENT_PUBKEY,
  };

  return program.methods.initializeState(args).accounts(accounts).instruction();
}

export function fundProductAuthorityIx(
  state: PublicKey,
  payer: PublicKey,
  productAuthority: PublicKey,
  lamports: number,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const accounts = {
    state,
    payer,
    productAuthority,
    systemProgram: SystemProgram.programId,
  };

  return program.methods
    .fundProductAuthority(new anchor.BN(lamports))
    .accounts(accounts)
    .instruction();
}

export async function initializeProductIx(
  state: PublicKey,
  admin: PublicKey,
  productAuthority: PublicKey,
  productName: string,
  underlyingMint: PublicKey,
  maxDepositLimit: anchor.BN,
  mapleAccount: PublicKey,
  programId: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const [productAddress, _productNonce] = await utils.getProductAddress(productName, programId);

  const [productUnderlyingTokenAccount, _productUnderlyingTokenAccountNonce] =
    await utils.getProductUnderlyingTokenAddress(productAddress, programId);

  const [depositQueueHeader, _depositQueueHeaderNonce] = await utils.getDepositQueueHeaderAddress(
    productAddress,
    programId,
  );

  const args: InitializeProductArgs = {
    productName,
    maxDepositLimit,
  };

  const accounts = {
    state,
    admin,
    productAuthority,
    product: productAddress,
    underlyingMint,
    productUnderlyingTokenAccount,
    depositQueueHeader,
    mapleAccount,
    tokenProgram: TOKEN_PROGRAM_ID,
    systemProgram: anchor.web3.SystemProgram.programId,
    rent: SYSVAR_RENT_PUBKEY,
  };

  return program.methods.initializeProduct(args).accounts(accounts).instruction();
}

export async function initializeVaultIx(
  state: PublicKey,
  traderAdmin: PublicKey,
  productAuthority: PublicKey,
  productAddress: PublicKey,
  epochTimes: EpochTimes,
  epochSequenceNumber: anchor.BN,
  programId: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const productInfo = await program.account.product.fetch(productAddress);
  const { underlyingMint } = productInfo;
  const { productUnderlyingTokenAccount } = productInfo;

  const [vault, _vaultNonce] = await utils.getVaultAddress(
    Buffer.from(productInfo.productName).toString().trim(),
    productInfo.productCounter,
    programId,
  );
  const [redeemableMint, _redeemableMintNonce] = await utils.getRedeemableMintAddress(
    vault,
    programId,
  );

  const [optionMint, _optionMintNonce] = await utils.getOptionMintAddress(vault, programId);

  const [vaultOptionTokenAccount, _vaultOptionTokenAccountNonce] =
    await utils.getVaultOptionTokenAccountAddress(optionMint, vault, programId);

  const [withdrawQueueHeader, _withdrawQueueHeaderNonce] =
    await utils.getWithdrawQueueHeaderAddress(vault, programId);

  const [vaultWithdrawQueueRedeemableTokenAccount, _vaultWithdrawQueueRedeemableTokenAccountNonce] =
    await utils.getVaultWithdrawQueueRedeemableTokenAccountAddress(vault, programId);

  const [structuredProductInfoAccount, _structuredProductInfoAccountNonce] =
    await utils.getStructuredProductInfoAccountAddress(vault, programId);

  const args: InitializeVaultArgs = {
    epochSequenceNumber,
    startEpoch: epochTimes.startEpoch,
    endEpoch: epochTimes.endEpoch,
    epochCadence: epochTimes.epochCadence,
    startDeposits: epochTimes.startDeposits,
    endDeposits: epochTimes.endDeposits,
  };

  const accounts = {
    state,
    traderAdmin,
    productAuthority,
    product: productAddress,
    vault,
    underlyingMint,
    redeemableMint,
    optionMint,
    productUnderlyingTokenAccount,
    vaultOptionTokenAccount,
    vaultWithdrawQueueRedeemableTokenAccount,
    withdrawQueueHeader,
    structuredProductInfoAccount,
    systemProgram: anchor.web3.SystemProgram.programId,
    tokenProgram: TOKEN_PROGRAM_ID,
    rent: SYSVAR_RENT_PUBKEY,
  };

  // console.log(util.inspect(args, {showHidden: false, depth: null, colors: true}))
  // console.log(util.inspect(accounts, {showHidden: false, depth: null, colors: true}))

  return program.methods.initializeVault(args).accounts(accounts).instruction();
}

export async function initializeOptionBarrierIx(
  state: PublicKey,
  traderAdmin: PublicKey,
  productAuthority: PublicKey,
  vault: PublicKey,
  oracle: PublicKey,
  oracleType: anchor.BN,
  assetName: string,
  optionNumber: anchor.BN,
  strikePercentage: anchor.BN,
  knockInPercentage: anchor.BN,
  knockOutPercentage: anchor.BN,
  observationTime: anchor.BN,
  timeBuffer: anchor.BN,
  timeIncrement: anchor.BN,
  programId: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const [optionBarrier, _optionBarrierNonce] = await utils.getOptionBarrierAddress(
    optionNumber,
    vault,
    programId,
  );
  const args: InitializeOptionBarrierArgs = {
    assetName,
    optionNumber,
    strikePercentage,
    knockInPercentage,
    knockOutPercentage,
    oracleType,
    observationTime,
    timeBuffer,
    timeIncrement,
  };
  const accounts = {
    state,
    traderAdmin,
    productAuthority,
    vault,
    optionBarrier,
    oracle,
    systemProgram: anchor.web3.SystemProgram.programId,
    rent: SYSVAR_RENT_PUBKEY,
  };
  return program.methods.initializeOptionBarrier(args).accounts(accounts).instruction();
}

export async function updateOptionBarrierDetailsIx(
  state: PublicKey,
  admin: PublicKey,
  vault: PublicKey,
  oracle: PublicKey,
  oracleType: anchor.BN,
  assetName: string,
  optionNumber: anchor.BN,
  programId: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const [optionBarrier, _optionBarrierNonce] = await utils.getOptionBarrierAddress(
    optionNumber,
    vault,
    programId,
  );
  const args: UpdateOptionBarrierDetailsArgs = {
    assetName,
    oracleType,
  };
  const accounts = {
    state,
    admin,
    vault,
    optionBarrier,
    oracle,
  };
  return program.methods.updateOptionBarrierDetails(args).accounts(accounts).instruction();
}

export async function initializeStructuredProductIx(
  state: PublicKey,
  traderAdmin: PublicKey,
  productAuthority: PublicKey,
  vault: PublicKey,
  aprPercentage: anchor.BN,
  tenorInDays: anchor.BN,
  numberOfPuts: anchor.BN,
  programId: PublicKey,
  program: anchor.Program<CegaVault>,
) {
  const [structuredProductInfoAccount, _structuredProductInfoAccountNonce] =
    await utils.getStructuredProductInfoAccountAddress(vault, programId);

  const args: InitializeStructuredProductArgs = {
    aprPercentage,
    tenorInDays,
    numberOfPuts,
  };

  const accounts = {
    state,
    traderAdmin,
    productAuthority,
    vault,
    structuredProductInfoAccount,
    systemProgram: anchor.web3.SystemProgram.programId,
    rent: anchor.web3.SYSVAR_RENT_PUBKEY,
  };

  return program.methods.initializeStructuredProduct(args).accounts(accounts).instruction();
}

export async function setProductDepositQueue(
  state: PublicKey,
  admin: PublicKey,
  productAuthority: PublicKey,
  product: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const [depositQueueHeader, _depositQueueHeaderNonce] = await utils.getDepositQueueHeaderAddress(
    product,
    program.programId,
  );

  const accounts = {
    state,
    admin,
    productAuthority,
    product,
    depositQueueHeader,
  };

  return program.methods.setProductDepositQueue().accounts(accounts).instruction();
}

export async function setProductState(
  state: PublicKey,
  admin: PublicKey,
  productAuthority: PublicKey,
  product: PublicKey,
  program: anchor.Program<CegaVault>,
  newProductState: boolean,
): Promise<TransactionInstruction> {
  const args: SetProductStateArgs = {
    newProductState: newProductState,
  };

  const accounts = {
    state,
    admin,
    productAuthority,
    product,
  };

  return program.methods.setProductState(args).accounts(accounts).instruction();
}

export async function depositVaultIx(
  state: PublicKey,
  admin: PublicKey,
  productAuthority: PublicKey,
  amount: anchor.BN,
  productAddress: PublicKey,
  vault: PublicKey,
  depositInfo: PublicKey,
  userAuthority: PublicKey,
  userUnderlyingTokenAccount: PublicKey,
  userRedeemableTokenAccount: PublicKey,
  underlyingMint: PublicKey,
  redeemableMint: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const productInfo = await program.account.product.fetch(productAddress);
  const args: DepositVaultArgs = {
    underlyingAmount: amount,
  };

  const accounts = {
    state,
    admin,
    productAuthority,
    userAuthority,
    product: productAddress,
    vault,
    depositInfo,
    underlyingMint,
    redeemableMint,
    userUnderlyingTokenAccount,
    productUnderlyingTokenAccount: productInfo.productUnderlyingTokenAccount,
    userRedeemableTokenAccount,
    tokenProgram: TOKEN_PROGRAM_ID,
    systemProgram: anchor.web3.SystemProgram.programId,
    rent: anchor.web3.SYSVAR_RENT_PUBKEY,
  };

  return program.methods.depositVault(args).accounts(accounts).instruction();
}

export async function addToDepositQueueIx(
  state: PublicKey,
  productAuthority: PublicKey,
  userAuthority: PublicKey,
  productAddress: PublicKey,
  userUnderlyingTokenAccount: PublicKey,
  amount: anchor.BN,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const productInfo = await program.account.product.fetch(productAddress);

  const depositQueueHeaderInfo = await program.account.queueHeader.fetch(
    productInfo.depositQueueHeader,
  );

  const [newDepositQueueNode, newDepositQueueNodeNonce] = await utils.getDepositQueueNodeAddress(
    productInfo.depositQueueHeader,
    userAuthority,
    depositQueueHeaderInfo.seqNum,
    program.programId,
  );

  const remainingAccounts: any[] = [];
  if (depositQueueHeaderInfo.count.toNumber() != 0) {
    remainingAccounts.push({
      pubkey: depositQueueHeaderInfo.tail,
      isSigner: false,
      isWritable: true,
    });
  }

  const args: AddToDepositQueueArgs = {
    depositAmount: amount,
    newDepositQueueNodeNonce: newDepositQueueNodeNonce,
  };

  const accounts = {
    state,
    productAuthority,
    userAuthority: userAuthority,
    product: productAddress,
    underlyingMint: productInfo.underlyingMint,
    productUnderlyingTokenAccount: productInfo.productUnderlyingTokenAccount,
    userUnderlyingTokenAccount,
    depositQueueHeader: productInfo.depositQueueHeader,
    newQueueNode: newDepositQueueNode,
    tokenProgram: TOKEN_PROGRAM_ID,
    systemProgram: SystemProgram.programId,
  };

  return program.methods
    .addToDepositQueue(args)
    .accounts(accounts)
    .remainingAccounts(remainingAccounts)
    .instruction();
}

export function processDepositQueueIx(
  state: PublicKey,
  product: vaultTypes.Product,
  vault: vaultTypes.Vault,
  productAuthority: PublicKey,
  remainingAccounts: AccountMeta[],
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const accounts = {
    state,
    product: product.address,
    vault: vault.address,
    productAuthority,
    underlyingMint: vault.underlyingMint,
    redeemableMint: vault.redeemableMint,
    productUnderlyingTokenAccount: product.productUnderlyingTokenAccount,
    depositQueueHeader: product.depositQueueHeader,
    tokenProgram: TOKEN_PROGRAM_ID,
  };

  return program.methods
    .processDepositQueue()
    .accounts(accounts)
    .remainingAccounts(remainingAccounts)
    .instruction();
}

export async function initializeProgramUsdcAccountIx(
  state: PublicKey,
  traderAdmin: PublicKey,
  productAuthority: PublicKey,
  underlyingMint: PublicKey,
  programId: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const [programUsdcTokenAccount, _programUsdcTokenAccountNonce] =
    await utils.getProgramUsdcTokenAccountAddress(underlyingMint, productAuthority, programId);

  const accounts = {
    state,
    traderAdmin,
    productAuthority,
    underlyingMint,
    programUsdcTokenAccount,
    tokenProgram: TOKEN_PROGRAM_ID,
    systemProgram: anchor.web3.SystemProgram.programId,
    rent: anchor.web3.SYSVAR_RENT_PUBKEY,
  };
  return program.methods.initializeProgramUsdcAccount().accounts(accounts).instruction();
}
export async function sendFundsToMarketMakersIx(
  amountToSend: anchor.BN,
  state: PublicKey,
  traderAdmin: PublicKey,
  productAuthority: PublicKey,
  underlyingMint: PublicKey,
  recieverWalletAddress: PublicKey,
  recieverUnderlyingTokenAccount: PublicKey,
  programId: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const [programUsdcTokenAccount, _programUsdcTokenAccountNonce] =
    await utils.getProgramUsdcTokenAccountAddress(underlyingMint, productAuthority, programId);

  const accounts = {
    state,
    traderAdmin,
    productAuthority,
    programUsdcTokenAccount,
    underlyingMint,
    recieverWalletAddress,
    recieverUnderlyingTokenAccount,
    tokenProgram: TOKEN_PROGRAM_ID,
    systemProgram: anchor.web3.SystemProgram.programId,
    rent: anchor.web3.SYSVAR_RENT_PUBKEY,
  };
  return program.methods.sendFundsToMarketMakers(amountToSend).accounts(accounts).instruction();
}

export async function transferToProgramUnderlyingTokenAccountIx(
  state: PublicKey,
  traderAdmin: PublicKey,
  productAuthority: PublicKey,
  productAddress: PublicKey,
  productUnderlyingTokenAccount: PublicKey,
  vaultAddress: PublicKey,
  underlyingMint: PublicKey,
  redeemableMint: PublicKey,
  programId: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const [programUsdcTokenAccount, _programUsdcTokenAccountNonce] =
    await utils.getProgramUsdcTokenAccountAddress(underlyingMint, productAuthority, programId);

  const accounts = {
    state,
    traderAdmin,
    productAuthority,
    underlyingMint,
    product: productAddress,
    productUnderlyingTokenAccount,
    programUsdcTokenAccount,
    vault: vaultAddress,
    redeemableMint,
    tokenProgram: TOKEN_PROGRAM_ID,
    systemProgram: anchor.web3.SystemProgram.programId,
    rent: anchor.web3.SYSVAR_RENT_PUBKEY,
  };
  return program.methods.transferToProgramUnderlyingTokenAccount().accounts(accounts).instruction();
}

export async function transferToProductUnderlyingTokenAccountIx(
  amountToTransfer: anchor.BN,
  state: PublicKey,
  traderAdmin: PublicKey,
  productAuthority: PublicKey,
  underlyingMint: PublicKey,
  productAddress: PublicKey,
  productUnderlyingTokenAccount: PublicKey,
  programId: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const [programUsdcTokenAccount, _programUsdcTokenAccountNonce] =
    await utils.getProgramUsdcTokenAccountAddress(underlyingMint, productAuthority, programId);

  const accounts = {
    state,
    traderAdmin,
    productAuthority,
    underlyingMint,
    product: productAddress,
    productUnderlyingTokenAccount,
    programUsdcTokenAccount,
    tokenProgram: TOKEN_PROGRAM_ID,
    systemProgram: anchor.web3.SystemProgram.programId,
    rent: anchor.web3.SYSVAR_RENT_PUBKEY,
  };

  return program.methods
    .transferToProductUnderlyingTokenAccount(amountToTransfer)
    .accounts(accounts)
    .instruction();
}

export function calculationAgentIx(
  state: PublicKey,
  admin: PublicKey,
  productAuthority: PublicKey,
  vault: vaultTypes.Vault,
  remainingAccounts: AccountMeta[],
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const accounts = {
    state,
    admin,
    productAuthority,
    vault: vault.address,
    structuredProductInfoAccount: vault.structuredProductInfoAccount,
  };
  return program.methods
    .calculationAgent()
    .accounts(accounts)
    .remainingAccounts(remainingAccounts)
    .instruction();
}

export function calculateCurrentYieldIx(
  state: PublicKey,
  admin: PublicKey,
  product: vaultTypes.Product,
  vault: vaultTypes.Vault,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const accounts = {
    state,
    admin,
    product: product.address,
    vault: vault.address,
    structuredProductInfoAccount: vault.structuredProductInfoAccount,
  };
  return program.methods.calculateCurrentYield().accounts(accounts).instruction();
}

export async function transferBetweenProductsIx(
  state: PublicKey,
  admin: PublicKey,
  productAuthority: PublicKey,
  productFromName: string,
  productDestinationName: string,
  amount: anchor.BN,
  programId: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const [productFromAddress, _productFromNonce] = await utils.getProductAddress(
    productFromName,
    programId,
  );
  const [productDestinationAddress, _productDestinationNonce] = await utils.getProductAddress(
    productDestinationName,
    programId,
  );
  const [productFromUnderlyingTokenAccount, _productFromUnderlyingTokenAccountNonce] =
    await utils.getProductUnderlyingTokenAddress(productFromAddress, programId);

  const [productDestinationUnderlyingTokenAccount, _productDestinationUnderlyingTokenAccountNonce] =
    await utils.getProductUnderlyingTokenAddress(productDestinationAddress, programId);

  const accounts = {
    state,
    admin,
    productAuthority,
    productFrom: productFromAddress,
    productFromUnderlyingTokenAccount,
    productDestination: productDestinationAddress,
    productDestinationUnderlyingTokenAccount,
    tokenProgram: TOKEN_PROGRAM_ID,
  };
  return program.methods.transferBetweenProducts(amount).accounts(accounts).instruction();
}

export function calculateVaultPayoffIx(
  state: PublicKey,
  admin: PublicKey,
  productAuthority: PublicKey,
  product: vaultTypes.Product,
  vault: vaultTypes.Vault,
  remainingAccounts: AccountMeta[],
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const accounts = {
    state,
    admin,
    productAuthority,
    product: product.address,
    vault: vault.address,
    structuredProductInfoAccount: vault.structuredProductInfoAccount,
  };
  return program.methods
    .calculateVaultPayoff()
    .accounts(accounts)
    .remainingAccounts(remainingAccounts)
    .instruction();
}

export async function withdrawVaultIx(
  state: PublicKey,
  productAuthority: PublicKey,
  userKey: PublicKey,
  amount: anchor.BN,
  userUnderlyingTokenAccount: PublicKey,
  userRedeemableTokenAccount: PublicKey,
  productAddress: PublicKey,
  vaultAddress: PublicKey,
  programId: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const productInfo = await program.account.product.fetch(productAddress);
  const vaultInfo = await program.account.vault.fetch(vaultAddress);

  const withdrawQueueHeaderInfo = await program.account.queueHeader.fetch(
    vaultInfo.withdrawQueueHeader,
  );

  const [newUserQueueNode, newUserQueueNodeNonce] = await utils.getWithdrawQueueNodeAddress(
    vaultInfo.withdrawQueueHeader,
    userKey,
    withdrawQueueHeaderInfo.seqNum,
    programId,
  );

  const remainingAccounts: any[] = [];
  if (withdrawQueueHeaderInfo.count.toNumber() != 0) {
    remainingAccounts.push({
      pubkey: withdrawQueueHeaderInfo.tail,
      isSigner: false,
      isWritable: true,
    });
  }

  const args: WithdrawVaultArgs = {
    redeemableAmount: amount,
    newWithdrawQueueNodeNonce: newUserQueueNodeNonce,
  };

  const accounts = {
    state,
    userAuthority: userKey,
    userUnderlyingTokenAccount,
    userRedeemableTokenAccount,
    product: productAddress,
    vault: vaultAddress,
    productAuthority,
    underlyingMint: vaultInfo.underlyingMint,
    redeemableMint: vaultInfo.redeemableMint,
    productUnderlyingTokenAccount: productInfo.productUnderlyingTokenAccount,
    vaultWithdrawQueueRedeemableTokenAccount: vaultInfo.vaultWithdrawQueueRedeemableTokenAccount,
    withdrawQueueHeader: vaultInfo.withdrawQueueHeader,
    newQueueNode: newUserQueueNode,
    tokenProgram: TOKEN_PROGRAM_ID,
    systemProgram: SystemProgram.programId,
    rent: SYSVAR_RENT_PUBKEY,
  };

  return program.methods
    .withdrawVault(args)
    .accounts(accounts)
    .remainingAccounts(remainingAccounts)
    .instruction();
}

export function processWithdrawQueueIx(
  state: PublicKey,
  productAuthority: PublicKey,
  product: vaultTypes.Product,
  vault: vaultTypes.Vault,
  remainingAccounts: AccountMeta[],
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const accounts = {
    state,
    product: product.address,
    vault: vault.address,
    productAuthority,
    underlyingMint: vault.underlyingMint,
    redeemableMint: vault.redeemableMint,
    productUnderlyingTokenAccount: product.productUnderlyingTokenAccount,
    vaultWithdrawQueueRedeemableTokenAccount: vault.vaultWithdrawQueueRedeemableTokenAccount,
    withdrawQueueHeader: vault.withdrawQueueHeader,
    tokenProgram: TOKEN_PROGRAM_ID,
  };

  return program.methods
    .processWithdrawQueue()
    .accounts(accounts)
    .remainingAccounts(remainingAccounts)
    .instruction();
}

export function rolloverVaultIx(
  state: PublicKey,
  traderAdmin: PublicKey,
  productAuthority: PublicKey,
  productAddress: PublicKey,
  vaultAddress: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const accounts = {
    state,
    traderAdmin,
    product: productAddress,
    vault: vaultAddress,
    productAuthority,
    tokenProgram: TOKEN_PROGRAM_ID,
  };
  return program.methods.rolloverVault().accounts(accounts).instruction();
}

export async function collectFeesIx(
  state: PublicKey,
  traderAdmin: PublicKey,
  productAuthority: PublicKey,
  feeRecipient: PublicKey,
  product: vaultTypes.Product,
  vault: vaultTypes.Vault,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const feeRecipientTokenAccount = await getAssociatedTokenAddress(
    product.underlyingMint,
    feeRecipient,
  );
  const accounts = {
    state,
    traderAdmin,
    productAuthority,
    product: product.address,
    vault: vault.address,
    underlyingMint: product.underlyingMint,
    productUnderlyingTokenAccount: product.productUnderlyingTokenAccount,
    feeRecipientTokenAccount,
    tokenProgram: TOKEN_PROGRAM_ID,
  };

  return program.methods.collectFees().accounts(accounts).instruction();
}

export function updateVaultEpochTimesIx(
  state: PublicKey,
  traderAdmin: PublicKey,
  vault: PublicKey,
  args: UpdateVaultEpochTimesArgs,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  return program.methods
    .updateVaultEpochTimes(args)
    .accounts({
      state,
      vault,
      traderAdmin,
    })
    .instruction();
}

export function overrideObservationPeriodIx(
  state: PublicKey,
  traderAdmin: PublicKey,
  optionBarrier: PublicKey,
  args: OverrideObservationPeriodArgs,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  return program.methods
    .overrideObservationPeriod(args)
    .accounts({
      state,
      traderAdmin,
      optionBarrier,
    })
    .instruction();
}

export function overrideVaultBarriersIx(
  state: PublicKey,
  admin: PublicKey,
  vault: PublicKey,
  args: OverrideVaultBarriersArgs,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  return program.methods
    .overrideVaultBarriers(args)
    .accounts({
      state,
      admin,
      vault,
    })
    .instruction();
}

export function overrideVaultStatusIx(
  state: PublicKey,
  admin: PublicKey,
  vault: PublicKey,
  updatedStatus: anchor.BN,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  return program.methods
    .overrideVaultStatus(updatedStatus)
    .accounts({
      state,
      admin,
      vault,
    })
    .instruction();
}

export function rollbackKnockOutEventIx(
  state: PublicKey,
  admin: PublicKey,
  product: PublicKey,
  vault: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  return program.methods
    .rollbackKnockOutEvent()
    .accounts({
      state,
      admin,
      product,
      vault,
    })
    .instruction();
}

export function overrideOptionBarrierPriceIx(
  state: PublicKey,
  admin: PublicKey,
  vault: PublicKey,
  optionBarrier: PublicKey,
  price: anchor.BN,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  return program.methods
    .overrideOptionBarrierPrice(price)
    .accounts({
      state,
      admin,
      vault,
      optionBarrier,
    })
    .instruction();
}

export function setOptionBarrierAbsIx(
  state: PublicKey,
  traderAdmin: PublicKey,
  vault: PublicKey,
  program: anchor.Program<CegaVault>,
  optionBarrier: PublicKey,
  strike: anchor.BN | null,
  knockIn: anchor.BN | null,
  knockOut: anchor.BN | null,
): Promise<TransactionInstruction> {
  return program.methods
    .setOptionBarrierAbs({
      strike,
      knockIn,
      knockOut,
    })
    .accounts({
      state,
      traderAdmin,
      vault,
      optionBarrier,
    })
    .instruction();
}

export function updateAdminIx(
  state: PublicKey,
  admin: PublicKey,
  newAdmin: PublicKey,
  program: anchor.Program<CegaVault>,
  currentAdmin?: PublicKey,
): Promise<TransactionInstruction> {
  const accounts = {
    state,
    admin: currentAdmin || admin,
  };

  return program.methods.updateAdmin(newAdmin).accounts(accounts).instruction();
}

export function acceptAdminUpdateIx(
  state: PublicKey,
  newAdmin: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const accounts = {
    state,
    newAdmin,
  };

  return program.methods.acceptAdminUpdate().accounts(accounts).instruction();
}

export function updateTraderAdminIx(
  state: PublicKey,
  programAdmin: PublicKey,
  newTraderAdmin: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  return program.methods
    .updateTraderAdmin(newTraderAdmin)
    .accounts({
      state,
      programAdmin,
    })
    .instruction();
}

export function updateMaxDepositLimitIx(
  state: PublicKey,
  traderAdmin: PublicKey,
  productAddress: PublicKey,
  newDepositLimit: anchor.BN,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  return program.methods
    .updateMaxDepositLimit(newDepositLimit)
    .accounts({
      state,
      traderAdmin,
      product: productAddress,
    })
    .instruction();
}

export function updateProductFeesIx(
  state: PublicKey,
  admin: PublicKey,
  productAddress: PublicKey,
  newManagementFeePercentage: anchor.BN,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  return program.methods
    .updateProductFees(newManagementFeePercentage)
    .accounts({
      state,
      admin,
      product: productAddress,
    })
    .instruction();
}

export function updateFeesIx(
  state: PublicKey,
  admin: PublicKey,
  yieldFeePercentage: number,
  managementFeePercentage: number,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  return program.methods
    .updateFees({ yieldFeePercentage, managementFeePercentage })
    .accounts({
      state,
      admin,
    })
    .instruction();
}

export function updateAprIx(
  state: PublicKey,
  traderAdmin: PublicKey,
  vault: PublicKey,
  structuredProductInfoAccount: PublicKey,
  apr: anchor.BN,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  return program.methods
    .updateApr(apr)
    .accounts({
      state,
      traderAdmin,
      vault,
      structuredProductInfoAccount,
    })
    .instruction();
}

export function updateTenorInDaysIx(
  state: PublicKey,
  admin: PublicKey,
  vault: PublicKey,
  structuredProductInfoAccount: PublicKey,
  tenorInDays: anchor.BN,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  return program.methods
    .updateTenorInDays(tenorInDays)
    .accounts({
      state,
      admin,
      vault,
      structuredProductInfoAccount,
    })
    .instruction();
}

export function updateFeeRecipientIx(
  state: PublicKey,
  programAdmin: PublicKey,
  feeRecipientTokenAccount: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  return program.methods
    .updateFeeRecipient(feeRecipientTokenAccount)
    .accounts({
      state,
      programAdmin,
    })
    .instruction();
}

export function updateMapleAccount(
  state: PublicKey,
  programAdmin: PublicKey,
  product: PublicKey,
  newMapleAccount: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  return program.methods
    .updateMapleAccount(newMapleAccount)
    .accounts({
      state,
      programAdmin,
      product,
    })
    .instruction();
}

export async function createTokenMetadataIx(
  state: PublicKey,
  admin: PublicKey,
  vault: PublicKey,
  productAuthority: PublicKey,
  programId: PublicKey,
  name: string,
  symbol: string,
  uri: string,
  metadataProgram: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const args: CreateTokenMetadataArgs = {
    name,
    symbol,
    uri,
  };
  const [redeemableMint, _redeemableMintNonce] = await utils.getRedeemableMintAddress(
    vault,
    programId,
  );
  const [metadataAccount, _metadataAccountNonce] = await utils.getMetadataAccountAddress(
    redeemableMint,
    metadataProgram,
  );
  return program.methods
    .createTokenMetadata(args)
    .accounts({
      state,
      admin,
      vault,
      productAuthority,
      redeemableMint,
      metadataAccount,
      metadataProgram,
      systemProgram: SystemProgram.programId,
      tokenProgram: TOKEN_PROGRAM_ID,
      rent: SYSVAR_RENT_PUBKEY,
    })
    .instruction();
}

export async function updateTokenMetadataIx(
  state: PublicKey,
  admin: PublicKey,
  vault: PublicKey,
  productAuthority: PublicKey,
  programId: PublicKey,
  name: string,
  symbol: string,
  uri: string,
  metadataProgram: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const args: CreateTokenMetadataArgs = {
    name,
    symbol,
    uri,
  };
  const [redeemableMint, _redeemableMintNonce] = await utils.getRedeemableMintAddress(
    vault,
    programId,
  );
  const [metadataAccount, _metadataAccountNonce] = await utils.getMetadataAccountAddress(
    redeemableMint,
    metadataProgram,
  );
  return program.methods
    .updateTokenMetadata(args)
    .accounts({
      state,
      admin,
      productAuthority,
      redeemableMint,
      metadataAccount,
      metadataProgram,
    })
    .instruction();
}

export async function updateUnderlyingAmountIx(
  state: PublicKey,
  admin: PublicKey,
  productAuthority: PublicKey,
  product: vaultTypes.Product,
  vault: vaultTypes.Vault,
  amountToIncrease: anchor.BN,
  programId: PublicKey,
  program: anchor.Program<CegaVault>,
): Promise<TransactionInstruction> {
  const [programUsdcTokenAccount, _programUsdcTokenAccountNonce] =
    await utils.getProgramUsdcTokenAccountAddress(
      vault.underlyingMint,
      productAuthority,
      programId,
    );

  const accounts = {
    state,
    admin,
    productAuthority,
    underlyingMint: vault.underlyingMint,
    product: product.address,
    vault: vault.address,
    productUnderlyingTokenAccount: product.productUnderlyingTokenAccount,
    programUsdcTokenAccount,
    tokenProgram: TOKEN_PROGRAM_ID,
    systemProgram: anchor.web3.SystemProgram.programId,
    rent: anchor.web3.SYSVAR_RENT_PUBKEY,
  };

  return program.methods.updateUnderlyingAmount(amountToIncrease).accounts(accounts).instruction();
}

export interface InitializeStateArgs {
  productAuthorityNonce: number;
  yieldFeePercentage: number;
  managementFeePercentage: number;
}

export interface InitializeProductArgs {
  productName: string;
  maxDepositLimit: anchor.BN;
}

export interface InitializeVaultArgs {
  epochSequenceNumber: anchor.BN;
  startEpoch: anchor.BN;
  endEpoch: anchor.BN;
  epochCadence: number;
  startDeposits: anchor.BN;
  endDeposits: anchor.BN;
}

export interface InitializeOptionBarrierArgs {
  assetName: string;
  optionNumber: anchor.BN;
  strikePercentage: anchor.BN;
  knockInPercentage: anchor.BN;
  knockOutPercentage: anchor.BN;
  oracleType: anchor.BN;
  observationTime: anchor.BN;
  timeBuffer: anchor.BN;
  timeIncrement: anchor.BN;
}

export interface UpdateOptionBarrierDetailsArgs {
  assetName: string;
  oracleType: anchor.BN;
}

export interface InitializeStructuredProductArgs {
  aprPercentage: anchor.BN;
  tenorInDays: anchor.BN;
  numberOfPuts: anchor.BN;
}

export interface DepositVaultArgs {
  underlyingAmount: anchor.BN;
}

export interface SetProductStateArgs {
  newProductState: boolean;
}

export interface AddToDepositQueueArgs {
  depositAmount: anchor.BN;
  newDepositQueueNodeNonce: number;
}

export interface TraderTransferArgs {
  amountToTrade: anchor.BN;
  recieverAddress: PublicKey;
}

export interface WithdrawVaultArgs {
  redeemableAmount: anchor.BN;
  newWithdrawQueueNodeNonce: number;
}

// all of these units are in seconds
export interface UpdateVaultEpochTimesArgs {
  startEpoch: anchor.BN;
  startDeposits: anchor.BN;
  endDeposits: anchor.BN;
  endEpoch: anchor.BN;
  epochCadence: number;
}

export interface OverrideObservationPeriodArgs {
  observationTime: anchor.BN;
  timeBuffer: anchor.BN;
  timeIncrement: anchor.BN;
}

export interface OverrideVaultBarriersArgs {
  knockIn: boolean;
  knockOut: boolean;
}

export interface SetOptionBarrierAbsArgs {
  optionNum: anchor.BN;
  strike: anchor.BN | null;
  knockIn: anchor.BN | null;
  knockOut: anchor.BN | null;
}

export interface OverrideOptionBarrierObservationArgs {
  optionNum: anchor.BN;
  observationTime: anchor.BN;
  timeIncrement: anchor.BN;
  timeBuffer: anchor.BN;
}

export interface OverrideVaultStatusArgs {
  status: number;
}

export interface VaultBumps {
  vault: number;
  vaultAuthority: number;
  redeemableMint: number;
  vaultUnderlying: number;
}

export interface EpochTimes {
  startEpoch: anchor.BN;
  startDeposits: anchor.BN;
  endDeposits: anchor.BN;
  endEpoch: anchor.BN;
  epochCadence: number;
}

export interface FeeRecipient {
  recipient: PublicKey;
  percentage: number;
}

export interface CreateTokenMetadataArgs {
  name: string;
  symbol: string;
  uri: string;
}
