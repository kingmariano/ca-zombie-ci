import { PublicKey } from '@solana/web3.js';
import * as anchor from '@project-serum/anchor';

export interface State {
  stateNonce: number;
  productAuthorityNonce: number;
  admin: PublicKey;
  nextAdmin: PublicKey;
  yieldFeePercentage: number;
  managementFeePercentage: number;
  feeRecipient: PublicKey;
  traderAdmin: PublicKey;
}

export interface Product {
  productName: Array<number>;
  productNonce: number;
  productUnderlyingTokenAccountNonce: number;
  productCounter: anchor.BN;
  underlyingMint: PublicKey;
  productUnderlyingTokenAccount: PublicKey;
  maxDepositLimit: anchor.BN;
  managementFeePercentage: anchor.BN;
  underlyingAmount: anchor.BN;
  mapleAccount: PublicKey;
  depositQueueHeaderNonce: number;
  depositQueueHeader: PublicKey;
  isActive: boolean;
}

export interface FeeRecipient {
  recipient: PublicKey;
  percentage: number;
}

export interface Vault {
  productName: Array<number>;
  vaultNumber: anchor.BN;
  vaultNonce: number;
  redeemableMintNonce: number;
  vaultUnderlyingTokenNonce: number;
  withdrawQueueHeaderNonce: number;
  vaultWithdrawQueuuRedeemableTokenAccountNonce: number;
  underlyingMint: PublicKey;
  redeemableMint: PublicKey;
  withdrawQueueHeader: PublicKey;
  vaultWithdrawQueueRedeemableTokenAccount: PublicKey;
  structuredProductInfoAccount: PublicKey;
  underlyingAmount: anchor.BN;
  vaultTotalCouponPayoff: anchor.BN;
  vaultFinalPayoff: anchor.BN;

  status: VaultStatus;
  knockInEvent: boolean;
  knockOutEvent: boolean;

  epochSequenceNumber: anchor.BN;
  startEpoch: anchor.BN;
  endDeposits: anchor.BN;
  startDeposits: anchor.BN;
  endEpoch: anchor.BN;
  tradeDate: anchor.BN;
  epochCadence: number;

  // Unused
  optionMint: PublicKey;
  optionsRemaining: boolean;
  collateralCollected: boolean;
}

export interface DepositInfo {
  depositInfoNonce: number;
  userKey: PublicKey;
  product: PublicKey;
  vault: PublicKey;
  usdcDeposit: anchor.BN;
}

export interface StructuredProductInfoAccount {
  structuredProductInfoAccountNonce: number;
  epochSequenceNumber: anchor.BN;
  numberOfPuts: anchor.BN;
  putOne: PublicKey; // Unused
  putTwo: PublicKey; // Unused
  putThree: PublicKey; // Unused
  putFour: PublicKey; // Unused
  putFive: PublicKey; // Unused
  aprPercentage: anchor.BN;
  daysPassed: anchor.BN;
  tenorInDays: anchor.BN;
}

export interface OptionBarrier {
  optionBarrierNonce: number;
  optionExists: boolean;
  assetName: Array<number>;
  optionNumber: anchor.BN;
  assetMint: PublicKey;
  strikeAbs?: any; // anchor.BN - TODO: rework for Option<u64>
  knockInAbs?: any; // anchor.BN
  knockOutAbs?: any; // anchor.BN
  lastPrice?: any; // anchor.BN
  isOverridePrice: boolean;
  overridePrice: anchor.BN;
  oracle: PublicKey;
  oracleType: number;
  observationTime: anchor.BN;
  timeBuffer: anchor.BN;
  timeIncrement: anchor.BN;
}

export interface QueueHeader {
  count: anchor.BN;
  seqNum: anchor.BN;
  head: PublicKey;
  tail: PublicKey;
}

export interface QueueNode {
  amount: anchor.BN;
  nextNode: PublicKey;
  userKey: PublicKey;
}

export enum VaultStatus {
  NotTraded,
  Traded,
  EpochEnded,
  PayoffCalculated,
  FeesCollected,
  ProcessingWithdrawQueue,
  WithdrawQueueProcessed,
  Zombie,
  ProcessingDepositQueue,
  DepositQueueProcessed,
}
