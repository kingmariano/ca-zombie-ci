;; P1b — same shape, 12 live i64s (more spill pressure)
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
        i64.const 0x9999999999999999
        i64.const 0xAAAAAAAAAAAAAAA1
        i64.const 0xBBBBBBBBBBBBBBB2
        i64.const 0xCCCCCCCCCCCCCCC3
        i64.const 1
        if (result i64)
          i64.const 0xAAAAAAAAAAAAAAAA
        else
          i64.const 0xBBBBBBBBBBBBBBBB
        end
        drop
        drop drop drop drop drop drop drop drop drop drop drop drop
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
