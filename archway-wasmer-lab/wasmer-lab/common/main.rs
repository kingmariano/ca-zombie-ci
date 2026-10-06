// CWA-2026-006 differential runner.
// Modes:
//   patterns            -> static-memory guard sentinel test (R1)
//   run <file.wat>      -> execute all zero-arg exported functions, print JSON
//
// Built once per engine (see Cargo.toml feature selection in each lab-* crate).
use libc::{c_void, mmap, MAP_ANONYMOUS, MAP_FIXED_NOREPLACE, MAP_PRIVATE, PROT_READ, PROT_WRITE};
use std::env;
use std::fs;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Mutex;
use wasmer::{Function, Instance, Imports, Module, Store};

// wasmer-vm 4.2.2 references __rust_probestack, which modern Rust's compiler_builtins
// no longer exports. Provide a minimal stub (only for the 4.2.2 lab crate).
#[cfg(all(target_arch = "x86_64", feature = "probestack-stub"))]
core::arch::global_asm!(
    ".globl __rust_probestack",
    "__rust_probestack:",
    "ret",
);

const PATTERN_WAT: &str = r#"
(module
  (memory (export "memory") 1 512)
  (func (export "load_at_4gib") (result i64)
    (i64.load offset=2147483648 (i32.const -2147483648)))
  (func (export "load_at_5gib") (result i64)
    (i64.load offset=2147483648 (i32.const -1073741824)))
  (func (export "load_at_6gib") (result i64)
    (i64.load offset=4294967295 (i32.const -2147483647)))
  (func (export "load_at_7gib") (result i64)
    (i64.load offset=4294967295 (i32.const -1073741823)))
  (func (export "load_at_8gib") (result i64)
    (i64.load offset=4294967295 (i32.const -1)))
  (func (export "store_at_7gib") (param i64)
    (i64.store offset=4294967295 (i32.const -1073741823) (local.get 0)))
)
"#;

const GIB: usize = 1 << 30;

// ---------------- rsp drift probe (Hexens WASMageddon shape) ----------------

#[cfg(target_arch = "x86_64")]
fn read_rsp() -> u64 {
    let rsp: u64;
    unsafe {
        core::arch::asm!("mov {}, rsp", out(reg) rsp, options(nomem, nostack, preserves_flags));
    }
    rsp
}
#[cfg(not(target_arch = "x86_64"))]
fn read_rsp() -> u64 {
    0
}

static PROBE_CALLS: AtomicU64 = AtomicU64::new(0);
static PROBE_FIRST: AtomicU64 = AtomicU64::new(0);
static PROBE_LAST: AtomicU64 = AtomicU64::new(0);
static PROBE_MIN: AtomicU64 = AtomicU64::new(u64::MAX);
static PROBE_MAX: AtomicU64 = AtomicU64::new(0);

fn probe() -> i32 {
    let rsp = read_rsp();
    let n = PROBE_CALLS.fetch_add(1, Ordering::Relaxed);
    if n == 0 {
        PROBE_FIRST.store(rsp, Ordering::Relaxed);
    }
    PROBE_LAST.store(rsp, Ordering::Relaxed);
    PROBE_MIN.fetch_min(rsp, Ordering::Relaxed);
    PROBE_MAX.fetch_max(rsp, Ordering::Relaxed);
    0
}

