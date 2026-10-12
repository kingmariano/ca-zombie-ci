//! Runs the EXACT deployed Dojoswap factory wasm (code 1063) in cosmwasm-vm and
//! tests the guards on migrate_pair / admin_withdraw_denom / set_whitelist.
//! Read-only local execution; nothing is sent to any chain.
use cosmwasm_std::testing::MockQuerier as _StdMQ;
use cosmwasm_std::{Binary, ContractResult as StdContractResult, Empty, SystemResult, WasmQuery};
use cosmwasm_vm::testing::{MockApi, MockQuerier, MockStorage};
use cosmwasm_vm::{call_execute, call_instantiate, Backend, Instance, InstanceOptions};

const WASM: &[u8] = include_bytes!("../../deployed-factory-1063.wasm");

fn make_instance() -> Instance<MockApi, MockStorage, MockQuerier> {
    let mut querier = MockQuerier::new(&[]);
    querier.update_wasm(|_q: &WasmQuery| {
        let resp = serde_json::json!({"balance": "0"});
        SystemResult::Ok(StdContractResult::Ok(Binary::from(resp.to_string().as_bytes())))
    });
    let backend = Backend { api: MockApi::default(), storage: MockStorage::default(), querier };
    Instance::from_code(WASM, backend, InstanceOptions { gas_limit: 500_000_000_000, print_debug: false }, None).unwrap()
}

fn main() {
    let _ = std::any::type_name::<_StdMQ>();
    let owner = "inj1owner0000000000000000000000000000000000";
    let attacker = "inj1attacker00000000000000000000000000000000";

    // try candidate instantiate shapes
    for init in [
        serde_json::json!({"token_code_id": 292, "pair_code_id": 290}),
        serde_json::json!({"owner": owner, "token_code_id": 292, "pair_code_id": 290}),
    ] {
        let mut instance = make_instance();
        match call_instantiate::<_, _, _, Empty>(&mut instance, &cosmwasm_vm::testing::mock_env(), &cosmwasm_vm::testing::mock_info(owner, &[]), init.to_string().as_bytes()) {
            Ok(StdContractResult::Ok(_)) => {
                println!("instantiate OK with {init}");

                // 1) migrate_pair from a NON-owner
                let mp = serde_json::json!({"migrate_pair": {"contract": "inj1pair000000000000000000000000000000000000", "code_id": 290}});
                match call_execute::<_, _, _, Empty>(&mut instance, &cosmwasm_vm::testing::mock_env(), &cosmwasm_vm::testing::mock_info(attacker, &[]), mp.to_string().as_bytes()) {
                    Ok(StdContractResult::Ok(resp)) => {
                        println!("!!! migrate_pair BY NON-OWNER SUCCEEDED: msgs={} {:?}", resp.messages.len(),
                                 resp.messages.iter().map(|m| serde_json::to_string(&m.msg).unwrap_or_default()).collect::<Vec<_>>());
                    }
                    Ok(StdContractResult::Err(e)) => println!("migrate_pair by non-owner REJECTED: {e}"),
                    Err(e) => println!("migrate_pair VM ERR: {e}"),
                }

                // 2) migrate_pair from the owner (positive control)
                let mp2 = serde_json::json!({"migrate_pair": {"contract": "inj1pair000000000000000000000000000000000000", "code_id": 290}});
                match call_execute::<_, _, _, Empty>(&mut instance, &cosmwasm_vm::testing::mock_env(), &cosmwasm_vm::testing::mock_info(owner, &[]), mp2.to_string().as_bytes()) {
                    Ok(StdContractResult::Ok(resp)) => println!("migrate_pair by OWNER OK: msgs={} {:?}", resp.messages.len(),
                        resp.messages.iter().map(|m| serde_json::to_string(&m.msg).unwrap_or_default()).collect::<Vec<_>>()),
                    Ok(StdContractResult::Err(e)) => println!("migrate_pair by OWNER REJECTED: {e}"),
                    Err(e) => println!("migrate_pair owner VM ERR: {e}"),
                }

                // 3) admin_withdraw_denom from a NON-owner
                let wd = serde_json::json!({"admin_withdraw_denom": {"amount": "1", "denom": "inj"}});
                match call_execute::<_, _, _, Empty>(&mut instance, &cosmwasm_vm::testing::mock_env(), &cosmwasm_vm::testing::mock_info(attacker, &[]), wd.to_string().as_bytes()) {
                    Ok(StdContractResult::Ok(resp)) => println!("!!! admin_withdraw_denom BY NON-OWNER SUCCEEDED: msgs={}", resp.messages.len()),
                    Ok(StdContractResult::Err(e)) => println!("admin_withdraw_denom by non-owner REJECTED: {e}"),
                    Err(e) => println!("admin_withdraw_denom VM ERR: {e}"),
                }

                // 4) set_whitelist from a NON-owner
                let sw = serde_json::json!({"set_whitelist": {"address": attacker, "enable": true}});
                match call_execute::<_, _, _, Empty>(&mut instance, &cosmwasm_vm::testing::mock_env(), &cosmwasm_vm::testing::mock_info(attacker, &[]), sw.to_string().as_bytes()) {
                    Ok(StdContractResult::Ok(resp)) => println!("!!! set_whitelist BY NON-OWNER SUCCEEDED: msgs={}", resp.messages.len()),
                    Ok(StdContractResult::Err(e)) => println!("set_whitelist by non-owner REJECTED: {e}"),
                    Err(e) => println!("set_whitelist VM ERR: {e}"),
                }
                return;
            }
            Ok(StdContractResult::Err(e)) => println!("instantiate shape failed: {init} -> {e}"),
            Err(e) => println!("instantiate VM ERR: {e}"),
        }
    }
}

#[no_mangle]
pub extern "C" fn __rust_probestack() {}
