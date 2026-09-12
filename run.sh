#!/bin/bash
# Build + run the clic MVP end to end: clic -> Metal -> GPU benchmark.
set -e
cd "$(dirname "$0")"
mkdir -p build

echo "==> [1/3] compiling clic kernels (clicc.py)"
python3 clicc.py examples/saxpy.clic      -o build/saxpy.metal
python3 clicc.py examples/gemm.clic       -o build/gemm.metal
python3 clicc.py examples/gemm_tiled.clic  -o build/gemm_tiled.metal
python3 clicc.py examples/gemm_i8.clic     -o build/gemm_i8.metal
python3 clicc.py examples/linear_relu.clic -o build/linear_relu.metal
python3 clicc.py examples/linear.clic      -o build/linear.metal
python3 clicc.py examples/collatz.clic     -o build/collatz.metal
python3 clicc.py examples/reduce.clic      -o build/reduce.metal
python3 clicc.py examples/nn.clic          -o build/nn.metal
python3 clicc.py examples/lang9.clic       -o build/lang9.metal
python3 clicc.py examples/quant.clic       -o build/quant.metal
python3 clicc.py examples/attention.clic   -o build/attention.metal
python3 clicc.py examples/conv2d.clic      -o build/conv2d.metal
python3 clicc.py examples/scan.clic        -o build/scan.metal
python3 clicc.py examples/vec4.clic        -o build/vec4.metal
python3 clicc.py examples/sha256.clic      -o build/sha256.metal
python3 clicc.py examples/raster.clic      -o build/raster.metal
python3 raster_scene.py                                     # build the cube scene

echo "==> [2/3] building GPU host (clicrun.swift)"
swiftc -O host/clicrun.swift -o build/clicrun

echo "==> [3/3] running on the GPU"
for r in saxpy gemm gemm_tiled gemm_i8 linear_relu linear reduce softmax layernorm attention conv2d scan vec4 clamp scale_half quant collatz sha256 raster; do
    echo
    ./build/clicrun "runs/$r.json"
done