fn drift(path: &str, iters: i32) {
    let src = match fs::read(path) {
        Ok(b) => b,
        Err(e) => {
            println!("{{\"pattern\":\"{}\",\"error\":\"read: {}\"}}", path, e);
            return;
        }
    };
    let mut store = Store::new(engine());
    let module = match Module::new(&store, &src) {
        Ok(m) => m,
        Err(e) => {
            println!("{{\"pattern\":\"{}\",\"error\":\"compile: {}\"}}", path, norm_err(&e));
            return;
        }
    };
    let mut imports = Imports::new();
    imports.define(
        "env",
        "probe",
        Function::new_typed(&mut store, |_: i32, _: i32, _: i32| -> i32 { probe() }),
    );
    let instance = match Instance::new(&mut store, &module, &imports) {
        Ok(i) => i,
        Err(e) => {
            println!("{{\"pattern\":\"{}\",\"error\":\"instantiate: {}\"}}", path, norm_err(&e));
            return;
        }
    };
    let f = match instance.exports.get_function("run") {
        Ok(f) => f,
        Err(e) => {
            println!("{{\"pattern\":\"{}\",\"error\":\"no run export: {}\"}}", path, norm_err(&e));
            return;
        }
    };
    let res = f.call(&mut store, &[wasmer::Value::I32(iters)]);
    let calls = PROBE_CALLS.load(Ordering::Relaxed);
    let first = PROBE_FIRST.load(Ordering::Relaxed);
    let last = PROBE_LAST.load(Ordering::Relaxed);
    let min = PROBE_MIN.load(Ordering::Relaxed);
    let max = PROBE_MAX.load(Ordering::Relaxed);
    let result = match &res {
        Ok(_) => "ok".to_string(),
        Err(e) => norm_err(e),
    };
    println!(
        "{{\"pattern\":\"{}\",\"iters\":{},\"calls\":{},\"result\":\"{}\",\"rsp_first\":\"0x{:x}\",\"rsp_last\":\"0x{:x}\",\"rsp_min\":\"0x{:x}\",\"rsp_max\":\"0x{:x}\",\"drift\":{}}}",
        path,
        iters,
        calls,
        result,
        first,
        last,
        min,
        max,
        first as i64 - last as i64
    );
}

// ---------------- E1: write-stream detector ----------------
//
// The host callback runs on the host stack (on_host_stack), so it cannot see
// the guest rsp. Instead it scans the fiber-stack mapping for the distinctive
// live values (i << 32) | K that `push_used_gpr` writes at the drifted rsp
// before each host call.

#[derive(Clone)]
struct WsScan {
    i: u64,
    hits: u64,
    min_addr: u64,
    max_addr: u64,
    addr_k0: u64,
    candidates: u64,
    maps_note: String,
    map_hits: String,
}

static WS_SCANS: Mutex<Vec<WsScan>> = Mutex::new(Vec::new());
static WS_CALLS: AtomicU64 = AtomicU64::new(0);
static WS_EXCL_LO: AtomicU64 = AtomicU64::new(0);
static WS_EXCL_HI: AtomicU64 = AtomicU64::new(0);

fn read_rw_maps() -> Vec<(u64, u64, String)> {
    let mut out = Vec::new();
    if let Ok(s) = fs::read_to_string("/proc/self/maps") {
        for line in s.lines() {
            let fields: Vec<&str> = line.split_whitespace().collect();
            if fields.len() < 2 || !fields[1].starts_with("rw") {
                continue;
            }
            let mut rp = fields[0].split('-');
            let (lo, hi) = match (rp.next(), rp.next()) {
                (Some(a), Some(b)) => (
                    u64::from_str_radix(a, 16).unwrap_or(0),
                    u64::from_str_radix(b, 16).unwrap_or(0),
                ),
                _ => continue,
            };
            let name = fields.get(5).copied().unwrap_or("").to_string();
            out.push((lo, hi, name));
        }
    }
    out
}

