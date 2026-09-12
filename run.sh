#!/bin/bash
# Build + run the clic MVP end to end: clic -> Metal -> GPU benchmark.
set -e
cd "$(dirname "$0")"
mkdir -p build

echo "==> [1/3] compiling clic kernels (clicc.py)"
python3 clicc.py examples/saxpy.clic  -o build/saxpy.metal
python3 clicc.py examples/gemm.clic   -o build/gemm.metal
python3 clicc.py examples/sha256.clic -o build/sha256.metal

echo "==> [2/3] building GPU host (clicrun.swift)"
swiftc -O host/clicrun.swift -o build/clicrun

echo "==> [3/3] running on the GPU"
echo
./build/clicrun runs/saxpy.json
echo
./build/clicrun runs/gemm.json
echo
./build/clicrun runs/sha256.json
