import * as anchor from '@project-serum/anchor';
import {
  PublicKey,
  Connection,
  ConfirmOptions,
  Transaction,
  AccountMeta,
  TransactionSignature,
  Keypair,
  ComputeBudgetProgram,
} from '@solana/web3.js';
import {
  getAssociatedTokenAddress,
  getAccount,
  createAssociatedTokenAccountInstruction,
  Account,
} from '@solana/spl-token';
import * as mpl from '@metaplex-foundation/mpl-token-metadata';
import idl from '../idl/cega_vault.json';
import { CegaVault } from '../types/cega_vault';
import { Network } from '../common/network';
import * as utils from '../common/utils';
import * as vaultUtils from './utils';
import * as instructions from './instructions';
import { Program } from '../common/program';
import * as programTypes from './program-types';
import * as types from './types';
import * as vaultConstants from './constants';
import { SOL_PRIORITY_FEE } from '../config/environment';

export class CegaSDK {
  public get isInitialized(): boolean {
    return this._isInitialized;
  }

  private _isInitialized: boolean;

  /**
   * Anchor program instance.
    await utils.processTransaction(Program.VAULT, this._provider, tx);
   */
  public get program(): anchor.Program<CegaVault> {
    return this._program;
  }

  private _program: anchor.Program<CegaVault>;

  public get programId(): PublicKey {
    return this._program.programId;
  }

  /**
   * Anchor provider instance.
   */
  public get provider(): anchor.AnchorProvider {
    return this._provider;
  }

  public get network(): Network {
    return this._network;
  }

  private _network: Network;

  private _provider: anchor.AnchorProvider;

  public get stateAddress(): PublicKey {
    return this._stateAddress;
  }

  private _stateAddress!: PublicKey;

  // public get vaultAuthority(): PublicKey {
  //   return this._vaultAuthority;
  // }
  // private _vaultAuthority: PublicKey;
  public get productAuthority(): PublicKey {
    return this._productAuthority;
  }

  private _productAuthority!: PublicKey;

  public get state(): types.State {
    return this._state;
  }

  private _state!: types.State;

  public get products(): types.Product[] {
    return this._products;
  }

  private _products!: types.Product[];

  public get vaults(): types.Vault[] {
    return this._vaults;
  }

  private _vaults: types.Vault[] = [];

  private _eventListeners: any[] = [];

  public assertInitialized() {
    if (!this.isInitialized) {
      throw Error('Vault not initialized!');
    }
  }

  public assertUninitialized() {
    if (this.isInitialized) {
      throw Error('Vault already initialized!');
    }
  }

  private constructor(
    connection: Connection,
    programId: PublicKey,
    wallet: anchor.Wallet,
    network: Network,
    opts: ConfirmOptions,
  ) {
    this.assertUninitialized();
    this._provider = new anchor.AnchorProvider(connection, wallet, opts);
    this._network = network;
    this._program = new anchor.Program(
      idl as anchor.Idl,
      programId,
      this._provider,
    ) as anchor.Program<CegaVault>;
    this._isInitialized = true;
  }

  // Wallet has to be state admin.
  public static async load(
    programId: PublicKey,
    network: Network,
    connection: Connection,
    wallet: anchor.Wallet,
    opts = utils.defaultCommitment(),
  ): Promise<CegaSDK> {
    const sdk = new CegaSDK(connection, programId, wallet, network, opts);
    const [state, _stateNonce] = await vaultUtils.getStateAddress(programId);
    const [productAuthority, _productAuthorityNonce] =
      await vaultUtils.getProductAuthorityAddress(programId);
    sdk._stateAddress = state;
    sdk._productAuthority = productAuthority;

    await sdk.updateProgramState();

    sdk._provider = new anchor.AnchorProvider(sdk._provider.connection, wallet, sdk._provider.opts);
    sdk._program = new anchor.Program(
      idl as anchor.Idl,
      sdk._program.programId,
      sdk._provider,
    ) as anchor.Program<CegaVault>;

    // TODO: for v2 repo, we're no longer pre-fetching and saving all state
    // await sdk.updateState();
    return sdk;
  }

  public async updateWallet(wallet: anchor.Wallet) {
    this._provider = new anchor.AnchorProvider(
      this._provider.connection,
      wallet,
      this._provider.opts,
    );
    this._program = new anchor.Program(
      idl as anchor.Idl,
      this._program.programId,
      this._provider,
    ) as anchor.Program<CegaVault>;
  }

  public async initializeState(
    admin: PublicKey,
    managementFeePercentage: number,
    yieldFeePercentage: number,
    feeRecipient: PublicKey,
  ): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.initializeStateIx(
        admin,
        this.provider.wallet.publicKey,
        managementFeePercentage,
        yieldFeePercentage,
        feeRecipient,
        this.programId,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateState();
    return txSig;
  }

