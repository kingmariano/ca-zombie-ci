// Heliobond zombie-hunt PoC — FIXED-control variant (integration test).
// Copied to investment_vault/tests/poc_fixed.rs by ci/run.sh and run with
//   cargo test -p investment-vault --test poc_fixed -- --nocapture
// Same scenario as poc_vulnerable: victim 40,000; attacker 10,000; fund 15,000;
// victim queues. The fixed contract must deduct the queue from NAV, pay the
// attacker fairly, and stay solvent.
#![cfg(test)]

use investment_vault::{InvestmentVault, InvestmentVaultClient};
use soroban_sdk::{
    testutils::{Address as _, Ledger as _},
    token::{StellarAssetClient, TokenClient},
    Address, BytesN, Env, String,
};

mod registry_contract {
    soroban_sdk::contractimport!(file = "../target/wasm32v1-none/release/project_registry.wasm");
}

const MIN_LOCK_PERIOD: u64 = 86_400;

fn metadata_hash(env: &Env) -> BytesN<32> {
    BytesN::from_array(env, &[7u8; 32])
}

struct S {
    env: Env,
    vault_client: InvestmentVaultClient<'static>,
    vault_address: Address,
    usdc_sac: Address,
    registry: Address,
}

fn setup() -> S {
    let env = Env::default();
    env.mock_all_auths();
    let admin = Address::generate(&env);
    let registry_id = env.register(registry_contract::WASM, (&admin, &admin));
    let usdc_admin = Address::generate(&env);
    let usdc_sac = env.register_stellar_asset_contract_v2(usdc_admin.clone()).address();
    let contract_id = env.register(InvestmentVault, (&admin, &usdc_sac, &registry_id));
    let vault_client = InvestmentVaultClient::new(&env, &contract_id);
    S { env, vault_client, vault_address: contract_id, usdc_sac, registry: registry_id }
}

fn mint_usdc(env: &Env, usdc_sac: &Address, to: &Address, amount: i128) {
    StellarAssetClient::new(env, usdc_sac).mint(to, &amount);
}

#[test]
fn poc_fixed_control_no_double_count() {
    let s = setup();
    let victim = Address::generate(&s.env);
    let attacker = Address::generate(&s.env);

    let victim_deposit: i128 = 40_000_0000000;
    let attacker_deposit: i128 = 10_000_0000000;
    mint_usdc(&s.env, &s.usdc_sac, &victim, victim_deposit);
    mint_usdc(&s.env, &s.usdc_sac, &attacker, attacker_deposit);
    let victim_shares = s.vault_client.deposit(&victim, &victim_deposit);
    let attacker_shares = s.vault_client.deposit(&attacker, &attacker_deposit);

    let registry_client = registry_contract::Client::new(&s.env, &s.registry);
    let creator = Address::generate(&s.env);
    registry_client.set_whitelist(&creator, &true);
    let project_id = registry_client.create_project(
        &creator,
        &String::from_str(&s.env, "ipfs://poc-double-count-fixed"),
        &0u64,
        &metadata_hash(&s.env),
    );
    s.vault_client.fund_project(&project_id, &15_000_0000000);

    s.env.ledger().with_mut(|li| {
        li.timestamp += MIN_LOCK_PERIOD + 1;
        // current main also enforces a ledger-based withdrawal window (#530,
        // default 1 ledger); advance past it.
        li.sequence_number += 10;
    });

    let usdc = TokenClient::new(&s.env, &s.usdc_sac);
    let ta_before = s.vault_client.total_assets();
    let liquid_before = usdc.balance(&s.vault_address);
    let victim_claim = s.vault_client.convert_to_assets(&victim_shares);
    assert!(victim_claim > liquid_before, "precondition: victim queues");

    let paid_victim = s.vault_client.withdraw(&victim, &victim_shares, &0);
    assert_eq!(paid_victim, 0, "victim withdrawal queued");

    let ta_after_queue = s.vault_client.total_assets();
    let supply_after = s.vault_client.total_supply();

    assert_eq!(
        ta_after_queue,
        ta_before - victim_claim,
        "FIX CONFIRMED: total_assets excludes the queued claim"
    );

    let expected_payout = ta_after_queue * attacker_shares / supply_after;
    let attacker_cash_before = usdc.balance(&attacker);
    let paid_attacker = s.vault_client.withdraw(&attacker, &attacker_shares, &0);
    let attacker_cash = usdc.balance(&attacker);
    assert_eq!(paid_attacker, expected_payout, "fair payout");
    assert!(
        paid_attacker <= ta_after_queue,
        "attacker cannot be paid more than the remaining NAV"
    );

    let ta_final = s.vault_client.total_assets();
    // The sole remaining claim on the vault is the queue: gross assets
    // (liquid + investments) equal the queued claim exactly, so shareholder
    // NAV is zero and never negative.
    assert_eq!(
        ta_final, 0,
        "gross assets exactly back the queue; no negative NAV"
    );

    // Simulate the project repaying its 15,000 principal, then settle the
    // queue: the queued claimant must be paid in full.
    let payer = Address::generate(&s.env);
    mint_usdc(&s.env, &s.usdc_sac, &payer, 15_000_0000000);
    s.vault_client
        .repay_principal(&payer, &project_id, &15_000_0000000);
    let victim_cash_before = usdc.balance(&victim);
    let claimed = s.vault_client.claim();
    assert_eq!(
        claimed, victim_claim,
        "queue fully paid after the project repays (fixed code)"
    );
    assert_eq!(usdc.balance(&victim) - victim_cash_before, victim_claim);
    assert_eq!(s.vault_client.total_assets(), 0, "vault fully wound down");

    println!(
        "POC_JSON {{\"test\":\"poc_fixed_control_no_double_count\",\
\"victim_deposit\":{},\"attacker_deposit\":{},\
\"ta_before\":{},\"liquid_before\":{},\"victim_shares\":{},\"attacker_shares\":{},\
\"victim_claim\":{},\"ta_after_queue\":{},\"supply_after\":{},\
\"paid_attacker\":{},\"expected_payout\":{},\"ta_final\":{},\"attacker_net\":{}}}",
        victim_deposit,
        attacker_deposit,
        ta_before,
        liquid_before,
        victim_shares,
        attacker_shares,
        victim_claim,
        ta_after_queue,
        supply_after,
        paid_attacker,
        expected_payout,
        ta_final,
        attacker_cash - attacker_cash_before - attacker_deposit
    );
}
