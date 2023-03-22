;; When the main thread calls proc_exit, it should terminate
;; a thread blocking in a WASI call. (fd_read)
;;
;; assumption: read from FD 0 blocks.
;;
;; linear memory usage:
;;   0: wait
;;   100: fd_read iovec
;;   200: buffer
;;   300: result

(module
  (memory (export "memory") (import "foo" "bar") 1 1 shared)
  (func $thread_spawn (import "wasi" "thread-spawn") (param i32) (result i32))
  (func $proc_exit (import "wasi_snapshot_preview1" "proc_exit") (param i32))
  (func $fd_read (import "wasi_snapshot_preview1" "fd_read") (param i32 i32 i32 i32) (result i32))
  (func (export "wasi_thread_start") (param i32 i32)
    ;; read from FD 0
    i32.const 100 ;; iov_base
    i32.const 200 ;; buffer
    i32.store
    i32.const 104 ;; iov_len
    i32.const 1
    i32.store
    i32.const 0 ;; fd 0
    i32.const 100 ;; iov_base
    i32.const 1   ;; iov count
    i32.const 300 ;; retp (out)
    call $fd_read
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
    ;; exit
    i32.const 99
    call $proc_exit
    unreachable
  )
)
