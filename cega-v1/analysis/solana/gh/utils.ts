import * as anchor from '@project-serum/anchor';
import { PublicKey } from '@solana/web3.js';
import { VaultStatus } from './program-types';
import _ from 'lodash';

export const REDEEMABLE_MINT_SEED = 'redeemable-mint';
export const STATE_SEED = 'state';
export const PRODUCT_SEED = 'product';
export const PRODUCT_UNDERLYING_SEED = 'product-underlying';
export const PRODUCT_AUTHORITY_SEED = 'vault-authority';
export const USER_REDEEMABLE_SEED = 'user-redeemable';
export const DEPOSIT_QUEUE_SEED = 'deposit-queue';
export const VAULT_DEPOSIT_QUEUE_UNDERLYING_SEED = 'vault-deposit-queue-underlying';
export const WITHDRAW_QUEUE_SEED = 'withdraw-queue';
export const VAULT_WITHDRAW_QUEUE_REDEEMABLE_SEED = 'vault-withdraw-queue-redeemable';
export const OPTION_MINT_SEED = 'option-mint';
export const STRUCTURED_PRODUCT_INFO_SEED = 'structured-product';
export const PUT_ONE_SEED = 'put-one';
export const PUT_TWO_SEED = 'put-two';
export const PUT_THREE_SEED = 'put-three';
export const PUT_FOUR_SEED = 'put-four';
export const PUT_FIVE_SEED = 'put-five';
export const PROGRAM_USDC_TOKEN_SEED = 'program-usdc-token';
export const METADATA_SEED = 'metadata';

export async function getStateAddress(programId: PublicKey): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync([Buffer.from('state')], programId);
}

export async function getProductAddress(
  productName: string,
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync(
    [Buffer.from(PRODUCT_SEED), Buffer.from(productName)],
    programId,
  );
}

export async function getProductUnderlyingTokenAddress(
  product: PublicKey,
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync(
    [Buffer.from(PRODUCT_UNDERLYING_SEED), product.toBuffer()],
    programId,
  );
}

export async function getDepositQueueHeaderAddress(
  productAddress: PublicKey,
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync(
    [Buffer.from(DEPOSIT_QUEUE_SEED), productAddress.toBuffer()],
    programId,
  );
}

export async function getDepositQueueNodeAddress(
  queueHeader: PublicKey,
  userKey: PublicKey,
  seqNum: anchor.BN,
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync(
    [
      Buffer.from(DEPOSIT_QUEUE_SEED),
      queueHeader.toBuffer(),
      userKey.toBuffer(),
      seqNum.toArrayLike(Buffer, 'le', 8),
    ],
    programId,
  );
}

export async function getVaultAddress(
  productName: string,
  vaultNumber: anchor.BN,
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync(
    [Buffer.from(productName), vaultNumber.toArrayLike(Buffer, 'le', 8)],
    programId,
  );
}

export async function getOptionBarrierAddress(
  optionNumber: anchor.BN,
  vaultAddress: PublicKey,
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync(
    [optionNumber.toArrayLike(Buffer, 'le', 8), vaultAddress.toBuffer()],
    programId,
  );
}

export async function getRedeemableMintAddress(
  vaultAddress: PublicKey,
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync(
    [Buffer.from(REDEEMABLE_MINT_SEED), vaultAddress.toBuffer()],
    programId,
  );
}

export async function getOptionMintAddress(
  vaultAddress: PublicKey,
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync(
    [Buffer.from(OPTION_MINT_SEED), vaultAddress.toBuffer()],
    programId,
  );
}

export async function getProductAuthorityAddress(
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync([Buffer.from(PRODUCT_AUTHORITY_SEED)], programId);
}

export async function getProductUnderlyingTokenAccountAddress(
  productAddress: PublicKey,
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync(
    [Buffer.from(PRODUCT_UNDERLYING_SEED), productAddress.toBuffer()],
    programId,
  );
}

export async function getVaultOptionTokenAccountAddress(
  optionMint: PublicKey,
  vaultAddress: PublicKey,
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync(
    [optionMint.toBuffer(), vaultAddress.toBuffer()],
    programId,
  );
}

export async function getProgramUsdcTokenAccountAddress(
  underlyingMint: PublicKey,
  productAuthorityAddress: PublicKey,
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync(
    [
      Buffer.from(PROGRAM_USDC_TOKEN_SEED),
      underlyingMint.toBuffer(),
      productAuthorityAddress.toBuffer(),
    ],
    programId,
  );
}

