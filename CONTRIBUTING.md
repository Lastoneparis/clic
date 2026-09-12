# Contributing to clic

clic is an open, vendor-neutral compute language. Its bet: keep CUDA's
grid-of-threads model, drop the lock-in, and target many backends from one
source — Apple Metal today, FPGA/custom silicon next.

## Repo layout

- `clicc.py` — the compiler (clic → Metal). Lexer, parser, code generator.
- `examples/*.clic` — kernels (`saxpy`, `gemm`, `sha256`).
- `host/clicrun.swift` — the Metal runtime + benchmark/verification harness.
- `runs/*.json` — run manifests (sizes, grid, buffers).
- `run.sh` — build + run everything.

## Dev setup (macOS, Apple Silicon)

Requires Xcode command-line tools (Swift + the Metal compiler) and Python 3.
Then:

```bash
./run.sh
```

Each kernel prints throughput and a correctness check (GEMM vs a CPU
reference, SHA-256 vs Apple CryptoKit).

## Adding a kernel

1. Write `examples/<name>.clic`.
2. Add `runs/<name>.json` (grid, threadgroup, buffers, optional `verify`).
3. Add the two lines to `run.sh`.

## Language scope (v0.1)

Kernels; types `i32`/`u32`/`f32`/`bool`, `buffer<T>`, `array<T,N>`; `tid.x/.y/.z`;
`let`/`var`; `if`/`else`/`for`; arithmetic, comparison, logical, and bitwise
operators; `rotr`, `min`, `max`, `sqrt`, casts. See `README.md`.

## Roadmap help wanted

- Tiled/threadgroup-memory GEMM
- A clic IR (decouple front-end from backends)
- The FPGA (ECP5) backend
- A triangle rasterizer (graphics demo)

Open an issue before large changes so we can agree on direction.
