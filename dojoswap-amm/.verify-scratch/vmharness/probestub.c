/* Historical compiler-builtins symbol (removed in newer rustc).
   wasmer-vm 4.2.2 keeps a pointer to it in its libcall table.
   For wasm-on-native JIT of a CosmWasm contract this libcall is not
   exercised; a no-op stub is sufficient to link. */
void __rust_probestack(void) {}
