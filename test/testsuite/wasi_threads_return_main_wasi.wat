;; When the main thread returns from _start, it should terminate
;; a thread blocking in a WASI call. (poll_oneoff)
;;
;; linear memory usage:
;;   0: wait
;;   0x100: poll_oneoff subscription
;;   0x200: poll_oneoff event
;;   0x300: poll_oneoff return value

(module
  (memory (export "memory") (import "foo" "bar") 1 1 shared)
  (func $thread_spawn (import "wasi" "thread-spawn") (param i32) (result i32))
  (func $poll_oneoff (import "wasi_snapshot_preview1" "poll_oneoff") (param i32 i32 i32 i32) (result i32))
  (func (export "wasi_thread_start") (param i32 i32)
    ;; long enough block
    ;; clock_realtime, !abstime (zeros)
    i32.const 0x118 ;; 0x100 + offsetof(subscription, timeout)
    i64.const 1_000_000_000 ;; 1s
    i64.store
    i32.const 0x100 ;; subscription
    i32.const 0x200 ;; event (out)
    i32.const 1   ;; nsubscriptions
    i32.const 0x300 ;; retp (out)
    call $poll_oneoff
    unreachable
  )
  (func (export "_start")
    ;; spawn a thread
    i32.const 0
    call $thread_spawn
    ;; check error
    i32.const 0
    i32.le_s
    if
      unreachable
    end
    ;; wait 500ms to ensure the other thread block
    i32.const 0
    i32.const 0
    i64.const 500_000_000
    memory.atomic.wait32
    ;; assert a timeout
    i32.const 2
    i32.ne
    if
      unreachable
    end
    ;; note: return from _start is the same as proc_exit(0).
  )
)
