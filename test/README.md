# Running tests

```bash
git clone -b prod/testsuite-all https://github.com/WebAssembly/wasi-testsuite
cd wasi-testsuite/
```

To execute the `wasi-threads` tests using the Wasmtime
runtime:
```bash
TEST_RUNTIME_EXE="wasmtime --wasm-features=threads --wasi-modules=experimental-wasi-threads" python3 test-runner/wasi_test_runner.py \
    -r adapters/wasmtime.py \
    -t tests/proposals/wasi-threads/
```

To execute the `wasi-threads` tests using the WAMR
runtime:
```bash
TEST_RUNTIME_EXE="iwasm" python3 test-runner/wasi_test_runner.py \
    -r adapters/wasm-micro-runtime.py \
    -t tests/proposals/wasi-threads/
```

See https://github.com/WebAssembly/wasi-testsuite for details.
