# Tutorial: your first clic kernel

This walks you from a clean checkout to writing, running, and verifying your own
GPU kernel. For the full language, see [LANGUAGE.md](LANGUAGE.md).

## 1. Prerequisites (macOS, Apple Silicon)

- **Xcode command-line tools** — provides Swift and the Metal compiler:
  `xcode-select --install`
- **Python 3** (ships with macOS).

That's it — no CUDA, no vendor SDK.

## 2. Run everything

```bash
git clone https://github.com/Lastoneparis/clic
cd clic
./run.sh
```

`run.sh` compiles each `.clic` kernel to Metal, builds the runtime, and runs
every example — printing throughput and a correctness check for each.

## 3. Anatomy of a kernel

Here is `examples/saxpy.clic` — compute `y = a*x + y`:

```rust
kernel saxpy(n: i32, a: f32, x: buffer<f32>, y: buffer<f32>) {
    let i = tid.x;            // this thread's global index
    if (i < n) {              // guard against the tail
        y[i] = a * x[i] + y[i];
    }
}
```

- A `kernel` runs once per thread. `tid.x` is the global thread id — no block
  arithmetic to get wrong.
- `buffer<f32>` parameters are arrays in GPU memory; scalars (`n`, `a`) are
  passed by value.

## 4. The run manifest

The runtime, `clicrun`, is told what to run by a small JSON file. Here is
`runs/saxpy.json`:

```json
{
  "kernel": "saxpy",
  "metal": "../build/saxpy.metal",
  "grid": [1048576, 1, 1],
  "threadgroup": [256, 1, 1],
  "iters": 200,
  "flops": 2097152,
  "verify": "saxpy",
  "bindings": [
    { "name": "n", "kind": "scalar", "type": "i32", "value": 1048576 },
    { "name": "a", "kind": "scalar", "type": "f32", "value": 2.0 },
    { "name": "x", "kind": "buffer", "type": "f32", "len": 1048576, "init": "random" },
    { "name": "y", "kind": "buffer", "type": "f32", "len": 1048576, "init": "random" }
  ]
}
```

- `grid` = total threads; `threadgroup` = threads per group.
- `bindings` are matched to kernel parameters **in order**. `init` can be
  `random`, `zero`, or inline `data`.
- `flops` (optional) makes the runtime print GFLOP/s; `verify` selects a
  built-in CPU/reference check.

Full field reference: [MANIFESTS.md](MANIFESTS.md).

## 5. Write your own kernel

Let's square every element of an array: `y[i] = x[i] * x[i]`.

**a. `examples/square.clic`**

```rust
kernel square(n: i32, x: buffer<f32>, y: buffer<f32>) {
    let i = tid.x;
    if (i < n) { y[i] = x[i] * x[i]; }
}
```

**b. `runs/square.json`**

```json
{
  "kernel": "square",
  "metal": "../build/square.metal",
  "grid": [1048576, 1, 1],
  "threadgroup": [256, 1, 1],
  "iters": 100,
  "bindings": [
    { "name": "n", "kind": "scalar", "type": "i32", "value": 1048576 },
    { "name": "x", "kind": "buffer", "type": "f32", "len": 1048576, "init": "random" },
    { "name": "y", "kind": "buffer", "type": "f32", "len": 1048576, "init": "zero" }
  ]
}
```

**c. Compile and run**

```bash
python3 clicc.py examples/square.clic -o build/square.metal
swiftc -O host/clicrun.swift -o build/clicrun     # once
./build/clicrun runs/square.json
```

You'll see it run on the GPU. (To wire it into `./run.sh`, add the compile line
and the kernel name to the run list.)

## 6. Verify correctness

The runtime has built-in references for the shipped kernels (`gemm`, `sha256`,
`reduce_sum`, ...). To check your own, add a branch in `host/clicrun.swift`
computing the expected result on the CPU and comparing — see the existing
`verify == "saxpy"` block for the pattern.

## 7. Use the standard library

Pull in reusable device functions with `include`:

```rust
include "../lib/activations.clic"

kernel apply_gelu(n: i32, x: buffer<f32>) {
    let i = tid.x;
    if (i < n) { x[i] = gelu(x[i]); }
}
```

## Next steps

- The full language: [LANGUAGE.md](LANGUAGE.md)
- Bigger examples: `examples/gemm_tiled.clic` (shared memory),
  `examples/reduce.clic` (tree reduction), `examples/sha256.clic` (crypto),
  `examples/raster.clic` (graphics).
- Open questions / good first issues: the repo's issue tracker.
