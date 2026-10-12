fn main() {
    // Link the no-op __rust_probestack stub only into this binary.
    // See probestub.c for rationale.
    let dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();
    println!("cargo:rustc-link-arg={}/probestub.o", dir);
    println!("cargo:rerun-if-changed=probestub.o");
}
