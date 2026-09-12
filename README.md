# clic — a clean, CUDA-like compute language

**Goal:** the software layer of a French/EU compute-accelerator project — a
language that replaces CUDA by keeping its strengths (the grid-of-threads
kernel model) while dropping its sharp edges (block/thread bookkeeping, host
boilerplate, cryptic errors).

**Strategy — one language, many backends:**

```
   .clic source
        │  clicc.py  (compiler)
        ▼
   Metal Shading Language ──► Apple GPU   ◄─ backend #1 (WORKS TODAY, this repo)
   (later) clic IR ─────────► FPGA / USB  ◄─ backend #2 (the €1000 board)
   (later) clic IR ─────────► real silicon◄─ backend #3 (raise money)
```

Proving the language on this Mac's GPU **now** de-risks everything: the
language, compiler, and benchmarks are done before any hardware ships. When
the FPGA arrives we add a backend, not a new language.

## What's here

| Path | What |
|------|------|
| `clicc.py` | The compiler: clic → Metal Shading Language (lexer, parser, codegen) |
| `examples/saxpy.clic` | `y = a*x + y` — the hello-world kernel |
| `examples/gemm.clic` | `C = A*B` — matrix multiply, the core of AI |
| `host/clicrun.swift` | Metal runtime: compiles the kernel, runs on GPU, verifies vs CPU, benchmarks |
| `runs/*.json` | Run manifests (sizes, grid, buffers) |
| `run.sh` | Build + run everything |

## Run it

```bash
./run.sh
```

## First results (Apple M3 Pro, 18-core GPU)

| Kernel | Throughput | Correctness |
|--------|-----------|-------------|
| gemm (1024³, fp32) — the AI workload | **~460 GFLOP/s** | PASS (rel err 1e-7 vs CPU) |
| sha256 (1M nonces) — the hash workload | **~800 MH/s** | PASS (vs Apple CryptoKit) |
| saxpy (1M, fp32) | memory-bound | PASS (exact) |

Two of the three target workloads, in your own language, verified. GEMM proves
the AI story; SHA-256 proves the hash/hacking story (and is the FPGA's future
strong suit on perf-per-watt). The graphics workload arrives with the FPGA
board (HDMI out). GEMM is a naive kernel — a tiled version will push it higher.

## The clic language (v0.1)

```
kernel name(param: type, ...) { ...statements... }
```

- **Types:** `i32`, `u32`, `f32`, `bool`, `buffer<T>`
- **Thread id:** `tid.x`, `tid.y`, `tid.z` (global index — no block math)
- **Statements:** `let`/`var` (typed or inferred), `if/else`, `for`, assignment
- **Expressions:** arithmetic, comparisons, `&&`/`||`/`!`, indexing `a[i]`,
  `.` access, builtins (`min`, `max`, `sqrt`, `float(...)`, ...)

## Roadmap

- [x] clic → Metal, GEMM + SAXPY running and verified on the GPU
- [x] SHA-256 kernel — verified vs Apple CryptoKit (the hash/hacking benchmark)
- [x] Language: bitwise ops, rotate, local arrays (`array<T,N>`)
- [ ] Tiled/threadgroup-memory GEMM (show clic can express optimization)
- [ ] A tiny rasterizer (the video-game demo)
- [ ] clic IR + FPGA backend (targets the ULX3S over USB)
