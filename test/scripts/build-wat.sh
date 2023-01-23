#! /bin/sh

WAT2WASM=${WAT2WASM:-wat2wasm}
for wat in testsuite/*.wat; do
	${WAT2WASM} --enable-threads -o ${wat%%.wat}.wasm ${wat}
done
