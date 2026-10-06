;; P0 — control: same loop + host call but NO result-bearing if/else.
;; Should show no rsp drift on any engine (baseline for the P1 probe).
(module
  (import "env" "probe" (func $host (param i32 i32 i32) (result i32)))
  (memory 1)
  (func (export "run") (param $iters i32) (result i32)
    (local $i i32)
    (block $exit
      (loop $l
        i64.const 0x1111111111111111
        i64.const 0x2222222222222222
        i64.const 0x3333333333333333
        i64.const 0x4444444444444444
        i64.const 0x5555555555555555
        i64.const 0x6666666666666666
        i64.const 0x7777777777777777
        i64.const 0x8888888888888888
        drop drop drop drop drop drop drop drop
        i32.const 0
        i32.const 0
        i32.const 0
        call $host
        drop
        local.get $i
        i32.const 1
        i32.add
        local.tee $i
        local.get $iters
        i32.lt_u
        br_if $l
      )
    )
    local.get $i
  )
)
