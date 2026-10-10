(module
  (type (;0;) (func))
  (type (;1;) (func (result i32)))
  (type (;2;) (func (param i32 i32)))
  (type (;3;) (func (param i32 i32) (result i32)))
  (type (;4;) (func (param i32 i32 i32) (result i32)))
  (type (;5;) (func (param i64)))
  (type (;6;) (func (param i64 i64 i64 i64) (result i32)))
  (type (;7;) (func (param i32 i32) (result i64)))
  (type (;8;) (func (result i64)))
  (type (;9;) (func (param i32 i64)))
  (type (;10;) (func (param i32)))
  (type (;11;) (func (param i64 i64 i64 i32 i64) (result i32)))
  (type (;12;) (func (param i64 i64 i64)))
  (type (;13;) (func (param i32) (result i32)))
  (type (;14;) (func (param i64 i64)))
  (type (;15;) (func (param i32 i32 i32)))
  (type (;16;) (func (param i32 i32 i32 i32)))
  (import "env" "action_data_size" (func (;0;) (type 1)))
  (import "env" "eosio_assert" (func (;1;) (type 2)))
  (import "env" "read_action_data" (func (;2;) (type 3)))
  (import "env" "memcpy" (func (;3;) (type 4)))
  (import "env" "require_auth" (func (;4;) (type 5)))
  (import "env" "db_lowerbound_i64" (func (;5;) (type 6)))
  (import "env" "db_next_i64" (func (;6;) (type 3)))
  (import "env" "abort" (func (;7;) (type 0)))
  (import "env" "set_blockchain_parameters_packed" (func (;8;) (type 2)))
  (import "env" "get_blockchain_parameters_packed" (func (;9;) (type 3)))
  (import "env" "set_proposed_producers" (func (;10;) (type 7)))
  (import "env" "current_time" (func (;11;) (type 8)))
  (import "env" "get_active_producers" (func (;12;) (type 3)))
  (import "env" "prints_l" (func (;13;) (type 2)))
  (import "env" "eosio_assert_code" (func (;14;) (type 9)))
  (import "env" "db_get_i64" (func (;15;) (type 4)))
  (import "env" "current_receiver" (func (;16;) (type 8)))
  (import "env" "db_remove_i64" (func (;17;) (type 10)))
  (import "env" "db_idx128_find_primary" (func (;18;) (type 11)))
  (import "env" "db_idx128_remove" (func (;19;) (type 10)))
  (func (;20;) (type 0)
    call 24)
  (func (;21;) (type 12) (param i64 i64 i64)
    local.get 0
    call 28
    call 20
    local.get 0
    local.get 1
    i64.eq
    if  ;; label = @1
      i64.const 4923678677923243008
      local.get 2
      i64.eq
      if  ;; label = @2
        local.get 0
        local.get 1
        call 30
      else
        local.get 0
        i64.const 6138663577826885632
        i64.ne
        if  ;; label = @3
          i32.const 0
          i64.const 8000000000000000000
          call 14
        end
      end
    else
      i64.const 6138663577826885632
      local.get 1
      i64.eq
      if  ;; label = @2
        i64.const -6569208335818555392
        local.get 2
        i64.eq
        if  ;; label = @3
          i32.const 0
          i64.const 8000000000000000001
          call 14
        end
      end
    end
    i32.const 0
    call 29)
  (func (;22;) (type 13) (param i32) (result i32)
    (local i32 i32 i32)
    block  ;; label = @1
      local.get 0
      br_if 0 (;@1;)
      i32.const 0
      return
    end
    i32.const 0
    i32.const 0
    i32.load offset=8204
    local.get 0
    i32.const 16
    i32.shr_u
    local.tee 1
    i32.add
    local.tee 2
    i32.store offset=8204
    i32.const 0
    i32.const 0
    i32.load offset=8196
    local.tee 3
    local.get 0
    i32.add
    i32.const 15
    i32.add
    i32.const -16
    i32.and
    local.tee 0
    i32.store offset=8196
    block  ;; label = @1
      local.get 2
      i32.const 16
      i32.shl
      local.get 0
      i32.gt_u
      br_if 0 (;@1;)
      i32.const 0
      local.get 2
      i32.const 1
      i32.add
      i32.store offset=8204
      local.get 1
      i32.const 1
      i32.add
      local.set 1
    end
    block  ;; label = @1
      local.get 1
      memory.grow
      i32.const -1
      i32.ne
      br_if 0 (;@1;)
      i32.const 0
      i32.const 8208
      call 1
    end
    local.get 3)
  (func (;23;) (type 10) (param i32))
  (func (;24;) (type 0)
    (local i32)
    global.get 0
    i32.const 16
    i32.sub
    local.tee 0
    i32.const 0
    i32.store offset=12
    i32.const 0
    local.get 0
    i32.load offset=12
    i32.load
    i32.const 15
    i32.add
    i32.const -16
    i32.and
    local.tee 0
    i32.store offset=8192
    i32.const 0
    local.get 0
    i32.store offset=8196
    i32.const 0
    memory.size
    i32.store offset=8204)
  (func (;25;) (type 13) (param i32) (result i32)
    (local i32 i32)
    local.get 0
    i32.const 1
    local.get 0
    select
    local.set 1
    block  ;; label = @1
      loop  ;; label = @2
        local.get 1
        call 22
        local.tee 0
        br_if 1 (;@1;)
        i32.const 0
        local.set 0
        i32.const 0
        i32.load offset=8260
        local.tee 2
        i32.eqz
        br_if 1 (;@1;)
        local.get 2
        call_indirect (type 0)
        br 0 (;@2;)
      end
    end
    local.get 0)
  (func (;26;) (type 10) (param i32)
    local.get 0
    call 23)
  (func (;27;) (type 10) (param i32)
    call 7
    unreachable)
  (func (;28;) (type 5) (param i64)
    i32.const 0
    local.get 0
    i64.store offset=8264)
  (func (;29;) (type 10) (param i32))
  (func (;30;) (type 14) (param i64 i64)
    (local i32 i32 i32 i32)
    global.get 0
    i32.const 48
    i32.sub
    local.tee 2
    local.set 3
    local.get 2
    global.set 0
    block  ;; label = @1
      block  ;; label = @2
        call 0
        local.tee 4
        br_if 0 (;@2;)
        i32.const 0
        local.set 2
        br 1 (;@1;)
      end
      block  ;; label = @2
        block  ;; label = @3
          local.get 4
          i32.const 512
          i32.lt_u
          br_if 0 (;@3;)
          local.get 4
          call 22
          local.set 2
          br 1 (;@2;)
        end
        local.get 2
        local.get 4
        i32.const 15
        i32.add
        i32.const -16
        i32.and
        i32.sub
        local.tee 2
        global.set 0
      end
      local.get 2
      local.get 4
      call 2
      drop
    end
    local.get 3
    i64.const 0
    i64.store offset=40
    local.get 2
    local.get 4
    i32.add
    local.set 5
    block  ;; label = @1
      local.get 4
      i32.const 7
      i32.gt_u
      br_if 0 (;@1;)
      i32.const 0
      i32.const 8295
      call 1
    end
    local.get 3
    i32.const 40
    i32.add
    local.get 2
    i32.const 8
    call 3
    drop
    local.get 3
    i32.const 32
    i32.add
    local.get 5
    i32.store
    local.get 3
    i32.const 28
    i32.add
    local.get 2
    i32.const 8
    i32.add
    i32.store
    local.get 3
    local.get 2
    i32.store offset=24
    local.get 3
    local.get 1
    i64.store offset=16
    local.get 3
    local.get 0
    i64.store offset=8
    local.get 3
    i32.const 8
    i32.add
    local.get 3
    i64.load offset=40
    call 31
    local.get 3
    i32.const 48
    i32.add
    global.set 0)
  (func (;31;) (type 9) (param i32 i64)
    (local i32 i64 i32 i32 i32)
    global.get 0
    i32.const 48
    i32.sub
    local.tee 2
    global.set 0
    local.get 0
    i64.load
    call 4
    local.get 2
    i32.const 32
    i32.add
    i32.const 0
    i32.store
    local.get 2
    i64.const -1
    i64.store offset=16
    local.get 2
    local.get 0
    i64.load
    local.tee 3
    i64.store
    local.get 2
    i64.const 0
    i64.store offset=24
    local.get 2
    local.get 1
    i64.store offset=8
    block  ;; label = @1
      block  ;; label = @2
        local.get 3
        local.get 1
        i64.const 6301537847124808880
        i64.const 0
        call 5
        local.tee 0
        i32.const 0
        i32.lt_s
        br_if 0 (;@2;)
        local.get 2
        local.get 0
        call 32
        local.set 4
        i32.const 1
        local.set 5
        loop  ;; label = @3
          i32.const 0
          local.set 0
          block  ;; label = @4
            local.get 4
            i32.load offset=28
            local.get 2
            i32.const 40
            i32.add
            call 6
            local.tee 6
            i32.const 0
            i32.lt_s
            br_if 0 (;@4;)
            local.get 2
            local.get 6
            call 32
            local.set 0
          end
          local.get 2
          local.get 4
          call 33
          local.get 0
          i32.eqz
          br_if 2 (;@1;)
          local.get 5
          i32.const 1000
          i32.lt_u
          local.set 6
          local.get 5
          i32.const 1
          i32.add
          local.set 5
          local.get 0
          local.set 4
          local.get 6
          br_if 0 (;@3;)
          br 2 (;@1;)
        end
      end
      i32.const 0
      i32.const 8233
      call 1
    end
    block  ;; label = @1
      local.get 2
      i32.load offset=24
      local.tee 5
      i32.eqz
      br_if 0 (;@1;)
      block  ;; label = @2
        block  ;; label = @3
          local.get 2
          i32.load offset=28
          local.tee 0
          local.get 5
          i32.ne
          br_if 0 (;@3;)
          local.get 5
          local.set 0
          br 1 (;@2;)
        end
        loop  ;; label = @3
          local.get 0
          i32.const -24
          i32.add
          local.tee 0
          i32.load
          local.set 4
          local.get 0
          i32.const 0
          i32.store
          block  ;; label = @4
            local.get 4
            i32.eqz
            br_if 0 (;@4;)
            local.get 4
            call 26
          end
          local.get 5
          local.get 0
          i32.ne
          br_if 0 (;@3;)
        end
        local.get 2
        i32.load offset=24
        local.set 0
      end
      local.get 2
      local.get 5
      i32.store offset=28
      local.get 0
      call 26
    end
    local.get 2
    i32.const 48
    i32.add
    global.set 0)
  (func (;32;) (type 3) (param i32 i32) (result i32)
    (local i32 i32 i32 i32 i64 i32)
    global.get 0
    i32.const 48
    i32.sub
    local.tee 2
    global.set 0
    local.get 2
    local.tee 3
    local.get 1
    i32.store offset=44
    block  ;; label = @1
      block  ;; label = @2
        local.get 0
        i32.load offset=24
        local.tee 4
        local.get 0
        i32.const 28
        i32.add
        i32.load
        local.tee 5
        i32.eq
        br_if 0 (;@2;)
        block  ;; label = @3
          loop  ;; label = @4
            local.get 5
            i32.const -8
            i32.add
            i32.load
            local.get 1
            i32.eq
            br_if 1 (;@3;)
            local.get 4
            local.get 5
            i32.const -24
            i32.add
            local.tee 5
            i32.ne
            br_if 0 (;@4;)
            br 2 (;@2;)
          end
        end
        local.get 4
        local.get 5
        i32.eq
        br_if 0 (;@2;)
        local.get 5
        i32.const -24
        i32.add
        i32.load
        local.set 1
        br 1 (;@1;)
      end
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              local.get 1
              i32.const 0
              i32.const 0
              call 15
              local.tee 4
              i32.const -1
              i32.gt_s
              br_if 0 (;@5;)
              i32.const 0
              i32.const 8272
              call 1
              br 1 (;@4;)
            end
            local.get 4
            i32.const 513
            i32.lt_u
            br_if 1 (;@3;)
          end
          local.get 4
          call 22
          local.set 5
          i32.const 1
          local.set 2
          br 1 (;@2;)
        end
        local.get 2
        local.get 4
        i32.const 15
        i32.add
        i32.const -16
        i32.and
        i32.sub
        local.tee 5
        global.set 0
        i32.const 0
        local.set 2
      end
      local.get 1
      local.get 5
      local.get 4
      call 15
      drop
      local.get 3
      local.get 5
      local.get 4
      i32.add
      i32.store offset=40
      local.get 3
      local.get 5
      i32.store offset=36
      local.get 3
      local.get 5
      i32.store offset=32
      local.get 3
      local.get 0
      i32.store offset=20
      local.get 3
      local.get 3
      i32.const 44
      i32.add
      i32.store offset=12
      local.get 3
      local.get 3
      i32.const 32
      i32.add
      i32.store offset=8
      local.get 3
      i32.const 24
      i32.add
      local.get 3
      i32.const 20
      i32.add
      local.get 3
      i32.const 8
      i32.add
      call 34
      local.get 3
      local.get 3
      i32.load offset=24
      local.tee 1
      i64.load32_u
      local.tee 6
      i64.store offset=8
      local.get 3
      local.get 1
      i32.load offset=28
      local.tee 7
      i32.store offset=20
      block  ;; label = @2
        block  ;; label = @3
          local.get 0
          i32.load offset=28
          local.tee 4
          local.get 0
          i32.const 32
          i32.add
          i32.load
          i32.ge_u
          br_if 0 (;@3;)
          local.get 4
          local.get 7
          i32.store offset=16
          local.get 4
          local.get 6
          i64.store offset=8
          local.get 3
          i32.const 0
          i32.store offset=24
          local.get 4
          local.get 1
          i32.store
          local.get 0
          local.get 4
          i32.const 24
          i32.add
          i32.store offset=28
          br 1 (;@2;)
        end
        local.get 0
        i32.const 24
        i32.add
        local.get 3
        i32.const 24
        i32.add
        local.get 3
        i32.const 8
        i32.add
        local.get 3
        i32.const 20
        i32.add
        call 35
      end
      block  ;; label = @2
        local.get 2
        i32.eqz
        br_if 0 (;@2;)
        local.get 5
        call 23
      end
      local.get 3
      i32.load offset=24
      local.set 5
      local.get 3
      i32.const 0
      i32.store offset=24
      local.get 5
      i32.eqz
      br_if 0 (;@1;)
      local.get 5
      call 26
    end
    local.get 3
    i32.const 48
    i32.add
    global.set 0
    local.get 1)
  (func (;33;) (type 2) (param i32 i32)
    (local i32 i32 i32 i32 i32 i32 i32)
    global.get 0
    i32.const 16
    i32.sub
    local.tee 2
    global.set 0
    block  ;; label = @1
      local.get 1
      i32.load offset=24
      local.get 0
      i32.eq
      br_if 0 (;@1;)
      i32.const 0
      i32.const 8337
      call 1
    end
    block  ;; label = @1
      call 16
      local.get 0
      i64.load
      i64.eq
      br_if 0 (;@1;)
      i32.const 0
      i32.const 8382
      call 1
    end
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            local.get 0
            i32.load offset=24
            local.tee 3
            local.get 0
            i32.const 28
            i32.add
            i32.load
            local.tee 4
            i32.eq
            br_if 0 (;@4;)
            block  ;; label = @5
              local.get 1
              i32.load
              local.tee 5
              local.get 4
              i32.const -24
              i32.add
              i32.load
              i32.load
              i32.ne
              br_if 0 (;@5;)
              local.get 4
              local.set 6
              br 2 (;@3;)
            end
            local.get 3
            i32.const 24
            i32.add
            local.set 7
            loop  ;; label = @5
              local.get 7
              local.get 4
              i32.eq
              br_if 1 (;@4;)
              local.get 4
              i32.const -48
              i32.add
              local.set 8
              local.get 4
              i32.const -24
              i32.add
              local.tee 6
              local.set 4
              local.get 5
              local.get 8
              i32.load
              i32.load
              i32.eq
              br_if 2 (;@3;)
              br 0 (;@5;)
            end
          end
          local.get 3
          local.set 6
          br 1 (;@2;)
        end
        local.get 3
        local.get 6
        i32.ne
        br_if 1 (;@1;)
      end
      i32.const 0
      i32.const 8432
      call 1
    end
    local.get 1
    i32.load offset=28
    call 17
    block  ;; label = @1
      block  ;; label = @2
        local.get 1
        i32.const 32
        i32.add
        i32.load
        local.tee 4
        i32.const -1
        i32.gt_s
        br_if 0 (;@2;)
        local.get 0
        i64.load
        local.get 0
        i64.load offset=8
        i64.const 6301537847124808880
        local.get 2
        local.get 1
        i64.load32_u
        call 18
        local.tee 4
        i32.const 0
        i32.lt_s
        br_if 1 (;@1;)
      end
      local.get 4
      call 19
    end
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          local.get 6
          local.get 0
          i32.load offset=28
          local.tee 7
          i32.ne
          br_if 0 (;@3;)
          local.get 6
          i32.const -24
          i32.add
          local.set 8
          br 1 (;@2;)
        end
        local.get 6
        local.set 4
        loop  ;; label = @3
          local.get 4
          i32.load
          local.set 8
          local.get 4
          i32.const 0
          i32.store
          local.get 4
          i32.const -24
          i32.add
          local.tee 5
          i32.load
          local.set 6
          local.get 5
          local.get 8
          i32.store
          block  ;; label = @4
            local.get 6
            i32.eqz
            br_if 0 (;@4;)
            local.get 6
            call 26
          end
          local.get 4
          i32.const -16
          i32.add
          local.tee 6
          i32.const 8
          i32.add
          local.get 4
          i32.const 16
          i32.add
          i32.load
          i32.store
          local.get 6
          local.get 4
          i32.const 8
          i32.add
          i64.load
          i64.store
          local.get 7
          local.get 4
          i32.const 24
          i32.add
          local.tee 4
          i32.ne
          br_if 0 (;@3;)
        end
        local.get 4
        i32.const -24
        i32.add
        local.set 8
        local.get 0
        i32.load offset=28
        local.tee 6
        i32.const 24
        i32.add
        local.get 4
        i32.eq
        br_if 1 (;@1;)
      end
      loop  ;; label = @2
        local.get 6
        i32.const -24
        i32.add
        local.tee 6
        i32.load
        local.set 4
        local.get 6
        i32.const 0
        i32.store
        block  ;; label = @3
          local.get 4
          i32.eqz
          br_if 0 (;@3;)
          local.get 4
          call 26
        end
        local.get 8
        local.get 6
        i32.ne
        br_if 0 (;@2;)
      end
    end
    local.get 0
    local.get 8
    i32.store offset=28
    local.get 2
    i32.const 16
    i32.add
    global.set 0)
  (func (;34;) (type 15) (param i32 i32 i32)
    (local i32 i32 i32 i32)
    global.get 0
    i32.const 16
    i32.sub
    local.tee 3
    global.set 0
    i32.const 40
    call 25
    local.tee 4
    i64.const 0
    i64.store offset=16
    local.get 4
    i64.const 0
    i64.store offset=8
    local.get 4
    local.get 1
    i32.load
    i32.store offset=24
    block  ;; label = @1
      local.get 2
      i32.load
      local.tee 1
      i32.load offset=8
      local.get 1
      i32.load offset=4
      local.tee 5
      i32.sub
      i32.const 3
      i32.gt_u
      br_if 0 (;@1;)
      i32.const 0
      i32.const 8295
      call 1
      local.get 1
      i32.load offset=4
      local.set 5
    end
    local.get 4
    local.get 5
    i32.const 4
    call 3
    drop
    local.get 1
    local.get 1
    i32.load offset=4
    i32.const 4
    i32.add
    local.tee 5
    i32.store offset=4
    local.get 3
    i64.const 0
    i64.store offset=8
    block  ;; label = @1
      local.get 1
      i32.load offset=8
      local.get 5
      i32.sub
      i32.const 7
      i32.gt_u
      br_if 0 (;@1;)
      i32.const 0
      i32.const 8295
      call 1
      local.get 1
      i32.load offset=4
      local.set 5
    end
    local.get 4
    i32.const 16
    i32.add
    local.set 6
    local.get 3
    i32.const 8
    i32.add
    local.get 5
    i32.const 8
    call 3
    drop
    local.get 4
    local.get 3
    i64.load offset=8
    i64.store offset=8
    local.get 1
    local.get 1
    i32.load offset=4
    i32.const 8
    i32.add
    local.tee 5
    i32.store offset=4
    block  ;; label = @1
      local.get 1
      i32.load offset=8
      local.get 5
      i32.sub
      i32.const 7
      i32.gt_u
      br_if 0 (;@1;)
      i32.const 0
      i32.const 8295
      call 1
      local.get 1
      i32.load offset=4
      local.set 5
    end
    local.get 6
    local.get 5
    i32.const 8
    call 3
    drop
    local.get 0
    local.get 4
    i32.store
    local.get 1
    local.get 1
    i32.load offset=4
    i32.const 8
    i32.add
    i32.store offset=4
    local.get 4
    local.get 2
    i32.load offset=4
    i32.load
    i32.store offset=28
    local.get 4
    i32.const -1
    i32.store offset=32
    local.get 3
    i32.const 16
    i32.add
    global.set 0)
  (func (;35;) (type 16) (param i32 i32 i32 i32)
    (local i32 i32 i32 i32 i32)
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          local.get 0
          i32.load offset=4
          local.get 0
          i32.load
          local.tee 4
          i32.sub
          i32.const 24
          i32.div_s
          local.tee 5
          i32.const 1
          i32.add
          local.tee 6
          i32.const 178956971
          i32.ge_u
          br_if 0 (;@3;)
          i32.const 178956970
          local.set 7
          block  ;; label = @4
            block  ;; label = @5
              local.get 0
              i32.load offset=8
              local.get 4
              i32.sub
              i32.const 24
              i32.div_s
              local.tee 4
              i32.const 89478484
              i32.gt_u
              br_if 0 (;@5;)
              local.get 6
              local.get 4
              i32.const 1
              i32.shl
              local.tee 7
              local.get 7
              local.get 6
              i32.lt_u
              select
              local.tee 7
              br_if 0 (;@5;)
              i32.const 0
              local.set 7
              i32.const 0
              local.set 4
              br 1 (;@4;)
            end
            local.get 7
            i32.const 24
            i32.mul
            call 25
            local.set 4
          end
          local.get 1
          i32.load
          local.set 6
          local.get 1
          i32.const 0
          i32.store
          local.get 4
          local.get 5
          i32.const 24
          i32.mul
          local.tee 8
          i32.add
          local.tee 1
          local.get 3
          i32.load
          i32.store offset=16
          local.get 1
          local.get 2
          i64.load
          i64.store offset=8
          local.get 1
          local.get 6
          i32.store
          local.get 4
          local.get 7
          i32.const 24
          i32.mul
          i32.add
          local.set 5
          local.get 1
          i32.const 24
          i32.add
          local.set 6
          local.get 0
          i32.load offset=4
          local.tee 2
          local.get 0
          i32.load
          local.tee 7
          i32.eq
          br_if 1 (;@2;)
          local.get 4
          local.get 8
          i32.add
          i32.const -24
          i32.add
          local.set 1
          loop  ;; label = @4
            local.get 2
            i32.const -24
            i32.add
            local.tee 4
            i32.load
            local.set 3
            local.get 4
            i32.const 0
            i32.store
            local.get 1
            local.get 3
            i32.store
            local.get 1
            i32.const 8
            i32.add
            local.get 2
            i32.const -16
            i32.add
            local.tee 2
            i64.load
            i64.store
            local.get 1
            i32.const 16
            i32.add
            local.get 2
            i32.const 8
            i32.add
            i32.load
            i32.store
            local.get 1
            i32.const -24
            i32.add
            local.set 1
            local.get 4
            local.set 2
            local.get 7
            local.get 4
            i32.ne
            br_if 0 (;@4;)
          end
          local.get 1
          i32.const 24
          i32.add
          local.set 1
          local.get 0
          i32.load offset=4
          local.set 7
          local.get 0
          i32.load
          local.set 4
          br 2 (;@1;)
        end
        local.get 0
        call 27
        unreachable
      end
      local.get 7
      local.set 4
    end
    local.get 0
    local.get 5
    i32.store offset=8
    local.get 0
    local.get 6
    i32.store offset=4
    local.get 0
    local.get 1
    i32.store
    block  ;; label = @1
      local.get 7
      local.get 4
      i32.eq
      br_if 0 (;@1;)
      loop  ;; label = @2
        local.get 7
        i32.const -24
        i32.add
        local.tee 7
        i32.load
        local.set 1
        local.get 7
        i32.const 0
        i32.store
        block  ;; label = @3
          local.get 1
          i32.eqz
          br_if 0 (;@3;)
          local.get 1
          call 26
        end
        local.get 4
        local.get 7
        i32.ne
        br_if 0 (;@2;)
      end
    end
    block  ;; label = @1
      local.get 4
      i32.eqz
      br_if 0 (;@1;)
      local.get 4
      call 26
    end)
  (table (;0;) 1 1 funcref)
  (memory (;0;) 1)
  (global (;0;) (mut i32) (i32.const 8192))
  (global (;1;) i32 (i32.const 8485))
  (global (;2;) i32 (i32.const 8485))
  (export "memory" (memory 0))
  (export "apply" (func 21))
  (data (;0;) (i32.const 8208) "failed to allocate pages\00extsymbolref \e8\a1\a8\e5\b7\b2\e6\b8\85\e7\a9\ba\00\00\00\00\00\00\00\00")
  (data (;1;) (i32.const 8266) "\00\00\00\00\00\00error reading iterator\00datastream attempted to read past the end\00object passed to erase is not in multi_index\00cannot erase objects in table of another contract\00attempt to remove object that was not in multi_index\00")
  (data (;2;) (i32.const 0) "(!\00\00"))