export async function getDepositInfoAccountAddress(
  userKey: PublicKey,
  vaultAddress: PublicKey,
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync([userKey.toBuffer(), vaultAddress.toBuffer()], programId);
}

export async function getWithdrawQueueHeaderAddress(
  vaultAddress: PublicKey,
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync(
    [Buffer.from(WITHDRAW_QUEUE_SEED), vaultAddress.toBuffer()],
    programId,
  );
}

export async function getWithdrawQueueNodeAddress(
  queueHeader: PublicKey,
  userKey: PublicKey,
  seqNum: anchor.BN,
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync(
    [
      Buffer.from(WITHDRAW_QUEUE_SEED),
      queueHeader.toBuffer(),
      userKey.toBuffer(),
      seqNum.toArrayLike(Buffer, 'le', 8),
    ],
    programId,
  );
}

export async function getVaultWithdrawQueueRedeemableTokenAccountAddress(
  vaultAddress: PublicKey,
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync(
    [Buffer.from(VAULT_WITHDRAW_QUEUE_REDEEMABLE_SEED), vaultAddress.toBuffer()],
    programId,
  );
}

export async function getStructuredProductInfoAccountAddress(
  vaultAddress: PublicKey,
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync(
    [Buffer.from(STRUCTURED_PRODUCT_INFO_SEED), vaultAddress.toBuffer()],
    programId,
  );
}

export async function getMetadataAccountAddress(
  redeemableMint: PublicKey,
  mplTokenMetadataProgram: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync(
    [Buffer.from(METADATA_SEED), mplTokenMetadataProgram.toBuffer(), redeemableMint.toBuffer()],
    mplTokenMetadataProgram,
  );
}

export async function getNthPutAccountAddress(
  putNumber: number,
  vaultAddress: PublicKey,
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  let seedConstant = '';
  switch (putNumber) {
    case 1:
      seedConstant = PUT_ONE_SEED;
      break;
    case 2:
      seedConstant = PUT_TWO_SEED;
      break;
    case 3:
      seedConstant = PUT_THREE_SEED;
      break;
    case 4:
      seedConstant = PUT_FOUR_SEED;
      break;
    case 5:
      seedConstant = PUT_FIVE_SEED;
      break;
    default:
      break;
  }
  return PublicKey.findProgramAddressSync(
    [Buffer.from(seedConstant), vaultAddress.toBuffer()],
    programId,
  );
}

export async function getRandomAccount(
  vaultAddress: PublicKey,
  programId: PublicKey,
): Promise<[PublicKey, number]> {
  return PublicKey.findProgramAddressSync(
    [Buffer.from('random-lol'), vaultAddress.toBuffer()],
    programId,
  );
}

// Methods for SDK

// enums are stored in Rust not as integrers, but rather obejcts
// for example, a status with traded status is represented as { traded: {} }
export function getStatusNumber(status: any) {
  if (_.isEqual(status, { notTraded: {} })) {
    return VaultStatus.NotTraded;
  }
  if (_.isEqual(status, { traded: {} })) {
    return VaultStatus.Traded;
  }
  if (_.isEqual(status, { epochEnded: {} })) {
    return VaultStatus.EpochEnded;
  }
  if (_.isEqual(status, { payoffCalculated: {} })) {
    return VaultStatus.PayoffCalculated;
  }
  if (_.isEqual(status, { feesCollected: {} })) {
    return VaultStatus.FeesCollected;
  }
  if (_.isEqual(status, { processingWithdrawQueue: {} })) {
    return VaultStatus.ProcessingWithdrawQueue;
  }
  if (_.isEqual(status, { withdrawQueueProcessed: {} })) {
    return VaultStatus.WithdrawQueueProcessed;
  }
  if (_.isEqual(status, { zombie: {} })) {
    return VaultStatus.Zombie;
  }
  if (_.isEqual(status, { processingDepositQueue: {} })) {
    return VaultStatus.ProcessingDepositQueue;
  }
  if (_.isEqual(status, { depositQueueProcessed: {} })) {
    return VaultStatus.DepositQueueProcessed;
  }
  return undefined;
}

export function nextUTC(hour: number): number {
  const date = new Date();
  const nowUTC =
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), hour, 0, 0) / 1000;
  if (date.getUTCHours() < hour) {
    return nowUTC;
  }
  return nowUTC + 60 * 60 * 24;
}
