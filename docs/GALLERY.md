# Gallery — clic by example

A tour of the library through short, real kernels. Full sources in
[`examples/`](../examples/); run any with `bin/clic run runs/<name>.json`.

## SAXPY — the map pattern
`y = a·x + y`. One thread per element; `tid.x` is the global index.
```rust
kernel saxpy(n: i32, a: f32, x: buffer<f32>, y: buffer<f32>) {
    let i = tid.x;
    if (i < n) { y[i] = a * x[i] + y[i]; }
}
```

## Branchless clamp — the ternary
Clamp into `[0,1]` with nested `?:`, no `if`.
```rust
let v = x[i];
y[i] = (v < 0.0) ? 0.0 : ((v > 1.0) ? 1.0 : v);
```

## Reduce — shared memory + barriers
Each threadgroup tree-reduces 256 values to one partial sum.
```rust
var scratch: threadgroup array<f32, 256>;
scratch[lx] = (gi < n) ? x[gi] : 0.0;   barrier();
var stride = 128;
while (stride > 0) {
    if (lx < stride) { scratch[lx] = scratch[lx] + scratch[lx + stride]; }
    barrier();
    stride /= 2;
}
```

## INT8 quantize — the i8 type
Round to INT8 and back — the heart of quantized inference.
```rust
var q: i8 = char(round(x[i] * 127.0));
y[i] = float(q) / 127.0;
```

## RMSNorm — the LLM normalization (Mistral / LLaMA)
```rust
var ss = 0.0;
for (var j: i32 = 0; j < C; j = j + 1) { let v = x[r*C+j]; ss = ss + v*v; }
let inv = 1.0 / sqrt(ss / float(C) + eps);
for (var j: i32 = 0; j < C; j = j + 1) { y[r*C+j] = x[r*C+j] * inv; }
```

## Fused FFN layer — functions + the stdlib
`C = gelu(A·B + bias)`, activation pulled from `lib/activations.clic`.
```rust
include "../lib/activations.clic"
// ... matmul into acc, plus bias ...
C[row * N + col] = gelu(acc);
```

## argmax — the decode step
Pick the next token: the index of the largest logit per row.
```rust
var best = x[r*C];   var bi: i32 = 0;
for (var j: i32 = 1; j < C; j = j + 1) {
    let v = x[r*C+j];
    if (v > best) { best = v; bi = j; }
}
out[r] = uint(bi);
```

## The big ones
- **Tiled GEMM** with `threadgroup` memory — [`examples/gemm_tiled.clic`](../examples/gemm_tiled.clic) (~864 GFLOP/s).
- **Scaled dot-product attention** — [`examples/attention.clic`](../examples/attention.clic).
- **SHA-256** (bitwise/`rotr`, local arrays) — [`examples/sha256.clic`](../examples/sha256.clic).
- **Keccak-f[1600]** (SHA-3 / keccak256 core; `u64` lanes, 64-bit rotates) — [`examples/keccak.clic`](../examples/keccak.clic).
- **SHA3-256** (full hasher: absorb + pad + squeeze; matches the NIST empty-string vector) — [`examples/sha3_256.clic`](../examples/sha3_256.clic).
- **keccak256** (Ethereum variant; matches the canonical empty-string vector) — [`examples/keccak256.clic`](../examples/keccak256.clic).
- **Rasterizer** (the 3D cube) — [`examples/raster.clic`](../examples/raster.clic).

## Putting it together
- `python/mlp_demo.py` — a 2-layer MLP on the GPU.
- `python/transformer_demo.py` — a **full transformer forward pass**
  (rmsnorm → attention → FFN → logits → argmax), verified end to end.

See the [language reference](LANGUAGE.md) and the [tutorial](TUTORIAL.md).
