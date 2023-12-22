;; Minimum valid command for wasi-threads.

(module
  (memory (export "memory") (import "foo" "bar") 0 0 shared)
  (func (export "_start"))
)
