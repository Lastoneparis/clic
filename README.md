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
| **gemm_tiled** (1024³, fp32) — AI, shared-memory | **~870 GFLOP/s** | PASS (vs CPU) |
| gemm (1024³, fp32) — AI, naive | ~477 GFLOP/s | PASS (vs CPU) |
| **sha256** (1M nonces) — hash / mining | **~836 MH/s** | PASS (vs Apple CryptoKit) |
| **raster** (512² , 3D cube) — graphics | ~0.31 ms/frame (~3200 fps) | visual (renders build/raster.png) |
| saxpy (1M, fp32) | memory-bound | PASS (exact) |

All three target workloads run in your own language:
- **AI** — GEMM; the tiled (shared-memory) version is **1.8× faster** than naive,
  proving clic expresses real GPU optimization.
- **Hash** — SHA-256, verified vs Apple CryptoKit; the runtime also scans the
  hashed range for the "hardest" nonce (a real mining primitive).
- **Graphics** — a triangle rasterizer renders a shaded 3D cube to a PNG; the
  same idea drives the FPGA's HDMI framebuffer later.

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

- [x] clic → Metal; GEMM, SAXPY, SHA-256 verified on the GPU
- [x] SHA-256 verified vs Apple CryptoKit, + a mining scan (hardest nonce)
- [x] Language: bitwise ops, rotate, local + `threadgroup` arrays, `barrier()`,
      `ltid`/`bid` (thread-in-group / group ids)
- [x] Tiled/threadgroup-memory GEMM — 1.8× over naive
- [x] Triangle rasterizer — renders a shaded 3D cube (graphics path started)
- [ ] Perspective-correct / textured triangles; a spinning animation
- [ ] clic IR + FPGA backend (targets the ULX3S 85F over USB)
- [ ] Graphics API compatibility (the long road to running real games)