fn ws_scan(i: i32) {
    let iu = i as u64;
    let excl_lo = WS_EXCL_LO.load(Ordering::Relaxed);
    let excl_hi = WS_EXCL_HI.load(Ordering::Relaxed);
    let mut rec = WsScan {
        i: iu,
        hits: 0,
        min_addr: u64::MAX,
        max_addr: 0,
        addr_k0: 0,
        candidates: 0,
        maps_note: String::new(),
        map_hits: String::new(),
    };
    for (lo, hi, name) in read_rw_maps() {
        let size = hi.saturating_sub(lo);
        if !(256 * 1024..=32 * 1024 * 1024).contains(&size) {
            continue;
        }
        if name.contains("[stack]") || name.contains("[heap]") {
            continue;
        }
        if lo < excl_hi && hi > excl_lo {
            continue; // overlaps the wasm linear memory
        }
        rec.candidates += 1;
        if rec.maps_note.len() < 200 {
            rec.maps_note
                .push_str(&format!("{}@0x{:x}-0x{:x};", name, lo, hi));
        }
        let mut map_hits: u64 = 0;
        let mut addr = lo;
        while addr + 8 <= hi {
            let v = unsafe { core::ptr::read_volatile(addr as *const u64) };
            if (v >> 32) == iu && (v & 0xffff_ffff) < 64 {
                rec.hits += 1;
                map_hits += 1;
                if addr < rec.min_addr {
                    rec.min_addr = addr;
                }
                if addr > rec.max_addr {
                    rec.max_addr = addr;
                }
                if v & 0xffff_ffff == 0 {
                    rec.addr_k0 = addr;
                }
            }
            addr += 8;
        }
        if map_hits > 0 {
            rec.map_hits
                .push_str(&format!("0x{:x}-0x{:x}:{};", lo, hi, map_hits));
        }
    }
    if let Ok(mut v) = WS_SCANS.lock() {
        if v.len() < 256 {
            v.push(rec);
        }
    }
}

fn writestream(path: &str, iters: i32, stride: u64) {
    let src = match fs::read(path) {
        Ok(b) => b,
        Err(e) => {
            println!("{{\"pattern\":\"{}\",\"error\":\"read: {}\"}}", path, e);
            return;
        }
    };
    let mut store = Store::new(engine());
    let module = match Module::new(&store, &src) {
        Ok(m) => m,
        Err(e) => {
            println!("{{\"pattern\":\"{}\",\"error\":\"compile: {}\"}}", path, norm_err(&e));
            return;
        }
    };
    let mut imports = Imports::new();
    imports.define(
        "env",
        "probe",
        Function::new_typed(&mut store, move |i: i32, _: i32, _: i32| -> i32 {
            let _n = WS_CALLS.fetch_add(1, Ordering::Relaxed);
            let iu = i as u64;
            if stride == 0 || iu % stride == 0 || iu + 1 >= iters as u64 {
                ws_scan(i);
            }
            0
        }),
    );
    let instance = match Instance::new(&mut store, &module, &imports) {
        Ok(i) => i,
        Err(e) => {
            println!("{{\"pattern\":\"{}\",\"error\":\"instantiate: {}\"}}", path, norm_err(&e));
            return;
        }
    };
    if let Ok(mem) = instance.exports.get_memory("memory") {
        let view = mem.view(&store);
        let base = view.data_ptr() as u64;
        WS_EXCL_LO.store(base, Ordering::Relaxed);
        WS_EXCL_HI.store(base + view.data_size(), Ordering::Relaxed);
    }
    let f = match instance.exports.get_function("run") {
        Ok(f) => f,
        Err(e) => {
            println!("{{\"pattern\":\"{}\",\"error\":\"no run export: {}\"}}", path, norm_err(&e));
            return;
        }
    };
    let res = f.call(&mut store, &[wasmer::Value::I32(iters)]);
    let result = match &res {
        Ok(_) => "ok".to_string(),
        Err(e) => norm_err(e),
    };
    let calls = WS_CALLS.load(Ordering::Relaxed);
    let scans = WS_SCANS.lock().map(|v| v.clone()).unwrap_or_default();
    println!(
        "{{\"pattern\":\"{}\",\"iters\":{},\"calls\":{},\"result\":\"{}\",\"scans\":[",
        path, iters, calls, result
    );
    for (n, s) in scans.iter().enumerate() {
        let comma = if n + 1 < scans.len() { "," } else { "" };
        println!(
            "{{\"i\":{},\"hits\":{},\"min\":\"0x{:x}\",\"max\":\"0x{:x}\",\"k0\":\"0x{:x}\",\"candidates\":{},\"maps\":\"{}\",\"map_hits\":\"{}\"}}{}",
            s.i, s.hits, s.min_addr, s.max_addr, s.addr_k0, s.candidates, s.maps_note, s.map_hits, comma
        );
    }
    println!("]}}");
}

