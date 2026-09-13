# clic roadmap — the path to a serious, open CUDA alternative

Worked through iteratively. Checked = done & pushed.

## Language completeness
- [x] kernels, `fn`, `include`, types (i32/u32/f32/bool/buffer/array)
- [x] if/else, for, arithmetic/logical/bitwise ops, indexing, calls
- [x] threadgroup memory, `barrier()`, `ltid`/`bid`
- [x] `while` loops, `break`, `continue`
- [x] compound assignment (`+= -= *= /= %= &= |= ^= <<= >>=`)
- [x] `const` global constants — file-scope, `constant` address space — verified on GPU (`examples/consts.clic`)
- [x] `f16` (half) type — verified on GPU (`examples/lang9.clic`)
- [x] ternary `cond ? a : b` — verified on GPU
- [x] `i8`/`u8` types — quantized AI — verified on GPU (`examples/quant.clic`)
- [x] vector type `f32x4` + swizzles — verified on GPU (`examples/vec4.clic`)

## Standard library
- [x] activations (relu, leaky_relu, sigmoid, gelu, silu/swish)
- [x] linear_gelu (transformer FFN: dense + bias + GELU) — `examples/linear_gelu.clic`
- [x] SwiGLU FFN (LLaMA/Mistral: SiLU-gated dual projection, fused) — `examples/swiglu.clic`, verified on GPU
- [x] reductions (parallel tree sum) — `examples/reduce.clic`
- [x] prefix sum / inclusive scan (Hillis-Steele) — `examples/scan.clic`
- [x] argmax (greedy decode / token selection) — `examples/argmax.clic`
- [x] transpose (matrix utility) — `examples/transpose.clic`
- [x] reduction: max variant (`reduce_max`) — `examples/reduce.clic`
- [x] softmax, layernorm — `examples/nn.clic` (transformer blocks)
- [x] scaled dot-product attention — `examples/attention.clic` (transformer core)
- [x] flash-attention-style online-softmax attention (single streaming pass, O(D) memory, no sequence cap) — `examples/flash_attn.clic`, matches plain attention on GPU
- [x] grouped-query attention (GQA, shared KV heads — Mistral's KV-cache saver) — `examples/gqa.clic`, verified on GPU
- [x] RMSNorm (LLaMA / Mistral normalization) — `examples/nn.clic`
- [x] RoPE rotary positional embedding (LLaMA / Mistral) — `examples/rope.clic`, verified on GPU
- [x] conv2d — `examples/conv2d.clic` (CNN core)
- [x] multi-channel conv2d (Cin→Cout, uses `tid.z`) — `examples/conv2d_mc.clic`
- [x] maxpool2d (CNN pooling) — `examples/maxpool.clic`
- [x] INT8 GEMM (i8×i8 → i32 accumulate) — `examples/gemm_i8.clic` (the OSHI-A1 datapath)
- [x] batched matmul (`bmm`, `tid.z` selects batch) — `examples/bmm.clic` (multi-head attention primitive)
- [x] math stdlib: `rsqrt sin cos tan atan2 exp2 log2 fract sign trunc` — verified on GPU (`examples/mathfns.clic`)
- [x] crypto: sha256 as a callable module (`lib/sha256.clic`, 6 device fns) — `examples/sha256.clic` includes it, 1001/1001 vs CryptoKit
- [x] `u64` type (`ulong`) + hex literals + 64-bit-safe literal suffixing — verified on GPU (`examples/u64mix.clic`)
- [x] crypto: Keccak-f[1600] permutation (SHA-3 / keccak256 core) — `examples/keccak.clic`, verified on GPU vs CPU reference + published zero-state KAT (lane0 = 0xF1258F7940E1DDE7)
- [x] crypto: full SHA3-256 hasher (absorb + pad10*1/0x06 + squeeze) — `examples/sha3_256.clic`, matches canonical `SHA3-256("")` vector on GPU
- [x] crypto: Ethereum keccak256 (0x01 domain byte) — `examples/keccak256.clic`, matches canonical `keccak256("")` vector on GPU
- [x] `fn` params that take a thread array by reference (`array<T,N>` → `thread T (&)[N]`) + void-return `fn`s — verified on GPU
- [x] extract Keccak-f into a callable module (`lib/keccak.clic`) — both keccak & sha3_256 include it, KATs still pass

## Manual & docs
- [x] LANGUAGE.md reference
- [x] TUTORIAL.md — write your first kernel, step by step
- [x] MANIFESTS.md — the run-manifest format
- [x] COMPARISON.md — clic vs CUDA (honest positioning)
- [x] examples gallery — `docs/GALLERY.md`

## Adoption / "serious competitor" paths
- [x] Python host API (`import clic`; run a kernel in a few lines) — `python/`
- [x] end-to-end MLP inference demo — composed kernels via Python (`python/mlp_demo.py`)
- [x] end-to-end transformer forward pass (rmsnorm→attention→FFN→logits→argmax) — `python/transformer_demo.py`
- [x] full Mistral-style decoder block (rmsnorm→RoPE→attention→residual→rmsnorm→SwiGLU→down→residual) — `python/mistral_block_demo.py`, matches reference end to end
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
