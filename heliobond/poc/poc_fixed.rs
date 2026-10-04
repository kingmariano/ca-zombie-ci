// ═══════════════════════════════════════════════════════════════════════════
// HELIOBOND ZOMBIE-HUNT PoC — FIXED-CONTROL variant (same scenario).
//
// Appended by the CI job to investment_vault/src/test.rs of the FIXED commit
// (current main, b233e10; fix e99b4cc "deduct queued redemption liabilities
// from total_assets"). Must show: NAV excludes the queue, the attacker is paid
// exactly their fair equity, and the vault stays solvent for the queue.
// ═══════════════════════════════════════════════════════════════════════════
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
        &test_metadata_hash(&s.env),
    );
    s.vault_client.fund_project(&project_id, &15_000_0000000);

    s.env.ledger().with_mut(|li| {
        li.timestamp += MIN_LOCK_PERIOD + 1;
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

    // FIX: NAV is reduced by the queued liability.
    assert_eq!(
        ta_after_queue,
        ta_before - victim_claim,
        "FIX CONFIRMED: total_assets excludes the queued claim"
    );

    // Attacker redeems all remaining shares at the fair price.
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
    assert!(
        ta_final >= victim_claim,
        "SOLVENT: total_assets {} >= queued liabilities {}",
        ta_final,
        victim_claim
    );

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
