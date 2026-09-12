# Benchmarks

Every clic kernel, measured on an **Apple M3 Pro (18-core GPU)**, each with a
correctness check. Reproduce with `./run.sh` (or `bin/clic bench`).

Absolute throughput is bounded by this GPU — clic is not "faster than CUDA"
(see [COMPARISON.md](COMPARISON.md)). The point is a **complete, correct,
portable** stack across AI, hashing, and graphics, ready to retarget to our own
silicon.

## Results

| Kernel | Category | Time | Throughput | Verified against |
|--------|----------|-----:|-----------:|------------------|
| `gemm_tiled` | AI · matmul (shared memory) | 2.49 ms | **864 GFLOP/s** | CPU reference |
| `linear_relu` | AI · dense + bias + ReLU | 4.23 ms | 508 GFLOP/s | CPU reference |
| `linear` | AI · dense + bias | 4.24 ms | 507 GFLOP/s | CPU reference |
| `gemm` | AI · matmul (naive) | 4.54 ms | 473 GFLOP/s | CPU reference |
| `attention` | Transformer · scaled dot-product | 0.78 ms | — | CPU reference (2.5e-7) |
| `conv2d` | CNN · 2D convolution (3×3) | 0.17 ms | — | CPU reference (8.9e-8) |
| `softmax_rows` | Transformer · softmax | 0.72 ms | — | CPU reference |
| `layernorm_rows` | Transformer · layernorm | 0.62 ms | — | CPU reference |
| `reduce_sum` | Reduction · tree sum | 0.34 ms | — | CPU (rel 1.4e-9) |
| `quant_i8` | Quant · INT8 round-trip | 0.32 ms | — | Int8 reference (exact) |
| `scale_half` | Precision · f16 compute | 0.34 ms | — | Float16 reference |
| `clamp01` | Control · ternary | 0.33 ms | — | exact |
| `sha256` | Hash · 1M nonces | 1.18 ms | **889 MH/s** | Apple CryptoKit |
| `collatz` | Control · `while`/`break` | 1.29 ms | — | Int32 reference (exact) |
| `saxpy` | Vector · `a·x+y` | 0.25 ms | memory-bound | exact |
| `raster` | Graphics · shaded 3D cube | 0.18 ms | ~5,700 fps | rendered |

All **PASS**. `gemm_tiled` is 1.8× the naive `gemm` (shared-memory tiling).
`sha256` also reports the hardest nonce found in the scanned range (mining).

## End-to-end

`python/mlp_demo.py` composes `linear_relu` + `linear` into a 2-layer MLP on the
GPU and matches a CPU reference — the kernels compose into real inference.

## Notes

- Times are per-dispatch averages over many iterations.
- FP throughput shown only for compute-bound GEMM-family kernels; the rest are
  small or memory-bound and reported by latency.
- Numbers move a little run-to-run with GPU clocking; re-run `./run.sh` for the
  current machine.
