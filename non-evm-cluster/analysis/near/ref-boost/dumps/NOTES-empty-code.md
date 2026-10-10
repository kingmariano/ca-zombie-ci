# Why ref-farming.near.wasm is 0 bytes

`view_code(ref-farming.near)` (block 219,323,775 / nearblocks contract endpoint) returns `code_base64: ""`
and `code_hash = GKot5hBsd81kMupNCXHaqbhv3huEbxAFMLnpcX2hniwn` =
base58(sha256(b"")) — the canonical hash of **empty code**. Same for `ref-finance.near`.
Hence the saved "wasm" is a 0-byte file and every call fails with
`CompilationError(PrepareError(Deserialization))` (block 219,321,488).
This is evidence, not a failed dump.
