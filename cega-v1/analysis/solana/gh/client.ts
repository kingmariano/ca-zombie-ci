import * as anchor from '@project-serum/anchor';
import {
  PublicKey,
  Connection,
  Transaction,
  Keypair,
  AccountMeta,
  TransactionSignature,
} from '@solana/web3.js';
import {
  getMint,
  getAccount,
  getAssociatedTokenAddress,
  createAssociatedTokenAccountInstruction,
  Account,
} from '@solana/spl-token';
import idl from '../idl/cega_vault.json';
import { CegaVault } from '../types/cega_vault';
import { CegaSDK } from './sdk';
import * as utils from '../common/utils';
import * as vaultUtils from './utils';
import * as instructions from './instructions';
import { QueueNode, QueuedNodes, VaultTokens, DepositInfo } from './types';
import { Program } from '../common/program';
import { SOL_PUBKEY } from '../common/constants';
import * as programTypes from './program-types';
import * as types from './types';

export class CegaClient {
  /**
   * Anchor program instance.
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

  private _provider: anchor.AnchorProvider;

  public get publicKey(): PublicKey {
    return this._provider.wallet.publicKey;
  }

  /**
   * Cega SDK instance
   */
  public get cegaSDK(): CegaSDK {
    return this._cegaSDK;
  }

  private _cegaSDK: CegaSDK;

  public get vaultTokens(): VaultTokens[] {
    return this._vaultTokens;
  }

  private _vaultTokens: VaultTokens[] = [];

  public get queuedDeposits(): QueuedNodes[] {
    return this._queuedDeposits;
  }

  private _queuedDeposits: QueuedNodes[] = [];

  public get queuedWithdrawals(): QueuedNodes[] {
    return this._queuedWithdrawals;
  }

  private _queuedWithdrawals: QueuedNodes[] = [];

  public get depositInfos(): DepositInfo[] {
    return this._depositInfos;
  }

  private _depositInfos: DepositInfo[] = [];

  private constructor(
    connection: Connection,
    wallet: anchor.Wallet,
    cegaSDK: any,
    opts = utils.defaultCommitment(),
  ) {
    this._provider = new anchor.AnchorProvider(connection, wallet, opts);
    this._program = new anchor.Program(
      idl as anchor.Idl,
      cegaSDK.programId,
      this._provider,
    ) as anchor.Program<CegaVault>;
    this._cegaSDK = cegaSDK;
  }

  public static async load(
    connection: Connection,
    wallet: anchor.Wallet,
    cegaSDK: any,
    opts = utils.defaultCommitment(),
  ): Promise<CegaClient> {
    if (!cegaSDK.isInitialized) {
      throw Error("Vault isn't loaded yet");
    }
    const client = new CegaClient(connection, wallet, cegaSDK, opts);
    await client.updateState();
    return client;
  }

