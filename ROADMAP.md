# clic roadmap — the path to a serious, open CUDA alternative

Worked through iteratively. Checked = done & pushed.

## Language completeness
- [x] kernels, `fn`, `include`, types (i32/u32/f32/bool/buffer/array)
- [x] if/else, for, arithmetic/logical/bitwise ops, indexing, calls
- [x] threadgroup memory, `barrier()`, `ltid`/`bid`
- [x] `while` loops, `break`, `continue`
- [x] compound assignment (`+= -= *= /= %= &= |= ^= <<= >>=`)
- [ ] `const` global constants
- [x] `f16` (half) type — verified on GPU (`examples/lang9.clic`)
- [x] ternary `cond ? a : b` — verified on GPU
- [x] `i8`/`u8` types — quantized AI — verified on GPU (`examples/quant.clic`)
- [x] vector type `f32x4` + swizzles — verified on GPU (`examples/vec4.clic`)

## Standard library
- [x] activations (relu, leaky_relu, sigmoid, gelu, silu/swish)
- [x] linear_gelu (transformer FFN: dense + bias + GELU) — `examples/linear_gelu.clic`
- [x] reductions (parallel tree sum) — `examples/reduce.clic`
- [x] prefix sum / inclusive scan (Hillis-Steele) — `examples/scan.clic`
- [x] argmax (greedy decode / token selection) — `examples/argmax.clic`
- [ ] reduction: max variant
- [x] softmax, layernorm — `examples/nn.clic` (transformer blocks)
- [x] scaled dot-product attention — `examples/attention.clic` (transformer core)
- [x] RMSNorm (LLaMA / Mistral normalization) — `examples/nn.clic`
- [x] conv2d — `examples/conv2d.clic` (CNN core)
- [x] INT8 GEMM (i8×i8 → i32 accumulate) — `examples/gemm_i8.clic` (the OSHI-A1 datapath)
- [ ] more math (tanh already; add erf, rsqrt helpers)
- [ ] crypto: sha256 as a callable module; keccak

## Manual & docs
- [x] LANGUAGE.md reference
- [x] TUTORIAL.md — write your first kernel, step by step
- [x] MANIFESTS.md — the run-manifest format
- [x] COMPARISON.md — clic vs CUDA (honest positioning)
- [ ] examples gallery in the README

## Adoption / "serious competitor" paths
- [x] Python host API (`import clic`; run a kernel in a few lines) — `python/`
- [x] end-to-end MLP inference demo — composed kernels via Python (`python/mlp_demo.py`)
- [x] end-to-end transformer forward pass (rmsnorm→attention→FFN→logits→argmax) — `python/transformer_demo.py`
- [x] a `clic` CLI (`clic build` / `run` / `bench` / `sim`) — `bin/clic`
- [ ] a dedicated clic IR (decouple front-end from backends)
- [x] RTL compute core — synthesizable `N×N` systolic MAC array, verified in
      simulation (`rtl/`) — the first FPGA→ASIC artifact
- [x] Wrap RTL into a GEMM accelerator block: SRAM + control FSM (HW skewing) +
      host load/read port, verified in sim (`rtl/gemm_accel.v`)
- [x] ECP5 synthesis (yosys `synth_ecp5`): DSP-mapped, fits ULX3S 85F
      (12×12 = 144-MAC cluster; `docs/hardware/SYNTHESIS.md`)
- [ ] Place & route (nextpnr-ecp5) for Fmax; map to physical ULX3S; measure perf/watt
- [x] INT4 packed MAC (2 INT4 MACs/cycle) RTL primitive, verified — `rtl/mac4.v`
- [ ] DFT (scan + memory BIST) for tape-out
- [ ] FPGA (ECP5) backend — the sovereignty story
- [ ] benchmark suite vs baselines

## Honesty
clic is not "faster than CUDA" — speed is silicon. clic competes on being
open, portable, clean, and a path to hardware you control.
