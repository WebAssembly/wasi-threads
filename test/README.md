# Running tests
The following command executes wasi-threads tests using wasmtime runtime (please note wasi-threads proposal is still in development in Wasmtime and requires [this change](https://github.com/bytecodealliance/wasmtime/pull/5484) to work).

```bash
git clone -b prod/testsuite-all https://github.com/WebAssembly/wasi-testsuite
cd wasi-testsuite/
TEST_RUNTIME_EXE="wasmtime --wasm-features=threads --wasi-modules=experimental-wasi-threads" python3 test-runner/wasi_test_runner.py \
    -r adapters/wasmtime.sh \
    -t tests/proposals/wasi-threads/
```

See https://github.com/WebAssembly/wasi-testsuite for details.
