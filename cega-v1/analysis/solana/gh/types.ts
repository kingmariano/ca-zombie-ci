import { PublicKey } from '@solana/web3.js';
import { VaultStatus } from './program-types';

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

// This is the code name for a "basket" but kept vague
export interface Product {
  address: PublicKey;
  productName: string;
  productCounter: number;
  underlyingMint: PublicKey;
  productUnderlyingTokenAccount: PublicKey;
  maxDepositLimit: number;
  managementFeePercentage: number;
  underlyingAmount: number;
  mapleAccount: PublicKey;
  depositQueueHeader: PublicKey;
  depositQueue: QueueNode[];
  isActive: boolean;
}

export interface StructuredProductInfoAccount {
  address: PublicKey;
  vaultAddress?: PublicKey;
  aprPercentage: number;
  daysPassed: number;
  epochSequenceNumber: number;
  numberOfPuts: number;
  tenorInDays: number;
  putOne: PublicKey; // Unused
  putTwo: PublicKey; // Unused
  putThree: PublicKey; // Unused
  putFour: PublicKey; // Unused
  putFive: PublicKey; // Unused
}

export interface Vault {
  address: PublicKey;
  productName: string;
  vaultNumber: number;
  underlyingMint: PublicKey;
  redeemableMint: PublicKey;
  vaultWithdrawQueueRedeemableTokenAccount: PublicKey;
  structuredProductInfoAccount: PublicKey;

  // Following values remaing as Big Number for accurate calculations
  underlyingAmount: number;
  vaultTotalCouponPayoff: number;
  vaultFinalPayoff: number;

  status: VaultStatus | undefined;
  knockInEvent: boolean;
  knockOutEvent: boolean;

  epochSequenceNumber: number;
  epochTimes: EpochTimes;
  epochTimesUnix: epochTimesUnix; // used to store the timings in raw unix numbers
  withdrawQueueHeader: PublicKey;
  withdrawalQueue: QueueNode[];

  // No Longer Used
  option: any | undefined; // Option
  vaultOptionTokenAccount: PublicKey | undefined;
}

export interface DepositInfo {
  depositInfoNonce: number;
  userKey: PublicKey;
  productAddress: PublicKey;
  vaultAddress: PublicKey;
  usdcDeposit: number;
}

export interface OptionBarrierDetailsUpdate {
  assetName: string;
  optionNumber: number;
  oracle: PublicKey;
  oracleType: number;
}

export interface OptionBarrierConfigInfo {
  assetName: string;
  optionNumber: number;
  oracle: PublicKey;
  oracleType: number;
  strikePercentage: number;
  knockInPercentage: number;
  knockOutPercentage: number;
  observationTime: number; // unix timestamp
  timeBuffer: number;
  timeIncrement: number;
}

export interface OptionBarrier {
  address: PublicKey;
  optionExists: boolean;
  assetName: string;
  optionNumber: number;
  assetMint: PublicKey;
  strikeAbs?: number | null; // anchor.BN - TODO: rework for Option<u64>
  knockInAbs?: number | null; // anchor.BN
  knockOutAbs?: number | null; // anchor.BN
  lastPrice?: number | null; // anchor.BN
  isOverridePrice: boolean;
  overridePrice: number;
  oracle: PublicKey;
  oracleType: number;
  observationTime: number;
  timeBuffer: number;
  timeIncrement: number;
}

export interface EpochTimes {
  startEpoch: Date;
  startDeposits: Date;
  endDeposits: Date;
  endEpoch: Date;
  tradeDate: Date;
  epochCadence: number;
}

// all of these units are in seconds
export interface epochTimesUnix {
  startEpoch: number;
  startDeposits: number;
  endDeposits: number;
  endEpoch: number;
  tradeDate: number;
  epochCadence: number;
}

export interface VaultTokens {
  vault: PublicKey;
  tokenAccount: PublicKey;
  amount: number;
}

export interface QueueNode {
  address: PublicKey;
  info: QueueNodeInfo;
}

export interface QueueNodeInfo {
  amount: number;
  nextNode: PublicKey;
  userKey: PublicKey;
}

export interface QueuedNodes {
  product: PublicKey;
  vault: PublicKey;
  nodes: QueueNode[];
}
