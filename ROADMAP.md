# clic roadmap — the path to a serious, open CUDA alternative

Worked through iteratively. Checked = done & pushed.

## Language completeness
- [x] kernels, `fn`, `include`, types (i32/u32/f32/bool/buffer/array)
- [x] if/else, for, arithmetic/logical/bitwise ops, indexing, calls
- [x] threadgroup memory, `barrier()`, `ltid`/`bid`
- [x] `while` loops, `break`, `continue`
- [x] compound assignment (`+= -= *= /= %= &= |= ^= <<= >>=`)
- [ ] `const` global constants
- [ ] `f16` (half) and `i8`/`u8` types — quantized AI
- [ ] vector types (`f32x4`) + swizzles
- [ ] ternary `cond ? a : b`

## Standard library
- [x] activations (relu, leaky_relu, sigmoid, gelu)
- [x] reductions (parallel tree sum) — `examples/reduce.clic`
- [ ] reduction: max + prefix sum (scan)
- [x] softmax, layernorm — `examples/nn.clic` (transformer blocks)
- [ ] more math (tanh already; add erf, rsqrt helpers)
- [ ] crypto: sha256 as a callable module; keccak

## Manual & docs
- [x] LANGUAGE.md reference
- [x] TUTORIAL.md — write your first kernel, step by step
- [ ] MANIFESTS.md — the run-manifest format
- [ ] COMPARISON.md — clic vs CUDA (honest positioning)
- [ ] examples gallery in the README

## Adoption / "serious competitor" paths
- [x] Python host API (`import clic`; run a kernel in a few lines) — `python/`
- [ ] a `clic` CLI (`clic build`, `clic run`)
- [ ] a dedicated clic IR (decouple front-end from backends)
- [x] RTL compute core — synthesizable `N×N` systolic MAC array, verified in
      simulation (`rtl/`) — the first FPGA→ASIC artifact
- [x] Wrap RTL into a GEMM accelerator block: SRAM + control FSM (HW skewing) +
      host load/read port, verified in sim (`rtl/gemm_accel.v`)
- [ ] Map the block to the ULX3S FPGA; measure real perf/watt
- [ ] INT4 packed mode; DFT (scan + memory BIST) for tape-out
- [ ] FPGA (ECP5) backend — the sovereignty story
- [ ] benchmark suite vs baselines

## Honesty
clic is not "faster than CUDA" — speed is silicon. clic competes on being
open, portable, clean, and a path to hardware you control.
