# Changelog

## v0.1.0 — first release

The first tagged release of clic: an open, vendor-neutral compute language with
a working Apple Metal backend, a useful library, tooling, docs, and the start of
a hardware path (verified RTL + a silicon spec).

### Language
- Kernels, device functions (`fn`), and `include`.
- Control flow: `if`/`else`, `for`, `while`, `break`, `continue`.
- Assignment incl. compound (`+= -= *= /= …`); ternary `cond ? a : b`.
- Types: `i8`/`u8`, `i32`/`u32`, `f16`/`f32`, `bool`, `buffer<T>`, `array<T,N>`,
  and `threadgroup` (shared) arrays.
- Thread ids `tid`/`ltid`/`bid`; `barrier()`; bitwise ops and `rotr`; math builtins.

### Library (all verified on GPU)
- AI: `gemm`, tiled `gemm_tiled`, `linear`, `linear_relu`, `attention`,
  `softmax`, `layernorm`, `conv2d`, INT8 `quant`, activations (relu/leaky_relu/
  sigmoid/gelu), `reduce` (tree sum).
- Hash: `sha256` (+ a mining scan). Graphics: a triangle `raster`izer.

### Tooling & adoption
- `bin/clic` CLI: `build` / `run` / `bench` / `sim`.
- Python host API (`clic.run`) + an end-to-end MLP inference demo.
- CI (GPU-free compile gate) on every kernel.

### Docs
- `docs/LANGUAGE.md`, `docs/TUTORIAL.md`, `docs/COMPARISON.md` (vs CUDA),
  `docs/BENCHMARKS.md`.

### Hardware (clic-A1 / OSHI-A1)
- Verified, synthesizable RTL: a systolic MAC array + a full GEMM accelerator
  block (SRAM + control FSM + host port).
- ECP5 synthesis: DSP-mapped, fits the ULX3S 85F (12×12 = 144-MAC cluster).
- Design docs: architecture, ISA, MVP silicon, ASIC flow, MPW/process, and the
  OSHI-A1 silicon spec (131 TOPS INT8 target).

### Honesty
Performance is bounded by the target device — clic is **not** "faster than CUDA."
All silicon figures are v0.1 targets pending fabrication.

[Unreleased]: work continues on the roadmap (IR, FPGA backend, more of the library).
