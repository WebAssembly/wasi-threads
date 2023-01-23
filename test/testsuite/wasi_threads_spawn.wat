;; Create a thread with thread-spawn and perform a few sanity checks.

(module
  (memory (export "memory") (import "foo" "bar") 1 1 shared)
  (func $thread_spawn (import "wasi" "thread_spawn") (param i32) (result i32))
  (func $proc_exit (import "wasi_snapshot_preview1" "proc_exit") (param i32))
  (func (export "wasi_thread_start") (param i32 i32)
    ;; store tid
    i32.const 4
    local.get 0
    i32.store
    ;; store user pointer
    i32.const 8
    local.get 1
    i32.store
    ;; notify the main
    i32.const 0
    i32.const 1
    i32.atomic.store
    i32.const 0
    i32.const 1
    memory.atomic.notify
    drop
    ;; returning from wasi_thread_start terminates only this thread
  )
  (func (export "_start") (local i32)
    ;; spawn a thread
    i32.const 12345  ;; user pointer
    call $thread_spawn
    ;; check error
    local.tee 0 ;; save the tid to check later
    i32.const 0
    i32.le_s
    if
      unreachable
    end
    ;; wait for the spawned thread to run
    i32.const 0
    i32.const 0
    i64.const -1
    memory.atomic.wait32
    ;; assert it was not a timeout
    i32.const 2
    i32.eq
    if
      unreachable
    end
    ;; check the tid
    local.get 0
    i32.const 4
    i32.load
    i32.ne
    if
      unreachable
    end
    ;; check the user pointer
    i32.const 8
    i32.load
    i32.const 12345
    i32.ne
    if
      unreachable
    end
    ;; exit
    i32.const 22
    call $proc_exit
    unreachable
  )
)