  public async fundProductWallet(lamports: number) {
    const tx = new Transaction().add(
      await instructions.fundProductAuthorityIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        this.productAuthority,
        lamports,
        this.program,
      ),
    );
    await utils.processTransaction(Program.VAULT, this._provider, tx);
  }

  public async initializeProduct(
    productName: string,
    underlyingMint: PublicKey,
    maxDepositLimit: anchor.BN,
    mapleAccount: PublicKey,
  ): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.initializeProductIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        this.productAuthority,
        productName,
        underlyingMint,
        maxDepositLimit,
        mapleAccount,
        this.programId,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateProducts();
    return txSig;
  }

  public async initializeVault(
    productAccount: PublicKey,
    epochTimes: instructions.EpochTimes,
    epochSequenceNumber: anchor.BN,
  ) {
    const tx = new Transaction().add(
      await instructions.initializeVaultIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        this.productAuthority,
        productAccount,
        epochTimes,
        epochSequenceNumber,
        this.programId,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    console.info(`🎶 sig: ${txSig}`);
    return txSig;
  }

  public async initializeOptionBarriers(
    vault: PublicKey,
    optionBarrierConfigInfo: types.OptionBarrierConfigInfo[],
  ): Promise<TransactionSignature> {
    const tx = new Transaction();
    for (let i = 0; i < optionBarrierConfigInfo.length; i++) {
      const {
        assetName,
        optionNumber,
        oracle,
        oracleType,
        strikePercentage,
        knockInPercentage,
        knockOutPercentage,
        observationTime,
        timeBuffer,
        timeIncrement,
      } = optionBarrierConfigInfo[i];
      tx.add(
        await instructions.initializeOptionBarrierIx(
          this.stateAddress,
          this.provider.wallet.publicKey,
          this.productAuthority,
          vault,
          oracle,
          new anchor.BN(oracleType),
          assetName,
          new anchor.BN(optionNumber),
          new anchor.BN(strikePercentage),
          new anchor.BN(knockInPercentage),
          new anchor.BN(knockOutPercentage),
          new anchor.BN(observationTime),
          new anchor.BN(timeBuffer),
          new anchor.BN(timeIncrement),
          this.programId,
          this.program,
        ),
      );
    }
    return utils.processTransaction(Program.VAULT, this._provider, tx);
  }

  public async updateOptionBarrierDetails(
    vault: PublicKey,
    optionBarrierDetailsUpdate: types.OptionBarrierDetailsUpdate,
  ): Promise<TransactionSignature> {
    const tx = new Transaction();
    const { assetName, optionNumber, oracle, oracleType } = optionBarrierDetailsUpdate;
    tx.add(
      await instructions.updateOptionBarrierDetailsIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        vault,
        oracle,
        new anchor.BN(oracleType),
        assetName,
        new anchor.BN(optionNumber),
        this.programId,
        this.program,
      ),
    );

    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    console.info(`txSig: ${txSig}`);

    return txSig;
  }

  // strike is native integer 6dp
  public async initializeStructuredProduct(
    vault: PublicKey,
    aprPercentage: anchor.BN,
    tenorInDays: anchor.BN,
    numberOfPuts: anchor.BN,
  ): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.initializeStructuredProductIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        this.productAuthority,
        vault,
        aprPercentage,
        tenorInDays,
        numberOfPuts,
        this.programId,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateProducts();
    await this.updateVaults();
    console.info(`🍷 initialized. Signature: ${txSig}`);
    return txSig;
  }

  public async initializeProgramUsdcTokenAccount(
    productAddress: PublicKey,
    vaultAddress: PublicKey,
  ): Promise<string | undefined> {
    const product = this.getProduct(productAddress);
    const vault = this.getVault(vaultAddress);

    const tx = new Transaction();

    const [productAuthorityUnderlyingToken, _productAuthorityUnderlyingTokenNonce] =
      await vaultUtils.getProgramUsdcTokenAccountAddress(
        product.underlyingMint,
        this.productAuthority,
        this.programId,
      );

    // See if it's token account exists, if not add it to the transaction
    try {
      await getAccount(this._provider.connection, productAuthorityUnderlyingToken);
    } catch (e) {
      console.error(
        `Program hasn't initialized programUsdcTokenAccount yet. Address is: ${productAuthorityUnderlyingToken.toString()}. Creating account.`,
      );
      tx.add(
        await instructions.initializeProgramUsdcAccountIx(
          this.stateAddress,
          this.provider.wallet.publicKey,
          this.productAuthority,
          vault.underlyingMint,
          this.programId,
          this.program,
        ),
      );
      const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
      return txSig;
    }

    return undefined;
  }

  public async setProductDepositQueue(productAddress: PublicKey): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.setProductDepositQueue(
        this.stateAddress,
        this.provider.wallet.publicKey,
        this.productAuthority,
        productAddress,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateProducts();
    return txSig;
  }

  public async setProductState(
    productAddress: PublicKey,
    isActive: boolean,
  ): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.setProductState(
        this.stateAddress,
        this.provider.wallet.publicKey,
        this.productAuthority,
        productAddress,
        this.program,
        isActive,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateProducts();
    return txSig;
  }

  public async transferToProgramUnderlyingTokenAccount(
    productAddress: PublicKey,
    vaultAddress: PublicKey,
  ): Promise<TransactionSignature> {
    return this.bulkTransferToProgramUnderlyingTokenAccount([{ productAddress, vaultAddress }]);
  }

  public async bulkTransferToProgramUnderlyingTokenAccount(
    vaultInfoList: {
      productAddress: PublicKey;
      vaultAddress: PublicKey;
    }[],
  ): Promise<TransactionSignature> {
    let tx = new Transaction();

    // See if it's token account exists, if not add it to the transaction
    const firstProduct = this.getProduct(vaultInfoList[0].productAddress);
    try {
      const [programUsdcTokenAccount, _programUsdcTokenAccountNonce] =
        await vaultUtils.getProgramUsdcTokenAccountAddress(
          firstProduct.underlyingMint,
          this.productAuthority,
          this.programId,
        );
      await getAccount(this._provider.connection, programUsdcTokenAccount);
    } catch (error) {
      console.error(
        "Program hasn't initialized programUsdcTokenAccount yet. Adding instruction.",
        error,
      );
      tx.add(
        await instructions.initializeProgramUsdcAccountIx(
          this.stateAddress,
          this.provider.wallet.publicKey,
          this.productAuthority,
          firstProduct.underlyingMint,
          this.programId,
          this.program,
        ),
      );
    }

    for (const vaultInfo of vaultInfoList) {
      const product = this.getProduct(vaultInfo.productAddress);
      const vault = this.getVault(vaultInfo.vaultAddress);

      tx = tx.add(
        await instructions.transferToProgramUnderlyingTokenAccountIx(
          this.stateAddress,
          this.provider.wallet.publicKey,
          this.productAuthority,
          product.address,
          product.productUnderlyingTokenAccount,
          vault.address,
          vault.underlyingMint,
          vault.redeemableMint,
          this.programId,
          this.program,
        ),
      );
    }

    // Add compute budget instructions
    tx.add(ComputeBudgetProgram.setComputeUnitPrice({ microLamports: SOL_PRIORITY_FEE }));
    tx.add(ComputeBudgetProgram.setComputeUnitLimit({ units: 300000 }));

    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    return txSig;
  }

  public async transferToProductUnderlyingTokenAccount(
    productAddress: PublicKey,
    amountToTransfer: anchor.BN,
  ): Promise<TransactionSignature> {
    return this.bulkTransferToProductUnderlyingTokenAccounts([
      { productAddress, amountToTransfer },
    ]);
  }

  public async bulkTransferToProductUnderlyingTokenAccounts(
    entries: {
      productAddress: PublicKey;
      amountToTransfer: anchor.BN;
    }[],
  ): Promise<TransactionSignature> {
    const tx = new Transaction();

    for (const entry of entries) {
      const product = this.getProduct(entry.productAddress);

      const [productAuthorityUnderlyingToken, _productAuthorityUnderlyingTokenNonce] =
        await vaultUtils.getProgramUsdcTokenAccountAddress(
          product.underlyingMint,
          this.productAuthority,
          this.programId,
        );

      // Create Product underlying token account if it doesn't exist
      try {
        await getAccount(this._provider.connection, productAuthorityUnderlyingToken);
      } catch (e) {
        console.error(
          'Program has not initialized programUsdcTokenAccount yet. Address is:',
          productAuthorityUnderlyingToken.toString(),
          'Creating account.',
          e,
        );
        tx.add(
          await instructions.initializeProgramUsdcAccountIx(
            this.stateAddress,
            this.provider.wallet.publicKey,
            this.productAuthority,
            product.underlyingMint,
            this.programId,
            this.program,
          ),
        );
      }

      tx.add(
        await instructions.transferToProductUnderlyingTokenAccountIx(
          entry.amountToTransfer,
          this.stateAddress,
          this.provider.wallet.publicKey,
          this.productAuthority,
          product.underlyingMint,
          product.address,
          product.productUnderlyingTokenAccount,
          this.programId,
          this.program,
        ),
      );
    }

    tx.add(ComputeBudgetProgram.setComputeUnitPrice({ microLamports: SOL_PRIORITY_FEE }));
    tx.add(ComputeBudgetProgram.setComputeUnitLimit({ units: 1000000 }));
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateProducts();
    return txSig;
  }

  public async sendFundsToMarketMakers(
    underlyingMint: PublicKey,
    marketMakerAddress: PublicKey,
    amountToSend: anchor.BN,
  ): Promise<TransactionSignature> {
    return this.bulkSendFundsToMarketMakers([
      {
        underlyingMint,
        marketMakerAddress,
        amountToSend,
      },
    ]);
  }

  public async bulkSendFundsToMarketMakers(
    fundTransferEntries: {
      underlyingMint: PublicKey;
      marketMakerAddress: PublicKey;
      amountToSend: anchor.BN;
    }[],
  ): Promise<TransactionSignature> {
    const tx = new Transaction();
    for (const entry of fundTransferEntries) {
      // See if it's market maker's token account exists. If not, create it for them
      const marketMakerUnderlyingTokenAccount = await getAssociatedTokenAddress(
        entry.underlyingMint,
        entry.marketMakerAddress,
      );

      try {
        await getAccount(this._provider.connection, marketMakerUnderlyingTokenAccount);
      } catch (e) {
        console.info(
          `Market Maker does not have associated USDC token account: ${marketMakerUnderlyingTokenAccount}. Creating account for them.`,
        );

        tx.add(
          await createAssociatedTokenAccountInstruction(
            this.provider.wallet.publicKey,
            marketMakerUnderlyingTokenAccount,
            entry.marketMakerAddress,
            entry.underlyingMint,
          ),
        );
      }

      tx.add(
        await instructions.sendFundsToMarketMakersIx(
          entry.amountToSend,
          this.stateAddress,
          this.provider.wallet.publicKey,
          this.productAuthority,
          entry.underlyingMint,
          entry.marketMakerAddress,
          marketMakerUnderlyingTokenAccount,
          this.programId,
          this.program,
        ),
      );
      // Add compute budget instructions
      tx.add(ComputeBudgetProgram.setComputeUnitPrice({ microLamports: SOL_PRIORITY_FEE }));
      tx.add(ComputeBudgetProgram.setComputeUnitLimit({ units: 60000 }));
    }

    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateProducts();
    return txSig;
  }

  public async setOptionSpotPrices(
    vaultAddress: PublicKey,
    args: instructions.SetOptionBarrierAbsArgs[],
  ): Promise<TransactionSignature> {
    return this.bulkSetOptionSpotPrices([{ vaultAddress, args }]);
  }

  public async bulkSetOptionSpotPrices(
    entries: {
      vaultAddress: PublicKey;
      args: instructions.SetOptionBarrierAbsArgs[];
    }[],
  ): Promise<TransactionSignature> {
    let tx = new Transaction();
    for (const entry of entries) {
      for (const optionOverride of entry.args) {
        const [optionAddress, _optionNonce] = await vaultUtils.getOptionBarrierAddress(
          optionOverride.optionNum,
          entry.vaultAddress,
          this.programId,
        );
        tx = tx.add(
          await instructions.setOptionBarrierAbsIx(
            this.stateAddress,
            this.provider.wallet.publicKey,
            entry.vaultAddress,
            this.program,
            optionAddress,
            optionOverride.strike,
            optionOverride.knockIn,
            optionOverride.knockOut,
          ),
        );
      }
    }

    // Add compute budget instructions
    tx.add(ComputeBudgetProgram.setComputeUnitPrice({ microLamports: SOL_PRIORITY_FEE }));
    tx.add(ComputeBudgetProgram.setComputeUnitLimit({ units: entries.length * 30000 }));

    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    return txSig;
  }

  public async setOptionObservationPeriod(
    vaultAddress: PublicKey,
    args: instructions.OverrideOptionBarrierObservationArgs[],
  ): Promise<TransactionSignature> {
    let tx = new Transaction();
    for (const observationOverride of args) {
      const [optionAddress, _] = await vaultUtils.getOptionBarrierAddress(
        observationOverride.optionNum,
        vaultAddress,
        this.programId,
      );
      tx = tx.add(
        await instructions.overrideObservationPeriodIx(
          this.stateAddress,
          this.provider.wallet.publicKey,
          optionAddress,
          {
            observationTime: observationOverride.observationTime,
            timeBuffer: observationOverride.timeBuffer,
            timeIncrement: observationOverride.timeIncrement,
          },
          this.program,
        ),
      );
    }
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    return txSig;
  }

  public async bulkSetOptionObservationPeriod(
    entries: {
      vaultAddress: PublicKey;
      args: instructions.OverrideOptionBarrierObservationArgs[];
    }[],
  ): Promise<TransactionSignature> {
    let tx = new Transaction();
    for (const entry of entries) {
      for (const observationOverride of entry.args) {
        const [optionAddress, _] = await vaultUtils.getOptionBarrierAddress(
          observationOverride.optionNum,
          entry.vaultAddress,
          this.programId,
        );
        tx = tx.add(
          await instructions.overrideObservationPeriodIx(
            this.stateAddress,
            this.provider.wallet.publicKey,
            optionAddress,
            {
              observationTime: observationOverride.observationTime,
              timeBuffer: observationOverride.timeBuffer,
              timeIncrement: observationOverride.timeIncrement,
            },
            this.program,
          ),
        );
      }
    }
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    return txSig;
  }

  public async runCalculationAgent(vaultAddress: PublicKey): Promise<TransactionSignature> {
    const vault = this.getVault(vaultAddress);
    const remainingAccounts = await this.getOracleRemainingAccounts(vault);

    const ix = await instructions.calculationAgentIx(
      this.stateAddress,
      this.provider.wallet.publicKey,
      this.productAuthority,
      vault,
      remainingAccounts,
      this.program,
    );
    const tx = new Transaction().add(ix);
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    return txSig;
  }

  public async transferBetweenProducts(
    productFromName: string,
    productDestinationName: string,
    amount: number,
  ): Promise<TransactionSignature> {
    const ix = await instructions.transferBetweenProductsIx(
      this.stateAddress,
      this.provider.wallet.publicKey,
      this.productAuthority,
      productFromName,
      productDestinationName,
      new anchor.BN(amount),
      this.programId,
      this.program,
    );
    const tx = new Transaction().add(ix);
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    await this.updateProducts();
    return txSig;
  }

  public async calculateCurrentYield(
    productAddress: PublicKey,
    vaultAddress: PublicKey,
  ): Promise<TransactionSignature> {
    const product = this.getProduct(productAddress);
    const vault = this.getVault(vaultAddress);

    const ix = await instructions.calculateCurrentYieldIx(
      this.stateAddress,
      this.provider.wallet.publicKey,
      product,
      vault,
      this.program,
    );
    const tx = new Transaction().add(ix);
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    await this.updateProducts();
    return txSig;
  }

  public async calculateVaultPayoff(
    productAddress: PublicKey,
    vaultAddress: PublicKey,
  ): Promise<TransactionSignature> {
    const product = this.getProduct(productAddress);
    const vault = this.getVault(vaultAddress);
    const remainingAccounts = await this.getOracleRemainingAccounts(vault);

    const ix = await instructions.calculateVaultPayoffIx(
      this.stateAddress,
      this.provider.wallet.publicKey,
      this.productAuthority,
      product,
      vault,
      remainingAccounts,
      this.program,
    );
    const tx = new Transaction().add(ix);
    tx.add(ComputeBudgetProgram.setComputeUnitPrice({ microLamports: SOL_PRIORITY_FEE }));
    tx.add(ComputeBudgetProgram.setComputeUnitLimit({ units: 30000 })); //https://explorer.solana.com/tx/2xD2xabDD14JMZa4Q1ZZ64JLYDHUwWkCkV7qjBPiE6Tr4fnQJ3TE8F4WCJWVA3yqTwagiePC12oppW8LWaSBonM4?cluster=mainnet-beta
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    await this.updateProducts();
    return txSig;
  }

  public async bulkCalculateVaultPayoff(
    entries: {
      productAddress: PublicKey;
      vaultAddress: PublicKey;
    }[],
  ): Promise<TransactionSignature> {
    const tx = new Transaction();
    for (const entry of entries) {
      const product = this.getProduct(entry.productAddress);
      const vault = this.getVault(entry.vaultAddress);
      const remainingAccounts = await this.getOracleRemainingAccounts(vault);

      const ix = await instructions.calculateVaultPayoffIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        this.productAuthority,
        product,
        vault,
        remainingAccounts,
        this.program,
      );
      tx.add(ix);
    }

    tx.add(ComputeBudgetProgram.setComputeUnitPrice({ microLamports: SOL_PRIORITY_FEE }));
    tx.add(ComputeBudgetProgram.setComputeUnitLimit({ units: 30000 * entries.length }));
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);

    return txSig;
  }

  public async processWithdrawQueue(
    productAddress: PublicKey,
    vaultAddress: PublicKey,
  ): Promise<TransactionSignature[]> {
    return this.bulkProcessWithdrawQueue([{ productAddress, vaultAddress }]);
  }

  public async preProcessWithdrawQueue(
    productAddress: PublicKey,
    vaultAddress: PublicKey,
  ): Promise<TransactionSignature[]> {
    return this.bulkPreProcessWithdrawQueue([{ productAddress, vaultAddress }]);
  }

  public async bulkProcessWithdrawQueue(
    entries: {
      productAddress: PublicKey;
      vaultAddress: PublicKey;
    }[],
  ): Promise<TransactionSignature[]> {
    const txs = [];
    for (const entry of entries) {
      await this.updateWithdrawalQueue(entry.vaultAddress);
      const product = this.getProduct(entry.productAddress);
      const vault = this.getVault(entry.vaultAddress);
      const withdrawQueue = vault.withdrawalQueue;

      if (withdrawQueue.length !== 0) {
        for (let i = 0; i < withdrawQueue.length; i += vaultConstants.PROCESS_QUEUE_ACCOUNT_LIMIT) {
          const remainingAccounts: AccountMeta[] = [];
          const slice = withdrawQueue.slice(i, i + vaultConstants.PROCESS_QUEUE_ACCOUNT_LIMIT);
          for (let j = 0; j < slice.length; j += 1) {
            const userUnderlyingTokenAccountAddress = await getAssociatedTokenAddress(
              vault.underlyingMint,
              slice[j].info.userKey,
              true, // allowOwnerOffCurve
            );

            // See if it's token account exists, if not add it to the transaction
            try {
              await getAccount(this._provider.connection, userUnderlyingTokenAccountAddress);
            } catch (e) {
              console.info(
                `User does not have userUnderlyingTokenAccountAddress: ${userUnderlyingTokenAccountAddress}. Creating account.`,
              );
              const tx2 = new Transaction();
              tx2.add(
                await createAssociatedTokenAccountInstruction(
                  this.provider.wallet.publicKey,
                  userUnderlyingTokenAccountAddress,
                  slice[j].info.userKey,
                  vault.underlyingMint,
                ),
              );
              tx2.add(
                ComputeBudgetProgram.setComputeUnitPrice({ microLamports: SOL_PRIORITY_FEE }),
              );
              tx2.add(ComputeBudgetProgram.setComputeUnitLimit({ units: 100000 }));
              txs.push(tx2);
            }

            remainingAccounts.push({
              pubkey: slice[j].address,
              isSigner: false,
              isWritable: true,
            });
            remainingAccounts.push({
              pubkey: userUnderlyingTokenAccountAddress,
              isSigner: false,
              isWritable: true,
            });
            remainingAccounts.push({
              pubkey: slice[j].info.userKey,
              isSigner: false,
              isWritable: true,
            });
          }

          const tx = new Transaction();
          tx.add(
            await instructions.processWithdrawQueueIx(
              this.stateAddress,
              this.productAuthority,
              product,
              vault,
              remainingAccounts,
              this.program,
            ),
          );
          tx.add(ComputeBudgetProgram.setComputeUnitPrice({ microLamports: SOL_PRIORITY_FEE }));
          tx.add(ComputeBudgetProgram.setComputeUnitLimit({ units: 200000 }));
          txs.push(tx);
        }
      } else {
        console.info('Empty withdrawal queue...');
        // Need to still have a transaction to set vault status to
        // VaultStatus::WithdrawQueueProcessed
        const tx = new Transaction();
        tx.add(
          await instructions.processWithdrawQueueIx(
            this.stateAddress,
            this.productAuthority,
            product,
            vault,
            [],
            this.program,
          ),
        );
        tx.add(ComputeBudgetProgram.setComputeUnitPrice({ microLamports: SOL_PRIORITY_FEE }));
        tx.add(ComputeBudgetProgram.setComputeUnitLimit({ units: 100000 }));
        txs.push(tx);
      }
    }
    // Must be sequential
    const txSigs = [];
    for (let i = 0; i < txs.length; i += 1) {
      const txSig = await utils.processTransaction(Program.VAULT, this._provider, txs[i]);
      txSigs.push(txSig);
    }
    await this.updateProducts();
    await this.updateVaults();
    return txSigs;
  }

  public async bulkPreProcessWithdrawQueue(
    entries: {
      productAddress: PublicKey;
      vaultAddress: PublicKey;
    }[],
  ): Promise<TransactionSignature[]> {
    const txs = [];
    for (const entry of entries) {
      await this.updateWithdrawalQueue(entry.vaultAddress);
      const product = this.getProduct(entry.productAddress);
      const vault = this.getVault(entry.vaultAddress);
      const withdrawQueue = vault.withdrawalQueue;

      if (withdrawQueue.length !== 0) {
        for (let i = 0; i < withdrawQueue.length; i += 10) {
          const slice = withdrawQueue.slice(i, i + 10);
          for (let j = 0; j < slice.length; j += 1) {
            const userUnderlyingTokenAccountAddress = await getAssociatedTokenAddress(
              vault.underlyingMint,
              slice[j].info.userKey,
              true, // allowOwnerOffCurve
            );

            // See if it's token account exists, if not add it to the transaction
            try {
              await getAccount(this._provider.connection, userUnderlyingTokenAccountAddress);
            } catch (e) {
              console.info(
                `Queue node #${j} does not have userUnderlyingTokenAccountAddress: ${userUnderlyingTokenAccountAddress}. Creating account.`,
              );
              const tx2 = new Transaction();
              tx2.add(
                await createAssociatedTokenAccountInstruction(
                  this.provider.wallet.publicKey,
                  userUnderlyingTokenAccountAddress,
                  slice[j].info.userKey,
                  vault.underlyingMint,
                ),
              );

              tx2.add(ComputeBudgetProgram.setComputeUnitPrice({ microLamports: 400000 }));
              txs.push(tx2);
            }
          }
        }
      }
    }
    // Must be sequential
    const txSigs = [];
    for (let i = 0; i < txs.length; i += 1) {
      const txSig = await utils.processTransaction(Program.VAULT, this._provider, txs[i]);
      txSigs.push(txSig);
    }
    await this.updateProducts();
    await this.updateVaults();
    return txSigs;
  }

  public async processDepositQueue(
    productAddress: PublicKey,
    vaultAddress: PublicKey,
    skipEmptyQueueTransaction: boolean = false,
  ): Promise<TransactionSignature[]> {
    return this.bulkProcessDepositQueue(
      [{ productAddress, vaultAddress }],
      skipEmptyQueueTransaction,
    );
  }

  public async bulkProcessDepositQueue(
    entries: {
      productAddress: PublicKey;
      vaultAddress: PublicKey;
    }[],
    skipEmptyQueueTransaction: boolean = false,
  ): Promise<TransactionSignature[]> {
    const txs = [];
    // Dont create ATA for the same address, if there's already an IX to do so.
    const createATAIxsForAddresses: Record<string, boolean> = {};

    for (const entry of entries) {
      await this.updateDepositQueue(entry.productAddress);
      const product = this.getProduct(entry.productAddress);
      const vault = this.getVault(entry.vaultAddress);
      const { depositQueue } = product;

      // Solana contract requires a transaction to move VaultStatus to DepositQueueProcessed
      if (depositQueue.length === 0 && !skipEmptyQueueTransaction) {
        const tx = new Transaction();
        tx.add(
          await instructions.processDepositQueueIx(
            this.stateAddress,
            product,
            vault,
            this.productAuthority,
            [],
            this.program,
          ),
        );
        // Add compute budget instructions
        tx.add(ComputeBudgetProgram.setComputeUnitPrice({ microLamports: SOL_PRIORITY_FEE }));
        tx.add(ComputeBudgetProgram.setComputeUnitLimit({ units: 50000 }));
        txs.push(tx);
      }

      for (let i = 0; i < depositQueue.length; i += vaultConstants.DEPOSIT_QUEUE_ACCOUNT_LIMIT) {
        const remainingAccounts: AccountMeta[] = [];
        const slice = depositQueue.slice(i, i + vaultConstants.DEPOSIT_QUEUE_ACCOUNT_LIMIT);
        for (let j = 0; j < slice.length; j += 1) {
          const userRedeemableTokenAccountAddress = await getAssociatedTokenAddress(
            vault.redeemableMint,
            slice[j].info.userKey,
            true, // allowOwnerOffCurve
          );

          // See if it's token account exists, if not add createATA instruction to the transaction
          try {
            await getAccount(this._provider.connection, userRedeemableTokenAccountAddress);
          } catch (e) {
            // If there is already an instruction to create the ATA, we don't want to add it again
            if (!(userRedeemableTokenAccountAddress.toString() in createATAIxsForAddresses)) {
              console.info(
                `User does not have userRedeemableTokenAccountAddress: ${userRedeemableTokenAccountAddress}. Creating account.`,
              );
              const tx2 = new Transaction();
              tx2.add(
                await createAssociatedTokenAccountInstruction(
                  this.provider.wallet.publicKey,
                  userRedeemableTokenAccountAddress,
                  slice[j].info.userKey,
                  vault.redeemableMint,
                ),
              );
              // Add compute budget instructions
              tx2.add(
                ComputeBudgetProgram.setComputeUnitPrice({ microLamports: SOL_PRIORITY_FEE }),
              );
              tx2.add(ComputeBudgetProgram.setComputeUnitLimit({ units: 30000 }));
              txs.push(tx2);
              createATAIxsForAddresses[userRedeemableTokenAccountAddress.toString()] = true;
            }
          }

          // Push triplet of [QueueNode, UserRedeemableTokenAccount, UserAuthority]
          remainingAccounts.push({
            pubkey: slice[j].address,
            isSigner: false,
            isWritable: true,
          });
          remainingAccounts.push({
            pubkey: userRedeemableTokenAccountAddress,
            isSigner: false,
            isWritable: true,
          });
          remainingAccounts.push({
            pubkey: slice[j].info.userKey,
            isSigner: false,
            isWritable: true,
          });
        }

        const tx = new Transaction();
        tx.add(
          await instructions.processDepositQueueIx(
            this.stateAddress,
            product,
            vault,
            this.productAuthority,
            remainingAccounts,
            this.program,
          ),
        );
        // Add compute budget instructions
        tx.add(ComputeBudgetProgram.setComputeUnitPrice({ microLamports: SOL_PRIORITY_FEE }));
        tx.add(ComputeBudgetProgram.setComputeUnitLimit({ units: 200000 }));
        txs.push(tx);
      }
    }
    // Must be sequential
    const txSigs = [];
    for (let i = 0; i < txs.length; i += 1) {
      const txSig = await utils.processTransaction(Program.VAULT, this._provider, txs[i]);
      txSigs.push(txSig);
    }
    await this.updateState();
    return txSigs;
  }

  public async bulkCreateRedeemableTokenAccounts(
    entries: {
      productAddress: PublicKey;
      vaultAddress: PublicKey;
    }[],
  ): Promise<TransactionSignature[]> {
    // Dont create ATA for the same address, if there's already an IX to do so.
    const createATAIxsForAddresses: Record<string, boolean> = {};
    const txSigatures = [];
    for (const entry of entries) {
      await this.updateDepositQueue(entry.productAddress);
      const product = this.getProduct(entry.productAddress);
      const vault = this.getVault(entry.vaultAddress);
      const { depositQueue } = product;

      let bulkTransaction = new Transaction();
      const maxNumberOfIxPerTransaction = 10;
      let numAccountsToCreate = 0;
      console.info('Deposit queue length: ', depositQueue.length);
      for (let i = 0; i < depositQueue.length; i += 1) {
        const userRedeemableTokenAccountAddress = await getAssociatedTokenAddress(
          vault.redeemableMint,
          depositQueue[i].info.userKey,
          true, // allowOwnerOffCurve
        );

        // See if it's token account exists, if not add createATA instruction to the transaction
        try {
          await getAccount(this._provider.connection, userRedeemableTokenAccountAddress);
        } catch (e) {
          // If there is already an instruction to create the ATA, we don't want to add it again
          if (!(userRedeemableTokenAccountAddress.toString() in createATAIxsForAddresses)) {
            console.info(
              `User does not have userRedeemableTokenAccountAddress: ${userRedeemableTokenAccountAddress}. Creating account.`,
            );
            bulkTransaction.add(
              await createAssociatedTokenAccountInstruction(
                this.provider.wallet.publicKey,
                userRedeemableTokenAccountAddress,
                depositQueue[i].info.userKey,
                vault.redeemableMint,
              ),
            );
            createATAIxsForAddresses[userRedeemableTokenAccountAddress.toString()] = true;
            numAccountsToCreate += 1;
          }
        }

        if (
          (numAccountsToCreate === maxNumberOfIxPerTransaction || i === depositQueue.length - 1) &&
          numAccountsToCreate > 0
        ) {
          console.info(`creating ${numAccountsToCreate} token accounts`);

          // Add compute budget instructions
          bulkTransaction.add(
            ComputeBudgetProgram.setComputeUnitPrice({ microLamports: SOL_PRIORITY_FEE }),
          );
          bulkTransaction.add(
            ComputeBudgetProgram.setComputeUnitLimit({ units: numAccountsToCreate * 26000 }),
          );

          try {
            const txSig = await utils.processTransaction(
              Program.VAULT,
              this._provider,
              bulkTransaction,
            );
            txSigatures.push(txSig);
          } catch (e) {
            console.error('Error creating token accounts: ', e);
          }

          numAccountsToCreate = 0;
          bulkTransaction = new Transaction();
        }
      }
    }
    console.info('Completed creating mint tokens.');
    return txSigatures;
  }

  public async collectFees(
    productAddress: PublicKey,
    vaultAddress: PublicKey,
  ): Promise<TransactionSignature> {
    return this.bulkCollectFees([{ productAddress, vaultAddress }]);
  }

  public async bulkCollectFees(
    vaultInfoList: {
      productAddress: PublicKey;
      vaultAddress: PublicKey;
    }[],
  ): Promise<TransactionSignature> {
    let tx = new Transaction();
    for (const vaultInfo of vaultInfoList) {
      const product = this.getProduct(vaultInfo.productAddress);
      const vault = this.getVault(vaultInfo.vaultAddress);

      tx = tx.add(
        await instructions.collectFeesIx(
          this.stateAddress,
          this.provider.wallet.publicKey,
          this.productAuthority,
          this.state.feeRecipient,
          product,
          vault,
          this.program,
        ),
      );
    }
    tx.add(ComputeBudgetProgram.setComputeUnitPrice({ microLamports: SOL_PRIORITY_FEE }));
    tx.add(ComputeBudgetProgram.setComputeUnitLimit({ units: 200000 }));
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateProducts();
    await this.updateVaults();
    return txSig;
  }

  public async rolloverVault(
    productAddress: PublicKey,
    vaultAddress: PublicKey,
  ): Promise<TransactionSignature> {
    return this.bulkRolloverVault([{ productAddress, vaultAddress }]);
  }

  public async bulkRolloverVault(
    vaultInfoList: {
      productAddress: PublicKey;
      vaultAddress: PublicKey;
    }[],
  ): Promise<TransactionSignature> {
    let tx = new Transaction();
    for (const vaultInfo of vaultInfoList) {
      tx = tx.add(
        await instructions.rolloverVaultIx(
          this.stateAddress,
          this.provider.wallet.publicKey,
          this.productAuthority,
          vaultInfo.productAddress,
          vaultInfo.vaultAddress,
          this.program,
        ),
      );
    }
    tx.add(ComputeBudgetProgram.setComputeUnitPrice({ microLamports: SOL_PRIORITY_FEE }));
    tx.add(ComputeBudgetProgram.setComputeUnitLimit({ units: 200000 }));
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateProducts();
    await this.updateVaults();
    return txSig;
  }

  public async updateMaxDepositLimit(
    productAddress: PublicKey,
    newDepositLimit: anchor.BN,
  ): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.updateMaxDepositLimitIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        productAddress,
        newDepositLimit,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateProducts();
    return txSig;
  }

  public async updateProductFees(
    productAddress: PublicKey,
    newManagementFeePercentage: anchor.BN,
  ): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.updateProductFeesIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        productAddress,
        newManagementFeePercentage,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateProducts();
    return txSig;
  }

  public async updateFees(
    yieldFeePercentage: number,
    managementFeePercentage: number,
  ): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.updateFeesIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        yieldFeePercentage,
        managementFeePercentage,
        this.program,
      ),
    );
    tx.add(ComputeBudgetProgram.setComputeUnitPrice({ microLamports: SOL_PRIORITY_FEE }));
    tx.add(
      ComputeBudgetProgram.setComputeUnitLimit({
        units: 100000,
      }),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    return txSig;
  }

  public async updateApr(
    vault: PublicKey,
    structuredProductInfoAccount: PublicKey,
    apr: anchor.BN,
  ): Promise<TransactionSignature> {
    return this.bulkUpdateApr([{ vault, structuredProductInfoAccount, apr }]);
  }

  public async bulkUpdateApr(
    entries: {
      vault: PublicKey;
      structuredProductInfoAccount: PublicKey;
      apr: anchor.BN;
    }[],
  ): Promise<TransactionSignature> {
    const tx = new Transaction();
    for (const entry of entries) {
      tx.add(
        await instructions.updateAprIx(
          this.stateAddress,
          this.provider.wallet.publicKey,
          entry.vault,
          entry.structuredProductInfoAccount,
          entry.apr,
          this.program,
        ),
      );
    }

    tx.add(ComputeBudgetProgram.setComputeUnitPrice({ microLamports: SOL_PRIORITY_FEE }));
    tx.add(
      ComputeBudgetProgram.setComputeUnitLimit({
        units: 200000,
      }),
    );

    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateProducts();
    return txSig;
  }

  public async updateTenorInDays(
    vault: PublicKey,
    structuredProductInfoAccount: PublicKey,
    tenorInDays: anchor.BN,
  ): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.updateTenorInDaysIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        vault,
        structuredProductInfoAccount,
        tenorInDays,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    return txSig;
  }

  public async updateVaultEpochTimes(
    vault: PublicKey,
    args: instructions.UpdateVaultEpochTimesArgs,
  ): Promise<TransactionSignature> {
    return this.bulkUpdateVaultEpochTimes([vault], args);
  }

  public async bulkUpdateVaultEpochTimes(
    vaults: PublicKey[],
    args: instructions.UpdateVaultEpochTimesArgs,
  ): Promise<TransactionSignature> {
    let tx = new Transaction();
    for (const vault of vaults) {
      tx = tx.add(
        await instructions.updateVaultEpochTimesIx(
          this.stateAddress,
          this.provider.wallet.publicKey,
          vault,
          args,
          this.program,
        ),
      );
    }
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    return txSig;
  }

  public async overrideObservationPeriod(
    optionBarrier: PublicKey,
    args: instructions.OverrideObservationPeriodArgs,
  ): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.overrideObservationPeriodIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        optionBarrier,
        args,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    return txSig;
  }

  public async overrideVaultBarriers(
    vault: PublicKey,
    args: instructions.OverrideVaultBarriersArgs,
  ): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.overrideVaultBarriersIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        vault,
        args,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    return txSig;
  }

  public async rollbackKnockOutEvent(
    product: PublicKey,
    vault: PublicKey,
  ): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.rollbackKnockOutEventIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        product,
        vault,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    return txSig;
  }

  public async overrideVaultStatus(
    vault: PublicKey,
    updatedStatus: anchor.BN,
  ): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.overrideVaultStatusIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        vault,
        updatedStatus,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    return txSig;
  }

  public async overrideOptionBarrierPrice(
    vault: PublicKey,
    optionNum: number,
    price: number,
  ): Promise<TransactionSignature> {
    return this.bulkOverrideOptionBarrierPrice([{ vault, optionNum, price }]);
  }

  public async bulkOverrideOptionBarrierPrice(
    entries: {
      vault: PublicKey;
      optionNum: number;
      price: number;
    }[],
  ): Promise<TransactionSignature> {
    const tx = new Transaction();
    for (const entry of entries) {
      const [optionBarrierAddress, _] = await vaultUtils.getOptionBarrierAddress(
        new anchor.BN(entry.optionNum),
        entry.vault,
        this.programId,
      );
      tx.add(
        await instructions.overrideOptionBarrierPriceIx(
          this.stateAddress,
          this.provider.wallet.publicKey,
          entry.vault,
          optionBarrierAddress,
          new anchor.BN(entry.price),
          this.program,
        ),
      );
    }
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    return txSig;
  }

  public async updateFeeRecipient(
    feeRecipientTokenAccount: PublicKey,
  ): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.updateFeeRecipientIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        feeRecipientTokenAccount,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateProducts();
    return txSig;
  }

  public async updateMapleAccount(
    product: PublicKey,
    newMapleAccount: PublicKey,
  ): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.updateMapleAccount(
        this.stateAddress,
        this.provider.wallet.publicKey,
        product,
        newMapleAccount,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    return txSig;
  }

  public async updateTraderAdmin(newTraderAdmin: PublicKey): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.updateTraderAdminIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        newTraderAdmin,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    return txSig;
  }

  // Sets the next operator admin
  public async updateAdmin(nextAdmin: PublicKey): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.updateAdminIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        nextAdmin,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    return txSig;
  }

  // Accepts the operator admin change
  public async acceptAdminUpdate(): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.acceptAdminUpdateIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    return txSig;
  }

  // TODO: This IX was meant to be created and then removed. Check if it's removed from contract.
  public async updateUnderlyingAmount(
    productAddress: PublicKey,
    vaultAddress: PublicKey,
    amountToIncrease: anchor.BN,
  ): Promise<TransactionSignature> {
    const product = this.getProduct(productAddress);
    const vault = this.getVault(vaultAddress);

    const tx = new Transaction().add(
      await instructions.updateUnderlyingAmountIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        this.productAuthority,
        product,
        vault,
        amountToIncrease,
        this.programId,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateProducts();
    await this.updateVaults();
    return txSig;
  }

  /*
   **  USER FACING INSTRUCTIONS
   */

  /**
   ** @param productAddress the product to deposit from
   ** @param amount The amount of assets to withdraw
   ** @desc Adds amount to a product's deposit queue
   * */
  public async addToDepositQueue(
    productAddress: PublicKey,
    amount: anchor.BN,
  ): Promise<TransactionSignature> {
    const product = this.getProduct(productAddress);

    let underlyingTokenAccountAddress: PublicKey;
    const tx = new Transaction();
    let keypair: Keypair;

    try {
      underlyingTokenAccountAddress = await getAssociatedTokenAddress(
        product.underlyingMint,
        this.provider.wallet.publicKey,
      );

      await getAccount(this._provider.connection, underlyingTokenAccountAddress);
    } catch (e) {
      throw new Error(
        `User does not have associated token account for ${product.underlyingMint.toString()}. Deposit failed.`,
      );
    }

    tx.add(
      await instructions.addToDepositQueueIx(
        this.stateAddress,
        this.productAuthority,
        this.provider.wallet.publicKey,
        productAddress,
        underlyingTokenAccountAddress,
        amount,
        this.program,
      ),
    );

    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx, [keypair!]);
    await this.updateState();
    return txSig;
  }

  /**
   ** @param productAddress the product to withdraw from
   ** @param amount The amount of shares (tokens) to withdraw
   ** @returns The transaction signature of the transaction
   ** @desc Attempts to withdraw amount from all product vaults in FIFO order based on the vault number
   ** @logic - 1. Get all vaults associated with the product.
   ** @logic - 2. Sort vaults in asc order based on deposit end date (this is a proxy for pulling money from the earliest vault)
   ** @logic - 3. Withdraw from each vault in order.
   ** @logic - Triggers multiple transactiosn for the user (1 withdrawal instructions per transaction)
   * */
  public async bulkWithdrawFromVaults(
    productAddress: PublicKey,
    vaultAddresses: PublicKey[],
    amount: anchor.BN,
  ): Promise<TransactionSignature> {
    const product = this.getProduct(productAddress);
    const productNameStr = Buffer.from(product.productName).toString()?.trim();
    const filteredVaults = this.vaults.filter(
      (v: any) =>
        Buffer.from(v.productName).toString().trim() === productNameStr &&
        vaultAddresses.map((a) => a.toString()).includes(v.address.toString()),
    );
    const orderedVaults = filteredVaults.sort((a, b) =>
      Number(a.epochTimesUnix.endDeposits) > Number(b.epochTimesUnix.endDeposits) ? 1 : -1,
    );

    const txs = [];
    let withdrawalRemaining = amount;
    for (const vault of orderedVaults) {
      if (withdrawalRemaining.toNumber() <= 0) {
        break;
      }
      const tx = new Transaction();

      // Check if vault has tokens to withdraw. If token account doesn't exist or no tokens, skip.
      let redeemableAccount: Account;
      const redeemableTokenAccountAddress = await getAssociatedTokenAddress(
        vault.redeemableMint,
        this.provider.wallet.publicKey,
      );
      try {
        redeemableAccount = await getAccount(
          this._provider.connection,
          redeemableTokenAccountAddress,
        );
      } catch (e) {
        console.error(
          'Withdrawal failed. User does not have associated token account for redeemable mint.',
          e,
        );
        continue;
      }

      if (Number(redeemableAccount.amount) <= 0) {
        continue;
      }

      // Create underlying token account for user if they don't have it
      let underlyingTokenAccountAddress: PublicKey;
      try {
        underlyingTokenAccountAddress = await getAssociatedTokenAddress(
          vault.underlyingMint,
          this.provider.wallet.publicKey,
        );
        await getAccount(this._provider.connection, underlyingTokenAccountAddress);
      } catch (e) {
        console.info(
          `User does not have associated token account for ${vault.underlyingMint.toString}. Creating now...`,
        );
        tx.add(
          await createAssociatedTokenAccountInstruction(
            this.provider.wallet.publicKey,
            underlyingTokenAccountAddress!,
            this.provider.wallet.publicKey,
            vault.underlyingMint,
          ),
        );
      }

      const maxRedeemableAmount = Number(redeemableAccount.amount);
      const redeemableAmount = Math.min(withdrawalRemaining.toNumber(), maxRedeemableAmount);
      tx.add(
        await instructions.withdrawVaultIx(
          this.stateAddress,
          this.productAuthority,
          this.provider.wallet.publicKey,
          new anchor.BN(redeemableAmount),
          underlyingTokenAccountAddress!,
          redeemableTokenAccountAddress,
          productAddress,
          vault.address,
          this.programId,
          this.program,
        ),
      );
      txs.push(tx);
      withdrawalRemaining = withdrawalRemaining.sub(new anchor.BN(redeemableAmount));
      if (withdrawalRemaining.toNumber() < 0) {
        throw Error('Withdraw balance was drained below zero. Please investigate!');
      }
    }
    // Must be sequential
    const txSigs = [];
    for (let i = 0; i < txs.length; i += 1) {
      const txSig = await utils.processTransaction(Program.VAULT, this._provider, txs[i]);
      txSigs.push(txSig);
    }
    await this.updateState();
    return txSigs[0];
  }

  /*
   **  Vault Refresh Methods
   */

  public async fetchWithdrawalQueue(vaultAddress: PublicKey) {
    const vault = this.getVault(vaultAddress);
    const withdrawQueueHeaderInfo = await this._program.account.queueHeader.fetch(
      vault.withdrawQueueHeader,
    );

    if (withdrawQueueHeaderInfo.count.toNumber() === 0) {
      return [];
    }
    const withdrawalQueue: types.QueueNode[] = [];
    let currNodeAddress = withdrawQueueHeaderInfo.head;
    while (!currNodeAddress.equals(PublicKey.default)) {
      const currNodeInfo = (await this._program.account.queueNode.fetch(
        currNodeAddress,
      )) as programTypes.QueueNode;
      withdrawalQueue.push({
        address: currNodeAddress,
        info: {
          amount: currNodeInfo.amount.toNumber(),
          nextNode: currNodeInfo.nextNode,
          userKey: currNodeInfo.userKey,
        },
      });
      currNodeAddress = currNodeInfo.nextNode;
    }
    return withdrawalQueue;
  }

  public async updateWithdrawalQueue(vaultAddress: PublicKey) {
    const vault = this.getVault(vaultAddress);
    vault.withdrawalQueue = await this.fetchWithdrawalQueue(vaultAddress);
  }

  public async fetchWithdrawalQueues(vaultAddresses: PublicKey[]) {
    return Promise.all(
      vaultAddresses.map(async (vaultAddress: PublicKey) => {
        const withdrawalQueue = await this.fetchWithdrawalQueue(vaultAddress);
        return {
          vaultAddress,
          withdrawalQueue,
        };
      }),
    );
  }

  public async updateWithdrawalQueues() {
    await Promise.all(
      this._vaults.map(async (vault) => {
        await this.updateWithdrawalQueue(vault.address);
      }),
    );
  }

  public async fetchDepositQueue(productAddress: PublicKey) {
    const product = this.getProduct(productAddress);

    try {
      const depositQueueHeaderInfo = await this._program.account.queueHeader.fetch(
        product.depositQueueHeader,
      );

      if (depositQueueHeaderInfo.count.toNumber() === 0) {
        return [];
      }
      const depositQueue: types.QueueNode[] = [];
      let currNodeAddress = depositQueueHeaderInfo.head;
      while (!currNodeAddress.equals(PublicKey.default)) {
        const currNodeInfo = (await this._program.account.queueNode.fetch(
          currNodeAddress,
        )) as programTypes.QueueNode;
        depositQueue.push({
          address: currNodeAddress,
          info: {
            amount: currNodeInfo.amount.toNumber(),
            nextNode: currNodeInfo.nextNode,
            userKey: currNodeInfo.userKey,
          },
        });
        currNodeAddress = currNodeInfo.nextNode;
      }
      return depositQueue;
    } catch (e) {
      console.error(`Deposit Queue not initialized for product ${productAddress.toString()}`, e);
      return [];
    }
  }

  public async updateDepositQueue(productAddress: PublicKey) {
    const product = this.getProduct(productAddress);
    product.depositQueue = await this.fetchDepositQueue(productAddress);
  }

  public async fetchDepositQueues(productAddresses: PublicKey[]) {
    return Promise.all(
      productAddresses.map(async (productAddress: PublicKey) => {
        const depositQueue = await this.fetchDepositQueue(productAddress);
        return {
          productAddress,
          depositQueue,
        };
      }),
    );
  }

  public async updateDepositQueues() {
    await Promise.all(
      this._products.map(async (product) => {
        await this.updateDepositQueue(product.address);
      }),
    );
  }

  public getVault(vaultAddress: PublicKey): types.Vault {
    for (let i = 0; i < this._vaults.length; i++) {
      if (this._vaults[i].address.equals(vaultAddress)) {
        return this._vaults[i];
      }
    }
    throw Error(`Vault does not exist: ${this.toString()}`);
  }

  public getProduct(productAddress: PublicKey): types.Product {
    for (let i = 0; i < this._products.length; i++) {
      if (this._products[i].address.equals(productAddress)) {
        return this._products[i];
      }
    }
    throw Error(`Product does not exist: ${this.toString()}`);
  }

  public getProductByName(productName: string): types.Product | undefined {
    for (let i = 0; i < this._products.length; i += 1) {
      if (this._products[i].productName === productName) {
        return this._products[i];
      }
    }
    return undefined;
  }

  public async fetchStructureAccount(
    address: PublicKey,
    vaultAddress: PublicKey,
  ): Promise<types.StructuredProductInfoAccount> {
    const structuredInfo = await this._program.account.structuredProductInfoAccount.fetch(address);
    return {
      address,
      vaultAddress,
      aprPercentage: structuredInfo.aprPercentage.toNumber(),
      daysPassed: structuredInfo.daysPassed.toNumber(),
      epochSequenceNumber: structuredInfo.epochSequenceNumber.toNumber(),
      numberOfPuts: structuredInfo.numberOfPuts.toNumber(),
      tenorInDays: structuredInfo.tenorInDays.toNumber(),
      putOne: structuredInfo.putOne,
      putTwo: structuredInfo.putTwo,
      putThree: structuredInfo.putThree,
      putFour: structuredInfo.putFour,
      putFive: structuredInfo.putFive,
    };
  }

  public async fetchPutAcount(optionBarrierAddress: PublicKey) {
    return this._program.account.optionBarrier.fetch(optionBarrierAddress);
  }

  public async updateProgramState() {
    try {
      this._state = (await this._program.account.state.fetch(this._stateAddress)) as types.State;
    } catch (e) {
      console.error('State account not initialized yet.', e);
    }
  }

  public async updateState() {
    await Promise.all([this.updateProgramState, this.updateProducts(), this.updateVaults()]);
    await this.updateWithdrawalQueues();
    await this.updateDepositQueues();
  }

  public async updateProducts() {
    const accs: anchor.ProgramAccount[] = await this.program.account.product.all();

    const products = await Promise.all(
      accs.map(async (acc) => {
        // TODO: figure out what the fallback state is
        const product = acc.account as programTypes.Product;
        return {
          address: acc.publicKey,
          productName: Buffer.from(product.productName).toString().trim(),
          productCounter: product.productCounter.toNumber(),
          underlyingMint: product.underlyingMint,
          productUnderlyingTokenAccount: product.productUnderlyingTokenAccount,
          maxDepositLimit: product.maxDepositLimit.toNumber(),
          managementFeePercentage: product.managementFeePercentage.toNumber(),
          underlyingAmount: product.underlyingAmount.toNumber(),
          mapleAccount: product.mapleAccount,
          depositQueueHeader: product.depositQueueHeader,

          depositQueue: [], // need to call updateDepositQueue separately, there's a race condition where product doesnt exist so cant fetch queueHeader
          isActive: product.isActive,
        };
      }),
    );
    this._products = products;
    return products;
  }

  public async updateVaults() {
    const accs: anchor.ProgramAccount[] = await this.program.account.vault.all();
    const vaults = await Promise.all(
      accs.map(async (acc) => {
        // TODO: figure out what the fallback state is
        const vault = acc.account as programTypes.Vault;
        const option: any = vault.optionMint.equals(PublicKey.default);

        const epochTimesUnix: types.epochTimesUnix = {
          startEpoch: vault.startEpoch.toNumber(),
          endDeposits: vault.endDeposits.toNumber(),
          startDeposits: vault.startDeposits.toNumber(),
          endEpoch: vault.endEpoch.toNumber(),
          tradeDate: vault.tradeDate.toNumber(),
          epochCadence: vault.epochCadence,
        };
        const epochTimes: types.EpochTimes = {
          startEpoch: new Date(vault.startEpoch.toNumber() * 1000),
          endDeposits: new Date(vault.endDeposits.toNumber() * 1000),
          startDeposits: new Date(vault.startDeposits.toNumber() * 1000),
          endEpoch: new Date(vault.endEpoch.toNumber() * 1000),
          tradeDate: new Date(vault.tradeDate.toNumber() * 1000),
          epochCadence: vault.epochCadence,
        };

        return {
          address: acc.publicKey,
          productName: Buffer.from(vault.productName).toString().trim(),
          vaultNumber: vault.vaultNumber.toNumber(),
          underlyingMint: vault.underlyingMint,
          redeemableMint: vault.redeemableMint,
          vaultWithdrawQueueRedeemableTokenAccount: vault.vaultWithdrawQueueRedeemableTokenAccount,
          structuredProductInfoAccount: vault.structuredProductInfoAccount,
          underlyingAmount: vault.underlyingAmount.toNumber(),
          vaultTotalCouponPayoff: vault.vaultTotalCouponPayoff.toNumber(),
          vaultFinalPayoff: vault.vaultFinalPayoff.toNumber(),
          knockInEvent: vault.knockInEvent,
          knockOutEvent: vault.knockOutEvent,
          epochSequenceNumber: vault.epochSequenceNumber.toNumber(),
          epochTimes,
          epochTimesUnix,
          option,
          vaultOptionTokenAccount: undefined,
          withdrawQueueHeader: vault.withdrawQueueHeader,
          withdrawalQueue: [],
          status: vaultUtils.getStatusNumber(vault.status),
        };
      }),
    );

    this._vaults = vaults;
    return vaults;
  }

  public async close() {
    for (let i = 0; i < this._eventListeners.length; i++) {
      await this._program.removeEventListener(this._eventListeners[i]);
    }
    this._eventListeners = [];
  }

  public async getOptionBarriers(vault: types.Vault): Promise<types.OptionBarrier[]> {
    const structure = await this.program.account.structuredProductInfoAccount.fetch(
      vault.structuredProductInfoAccount,
    );
    const optionBarriers = [];
    for (let optionNum = 0; optionNum < structure.numberOfPuts.toNumber(); optionNum += 1) {
      const [optionBarrierAddress, _nonce] = await vaultUtils.getOptionBarrierAddress(
        new anchor.BN(optionNum),
        vault.address,
        this.programId,
      );
      const pt_optionBarrier = await this.program.account.optionBarrier.fetch(optionBarrierAddress);
      const optionBarrier = {
        ...pt_optionBarrier,
        address: optionBarrierAddress,
        assetName: Buffer.from(pt_optionBarrier.assetName).toString().trim(),
        knockInAbs: pt_optionBarrier.knockInAbs ? Number(pt_optionBarrier.knockInAbs) : null,
        knockOutAbs: pt_optionBarrier.knockOutAbs ? Number(pt_optionBarrier.knockOutAbs) : null,
        strikeAbs: pt_optionBarrier.strikeAbs ? Number(pt_optionBarrier.strikeAbs) : null,
      };
      optionBarriers.push(optionBarrier);
    }
    return optionBarriers;
  }

  // Upgraded getOptionBarriers to actually map variables to their correct types
  // eg. BN -> number
  public async fetchOptionBarriers(vault: types.Vault): Promise<types.OptionBarrier[]> {
    const structure = await this.program.account.structuredProductInfoAccount.fetch(
      vault.structuredProductInfoAccount,
    );
    const optionBarriers = [];
    for (let optionNum = 0; optionNum < structure.numberOfPuts.toNumber(); optionNum += 1) {
      const [optionBarrierAddress, _nonce] = await vaultUtils.getOptionBarrierAddress(
        new anchor.BN(optionNum),
        vault.address,
        this.programId,
      );
      const optionBarrierInfo =
        await this.program.account.optionBarrier.fetch(optionBarrierAddress);
      const optionBarrier = {
        address: optionBarrierAddress,
        vaultAddress: vault.address,
        optionExists: optionBarrierInfo.optionExists,
        assetName: Buffer.from(optionBarrierInfo.assetName).toString().trim(),
        optionNumber: Number(optionBarrierInfo.optionNumber),
        assetMint: optionBarrierInfo.assetMint,
        strikeAbs: optionBarrierInfo.strikeAbs ? Number(optionBarrierInfo.strikeAbs) : null,
        knockInAbs: optionBarrierInfo.knockInAbs ? Number(optionBarrierInfo.knockInAbs) : null,
        knockOutAbs: optionBarrierInfo.knockOutAbs ? Number(optionBarrierInfo.knockOutAbs) : null,
        lastPrice: optionBarrierInfo.lastPrice ? Number(optionBarrierInfo.lastPrice) : null,
        isOverridePrice: optionBarrierInfo.isOverridePrice,
        overridePrice: Number(optionBarrierInfo.overridePrice),
        oracle: optionBarrierInfo.oracle,
        oracleType: optionBarrierInfo.oracleType,
        observationTime: Number(optionBarrierInfo.observationTime),
        timeBuffer: Number(optionBarrierInfo.timeBuffer),
        timeIncrement: Number(optionBarrierInfo.timeIncrement),
      };
      optionBarriers.push(optionBarrier);
    }
    return optionBarriers;
  }

  public async getOracleRemainingAccounts(vault: types.Vault): Promise<Array<AccountMeta>> {
    const structure = await this.program.account.structuredProductInfoAccount.fetch(
      vault.structuredProductInfoAccount,
    );

    const remainingAccounts: Array<AccountMeta> = [];
    // Iterate through all options accounts starting from 0 until the numberOfPuts - 1
    for (
      let optionNumber = 0;
      optionNumber < structure.numberOfPuts.toNumber();
      optionNumber += 1
    ) {
      const [optionBarrierAddress, _nonce] = await vaultUtils.getOptionBarrierAddress(
        new anchor.BN(optionNumber),
        vault.address,
        this.programId,
      );
      const optionBarrierInfo =
        await this.program.account.optionBarrier.fetch(optionBarrierAddress);

      const oracleAssetAddress = optionBarrierInfo.oracle;

      remainingAccounts.push({
        pubkey: optionBarrierAddress,
        isSigner: false,
        isWritable: true,
      });
      remainingAccounts.push({
        pubkey: oracleAssetAddress,
        isSigner: false,
        isWritable: true,
      });
    }
    return remainingAccounts;
  }

  /**
   *  Vault Token Metadata Methods
   */

  /**
   * Creates a vault's Token Metadata
   * @param vault - PublicKey of Vault
   * @param name - Title of Token "eg. Cega Vault Token"
   * @param symbol - Symbol of Token "eg. CEGA-V0"
   * @param uri - Full URL (including https://) of asset
   * @returns Transaction Signature
   */
  public async createTokenMetadata(
    vault: PublicKey,
    name: string,
    symbol: string,
    uri: string,
  ): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.createTokenMetadataIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        vault,
        this.productAuthority,
        this.programId,
        name,
        symbol,
        uri,
        mpl.PROGRAM_ID,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    return txSig;
  }

  /**
   * Updates a vault's Token Metadata
   * @param vault - PublicKey of Vault
   * @param name - Title of Token "eg. Cega Vault Token"
   * @param symbol - Symbol of Token "eg. CEGA-V0"
   * @param uri - Full URL (including https://) of asset
   * @returns Transaction Signature
   */
  public async updateTokenMetadata(
    vault: PublicKey,
    name: string,
    symbol: string,
    uri: string,
  ): Promise<TransactionSignature> {
    const tx = new Transaction().add(
      await instructions.updateTokenMetadataIx(
        this.stateAddress,
        this.provider.wallet.publicKey,
        vault,
        this.productAuthority,
        this.programId,
        name,
        symbol,
        uri,
        mpl.PROGRAM_ID,
        this.program,
      ),
    );
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx);
    await this.updateVaults();
    return txSig;
  }

  /**
   * Creates a vault's Token Metadata if it doesn't exist. Updates if it does.
   * @param vault - PublicKey of Vault
   * @param name - Title of Token "eg. Cega Vault Token"
   * @param symbol - Symbol of Token "eg. CEGA-V0"
   * @param uri - Full URL (including https://) of metadata blob
   * @returns Transaction Signature
   */
  public async createOrUpdateTokenMetadata(
    vault: PublicKey,
    name: string,
    symbol: string,
    uri: string,
  ): Promise<TransactionSignature> {
    const [redeemableMint, _redeemableMintNonce] = await vaultUtils.getRedeemableMintAddress(
      vault,
      this.programId,
    );
    const [metadataAccount, _metadataAccountNonce] = await vaultUtils.getMetadataAccountAddress(
      redeemableMint,
      mpl.PROGRAM_ID,
    );

    const metadataInfo = await this._provider.connection.getAccountInfo(metadataAccount);
    if (metadataInfo === null) {
      const txSig = await this.createTokenMetadata(vault, name, symbol, uri);
      return txSig;
    }

    const txSig = await this.updateTokenMetadata(vault, name, symbol, uri);
    return txSig;
  }

  /*
   * NEW METHODS THAT DONT USE THE CACHE
   */

  // This method should mirror that of `updateProducts`
  public async fetchProducts() {
    const accs: anchor.ProgramAccount[] = await this.program.account.product.all();
    const products = accs.map((acc) => {
      const product = acc.account as programTypes.Product;
      return {
        address: acc.publicKey,
        productName: Buffer.from(product.productName).toString().trim(),
        productCounter: product.productCounter.toNumber(),
        underlyingMint: product.underlyingMint,
        productUnderlyingTokenAccount: product.productUnderlyingTokenAccount,
        maxDepositLimit: product.maxDepositLimit.toNumber(),
        managementFeePercentage: product.managementFeePercentage.toNumber(),
        underlyingAmount: product.underlyingAmount.toNumber(),
        mapleAccount: product.mapleAccount,
        depositQueueHeader: product.depositQueueHeader,

        depositQueue: [], // need to call updateDepositQueue separately, there's a race condition where product doesnt exist so cant fetch queueHeader
        isActive: product.isActive,
      };
    });
    this._products = products;
    return products;
  }

  transformVaultAccountToVault = (address: PublicKey, vault: programTypes.Vault): types.Vault => {
    const option: any = vault.optionMint.equals(PublicKey.default);
    const epochTimesUnix: types.epochTimesUnix = {
      startEpoch: Number(vault.startEpoch),
      endDeposits: Number(vault.endDeposits),
      startDeposits: Number(vault.startDeposits),
      endEpoch: Number(vault.endEpoch),
      tradeDate: Number(vault.tradeDate),
      epochCadence: vault.epochCadence,
    };
    const epochTimes: types.EpochTimes = {
      startEpoch: new Date(Number(vault.startEpoch) * 1000),
      endDeposits: new Date(Number(vault.endDeposits) * 1000),
      startDeposits: new Date(Number(vault.startDeposits) * 1000),
      endEpoch: new Date(Number(vault.endEpoch) * 1000),
      tradeDate: new Date(Number(vault.tradeDate) * 1000),
      epochCadence: vault.epochCadence,
    };

    return {
      address,
      productName: Buffer.from(vault.productName).toString().trim(),
      vaultNumber: Number(vault.vaultNumber),
      underlyingMint: vault.underlyingMint,
      redeemableMint: vault.redeemableMint,
      vaultWithdrawQueueRedeemableTokenAccount: vault.vaultWithdrawQueueRedeemableTokenAccount,
      structuredProductInfoAccount: vault.structuredProductInfoAccount,
      underlyingAmount: Number(vault.underlyingAmount),
      vaultTotalCouponPayoff: Number(vault.vaultTotalCouponPayoff),
      vaultFinalPayoff: Number(vault.vaultFinalPayoff),
      knockInEvent: vault.knockInEvent,
      knockOutEvent: vault.knockOutEvent,
      epochSequenceNumber: Number(vault.epochSequenceNumber),
      epochTimes,
      epochTimesUnix,
      option,
      vaultOptionTokenAccount: undefined,
      withdrawQueueHeader: vault.withdrawQueueHeader,
      withdrawalQueue: [],
      status: vaultUtils.getStatusNumber(vault.status),
    };
  };

  // Fetches a single vault
  public async fetchVault(address: PublicKey): Promise<types.Vault> {
    const vault = await this.program.account.vault.fetch(address);
    return this.transformVaultAccountToVault(address, vault as unknown as programTypes.Vault);
  }

  // This method should mirror that of `updateVaults`
  public async fetchVaults(): Promise<types.Vault[]> {
    const accs: anchor.ProgramAccount[] = await this.program.account.vault.all();
    const vaults = accs.map((acc) => this.transformVaultAccountToVault(acc.publicKey, acc.account));
    this._vaults = vaults;
    return vaults;
  }

  public async fetchStructuredProductInfoAccounts(): Promise<types.StructuredProductInfoAccount[]> {
    const accounts: anchor.ProgramAccount[] =
      await this.program.account.structuredProductInfoAccount.all();
    const resp = accounts.map((acc) => {
      const structure = acc.account as programTypes.StructuredProductInfoAccount;
      return {
        address: acc.publicKey,
        vaultAddress: undefined, // prev sdk iterated through vaults where vaultAddress was present
        aprPercentage: Number(structure.aprPercentage),
        daysPassed: Number(structure.daysPassed),
        epochSequenceNumber: Number(structure.epochSequenceNumber),
        numberOfPuts: Number(structure.numberOfPuts),
        tenorInDays: Number(structure.tenorInDays),
        putOne: structure.putOne,
        putTwo: structure.putTwo,
        putThree: structure.putThree,
        putFour: structure.putFour,
        putFive: structure.putFive,
      };
    });
    return resp;
  }

  public async fetchOptionBarrierDetails(vaultAddress: PublicKey, maximumNumberOfOptions: number) {
    const addresses = await Promise.all(
      [...Array(maximumNumberOfOptions).keys()].map(async (optionNum) => {
        const [optionAddress, _optionNonce] = await vaultUtils.getOptionBarrierAddress(
          new anchor.BN(optionNum),
          vaultAddress,
          this.programId,
        );
        return optionAddress;
      }),
    );
    const optionBarriers = await Promise.all(
      addresses.map(async (address) => {
        try {
          const barrier: programTypes.OptionBarrier =
            await this.program.account.optionBarrier.fetch(address);
          return {
            address,
            optionExists: barrier.optionExists,
            assetName: Buffer.from(barrier.assetName).toString().trim(),
            optionNumber: Number(barrier.optionNumber),
            assetMint: barrier.assetMint,
            strikeAbs: barrier.strikeAbs ? Number(barrier.strikeAbs) : undefined,
            knockInAbs: barrier.knockInAbs ? Number(barrier.knockInAbs) : undefined,
            knockOutAbs: barrier.knockOutAbs ? Number(barrier.knockOutAbs) : undefined,
            lastPrice: barrier.lastPrice ? Number(barrier.lastPrice) : undefined,
            isOverridePrice: barrier.isOverridePrice,
            overridePrice: Number(barrier.overridePrice),
            oracle: barrier.oracle,
            oracleType: Number(barrier.oracleType),
            observationTime: Number(barrier.observationTime),
            timeBuffer: Number(barrier.timeBuffer),
            timeIncrement: Number(barrier.timeIncrement),
          };
        } catch {
          return null;
        }
      }),
    );
    function notEmpty<TValue>(value: TValue | null | undefined): value is TValue {
      return value !== null && value !== undefined;
    }
    const nonEmptyOptionBarriers: types.OptionBarrier[] = optionBarriers.filter(notEmpty);
    return nonEmptyOptionBarriers;
  }

  public async fetchQueue(queueHeaderAddress: PublicKey, userWalletAddress?: PublicKey) {
    let queue: types.QueueNode[] = [];
    try {
      const depositQueueHeaderInfo =
        await this._program.account.queueHeader.fetch(queueHeaderAddress);

      if (depositQueueHeaderInfo.count.toNumber() === 0) {
        queue = [];
      } else {
        let currNodeAddress = depositQueueHeaderInfo.head;
        while (!currNodeAddress.equals(PublicKey.default)) {
          const currNodeInfo = (await this._program.account.queueNode.fetch(
            currNodeAddress,
          )) as programTypes.QueueNode;

          if (
            !userWalletAddress ||
            (userWalletAddress && currNodeInfo.userKey.equals(userWalletAddress))
          ) {
            queue.push({
              address: currNodeAddress,
              info: {
                amount: currNodeInfo.amount.toNumber(),
                nextNode: currNodeInfo.nextNode,
                userKey: currNodeInfo.userKey,
              },
            });
          }
          currNodeAddress = currNodeInfo.nextNode;
        }
      }
    } catch (e) {
      console.error(`Queue not initialized ${queueHeaderAddress.toString()}`, e);
    }

    return queue;
  }
}