fn try_sentinel(addr: usize, magic: u64) -> Option<usize> {
    unsafe {
        let p = mmap(
            addr as *mut c_void,
            4096,
            PROT_READ | PROT_WRITE,
            MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED_NOREPLACE,
            -1,
            0,
        );
        if p == libc::MAP_FAILED {
            return None;
        }
        *(p as *mut u64) = magic;
        Some(p as usize)
    }
}

fn patterns() {
    let mut store = Store::new(engine());
    let module = Module::new(&store, PATTERN_WAT).expect("compile");
    let instance = Instance::new(&mut store, &module, &Imports::new()).expect("instantiate");
    let memory = instance.exports.get_memory("memory").expect("memory");
    let base = memory.view(&store).data_ptr() as usize;
    println!("memory base = 0x{:x}", base);

    let mut sentinels: Vec<(usize, u64)> = Vec::new();
    for (i, off) in [6usize, 7, 8, 9, 10].iter().enumerate() {
        let magic = 0xC0FFEE00_0000_0001u64 + i as u64;
        match try_sentinel(base + off * GIB, magic) {
            Some(p) => {
                println!("sentinel @ base+{}GiB = 0x{:x} (magic 0x{:x})", off, p, magic);
                sentinels.push((p, magic));
            }
            None => println!("sentinel @ base+{}GiB: mmap refused (reserved by engine?)", off),
        }
    }

    for name in [
        "load_at_4gib",
        "load_at_5gib",
        "load_at_6gib",
        "load_at_7gib",
        "load_at_8gib",
    ] {
        let f = instance.exports.get_function(name).expect(name);
        let res: Result<Box<[wasmer::Value]>, _> = f.call(&mut store, &[]);
        match res {
            Ok(vals) => {
                let v = vals[0].i64().unwrap_or(-1);
                let hit = sentinels
                    .iter()
                    .find(|(_, m)| *m == v as u64)
                    .map(|(p, _)| format!("0x{:x}", p))
                    .unwrap_or_else(|| "no".into());
                println!("{}: RETURNED 0x{:x} (sentinel hit: {})", name, v as u64, hit);
            }
            Err(e) => println!(
                "{}: TRAP/ERR ({})",
                name,
                format!("{}", e).lines().next().unwrap_or("")
            ),
        }
    }

    let f = instance.exports.get_function("store_at_7gib").unwrap();
    let magic = 0xDEADBEEF_00000007u64;
    match f.call(&mut store, &[wasmer::Value::I64(magic as i64)]) {
        Ok(_) => {
            let mut found = false;
            for (p, _) in &sentinels {
                let v = unsafe { *(*p as *const u64) };
                if v == magic {
                    println!("store_at_7gib: WROTE 0x{:x} INTO SENTINEL 0x{:x}", magic, p);
                    found = true;
                }
            }
            if !found {
                println!("store_at_7gib: returned Ok but no sentinel was modified");
            }
        }
        Err(e) => println!(
            "store_at_7gib: TRAP/ERR ({})",
            format!("{}", e).lines().next().unwrap_or("")
        ),
    }
}

fn norm_err(e: &dyn std::fmt::Display) -> String {
    let s = format!("{}", e);
    let l = s.to_lowercase();
    if l.contains("out of bounds") || l.contains("trap") || l.contains("unreachable") {
        "trap".to_string()
    } else if l.contains("stack overflow") {
        "stack-overflow".to_string()
    } else {
        let first = s.lines().next().unwrap_or("").to_string();
        format!("err:{}", first.chars().take(120).collect::<String>())
    }
}

