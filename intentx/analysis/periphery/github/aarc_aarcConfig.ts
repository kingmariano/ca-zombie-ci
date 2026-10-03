import {
  FKConfig,
  ThemeName,
  TransactionSuccessData,
  TransactionErrorData,
  SourceConnectorName,
} from "@aarc-xyz/fundkit-web-sdk";
import { DIAMOND_ADDRESS, SupportedChainId } from "../constants";

export const aarcConfig: FKConfig = {
  appName: "IntentX x Aarc",
  module: {
    exchange: {
      enabled: true,
    },
    onRamp: {
      enabled: true,
      onRampConfig: {},
    },
    bridgeAndSwap: {
      enabled: true,
      fetchOnlyDestinationBalance: false,
      routeType: "Value",
      connectors: [SourceConnectorName.ETHEREUM],
    },
  },
  destination: {
    contract: {
      contractAddress: DIAMOND_ADDRESS[SupportedChainId.BASE],
      contractName: "IntentX Deposit",
      contractPayload: "0x", // This will be updated dynamically
      contractGasLimit: "300000", // Standard gas limit, can be adjusted if needed
    },
    walletAddress: DIAMOND_ADDRESS[SupportedChainId.BASE],
    chainId: 8453, // Base chain ID
    tokenAddress: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", // USDC on Base
  },
  appearance: {
    roundness: 42,
    theme: ThemeName.DARK,
  },
  apiKeys: {
    aarcSDK: import.meta.env.VITE_AARC_API_KEY,
  },
  events: {
    onTransactionSuccess: (data: TransactionSuccessData) => {
      console.log("Transaction successful:", data);
    },
    onTransactionError: (data: TransactionErrorData) => {
      console.error("Transaction failed:", data);
    },
    onWidgetClose: () => {
      console.log("Widget closed");
    },
    onWidgetOpen: () => {
      console.log("Widget opened");
    },
  },
  origin: window.location.origin,

}; 