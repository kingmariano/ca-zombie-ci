//! Independent verification harness: executes the DEPLOYED locker wasm
//! (code_id 1178 on Injective, sha256 489efa1f...) inside a local CosmWasm VM
//! against the real on-chain storage snapshot, to test whether an unprivileged
//! caller can unstake an expired lock.
//!
//! Usage:
//!   vmharness <wasm> <storage_hex.json> [mode] [time_unix] [sender] [lock_id]
//! modes: expired | future | disabled | owner

use cosmwasm_std::{
    to_json_binary, Addr, BlockInfo, ContractInfo, ContractResult, Empty, Env, MessageInfo,
    SystemResult, Timestamp, TransactionInfo, WasmQuery,
};
use cosmwasm_vm::testing::{MockApi, MockQuerier, MockStorage};
use cosmwasm_vm::{Backend, Instance, InstanceOptions, Size, Storage};

const LOCKER: &str = "inj1kmu3lhsxz0h49kq342frpnpq6qmpz7pv65zwlq";
const LP_TOKEN: &str = "inj1nj2gnkkphk370n2086n27m6ryj5sjlsuxthla8";
const DEFAULT_ATTACKER: &str = "inj1r3xsl82rluavmfy5usexy8s203f3etesap0qqy";
const DEFAULT_LOCK: &str = "df1109dba3ab40dfde16b3eb005b77f97dd870f90c1b34bcb77a271eda687b61";
const LOCK_OWNER: &str = "inj18xsczx27lanjt40y9v79q0v57d76j2s8ctj85x";
const CHAIN_TIME: u64 = 1_791_758_407; // 2026-10-11T22:40:07Z (Injective mainnet block ~186,888,846)
const LOCKER_LP_BALANCE: &str = "174717569558057606";
const LP_TOTAL_SUPPLY: &str = "176482597834073977";

fn hex_decode(s: &str) -> Vec<u8> {
    let b = s.as_bytes();
    assert!(b.len() % 2 == 0, "odd hex length");
    let val = |c: u8| -> u8 {
        match c {
            b'0'..=b'9' => c - b'0',
            b'a'..=b'f' => c - b'a' + 10,
            b'A'..=b'F' => c - b'A' + 10,
            _ => panic!("invalid hex char"),
        }
    };
    (0..b.len() / 2)
        .map(|i| (val(b[2 * i]) << 4) | val(b[2 * i + 1]))
        .collect()
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let wasm_path = args
        .get(1)
        .expect("usage: vmharness <wasm> <storage_hex.json> [mode] [time] [sender] [lock_id]");
    let storage_path = args.get(2).expect("storage hex json path");
    let mode = args.get(3).cloned().unwrap_or_else(|| "expired".to_string());
    let time: u64 = args.get(4).map(|s| s.parse().unwrap()).unwrap_or(CHAIN_TIME);
    let sender = args
        .get(5)
        .cloned()
        .unwrap_or_else(|| DEFAULT_ATTACKER.to_string());
    let lock_id = args
        .get(6)
        .cloned()
        .unwrap_or_else(|| DEFAULT_LOCK.to_string());

    let wasm = std::fs::read(wasm_path).expect("read wasm");
    let manifest: serde_json::Value =
        serde_json::from_str(&std::fs::read_to_string(storage_path).unwrap()).unwrap();

    let mut storage = MockStorage::new();
    for (k, v) in manifest.as_object().unwrap() {
        let key = hex_decode(k);
        let val = hex_decode(v.as_str().unwrap());
        storage.set(&key, &val).0.unwrap();
    }
    if mode == "disabled" {
        let cfg = storage.get(b"config").0.unwrap().unwrap();
        let mut c: serde_json::Value = serde_json::from_slice(&cfg).unwrap();
        c["enabled"] = serde_json::Value::Bool(false);
        storage
            .set(b"config", &serde_json::to_vec(&c).unwrap())
            .0
            .unwrap();
    }

    // Mock the LP token smart queries (balance / token_info / minter), using the
    // real on-chain values, in case the contract queries the token during
    // execute. Bank balances are handled by MockQuerier itself.
    let mut querier = MockQuerier::new(&[]);
    querier.update_wasm(move |req| {
        if let WasmQuery::Smart { contract_addr, msg } = req {
            if contract_addr == LP_TOKEN {
                let m: serde_json::Value =
                    serde_json::from_slice(msg.as_slice()).unwrap_or(serde_json::Value::Null);
                let resp = if m.get("balance").is_some() {
                    serde_json::json!({ "balance": LOCKER_LP_BALANCE })
                } else if m.get("token_info").is_some() {
                    serde_json::json!({
                        "name": "dojoswap liquidity token",
                        "symbol": "uLP",
                        "decimals": 6,
                        "total_supply": LP_TOTAL_SUPPLY
                    })
                } else if m.get("minter").is_some() {
                    serde_json::json!({ "minter": "inj1859sjey6v43cz40rtj8scka5xng2vn5c37j6f5", "cap": null })
                } else {
                    serde_json::Value::Null
                };
                let bin = to_json_binary(&resp).unwrap();
                return SystemResult::Ok(ContractResult::Ok(bin));
            }
        }
        SystemResult::Err(cosmwasm_std::SystemError::Unknown {})
    });

    let api = MockApi::default();
    let backend = Backend {
        api,
        storage,
        querier,
    };
    let mut instance = Instance::from_code(
        &wasm,
        backend,
        InstanceOptions {
            gas_limit: 500_000_000_000,
            print_debug: true,
        },
        Some(Size::mebi(32)),
    )
    .expect("instance");

    let env = Env {
        block: BlockInfo {
            height: 186_888_850,
            time: Timestamp::from_seconds(time),
            chain_id: "injective-1".to_string(),
        },
        transaction: Some(TransactionInfo { index: 0 }),
        contract: ContractInfo {
            address: Addr::unchecked(LOCKER),
        },
    };
    let info = MessageInfo {
        sender: Addr::unchecked(&sender),
        funds: vec![],
    };
    let msg = serde_json::json!({ "unstake": { "denom": lock_id } });
    let msgbytes = serde_json::to_vec(&msg).unwrap();

    println!("scenario mode={mode} time={time} sender={sender} lock_id={lock_id}");
    match cosmwasm_vm::call_execute::<MockApi, MockStorage, MockQuerier, Empty>(
        &mut instance,
        &env,
        &info,
        &msgbytes,
    ) {
        Ok(cr) => println!("RESULT_JSON {}", serde_json::to_string(&cr).unwrap()),
        Err(e) => println!("VM_ERROR {e:?}"),
    }
    // The lock owner address is referenced so the "owner" scenario is reproducible.
    let _ = LOCK_OWNER;
}