fn fmt_value(v: &wasmer::Value) -> String {
    match v {
        wasmer::Value::I32(x) => format!("i32:{}", x),
        wasmer::Value::I64(x) => format!("i64:{}", x),
        wasmer::Value::F32(x) => format!("f32:{}", x),
        wasmer::Value::F64(x) => format!("f64:{}", x),
        other => format!("other:{:?}", other),
    }
}

fn run_file(path: &str) {
    let src = match fs::read(path) {
        Ok(b) => b,
        Err(e) => {
            println!("{{\"file\":\"{}\",\"status\":\"read_err:{}\"}}", path, e);
            return;
        }
    };
    let mut store = Store::new(engine());
    let module = match Module::new(&store, &src) {
        Ok(m) => m,
        Err(e) => {
            println!(
                "{{\"file\":\"{}\",\"status\":\"compile_err\",\"err\":\"{}\"}}",
                path,
                norm_err(&e)
            );
            return;
        }
    };
    let instance = match Instance::new(&mut store, &module, &Imports::new()) {
        Ok(i) => i,
        Err(e) => {
            println!("{{\"file\":\"{}\",\"status\":\"instantiate_err:{}\"}}", path, norm_err(&e));
            return;
        }
    };

    // collect zero-param exported functions, sorted by name
    let mut names: Vec<String> = Vec::new();
    for (name, ext) in instance.exports.iter() {
        if let wasmer::Extern::Function(f) = ext {
            if f.ty(&store).params().len() == 0 {
                names.push(name.to_string());
            }
        }
    }
    names.sort();

    let mut calls: Vec<String> = Vec::new();
    for name in &names {
        let f = instance.exports.get_function(name).unwrap();
        let res: Result<Box<[wasmer::Value]>, _> = f.call(&mut store, &[]);
        match res {
            Ok(vals) => {
                let vs: Vec<String> = vals.iter().map(fmt_value).collect();
                calls.push(format!("{{\"fn\":\"{}\",\"ok\":true,\"values\":[{}]}}", name, vs.join(",")));
            }
            Err(e) => {
                calls.push(format!("{{\"fn\":\"{}\",\"ok\":false,\"err\":\"{}\"}}", name, norm_err(&e)));
            }
        }
    }
    println!(
        "{{\"file\":\"{}\",\"status\":\"ok\",\"calls\":[{}]}}",
        path,
        calls.join(",")
    );
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() >= 2 && args[1] == "patterns" {
        patterns();
    } else if args.len() >= 3 && args[1] == "run" {
        run_file(&args[2]);
    } else if args.len() >= 4 && args[1] == "drift" {
        let iters: i32 = args[3].parse().unwrap_or(1000);
        drift(&args[2], iters);
    } else if args.len() >= 4 && args[1] == "writestream" {
        let iters: i32 = args[3].parse().unwrap_or(1000);
        let stride: u64 = args.get(4).and_then(|s| s.parse().ok()).unwrap_or(4096);
        writestream(&args[2], iters, stride);
    } else {
        eprintln!(
            "usage: {} patterns | run <file.wat> | drift <file.wat> <iters> | writestream <file.wat> <iters> [stride]",
            args[0]
        );
        std::process::exit(2);
    }
}

// ---- engine selection (one lab crate per engine; see Cargo.toml) ----
#[cfg(all(feature = "engine-singlepass", feature = "old-wasmer"))]
fn engine() -> wasmer::Singlepass {
    wasmer::Singlepass::default()
}

#[cfg(all(feature = "engine-singlepass", feature = "new-wasmer"))]
fn engine() -> wasmer::sys::Singlepass {
    wasmer::sys::Singlepass::new()
}

#[cfg(all(feature = "engine-cranelift", feature = "old-wasmer"))]
fn engine() -> wasmer::Cranelift {
    wasmer::Cranelift::default()
}

#[cfg(all(feature = "engine-cranelift", feature = "new-wasmer"))]
fn engine() -> wasmer::sys::Cranelift {
    wasmer::sys::Cranelift::default()
}