  public async depositVault(
    productAddress: PublicKey,
    vaultAddress: PublicKey,
    amount: anchor.BN,
  ): Promise<TransactionSignature> {
    const vault = this.cegaSDK.getVault(vaultAddress);
    const product = this.cegaSDK.getProduct(productAddress);

    let underlyingTokenAccountAddress: PublicKey;
    let userRedeemableTokenAddress: PublicKey;
    let tx = new Transaction();
    let keypair: Keypair = Keypair.generate();

    // TODO: Why do we need to wrap the SOL if the vault transacts in SOL?
    if (vault.underlyingMint.equals(SOL_PUBKEY)) {
      [tx, keypair] = await utils.createWrappedNativeAccount(
        this._provider.connection,
        this.publicKey,
        this.publicKey,
        amount,
      );

      underlyingTokenAccountAddress = keypair.publicKey;
    } else {
      try {
        underlyingTokenAccountAddress = await getAssociatedTokenAddress(
          vault.underlyingMint,
          this.publicKey,
        );

        await getAccount(this._provider.connection, underlyingTokenAccountAddress);
      } catch (e) {
        throw Error(
          `User does not have associated token account for ${vault.underlyingMint.toString}. Deposit failed.`,
        );
      }
    }

    const redeemableTokenAccountAddress = await getAssociatedTokenAddress(
      vault.redeemableMint,
      this.publicKey,
    );
    const [depositInfoAccount, depositInfoNonce] = await vaultUtils.getDepositInfoAccountAddress(
      this.publicKey,
      vault.address,
      this.cegaSDK.programId,
    );
    try {
      await getAccount(this._provider.connection, redeemableTokenAccountAddress);
    } catch (e) {
      console.info(
        'User does not have associated token account for redeemable mint. Creating account.',
      );
      userRedeemableTokenAddress = await getAssociatedTokenAddress(
        vault.redeemableMint,
        this.publicKey,
      );
      tx.add(
        await createAssociatedTokenAccountInstruction(
          this.publicKey,
          userRedeemableTokenAddress,
          this.publicKey,
          vault.redeemableMint,
        ),
      );
    }

    tx.add(
      await instructions.depositVaultIx(
        this.cegaSDK.stateAddress,
        this.cegaSDK.provider.wallet.publicKey,
        this.cegaSDK.productAuthority,
        amount,
        productAddress,
        vaultAddress,
        depositInfoAccount,
        this.publicKey,
        underlyingTokenAccountAddress,
        redeemableTokenAccountAddress,
        vault.underlyingMint,
        vault.redeemableMint,
        this.cegaSDK.program,
      ),
    );

    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx, [keypair]);
    await this.updateState();
    return txSig;
  }

  public async addToDepositQueue(
    productAddress: PublicKey,
    amount: anchor.BN,
  ): Promise<TransactionSignature> {
    const product = this.cegaSDK.getProduct(productAddress);

    let underlyingTokenAccountAddress: PublicKey;
    const tx = new Transaction();
    const keypair: Keypair = Keypair.generate();

    try {
      underlyingTokenAccountAddress = await getAssociatedTokenAddress(
        product.underlyingMint,
        this.publicKey,
      );

      await getAccount(this._provider.connection, underlyingTokenAccountAddress);
    } catch (e) {
      throw Error(
        `User does not have associated token account for ${product.underlyingMint.toString}. Deposit failed.`,
      );
    }

    tx.add(
      await instructions.addToDepositQueueIx(
        this.cegaSDK.stateAddress,
        this.cegaSDK.productAuthority,
        this.publicKey,
        productAddress,
        underlyingTokenAccountAddress,
        amount,
        this.cegaSDK.program,
      ),
    );

    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx, [keypair]);
    await this.updateState();
    return txSig;
  }

  public async removeQueuedWithdrawal(
    vaultAddress: PublicKey,
    queueNodeToRemove: PublicKey,
  ): Promise<TransactionSignature> {
    const vault = this.cegaSDK.getVault(vaultAddress);

    const withdrawQueueHeaderInfo = await this._program.account.queueHeader.fetch(
      vault.withdrawQueueHeader,
    );
    if (withdrawQueueHeaderInfo.count.toNumber() == 0) {
      throw Error('Cannot remove queued withdraw from empty queue.');
    }

    let currNodeInfo: programTypes.QueueNode | null = null;
    let currNodeAddress: PublicKey = withdrawQueueHeaderInfo.head;
    let prevNodeAddress: PublicKey = PublicKey.default;
    const { withdrawalQueue } = vault;

    for (let i = 0; i < withdrawalQueue.length; i++) {
      currNodeInfo = withdrawalQueue[i].info;
      if (currNodeAddress.equals(queueNodeToRemove)) {
        break;
      }
      prevNodeAddress = currNodeAddress;
      currNodeAddress = currNodeInfo.nextNode;
    }

    if (currNodeAddress.equals(PublicKey.default)) {
      throw Error("Queue node to remove doesn't exist.");
    }

    if (currNodeInfo === null || !currNodeInfo.userKey.equals(this.publicKey)) {
      throw Error('Cannot remove a queue node that you do not own.');
    }

    const redeemableTokenAccountAddress = await getAssociatedTokenAddress(
      vault.redeemableMint,
      this.publicKey,
    );

    const tx = new Transaction();

    try {
      await getAccount(this._provider.connection, redeemableTokenAccountAddress);
    } catch (e) {
      console.info(
        'User does not have associated token account for redeemable mint. Creating account.',
      );
      tx.add(
        await createAssociatedTokenAccountInstruction(
          this.publicKey,
          redeemableTokenAccountAddress,
          this.publicKey,
          vault.redeemableMint,
        ),
      );
    }

    const remainingAccounts: AccountMeta[] = [];

    if (!queueNodeToRemove.equals(withdrawQueueHeaderInfo.head)) {
      remainingAccounts.push({
        pubkey: prevNodeAddress,
        isSigner: false,
        isWritable: true,
      });
    }

    tx.add();

    return utils.processTransaction(Program.VAULT, this._provider, tx);
  }

  public getQueuedWithdrawals(vaultAddress: PublicKey): QueueNode[] {
    const vault = this.cegaSDK.getVault(vaultAddress);
    const { withdrawalQueue } = vault;
    const userQueue: types.QueueNode[] = [];
    for (let i = 0; i < withdrawalQueue.length; i++) {
      if (withdrawalQueue[i].info.userKey.equals(this.publicKey)) {
        userQueue.push(withdrawalQueue[i]);
      }
    }
    return userQueue;
  }

  public getQueuedDeposits(productAddress: PublicKey): QueueNode[] {
    const product = this.cegaSDK.getProduct(productAddress);
    const { depositQueue } = product;
    const userQueue: types.QueueNode[] = [];
    for (let i = 0; i < depositQueue.length; i++) {
      if (depositQueue[i].info.userKey.equals(this.publicKey)) {
        userQueue.push(depositQueue[i]);
      }
    }
    return userQueue;
  }

  public async getDepositInfo(vaultAddress: PublicKey) {
    const vault = this.cegaSDK.getVault(vaultAddress);
    try {
      const [depositInfoAccount, depositInfoNonce] = await vaultUtils.getDepositInfoAccountAddress(
        this.publicKey,
        vault.address,
        this.cegaSDK.programId,
      );
      const depositInfo = await this._program.account.depositInfo.fetch(depositInfoAccount);
      return {
        depositInfoNonce: depositInfo.depositInfoNonce,
        userKey: depositInfo.userKey,
        productAddress: depositInfo.product,
        vaultAddress: depositInfo.vault,
        usdcDeposit: depositInfo.usdcDeposit.toNumber(),
      };
    } catch (e) {
      return undefined;
    }
  }

  public async withdrawVault(
    productAddress: PublicKey,
    vaultAddress: PublicKey,
    amount: anchor.BN,
  ): Promise<TransactionSignature> {
    const vault = this.cegaSDK.getVault(vaultAddress);
    const redeemableTokenAccountAddress = await getAssociatedTokenAddress(
      vault.redeemableMint,
      this.publicKey,
    );
    try {
      await getAccount(this._provider.connection, redeemableTokenAccountAddress);
    } catch (e) {
      throw Error(
        'Withdrawal failed. User does not have associated token account for redeemable mint.',
      );
    }

    let underlyingTokenAccountAddress: PublicKey = PublicKey.default;
    const tx = new Transaction();

    // Create underlying token account for user if they don't have it
    try {
      underlyingTokenAccountAddress = await getAssociatedTokenAddress(
        vault.underlyingMint,
        this.publicKey,
      );

      await getAccount(this._provider.connection, underlyingTokenAccountAddress);
    } catch (e) {
      console.info(
        `User does not have associated token account for ${vault.underlyingMint.toString}. Creating now.`,
      );
      tx.add(
        await createAssociatedTokenAccountInstruction(
          this.publicKey,
          underlyingTokenAccountAddress,
          this.publicKey,
          vault.underlyingMint,
        ),
      );
    }

    tx.add(
      await instructions.withdrawVaultIx(
        this.cegaSDK.stateAddress,
        this.cegaSDK.productAuthority,
        this.publicKey,
        amount,
        underlyingTokenAccountAddress,
        redeemableTokenAccountAddress,
        productAddress,
        vaultAddress,
        this.cegaSDK.programId,
        this.cegaSDK.program,
      ),
    );

    const keypair: Keypair = Keypair.generate();
    const txSig = await utils.processTransaction(Program.VAULT, this._provider, tx, [keypair]);
    await this.updateState();
    console.info('Withdrawal successful');
    return txSig;
  }

  public async updateTokenState() {
    const vaultTokens: VaultTokens[] = [];
    await Promise.all(
      this.cegaSDK.vaults.map(async (vault) => {
        const redeemableTokenAccountAddress = await getAssociatedTokenAddress(
          vault.redeemableMint,
          this.publicKey,
        );
        let tokens = 0;
        try {
          const tokenAccount = await getAccount(
            this._provider.connection,
            redeemableTokenAccountAddress,
          );
          tokens = Number(tokenAccount.amount);
        } catch (e) {
          console.error(
            'User does not have associated token account for redeemable mint. Skipping...',
          );
        }
        vaultTokens.push({
          vault: vault.address,
          tokenAccount: redeemableTokenAccountAddress,
          amount: tokens,
        });
      }),
    );

    this._vaultTokens = vaultTokens;
  }

  /** Attempts to withdraw amount from all product vaults in FIFO order based on the vault number.
   ** @param productAddress the product to withdraw from.
   ** @param amount The amount to withdraw.
   ** @returns The transaction signature of the transaction
   ** @logic - 1. Get all vaults associated with the product. 2. Sort vaults in ascneding order based on deposit end date (this is a proxy for pulling money from the earliest vault). 3. Withdraw from each vault in order.
   ** @logic - Triggers multiple transactiosn for the user (1 withdrawal instructions per transaction)
   * */
  public async bulkWithdrawFromVaults(
    productAddress: PublicKey,
    amount: anchor.BN,
  ): Promise<TransactionSignature> {
    const product = this.cegaSDK.getProduct(productAddress);
    const productNameStr = Buffer.from(product.productName).toString()?.trim();
    const filteredVaults = this.cegaSDK.vaults.filter(
      (v: any) => Buffer.from(v.productName).toString().trim() == productNameStr,
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
        this.publicKey,
      );
      try {
        redeemableAccount = await getAccount(
          this._provider.connection,
          redeemableTokenAccountAddress,
        );
      } catch (e) {
        console.info(
          'Withdrawal failed. User does not have associated token account for redeemable mint.',
        );
        continue;
      }

      if (Number(redeemableAccount.amount) <= 0) {
        continue;
      }

      // Create underlying token account for user if they don't have it
      let underlyingTokenAccountAddress: PublicKey = PublicKey.default;
      try {
        underlyingTokenAccountAddress = await getAssociatedTokenAddress(
          vault.underlyingMint,
          this.publicKey,
        );
        await getAccount(this._provider.connection, underlyingTokenAccountAddress);
      } catch (e) {
        console.info(
          `User does not have associated token account for ${vault.underlyingMint.toString}. Creating now...`,
        );
        tx.add(
          await createAssociatedTokenAccountInstruction(
            this.publicKey,
            underlyingTokenAccountAddress,
            this.publicKey,
            vault.underlyingMint,
          ),
        );
      }

      const maxRedeemableAmount = Number(redeemableAccount.amount);
      const redeemableAmount = Math.min(withdrawalRemaining.toNumber(), maxRedeemableAmount);
      tx.add(
        await instructions.withdrawVaultIx(
          this.cegaSDK.stateAddress,
          this.cegaSDK.productAuthority,
          this.publicKey,
          new anchor.BN(redeemableAmount),
          underlyingTokenAccountAddress,
          redeemableTokenAccountAddress,
          productAddress,
          vault.address,
          this.cegaSDK.programId,
          this.cegaSDK.program,
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
    console.info(txSigs);
    return txSigs[0];
  }

  public async updateWithdrawalQueue() {
    this._queuedWithdrawals = [];
    await Promise.all(
      this.cegaSDK.vaults.map(async (vault) => {
        const product = this.cegaSDK.getProductByName(vault.productName);
        if (product) {
          this._queuedWithdrawals.push({
            product: product.address,
            vault: vault.address,
            nodes: this.getQueuedWithdrawals(vault.address),
          });
        }
      }),
    );
  }

  public async updateDepositQueue() {
    this._queuedDeposits = [];
    await Promise.all(
      this.cegaSDK.products.map(async (product) => {
        this._queuedDeposits.push({
          product: product.address,
          vault: product.address,
          nodes: this.getQueuedDeposits(product.address),
        });
      }),
    );
  }

  public async updateDepositInfos() {
    this._depositInfos = [];
    await Promise.all(
      this.cegaSDK.vaults.map(async (vault) => {
        const depositInfo = await this.getDepositInfo(vault.address);
        if (depositInfo !== undefined) {
          this._depositInfos.push(depositInfo);
        }
      }),
    );
  }

  public async updateState() {
    await this.cegaSDK.updateState();
    await this.updateTokenState();
    await this.updateWithdrawalQueue();
    await this.updateDepositQueue();
    await this.updateDepositInfos();
  }

  public getRedeemableTokenAmount(vaultAddress: PublicKey): number {
    for (let i = 0; i < this._vaultTokens.length; i++) {
      if (this._vaultTokens[i].vault.equals(vaultAddress)) {
        return this._vaultTokens[i].amount;
      }
    }
    throw Error('Vault does not exist!');
  }

  public async getDepositExchangeRate(vaultAddress: PublicKey): Promise<number> {
    const vault = this.cegaSDK.getVault(vaultAddress);
    const mintTokenInfo = await getMint(this._provider.connection, vault.redeemableMint);
    if (vault.epochSequenceNumber === 0) {
      return 1;
    }
    return Number(mintTokenInfo.supply) / vault.underlyingAmount;
  }

  // Exchange rate is calculated as the
  // Vault-withdraw weighted average of token exchange rates at expiry without KI/KO
  // - edge case: while a KO is in progress (knock-out flag is set && not traded)
  //   - you have to subtract yield from the underlying deposit
  // Example:
  // vault 1 has 100 usdc in deposits and vault 2 has 200 usdc in deposits
  public async getWithdrawExchangeRate(
    productAddress: PublicKey,
    totalWithdrawalAmount: number,
  ): Promise<number> {
    const product = this.cegaSDK.getProduct(productAddress);
    const filteredVaults = this.cegaSDK.vaults.filter(
      (v: any) => Buffer.from(v.productName).toString().trim() === product.productName,
    );
    const orderedVaults = filteredVaults.sort((a, b) =>
      Number(a.vaultNumber) > Number(b.vaultNumber) ? 1 : -1,
    );
    let withdrawalRemaining = totalWithdrawalAmount;
    let sumTotalReturned = 0;
    for (const vault of orderedVaults) {
      if (withdrawalRemaining <= 0) {
        break;
      }
      const redeemableTokenInfo = this.vaultTokens.find(
        (t: any) => t.vault.toString() === vault.address.toString(),
      );
      if (redeemableTokenInfo && redeemableTokenInfo.amount !== 0) {
        const vaultWithdrawAmount = Math.min(redeemableTokenInfo.amount, totalWithdrawalAmount);
        const mintTokenInfo = await getMint(this._provider.connection, vault.redeemableMint);
        const structure = await this.cegaSDK.fetchStructureAccount(
          vault.structuredProductInfoAccount,
          vault.address,
        );
        const stateInfo = await this.cegaSDK?.program.account.state.fetch(
          this.cegaSDK.stateAddress,
        );

        // user's token ownership of the vault based on withdraw amount
        const ownershipPercent = vaultWithdrawAmount / Number(mintTokenInfo.supply);
        const daysPassed =
          vault.knockOutEvent && vault.status !== programTypes.VaultStatus.Traded
            ? structure.daysPassed
            : structure.tenorInDays;

        // Calculate Collateral Returned
        // 1. calculated fraction of the annualized management fee based on tenor
        const managementFeePercentage =
          (stateInfo.managementFeePercentage / 10 ** 4) * (daysPassed / 365);
        const collateralAmount = vault.underlyingAmount * ownershipPercent;
        const collateralReturned = (1 - managementFeePercentage) * collateralAmount;

        // Calculate Yield Returned
        // 1. calculate fraction of annualized yield fee based on tenor
        // 2. calculate the fraction of apr based on tenor
        const yieldFeePercentage = stateInfo.yieldFeePercentage / 10 ** 4;
        const aprPercentage = ((structure.aprPercentage / 10 ** 4) * daysPassed) / 365;
        const yieldAmount = aprPercentage * collateralAmount;
        const yieldReturned = yieldAmount * (1 - yieldFeePercentage);

        const totalReturned = collateralReturned + yieldReturned;
        sumTotalReturned += totalReturned;
        withdrawalRemaining -= redeemableTokenInfo.amount;
      }
    }
    return sumTotalReturned / totalWithdrawalAmount;
  }
}
