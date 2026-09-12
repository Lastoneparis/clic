# The clic language

A small, CUDA-like compute language. A **kernel** runs once per thread over a
grid; `tid.x/.y/.z` is the global thread id — no block/thread math to get
wrong. This document is the v0.1 reference.

## Program structure

A `.clic` file contains device functions (`fn`) and kernels (`kernel`), and may
pull in a library:

```rust
include "../lib/activations.clic"

fn scale(x: f32, k: f32) -> f32 { return x * k; }

kernel apply(n: i32, k: f32, x: buffer<f32>) {
    let i = tid.x;
    if (i < n) { x[i] = scale(x[i], k); }
}
```

- `include "path"` — textually includes another `.clic` file (path is relative
  to the including file). Safe against cycles.
- `fn name(params) -> type { ... }` — a device function; returns with `return`.
- `kernel name(params) { ... }` — a GPU entry point (no return value).

## Types

| Type | Meaning |
|------|---------|
| `i32`, `u32` | 32-bit signed / unsigned integer |
| `f32` | 32-bit float |
| `f16` | 16-bit float (half) — for quantized/AI compute |
| `bool` | boolean |
| `buffer<T>` | a pointer to global memory (kernel/fn parameter) |
| `array<T, N>` | a thread-local fixed array |
| `threadgroup array<T, N>` | shared memory, visible to a whole threadgroup |

## Thread identity

| Expr | Meaning |
|------|---------|
| `tid.x/.y/.z` | global thread index |
| `ltid.x/.y/.z` | thread index within its threadgroup |
| `bid.x/.y/.z` | threadgroup index within the grid |

## Statements

- `let name = expr;` / `let name: T = expr;` — immutable binding
- `var name: T = expr;` / `var name: T;` — mutable; arrays declared without init
- `name = expr;` and `a[i] = expr;` — assignment
- compound assignment: `+= -= *= /= %= &= |= ^= <<= >>=`
- `if (cond) { ... } else { ... }`
- `for (var i: i32 = 0; i < n; i = i + 1) { ... }`
- `while (cond) { ... }`, with `break;` and `continue;`
- `return expr;` (in functions)
- `barrier();` — threadgroup synchronization

## Expressions

Operators, tightest-binding first:

```
* / %        +  -        << >>        < <= > >=        == !=
&        ^        |        &&        ||
```

Unary: `-x`, `!x`, `~x`. Conditional (ternary): `cond ? a : b`.
Indexing `a[i]`, member `v.x`, calls `f(a, b)`.

## Built-in functions

`min`, `max`, `abs`, `clamp`, `sqrt`, `exp`, `log`, `pow`, `fma`, `floor`,
`ceil`, `tanh`; casts `float(x)`, `int(x)`, `uint(x)`; `rotr(x, n)`
(32-bit rotate-right, for crypto); `barrier()`.

## Standard library

`lib/activations.clic` provides `relu`, `leaky_relu`, `sigmoid`, `gelu`.
Pull it in with `include`.

## Complete examples

See [`examples/`](../examples/): `saxpy`, `gemm`, `gemm_tiled` (shared memory),
`linear_relu` (a fused NN layer using the stdlib), `sha256`, `raster`.

## Compiling

```bash
python3 clicc.py examples/gemm_tiled.clic -o build/gemm_tiled.metal
```

Today the only backend is Apple Metal (MSL). The compiler front-end
(lexer → parser → AST) is intentionally separate from code generation so more
backends — FPGA, custom silicon — can be added behind the same language.
