#!/bin/bash

CC=${CC:=clang}

for input in testsuite/*.c; do
  output="testsuite/$(basename $input .c).wasm"

  if [ "$input" -nt "$output" ]; then
    echo "Compiling $input"
    $CC "$input" testsuite/wasi_thread_spawn.S -o "$output"
  fi
done
