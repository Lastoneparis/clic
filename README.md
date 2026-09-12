<div align="center">

# clic

### An open, vendor-neutral compute language — CUDA's model without the lock-in.

**One language for AI, hashing, and graphics** — running on your GPU today,
built to target FPGAs and custom silicon next.

<img src="assets/cube.gif" width="360" alt="A 3D cube rasterized by a clic kernel" />

*A shaded 3D cube, rasterized pixel-by-pixel by a clic kernel on the GPU.*

[![CI](https://github.com/Lastoneparis/clic/actions/workflows/ci.yml/badge.svg)](https://github.com/Lastoneparis/clic/actions/workflows/ci.yml)
![license](https://img.shields.io/badge/license-MIT-blue)
![backend](https://img.shields.io/badge/backend-Apple%20Metal-black)
![next](https://img.shields.io/badge/next-FPGA%20%2F%20silicon-8A2BE2)
![status](https://img.shields.io/badge/status-prototype-orange)
![stars](https://img.shields.io/github/stars/Lastoneparis/clic?style=social)

</div>

---

## Why clic?

CUDA is fast, but it only runs on NVIDIA. That lock-in is its biggest weakness.

**clic keeps what's good about CUDA** — the simple *grid-of-threads* kernel
model — and drops what isn't: the vendor lock-in, the block/thread bookkeeping,
the cryptic errors. One kernel, written once, is meant to run on **many**
backends.

```
   your kernel (.clic)
        │   clicc.py  (compiler)
        ▼
   Metal Shading Language ──► Apple GPU     ◄─ works today
   (next) clic IR ──────────► FPGA over USB ◄─ our own board
   (next) clic IR ──────────► custom silicon
```

The bet: you don't beat CUDA on raw speed — you beat it on **openness,
efficiency-per-watt, and sovereignty**, and clic is the software layer that
makes non-NVIDIA hardware usable.

## Benchmarks — Apple M3 Pro, verified

| Workload | Kernel | Result | Verified against |
|---|---|---|---|
| 🧠 **AI** | `gemm_tiled` (1024³, shared memory) | **872 GFLOP/s** | CPU reference |
| 🧠 AI | `linear_relu` (fused matmul + bias + ReLU) | 505 GFLOP/s | CPU reference |
| 🧠 AI | `gemm` (1024³, naive) | 477 GFLOP/s | CPU reference |
| 🔐 **Hash** | `sha256` (1M nonces) | **836 MH/s** | Apple CryptoKit |
| 🎮 **Graphics** | `raster` (512², shaded cube) | ~3,200 fps | *(the GIF above)* |

The tiled GEMM is **1.8× faster** than the naive one — same language, real GPU
optimization (shared memory + barriers). The SHA-256 runtime also scans its
range for the "hardest" hash — a real mining primitive.

## Quick start

Requires macOS with Xcode command-line tools (Swift + the Metal compiler) and
Python 3. Then:

```bash
git clone https://github.com/Lastoneparis/clic
cd clic
./run.sh          # compiles every kernel and runs it on your GPU
```

Each kernel prints its throughput and a correctness check. New here? Walk
through **[docs/TUTORIAL.md](docs/TUTORIAL.md)** — write and run your own kernel
in a few minutes.

## From Python

Run a kernel on the GPU in a few lines — no Metal boilerplate ([python/](python/)):

```python
import clic
out = clic.run("examples/saxpy.clic", "saxpy", grid=[8, 1, 1],
               values={"n": 8, "a": 3.0, "x": [0,1,2,3,4,5,6,7], "y": [10]*8},
               read=["y"])
print(out["y"])   # [10.0, 13.0, 16.0, 19.0, 22.0, 25.0, 28.0, 31.0]
```

## The language, at a glance

`tid.x` is the global thread index — no block math to get wrong:

```rust
// y = a*x + y
kernel saxpy(n: i32, a: f32, x: buffer<f32>, y: buffer<f32>) {
    let i = tid.x;
    if (i < n) {
        y[i] = a * x[i] + y[i];
    }
}
```

It also has reusable **device functions** and a small **standard library** —
a fused neural-net layer is just:

```rust
include "../lib/activations.clic"      // relu, gelu, sigmoid, ...

kernel linear_relu(/* ... */) {
    // ... matmul + bias ...
    C[row * N + col] = relu(acc);      // C = relu(A*B + bias)
}
```

Plus `threadgroup` (shared) memory, `barrier()`, bitwise ops and `rotr` (for
crypto), local `array<T,N>`, and per-group ids `ltid`/`bid`. Full reference:
**[docs/LANGUAGE.md](docs/LANGUAGE.md)**. Kernels in [`examples/`](examples/).

## How it's built

| Path | What |
|------|------|
| `clicc.py` | The compiler: clic → Metal (lexer, parser, codegen) |
| `examples/*.clic` | Kernels: `saxpy`, `gemm`, `gemm_tiled`, `linear_relu`, `reduce`, `nn` (softmax/layernorm), `collatz`, `sha256`, `raster` |
| `lib/*.clic` | Standard library (activation functions) |
| `host/clicrun.swift` | Metal runtime + benchmark & verification harness |
| `python/clic.py` | Python host API — run a kernel from Python |
| `raster_scene.py` | Host-side geometry (the "vertex stage") for the rasterizer |
| `runs/*.json` | Run manifests (sizes, grid, buffers) |
| `docs/LANGUAGE.md` | The language reference · `tests/` | CI compile checks |

## Roadmap

- [x] clic → Metal; GEMM, SAXPY, SHA-256 running and verified
- [x] Shared memory, `barrier()`, `ltid`/`bid` — tiled GEMM (1.8× over naive)
- [x] SHA-256 verified vs Apple CryptoKit, plus a mining scan
- [x] Triangle rasterizer — a shaded 3D cube (graphics path started)
- [x] Device functions + `include`; a stdlib (activations) + a fused NN layer
- [x] Full control flow: `while`, `break`/`continue`, compound assignment
- [x] Parallel reduction (tree sum) + a step-by-step TUTORIAL
- [x] AI library: softmax + layernorm (transformer building blocks)
- [x] Python host API — run a clic kernel from Python in a few lines
- [ ] A dedicated clic IR (decouple the front-end from backends)
- [ ] The **FPGA backend** — target the Lattice ECP5 (ULX3S) over USB
- [ ] Textured / perspective-correct triangles; animation
- [ ] The long road: a graphics API + drivers (to run real games)

## Status & honesty

clic is an early **prototype**. It is **not** faster than CUDA in absolute
terms — nothing is, by being a language; speed comes from silicon. What clic
offers is portability, clean ergonomics, and a path to hardware you control.
Contributions and ideas welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

The bigger vision — a European fabless AI-inference accelerator built on this
open stack — is in [PITCH.md](PITCH.md) and [docs/FUNDRAISING.md](docs/FUNDRAISING.md).

**Toward silicon — `clic-A1`:** the accelerator this stack compiles to, with a
de-risked path from FPGA to an FD-SOI MPW tape-out:
[architecture](docs/hardware/ARCHITECTURE.md) ·
[ISA](docs/hardware/ISA.md) ·
[MVP silicon](docs/hardware/MVP-SILICON.md) ·
[ASIC flow](docs/hardware/ASIC-FLOW.md) ·
[MPW shuttle & process](docs/hardware/MPW-SHUTTLE.md) ·
[hardware roadmap](docs/hardware/HARDWARE-ROADMAP.md).

The compute core is real, not just specified: [`rtl/`](rtl/) has a
synthesizable **systolic MAC array** in Verilog, verified in simulation against
a CPU reference (`./rtl/sim.sh`).

## License

[MIT](LICENSE) © 2026 Hugo Moriceau

<div align="center">

**If this direction interests you, a ⭐ helps it find contributors.**

</div>
