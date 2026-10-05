use cosmwasm_std::{entry_point, Binary, Deps, DepsMut, Env, MessageInfo, Response, StdResult};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct InstantiateMsg {
    pub seed: u64,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum ExecuteMsg {
    /// storage write + read-back
    Set { key: String, value: String },
    Get { key: String },
    /// pure arithmetic loop (stress codegen)
    Loop { n: u32 },
    /// 64-bit ops
    Mix { a: i64, b: i64 },
    /// branch-heavy
    Classify { n: u32 },
    /// memory churn
    Churn { n: u32 },
}

#[entry_point]
pub fn instantiate(
    deps: DepsMut,
    _env: Env,
    _info: MessageInfo,
    msg: InstantiateMsg,
) -> StdResult<Response> {
    deps.storage.set(b"seed", &msg.seed.to_be_bytes());
    Ok(Response::new().add_attribute("seed", msg.seed.to_string()))
}

#[entry_point]
pub fn execute(
    deps: DepsMut,
    _env: Env,
    _info: MessageInfo,
    msg: ExecuteMsg,
) -> StdResult<Response> {
    match msg {
        ExecuteMsg::Set { key, value } => {
            deps.storage.set(key.as_bytes(), value.as_bytes());
            Ok(Response::new())
        }
        ExecuteMsg::Get { key } => {
            let v = deps.storage.get(key.as_bytes()).unwrap_or_default();
            Ok(Response::new().set_data(v))
        }
        ExecuteMsg::Loop { n } => {
            let mut x: u64 = 1;
            let mut i: u64 = 0;
            while i < n as u64 {
                x = x.wrapping_mul(6364136223846793005).wrapping_add(i);
                i += 1;
            }
            Ok(Response::new().set_data(x.to_be_bytes()))
        }
        ExecuteMsg::Mix { a, b } => {
            let mut x = a;
            let mut y = b;
            for _ in 0..32 {
                x = x.rotate_left(7).wrapping_add(y);
                y = y.rotate_right(3) ^ x;
            }
            Ok(Response::new().set_data(x.to_be_bytes()))
        }
        ExecuteMsg::Classify { n } => {
            let mut acc: u32 = 0;
            for i in 0..n {
                match i % 7 {
                    0 => acc = acc.wrapping_add(1),
                    1 => acc = acc.wrapping_mul(3),
                    2 => acc ^= i,
                    3 => acc = acc.wrapping_sub(5),
                    4 => acc = acc.rotate_left(1),
                    5 => acc = acc.wrapping_add(i),
                    _ => acc = acc.wrapping_mul(2).wrapping_add(7),
                }
            }
            Ok(Response::new().set_data(acc.to_be_bytes()))
        }
        ExecuteMsg::Churn { n } => {
            let mut v: Vec<u8> = Vec::with_capacity(4096);
            for i in 0..n {
                v.push((i & 0xff) as u8);
                if v.len() > 4096 {
                    v.clear();
                }
            }
            Ok(Response::new().set_data(Binary::from(v)))
        }
    }
}
